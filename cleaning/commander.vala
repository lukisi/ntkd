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
using TaskletSystem;

namespace Netsukuku
{
    [NoReturn]
    internal void error_in_command(ArrayList<string> cmd_args, string stdout, string stderr)
    {
        string cmd = cmd_repr(cmd_args);
        print("Error in command:\n");
        print(@"   $(cmd)\n");
        print("command stdout =======\n");
        print(@"$(stdout)\n");
        print("======================\n");
        print("command stderr =======\n");
        print(@"$(stderr)\n");
        print("======================\n");
        error(@"Error in command: `$(cmd)`");
    }

    internal string cmd_repr(ArrayList<string> cmd_args)
    {
        string cmd = ""; string sep = "";
        foreach (string arg in cmd_args)
        {
            cmd += sep;
            if (" " in arg) cmd += @"'$(arg)'";
            else cmd += arg;
            sep = " ";
        }
        return cmd;
    }

    class Commander : Object
    {
        public static Commander get_singleton()
        {
            if (singleton == null) singleton = new Commander();
            return singleton;
        }

        private static Commander singleton;

        private Commander()
        {
            log_console = false;
        }

        private bool log_console;

        public void start_console_log()
        {
            log_console = true;
        }

        public void stop_console_log()
        {
            log_console = false;
        }

        // Launch a command that shall not fail.
        public TaskletCommandResult command(ArrayList<string> cmd_args)
        {
            var com_ret = mayfail_command(cmd_args);
            if (com_ret.exit_status != 0)
                error_in_command(cmd_args, com_ret.stdout, com_ret.stderr);
            return com_ret;
        }

        // Launch a command that might fail.
        public TaskletCommandResult mayfail_command(ArrayList<string> cmd_args)
        {
            try {
                string cmd = cmd_repr(cmd_args);
                if (log_console) print(@"$$ $(cmd)\n");
                var com_ret = tasklet.exec_command_argv(cmd_args);
                if (log_console)
                {
                    if (com_ret.exit_status != 0) print(@"ret: $(com_ret.exit_status)\n");
                    if (com_ret.stdout != "" && ! ("sysctl" in cmd)) print(@"OUT: $(com_ret.stdout)");
                    if (com_ret.stderr != "") print(@"ERR: $(com_ret.stderr)");
                }
                return com_ret;
            } catch (Error e) {error(@"Unable to spawn a command: $(e.message)");}
        }
    }
}
