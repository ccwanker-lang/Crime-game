// 3D grass blades for MultiMeshInstance3D. UV.y = 0 at the root, 1 at the tip.
// Wind sways the tips; colour varies by world position.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 root_color : source_color = vec4(0.13, 0.2, 0.07, 1.0);
uniform vec4 tip_color : source_color = vec4(0.45, 0.58, 0.22, 1.0);
uniform vec4 dry_color : source_color = vec4(0.6, 0.58, 0.3, 1.0);
uniform float wind_strength = 0.12;
uniform float wind_speed = 1.4;
uniform vec2 wind_direction = vec2(1.0, 0.3);

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
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = UV.y * UV.y;
	float gust = noise(wp.xz * 0.15 + TIME * wind_speed * 0.3);
	float sway = sin(TIME * wind_speed + wp.x * 0.7 + wp.z * 0.5) * 0.5 + gust;
	vec2 d = normalize(wind_direction) * sway * wind_strength * h;
	// Apply the offset in world space, then convert back to local space.
	vec3 offset_world = vec3(d.x, 0.0, d.y);
	VERTEX += (inverse(MODEL_MATRIX) * vec4(offset_world, 0.0)).xyz;
	world_pos = wp;
	// Point normals up so blades are lit like the ground (no dark backsides).
	NORMAL = (inverse(MODEL_MATRIX) * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
}

void fragment() {
	float v = noise(world_pos.xz * 0.2);
	vec3 tip = mix(tip_color.rgb, dry_color.rgb, smoothstep(0.6, 0.9, v) * 0.6);
	ALBEDO = mix(root_color.rgb, tip, UV.y);
	ROUGHNESS = 0.85;
	SPECULAR = 0.25;
	AO = mix(0.4, 1.0, UV.y);
	AO_LIGHT_AFFECT = 0.6;
	BACKLIGHT = vec3(0.25, 0.35, 0.1) * UV.y;
}
