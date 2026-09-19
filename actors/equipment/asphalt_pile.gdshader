shader_type spatial;
render_mode depth_prepass_alpha;

uniform sampler2D asphalt_texture;
uniform sampler2D pile_noise;
uniform float opacity = 1.;
uniform float asphalt_pile_size = 1.;
uniform float asphalt_pile_spread_min = 1.;
uniform float asphalt_pile_spread_max = 1.;
uniform float asphalt_tile_size_ratio = 1.;
uniform float asphalt_shiny: hint_range(0.0, 1.0) = 0.2;
uniform float asphalt_spread: hint_range(0.0, 500.0) = 10.;
uniform float edge_transition = 0.001;

void vertex() {
	vec2 pos = (UV - 0.5) * 2.;
	VERTEX.y += (
		smoothstep(asphalt_pile_spread_min, asphalt_pile_spread_max ,(1. - length(pos))) * asphalt_pile_size
		- texture(pile_noise, UV).r * asphalt_pile_spread_max
	);

	// Do not set mesh height from samples from the other side of the level ( texture sampling wrap-around )
	float distance_from_edge = min(min(1. - UV.x, UV.x), min(1. - UV.y, UV.y));
	VERTEX.y *= smoothstep(0., edge_transition, distance_from_edge);
}

void fragment() {
	ALBEDO = texture(asphalt_texture, UV * asphalt_tile_size_ratio).rgb;
	ALPHA = opacity;
	vec2 pos = (UV - 0.5) * 2.;
	NORMAL = normalize(vec3(-pos.x, texture(pile_noise, UV).r, -pos.y));
}

// Recreation of the default godot light shader from
// --> https://github.com/RustyRoboticsBV/GodotStandardLightShader/blob/master/Lambert_SchlickGGX.gdshader
float DistributionGGX(float cos_theta_m, float alpha)
{
	float alpha2 = alpha * alpha;
	float d = 1.0 + (alpha2 - 1.0) * cos_theta_m * cos_theta_m;
	return alpha2 / (PI * d * d);
}

float GeometryGGX(float NdotL, float NdotV, float alpha)
{
	return 0.5 / mix(2.0 * NdotL * NdotV, NdotL + NdotV, alpha);
}

vec3 SchlickBaseReflectivity(float metallic, float specular, vec3 albedo)
{
	float dielectric = 0.04 * specular * specular;
	return mix(vec3(dielectric), albedo, vec3(metallic));
}

float SchlickFresnel(float u)
{
	float m = 1.0 - u;
	float m2 = m * m;
	return m2 * m2 * m;
}

void light()
{
	// Calculate some vectors.
	vec3 lightColor = LIGHT_COLOR / PI;

	vec3 half = normalize(VIEW + LIGHT);

	float NdotL = max(dot(NORMAL, LIGHT), 0.0);
	float NdotV = max(dot(NORMAL, VIEW), 0.0);
	float NdotH = max(dot(NORMAL, half), 0.0);
	float LdotH = max(dot(LIGHT, half), 0.0);

	// Diffuse light (Lambert).
	DIFFUSE_LIGHT += clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION * lightColor;

	// Specular light (Schlick-GGX).
	float ggxAlpha = ROUGHNESS * ROUGHNESS;
	float D = DistributionGGX(NdotH, ggxAlpha);
	float G = GeometryGGX(NdotL, NdotV, ggxAlpha);

	vec3 f0 = SchlickBaseReflectivity(METALLIC, SPECULAR_AMOUNT, ALBEDO);
	float LdotH5 = SchlickFresnel(LdotH);
	float f90 = clamp(50.0 * f0.g, 0.0, 1.0);
	vec3 F = f0 + (f90 - f0) * LdotH5;

	vec3 specularBRDF = max(NdotL * D * G * F, 0.0);
	SPECULAR_LIGHT += specularBRDF * LIGHT_COLOR * ATTENUATION;

	// Custom edits to (supposed) godot default light shader: Make asphalt shiny where hot
	vec3 halfway_vector = normalize(LIGHT + VIEW);
	SPECULAR_LIGHT += (
		pow(max(dot(NORMAL, halfway_vector), 0.), 500. - asphalt_spread) * LIGHT_COLOR * asphalt_shiny
	);
}