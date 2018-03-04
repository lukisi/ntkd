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
    void neighborhood_nic_address_set(string my_dev, string my_addr)
    {
        if (identity_mgr != null)
        {
            print(@"Warning: Signal `nic_address_set($(my_dev),$(my_addr))` when module Identities is already initialized.\n");
            print(@"         This should not happen and will be ignored.\n");
            return;
        }
        string my_mac = macgetter.get_mac(my_dev).up();
        HandledNic n = new HandledNic();
        n.dev = my_dev;
        n.mac = my_mac;
        n.linklocal = my_addr;
        handlednic_list.add(n);
    }

    void neighborhood_arc_added(INeighborhoodArc neighborhood_arc)
    {
        // Add arc to module Identities and to arc_list
        IdmgmtArc arc = new IdmgmtArc(neighborhood_arc);
        arc_list.add(arc);
        identity_mgr.add_arc(arc);
    }

    void neighborhood_arc_changed(INeighborhoodArc neighborhood_arc)
    {
        // TODO for each identity, for each id-arc, if qspn_arc is present, change cost
    }

    void neighborhood_arc_removing(INeighborhoodArc neighborhood_arc, bool is_still_usable)
    {
        // Remove arc from module Identities
        IdmgmtArc? to_del = null;
        foreach (IdmgmtArc arc in arc_list) if (arc.neighborhood_arc == neighborhood_arc) {to_del = arc; break;}
        if (to_del == null) return;
        identity_mgr.remove_arc(to_del);
        // TODO Do we need to wait for map update? how much?
    }

    void neighborhood_arc_removed(INeighborhoodArc neighborhood_arc)
    {
        // Remove arc from arc_list
        IdmgmtArc? to_del = null;
        foreach (IdmgmtArc arc in arc_list) if (arc.neighborhood_arc == neighborhood_arc) {to_del = arc; break;}
        if (to_del == null) return;
        arc_list.remove(to_del);
        // TODO ?
    }

    void neighborhood_nic_address_unset(string my_dev, string my_addr)
    {
        // TODO ?
    }
}
