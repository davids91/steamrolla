shader_type spatial;

uniform sampler2D road_colormap;
uniform sampler2D asphalt_texture;
uniform sampler2D asphalt_normals;
uniform sampler2D asphalt_quantity;
uniform sampler2D asphalt_filter;
uniform sampler2D terrain_normalmap;
uniform sampler2D terrain_heightmap;
uniform sampler2D level_tool_reference;
uniform sampler2D level_tool_result_color;
uniform vec4 level_tool_scan_color: source_color;
uniform float asphalt_tile_size_ratio = 1.;
uniform float asphalt_highlight = 1.6;
uniform float asphalt_minimum_quantity_for_display = 0.005;
uniform float terrain_normal_strength = 0.1;
uniform float height_unit = 0.1;
uniform float normal_calculation_range = 0.05;
uniform float hightlight_strength = 0.0;
uniform vec3 highlight_color: source_color;
uniform float level_tool_scanning_strength = 0.0;
uniform float level_tool_height = 0.2;
uniform float level_tool_range: hint_range(0.0, 1.0) = 0.005;
uniform float level_tool_tolerance: hint_range(0.0, 1.0) = 0.05;
uniform float crazify_amount = 0.0;
uniform float crazify_scale = 0.0;
uniform float crazify_speed = 0.0;

varying float asphalt_bump_height;
varying float road_level;
void vertex() {
	asphalt_bump_height = (
		abs(texture(asphalt_quantity, UV).r)
		* height_unit * texture(asphalt_filter, UV).r
	);
	VERTEX.y += asphalt_bump_height;
	VERTEX.y += abs(texture(terrain_heightmap, UV).r) * height_unit;
	VERTEX.y += (
		(
			sin(UV.x / crazify_scale + TIME * crazify_speed)
			+ cos(UV.y / crazify_scale + TIME * crazify_speed)
		) * crazify_amount * texture(asphalt_filter, UV).r
	);
	road_level = VERTEX.y;
}

vec3 normal_from_heightmap(sampler2D heightmap, vec2 uv, float gradient_delta){
	float terrain_height_left = abs(texture(heightmap, uv + vec2(-gradient_delta, 0.)).r);
	float terrain_height_right = abs(texture(heightmap, uv + vec2(gradient_delta, 0.)).r);
	float terrain_height_far = abs(texture(heightmap, uv + vec2(0., gradient_delta)).r);
	float terrain_height_near = abs(texture(heightmap, uv + vec2(0., -gradient_delta)).r);
	return normalize(vec3((terrain_height_right - terrain_height_left), (terrain_height_near - terrain_height_far), -1));
}

void fragment() {
	vec3 normal_vec = normal_from_heightmap(terrain_heightmap, UV, normal_calculation_range);
	float asphalt_enabled = texture(asphalt_filter, UV).r;

	// Update normalmap from terrain normal map
	normal_vec = mix(
		normal_vec, texture(terrain_normalmap, UV).xyz,
		terrain_normal_strength * min((1.51 - asphalt_enabled), 1.) * (1. -  asphalt_enabled)
	);

	// Update normal map based on asphalt bumpyness
	normal_vec += (
		normal_from_heightmap(asphalt_quantity, UV, normal_calculation_range)
		* asphalt_enabled * asphalt_highlight
	);

	// Decide terrain color
	ALBEDO = texture(road_colormap, UV).rgb;
	if (asphalt_minimum_quantity_for_display < asphalt_bump_height){
		normal_vec += texture(asphalt_texture, UV * asphalt_tile_size_ratio).xyz * asphalt_highlight;
		ALBEDO = texture(asphalt_texture, UV * asphalt_tile_size_ratio).rgb;
	}
	NORMAL_MAP = normal_vec;

	// Mix in highlight color
	ALBEDO = mix(
		ALBEDO, highlight_color,
		hightlight_strength * asphalt_enabled
	);

	// update output for level tool color
	float level_tool_height_diff = clamp(abs(road_level - level_tool_height), 0., 1.);
	float target_level_height_diff_ratio = clamp(
		abs( // reference contains both the terrain and asphalt quantity heights
			texture(level_tool_reference, UV).r * 2.
			- (texture(asphalt_quantity, UV).r * asphalt_enabled + texture(terrain_heightmap, UV).r)
		) * 0.5 / level_tool_tolerance,
		0.01, 0.99
	);
	ALBEDO = mix(
		ALBEDO,
		mix(
			texture(level_tool_result_color, vec2(target_level_height_diff_ratio, 0.0)).rgb,
			level_tool_scan_color.rgb, level_tool_scanning_strength
		),
		step(level_tool_height_diff, level_tool_range)
	);
}
