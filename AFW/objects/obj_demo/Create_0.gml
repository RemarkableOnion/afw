#region Settings

	// Define
	AFW.storage_define("settings", "settings.json");
	AFW.storage_set_property("settings", "key_left", vk_left);
	AFW.storage_set_property("settings", "key_right", vk_right);

	// Load (or crate if non-existent)
	if (!AFW.storage_load("settings"))
	{
		AFW.storage_save("settings");
	}

#endregion
#region Timesteps

	// Define timesteps
	AFW.timestep_create("slow_timestep", 1);
	AFW.timestep_create("fast_timestep", 10);

#endregion
#region Inputs

	// Define
	AFW.input_define("left");
	AFW.input_define("right");

	// Bind to key directly
	// AFW.input_bind_to_key("left", vk_left);
	// AFW.input_bind_to_key("right", vk_right);

	// Bind to storage (for auto updates when storage changes)
	AFW.input_bind_to_storage("left", "settings", "key_left");
	AFW.input_bind_to_storage("right", "settings", "key_right");

	// Track inputs separately for each timestep
	// AFW.input_add_poll_on_timestep("fast_timestep");

#endregion
#region World Updates

	// Define circles
	circles[0] = { x : 160, y : 180, r : 0, colour : c_white, outline : false, timestep : "slow_timestep" }
	circles[1] = { x : 480, y : 180, r : 0, colour : c_white, outline : false, timestep : "fast_timestep" }

	// Randomizing graphics
	var randomize_size_and_colour = function()
	{
		r = random_range(8, 64);
		colour = make_colour_rgb(
			irandom(128), irandom(128), irandom(128)
		);
	}

	// Attach circles to timesteps
	var circle_count = array_length(circles);
	for (var i=0; i<circle_count; i++)
	{
		var circle = circles[i];
		var message = ("afw timestep " + circle.timestep);
		AFW.message_attach_callback(message,  randomize_size_and_colour, circles[i], 0);
	}

#endregion