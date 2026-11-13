// Point 27 art direction: stylized window glass. Flat glass colour with a simple sky
// reflection (lighter towards the top + one soft diagonal sheen), now and then a flat
// curtain; at night (global night_lights) most windows glow warm.
// UV = 0..1 over the pane; the object position picks a different look per window.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert_wrap, specular_schlick_ggx;

uniform sampler2D palette : source_color, filter_nearest;
uniform int glass_swatch = 36;
uniform int glow_swatch = 37;
uniform vec4 sky_color : source_color = vec4(0.78, 0.88, 0.96, 1.0);
uniform float sheen = 0.35;
uniform float night_lit_share = 0.65;
uniform float night_brightness = 1.6;
uniform float day_glow = 0.0;     // shops: a little light inside by day too
global uniform float night_lights;

varying vec3 obj_pos;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void vertex() {
	obj_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 glass = texelFetch(palette, ivec2(glass_swatch % 8, glass_swatch / 8), 0).rgb;
	vec3 glow = texelFetch(palette, ivec2(glow_swatch % 8, glow_swatch / 8), 0).rgb;
	vec2 uv = UV;
	// Reflection: sky at the top fading to the darker glass colour, one diagonal sheen band.
	vec3 c = mix(glass * 0.55, mix(glass, sky_color.rgb, 0.45), smoothstep(0.0, 1.0, uv.y));
	float band = uv.x + uv.y * 0.6 + hash(floor(obj_pos.xz * 0.7)) * 0.4;
	float s = smoothstep(0.08, 0.0, abs(fract(band * 0.8) - 0.5) - 0.1);
	c = mix(c, sky_color.rgb, s * sheen);
	// Some windows have a flat curtain on the sides.
	float wh = hash(floor(obj_pos.xz * 1.3) + floor(obj_pos.y * 0.7) * 7.0);
	float curtain = 0.0;
	if (wh > 0.6) {
		float w = 0.16 + 0.1 * fract(wh * 13.1);
		curtain = (uv.x < w || uv.x > 1.0 - w) ? 1.0 : 0.0;
	}
	vec3 curtain_col = mix(vec3(0.93, 0.88, 0.76), vec3(0.75, 0.35, 0.28), step(0.5, fract(wh * 7.3)));
	c = mix(c, curtain_col * 0.8, curtain);
	// Night: warm glow in most windows, curtains glow a bit less.
	float lit = step(hash(floor(obj_pos.xz * 0.9) + floor(obj_pos.y * 0.45) * 3.1 + 11.0), night_lit_share);
	float g = max(night_lights * lit, day_glow);
	vec3 e = glow * night_brightness * mix(1.0, 0.7, curtain) * g;
	ALBEDO = c * (1.0 - g * 0.85);
	EMISSION = e;
	ROUGHNESS = 0.25;
	SPECULAR = 0.6;
}
