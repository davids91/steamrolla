shader_type canvas_item;

uniform sampler2D terrain;
uniform sampler2D asphalt_state; // Basically asphalt quantity
uniform sampler2D asphalt_attributes; /// r: presence, g: editability, b: fluidity
uniform float asphalt_delta = 0.; // Addition / removal of asphalt under brush
uniform float paver_height = 0.;
uniform float paver_overflow_min: hint_range(0.0, 1.) = 0.1;
uniform float paver_overflow_max: hint_range(0.0, 1.) = 0.1;

uniform vec2 tool_center = vec2(0.5); 
uniform vec2 tool_size = vec2(0.3, 0.2); // size for rectangle shaped tools
uniform float tool_radius = 0.01; // radius for tools without a defined shape
uniform float tool_strength: hint_range(0.0, 1.0) = 0.4; // sets how mush the equipped tool affects the level
uniform float tool_angle = 0.;
uniform float tool_angle_offset = 0.;
uniform int used_tool = 0; // values of enum Tools{ ROLLER, PAVER, DUMPTRUCK, COMPACTOR, SHOVEL, UNKNOWN } (from core/UI/tool_panel.gd)
const int TOOL_ROLLER = 0;
const int TOOL_PAVER = 1;
const int TOOL_DUMPTRUCK = 2;
const int TOOL_COMPACTOR = 3;
const int TOOL_SHOVEL = 4;

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

// https://iquilezles.org/articles/distfunctions2d/
float sdSegment( in vec2 p, in vec2 a, in vec2 b )
{
    vec2 pa = p-a, ba = b-a;
    float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
    return length( pa - ba*h );
}

void fragment() {
	float asphalt_delta_output = 0.0;
	// early exit through return; is not supported....
	if(CONTROL_EPSILON < texture(asphalt_attributes, UV).g){ // Only run shader if the pixel is editable
		float current_asphalt_level = texture(asphalt_state, UV).r;
		vec2 roller_direction = vec2(cos(tool_angle + tool_angle_offset), sin(tool_angle + tool_angle_offset)); // Roller direction to set esact boundaries of the roller
		vec2 roller_sideways_direction = vec2(-roller_direction.y, roller_direction.x);
		vec2 roller_bl = tool_center - tool_size.x * 0.5 * roller_sideways_direction - tool_size.y * 0.5 * roller_direction;
		vec2 roller_br = tool_center + tool_size.x * 0.5 * roller_sideways_direction - tool_size.y * 0.5 * roller_direction;
		vec2 roller_tr = tool_center + tool_size.x * 0.5 * roller_sideways_direction + tool_size.y * 0.5 * roller_direction;
		vec2 roller_tl = tool_center - tool_size.x * 0.5 * roller_sideways_direction + tool_size.y * 0.5 * roller_direction;
		float distance_from_center = length(UV - tool_center);

		// Refine roller direction for the asphalt simulation
		roller_direction = normalize(mix(roller_direction, normalize(UV - tool_center), 0.1));

		/// DEBUG: to see roller angle
		//if(point_in_triangle(roller_bl, roller_tl, roller_tr, UV) || point_in_triangle(roller_bl, roller_tr, roller_br, UV)){
				//asphalt_delta_output = 0.8;
				//if(0.05 < length(UV - roller_bl)) asphalt_delta_output -= 0.3;
				//if(0.05 < length(UV - roller_br)) asphalt_delta_output += 0.3;
		//} else
		if (used_tool == TOOL_SHOVEL){
			asphalt_delta_output = asphalt_delta * (1. - smoothstep(0., tool_radius, distance_from_center));
		}else if (
			used_tool == TOOL_PAVER 
		){
			asphalt_delta_output = max( 
				sign(
					paver_height * (1. + tool_strength)
					- smoothstep(
						paver_overflow_min, paver_overflow_max,
						min(
							sdSegment(UV, roller_tl, tool_center),
							sdSegment(UV, roller_tr, tool_center)
						)
					)
					- current_asphalt_level
				) * asphalt_delta,
				0.
			);
		}else if(used_tool == TOOL_COMPACTOR) {
			if(distance_from_center < tool_radius){
				float avg_value = 0.;
				float sample_count = 0.;
				for(float x = UV.x - tool_radius; x < UV.x + tool_radius; x += (tool_radius / 5.)) {
					for(float y = UV.y - tool_radius; y < UV.y + tool_radius; y += (tool_radius / 5.)) {
						avg_value += texture(asphalt_state, vec2(x,y)).r;
						sample_count += 1.;
					}
				}
				avg_value /= sample_count;
				asphalt_delta_output = (avg_value - current_asphalt_level) * tool_strength * smoothstep(tool_radius, 0., distance_from_center);
			}
		}else if(used_tool == TOOL_ROLLER) {
			vec2 prev_pixel_pos = UV - roller_direction * PIXEL_RADIUS;
			if( // Check if pixel is within Roller distance
				(point_in_triangle(roller_bl, roller_tl, roller_tr, UV)|| point_in_triangle(roller_bl, roller_tr, roller_br, UV))
				// Check for out of bounds
				&&(all(lessThan(prev_pixel_pos, vec2(1.))) && all(greaterThan(prev_pixel_pos, vec2(0.))))
			){
				// calculate the asphalt being moved forward to the direction of the rolling to the next pixel
				asphalt_delta_output -= current_asphalt_level * tool_strength;
				// calcualte the asphalt being moved into this pixel from a neighbouring pixel opposite of the rolling direction
				asphalt_delta_output += texture(asphalt_state, prev_pixel_pos).r * tool_strength;
			}
		}
	}

	// asphalt delta is relative to 0.5
	asphalt_delta_output = 0.5 + clamp(asphalt_delta_output, -1., 1.) * 0.5;
	COLOR = vec4(vec3(asphalt_delta_output), 1.);
}