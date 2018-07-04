/*
 *  This file is part of Netsukuku.
 *  Copyright (C) 2018 Luca Dionisi aka lukisi <luca.dionisi@gmail.com>
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
using Netsukuku.Hooking;
using TaskletSystem;

namespace Netsukuku
{
    void per_identity_hooking_same_network(IdentityData id, IIdentityArc _ia)
    {
        IdentityArc ia = ((HookingIdentityArc)_ia).ia;
        ia.network_id = null;
        print(@"Signal Hooking.same_network: adding qspn_arc for id-arc " +
            @"$(id.nodeid.id)-$(ia.id_arc.get_peer_nodeid().id) on arc $(((IdmgmtArc)ia.arc).id).\n");
        UpdateGraph.add_arc(ia); // this will set ia.qspn_arc
    }

    void per_identity_hooking_another_network(IdentityData id, IIdentityArc _ia, int64 network_id)
    {
        IdentityArc ia = ((HookingIdentityArc)_ia).ia;
        ia.network_id = network_id;
        print(@"Signal Hooking.another_network: saving network_id $(network_id) for id-arc " +
            @"$(id.nodeid.id)-$(ia.id_arc.get_peer_nodeid().id) on arc $(((IdmgmtArc)ia.arc).id).\n");
    }

    void per_identity_hooking_do_prepare_migration(IdentityData id, int migration_id)
    {
        warning("Not implemented yet: do_prepare_migration");
    }

    void per_identity_hooking_do_finish_migration(IdentityData id,
        int migration_id, int guest_gnode_level, EntryData migration_data, int go_connectivity_position)
    {
        warning("Not implemented yet: do_finish_migration");
    }

    void per_identity_hooking_do_prepare_enter(IdentityData id, int enter_id)
    {
        print(@"Signal Hooking.do_prepare_enter: For identity $(id.nodeid.id) with enter_id $(enter_id).\n");
        EnterNetwork.prepare_enter(enter_id, id);
    }

    void per_identity_hooking_do_finish_enter(IdentityData id,
        int enter_id, int guest_gnode_level, EntryData entry_data, int go_connectivity_position)
    {
        print(@"Signal Hooking.do_finish_enter: For identity $(id.nodeid.id) with enter_id $(enter_id).\n");
        print(@"     With guest_gnode_level $(guest_gnode_level) on network_id $(entry_data.network_id).\n");
        IdentityData new_id = EnterNetwork.enter(enter_id, id, entry_data.network_id,
            guest_gnode_level, go_connectivity_position,
            entry_data.pos,
            entry_data.elderships);
        print(@"Completed do_finish_enter: New identity is $(new_id.nodeid.id).\n");
    }
}
