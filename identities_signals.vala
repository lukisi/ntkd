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
        IdentityData identity_data = find_or_create_local_identity(id);
        IdentityArc ia = new IdentityArc(identity_data, arc, id_arc);
        identity_data.identity_arcs.add(ia);
    }

    void identities_identity_arc_changed(IIdmgmtArc arc, NodeID id, IIdmgmtIdentityArc id_arc, bool only_neighbour_migrated)
    {
        // Retrieve my identity.
        IdentityData identity_data = find_or_create_local_identity(id);
        // Retrieve peer_nodeid
        NodeID peer_nodeid = id_arc.get_peer_nodeid();
        // Retrieve IdentityArc
        IdentityArc ia = find_identity_arc(identity_data, arc, peer_nodeid);

        ia.prev_peer_mac = ia.peer_mac;
        ia.prev_peer_linklocal = ia.peer_linklocal;
        ia.peer_mac = ia.id_arc.get_peer_mac();
        ia.peer_linklocal = ia.id_arc.get_peer_linklocal();

        if (only_neighbour_migrated)
            warning("unused signal identities_identity_arc_changed(only_neighbour_migrated)");
        else
            warning("unused signal identities_identity_arc_changed()");
    }

    void identities_identity_arc_removing(IIdmgmtArc arc, NodeID id, NodeID peer_nodeid)
    {
        warning("unused signal identities_identity_arc_removing");
    }

    void identities_identity_arc_removed(IIdmgmtArc arc, NodeID id, NodeID peer_nodeid)
    {
        warning("unused signal identities_identity_arc_removed");
    }

    void identities_arc_removed(IIdmgmtArc arc)
    {
        warning("unused signal identities_arc_removed");
    }
}
