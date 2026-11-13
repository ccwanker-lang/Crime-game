// Outline for art style C: the back faces pushed out in screen space (constant width in
// pixels, also on skinned and scaled models), unlit dark colour.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled;
uniform vec4 outline_color : source_color = vec4(0.05, 0.05, 0.06, 1.0);
uniform float width_px = 2.0;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 n = normalize(mat3(MODELVIEW_MATRIX) * NORMAL);
	vec2 dir = (PROJECTION_MATRIX * vec4(n, 0.0)).xy;
	if (length(dir) > 0.0001) {
		dir = normalize(dir);
	}
	clip.xy += dir * width_px * 2.0 / VIEWPORT_SIZE * clip.w;
	POSITION = clip;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
