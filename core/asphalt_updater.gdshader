shader_type canvas_item;

uniform bool using_roller = true;
uniform sampler2D terrain;
uniform sampler2D asphalt; // Basically asphalt quantity
uniform sampler2D asphalt_filter; // where is asphalt
uniform sampler2D target_height; // the reference height set by the level
uniform float effect_radius = 0.01; // Shovel for asphalt alpha
uniform float set_to_reference = 0.; // Set to some arbitrary value to "snap" asphalt to given reference
uniform float effect_strength: hint_range(0.0, 1.0) = 0.4;
uniform float asphalt_delta = 0.; // Addition / removal of asphalt
uniform vec2 roller_center = vec2(0.5); 
uniform vec2 roller_size = vec2(0.3, 0.2);
uniform float roller_angle = 0.;
uniform float asphalt_minimum_quantity_for_display = 0.005; // Minimum quantity of  asphalt that is displayed as asphalt

const float CONTROL_EPSILON = 0.005;
const float VALUE_EPSILON = 0.001;

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
	float asphalt_level = texture(asphalt, UV).r;
	vec2 roller_direction = vec2(cos(roller_angle), sin(roller_angle));
	vec2 roller_sideways_direction = vec2(-roller_direction.y, roller_direction.x);
	vec2 roller_bl = roller_center - roller_size.x * 0.5 * roller_sideways_direction - roller_size.y * 0.5 * roller_direction;
	vec2 roller_br = roller_center + roller_size.x * 0.5 * roller_sideways_direction - roller_size.y * 0.5 * roller_direction;
	vec2 roller_tr = roller_center + roller_size.x * 0.5 * roller_sideways_direction + roller_size.y * 0.5 * roller_direction;
	vec2 roller_tl = roller_center - roller_size.x * 0.5 * roller_sideways_direction + roller_size.y * 0.5 * roller_direction;
	///// DEBUG: to see roller angle
	//if(true){
		//if(
			//point_in_triangle(roller_bl, roller_tl, roller_tr, UV)
			//|| point_in_triangle(roller_bl, roller_tr, roller_br, UV)
		//) {
			//asphalt_level += asphalt_delta;
			//if(0.05 < length(UV - roller_bl)){
				//asphalt_level -= 0.3;
			//}
			//if(0.05 < length(UV - roller_br)){
				//asphalt_level += 0.3;
			//}
		//}
	//} else
	if (CONTROL_EPSILON < effect_strength) {
		if (VALUE_EPSILON < abs(asphalt_delta)){ // Shoveling
			float distance_from_center = length(UV - roller_center);
			float _asphalt_delta = asphalt_delta * smoothstep(effect_radius, 0., distance_from_center);
			if(abs(_asphalt_delta) > VALUE_EPSILON){
				// TODO: better shoveling distribution for putting asphalt
				asphalt_level += _asphalt_delta;
			}
		}else if(VALUE_EPSILON < set_to_reference){ // Morphing into reference
			//TODO: unify common parts ( e.g. texture requests ) into one common part before the branches
			float expected_asphalt_level = (
				(texture(target_height, UV).r - texture(terrain, UV).r * 0.5)
				 * 2.0
			);
			asphalt_level = mix(asphalt_level, expected_asphalt_level, set_to_reference);
			//float input_difference_value = (0.5 - texture(input_difference, UV).r);
			//if (set_to_reference < VALUE_EPSILON){
				//asphalt_level += input_difference_value;
			//}else{
				//asphalt_level += input_difference_value * set_to_reference;
			//}
			
		}
		else if(!using_roller){ // Manually compacting
			if(length(UV - roller_center) < effect_radius){
				float avg_value = 0.;
				float sample_count = 0.;
				//TODO: read in LOD instead of calculating avg
				for(float x = UV.x - effect_radius; x < UV.x + effect_radius; x += (effect_radius / 5.)) {
					for(float y = UV.y - effect_radius; y < UV.y + effect_radius; y += (effect_radius / 5.)) {
						avg_value += texture(asphalt, vec2(x,y)).r;
						sample_count += 1.;
					}
				}
				avg_value /= sample_count;
				asphalt_level = mix(asphalt_level, avg_value, effect_strength);
			}
		}else if( // Roller
			point_in_triangle(roller_bl, roller_tl, roller_tr, UV)
			|| point_in_triangle(roller_bl, roller_tr, roller_br, UV)
		) {
			// Convert to a coordinate system where origin is roller_center
			//TODO: +++ Logic to query the asphalt level at the start of the rolling
			float min_asphalt_level = texture(asphalt, UV).r * (1. - effect_strength);
			//vec2 pos_to_center = UV - roller_center; 
//
			//// Is this really needed?
			////// Angle between the 2 directions
			////// https://github.com/godotengine/godot/blob/master/core/math/vector2.cpp#L90
			////float angle_to_pos = atan(
				////// cross product
				////// https://github.com/godotengine/godot/blob/master/core/math/vector2.cpp#L102
				////(pos_to_center.x * roller_direction.y - pos_to_center.y * roller_direction.x),
				////dot(pos_to_center, roller_direction)
			////);
//
			//vec2 pos_projected_to_roller_center = (
				////TODO: Based on https://en.wikipedia.org/wiki/Vector_projection
				//vec2(0.)
			//);
//
			//float size_diff_to_pos = sqrt( //TODO: verify!!
				//pow((roller_center - UV), 2.) - pow((UV - pos_projected_to_roller_center), 2.)
			//);
			////TODO: This determines the start of the rectangle in direction by: x = size/2 - size_diff_to_pos
			// End: +++ Logic to query the asphalt level at the start of the rolling


			float pixel_radius = 0.002; // 1. / 512. because asphalt quantity texture is of resolution 512x512
			//// TODO: Add the sum of the fraction of the values opposite to the direction of the roller for a radius
			//// TODO: Add the values after the edge of the actual roller
			// calculate the asphalt being moved forward to the direction of the rolling to the next pixel
			float clamped_minimum_asphalt_level = 0.;
			if(asphalt_level > 0.){
				clamped_minimum_asphalt_level = asphalt_minimum_quantity_for_display;
			}
			// calcualte the asphalt being moved into this pixel from a neighbouring pixel opposite of the rolling direction
			asphalt_level -=  (texture(asphalt, UV).r - min_asphalt_level) * effect_strength;
			asphalt_level += (texture(asphalt, UV - roller_direction * pixel_radius).r - min_asphalt_level) * effect_strength * 1.001;
			asphalt_level = clamp(asphalt_level, clamped_minimum_asphalt_level, 1.);
			// TODO: push asphalt overflow to the nearest compatible neighbour, not only in the roller direction
		}
	}
	asphalt_level = clamp(asphalt_level, 0., 1.);
	COLOR = vec4(vec3(asphalt_level), 1.);
}
