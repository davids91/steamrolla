shader_type spatial;
render_mode cull_disabled;

uniform sampler2D road_colormap;
uniform sampler2D asphalt_attributes; /// r: presence, g: editability, b: fluidity
uniform sampler2D asphalt_physics_state;
uniform sampler2D terrain_normalmap;
uniform sampler2D terrain_heightmap;
uniform float terrain_normal_strength = 0.1;
uniform float height_unit = 0.1;
uniform float normal_calculation_range = 0.05;
uniform float level_edge_transition = 0.001;
uniform vec3 water_color: source_color = vec3(0., 0., 1.);
uniform float water_transparency = 1.0;
uniform float water_detail: hint_range(0.001, 20.0) = 4.;
uniform sampler2D water_frequency_offset_curve;
uniform float water_detail_strength = 0.6;
uniform float water_scale = 2.0;
uniform float water_speed = 1.0;
uniform float water_height = 0.3;
uniform float water_shiny = 40;
uniform float water_directionality_angle = 0.;
uniform float water_direction_dominance: hint_range(0.0, 1.0) = 0.;
uniform float water_edge_calculation_range = 0.006;

const float VALUE_EPSILON = 0.001;
const float PIXEL_RADIUS = 0.002; // 1. / 512. because asphalt quantity texture is of resolution 512x512

float water_edge_modifier_for(vec2 uv, sampler2D asphalt_attributes_for_water, float calculation_range) {
	float water_count = 0.;
	float non_water_count = 0.;
	for(float x = uv.x - calculation_range; x < uv.x + calculation_range; x+= PIXEL_RADIUS){
		for(float y = uv.y - calculation_range; y < uv.y + calculation_range; y+= PIXEL_RADIUS){
			water_count += texture(asphalt_attributes_for_water, vec2(x,y)).b;
			non_water_count += 1. - texture(asphalt_attributes_for_water, vec2(x,y)).b;
		}
	}
	return smoothstep(0., calculation_range / PIXEL_RADIUS, water_count / max(non_water_count, VALUE_EPSILON));
}

varying vec3 water_normal;
varying float water_edge_modifier;
void vertex() {
	float vertex_height_addition = abs(texture(terrain_heightmap, UV).r) * height_unit;
	float water_height_addition = texture(asphalt_attributes, UV).b;
	vec2 water_normal_2D = vec2(0.);
	float wave_frequency = 1. / water_detail;
	for(float phase = 0.; phase < 1.; phase += wave_frequency) {
		float water_direction_angle = mix(water_directionality_angle + phase * TAU, water_directionality_angle, water_direction_dominance);
		vec2 water_direction = vec2(cos(water_direction_angle), sin(water_direction_angle));
		float wave_phase_value = (
			(dot(water_direction, UV) * water_scale)
			+ TIME * water_speed * phase
			+ texture(water_frequency_offset_curve, vec2(phase, 0.)).r
		);
		float wave_amplitude = pow(water_detail_strength, phase) * water_height;
		water_height_addition += sin(wave_phase_value) * wave_amplitude;
		water_normal_2D += water_direction * wave_amplitude * wave_frequency * water_scale * cos(wave_phase_value);
	}
	water_normal = mix(texture(terrain_normalmap, UV).xyz, normalize(vec3(-water_normal_2D, 0.)), water_detail_strength);

	// Do not set mesh height when OOB:
	// - from samples from the other side of the level ( texture sampling wrap-around )
	// - from water area
	float distance_from_level_edge = min(min(1. - UV.x, UV.x), min(1. - UV.y, UV.y));
	water_edge_modifier = (
		water_edge_modifier_for(UV, asphalt_attributes, water_edge_calculation_range)
		* smoothstep(0., level_edge_transition, distance_from_level_edge)
	);

	NORMAL = water_normal;
	VERTEX.y += vertex_height_addition + water_height_addition * water_edge_modifier;
}

void fragment() {
	//TODO: set shader values from RoadChunk object
	if (VALUE_EPSILON > water_edge_modifier)discard;
	ALBEDO = mix(texture(road_colormap, UV).rgb, water_color, 0.9);
	NORMAL = water_normal;
	ALPHA = water_transparency;
}

const float WATER_SHINY_MAX = 200.;
void light() {
	vec3 halfway_vector = normalize(LIGHT + VIEW);
	SPECULAR_LIGHT += pow(max(dot(NORMAL, halfway_vector), 0.), WATER_SHINY_MAX - water_shiny) * LIGHT_COLOR;
}