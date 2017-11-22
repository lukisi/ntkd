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
            command_dispatcher = tasklet.create_dispatchable_tasklet();
            log_console = false;
            blocks = new HashMap<int, BeginBlockTasklet>();
            next_block_id = 0;
        }

        private DispatchableTasklet command_dispatcher;
        private bool log_console;

        public void start_console_log()
        {
            log_console = true;
        }

        public void stop_console_log()
        {
            log_console = false;
        }

        /* Single command
        ** 
        */

        public void single_command(ArrayList<string> cmd_args, bool wait=true)
        {
            SingleCommandTasklet ts = new SingleCommandTasklet();
            ts.cm_t = this;
            ts.cmd_args = cmd_args;
            command_dispatcher.dispatch(ts, wait);
        }
        private void tasklet_single_command(ArrayList<string> cmd_args)
        {
            try {
                string cmd = cmd_repr(cmd_args);
                if (log_console) print(@"$$ $(cmd)\n");
                TaskletCommandResult com_ret = tasklet.exec_command_argv(cmd_args);
                if (log_console)
                {
                    if (com_ret.exit_status != 0) print(@"ret: $(com_ret.exit_status)\n");
                    if (com_ret.stdout != "" && ! ("sysctl" in cmd)) print(@"OUT: $(com_ret.stdout)");
                    if (com_ret.stderr != "") print(@"ERR: $(com_ret.stderr)");
                }
                if (com_ret.exit_status != 0)
                    error_in_command(cmd_args, com_ret.stdout, com_ret.stderr);
            } catch (Error e) {error(@"Unable to spawn a command: $(e.message)");}
        }
        class SingleCommandTasklet : Object, ITaskletSpawnable
        {
            public Commander cm_t;
            public ArrayList<string> cmd_args;
            public void * func()
            {
                cm_t.tasklet_single_command(cmd_args);
                return null;
            }
        }

        /* Block of commands
        ** 
        */

        private HashMap<int, BeginBlockTasklet> blocks;
        private int next_block_id;
        public int begin_block()
        {
            int block_id = next_block_id++;
            blocks[block_id] = new BeginBlockTasklet(this);
            command_dispatcher.dispatch(blocks[block_id], false, true); // wait for start, not for end
            return block_id;
        }
        private class BeginBlockTasklet : Object, ITaskletSpawnable
        {
            public BeginBlockTasklet(Commander cm_t)
            {
                this.cm_t = cm_t;
                ch = tasklet.get_channel();
                cmds = new ArrayList<ArrayList<string>>();
            }

            private Commander cm_t;
            private IChannel ch;
            private ArrayList<ArrayList<string>> cmds;
            private bool wait;

            public void single_command_in_block(ArrayList<string> cmd_args)
            {
                cmds.add(cmd_args);
            }

            public void end_block(bool wait)
            {
                this.wait = wait;
                if (wait)
                {
                    ch.send(0);
                    ch.recv();
                }
                else
                {
                    ch.send_async(0);
                }
            }

            public void * func()
            {
                ch.recv();
                foreach (ArrayList<string> cmd_args in cmds) cm_t.tasklet_single_command(cmd_args);
                if (wait) ch.send(0);
                return null;
            }
        }

        public void single_command_in_block(int block_id, ArrayList<string> cmd_args)
        {
            assert(blocks.has_key(block_id));
            blocks[block_id].single_command_in_block(cmd_args);
        }

        public void end_block(int block_id, bool wait=true)
        {
            assert(blocks.has_key(block_id));
            blocks[block_id].end_block(wait);
            blocks.unset(block_id);
        }
    }
}
