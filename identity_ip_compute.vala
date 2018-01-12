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

namespace Netsukuku.IpCompute
{
    void new_main_id(IdentityData id)
    {
        Gee.List<int> n_addr = id.my_naddr.pos;
        id.local_ip_set = new LocalIPSet();
        for (int k = 0; k < levels; k++)
            id.local_ip_set.intern[k] = ip_internal_node(n_addr, k);
        id.local_ip_set.global = ip_global_node(n_addr);
        id.local_ip_set.anonymizing = ip_anonymizing_node(n_addr);
        id.local_ip_set.anonymizing_range = ip_anonymizing_range();
        if (subnetlevel > 0)
        {
            id.local_ip_set.netmap_range1 = ip_netmap_range1();
            for (int k = subnetlevel; k <= levels-2; k++)
            {
                id.local_ip_set.netmap_range2[k] = ip_netmap_range2(n_addr, k);
                id.local_ip_set.netmap_range3[k] = ip_netmap_range3(k);
            }
            id.local_ip_set.netmap_range2_upper = ip_netmap_range2_upper(n_addr);
            id.local_ip_set.netmap_range3_upper = ip_netmap_range3_upper();
            id.local_ip_set.netmap_range4 = ip_netmap_range4(n_addr);
        }
    }

    void new_id(IdentityData id)
    {
        Gee.List<int> n_addr = id.my_naddr.pos;
        int up_to = -1;
        if (!id.main_id) up_to = id.connectivity_from_level-1;
        assert(is_real_from_to(n_addr, up_to+1, levels-1));

        for (int i = levels-1; i >= subnetlevel; i--)
            if (i >= up_to)
            for (int j = 0; j < gsizes[i]; j++)
            if (n_addr[i] != j)
        {
            HCoord hc = new HCoord(i, j);
            Gee.List<int> hc_addr = n_addr.slice(i+1, n_addr.size);
            hc_addr.insert(0, j);
            id.dest_ip_set.gnode[hc].global = ip_global_gnode(hc_addr);
            id.dest_ip_set.gnode[hc].anonymizing = ip_anonymizing_gnode(hc_addr);
            for (int k = levels-1; k >= i+1; k--)
                id.dest_ip_set.gnode[hc].intern[k] = ip_internal_gnode(hc_addr, k);
        }
    }

    bool is_real_from_to(Gee.List<int> n_addr, int from, int to)
    {
        for (int i = from; i <= to; i++)
            if (n_addr[i] >= gsizes[i]) return false;
        return true;
    }

    void gone_connectivity_id(IdentityData id, int prev_lvl, int prev_pos)
    {
        Gee.List<int> n_addr = id.my_naddr.pos;
        assert(is_real_from_to(n_addr, prev_lvl+1, levels-1));
        assert(prev_pos < gsizes[prev_lvl]);
        assert(n_addr[prev_lvl] >= gsizes[prev_lvl]);

        id.local_ip_set = null;
        int i = prev_lvl; int j = prev_pos;
        {
            HCoord hc = new HCoord(i, j);
            Gee.List<int> hc_addr = n_addr.slice(i+1, n_addr.size);
            hc_addr.insert(0, j);
            id.dest_ip_set.gnode[hc].global = ip_global_gnode(hc_addr);
            id.dest_ip_set.gnode[hc].anonymizing = ip_anonymizing_gnode(hc_addr);
            for (int k = levels-1; k >= i+1; k--)
                id.dest_ip_set.gnode[hc].intern[k] = ip_internal_gnode(hc_addr, k);
        }
        ArrayList<HCoord> dest_keys = new ArrayList<HCoord>();
        dest_keys.add_all(id.dest_ip_set.gnode.keys);
        foreach (HCoord hc in dest_keys) if (hc.lvl < prev_lvl)
            id.dest_ip_set.gnode.unset(hc);
    }
}
