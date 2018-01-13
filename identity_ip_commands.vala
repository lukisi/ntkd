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

namespace Netsukuku.IpCommands
{
    void main_start(IdentityData id)
    {
        // foreach (HandledNic n in handlednic_list) n.dev n.mac n.linklocal
        ArrayList<string> devs = new ArrayList<string>();
        foreach (HandledNic n in handlednic_list) devs.add(n.dev);
        LocalIPSet local_ip_set = id.local_ip_set;
        DestinationIPSet dest_ip_set = id.dest_ip_set;

        foreach (string dev in devs)
        {
            for (int k = 1; k < levels; k++)
            {
                cm.single_command(new ArrayList<string>.wrap({
                    @"ip", @"address", @"add", @"$(local_ip_set.intern[k])", @"dev", @"$(dev)"}));
            }
            cm.single_command(new ArrayList<string>.wrap({
                @"ip", @"address", @"add", @"$(local_ip_set.global)", @"dev", @"$(dev)"}));
            if (accept_anonymous_requests)
            {
                cm.single_command(new ArrayList<string>.wrap({
                    @"ip", @"address", @"add", @"$(local_ip_set.anonymizing)", @"dev", @"$(dev)"}));
            }
        }

        cm.single_command(new ArrayList<string>.wrap({
            @"ip", @"address", @"add", @"$(local_ip_set.intern[0])", @"dev", @"lo"}));

        if (! no_anonymize)
        {
            cm.single_command(new ArrayList<string>.wrap({
                @"iptables", @"-t", @"nat", @"-A", @"POSTROUTING", @"-d", @"$(local_ip_set.anonymizing_range)",
                @"-j", @"SNAT", @"--to", @"$(local_ip_set.global)"}));
        }

        if (subnetlevel > 0)
        {
            for (int i = subnetlevel; i <= levels-2; i++)
            {
                cm.single_command(new ArrayList<string>.wrap({
                    @"iptables", @"-t", @"nat", @"-A", @"PREROUTING", @"-d", @"$(local_ip_set.netmap_range2[i])",
                    @"-j", @"NETMAP", @"--to", @"$(local_ip_set.netmap_range1)"}));
                cm.single_command(new ArrayList<string>.wrap({
                    @"iptables", @"-t", @"nat", @"-A", @"POSTROUTING", @"-d", @"$(local_ip_set.netmap_range3[i])",
                    @"-s", @"$(local_ip_set.netmap_range1)",
                    @"-j", @"NETMAP", @"--to", @"$(local_ip_set.netmap_range2[i])"}));
            }
            cm.single_command(new ArrayList<string>.wrap({
                @"iptables", @"-t", @"nat", @"-A", @"PREROUTING", @"-d", @"$(local_ip_set.netmap_range2_upper)",
                @"-j", @"NETMAP", @"--to", @"$(local_ip_set.netmap_range1)"}));
            cm.single_command(new ArrayList<string>.wrap({
                @"iptables", @"-t", @"nat", @"-A", @"POSTROUTING", @"-d", @"$(local_ip_set.netmap_range3_upper)",
                @"-s", @"$(local_ip_set.netmap_range1)",
                @"-j", @"NETMAP", @"--to", @"$(local_ip_set.netmap_range2_upper)"}));
            if (accept_anonymous_requests)
            {
                cm.single_command(new ArrayList<string>.wrap({
                    @"iptables", @"-t", @"nat", @"-A", @"PREROUTING", @"-d", @"$(local_ip_set.netmap_range4)",
                    @"-j", @"NETMAP", @"--to", @"$(local_ip_set.netmap_range1)"}));
            }
            cm.single_command(new ArrayList<string>.wrap({
                @"iptables", @"-t", @"nat", @"-A", @"POSTROUTING", @"-d", @"$(local_ip_set.anonymizing_range)",
                @"-s", @"$(local_ip_set.netmap_range1)",
                @"-j", @"NETMAP", @"--to", @"$(local_ip_set.netmap_range2_upper)"}));
        }

        cm.single_command(new ArrayList<string>.wrap({
            @"ip", @"rule", @"add", @"table", @"ntk"}));

        foreach (HCoord hc in dest_ip_set.gnode.keys)
        {
            DestinationIPSetGnode dest = dest_ip_set.gnode[hc];
            cm.single_command(new ArrayList<string>.wrap({
                @"ip", @"route", @"add", @"unreachable", @"$(dest.global)", @"table", @"ntk"}));
            cm.single_command(new ArrayList<string>.wrap({
                @"ip", @"route", @"add", @"unreachable", @"$(dest.anonymizing)", @"table", @"ntk"}));
            for (int k = levels-1; k >= hc.lvl+1; k--)
            {
                cm.single_command(new ArrayList<string>.wrap({
                    @"ip", @"route", @"add", @"unreachable", @"$(dest.intern[k])", @"table", @"ntk"}));
            }
        }
    }

    void main_dup(IdentityData id, int host_gnode_level, int guest_gnode_level,
                  LocalIPSet prev_local_ip_set, DestinationIPSet prev_dest_ip_set,
                  Gee.List<string> prev_peermacs, Gee.List<string> new_peermacs, Gee.List<string> both_peermacs)
    {
        ArrayList<string> devs = new ArrayList<string>();
        foreach (HandledNic n in handlednic_list) devs.add(n.dev);
        LocalIPSet local_ip_set = id.local_ip_set;
        DestinationIPSet dest_ip_set = id.dest_ip_set;

        foreach (HCoord hc in prev_dest_ip_set.gnode.keys)
        {
            DestinationIPSetGnode prev_dest = prev_dest_ip_set.gnode[hc];
            cm.single_command(new ArrayList<string>.wrap({
                @"ip", @"route", @"del", @"$(prev_dest.global)", @"table", @"ntk"}));
            cm.single_command(new ArrayList<string>.wrap({
                @"ip", @"route", @"del", @"$(prev_dest.anonymizing)", @"table", @"ntk"}));
            for (int k = levels-1; k >= hc.lvl+1; k--) if (k >= guest_gnode_level)
            {
                cm.single_command(new ArrayList<string>.wrap({
                    @"ip", @"route", @"del", @"$(prev_dest.intern[k])", @"table", @"ntk"}));
            }
        }

        foreach (string m in both_peermacs)
        {
            string table;
            int tid;
            tn.get_table(null, m, out tid, out table);
            foreach (HCoord hc in prev_dest_ip_set.gnode.keys)
            {
                DestinationIPSetGnode prev_dest = prev_dest_ip_set.gnode[hc];
                cm.single_command(new ArrayList<string>.wrap({
                    @"ip", @"route", @"del", @"$(prev_dest.global)", @"table", @"$(table)"}));
                cm.single_command(new ArrayList<string>.wrap({
                    @"ip", @"route", @"del", @"$(prev_dest.anonymizing)", @"table", @"$(table)"}));
                for (int k = levels-1; k >= hc.lvl+1; k--) if (k >= guest_gnode_level)
                {
                    cm.single_command(new ArrayList<string>.wrap({
                        @"ip", @"route", @"del", @"$(prev_dest.intern[k])", @"table", @"$(table)"}));
                }
            }
        }

        foreach (string m in prev_peermacs)
        {
            string table;
            int tid;
            tn.get_table(null, m, out tid, out table);
            cm.single_command(new ArrayList<string>.wrap({
                @"ip", @"route", @"flush", @"table", @"$(table)"}));
            cm.single_command(new ArrayList<string>.wrap({
                @"ip", @"rule", @"del", @"fwmark", @"$(tid)", @"table", @"$(table)"}));
            cm.single_command(new ArrayList<string>.wrap({
                @"iptables", @"-t", @"mangle", @"-D", @"PREROUTING",
                @"-m", @"mac", @"--mac-source", @"$(m)",
                @"-j", @"MARK", @"--set-mark", @"$(tid)"}));
            if (tn.decref_table(m) <= 0) tn.release_table(null, m);
        }

        if (subnetlevel > 0)
        {
            for (int k = host_gnode_level; k <= levels-2; k++)
            {
                cm.single_command(new ArrayList<string>.wrap({
                    @"iptables", @"-t", @"nat", @"-D", @"PREROUTING", @"-d", @"$(prev_local_ip_set.netmap_range2[k])",
                    @"-j", @"NETMAP", @"--to", @"$(prev_local_ip_set.netmap_range1)"}));
                cm.single_command(new ArrayList<string>.wrap({
                    @"iptables", @"-t", @"nat", @"-D", @"POSTROUTING", @"-d", @"$(prev_local_ip_set.netmap_range3[k])",
                    @"-s", @"$(prev_local_ip_set.netmap_range1)",
                    @"-j", @"NETMAP", @"--to", @"$(prev_local_ip_set.netmap_range2[k])"}));
            }
            cm.single_command(new ArrayList<string>.wrap({
                @"iptables", @"-t", @"nat", @"-D", @"PREROUTING", @"-d", @"$(prev_local_ip_set.netmap_range2_upper)",
                @"-j", @"NETMAP", @"--to", @"$(prev_local_ip_set.netmap_range1)"}));
            cm.single_command(new ArrayList<string>.wrap({
                @"iptables", @"-t", @"nat", @"-D", @"POSTROUTING", @"-d", @"$(prev_local_ip_set.netmap_range3_upper)",
                @"-s", @"$(prev_local_ip_set.netmap_range1)",
                @"-j", @"NETMAP", @"--to", @"$(prev_local_ip_set.netmap_range2_upper)"}));
            if (accept_anonymous_requests)
            {
                cm.single_command(new ArrayList<string>.wrap({
                    @"iptables", @"-t", @"nat", @"-D", @"PREROUTING", @"-d", @"$(prev_local_ip_set.netmap_range4)",
                    @"-j", @"NETMAP", @"--to", @"$(prev_local_ip_set.netmap_range1)"}));
            }
            cm.single_command(new ArrayList<string>.wrap({
                @"iptables", @"-t", @"nat", @"-D", @"POSTROUTING", @"-d", @"$(prev_local_ip_set.anonymizing_range)",
                @"-s", @"$(prev_local_ip_set.netmap_range1)",
                @"-j", @"NETMAP", @"--to", @"$(prev_local_ip_set.netmap_range2_upper)"}));
        }

        if (! no_anonymize)
        {
            cm.single_command(new ArrayList<string>.wrap({
                @"iptables", @"-t", @"nat", @"-D", @"POSTROUTING", @"-d", @"$(prev_local_ip_set.anonymizing_range)",
                @"-j", @"SNAT", @"--to", @"$(prev_local_ip_set.global)"}));
        }

        foreach (string dev in devs)
        {
            for (int k = host_gnode_level; k <= levels-1; k++)
            {
                cm.single_command(new ArrayList<string>.wrap({
                    @"ip", @"address", @"del", @"$(prev_local_ip_set.intern[k])/32", @"dev", @"$(dev)"}));
            }
            cm.single_command(new ArrayList<string>.wrap({
                @"ip", @"address", @"del", @"$(prev_local_ip_set.global)/32", @"dev", @"$(dev)"}));
            if (accept_anonymous_requests)
            {
                cm.single_command(new ArrayList<string>.wrap({
                    @"ip", @"address", @"del", @"$(prev_local_ip_set.anonymizing)/32", @"dev", @"$(dev)"}));
            }
        }

        foreach (string dev in devs)
        {
            for (int k = host_gnode_level; k <= levels-1; k++)
            {
                cm.single_command(new ArrayList<string>.wrap({
                    @"ip", @"address", @"add", @"$(local_ip_set.intern[k])", @"dev", @"$(dev)"}));
            }
            cm.single_command(new ArrayList<string>.wrap({
                @"ip", @"address", @"add", @"$(local_ip_set.global)", @"dev", @"$(dev)"}));
            if (accept_anonymous_requests)
            {
                cm.single_command(new ArrayList<string>.wrap({
                    @"ip", @"address", @"add", @"$(local_ip_set.anonymizing)", @"dev", @"$(dev)"}));
            }
        }

        if (! no_anonymize)
        {
            cm.single_command(new ArrayList<string>.wrap({
                @"iptables", @"-t", @"nat", @"-A", @"POSTROUTING", @"-d", @"$(local_ip_set.anonymizing_range)",
                @"-j", @"SNAT", @"--to", @"$(local_ip_set.global)"}));
        }

        if (subnetlevel > 0)
        {
            for (int k = host_gnode_level; k <= levels-2; k++)
            {
                cm.single_command(new ArrayList<string>.wrap({
                    @"iptables", @"-t", @"nat", @"-A", @"PREROUTING", @"-d", @"$(local_ip_set.netmap_range2[k])",
                    @"-j", @"NETMAP", @"--to", @"$(local_ip_set.netmap_range1)"}));
                cm.single_command(new ArrayList<string>.wrap({
                    @"iptables", @"-t", @"nat", @"-A", @"POSTROUTING", @"-d", @"$(local_ip_set.netmap_range3[k])",
                    @"-s", @"$(local_ip_set.netmap_range1)",
                    @"-j", @"NETMAP", @"--to", @"$(local_ip_set.netmap_range2[k])"}));
            }
            cm.single_command(new ArrayList<string>.wrap({
                @"iptables", @"-t", @"nat", @"-A", @"PREROUTING", @"-d", @"$(local_ip_set.netmap_range2_upper)",
                @"-j", @"NETMAP", @"--to", @"$(local_ip_set.netmap_range1)"}));
            cm.single_command(new ArrayList<string>.wrap({
                @"iptables", @"-t", @"nat", @"-A", @"POSTROUTING", @"-d", @"$(local_ip_set.netmap_range3_upper)",
                @"-s", @"$(local_ip_set.netmap_range1)",
                @"-j", @"NETMAP", @"--to", @"$(local_ip_set.netmap_range2_upper)"}));
            if (accept_anonymous_requests)
            {
                cm.single_command(new ArrayList<string>.wrap({
                    @"iptables", @"-t", @"nat", @"-A", @"PREROUTING", @"-d", @"$(local_ip_set.netmap_range4)",
                    @"-j", @"NETMAP", @"--to", @"$(local_ip_set.netmap_range1)"}));
            }
            cm.single_command(new ArrayList<string>.wrap({
                @"iptables", @"-t", @"nat", @"-A", @"POSTROUTING", @"-d", @"$(local_ip_set.anonymizing_range)",
                @"-s", @"$(local_ip_set.netmap_range1)",
                @"-j", @"NETMAP", @"--to", @"$(local_ip_set.netmap_range2_upper)"}));
        }

        foreach (HCoord hc in dest_ip_set.gnode.keys)
        {
            DestinationIPSetGnode dest = dest_ip_set.gnode[hc];
            cm.single_command(new ArrayList<string>.wrap({
                @"ip", @"route", @"add", @"unreachable", @"$(dest.global)", @"table", @"ntk"}));
            cm.single_command(new ArrayList<string>.wrap({
                @"ip", @"route", @"add", @"unreachable", @"$(dest.anonymizing)", @"table", @"ntk"}));
            for (int k = levels-1; k >= hc.lvl+1; k--) if (k >= guest_gnode_level)
            {
                cm.single_command(new ArrayList<string>.wrap({
                    @"ip", @"route", @"add", @"unreachable", @"$(dest.intern[k])", @"table", @"ntk"}));
            }
        }

        foreach (string m in both_peermacs)
        {
            string table;
            int tid;
            tn.get_table(null, m, out tid, out table);
            foreach (HCoord hc in dest_ip_set.gnode.keys)
            {
                DestinationIPSetGnode dest = dest_ip_set.gnode[hc];
                cm.single_command(new ArrayList<string>.wrap({
                    @"ip", @"route", @"add", @"unreachable", @"$(dest.global)", @"table", @"$(table)"}));
                cm.single_command(new ArrayList<string>.wrap({
                    @"ip", @"route", @"add", @"unreachable", @"$(dest.anonymizing)", @"table", @"$(table)"}));
                for (int k = levels-1; k >= hc.lvl+1; k--) if (k >= guest_gnode_level)
                {
                    cm.single_command(new ArrayList<string>.wrap({
                        @"ip", @"route", @"add", @"unreachable", @"$(dest.intern[k])", @"table", @"$(table)"}));
                }
            }
        }

        foreach (string m in new_peermacs)
        {
            string table;
            int tid;
            tn.get_table(null, m, out tid, out table);
            cm.single_command(new ArrayList<string>.wrap({
                @"iptables", @"-t", @"mangle", @"-A", @"PREROUTING", @"-m", @"mac",
                @"--mac-source", @"$(m)", @"-j", @"MARK", @"--set-mark", @"$(tid)"}));
            cm.single_command(new ArrayList<string>.wrap({
                @"ip", @"rule", @"add", @"fwmark", @"$(tid)", @"table", @"$(table)"}));
            tn.incref_table(m);
            foreach (HCoord hc in dest_ip_set.gnode.keys)
            {
                DestinationIPSetGnode dest = dest_ip_set.gnode[hc];
                cm.single_command(new ArrayList<string>.wrap({
                    @"ip", @"route", @"add", @"unreachable", @"$(dest.global)", @"table", @"$(table)"}));
                cm.single_command(new ArrayList<string>.wrap({
                    @"ip", @"route", @"add", @"unreachable", @"$(dest.anonymizing)", @"table", @"$(table)"}));
                for (int k = levels-1; k >= hc.lvl+1; k--)
                {
                    cm.single_command(new ArrayList<string>.wrap({
                        @"ip", @"route", @"add", @"unreachable", @"$(dest.intern[k])", @"table", @"$(table)"}));
                }
            }
        }
    }

    void cat_cmd(Gee.List<string> prefix_cmd, string[] cmd_array)
    {
        ArrayList<string> cmd = new ArrayList<string>();
        cmd.add_all(prefix_cmd);
        cmd.add_all_array(cmd_array);
        cm.single_command(cmd);
    }

    void gone_connectivity(IdentityData id, Gee.List<string> peermacs)
    {
        DestinationIPSet dest_ip_set = id.dest_ip_set;
        assert(! id.main_id);
        ArrayList<string> prefix_cmd = new ArrayList<string>.wrap({
            @"ip", @"netns", @"exec", @"$(id.network_namespace)"});

        foreach (string m in peermacs)
        {
            string table;
            int tid;
            tn.get_table(null, m, out tid, out table);
            cat_cmd(prefix_cmd, {
                @"iptables", @"-t", @"mangle", @"-A", @"PREROUTING", @"-m", @"mac",
                @"--mac-source", @"$(m)", @"-j", @"MARK", @"--set-mark", @"$(tid)"});
            cat_cmd(prefix_cmd, {
                @"ip", @"rule", @"add", @"fwmark", @"$(tid)", @"table", @"$(table)"});
            tn.incref_table(m);
            foreach (HCoord hc in dest_ip_set.gnode.keys)
            {
                DestinationIPSetGnode dest = dest_ip_set.gnode[hc];
                cat_cmd(prefix_cmd, {
                    @"ip", @"route", @"add", @"unreachable", @"$(dest.global)", @"table", @"$(table)"});
                cat_cmd(prefix_cmd, {
                    @"ip", @"route", @"add", @"unreachable", @"$(dest.anonymizing)", @"table", @"$(table)"});
                for (int k = levels-1; k >= hc.lvl+1; k--)
                {
                    cat_cmd(prefix_cmd, {
                        @"ip", @"route", @"add", @"unreachable", @"$(dest.intern[k])", @"table", @"$(table)"});
                }
            }
        }
    }

    void connectivity_dup(IdentityData id, int host_gnode_level, int guest_gnode_level,
                  DestinationIPSet prev_dest_ip_set,
                  Gee.List<string> prev_peermacs, Gee.List<string> new_peermacs, Gee.List<string> both_peermacs)
    {
        DestinationIPSet dest_ip_set = id.dest_ip_set;
        assert(! id.main_id);
        ArrayList<string> prefix_cmd = new ArrayList<string>.wrap({
            @"ip", @"netns", @"exec", @"$(id.network_namespace)"});

        foreach (string m in both_peermacs)
        {
            string table;
            int tid;
            tn.get_table(null, m, out tid, out table);
            foreach (HCoord hc in prev_dest_ip_set.gnode.keys)
            {
                DestinationIPSetGnode prev_dest = prev_dest_ip_set.gnode[hc];
                cat_cmd(prefix_cmd, {
                    @"ip", @"route", @"del", @"$(prev_dest.global)", @"table", @"$(table)"});
                cat_cmd(prefix_cmd, {
                    @"ip", @"route", @"del", @"$(prev_dest.anonymizing)", @"table", @"$(table)"});
                for (int k = levels-1; k >= hc.lvl+1; k--) if (k >= guest_gnode_level)
                {
                    cat_cmd(prefix_cmd, {
                        @"ip", @"route", @"del", @"$(prev_dest.intern[k])", @"table", @"$(table)"});
                }
            }
        }

        foreach (string m in prev_peermacs)
        {
            string table;
            int tid;
            tn.get_table(null, m, out tid, out table);
            cat_cmd(prefix_cmd, {
                @"ip", @"route", @"flush", @"table", @"$(table)"});
            cat_cmd(prefix_cmd, {
                @"ip", @"rule", @"del", @"fwmark", @"$(tid)", @"table", @"$(table)"});
            cat_cmd(prefix_cmd, {
                @"iptables", @"-t", @"mangle", @"-D", @"PREROUTING", @"-m", @"mac",
                @"--mac-source", @"$(m)", @"-j", @"MARK", @"--set-mark", @"$(tid)"});
            if (tn.decref_table(m) <= 0) tn.release_table(null, m);
        }

        foreach (string m in both_peermacs)
        {
            string table;
            int tid;
            tn.get_table(null, m, out tid, out table);
            foreach (HCoord hc in dest_ip_set.gnode.keys)
            {
                DestinationIPSetGnode dest = dest_ip_set.gnode[hc];
                cat_cmd(prefix_cmd, {
                    @"ip", @"route", @"add", @"unreachable", @"$(dest.global)", @"table", @"$(table)"});
                cat_cmd(prefix_cmd, {
                    @"ip", @"route", @"add", @"unreachable", @"$(dest.anonymizing)", @"table", @"$(table)"});
                for (int k = levels-1; k >= hc.lvl+1; k--) if (k >= guest_gnode_level)
                {
                    cat_cmd(prefix_cmd, {
                        @"ip", @"route", @"add", @"unreachable", @"$(dest.intern[k])", @"table", @"$(table)"});
                }
            }
        }

        foreach (string m in new_peermacs)
        {
            string table;
            int tid;
            tn.get_table(null, m, out tid, out table);
            cat_cmd(prefix_cmd, {
                @"iptables", @"-t", @"mangle", @"-A", @"PREROUTING", @"-m", @"mac",
                @"--mac-source", @"$(m)", @"-j", @"MARK", @"--set-mark", @"$(tid)"});
            cat_cmd(prefix_cmd, {
                @"ip", @"rule", @"add", @"fwmark", @"$(tid)", @"table", @"$(table)"});
            tn.incref_table(m);
            foreach (HCoord hc in dest_ip_set.gnode.keys)
            {
                DestinationIPSetGnode dest = dest_ip_set.gnode[hc];
                cat_cmd(prefix_cmd, {
                    @"ip", @"route", @"add", @"unreachable", @"$(dest.global)", @"table", @"$(table)"});
                cat_cmd(prefix_cmd, {
                    @"ip", @"route", @"add", @"unreachable", @"$(dest.anonymizing)", @"table", @"$(table)"});
                for (int k = levels-1; k >= hc.lvl+1; k--)
                {
                    cat_cmd(prefix_cmd, {
                        @"ip", @"route", @"add", @"unreachable", @"$(dest.intern[k])", @"table", @"$(table)"});
                }
            }
        }
    }

    void new_arc(IdentityData id)
    {
        warning("not implemented yet");
    }

    void map_update(IdentityData id)
    {
        warning("not implemented yet");
    }

    void changed_arc(IdentityData id)
    {
        warning("not implemented yet");
    }

    void removed_arc(IdentityData id)
    {
        warning("not implemented yet");
    }

    void connectivity_stop(IdentityData id)
    {
        warning("not implemented yet");
    }

    void main_stop(IdentityData id)
    {
        warning("not implemented yet");
    }
}