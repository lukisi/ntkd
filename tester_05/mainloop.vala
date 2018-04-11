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

        Tester05Tasklet ts = new Tester05Tasklet();
        tasklet.spawn(ts);

        // Main loop
        while (true)
        {
            tasklet.ms_wait(100);
            if (do_me_exit) break;
        }
    }

    class Tester05Tasklet : Object, ITaskletSpawnable
    {
        public void * func()
        {
            tasklet.ms_wait(2000);
            print("tester05: test begins\n");
            print("What is my id and my network? Change with YYYYYYY and GGGGGGGGG.\n");
            // first_identity_data: my id YYYYYYY is in network_id GGGGGGGGG.
            assert(local_identities.size == 1);
            IdentityData first_identity_data = local_identities[0];
            assert(first_identity_data.main_id);

            // Some identity arcs have been passed to the module Hooking:
            // * there is one with 87104682 on network 792653743.
            HookingIdentityArc arc_01 = null;
            foreach (var _idarc in first_identity_data.hook_mgr.arc_list)
            {
                HookingIdentityArc __idarc = (HookingIdentityArc)_idarc;
                IdentityArc ia = __idarc.ia;
                if (ia.id_arc.get_peer_nodeid().id == 87104682) arc_01 = __idarc;
            }
            assert(arc_01 != null);

            // Simulation: Hooking informs us that this id_arc's peer is of a certain network.
            print("Simulation: Peer 87104682 on network 792653743.\n");
            first_identity_data.hook_mgr.another_network(arc_01, 792653743);

            // Simulation: Hooking does not tell us to enter

            tasklet.ms_wait(3000);

            // Some more identity arcs have been passed to the module Hooking:
            // * there is one with 1267178494 on network 1354430125.
            HookingIdentityArc arc_03 = null;
            foreach (var _idarc in first_identity_data.hook_mgr.arc_list)
            {
                HookingIdentityArc __idarc = (HookingIdentityArc)_idarc;
                IdentityArc ia = __idarc.ia;
                if (ia.id_arc.get_peer_nodeid().id == 1267178494) arc_03 = __idarc;
            }
            assert(arc_03 != null);

            // Simulation: Hooking informs us that this id_arc's peer is of a certain network.
            print("Simulation: Peer 1267178494 on network 1354430125.\n");
            first_identity_data.hook_mgr.another_network(arc_03, 1354430125);

            // Simulation: Hooking does not tell us to enter

            tasklet.ms_wait(3000);

            print("What is the new id of server01? Change with ZZZZZZZ.\n");
/*
            // Some more identity arcs have been passed to the module Hooking:
            // * there is one with ZZZZZZZ on network GGGGGGGGG.
            HookingIdentityArc arc_04 = null;
            foreach (var _idarc in first_identity_data.hook_mgr.arc_list)
            {
                HookingIdentityArc __idarc = (HookingIdentityArc)_idarc;
                IdentityArc ia = __idarc.ia;
                if (ia.id_arc.get_peer_nodeid().id == ZZZZZZZ) arc_04 = __idarc;
            }
            assert(arc_04 != null);

            // Simulation: Hooking informs us that this id_arc's peer is of our same network.
            print("Simulation: Peer ZZZZZZZ on network GGGGGGGGG.\n");
            first_identity_data.hook_mgr.same_network(arc_04);
*/

            // TODO continue

            return null;















        }
    }
}
