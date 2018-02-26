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
    void per_identity_qspn_arc_removed(IdentityData id, IQspnArc arc, bool bad_link)
    {
        warning("per_identity_qspn_arc_removed: not implemented yet");
    }

    void per_identity_qspn_changed_fp(IdentityData id, int l)
    {
        warning("per_identity_qspn_changed_fp: not implemented yet");
    }

    void per_identity_qspn_changed_nodes_inside(IdentityData id, int l)
    {
        warning("per_identity_qspn_changed_nodes_inside: not implemented yet");
    }

    void per_identity_qspn_destination_added(IdentityData id, HCoord h)
    {
        warning("per_identity_qspn_destination_added: not implemented yet");
    }

    void per_identity_qspn_destination_removed(IdentityData id, HCoord h)
    {
        warning("per_identity_qspn_destination_removed: not implemented yet");
    }

    void per_identity_qspn_gnode_splitted(IdentityData id, IQspnArc a, HCoord d, IQspnFingerprint fp)
    {
        error("per_identity_qspn_gnode_splitted: not implemented yet");
    }

    void per_identity_qspn_path_added(IdentityData id, IQspnNodePath p)
    {
        per_identity_qspn_map_update(id, p);
    }

    void per_identity_qspn_path_changed(IdentityData id, IQspnNodePath p)
    {
        per_identity_qspn_map_update(id, p);
    }

    void per_identity_qspn_path_removed(IdentityData id, IQspnNodePath p)
    {
        per_identity_qspn_map_update(id, p);
    }

    void per_identity_qspn_map_update(IdentityData id, IQspnNodePath p)
    {
        HCoord hc = p.i_qspn_get_hops().last().i_qspn_get_hcoord();
        if (hc in id.dest_ip_set.gnode.keys)
        {
            QspnManager qspn_mgr = (QspnManager)identity_mgr.get_identity_module(id.nodeid, "qspn");
            try {
                qspn_mgr.get_paths_to(hc);
            } catch (QspnBootstrapInProgressError e) {
                id.bootstrap_phase_pending_updates.add(hc);
                return;
            }
            UpdateGraph.update_destination(id, hc);
        }
    }

    void per_identity_qspn_presence_notified(IdentityData id)
    {
        warning("per_identity_qspn_presence_notified: not implemented yet");
    }

    void per_identity_qspn_qspn_bootstrap_complete(IdentityData id)
    {
        QspnManager qspn_mgr = (QspnManager)identity_mgr.get_identity_module(id.nodeid, "qspn");
        Fingerprint fp_levels;
        try {
            fp_levels = (Fingerprint)qspn_mgr.get_fingerprint(levels);
        } catch (QspnBootstrapInProgressError e) {
            assert_not_reached();
        }
        print(@"per_identity_qspn_qspn_bootstrap_complete: my id $(id.nodeid.id) is in network_id $(fp_levels.id).\n");
        foreach (HCoord hc in id.bootstrap_phase_pending_updates) UpdateGraph.update_destination(id, hc);
    }

    void per_identity_qspn_remove_identity(IdentityData id)
    {
        error("per_identity_qspn_remove_identity: not implemented yet");
    }
}

