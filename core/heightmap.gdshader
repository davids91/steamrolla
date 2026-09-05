shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;

uniform sampler2D road_colormap;
uniform sampler2D asphalt_texture;
uniform sampler2D asphalt_normals;
uniform sampler2D asphalt_state;
uniform sampler2D asphalt_attributes; /// r: presence, g: editability, b: fluidity
uniform sampler2D asphalt_physics_state;
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
uniform float level_edge_transition = 0.001;
uniform float asphalt_shiny: hint_range(0.0, 1.0) = 0.2;
uniform float asphalt_spread: hint_range(0.0, 500.0) = 10.;
uniform vec3 asphalt_hot_color: source_color = vec3(0.1,0.,0.);

const float VALUE_EPSILON = 0.001;

varying float road_level;
void vertex() {
	vec3 current_asphalt_attributes = texture(asphalt_attributes, UV).rgb;

	// Add asphalt and terrain heights to the height of the current vertex
	float vertex_height_addition = abs(texture(asphalt_state, UV).r) * height_unit * current_asphalt_attributes.r;
	vertex_height_addition += abs(texture(terrain_heightmap, UV).r) * height_unit;
	vertex_height_addition += ( // Crazify asphalt
		(sin(UV.x / crazify_scale + TIME * crazify_speed) + cos(UV.y / crazify_scale + TIME * crazify_speed))
		* crazify_amount * texture(asphalt_attributes, UV).r
	);

	// Display Crack where there is no asphalt
	if(VALUE_EPSILON > texture(asphalt_state, UV).r && VALUE_EPSILON < current_asphalt_attributes.r){
		vertex_height_addition -= abs(texture(terrain_heightmap, UV).g) * height_unit;
	}

	// Add water effect Sink terrain where water is present
	vertex_height_addition += texture(asphalt_physics_state, UV).b * current_asphalt_attributes.b * 0.7;
	vertex_height_addition *= 1. - current_asphalt_attributes.b;

	VERTEX.y += vertex_height_addition;

	// Do not set mesh height from samples from the other side of the level ( texture sampling wrap-around )
	float distance_from_level_edge = min(min(1. - UV.x, UV.x), min(1. - UV.y, UV.y));
	VERTEX.y *= smoothstep(0., level_edge_transition, distance_from_level_edge);

	// Send resulting height forward to the fragment shader
	road_level = VERTEX.y;
}

vec3 red_channel_normal_from_heightmap(sampler2D heightmap, vec2 uv, float gradient_delta){
	float terrain_height_left = abs(texture(heightmap, uv + vec2(-gradient_delta, 0.)).r);
	float terrain_height_right = abs(texture(heightmap, uv + vec2(gradient_delta, 0.)).r);
	float terrain_height_far = abs(texture(heightmap, uv + vec2(0., gradient_delta)).r);
	float terrain_height_near = abs(texture(heightmap, uv + vec2(0., -gradient_delta)).r);
	return normalize(vec3((terrain_height_right - terrain_height_left), (terrain_height_near - terrain_height_far), -1));
}

void fragment() {
	vec3 normal_vec = red_channel_normal_from_heightmap(terrain_heightmap, UV, normal_calculation_range);
	float asphalt_presence = texture(asphalt_attributes, UV).r;
	float asphalt_in_pixel = texture(asphalt_state, UV).r * asphalt_presence;

	// Update normalmap from terrain normal map
	normal_vec = mix(
		normal_vec, texture(terrain_normalmap, UV).xyz,
		terrain_normal_strength * min((1.51 - asphalt_presence), 1.) * (1. -  asphalt_presence)
	);

	// Update normal map based on asphalt bumpyness
	normal_vec += (
		red_channel_normal_from_heightmap(asphalt_state, UV, normal_calculation_range)
		* asphalt_presence * asphalt_highlight
	);

	// Decide terrain color
	ALBEDO = texture(road_colormap, UV).rgb;
	if (asphalt_minimum_quantity_for_display < (asphalt_in_pixel * height_unit)){
		normal_vec += texture(asphalt_texture, UV * asphalt_tile_size_ratio).xyz * asphalt_highlight;
		ALBEDO = texture(asphalt_texture, UV * asphalt_tile_size_ratio).rgb;
	}
	NORMAL_MAP = normal_vec;

	// Mix in highlight color
	ALBEDO = mix(ALBEDO, highlight_color, hightlight_strength * asphalt_presence);

	// update output for level tool color
	float level_tool_height_diff = clamp(abs(road_level - level_tool_height), 0., 1.);
	float target_level_height_diff_ratio = clamp(
		abs( // reference contains both the terrain and asphalt quantity heights
			(texture(level_tool_reference, UV).r * 2.)
			- (asphalt_in_pixel + texture(terrain_heightmap, UV).r)
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

	// Make Asphalt glow red when hot
	ALBEDO += asphalt_hot_color * texture(asphalt_physics_state, UV).g;
	ALPHA = texture(road_colormap, UV).a;
}

// Recreation of the default godot light shader from
// --> https://github.com/RustyRoboticsBV/GodotStandardLightShader/blob/master/Lambert_SchlickGGX.gdshader
float DistributionGGX(float cos_theta_m, float alpha)
{
	float alpha2 = alpha * alpha;
	float d = 1.0 + (alpha2 - 1.0) * cos_theta_m * cos_theta_m;
	return alpha2 / (PI * d * d);
}

float GeometryGGX(float NdotL, float NdotV, float alpha)
{
	return 0.5 / mix(2.0 * NdotL * NdotV, NdotL + NdotV, alpha);
}

vec3 SchlickBaseReflectivity(float metallic, float specular, vec3 albedo)
{
	float dielectric = 0.04 * specular * specular;
	return mix(vec3(dielectric), albedo, vec3(metallic));
}

float SchlickFresnel(float u)
{
	float m = 1.0 - u;
	float m2 = m * m;
	return m2 * m2 * m;
}

void light()
{
	// Calculate some vectors.
	vec3 lightColor = LIGHT_COLOR / PI;

	vec3 half = normalize(VIEW + LIGHT);

	float NdotL = max(dot(NORMAL, LIGHT), 0.0);
	float NdotV = max(dot(NORMAL, VIEW), 0.0);
	float NdotH = max(dot(NORMAL, half), 0.0);
	float LdotH = max(dot(LIGHT, half), 0.0);

	// Diffuse light (Lambert).
	DIFFUSE_LIGHT += clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION * lightColor;

	// Specular light (Schlick-GGX).
	float ggxAlpha = ROUGHNESS * ROUGHNESS;
	float D = DistributionGGX(NdotH, ggxAlpha);
	float G = GeometryGGX(NdotL, NdotV, ggxAlpha);

	vec3 f0 = SchlickBaseReflectivity(METALLIC, SPECULAR_AMOUNT, ALBEDO);
	float LdotH5 = SchlickFresnel(LdotH);
	float f90 = clamp(50.0 * f0.g, 0.0, 1.0);
	vec3 F = f0 + (f90 - f0) * LdotH5;

	vec3 specularBRDF = max(NdotL * D * G * F, 0.0);
	SPECULAR_LIGHT += specularBRDF * LIGHT_COLOR * ATTENUATION;

	// Custom edits to (supposed) godot default light shader: Make asphalt shiny where hot
	if (VALUE_EPSILON < texture(asphalt_state, UV).r * texture(asphalt_attributes, UV).r){
		vec3 halfway_vector = normalize(LIGHT + VIEW);
		SPECULAR_LIGHT += (
			pow(max(dot(NORMAL, halfway_vector), 0.), 500. - asphalt_spread) * LIGHT_COLOR * asphalt_shiny
			* (10. * texture(asphalt_physics_state, UV).g) // Have asphalt be shinyer when hot
		);
	}
}