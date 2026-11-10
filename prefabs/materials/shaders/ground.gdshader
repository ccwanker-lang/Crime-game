// Natural ground: grass texture blended with dirt/worn patches by world-space noise.
// UVs come from world XZ, so any ground mesh can use it without UV setup.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D grass_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;

uniform float grass_scale = 0.4;   // repeats per metre
uniform float dirt_scale = 0.5;
uniform float dirt_amount = 0.35;  // 0 = only grass, 1 = lots of dirt
uniform float patch_scale = 0.08;
uniform vec4 grass_tint : source_color = vec4(0.9, 1.0, 0.85, 1.0);

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

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p *= 2.1;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	// Two scales of grass texture to hide tiling.
	vec3 g1 = texture(grass_albedo, p * grass_scale).rgb;
	vec3 g2 = texture(grass_albedo, p * grass_scale * 0.27 + 0.37).rgb;
	vec3 grass = mix(g1, g2, 0.35) * grass_tint.rgb;
	// Large-scale colour variation (dry / lush areas).
	float lush = fbm(p * 0.03);
	grass *= mix(vec3(1.08, 1.02, 0.8), vec3(0.85, 1.0, 0.85), lush);

	vec3 dirt = texture(dirt_albedo, p * dirt_scale).rgb;
	float m = fbm(p * patch_scale + 11.0);
	float d = smoothstep(1.0 - dirt_amount, 1.0 - dirt_amount + 0.15, m);

	ALBEDO = mix(grass, dirt, d);
	vec3 n1 = texture(grass_normal, p * grass_scale).rgb;
	vec3 n2 = texture(dirt_normal, p * dirt_scale).rgb;
	NORMAL_MAP = mix(n1, n2, d);
	ROUGHNESS = mix(0.95, 0.9, d);
}
