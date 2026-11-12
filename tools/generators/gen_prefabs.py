"""Generates the reusable prefab scenes in res://prefabs/ (nature, props, interiors, buildings).
Usage: python gen_prefabs.py <project root>"""
import sys
from tscn import Scene, v3, col, xform, strarr

ROOT = sys.argv[1].rstrip("/\\") + "/"
PH = "res://assets/polyhaven/%s/%s.gltf"
S = {
    "model_part": "res://scripts/procgen/model_part.gd",
    "tree": "res://scripts/procgen/proc_tree.gd",
    "hedge": "res://scripts/procgen/hedge.gd",
    "grass": "res://scripts/procgen/grass_field.gd",
    "flower_bed": "res://scripts/procgen/flower_bed.gd",
    "street_prop": "res://scripts/procgen/street_prop.gd",
    "container": "res://scripts/procgen/shipping_container.gd",
    "fence": "res://scripts/procgen/garden_fence.gd",
    "proc_box": "res://scripts/procgen/proc_box.gd",
    "building": "res://scripts/procgen/building.gd",
    "property": "res://scenes/world/property.gd",
    "proc_item": "res://scripts/procgen/proc_item.gd",
}


def save(scene, rel):
    scene.save(ROOT + rel)
    print("wrote", rel)


def box_shape(sc, size):
    return sc.subres("BoxShape3D", {"size": v3(*size)})


def cyl_shape(sc, r, h):
    return sc.subres("CylinderShape3D", {"radius": f"{r:g}", "height": f"{h:g}"})


def model_prefab(rel, model, parts=None, collision=None, scale=1.0, vis_end=0.0, shadows=True,
                 extra=None, root_type="StaticBody3D", layer2=False):
    """StaticBody3D root + ModelPart + optional collision.
    collision: ("box", (sx,sy,sz), (cx,cy,cz)) or ("cyl", r, h)"""
    sc = Scene()
    name = rel.split("/")[-1].replace(".tscn", "").title().replace("_", "")
    sc.node(name, root_type if collision else "Node3D")
    props = {"script": sc.script(S["model_part"]), "model": sc.scene(PH % (model, model))}
    if parts:
        props["parts"] = strarr(parts)
    if vis_end:
        props["visibility_end"] = f"{vis_end:g}"
    if not shadows:
        props["cast_shadows"] = "false"
    if scale != 1.0:
        props["transform"] = xform(scale=scale)
    sc.node("Model", "Node3D", ".", props=props)
    if collision:
        if collision[0] == "box":
            size, center = collision[1], collision[2]
            sc.node("Collision", "CollisionShape3D", ".",
                    props={"transform": xform(center), "shape": box_shape(sc, size)})
        else:
            r, h = collision[1], collision[2]
            sc.node("Collision", "CollisionShape3D", ".",
                    props={"transform": xform((0, h / 2, 0)), "shape": cyl_shape(sc, r, h)})
    if extra:
        extra(sc)
    save(sc, rel)


def script_prefab(rel, ntype, script, props=None):
    sc = Scene()
    name = rel.split("/")[-1].replace(".tscn", "").title().replace("_", "")
    p = {"script": sc.script(S[script])}
    p.update(props or {})
    sc.node(name, ntype, props=p)
    save(sc, rel)


# --------------------------------------------------------------------------- nature
N = "prefabs/nature/"
script_prefab(N + "tree_large.tscn", "StaticBody3D", "tree",
              {"tree_seed": "7", "height": "10.5", "crown_radius": "3.6", "trunk_radius": "0.24", "leaf_cards": "300"})
script_prefab(N + "tree_medium.tscn", "StaticBody3D", "tree",
              {"tree_seed": "1", "height": "8.0", "crown_radius": "2.8", "trunk_radius": "0.18", "leaf_cards": "240"})
script_prefab(N + "tree_street.tscn", "StaticBody3D", "tree",
              {"tree_seed": "3", "height": "6.5", "crown_radius": "2.0", "trunk_radius": "0.13", "leaf_cards": "170",
               "leaf_tint": col(1.05, 1.08, 0.9)})
for i, part in enumerate(["shrub_02_a", "shrub_02_b", "shrub_02_c", "shrub_02_d"]):
    model_prefab(N + f"shrub_{'abcd'[i]}.tscn", "shrub_02", [part], ("cyl", 0.55, 1.4), scale=0.75,
                 vis_end=70, shadows=True)
model_prefab(N + "fern.tscn", "fern_02", ["fern_02_b"], vis_end=35, shadows=False)
script_prefab(N + "hedge.tscn", "StaticBody3D", "hedge")
script_prefab(N + "flower_bed.tscn", "Node3D", "flower_bed")
script_prefab(N + "grass_field.tscn", "MultiMeshInstance3D", "grass")

# --------------------------------------------------------------------------- props
P = "prefabs/props/"


def lamp_light(sc):
    sc.node("Light", "OmniLight3D", ".", groups=["street_lights"],
            props={"transform": xform((0.0, 4.55, 0.0)), "visible": "false", "light_energy": "1.8",
                   "light_color": col(1, 0.8, 0.55), "omni_range": "12.0", "omni_attenuation": "1.4",
                   "shadow_enabled": "false", "distance_fade_enabled": "true", "distance_fade_begin": "70.0",
                   "distance_fade_length": "20.0"})


model_prefab(P + "street_lamp.tscn", "street_lamp_01", None, ("cyl", 0.12, 4.8), scale=1.25, extra=lamp_light)
def bench_seats(sc):
    # Sit spots for pedestrians (they sit facing +Z, the front of the bench).
    for i, x in enumerate((-0.55, 0.55)):
        sc.node(f"Seat{i + 1}", "Marker3D", ".", groups=["bench_seat"], props={"transform": xform((x, 0, 0.0))})


model_prefab(P + "bench.tscn", "modular_street_seating",
             ["seat", "seat_back", "crossbar", "legs_single", "legs_double", "back_support_r", "back_support_l",
              "suspended_support_01", "arm_rest_01", "arm_rest_02"],
             ("box", (2.3, 0.85, 0.7), (0, 0.425, 0)), vis_end=80, extra=bench_seats)
model_prefab(P + "trash_can.tscn", "metal_trash_can",
             ["metal_trash_can", "metal_trash_can_handle_left", "metal_trash_can_handle_right"],
             ("cyl", 0.3, 0.9), vis_end=70)
model_prefab(P + "trash_can_rusty.tscn", "metal_trash_can",
             ["metal_trash_can_rust", "metal_trash_can_rust_handle_left", "metal_trash_can_rust_handle_right"],
             ("cyl", 0.3, 0.9), vis_end=70)
model_prefab(P + "trashbag.tscn", "trashbag", None, vis_end=50, shadows=False)
model_prefab(P + "utility_box.tscn", "utility_box_01", None, ("box", (0.52, 1.12, 0.43), (0, 0.56, 0)), vis_end=80)
model_prefab(P + "planter_box.tscn", "planter_box_01", None, ("box", (0.91, 0.42, 0.41), (0, 0.21, 0)), vis_end=60)
model_prefab(P + "crate_long.tscn", "wooden_crate_02", None, ("box", (0.53, 0.46, 1.17), (0, 0.23, 0)), vis_end=80)
model_prefab(P + "crate_flat.tscn", "wooden_crate_01", None, ("box", (0.83, 0.35, 0.41), (0, 0.175, 0)), vis_end=60)
model_prefab(P + "barrel.tscn", "barrel_03", None, ("cyl", 0.32, 0.93), vis_end=80)
model_prefab(P + "road_barrier.tscn", "concrete_road_barrier", None, ("box", (1.55, 0.83, 0.64), (0, 0.415, 0)))
model_prefab(P + "covered_car.tscn", "covered_car", None, ("box", (1.79, 1.4, 4.38), (0, 0.7, 0)))
model_prefab(P + "aircon.tscn", "exterior_aircon_unit", ["exterior_aircon_unit"], vis_end=70)


# Flood light on its own steel pole (StreetProp LIGHT_POLE): lamps never float.
def floodlight_pole():
    sc = Scene()
    sc.node("FloodlightPole", "StaticBody3D", props={"script": sc.script(S["street_prop"]), "kind": "6"})
    sc.node("Model", "Node3D", ".", props={
        "transform": xform((0, 4.95, 0.42)), "script": sc.script(S["model_part"]),
        "model": sc.scene(PH % ("security_light", "security_light")), "recenter": "false",
        "visibility_end": "90"})
    sc.node("Light", "SpotLight3D", ".", groups=["street_lights"],
            props={"transform": "Transform3D(1, 0, 0, 0, 0.5, 0.866, 0, -0.866, 0.5, 0, 4.75, 0.62)",
                   "visible": "false", "light_energy": "3.0", "spot_range": "16.0", "spot_angle": "50.0"})
    save(sc, P + "floodlight_pole.tscn")


floodlight_pole()


def fence_extra(sc):
    sc.node("Panel", "Node3D", ".", props={
        "transform": xform((1.0, 0, 0)), "script": sc.script(S["model_part"]),
        "model": sc.scene(PH % ("modular_chainlink_fence", "modular_chainlink_fence")),
        "parts": strarr(["modular_chainlink_fence_double"]), "visibility_end": "90"})


# Chainlink segment: 2 m along +X, post at the origin.
model_prefab(P + "chainlink_fence.tscn", "modular_chainlink_fence", ["modular_chainlink_fence_post"],
             ("box", (2.0, 2.5, 0.1), (1.0, 1.25, 0)), vis_end=90, extra=fence_extra)
# Gate frame: 2 m opening frame along +X (no gate leaf, so the yard stays open).
model_prefab(P + "chainlink_gate_frame.tscn", "modular_chainlink_fence", ["modular_chainlink_fence_door_frame"],
             None, vis_end=90)

for kind, name in [(0, "bollard"), (1, "post_box"), (2, "bike_rack"), (3, "sign_post"), (4, "manhole")]:
    script_prefab(P + f"{name}.tscn", "StaticBody3D", "street_prop", {"kind": str(kind)})
script_prefab(P + "container_6m.tscn", "StaticBody3D", "container", {"length_type": '"6m"'})
script_prefab(P + "container_12m.tscn", "StaticBody3D", "container", {"length_type": '"12m"'})
script_prefab(P + "garden_fence.tscn", "StaticBody3D", "fence")
script_prefab(P + "picket_fence.tscn", "StaticBody3D", "fence",
              {"style": '"picket"', "height": "0.9", "tint": col(0.95, 0.95, 0.93)})

# --------------------------------------------------------------------------- interiors
I = "prefabs/interiors/"


def furn(name, model, size, center_y=None, parts=None, scale=1.0, center=None):
    cy = size[1] / 2 if center_y is None else center_y
    model_prefab(I + name + ".tscn", model, parts, ("box", size, center or (0, cy, 0)), scale=scale, vis_end=40)


furn("sofa", "Sofa_01", (1.57, 0.8, 0.66))
furn("armchair", "ArmChair_01", (0.85, 1.0, 0.77))
furn("coffee_table", "WoodenTable_01", (1.8, 0.55, 0.66))
furn("bookshelf", "wooden_bookshelf_worn", (1.37, 2.06, 0.58))
furn("television", "Television_01", (0.6, 0.46, 0.47))
furn("cardboard_box", "cardboard_box_01", (0.39, 0.34, 0.52))
furn("steel_shelves", "steel_frame_shelves_01", (1.1, 2.14, 0.5), scale=0.1)
furn("cash_register", "CashRegister_01", (0.6, 0.62, 0.44))
furn("bed", "old_bed_frame", (0.9, 1.2, 2.0), center_y=0.3)
furn("wheelchair", "wheelchair_01", (0.82, 1.1, 1.09))
furn("office_desk", "metal_office_desk", (2.0, 0.79, 0.95))
# Extra home/business furniture (Poly Haven CC0, fetched with tools/fetch_polyhaven.py). Front = +Z.
furn("dining_table", "dining_table", (2.2, 0.88, 1.35), center=(0, 0.44, 0.02))
furn("dining_chair", "dining_chair_02", (0.43, 0.97, 0.5), center=(0, 0.49, -0.04))
furn("nightstand", "ClassicNightstand_01", (0.57, 0.7, 0.42))
furn("drawer_cabinet", "drawer_cabinet", (1.14, 1.88, 0.49))
furn("low_cabinet", "modern_wooden_cabinet", (2.44, 0.68, 0.52), parts=["modern_wooden_cabinet_body",
     "modern_wooden_cabinet_door_l", "modern_wooden_cabinet_door_r"])
furn("sofa_modern", "sofa_02", (1.81, 0.71, 0.8), center=(0, 0.35, -0.07))
furn("round_coffee_table", "coffee_table_round_01", (1.25, 0.49, 1.25))
furn("side_table", "side_table_01", (0.55, 0.55, 0.45))
furn("wardrobe", "vintage_cabinet_01", (2.0, 2.24, 0.62), center=(0, 1.12, 0.06))
furn("wall_shelf", "Shelf_01", (1.0, 2.08, 0.26), center=(0, 1.04, 0.13))
furn("rocking_chair", "Rockingchair_01", (0.7, 0.99, 0.8), center=(0, 0.5, 0.06))
furn("barber_chair", "BarberShopChair_01", (0.76, 1.49, 1.2), center=(-0.02, 0.74, 0.22))
furn("tool_cart", "tool_cart", (1.25, 0.96, 0.75))
furn("metal_rack", "worn_metal_rack", (0.92, 1.9, 0.6))
furn("stool", "metal_stool_01", (0.35, 0.88, 0.35))
furn("plastic_chair", "plastic_monobloc_chair_01", (0.62, 0.88, 0.6))
furn("picnic_table", "wooden_picnic_table", (2.2, 0.75, 3.0))
furn("painted_bench", "painted_wooden_bench", (1.16, 0.89, 0.5))
model_prefab(I + "potted_plant.tscn", "potted_plant_01", None, ("cyl", 0.25, 0.55), vis_end=30)


def hanging_light(sc):
    sc.node("Light", "OmniLight3D", ".", props={
        "transform": xform((0, -1.5, 0)), "light_color": col(1, 0.85, 0.65), "light_energy": "1.6",
        "omni_range": "9.0", "shadow_enabled": "true"})


model_prefab(I + "hanging_lamp.tscn", "hanging_industrial_lamp", None, extra=hanging_light)

# Ceiling lamp: small glowing dome + light (origin at the ceiling).
sc = Scene()
sc.node("CeilingLamp", "Node3D")
dome = sc.subres("SphereMesh", {"radius": "0.22", "height": "0.2", "is_hemisphere": "true",
                                "material": sc.res("Material", "res://prefabs/materials/lamp_glow.tres")})
sc.node("Dome", "MeshInstance3D", ".", props={"transform": "Transform3D(1, 0, 0, 0, -1, 0, 0, 0, -1, 0, 0, 0)",
                                               "mesh": dome, "cast_shadow": "0"})
sc.node("Light", "OmniLight3D", ".", props={"transform": xform((0, -0.35, 0)), "light_color": col(1, 0.9, 0.75),
                                            "light_energy": "1.4", "omni_range": "8.0", "shadow_enabled": "true"})
save(sc, I + "ceiling_lamp.tscn")

# --------------------------------------------------------------------------- buildings
B = "prefabs/buildings/"
ST = "prefabs/stations/"


def building(rel, props, extra=None):
    sc = Scene()
    name = rel.split("/")[-1].replace(".tscn", "").title().replace("_", "")
    p = {"script": sc.script(S["building"])}
    p.update(props)
    sc.node(name, "StaticBody3D", props=p)
    if extra:
        extra(sc)
    save(sc, rel)


def q(s):
    return f'"{s}"'


HOUSES = {
    "row_house_a": {"width": "6.0", "depth": "9.0", "floors": "2", "wall_material": q("brick_old"),
                    "roof_material": q("roof_dark"), "door_bay": "0", "bay_window_bay": "1", "chimney": q("left"),
                    "door_color": col(0.12, 0.22, 0.18), "variation_seed": "11"},
    "row_house_b": {"width": "5.2", "depth": "9.5", "floors": "3", "floor_height": "2.9", "wall_material": q("plaster"),
                    "wall_tint": col(0.93, 0.89, 0.8), "roof_material": q("roof_dark"), "door_bay": "1",
                    "balcony_bay": "0", "dormer": "true", "chimney": q("right"),
                    "door_color": col(0.45, 0.1, 0.1), "variation_seed": "22"},
    "row_house_c": {"width": "7.2", "depth": "10.0", "floors": "2", "floor_height": "3.2",
                    "wall_material": q("brick_mixed"), "roof_material": q("roof_red"), "roof_pitch": "38.0",
                    "door_bay": "0", "bay_window_bay": "2", "dormer": "true", "chimney": q("left"),
                    "door_color": col(0.1, 0.12, 0.2), "variation_seed": "33"},
    "row_house_d": {"width": "5.6", "depth": "9.0", "floors": "2", "wall_material": q("brick_yellow"),
                    "roof_material": q("roof_dark"), "roof_pitch": "48.0", "door_bay": "1", "chimney": q("right"),
                    "trim_color": col(0.18, 0.18, 0.19), "door_color": col(0.2, 0.2, 0.21), "variation_seed": "44"},
    "row_house_e": {"width": "6.6", "depth": "11.0", "floors": "3", "floor_height": "3.1",
                    "wall_material": q("brick_white"), "wall_tint": col(0.95, 0.95, 0.93),
                    "roof_material": q("roof_dark"), "roof_type": q("hip"), "roof_pitch": "35.0", "door_bay": "0",
                    "balcony_bay": "1", "corner_quoins": "true", "chimney": q("none"),
                    "door_color": col(0.05, 0.25, 0.3), "variation_seed": "55"},
    "row_house_f": {"width": "4.8", "depth": "8.5", "floors": "2", "floor_height": "2.8",
                    "wall_material": q("plaster"), "wall_tint": col(0.78, 0.84, 0.82), "roof_material": q("roof_red"),
                    "roof_pitch": "45.0", "door_bay": "1", "string_courses": "false", "chimney": q("left"),
                    "door_color": col(0.35, 0.22, 0.12), "variation_seed": "66"},
    "corner_house": {"width": "7.5", "depth": "9.0", "floors": "3", "floor_height": "3.0",
                     "wall_material": q("brick_old"), "roof_material": q("roof_dark"), "roof_type": q("hip"),
                     "door_bay": "1", "side_windows": "true", "corner_quoins": "true", "bay_window_bay": "2",
                     "chimney": q("none"), "door_color": col(0.1, 0.15, 0.12), "variation_seed": "77"},
    "shop": {"width": "7.0", "depth": "10.0", "floors": "3", "wall_material": q("brick_mixed"),
             "roof_material": q("roof_dark"), "ground_floor": q("shop"), "door_bay": "0", "shop_sign": q("SHOP"),
             "awning": "true", "awning_color": col(0.12, 0.3, 0.2), "balcony_bay": "1", "chimney": q("right"),
             "variation_seed": "88"},
}
# Every house can be entered: all floors, stairwell, procedural furniture and lights.
WALK_IN = {"enterable": "true", "upper_floors": "true", "furnish": q("home")}
for name, props in HOUSES.items():
    building(B + name + ".tscn", {**props, **WALK_IN})

building(B + "warehouse.tscn", {
    "width": "16.0", "depth": "12.0", "floors": "1", "floor_height": "5.5", "bays": "4",
    "wall_material": q("corrugated"), "wall_tint": col(0.55, 0.6, 0.62), "roof_material": q("roof_dark"),
    "roof_type": q("gable"), "roof_pitch": "15.0", "string_courses": "false", "chimney": q("none"),
    "door_bay": "1", "lit_windows": "0.0", "variation_seed": "99",
    "enterable": "true", "furnish": q("storage"), "floor_material": q("concrete")})


def marker(sc, name, pos, rot=0.0):
    sc.node(name, "Marker3D", ".", props={"transform": xform(pos, rot)})


def inst(sc, name, rel, pos, rot=0.0, props=None):
    p = {"transform": xform(pos, rot)}
    p.update(props or {})
    sc.node(name, None, ".", instance="res://" + rel, props=p)


FLOOR = 0.15


def shopkeeper(sc, name, pos, npc_name, shop_name, greeting, stock, variant, color_seed, extra=None):
    """NPC who sells `stock` (item ids), standing at `pos` facing the room (+Z)."""
    props = {"npc_name": q(npc_name), "shop_name": q(shop_name), "greeting": q(greeting),
             "stock": "Array[StringName]([" + ", ".join(f'&"{i}"' for i in stock) + "])",
             "variant": str(variant), "color_seed": str(color_seed)}
    props.update(extra or {})
    inst(sc, name, "prefabs/npc/shopkeeper.tscn", pos, 180, props)


# Starter Room: the players' first property. Station spots stay free for step 6.
def starter_extra(sc):
    inst(sc, "Bed", I + "bed.tscn", (-2.2, FLOOR, -7.6), 0)
    inst(sc, "Sofa", I + "sofa.tscn", (1.6, FLOOR, -8.3), 0)
    inst(sc, "Table", I + "coffee_table.tscn", (1.6, FLOOR, -6.9), 0, )
    inst(sc, "TVStand", I + "cardboard_box.tscn", (2.5, FLOOR, -4.2), 0)
    inst(sc, "TV", I + "television.tscn", (2.5, FLOOR + 0.34, -4.2), -90)
    inst(sc, "Armchair", I + "armchair.tscn", (0.3, FLOOR, -3.6), 120)
    inst(sc, "Bookshelf", I + "bookshelf.tscn", (-2.5, FLOOR, -3.2), 90)
    inst(sc, "Box1", I + "cardboard_box.tscn", (-2.3, FLOOR, -1.0), 15)
    inst(sc, "Box2", I + "cardboard_box.tscn", (-2.35, FLOOR + 0.34, -1.05), -10)
    inst(sc, "Plant", I + "potted_plant.tscn", (2.4, FLOOR, -0.7))
    inst(sc, "Lamp", I + "ceiling_lamp.tscn", (0, 2.98, -4.5))
    marker(sc, "PotSpot", (-1.2, FLOOR, -5.2))
    # Point 6: new games start with an EMPTY weed corner (stations are bought + placed).
    # The markers are where the stations of old saves (and the tests' weed corner) go.
    marker(sc, "LampSpot", (-1.2, FLOOR, -5.2), 0)
    marker(sc, "Pot1Spot", (-1.6, FLOOR, -5.2), 0)
    marker(sc, "Pot2Spot", (-0.8, FLOOR, -5.2), 0)
    marker(sc, "RackSpot", (2.55, FLOOR, -6.0), 90)
    marker(sc, "PackagingSpot", (1.0, FLOOR, -5.4))
    inst(sc, "DeliveryBox", ST + "delivery_box.tscn", (2.3, FLOOR, -2.4), -90)
    sc.node("Property", "Node3D", ".", props={
        "transform": xform((0, 3.4, 0.25)), "script": sc.script(S["property"]),
        "property_id": '&"starter_room"', "display_name": q("Starter Room")})
    sc.node("Label3D", "Label3D", "Property", props={
        "text": q("STARTER ROOM\nOwner: -"), "font_size": "40", "pixel_size": "0.006", "outline_size": "8",
        "modulate": col(1, 0.95, 0.8), "billboard": "0", "double_sided": "false"})


building(B + "starter_room.tscn", {
    "width": "6.0", "depth": "9.0", "floors": "2", "wall_material": q("brick_white"),
    "wall_tint": col(0.92, 0.9, 0.86), "roof_material": q("roof_dark"), "door_bay": "1",
    "door_color": col(0.12, 0.2, 0.35), "enterable": "true", "chimney": q("left"), "variation_seed": "5"},
    starter_extra)


def store_extra(sc):
    for i in range(3):
        inst(sc, f"ShelfL{i}", I + "steel_shelves.tscn", (-4.4, FLOOR, -2.5 - i * 1.6), 90)
        inst(sc, f"ShelfR{i}", I + "steel_shelves.tscn", (4.4, FLOOR, -2.5 - i * 1.6), -90)
    for i in range(2):
        inst(sc, f"ShelfMid{i}", I + "steel_shelves.tscn", (-0.6 + i * 1.15, FLOOR, -4.2), 0)
    sc.node("Counter", "StaticBody3D", ".", props={
        "transform": xform((1.8, FLOOR, -7.6)), "script": sc.script(S["proc_box"]),
        "size": v3(3.0, 1.0, 0.7), "material_key": q("planks")})
    inst(sc, "Register", I + "cash_register.tscn", (2.4, FLOOR + 1.0, -7.6), 180)
    for i in range(4):
        inst(sc, f"Box{i}", I + "cardboard_box.tscn", (-3.6 + (i % 2) * 0.45, FLOOR + (i // 2) * 0.34, -9.1), i * 13)
    inst(sc, "Lamp1", I + "ceiling_lamp.tscn", (0, 2.98, -3.0))
    inst(sc, "Lamp2", I + "ceiling_lamp.tscn", (0, 2.98, -7.0))
    marker(sc, "StoreSpot", (1.8, FLOOR, -8.4), 0)
    shopkeeper(sc, "Clerk", (1.8, FLOOR, -8.4), "Marc", "Store",
               "Morning. Soil, pots, lamps, baggies... it's all on the shelves.",
               ["soil", "watering_can", "baggie", "grow_pot", "grow_lamp", "drying_rack", "packaging_table",
                "storage_locker"], 1, 7)
    marker(sc, "BuyPoint", (1.8, FLOOR, -6.6), 0)


building(B + "store.tscn", {
    "width": "10.0", "depth": "10.0", "floors": "2", "wall_material": q("brick_old"),
    "roof_material": q("roof_dark"), "roof_type": q("hip"), "ground_floor": q("shop"), "door_bay": "1",
    "shop_sign": q("STORE"), "awning": "true", "awning_color": col(0.6, 0.12, 0.1), "enterable": "true",
    "public_building": "true",
    "floor_material": q("floor_tiles"), "chimney": q("none"), "variation_seed": "12"}, store_extra)


def hospital_extra(sc):
    sc.node("Reception", "StaticBody3D", ".", props={
        "transform": xform((0, FLOOR, -6.0)), "script": sc.script(S["proc_box"]),
        "size": v3(4.0, 1.1, 0.8), "material_key": q("trim_paint")})
    inst(sc, "Desk", I + "office_desk.tscn", (5.5, FLOOR, -11.0), 180)
    for i in range(3):
        inst(sc, f"Seat{i}", I + "sofa.tscn", (-8.0 + i * 2.0, FLOOR, -2.0), 180)
    inst(sc, "Wheelchair1", I + "wheelchair.tscn", (8.5, FLOOR, -2.2), -30)
    inst(sc, "Wheelchair2", I + "wheelchair.tscn", (9.4, FLOOR, -2.6), -50)
    inst(sc, "Bed1", I + "bed.tscn", (-8.5, FLOOR, -11.0), 90)
    inst(sc, "Plant1", I + "potted_plant.tscn", (-3.0, FLOOR, -1.0))
    inst(sc, "Plant2", I + "potted_plant.tscn", (3.0, FLOOR, -1.0))
    # Partition walls: lobby in front, treatment rooms at the back.
    for name, cx, w in [("WallL", -6.5, 7.6), ("WallR", 6.5, 7.6)]:
        sc.node(name, "StaticBody3D", ".", props={
            "transform": xform((cx, FLOOR, -8.5)), "script": sc.script(S["proc_box"]),
            "size": v3(w, 3.13, 0.15), "material_key": q("interior_plaster"), "bevel": "0.0"})
    for i, x in enumerate([-7.0, 0.0, 7.0]):
        inst(sc, f"Lamp{i}", I + "ceiling_lamp.tscn", (x, 3.28, -4.0))
        inst(sc, f"LampB{i}", I + "ceiling_lamp.tscn", (x, 3.28, -11.0))


building(B + "hospital.tscn", {
    "width": "22.0", "depth": "14.0", "floors": "3", "floor_height": "3.3", "bays": "9",
    "wall_material": q("plaster"), "wall_tint": col(0.95, 0.94, 0.9), "roof_type": q("flat"),
    "ground_floor": q("shop"), "door_bay": "4", "shop_sign": q("ST. ANNA HOSPITAL"),
    "trim_color": col(0.85, 0.87, 0.88), "string_courses": "true", "side_windows": "true",
    "enterable": "true", "public_building": "true", "floor_material": q("floor_tiles"), "lit_windows": "0.45",
    "variation_seed": "3"},
    hospital_extra)


W = "prefabs/weapons/"


def gun_shop_extra(sc):
    """Gun shop: counter with the dealer, guns on a pegboard behind him, ammo crates."""
    sc.node("Counter", "StaticBody3D", ".", props={
        "transform": xform((0.6, FLOOR, -6.3)), "script": sc.script(S["proc_box"]),
        "size": v3(4.2, 1.0, 0.65), "material_key": q("planks")})
    inst(sc, "Register", I + "cash_register.tscn", (2.0, FLOOR + 1.0, -6.3), 180)
    sc.node("Pegboard", "StaticBody3D", ".", props={
        "transform": xform((0.2, FLOOR + 0.95, -9.72)), "script": sc.script(S["proc_box"]),
        "size": v3(5.4, 1.75, 0.06), "material_key": q("metal_dark"), "bevel": "0.0"})
    # Display guns (decoration), barrels pointing left, hung on the pegboard.
    for name, rel, x, y in [("DisplaySniper", "sniper.tscn", 0.6, 2.38), ("DisplayAK", "ak47.tscn", 0.4, 2.02),
                            ("DisplayShotgun", "shotgun.tscn", 0.5, 1.66), ("DisplaySMG", "smg.tscn", -1.2, 1.3),
                            ("DisplayPistol", "pistol.tscn", 1.4, 1.3)]:
        inst(sc, name, W + rel, (x, FLOOR + y, -9.62), 90)
    for i in range(2):
        inst(sc, f"Shelf{i}", I + "steel_shelves.tscn", (-3.0, FLOOR, -2.4 - i * 1.6), 90)
    inst(sc, "AmmoCrate1", P + "crate_flat.tscn", (2.6, FLOOR, -2.2), 10)
    inst(sc, "AmmoCrate2", P + "crate_flat.tscn", (2.62, FLOOR + 0.46, -2.25), -5)
    inst(sc, "AmmoCrate3", P + "crate_long.tscn", (2.6, FLOOR, -3.6), 90)
    inst(sc, "Lamp1", I + "ceiling_lamp.tscn", (0, 2.98, -3.0))
    inst(sc, "Lamp2", I + "ceiling_lamp.tscn", (0, 2.98, -7.6))
    marker(sc, "GunShopSpot", (0.6, FLOOR, -7.1), 0)
    shopkeeper(sc, "Dealer", (0.6, FLOOR, -7.1), "Vince", "Gun Shop",
               "Looking for protection? Guns on the wall, ammo by the box. No questions.",
               ["smg", "shotgun", "ak47", "sniper", "ammo_9mm", "ammo_12g", "ammo_762", "ammo_308"], 11, 42)


building(B + "gun_shop.tscn", {
    "width": "7.0", "depth": "10.0", "floors": "2", "wall_material": q("concrete"),
    "wall_tint": col(0.75, 0.74, 0.72), "roof_material": q("roof_dark"), "roof_type": q("flat"),
    "ground_floor": q("shop"), "door_bay": "1", "shop_sign": q("GUNS & AMMO"), "awning": "true",
    "awning_color": col(0.15, 0.15, 0.16), "enterable": "true", "public_building": "true",
    "floor_material": q("concrete"), "chimney": q("none"), "variation_seed": "17"}, gun_shop_extra)


def contact_extra(sc):
    inst(sc, "Desk", I + "office_desk.tscn", (0.2, FLOOR, -3.6), 0)
    inst(sc, "Chair", I + "armchair.tscn", (-0.45, FLOOR, -4.75), 180)
    inst(sc, "Crate1", P + "crate_long.tscn", (-1.7, FLOOR, -3.2), 0)
    inst(sc, "Crate2", P + "crate_flat.tscn", (-1.7, FLOOR + 0.46, -3.3), 8)
    inst(sc, "Barrel", P + "barrel.tscn", (1.8, FLOOR, -1.0))
    inst(sc, "Lamp", I + "hanging_lamp.tscn", (0, 3.48, -2.6))
    marker(sc, "ContactSpot", (0.75, FLOOR, -4.7), 0)
    shopkeeper(sc, "Contact", (0.75, FLOOR, -4.7), "Dries", "Contact",
               "You looking to grow? I got seeds. Cash only.", ["weed_seed"], 10, 3)


building(B + "contact_hideout.tscn", {
    "width": "5.0", "depth": "5.5", "floors": "1", "floor_height": "3.5", "bays": "2",
    "wall_material": q("brick_old"), "wall_tint": col(0.8, 0.78, 0.76), "roof_type": q("flat"),
    "door_bay": "0", "door_color": col(0.2, 0.2, 0.2), "string_courses": "false", "enterable": "true",
    "floor_material": q("concrete"), "lit_windows": "0.0", "variation_seed": "13"}, contact_extra)


# Point 7: the garage. Workshop in front, the black market behind a chain-link fence at the
# back (gate locked during the day, Rook only sells at night).
GARAGE_W = 12.6  # interior 12 m: 5 fence panels of 2 m + a 2 m gate


def garage_extra(sc):
    fz = -7.6  # the fence line (market behind it)
    # Front: big GARAGE letters over the door and a closed roller shutter over the right two bays.
    sc.node("Sign", "Label3D", ".", props={
        "transform": xform((2.1, 4.05, 0.08)), "text": q("GARAGE"), "font_size": "120", "pixel_size": "0.007",
        "outline_size": "12", "modulate": col(0.95, 0.85, 0.3), "double_sided": "false"})
    sc.node("Shutter", "StaticBody3D", ".", props={
        "script": sc.script("res://scripts/procgen/roller_shutter.gd"), "transform": xform((2.1, 0.0, 0.02)),
        "size": "Vector2(7.2, 3.3)"})
    # Workshop: covered car on the lift spot, tools, racks, tyres (barrels), oil stain crates.
    inst(sc, "CoveredCar", P + "covered_car.tscn", (1.6, FLOOR, -4.0), 90)
    inst(sc, "ToolCart", I + "tool_cart.tscn", (-1.4, FLOOR, -3.2), -20)
    inst(sc, "Rack1", I + "metal_rack.tscn", (5.6, FLOOR, -2.2), -90)
    inst(sc, "Rack2", I + "steel_shelves.tscn", (5.6, FLOOR, -4.6), -90)
    inst(sc, "Barrel1", P + "barrel.tscn", (4.9, FLOOR, -6.6))
    inst(sc, "Barrel2", P + "barrel.tscn", (4.3, FLOOR, -6.9))
    inst(sc, "Crate1", P + "crate_long.tscn", (-5.2, FLOOR, -6.5), 90)
    inst(sc, "Lamp1", I + "hanging_lamp.tscn", (-2.5, 4.35, -3.5))
    inst(sc, "Lamp2", I + "hanging_lamp.tscn", (2.5, 4.35, -3.5))
    # Fence across the hall with the night gate (x -2..0).
    for i, x in enumerate([-6.0, -4.0, 0.0, 2.0, 4.0]):
        inst(sc, f"Fence{i + 1}", P + "chainlink_fence.tscn", (x, FLOOR, fz), 0)
    sc.node("MarketGate", None, ".", instance="res://prefabs/buildings/night_gate.tscn",
            props={"transform": xform((-2.0, FLOOR, fz), 0)})
    # The market: Rook behind a table of crates.
    inst(sc, "MarketTable", I + "dining_table.tscn", (1.6, FLOOR, -9.4), 0)
    inst(sc, "MarketCrate1", P + "crate_long.tscn", (-4.6, FLOOR, -10.9), 0)
    inst(sc, "MarketCrate2", P + "crate_flat.tscn", (-4.6, FLOOR + 0.46, -10.9), 6)
    inst(sc, "MarketCrate3", P + "crate_long.tscn", (4.9, FLOOR, -10.9), 90)
    inst(sc, "MarketBox", I + "cardboard_box.tscn", (1.2, FLOOR + 0.88, -9.4), 20)
    inst(sc, "MarketLamp", I + "hanging_lamp.tscn", (1.6, 4.35, -9.6))
    marker(sc, "BlackMarketSpot", (1.6, FLOOR, -10.6), 0)
    shopkeeper(sc, "BlackMarket", (1.6, FLOOR, -10.6), "Rook", "Black Market",
               "Keep your voice down. Seeds, gear, anything you need to get started. Cash.",
               ["weed_seed", "baggie", "grow_pot", "grow_lamp", "drying_rack", "packaging_table", "storage_locker"],
               5, 11, {"night_only": "true", "price_factor": "0.9"})


building(B + "garage.tscn", {
    "width": str(GARAGE_W), "depth": "12.0", "floors": "1", "floor_height": "4.5", "bays": "3",
    "wall_material": q("brick_mixed"), "wall_tint": col(0.82, 0.8, 0.78), "roof_type": q("flat"),
    "door_bay": "0", "door_color": col(0.25, 0.27, 0.3), "string_courses": "false", "enterable": "true",
    "public_building": "true", "shop_sign": q("GARAGE"), "floor_material": q("concrete"), "chimney": q("none"),
    "lit_windows": "0.0", "variation_seed": "41"}, garage_extra)


# --------------------------------------------------------------------------- items
# Held / dropped / icon models of the small inventory items (ProcItem, origin = grip, front -Z).
IT = "prefabs/items/"
for item_id, kind, props in [
        ("soil", "soil_bag", {}), ("watering_can", "watering_can", {}),
        ("weed_seed", "seed_packet", {"tint": col(0.25, 0.55, 0.2)}), ("baggie", "baggie", {}),
        ("weed_bag", "weed_bag", {}), ("weed_bud", "weed_bud", {}), ("fresh_weed", "fresh_weed", {}),
        ("ammo_9mm", "ammo_box", {"tint": col(0.75, 0.62, 0.38), "accent": col(0.2, 0.35, 0.7)}),
        ("ammo_762", "ammo_box", {"tint": col(0.4, 0.42, 0.3), "accent": col(0.75, 0.2, 0.12)}),
        ("ammo_12g", "ammo_box", {"tint": col(0.6, 0.12, 0.1), "accent": col(0.9, 0.85, 0.7)}),
        ("ammo_308", "ammo_box", {"tint": col(0.25, 0.27, 0.22), "accent": col(0.85, 0.7, 0.2)})]:
    script_prefab(IT + item_id + ".tscn", "Node3D", "proc_item", {"kind": q(kind), **props})
