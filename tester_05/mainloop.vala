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

        Tasklet01 ts01 = new Tasklet01();
        tasklet.spawn(ts01);
        Tasklet02pre ts02pre = new Tasklet02pre();
        tasklet.spawn(ts02pre);
        Tasklet02 ts02 = new Tasklet02();
        tasklet.spawn(ts02);
        Tasklet03 ts03 = new Tasklet03();
        tasklet.spawn(ts03);
        Tasklet0301 ts0301 = new Tasklet0301();
        tasklet.spawn(ts0301);
        Tasklet04pre ts04pre = new Tasklet04pre();
        tasklet.spawn(ts04pre);
        Tasklet04 ts04 = new Tasklet04();
        tasklet.spawn(ts04);
        Tasklet05 ts05 = new Tasklet05();
        tasklet.spawn(ts05);
        Tasklet0501 ts0501 = new Tasklet0501();
        tasklet.spawn(ts0501);
        Tasklet06pre ts06pre = new Tasklet06pre();
        tasklet.spawn(ts06pre);
        Tasklet06 ts06 = new Tasklet06();
        tasklet.spawn(ts06);
        Tasklet07 ts07 = new Tasklet07();
        tasklet.spawn(ts07);
        Tasklet0701 ts0701 = new Tasklet0701();
        tasklet.spawn(ts0701);
        Tasklet08 ts08 = new Tasklet08();
        tasklet.spawn(ts08);
        Tasklet09 ts09 = new Tasklet09();
        tasklet.spawn(ts09);
        Tasklet10 ts10 = new Tasklet10();
        tasklet.spawn(ts10);
        Tasklet11 ts11 = new Tasklet11();
        tasklet.spawn(ts11);
        Tasklet12 ts12 = new Tasklet12();
        tasklet.spawn(ts12);
        Tasklet13 ts13 = new Tasklet13();
        tasklet.spawn(ts13);
        Tasklet14 ts14 = new Tasklet14();
        tasklet.spawn(ts14);
        Tasklet15 ts15 = new Tasklet15();
        tasklet.spawn(ts15);
        Tasklet16 ts16 = new Tasklet16();
        tasklet.spawn(ts16);
        Tasklet17 ts17 = new Tasklet17();
        tasklet.spawn(ts17);
        Tasklet18 ts18 = new Tasklet18();
        tasklet.spawn(ts18);
        Tasklet19 ts19 = new Tasklet19();
        tasklet.spawn(ts19);
        Tasklet20 ts20 = new Tasklet20();
        tasklet.spawn(ts20);

        // Main loop
        while (true)
        {
            tasklet.ms_wait(100);
            if (do_me_exit) break;
        }
    }

    IdentityData first_identity_data;

    class Tasklet01 : Object, ITaskletSpawnable
    {
        public void * func()
        {
            tasklet.ms_wait(TESTER_TIME_01);
            print("tester05: TIME_01\n");

            // first_identity_data: my id TESTER_SERVER05_ID01 is in network_id TESTER_SERVER05_NETWORK01.
            assert(local_identities.size == 1);
            first_identity_data = local_identities[0];
            assert(first_identity_data.main_id);

            // Some identity arcs have been passed to the module Hooking:
            // * there is one with TESTER_SERVER01_ID01 on network TESTER_SERVER01_NETWORK01.
            HookingIdentityArc arc_01 = null;
            foreach (IdentityArc ia in first_identity_data.identity_arcs)
            {
                if (ia.id_arc.get_peer_nodeid().id == TESTER_SERVER01_ID01) arc_01 = ia.hooking_arc;
            }
            assert(arc_01 != null);

            // Simulation: Hooking informs us that this id_arc's peer is of a certain network.
            print(@"Simulation: Peer $(TESTER_SERVER01_ID01) on network $(TESTER_SERVER01_NETWORK01).\n");
            first_identity_data.hook_mgr.another_network(arc_01, TESTER_SERVER01_NETWORK01);

            // Simulation: Hooking does not tell us to enter

            return null;
        }
    }

    class Tasklet02pre : Object, ITaskletSpawnable
    {
        public void * func()
        {
            tasklet.ms_wait(TESTER_TIME_02_PRE);
            print("tester05: TIME_02_PRE\n");

            // ...

            return null;
        }
    }

    class Tasklet02 : Object, ITaskletSpawnable
    {
        public void * func()
        {
            tasklet.ms_wait(TESTER_TIME_02);
            print("tester05: TIME_02\n");

            // ...

            return null;
        }
    }

    class Tasklet03 : Object, ITaskletSpawnable
    {
        public void * func()
        {
            tasklet.ms_wait(TESTER_TIME_03);
            print("tester05: TIME_03\n");

            // Some more identity arcs have been passed to the module Hooking:
            // * there is one with TESTER_SERVER01_ID02 on network TESTER_SERVER02_NETWORK01.
            HookingIdentityArc arc_03 = null;
            foreach (IdentityArc ia in first_identity_data.identity_arcs)
            {
                if (ia.id_arc.get_peer_nodeid().id == TESTER_SERVER01_ID02) arc_03 = ia.hooking_arc;
            }
            assert(arc_03 != null);

            // Simulation: Hooking informs us that this id_arc's peer is of a certain network.
            print(@"Simulation: Peer $(TESTER_SERVER01_ID02) on network $(TESTER_SERVER02_NETWORK01).\n");
            first_identity_data.hook_mgr.another_network(arc_03, TESTER_SERVER02_NETWORK01);

            // Simulation: Hooking does not tell us to enter

            return null;
        }
    }

    class Tasklet0301 : Object, ITaskletSpawnable
    {
        public void * func()
        {
            tasklet.ms_wait(TESTER_TIME_03_01);
            print("tester05: TIME_03_01\n");

            // ...

            return null;
        }
    }

    class Tasklet04pre : Object, ITaskletSpawnable
    {
        public void * func()
        {
            tasklet.ms_wait(TESTER_TIME_04_PRE);
            print("tester05: TIME_04_PRE\n");

            // ...

            return null;
        }
    }

    class Tasklet04 : Object, ITaskletSpawnable
    {
        public void * func()
        {
            tasklet.ms_wait(TESTER_TIME_04);
            print("tester05: TIME_04\n");

            // ...

            return null;
        }
    }

    class Tasklet05 : Object, ITaskletSpawnable
    {
        public void * func()
        {
            tasklet.ms_wait(TESTER_TIME_05);
            print("tester05: TIME_05\n");

            // ...

            return null;
        }
    }

    class Tasklet0501 : Object, ITaskletSpawnable
    {
        public void * func()
        {
            tasklet.ms_wait(TESTER_TIME_05_01);
            print("tester05: TIME_05_01\n");

            // ...

            return null;
        }
    }

    class Tasklet06pre : Object, ITaskletSpawnable
    {
        public void * func()
        {
            tasklet.ms_wait(TESTER_TIME_06_PRE);
            print("tester05: TIME_06_PRE\n");

            print(@"Simulation: Server $(TESTER_SERVER05_ID01) asks coordinator to reserve in lvl=3.\n");
            Reservation res = first_identity_data.coord_mgr.reserve(3 /*lvl*/, 789 /*id*/);
            print(@"Coordinator reserve pos $(res.new_pos) eldership $(res.new_eldership).\n");
            assert(res.new_pos == 1);
            assert(res.new_eldership == 1);

            return null;
        }
    }

    class Tasklet06 : Object, ITaskletSpawnable
    {
        public void * func()
        {
            tasklet.ms_wait(TESTER_TIME_06);
            print("tester05: TIME_06\n");

            // ...

            return null;
        }
    }

    class Tasklet07 : Object, ITaskletSpawnable
    {
        public void * func()
        {
            tasklet.ms_wait(TESTER_TIME_07);
            print("tester05: TIME_07\n");

            // Some more identity arcs have been passed to the module Hooking:
            // * there is one with TESTER_SERVER01_ID03 on network TESTER_SERVER05_NETWORK01.
            HookingIdentityArc arc_04 = null;
            foreach (IdentityArc ia in first_identity_data.identity_arcs)
            {
                if (ia.id_arc.get_peer_nodeid().id == TESTER_SERVER01_ID03) arc_04 = ia.hooking_arc;
            }
            assert(arc_04 != null);

            // Simulation: Hooking informs us that this id_arc's peer is of our same network.
            print(@"Simulation: Peer $(TESTER_SERVER01_ID03) on network $(TESTER_SERVER05_NETWORK01).\n");
            first_identity_data.hook_mgr.same_network(arc_04);

            return null;
        }
    }

    class Tasklet0701 : Object, ITaskletSpawnable
    {
        public void * func()
        {
            tasklet.ms_wait(TESTER_TIME_07_01);
            print("tester05: TIME_07_01\n");

            var should = true;
            var should2 = true;
            var should3 = true;
            while (true)
            {
                var ret = ping("10.0.0.62");
                if (ret != should)
                {
                    if (!ret) warning("Server05 is not able to ping 10.0.0.62\n");
                    else warning("Server05 is now again able to ping 10.0.0.62\n");
                    should = ret;
                }
                var ret2 = ping("10.0.0.63");
                if (ret2 != should2)
                {
                    if (!ret2) warning("Server05 is not able to ping 10.0.0.63\n");
                    else warning("Server05 is now again able to ping 10.0.0.63\n");
                    should2 = ret2;
                }
                var ret3 = ping("10.0.0.7");
                if (ret3 != should3)
                {
                    if (!ret3) warning("Server05 is not able to ping 10.0.0.7\n");
                    else warning("Server05 is now again able to ping 10.0.0.7\n");
                    should3 = ret3;
                }
                tasklet.ms_wait(200);
            }
        }
    }

    class Tasklet08 : Object, ITaskletSpawnable
    {
        public void * func()
        {
            tasklet.ms_wait(TESTER_TIME_08);
            print("tester05: TIME_08\n");

            // ...

            return null;
        }
    }

    class Tasklet09 : Object, ITaskletSpawnable
    {
        public void * func()
        {
            tasklet.ms_wait(TESTER_TIME_09);
            print("tester05: TIME_09\n");

            // ...

            return null;
        }
    }

    class Tasklet10 : Object, ITaskletSpawnable
    {
        public void * func()
        {
            tasklet.ms_wait(TESTER_TIME_10);
            print("tester05: TIME_10\n");

            // ...

            return null;
        }
    }

    class Tasklet11 : Object, ITaskletSpawnable
    {
        public void * func()
        {
            tasklet.ms_wait(TESTER_TIME_11);
            print("tester05: TIME_11\n");

            // ...

            return null;
        }
    }

    class Tasklet12 : Object, ITaskletSpawnable
    {
        public void * func()
        {
            tasklet.ms_wait(TESTER_TIME_12);
            print("tester05: TIME_12\n");

            // ...

            return null;
        }
    }

    class Tasklet13 : Object, ITaskletSpawnable
    {
        public void * func()
        {
            tasklet.ms_wait(TESTER_TIME_13);
            print("tester05: TIME_13\n");

            // ...

            return null;
        }
    }

    class Tasklet14 : Object, ITaskletSpawnable
    {
        public void * func()
        {
            tasklet.ms_wait(TESTER_TIME_14);
            print("tester05: TIME_14\n");

            // ...

            return null;
        }
    }

    class Tasklet15 : Object, ITaskletSpawnable
    {
        public void * func()
        {
            tasklet.ms_wait(TESTER_TIME_15);
            print("tester05: TIME_15\n");

            // ...

            return null;
        }
    }

    class Tasklet16 : Object, ITaskletSpawnable
    {
        public void * func()
        {
            tasklet.ms_wait(TESTER_TIME_16);
            print("tester05: TIME_16\n");

            // ...

            return null;
        }
    }

    class Tasklet17 : Object, ITaskletSpawnable
    {
        public void * func()
        {
            tasklet.ms_wait(TESTER_TIME_17);
            print("tester05: TIME_17\n");

            // ...

            return null;
        }
    }

    class Tasklet18 : Object, ITaskletSpawnable
    {
        public void * func()
        {
            tasklet.ms_wait(TESTER_TIME_18);
            print("tester05: TIME_18\n");

            // ...

            return null;
        }
    }

    class Tasklet19 : Object, ITaskletSpawnable
    {
        public void * func()
        {
            tasklet.ms_wait(TESTER_TIME_19);
            print("tester05: TIME_19\n");

            // ...

            return null;
        }
    }

    class Tasklet20 : Object, ITaskletSpawnable
    {
        public void * func()
        {
            tasklet.ms_wait(TESTER_TIME_20);
            print("tester05: TIME_20\n");

            // ...

            return null;
        }
    }
}
