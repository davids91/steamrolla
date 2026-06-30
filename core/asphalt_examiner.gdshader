shader_type canvas_item;

uniform sampler2D terrain;
uniform sampler2D asphalt;
uniform sampler2D asphalt_filter;
uniform sampler2D target_height;

void fragment() {
	float terrain_normalized_height = texture(terrain, UV).r * 0.5; // divide by 2(overall height)
	float asphalt_normalized_height = texture(asphalt, UV).r * 0.5 * texture(asphalt_filter, UV).r;
	float current_surface_height = terrain_normalized_height + asphalt_normalized_height;
	COLOR = vec4( // Render the difference of the surface height from the ideal surface height
		vec3(0.5 + (current_surface_height - texture(target_height, UV).r) * 0.5),
		1.
	);
}
