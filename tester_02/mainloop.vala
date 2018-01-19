/*
 *  This file is part of Netsukuku.
 *  Copyright (C) 2017-2018 Luca Dionisi aka lukisi <luca.dionisi@gmail.com>
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
    void mainloop()
    {
        // register handlers for SIGINT and SIGTERM to exit
        Posix.@signal(Posix.SIGINT, safe_exit);
        Posix.@signal(Posix.SIGTERM, safe_exit);

        Tester02Tasklet ts = new Tester02Tasklet();
        tasklet.spawn(ts);

        // Main loop
        while (true)
        {
            tasklet.ms_wait(100);
            if (do_me_exit) break;
        }
    }

    class Tester02Tasklet : Object, ITaskletSpawnable
    {
        public void * func()
        {
            tasklet.ms_wait(1000);
            // first_identity_data nodeid 948911663 is in network_id 348371222.
            assert(local_identities.size == 1);
            IdentityData first_identity_data = local_identities[0];
            assert(first_identity_data.main_id);

            // Simulation: Hooking informs us that this id_arc's peer is of a certain network.
            foreach (IdentityArc w0 in first_identity_data.identity_arcs)
                if (w0.id_arc.get_peer_nodeid().id == 1239482480)
                w0.network_id = 380228860;

            // Simulation: Hooking does not tell us to enter

            tasklet.ms_wait(5000);

            // Simulation: Hooking informs us that this id_arc's peer is of our same network.
            foreach (IdentityArc w0 in first_identity_data.identity_arcs)
                if (w0.id_arc.get_peer_nodeid().id == 948911663)
            {
                w0.network_id = 348371222;
                NodeID destid = w0.id_arc.get_peer_nodeid();
                NodeID sourceid = w0.id; // == first_identity_data.nodeid
                w0.qspn_arc = new QspnArc(sourceid, destid, w0, w0.peer_mac);

                QspnManager my_qspn = (QspnManager)identity_mgr.get_identity_module(first_identity_data.nodeid, "qspn");
                my_qspn.arc_add(w0.qspn_arc);
            }

            if (true) return null;

            tasklet.ms_wait(5000);
            identity_mgr.prepare_add_identity(2, first_identity_data.nodeid);
            tasklet.ms_wait(0);
            NodeID second_nodeid = identity_mgr.add_identity(2, first_identity_data.nodeid);
            // When this call returns, a bunch of signals `identity_arc_added` has been (possibly) emitted and handled.
            // Thus, we have a new instance of IdentityData with a list of new instances of IdentityArc.
            // In this case, one of those, the one with peer_nodeid=1595149094,
            // is in same network, so we have to add a qspn_arc.
            // Also, in this case our neighbor does not participate to the same migration. Thus there won't be any
            // signal `identity_arc_changed`. In general, if an old id-arc has been changed then we would have
            // its properties `prev_peer_*` set.
            IdentityData second_identity_data = find_or_create_local_identity(second_nodeid);

            second_identity_data.addr_man = new AddressManagerForIdentity();
            ArrayList<int> naddr = new ArrayList<int>.wrap({1,0,0,0});
            Naddr my_naddr = new Naddr(naddr.to_array(), gsizes.to_array());
            ArrayList<int> elderships = new ArrayList<int>.wrap({1,0,0,0});
            Fingerprint my_fp = new Fingerprint(elderships.to_array());
            second_identity_data.my_naddr = my_naddr;
            second_identity_data.my_fp = my_fp;
            ArrayList<int> in_same_network_with_second_identity = new ArrayList<int>.wrap({1595149094});

            {
                IdentityData old_identity_data = first_identity_data;
                IdentityData new_identity_data = second_identity_data;
                ArrayList<int> new_qspn_arc_for_peer_id_list = in_same_network_with_second_identity;
                int guest_gnode_level = 0;
                int host_gnode_level = 1;
                // NodeID new_id = second_nodeid;
                NodeID old_id = old_identity_data.nodeid;
                QspnManager old_id_qspn_mgr = (QspnManager)(identity_mgr.get_identity_module(old_id, "qspn"));
                Naddr old_identity_prev_naddr = old_identity_data.my_naddr;
                Fingerprint old_identity_prev_fp = old_identity_data.my_fp;
                new_identity_data.copy_of_identity = old_identity_data;
                new_identity_data.connectivity_from_level = old_identity_data.connectivity_from_level;
                new_identity_data.connectivity_to_level = old_identity_data.connectivity_to_level;

                old_identity_data.connectivity_from_level = guest_gnode_level + 1;
                old_identity_data.connectivity_to_level = levels; // after enter, the old id will be dismissed soon anyway.

                HashMap<IdentityArc, IdentityArc> old_to_new_id_arc = new HashMap<IdentityArc, IdentityArc>();
                foreach (IdentityArc w0 in old_identity_data.identity_arcs)
                {
                    bool old_identity_arc_changed_peer_mac = (w0.prev_peer_mac != null);
                    // find appropriate w1
                    foreach (IdentityArc w1 in new_identity_data.identity_arcs)
                    {
                        if (w1.arc != w0.arc) continue;
                        if (old_identity_arc_changed_peer_mac)
                        {
                            if (w1.peer_mac != w0.prev_peer_mac) continue;
                        }
                        else
                        {
                            if (w1.peer_mac != w0.peer_mac) continue;
                        }
                        old_to_new_id_arc[w0] = w1;
                        break;
                    }
                }

                string old_ns = new_identity_data.network_namespace;
                string new_ns = old_identity_data.network_namespace;

                // Prepare update_copied_internal_fingerprints
                ChangeFingerprintDelegate update_copied_internal_fingerprints = (_f) => {
                    Fingerprint f = (Fingerprint)_f;
                    for (int l = guest_gnode_level; l < levels; l++)
                        f.elderships[l] = new_identity_data.my_fp.elderships[l];
                    return f;
                    // Returning the same instance is ok, because the delegate is alway
                    // called like "x = update_internal_fingerprints(x)"
                };

                // Prepare internal arcs
                ArrayList<IQspnArc> internal_arc_set = new ArrayList<IQspnArc>();
                ArrayList<IQspnNaddr> internal_arc_peer_naddr_set = new ArrayList<IQspnNaddr>();
                ArrayList<IQspnArc> internal_arc_prev_arc_set = new ArrayList<IQspnArc>();
                foreach (IdentityArc w0 in old_identity_data.identity_arcs)
                {
                    bool old_identity_arc_is_internal = (w0.prev_peer_mac != null);
                    if (old_identity_arc_is_internal)
                    {
                        // It is an internal arc
                        IdentityArc w1 = old_to_new_id_arc[w0]; // w1 is already in new_identity_data.my_identityarcs
                        NodeID destid = w1.id_arc.get_peer_nodeid();
                        NodeID sourceid = w1.id; // == new_id
                        w1.qspn_arc = new QspnArc(sourceid, destid, w1, w1.peer_mac);
                        // tn.get_table(null, w1.peer_mac, out w1.tid, out w1.tablename);
                        // w1.rule_added = w0.prev_rule_added;

                        assert(w0.qspn_arc != null);
                        IQspnNaddr? _w0_peer_naddr = old_id_qspn_mgr.get_naddr_for_arc(w0.qspn_arc);
                        assert(_w0_peer_naddr != null);
                        Naddr w0_peer_naddr = (Naddr)_w0_peer_naddr;
                        ArrayList<int> _w1_peer_naddr = new ArrayList<int>();
                        _w1_peer_naddr.add_all(w0_peer_naddr.pos.slice(0, host_gnode_level-1));
                        _w1_peer_naddr.add_all(new_identity_data.my_naddr.pos.slice(host_gnode_level-1, levels));
                        Naddr w1_peer_naddr = new Naddr(_w1_peer_naddr.to_array(), gsizes.to_array());

                        // Now add: the 3 ArrayList should have same size at the end.
                        internal_arc_set.add(w1.qspn_arc);
                        internal_arc_peer_naddr_set.add(w1_peer_naddr);
                        internal_arc_prev_arc_set.add(w0.qspn_arc);
                    }
                }

                // Prepare external arcs
                ArrayList<IQspnArc> external_arc_set = new ArrayList<IQspnArc>();
                foreach (IdentityArc w0 in old_identity_data.identity_arcs)
                  if (w0.id_arc.get_peer_nodeid().id in new_qspn_arc_for_peer_id_list)
                {
                    IdentityArc w1 = old_to_new_id_arc[w0]; // w1 is already in new_identity_data.my_identityarcs
                    NodeID destid = w1.id_arc.get_peer_nodeid();
                    NodeID sourceid = w1.id; // == new_id
                    w1.qspn_arc = new QspnArc(sourceid, destid, w1, w1.peer_mac);
                    // tn.get_table(null, w1.peer_mac, out w1.tid, out w1.tablename);
                    // w1.rule_added = false;

                    external_arc_set.add(w1.qspn_arc);
                }

                // TODO iproute commands for startup second identity

                QspnManager qspn_mgr = new QspnManager.enter_net(
                    internal_arc_set,
                    internal_arc_prev_arc_set,
                    internal_arc_peer_naddr_set,
                    external_arc_set,
                    new_identity_data.my_naddr,
                    new_identity_data.my_fp,
                    update_copied_internal_fingerprints,
                    new QspnStubFactory(new_identity_data),
                    /*hooking_gnode_level*/ 0,
                    /*into_gnode_level*/ 1,
                    /*previous_identity*/ old_id_qspn_mgr);
                // soon after creation, connect to signals.
                qspn_mgr.arc_removed.connect(second_identity_data.arc_removed);
                qspn_mgr.changed_fp.connect(second_identity_data.changed_fp);
                qspn_mgr.changed_nodes_inside.connect(second_identity_data.changed_nodes_inside);
                qspn_mgr.destination_added.connect(second_identity_data.destination_added);
                qspn_mgr.destination_removed.connect(second_identity_data.destination_removed);
                qspn_mgr.gnode_splitted.connect(second_identity_data.gnode_splitted);
                qspn_mgr.path_added.connect(second_identity_data.path_added);
                qspn_mgr.path_changed.connect(second_identity_data.path_changed);
                qspn_mgr.path_removed.connect(second_identity_data.path_removed);
                qspn_mgr.presence_notified.connect(second_identity_data.presence_notified);
                qspn_mgr.qspn_bootstrap_complete.connect(second_identity_data.qspn_bootstrap_complete);
                qspn_mgr.remove_identity.connect(second_identity_data.remove_identity);

                identity_mgr.set_identity_module(second_nodeid, "qspn", qspn_mgr);
                second_identity_data.addr_man.qspn_mgr = qspn_mgr;  // weak ref
                qspn_mgr = null;

                foreach (IdentityArc ia in old_identity_data.identity_arcs)
                {
                    ia.prev_peer_mac = null;
                    ia.prev_peer_linklocal = null;
                    ia.prev_tablename = null;
                    ia.prev_tid = null;
                    ia.prev_rule_added = null;
                }
            }

            tasklet.ms_wait(5000);
            identity_mgr.remove_identity(first_identity_data.nodeid);
            local_identities.remove(first_identity_data);

/*
            tasklet.ms_wait(4000);
            identity_mgr.prepare_add_identity(3, second_identity_data.nodeid);
            tasklet.ms_wait(1000);
            NodeID third_nodeid = identity_mgr.add_identity(3, second_identity_data.nodeid);
            // This produced some signal `identity_arc_added`: hence some IdentityArc instances have been created
            //  and stored in `third_identity_data.my_identityarcs`.
            IdentityData third_identity_data = find_or_create_local_identity(third_nodeid);
*/

            return null;
        }
    }
}
