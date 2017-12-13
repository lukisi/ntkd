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
using Netsukuku.Neighborhood;
using Netsukuku.Identities;
using Netsukuku.Qspn;
using TaskletSystem;

namespace Netsukuku
{
    class LookupTable : Object
    {
        public string tablename;
        public bool pkt_egress;
        public NeighborData? pkt_from;

        public LookupTable.egress(string tablename)
        {
            this.tablename = tablename;
            pkt_egress = true;
            pkt_from = null;
        }

        public LookupTable.forwarding(string tablename, NeighborData pkt_from)
        {
            this.tablename = tablename;
            pkt_egress = false;
            this.pkt_from = pkt_from;
        }
    }

    class NeighborData : Object
    {
        public string mac;
        public string tablename;
        public HCoord? h;
    }

    NeighborData get_neighbor(IdentityData id, IdentityArc ia)
    {
        assert(ia.qspn_arc != null);

        // Compute neighbor.
        NeighborData ret = new NeighborData();
        ret.mac = ia.id_arc.get_peer_mac();
        ret.tablename = ia.tablename;

        QspnManager qspn_mgr = (QspnManager)identity_mgr.get_identity_module(id.nodeid, "qspn");
        IQspnNaddr? neighbour_naddr = qspn_mgr.get_naddr_for_arc(ia.qspn_arc);
        if (neighbour_naddr == null) ret.h = null;
        else ret.h = id.my_naddr.i_qspn_get_coord_by_address(neighbour_naddr);

        return ret;
    }

    Gee.List<NeighborData> all_neighbors(IdentityData id, bool only_known_peers=false)
    {
        // Compute list of neighbors.
        ArrayList<NeighborData> neighbors = new ArrayList<NeighborData>();
        foreach (IdentityArc ia in id.identity_arcs) if (ia.qspn_arc != null)
        {
            NeighborData neighbor = get_neighbor(id, ia);
            if ((! only_known_peers) || neighbor.h != null)
                neighbors.add(neighbor);
        }
        return neighbors;
    }

    class BestRouteToDest : Object
    {
        public string gw;
        public string dev;
    }
}

