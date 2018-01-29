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
using Netsukuku;
using Netsukuku.Neighborhood;
using Netsukuku.Identities;
using Netsukuku.Qspn;
using Netsukuku.Coordinator;
using Netsukuku.Hooking;
using Netsukuku.Andna;
using TaskletSystem;

namespace Netsukuku.UpdateGraph
{
    void add_arc(IdentityArc identity_arc)
    {
        IdentityData identity_data = identity_arc.identity_data;

        NodeID destid = identity_arc.id_arc.get_peer_nodeid();
        NodeID sourceid = identity_arc.id; // == identity_data.nodeid
        identity_arc.qspn_arc = new QspnArc(sourceid, destid, identity_arc, identity_arc.peer_mac);

        QspnManager my_qspn = (QspnManager)identity_mgr.get_identity_module(identity_data.nodeid, "qspn");
        my_qspn.arc_add(identity_arc.qspn_arc);
        IpCommands.new_arc(identity_data, identity_arc.peer_mac);
    }

    void update_destination(IdentityData id, HCoord hc)
    {
        QspnManager qspn_mgr = (QspnManager)identity_mgr.get_identity_module(id.nodeid, "qspn");
        Gee.List<IQspnNodePath> paths;
        try {
            paths = qspn_mgr.get_paths_to(hc);
        } catch (QspnBootstrapInProgressError e) {
            assert_not_reached();
        }
        ArrayList<string> peer_mac_set = new ArrayList<string>();
        ArrayList<HCoord> peer_hc_set = new ArrayList<HCoord>();
        foreach (IdentityArc ia in id.identity_arcs) if (ia.qspn_arc != null)
        {
            QspnArc qspn_arc = (QspnArc)ia.qspn_arc;
            string peer_mac = qspn_arc.peer_mac;
            IQspnNaddr? peer_naddr = qspn_mgr.get_naddr_for_arc(qspn_arc);
            if (peer_naddr != null)
            {
                HCoord peer_hc = id.my_naddr.i_qspn_get_coord_by_address(peer_naddr);
                peer_mac_set.add(peer_mac);
                peer_hc_set.add(peer_hc);
            }
        }
        IpCommands.map_update(id, hc, paths, peer_mac_set, peer_hc_set);
    }
}
