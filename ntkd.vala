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

        configuration(ref args, out naddr, out devs);

        startup(ref naddr, ref devs);

        mainloop();

        cleanup();

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
            local_ip_set = null;
            dest_ip_set = null;
        }

        public NodeID nodeid;
        public Naddr my_naddr;
        public Fingerprint my_fp;
        public int connectivity_from_level;
        public int connectivity_to_level;
        public IdentityData? copy_of_identity;
        public AddressManagerForIdentity addr_man;

        public ArrayList<IdentityArc> identity_arcs;

        public LocalIPSet? local_ip_set;
        public DestinationIPSet? dest_ip_set;

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
        public int64? network_id;
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
            network_id = null;
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

    class IdentityArcPair : Object
    {
        public IdentityArcPair(IdentityArc old_id_arc, IdentityArc new_id_arc)
        {
            this.old_id_arc = old_id_arc;
            this.new_id_arc = new_id_arc;
        }
        public IdentityArc old_id_arc {get; private set;}
        public IdentityArc new_id_arc {get; private set;}
    }

    class LocalIPSet : Object
    {
        public string global;
        public string anonymizing;
        public HashMap<int,string> intern;
        public string anonymizing_range;
        public string netmap_range1;
        public HashMap<int,string> netmap_range2;
        public HashMap<int,string> netmap_range3;
        public string netmap_range2_upper;
        public string netmap_range3_upper;
        public string netmap_range4;

        public LocalIPSet()
        {
            intern = new HashMap<int,string>();
            netmap_range2 = new HashMap<int,string>();
            netmap_range3 = new HashMap<int,string>();
        }

        public LocalIPSet copy()
        {
            LocalIPSet ret = new LocalIPSet();
            ret.global = this.global;
            ret.anonymizing = this.anonymizing;
            foreach (int k in this.intern.keys) ret.intern[k] = this.intern[k];
            ret.anonymizing_range = this.anonymizing_range;
            ret.netmap_range1 = this.netmap_range1;
            foreach (int k in this.netmap_range2.keys) ret.netmap_range2[k] = this.netmap_range2[k];
            foreach (int k in this.netmap_range3.keys) ret.netmap_range3[k] = this.netmap_range3[k];
            ret.netmap_range2_upper = this.netmap_range2_upper;
            ret.netmap_range3_upper = this.netmap_range3_upper;
            ret.netmap_range4 = this.netmap_range4;
            return ret;
        }
    }

    class DestinationIPSetGnode : Object
    {
        public string global;
        public string anonymizing;
        public HashMap<int,string> intern;

        public DestinationIPSetGnode()
        {
            intern = new HashMap<int,string>();
        }

        public DestinationIPSetGnode copy()
        {
            DestinationIPSetGnode ret = new DestinationIPSetGnode();
            ret.global = this.global;
            ret.anonymizing = this.anonymizing;
            foreach (int k in this.intern.keys) ret.intern[k] = this.intern[k];
            return ret;
        }
    }

    class DestinationIPSet : Object
    {
        public HashMap<HCoord,DestinationIPSetGnode> gnode;

        public DestinationIPSet()
        {
            gnode = new HashMap<HCoord,DestinationIPSetGnode>(null, (a, b) => a.equals(b));
        }

        private Gee.List<HCoord> _sorted_gnode_keys;
        public Gee.List<HCoord> sorted_gnode_keys
        {
            get {
                ArrayList<HCoord> ret = new ArrayList<HCoord>();
                ret.add_all(gnode.keys);
                ret.sort((a, b) => {
                    if (a.lvl > b.lvl) return -1;
                    if (a.lvl < b.lvl) return 1;
                    return a.pos - b.pos;
                });
                _sorted_gnode_keys = ret;
                return _sorted_gnode_keys;
            }
        }

        public DestinationIPSet copy()
        {
            DestinationIPSet ret = new DestinationIPSet();
            foreach (HCoord hc in gnode.keys)
            {
                ret.gnode[hc] = gnode[hc].copy();
            }
            return ret;
        }
    }
}

