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
    const uint16 ntkd_port = 60269;
    const int max_paths = 5;
    const double max_common_hops_ratio = 0.6;
    const int arc_timeout = 10000;

    [CCode (array_length = false, array_null_terminated = true)]
    string[] interfaces;
    bool accept_anonymous_requests;
    bool no_anonymize;
    int subnetlevel;

    ITasklet tasklet;
    Commander cm;
    ArrayList<int> gsizes;
    ArrayList<int> g_exp;
    int levels;
    NeighborhoodManager? neighborhood_mgr;
    ArrayList<string> real_nics;
    ArrayList<HandledNic> handlednics;

    ServerDelegate dlg;
    ServerErrorHandler err;
    ArrayList<ITaskletHandle> t_udp_list;

    int main(string[] _args)
    {
        subnetlevel = 0; // default
        accept_anonymous_requests = false; // default
        no_anonymize = false; // default
        OptionContext oc = new OptionContext("<options>");
        OptionEntry[] entries = new OptionEntry[5];
        int index = 0;
        entries[index++] = {"subnetlevel", 's', 0, OptionArg.INT, ref subnetlevel, "Level of g-node for autonomous subnet", null};
        entries[index++] = {"interfaces", 'i', 0, OptionArg.STRING_ARRAY, ref interfaces, "Interface (e.g. -i eth1). You can use it multiple times.", null};
        entries[index++] = {"serve-anonymous", 'k', 0, OptionArg.NONE, ref accept_anonymous_requests, "Accept anonymous requests", null};
        entries[index++] = {"no-anonymize", 'j', 0, OptionArg.NONE, ref no_anonymize, "Disable anonymizer", null};
        entries[index++] = { null };
        oc.add_main_entries(entries, null);
        try {
            oc.parse(ref _args);
        }
        catch (OptionError e) {
            print(@"Error parsing options: $(e.message)\n");
            return 1;
        }

        ArrayList<string> args = new ArrayList<string>.wrap(_args);
        // TODO some argument?

        // First network: the node on its own. Topoplogy of the network and address of the node.
        ArrayList<int> naddr = new ArrayList<int>();
        gsizes = new ArrayList<int>();
        g_exp = new ArrayList<int>();
        foreach (int gsize in new int[]{4,2,2,2}) // hard-wired topology.
        {
            if (gsize < 2) error(@"Bad gsize $(gsize).");
            int _g_exp = 0;
            for (int k = 1; k < 17; k++)
            {
                if (gsize == (1 << k)) _g_exp = k;
            }
            if (_g_exp == 0) error(@"Bad gsize $(gsize): must be power of 2 up to 2^16.");
            g_exp.insert(0, _g_exp);
            gsizes.insert(0, gsize);

            naddr.insert(0, 0); // Random(0..gsize-1) or 0.
        }
        levels = gsizes.size;

        // Names of the network interfaces to monitor.
        ArrayList<string> devs = new ArrayList<string>();
        foreach (string dev in interfaces) devs.add(dev);

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

        // The RPC library will need a tasklet for TCP connections and many
        // tasklets (one per NIC) for UDP connecions.
        dlg = new ServerDelegate();
        err = new ServerErrorHandler();
        // Handle for TCP
        ITaskletHandle t_tcp;
        // Handles for UDP
        t_udp_list = new ArrayList<ITaskletHandle>();
        // Start listen TCP
        t_tcp = tcp_listen(dlg, err, ntkd_port);
        // The UDP tasklets will be launched after the NeighborhoodManager is
        // created and ready to start_monitor.

        string ntklocalhost = ip_internal_node(naddr, 0);
        int bid = cm.begin_block();
        cm.single_command_in_block(bid, new ArrayList<string>.wrap({
            @"sysctl", @"net.ipv4.ip_forward=1"}));
        cm.single_command_in_block(bid, new ArrayList<string>.wrap({
            @"sysctl", @"net.ipv4.conf.all.rp_filter=0"}));
        cm.single_command_in_block(bid, new ArrayList<string>.wrap({
            @"ip", @"address", @"add", @"$(ntklocalhost)", @"dev", @"lo"}));
        cm.end_block(bid);

        real_nics = new ArrayList<string>();
        handlednics = new ArrayList<HandledNic>();

        // Init module Neighborhood
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
        foreach (string dev in devs) manage_real_nic(dev);
        // Here (for each dev) the linklocal address has been added, and the signal handler for
        //  nic_address_set has been processed, so we have in `handlednics` the informations
        //  for the module Identities.
        
        // TODO continue

        // register handlers for SIGINT and SIGTERM to exit
        Posix.@signal(Posix.SIGINT, safe_exit);
        Posix.@signal(Posix.SIGTERM, safe_exit);
        // Main loop
        while (true)
        {
            tasklet.ms_wait(100);
            if (do_me_exit) break;
        }

        // Cleanup

        // Call stop_monitor_all of NeighborhoodManager.
        neighborhood_mgr.stop_monitor_all();

        // remove local addresses (global, anon, intern, localhost)
        cm.single_command(new ArrayList<string>.wrap({
            @"ip", @"address", @"del", @"$(ntklocalhost)/32", @"dev", @"lo"}));

        // Then we destroy the object NeighborhoodManager.
        // Beware that node_skeleton.neighborhood_mgr is a weak reference.
        neighborhood_mgr = null;

        // Kill the tasklets that were used by the RPC library.
        foreach (ITaskletHandle t_udp in t_udp_list) t_udp.kill();
        t_tcp.kill();

        tasklet.ms_wait(100);

        PthTaskletImplementer.kill();
        print("\nExiting.\n");
        return 0;
    }

    bool do_me_exit = false;
    void safe_exit(int sig)
    {
        // We got here because of a signal. Quick processing.
        do_me_exit = true;
    }

    void manage_real_nic(string dev)
    {
        real_nics.add(dev);

        // Set up NIC
        int bid = cm.begin_block();
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
        // Run monitor
        neighborhood_mgr.start_monitor(new NeighborhoodNetworkInterface(dev));
    }

    class HandledNic : Object
    {
        public string dev;
        public string mac;
        public string linklocal;
    }
}

