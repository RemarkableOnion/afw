function AFW() constructor 
{
	// Messages
	// Lightweight publish-subscribe system for sending named messages to scoped callback listeners with optional priorities.
	// Dependencies:				None
	message_broadcast 				= function(message, args = undefined)				{ }
	message_attach_callback 		= function(message, script, scope, priority = 0)	{ }
	message_detach_callback 		= function(handle)									{ }
	
	// Timesteps
	// Defines custom, fixed-rate update loops that dispatch timed messages independently of GameMaker’s built-in step event.
	// Dependencies: 				Messages
	timestep_create					= function(name, hertz)								{ }
	timestep_exists					= function(name)									{ }
	timestep_destroy				= function(name)									{ }
	timestep_get_timescale			= function(name)									{ }
	timestep_set_timescale			= function(name, timescale)							{ }
	timestep_get_rate				= function(name)									{ }
	
	// Storage
	// Handles simple structured data saving/loading to files, with optional message broadcasts when properties change or reload.
	// Dependencies: 				Messages*
	storage_define					= function(name, filepath)							{ }
	storage_get_property			= function(name, property)							{ }
	storage_set_property			= function(name, property, value)					{ }
	storage_load					= function(name)									{ }
	storage_save					= function(name)									{ }
	
	// Inputs
	// Maps player actions to keyboard keys or storage-bound keys and tracks their state globally or across timesteps.
	// Dependency: 					Timesteps*, Storage*
	input_define					= function(action)									{ }
	input_bind_to_key				= function(action, key)								{ }
	input_bind_to_storage			= function(action, name, property)					{ }
	input_add_poll_on_timestep		= function(timestep_name)							{ }
	input_remove_poll_on_timestep	= function(timestep_name)							{ }
	input_is_held					= function(action, timestep_name = undefined)		{ }
	input_is_pressed				= function(action, timestep_name = undefined)		{ }
	input_is_released				= function(action, timestep_name = undefined)		{ }
	
	// Messages
	static messages = { }
	with (messages)
	{
		// API implementation
		AFW.message_broadcast = function(message, args=undefined)
		{
			// Get list of handles
			var handle_list = AFW.messages.message_handle_map[? message];
			if (is_undefined(handle_list))
			{
				return 0;	
			}
			
			// Trigger callbacks associated with handles in list
			var num_recipients = 0;
			var handle_count = ds_list_size(handle_list);
			for (var i=0; i<handle_count; i++)
			{
				var handle = handle_list[| i];
				var callback = AFW.messages.handle_callback_map[? handle];
				
				// Respect scope
				if (is_undefined(callback.scope))
				{
					script_execute(callback.script, args);
				}
				else
				{
					with (callback.scope)
					{
						script_execute(callback.script, args);	
					}
				} 
			}
			
			// Success
			return num_recipients;
		}	
		AFW.message_attach_callback = function(message, script, scope, priority = 0)
		{
			static last_callback_handle = 0;
        
	        // Generate handle
	        var new_handle;
	        if (ds_queue_empty(AFW.messages.recycled_handles))
	        {
	            new_handle = (last_callback_handle + 1);
	            last_callback_handle = new_handle;  
	        }
	        else
	        { 
	            new_handle = ds_queue_dequeue(AFW.messages.recycled_handles);  
	        }
			
	        // Store callback by handle
	        AFW.messages.handle_callback_map[? new_handle] = {
	            handle : new_handle,
	            message : message,
	            script : script,
	            scope : scope,
	            priority : priority,
	        }
	        
	        // Get a list of handles; create if needed
	        var handle_list = AFW.messages.message_handle_map[? message];
	        if (is_undefined(handle_list))
	        {
	            handle_list = ds_list_create();
	            AFW.messages.message_handle_map[? message] = handle_list;    
	        }
	        
	        // Find insertion point
	        var insert_at;
	        var handle_count = ds_list_size(handle_list);
	        for (insert_at=0; insert_at<handle_count; insert_at++)
	        { 
	            var handle = handle_list[| insert_at];
	            var callback = AFW.messages.handle_callback_map[? handle];
	            if (priority >= callback.priority)
	            {
	                break;
	            }       
	        }
	        
	        // Insert
	        ds_list_insert(handle_list, insert_at, new_handle);
	        return new_handle;
			
		}
		AFW.message_detach_callback = function(handle)
		{
			// Get callback info
	        var callback = AFW.messages.handle_callback_map[? handle];
	        if (is_undefined(callback))
	        {
	            var error_string = "AfwMessages: Callback handle " + string(handle) + " is invalid or missing.";
	            show_error(error_string, true);
	        }
	        
	        // Get handle list using callback info
	        var handle_list = AFW.messages.message_handle_map[? callback.message];
	        if (is_undefined(handle_list))
	        {
	            var error_string = "AfwMessages: Could not remove callback. No handle list found for message '" + string(callback.message) + "'.";
	            show_error(error_string, true); 
	        }
	        
	        // Find and remove from message map
	        var handle_count = ds_list_size(handle_list);
	        for (var i=0; i<handle_count; i++)
	        {
	            if (handle == handle_list[| i])
	            {
	                ds_list_delete(handle_list, i);
	                if (ds_list_empty(handle_list))
	                {
	                    ds_list_destroy(handle_list);
	                    ds_map_delete(AFW.messages.message_handle_map, callback.message);
	                }
	                
	                break;
	            }
	        }
	        
	        // Remove callback
	        ds_queue_enqueue(AFW.messages.recycled_handles, handle);
	        ds_map_delete(AFW.messages.handle_callback_map, handle);
		}
		
		// Members
		recycled_handles = ds_queue_create();
		message_handle_map = ds_map_create();
		handle_callback_map = ds_map_create();
	}
	
	// Timesteps
	static timesteps = { }
	with (timesteps)
	{
		// API implementation
		AFW.timestep_create = function(name, hertz)
		{
			// Ensure it doesn't already exist
	        var config_index = AFW.timesteps.get_config_index(name);
	        if (config_index != -1)
	        {
	            var error_string = "AfwTimesteps: Could not create timestep with name '" + name + "'; it already exists.";
	            show_error(error_string, true);     
	        }
	         
	        // Define config
	        var new_config = { 
	            name : name,
	            hertz : hertz,
	            timescale : 1,
	            unapplied_delta : 0, 
	        }
	        
	        // Add to config list
	        ds_list_add(
	            AFW.timesteps.configs, 
	            new_config 
	        );
		}
		AFW.timestep_exists = function(name)
		{
			return (AFW.timesteps.get_config_index(name) != -1);
		}
		AFW.timestep_destroy = function(name)
		{
			// Find index
	        var remove_at_index = AFW.timesteps.get_config_index(name);
	        if (remove_at_index == -1)
	        {
	            var error_string = "AfwTimesteps: Could not delete timestep with name '" + name + "'; it doesn't exist.";
	            show_error(error_string, true); 
	        }
	        
	        // Remove the config
	        ds_list_delete(AFW.timesteps.configs, remove_at_index);
		}	
		AFW.timestep_get_timescale = function(name)
		{
			// Find index
	        var config_index = AFW.timesteps.get_config_index(name);
	        if (config_index == -1)
	        {
	            var error_string = "AfwTimesteps: Could not get timescale for timestep with name '" + name + "'; it doesn't exist.";
	            show_error(error_string, true);    
	        }
	        
	        // Get timescale
	        return AFW.timesteps.configs[| config_index].timescale;
		}
		AFW.timestep_set_timescale = function(name, timescale)
		{
			// Find index
	        var config_index = AFW.timesteps.get_config_index(name);
	        if (config_index == -1)
	        {
	            var error_string = "AfwTimesteps: Could not set timescale for timestep with name '" + name + "'; it doesn't exist.";
	            show_error(error_string, true);    
	        }
	        
	        // Get timescale
	        AFW.timesteps.configs[| config_index].timescale = timescale;
		}
		AFW.timestep_get_rate = function(name)
		{
			// Find index
	        var config_index = AFW.timesteps.get_config_index(name);
	        if (config_index == -1)
	        {
	            var error_string = "AfwTimesteps: Could not set timescale for timestep with name '" + name + "'; it doesn't exist.";
	            show_error(error_string, true);    
	        }	
			
			// Calculate and return
			var config = AFW.timesteps.configs[| config_index];
			return (config.timescale * config.hertz);
		}
		
		// Helper
		get_config_index = function(name)
	    {
	        // Get config from list
	        var config;
	        var config_index = -1;
	        var config_count = ds_list_size(AFW.timesteps.configs);
	        for (var i=0; i<config_count; i++)
	        {
	            config = AFW.timesteps.configs[| i];
	            if (name == config.name) 
	            {
	                config_index = i;
	                break;
	            }
	        }
	        
	        return config_index;
	    }
		on_step = function()
	    {
	        var config;
	        var config_count = ds_list_size(AFW.timesteps.configs); 
	        for (var i=0; i<config_count; i++)
	        {
	            // Accrue time
	            config = AFW.timesteps.configs[| i];     
	            config.unapplied_delta += (delta_time * config.timescale);
	            
	            // Broadcast ticks
	            var interval = (1000000 / config.hertz);
	            while (config.unapplied_delta >= interval)
	            {
	                AFW.message_broadcast("afw timestep " + config.name, config.name);
					config.unapplied_delta -= interval;    
	            }
	        }     
	    }
		
		// Members
	    configs = ds_list_create();
	    
	    // Start update loop
	    call_later(1, time_source_units_frames, on_step, true);
	}
	
	// Storage
	static storage = { }
	with (storage)
	{
		// API implementation	
		AFW.storage_define = function(name, filepath)
		{
			// Ensure not duplicate
	        if (ds_map_exists(AFW.storage.name_config_map, name))
	        {
	            var error_string = ("AfwStorage: Could not define storage '" + name + "'. It already exists.");
	            show_error(error_string, true);  
	        }
	        
	        // Define
	        AFW.storage.name_config_map[? name] = {
	            filepath : filepath,
	            properties : { },
	        }
		}
		AFW.storage_get_property = function(name, property)
		{
			var config =AFW.storage.get_config(name);
        	return struct_get(config.properties, property);
		}
		AFW.storage_set_property = function(name, property, value)
		{
			// Update property
	        var config =AFW.storage.get_config(name);
	        struct_set(config.properties, property, value);    
	        
	        // Broadcast message indicating changes
	  		AFW.message_broadcast("afw storage set", [name, property, value]);   
		}
		AFW.storage_load = function(name)
		{
			// Get config
	        var config =AFW.storage.get_config(name);
	        if (!file_exists(config.filepath))
	        {
	            return false;
	        }
	        
	        // Read json from file
	        var json = "";
	        var input_file = file_text_open_read(config.filepath);
	        while (!file_text_eof(input_file))
	        {
	            json += file_text_readln(input_file);
	        }
	        
	        // Get properties from json
	        var properties = json_parse(json);
	        if (!is_struct(properties))
	        {
	            var error_string = ("AfwStorage: Could not load storage '" + name + "'. Invalid file.");
	            show_error(error_string, true);  
	        }
	        
	        // Update properties
	        config.properties = properties;
	        
	        // Broadcast message indicating changes
	  	AFW.message_broadcast("afw storage load " + name);  
	        
	        // Succesful load...
	        return true;	
		}
		AFW.storage_save = function(name)
		{
			var config = AFW.storage.get_config(name);
	        var json = json_stringify(config.properties, true);
	        var output_file = file_text_open_write(config.filepath);
	        file_text_write_string(output_file, json);
	        file_text_close(output_file);
		}
		
		// Helper
	 	get_config = function(name)
	    {
	        var config = AFW.storage.name_config_map[? name];
	        if (is_undefined(config))
	        {
	            var error_string = ("AfwStorage: Could set property from storage '" + name + "'. Storage doesn't exist.");
	            show_error(error_string, true);      
	        }
	        
	        return config; 
	    }
		
		// Members
		name_config_map = ds_map_create();
	}
	
	// Inputs
	static inputs = { }
	with (inputs)
	{
		// API implementation
		AFW.input_define = function(action)
		{
			// Ensure not predefined
			if (ds_list_find_index(AFW.inputs.action_list, action) != -1)
			{
				var error_string = ("AfwInputs: Could not define action '" + action + "'. It already exists!");
	            show_error(error_string, true);
			}
			
			// Update list
			ds_list_add(
				AFW.inputs.action_list, {
					action : action,
					binding : undefined,
					binding_source : undefined,
					binding_property : undefined,
				}
			);
			
			// Add to any currently tracked timesteps
			var keys = ds_map_keys_to_array(AFW.inputs.state_map);
			var key_count = array_length(keys);
			for (var i=0; i<key_count; i++)
			{
				var state_struct = AFW.inputs.state_map[? keys[i]];
				struct_set(state_struct, action, 0);
			}
		}
		AFW.input_bind_to_key = function(action, key)
		{
			// Get action struct
			var action_struct = undefined;
			var action_count = ds_list_size(AFW.inputs.action_list);
			for (var i=0; i<action_count; i++)
			{
				var as = AFW.inputs.action_list[| i];
				if (as.action == action)
				{
					action_struct = as;
				}
			}
			
			// Remove existing binds if they exist
			var handle = AFW.inputs.storage_handles[? action];
			if (!is_undefined(handle))
			{
				AFW.message_detach_callback(handle);	
			}
			
			// Ensure defined
			if (is_undefined(action_struct))
			{
				var error_string = ("AfwInputs: Could not bind action to key. Action '" + action + "' wasn't defined.");
	            show_error(error_string, true);  
			}
			
			// Store keybind
			action_struct.binding = key;
		}
		AFW.input_bind_to_storage = function(action, name, property)
		{
			// Find the action struct
			var action_struct = undefined;
			var count = ds_list_size(AFW.inputs.action_list);
			for (var i = 0; i < count; i++)
			{
				var a = AFW.inputs.action_list[| i];
				if (a.action == action)
				{
					action_struct = a;
					break;
				}
			}
			
			// Ensure exists
			if (is_undefined(action_struct))
			{
				var error_string = ("AfwInputs: Could not bind action '" + action + "' to storage. It wasn't defined.");
				show_error(error_string, true);
			}
			
			// Store binding source
			action_struct.binding_source = name;
			action_struct.binding_property = property;
			action_struct.binding = AFW.storage_get_property(name, property);
			
			// Remove existing binds if they exist
			var handle = AFW.inputs.storage_handles[? action];
			if (!is_undefined(handle))
			{
				AFW.message_detach_callback(handle);	
			}
			
			// Listen for changes to storage property
			var handle = AFW.message_attach_callback("afw storage set", AFW.inputs.update_storage_binding, undefined, 0);
			AFW.inputs.storage_handles[? action] = handle;
		}
		AFW.input_add_poll_on_timestep = function(timestep_name)
		{
			// Ensure timestep exists
			if (!AFW.timestep_exists(timestep_name))
			{
				var error_string = ("AfwInputs: Could not bind input to timestep. Timestep doesn't exist!");
	            show_error(error_string, true);	
			}
			
			// Prevent double polling
			if (!is_undefined(AFW.inputs.state_map[? timestep_name]))
			{
				var error_string = ("AfwInputs: Could not add input polling to timestep. It is already bound!");
	            show_error(error_string, true);	
			}
			
			// Create state struct
			var state_struct = { }
			var action_count = ds_list_size(AFW.inputs.action_list);
			for (var i=0; i<action_count; i++)
			{
				struct_set(state_struct, AFW.inputs.action_list[| i].action, 0);	
			}
			
			// Add to state map
			AFW.inputs.state_map[? timestep_name] = state_struct;
			
			// Trigger on timestep
			var handle = AFW.message_attach_callback("afw timestep " + timestep_name, AFW.inputs.poll, undefined, 1);
			AFW.inputs.timestep_handles[? timestep_name] = handle;
		}
		AFW.input_remove_poll_on_timestep = function(timestep_name)
		{
			// Ensure timestep exists
			if (!AFW.timestep_exists(timestep_name))
			{
				var error_string = ("AfwInputs: Could not remove input polling from timestep. Timestep doesn't exist!");
	            show_error(error_string, true);	
			}
			
			// Can't unbind what isn't bound
			if (is_undefined(AFW.inputs.state_map[? timestep_name]))
			{
				var error_string = ("AfwInputs: Could not remove input polling to timestep. It was never bound!");
	            show_error(error_string, true);	
			}
			
			// Remove from map
			ds_map_delete(AFW.inputs.state_map, timestep_name);
			
			// Detach timestep
			var handle = AFW.inputs.timestep_handles[? timestep_name];
			AFW.message_detach_callback(handle);
		}
		AFW.input_is_held = function(action, timestep_name = undefined)
		{
			return ((AFW.inputs.get_action_state(action, timestep_name) & 1) != 0);
		}	
		AFW.input_is_pressed = function(action, timestep_name = undefined)
		{
			return ((AFW.inputs.get_action_state(action, timestep_name) & 2) != 0);	
		}
		AFW.input_is_released = function(action, timestep_name = undefined)
		{
			return ((AFW.inputs.get_action_state(action, timestep_name) & 4) != 0);	
		}
		
		// Helper
		poll = function(timestep_name = undefined)
		{
			// Default to global
			if (is_undefined(timestep_name))
			{
				timestep_name = "global";
			}
			
			// Get state struct
			var state_struct = AFW.inputs.state_map[? timestep_name];
			if (is_undefined(state_struct))
			{
				var error_string = ("AfwInputs: Could not poll on timestep '" + timestep_name + "'. It was never linked for polling!");
	            show_error(error_string, true);		
			}
			
			// Update states
			var action_count = ds_list_size(AFW.inputs.action_list);
			for (var i=0; i<action_count; i++)
			{
				// Get previous sate
				var action_struct = AFW.inputs.action_list[| i];
				
				// Previous state
				var previous_state = struct_get(state_struct, action_struct.action);
				var was_held = (previous_state & 1 != 0);
				
				// Determine new state
				var is_held = AFW.inputs.is_action_held(action_struct);
				var is_pressed = (is_held && !was_held);
				var is_released = (!is_held && was_held);
				
				// Store as bitfield
				struct_set(
					state_struct,
					action_struct.action,
					(is_held << 0) | (is_pressed << 1) | (is_released << 2)
				); 
			}
		}
		is_action_held = function(action_struct)
		{
			// If bound to storage
			var key;
			if (!is_undefined(action_struct.binding))
			{
				key = action_struct.binding;
			}
			else
			{
				return false;	
			}
		
			// Return status
			return keyboard_check(key);
		}
		get_action_state = function(action, timestep_name = undefined)
		{
			// Default to global if none specified
		    if (is_undefined(timestep_name))
		    {
		        timestep_name = "global";
		    }
		
		    // Look up state struct
		    var state_struct = AFW.inputs.state_map[? timestep_name];
		    if (is_undefined(state_struct))
		    {
		        var error_string = "AfwInputs: Tried to get action state for timestep '" + timestep_name + "', but it wasn't linked for polling.";
		        show_error(error_string, true);
		    }
		
		    // Get state for action
		    return struct_get(state_struct, action);
		}
		update_storage_binding = function(args)
		{
			var storage = args[0];
		    var property = args[1];
		    var value = args[2];
			
		    // Iterate all actions
		    var action_count = ds_list_size(AFW.inputs.action_list);
		    for (var i = 0; i < action_count; i++)
		    {
		        var action_struct = AFW.inputs.action_list[| i];
		
		        // Check if this action is bound to the changed storage property
		        if (action_struct.binding_source == storage && action_struct.binding_property == property )
		        {
		            action_struct.binding = value;
		        }
		    }
		}
		
		// Members
		action_list = ds_list_create();
		state_map = ds_map_create();
		timestep_handles = ds_map_create();
		storage_handles = ds_map_create();
		ds_map_add(state_map, "global", { } );
		
		// Start polling loop
		call_later(1, time_source_units_frames, poll, true);
	}
}

// Initialize
new AFW();