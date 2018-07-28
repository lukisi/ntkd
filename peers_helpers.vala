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

        public int i_peers_get_levels()
        {
            return levels;
        }

        public int i_peers_get_gsize(int level)
        {
            return gsizes[level];
        }

        public int i_peers_get_my_pos(int level)
        {
            return identity_data.my_naddr.pos[level];
        }

        public int i_peers_get_nodes_in_my_group(int level)
        {
            try {
                return identity_data.qspn_mgr.get_nodes_inside(level);
            } catch (QspnBootstrapInProgressError e) {
                assert_not_reached();
            }
        }

        public bool i_peers_exists(int level, int pos)
        {
            try {
                Gee.List<HCoord> dests = identity_data.qspn_mgr.get_known_destinations(level);
                foreach (HCoord dest in dests) if (dest.pos == pos) return true;
                return false;
            } catch (QspnBootstrapInProgressError e) {
                assert_not_reached();
            }
        }

        public IPeersManagerStub i_peers_gateway(int level, int pos, CallerInfo? received_from = null, IPeersManagerStub? failed = null)
        throws PeersNonexistentDestinationError
        {
            // If there is a (previous) failed stub, remove the physical arc it was based on.
            if (failed != null)
            {
                INeighborhoodArc neighborhood_arc = ((PeersManagerStubHolder)failed).neighborhood_arc;
                ArrayList<INeighborhoodArc> neighborhood_arc_list = new ArrayList<INeighborhoodArc>();
                foreach (NodeArc node_arc in arc_list) neighborhood_arc_list.add(node_arc.neighborhood_arc);
                foreach (INeighborhoodArc arc in neighborhood_arc_list)
                {
                    if (arc == neighborhood_arc)
                    {
                        neighborhood_mgr.remove_my_arc(arc, false);
                        // After removing a arc, we can give the program a little while in order
                        //  to retrieve ETPs from remaining links and update its map.
                        tasklet.ms_wait(1000);
                        break;
                    }
                }
            }
            // Search a gateway to reach (level, pos) excluding received_from
            NodeID? received_from_nodeid = null;
            if (received_from != null)
            {
                if (received_from is TcpclientCallerInfo)
                {
                    TcpclientCallerInfo tcp = (TcpclientCallerInfo)received_from;
                    SkeletonFactory f = new SkeletonFactory();
                    received_from_nodeid = f.get_identity(tcp.sourceid);
                }
                else
                {
                    warning(@"PeersMapPaths.i_peers_gateway: not a expected type of caller $(received_from.get_type().name()).");
                }
            }
            Gee.List<IQspnNodePath> paths;
            try {
                paths = identity_data.qspn_mgr.get_paths_to(new HCoord(level, pos));
            } catch (QspnBootstrapInProgressError e) {
                assert_not_reached();
            }
            while (! paths.is_empty)
            {
                IQspnNodePath path = paths[0];
                QspnArc qspn_arc = (QspnArc)path.i_qspn_get_arc();
                NodeID gw_nodeid = qspn_arc.destid;
                if (received_from_nodeid != null && received_from_nodeid.equals(gw_nodeid))
                {
                    paths.remove_at(0);
                    continue;
                }
                // found a gateway, excluding received_from
                break;
            }
            if (paths.is_empty) throw new PeersNonexistentDestinationError.GENERIC("No more paths");
            // Note: currently the module PeerServices handles this exception and does not use the message in any way.
            IQspnNodePath best_path = paths[0];
            QspnArc gw_qspn_arc = (QspnArc)best_path.i_qspn_get_arc();
            // find gw_ia by gw_qspn_arc, otherwise exit_tasklet.
            IdentityArc? gw_ia = null;
            foreach (IdentityArc _ia in identity_data.identity_arcs) if (_ia.qspn_arc == gw_qspn_arc)
            {
                gw_ia = _ia;
                break;
            }
            if (gw_ia == null) tasklet.exit_tasklet();
            StubFactory f = new StubFactory();
            IAddressManagerStub addrstub = f.get_stub_identity_aware_unicast_from_ia(gw_ia, false);
            PeersManagerStubHolder ret = new PeersManagerStubHolder(addrstub);
            ret.neighborhood_arc = ((IdmgmtArc)gw_ia.arc).neighborhood_arc;
            return ret;
        }

        public IPeersManagerStub? i_peers_neighbor_at_level(int level, IPeersManagerStub? failed = null)
        {
            // If there is a (previous) failed stub, remove the physical arc it was based on.
            if (failed != null)
            {
                INeighborhoodArc neighborhood_arc = ((PeersManagerStubHolder)failed).neighborhood_arc;
                ArrayList<INeighborhoodArc> neighborhood_arc_list = new ArrayList<INeighborhoodArc>();
                foreach (NodeArc node_arc in arc_list) neighborhood_arc_list.add(node_arc.neighborhood_arc);
                foreach (INeighborhoodArc arc in neighborhood_arc_list)
                {
                    if (arc == neighborhood_arc)
                    {
                        neighborhood_mgr.remove_my_arc(arc, false);
                        // Here we don't need to wait for map update. We care just about neighbors.
                        break;
                    }
                }
            }
            IPeersManagerStub? ret = null;
            foreach (IdentityArc ia in identity_data.identity_arcs) if (ia.qspn_arc != null)
            {
                IQspnNaddr? naddr_for_ia = identity_data.qspn_mgr.get_naddr_for_arc(ia.qspn_arc);
                if (naddr_for_ia == null) continue;
                HCoord gw = identity_data.my_naddr.i_qspn_get_coord_by_address(naddr_for_ia);
                if (gw.lvl == level)
                {
                    StubFactory f = new StubFactory();
                    IAddressManagerStub addrstub = f.get_stub_identity_aware_unicast_from_ia(ia, true);
                    PeersManagerStubHolder _ret = new PeersManagerStubHolder(addrstub);
                    _ret.neighborhood_arc = ((IdmgmtArc)ia.arc).neighborhood_arc;
                    ret = _ret;
                    break;
                }
            }
            return ret;
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
            StubFactory f = new StubFactory();
            IAddressManagerStub addrstub = f.get_stub_identity_aware_unicast_inside_gnode(positions, identity_data);
            PeersManagerStubHolder ret = new PeersManagerStubHolder(addrstub);
            return ret;
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
            ArrayList<NodeID> broadcast_node_id_set = new ArrayList<NodeID>();
            foreach (IdentityArc ia in identity_data.identity_arcs)
            {
                if (ia.qspn_arc != null)
                    broadcast_node_id_set.add(ia.id_arc.get_peer_nodeid());
            }
            if(broadcast_node_id_set.is_empty) return new PeersManagerStubVoid();
            MissingArcHandlerForPeers identity_missing_handler =
                new MissingArcHandlerForPeers(missing_handler);
            StubFactory f = new StubFactory();
            IAddressManagerStub addrstub = f.get_stub_identity_aware_broadcast(
                identity_data,
                broadcast_node_id_set,
                identity_missing_handler);
            PeersManagerStubHolder ret = new PeersManagerStubHolder(addrstub);
            return ret;
        }

        public IPeersManagerStub i_peers_get_tcp(IPeersArc arc)
        {
            IdentityArc ia = ((PeersArc)arc).ia;
            StubFactory f = new StubFactory();
            IAddressManagerStub addrstub = f.get_stub_identity_aware_unicast_from_ia(ia, true);
            PeersManagerStubHolder ret = new PeersManagerStubHolder(addrstub);
            return ret;
        }
    }

    class MissingArcHandlerForPeers : Object, IIdentityAwareMissingArcHandler
    {
        public MissingArcHandlerForPeers(IPeersMissingArcHandler peers_missing)
        {
            this.peers_missing = peers_missing;
        }
        private IPeersMissingArcHandler peers_missing;

        public void missing(IdentityData identity_data, IdentityArc identity_arc)
        {
            if (identity_arc.qspn_arc != null)
            {
                // identity_arc is on this network
                PeersArc peers_arc = new PeersArc(identity_arc);
                peers_missing.i_peers_missing(peers_arc);
            }
        }
    }

    class PeersArc : Object, IPeersArc
    {
        public PeersArc(IdentityArc ia)
        {
            this.ia = ia;
        }
        public weak IdentityArc ia;
    }
}
