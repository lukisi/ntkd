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
    void identities_identity_arc_added(IIdmgmtArc arc, NodeID id, IIdmgmtIdentityArc id_arc)
    {
        // Retrieve my identity.
        IdentityData identity_data = find_or_create_local_identity(id);
        // Create IdentityArc.
        IdentityArc ia = new IdentityArc(identity_data, arc, id_arc);
        // Add to the list.
        identity_data.identity_arcs.add(ia);

        // TODO Pass it to the Hooking module.

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
    }

    void identities_identity_arc_removing(IIdmgmtArc arc, NodeID id, NodeID peer_nodeid)
    {
        // Retrieve my identity.
        IdentityData identity_data = find_or_create_local_identity(id);
        // Retrieve IdentityArc.
        IdentityArc ia = find_identity_arc_by_peer_nodeid(identity_data, arc, peer_nodeid);

        // TODO If a Qspn arc exists for it, change routes in kernel tables.
        //      Then remove Qspn arc.

        print(@"identities_identity_arc_removing: my id $(identity_data.nodeid.id) connected to");
        print(@" id $(ia.id_arc.get_peer_nodeid().id) on arc $(((IdmgmtArc)arc).id).\n");
        print(@" peer_linklocal = $(ia.peer_linklocal).\n");
    }

    void identities_identity_arc_removed(IIdmgmtArc arc, NodeID id, NodeID peer_nodeid)
    {
        // Retrieve my identity.
        IdentityData identity_data = find_or_create_local_identity(id);
        // Retrieve IdentityArc.
        IdentityArc ia = find_identity_arc_by_peer_nodeid(identity_data, arc, peer_nodeid);

        // Remove from the list.
        identity_data.identity_arcs.remove(ia);

        print(@"identities_identity_arc_removed: my id $(identity_data.nodeid.id) connected to");
        print(@" id $(ia.id_arc.get_peer_nodeid().id) on arc $(((IdmgmtArc)arc).id).\n");
        print(@" peer_linklocal = $(ia.peer_linklocal).\n");
    }

    void identities_arc_removed(IIdmgmtArc arc)
    {
        warning("unused signal identities_arc_removed");
    }
}
