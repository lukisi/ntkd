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
        public NeighborhoodNodeID id;

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
}
