shader_type canvas_item;

uniform sampler2D terrain;
uniform sampler2D asphalt_state; /// Red channel: asphalt quantity
uniform sampler2D asphalt_physics_state; /// Also the output. Red channel: surface height(terrain + asphalt); Green channel: surface temperature
uniform sampler2D asphalt_attributes; /// r: presence, g: editability, b: fluidity
uniform sampler2D asphalt_delta;
uniform float cooldown_percentage = 0.5;

void fragment() {
	float current_surface_height = (
		texture(terrain, UV).r
		+ texture(asphalt_state, UV).r * texture(asphalt_attributes, UV).r
	) * 0.5;
	float temp_from_updates = smoothstep(0.0, 0.05, abs(texture(asphalt_delta, UV).r - 0.5));
	float asphalt_temperature = texture(asphalt_physics_state, UV).g * cooldown_percentage + temp_from_updates;
	COLOR = vec4(
		current_surface_height,
		asphalt_temperature,
		0.,
		1.
	);
}
