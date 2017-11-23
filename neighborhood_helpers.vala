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
    class NeighborhoodIPRouteManager : Object, INeighborhoodIPRouteManager
    {
        public void add_address(string my_addr, string my_dev)
        {
            cm.single_command(new ArrayList<string>.wrap({
                @"ip", @"address", @"add", @"$(my_addr)", @"dev", @"$(my_dev)"}));
        }

        public void add_neighbor(string my_addr, string my_dev, string neighbor_addr)
        {
            cm.single_command(new ArrayList<string>.wrap({
                @"ip", @"route", @"add", @"$(neighbor_addr)", @"dev", @"$(my_dev)", @"src", @"$(my_addr)"}));
        }

        public void remove_neighbor(string my_addr, string my_dev, string neighbor_addr)
        {
            cm.single_command(new ArrayList<string>.wrap({
                @"ip", @"route", @"del", @"$(neighbor_addr)", @"dev", @"$(my_dev)", @"src", @"$(my_addr)"}));
        }

        public void remove_address(string my_addr, string my_dev)
        {
            cm.single_command(new ArrayList<string>.wrap({
                @"ip", @"address", @"del", @"$(my_addr)/32", @"dev", @"$(my_dev)"}));
        }
    }

    class NeighborhoodStubFactory : Object, INeighborhoodStubFactory
    {
        public IAddressManagerStub
        get_broadcast(
            Gee.List<string> devs,
            Gee.List<string> src_ips,
            ISourceID source_id,
            IBroadcastID broadcast_id,
            IAckCommunicator? ack_com = null)
        {
            assert(! devs.is_empty);
            assert(devs.size == src_ips.size);
            var bc = get_addr_broadcast(devs, src_ips, ntkd_port, source_id, broadcast_id, ack_com);
            return bc;
        }

        public IAddressManagerStub
        get_unicast(
            string dev,
            string src_ip,
            ISourceID source_id,
            IUnicastID unicast_id,
            bool wait_reply = true)
        {
            var uc = get_addr_unicast(dev, ntkd_port, src_ip, source_id, unicast_id, wait_reply);
            return uc;
        }

        public IAddressManagerStub
        get_tcp(
            string dest,
            ISourceID source_id,
            IUnicastID unicast_id,
            bool wait_reply = true)
        {
            var tc = get_addr_tcp_client(dest, ntkd_port, source_id, unicast_id);
            assert(tc is ITcpClientRootStub);
            ((ITcpClientRootStub)tc).wait_reply = wait_reply;
            return tc;
        }
    }

    class NeighborhoodNetworkInterface : Object, INeighborhoodNetworkInterface
    {
        public NeighborhoodNetworkInterface(string dev)
        {
            _dev = dev;
            _mac = macgetter.get_mac(dev).up();
        }
        private string _dev;
        private string _mac;

        public string dev {
            get {
                return _dev;
            }
        }

        public string mac {
            get {
                return _mac;
            }
        }

        public long measure_rtt(string peer_addr, string peer_mac, string my_dev, string my_addr) throws NeighborhoodGetRttError
        {
            TaskletCommandResult com_ret;
            try {
                //print(@"ping -n -q -c 1 $(peer_addr)\n");
                com_ret = tasklet.exec_command(@"ping -n -q -c 1 $(peer_addr)");
            } catch (Error e) {
                throw new NeighborhoodGetRttError.GENERIC(@"Unable to spawn a command: $(e.message)");
            }
            if (com_ret.exit_status != 0)
                throw new NeighborhoodGetRttError.GENERIC(@"ping: error $(com_ret.stdout)");
            foreach (string line in com_ret.stdout.split("\n"))
            {
                /*  """rtt min/avg/max/mdev = 2.854/2.854/2.854/0.000 ms"""  */
                if (line.has_prefix("rtt ") && line.has_suffix(" ms"))
                {
                    string s2 = line.substring(line.index_of(" = ") + 3);
                    string s3 = s2.substring(0, s2.index_of("/"));
                    double x;
                    bool res = double.try_parse (s3, out x);
                    if (res)
                    {
                        long ret = (long)(x * 1000);
                        //print(@" returned $(ret) microseconds.\n");
                        return ret;
                    }
                }
            }
            throw new NeighborhoodGetRttError.GENERIC(@"could not parse $(com_ret.stdout)");
        }
    }

    IAddressManagerSkeleton?
    get_identity_skeleton(
        NodeID source_id,
        NodeID unicast_id,
        string peer_address)
    {
        error("not implemented yet");
    }

    Gee.List<IAddressManagerSkeleton>
    get_identity_skeleton_set(
        NodeID source_id,
        Gee.List<NodeID> broadcast_set,
        string peer_address,
        string dev)
    {
        error("not implemented yet");
    }
}
