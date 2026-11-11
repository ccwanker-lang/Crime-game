// Muzzle flash card: hot core with ragged spikes, additive, unshaded.
// UV (0.5, 0.5) is the muzzle for the front card; for side cards the flame
// starts at UV.x = 0 and points to UV.x = 1.
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.72, 0.38, 1.0);
uniform float intensity = 3.0;
uniform float seed = 0.0;
uniform bool side_card = false;
// Same trick as the viewmodel shader: < 1 keeps it in front of walls.
uniform float depth_scale = 1.0;

float hash(float n) { return fract(sin(n) * 43758.5453); }

void vertex() {
	vec4 view_pos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	view_pos.xyz *= depth_scale;
	POSITION = PROJECTION_MATRIX * view_pos;
}

void fragment() {
	float a;
	if (side_card) {
		// Flame along +x, widest near the muzzle, fading out.
		float x = UV.x;
		float y = abs(UV.y - 0.5) * 2.0;
		float width = mix(0.55, 0.05, x) * (0.8 + 0.4 * hash(floor(x * 9.0) + seed));
		a = smoothstep(width, width * 0.3, y) * smoothstep(1.0, 0.25, x) * smoothstep(0.0, 0.06, x);
	} else {
		vec2 p = (UV - 0.5) * 2.0;
		float r = length(p);
		float ang = atan(p.y, p.x);
		float spikes = 0.0;
		for (int i = 0; i < 6; i++) {
			float dir = (float(i) + hash(seed + float(i))) * 6.2831 / 6.0;
			float d = abs(mod(ang - dir + 3.1416, 6.2831) - 3.1416);
			spikes = max(spikes, smoothstep(0.35, 0.0, d) * (0.6 + 0.4 * hash(seed * 3.0 + float(i))));
		}
		float core = smoothstep(0.45, 0.0, r);
		a = max(core, spikes * smoothstep(1.0, 0.2, r));
	}
	vec3 hot = mix(color.rgb, vec3(1.0, 0.95, 0.85), a * a);
	ALBEDO = hot * intensity * a;
	ALPHA = a;
}
