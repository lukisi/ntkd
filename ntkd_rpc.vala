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
using Netsukuku.Coordinator;
using Netsukuku.Hooking;
using Netsukuku.Andna;
using TaskletSystem;

namespace Netsukuku
{
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
                if (unicastid is PeersUnicastID)
                {
                    IdentityData main_id = null;
                    foreach (IdentityData identity_data in local_identities)
                    {
                        if (identity_data.main_id)
                        {
                            main_id = identity_data;
                            break;
                        }
                    }
                    assert(main_id != null);
                    ret.add(main_id.identity_skeleton);
                    return ret;
                }
                IAddressManagerSkeleton? d = neighborhood_mgr.get_dispatcher(sourceid, unicastid, peer_address, null);
                if (d != null) ret.add(d);
                return ret;
            }
            else if (caller is UnicastCallerInfo)
            {
                UnicastCallerInfo c = (UnicastCallerInfo)caller;
                string peer_address = c.peer_address;
                string dev = c.dev;
                ISourceID sourceid = c.sourceid;
                IUnicastID unicastid = c.unicastid;
                var ret = new ArrayList<IAddressManagerSkeleton>();
                IAddressManagerSkeleton? d = neighborhood_mgr.get_dispatcher(sourceid, unicastid, peer_address, dev);
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
                return neighborhood_mgr.get_dispatcher_set(sourceid, broadcastid, peer_address, dev);
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

    /* A skeleton for the identity remotable methods
     */
    class IdentitySkeleton : Object, IAddressManagerSkeleton
    {
        public IdentitySkeleton(IdentityData identity_data)
        {
            this.identity_data = identity_data;
        }

        private weak IdentityData identity_data;

        public unowned INeighborhoodManagerSkeleton
        neighborhood_manager_getter()
        {
            warning("IdentitySkeleton.neighborhood_manager_getter: not for identity");
            tasklet.exit_tasklet(null);
        }

        protected unowned IIdentityManagerSkeleton
        identity_manager_getter()
        {
            warning("IdentitySkeleton.identity_manager_getter: not for identity");
            tasklet.exit_tasklet(null);
        }

        public unowned IQspnManagerSkeleton
        qspn_manager_getter()
        {
            // member qspn_mgr of identity_data is a IQspnManagerSkeleton
            return identity_data.qspn_mgr;
        }

        public unowned IPeersManagerSkeleton
        peers_manager_getter()
        {
            // member peers_mgr of identity_data is a IPeersManagerSkeleton
            return identity_data.peers_mgr;
        }

        public unowned ICoordinatorManagerSkeleton
        coordinator_manager_getter()
        {
            error("not implemented yet");
        }
    }

    /* A skeleton for the whole-node remotable methods
     */
    class NodeSkeleton : Object, IAddressManagerSkeleton
    {
        public unowned INeighborhoodManagerSkeleton
        neighborhood_manager_getter()
        {
            // global var neighborhood_mgr is a INeighborhoodManagerSkeleton
            return neighborhood_mgr;
        }

        protected unowned IIdentityManagerSkeleton
        identity_manager_getter()
        {
            // global var identity_mgr is a IIdentityManagerSkeleton
            return identity_mgr;
        }

        public unowned IQspnManagerSkeleton
        qspn_manager_getter()
        {
            warning("NodeSkeleton.qspn_manager_getter: not for node");
            tasklet.exit_tasklet(null);
        }

        public unowned IPeersManagerSkeleton
        peers_manager_getter()
        {
            warning("NodeSkeleton.peers_manager_getter: not for node");
            tasklet.exit_tasklet(null);
        }

        public unowned ICoordinatorManagerSkeleton
        coordinator_manager_getter()
        {
            warning("NodeSkeleton.coordinator_manager_getter: not for node");
            tasklet.exit_tasklet(null);
        }
    }

    class IdentityManagerStubHolder : Object, IIdentityManagerStub
    {
        public IdentityManagerStubHolder(IAddressManagerStub addr)
        {
            this.addr = addr;
        }
        private IAddressManagerStub addr;

        public IIdentityID get_peer_main_id()
        throws StubError, DeserializeError
        {
            return addr.identity_manager.get_peer_main_id();
        }

        public IDuplicationData? match_duplication
        (int migration_id, IIdentityID peer_id, IIdentityID old_id,
        IIdentityID new_id, string old_id_new_mac, string old_id_new_linklocal)
        throws StubError, DeserializeError
        {
            return addr.identity_manager.match_duplication
                (migration_id, peer_id, old_id,
                 new_id, old_id_new_mac, old_id_new_linklocal);
        }

        public void notify_identity_arc_removed(IIdentityID peer_id, IIdentityID my_id)
        throws StubError, DeserializeError
        {
            addr.identity_manager.notify_identity_arc_removed(peer_id, my_id);
        }
    }

    class QspnManagerStubHolder : Object, IQspnManagerStub
    {
        public QspnManagerStubHolder(IAddressManagerStub addr)
        {
            this.addr = addr;
        }
        private IAddressManagerStub addr;

        public IQspnEtpMessage get_full_etp(IQspnAddress requesting_address)
        throws QspnNotAcceptedError, QspnBootstrapInProgressError, StubError, DeserializeError
        {
            return addr.qspn_manager.get_full_etp(requesting_address);
        }

        public void got_destroy()
        throws StubError, DeserializeError
        {
            addr.qspn_manager.got_destroy();
        }

        public void got_prepare_destroy()
        throws StubError, DeserializeError
        {
            addr.qspn_manager.got_prepare_destroy();
        }

        public void send_etp(IQspnEtpMessage etp, bool is_full)
        throws QspnNotAcceptedError, StubError, DeserializeError
        {
            addr.qspn_manager.send_etp(etp, is_full);
        }
    }

    class QspnManagerStubVoid : Object, IQspnManagerStub
    {
        public IQspnEtpMessage get_full_etp(IQspnAddress requesting_address)
        throws QspnNotAcceptedError, QspnBootstrapInProgressError, StubError, DeserializeError
        {
            assert_not_reached();
        }

        public void got_destroy()
        throws StubError, DeserializeError
        {
        }

        public void got_prepare_destroy()
        throws StubError, DeserializeError
        {
        }

        public void send_etp(IQspnEtpMessage etp, bool is_full)
        throws QspnNotAcceptedError, StubError, DeserializeError
        {
        }
    }

    class PeersManagerStubHolder : Object, IPeersManagerStub
    {
        public PeersManagerStubHolder(IAddressManagerStub addr)
        {
            this.addr = addr;
        }
        private IAddressManagerStub addr;

        public IPeerParticipantSet ask_participant_maps() throws StubError, DeserializeError
        {
            return addr.peers_manager.ask_participant_maps();
        }

        public void forward_peer_message(IPeerMessage peer_message) throws StubError, DeserializeError
        {
            addr.peers_manager.forward_peer_message(peer_message);
        }

        public IPeersRequest get_request(int msg_id, IPeerTupleNode respondant)
        throws PeersUnknownMessageError, PeersInvalidRequest, StubError, DeserializeError
        {
            return addr.peers_manager.get_request(msg_id, respondant);
        }

        public void give_participant_maps(IPeerParticipantSet maps) throws StubError, DeserializeError
        {
            addr.peers_manager.give_participant_maps(maps);
        }

        public void set_failure(int msg_id, IPeerTupleGNode tuple) throws StubError, DeserializeError
        {
            addr.peers_manager.set_failure(msg_id, tuple);
        }

        public void set_missing_optional_maps(int msg_id) throws StubError, DeserializeError
        {
            addr.peers_manager.set_missing_optional_maps(msg_id);
        }

        public void set_next_destination(int msg_id, IPeerTupleGNode tuple) throws StubError, DeserializeError
        {
            addr.peers_manager.set_next_destination(msg_id, tuple);
        }

        public void set_non_participant(int msg_id, IPeerTupleGNode tuple) throws StubError, DeserializeError
        {
            addr.peers_manager.set_non_participant(msg_id, tuple);
        }

        public void set_participant(int p_id, IPeerTupleGNode tuple) throws StubError, DeserializeError
        {
            addr.peers_manager.set_participant(p_id, tuple);
        }

        public void set_redo_from_start(int msg_id, IPeerTupleNode respondant) throws StubError, DeserializeError
        {
            addr.peers_manager.set_redo_from_start(msg_id, respondant);
        }

        public void set_refuse_message(int msg_id, string refuse_message, int e_lvl, IPeerTupleNode respondant) throws StubError, DeserializeError
        {
            addr.peers_manager.set_refuse_message(msg_id, refuse_message, e_lvl, respondant);
        }

        public void set_response(int msg_id, IPeersResponse response, IPeerTupleNode respondant) throws StubError, DeserializeError
        {
            addr.peers_manager.set_response(msg_id, response, respondant);
        }
    }

    class PeersManagerStubVoid : Object, IPeersManagerStub
    {
        public IPeerParticipantSet ask_participant_maps() throws StubError, DeserializeError
        {
            assert_not_reached();
        }

        public void forward_peer_message(IPeerMessage peer_message) throws StubError, DeserializeError
        {
        }

        public IPeersRequest get_request(int msg_id, IPeerTupleNode respondant)
        throws PeersUnknownMessageError, PeersInvalidRequest, StubError, DeserializeError
        {
            assert_not_reached();
        }

        public void give_participant_maps(IPeerParticipantSet maps) throws StubError, DeserializeError
        {
        }

        public void set_failure(int msg_id, IPeerTupleGNode tuple) throws StubError, DeserializeError
        {
        }

        public void set_missing_optional_maps(int msg_id) throws StubError, DeserializeError
        {
        }

        public void set_next_destination(int msg_id, IPeerTupleGNode tuple) throws StubError, DeserializeError
        {
        }

        public void set_non_participant(int msg_id, IPeerTupleGNode tuple) throws StubError, DeserializeError
        {
        }

        public void set_participant(int p_id, IPeerTupleGNode tuple) throws StubError, DeserializeError
        {
        }

        public void set_redo_from_start(int msg_id, IPeerTupleNode respondant) throws StubError, DeserializeError
        {
        }

        public void set_refuse_message(int msg_id, string refuse_message, int e_lvl, IPeerTupleNode respondant) throws StubError, DeserializeError
        {
        }

        public void set_response(int msg_id, IPeersResponse response, IPeerTupleNode respondant) throws StubError, DeserializeError
        {
        }
    }
}
