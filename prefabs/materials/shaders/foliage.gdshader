// Alpha-scissor foliage cards (trees, hedges) with wind and light shining through.
// Vertex COLOR.r = how much this vertex moves in the wind (0 at the trunk, 1 at outer leaves).
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D leaf_tex : source_color, filter_linear_mipmap_anisotropic;
uniform float alpha_cut = 0.5;
uniform vec4 tint : source_color = vec4(1.0);
instance uniform vec4 foliage_tint : source_color, instance_index(4) = vec4(1.0);
uniform float wind_strength = 0.08;
uniform float wind_speed = 1.1;

varying vec3 world_pos;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float w = COLOR.r;
	float phase = wp.x * 0.4 + wp.z * 0.3 + wp.y * 0.6;
	vec3 sway = vec3(sin(TIME * wind_speed + phase), sin(TIME * wind_speed * 1.7 + phase * 1.3) * 0.4, cos(TIME * wind_speed * 0.8 + phase)) * wind_strength * w;
	VERTEX += (inverse(MODEL_MATRIX) * vec4(sway, 0.0)).xyz;
	world_pos = wp;
}

void fragment() {
	vec4 c = texture(leaf_tex, UV);
	ALBEDO = c.rgb * tint.rgb * foliage_tint.rgb;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	ROUGHNESS = 0.8;
	SPECULAR = 0.3;
	BACKLIGHT = c.rgb * 0.6;
	// Darker towards the inside of the crown.
	AO = mix(0.55, 1.0, COLOR.r);
	AO_LIGHT_AFFECT = 0.7;
}
