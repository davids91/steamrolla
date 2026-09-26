shader_type canvas_item;

uniform sampler2D asphalt_state;
uniform sampler2D asphalt_attributes; /// r: presence, g: editability, b: fluidity
uniform vec2 getter_position; /// normalized position of the asphalt state to display in this texture

void fragment() {
	COLOR = vec4(
		texture(asphalt_state, getter_position).r * texture(asphalt_attributes, getter_position).r,
		0., 0., 1.
	);
}