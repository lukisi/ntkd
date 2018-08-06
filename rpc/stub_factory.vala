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

namespace Netsukuku
{
    interface IIdentityAwareMissingArcHandler : Object
    {
        public abstract void missing(IdentityData identity_data, IdentityArc identity_arc);
    }

    class StubFactory : Object
    {
        public StubFactory()
        {
        }

        public IAddressManagerStub
        get_stub_identity_aware_unicast(
            INeighborhoodArc arc,
            IdentityData identity_data,
            NodeID unicast_node_id,
            bool wait_reply=true)
        {
            NodeID source_node_id = identity_data.nodeid;
            IdentityAwareSourceID source_id = new IdentityAwareSourceID(source_node_id);
            IdentityAwareUnicastID unicast_id = new IdentityAwareUnicastID(unicast_node_id);
            string dest = arc.neighbour_nic_addr;
            IAddressManagerStub tc = get_addr_tcp_client(dest, ntkd_port, source_id, unicast_id);
            assert(tc is ITcpClientRootStub);
            ((ITcpClientRootStub)tc).wait_reply = wait_reply;
            return tc;
        }

        public IAddressManagerStub
        get_stub_identity_aware_unicast_from_ia(IdentityArc ia, bool wait_reply=true)
        {
            IdmgmtArc arc = (IdmgmtArc)ia.arc;
            INeighborhoodArc neighborhood_arc = arc.neighborhood_arc;
            IdentityData identity_data = ia.identity_data;
            NodeID unicast_node_id = ia.id_arc.get_peer_nodeid();
            return get_stub_identity_aware_unicast(neighborhood_arc, identity_data, unicast_node_id, wait_reply);
        }

        public IAddressManagerStub
        get_stub_main_identity_unicast_inside_gnode(
            Gee.List<int> positions,
            bool wait_reply=true)
        {
            ArrayList<int> n_addr = new ArrayList<int>();
            n_addr.add_all(positions);
            int inside_level = n_addr.size;
            for (int i = inside_level; i < levels; i++) n_addr.add(0);
            string dest = ip_internal_node(n_addr, inside_level);
            ISourceID source_id = new MainIdentitySourceID();
            IUnicastID unicast_id = new MainIdentityUnicastID();
            IAddressManagerStub tc = get_addr_tcp_client(dest, ntkd_port, source_id, unicast_id);
            assert(tc is ITcpClientRootStub);
            ((ITcpClientRootStub)tc).wait_reply = wait_reply;
            return tc;
        }

        public IAddressManagerStub
        get_stub_identity_aware_broadcast(
            IdentityData identity_data,
            Gee.List<NodeID> broadcast_node_id_set,
            IIdentityAwareMissingArcHandler? identity_missing_handler=null)
        {
            NodeID source_node_id = identity_data.nodeid;
            IdentityAwareSourceID source_id = new IdentityAwareSourceID(source_node_id);
            IdentityAwareBroadcastID broadcast_id = new IdentityAwareBroadcastID(broadcast_node_id_set);
            ArrayList<string> devs = new ArrayList<string>();
            ArrayList<string> src_ips = new ArrayList<string>();
            ArrayList<INeighborhoodNetworkInterface> nics = new ArrayList<INeighborhoodNetworkInterface>();

            ArrayList<INeighborhoodArc> neighborhood_arc_list = new ArrayList<INeighborhoodArc>();
            foreach (NodeArc node_arc in arc_list) neighborhood_arc_list.add(node_arc.neighborhood_arc);
            foreach (INeighborhoodArc arc in neighborhood_arc_list) if (! (arc.nic.dev in devs))
            {
                string local_address = null;
                foreach (HandledNic n in handlednic_list)
                {
                    if (n.dev == arc.nic.dev) src_ips.add(n.linklocal);
                }
                if (local_address != null)
                {
                    devs.add(arc.nic.dev);
                    src_ips.add(local_address);
                    nics.add(arc.nic);
                }
            }
            IAckCommunicator? ack_com = null;
            if (identity_missing_handler != null)
            {
                NodeMissingArcHandlerForIdentityAware node_missing_handler
                    = new NodeMissingArcHandlerForIdentityAware(identity_missing_handler, identity_data);
                ack_com = new AcknowledgementsCommunicator(this, nics, node_missing_handler);
            }
            assert(! devs.is_empty);
            assert(devs.size == src_ips.size);
            IAddressManagerStub bc = get_addr_broadcast(devs, src_ips, ntkd_port, source_id, broadcast_id, ack_com);
            return bc;
        }

        private Gee.List<INeighborhoodArc> get_current_arcs_for_broadcast(Gee.List<INeighborhoodNetworkInterface> nics)
        {
            var ret = new ArrayList<INeighborhoodArc>();
            foreach (NodeArc node_arc in arc_list)
                if (node_arc.neighborhood_arc.nic in nics)
                    ret.add(node_arc.neighborhood_arc);
            return ret;
        }

        class NodeMissingArcHandlerForIdentityAware : Object
        {
            public NodeMissingArcHandlerForIdentityAware(IIdentityAwareMissingArcHandler identity_missing_handler, IdentityData identity_data)
            {
                this.identity_missing_handler = identity_missing_handler;
                this.identity_data = identity_data;
            }
            private IIdentityAwareMissingArcHandler identity_missing_handler;
            private weak IdentityData identity_data;

            public void missing(INeighborhoodArc arc)
            {
                // from a INeighborhoodArc get a list of identity_arcs
                foreach (IdentityArc ia in identity_data.identity_arcs)
                {
                    IdmgmtArc _ia = (IdmgmtArc)ia.arc;
                    if (_ia.neighborhood_arc == arc)
                    {
                        // each identity_arc in its tasklet:
                        ActOnMissingTasklet ts = new ActOnMissingTasklet();
                        ts.identity_missing_handler = identity_missing_handler;
                        ts.identity_data = identity_data;
                        ts.ia = ia;
                        tasklet.spawn(ts);
                    }
                }
            }

            private class ActOnMissingTasklet : Object, ITaskletSpawnable
            {
                public IIdentityAwareMissingArcHandler identity_missing_handler;
                public IdentityData identity_data;
                public IdentityArc ia;
                public void * func()
                {
                    identity_missing_handler.missing(identity_data, ia);
                    return null;
                }
            }
        }

        /* The instance of this class is created when the stub factory is invoked to
         * obtain a stub for broadcast.
         */
        private class AcknowledgementsCommunicator : Object, IAckCommunicator
        {
            public StubFactory stub_factory;
            public ArrayList<INeighborhoodNetworkInterface> nics;
            public NodeMissingArcHandlerForIdentityAware node_missing_handler;
            public Gee.List<INeighborhoodArc> lst_expected;

            public AcknowledgementsCommunicator(
                                StubFactory stub_factory,
                                Gee.List<INeighborhoodNetworkInterface> nics,
                                NodeMissingArcHandlerForIdentityAware node_missing_handler)
            {
                this.stub_factory = stub_factory;
                this.nics = new ArrayList<INeighborhoodNetworkInterface>();
                this.nics.add_all(nics);
                this.node_missing_handler = node_missing_handler;
                lst_expected = stub_factory.get_current_arcs_for_broadcast(nics);
            }

            public void process_macs_list(Gee.List<string> responding_macs)
            {
                // intersect with current ones now
                Gee.List<INeighborhoodArc> lst_expected_now = stub_factory.get_current_arcs_for_broadcast(nics);
                ArrayList<INeighborhoodArc> lst_expected_intersect = new ArrayList<INeighborhoodArc>();
                foreach (var el in lst_expected)
                    if (el in lst_expected_now)
                        lst_expected_intersect.add(el);
                lst_expected = lst_expected_intersect;
                // prepare a list of missed arcs.
                var lst_missed = new ArrayList<INeighborhoodArc>();
                foreach (INeighborhoodArc expected in lst_expected)
                    if (! (expected.neighbour_mac in responding_macs))
                        lst_missed.add(expected);
                // foreach missed arc launch in a tasklet
                // the 'missing' callback.
                foreach (INeighborhoodArc missed in lst_missed)
                {
                    // each neighborhood_arc in its tasklet:
                    ActOnMissingTasklet ts = new ActOnMissingTasklet();
                    ts.node_missing_handler = node_missing_handler;
                    ts.missed = missed;
                    tasklet.spawn(ts);
                }
            }

            private class ActOnMissingTasklet : Object, ITaskletSpawnable
            {
                public NodeMissingArcHandlerForIdentityAware node_missing_handler;
                public INeighborhoodArc missed;
                public void * func()
                {
                    node_missing_handler.missing(missed);
                    return null;
                }
            }
        }

        /* Get a stub for a whole-node unicast request.
         */
        public IAddressManagerStub
        get_stub_whole_node_unicast(
            INeighborhoodArc arc,
            bool wait_reply=true)
        {
            WholeNodeSourceID source_id = new WholeNodeSourceID(skeleton_factory.node_skeleton.id);
            WholeNodeUnicastID unicast_id = new WholeNodeUnicastID(arc.neighbour_id);
            string dest = arc.neighbour_nic_addr;
            IAddressManagerStub tc = get_addr_tcp_client(dest, ntkd_port, source_id, unicast_id);
            assert(tc is ITcpClientRootStub);
            ((ITcpClientRootStub)tc).wait_reply = wait_reply;
            return tc;
        }

        /* Get a stub for a whole-node broadcast request.
         */
        public IAddressManagerStub
        get_stub_whole_node_broadcast_for_radar(INeighborhoodNetworkInterface nic)
        {
            string local_address = null;
            foreach (HandledNic n in handlednic_list)
            {
                if (n.dev == nic.dev) local_address = n.linklocal;
            }
            assert(local_address != null);
            WholeNodeSourceID source_id = new WholeNodeSourceID(skeleton_factory.node_skeleton.id);
            EveryWholeNodeBroadcastID broadcast_id = new EveryWholeNodeBroadcastID();
            var devs = new ArrayList<string>.wrap({nic.dev});
            var src_ips = new ArrayList<string>.wrap({local_address});
            IAddressManagerStub bc = get_addr_broadcast(devs, src_ips, ntkd_port, source_id, broadcast_id, null);
            return bc;
        }
    }
}
