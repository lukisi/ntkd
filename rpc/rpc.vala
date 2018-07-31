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

/** This file should contain code relative to RPC
    that is independent from the API specified in ntkdrpc.
 */

namespace Netsukuku
{
    // Server side

    class ServerDelegate : Object, IRpcDelegate
    {
        public Gee.List<IAddressManagerSkeleton> get_addr_set(CallerInfo caller)
        {
            if (caller is TcpclientCallerInfo)
            {
                TcpclientCallerInfo c = (TcpclientCallerInfo)caller;
                string peer_address = c.peer_address;
                ISourceID sourceid = c.sourceid;
                IUnicastID unicastid = c.unicastid;
                var ret = new ArrayList<IAddressManagerSkeleton>();
                SkeletonFactory f = new SkeletonFactory();
                IAddressManagerSkeleton? d = f.get_dispatcher(sourceid, unicastid, peer_address);
                if (d != null) ret.add(d);
                return ret;
            }
            else if (caller is BroadcastCallerInfo)
            {
                BroadcastCallerInfo c = (BroadcastCallerInfo)caller;
                string peer_address = c.peer_address;
                string dev = c.dev;
                ISourceID sourceid = c.sourceid;
                IBroadcastID broadcastid = c.broadcastid;
                SkeletonFactory f = new SkeletonFactory();
                return f.get_dispatcher_set(sourceid, broadcastid, peer_address, dev);
            }
            else
            {
                error(@"Unexpected class $(caller.get_type().name())");
            }
        }
    }

    class ServerErrorHandler : Object, IRpcErrorHandler
    {
        public void error_handler(Error e)
        {
            error(@"error_handler: $(e.message)");
        }
    }

    class SkeletonFactory : Object
    {
        public SkeletonFactory()
        {
        }

        /* Get root-dispatcher if the received message is to be processed.
         */
        public IAddressManagerSkeleton?
        get_dispatcher(
            ISourceID _source_id,
            IUnicastID _unicast_id,
            string peer_address)
        {
            if (_unicast_id is IdentityAwareUnicastID)
            {
                IdentityAwareUnicastID unicast_id = (IdentityAwareUnicastID)_unicast_id;
                if (! (_source_id is IdentityAwareSourceID)) return null;
                IdentityAwareSourceID source_id = (IdentityAwareSourceID)_source_id;
                NodeID identity_aware_unicast_id = unicast_id.id;
                NodeID identity_aware_source_id = source_id.id;
                return get_identity_skeleton(identity_aware_source_id, identity_aware_unicast_id, peer_address);
            }
            if (_unicast_id is WholeNodeUnicastID)
            {
                if (! (_source_id is WholeNodeSourceID)) return null;
                WholeNodeSourceID source_id = (WholeNodeSourceID)_source_id;
                NeighborhoodNodeID whole_node_source_id = source_id.id;
                foreach (NodeArc arc in arc_list)
                {
                    if (arc.neighborhood_arc.neighbour_nic_addr == peer_address &&
                            arc.neighborhood_arc.neighbour_id.equals(whole_node_source_id)) return node_skeleton;
                }
                return null;
            }
            if (_unicast_id is PeersUnicastID)
            {
                IdentityData main_id = null;
                while (main_id == null)
                {
                    foreach (IdentityData identity_data in local_identities)
                    {
                        if (identity_data.main_id)
                        {
                            main_id = identity_data;
                            break;
                        }
                    }
                    if (main_id == null) tasklet.ms_wait(5); // avoid rare (but possible) temporary condition.
                }
                return main_id.identity_skeleton;
            }
            warning(@"Unknown IUnicastID class $(_unicast_id.get_type().name())");
            return null;
        }

        /* Get root-dispatchers if the received message is to be processed.
         */
        public Gee.List<IAddressManagerSkeleton>
        get_dispatcher_set(
            ISourceID _source_id,
            IBroadcastID _broadcast_id,
            string peer_address,
            string dev)
        {
            // If it is a radar scan, accept.
            if (_broadcast_id is EveryWholeNodeBroadcastID)
            {
                Gee.List<IAddressManagerSkeleton> ret = new ArrayList<IAddressManagerSkeleton>();
                ret.add(node_skeleton);
                return ret;
            }
            // If it's not a radar scan and there's not an arc, refuse.
            INeighborhoodArc? i = null;
            foreach (NodeArc arc in arc_list)
            {
                if (arc.neighborhood_arc.neighbour_nic_addr == peer_address && arc.neighborhood_arc.nic.dev == dev)
                {
                    i = arc.neighborhood_arc;
                    break;
                }
            }
            if (i == null) return new ArrayList<IAddressManagerSkeleton>();
            // There's an arc. It must be an identity-aware broadcast message.
            if (_broadcast_id is IdentityAwareBroadcastID)
            {
                IdentityAwareBroadcastID broadcast_id = (IdentityAwareBroadcastID)_broadcast_id;
                if (! (_source_id is IdentityAwareSourceID)) return new ArrayList<IAddressManagerSkeleton>();
                IdentityAwareSourceID source_id = (IdentityAwareSourceID)_source_id;
                Gee.List<NodeID> identity_aware_broadcast_set = broadcast_id.id_set;
                NodeID identity_aware_source_id = source_id.id;
                return get_identity_skeleton_set
                    (identity_aware_source_id,
                    identity_aware_broadcast_set,
                    peer_address,
                    dev);
            }
            return new ArrayList<IAddressManagerSkeleton>();
        }

        public static NodeSkeleton node_skeleton;

        private IAddressManagerSkeleton?
        get_identity_skeleton(
            NodeID source_id,
            NodeID unicast_id,
            string peer_address)
        {
            foreach (IdentityData local_identity_data in local_identities)
            {
                NodeID local_nodeid = local_identity_data.nodeid;
                if (local_nodeid.equals(unicast_id))
                {
                    foreach (IdentityArc ia in local_identity_data.identity_arcs)
                    {
                        IdmgmtArc _arc = (IdmgmtArc)ia.arc;
                        if (_arc.neighborhood_arc.neighbour_nic_addr == peer_address)
                        {
                            if (ia.id_arc.get_peer_nodeid().equals(source_id))
                            {
                                return local_identity_data.identity_skeleton;
                            }
                        }
                    }
                }
            }
            return null;
        }

        private Gee.List<IAddressManagerSkeleton>
        get_identity_skeleton_set(
            NodeID source_id,
            Gee.List<NodeID> broadcast_set,
            string peer_address,
            string dev)
        {
            ArrayList<IAddressManagerSkeleton> ret = new ArrayList<IAddressManagerSkeleton>();
            foreach (IdentityData local_identity_data in local_identities)
            {
                NodeID local_nodeid = local_identity_data.nodeid;
                if (local_nodeid in broadcast_set)
                {
                    foreach (IdentityArc ia in local_identity_data.identity_arcs)
                    {
                        IdmgmtArc _arc = (IdmgmtArc)ia.arc;
                        if (_arc.neighborhood_arc.neighbour_nic_addr == peer_address
                            && _arc.neighborhood_arc.nic.dev == dev)
                        {
                            if (ia.id_arc.get_peer_nodeid().equals(source_id))
                            {
                                ret.add(local_identity_data.identity_skeleton);
                            }
                        }
                    }
                }
            }
            return ret;
        }

        /* Get NodeID for the source of a received message. For identity-aware requests.
         */
        public NodeID
        from_caller_get_identity(CallerInfo rpc_caller)
        {
            // This method should be called by a identity module
            if (rpc_caller is TcpclientCallerInfo)
            {
                TcpclientCallerInfo tcp = (TcpclientCallerInfo)rpc_caller;
                ISourceID _source_id = tcp.sourceid;
                if (! (_source_id is IdentityAwareSourceID)) tasklet.exit_tasklet(null); // ignore message.
                IdentityAwareSourceID source_id = (IdentityAwareSourceID)_source_id;
                return source_id.id;
            }
            else if (rpc_caller is BroadcastCallerInfo)
            {
                BroadcastCallerInfo brd = (BroadcastCallerInfo)rpc_caller;
                ISourceID _source_id = brd.sourceid;
                if (! (_source_id is IdentityAwareSourceID)) tasklet.exit_tasklet(null); // ignore message.
                IdentityAwareSourceID source_id = (IdentityAwareSourceID)_source_id;
                return source_id.id;
            }
            else
            {
                // unexpected class. ignore message.
                tasklet.exit_tasklet(null);
            }
        }

        /* Get the arc for the source of a received message. For whole-node requests.
         */
        public INeighborhoodArc?
        from_caller_get_node_arc(CallerInfo rpc_caller)
        {
            if (rpc_caller is TcpclientCallerInfo)
            {
                TcpclientCallerInfo c = (TcpclientCallerInfo)rpc_caller;
                ISourceID sourceid = c.sourceid;
                string my_address = c.my_address;
                foreach (HandledNic n in handlednic_list) if (n.linklocal == my_address)
                {
                    string dev = n.dev;
                    return get_node_arc(sourceid, dev);
                }
                warning(@"from_caller_get_node_arc: got a unknown caller: my_address was $(my_address).\n");
                foreach (HandledNic n in handlednic_list)
                {
                    string dev = n.dev;
                    print(@"  in $(dev) we have $(n.linklocal).\n");
                }
                return null;
            }
            warning(@"from_caller_get_node_arc: not a expected type of caller $(rpc_caller.get_type().name()).");
            return null;
        }

        private INeighborhoodArc?
        get_node_arc(
            ISourceID _source_id,
            string dev)
        {
            if (! (_source_id is WholeNodeSourceID)) return null;
            WholeNodeSourceID source_id = (WholeNodeSourceID)_source_id;
            NeighborhoodNodeID whole_node_source_id = source_id.id;
            INeighborhoodArc? i = null;
            foreach (NodeArc arc in arc_list)
            {
                if (arc.neighborhood_arc.neighbour_id.equals(whole_node_source_id) && arc.neighborhood_arc.nic.dev == dev)
                {
                    i = arc.neighborhood_arc;
                    break;
                }
            }
            return i;
        }
    }

    // Client side

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
        get_stub_identity_aware_unicast_inside_gnode(
            Gee.List<int> positions,
            IdentityData identity_data, // TODO use it in ZCD
            bool wait_reply=true)
        {
            ArrayList<int> n_addr = new ArrayList<int>();
            n_addr.add_all(positions);
            int inside_level = n_addr.size;
            for (int i = inside_level; i < levels; i++) n_addr.add(0);
            string dest = ip_internal_node(n_addr, inside_level);
            ISourceID source_id = new PeersSourceID();
            IUnicastID unicast_id = new PeersUnicastID();
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
                NeighborhoodMissingArcHandlerForIdentityAware neighborhood_missing_handler
                    = new NeighborhoodMissingArcHandlerForIdentityAware(identity_missing_handler, identity_data);
                Gee.List<INeighborhoodArc> lst_expected = get_current_arcs_for_broadcast(nics);
                ack_com = new NeighborhoodAcknowledgementsCommunicator(this, nics, neighborhood_missing_handler, lst_expected);
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

        class NeighborhoodMissingArcHandlerForIdentityAware : Object, INeighborhoodMissingArcHandler
        {
            public NeighborhoodMissingArcHandlerForIdentityAware(IIdentityAwareMissingArcHandler identity_missing_handler, IdentityData identity_data)
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
        private class NeighborhoodAcknowledgementsCommunicator : Object, IAckCommunicator
        {
            public StubFactory stub_factory;
            public ArrayList<INeighborhoodNetworkInterface> nics;
            public INeighborhoodMissingArcHandler neighborhood_missing_handler;
            public ArrayList<INeighborhoodArc> lst_expected;

            public NeighborhoodAcknowledgementsCommunicator(
                                StubFactory stub_factory,
                                Gee.List<INeighborhoodNetworkInterface> nics,
                                INeighborhoodMissingArcHandler neighborhood_missing_handler,
                                Gee.List<INeighborhoodArc> lst_expected)
            {
                this.stub_factory = stub_factory;
                this.nics = new ArrayList<INeighborhoodNetworkInterface>();
                this.nics.add_all(nics);
                this.neighborhood_missing_handler = neighborhood_missing_handler;
                this.lst_expected = new ArrayList<INeighborhoodArc>();
                this.lst_expected.add_all(lst_expected);
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
                    ts.neighborhood_missing_handler = neighborhood_missing_handler;
                    ts.missed = missed;
                    tasklet.spawn(ts);
                }
            }

            private class ActOnMissingTasklet : Object, ITaskletSpawnable
            {
                public INeighborhoodMissingArcHandler neighborhood_missing_handler;
                public INeighborhoodArc missed;
                public void * func()
                {
                    neighborhood_missing_handler.missing(missed);
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
            WholeNodeSourceID source_id = new WholeNodeSourceID(SkeletonFactory.node_skeleton.id);
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
            WholeNodeSourceID source_id = new WholeNodeSourceID(SkeletonFactory.node_skeleton.id);
            EveryWholeNodeBroadcastID broadcast_id = new EveryWholeNodeBroadcastID();
            var devs = new ArrayList<string>.wrap({nic.dev});
            var src_ips = new ArrayList<string>.wrap({local_address});
            IAddressManagerStub bc = get_addr_broadcast(devs, src_ips, ntkd_port, source_id, broadcast_id, null);
            return bc;
        }
    }
}
