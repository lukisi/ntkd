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

    class AddressManagerForIdentity : Object, IAddressManagerSkeleton
    {
        public unowned INeighborhoodManagerSkeleton
        neighborhood_manager_getter()
        {
            warning("AddressManagerForIdentity.neighborhood_manager_getter: not for identity");
            tasklet.exit_tasklet(null);
        }

        protected unowned IIdentityManagerSkeleton
        identity_manager_getter()
        {
            warning("AddressManagerForIdentity.identity_manager_getter: not for identity");
            tasklet.exit_tasklet(null);
        }

        public unowned IQspnManagerSkeleton
        qspn_manager_getter()
        {
            error("not implemented yet");
        }

        public unowned IPeersManagerSkeleton
        peers_manager_getter()
        {
            error("not implemented yet");
        }

        public unowned ICoordinatorManagerSkeleton
        coordinator_manager_getter()
        {
            error("not implemented yet");
        }
    }

    class AddressManagerForNode : Object, IAddressManagerSkeleton
    {
        public weak INeighborhoodManagerSkeleton neighborhood_mgr;
        public weak IIdentityManagerSkeleton identity_mgr;

        public unowned INeighborhoodManagerSkeleton
        neighborhood_manager_getter()
        {
            return neighborhood_mgr;
        }

        protected unowned IIdentityManagerSkeleton
        identity_manager_getter()
        {
            return identity_mgr;
        }

        public unowned IQspnManagerSkeleton
        qspn_manager_getter()
        {
            warning("AddressManagerForNode.qspn_manager_getter: not for node");
            tasklet.exit_tasklet(null);
        }

        public unowned IPeersManagerSkeleton
        peers_manager_getter()
        {
            warning("AddressManagerForNode.peers_manager_getter: not for node");
            tasklet.exit_tasklet(null);
        }

        public unowned ICoordinatorManagerSkeleton
        coordinator_manager_getter()
        {
            warning("AddressManagerForNode.coordinator_manager_getter: not for node");
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
}
