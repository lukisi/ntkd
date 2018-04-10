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
            tasklet.ms_wait(2000);
            print("tester02: test begins\n");
            // first_identity_data: my id 1596432545 is in network_id 1354430125.
            assert(local_identities.size == 1);
            IdentityData first_identity_data = local_identities[0];
            assert(first_identity_data.main_id);

            // Some identity arcs have been passed to the module Hooking:
            // * there is one with 87104682 on network 792653743.
            HookingIdentityArc arc_01 = null;
            // * there is one with 846793969 on network 423365822.
            HookingIdentityArc arc_02 = null;
            foreach (var _idarc in first_identity_data.hook_mgr.arc_list)
            {
                HookingIdentityArc __idarc = (HookingIdentityArc)_idarc;
                IdentityArc ia = __idarc.ia;
                if (ia.id_arc.get_peer_nodeid().id == 87104682) arc_01 = __idarc;
                if (ia.id_arc.get_peer_nodeid().id == 846793969) arc_02 = __idarc;
            }
            assert(arc_01 != null);
            assert(arc_02 != null);

            // Simulation: Hooking informs us that this id_arc's peer is of a certain network.
            print("Simulation: Peer 87104682 on network 792653743.\n");
            first_identity_data.hook_mgr.another_network(arc_01, 792653743);

            // Simulation: Hooking informs us that this id_arc's peer is of a certain network.
            print("Simulation: Peer 846793969 on network 423365822.\n");
            first_identity_data.hook_mgr.another_network(arc_02, 423365822);

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

            // Simulation: Hooking informs us that this id_arc's peer is of our same network.
            print("Simulation: Peer 1267178494 on network 1354430125.\n");
            first_identity_data.hook_mgr.same_network(arc_03);

            tasklet.ms_wait(3000);

            // Some more identity arcs have been passed to the module Hooking:
            // * there is one with 399143400 on network 1354430125.
            HookingIdentityArc arc_04 = null;
            foreach (var _idarc in first_identity_data.hook_mgr.arc_list)
            {
                HookingIdentityArc __idarc = (HookingIdentityArc)_idarc;
                IdentityArc ia = __idarc.ia;
                if (ia.id_arc.get_peer_nodeid().id == 399143400) arc_04 = __idarc;
            }
            assert(arc_04 != null);

            // Simulation: Hooking informs us that this id_arc's peer is of our same network.
            print("Simulation: Peer 399143400 on network 1354430125.\n");
            first_identity_data.hook_mgr.same_network(arc_04);

            // TODO continue

            return null;















        }
    }
}
