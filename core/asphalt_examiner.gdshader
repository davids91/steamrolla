shader_type canvas_item;

uniform sampler2D asphalt_state;
uniform sampler2D asphalt_attributes; /// r: presence, g: editability, b: fluidity
uniform sampler2D target_asphalt_state; /// r: quantity

void fragment() {
	COLOR = vec4( // The difference betwen the current and target quantities where asphalt is present
		vec3(
			(0.5 + (texture(asphalt_state, UV).r - texture(target_asphalt_state, UV).r))
			* texture(asphalt_attributes, UV).r
		),
		1.
	);
}
