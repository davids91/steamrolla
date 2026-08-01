shader_type canvas_item;

uniform bool using_roller = true;
uniform sampler2D terrain;
uniform sampler2D asphalt_state; // Basically asphalt quantity
uniform sampler2D asphalt_attributes; /// r: presence, g: editability, b: fluidity
uniform float effect_radius = 0.01; // Shovel for asphalt alpha
uniform float effect_strength: hint_range(0.0, 1.0) = 0.4;
uniform float asphalt_delta = 0.; // Addition / removal of asphalt under brush
uniform vec2 roller_center = vec2(0.5); 
uniform vec2 roller_size = vec2(0.3, 0.2);
uniform float roller_angle = 0.;

const float CONTROL_EPSILON = 0.005;
const float VALUE_EPSILON = 0.001;
const float PIXEL_RADIUS = 0.002; // 1. / 512. because asphalt quantity texture is of resolution 512x512

// https://github.com/SebLague/Gamedev-Maths/blob/master/PointInTriangle.cs
bool point_in_triangle(vec2 a, vec2 b, vec2 c, vec2 p) {
	float s1 = c.y - a.y;
	float s2 = c.x - a.x;
	float s3 = b.y - a.y;
	float s4 = p.y - a.y;

	float w1 = (a.x * s1 + s4 * s2 - p.x * s1) / (s3 * s2 - (b.x-a.x) * s1);
	float w2 = (s4- w1 * s3) / s1;
	return w1 >= 0. && w2 >= 0. && (w1 + w2) <= 1.;
}

void fragment() {
	float asphalt_delta_output = 0.0;
	// early exit through return; is not supported....
	if(CONTROL_EPSILON < texture(asphalt_attributes, UV).g){ // Only run shader if the pixel is editable
		vec2 roller_direction = vec2(cos(roller_angle), sin(roller_angle)); // Roller direction to set esact boundaries of the roller
		vec2 roller_sideways_direction = vec2(-roller_direction.y, roller_direction.x);
		vec2 roller_bl = roller_center - roller_size.x * 0.5 * roller_sideways_direction - roller_size.y * 0.5 * roller_direction;
		vec2 roller_br = roller_center + roller_size.x * 0.5 * roller_sideways_direction - roller_size.y * 0.5 * roller_direction;
		vec2 roller_tr = roller_center + roller_size.x * 0.5 * roller_sideways_direction + roller_size.y * 0.5 * roller_direction;
		vec2 roller_tl = roller_center - roller_size.x * 0.5 * roller_sideways_direction + roller_size.y * 0.5 * roller_direction;
		float distance_from_center = length(UV - roller_center);

		// Refine roller direction for the asphalt simulation
		roller_direction = normalize(mix(roller_direction, normalize(UV - roller_center), 0.1));

		//if(true){ /// DEBUG: to see roller angle
			//if(point_in_triangle(roller_bl, roller_tl, roller_tr, UV) || point_in_triangle(roller_bl, roller_tr, roller_br, UV)) {
				//asphalt_delta_output = asphalt_delta;
				//if(0.05 < length(UV - roller_bl)) asphalt_delta_output -= 0.3;
				//if(0.05 < length(UV - roller_br)) asphalt_delta_output += 0.3;
			//}
		//} else
		if (VALUE_EPSILON < abs(asphalt_delta)){ // Shoveling
			float _asphalt_delta = asphalt_delta * (1. - smoothstep(0., effect_radius, distance_from_center));
			if(abs(_asphalt_delta) > VALUE_EPSILON){
				asphalt_delta_output = _asphalt_delta;
			}
		//}else if(CONTROL_EPSILON < effect_strength && !using_roller){ // Manually compacting
		}else if(false){ // DEBUG
			if(distance_from_center < effect_radius){
				float avg_value = 0.;
				float sample_count = 0.;
				for(float x = UV.x - effect_radius; x < UV.x + effect_radius; x += (effect_radius / 5.)) {
					for(float y = UV.y - effect_radius; y < UV.y + effect_radius; y += (effect_radius / 5.)) {
						avg_value += texture(asphalt_state, vec2(x,y)).r;
						sample_count += 1.;
					}
				}
				avg_value /= sample_count;
				asphalt_delta_output = (avg_value - texture(asphalt_state, UV).r) * effect_strength * smoothstep(effect_radius, 0., distance_from_center);
			}
		}else if(CONTROL_EPSILON < effect_strength) { // Using SteamRoller
			vec2 prev_pixel_pos = UV - roller_direction * PIXEL_RADIUS;
			if(
				( // Check if pixel is within Roller distance
					point_in_triangle(roller_bl, roller_tl, roller_tr, UV)
					|| point_in_triangle(roller_bl, roller_tr, roller_br, UV)
				)&&( // Check for out of bounds
					all(lessThan(prev_pixel_pos, vec2(1.)))
					&& all(greaterThan(prev_pixel_pos, vec2(0.)))
				)
			){
				// calculate the asphalt being moved forward to the direction of the rolling to the next pixel
				asphalt_delta_output -= texture(asphalt_state, UV).r * effect_strength;
				// calcualte the asphalt being moved into this pixel from a neighbouring pixel opposite of the rolling direction
				asphalt_delta_output += texture(asphalt_state, prev_pixel_pos).r * effect_strength;
			}
		}
	}

	// asphalt delta is relative to 0.5
	asphalt_delta_output = 0.5 + clamp(asphalt_delta_output, -1., 1.) * 0.5;
	COLOR = vec4(vec3(asphalt_delta_output), 1.);
}