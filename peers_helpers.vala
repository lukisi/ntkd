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
            ArrayList<int> n_addr = new ArrayList<int>();
            n_addr.add_all(positions);
            int inside_level = n_addr.size;
            for (int i = inside_level; i < levels; i++) n_addr.add(0);
            string dest = ip_internal_node(n_addr, inside_level);
            ISourceID source_id = new PeersSourceID();
            IUnicastID unicast_id = new PeersUnicastID();
            IAddressManagerStub addrstub = get_addr_tcp_client(dest, ntkd_port, source_id, unicast_id);
            assert(addrstub is ITcpClientRootStub);
            ((ITcpClientRootStub)addrstub).wait_reply = true;
            PeersManagerStubHolder ret = new PeersManagerStubHolder(addrstub);
            return ret;
        }
    }

    class PeersSourceID : Object, ISourceID
    {
    }

    class PeersUnicastID : Object, IUnicastID
    {
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
            ArrayList<NodeID> broadcast_node_id_set = new ArrayList<NodeID>();
            foreach (IdentityArc ia in identity_data.identity_arcs)
            {
                if (ia.qspn_arc != null)
                    broadcast_node_id_set.add(ia.id_arc.get_peer_nodeid());
            }
            if(broadcast_node_id_set.is_empty) return new PeersManagerStubVoid();
            NodeID source_node_id = identity_data.nodeid;
            INeighborhoodMissingArcHandler n_missing_handler =
                new NeighborhoodMissingArcHandlerForPeers(missing_handler, identity_data);
            IAddressManagerStub addrstub =
                neighborhood_mgr.get_stub_identity_aware_broadcast(
                source_node_id,
                broadcast_node_id_set,
                n_missing_handler);
            PeersManagerStubHolder ret = new PeersManagerStubHolder(addrstub);
            return ret;
        }

        public IPeersManagerStub i_peers_get_tcp(IPeersArc arc)
        {
            PeersArc _arc = (PeersArc)arc;
            IAddressManagerStub addrstub =
                neighborhood_mgr.get_stub_identity_aware_unicast(
                _arc.arc.neighborhood_arc,
                _arc.sourceid,
                _arc.destid,
                true);  // wait_reply
            PeersManagerStubHolder ret = new PeersManagerStubHolder(addrstub);
            return ret;
        }
    }

    class NeighborhoodMissingArcHandlerForPeers : Object, INeighborhoodMissingArcHandler
    {
        public NeighborhoodMissingArcHandlerForPeers(IPeersMissingArcHandler peers_missing, IdentityData identity_data)
        {
            this.peers_missing = peers_missing;
            this.identity_data = identity_data;
        }
        private IPeersMissingArcHandler peers_missing;
        private weak IdentityData identity_data;

        public void missing(INeighborhoodArc arc)
        {
            foreach (IdentityArc ia in identity_data.identity_arcs)
            {
                // ia is an identity-arc of my node
                IdmgmtArc _arc = (IdmgmtArc)ia.arc;
                INeighborhoodArc n_arc = _arc.neighborhood_arc;
                if (n_arc == arc)
                {
                    // ia is over this physical arc
                    if (ia.qspn_arc != null)
                    {
                        // ia is on this network
                        PeersArc peers_arc = new PeersArc(ia);
                        peers_missing.i_peers_missing(peers_arc);
                    }
                }
            }
        }
    }

    class PeersArc : Object, IPeersArc
    {
        public PeersArc(IdentityArc ia)
        {
            this.sourceid = ia.id;
            this.destid = ia.id_arc.get_peer_nodeid();
            this.ia = ia;
            arc = (IdmgmtArc)ia.arc;
        }
        public weak IdmgmtArc arc;
        public NodeID sourceid;
        public NodeID destid;
        public weak IdentityArc ia;
    }
}
