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
using Netsukuku.Hooking;
using Netsukuku.Qspn;
using Netsukuku.Coordinator;
using TaskletSystem;

namespace Netsukuku
{
    class HookingIdentityArc : Object, IIdentityArc
    {
        public HookingIdentityArc(IdentityArc ia)
        {
            this.ia = ia;
        }
        public weak IdentityArc ia;

        public IHookingManagerStub get_stub()
        {
            IAddressManagerStub addrstub = root_stub_unicast_from_ia(ia, true);
            return new HookingManagerStubHolder(addrstub);
        }
    }

    class HookingMapPaths : Object, IHookingMapPaths
    {
        public HookingMapPaths(IdentityData identity_data)
        {
            this.identity_data = identity_data;
        }
        private weak IdentityData identity_data;

        public int64 get_network_id()
        {
            QspnManager qspn_mgr = identity_data.qspn_mgr;
            while (! qspn_mgr.is_bootstrap_complete()) tasklet.ms_wait(10);
            Fingerprint fp_levels;
            try {
                fp_levels = (Fingerprint)qspn_mgr.get_fingerprint(levels);
            } catch (QspnBootstrapInProgressError e) {
                assert_not_reached();
            }
            return fp_levels.id;
        }

        public int get_levels()
        {
            return levels;
        }

        public int get_gsize(int level)
        {
            return gsizes[level];
        }

        public int get_epsilon(int level)
        {
            return hooking_epsilon[level];
        }

        public int get_n_nodes()
        {
            QspnManager qspn_mgr = identity_data.qspn_mgr;
            while (! qspn_mgr.is_bootstrap_complete()) tasklet.ms_wait(10);
            try {
                return qspn_mgr.get_nodes_inside(levels);
            } catch (QspnBootstrapInProgressError e) {
                assert_not_reached();
            }
        }

        public int get_my_pos(int level)
        {
            Naddr my_naddr = identity_data.my_naddr;
            return my_naddr.pos[level];
        }

        public int get_my_eldership(int level)
        {
            Fingerprint my_fp = identity_data.my_fp;
            return my_fp.elderships[level];
        }

        public int get_subnetlevel()
        {
            return subnetlevel;
        }

        public bool exists(int level, int pos)
        {
            QspnManager qspn_mgr = identity_data.qspn_mgr;
            while (! qspn_mgr.is_bootstrap_complete()) tasklet.ms_wait(10);
            try {
                return qspn_mgr.is_known_destination(new HCoord(level, pos));
            } catch (QspnBootstrapInProgressError e) {
                assert_not_reached();
            }
        }

        public int get_eldership(int level, int pos)
        {
            // requires: exists(int level, int pos) == true
            QspnManager qspn_mgr = identity_data.qspn_mgr;
            while (! qspn_mgr.is_bootstrap_complete()) tasklet.ms_wait(10);
            try {
                IQspnFingerprint _fp = qspn_mgr.get_fingerprint_of_known_destination(new HCoord(level, pos));
                Fingerprint fp = (Fingerprint)_fp;
                return fp.elderships[0];
            } catch (QspnBootstrapInProgressError e) {
                assert_not_reached();
            }
        }

        public IHookingManagerStub gateway(int level, int pos)
        {
            // requires: exists(int level, int pos) == true
            QspnManager qspn_mgr = identity_data.qspn_mgr;
            while (! qspn_mgr.is_bootstrap_complete()) tasklet.ms_wait(10);
            try {
                Gee.List<IQspnNodePath> paths = qspn_mgr.get_paths_to(new HCoord(level, pos));
                assert(! paths.is_empty);
                IQspnNodePath best_path = paths[0];
                QspnArc gw_qspn_arc = (QspnArc)best_path.i_qspn_get_arc();
                // find gw_ia by gw_qspn_arc, otherwise error.
                IdentityArc? gw_ia = null;
                foreach (IdentityArc _ia in identity_data.identity_arcs) if (_ia.qspn_arc == gw_qspn_arc)
                {
                    gw_ia = _ia;
                    break;
                }
                assert (gw_ia != null);
                IAddressManagerStub addrstub = root_stub_unicast_from_ia(gw_ia, false);
                return new HookingManagerStubHolder(addrstub);
            } catch (QspnBootstrapInProgressError e) {
                assert_not_reached();
            }
        }

        private class HookingAdjacentGNode : Object, IPairHCoordInt
        {
            public HookingAdjacentGNode(int level_my_gnode, HCoord hc_adjacent, int pos_my_border_gnode)
            {
                this.hc_adjacent = hc_adjacent;
                this.level_my_gnode = level_my_gnode;
                this.pos_my_border_gnode = pos_my_border_gnode;
            }
            private int level_my_gnode;
            private HCoord hc_adjacent;
            private int pos_my_border_gnode;

            public int get_level_my_gnode()
            {
                return level_my_gnode;
            }

            public HCoord get_hc_adjacent()
            {
                return hc_adjacent;
            }

            public int get_pos_my_border_gnode()
            {
                return pos_my_border_gnode;
            }
        }
        public Gee.List<IPairHCoordInt> adjacent_to_my_gnode(int level_adjacent_gnodes, int level_my_gnode)
        {
            QspnManager qspn_mgr = identity_data.qspn_mgr;
            while (! qspn_mgr.is_bootstrap_complete()) tasklet.ms_wait(10);
            try {
                assert(level_adjacent_gnodes >= level_my_gnode);
                // Find g-nodes of level level_adjacent_gnodes in my next-higher g-node.
                Gee.List<HCoord> existing_gnodes = qspn_mgr.get_known_destinations(level_adjacent_gnodes);
                ArrayList<IPairHCoordInt> ret = new ArrayList<IPairHCoordInt>();
                foreach (HCoord hc in existing_gnodes)
                {
                    // Is hc adjacent to my g-node of level level_my_gnode?
                    IQspnNodePath p = qspn_mgr.get_paths_to(hc)[0];
                    Gee.List<IQspnHop> hops = p.i_qspn_get_hops();
                    // We must save last intermediate hop of level level_my_gnode-1
                    HCoord border_gnode = new HCoord(level_my_gnode-1, get_my_pos(level_my_gnode-1));
                    bool adj = true;
                    foreach (IQspnHop hop in hops)
                    {
                        HCoord hop_hc = hop.i_qspn_get_hcoord();
                        if (hop_hc.equals(hc)) break; // for each hop but last.
                        if (hop_hc.lvl == level_my_gnode-1)
                        {
                            border_gnode = hop_hc;
                        }
                        if (hop_hc.lvl >= level_my_gnode)
                        {
                            // not adjacent.
                            adj = false;
                            break;
                        }
                    }
                    if (! adj) break;
                    // It is adjacent. Is my border_gnode not virtual?
                    if (border_gnode.pos >= gsizes[level_my_gnode-1]) break;
                    // All ok.
                    ret.add(new HookingAdjacentGNode(level_my_gnode, hc, border_gnode.pos));
                }
                return ret;
            } catch (QspnBootstrapInProgressError e) {
                assert_not_reached();
            }
        }
    }

    class HookingCoordinator : Object, ICoordinator
    {
        public HookingCoordinator(IdentityData identity_data)
        {
            this.identity_data = identity_data;
        }
        private weak IdentityData identity_data;

        public int get_n_nodes()
        {
            return identity_data.coord_mgr.get_n_nodes();
        }

        public Object evaluate_enter(Object evaluate_enter_data) throws CoordProxyError
        {
            Object ret;
            try {
                ret = identity_data.coord_mgr.evaluate_enter(levels, evaluate_enter_data);
            } catch (Coordinator.ProxyError e) {
                throw new CoordProxyError.GENERIC(@"Coordinator.ProxyError: $(e.message)");
            }
            return ret;
        }

        public Object get_hooking_memory(int lvl) throws CoordProxyError
        {
            Object ret;
            try {
                ret = identity_data.coord_mgr.get_hooking_memory(lvl);
            } catch (Coordinator.ProxyError e) {
                throw new CoordProxyError.GENERIC(@"Coordinator.ProxyError: $(e.message)");
            } catch (Coordinator.NotCoordinatorNodeError e) {
                throw new CoordProxyError.GENERIC(@"Coordinator.NotCoordinatorNodeError: $(e.message)");
            }
            return ret;
        }

        public void set_hooking_memory(int lvl, Object memory) throws CoordProxyError
        {
            try {
                identity_data.coord_mgr.set_hooking_memory(lvl, memory);
            } catch (Coordinator.ProxyError e) {
                throw new CoordProxyError.GENERIC(@"Coordinator.ProxyError: $(e.message)");
            } catch (Coordinator.NotCoordinatorNodeError e) {
                throw new CoordProxyError.GENERIC(@"Coordinator.NotCoordinatorNodeError: $(e.message)");
            }
        }

        public Object begin_enter(int lvl, Object begin_enter_data) throws CoordProxyError
        {
            Object ret;
            try {
                ret = identity_data.coord_mgr.begin_enter(lvl, begin_enter_data);
            } catch (Coordinator.ProxyError e) {
                throw new CoordProxyError.GENERIC(@"Coordinator.ProxyError: $(e.message)");
            }
            return ret;
        }

        public Object completed_enter(int lvl, Object completed_enter_data) throws CoordProxyError
        {
            Object ret;
            try {
                ret = identity_data.coord_mgr.completed_enter(lvl, completed_enter_data);
            } catch (Coordinator.ProxyError e) {
                throw new CoordProxyError.GENERIC(@"Coordinator.ProxyError: $(e.message)");
            }
            return ret;
        }

        public Object abort_enter(int lvl, Object abort_enter_data) throws CoordProxyError
        {
            Object ret;
            try {
                ret = identity_data.coord_mgr.abort_enter(lvl, abort_enter_data);
            } catch (Coordinator.ProxyError e) {
                throw new CoordProxyError.GENERIC(@"Coordinator.ProxyError: $(e.message)");
            }
            return ret;
        }

        public void prepare_enter(int lvl, Object prepare_enter_data)
        {
            identity_data.coord_mgr.prepare_enter(lvl, prepare_enter_data);
        }

        public void finish_enter(int lvl, Object finish_enter_data)
        {
            identity_data.coord_mgr.finish_enter(lvl, finish_enter_data);
        }

        public void reserve(int host_lvl, int reserve_request_id, out int new_pos, out int new_eldership) throws CoordReserveError
        {
            try {
                Reservation ret = identity_data.coord_mgr.reserve(host_lvl, reserve_request_id);
                new_pos = ret.new_pos;
                new_eldership = ret.new_eldership;
            } catch (ReserveError e) {
                throw new CoordReserveError.GENERIC(@"$(e.message)");
            }
        }

        public void delete_reserve(int host_lvl, int reserve_request_id)
        {
            identity_data.coord_mgr.delete_reserve(host_lvl, reserve_request_id);
        }

        public void prepare_migration(int lvl, Object prepare_migration_data)
        {
            identity_data.coord_mgr.prepare_migration(lvl, prepare_migration_data);
        }

        public void finish_migration(int lvl, Object finish_migration_data)
        {
            identity_data.coord_mgr.finish_migration(lvl, finish_migration_data);
        }
    }
}
