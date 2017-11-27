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
    class IdmgmtNetnsManager : Object, IIdmgmtNetnsManager
    {
        public void create_namespace(string ns)
        {
            assert(ns != "");
            cm.single_command(new ArrayList<string>.wrap({
                @"ip", @"netns", @"add", @"$(ns)"}));
            cm.single_command(new ArrayList<string>.wrap({
                @"sysctl", @"net.ipv4.ip_forward=1"}));
            cm.single_command(new ArrayList<string>.wrap({
                @"sysctl", @"net.ipv4.conf.all.rp_filter=0"}));
        }

        public void create_pseudodev(string dev, string ns, string pseudo_dev, out string pseudo_mac)
        {
            assert(ns != "");
            cm.single_command(new ArrayList<string>.wrap({
                @"ip", @"link", @"add", @"dev", @"$(pseudo_dev)", @"link", @"$(dev)", @"type", @"macvlan"}));
            pseudo_mac = macgetter.get_mac(pseudo_dev).up();
            cm.single_command(new ArrayList<string>.wrap({
                @"ip", @"link", @"set", @"dev", @"$(pseudo_dev)", @"netns", @"$(ns)"}));
            // disable rp_filter
            cm.single_command(new ArrayList<string>.wrap({
                @"ip", @"netns", @"exec", @"$(ns)", @"sysctl", @"net.ipv4.conf.$(pseudo_dev).rp_filter=0"}));
            // arp policies
            cm.single_command(new ArrayList<string>.wrap({
                @"ip", @"netns", @"exec", @"$(ns)", @"sysctl", @"net.ipv4.conf.$(pseudo_dev).arp_ignore=1"}));
            cm.single_command(new ArrayList<string>.wrap({
                @"ip", @"netns", @"exec", @"$(ns)", @"sysctl", @"net.ipv4.conf.$(pseudo_dev).arp_announce=2"}));
            // up
            cm.single_command(new ArrayList<string>.wrap({
                @"ip", @"netns", @"exec", @"$(ns)", @"ip", @"link", @"set", @"dev", @"$(pseudo_dev)", @"up"}));
        }

        public void add_address(string ns, string pseudo_dev, string linklocal)
        {
            // ns may be empty-string.
            ArrayList<string> argv = new ArrayList<string>();
            if (ns != "") argv.add_all_array({@"ip", @"netns", @"exec", @"$(ns)"});
            argv.add_all_array({
                @"ip", @"address", @"add", @"$(linklocal)", @"dev", @"$(pseudo_dev)"});
            cm.single_command(argv);
        }

        public void add_gateway(string ns, string linklocal_src, string linklocal_dst, string dev)
        {
            // ns may be empty-string.
            ArrayList<string> argv = new ArrayList<string>();
            if (ns != "") argv.add_all_array({@"ip", @"netns", @"exec", @"$(ns)"});
            argv.add_all_array({
                @"ip", @"route", @"add", @"$(linklocal_dst)", @"dev", @"$(dev)", @"src", @"$(linklocal_src)"});
            cm.single_command(argv);
        }

        public void remove_gateway(string ns, string linklocal_src, string linklocal_dst, string dev)
        {
            // ns may be empty-string.
            ArrayList<string> argv = new ArrayList<string>();
            if (ns != "") argv.add_all_array({@"ip", @"netns", @"exec", @"$(ns)"});
            argv.add_all_array({
                @"ip", @"route", @"del", @"$(linklocal_dst)", @"dev", @"$(dev)", @"src", @"$(linklocal_src)"});
            cm.single_command(argv);
        }

        public void flush_table(string ns)
        {
            assert(ns != "");
            cm.single_command(new ArrayList<string>.wrap({
                @"ip", @"netns", @"exec", @"$(ns)", @"ip", @"route", @"flush", @"table", @"main"}));
        }

        public void delete_pseudodev(string ns, string pseudo_dev)
        {
            assert(ns != "");
            cm.single_command(new ArrayList<string>.wrap({
                @"ip", @"netns", @"exec", @"$(ns)", @"ip", @"link", @"delete", @"$(pseudo_dev)", @"type", @"macvlan"}));
        }

        public void delete_namespace(string ns)
        {
            assert(ns != "");
            cm.single_command(new ArrayList<string>.wrap({
                @"ip", @"netns", @"del", @"$(ns)"}));
        }
    }

    class IdmgmtStubFactory : Object, IIdmgmtStubFactory
    {
        public IIdmgmtArc? get_arc(CallerInfo caller)
        {
            if (caller is TcpclientCallerInfo)
            {
                TcpclientCallerInfo c = (TcpclientCallerInfo)caller;
                ISourceID sourceid = c.sourceid;
                string my_address = c.my_address;
                foreach (HandledNic n in handlednic_list)
                {
                    string dev = n.dev;
                    if (n.linklocal == my_address)
                    {
                        INeighborhoodArc? neighborhood_arc = neighborhood_mgr.get_node_arc(sourceid, dev);
                        if (neighborhood_arc == null)
                        {
                            // some warning message?
                            return null;
                        }
                        foreach (Arc arc in arc_list)
                        {
                            if (arc.neighborhood_arc == neighborhood_arc)
                            {
                                return arc.idmgmt_arc;
                            }
                        }
                        error("missing something?");
                    }
                }
                print(@"got a unknown caller:\n");
                print(@"  my_address was $(my_address).\n");
                foreach (HandledNic n in handlednic_list)
                {
                    string dev = n.dev;
                    print(@"  in $(dev) we have $(n.linklocal).\n");
                }
                return null;
            }
            error(@"not a expected type of caller $(caller.get_type().name()).");
        }

        public IIdentityManagerStub get_stub(IIdmgmtArc arc)
        {
            IdmgmtArc _arc = (IdmgmtArc)arc;
            IAddressManagerStub addrstub = 
                neighborhood_mgr.get_stub_whole_node_unicast(_arc.arc.neighborhood_arc);
            IdentityManagerStubHolder ret = new IdentityManagerStubHolder(addrstub);
            return ret;
        }
    }

    class IdmgmtArc : Object, IIdmgmtArc
    {
        public IdmgmtArc(Arc arc)
        {
            this.arc = arc;
        }
        public weak Arc arc;

        public string get_dev()
        {
            return arc.neighborhood_arc.nic.dev;
        }

        public string get_peer_mac()
        {
            return arc.neighborhood_arc.neighbour_mac;
        }

        public string get_peer_linklocal()
        {
            return arc.neighborhood_arc.neighbour_nic_addr;
        }
    }
}
