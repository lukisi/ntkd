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
using Netsukuku.Qspn;
using Netsukuku.Neighborhood;

namespace Netsukuku
{
    public class Naddr : Object, IQspnAddress, IQspnNaddr, IQspnMyNaddr, Json.Serializable
    {
        public ArrayList<int> pos {get; set;}
        public ArrayList<int> sizes {get; set;}
        public Naddr(int[] pos, int[] sizes)
        {
            assert(sizes.length == pos.length);
            this.pos = new ArrayList<int>();
            this.pos.add_all_array(pos);
            this.sizes = new ArrayList<int>();
            this.sizes.add_all_array(sizes);
        }

        /*
        public int get_real_up_to()
        {
            int levels = sizes.size;
            int real_up_to = -1;
            while (real_up_to < levels-1)
            {
                if (pos[real_up_to+1] >= sizes[real_up_to+1]) break;
                real_up_to++;
            }
            return real_up_to;
        }

        public int get_virtual_up_to()
        {
            int levels = sizes.size;
            int virtual_up_to = levels-1;
            while (virtual_up_to >= 0)
            {
                if (pos[virtual_up_to] >= sizes[virtual_up_to]) break;
                virtual_up_to--;
            }
            return virtual_up_to;
        }
        */

        public bool is_real_from_to(int from, int to)
        {
            for (int i = from; i <= to; i++)
                if (pos[i] >= sizes[i]) return false;
            return true;
        }

        public bool deserialize_property
        (string property_name,
         out GLib.Value @value,
         GLib.ParamSpec pspec,
         Json.Node property_node)
        {
            @value = 0;
            switch (property_name) {
            case "pos":
            case "sizes":
                try {
                    ArrayList<int> ret = new ArrayList<int>();
                    ret.add_all(deserialize_list_int(property_node));
                    @value = ret;
                } catch (HelperDeserializeError e) {
                    return false;
                }
                break;
            default:
                return false;
            }
            return true;
        }

        public unowned GLib.ParamSpec? find_property
        (string name)
        {
            return get_class().find_property(name);
        }

        public Json.Node serialize_property
        (string property_name,
         GLib.Value @value,
         GLib.ParamSpec pspec)
        {
            switch (property_name) {
            case "pos":
            case "sizes":
                return serialize_list_int((Gee.List<int>)@value);
            default:
                error(@"wrong param $(property_name)");
            }
        }

        public int i_qspn_get_levels()
        {
            return sizes.size;
        }

        public int i_qspn_get_gsize(int level)
        {
            return sizes[level];
        }

        public int i_qspn_get_pos(int level)
        {
            return pos[level];
        }

        public HCoord i_qspn_get_coord_by_address(IQspnNaddr dest)
        {
            int l = pos.size-1;
            while (l >= 0)
            {
                if (pos[l] != dest.i_qspn_get_pos(l)) return new HCoord(l, dest.i_qspn_get_pos(l));
                l--;
            }
            // same naddr: error
            return new HCoord(-1, -1);
        }

        public bool equals(Naddr o)
        {
            if (pos.size != o.pos.size) return false;
            for (int i = 0; i < pos.size; i++)
            {
                if (pos[i] != o.pos[i]) return false;
                if (sizes[i] != o.sizes[i]) return false;
            }
            return true;
        }
    }

    public class Fingerprint : Object, IQspnFingerprint, Json.Serializable
    {
        public int64 id {get; set;}
        public int level {get; set;}
        // elderships has n items, where level + n = levels of the network.
        public ArrayList<int> elderships {get; set;}
        public ArrayList<int> elderships_seed {get; set;}
        public Fingerprint(int[] elderships, int64 id=-1)
        {
            if (id == -1)
            {
                this.id = PRNGen.int_range(0, int32.MAX);
                this.id *= int32.MAX;
                this.id = PRNGen.int_range(0, int32.MAX);
            }
            else
                this.id = id;
            level = 0;
            this.elderships = new ArrayList<int>();
            this.elderships.add_all_array(elderships);
            elderships_seed = new ArrayList<int>();
        }

        public bool deserialize_property
        (string property_name,
         out GLib.Value @value,
         GLib.ParamSpec pspec,
         Json.Node property_node)
        {
            @value = 0;
            switch (property_name) {
            case "id":
                try {
                    @value = deserialize_int64(property_node);
                } catch (HelperDeserializeError e) {
                    return false;
                }
                break;
            case "level":
                try {
                    @value = deserialize_int(property_node);
                } catch (HelperDeserializeError e) {
                    return false;
                }
                break;
            case "elderships_seed":
            case "elderships-seed":
            case "elderships":
                try {
                    ArrayList<int> ret = new ArrayList<int>();
                    ret.add_all(deserialize_list_int(property_node));
                    @value = ret;
                } catch (HelperDeserializeError e) {
                    return false;
                }
                break;
            default:
                return false;
            }
            return true;
        }

        public unowned GLib.ParamSpec? find_property
        (string name)
        {
            return get_class().find_property(name);
        }

        public Json.Node serialize_property
        (string property_name,
         GLib.Value @value,
         GLib.ParamSpec pspec)
        {
            switch (property_name) {
            case "id":
                return serialize_int64((int64)@value);
            case "level":
                return serialize_int((int)@value);
            case "elderships_seed":
            case "elderships-seed":
            case "elderships":
                return serialize_list_int((Gee.List<int>)@value);
            default:
                error(@"wrong param $(property_name)");
            }
        }

        private Fingerprint.empty() {}

        public bool i_qspn_equals(IQspnFingerprint other)
        {
            assert(other is Fingerprint);
            Fingerprint _other = (Fingerprint)other;

            /* The level of the destination must be the same (and also the pos)
             */
            assert(_other.level == level);

            if (_other.id != id) return false;
            return true;
        }

        private bool elder(IQspnFingerprint other)
        {
            /* The class uses this method to compare fingerprints referred to
             * two distinct destination in the same upper g-node.
             */

            assert(other is Fingerprint);
            Fingerprint _other = (Fingerprint)other;

            /* The level of the destination must be the same (but not the pos)
             */
            assert(_other.level == level);

            if (elderships[0] == -1) return false; // other is elder, because mine is_null_eldership.

            if (_other.elderships[0] < elderships[0]) return false; // other is elder
            return true;
        }

        public bool i_qspn_elder_seed(IQspnFingerprint other)
        {
            /* The program should use this method to compare fingerprints referred to
             * one destination. And after that i_qspn_equals reveals that they are not
             * equal. And only for levels greater than 0.
             */

            assert(other is Fingerprint);
            Fingerprint _other = other as Fingerprint;

            /* The level of the destination must be the same (and also the pos)
             */
            assert(_other.level == level);
            assert(level > 0);

            /* The compare must be made when we know that the id is not the same
             */
            assert(_other.id != id);

            /* The correct behaviour assures that different id in the same g-node will
             * never get the same elderships_seed. We should (somehow) assure that a
             * fingerprint maliciously crafted will be spotted and dropped.
             */
            assert(_other.elderships_seed.size == elderships_seed.size);
            for (int i = 0; i < elderships_seed.size; i++)
            {
                if (_other.elderships_seed[i] < elderships_seed[i]) return false; // other is elder
                if (_other.elderships_seed[i] > elderships_seed[i]) return true; // this is elder
            }
            assert_not_reached();
        }

        public int i_qspn_get_level()
        {
            return level;
        }

        public IQspnFingerprint i_qspn_construct(Gee.List<IQspnFingerprint> fingerprints, bool is_null_eldership)
        {
            // given that:
            //  levels = level + elderships.size
            // do not construct for level = levels+1
            assert(elderships.size > 0);

            // handle is_null_eldership
            if (is_null_eldership) elderships[0] = -1;

            Fingerprint ret = new Fingerprint.empty();
            ret.level = level + 1;
            ret.elderships = new ArrayList<int>();
            for (int i = 1; i < elderships.size; i++)
                ret.elderships.add(elderships[i]);
            // start comparing
            Fingerprint eldest_f = this;
            foreach (IQspnFingerprint f in fingerprints)
            {
                assert(f is Fingerprint);
                Fingerprint _f = (Fingerprint)f;
                if (_f.elder(eldest_f)) eldest_f = _f;
            }
            ret.elderships_seed = new ArrayList<int>();
            ret.elderships_seed.add(eldest_f.elderships[0]);
            ret.elderships_seed.add_all(eldest_f.elderships_seed);
            ret.id = eldest_f.id;
            return ret;
        }
    }

    public class Cost : Object, IQspnCost
    {
        public int64 usec_rtt {get; set;}

        public Cost(int64 usec_rtt)
        {
            this.usec_rtt = usec_rtt;
        }

        public int i_qspn_compare_to(IQspnCost other)
        {
            if (other.i_qspn_is_dead()) return -1;
            if (other.i_qspn_is_null()) return 1;
            assert(other is Cost);
            Cost o = (Cost)other;
            if (usec_rtt > o.usec_rtt) return 1;
            if (usec_rtt < o.usec_rtt) return -1;
            return 0;
        }

        public IQspnCost i_qspn_add_segment(IQspnCost other)
        {
            if (other.i_qspn_is_dead()) return other;
            if (other.i_qspn_is_null()) return this;
            assert(other is Cost);
            Cost o = (Cost)other;
            return new Cost(usec_rtt + o.usec_rtt);
        }

        public bool i_qspn_important_variation(IQspnCost new_cost)
        {
            if (new_cost.i_qspn_is_dead()) return true;
            if (new_cost.i_qspn_is_null()) return true;
            assert(new_cost is Cost);
            Cost o = (Cost)new_cost;
            int64 upper_threshold = (int64)(o.usec_rtt * 0.3);
            if (o.usec_rtt > usec_rtt + upper_threshold) return true;
            int64 lower_threshold = (int64)(usec_rtt * 0.3);
            if (o.usec_rtt < usec_rtt - lower_threshold) return true;
            return false;
        }

        public virtual bool i_qspn_is_dead()
        {
            return false;
        }

        public virtual bool i_qspn_is_null()
        {
            return false;
        }
    }

    public class WholeNodeSourceID : Object, ISourceID
    {
        public WholeNodeSourceID(NeighborhoodNodeID id)
        {
            this.id = id;
        }
        public NeighborhoodNodeID id {get; set;}
    }

    public class WholeNodeUnicastID : Object, IUnicastID
    {
        public WholeNodeUnicastID(NeighborhoodNodeID neighbour_id)
        {
            this.neighbour_id = neighbour_id;
        }
        public NeighborhoodNodeID neighbour_id {get; set;}
    }

    public class EveryWholeNodeBroadcastID : Object, IBroadcastID
    {
    }

    public class IdentityAwareSourceID : Object, ISourceID
    {
        public IdentityAwareSourceID(NodeID id)
        {
            this.id = id;
        }
        public NodeID id {get; set;}
    }

    public class IdentityAwareUnicastID : Object, IUnicastID
    {
        public IdentityAwareUnicastID(NodeID id)
        {
            this.id = id;
        }
        public NodeID id {get; set;}
    }

    public class IdentityAwareBroadcastID : Object, Json.Serializable, IBroadcastID
    {
        public IdentityAwareBroadcastID(Gee.List<NodeID> id_set)
        {
            this.id_set = new ArrayList<NodeID>((a, b) => a.equals(b));
            this.id_set.add_all(id_set);
        }
        public Gee.List<NodeID> id_set {get; set;}

        public bool deserialize_property
        (string property_name,
         out GLib.Value @value,
         GLib.ParamSpec pspec,
         Json.Node property_node)
        {
            @value = 0;
            switch (property_name) {
            case "id_set":
            case "id-set":
                try {
                    @value = deserialize_list_node_id(property_node);
                } catch (HelperDeserializeError e) {
                    return false;
                }
                break;
            default:
                return false;
            }
            return true;
        }

        public unowned GLib.ParamSpec? find_property
        (string name)
        {
            return get_class().find_property(name);
        }

        public Json.Node serialize_property
        (string property_name,
         GLib.Value @value,
         GLib.ParamSpec pspec)
        {
            switch (property_name) {
            case "id_set":
            case "id-set":
                return serialize_list_node_id((Gee.List<NodeID>)@value);
            default:
                error(@"wrong param $(property_name)");
            }
        }
    }

    public class MainIdentitySourceID : Object, ISourceID
    {
    }

    public class MainIdentityUnicastID : Object, IUnicastID
    {
    }

    internal errordomain HelperDeserializeError {
        GENERIC
    }

    internal int deserialize_int(Json.Node property_node)
    throws HelperDeserializeError
    {
        Json.Reader r = new Json.Reader(property_node.copy());
        if (r.get_null_value())
            throw new HelperDeserializeError.GENERIC("element is not nullable");
        if (!r.is_value())
            throw new HelperDeserializeError.GENERIC("element must be a int");
        if (r.get_value().get_value_type() != typeof(int64))
            throw new HelperDeserializeError.GENERIC("element must be a int");
        int64 val = r.get_int_value();
        if (val > int.MAX || val < int.MIN)
            throw new HelperDeserializeError.GENERIC("element overflows size of int");
        return (int)val;
    }

    internal Json.Node serialize_int(int i)
    {
        Json.Node ret = new Json.Node(Json.NodeType.VALUE);
        ret.set_int(i);
        return ret;
    }

    internal int64 deserialize_int64(Json.Node property_node)
    throws HelperDeserializeError
    {
        Json.Reader r = new Json.Reader(property_node.copy());
        if (r.get_null_value())
            throw new HelperDeserializeError.GENERIC("element is not nullable");
        if (!r.is_value())
            throw new HelperDeserializeError.GENERIC("element must be a int");
        if (r.get_value().get_value_type() != typeof(int64))
            throw new HelperDeserializeError.GENERIC("element must be a int");
        return r.get_int_value();
    }

    internal Json.Node serialize_int64(int64 i)
    {
        Json.Node ret = new Json.Node(Json.NodeType.VALUE);
        ret.set_int(i);
        return ret;
    }

    internal Gee.List<int> deserialize_list_int(Json.Node property_node)
    throws HelperDeserializeError
    {
        ArrayList<int> ret = new ArrayList<int>();
        Json.Reader r = new Json.Reader(property_node.copy());
        if (r.get_null_value())
            throw new HelperDeserializeError.GENERIC("element is not nullable");
        if (!r.is_array())
            throw new HelperDeserializeError.GENERIC("element must be an array");
        int l = r.count_elements();
        for (int j = 0; j < l; j++)
        {
            r.read_element(j);
            if (r.get_null_value())
                throw new HelperDeserializeError.GENERIC("element is not nullable");
            if (!r.is_value())
                throw new HelperDeserializeError.GENERIC("element must be a int");
            if (r.get_value().get_value_type() != typeof(int64))
                throw new HelperDeserializeError.GENERIC("element must be a int");
            int64 val = r.get_int_value();
            if (val > int.MAX || val < int.MIN)
                throw new HelperDeserializeError.GENERIC("element overflows size of int");
            ret.add((int)val);
            r.end_element();
        }
        return ret;
    }

    internal Json.Node serialize_list_int(Gee.List<int> lst)
    {
        Json.Builder b = new Json.Builder();
        b.begin_array();
        foreach (int i in lst)
        {
            b.add_int_value(i);
        }
        b.end_array();
        return b.get_root();
    }

    internal Object? deserialize_object(Type expected_type, bool nullable, Json.Node property_node)
    throws HelperDeserializeError
    {
        Json.Reader r = new Json.Reader(property_node.copy());
        if (r.get_null_value())
        {
            if (!nullable)
                throw new HelperDeserializeError.GENERIC("element is not nullable");
            return null;
        }
        if (!r.is_object())
            throw new HelperDeserializeError.GENERIC("element must be an object");
        string typename;
        if (!r.read_member("typename"))
            throw new HelperDeserializeError.GENERIC("element must have typename");
        if (!r.is_value())
            throw new HelperDeserializeError.GENERIC("typename must be a string");
        if (r.get_value().get_value_type() != typeof(string))
            throw new HelperDeserializeError.GENERIC("typename must be a string");
        typename = r.get_string_value();
        r.end_member();
        Type type = Type.from_name(typename);
        if (type == 0)
            throw new HelperDeserializeError.GENERIC(@"typename '$(typename)' unknown class");
        if (!type.is_a(expected_type))
            throw new HelperDeserializeError.GENERIC(@"typename '$(typename)' is not a '$(expected_type.name())'");
        if (!r.read_member("value"))
            throw new HelperDeserializeError.GENERIC("element must have value");
        r.end_member();
        unowned Json.Node p_value = property_node.get_object().get_member("value");
        Json.Node cp_value = p_value.copy();
        return Json.gobject_deserialize(type, cp_value);
    }

    internal Json.Node serialize_object(Object obj)
    {
        Json.Builder b = new Json.Builder();
        b.begin_object();
        b.set_member_name("typename");
        b.add_string_value(obj.get_type().name());
        b.set_member_name("value");
        b.add_value(Json.gobject_serialize(obj));
        b.end_object();
        return b.get_root();
    }

    internal class ListDeserializer<T> : Object
    {
        internal Gee.List<T> deserialize_list_object(Json.Node property_node)
        throws HelperDeserializeError
        {
            ArrayList<T> ret = new ArrayList<T>();
            Json.Reader r = new Json.Reader(property_node.copy());
            if (r.get_null_value())
                throw new HelperDeserializeError.GENERIC("element is not nullable");
            if (!r.is_array())
                throw new HelperDeserializeError.GENERIC("element must be an array");
            int l = r.count_elements();
            for (uint j = 0; j < l; j++)
            {
                unowned Json.Node p_value = property_node.get_array().get_element(j);
                Json.Node cp_value = p_value.copy();
                ret.add(deserialize_object(typeof(T), false, cp_value));
            }
            return ret;
        }
    }

    internal Json.Node serialize_list_object(Gee.List<Object> lst)
    {
        Json.Builder b = new Json.Builder();
        b.begin_array();
        foreach (Object obj in lst)
        {
            b.add_value(serialize_object(obj));
        }
        b.end_array();
        return b.get_root();
    }

    internal Gee.List<NodeID> deserialize_list_node_id(Json.Node property_node)
    throws HelperDeserializeError
    {
        ListDeserializer<NodeID> c = new ListDeserializer<NodeID>();
        var first_ret = c.deserialize_list_object(property_node);
        // N.B. list of NeighborhoodNodeID must be searchable for the Neighborhood module to work.
        var ret = new ArrayList<NodeID>((a, b) => a.equals(b));
        ret.add_all(first_ret);
        return ret;
    }

    internal Json.Node serialize_list_node_id(Gee.List<NodeID> lst)
    {
        return serialize_list_object(lst);
    }
}
