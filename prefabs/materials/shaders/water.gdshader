shader_type spatial;
// Point 47: stylized sea/harbour water - flat colour bands, slow low-poly waves, lighter at grazing angles.
render_mode cull_disabled;

uniform vec3 deep_color : source_color = vec3(0.10, 0.32, 0.42);
uniform vec3 shallow_color : source_color = vec3(0.24, 0.55, 0.60);
uniform vec3 foam_color : source_color = vec3(0.80, 0.90, 0.88);
uniform float wave_height = 0.12;
uniform float wave_scale = 0.08;
uniform float speed = 0.35;

varying vec3 world_pos;

float wave(vec2 p, float t) {
	return sin(p.x * wave_scale * 6.0 + t) * 0.5 + sin(p.y * wave_scale * 4.3 - t * 1.3) * 0.35
		+ sin((p.x + p.y) * wave_scale * 9.0 + t * 0.7) * 0.15;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += wave(world_pos.xz, TIME * speed) * wave_height;
}

void fragment() {
	float t = TIME * speed;
	float w = wave(world_pos.xz, t) * 0.5 + 0.5;
	float band = floor(w * 3.0) / 3.0;  // stylized: 3 colour bands
	vec3 c = mix(deep_color, shallow_color, band * 0.6);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	c = mix(c, shallow_color * 1.2, fres * 0.5);
	float crest = smoothstep(0.93, 0.98, w);
	ALBEDO = mix(c, foam_color, crest * 0.5);
	ROUGHNESS = 0.18;
	SPECULAR = 0.6;
	METALLIC = 0.0;
}
