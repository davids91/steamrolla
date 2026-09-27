shader_type canvas_item;
render_mode blend_mix;

uniform sampler2D color_gradient: source_color;
uniform float stripes_angle = 0.;
uniform float stripes_spread = 0.;
uniform float stripes_edge = 0.;

void fragment() {
	vec2 rota_matrix = vec2(cos(stripes_angle), sin(stripes_angle));
	vec2 pos = vec2(
		UV.x * rota_matrix.x - UV.y * rota_matrix.y,
		UV.x * rota_matrix.y + UV.y * rota_matrix.x
	);
	float stripe_y = mod(pos.y * stripes_spread, 1.);
	vec4 edge_left_sample = texture(TEXTURE, UV - rota_matrix * vec2(stripes_edge));
	vec4 edge_right_sample = texture(TEXTURE, UV + rota_matrix * vec2(stripes_edge));
	COLOR = vec4(
		texture(color_gradient, vec2(stripe_y, 0.)).rgb,
		max(COLOR.a, max(edge_left_sample.a, edge_right_sample.a))
	);
	COLOR.rgb += vec3(COLOR.a - edge_right_sample.a);
	COLOR.rgb -= vec3(COLOR.a - edge_left_sample.a);
}