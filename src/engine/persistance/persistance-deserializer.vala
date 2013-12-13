/* Copyright 2013 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

/**
 * A Deserializer turns specially-formatted bytes streams (generated by {@link Serializer}) into
 * Objects which implement {@link Serializable}.
 *
 * The {@link DataFlavor} given to the Deserializer must match the DataFlavor used to generate
 * the serialized stream.  There is no metadata in the stream to tell the Deserializer which to
 * use.
 *
 * See notes at Serializer for more information on how the serialized stream must be maintained by
 * the caller in order for Deserializer to operate properly.
 */

public class Geary.Persistance.Deserializer : BaseObject {
    private DataFlavor flavor;
    private Activator activator;
    
    public Deserializer(DataFlavor flavor, Activator activator) {
        this.flavor = flavor;
        this.activator = activator;
    }
    
    public Serializable from_buffer(Geary.Memory.Buffer buffer) throws Error {
        DataFlavorDeserializer deserializer = flavor.create_deserializer(buffer);
        
        return deserialize_properties(deserializer);
    }
    
    public Serializable deserialize_properties(DataFlavorDeserializer deserializer)
        throws Error {
        Serializable? sobj = activator.activate(deserializer.get_classname(),
            deserializer.get_serialized_version());
        // TODO: Need Errors
        assert(sobj != null);
        
        foreach (ParamSpec param_spec in sobj.get_class().list_properties()) {
            if (!is_serializable(param_spec, false))
                continue;
            
            if (!deserializer.has_value(param_spec.name)) {
                debug("WARNING: Serialized stream does not contain parameter for %s",
                    param_spec.name);
                
                continue;
            }
            
            // Give the object the chance to manually deserialize the property
            if (sobj.deserialize_property(param_spec.name, deserializer))
                continue;
            
            Value value;
            switch (deserializer.get_value_type(param_spec.name)) {
                case SerializedType.BOOL:
                    value = Value(typeof(bool));
                    value.set_boolean(deserializer.get_bool(param_spec.name));
                break;
                
                case SerializedType.INT:
                    value = Value(typeof(int));
                    value.set_int(deserializer.get_int(param_spec.name));
                break;
                
                case SerializedType.INT64:
                    value = Value(typeof(int64));
                    value.set_int64(deserializer.get_int64(param_spec.name));
                break;
                
                case SerializedType.INT_ARRAY:
                case SerializedType.UTF8_ARRAY:
                    debug("WARNING: int[] and string[] properties must be manually deserialized");
                    
                    continue;
                
                default:
                    assert_not_reached();
            }
            
            sobj.set_property(param_spec.name, value);
        }
        
        return sobj;
    }
}

