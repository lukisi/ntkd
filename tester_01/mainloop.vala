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
    void mainloop()
    {
        // register handlers for SIGINT and SIGTERM to exit
        Posix.@signal(Posix.SIGINT, safe_exit);
        Posix.@signal(Posix.SIGTERM, safe_exit);

        Tester01Tasklet ts = new Tester01Tasklet();
        tasklet.spawn(ts);

        // Main loop
        while (true)
        {
            tasklet.ms_wait(100);
            if (do_me_exit) break;
        }
    }

    class Tester01Tasklet : Object, ITaskletSpawnable
    {
        public void * func()
        {
            tasklet.ms_wait(1000);
            assert(local_identities.size == 1);
            IdentityData first_identity_data = local_identities[0];
            assert(first_identity_data.main_id);

            tasklet.ms_wait(1000);
            identity_mgr.prepare_add_identity(1, first_identity_data.nodeid);
            tasklet.ms_wait(0);
            NodeID second_nodeid = identity_mgr.add_identity(1, first_identity_data.nodeid);
            IdentityData second_identity_data = find_or_create_local_identity(second_nodeid);

            second_identity_data.addr_man = new AddressManagerForIdentity();
            ArrayList<int> naddr = new ArrayList<int>.wrap({0,0,0,0});
            Naddr my_naddr = new Naddr(naddr.to_array(), gsizes.to_array());
            ArrayList<int> elderships = new ArrayList<int>.wrap({0,0,0,0});
            Fingerprint my_fp = new Fingerprint(elderships.to_array());
            second_identity_data.my_naddr = my_naddr;
            second_identity_data.my_fp = my_fp;

            // TODO iproute commands for startup second identity

            QspnManager qspn_mgr = new QspnManager.create_net(
                my_naddr,
                my_fp,
                new QspnStubFactory(second_identity_data));
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

            tasklet.ms_wait(5000);
            // an id-arc has been added to second_id with peer_id 992832884 and it needs an qspn_arc.
            assert(second_identity_data.identity_arcs.size == 2);
            bool found = false;
            IdentityArc? id_arc = null;
            foreach (IdentityArc w0 in second_identity_data.identity_arcs)
            {
                if (w0.id_arc.get_peer_nodeid().id == 992832884)
                {
                    assert(!found);
                    found = true;
                    id_arc = w0;
                }
            }
            assert(found);
            {
                qspn_mgr = (QspnManager)identity_mgr.get_identity_module(second_identity_data.nodeid, "qspn");

                NodeID destid = id_arc.id_arc.get_peer_nodeid();
                NodeID sourceid = id_arc.id; // == new_id
                id_arc.qspn_arc = new QspnArc(sourceid, destid, id_arc, id_arc.peer_mac);
                // tn.get_table(null, id_arc.peer_mac, out id_arc.tid, out id_arc.tablename);
                // id_arc.rule_added = false;
                qspn_mgr.arc_add(id_arc.qspn_arc);

                qspn_mgr = null;
            }

            tasklet.ms_wait(3000);
            identity_mgr.remove_identity(first_identity_data.nodeid);
            local_identities.remove(first_identity_data);

/*
            tasklet.ms_wait(5000);
            identity_mgr.prepare_add_identity(3, second_identity_data.nodeid);
            tasklet.ms_wait(1000);
            NodeID third_nodeid = identity_mgr.add_identity(3, second_identity_data.nodeid);
            IdentityData third_identity_data = find_or_create_local_identity(third_nodeid);

            third_identity_data.addr_man = new AddressManagerForIdentity();
            naddr = new ArrayList<int>.wrap({0,1,0,0});
            my_naddr = new Naddr(naddr.to_array(), gsizes.to_array());
            ArrayList<int> elderships = new ArrayList<int>.wrap({0,1,0,0});
            my_fp = new Fingerprint(elderships.to_array());
            third_identity_data.my_naddr = my_naddr;
            third_identity_data.my_fp = my_fp;

            // TODO iproute commands for startup third identity

            qspn_mgr = new QspnManager.enter_net(
                my_naddr,
                my_fp,
                new QspnStubFactory(third_identity_data));

            public QspnManager.enter_net(
                           Gee.List<IQspnArc> internal_arc_set,
                           Gee.List<IQspnArc> internal_arc_prev_arc_set,
                           Gee.List<IQspnNaddr> internal_arc_peer_naddr_set,
                           Gee.List<IQspnArc> external_arc_set,
                           IQspnMyNaddr my_naddr,
                           IQspnFingerprint my_fingerprint,
                           ChangeFingerprintDelegate update_internal_fingerprints,
                           IQspnStubFactory stub_factory,
                           int hooking_gnode_level,
                           int into_gnode_level,
                           QspnManager previous_identity
                           )

            // soon after creation, connect to signals.
            qspn_mgr.arc_removed.connect(third_identity_data.arc_removed);
            qspn_mgr.changed_fp.connect(third_identity_data.changed_fp);
            qspn_mgr.changed_nodes_inside.connect(third_identity_data.changed_nodes_inside);
            qspn_mgr.destination_added.connect(third_identity_data.destination_added);
            qspn_mgr.destination_removed.connect(third_identity_data.destination_removed);
            qspn_mgr.gnode_splitted.connect(third_identity_data.gnode_splitted);
            qspn_mgr.path_added.connect(third_identity_data.path_added);
            qspn_mgr.path_changed.connect(third_identity_data.path_changed);
            qspn_mgr.path_removed.connect(third_identity_data.path_removed);
            qspn_mgr.presence_notified.connect(third_identity_data.presence_notified);
            qspn_mgr.qspn_bootstrap_complete.connect(third_identity_data.qspn_bootstrap_complete);
            qspn_mgr.remove_identity.connect(third_identity_data.remove_identity);

            identity_mgr.set_identity_module(third_nodeid, "qspn", qspn_mgr);
            third_identity_data.addr_man.qspn_mgr = qspn_mgr;  // weak ref
            qspn_mgr = null;
*/

            return null;
        }
    }
}
