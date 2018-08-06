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
using Netsukuku.PeerServices;
using Netsukuku.Coordinator;
using Netsukuku.Hooking;
using Netsukuku.Andna;
using TaskletSystem;

namespace Netsukuku
{
    void startup(ref ArrayList<int> naddr, ref ArrayList<string> devs)
    {
        // Initialize tasklet system
        PthTaskletImplementer.init();
        tasklet = PthTaskletImplementer.get_tasklet_system();

        // Initialize modules that have remotable methods (serializable classes need to be registered).
        NeighborhoodManager.init(tasklet);
        IdentityManager.init(tasklet);
        QspnManager.init(tasklet, max_paths, max_common_hops_ratio, arc_timeout, new ThresholdCalculator());
        PeersManager.init(tasklet);
        CoordinatorManager.init(tasklet);
        HookingManager.init(tasklet);
        AndnaManager.init(tasklet);
        typeof(MainIdentitySourceID).class_peek();
        typeof(MainIdentityUnicastID).class_peek();

        // Initialize pseudo-random number generators.
        uint32 seed_prn = 0;
        if (devs.size > 0)
        {
            string _seed = macgetter.get_mac(devs[0]).up();
            seed_prn = (uint32)_seed.hash();
        }
        PRNGen.init_rngen(null, seed_prn);
        NeighborhoodManager.init_rngen(null, seed_prn);
        IdentityManager.init_rngen(null, seed_prn);
        QspnManager.init_rngen(null, seed_prn);
        CoordinatorManager.init_rngen(null, seed_prn);
        HookingManager.init_rngen(null, seed_prn);

        // Pass tasklet system to the RPC library (ntkdrpc)
        init_tasklet_system(tasklet);

        // Commander
        cm = Commander.get_singleton();
        cm.start_console_log();
        // TableNames
        tn = TableNames.get_singleton(cm);

        // RPC
        skeleton_factory = new SkeletonFactory();
        stub_factory = new StubFactory();
        // The RPC library will need a tasklet for TCP connections and many
        // tasklets (one per NIC) for UDP connecions.
        t_udp_list = new ArrayList<ITaskletHandle>();
        // Start listen TCP
        t_tcp = skeleton_factory.start_tcp_listen();
        // The UDP tasklets will be launched after the NeighborhoodManager is
        // created and ready to start_monitor.

        int bid = cm.begin_block();
        cm.single_command_in_block(bid, new ArrayList<string>.wrap({
            @"sysctl", @"net.ipv4.ip_forward=1"}));
        cm.single_command_in_block(bid, new ArrayList<string>.wrap({
            @"sysctl", @"net.ipv4.conf.all.rp_filter=0"}));
        cm.end_block(bid);

        handlednic_list = new ArrayList<HandledNic>();
        arc_list = new ArrayList<NodeArc>();
        local_identities = new ArrayList<IdentityData>();

        // Init module Neighborhood
        identity_mgr = null;
        neighborhood_mgr = new NeighborhoodManager(
            1000 /*very high max_arcs*/,
            new NeighborhoodStubFactory(),
            new NeighborhoodQueryCallerInfo(),
            new NeighborhoodIPRouteManager(),
            () => @"169.254.$(PRNGen.int_range(0, 255)).$(PRNGen.int_range(0, 255))");
        skeleton_factory.node_skeleton.id = neighborhood_mgr.get_my_neighborhood_id();
        // connect signals
        neighborhood_mgr.nic_address_set.connect(neighborhood_nic_address_set);
        neighborhood_mgr.arc_added.connect(neighborhood_arc_added);
        neighborhood_mgr.arc_changed.connect(neighborhood_arc_changed);
        neighborhood_mgr.arc_removing.connect(neighborhood_arc_removing);
        neighborhood_mgr.arc_removed.connect(neighborhood_arc_removed);
        neighborhood_mgr.nic_address_unset.connect(neighborhood_nic_address_unset);

        foreach (string dev in devs)
        {
            // Set up NIC
            bid = cm.begin_block();
            cm.single_command_in_block(bid, new ArrayList<string>.wrap({
                @"sysctl", @"net.ipv4.conf.$(dev).rp_filter=0"}));
            cm.single_command_in_block(bid, new ArrayList<string>.wrap({
                @"sysctl", @"net.ipv4.conf.$(dev).arp_ignore=1"}));
            cm.single_command_in_block(bid, new ArrayList<string>.wrap({
                @"sysctl", @"net.ipv4.conf.$(dev).arp_announce=2"}));
            cm.single_command_in_block(bid, new ArrayList<string>.wrap({
                @"ip", @"link", @"set", @"dev", @"$(dev)", @"up"}));
            cm.end_block(bid);

            // Start listen UDP on dev
            t_udp_list.add(skeleton_factory.start_udp_listen(dev));
            // Run monitor. This will also set the IP link-local address and the list
            //  `handlednic_list` will be compiled.
            var _nic = new NeighborhoodNetworkInterface(dev);
            _nic.start_console_log();
            neighborhood_mgr.start_monitor(_nic);
        }

        // Init module Identities
        Gee.List<string> if_list_dev = new ArrayList<string>();
        Gee.List<string> if_list_mac = new ArrayList<string>();
        Gee.List<string> if_list_linklocal = new ArrayList<string>();
        foreach (HandledNic n in handlednic_list)
        {
            if_list_dev.add(n.dev);
            if_list_mac.add(n.mac);
            if_list_linklocal.add(n.linklocal);
        }
        identity_mgr = new IdentityManager(
            if_list_dev, if_list_mac, if_list_linklocal,
            new IdmgmtNetnsManager(),
            new IdmgmtStubFactory(),
            () => @"169.254.$(PRNGen.int_range(0, 255)).$(PRNGen.int_range(0, 255))");
        identity_mgr.identity_arc_added.connect(identities_identity_arc_added);
        identity_mgr.identity_arc_changed.connect(identities_identity_arc_changed);
        identity_mgr.identity_arc_removing.connect(identities_identity_arc_removing);
        identity_mgr.identity_arc_removed.connect(identities_identity_arc_removed);
        identity_mgr.arc_removed.connect(identities_arc_removed);

        // First identity
        NodeID nodeid = identity_mgr.get_main_id();
        IdentityData first_identity_data = find_or_create_local_identity(nodeid);
        first_identity_data.identity_skeleton = new IdentitySkeleton(first_identity_data);
        Naddr my_naddr = new Naddr(naddr.to_array(), gsizes.to_array());
        ArrayList<int> elderships = new ArrayList<int>();
        for (int i = 0; i < levels; i++) elderships.add(0);
        Fingerprint my_fp = new Fingerprint(elderships.to_array());
        first_identity_data.my_naddr = my_naddr;
        first_identity_data.my_fp = my_fp;
        print(@"startup: my id $(first_identity_data.nodeid.id) has address $(json_string_object(first_identity_data.my_naddr))");
        print(@" and fp $(json_string_object(first_identity_data.my_fp)).\n");

        // iproute commands for startup first identity
        IpCompute.new_main_id(first_identity_data);
        IpCompute.new_id(first_identity_data);
        IpCommands.main_start(first_identity_data);

        // First qspn manager
        QspnManager qspn_mgr = new QspnManager.create_net(
            my_naddr,
            my_fp,
            new QspnStubFactory(first_identity_data));
        identity_mgr.set_identity_module(nodeid, "qspn", qspn_mgr);
        first_identity_data.qspn_mgr = qspn_mgr;  // weak ref

        // immediately after creation, connect to signals.
        qspn_mgr.arc_removed.connect(first_identity_data.arc_removed);
        qspn_mgr.changed_fp.connect(first_identity_data.changed_fp);
        qspn_mgr.changed_nodes_inside.connect(first_identity_data.changed_nodes_inside);
        qspn_mgr.destination_added.connect(first_identity_data.destination_added);
        qspn_mgr.destination_removed.connect(first_identity_data.destination_removed);
        qspn_mgr.gnode_splitted.connect(first_identity_data.gnode_splitted);
        qspn_mgr.path_added.connect(first_identity_data.path_added);
        qspn_mgr.path_changed.connect(first_identity_data.path_changed);
        qspn_mgr.path_removed.connect(first_identity_data.path_removed);
        qspn_mgr.presence_notified.connect(first_identity_data.presence_notified);
        qspn_mgr.qspn_bootstrap_complete.connect(first_identity_data.qspn_bootstrap_complete);
        qspn_mgr.remove_identity.connect(first_identity_data.remove_identity);

        // First identity is immediately bootstrapped.
        while (! qspn_mgr.is_bootstrap_complete()) tasklet.ms_wait(1);
        // Then we can instantiate p2p services
        PeersManager peers_mgr = new PeersManager(null, 0, 0,
            new PeersMapPaths(first_identity_data),
            new PeersBackStubFactory(first_identity_data),
            new PeersNeighborsFactory(first_identity_data));
        identity_mgr.set_identity_module(nodeid, "peers", peers_mgr);
        first_identity_data.peers_mgr = peers_mgr;  // weak ref

        // CoordinatorManager
        CoordinatorManager coord_mgr = new CoordinatorManager(gsizes,
            new CoordinatorEvaluateEnterHandler(first_identity_data),
            new CoordinatorBeginEnterHandler(first_identity_data),
            new CoordinatorCompletedEnterHandler(first_identity_data),
            new CoordinatorAbortEnterHandler(first_identity_data),
            new CoordinatorPropagationHandler(first_identity_data),
            new CoordinatorStubFactory(first_identity_data),
            null, null, null);
        identity_mgr.set_identity_module(nodeid, "coordinator", coord_mgr);
        first_identity_data.coord_mgr = coord_mgr;  // weak ref
        coord_mgr.bootstrap_completed(
            first_identity_data.peers_mgr,
            new CoordinatorMap(first_identity_data),
            first_identity_data.main_id);
        if (first_identity_data.main_id)
            first_identity_data.gone_connectivity.connect(first_identity_data.handle_gone_connectivity_for_coord);

        // HookingManager
        HookingManager hook_mgr = new HookingManager(
            new HookingMapPaths(first_identity_data),
            new HookingCoordinator(first_identity_data));
        identity_mgr.set_identity_module(nodeid, "hooking", hook_mgr);
        first_identity_data.hook_mgr = hook_mgr;  // weak ref
        // immediately after creation, connect to signals.
        hook_mgr.same_network.connect((_ia) =>
            per_identity_hooking_same_network(first_identity_data, _ia));
        hook_mgr.another_network.connect((_ia, network_id) =>
            per_identity_hooking_another_network(first_identity_data, _ia, network_id));
        hook_mgr.do_prepare_migration.connect((migration_id) =>
            per_identity_hooking_do_prepare_migration(first_identity_data, migration_id));
        hook_mgr.do_finish_migration.connect(
            (migration_id, guest_gnode_level, migration_data, go_connectivity_position) =>
            per_identity_hooking_do_finish_migration
            (first_identity_data, migration_id, guest_gnode_level,
            migration_data, go_connectivity_position));
        hook_mgr.do_prepare_enter.connect((enter_id) =>
            per_identity_hooking_do_prepare_enter(first_identity_data, enter_id));
        hook_mgr.do_finish_enter.connect(
            (enter_id, guest_gnode_level, entry_data, go_connectivity_position) =>
            per_identity_hooking_do_finish_enter
            (first_identity_data, enter_id, guest_gnode_level,
            entry_data, go_connectivity_position));

        // AndnaManager  TODO
        AndnaManager andna_mgr = new AndnaManager();
        identity_mgr.set_identity_module(nodeid, "andna", andna_mgr);
        first_identity_data.andna_mgr = andna_mgr;  // weak ref

        // TODO continue
    }
}
