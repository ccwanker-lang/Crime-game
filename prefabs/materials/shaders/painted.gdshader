// Painted surfaces without a texture (window frames, doors, gutters, railings).
// Per-building colours via instance uniforms; subtle noise for worn paint.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.9, 0.9, 0.88, 1.0);
uniform float roughness = 0.5;
uniform float metallic = 0.0;
uniform float wear = 0.15;
// 0 = none, 3 = trim_tint (frames), 4 = door_tint, 1 = wall_tint
uniform int tint_channel = 0;
instance uniform vec4 trim_tint : source_color, instance_index(2) = vec4(1.0);
instance uniform vec4 door_tint : source_color, instance_index(3) = vec4(1.0);
instance uniform vec4 wall_tint : source_color, instance_index(0) = vec4(1.0);

varying vec3 world_pos;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 c = base_color.rgb;
	if (tint_channel == 3) c *= trim_tint.rgb;
	else if (tint_channel == 4) c *= door_tint.rgb;
	else if (tint_channel == 1) c *= wall_tint.rgb;
	float n = noise(world_pos.xy * 6.0 + world_pos.zy * 5.0);
	c *= 1.0 - wear * smoothstep(0.4, 1.0, n);
	ALBEDO = c;
	ROUGHNESS = clamp(roughness + n * wear, 0.0, 1.0);
	METALLIC = metallic;
}
