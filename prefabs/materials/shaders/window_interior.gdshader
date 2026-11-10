// Fake interior behind window glass ("interior mapping").
// The glass quad needs UV 0..1 across the opening and tangents (U = right, V = up).
// Vertex COLOR per window: rgb = wall colour of the fake room, a = how bright the room light is.
// Rooms get random curtains/blinds from a hash of the window position.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform float room_depth = 1.6;          // relative to half window width
uniform vec4 floor_color : source_color = vec4(0.32, 0.22, 0.14, 1.0);
uniform vec4 ceiling_color : source_color = vec4(0.85, 0.83, 0.78, 1.0);
uniform float room_brightness = 0.35;
uniform float lit_brightness = 1.4;
uniform vec4 glass_tint : source_color = vec4(0.55, 0.62, 0.68, 1.0);
uniform float reflection = 0.55;         // how much the glass darkens/reflects

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
	// Ray into the room in tangent space (x = right, y = up, z = into the wall).
	vec3 dir = -VIEW;
	vec3 rd = normalize(vec3(dot(dir, TANGENT), dot(dir, BINORMAL), dot(dir, -NORMAL)));
	vec3 ro = vec3(UV.x * 2.0 - 1.0, UV.y * 2.0 - 1.0, 0.0);
	rd.z = max(rd.z, 0.001);

	float tx = ((rd.x > 0.0 ? 1.0 : -1.0) - ro.x) / (abs(rd.x) < 1e-4 ? 1e-4 : rd.x);
	float ty = ((rd.y > 0.0 ? 1.0 : -1.0) - ro.y) / (abs(rd.y) < 1e-4 ? 1e-4 : rd.y);
	float tz = (room_depth - ro.z) / rd.z;
	float t = min(min(tx, ty), tz);
	vec3 hit = ro + rd * t;

	vec3 wall = COLOR.rgb;
	vec3 room;
	float shade;
	if (t == tz) {
		room = wall * 0.9;                       // back wall
		// simple furniture silhouette / picture on the back wall
		float h = hash(floor(obj_pos.xz * 0.5) + floor(obj_pos.y));
		if (h > 0.5 && hit.y < -0.35 && abs(hit.x) < 0.6) room = mix(room, vec3(0.25, 0.2, 0.17), 0.8);
		if (h < 0.3 && hit.y > 0.0 && hit.y < 0.5 && abs(hit.x - 0.2) < 0.25) room = vec3(0.35, 0.4, 0.45);
		shade = 0.75;
	} else if (t == tx) {
		room = wall;                              // side walls
		shade = 0.6;
	} else if (rd.y < 0.0) {
		room = floor_color.rgb;                   // floor
		shade = 0.5;
	} else {
		room = ceiling_color.rgb;                 // ceiling
		shade = 0.9;
	}
	// Depth fade (rooms get darker further in).
	shade *= mix(1.0, 0.55, clamp(hit.z / room_depth, 0.0, 1.0));

	// Curtains / blinds, chosen per window from its position.
	float wh = hash(floor(obj_pos.xz * 1.3) + floor(obj_pos.y * 0.7) * 7.0);
	vec2 uv = UV;
	vec3 curtain_col = mix(vec3(0.75, 0.7, 0.6), vec3(0.45, 0.2, 0.18), step(0.5, fract(wh * 7.3)));
	bool covered = false;
	if (wh > 0.55) {
		float w = 0.18 + 0.12 * fract(wh * 13.1);
		if (uv.x < w || uv.x > 1.0 - w) covered = true;  // side curtains
	}
	if (wh < 0.2) {
		if (uv.y > 1.0 - (0.3 + 0.5 * fract(wh * 17.7))) covered = true;  // blind pulled down
	}

	float light = room_brightness + COLOR.a * lit_brightness;
	vec3 inside = room * shade * light;
	if (covered) {
		inside = curtain_col * (0.35 + COLOR.a * 0.9) * (0.85 + 0.15 * sin(uv.x * 60.0));
	}

	// Glass: darkened interior plus reflections from the sky/environment.
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = glass_tint.rgb * 0.05;
	EMISSION = inside * (1.0 - reflection * 0.6) * (1.0 - fres * 0.7);
	METALLIC = 0.2;
	ROUGHNESS = 0.06;
	SPECULAR = 0.5 + reflection * 0.5;
}
