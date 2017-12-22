/*
 *  This file is part of Netsukuku.
 *  Copyright (C) 2017 Luca Dionisi aka lukisi <luca.dionisi@gmail.com>
 *
 *  Netsukuku is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  Netsukuku is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with Netsukuku.  If not, see <http://www.gnu.org/licenses/>.
 */

using Gee;
using Netsukuku;
using Netsukuku.Neighborhood;
using Netsukuku.Identities;
using Netsukuku.Qspn;
using Netsukuku.Coordinator;
using Netsukuku.Hooking;
using Netsukuku.Andna;
using TaskletSystem;

namespace Netsukuku
{
    const uint16 ntkd_port = 60269;
    const int max_paths = 5;
    const double max_common_hops_ratio = 0.6;
    const int arc_timeout = 10000;

    [CCode (array_length = false, array_null_terminated = true)]
    string[] interfaces;
    bool accept_anonymous_requests;
    bool no_anonymize;
    int subnetlevel;

    ITasklet tasklet;
    Commander cm;
    TableNames tn;
    ArrayList<int> gsizes;
    ArrayList<int> g_exp;
    int levels;
    NeighborhoodManager? neighborhood_mgr;
    IdentityManager? identity_mgr;
    ArrayList<HandledNic> handlednic_list;
    ArrayList<IdmgmtArc> arc_list;
    ArrayList<IdentityData> local_identities;

    IdentityData find_or_create_local_identity(NodeID node_id)
    {
        foreach (IdentityData k in local_identities)
        {
            if (k.nodeid.equals(node_id))
            {
                return k;
            }
        }
        IdentityData ret = new IdentityData(node_id);
        local_identities.add(ret);
        return ret;
    }

    void remove_local_identity(NodeID node_id)
    {
        local_identities.remove(find_or_create_local_identity(node_id));
    }

    IdentityArc find_identity_arc(IIdmgmtIdentityArc id_arc)
    {
        foreach (IdentityData k in local_identities) foreach (IdentityArc ia in k.identity_arcs)
        {
            if (ia.id_arc == id_arc)
            {
                return ia;
            }
        }
        error("IdentityArc not found");
    }

    IdentityArc find_identity_arc_by_peer_nodeid(IdentityData identity_data, IIdmgmtArc arc, NodeID peer_nodeid)
    {
        foreach (IdentityArc ia in identity_data.identity_arcs)
        {
            if (ia.arc == arc)
             if (ia.id_arc.get_peer_nodeid().equals(peer_nodeid))
                return ia;
        }
        error("IdentityArc not found");
    }

    ServerDelegate dlg;
    ServerErrorHandler err;
    ITaskletHandle t_tcp;
    ArrayList<ITaskletHandle> t_udp_list;

    int main(string[] _args)
    {
        subnetlevel = 0; // default
        accept_anonymous_requests = false; // default
        no_anonymize = false; // default
        OptionContext oc = new OptionContext("<options>");
        OptionEntry[] entries = new OptionEntry[5];
        int index = 0;
        entries[index++] = {"subnetlevel", 's', 0, OptionArg.INT, ref subnetlevel, "Level of g-node for autonomous subnet", null};
        entries[index++] = {"interfaces", 'i', 0, OptionArg.STRING_ARRAY, ref interfaces, "Interface (e.g. -i eth1). You can use it multiple times.", null};
        entries[index++] = {"serve-anonymous", 'k', 0, OptionArg.NONE, ref accept_anonymous_requests, "Accept anonymous requests", null};
        entries[index++] = {"no-anonymize", 'j', 0, OptionArg.NONE, ref no_anonymize, "Disable anonymizer", null};
        entries[index++] = { null };
        oc.add_main_entries(entries, null);
        try {
            oc.parse(ref _args);
        }
        catch (OptionError e) {
            print(@"Error parsing options: $(e.message)\n");
            return 1;
        }

        ArrayList<string> args = new ArrayList<string>.wrap(_args);
        ArrayList<int> naddr;
        ArrayList<string> devs;
        string ntklocalhost;

        configuration(ref args, out naddr, out devs);

        startup(ref naddr, ref devs, out ntklocalhost);

        mainloop();

        cleanup(ref ntklocalhost);

        return 0;
    }

    bool do_me_exit = false;
    void safe_exit(int sig)
    {
        // We got here because of a signal. Quick processing.
        do_me_exit = true;
    }

    class HandledNic : Object
    {
        public string dev;
        public string mac;
        public string linklocal;
    }

    class IdentityData : Object
    {
        public IdentityData(NodeID nodeid)
        {
            this.nodeid = nodeid;
            identity_arcs = new ArrayList<IdentityArc>();
            connectivity_from_level = 0;
            connectivity_to_level = 0;
            copy_of_identity = null;

            local_ip_set = init_local_ip_set();

            destination_ip_set = init_destination_ip_set();
        }

        public NodeID nodeid;
        public Naddr my_naddr;
        public Fingerprint my_fp;
        public int connectivity_from_level;
        public int connectivity_to_level;
        public IdentityData? copy_of_identity;
        public AddressManagerForIdentity addr_man;

        public ArrayList<IdentityArc> identity_arcs;

        public LocalIPSet local_ip_set;
        public HashMap<int,HashMap<int,DestinationIPSet>> destination_ip_set;

        private string _network_namespace;
        public string network_namespace {
            get {
                _network_namespace = identity_mgr.get_namespace(nodeid);
                return _network_namespace;
            }
        }

        public bool main_id {
            get {
                return nodeid.equals(identity_mgr.get_main_id());
            }
        }

        // handle signals from qspn_manager

        public bool qspn_handlers_disabled = false;

        public void arc_removed(IQspnArc arc, string message, bool bad_link)
        {
            if (qspn_handlers_disabled) return;
            per_identity_qspn_arc_removed(this, arc, message, bad_link);
        }

        public void changed_fp(int l)
        {
            if (qspn_handlers_disabled) return;
            per_identity_qspn_changed_fp(this, l);
        }

        public void changed_nodes_inside(int l)
        {
            if (qspn_handlers_disabled) return;
            per_identity_qspn_changed_nodes_inside(this, l);
        }

        public void destination_added(HCoord h)
        {
            if (qspn_handlers_disabled) return;
            per_identity_qspn_destination_added(this, h);
        }

        public void destination_removed(HCoord h)
        {
            if (qspn_handlers_disabled) return;
            per_identity_qspn_destination_removed(this, h);
        }

        public void gnode_splitted(IQspnArc a, HCoord d, IQspnFingerprint fp)
        {
            if (qspn_handlers_disabled) return;
            per_identity_qspn_gnode_splitted(this, a, d, fp);
        }

        public void path_added(IQspnNodePath p)
        {
            if (qspn_handlers_disabled) return;
            per_identity_qspn_path_added(this, p);
        }

        public void path_changed(IQspnNodePath p)
        {
            if (qspn_handlers_disabled) return;
            per_identity_qspn_path_changed(this, p);
        }

        public void path_removed(IQspnNodePath p)
        {
            if (qspn_handlers_disabled) return;
            per_identity_qspn_path_removed(this, p);
        }

        public void presence_notified()
        {
            if (qspn_handlers_disabled) return;
            per_identity_qspn_presence_notified(this);
        }

        public void qspn_bootstrap_complete()
        {
            if (qspn_handlers_disabled) return;
            per_identity_qspn_qspn_bootstrap_complete(this);
        }

        public void remove_identity()
        {
            if (qspn_handlers_disabled) return;
            per_identity_qspn_remove_identity(this);
        }
    }

    class IdentityArc : Object
    {
        public IIdmgmtArc arc;
        public NodeID id;
        public IIdmgmtIdentityArc id_arc;
        public weak IdentityData identity_data;
        public string peer_mac;
        public string peer_linklocal;

        public QspnArc? qspn_arc;
        public string? tablename;
        public int? tid;
        public bool? rule_added;
        public string? prev_peer_mac;
        public string? prev_peer_linklocal;
        public string? prev_tablename;
        public int? prev_tid;
        public bool? prev_rule_added;

        public IdentityArc(IdentityData identity_data, IIdmgmtArc arc, IIdmgmtIdentityArc id_arc)
        {
            this.identity_data = identity_data;
            this.arc = arc;
            id = identity_data.nodeid;
            this.id_arc = id_arc;
            peer_mac = id_arc.get_peer_mac();
            peer_linklocal = id_arc.get_peer_linklocal();

            qspn_arc = null;
            tablename = null;
            tid = null;
            rule_added = null;
            prev_peer_mac = null;
            prev_peer_linklocal = null;
            prev_tablename = null;
            prev_tid = null;
            prev_rule_added = null;
        }
    }

    class LocalIPSet : Object
    {
        public string global;
        public string anonymous;
        public HashMap<int,string> intern;
    }

    LocalIPSet init_local_ip_set()
    {
        LocalIPSet local_ip_set = new LocalIPSet();
        local_ip_set.global = "";
        local_ip_set.anonymous = "";
        local_ip_set.intern = new HashMap<int,string>();
        for (int j = 1; j < levels; j++) local_ip_set.intern[j] = "";
        return local_ip_set;
    }

    LocalIPSet copy_local_ip_set(LocalIPSet orig)
    {
        LocalIPSet ret = new LocalIPSet();
        ret.global = orig.global;
        ret.anonymous = orig.anonymous;
        ret.intern = new HashMap<int,string>();
        for (int k = 1; k < levels; k++)
            ret.intern[k] = orig.intern[k];
        return ret;
    }

    void compute_local_ip_set(LocalIPSet local_ip_set, Naddr my_naddr)
    {
        if (my_naddr.is_real_from_to(0, levels-1))
        {
            local_ip_set.global = ip_global_node(my_naddr.pos);
            local_ip_set.anonymous = ip_anonymizing_node(my_naddr.pos);
        }
        else
        {
            local_ip_set.global = "";
            local_ip_set.anonymous = "";
        }
        for (int i = levels-1; i >= 1; i--)
        {
            if (my_naddr.is_real_from_to(0, i-1))
                local_ip_set.intern[i] = ip_internal_node(my_naddr.pos, i);
            else
                local_ip_set.intern[i] = "";
        }
    }

    class DestinationIPSet : Object
    {
        public string global;
        public string anonymous;
        public HashMap<int,string> intern;
    }

    HashMap<int,HashMap<int,DestinationIPSet>> init_destination_ip_set()
    {
        HashMap<int,HashMap<int,DestinationIPSet>> ret;
        ret = new HashMap<int,HashMap<int,DestinationIPSet>>();
        for (int i = subnetlevel; i < levels; i++)
        {
            ret[i] = new HashMap<int,DestinationIPSet>();
            for (int j = 0; j < gsizes[i]; j++)
            {
                ret[i][j] = new DestinationIPSet();
                ret[i][j].global = "";
                ret[i][j].anonymous = "";
                ret[i][j].intern = new HashMap<int,string>();
                for (int k = i + 1; k < levels; k++) ret[i][j].intern[k] = "";
            }
        }
        return ret;
    }

    HashMap<int,HashMap<int,DestinationIPSet>> copy_destination_ip_set(HashMap<int,HashMap<int,DestinationIPSet>> orig)
    {
        HashMap<int,HashMap<int,DestinationIPSet>> ret;
        ret = new HashMap<int,HashMap<int,DestinationIPSet>>();
        for (int i = subnetlevel; i < levels; i++)
        {
            ret[i] = new HashMap<int,DestinationIPSet>();
            for (int j = 0; j < gsizes[i]; j++)
            {
                ret[i][j] = new DestinationIPSet();
                ret[i][j].global = orig[i][j].global;
                ret[i][j].anonymous = orig[i][j].anonymous;
                ret[i][j].intern = new HashMap<int,string>();
                for (int k = i + 1; k < levels; k++)
                    ret[i][j].intern[k] = orig[i][j].intern[k];
            }
        }
        return ret;
    }

    void compute_destination_ip_set(HashMap<int,HashMap<int,DestinationIPSet>> destination_ip_set, Naddr my_naddr)
    {
        for (int i = subnetlevel; i < levels; i++)
         for (int j = 0; j < gsizes[i]; j++)
        {
            ArrayList<int> naddr = new ArrayList<int>();
            naddr.add_all(my_naddr.pos);
            naddr[i] = j;
            if (my_naddr.is_real_from_to(i+1, levels-1) && my_naddr.pos[i] != j)
            {
                destination_ip_set[i][j].global = ip_global_gnode(naddr, i);
                destination_ip_set[i][j].anonymous = ip_anonymizing_gnode(naddr, i);
            }
            else
            {
                destination_ip_set[i][j].global = "";
                destination_ip_set[i][j].anonymous = "";
            }
            for (int k = i + 1; k < levels; k++)
            {
                if (my_naddr.is_real_from_to(i+1, k-1) && my_naddr.pos[i] != j)
                {
                    destination_ip_set[i][j].intern[k] = ip_internal_gnode(naddr, i, k);
                }
                else
                {
                    destination_ip_set[i][j].intern[k] = "";
                }
            }
        }
    }
}

