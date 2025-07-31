// Update timescales
// ... we don't pass a timestep to the input functions
// ... this way it checks presses/released globally not local to that timestep
var ix = (AFW.input_is_pressed("right") - AFW.input_is_pressed("left"));
var circle_count = array_length(circles);
for (var i=0; i<circle_count; i++)
{
	var timestep = circles[i].timestep;
	var prev_timescale = AFW.timestep_get_timescale(timestep);
	AFW.timestep_set_timescale(
		timestep, 
		clamp(prev_timescale + ix, 0, 4)
	);
}