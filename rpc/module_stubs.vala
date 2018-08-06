/*
 *  This file is part of Netsukuku.
 *  Copyright (C) 2017-2018 Luca Dionisi aka lukisi <luca.dionisi@gmail.com>
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
    class NeighborhoodManagerStubHolder : Object, INeighborhoodManagerStub
    {
        public NeighborhoodManagerStubHolder(IAddressManagerStub addr)
        {
            this.addr = addr;
        }
        private IAddressManagerStub addr;

        public bool can_you_export(bool i_can_export)
        throws StubError, DeserializeError
        {
            return addr.neighborhood_manager.can_you_export(i_can_export);
        }

        public void here_i_am(INeighborhoodNodeIDMessage my_id, string my_mac, string my_nic_addr)
        throws StubError, DeserializeError
        {
            addr.neighborhood_manager.here_i_am(my_id, my_mac, my_nic_addr);
        }

        public void nop()
        throws StubError, DeserializeError
        {
            addr.neighborhood_manager.nop();
        }

        public void remove_arc
        (INeighborhoodNodeIDMessage your_id, string your_mac, string your_nic_addr,
        INeighborhoodNodeIDMessage my_id, string my_mac, string my_nic_addr)
        throws StubError, DeserializeError
        {
            addr.neighborhood_manager.remove_arc(your_id, your_mac, your_nic_addr,
                my_id, my_mac, my_nic_addr);
        }

        public void request_arc(INeighborhoodNodeIDMessage your_id, string your_mac, string your_nic_addr,
        INeighborhoodNodeIDMessage my_id, string my_mac, string my_nic_addr)
        throws StubError, DeserializeError
        {
            addr.neighborhood_manager.request_arc(your_id, your_mac, your_nic_addr,
                my_id, my_mac, my_nic_addr);
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
        public weak INeighborhoodArc neighborhood_arc;

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

    class CoordinatorManagerStubHolder : Object, ICoordinatorManagerStub
    {
        public CoordinatorManagerStubHolder(IAddressManagerStub addr)
        {
            this.addr = addr;
        }
        private IAddressManagerStub addr;

        public void execute_prepare_migration(ICoordTupleGNode tuple, int64 fp_id, int propagation_id, int lvl, ICoordObject prepare_migration_data)
        throws StubError, DeserializeError
        {
            addr.coordinator_manager.execute_prepare_migration(tuple, fp_id, propagation_id, lvl, prepare_migration_data);
        }

        public void execute_finish_migration(ICoordTupleGNode tuple, int64 fp_id, int propagation_id, int lvl, ICoordObject finish_migration_data)
        throws StubError, DeserializeError
        {
            addr.coordinator_manager.execute_finish_migration(tuple, fp_id, propagation_id, lvl, finish_migration_data);
        }

        public void execute_prepare_enter(ICoordTupleGNode tuple, int64 fp_id, int propagation_id, int lvl, ICoordObject prepare_enter_data)
        throws StubError, DeserializeError
        {
            addr.coordinator_manager.execute_prepare_enter(tuple, fp_id, propagation_id, lvl, prepare_enter_data);
        }

        public void execute_finish_enter(ICoordTupleGNode tuple, int64 fp_id, int propagation_id, int lvl, ICoordObject finish_enter_data)
        throws StubError, DeserializeError
        {
            addr.coordinator_manager.execute_finish_enter(tuple, fp_id, propagation_id, lvl, finish_enter_data);
        }

        public void execute_we_have_splitted(ICoordTupleGNode tuple, int64 fp_id, int propagation_id, int lvl, ICoordObject we_have_splitted_data)
        throws StubError, DeserializeError
        {
            addr.coordinator_manager.execute_we_have_splitted(tuple, fp_id, propagation_id, lvl, we_have_splitted_data);
        }
    }

    class CoordinatorManagerStubVoid : Object, ICoordinatorManagerStub
    {
        public void execute_prepare_migration(ICoordTupleGNode tuple, int64 fp_id, int propagation_id, int lvl, ICoordObject prepare_migration_data)
        throws StubError, DeserializeError
        {
        }

        public void execute_finish_migration(ICoordTupleGNode tuple, int64 fp_id, int propagation_id, int lvl, ICoordObject finish_migration_data)
        throws StubError, DeserializeError
        {
        }

        public void execute_prepare_enter(ICoordTupleGNode tuple, int64 fp_id, int propagation_id, int lvl, ICoordObject prepare_enter_data)
        throws StubError, DeserializeError
        {
        }

        public void execute_finish_enter(ICoordTupleGNode tuple, int64 fp_id, int propagation_id, int lvl, ICoordObject finish_enter_data)
        throws StubError, DeserializeError
        {
        }

        public void execute_we_have_splitted(ICoordTupleGNode tuple, int64 fp_id, int propagation_id, int lvl, ICoordObject we_have_splitted_data)
        throws StubError, DeserializeError
        {
        }
    }

    class HookingManagerStubHolder : Object, IHookingManagerStub
    {
        public HookingManagerStubHolder(IAddressManagerStub addr)
        {
            this.addr = addr;
        }
        private IAddressManagerStub addr;

        public INetworkData retrieve_network_data(bool ask_coord)
        throws HookingNotPrincipalError, StubError, DeserializeError
        {
            return addr.hooking_manager.retrieve_network_data(ask_coord);
        }

        public IEntryData search_migration_path(int lvl)
        throws NoMigrationPathFoundError, MigrationPathExecuteFailureError, StubError, DeserializeError
        {
            return addr.hooking_manager.search_migration_path(lvl);
        }

        public void
        route_delete_reserve_request(Netsukuku.IDeleteReservationRequest p0)
        throws StubError, DeserializeError
        {
            addr.hooking_manager.route_delete_reserve_request(p0);
        }

        public void
        route_explore_request(Netsukuku.IExploreGNodeRequest p0)
        throws StubError, DeserializeError
        {
            addr.hooking_manager.route_explore_request(p0);
        }

        public void
        route_explore_response(Netsukuku.IExploreGNodeResponse p1)
        throws StubError, DeserializeError
        {
            addr.hooking_manager.route_explore_response(p1);
        }

        public void
        route_mig_request(Netsukuku.IRequestPacket p0)
        throws StubError, DeserializeError
        {
            addr.hooking_manager.route_mig_request(p0);
        }

        public void
        route_mig_response(Netsukuku.IResponsePacket p1)
        throws StubError, DeserializeError
        {
            addr.hooking_manager.route_mig_response(p1);
        }

        public void
        route_search_error(Netsukuku.ISearchMigrationPathErrorPkt p2)
        throws StubError, DeserializeError
        {
            addr.hooking_manager.route_search_error(p2);
        }

        public void
        route_search_request(Netsukuku.ISearchMigrationPathRequest p0)
        throws StubError, DeserializeError
        {
            addr.hooking_manager.route_search_request(p0);
        }

        public void
        route_search_response(Netsukuku.ISearchMigrationPathResponse p1)
        throws StubError, DeserializeError
        {
            addr.hooking_manager.route_search_response(p1);
        }
    }
}
