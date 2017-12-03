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
    void startup(ref ArrayList<int> naddr, ref ArrayList<string> devs, out string ntklocalhost)
    {
        // Initialize tasklet system
        PthTaskletImplementer.init();
        tasklet = PthTaskletImplementer.get_tasklet_system();

        // Initialize modules that have remotable methods.
        NeighborhoodManager.init(tasklet);
        // ...
        HookingManager.init(tasklet);
        AndnaManager.init(tasklet);

        // Pass tasklet system to the RPC library (ntkdrpc)
        init_tasklet_system(tasklet);

        // Commander
        cm = Commander.get_singleton();
        cm.start_console_log();
        // TableNames
        tn = TableNames.get_singleton(cm);

        // The RPC library will need a tasklet for TCP connections and many
        // tasklets (one per NIC) for UDP connecions.
        dlg = new ServerDelegate();
        err = new ServerErrorHandler();
        t_udp_list = new ArrayList<ITaskletHandle>();
        // Start listen TCP
        t_tcp = tcp_listen(dlg, err, ntkd_port);
        // The UDP tasklets will be launched after the NeighborhoodManager is
        // created and ready to start_monitor.

        ntklocalhost = ip_internal_node(naddr, 0);
        int bid = cm.begin_block();
        cm.single_command_in_block(bid, new ArrayList<string>.wrap({
            @"sysctl", @"net.ipv4.ip_forward=1"}));
        cm.single_command_in_block(bid, new ArrayList<string>.wrap({
            @"sysctl", @"net.ipv4.conf.all.rp_filter=0"}));
        cm.single_command_in_block(bid, new ArrayList<string>.wrap({
            @"ip", @"address", @"add", @"$(ntklocalhost)", @"dev", @"lo"}));
        cm.end_block(bid);

        handlednic_list = new ArrayList<HandledNic>();
        arc_list = new ArrayList<IdmgmtArc>();
        local_identities = new ArrayList<IdentityData>();

        // Init module Neighborhood
        identity_mgr = null;
        node_skeleton = new AddressManagerForNode();
        neighborhood_mgr = new NeighborhoodManager(
            get_identity_skeleton,
            get_identity_skeleton_set,
            node_skeleton,
            1000 /*very high max_arcs*/,
            new NeighborhoodStubFactory(),
            new NeighborhoodIPRouteManager(),
            () => @"169.254.$(Random.int_range(0, 255)).$(Random.int_range(0, 255))");
        node_skeleton.neighborhood_mgr = neighborhood_mgr;
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
            t_udp_list.add(udp_listen(dlg, err, ntkd_port, dev));
            // Run monitor. This will also set the IP link-local address and the list
            //  `handlednic_list` will be compiled.
            neighborhood_mgr.start_monitor(new NeighborhoodNetworkInterface(dev));
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
            tasklet,
            if_list_dev, if_list_mac, if_list_linklocal,
            new IdmgmtNetnsManager(),
            new IdmgmtStubFactory(),
            () => @"169.254.$(Random.int_range(0, 255)).$(Random.int_range(0, 255))");
        node_skeleton.identity_mgr = identity_mgr;
        identity_mgr.identity_arc_added.connect(identities_identity_arc_added);
        identity_mgr.identity_arc_changed.connect(identities_identity_arc_changed);
        identity_mgr.identity_arc_removing.connect(identities_identity_arc_removing);
        identity_mgr.identity_arc_removed.connect(identities_identity_arc_removed);
        identity_mgr.arc_removed.connect(identities_arc_removed);

        // First identity
        NodeID nodeid = identity_mgr.get_main_id();
        IdentityData first_identity_data = find_or_create_local_identity(nodeid);
        first_identity_data.addr_man = new AddressManagerForIdentity();

        // TODO continue
    }
}