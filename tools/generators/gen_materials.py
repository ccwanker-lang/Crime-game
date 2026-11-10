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


def surface(name, tex, size, **params):
    d = TX + tex + "/"
    textures = {"albedo_tex": d + "color.jpg", "normal_tex": d + "normal.jpg", "roughness_tex": d + "roughness.jpg"}
    if os.path.exists(os.path.join(ROOT, "assets", "textures", tex, "ao.jpg")):
        textures["ao_tex"] = d + "ao.jpg"
    p = {"uv_scale": (round(1.0 / size, 4), round(1.0 / size, 4))}
    p.update(params)
    shader_material(name, "surface.gdshader", textures, p)


os.makedirs(OUT, exist_ok=True)

# --- Walls (tint_channel 1 = per-building wall tint) ---
surface("brick_old", "Bricks097", 1.2, tint_channel=1, streak_amount=0.25, grime_amount=0.4)
surface("brick_mixed", "Bricks042", 1.2, tint_channel=1, streak_amount=0.2, grime_amount=0.35)
surface("brick_yellow", "Bricks053", 1.2, tint_channel=1, streak_amount=0.25, grime_amount=0.4)
surface("brick_white", "Bricks060", 1.2, tint_channel=1, streak_amount=0.3, grime_amount=0.45)
surface("plaster", "Plaster001", 2.5, tint_channel=1, streak_amount=0.35, grime_amount=0.45, stain_amount=0.3)
surface("bluestone", "Concrete031", 1.0, base_tint=(0.36, 0.38, 0.42, 1.0), grime_amount=0.15, stain_amount=0.2, roughness_mult=0.8)
surface("concrete", "Concrete031", 2.5, grime_amount=0.3, stain_amount=0.25, streak_amount=0.2, tint_channel=1)
surface("curb", "Concrete031", 1.0, base_tint=(0.75, 0.75, 0.73, 1.0), grime_amount=0.0, stain_amount=0.25)

# --- Roofs (tint_channel 2) ---
surface("roof_dark", "RoofingTiles013A", 1.6, tint_channel=2, grime_amount=0.0, stain_amount=0.2, moss_amount=0.35)
surface("roof_red", "RoofingTiles014A", 1.6, tint_channel=2, grime_amount=0.0, stain_amount=0.25, moss_amount=0.4)

# --- Ground surfaces ---
surface("asphalt", "Asphalt025C", 4.0, grime_amount=0.0, stain_amount=0.35, stain_scale=0.15, grime_color=(0.55, 0.55, 0.55, 1.0))
surface("sidewalk", "PavingStones128", 2.4, base_tint=(0.62, 0.62, 0.6, 1.0), grime_amount=0.0, stain_amount=0.3, stain_scale=0.25)
surface("cobbles", "PavingStones070", 1.6, base_tint=(0.56, 0.55, 0.54, 1.0), grime_amount=0.0, stain_amount=0.3, stain_scale=0.3)
surface("soil", "Ground048", 1.5, grime_amount=0.0, stain_amount=0.0)

# --- Interior ---
surface("wood_floor", "WoodFloor041", 2.0, grime_amount=0.0, stain_amount=0.15)
surface("floor_tiles", "Tiles107", 1.5, grime_amount=0.0, stain_amount=0.15, roughness_mult=0.7)
surface("interior_plaster", "Plaster001", 2.5, grime_amount=0.15, stain_amount=0.1, base_tint=(0.93, 0.9, 0.84, 1.0), tint_channel=0)
surface("planks", "Planks023A", 1.5, grime_amount=0.2, stain_amount=0.2)
surface("corrugated", "CorrugatedSteel005", 2.0, tint_channel=1, metallic=0.4, grime_amount=0.4, streak_amount=0.4, stain_amount=0.3)

# --- Painted (no textures) ---
shader_material("trim_paint", "painted.gdshader", {}, {"base_color": (0.92, 0.92, 0.9, 1.0), "roughness": 0.45, "tint_channel": 3, "wear": 0.12})
shader_material("door_paint", "painted.gdshader", {}, {"base_color": (1.0, 1.0, 1.0, 1.0), "roughness": 0.4, "tint_channel": 4, "wear": 0.18})
shader_material("metal_dark", "painted.gdshader", {}, {"base_color": (0.16, 0.17, 0.18, 1.0), "roughness": 0.45, "metallic": 0.6, "wear": 0.2})
shader_material("zinc", "painted.gdshader", {}, {"base_color": (0.55, 0.57, 0.58, 1.0), "roughness": 0.4, "metallic": 0.7, "wear": 0.25})
shader_material("road_marking", "painted.gdshader", {}, {"base_color": (0.88, 0.88, 0.85, 1.0), "roughness": 0.7, "wear": 0.35})
standard_material("awning", {"vertex_color_use_as_albedo": True, "cull_mode": 2, "roughness": 0.9})
shader_material("hedge_core", "painted.gdshader", {}, {"base_color": (0.1, 0.17, 0.07, 1.0), "roughness": 0.95, "wear": 0.3})

# --- Glass ---
shader_material("glass_interior", "window_interior.gdshader", {}, {})
shader_material("glass_shop", "window_interior.gdshader", {}, {"room_brightness": 0.9, "lit_brightness": 0.8, "reflection": 0.35,
                                                              "floor_color": (0.6, 0.6, 0.58, 1.0), "ceiling_color": (0.95, 0.95, 0.95, 1.0)})
standard_material("glass_clear", {
    "transparency": 1, "cull_mode": 2, "albedo_color": (0.55, 0.65, 0.7, 0.18),
    "metallic": 0.3, "roughness": 0.04, "metallic_specular": 0.9,
})
standard_material("lamp_glow", {
    "albedo_color": (1.0, 0.92, 0.75, 1.0), "emission_enabled": True,
    "emission": (1.0, 0.85, 0.6, 1.0), "emission_energy_multiplier": 1.6,
})

# --- Nature ---
shader_material("ground", "ground.gdshader", {
    "grass_albedo": TX + "Grass004/color.jpg", "grass_normal": TX + "Grass004/normal.jpg",
    "dirt_albedo": TX + "Ground037/color.jpg", "dirt_normal": TX + "Ground037/normal.jpg",
}, {"dirt_amount": 0.3})
shader_material("grass_blades", "grass_blades.gdshader", {}, {})
shader_material("leaves", "foliage.gdshader", {"leaf_tex": TX + "foliage/leaves_cluster.png"}, {})
standard_material("bark", {"uv1_scale": "Vector3(1, 2, 1)", "normal_enabled": True},
                  rtype="ORMMaterial3D",
                  textures={"albedo_texture": TX + "bark/color.jpg", "normal_texture": TX + "bark/normal.jpg",
                            "orm_texture": TX + "bark/arm.jpg"})
