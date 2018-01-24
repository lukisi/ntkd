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
            // first_identity_data nodeid 948911663 is in network_id 348371222.
            assert(local_identities.size == 1);
            IdentityData first_identity_data = local_identities[0];
            assert(first_identity_data.main_id);

            // Simulation: Hooking informs us that this id_arc's peer is of a certain network.
            print("Simulation: Peer 1239482480 is on 380228860.\n");
            foreach (IdentityArc w0 in first_identity_data.identity_arcs)
                if (w0.id_arc.get_peer_nodeid().id == 1239482480)
            {
                print("Peer 1239482480 found.\n");
                w0.network_id = 380228860;
            }

            // Simulation: Hooking does not tell us to enter

            tasklet.ms_wait(3000);

            // Simulation: Hooking informs us that this id_arc's peer is of our same network.
            print("Simulation: Peer 1595149094 is on 348371222.\n");
            foreach (IdentityArc w0 in first_identity_data.identity_arcs)
                if (w0.id_arc.get_peer_nodeid().id == 1595149094)
            {
                print("Peer 1595149094 found.\n");
                w0.network_id = 348371222;
                UpdateGraph.add_arc(w0); // this will set w0.qspn_arc
            }

            return null;
        }
    }
}
