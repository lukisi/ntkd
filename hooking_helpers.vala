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
            error("not implemented yet");
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
                // return new HookingManagerStubHolder(addrstub);
                error("not implemented yet");
            } catch (QspnBootstrapInProgressError e) {
                assert_not_reached();
            }
        }

        public Gee.List<IPairHCoordInt> adjacent_to_my_gnode(int level_adjacent_gnodes, int level_my_gnode)
        {
            QspnManager qspn_mgr = identity_data.qspn_mgr;
            while (! qspn_mgr.is_bootstrap_complete()) tasklet.ms_wait(10);
            try {
                error("not implemented yet");
            } catch (QspnBootstrapInProgressError e) {
                assert_not_reached();
            }
        }
    }

    class HookingAdjacentGNode : Object, IPairHCoordInt
    {
        public int my_gnode_lvl {get; private set;}
        public HCoord hc {get; private set;}
        public int border_pos {get; private set;}

        public HookingAdjacentGNode(int my_gnode_lvl, HCoord hc, int border_pos)
        {
            this.my_gnode_lvl = my_gnode_lvl;
            this.hc = hc;
            this.border_pos = border_pos;
        }

        public int get_level_my_gnode()
        {
            return my_gnode_lvl;
        }

        public int get_pos_my_border_gnode()
        {
            return border_pos;
        }

        public HCoord get_hc_adjacent()
        {
            return hc;
        }
    }

    class HookingCoordinator : Object, ICoordinator
    {
        public HookingCoordinator(IdentityData identity_data)
        {
            this.identity_data = identity_data;
        }
        private weak IdentityData identity_data;

        public Object evaluate_enter(int lvl, Object evaluate_enter_data) throws CoordProxyError
        {
            error("not implemented yet");
        }

        public int get_n_nodes()
        {
            error("not implemented yet");
        }

        public void reserve(int host_lvl, int reserve_request_id, out int new_pos, out int new_eldership) throws CoordReserveError
        {
            error("not implemented yet");
        }

        public void delete_reserve(int host_lvl, int reserve_request_id)
        {
            error("not implemented yet");
        }

        public void prepare_migration(/*TODO*/)
        {
            error("not implemented yet");
        }

        public void finish_migration(/*TODO*/)
        {
            error("not implemented yet");
        }
    }
}
