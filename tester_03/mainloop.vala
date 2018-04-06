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

        Tester03Tasklet ts = new Tester03Tasklet();
        tasklet.spawn(ts);

        // Main loop
        while (true)
        {
            tasklet.ms_wait(100);
            if (do_me_exit) break;
        }
    }

    class Tester03Tasklet : Object, ITaskletSpawnable
    {
        public void * func()
        {
            tasklet.ms_wait(2000);
            print("tester03: test begins\n");
            // first_identity_data: my id 846793969 is in network_id 423365822.
            assert(local_identities.size == 1);
            IdentityData first_identity_data = local_identities[0];
            assert(first_identity_data.main_id);

            // Some identity arcs have been passed to the module Hooking:
            // * there is one with 1596432545 on network 1609842343.
            HookingIdentityArc arc_01 = null;
            foreach (var _idarc in first_identity_data.hook_mgr.arc_list)
            {
                HookingIdentityArc __idarc = (HookingIdentityArc)_idarc;
                IdentityArc ia = __idarc.ia;
                if (ia.id_arc.get_peer_nodeid().id == 1596432545) arc_01 = __idarc;
            }
            assert(arc_01 != null);

            // Simulation: Hooking informs us that this id_arc's peer is of a certain network.
            print("Simulation: Peer 1596432545 on network 1609842343.\n");
            first_identity_data.hook_mgr.another_network(arc_01, 1609842343);

            tasklet.ms_wait(4000);
            // Simulation: Hooking says we must enter in network_id = 1609842343
            int64 enter_into_network_id = 1609842343;
            int guest_gnode_level = 1;
            int go_connectivity_position = PRNGen.int_range(gsizes[guest_gnode_level], int32.MAX); // not important on entering another network.
            ArrayList<int> new_gnode_positions = new ArrayList<int>.wrap({1, 0, 0});
            ArrayList<int> new_gnode_elderships = new ArrayList<int>.wrap({1, 0, 0});
            int enter_id = 2;

            first_identity_data.hook_mgr.do_prepare_enter(enter_id);
            tasklet.ms_wait(0);
            EntryData entry_data = new EntryData();
            entry_data.network_id = enter_into_network_id;
            entry_data.pos = new_gnode_positions;
            entry_data.elderships = new_gnode_elderships;
            first_identity_data.hook_mgr.do_finish_enter(enter_id, guest_gnode_level, entry_data, go_connectivity_position);

            // first identity should already have been removed
            assert(local_identities.size == 1);
            IdentityData second_identity_data = local_identities[0];

            // second_identity_data nodeid ZZZZZZZ should be in about 2 more seconds bootstrapped in network_id 1609842343. See tester02/mainloop.vala
            
/*
Simulation: Il core03 846793969 hooking segnala:
 prepare_enter enter_id=2.
 Wait 0.
 enter enter_id=2 with guest_gnode_level = 1 in network_id = 1609842343
       with pos {1, 0, 0} eldership {1, 0, 0}
       nuovo id ZZZZZZZ on network 1609842343
*/
            // TODO continue

            return null;














        }
    }
}
