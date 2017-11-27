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
    void configuration(ref ArrayList<string> args, out ArrayList<int> naddr, out ArrayList<string> devs)
    {
        // TODO some argument to use in `args`?

        // First network: the node on its own. Topoplogy of the network and address of the node.
        naddr = new ArrayList<int>();
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
        devs = new ArrayList<string>();
        foreach (string dev in interfaces) devs.add(dev);
    }
}
