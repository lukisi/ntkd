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
using TaskletSystem;

namespace Netsukuku
{
    void identities_identity_arc_added(IIdmgmtArc arc, NodeID id, IIdmgmtIdentityArc id_arc, IIdmgmtIdentityArc? prev_id_arc)
    {
        // Retrieve my identity.
        IdentityData identity_data = find_or_create_local_identity(id);
        // Create IdentityArc.
        IdentityArc ia = new IdentityArc(identity_data, arc, id_arc);
        // Add to the list.
        identity_data.identity_arcs.add(ia);

        // If needed, pass it to the Hooking module.
        if (prev_id_arc == null) identity_data.hook_mgr.add_arc(new HookingIdentityArc(ia));

        print(@"identities_identity_arc_added: my id $(identity_data.nodeid.id) connected to");
        print(@" id $(ia.id_arc.get_peer_nodeid().id) on arc $(((IdmgmtArc)arc).id).\n");
        print(@" peer_linklocal = $(ia.peer_linklocal).\n");
    }

    void identities_identity_arc_changed(IIdmgmtArc arc, NodeID id, IIdmgmtIdentityArc id_arc, bool only_neighbour_migrated)
    {
        // Retrieve my identity.
        IdentityData identity_data = find_or_create_local_identity(id);
        // Retrieve IdentityArc.
        IdentityArc ia = find_identity_arc(id_arc);

        // Modify properties.
        ia.prev_peer_mac = ia.peer_mac;
        ia.prev_peer_linklocal = ia.peer_linklocal;
        ia.peer_mac = ia.id_arc.get_peer_mac();
        ia.peer_linklocal = ia.id_arc.get_peer_linklocal();

        // TODO If a Qspn arc exists for it, change routes in kernel tables.

        print(@"identities_identity_arc_changed: my id $(identity_data.nodeid.id) connected to");
        print(@" id $(ia.id_arc.get_peer_nodeid().id) on arc $(((IdmgmtArc)arc).id).\n");
        if (only_neighbour_migrated) print(@" only_neighbour_migrated.\n");
        print(@" prev_peer_linklocal = $(ia.prev_peer_linklocal).");
        print(@" peer_linklocal = $(ia.peer_linklocal).\n");

        // This signal might happen when the module Identities of this system is doing `add_identity` on
        //  this very identity (identity_data).
        //  In this case the program does some further operations on its own (see user_commands.vala).
        //  But this might also happen when only our neighbour is doing `add_identity`.
        if (only_neighbour_migrated)
        {
            // TODO In this case we must do some work if we have a qspn_arc on this identity_arc.

            // After that, we need no more to keep old values.
            ia.prev_peer_mac = null;
            ia.prev_peer_linklocal = null;
        }
    }

    void identities_identity_arc_removing(IIdmgmtArc arc, NodeID id, NodeID peer_nodeid)
    {
        // Retrieve my identity.
        IdentityData identity_data = find_or_create_local_identity(id);
        // Retrieve IdentityArc.
        IdentityArc ia = find_identity_arc_by_peer_nodeid(identity_data, arc, peer_nodeid);

        print(@"identities_identity_arc_removing: my id $(identity_data.nodeid.id) connected to");
        print(@" id $(ia.id_arc.get_peer_nodeid().id) on arc $(((IdmgmtArc)arc).id).\n");
        print(@" peer_linklocal = $(ia.peer_linklocal).\n");

        if (ia.qspn_arc != null)
        {
            // Remove Qspn arc.
            QspnManager qspn_mgr = (QspnManager)identity_mgr.get_identity_module(id, "qspn");
            qspn_mgr.arc_remove(ia.qspn_arc);
        }
    }

    void identities_identity_arc_removed(IIdmgmtArc arc, NodeID id, NodeID peer_nodeid)
    {
        // Retrieve my identity.
        IdentityData identity_data = find_or_create_local_identity(id);
        // Retrieve IdentityArc.
        IdentityArc ia = find_identity_arc_by_peer_nodeid(identity_data, arc, peer_nodeid);

        print(@"identities_identity_arc_removed: my id $(identity_data.nodeid.id) connected to");
        print(@" id $(ia.id_arc.get_peer_nodeid().id) on arc $(((IdmgmtArc)arc).id).\n");
        print(@" peer_linklocal = $(ia.peer_linklocal).\n");

        if (ia.qspn_arc != null)
        {
            ia.qspn_arc = null;
            // Remove from the list.
            identity_data.identity_arcs.remove(ia);
            // Then remove kernel tables.
            IpCommands.removed_arc(identity_data, ia.peer_mac);
        }
    }

    void identities_arc_removed(IIdmgmtArc arc)
    {
        warning("unused signal identities_arc_removed");
    }
}
