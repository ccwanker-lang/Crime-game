// Art style A: flat colours, soft wrapped light, no specular highlights.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert_wrap, specular_disabled;
#include "res://prefabs/materials/shaders/stylized_common.gdshaderinc"
