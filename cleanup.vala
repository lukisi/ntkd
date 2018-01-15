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
                // remove namespace
                identity_mgr.remove_identity(identity_data.nodeid);
                local_identities.remove(identity_data);

                // when needed, remove ntk_from_xxx from rt_tables
                ArrayList<string> peermacs = new ArrayList<string>();
                foreach (IdentityArc id_arc in identity_data.identity_arcs)
                    peermacs.add(id_arc.peer_mac);
                IpCommands.connectivity_stop(identity_data, peermacs);
            }
        }

        // For main identity...
        assert(local_identities.size == 1);
        IdentityData identity_data = local_identities[0];
        assert(identity_data.main_id);

        QspnManager qspn_mgr = (QspnManager)identity_mgr.get_identity_module(identity_data.nodeid, "qspn");
        // ... send "destroy" message.
        qspn_mgr.destroy();

        // Call stop_monitor_all of NeighborhoodManager.
        neighborhood_mgr.stop_monitor_all();

        // ... disconnect signal handlers of qspn_mgr.
        qspn_mgr.arc_removed.disconnect(identity_data.arc_removed);
        qspn_mgr.changed_fp.disconnect(identity_data.changed_fp);
        qspn_mgr.changed_nodes_inside.disconnect(identity_data.changed_nodes_inside);
        qspn_mgr.destination_added.disconnect(identity_data.destination_added);
        qspn_mgr.destination_removed.disconnect(identity_data.destination_removed);
        qspn_mgr.gnode_splitted.disconnect(identity_data.gnode_splitted);
        qspn_mgr.path_added.disconnect(identity_data.path_added);
        qspn_mgr.path_changed.disconnect(identity_data.path_changed);
        qspn_mgr.path_removed.disconnect(identity_data.path_removed);
        qspn_mgr.presence_notified.disconnect(identity_data.presence_notified);
        qspn_mgr.qspn_bootstrap_complete.disconnect(identity_data.qspn_bootstrap_complete);
        qspn_mgr.remove_identity.disconnect(identity_data.remove_identity);
        identity_data.qspn_handlers_disabled = true;
        identity_mgr.unset_identity_module(identity_data.nodeid, "qspn");
        qspn_mgr.stop_operations();
        qspn_mgr = null;

        // iproute commands for cleanup main identity
        ArrayList<string> peermacs = new ArrayList<string>();
        foreach (IdentityArc id_arc in identity_data.identity_arcs)
            peermacs.add(id_arc.peer_mac);
        IpCommands.main_stop(identity_data, peermacs);

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
