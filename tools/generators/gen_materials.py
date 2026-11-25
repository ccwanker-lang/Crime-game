# Generates material .tres files in res://prefabs/materials/.
# Usage: python gen_materials.py <project root>
import os, sys

ROOT = sys.argv[1]
OUT = os.path.join(ROOT, "prefabs", "materials")
SH = "res://prefabs/materials/shaders/"
TX = "res://assets/textures/"


def fmt(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(float(v)) if isinstance(v, float) else str(v)
    if isinstance(v, tuple) and len(v) == 2:
        return "Vector2(%s, %s)" % (v[0], v[1])
    if isinstance(v, tuple) and len(v) == 4:
        return "Color(%s, %s, %s, %s)" % v
    return v


def shader_material(name, shader, textures, params):
    lines = ["[gd_resource type=\"ShaderMaterial\" format=3]", ""]
    lines.append('[ext_resource type="Shader" path="%s%s" id="1_sh"]' % (SH, shader))
    tex_ids = {}
    for i, (param, path) in enumerate(textures.items()):
        tid = "%d_tx" % (i + 2)
        tex_ids[param] = tid
        lines.append('[ext_resource type="Texture2D" path="%s" id="%s"]' % (path, tid))
    lines += ["", "[resource]", 'shader = ExtResource("1_sh")']
    for param, tid in tex_ids.items():
        lines.append('shader_parameter/%s = ExtResource("%s")' % (param, tid))
    for k, v in params.items():
        lines.append("shader_parameter/%s = %s" % (k, fmt(v)))
    write(name, lines)


def standard_material(name, props, rtype="StandardMaterial3D", textures=None):
    lines = ['[gd_resource type="%s" format=3]' % rtype, ""]
    textures = textures or {}
    for i, (prop, path) in enumerate(textures.items()):
        lines.append('[ext_resource type="Texture2D" path="%s" id="%d_tx"]' % (path, i + 1))
    lines += ["", "[resource]"]
    for i, prop in enumerate(textures):
        lines.append('%s = ExtResource("%d_tx")' % (prop, i + 1))
    for k, v in props.items():
        lines.append("%s = %s" % (k, fmt(v)))
    write(name, lines)


def write(name, lines):
    path = os.path.join(OUT, name + ".tres")
    with open(path, "w", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    print("wrote", name)


os.makedirs(OUT, exist_ok=True)

# =====================================================================================
# Point 27 art direction (DESIGN.md): stylized low-poly. Every material is a flat colour from
# the one palette (gen_palette.py), optionally with a simple procedural pattern
# (stylized.gdshader); objects use StandardMaterial3D with the same lambert-wrap light.
# (The photo/PBR materials of before point 27 are in git history.)
# =====================================================================================
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_palette import SWATCHES  # noqa: E402

PAL = {n: i for i, (n, _) in enumerate(SWATCHES)}
PCOL = {n: c for n, c in SWATCHES}
PALETTE_TEX = {"palette": "res://assets/palette/palette.png"}


def styl(name, swatch, pattern=0, **params):
    p = {"swatch": PAL[swatch]} if swatch else {}
    if "swatch2" in params:
        params["swatch2"] = PAL[params["swatch2"]]
    p["pattern"] = pattern
    p.update(params)
    shader_material(name, "stylized.gdshader", PALETTE_TEX, p)


def flat(name, swatch, roughness=0.8, metallic=0.0, vertex=False, extra=None, color=None):
    # Objects keep StandardMaterial3D (cars duplicate car_paint, the viewmodel copies its
    # inputs) but with the same light model as the world: lambert wrap, matte.
    c = color or (PCOL[swatch] if swatch else (1.0, 1.0, 1.0))
    props = {"albedo_color": (c[0], c[1], c[2], 1.0), "roughness": roughness, "metallic": metallic,
             "diffuse_mode": 2, "metallic_specular": 0.3}
    if vertex:
        props.update({"vertex_color_use_as_albedo": True, "vertex_color_is_srgb": True})
        props["albedo_color"] = (1.0, 1.0, 1.0, 1.0)
    props.update(extra or {})
    standard_material(name, props)


# Walls (tint_channel 1): one base colour, faint joints, a few odd bricks. Bricks are drawn
# larger than real ones so they read as a pattern, not as noise.
for n, sw in [("brick_old", "brick_brown"), ("brick_mixed", "brick_red"), ("brick_yellow", "brick_yellow"),
              ("brick_white", "brick_white")]:
    styl(n, sw, 1, cell=(0.42, 0.14), line_width=0.018, line_amount=0.35, odd_share=0.1, odd_amount=0.07,
         swatch2="brick_white", tint_channel=1, ground_shade=0.1)
styl("plaster", "plaster_cream", 0, tint_channel=1, ground_shade=0.1)
styl("bluestone", "roof_slate", 3, cell=(0.6, 0.3), line_width=0.01, line_amount=0.4, odd_amount=0.05)
# Point 103: wet_receiver = how much rain wets the surface (Weather -> global shader parameter "wetness").
styl("concrete", "concrete", 3, cell=(1.5, 1.5), line_width=0.012, line_amount=0.25, odd_amount=0.04, tint_channel=1,
     wet_receiver=0.6)
styl("curb", "curb", 3, cell=(1.0, 4.0), line_width=0.015, line_amount=0.5, odd_amount=0.04, wet_receiver=0.8)
# Roofs (tint_channel 2): rows of tiles.
for n, sw in [("roof_dark", "roof_dark"), ("roof_red", "roof_red")]:
    styl(n, sw, 2, cell=(0.3, 0.32), line_width=0.02, line_amount=0.5, odd_share=0.06, odd_amount=0.08, tint_channel=2,
         wet_receiver=0.5)
# Ground: flat asphalt, paving with clear joints.
styl("asphalt", "asphalt", 7, swatch2="asphalt_light", odd_amount=0.04, patch_scale=0.05, roughness_v=0.95, specular_v=0.2,
     wet_receiver=1.0)
styl("sidewalk", "pavement", 3, cell=(0.6, 0.6), line_width=0.02, line_amount=0.6, odd_share=0.08, odd_amount=0.06,
     swatch2="pavement_dark", wet_receiver=0.85)
styl("cobbles", "pavement_dark", 5, cell=(0.22, 0.16), line_width=0.02, line_amount=0.5, odd_share=0.12, odd_amount=0.07,
     swatch2="concrete", wet_receiver=0.9)
styl("soil", "soil", 7, swatch2="wood_dark", odd_amount=0.05, patch_scale=0.5)
# Interior.
styl("wood_floor", "wood", 4, cell=(0.16, 1.0), line_width=0.008, line_amount=0.5, odd_amount=0.08, swatch2="wood_dark")
styl("floor_tiles", "brick_white", 3, cell=(0.4, 0.4), line_width=0.01, line_amount=0.4, odd_amount=0.04, swatch2="concrete")
styl("interior_plaster", "plaster_cream", 0)
styl("planks", "wood", 4, cell=(0.18, 2.0), line_width=0.012, line_amount=0.6, odd_share=0.2, odd_amount=0.1, swatch2="wood_dark")
styl("corrugated", "metal", 6, cell=(0.08, 1.0), odd_amount=0.0, tint_channel=1, roughness_v=0.6)
# Painted parts.
styl("trim_paint", "trim_white", 0, tint_channel=3, roughness_v=0.6)
styl("door_paint", None, 0, tint_channel=4, roughness_v=0.55)
styl("metal_dark", "metal_dark", 0, roughness_v=0.55, specular_v=0.45)
styl("zinc", "metal", 0, roughness_v=0.5, specular_v=0.45)
styl("road_marking", "road_line", 0)
styl("hedge_core", "leaf_dark", 0)
standard_material("awning", {"vertex_color_use_as_albedo": True, "vertex_color_is_srgb": True, "cull_mode": 2,
                             "roughness": 0.9, "diffuse_mode": 2})
# Glass.
shader_material("glass_interior", "stylized_window.gdshader", PALETTE_TEX, {})
shader_material("glass_shop", "stylized_window.gdshader", PALETTE_TEX, {"day_glow": 0.25, "night_lit_share": 1.0, "sheen": 0.25})
standard_material("glass_clear", {"transparency": 1, "cull_mode": 2, "albedo_color": (0.62, 0.74, 0.82, 0.25),
                                  "roughness": 0.15, "diffuse_mode": 2})
standard_material("lamp_glow", {"albedo_color": (1.0, 0.92, 0.75, 1.0), "emission_enabled": True,
                                "emission": (1.0, 0.82, 0.55, 1.0), "emission_energy_multiplier": 1.8})
# Nature: soft colour fields; stylized trees, tufts and shrubs get palette vertex colours.
styl("ground", "grass", 7, swatch2="grass_light", odd_amount=0.09, patch_scale=0.06, roughness_v=0.95, specular_v=0.15)
flat("grass_blades", None, 0.95, vertex=True, extra={"cull_mode": 2})
flat("leaves", None, 0.9, vertex=True, extra={"cull_mode": 2})
# Weed plants keep their leaf cards (growing is approved as it is): alpha-tested atlas.
shader_material("weed_leaves", "foliage.gdshader", {"leaf_tex": TX + "foliage/weed_atlas.png"}, {"wind_strength": 0.006, "wind_speed": 0.6})
flat("bark", "bark", 0.95)
# Stations.
styl("soil_wet", "soil", 0, base_color=(0.7, 0.66, 0.62, 1.0))
styl("soil_dry", "soil", 0, base_color=(1.0, 0.97, 0.92, 1.0))
flat("pot_plastic", "metal_dark", 0.6)
flat("lamp_housing", "metal", 0.4)
standard_material("grow_light_glow", {"albedo_color": (1.0, 0.85, 0.95, 1.0), "emission_enabled": True,
                                      "emission": (1.0, 0.72, 0.9, 1.0), "emission_energy_multiplier": 3.0})
flat("weed_stem", None, 0.8, color=(0.42, 0.55, 0.25))
flat("string", None, 0.9, color=(0.8, 0.74, 0.62))
# Firearms: flat colours, a little sheen on metal.
flat("gun_metal", None, 0.45, 0.25, color=(0.33, 0.35, 0.39))
flat("gun_polymer", None, 0.8, color=(0.15, 0.15, 0.17))
flat("gun_wood", "wood", 0.7)
# Cars.
flat("car_paint", None, 0.45, color=(0.8, 0.8, 0.8))
flat("car_glass", None, 0.15, color=(0.16, 0.2, 0.26))
flat("car_tire", None, 0.9, color=(0.09, 0.09, 0.1))
flat("car_trim", None, 0.7, color=(0.13, 0.13, 0.15))
flat("car_chrome", "metal", 0.35, 0.3)
standard_material("car_headlight", {"albedo_color": (1.0, 0.98, 0.9, 1.0), "emission_enabled": True,
                                    "emission": (1.0, 0.95, 0.85, 1.0), "emission_energy_multiplier": 2.5})
standard_material("car_taillight", {"albedo_color": (0.75, 0.1, 0.08, 1.0), "emission_enabled": True,
                                    "emission": (1.0, 0.1, 0.06, 1.0), "emission_energy_multiplier": 1.5})
# Items (vertex colours).
flat("item_matte", None, 0.85, vertex=True, extra={"cull_mode": 2})
flat("item_glossy", None, 0.4, vertex=True)
flat("item_metal", None, 0.4, 0.3, vertex=True)
standard_material("item_clear", {"vertex_color_use_as_albedo": True, "vertex_color_is_srgb": True, "transparency": 1,
                                 "roughness": 0.15, "cull_mode": 2, "diffuse_mode": 2})
