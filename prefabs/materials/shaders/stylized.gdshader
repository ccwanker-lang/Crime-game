// Point 27 art direction (stylized low-poly): THE surface shader of the world. Colour = a
// swatch of the one game palette (assets/palette/palette.png) or base_color, times the
// per-building tint, plus an optional simple procedural pattern (bricks, roof rows, paving
// tiles, planks...) with a few slightly different cells. No photo textures. Light model =
// lambert wrap, matte: the same as every other material in the game (characters, cars,
// weapons use StandardMaterial3D with diffuse_mode lambert wrap).
// UVs of procedural meshes are in metres.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert_wrap, specular_schlick_ggx;

uniform sampler2D palette : source_color, filter_nearest;
uniform int swatch = -1;         // -1 = base_color
uniform int swatch2 = -1;        // second colour: patches (grass), mortar/joint colour
uniform vec4 base_color : source_color = vec4(1.0);
uniform bool use_vertex_color = false;
// 0 none, 1 wall_tint, 2 roof_tint, 3 trim_tint, 4 door_tint, 5 foliage_tint
uniform int tint_channel = 0;
// 0 none, 1 bricks, 2 roof rows, 3 tile grid, 4 planks, 5 cobbles, 6 ribs, 7 soft patches
uniform int pattern = 0;
uniform vec2 cell = vec2(0.5, 0.17);
uniform float line_width = 0.014;
uniform float line_amount = 0.5;  // how much the joint colour shows in the lines
uniform float odd_share = 0.08;   // share of cells with a slightly different tone
uniform float odd_amount = 0.09;
uniform float patch_scale = 0.07; // pattern 7: patches per metre
uniform vec2 uv_scale = vec2(1.0);
uniform float roughness_v = 0.85;
uniform float specular_v = 0.3;
uniform float metallic_v = 0.0;
uniform float ground_shade = 0.0;  // slightly darker near the ground (walls)
// Point 103: how much rain wets this surface (roads 1, paving ~0.85, roofs 0.5; 0 = never: interiors).
uniform float wet_receiver = 0.0;
global uniform float wetness;
instance uniform vec4 wall_tint : source_color, instance_index(0) = vec4(1.0);
instance uniform vec4 roof_tint : source_color, instance_index(1) = vec4(1.0);
instance uniform vec4 trim_tint : source_color, instance_index(2) = vec4(1.0);
instance uniform vec4 door_tint : source_color, instance_index(3) = vec4(1.0);
instance uniform vec4 foliage_tint : source_color, instance_index(4) = vec4(1.0);

varying vec3 world_pos;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x),
			mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x), u.y);
}

vec3 swatch_color(int i, vec3 fallback) {
	if (i < 0) return fallback;
	return texelFetch(palette, ivec2(i % 8, i / 8), 0).rgb;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 c = swatch_color(swatch, base_color.rgb);
	if (swatch >= 0) c *= base_color.rgb;
	if (use_vertex_color) c *= COLOR.rgb;
	if (tint_channel == 1) c *= wall_tint.rgb;
	else if (tint_channel == 2) c *= roof_tint.rgb;
	else if (tint_channel == 3) c *= trim_tint.rgb;
	else if (tint_channel == 4) c *= door_tint.rgb;
	else if (tint_channel == 5) c *= foliage_tint.rgb;

	vec2 uv = UV * uv_scale;
	if (pattern == 7) {
		vec3 c2 = swatch_color(swatch2, c * 1.12);
		float n = vnoise(world_pos.xz * patch_scale) * 0.65 + vnoise(world_pos.xz * patch_scale * 2.7) * 0.35;
		c = mix(c, c2, smoothstep(0.5, 0.62, n) * odd_amount * 4.0);
	} else if (pattern > 0) {
		vec2 g = uv / cell;
		float row = floor(g.y);
		if (pattern == 1 || pattern == 5) g.x += mod(row, 2.0) * 0.5;  // half-brick offset
		if (pattern == 2) g.x += hash21(vec2(row, 3.0)) * 0.5;
		vec2 id = floor(g);
		vec2 f = fract(g);
		// Distance to the nearest joint, in metres; lines fade out when cells get tiny on screen.
		vec2 d = min(f, 1.0 - f) * cell;
		vec2 fw = fwidth(uv);
		float px = max(fw.x / cell.x, fw.y / cell.y);
		float fade = 1.0 - smoothstep(0.08, 0.25, px);
		float lx = 1.0 - smoothstep(line_width * 0.5, line_width * 0.5 + fw.x, d.x);
		float ly = 1.0 - smoothstep(line_width * 0.5, line_width * 0.5 + fw.y, d.y);
		float line = 0.0;
		if (pattern == 1 || pattern == 3 || pattern == 5) line = max(lx, ly);
		else if (pattern == 2) line = ly;
		else if (pattern == 4) line = lx;
		// A few cells a little lighter or darker (always visible, also far away).
		float h = hash21(id + vec2(17.0, 3.0));
		if (h < odd_share) c *= 1.0 + (hash21(id + vec2(5.0, 9.0)) - 0.5) * 2.0 * odd_amount * 2.0;
		else c *= 1.0 + (h - 0.5) * odd_amount * 0.35;
		if (pattern == 2) c *= mix(0.86, 1.0, smoothstep(0.0, 0.45, f.y));  // each row overlaps the next
		if (pattern == 6) c *= 0.9 + 0.1 * sin(g.x * 6.2832);
		vec3 joint = swatch_color(swatch2, c * 0.8);
		c = mix(c, joint, line * line_amount * fade);
	}
	if (ground_shade > 0.0) c *= mix(1.0 - ground_shade, 1.0, clamp(world_pos.y / 1.5, 0.0, 1.0));
	float rough = roughness_v;
	float spec = specular_v;
	float w = wetness * wet_receiver;
	if (w > 0.001) {
		// Wet: darker and glossier; on flat ground puddles (noise) go almost mirror-like.
		vec3 wn = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
		float flat_up = smoothstep(0.75, 0.95, wn.y);
		float puddle = smoothstep(0.58, 0.7, vnoise(world_pos.xz * 0.3) * 0.7 + vnoise(world_pos.xz * 1.1) * 0.3) * flat_up;
		c *= mix(1.0, 0.6, w) * mix(1.0, 0.85, puddle * w);
		rough = mix(rough, mix(0.3, 0.06, puddle), w);
		spec = mix(spec, 0.6, w);
	}
	ALBEDO = c;
	ROUGHNESS = rough;
	SPECULAR = spec;
	METALLIC = metallic_v;
}
