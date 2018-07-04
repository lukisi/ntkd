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
using Netsukuku.Coordinator;
using TaskletSystem;

namespace Netsukuku
{
    class CoordinatorEvaluateEnterHandler : Object, IEvaluateEnterHandler
    {
        public CoordinatorEvaluateEnterHandler(IdentityData identity_data)
        {
            this.identity_data = identity_data;
        }
        private weak IdentityData identity_data;

        public Object evaluate_enter(int lvl, Object evaluate_enter_data, Gee.List<int> client_address)
        throws HandlingImpossibleError
        {
            return identity_data.hook_mgr.evaluate_enter(evaluate_enter_data, client_address);
        }
    }

    class CoordinatorBeginEnterHandler : Object, IBeginEnterHandler
    {
        public CoordinatorBeginEnterHandler(IdentityData identity_data)
        {
            this.identity_data = identity_data;
        }
        private weak IdentityData identity_data;

        public Object begin_enter(int lvl, Object begin_enter_data, Gee.List<int> client_address)
        throws HandlingImpossibleError
        {
            return identity_data.hook_mgr.begin_enter(lvl, begin_enter_data, client_address);
        }
    }

    class CoordinatorCompletedEnterHandler : Object, ICompletedEnterHandler
    {
        public CoordinatorCompletedEnterHandler(IdentityData identity_data)
        {
            this.identity_data = identity_data;
        }
        private weak IdentityData identity_data;

        public Object completed_enter(int lvl, Object completed_enter_data, Gee.List<int> client_address)
        throws HandlingImpossibleError
        {
            return identity_data.hook_mgr.completed_enter(lvl, completed_enter_data, client_address);
        }
    }

    class CoordinatorAbortEnterHandler : Object, IAbortEnterHandler
    {
        public CoordinatorAbortEnterHandler(IdentityData identity_data)
        {
            this.identity_data = identity_data;
        }
        private weak IdentityData identity_data;

        public Object abort_enter(int lvl, Object abort_enter_data, Gee.List<int> client_address)
        throws HandlingImpossibleError
        {
            return identity_data.hook_mgr.abort_enter(lvl, abort_enter_data, client_address);
        }
    }

    class CoordinatorPropagationHandler : Object, IPropagationHandler
    {
        public CoordinatorPropagationHandler(IdentityData identity_data)
        {
            this.identity_data = identity_data;
        }
        private weak IdentityData identity_data;

        public void prepare_migration(int lvl, Object prepare_migration_data)
        {
            identity_data.hook_mgr.prepare_migration(lvl, prepare_migration_data);
        }

        public void finish_migration(int lvl, Object finish_migration_data)
        {
            identity_data.hook_mgr.finish_migration(lvl, finish_migration_data);
        }

        public void prepare_enter(int lvl, Object prepare_enter_data)
        {
            identity_data.hook_mgr.prepare_enter(lvl, prepare_enter_data);
        }

        public void finish_enter(int lvl, Object finish_enter_data)
        {
            identity_data.hook_mgr.finish_enter(lvl, finish_enter_data);
        }

        public void we_have_splitted(int lvl, Object we_have_splitted_data)
        {
            error("not implemented yet");
        }
    }

    class CoordinatorMap : Object, ICoordinatorMap
    {
        public CoordinatorMap(IdentityData identity_data)
        {
            this.identity_data = identity_data;
        }
        private weak IdentityData identity_data;

        public int get_my_pos(int lvl)
        {
            return identity_data.my_naddr.pos[lvl];
        }

        public bool can_reserve(int lvl)
        {
            if (subnetlevel > lvl) return false;
            if (lvl > levels) return false;
            return true;
        }

        public Gee.List<int> get_free_pos(int lvl)
        {
            if (subnetlevel > lvl)
            {
                warning(@"CoordinatorMap.get_free_pos($(lvl)): This is a gateway for g-node of level $(subnetlevel). Why should Coordinator ask for it?");
                return new ArrayList<int>();
            }
            try {
                Gee.List<HCoord> busy = identity_data.qspn_mgr.get_known_destinations(lvl);
                Gee.List<int> ret = new ArrayList<int>();
                for (int i = 0; i < gsizes[lvl]; i++) ret.add(i);
                foreach (HCoord hc in busy) ret.remove(hc.pos);
                ret.remove(identity_data.my_naddr.pos[lvl]);
                return ret;
            } catch (QspnBootstrapInProgressError e) {
                assert_not_reached();
            }
        }

        public int get_n_nodes()
        {
            try {
                return identity_data.qspn_mgr.get_nodes_inside(levels);
            } catch (QspnBootstrapInProgressError e) {
                assert_not_reached();
            }
        }

        public int64 get_fp_id(int lvl)
        {
            try {
                Fingerprint fp = (Fingerprint)identity_data.qspn_mgr.get_fingerprint(lvl);
                return fp.id;
            } catch (QspnBootstrapInProgressError e) {
                assert_not_reached();
            }
        }
    }

    class CoordinatorStubFactory : Object, IStubFactory
    {
        public CoordinatorStubFactory(IdentityData identity_data)
        {
            this.identity_data = identity_data;
        }
        private weak IdentityData identity_data;

        public ICoordinatorManagerStub get_stub_for_all_neighbors()
        {
            IAddressManagerStub? addrstub = Coordinator.root_stub_broadcast(identity_data);
            if(addrstub == null) return new CoordinatorManagerStubVoid();
            return new CoordinatorManagerStubHolder(addrstub);
        }

        public Gee.List<ICoordinatorManagerStub> get_stub_for_each_neighbor()
        {
            ArrayList<ICoordinatorManagerStub> ret = new ArrayList<ICoordinatorManagerStub>();
            foreach (IdentityArc ia in identity_data.identity_arcs)
            {
                if (ia.qspn_arc != null)
                {
                    ret.add(new CoordinatorManagerStubHolder(Coordinator.root_stub_unicast_from_ia(ia, false)));
                }
            }
            return ret;
        }
    }

    namespace Coordinator
    {
        IAddressManagerStub root_stub_unicast_from_ia(IdentityArc ia, bool wait_reply)
        {
            return neighborhood_mgr.get_stub_identity_aware_unicast(
                ((IdmgmtArc)ia.arc).neighborhood_arc,
                ia.id,  // sourceid
                ia.id_arc.get_peer_nodeid(),  // destid
                wait_reply);
        }

        IAddressManagerStub? root_stub_broadcast(IdentityData identity_data)
        {
            ArrayList<NodeID> broadcast_node_id_set = new ArrayList<NodeID>();
            foreach (IdentityArc ia in identity_data.identity_arcs)
            {
                if (ia.qspn_arc != null)
                    broadcast_node_id_set.add(ia.id_arc.get_peer_nodeid());
            }
            if(broadcast_node_id_set.is_empty) return null;
            NodeID source_node_id = identity_data.nodeid;
            return neighborhood_mgr.get_stub_identity_aware_broadcast(
                source_node_id,
                broadcast_node_id_set,
                null);
        }
    }
}
