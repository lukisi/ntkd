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
using TaskletSystem;

namespace Netsukuku
{
    [CCode (array_length = false, array_null_terminated = true)]
    string[] interfaces;

    ITasklet tasklet;
    Commander cm;

    int main(string[] _args)
    {
        OptionContext oc = new OptionContext("<options>");
        OptionEntry[] entries = new OptionEntry[2];
        int index = 0;
        entries[index++] = {"interfaces", 'i', 0, OptionArg.STRING_ARRAY, ref interfaces, "Interface (e.g. -i eth1). You can use it multiple times.", null};
        entries[index++] = { null };
        oc.add_main_entries(entries, null);
        try {
            oc.parse(ref _args);
        }
        catch (OptionError e) {
            print(@"Error parsing options: $(e.message)\n");
            return 1;
        }

        // Names of the network interfaces that the program must handle.
        ArrayList<string> devs = new ArrayList<string>();
        foreach (string dev in interfaces) devs.add(dev);

        // Initialize tasklet system
        PthTaskletImplementer.init();
        tasklet = PthTaskletImplementer.get_tasklet_system();

        // Commander
        cm = Commander.get_singleton();

        TaskletCommandResult com_ret;
        /*
        public int exit_status;
        public string stderr;
        public string stdout;
        */
        Gee.List<string> lines;

        com_ret = cm.command(new ArrayList<string>.wrap({
            @"ip", @"netns", @"list"}));
        lines = get_lines(com_ret.stdout);
        foreach (string line in lines)
        {
            if (line.has_prefix("ntkv"))
            {
                cm.start_console_log();
                cm.command(new ArrayList<string>.wrap({
                    @"ip", @"netns", @"del", @"$(line)"}));
                cm.stop_console_log();
            }
        }

        com_ret = cm.command(new ArrayList<string>.wrap({
            @"ip", @"link", @"show"}));
        lines = get_lines(com_ret.stdout);
        foreach (string line in lines)
        {
            if (line.has_prefix("   ")) continue;
            MatchInfo match_info;
            if (/ntkv.+:/.match(line, 0, out match_info))
            {
                string pseudo_dev = match_info.fetch(0);
                // remove trailing ':'
                pseudo_dev = pseudo_dev.substring(0, pseudo_dev.length-1);
                // if there is a '@', only first part.
                if ("@" in pseudo_dev) pseudo_dev = pseudo_dev.substring(0, pseudo_dev.index_of("@"));
                // ready.
                cm.start_console_log();
                com_ret = cm.command(new ArrayList<string>.wrap({
                    @"ip", @"link", @"delete", @"$(pseudo_dev)", @"type", @"macvlan"}));
                cm.stop_console_log();
            }
        }

        table_names_fix();
        table_names_verify();

        return 0;
    }

    void table_names_fix()
    {
        TaskletCommandResult com_ret;
        /*
        public int exit_status;
        public string stderr;
        public string stdout;
        */
        Gee.List<string> lines;

        com_ret = cm.mayfail_command(new ArrayList<string>.wrap({
            @"egrep", @"^251 ", @"/etc/iproute2/rt_tables"}));
        lines = get_lines(com_ret.stdout);
        if (lines.size != 1 || lines[0] != "251 ntk")
        {
            cm.start_console_log();
            cm.command(new ArrayList<string>.wrap({
                @"cp", @"/etc/iproute2/rt_tables_orig", @"/etc/iproute2/rt_tables"}));
            cm.stop_console_log();
            return;
        }

        for (int i = 250; i >= 200; i--)
        {
            com_ret = cm.mayfail_command(new ArrayList<string>.wrap({
                @"egrep", @"^$(i) ", @"/etc/iproute2/rt_tables"}));
            lines = get_lines(com_ret.stdout);
            if (lines.size == 1 && lines[0] == @"$(i) reserved_ntk_from_$(i)") continue;
            if (lines.size == 1)
            {
                string prefix = @"$(i) ntk_from_";
                if (lines[0].has_prefix(prefix))
                {
                    string mac = lines[0].substring(prefix.length);
                    if (mac.length == 17)
                    {
                        cm.start_console_log();
                        com_ret = cm.command(new ArrayList<string>.wrap({
                            @"sed", @"-i", @"s/$(lines[0])/$(i) reserved_ntk_from_$(i)/", @"/etc/iproute2/rt_tables"}));
                        cm.stop_console_log();
                        continue;
                    }
                }
            }
            cm.start_console_log();
            cm.command(new ArrayList<string>.wrap({
                @"cp", @"/etc/iproute2/rt_tables_orig", @"/etc/iproute2/rt_tables"}));
            cm.stop_console_log();
            return;
        }
    }

    void table_names_verify()
    {
        TaskletCommandResult com_ret;
        /*
        public int exit_status;
        public string stderr;
        public string stdout;
        */
        Gee.List<string> lines;

        com_ret = cm.mayfail_command(new ArrayList<string>.wrap({
            @"egrep", @"^251 ", @"/etc/iproute2/rt_tables"}));
        lines = get_lines(com_ret.stdout);
        if (lines.size != 1 || lines[0] != "251 ntk")
        {
            error(@"table_names_verify: problem with tid 251.");
        }

        for (int i = 250; i >= 200; i--)
        {
            com_ret = cm.mayfail_command(new ArrayList<string>.wrap({
                @"egrep", @"^$(i) ", @"/etc/iproute2/rt_tables"}));
            lines = get_lines(com_ret.stdout);
            if (lines.size == 1 && lines[0] == @"$(i) reserved_ntk_from_$(i)") continue;
            error(@"table_names_verify: problem with tid $(i).");
        }
    }

    Gee.List<string> get_lines(string text)
    {
        ArrayList<string> ret = new ArrayList<string>();
        MatchInfo match_info;
        Regex r = /^.*$/m;
        r.match(text, 0, out match_info);
        while (match_info.matches())
        {
            string line = match_info.fetch(0);
            ret.add(line);
            try {
                match_info.next();
            } catch (RegexError e) {
                error(@"get_lines: $(e.message)");
            }
        }
        if (!ret.is_empty && ret.last() == "") ret.remove_at(ret.size-1);
        return ret;
    }
}

