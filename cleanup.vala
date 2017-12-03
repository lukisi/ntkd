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
    void cleanup(ref string ntklocalhost)
    {
        // Remove connectivity identities and their network namespaces and linklocal addresses.
        ArrayList<IdentityData> local_identities_copy = new ArrayList<IdentityData>();
        local_identities_copy.add_all(local_identities);
        foreach (IdentityData identity_data in local_identities_copy)
        {
            if (! identity_data.main_id)
            {
                // TODO remove namespace
                // TODO when needed, remove ntk_from_xxx from rt_tables
                identity_mgr.remove_identity(identity_data.nodeid);
                local_identities.remove(identity_data);
            }
        }

        // For main identity...
        assert(local_identities.size == 1);
        IdentityData identity_data = local_identities[0];
        assert(identity_data.main_id);
        // ... TODO send "destroy" message to Qspn module.

        // Call stop_monitor_all of NeighborhoodManager.
        neighborhood_mgr.stop_monitor_all();

        // remove local addresses (global, anon, intern, localhost)
        cm.single_command(new ArrayList<string>.wrap({
            @"ip", @"address", @"del", @"$(ntklocalhost)/32", @"dev", @"lo"}));

        // Then we destroy the object NeighborhoodManager.
        // Beware that node_skeleton.neighborhood_mgr is a weak reference.
        neighborhood_mgr = null;

        // Kill the tasklets that were used by the RPC library.
        foreach (ITaskletHandle t_udp in t_udp_list) t_udp.kill();
        t_tcp.kill();

        tasklet.ms_wait(100);

        PthTaskletImplementer.kill();
        print("\nExiting.\n");
    }
}
