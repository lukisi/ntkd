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
using Netsukuku.Hooking;
using TaskletSystem;

namespace Netsukuku
{
    void per_identity_hooking_same_network(IdentityData id, IIdentityArc _ia)
    {
        IdentityArc ia = ((HookingIdentityArc)_ia).ia;
        warning("Not implemented yet: same_network");
    }

    void per_identity_hooking_another_network(IdentityData id, IIdentityArc _ia, int64 network_id)
    {
        IdentityArc ia = ((HookingIdentityArc)_ia).ia;
        warning("Not implemented yet: another_network");
    }

    void per_identity_hooking_do_prepare_migration(IdentityData id)
    {
        warning("Not implemented yet: do_prepare_migration");
    }

    void per_identity_hooking_do_finish_migration(IdentityData id)
    {
        warning("Not implemented yet: do_finish_migration");
    }

    void per_identity_hooking_do_prepare_enter(IdentityData id, int enter_id)
    {
        warning("Not implemented yet: do_prepare_enter");
    }

    void per_identity_hooking_do_finish_enter(IdentityData id,
        int enter_id, int guest_gnode_level, EntryData entry_data, int go_connectivity_position)
    {
        warning("Not implemented yet: do_finish_enter");
    }
}
