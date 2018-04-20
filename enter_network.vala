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
using Netsukuku;
using Netsukuku.Neighborhood;
using Netsukuku.Identities;
using Netsukuku.Qspn;
using Netsukuku.Coordinator;
using Netsukuku.Hooking;
using Netsukuku.Andna;
using TaskletSystem;

namespace Netsukuku.EnterNetwork
{
    void prepare_enter(int enter_id, IdentityData old_identity_data)
    {
        // Prepare duplication.
        identity_mgr.prepare_add_identity(enter_id, old_identity_data.nodeid);
    }

    IdentityData enter(int enter_id, IdentityData old_identity_data, int64 enter_into_network_id,
        int guest_gnode_level, int go_connectivity_position,
        Gee.List<int> new_gnode_positions,
        Gee.List<int> new_gnode_elderships)
    {
        int host_gnode_level = levels - (new_gnode_positions.size - 1);
        // Duplicate.
        NodeID new_nodeid = identity_mgr.add_identity(enter_id, old_identity_data.nodeid);
        IdentityData new_identity_data = find_or_create_local_identity(new_nodeid);
        new_identity_data.copy_of_identity = old_identity_data;
        new_identity_data.connectivity_from_level = old_identity_data.connectivity_from_level;
        new_identity_data.connectivity_to_level = old_identity_data.connectivity_to_level;
        old_identity_data.connectivity_from_level = guest_gnode_level + 1;
        old_identity_data.connectivity_to_level = levels; // after enter, the old id will be dismissed soon anyway.

        // Associate id-arcs of old and new identity.
        Gee.List<IdentityArcPair> arcpairs = new ArrayList<IdentityArcPair>();
        foreach (IdentityArc w0 in old_identity_data.identity_arcs)
        {
            bool old_identity_arc_changed_peer_mac = (w0.prev_peer_mac != null);
            // find appropriate w1
            foreach (IdentityArc w1 in new_identity_data.identity_arcs)
            {
                if (w1.arc != w0.arc) continue;
                if (old_identity_arc_changed_peer_mac)
                {
                    if (w1.peer_mac != w0.prev_peer_mac) continue;
                }
                else
                {
                    if (w1.peer_mac != w0.peer_mac) continue;
                }
                arcpairs.add(new IdentityArcPair(w0, w1));
                break;
            }
        }

        // discriminate id-arcs
        Gee.List<IdentityArcPair> prev_arcpairs = new ArrayList<IdentityArcPair>();
        Gee.List<IdentityArcPair> new_arcpairs = new ArrayList<IdentityArcPair>();
        Gee.List<IdentityArcPair> both_arcpairs = new ArrayList<IdentityArcPair>();
        foreach (IdentityArcPair arcpair in arcpairs)
        {
            if (arcpair.old_id_arc.qspn_arc != null)
            {
                // the old peer was in same network as old_id
                // we still have to check if it was participating to the entering
                if (arcpair.old_id_arc.prev_peer_mac != null)
                {
                    // the peer participates to the entering: the new peer will be in same network as new_id
                    both_arcpairs.add(arcpair);
                }
                else
                {
                    // the peer won't be in same network as new_id
                    prev_arcpairs.add(arcpair);
                }
            }
            else
            {
                // the peer wasn't in same network as old_id
                if (arcpair.old_id_arc.network_id == enter_into_network_id)
                {
                    // the peer will be in same network as new_id
                    new_arcpairs.add(arcpair);
                }
            }
        }

        // Old identity will become of connectivity and so will change its
        //  address and elderships. The call to `make_connectivity` must be done after the
        //  creation of new identity with `enter_net`. But the data
        //  structure IdentityData will be changed now in order to use
        //  in 'enter_another_network_commands' function.
        bool prev_was_main = old_identity_data.main_id;
        Naddr old_naddr = old_identity_data.my_naddr;
        Fingerprint old_fp = old_identity_data.my_fp;

        ArrayList<int> _naddr_temp = new ArrayList<int>();
        _naddr_temp.add_all(old_identity_data.my_naddr.pos);
        _naddr_temp[guest_gnode_level] = go_connectivity_position;
        old_identity_data.my_naddr = new Naddr(_naddr_temp.to_array(), gsizes.to_array());

        enter_another_network_commands(old_identity_data, new_identity_data,
            guest_gnode_level, old_naddr, old_fp,
            new_gnode_positions,
            new_gnode_elderships,
            prev_arcpairs, new_arcpairs, both_arcpairs);

        QspnManager old_qspn = (QspnManager)identity_mgr.get_identity_module(old_identity_data.nodeid, "qspn");
        QspnManager new_qspn =
            enter_another_network_qspn(old_identity_data, new_identity_data,
            old_qspn,
            guest_gnode_level, go_connectivity_position,
            host_gnode_level,
            prev_arcpairs, new_arcpairs, both_arcpairs);
        if (prev_was_main) old_identity_data.gone_connectivity();

        // soon after creation, connect to signals.
        new_qspn.arc_removed.connect(new_identity_data.arc_removed);
        new_qspn.changed_fp.connect(new_identity_data.changed_fp);
        new_qspn.changed_nodes_inside.connect(new_identity_data.changed_nodes_inside);
        new_qspn.destination_added.connect(new_identity_data.destination_added);
        new_qspn.destination_removed.connect(new_identity_data.destination_removed);
        new_qspn.gnode_splitted.connect(new_identity_data.gnode_splitted);
        new_qspn.path_added.connect(new_identity_data.path_added);
        new_qspn.path_changed.connect(new_identity_data.path_changed);
        new_qspn.path_removed.connect(new_identity_data.path_removed);
        new_qspn.presence_notified.connect(new_identity_data.presence_notified);
        new_qspn.qspn_bootstrap_complete.connect(new_identity_data.qspn_bootstrap_complete);
        new_qspn.remove_identity.connect(new_identity_data.remove_identity);
        identity_mgr.set_identity_module(new_nodeid, "qspn", new_qspn);
        new_identity_data.qspn_mgr = new_qspn;  // weak ref

        // prepare for operations on bootstrap_complete
        new_identity_data.on_bootstrap_complete_do_create_peers_manager = true;
        new_identity_data.on_bootstrap_complete_create_peers_manager_prev_peers_mgr = old_identity_data.peers_mgr;
        new_identity_data.on_bootstrap_complete_create_peers_manager_guest_gnode_level = guest_gnode_level;
        new_identity_data.on_bootstrap_complete_create_peers_manager_host_gnode_level = host_gnode_level;

        // CoordinatorManager
        CoordinatorManager coord_mgr = new CoordinatorManager(gsizes,
            new CoordinatorEvaluateEnterHandler(new_identity_data),
            new CoordinatorBeginEnterHandler(new_identity_data),
            new CoordinatorCompletedEnterHandler(new_identity_data),
            new CoordinatorAbortEnterHandler(new_identity_data),
            new CoordinatorPropagationHandler(new_identity_data),
            new CoordinatorStubFactory(new_identity_data),
            guest_gnode_level,
            host_gnode_level,
            old_identity_data.coord_mgr);
        identity_mgr.set_identity_module(new_nodeid, "coordinator", coord_mgr);
        new_identity_data.coord_mgr = coord_mgr;  // weak ref

        // HookingManager
        HookingManager hook_mgr = new HookingManager();
        identity_mgr.set_identity_module(new_nodeid, "hooking", hook_mgr);
        new_identity_data.hook_mgr = hook_mgr;  // weak ref
        // immediately after creation, connect to signals.
        hook_mgr.same_network.connect((_ia) =>
            per_identity_hooking_same_network(new_identity_data, _ia));
        hook_mgr.another_network.connect((_ia, network_id) =>
            per_identity_hooking_another_network(new_identity_data, _ia, network_id));
        hook_mgr.do_prepare_migration.connect(() =>
            per_identity_hooking_do_prepare_migration(new_identity_data));
        hook_mgr.do_finish_migration.connect(() =>
            per_identity_hooking_do_finish_migration(new_identity_data));
        hook_mgr.do_prepare_enter.connect((enter_id) =>
            per_identity_hooking_do_prepare_enter(new_identity_data, enter_id));
        hook_mgr.do_finish_enter.connect((enter_id, guest_gnode_level, entry_data, go_connectivity_position) =>
            per_identity_hooking_do_finish_enter(new_identity_data, enter_id, guest_gnode_level, entry_data, go_connectivity_position));

        // AndnaManager  TODO
        AndnaManager andna_mgr = new AndnaManager();
        identity_mgr.set_identity_module(new_nodeid, "andna", andna_mgr);
        new_identity_data.andna_mgr = andna_mgr;  // weak ref

        foreach (IdentityArc ia in old_identity_data.identity_arcs)
        {
            ia.prev_peer_mac = null;
            ia.prev_peer_linklocal = null;
        }

        // remove old identity.
        old_qspn.destroy();
        old_qspn.arc_removed.disconnect(old_identity_data.arc_removed);
        old_qspn.changed_fp.disconnect(old_identity_data.changed_fp);
        old_qspn.changed_nodes_inside.disconnect(old_identity_data.changed_nodes_inside);
        old_qspn.destination_added.disconnect(old_identity_data.destination_added);
        old_qspn.destination_removed.disconnect(old_identity_data.destination_removed);
        old_qspn.gnode_splitted.disconnect(old_identity_data.gnode_splitted);
        old_qspn.path_added.disconnect(old_identity_data.path_added);
        old_qspn.path_changed.disconnect(old_identity_data.path_changed);
        old_qspn.path_removed.disconnect(old_identity_data.path_removed);
        old_qspn.presence_notified.disconnect(old_identity_data.presence_notified);
        old_qspn.qspn_bootstrap_complete.disconnect(old_identity_data.qspn_bootstrap_complete);
        old_qspn.remove_identity.disconnect(old_identity_data.remove_identity);
        identity_mgr.remove_identity(old_identity_data.nodeid);
        old_identity_data.qspn_handlers_disabled = true;
        old_qspn.stop_operations();
        remove_local_identity(old_identity_data.nodeid);

        return new_identity_data;
    }

    void enter_another_network_commands(IdentityData old_id, IdentityData new_id,
        int guest_gnode_level, Naddr old_naddr, Fingerprint old_fp,
        Gee.List<int> new_gnode_positions,
        Gee.List<int> new_gnode_elderships,
        Gee.List<IdentityArcPair> prev_arcpairs, Gee.List<IdentityArcPair> new_arcpairs, Gee.List<IdentityArcPair> both_arcpairs)
    {
        assert(new_gnode_positions.size == new_gnode_elderships.size);
        int host_gnode_level = levels - (new_gnode_positions.size - 1);
        assert(guest_gnode_level >= 0);
        assert(guest_gnode_level < host_gnode_level);

        int old_id_prev_lvl = guest_gnode_level;
        int old_id_prev_pos = old_naddr.pos[old_id_prev_lvl];

        LocalIPSet? prev_local_ip_set = null;
        if (new_id.main_id) prev_local_ip_set = old_id.local_ip_set.copy();
        DestinationIPSet prev_dest_ip_set = old_id.dest_ip_set.copy();

        ArrayList<int> pos = new ArrayList<int>();
        pos.add_all(new_gnode_positions);
        for (int i = host_gnode_level-2; i >= 0; i--)
            pos.insert(0, old_naddr.pos[i]);
        Naddr new_naddr = new Naddr(pos.to_array(), gsizes.to_array());
        ArrayList<int> elderships = new ArrayList<int>();
        elderships.add_all(new_gnode_elderships);
        for (int i = host_gnode_level-2; i >= 0; i--)
            elderships.insert(0, old_fp.elderships[i]);
        Fingerprint new_fp = new Fingerprint(elderships.to_array(), old_fp.id);
        new_id.my_naddr = new_naddr;
        new_id.my_fp = new_fp;

        if (new_id.main_id) IpCompute.new_main_id(new_id);
        IpCompute.new_id(new_id);
        IpCompute.gone_connectivity_id(old_id, old_id_prev_lvl, old_id_prev_pos);

        Gee.List<string> old_id_peermacs = new ArrayList<string>();
        foreach (IdentityArcPair prev_arcpair in prev_arcpairs)
            old_id_peermacs.add(prev_arcpair.old_id_arc.peer_mac);
        foreach (IdentityArcPair both_arcpair in both_arcpairs)
            old_id_peermacs.add(both_arcpair.old_id_arc.peer_mac);
        IpCommands.gone_connectivity(old_id, old_id_peermacs);

        Gee.List<string> prev_peermacs = new ArrayList<string>();
        foreach (IdentityArcPair prev_arcpair in prev_arcpairs)
            prev_peermacs.add(prev_arcpair.new_id_arc.peer_mac);
        Gee.List<string> new_peermacs = new ArrayList<string>();
        foreach (IdentityArcPair new_arcpair in new_arcpairs)
            new_peermacs.add(new_arcpair.new_id_arc.peer_mac);
        Gee.List<string> both_peermacs = new ArrayList<string>();
        foreach (IdentityArcPair both_arcpair in both_arcpairs)
            both_peermacs.add(both_arcpair.new_id_arc.peer_mac);
        if (new_id.main_id)
        {
            IpCommands.main_dup(new_id, host_gnode_level, guest_gnode_level,
                prev_local_ip_set, prev_dest_ip_set,
                prev_peermacs, new_peermacs, both_peermacs);
        }
        else
        {
            IpCommands.connectivity_dup(new_id, host_gnode_level, guest_gnode_level,
                prev_dest_ip_set,
                prev_peermacs, new_peermacs, both_peermacs);
        }

        ArrayList<string> peermacs = new ArrayList<string>();
        foreach (IdentityArc id_arc in old_id.identity_arcs)
            if (id_arc.qspn_arc != null)
            peermacs.add(id_arc.peer_mac);
        IpCommands.connectivity_stop(old_id, peermacs);
    }

    QspnManager enter_another_network_qspn(IdentityData old_id, IdentityData new_id,
        QspnManager old_id_qspn_mgr,
        int guest_gnode_level, int go_connectivity_position,
        int host_gnode_level,
        Gee.List<IdentityArcPair> prev_arcpairs, Gee.List<IdentityArcPair> new_arcpairs, Gee.List<IdentityArcPair> both_arcpairs)
    {
        assert(guest_gnode_level >= 0);
        assert(guest_gnode_level < host_gnode_level);

        // Prepare update_copied_internal_fingerprints
        ChangeFingerprintDelegate update_copied_internal_fingerprints = (_f) => {
            Fingerprint f = (Fingerprint)_f;
            for (int l = guest_gnode_level; l < levels; l++)
            {
                // f.elderships has n items, where f.level + n = levels.
                // f.elderships[0] refers to l=f.level.
                // f.elderships[n-1] refers to l=f.level+n-1=levels-1.
                // so, f.elderships[i] refers to l=f.level+i.
                int i = l - f.level;
                if (i >= 0)
                    f.elderships[i] = new_id.my_fp.elderships[l];
                // f.elderships_seed doesn't need to change.
            }
            return f;
            // Returning the same instance is ok, because the delegate is alway
            // called like "x = update_internal_fingerprints(x)"
        };

        // Prepare internal arcs
        ArrayList<IQspnArc> internal_arc_set = new ArrayList<IQspnArc>();
        ArrayList<IQspnNaddr> internal_arc_peer_naddr_set = new ArrayList<IQspnNaddr>();
        ArrayList<IQspnArc> internal_arc_prev_arc_set = new ArrayList<IQspnArc>();

        foreach (IdentityArcPair arcpair in both_arcpairs)
        {
            IdentityArc w0 = arcpair.old_id_arc;
            IdentityArc w1 = arcpair.new_id_arc;

            NodeID destid = w1.id_arc.get_peer_nodeid();
            NodeID sourceid = w1.id; // == new_id
            w1.qspn_arc = new QspnArc(sourceid, destid, w1, w1.peer_mac);

            assert(w0.qspn_arc != null);
            IQspnNaddr? _w0_peer_naddr = old_id_qspn_mgr.get_naddr_for_arc(w0.qspn_arc);
            assert(_w0_peer_naddr != null);
            Naddr w0_peer_naddr = (Naddr)_w0_peer_naddr;
            ArrayList<int> _w1_peer_naddr = new ArrayList<int>();
            _w1_peer_naddr.add_all(w0_peer_naddr.pos.slice(0, host_gnode_level-1));
            _w1_peer_naddr.add_all(new_id.my_naddr.pos.slice(host_gnode_level-1, levels));
            Naddr w1_peer_naddr = new Naddr(_w1_peer_naddr.to_array(), gsizes.to_array());

            // Now add: the 3 ArrayList should have same size at the end.
            internal_arc_set.add(w1.qspn_arc);
            internal_arc_peer_naddr_set.add(w1_peer_naddr);
            internal_arc_prev_arc_set.add(w0.qspn_arc);
        }

        // Prepare external arcs
        ArrayList<IQspnArc> external_arc_set = new ArrayList<IQspnArc>();

        foreach (IdentityArcPair arcpair in new_arcpairs)
        {
            IdentityArc w1 = arcpair.new_id_arc;

            NodeID destid = w1.id_arc.get_peer_nodeid();
            NodeID sourceid = w1.id; // == new_id
            w1.qspn_arc = new QspnArc(sourceid, destid, w1, w1.peer_mac);
            // Adjust network_id in new arcs.
            w1.network_id = null;

            external_arc_set.add(w1.qspn_arc);
        }

        // Adjust network_id in previous arcs.
        foreach (IdentityArcPair arcpair in prev_arcpairs)
        {
            IdentityArc w1 = arcpair.new_id_arc;

            Fingerprint old_id_fp_levels;
            try {
                old_id_fp_levels = (Fingerprint)old_id_qspn_mgr.get_fingerprint(levels);
            } catch (QspnBootstrapInProgressError e) {
                assert_not_reached();
            }
            w1.network_id = old_id_fp_levels.id;
        }

        QspnManager qspn_mgr = new QspnManager.enter_net(
            internal_arc_set,
            internal_arc_prev_arc_set,
            internal_arc_peer_naddr_set,
            external_arc_set,
            new_id.my_naddr,
            new_id.my_fp,
            update_copied_internal_fingerprints,
            new QspnStubFactory(new_id),
            guest_gnode_level,
            host_gnode_level,
            old_id_qspn_mgr);

        // Prepare old_identity_update_naddr
        ChangeNaddrDelegate old_identity_update_naddr = (_a) => {
            Naddr a = (Naddr)_a;
            ArrayList<int> _naddr_temp = new ArrayList<int>();
            _naddr_temp.add_all(a.pos);
            _naddr_temp[guest_gnode_level] = go_connectivity_position;
            return new Naddr(_naddr_temp.to_array(), gsizes.to_array());
        };

        // call to make_connectivity
        old_id_qspn_mgr.make_connectivity(
            old_id.connectivity_from_level,
            old_id.connectivity_to_level,
            old_identity_update_naddr);

        return qspn_mgr;
    }
}
