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
    class ServerDelegate : Object, IRpcDelegate
    {
        public ServerDelegate(SkeletonFactory skeleton_factory)
        {
            this.skeleton_factory = skeleton_factory;
        }
        private SkeletonFactory skeleton_factory;

        public Gee.List<IAddressManagerSkeleton> get_addr_set(CallerInfo caller)
        {
            if (caller is TcpclientCallerInfo)
            {
                TcpclientCallerInfo c = (TcpclientCallerInfo)caller;
                string peer_address = c.peer_address;
                ISourceID sourceid = c.sourceid;
                IUnicastID unicastid = c.unicastid;
                var ret = new ArrayList<IAddressManagerSkeleton>();
                IAddressManagerSkeleton? d = skeleton_factory.get_dispatcher(sourceid, unicastid, peer_address);
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
                return skeleton_factory.get_dispatcher_set(sourceid, broadcastid, peer_address, dev);
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

    const uint16 ntkd_port = 60269;

    class SkeletonFactory : Object
    {
        public SkeletonFactory()
        {
            this.node_skeleton = new NodeSkeleton();
            dlg = new ServerDelegate(this);
            err = new ServerErrorHandler();
        }

        public NodeSkeleton node_skeleton {get; private set;}
        public ServerDelegate dlg;
        public ServerErrorHandler err;


        // DEPRECATED
        public ITaskletHandle start_tcp_listen()
        {
            return tcp_listen(dlg, err, ntkd_port);
        }

        // DEPRECATED
        public ITaskletHandle start_udp_listen(string dev)
        {
            return udp_listen(dlg, err, ntkd_port, dev);
        }


        public void start_stream_ip_listen(string ip)
        {
            error("not implemented yet");
            /*
            In ntkdrpc there will be a function stream_ip_listen(ip,tcp_port)
            Will do:
            handles_by_ip[ip] = stream_ip_listen(dlg, err, ip, ntkd_port);
            */
        }

        public void stop_stream_ip_listen(string ip)
        {
            error("not implemented yet");
            /*
            Will do:
            ITaskletHandle th = handles_by_ip[ip];
            th.kill();
            */
        }

        public void start_stream_pathname_listen(string pathname)
        {
            error("not implemented yet");
            /*
            In ntkdrpc there will be a function stream_pathname_listen(pathname)
            Will do:
            handles_by_pathname[pathname] = stream_pathname_listen(dlg, err, pathname);
            */
        }

        public void stop_stream_pathname_listen(string pathname)
        {
            error("not implemented yet");
            /*
            Will do:
            ITaskletHandle th = handles_by_pathname[pathname];
            th.kill();
            */
        }

        public void start_datagram_nic_listen(string dev)
        {
            error("not implemented yet");
            /*
            In ntkdrpc there will be a function datagram_nic_listen(dev,udp_port)
            Will do:
            handles_by_dev[dev] = datagram_nic_listen(dlg, err, dev, ntkd_port);
            */
        }

        public void stop_datagram_nic_listen(string dev)
        {
            error("not implemented yet");
            /*
            Will do:
            ITaskletHandle th = handles_by_dev[dev];
            th.kill();
            */
        }

        public void start_datagram_pathname_listen(string pseudodev)
        {
            error("not implemented yet");
            /*
            In ntkdrpc there will be a function datagram_pathname_listen(pseudodev)
            Si mette in ascolto di datagram sul pathname recv_<pid>_<pseudodev>.
            Se ne riceve trasmette ACK sul pathname send_<pid>_<pseudodev>.
            Will do:
            handles_by_pseudodev[pseudodev] = stream_pathname_listen(dlg, err, pathname);
            */
        }

        public void stop_datagram_pathname_listen(string pseudodev)
        {
            error("not implemented yet");
            /*
            Will do:
            ITaskletHandle th = handles_by_pseudodev[pseudodev];
            th.kill();
            */
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
            if (_unicast_id is MainIdentityUnicastID)
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

        /* Get dev name where a received message has transited. For broadcast requests of any kind.
         */
        public string?
        from_caller_get_mydev(CallerInfo _rpc_caller)
        {
            if (_rpc_caller is BroadcastCallerInfo)
            {
                BroadcastCallerInfo rpc_caller = (BroadcastCallerInfo)_rpc_caller;
                return rpc_caller.dev;
            }
            return null;
        }


        /* Get NodeArc where a received message has transited. For whole-node requests.
         */
        public NodeArc?
        from_caller_get_nodearc(CallerInfo rpc_caller)
        {
            NeighborhoodNodeID peer_node_id;
            string peer_address;
            string my_dev;
            if (rpc_caller is TcpclientCallerInfo)
            {
                TcpclientCallerInfo tcp = (TcpclientCallerInfo)rpc_caller;
                ISourceID _source_id = tcp.sourceid;
                if (! (_source_id is WholeNodeSourceID)) return null;
                peer_node_id = ((WholeNodeSourceID)_source_id).id;
                peer_address = tcp.peer_address;
                string my_address = tcp.my_address;
                my_dev = null;
                foreach (HandledNic n in handlednic_list) if (n.linklocal == my_address) my_dev = n.dev;
                if (my_dev == null) return null;
            }
            else
            {
                // unexpected class.
                return null;
            }
            foreach (NodeArc node_arc in arc_list)
            {
                INeighborhoodArc neighborhood_arc = node_arc.neighborhood_arc;
                // check my_dev
                if (neighborhood_arc.nic.dev != my_dev) continue;
                // check peer_address
                if (neighborhood_arc.neighbour_nic_addr != peer_address) continue;
                // check peer_node_id
                if (neighborhood_arc.neighbour_id.equals(peer_node_id)) return node_arc;
            }
            return null;
        }

        /* Get IdentityArc where a received message has transited. For identity-aware requests.
         */
        public IdentityArc?
        from_caller_get_identityarc(CallerInfo rpc_caller, IdentityData identity_data)
        {
            NodeID peer_identity_id;
            string peer_address;
            string my_dev;
            if (rpc_caller is TcpclientCallerInfo)
            {
                TcpclientCallerInfo tcp = (TcpclientCallerInfo)rpc_caller;
                ISourceID _source_id = tcp.sourceid;
                if (! (_source_id is IdentityAwareSourceID)) return null;
                peer_identity_id = ((IdentityAwareSourceID)_source_id).id;
                peer_address = tcp.peer_address;
                string my_address = tcp.my_address;
                my_dev = null;
                foreach (HandledNic n in handlednic_list) if (n.linklocal == my_address) my_dev = n.dev;
                if (my_dev == null) return null;
            }
            else if (rpc_caller is BroadcastCallerInfo)
            {
                BroadcastCallerInfo brd = (BroadcastCallerInfo)rpc_caller;
                ISourceID _source_id = brd.sourceid;
                if (! (_source_id is IdentityAwareSourceID)) return null;
                peer_identity_id = ((IdentityAwareSourceID)_source_id).id;
                peer_address = brd.peer_address;
                my_dev = brd.dev;
            }
            else
            {
                // unexpected class.
                return null;
            }
            foreach (IdentityArc ia in identity_data.identity_arcs)
            {
                // get where ia is laid upon.
                IdmgmtArc _arc = (IdmgmtArc)ia.arc;
                INeighborhoodArc neighborhood_arc = _arc.neighborhood_arc;
                // check my_dev
                if (neighborhood_arc.nic.dev != my_dev) continue;
                // check peer_address
                if (neighborhood_arc.neighbour_nic_addr != peer_address) continue;
                // check peer_identity_id
                if (ia.id_arc.get_peer_nodeid().equals(peer_identity_id)) return ia;
            }
            return null;
        }
    }
}
