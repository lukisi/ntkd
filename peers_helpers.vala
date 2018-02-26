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
using Netsukuku.PeerServices;
using TaskletSystem;

namespace Netsukuku
{
    class PeersMapPaths : Object, IPeersMapPaths
    {
        public PeersMapPaths(IdentityData identity_data)
        {
            this.identity_data = identity_data;
        }
        private weak IdentityData identity_data;

        public bool i_peers_exists(int level, int pos)
        {
            error("not implemented yet");
        }

        public IPeersManagerStub i_peers_gateway(int level, int pos, CallerInfo? received_from = null, IPeersManagerStub? failed = null)
        throws PeersNonexistentDestinationError
        {
            error("not implemented yet");
        }

        public int i_peers_get_gsize(int level)
        {
            error("not implemented yet");
        }

        public int i_peers_get_levels()
        {
            error("not implemented yet");
        }

        public int i_peers_get_my_pos(int level)
        {
            error("not implemented yet");
        }

        public int i_peers_get_nodes_in_my_group(int level)
        {
            error("not implemented yet");
        }

        public IPeersManagerStub? i_peers_neighbor_at_level(int level, IPeersManagerStub? failed = null)
        {
            error("not implemented yet");
        }
    }

    class PeersBackStubFactory : Object, IPeersBackStubFactory
    {
        public PeersBackStubFactory(IdentityData identity_data)
        {
            this.identity_data = identity_data;
        }
        private weak IdentityData identity_data;

        public IPeersManagerStub i_peers_get_tcp_inside(Gee.List<int> positions)
        {
            error("not implemented yet");
        }
    }

    class PeersNeighborsFactory : Object, IPeersNeighborsFactory
    {
        public PeersNeighborsFactory(IdentityData identity_data)
        {
            this.identity_data = identity_data;
        }
        private weak IdentityData identity_data;

        public IPeersManagerStub i_peers_get_broadcast(IPeersMissingArcHandler missing_handler)
        {
            error("not implemented yet");
        }

        public IPeersManagerStub i_peers_get_tcp(IPeersArc arc)
        {
            error("not implemented yet");
        }
    }
}
