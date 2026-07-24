shader_type canvas_item;

uniform sampler2D terrain;
uniform sampler2D asphalt_state; /// Red channel: asphalt quantity
uniform sampler2D asphalt_physics_state; /// Also the output. Red channel: surface height(terrain + asphalt); Green channel: surface temperature
uniform sampler2D asphalt_attributes; /// r: presence, g: editability, b: fluidity
uniform sampler2D asphalt_delta;
uniform sampler2D water_noise;
uniform float water_speed = 0.001;
uniform float water_flow_modifier_threshold = 0.5;
uniform float cooldown_percentage = 0.5;

const float PI_DOUBLE = 6.283185307;
const float PIXEL_RADIUS = 0.002; // 1. / 512. because asphalt quantity texture is of resolution 512x512

void fragment() {
	vec3 current_physics_state = texture(asphalt_physics_state, UV).rgb;
	vec3 current_asphalt_attributes = texture(asphalt_attributes, UV).rgb;
	float current_surface_height = (
		texture(terrain, UV).r
		+ texture(asphalt_state, UV).r * current_asphalt_attributes.r
	) * 0.5;

	// Handle temperature physics
	float temp_from_updates = smoothstep(0.0, 0.05, abs(texture(asphalt_delta, UV).r - 0.5));
	float asphalt_temperature = current_physics_state.g * cooldown_percentage + temp_from_updates;

	// Handle water physics
	vec2 uv_water_sample = mod(UV + vec2(fract(TIME * water_speed * current_asphalt_attributes.b), 0.), 1.);
	float current_water_level = texture(water_noise, uv_water_sample).r;
	if(water_flow_modifier_threshold >= current_water_level){
		uv_water_sample = mod(UV + vec2(0., fract(TIME * water_speed * current_asphalt_attributes.b)), 1.);
	}
	current_water_level = texture(water_noise, uv_water_sample).r * current_asphalt_attributes.b;

	COLOR = vec4(
		current_surface_height,
		asphalt_temperature,
		current_water_level,
		1.
	);
}
