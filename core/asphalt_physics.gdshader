shader_type canvas_item;

uniform sampler2D terrain;
uniform sampler2D asphalt;
uniform sampler2D asphalt_filter;
uniform sampler2D asphalt_delta;
uniform sampler2D asphalt_meta; /// Also the output. Red channel: surface height; Green channel: surface temperature
uniform float cooldown_percentage = 0.5;

void fragment() {
	float terrain_normalized_height = texture(terrain, UV).r * 0.5; // divide by 2(overall height)
	float asphalt_normalized_height = texture(asphalt, UV).r * 0.5 * texture(asphalt_filter, UV).r;
	float current_surface_height = terrain_normalized_height + asphalt_normalized_height;
	float temp_from_updates = smoothstep(0.0, 0.05, abs(texture(asphalt_delta, UV).r - 0.5));
	float asphalt_temperature = texture(asphalt_meta, UV).g * cooldown_percentage + temp_from_updates;
	COLOR = vec4(
		current_surface_height,
		asphalt_temperature,
		0.,
		1.
	);
}
