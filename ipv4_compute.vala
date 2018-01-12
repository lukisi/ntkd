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

namespace Netsukuku
{
    string ip_global_node(Gee.List<int> n_addr)
    {
        // 1·2·3·4·5 in public-range
        // Used in order to set its own address. Or to compute address to return from andna_resolv.
        assert(n_addr.size == levels);
        for (int l = 0; l < levels; l++)
        {
            assert(n_addr[l] < gsizes[l]);
            assert(n_addr[l] >= 0);
        }
        int32 ip = 0;
        for (int c = levels - 1; c >= 0; c--)
        {
            ip <<= g_exp[c];
            ip += n_addr[c];
        }
        int i0 = ip & 255;
        ip >>= 8;
        int i1 = ip & 255;
        ip >>= 8;
        int i2 = ip;
        string ret = @"10.$(i2).$(i1).$(i0)";
        return ret;
    }

    string ip_anonymizing_node(Gee.List<int> n_addr)
    {
        // 1·2·3·4·5 in anon-range
        // Used in order to set its own address. Or to compute address to return from andna_resolv.
        assert(n_addr.size == levels);
        for (int l = 0; l < levels; l++)
        {
            assert(n_addr[l] < gsizes[l]);
            assert(n_addr[l] >= 0);
        }
        int32 ip = 2;
        for (int c = levels - 1; c >= 0; c--)
        {
            ip <<= g_exp[c];
            ip += n_addr[c];
        }
        int i0 = ip & 255;
        ip >>= 8;
        int i1 = ip & 255;
        ip >>= 8;
        int i2 = ip;
        string ret = @"10.$(i2).$(i1).$(i0)";
        return ret;
    }

    string ip_global_gnode(Gee.List<int> hc_addr)
    {
        // 1·2·3·* in public-range
        // Used to set a route to a destination.
        assert(hc_addr.size <= levels);
        Gee.List<int> n_addr = new ArrayList<int>();
        int n_level = levels - hc_addr.size;
        for (int i = 0; i < n_level; i++) n_addr.add(0);
        n_addr.add_all(hc_addr);
        for (int l = n_level; l < levels; l++)
        {
            assert(n_addr[l] < gsizes[l]);
            assert(n_addr[l] >= 0);
        }
        assert(n_level >= 0);
        assert(n_level <= levels);
        int32 ip = 0;
        for (int c = levels - 1; c >= 0; c--)
        {
            ip <<= g_exp[c];
            if (c >= n_level) ip += n_addr[c];
        }
        int i0 = ip & 255;
        ip >>= 8;
        int i1 = ip & 255;
        ip >>= 8;
        int i2 = ip;
        int sum = 0;
        for (int k = 0; k <= n_level - 1; k++) sum += g_exp[k];
        int prefix = 32 - sum;
        string ret = @"10.$(i2).$(i1).$(i0)/$(prefix)";
        return ret;
    }

    string ip_anonymizing_gnode(Gee.List<int> hc_addr)
    {
        // 1·2·3·* in anon-range
        // Used to set a route to a destination.
        assert(hc_addr.size <= levels);
        Gee.List<int> n_addr = new ArrayList<int>();
        int n_level = levels - hc_addr.size;
        for (int i = 0; i < n_level; i++) n_addr.add(0);
        n_addr.add_all(hc_addr);
        for (int l = n_level; l < levels; l++)
        {
            assert(n_addr[l] < gsizes[l]);
            assert(n_addr[l] >= 0);
        }
        assert(n_level >= 0);
        assert(n_level <= levels);
        int32 ip = 2;
        for (int c = levels - 1; c >= 0; c--)
        {
            ip <<= g_exp[c];
            if (c >= n_level) ip += n_addr[c];
        }
        int i0 = ip & 255;
        ip >>= 8;
        int i1 = ip & 255;
        ip >>= 8;
        int i2 = ip;
        int sum = 0;
        for (int k = 0; k <= n_level - 1; k++) sum += g_exp[k];
        int prefix = 32 - sum;
        string ret = @"10.$(i2).$(i1).$(i0)/$(prefix)";
        return ret;
    }

    string ip_internal_node(Gee.List<int> n_addr, int inside_level)
    {
        // *·3·4·5 in public-range
        // Used in order to set its own address. Or to compute address to return from andna_resolv.
        assert(n_addr.size == levels);
        for (int l = 0; l < inside_level; l++)
        {
            assert(n_addr[l] < gsizes[l]);
            assert(n_addr[l] >= 0);
        }
        assert(inside_level >= 0);
        assert(inside_level < levels);
        int32 ip = 1;
        for (int c = levels - 1; c >= 0; c--)
        {
            ip <<= g_exp[c];
            if (c == levels - 1) ip += inside_level;
            else if (c >= inside_level) {}
            else ip += n_addr[c];
        }
        int i0 = ip & 255;
        ip >>= 8;
        int i1 = ip & 255;
        ip >>= 8;
        int i2 = ip;
        string ret = @"10.$(i2).$(i1).$(i0)";
        return ret;
    }

    string ip_internal_gnode(Gee.List<int> hc_addr, int inside_level)
    {
        // *·3·* in public-range
        // Used to set a route to a destination.
        assert(hc_addr.size <= levels);
        Gee.List<int> n_addr = new ArrayList<int>();
        int n_level = levels - hc_addr.size;
        for (int i = 0; i < n_level; i++) n_addr.add(0);
        n_addr.add_all(hc_addr);
        for (int l = n_level; l < inside_level; l++)
        {
            assert(n_addr[l] < gsizes[l]);
            assert(n_addr[l] >= 0);
        }
        assert(n_level >= 0);
        assert(n_level < levels);
        assert(inside_level >= n_level);
        assert(inside_level < levels);
        int32 ip = 1;
        for (int c = levels - 1; c >= 0; c--)
        {
            ip <<= g_exp[c];
            if (c == levels - 1) ip += inside_level;
            else if (c >= inside_level) {}
            else if (c < n_level) {}
            else ip += n_addr[c];
        }
        int i0 = ip & 255;
        ip >>= 8;
        int i1 = ip & 255;
        ip >>= 8;
        int i2 = ip;
        int sum = 0;
        for (int k = 0; k <= n_level - 1; k++) sum += g_exp[k];
        int prefix = 32 - sum;
        string ret = @"10.$(i2).$(i1).$(i0)/$(prefix)";
        return ret;
    }

    string ip_anonymizing_range()
    {
        // Fake hc_addr of 0 positions (that is level `levels`)
        Gee.List<int> hc_addr = new ArrayList<int>();
        // Range of addresses anonymizing which comprises all the nodes of the whole network.
        //  It does not depend on n_addr.
        return ip_anonymizing_gnode(hc_addr);
    }

    string ip_netmap_range1()
    {
        // Fake hc_addr of levels-subnetlevel positions (that is level `subnetlevel`)
        Gee.List<int> hc_addr = new ArrayList<int>();
        for (int i = subnetlevel; i < levels; i++) hc_addr.add(0);
        // Range of addresses internal to a g-node of level "subnetlevel" which comprises all the nodes
        //  in our g-node of level "subnetlevel". It does not depend on n_addr.
        return ip_internal_gnode(hc_addr, subnetlevel);
    }

    string ip_netmap_range2(Gee.List<int> n_addr, int inside_level)
    {
        // An hc_addr for our position at level `subnetlevel`
        Gee.List<int> hc_addr = n_addr.slice(subnetlevel, n_addr.size);
        // Range of addresses internal to a g-node of level "inside_level+1" which comprises all the nodes
        //  in our g-node of level "subnetlevel". It does depend on n_addr positions at
        //  levels from "subnetlevel" to "inside_level".
        return ip_internal_gnode(hc_addr, inside_level+1);
    }

    string ip_netmap_range3(int inside_level)
    {
        // Fake hc_addr of levels-(inside_level+1) positions (that is level `inside_level+1`)
        Gee.List<int> hc_addr = new ArrayList<int>();
        for (int i = inside_level+1; i < levels; i++) hc_addr.add(0);
        // Range of addresses internal to a g-node of level "inside_level+1" which comprises all the nodes
        //  in our g-node of level "inside_level+1". It does not depend on n_addr.
        return ip_internal_gnode(hc_addr, inside_level+1);
    }

    string ip_netmap_range2_upper(Gee.List<int> n_addr)
    {
        // An hc_addr for our position at level `subnetlevel`
        Gee.List<int> hc_addr = n_addr.slice(subnetlevel, n_addr.size);
        // Range of addresses global which comprises all the nodes
        //  in our g-node of level "subnetlevel". It does depend on n_addr positions at
        //  levels from "subnetlevel" to "levels-1".
        return ip_global_gnode(hc_addr);
    }

    string ip_netmap_range3_upper()
    {
        // Fake hc_addr of 0 positions (that is level `levels`)
        Gee.List<int> hc_addr = new ArrayList<int>();
        // Range of addresses global which comprises all the nodes of the whole network.
        //  It does not depend on n_addr.
        return ip_global_gnode(hc_addr);
    }

    string ip_netmap_range4(Gee.List<int> n_addr)
    {
        // An hc_addr for our position at level `subnetlevel`
        Gee.List<int> hc_addr = n_addr.slice(subnetlevel, n_addr.size);
        // Range of addresses anonymizing which comprises all the nodes
        //  in our g-node of level "subnetlevel". It does depend on n_addr positions at
        //  levels from "subnetlevel" to "levels-1".
        return ip_anonymizing_gnode(hc_addr);
    }
}
