// First-person viewmodel (arms + weapon). Same PBR inputs as a StandardMaterial3D
// (see Viewmodel.convert_material), but the vertex is pulled towards the camera
// in clip space: the image stays identical, only the depth shrinks, so the
// weapon is always drawn in front of walls it would otherwise poke into.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, hint_default_white;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic;
uniform bool use_normal = false;
uniform float normal_strength = 1.0;
// glTF metal/rough texture: G = roughness, B = metallic (R = AO when use_ao).
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap_anisotropic;
uniform bool use_orm = false;
uniform bool use_ao = false;
uniform float roughness = 0.8;
uniform float metallic = 0.0;
// 1 = normal depth; smaller = closer to the camera (never behind world geometry).
// 0.4: the gun (< 0.6 m away) lands within 0.25 m, closer than any wall can be
// (the player capsule keeps walls 0.35 m away); parts nearer than 0.125 m get
// clipped by the camera's near plane (0.05 m), but those are outside the view.
uniform float depth_scale = 0.4;

void vertex() {
	vec4 view_pos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	view_pos.xyz *= depth_scale;  // same direction from the eye = same pixel
	POSITION = PROJECTION_MATRIX * view_pos;
}

void fragment() {
	vec4 c = texture(albedo_tex, UV) * albedo;
	ALBEDO = c.rgb;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	if (use_orm) {
		vec3 orm = texture(orm_tex, UV).rgb;
		ROUGHNESS = roughness * orm.g;
		METALLIC = metallic * orm.b;
		if (use_ao) {
			AO = orm.r;
		}
	}
	if (use_normal) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
		NORMAL_MAP_DEPTH = normal_strength;
	}
}
