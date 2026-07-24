shader_type spatial;

uniform sampler2D road_colormap;
uniform sampler2D asphalt_attributes; /// r: presence, g: editability, b: fluidity
uniform sampler2D asphalt_physics_state;
uniform sampler2D terrain_normalmap;
uniform sampler2D terrain_heightmap;
uniform float terrain_normal_strength = 0.1;
uniform float height_unit = 0.1;
uniform float normal_calculation_range = 0.05;
uniform float level_edge_transition = 0.001;
uniform float water_transparency = 1.0; //TODO: this to actually work

const float VALUE_EPSILON = 0.001;

void vertex() {
	float vertex_height_addition = abs(texture(terrain_heightmap, UV).r) * height_unit;
	vertex_height_addition += texture(asphalt_physics_state, UV).b * texture(asphalt_attributes, UV).b;
	vertex_height_addition *= smoothstep(0., level_edge_transition, min(min(1. - UV.x, UV.x), min(1. - UV.y, UV.y)));
	VERTEX.y += vertex_height_addition;
}

vec3 normal_from_heightmap(sampler2D heightmap, vec2 uv, float gradient_delta){
	float terrain_height_left = abs(texture(heightmap, uv + vec2(-gradient_delta, 0.)).r);
	float terrain_height_right = abs(texture(heightmap, uv + vec2(gradient_delta, 0.)).r);
	float terrain_height_far = abs(texture(heightmap, uv + vec2(0., gradient_delta)).r);
	float terrain_height_near = abs(texture(heightmap, uv + vec2(0., -gradient_delta)).r);
	return normalize(vec3((terrain_height_right - terrain_height_left), (terrain_height_near - terrain_height_far), -1));
}

void fragment() {
	if (VALUE_EPSILON > texture(asphalt_physics_state, UV).b) discard;
	ALBEDO = texture(road_colormap, UV).rgb;
	NORMAL_MAP = mix(
		normal_from_heightmap(terrain_heightmap, UV, normal_calculation_range),
		texture(terrain_normalmap, UV).xyz, 0.5
	);
	ALPHA = texture(asphalt_attributes, UV).b;
}
