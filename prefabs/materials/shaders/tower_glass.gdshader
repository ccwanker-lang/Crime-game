// Map zone 7: curtain-wall glass for city towers. UV.x = window number along the face (fract = the pane),
// UV.y = floor number (fract = up the pane). Each window gets one fixed look from its number: blinds part way
// down now and then, lit at night (global night_lights) for a share of them. The sky reflection fades with height.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert_wrap, specular_schlick_ggx;

uniform vec4 glass_color : source_color = vec4(0.28, 0.38, 0.48, 1.0);
uniform vec4 sky_color : source_color = vec4(0.78, 0.88, 0.96, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.86, 0.6, 1.0);
uniform float night_lit_share = 0.45;
uniform float night_brightness = 1.4;
global uniform float night_lights;

varying vec3 world_pos;
varying float tower_seed;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	tower_seed = fract(sin(dot(NODE_POSITION_WORLD.xz, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 id = floor(UV);
	vec2 pane = fract(UV);
	float h = hash(id + tower_seed * 97.0);
	// Glass: darker low in the pane, the sky mirrored higher up, a soft diagonal sheen over the whole facade.
	vec3 c = mix(glass_color.rgb * 0.7, mix(glass_color.rgb, sky_color.rgb, 0.5), smoothstep(0.0, 1.0, pane.y));
	float sheen = smoothstep(0.35, 0.0, abs(fract((world_pos.x + world_pos.z) * 0.012 + world_pos.y * 0.008 + tower_seed) - 0.5) - 0.2);
	c = mix(c, sky_color.rgb, sheen * 0.35);
	c *= 0.92 + 0.16 * h;
	// Blinds: a light band from the top of the pane down.
	float blind = step(0.72, h) * step(1.0 - (0.25 + 0.5 * fract(h * 17.0)), pane.y);
	c = mix(c, vec3(0.86, 0.85, 0.8), blind * 0.85);
	// Night: a share of the windows glow warm.
	float lit = step(hash(id * 1.7 + tower_seed * 31.0 + 5.0), night_lit_share);
	float g = night_lights * lit;
	ALBEDO = c * (1.0 - g * 0.8);
	EMISSION = glow_color.rgb * night_brightness * g * mix(1.0, 0.75, blind);
	ROUGHNESS = 0.18;
	SPECULAR = 0.65;
	METALLIC = 0.1;
}
