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
        foreach (int _g_exp in new int[]{2,1,1,1}) // hard-wired topology in bits.
        {
            if (_g_exp < 1 || _g_exp > 16) error(@"Bad g_exp $(_g_exp): must be between 1 and 16");
            int gsize = 1 << _g_exp;
            g_exp.insert(0, _g_exp);
            gsizes.insert(0, gsize);

            naddr.insert(0, 0); // Random(0..gsize-1) or 0.
        }
        levels = gsizes.size;
        hooking_epsilon = new ArrayList<int>();
        for (int i = 0; i < levels; i++)
        {
            int delta_bits = 5;
            int eps = 0;
            int j = i;
            while (delta_bits > 0 && j < levels)
            {
                eps++;
                delta_bits -= g_exp[j];
                j++;
            }
            eps++;
            hooking_epsilon.add(eps);
        }

        // Names of the network interfaces to monitor.
        devs = new ArrayList<string>();
        foreach (string dev in interfaces) devs.add(dev);
    }
}
