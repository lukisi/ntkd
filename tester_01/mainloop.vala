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
            // This produced some signal `identity_arc_added`: hence some IdentityArc instances have been created
            //  and stored in `second_identity_data.my_identityarcs`.
            IdentityData second_identity_data = find_or_create_local_identity(second_nodeid);

            tasklet.ms_wait(8000);
            identity_mgr.remove_identity(first_identity_data.nodeid);
            local_identities.remove(first_identity_data);

            tasklet.ms_wait(5000);
            identity_mgr.prepare_add_identity(3, second_identity_data.nodeid);
            tasklet.ms_wait(1000);
            NodeID third_nodeid = identity_mgr.add_identity(3, second_identity_data.nodeid);
            // This produced some signal `identity_arc_added`: hence some IdentityArc instances have been created
            //  and stored in `third_identity_data.my_identityarcs`.
            IdentityData third_identity_data = find_or_create_local_identity(third_nodeid);

            return null;
        }
    }
}
