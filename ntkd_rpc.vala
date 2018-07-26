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
                    ret.add(main_id.identity_skeleton);
                    return ret;
                }
                StubFactory f = new StubFactory();
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
                StubFactory f = new StubFactory();
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
            // member qspn_mgr of identity_data is QspnManager, which is a IQspnManagerSkeleton
            if (identity_data.qspn_mgr == null)
            {
                print(@"IdentitySkeleton.qspn_manager_getter: id $(identity_data.nodeid.id) has qspn_mgr NULL. Might be too early, wait a bit.\n");
                bool once_more = true; int wait_next = 5;
                while (once_more)
                {
                    once_more = false;
                    if (identity_data.qspn_mgr == null)
                    {
                        //  let's wait a bit and try again a few times.
                        if (wait_next < 3000) {
                            wait_next = wait_next * 10; tasklet.ms_wait(wait_next); once_more = true;
                        }
                    }
                    else
                    {
                        print(@"IdentitySkeleton.qspn_manager_getter: id $(identity_data.nodeid.id) now has qspn_mgr valid.\n");
                    }
                }
            }
            if (identity_data.qspn_mgr == null)
            {
                print(@"IdentitySkeleton.qspn_manager_getter: id $(identity_data.nodeid.id) has qspn_mgr NULL yet. Might be too late, abort responding.\n");
                tasklet.exit_tasklet(null);
            }
            return identity_data.qspn_mgr;
        }

        public unowned IPeersManagerSkeleton
        peers_manager_getter()
        {
            // member peers_mgr of identity_data is PeersManager, which is a IPeersManagerSkeleton
            if (identity_data.peers_mgr == null)
            {
                print(@"IdentitySkeleton.peers_manager_getter: id $(identity_data.nodeid.id) has peers_mgr NULL. Might be too early, wait a bit.\n");
                bool once_more = true; int wait_next = 5;
                while (once_more)
                {
                    once_more = false;
                    if (identity_data.peers_mgr == null)
                    {
                        //  let's wait a bit and try again a few times.
                        if (wait_next < 3000) {
                            wait_next = wait_next * 10; tasklet.ms_wait(wait_next); once_more = true;
                        }
                    }
                    else
                    {
                        print(@"IdentitySkeleton.peers_manager_getter: id $(identity_data.nodeid.id) now has peers_mgr valid.\n");
                    }
                }
            }
            if (identity_data.peers_mgr == null)
            {
                print(@"IdentitySkeleton.peers_manager_getter: id $(identity_data.nodeid.id) has peers_mgr NULL. Not bootstrapped? abort responding.\n");
                // Probably is a call to broadcast.
                tasklet.exit_tasklet(null);
            }
            return identity_data.peers_mgr;
        }

        public unowned ICoordinatorManagerSkeleton
        coordinator_manager_getter()
        {
            // member coord_mgr of identity_data is CoordinatorManager, which is a ICoordinatorManagerSkeleton
            return identity_data.coord_mgr;
        }

        public unowned IHookingManagerSkeleton
        hooking_manager_getter()
        {
            // member hook_mgr of identity_data is HookingManager, which is a IHookingManagerSkeleton
            return identity_data.hook_mgr;
        }

        /* TODO in ntkdrpc
        public unowned IAndnaManagerSkeleton
        andna_manager_getter()
        {
            // member andna_mgr of identity_data is AndnaManager, which is a IAndnaManagerSkeleton
            return identity_data.andna_mgr;
        }
        */
    }

    /* A skeleton for the whole-node remotable methods
     */
    class NodeSkeleton : Object, IAddressManagerSkeleton
    {
        public NodeSkeleton(NeighborhoodNodeID id)
        {
            this.id = id;
        }
        public NeighborhoodNodeID id {get; private set;}

        public unowned INeighborhoodManagerSkeleton
        neighborhood_manager_getter()
        {
            // global var neighborhood_mgr is NeighborhoodManager, which is a INeighborhoodManagerSkeleton
            return neighborhood_mgr;
        }

        protected unowned IIdentityManagerSkeleton
        identity_manager_getter()
        {
            // global var identity_mgr is IdentityManager, which is a IIdentityManagerSkeleton
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

        public unowned IHookingManagerSkeleton
        hooking_manager_getter()
        {
            warning("NodeSkeleton.hooking_manager_getter: not for node");
            tasklet.exit_tasklet(null);
        }

        /* TODO in ntkdrpc
        public unowned IAndnaManagerSkeleton
        andna_manager_getter()
        {
            warning("NodeSkeleton.andna_manager_getter: not for node");
            tasklet.exit_tasklet(null);
        }
        */
    }

    NodeSkeleton node_skeleton;

    IAddressManagerSkeleton?
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

    Gee.List<IAddressManagerSkeleton>
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
