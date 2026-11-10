// General PBR surface for procedural meshes (walls, roofs, roads, pavements).
// UVs are in metres; uv_scale = texture repeats per metre.
// Adds grime near the ground, noise stains/streaks and optional moss so that
// tiling textures do not look clean and repetitive.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ao_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;

uniform vec2 uv_scale = vec2(1.0, 1.0);
uniform vec4 base_tint : source_color = vec4(1.0);
uniform float normal_strength = 1.0;
uniform float roughness_mult = 1.0;
uniform float metallic = 0.0;
uniform float ao_strength = 1.0;

// 0 = no per-instance tint, 1 = use wall_tint, 2 = use roof_tint
uniform int tint_channel = 0;
instance uniform vec4 wall_tint : source_color, instance_index(0) = vec4(1.0);
instance uniform vec4 roof_tint : source_color, instance_index(1) = vec4(1.0);

uniform vec4 grime_color : source_color = vec4(0.32, 0.29, 0.25, 1.0);
uniform float grime_amount = 0.35;      // darkening near the ground
uniform float grime_height = 1.2;       // metres above y = 0
uniform float stain_amount = 0.25;      // large noise blotches
uniform float stain_scale = 0.35;
uniform float streak_amount = 0.0;      // vertical rain streaks (walls)
uniform vec4 moss_color : source_color = vec4(0.28, 0.33, 0.17, 1.0);
uniform float moss_amount = 0.0;        // roofs

varying vec3 world_pos;
varying vec3 world_normal;

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
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 uv = UV * uv_scale;
	vec3 albedo = texture(albedo_tex, uv).rgb * base_tint.rgb;
	if (tint_channel == 1) {
		albedo *= wall_tint.rgb;
	} else if (tint_channel == 2) {
		albedo *= roof_tint.rgb;
	}

	// Planar coordinate along the surface for noise (works for walls and floors).
	vec2 np = abs(world_normal.y) > 0.7 ? world_pos.xz : vec2(world_pos.x + world_pos.z, world_pos.y);

	float stains = smoothstep(0.45, 0.85, fbm(np * stain_scale)) * stain_amount;
	float grime = (1.0 - smoothstep(0.0, grime_height, world_pos.y)) * grime_amount;
	float streak = 0.0;
	if (streak_amount > 0.0) {
		float s = noise(vec2((world_pos.x + world_pos.z) * 2.7, world_pos.y * 0.15));
		streak = smoothstep(0.55, 0.9, s) * streak_amount * (1.0 - abs(world_normal.y));
	}
	float dirt = clamp(stains + grime + streak, 0.0, 0.85);
	albedo = mix(albedo, albedo * grime_color.rgb, dirt);

	float rough = texture(roughness_tex, uv).r * roughness_mult;
	if (moss_amount > 0.0) {
		float m = smoothstep(0.5, 0.8, fbm(np * 0.6 + 3.1)) * moss_amount;
		albedo = mix(albedo, moss_color.rgb, m);
		rough = mix(rough, 1.0, m);
	}

	ALBEDO = albedo;
	ROUGHNESS = clamp(rough + dirt * 0.2, 0.0, 1.0);
	METALLIC = metallic;
	NORMAL_MAP = texture(normal_tex, uv).rgb;
	NORMAL_MAP_DEPTH = normal_strength;
	AO = mix(1.0, texture(ao_tex, uv).r, ao_strength);
	AO_LIGHT_AFFECT = 0.3;
}
