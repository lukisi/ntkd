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
using TaskletSystem;

namespace Netsukuku
{
    class TableNames : Object
    {
        public static TableNames get_singleton(Commander my_cm)
        {
            if (singleton == null) singleton = new TableNames(my_cm);
            return singleton;
        }

        private static TableNames singleton;
        private Commander my_cm;

        private TableNames(Commander my_cm)
        {
            this.my_cm = my_cm;
            init_table_names();
        }

        /* Table-names management
        ** 
        */

        private const string RT_TABLES = "/etc/iproute2/rt_tables";
        private static ArrayList<int> free_tid;
        private static HashMap<string, int> mac_tid;
        private static void init_table_names()
        {
            free_tid = new ArrayList<int>();
            for (int i = 250; i >= 200; i--) free_tid.add(i);
            mac_tid = new HashMap<string, int>();
        }

        public void get_table(int? bid, string peer_mac, out int tid, out string tablename)
        {
            tablename = @"ntk_from_$(peer_mac)";
            if (mac_tid.has_key(peer_mac))
            {
                tid = mac_tid[peer_mac];
                return;
            }
            assert(! free_tid.is_empty);
            tid = free_tid.remove_at(0);
            mac_tid[peer_mac] = tid;
            ArrayList<string> cmd = new ArrayList<string>.wrap({
                @"sed", @"-i", @"s/$(tid) reserved_ntk_from_$(tid)/$(tid) $(tablename)/", RT_TABLES});
            if (bid != null) my_cm.single_command_in_block(bid, cmd);
            else my_cm.single_command(cmd);
        }

        public void release_table(int? bid, string peer_mac)
        {
            string tablename = @"ntk_from_$(peer_mac)";
            assert(mac_tid.has_key(peer_mac));
            int tid = mac_tid[peer_mac];
            assert(! (tid in free_tid));
            free_tid.insert(0, tid);
            mac_tid.unset(peer_mac);
            ArrayList<string> cmd = new ArrayList<string>.wrap({
                @"sed", @"-i", @"s/$(tid) $(tablename)/$(tid) reserved_ntk_from_$(tid)/", RT_TABLES});
            if (bid != null) my_cm.single_command_in_block(bid, cmd);
            else my_cm.single_command(cmd);
        }

        public void release_all_tables(int? bid) // TODO is this function useful?
        {
            foreach (string peer_mac in mac_tid.keys)
            {
                int tid = mac_tid[peer_mac];
                string tablename = @"ntk_from_$(peer_mac)";
                ArrayList<string> cmd = new ArrayList<string>.wrap({
                    @"sed", @"-i", @"s/$(tid) $(tablename)/$(tid) reserved_ntk_from_$(tid)/", RT_TABLES});
                if (bid != null) my_cm.single_command_in_block(bid, cmd);
                else my_cm.single_command(cmd);
            }
            free_tid.clear();
            mac_tid.clear();
        }
    }
}
