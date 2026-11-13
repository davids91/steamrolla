shader_type canvas_item;

uniform sampler2D terrain; // r: height, g: cracks, b: water presence
uniform sampler2D asphalt_state; // r: asphalt quantity, g: terrain temperature, b: unused
uniform sampler2D asphalt_attributes; /// r: presence, g: editability, b: fluidity
uniform float asphalt_minimum_quantity_for_display = 0.005;
uniform float asphalt_delta = 0.; // Addition / removal of asphalt under brush
uniform float paver_overflow_min: hint_range(0.0, 1.) = 0.1;
uniform float paver_overflow_max: hint_range(0.0, 1.) = 0.1;

uniform float tool_current_normalized_height = 0.;
uniform vec2 tool_center = vec2(0.5); 
uniform vec2 tool_size = vec2(0.3, 0.2); // size for rectangle shaped tools
uniform float tool_radius = 0.01; // radius for tools without a defined shape
uniform float tool_strength: hint_range(0.0, 1.0) = 0.4; // sets how mush the equipped tool affects the level
uniform float tool_angle = 0.;
uniform float tool_angle_offset = 0.;
uniform int used_tool = 0; // values of enum Tools{ ROLLER, PAVER, DUMPTRUCK, COMPACTOR, SHOVEL, UNKNOWN } (from UI/panels/tool_panel.gd)
const int TOOL_ROLLER = 0;
const int TOOL_PAVER = 1;
const int TOOL_DUMPTRUCK = 2;
const int TOOL_COMPACTOR = 3;
const int TOOL_SHOVEL = 4;

const float CONTROL_EPSILON = 0.005;
const float VALUE_EPSILON = 0.001;
const float PIXEL_RADIUS = 0.00390625; // 1. / 256. because asphalt display is of subdivision 256x256

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

// https://iquilezles.org/articles/distfunctions2d/
float sdSegment( in vec2 p, in vec2 a, in vec2 b )
{
    vec2 pa = p-a, ba = b-a;
    float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
    return length( pa - ba*h );
}

void fragment() {
	float asphalt_delta_output = 0.0;
	float current_asphalt_level = texture(asphalt_state, UV).r;
	float terrain_height = texture(terrain, UV).r;

	// early exit through return; is not supported....
	if(CONTROL_EPSILON < texture(asphalt_attributes, UV).g){ // Only run shader if the pixel is editable
		float distance_from_center = length(UV - tool_center);
		vec2 roller_direction = vec2(cos(tool_angle + tool_angle_offset), sin(tool_angle + tool_angle_offset)); // Roller direction to set exact boundaries of the roller
		vec2 roller_sideways_direction = vec2(-roller_direction.y, roller_direction.x);
		vec2 roller_bl = tool_center - tool_size.x * 0.5 * roller_sideways_direction - tool_size.y * 0.5 * roller_direction;
		vec2 roller_br = tool_center + tool_size.x * 0.5 * roller_sideways_direction - tool_size.y * 0.5 * roller_direction;
		vec2 roller_tr = tool_center + tool_size.x * 0.5 * roller_sideways_direction + tool_size.y * 0.5 * roller_direction;
		vec2 roller_tl = tool_center - tool_size.x * 0.5 * roller_sideways_direction + tool_size.y * 0.5 * roller_direction;

		/// DEBUG: to see roller angle
		//if(point_in_triangle(roller_bl, roller_tl, roller_tr, UV) || point_in_triangle(roller_bl, roller_tr, roller_br, UV)){
				//asphalt_delta_output = 0.8;
				//if(0.05 < length(UV - roller_bl)) asphalt_delta_output -= 0.3;
				//if(0.05 < length(UV - roller_br)) asphalt_delta_output += 0.3;
		//} else
		if (used_tool == TOOL_SHOVEL){
			asphalt_delta_output = asphalt_delta * (1. - smoothstep(0., tool_radius, distance_from_center));
		}else if (used_tool == TOOL_PAVER || used_tool == TOOL_DUMPTRUCK){
			float paver_range = 1. - smoothstep(
				paver_overflow_min, paver_overflow_max,
				min(
					sdSegment(UV, roller_tl, tool_center),
					sdSegment(UV, roller_tr, tool_center)
				)
			);
			asphalt_delta_output = max(
				sign((paver_range * tool_strength) - current_asphalt_level) * asphalt_delta,
				0.
			);
		}else if(used_tool == TOOL_COMPACTOR) {
			if(distance_from_center < tool_radius){ // Calculate the average height near the radius of the tool
				float avg_value = 0.;
				float sample_count = 0.;
				for(float x = UV.x - tool_radius; x < UV.x + tool_radius; x += (tool_radius / 5.)) {
					for(float y = UV.y - tool_radius; y < UV.y + tool_radius; y += (tool_radius / 5.)) {
						if(0. < texture(asphalt_attributes, vec2(x,y)).r){ // Only count pixel if it's part of the road
							avg_value += texture(asphalt_state, vec2(x,y)).r + texture(terrain, vec2(x,y)).r;
							sample_count += 1.;
						}
					}
				}
				avg_value /= sample_count;
				asphalt_delta_output = ( // Calculate the value this px needs to change to set the average height
					(avg_value - (current_asphalt_level + terrain_height))
					* tool_strength * smoothstep(tool_radius, 0., distance_from_center)
				);
			}
		}else if(used_tool == TOOL_ROLLER) {
			if(
				(terrain_height + current_asphalt_level) > tool_current_normalized_height
				&&(point_in_triangle(roller_bl, roller_tl, roller_tr, UV)|| point_in_triangle(roller_bl, roller_tr, roller_br, UV))
			) {
				// Squeeze direction is based on the axle of the roller
				vec2 roller_left = tool_center - tool_size.x * 0.5 * roller_sideways_direction;
				vec2 roller_right = tool_center + tool_size.x * 0.5 * roller_sideways_direction;
				vec2 roller_axle_direction = normalize(roller_left - roller_right);
				vec2 uv_projected_to_axle = roller_right + roller_axle_direction * dot(roller_axle_direction, (UV - roller_right));

				// Set squeeze direction to point away from roller axles
				roller_direction = normalize(UV - uv_projected_to_axle);

				// Refine roller direction for the asphalt simulation: direction points away from the center of the tool
				roller_direction = normalize(mix(roller_direction, normalize(UV - tool_center), 0.1));

				if(0. < dot(roller_direction, UV - uv_projected_to_axle)){
					vec2 prev_pixel_pos = UV - roller_direction * PIXEL_RADIUS;
					vec2 next_pixel_pos = UV + roller_direction * PIXEL_RADIUS;

					// Check for out of bounds
					if(all(lessThan(prev_pixel_pos, vec2(1.))) && all(greaterThan(prev_pixel_pos, vec2(0.)))){
						// The below lines are an attempt to simulate roller pressure for each induvidual pixel under the roller
						// calculate the asphalt being moved forward to the direction of the rolling to the next pixel
						vec3 next_pixel_attribute = texture(asphalt_attributes, next_pixel_pos).rgb;
						vec3 prev_pixel_attribute = texture(asphalt_attributes, prev_pixel_pos).rgb;

						// But only if the next pixel is within the editable asphalt area
						// --> Be enabling the below line, asphalt accumulates near the edges
						// --> because asphalt arriving from the previous pixels accumulate here
						// --> and has no way of leaving the level
						// if(next_pixel_attribute.r > 0. && next_pixel_attribute.g > 0.)
							asphalt_delta_output -= max(0., current_asphalt_level * tool_strength);

						// calcualte the asphalt being moved into this pixel from a neighbouring pixel opposite of the rolling direction
						if(prev_pixel_attribute.r > 0. && prev_pixel_attribute.g > 0.)
							asphalt_delta_output += max(0., texture(asphalt_state, prev_pixel_pos).r) * tool_strength;
					}
				} else {
					float avg_value = 0.;
					float sample_count = 0.;
					vec2 xy = UV + vec2(-PIXEL_RADIUS, -PIXEL_RADIUS);
					if(0. < texture(asphalt_attributes, xy).r){ // Only count pixel if it's part of the road
						avg_value += texture(asphalt_state, xy).r + texture(terrain, xy).r;
						sample_count += 1.;
					}
					xy = UV + vec2(-PIXEL_RADIUS, 0.);
					if(0. < texture(asphalt_attributes, xy).r){ // Only count pixel if it's part of the road
						avg_value += texture(asphalt_state, xy).r + texture(terrain, xy).r;
						sample_count += 1.;
					}
					xy = UV + vec2(-PIXEL_RADIUS, PIXEL_RADIUS);
					if(0. < texture(asphalt_attributes, xy).r){ // Only count pixel if it's part of the road
						avg_value += texture(asphalt_state, xy).r + texture(terrain, xy).r;
						sample_count += 1.;
					}
					xy = UV + vec2(0., PIXEL_RADIUS);
					if(0. < texture(asphalt_attributes, xy).r){ // Only count pixel if it's part of the road
						avg_value += texture(asphalt_state, xy).r + texture(terrain, xy).r;
						sample_count += 1.;
					}
					xy = UV + vec2(PIXEL_RADIUS, PIXEL_RADIUS);
					if(0. < texture(asphalt_attributes, xy).r){ // Only count pixel if it's part of the road
						avg_value += texture(asphalt_state, xy).r + texture(terrain, xy).r;
						sample_count += 1.;
					}
					xy = UV + vec2(PIXEL_RADIUS, 0.);
					if(0. < texture(asphalt_attributes, xy).r){ // Only count pixel if it's part of the road
						avg_value += texture(asphalt_state, xy).r + texture(terrain, xy).r;
						sample_count += 1.;
					}
					xy = UV + vec2(PIXEL_RADIUS, -PIXEL_RADIUS);
					if(0. < texture(asphalt_attributes, xy).r){ // Only count pixel if it's part of the road
						avg_value += texture(asphalt_state, xy).r + texture(terrain, xy).r;
						sample_count += 1.;
					}
					xy = UV;
					if(0. < texture(asphalt_attributes, xy).r){ // Only count pixel if it's part of the road
						avg_value += texture(asphalt_state, xy).r + texture(terrain, xy).r;
						sample_count += 1.;
					}
					avg_value /= sample_count;
					asphalt_delta_output = ( // Calculate the value this px needs to change to set the average height
						(avg_value - (current_asphalt_level + terrain_height))
						* tool_strength * smoothstep(tool_radius, 0., distance_from_center)
					);
				}
			}
		}
	}

	// clamp asphalt delta output in case it would eliminate asphalt
	if(current_asphalt_level > asphalt_minimum_quantity_for_display && asphalt_delta_output <= -current_asphalt_level) {
		asphalt_delta_output = asphalt_minimum_quantity_for_display - current_asphalt_level;
	}

	// asphalt delta is relative to 0.5
	asphalt_delta_output = 0.5 + clamp(asphalt_delta_output, -1., 1.) * 0.5;
	COLOR = vec4(vec3(asphalt_delta_output), 1.);
}