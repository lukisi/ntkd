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
using TaskletSystem;

namespace Netsukuku
{
    class QspnStubFactory : Object, IQspnStubFactory
    {
        public QspnStubFactory(IdentityData identity_data)
        {
            this.identity_data = identity_data;
        }
        private weak IdentityData identity_data;

        public IQspnManagerStub
                        i_qspn_get_broadcast(
                            Gee.List<IQspnArc> arcs,
                            IQspnMissingArcHandler? missing_handler=null
                        )
        {
            if(arcs.is_empty) return new QspnManagerStubVoid();
            ArrayList<NodeID> broadcast_node_id_set = new ArrayList<NodeID>();
            foreach (IQspnArc arc in arcs)
            {
                QspnArc _arc = (QspnArc)arc;
                broadcast_node_id_set.add(_arc.destid);
            }
            MissingArcHandlerForQspn? identity_missing_handler = null;
            if (missing_handler != null)
            {
                identity_missing_handler = new MissingArcHandlerForQspn(missing_handler);
            }
            StubFactory f = new StubFactory();
            IAddressManagerStub addrstub = f.get_stub_identity_aware_broadcast(
                identity_data,
                broadcast_node_id_set,
                identity_missing_handler);
            QspnManagerStubHolder ret = new QspnManagerStubHolder(addrstub);
            return ret;
        }

        public IQspnManagerStub
                        i_qspn_get_tcp(
                            IQspnArc arc,
                            bool wait_reply=true
                        )
        {
            QspnArc _arc = (QspnArc)arc;
            IdentityArc ia = _arc.ia;
            StubFactory f = new StubFactory();
            IAddressManagerStub addrstub = f.get_stub_identity_aware_unicast_from_ia(ia, wait_reply);
            QspnManagerStubHolder ret = new QspnManagerStubHolder(addrstub);
            return ret;
        }
    }

    class MissingArcHandlerForQspn : Object, IIdentityAwareMissingArcHandler
    {
        public MissingArcHandlerForQspn(IQspnMissingArcHandler qspn_missing)
        {
            this.qspn_missing = qspn_missing;
        }
        private IQspnMissingArcHandler? qspn_missing;

        public void missing(IdentityData identity_data, IdentityArc identity_arc)
        {
            if (identity_arc.qspn_arc != null)
            {
                // identity_arc is on this network
                qspn_missing.i_qspn_missing(identity_arc.qspn_arc);
            }
        }
    }

    class ThresholdCalculator : Object, IQspnThresholdCalculator
    {
        public int i_qspn_calculate_threshold(IQspnNodePath p1, IQspnNodePath p2)
        {
            return 10000;
        }
    }

    class QspnArc : Object, IQspnArc
    {
        public QspnArc(NodeID sourceid, NodeID destid, IdentityArc ia)
        {
            this.sourceid = sourceid;
            this.destid = destid;
            this.ia = ia;
            cost_seed = PRNGen.int_range(0, 1000);
            arc = (IdmgmtArc)ia.arc;
        }
        public weak IdmgmtArc arc;
        public NodeID sourceid;
        public NodeID destid;
        public weak IdentityArc ia;
        private int cost_seed;

        public IQspnCost i_qspn_get_cost()
        {
            return new Cost(arc.neighborhood_arc.cost + cost_seed);
        }

        public bool i_qspn_equals(IQspnArc other)
        {
            return other == this;
        }

        public bool i_qspn_comes_from(CallerInfo rpc_caller)
        {
            SkeletonFactory f = new SkeletonFactory();
            return destid.equals(f.from_caller_get_identity(rpc_caller));
        }
    }

    // For IQspnNaddr, IQspnMyNaddr, IQspnCost, IQspnFingerprint see Naddr, Cost, Fingerprint in serializables.vala
}

