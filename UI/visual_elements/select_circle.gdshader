shader_type spatial;
render_mode depth_test_disabled, unshaded;

uniform vec3 ring_color: source_color;
uniform sampler2D alpha_texture;
uniform float texture_y_scale = 1.;
uniform float ring_sharpness = 0.28;
uniform float ring_width = 0.3;
uniform float ring_diameter = 0.3;
uniform float ring_fadeout_width: hint_range(0.0, PI) = 0.3;
uniform float ring_fadeout_sharpness: hint_range(0.0, PI) = 0.3;
uniform float ring_fade_speed = 0.1;
uniform float pixellize_size = 50.;
uniform float leading_corner: hint_range(0.0, 1.) = 0.1;
uniform float leading_tip: hint_range(0.0, 0.1) = 0.1;

void vertex() {
    MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
        INV_VIEW_MATRIX[0],
        INV_VIEW_MATRIX[1],
        INV_VIEW_MATRIX[2],
        MODEL_MATRIX[3]
    );
    MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

// https://github.com/godotengine/godot/blob/fefec82d74b46f5e6cc31f373071058f80a5cbee/core/math/math_funcs.h#L505
// Why do I have to implement this?!
float angle_difference(float p_from, float p_to) {
	float difference = mod(p_to - p_from, TAU);
 	return mod(2.0 * difference, TAU) - difference;
}

void fragment() {
	vec2 pos = (UV - 0.5) * 2.;
	pos = round(pos * pixellize_size) / pixellize_size;
	float px_distance_from_center = length(pos);
	float px_distance_from_ring_center = abs(px_distance_from_center - ring_diameter);
	float ring_radial_presence = 1. - smoothstep(ring_sharpness, ring_width, px_distance_from_ring_center);
	float ring_fade_angle = -mod(TIME * ring_fade_speed, TAU);
	float ring_angular_position = max(
		angle_difference(atan(pos.y, pos.x) + PI, ring_fade_angle),
		angle_difference(atan(pos.y, pos.x) + PI, ring_fade_angle + PI)
	);
	float ring_angular_presence = smoothstep(ring_fadeout_sharpness, ring_fadeout_width, ring_angular_position);
	vec2 texture_sample_position = vec2(
		(px_distance_from_center - (ring_diameter - ring_width)) / (ring_width * 2.),
		ring_angular_position / TAU * texture_y_scale
	);
    ALBEDO = mix(vec3(0.), ring_color, vec3(ring_radial_presence * ring_angular_presence));
    ALPHA = ring_radial_presence * ring_angular_presence * texture(alpha_texture, texture_sample_position).a;
	ALPHA -= 1. - smoothstep(
		ring_width - leading_corner, ring_width,
		(ring_width * ((PI - ring_angular_position)) + leading_tip) / px_distance_from_ring_center
	);

	// DEBUG
	//ALBEDO = vec3(0.);
	//ALBEDO.r = smoothstep(
		//ring_width - leading_corner, ring_width,
		//(ring_width * (1. - ring_angular_position) + leading_tip) / px_distance_from_ring_center
	//);
	//ALPHA = 1.;
}