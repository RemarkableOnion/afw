// Demo circles
var circle_count = array_length(circles);
for (var i=0; i<circle_count; i++)
{
	with (circles[i])
	{
		draw_set_halign(fa_center);
		draw_circle_colour(x, y, r, colour, colour, outline);
		draw_text(
			x, 16, 
			timestep + "\n" + 
			"Hertz: " + string(AFW.timestep_get_rate(timestep)) + "\n" + 
			"Timescale: " + string(AFW.timestep_get_timescale(timestep))
		);
	}	
}

// Instructions
draw_set_halign(fa_left);
draw_text(16, 300, "'Left': " + string(AFW.storage_get_property("settings", "key_left")));
draw_text(16, 316, "'Right': " + string(AFW.storage_get_property("settings", "key_right")));
draw_text(16, 332, "Use Left/Right to adjust timescale");