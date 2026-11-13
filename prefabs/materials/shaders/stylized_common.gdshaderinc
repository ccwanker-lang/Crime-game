// Shared part of the stylized art-style shaders (point 27 comparison). A flat base colour
// (the average of the original texture), the per-building tints as instance uniforms (same
// indices as surface/painted/foliage), optional faint texture detail and a soft darkening
// towards the ground.
uniform vec4 base_color : source_color = vec4(1.0);
uniform bool use_vertex_color = false;
// 0 none, 1 wall_tint, 2 roof_tint, 3 trim_tint, 4 door_tint, 5 foliage_tint
uniform int tint_channel = 0;
uniform sampler2D detail_tex : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float detail = 0.0;
// Atlas textures (one texture with all colours of a model): keep the colour areas, blurred
// and posterized, instead of one average colour.
uniform bool atlas = false;
uniform float detail_lum = 0.5;
uniform vec2 uv_scale = vec2(1.0);
uniform float roughness_v = 1.0;
uniform float metallic_v = 0.0;
uniform float ground_shade = 0.12;
instance uniform vec4 wall_tint : source_color, instance_index(0) = vec4(1.0);
instance uniform vec4 roof_tint : source_color, instance_index(1) = vec4(1.0);
instance uniform vec4 trim_tint : source_color, instance_index(2) = vec4(1.0);
instance uniform vec4 door_tint : source_color, instance_index(3) = vec4(1.0);
instance uniform vec4 foliage_tint : source_color, instance_index(4) = vec4(1.0);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 c = base_color.rgb;
	if (atlas) {
		vec3 t = textureLod(detail_tex, UV, 2.5).rgb;
		c *= floor(t * 6.0 + 0.5) / 6.0;
	}
	if (use_vertex_color) {
		c *= pow(COLOR.rgb, vec3(2.2));
	}
	if (tint_channel == 1) c *= wall_tint.rgb;
	else if (tint_channel == 2) c *= roof_tint.rgb;
	else if (tint_channel == 3) c *= trim_tint.rgb;
	else if (tint_channel == 4) c *= door_tint.rgb;
	else if (tint_channel == 5) c *= foliage_tint.rgb;
	if (detail > 0.0) {
		float l = dot(texture(detail_tex, UV * uv_scale).rgb, vec3(0.299, 0.587, 0.114));
		c *= mix(1.0, clamp(l / max(detail_lum, 0.03), 0.4, 1.8), detail);
	}
	c *= mix(1.0 - ground_shade, 1.0, clamp(world_pos.y / 2.5, 0.0, 1.0));
	ALBEDO = c;
	ROUGHNESS = roughness_v;
	METALLIC = metallic_v;
}
