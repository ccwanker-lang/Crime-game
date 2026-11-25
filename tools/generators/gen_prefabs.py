"""Generates the reusable prefab scenes in res://prefabs/ (nature, props, interiors, buildings).
Usage: python gen_prefabs.py <project root>"""
import sys
from tscn import Scene, v3, col, xform, strarr
from palette_tint import ptint, pcol  # point 27: building colours from the palette

ROOT = sys.argv[1].rstrip("/\\") + "/"
PH = "res://assets/polyhaven/%s/%s.gltf"
S = {
    "model_part": "res://scripts/procgen/model_part.gd",
    "tree": "res://scripts/procgen/proc_tree.gd",
    "shrub": "res://scripts/procgen/proc_shrub.gd",
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
    "estate_agent": "res://scripts/npc/estate_agent.gd",
    "car_dealer": "res://scripts/npc/car_dealer.gd",
    "washing_machine": "res://scripts/procgen/washing_machine.gd",
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
# Point 27: stylized shrubs (faceted blobs in palette greens) instead of the Poly Haven shrub/fern.
SHRUBS = [("a", 1, (1.4, 1.2, 1.3), '"leaf_dark", "leaf", "leaf_light"'),
          ("b", 2, (1.1, 0.9, 1.1), '"leaf_dark", "leaf", "accent_yellow"'),
          ("c", 3, (1.6, 1.3, 1.4), '"leaf_dark", "leaf_dark", "leaf"'),
          ("d", 4, (1.0, 1.1, 1.0), '"leaf_dark", "leaf", "plaster_pink"')]
for letter, seed, size, sw in SHRUBS:
    script_prefab(N + f"shrub_{letter}.tscn", "StaticBody3D", "shrub",
                  {"shrub_seed": str(seed), "size": v3(*size), "swatches": "PackedStringArray(%s)" % sw})
script_prefab(N + "fern.tscn", "StaticBody3D", "shrub",
              {"shrub_seed": "9", "size": v3(0.7, 0.45, 0.7), "swatches": 'PackedStringArray("grass_dark", "leaf", "grass_light")',
               "collide": "false"})
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
script_prefab(I + "washing_machine.tscn", "StaticBody3D", "washing_machine")
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
                    "wall_tint": ptint("plaster", "plaster_cream"), "roof_material": q("roof_dark"), "door_bay": "1",
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
                    "wall_material": q("brick_white"), "wall_tint": ptint("brick_white", "brick_white"),
                    "roof_material": q("roof_dark"), "roof_type": q("hip"), "roof_pitch": "35.0", "door_bay": "0",
                    "balcony_bay": "1", "corner_quoins": "true", "chimney": q("none"),
                    "door_color": col(0.05, 0.25, 0.3), "variation_seed": "55"},
    "row_house_f": {"width": "4.8", "depth": "8.5", "floors": "2", "floor_height": "2.8",
                    "wall_material": q("plaster"), "wall_tint": ptint("plaster", "plaster_green"), "roof_material": q("roof_red"),
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
    # Point 20: every Starter Room gets a free storage locker here (against the left wall).
    marker(sc, "LockerSpot", (-2.43, FLOOR, -5.6), 90)
    inst(sc, "DeliveryBox", ST + "delivery_box.tscn", (2.3, FLOOR, -2.4), -90)
    sc.node("Property", "Node3D", ".", props={
        "transform": xform((0, 3.4, 0.25)), "script": sc.script(S["property"]),
        "property_id": '&"starter_room"', "display_name": q("Starter Room")})
    sc.node("Label3D", "Label3D", "Property", props={
        "text": q("STARTER ROOM\nOwner: -"), "font_size": "40", "pixel_size": "0.006", "outline_size": "8",
        "modulate": col(1, 0.95, 0.8), "billboard": "0", "double_sided": "false"})


building(B + "starter_room.tscn", {
    "width": "6.0", "depth": "9.0", "floors": "2", "wall_material": q("brick_white"),
    "wall_tint": ptint("brick_white", "brick_white"), "roof_material": q("roof_dark"), "door_bay": "1",
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
               "Morning. Soil, watering cans, baggies, storage lockers, trash bins... it's all on the shelves.",
               ["soil", "watering_can", "baggie", "storage_locker", "trash_bin"], 1, 7)
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
    "wall_material": q("plaster"), "wall_tint": ptint("plaster", "brick_white"), "roof_type": q("flat"),
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
    "wall_material": q("brick_old"), "wall_tint": ptint("brick_old", "brick_brown", 0.85), "roof_type": q("flat"),
    "door_bay": "0", "door_color": col(0.2, 0.2, 0.2), "string_courses": "false", "enterable": "true",
    "floor_material": q("concrete"), "lit_windows": "0.0", "variation_seed": "13"}, contact_extra)


# Point 8: the real estate agent's office (Mrs. Vos sells the properties marked for_sale).
def estate_extra(sc):
    inst(sc, "Desk", I + "office_desk.tscn", (0.8, FLOOR, -6.2), 180)
    inst(sc, "Chair1", I + "dining_chair.tscn", (0.4, FLOOR, -5.0), 0)
    inst(sc, "Chair2", I + "dining_chair.tscn", (1.3, FLOOR, -5.0), 0)
    inst(sc, "Shelf", I + "bookshelf.tscn", (-3.0, FLOOR, -8.9), 0)
    inst(sc, "Cabinet", I + "drawer_cabinet.tscn", (2.6, FLOOR, -9.4), 0)
    inst(sc, "Sofa", I + "sofa_modern.tscn", (-2.9, FLOOR, -3.6), 90)
    inst(sc, "SideTable", I + "side_table.tscn", (-3.0, FLOOR, -2.2), 90)
    inst(sc, "Plant1", I + "potted_plant.tscn", (3.0, FLOOR, -1.0))
    inst(sc, "Plant2", I + "potted_plant.tscn", (-3.0, FLOOR, -6.5))
    inst(sc, "Lamp1", I + "ceiling_lamp.tscn", (0, 2.98, -3.0))
    inst(sc, "Lamp2", I + "ceiling_lamp.tscn", (0, 2.98, -7.0))
    marker(sc, "EstateSpot", (0.8, FLOOR, -7.3), 0)
    shopkeeper(sc, "Agent", (0.8, FLOOR, -7.3), "Mrs. Vos", "Vos Real Estate",
               "Looking for more room? Houses, a warehouse... I have something for every budget.", [], 6, 21,
               {"script": sc.script(S["estate_agent"])})


building(B + "real_estate.tscn", {
    "width": "8.0", "depth": "10.0", "floors": "2", "wall_material": q("plaster"), "wall_tint": ptint("plaster", "plaster_cream"),
    "roof_material": q("roof_dark"), "ground_floor": q("shop"), "door_bay": "0", "shop_sign": q("VOS REAL ESTATE"),
    "awning": "true", "awning_color": col(0.12, 0.2, 0.4), "chimney": q("none"), "enterable": "true",
    "public_building": "true", "variation_seed": "512"}, estate_extra)


# Point 45: Carlo's Cars, the sales office on the car lot (the lot itself is in gen_world).
def car_dealer_extra(sc):
    inst(sc, "Desk", I + "office_desk.tscn", (0.0, FLOOR, -5.0), 180)
    inst(sc, "Chair1", I + "dining_chair.tscn", (-0.5, FLOOR, -3.8), 0)
    inst(sc, "Chair2", I + "dining_chair.tscn", (0.5, FLOOR, -3.8), 0)
    inst(sc, "Cabinet", I + "drawer_cabinet.tscn", (2.2, FLOOR, -7.4), 0)
    inst(sc, "Shelf", I + "wall_shelf.tscn", (-2.0, FLOOR, -7.5), 0)
    inst(sc, "Plant", I + "potted_plant.tscn", (2.7, FLOOR, -0.8))
    inst(sc, "Sofa", I + "sofa_modern.tscn", (2.9, FLOOR, -3.4), -90)  # (the door is in the left bay)
    inst(sc, "Lamp", I + "ceiling_lamp.tscn", (0, 2.98, -4.0))
    shopkeeper(sc, "Carlo", (0.0, FLOOR, -6.1), "Carlo", "Carlo's Cars",
               "Wheels! Every car on the lot runs, mostly. Cash or... cash.", [], 2, 33,
               {"script": sc.script(S["car_dealer"])})


building(B + "car_dealer.tscn", {
    "width": "7.0", "depth": "8.0", "floors": "1", "wall_material": q("plaster"), "wall_tint": ptint("plaster", "plaster_blue"),
    "roof_material": q("roof_dark"), "ground_floor": q("shop"), "door_bay": "0", "shop_sign": q("CARLO'S CARS"),
    "awning": "true", "awning_color": col(0.55, 0.08, 0.06), "chimney": q("none"), "enterable": "true",
    "public_building": "true", "variation_seed": "845"}, car_dealer_extra)


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
    "wall_material": q("brick_mixed"), "wall_tint": ptint("brick_mixed", "brick_red", 0.85), "roof_type": q("flat"),
    "door_bay": "0", "door_color": col(0.25, 0.27, 0.3), "string_courses": "false", "enterable": "true",
    "public_building": "true", "shop_sign": q("GARAGE"), "floor_material": q("concrete"), "chimney": q("none"),
    "lit_windows": "0.0", "variation_seed": "41"}, garage_extra)


# Point 9: front businesses (bought at Vos Real Estate). The back-office safe launders
# dirty cash: `daily_max` per in-game day, 10% fee.
def safe(sc, pos, daily_max, rot=0.0):
    inst(sc, "Safe", "prefabs/stations/launder_safe.tscn", pos, rot, {"daily_max": str(daily_max)})


def counter(sc, name, pos, size, material="planks"):
    sc.node(name, "StaticBody3D", ".", props={
        "transform": xform(pos), "script": sc.script(S["proc_box"]), "size": v3(*size), "material_key": q(material)})


# Point 52: the cover garage (a property, rank 1): a real workshop in front (car lift = RepairBay, repairs pay
# clean money) and a hidden room at the back behind a tool shelf that slides aside (HiddenShelfDoor).
COVER_W = 12.4


def cover_garage_extra(sc):
    wz = -10.1  # the wall between the workshop and the hidden room
    top = 4.35
    # Front: big letters + a closed roller shutter over the right two bays (cars come in through the back alley).
    sc.node("Sign", "Label3D", ".", props={
        "transform": xform((2.0, 4.05, 0.08)), "text": q("AUTO REPAIR"), "font_size": "110", "pixel_size": "0.007",
        "outline_size": "12", "modulate": col(0.4, 0.8, 1.0), "double_sided": "false"})
    sc.node("Shutter", "StaticBody3D", ".", props={
        "script": sc.script("res://scripts/procgen/roller_shutter.gd"), "transform": xform((2.0, 0.0, 0.02)),
        "size": "Vector2(7.0, 3.3)"})
    # Workshop: the lift with the customer's car, workbench, tools, racks, tyres.
    inst(sc, "RepairBay", "prefabs/stations/repair_bay.tscn", (2.0, FLOOR, -5.0), 0)
    counter(sc, "Workbench", (-4.6, FLOOR, -8.9), (2.6, 0.9, 0.8), "metal_dark")
    inst(sc, "ToolCart", I + "tool_cart.tscn", (-1.0, FLOOR, -4.4), 15)
    inst(sc, "Rack1", I + "metal_rack.tscn", (5.6, FLOOR, -2.0), -90)
    inst(sc, "Rack2", I + "steel_shelves.tscn", (5.6, FLOOR, -8.4), -90)
    inst(sc, "Barrel1", P + "barrel.tscn", (-5.4, FLOOR, -1.4))
    inst(sc, "Barrel2", P + "barrel.tscn", (-4.8, FLOOR, -1.0))
    inst(sc, "Crate1", P + "crate_flat.tscn", (-5.3, FLOOR, -6.0), 90)
    inst(sc, "Lamp1", I + "hanging_lamp.tscn", (-2.5, 4.35, -4.0))
    inst(sc, "Lamp2", I + "hanging_lamp.tscn", (2.5, 4.35, -5.0))
    # The wall with the gap for the secret door (x -0.6..0.6); the shelf stands in front of it, slides right.
    counter(sc, "HiddenWallL", ((-6.2 + -0.6) / 2, FLOOR, wz), (5.6, top, 0.2), "interior_plaster")
    counter(sc, "HiddenWallR", ((0.6 + 6.2) / 2, FLOOR, wz), (5.6, top, 0.2), "interior_plaster")
    counter(sc, "HiddenWallTop", (0.0, FLOOR + 2.3, wz), (1.2, top - 2.3, 0.2), "interior_plaster")
    sc.node("SecretShelf", "Node3D", ".", props={
        "script": sc.script("res://scripts/interaction/hidden_shelf_door.gd"),
        "transform": xform((-0.6, FLOOR, wz + 0.1 + 0.47)), "width": "1.2", "height": "2.3", "depth": "0.45"})
    # The hidden room (3.6 m deep): bare, a lamp and an old crate; the crew builds its lab/storage here.
    inst(sc, "HiddenLamp", I + "hanging_lamp.tscn", (0.0, 4.35, -12.0))
    inst(sc, "HiddenCrate", P + "crate_long.tscn", (5.0, FLOOR, -13.0), 0)
    marker(sc, "HiddenRoomSpot", (0.0, FLOOR, -12.0), 0)


building(B + "cover_garage.tscn", {
    "width": str(COVER_W), "depth": "14.0", "floors": "1", "floor_height": "4.5", "bays": "3",
    "wall_material": q("concrete"), "roof_type": q("flat"), "door_bay": "0", "door_color": col(0.15, 0.3, 0.5),
    "string_courses": "false", "enterable": "true", "shop_sign": q("AUTO REPAIR"), "floor_material": q("concrete"),
    "chimney": q("none"), "lit_windows": "0.0", "variation_seed": "52"}, cover_garage_extra)


def bakery_extra(sc):
    counter(sc, "Counter", (0.6, FLOOR, -5.6), (4.6, 0.95, 0.7))
    sc.node("Display", "StaticBody3D", ".", props={
        "transform": xform((0.6, FLOOR + 0.95, -5.6)), "script": sc.script(S["proc_box"]),
        "size": v3(4.2, 0.35, 0.55), "material_key": q("glass_clear"), "collision": "false", "bevel": "0.005"})
    inst(sc, "Register", I + "cash_register.tscn", (2.5, FLOOR + 0.95, -5.6), 180)
    inst(sc, "ShelfA", I + "wall_shelf.tscn", (-2.0, FLOOR, -9.7), 0)
    inst(sc, "ShelfB", I + "wall_shelf.tscn", (0.2, FLOOR, -9.7), 0)
    # Front door is in the left bay: the seating goes right.
    inst(sc, "Table", I + "round_coffee_table.tscn", (2.0, FLOOR, -2.6), 0)
    inst(sc, "ChairA", I + "dining_chair.tscn", (1.3, FLOOR, -2.6), 90)
    inst(sc, "ChairB", I + "dining_chair.tscn", (2.75, FLOOR, -2.6), -90)
    inst(sc, "Plant", I + "potted_plant.tscn", (2.9, FLOOR, -0.9))
    inst(sc, "Lamp1", I + "ceiling_lamp.tscn", (0, 2.98, -3.0))
    inst(sc, "Lamp2", I + "ceiling_lamp.tscn", (0, 2.98, -7.5))
    safe(sc, (2.6, FLOOR, -9.3), 1500)


def barber_extra(sc):
    for i, z in enumerate([-3.4, -5.6]):
        inst(sc, f"Chair{i}", I + "barber_chair.tscn", (-1.7, FLOOR, z), -90)
        sc.node(f"MirrorFrame{i}", "StaticBody3D", ".", props={
            "transform": xform((-2.93, FLOOR + 0.95, z)), "script": sc.script(S["proc_box"]),
            "size": v3(0.04, 1.1, 1.0), "material_key": q("planks"), "bevel": "0.01"})
        sc.node(f"Mirror{i}", "StaticBody3D", ".", props={
            "transform": xform((-2.9, FLOOR + 1.0, z)), "script": sc.script(S["proc_box"]),
            "size": v3(0.02, 0.95, 0.85), "material_key": q("car_chrome"), "bevel": "0.0", "collision": "false"})
    inst(sc, "Bench", I + "painted_bench.tscn", (2.5, FLOOR, -3.6), -90)
    inst(sc, "Side", I + "side_table.tscn", (2.6, FLOOR, -5.4), -90)
    inst(sc, "Register", I + "cash_register.tscn", (2.6, FLOOR + 0.55, -5.4), -90)
    inst(sc, "Shelf", I + "wall_shelf.tscn", (-1.2, FLOOR, -9.7), 0)
    inst(sc, "Plant", I + "potted_plant.tscn", (2.6, FLOOR, -1.0))
    inst(sc, "Lamp1", I + "ceiling_lamp.tscn", (0, 2.98, -3.0))
    inst(sc, "Lamp2", I + "ceiling_lamp.tscn", (0, 2.98, -7.0))
    safe(sc, (2.3, FLOOR, -9.3), 2500)


def laundromat_extra(sc):
    for i in range(9):
        inst(sc, f"Washer{i}", I + "washing_machine.tscn", (-3.3, FLOOR, -3.0 - i * 0.68), 90)
    inst(sc, "Folding", I + "office_desk.tscn", (0.6, FLOOR, -5.5), 90)
    for i, z in enumerate([-2.2, -3.0, -3.8]):
        inst(sc, f"Chair{i}", I + "plastic_chair.tscn", (3.2, FLOOR, z), -90)
    inst(sc, "Basket", I + "cardboard_box.tscn", (0.6, FLOOR + 0.79, -5.0), 10)
    inst(sc, "Plant", I + "potted_plant.tscn", (3.2, FLOOR, -1.0))
    inst(sc, "Lamp1", I + "ceiling_lamp.tscn", (0, 2.98, -3.0))
    inst(sc, "Lamp2", I + "ceiling_lamp.tscn", (0, 2.98, -7.0))
    safe(sc, (3.0, FLOOR, -9.3), 4000)


# Point 10: the police station. Officers start at the OfficerSpawn markers and patrol around it.
def police_extra(sc):
    counter(sc, "FrontDesk", (2.0, FLOOR, -4.2), (4.0, 1.05, 0.7))
    inst(sc, "DeskPC", I + "television.tscn", (2.6, FLOOR + 1.05, -4.25), 180, {"scale": "Vector3(0.6, 0.6, 0.6)"})
    inst(sc, "Bench", I + "painted_bench.tscn", (5.3, FLOOR, -2.4), -90)
    inst(sc, "Plant", I + "potted_plant.tscn", (5.3, FLOOR, -0.9))
    for i, x in enumerate([-3.0, 1.5]):
        inst(sc, f"Desk{i}", I + "office_desk.tscn", (x, FLOOR, -7.4), 0)
        inst(sc, f"Chair{i}", I + "dining_chair.tscn", (x, FLOOR, -6.6), 180)
    inst(sc, "Shelves", I + "steel_shelves.tscn", (5.2, FLOOR, -8.0), -90)
    inst(sc, "Cabinet", I + "drawer_cabinet.tscn", (-5.0, FLOOR, -9.3), 0)
    for i, x in enumerate([-1.0, 0.0, 1.0]):
        marker(sc, f"OfficerSpawn{i + 1}", (x, FLOOR, -2.0), 0)
    # Point 25: arrested players are released here (on the pavement by the door).
    marker(sc, "ReleaseSpot", (-2.5, 0.25, 1.6), 0)
    for i, x in enumerate([-3.0, 0.0, 3.0]):
        inst(sc, f"Lamp{i}", I + "ceiling_lamp.tscn", (x, 2.98, -5.0))
    # Blue lamp over the door.
    sc.node("BlueLamp", "OmniLight3D", ".", props={
        "transform": xform((-3.0, 3.2, 0.6)), "light_color": col(0.4, 0.55, 1.0), "light_energy": "1.5",
        "omni_range": "5.0"})


building(B + "police_station.tscn", {
    "width": "12.0", "depth": "10.0", "floors": "2", "bays": "4", "wall_material": q("brick_white"),
    "wall_tint": col(0.9, 0.92, 0.95), "roof_material": q("roof_dark"), "roof_type": q("flat"),
    "ground_floor": q("shop"), "door_bay": "0", "shop_sign": q("POLICE"), "awning": "false",
    "chimney": q("none"), "enterable": "true", "public_building": "true", "string_courses": "false",
    "floor_material": q("floor_tiles"), "trim_color": col(0.1, 0.18, 0.45), "door_color": col(0.1, 0.18, 0.45),
    "variation_seed": "700"}, police_extra)


# Point 11: the Black Crows' house (a dark, run-down corner house; they come out at the RivalSpawn markers).
def crows_extra(sc):
    for i, x in enumerate([-1.6, 0.0, 1.6]):
        marker(sc, f"RivalSpawn{i + 1}", (x - 0.8, 0.1, 1.8), 0)
    sc.node("Tag", "Label3D", ".", props={
        "transform": xform((-2.3, 1.3, 0.02)), "text": q("CROWS"), "font_size": "72", "pixel_size": "0.008",
        "modulate": col(0.75, 0.08, 0.06, 0.9), "outline_size": "0", "double_sided": "false"})
    sc.node("PorchLight", "OmniLight3D", ".", props={
        "transform": xform((0.0, 2.6, 0.7)), "light_color": col(1.0, 0.45, 0.3), "light_energy": "0.9",
        "omni_range": "5.0"})


building(B + "crows_house.tscn", {**HOUSES["corner_house"], **WALK_IN, "wall_material": q("brick_old"),
         "wall_tint": col(0.5, 0.47, 0.45), "door_color": col(0.25, 0.04, 0.04), "lit_windows": "0.35",
         "variation_seed": "1313"}, crows_extra)


FRONT = {"depth": "10.0", "floors": "2", "roof_material": q("roof_dark"), "ground_floor": q("shop"),
         "door_bay": "0", "awning": "true", "chimney": q("none"), "enterable": "true", "public_building": "true",
         "floor_material": q("floor_tiles")}
building(B + "bakery.tscn", {**FRONT, "width": "7.0", "shop_sign": q("BAKERY"), "wall_material": q("brick_yellow"),
         "awning_color": col(0.55, 0.38, 0.2), "variation_seed": "200", "floor_material": q("wood_floor")}, bakery_extra)
building(B + "barber.tscn", {**FRONT, "width": "6.5", "shop_sign": q("BARBER"), "wall_material": q("brick_white"),
         "awning_color": col(0.15, 0.25, 0.55), "variation_seed": "610"}, barber_extra)
building(B + "laundromat.tscn", {**FRONT, "width": "7.5", "shop_sign": q("LAUNDROMAT"), "wall_material": q("plaster"),
         "wall_tint": ptint("plaster", "plaster_blue"), "awning_color": col(0.1, 0.45, 0.5), "variation_seed": "620"}, laundromat_extra)


# Point 49: the prison of the intro, far outside the village (gen_world puts it at PRISON_POS). Local layout,
# +Z = south = the gate and the bus. Point 93: a real complex inside a 5 m wall round an 80 x 52 m compound
# (x -40..40, z -32..20): cell block A (the intro: 4 cells with sliding barred CellDoors + 2 locked cells, barred
# fronts, a corridor, the exit to the yard), cell block B in the north-west (10 locked cells along a day room),
# the canteen in the north-east, covered walkways between the blocks, the yard (benches, pull-up bar, a hoop,
# Marco), the visiting room by the gate (glass partition with booths), the release desk, a gatehouse, a boom
# barrier outside the gate and four watchtowers in the corners. Markers Cell1-4 = where players wake up.
S["cell_door"] = "res://scripts/interaction/cell_door.gd"
S["intro_npc"] = "res://scripts/npc/intro_npc.gd"
S["proc_bus"] = "res://scripts/procgen/proc_bus.gd"
S["prison_bars"] = "res://scripts/procgen/prison_bars.gd"
S["boom_gate"] = "res://scripts/world/boom_gate.gd"
S["sliding_gate"] = "res://scripts/world/sliding_gate.gd"
S["proc_stairs"] = "res://scripts/procgen/proc_stairs.gd"
S["razor_wire"] = "res://scripts/procgen/razor_wire.gd"
S["army_prop"] = "res://scripts/procgen/army_prop.gd"
ARMY_KIND = {"bunk": 0, "rack": 1, "sandbags": 2, "map": 3, "radio": 4, "ammo": 5, "lockers": 6}


def aprop(sc, name, kind, pos, rot=0.0, length=None, rows=None):
    """Point 100: one ArmyProp (one mesh + one box)."""
    props = {"script": sc.script(S["army_prop"]), "transform": xform(pos, rot), "kind": str(ARMY_KIND[kind])}
    if length is not None:
        props["length"] = f"{length:g}"
    if rows is not None:
        props["rows"] = str(rows)
    sc.node(name, "StaticBody3D", ".", props=props)


def stairs(sc, name, foot, height, run, width=1.2, rot=0.0, rails=3, material="metal_dark"):
    """Point 99: a ProcStairs flight; `foot` = middle of its first step at the floor, climbs towards local -Z."""
    sc.node(name, "StaticBody3D", ".", props={"script": sc.script(S["proc_stairs"]), "transform": xform(foot, rot),
            "width": f"{width:g}", "height": f"{height:g}", "run": f"{run:g}", "rails": str(rails),
            "material_key": f'&"{material}"'})


def razor(sc, name, start, length, rot=0.0):
    """Point 99: razor wire on a wall top from `start` along local +X (rot -90 = along +Z)."""
    sc.node(name, "Node3D", ".", props={"script": sc.script(S["razor_wire"]), "transform": xform(start, rot),
            "length": f"{length:g}"})
S["watchtower"] = "res://scripts/procgen/watchtower.gd"


def bars(sc, name, pos, width, height, rot=0.0):
    """A fixed barred grille, `pos` = its left bottom corner (bars run along local +X)."""
    sc.node(name, "StaticBody3D", ".", props={"script": sc.script(S["prison_bars"]), "transform": xform(pos, rot),
            "width": f"{width:g}", "height": f"{height:g}"})


def hall(sc, prefix, x0, x1, z0, z1, h, doors, roof="roof_dark", floor="floor_tiles", wall="plaster"):
    """A closed single-storey hall (walls 0.3 m, roof, floor). `doors` = [(side, centre, width[, top[, sill]])],
    side N/S/W/E; a gap is `top` (2.3) m high with wall above; point 100: a `sill` > 0 makes it a window (wall
    below + a glass pane)."""
    t = 0.3
    sides = {"N": (z0, x0, x1, True), "S": (z1, x0, x1, True), "W": (x0, z0, z1, False), "E": (x1, z0, z1, False)}
    for side, (fixed, a, b, along_x) in sides.items():
        cuts = sorted([(d[1] - d[2] / 2, d[1] + d[2] / 2, d[3] if len(d) > 3 else 2.3, d[4] if len(d) > 4 else 0.0)
                       for d in doors if d[0] == side])
        pos = a
        pieces = []
        for (c0, c1, top, sill) in cuts:
            pieces.append((pos, c0))
            pieces.append(("top", c0, c1, top))
            if sill > 0:
                pieces.append(("sill", c0, c1, sill))
                pieces.append(("glass", c0, c1, top, sill))
            pos = c1
        pieces.append((pos, b))
        for i, pc in enumerate(pieces):
            if pc[0] == "glass":
                _, c0, c1, top, sill = pc
                mid = (c0 + c1) / 2
                if along_x:
                    counter(sc, f"{prefix}Glass{side}{i}", (mid, sill, fixed), (c1 - c0, top - sill, 0.05), "glass_clear")
                else:
                    counter(sc, f"{prefix}Glass{side}{i}", (fixed, sill, mid), (0.05, top - sill, c1 - c0), "glass_clear")
                continue
            if pc[0] == "sill":
                _, c0, c1, sill = pc
                mid, ln, y, hh = (c0 + c1) / 2, c1 - c0, 0, sill
            elif pc[0] == "top":
                _, c0, c1, top = pc
                if h - top < 0.05:
                    continue
                mid, ln, y, hh = (c0 + c1) / 2, c1 - c0, top, h - top
            else:
                c0, c1 = pc
                if c1 - c0 < 0.05:
                    continue
                mid, ln, y, hh = (c0 + c1) / 2, c1 - c0, 0, h
            if along_x:
                counter(sc, f"{prefix}Wall{side}{i}", (mid, y, fixed), (ln + (t if pc[0] not in ("top", "sill") else 0), hh, t), wall)
            else:
                counter(sc, f"{prefix}Wall{side}{i}", (fixed, y, mid), (t, hh, ln), wall)
    counter(sc, f"{prefix}Roof", ((x0 + x1) / 2, h, (z0 + z1) / 2), (x1 - x0 + 0.6, 0.3, z1 - z0 + 0.6), roof)
    counter(sc, f"{prefix}Floor", ((x0 + x1) / 2, 0, (z0 + z1) / 2), (x1 - x0, 0.05, z1 - z0), floor)


def prison():
    sc = Scene()
    sc.node("Prison", "Node3D")
    wall_h = 5.0
    counter(sc, "Ground", (0, -0.3, 6), (90, 0.3, 80), "concrete")
    # Outer wall (x -40..40, z -32..20.25) with the gate gap (x -3..3) in the south side.
    counter(sc, "WallN", (0, 0, -32.25), (80.5, wall_h, 0.5), "concrete")
    counter(sc, "WallW", (-40, 0, -6), (0.5, wall_h, 52.5), "concrete")
    counter(sc, "WallE", (40, 0, -6), (0.5, wall_h, 52.5), "concrete")
    counter(sc, "WallS1", (-21.5, 0, 20.25), (37.0, wall_h, 0.5), "concrete")
    counter(sc, "WallS2", (21.5, 0, 20.25), (37.0, wall_h, 0.5), "concrete")
    # Point 99: razor wire on every wall top.
    razor(sc, "WireN", (-40, wall_h, -32.25), 80.0)
    razor(sc, "WireW", (-40, wall_h, -32.25), 52.5, -90)
    razor(sc, "WireE", (40, wall_h, -32.25), 52.5, -90)
    razor(sc, "WireS1", (-40, wall_h, 20.25), 37.0)
    razor(sc, "WireS2", (3, wall_h, 20.25), 37.0)
    # Point 99: the gate itself - a steel sliding gate that rolls open behind WallS2 when someone comes near.
    sc.node("MainGate", "Node3D", ".", props={"script": sc.script(S["sliding_gate"]),
            "transform": xform((0, 0, 19.9)), "width": "6.0", "height": "3.6"})
    counter(sc, "GateBeam", (0, wall_h - 0.8, 20.25), (6.0, 0.8, 0.6), "metal_dark")
    sc.node("PrisonSign", "Label3D", ".", props={
        "transform": xform((0, wall_h - 0.4, 20.6)), "text": q("RIVERTON STATE PRISON"), "font_size": "90",
        "pixel_size": "0.006", "outline_size": "10", "modulate": col(0.95, 0.95, 0.9)})
    sc.node("GateBoom", "Node3D", ".", props={"script": sc.script(S["boom_gate"]),
            "transform": xform((3.6, 0, 22.2)), "length": "6.6"})
    # Gatehouse just inside the gate (east), the gate guard stands at its door.
    hall(sc, "Gatehouse", 5.0, 10.0, 15.0, 19.6, 3.0, [("W", 17.6, 1.2)])
    bars(sc, "GatehouseWindow", (4.85, 1.1, 16.9), 1.2, 1.0, -90)
    # Point 99: the gatehouse is the guard post - a desk with the camera screens, a chair, a locker, a sign.
    counter(sc, "PostDesk", (7.5, 0, 15.75), (4.0, 0.8, 0.9), "metal_dark")
    for i, x in enumerate((6.4, 7.5, 8.6)):
        counter(sc, f"PostScreen{i}", (x, 0.82, 15.5), (0.9, 0.6, 0.08), "car_headlight")
    inst(sc, "PostChair", I + "dining_chair.tscn", (7.5, 0.05, 16.9), 180)
    inst(sc, "PostLocker", I + "steel_shelves.tscn", (9.4, 0.05, 18.7), -90)
    inst(sc, "PostLamp", I + "ceiling_lamp.tscn", (7.5, 2.98, 17.3))
    sc.node("PostSign", "Label3D", ".", props={"transform": xform((4.8, 2.6, 17.6), -90), "text": q("GUARD POST"),
            "font_size": "48", "pixel_size": "0.006", "outline_size": "8", "modulate": col(0.95, 0.95, 0.9)})
    marker(sc, "PrisonGuardPost1", (7.5, 0.1, 17.2), 180)

    # --- Cell block A (the intro): x -14..14, z -20..-10, 3.6 m high, the exit to the yard at x 0.
    h = 3.6
    counter(sc, "BlockW", (-14, 0, -15), (0.3, h, 10), "plaster")
    counter(sc, "BlockE", (14, 0, -15), (0.3, h, 10), "plaster")
    counter(sc, "BlockN", (0, 0, -20), (28.3, h, 0.3), "plaster")
    counter(sc, "BlockS1", (-7.6, 0, -10), (12.8, h, 0.3), "plaster")
    counter(sc, "BlockS2", (7.6, 0, -10), (12.8, h, 0.3), "plaster")
    counter(sc, "BlockSTop", (0, 2.6, -10), (2.4, h - 2.6, 0.3), "plaster")
    counter(sc, "BlockRoof", (0, h, -15), (28.6, 0.3, 10.6), "roof_dark")
    counter(sc, "BlockFloor", (0, 0, -15), (28, 0.05, 10), "floor_tiles")
    sc.node("BlockASign", "Label3D", ".", props={"transform": xform((0, 3.0, -9.8)), "text": q("BLOCK A"),
            "font_size": "64", "pixel_size": "0.006", "outline_size": "8", "modulate": col(0.95, 0.95, 0.9)})
    for i in range(4):
        x0 = -8.0 + 4.0 * i
        cx = x0 + 2.0
        counter(sc, f"CellWall{i}", (x0, 0, -17), (0.2, h, 6), "interior_plaster")
        # Barred front with a 1.2 m door gap at the cell's middle (the sliding CellDoor).
        bars(sc, f"CellFrontL{i}", (x0 + 0.1, 0, -14), 1.3, 2.3)
        bars(sc, f"CellFrontR{i}", (x0 + 2.6, 0, -14), 1.3, 2.3)
        counter(sc, f"CellFrontTop{i}", (cx, 2.3, -14), (4.0, h - 2.3, 0.2), "interior_plaster")
        sc.node(f"CellDoor{i + 1}", "Node3D", ".", props={
            "script": sc.script(S["cell_door"]), "transform": xform((cx - 0.6, 0, -13.85)),
            "width": "1.2", "height": "2.3"})
        inst(sc, f"Bunk{i + 1}", I + "bed.tscn", (x0 + 0.55, 0.05, -18.4), 90)
        inst(sc, f"CellLamp{i + 1}", I + "ceiling_lamp.tscn", (cx, h - 0.02, -17.0))
        marker(sc, f"Cell{i + 1}", (cx + 0.6, 0.1, -17.0), 180)
    counter(sc, "CellWall4", (8.0, 0, -17), (0.2, h, 6), "interior_plaster")
    # Two locked cells at the ends (no door, all bars).
    for i, x0 in enumerate((-12.0, 8.0)):
        if i == 0:
            counter(sc, "CellWallA5", (-12.0, 0, -17), (0.2, h, 6), "interior_plaster")
        else:
            counter(sc, "CellWallA6", (12.0, 0, -17), (0.2, h, 6), "interior_plaster")
        bars(sc, f"LockedFront{i}", (x0 + 0.1, 0, -14), 3.8, 2.3)
        counter(sc, f"LockedFrontTop{i}", (x0 + 2.0, 2.3, -14), (4.0, h - 2.3, 0.2), "interior_plaster")
        inst(sc, f"LockedBunk{i}", I + "bed.tscn", (x0 + 0.55, 0.05, -18.4), 90)
    for i, x in enumerate((-10, 0, 10)):
        inst(sc, f"CorridorLamp{i}", I + "ceiling_lamp.tscn", (x, h - 0.02, -12.0))
    for i, x in enumerate((-11.0, -3.0, 5.0)):  # barred windows high in the yard wall
        bars(sc, f"BlockAWindow{i}", (x, 2.6, -9.82), 1.6, 0.7)

    # --- Cell block B: x -34..-18, z -30..-12: four cells on each side of a day room, door east to the walkway.
    # Point 99: two tiers - a second row of cells above each row, galleries in front with railings, a steel stair up
    # the west wall to the north gallery and a bridge at the east end to the south one.
    hb = 7.2
    hall(sc, "BlockB", -34.0, -18.0, -30.0, -12.0, hb, [("E", -21.0, 1.6)])
    up = 3.8  # upper floor level
    counter(sc, "BSlabN", (-26.0, 3.6, -27.3), (16.0, 0.2, 5.4), "concrete")
    counter(sc, "BSlabS", (-26.0, 3.6, -14.7), (16.0, 0.2, 5.4), "concrete")
    counter(sc, "BBridge", (-19.15, 3.6, -21.0), (1.7, 0.2, 7.2), "concrete")
    for row, (zf, zb) in enumerate(((-26.0, -28.6), (-16.0, -13.4))):
        for i in range(4):
            x0 = -34.0 + 4.0 * i
            if i > 0:
                zc = (zf + (-30.0 if row == 0 else -12.0)) / 2
                counter(sc, f"BUpWall{row}{i}", (x0, up, zc), (0.2, hb - up, 4.0), "interior_plaster")
            bars(sc, f"BUpFront{row}{i}", (x0 + 0.15, up, zf), 3.7, 2.4)
            counter(sc, f"BUpTop{row}{i}", (x0 + 2.0, up + 2.4, zf), (4.0, hb - up - 2.4, 0.2), "interior_plaster")
            inst(sc, f"BUpBunk{row}{i}", I + "bed.tscn", (x0 + 0.6, up + 0.05, zb), 90)
    bars(sc, "BRailN", (-32.7, up, -24.6), 12.7, 1.05, 0)
    bars(sc, "BRailS", (-34.0, up, -17.4), 13.98, 1.05, 0)
    bars(sc, "BRailBridge", (-20.0, up, -24.6), 7.2, 1.05, -90)
    stairs(sc, "BStairs", (-33.3, 0, -18.2), up, 6.4, 1.1, 0, 1)
    marker(sc, "PrisonGuardPost3", (-26.0, up + 0.1, -25.3), 180)
    sc.node("BlockBSign", "Label3D", ".", props={"transform": xform((-17.8, 2.9, -21.0), 90), "text": q("BLOCK B"),
            "font_size": "64", "pixel_size": "0.006", "outline_size": "8", "modulate": col(0.95, 0.95, 0.9)})
    for row, (zf, zb, rot_bed) in enumerate(((-26.0, -28.6, 90), (-16.0, -13.4, 90))):
        for i in range(4):
            x0 = -34.0 + 4.0 * i
            if i > 0:
                zc = (zf + (-30.0 if row == 0 else -12.0)) / 2
                counter(sc, f"BCellWall{row}{i}", (x0, 0, zc), (0.2, h, 4.0), "interior_plaster")
            bars(sc, f"BCellFront{row}{i}", (x0 + 0.15, 0, zf), 3.7, 2.4)
            counter(sc, f"BCellTop{row}{i}", (x0 + 2.0, 2.4, zf), (4.0, h - 2.4, 0.2), "interior_plaster")
            inst(sc, f"BBunk{row}{i}", I + "bed.tscn", (x0 + 0.6, 0.05, zb), rot_bed)
    for i, x in enumerate((-30.0, -23.5)):  # day room: two steel tables with stools
        counter(sc, f"BTable{i}", (x, 0, -21.0), (2.4, 0.78, 1.0), "metal_dark")
        for j, dz in enumerate((-1.0, 1.0)):
            inst(sc, f"BStool{i}{j}", I + "stool.tscn", (x, 0.05, -21.0 + dz), 0)
    counter(sc, "BTVBracket", (-26.0, 3.0, -24.5), (0.1, 0.6, 0.1), "metal_dark")
    inst(sc, "BTV", I + "television.tscn", (-26.0, 2.45, -24.45), 0)
    for i, x in enumerate((-30.0, -22.0)):
        inst(sc, f"BLamp{i}", I + "ceiling_lamp.tscn", (x, hb - 0.02, -21.0))

    # --- Canteen: x 18..34, z -30..-12, door west to the walkway, a serving counter behind bars.
    hall(sc, "Canteen", 18.0, 34.0, -30.0, -12.0, 4.0, [("W", -15.0, 1.8)], wall="brick_white")
    sc.node("CanteenSign", "Label3D", ".", props={"transform": xform((17.8, 3.1, -15.0), -90), "text": q("CANTEEN"),
            "font_size": "64", "pixel_size": "0.006", "outline_size": "8", "modulate": col(1.0, 0.85, 0.3)})
    counter(sc, "ServeCounter", (26.0, 0, -27.4), (14.0, 1.0, 0.8), "metal_dark")
    bars(sc, "ServeBars", (19.0, 1.0, -27.1), 14.0, 1.3)
    counter(sc, "ServeTop", (26.0, 2.3, -27.1), (14.0, 1.7, 0.2), "interior_plaster")
    inst(sc, "Kitchen1", I + "steel_shelves.tscn", (21.0, 0.05, -29.4), 0)
    inst(sc, "Kitchen2", I + "steel_shelves.tscn", (31.0, 0.05, -29.4), 0)
    for i, z in enumerate((-23.5, -19.5, -15.5)):
        for j, x in enumerate((22.5, 29.5)):
            counter(sc, f"Table{i}{j}", (x, 0, z), (5.0, 0.78, 1.1), "planks")
            counter(sc, f"BenchN{i}{j}", (x, 0, z - 0.9), (5.0, 0.45, 0.35), "planks")
            counter(sc, f"BenchS{i}{j}", (x, 0, z + 0.9), (5.0, 0.45, 0.35), "planks")
    for i, (x, z) in enumerate([(22.5, -22), (29.5, -22), (22.5, -16), (29.5, -16)]):
        inst(sc, f"CanteenLamp{i}", I + "ceiling_lamp.tscn", (x, 3.98, z))

    # --- Covered walkways (the corridors between the blocks): roofs on posts, open sides.
    for i, (x0, x1) in enumerate(((-18.0, -14.0), (14.0, 18.0))):
        counter(sc, f"WalkRoof{i}", ((x0 + x1) / 2, 3.3, -20.0), (x1 - x0, 0.2, 20.0), "roof_dark")
        for j, z in enumerate((-29.8, -22.0, -10.2)):
            counter(sc, f"WalkPost{i}{j}", (x1 - 0.35 if i == 0 else x0 + 0.35, 0, z), (0.2, 3.3, 0.2), "metal_dark")

    # --- The yard: benches, a pull-up bar, a basketball hoop, Marco by the east benches.
    for i, (x, z, r) in enumerate([(9, -4, -90), (9, 0, -90), (-9, -2, 90), (-20, 9, 0)]):
        inst(sc, f"Bench{i}", P + "bench.tscn", (x, 0, z), r)
    counter(sc, "BarPostL", (-4, 0, 2), (0.15, 2.4, 0.15), "metal_dark")
    counter(sc, "BarPostR", (-2, 0, 2), (0.15, 2.4, 0.15), "metal_dark")
    counter(sc, "Bar", (-3, 2.3, 2), (2.2, 0.08, 0.08), "metal_dark")
    counter(sc, "HoopPost", (-30, 0, -4), (0.2, 3.0, 0.2), "metal_dark")
    counter(sc, "HoopBoard", (-30, 2.9, -3.8), (1.8, 1.1, 0.08), "trim_paint")
    counter(sc, "HoopRing", (-30, 3.0, -3.4), (0.45, 0.04, 0.45), "metal_dark")
    counter(sc, "Court", (-30, 0, 2), (12.0, 0.02, 10.0), "asphalt")
    # Point 99: picnic tables + a weight corner in the yard; markers for session B's prison guards (posts + a yard
    # patrol loop, see A.md).
    for i, (x, z) in enumerate([(-18.0, 12.5), (-18.0, 16.5)]):
        inst(sc, f"YardTable{i}", I + "picnic_table.tscn", (x, 0.02, z), 0)
    counter(sc, "WeightBench", (-20.0, 0, -6.0), (0.5, 0.45, 1.6), "metal_dark")
    counter(sc, "WeightRack", (-21.2, 0, -6.0), (0.4, 1.3, 1.8), "metal_dark")
    marker(sc, "PrisonGuardPost2", (0.0, 0.1, 4.0), 180)
    marker(sc, "PrisonGuardPost4", (26.0, 0.1, -25.0), 180)
    for i, (x, z) in enumerate([(-12, 8), (12, 8), (12, -6), (-12, -6)]):
        marker(sc, f"PrisonPatrol{i + 1}", (x, 0.1, z), 0)
    shopkeeper(sc, "Marco", (8.2, 0, -2.0), "Marco", "fellow prisoner", "", [], 3, 49,
               {"script": sc.script(S["intro_npc"]), "role": q("mentor")})

    # --- Visiting room: x 16..34, z 4..16, inmates come in from the yard (north door), visitors from the gate side
    # (west door); a glass partition with five booths across the middle (z 10).
    hall(sc, "Visit", 16.0, 34.0, 4.0, 16.0, 3.4, [("N", 25.0, 1.6), ("W", 13.5, 1.4)], wall="plaster")
    sc.node("VisitSign", "Label3D", ".", props={"transform": xform((25.0, 2.9, 3.8), 180), "text": q("VISITING"),
            "font_size": "64", "pixel_size": "0.006", "outline_size": "8", "modulate": col(1.0, 0.85, 0.3)})
    counter(sc, "VisitCounter", (25.0, 0, 10.0), (17.4, 1.0, 0.6), "planks")
    counter(sc, "VisitGlass", (25.0, 1.0, 10.0), (17.4, 1.6, 0.06), "glass_interior")
    for i in range(5):
        x = 18.6 + 3.2 * i
        for j, (dz, r) in enumerate(((-0.9, 0), (0.9, 180))):
            inst(sc, f"VisitChair{i}{j}", I + "dining_chair.tscn", (x, 0.05, 10.0 + dz), r)
        if i < 4:
            counter(sc, f"VisitDivider{i}", (x + 1.6, 0, 10.0), (0.08, 2.6, 2.2), "interior_plaster")
    for i, x in enumerate((20.0, 30.0)):
        inst(sc, f"VisitLamp{i}", I + "ceiling_lamp.tscn", (x, 3.38, 10.0))

    # --- Release desk next to the gate (inside the wall, west): a booth with a counter.
    counter(sc, "DeskBoothBack", (-7, 0, 11), (6, 3, 0.2), "plaster")
    counter(sc, "DeskBoothSide", (-10, 0, 13), (0.2, 3, 4), "plaster")
    counter(sc, "DeskBoothRoof", (-7, 3, 13), (6.4, 0.2, 4.4), "roof_dark")
    counter(sc, "DeskCounter", (-7, 0, 13.6), (3.0, 1.05, 0.6), "planks")
    shopkeeper(sc, "DeskGuard", (-7, 0, 12.4), "Officer Daems", "release desk", "", [], 5, 77,
               {"script": sc.script(S["intro_npc"]), "role": q("desk")})
    marker(sc, "DeskSpot", (-7, 0.1, 15.0), 0)
    sc.node("DeskSign", "Label3D", ".", props={
        "transform": xform((-7, 2.6, 15.25)), "text": q("RELEASE"), "font_size": "64", "pixel_size": "0.006",
        "outline_size": "8", "modulate": col(1.0, 0.85, 0.3)})

    # --- Watchtowers in the four corners + a guard at the gate.
    for i, (x, z, r) in enumerate([(-37, -29, 0), (37, -29, 0), (-37, 17, 180), (37, 17, 180)]):
        sc.node(f"Watchtower{i + 1}", "StaticBody3D", ".", props={"script": sc.script(S["watchtower"]),
                "transform": xform((x, 0, z), r), "height": "7.0", "tint": col(0.55, 0.55, 0.52)})
    shopkeeper(sc, "GateGuard", (3.6, 0, 18.6), "Guard", "gate", "", [], 5, 91,
               {"script": sc.script(S["intro_npc"]), "role": q("guard")})
    for i, (x, z) in enumerate([(-30, 12), (30, 0), (-30, -8), (-14, 6), (8, 35.5)]):  # (49b: last one off the road)
        inst(sc, f"Flood{i}", P + "floodlight_pole.tscn", (x, 0, z), 0)
    # Outside the gate: the road stub and the bus (door on its gate side).
    counter(sc, "BusRoad", (0, 0, 28), (60, 0.03, 7), "asphalt")
    sc.node("Bus", "StaticBody3D", ".", props={
        "script": sc.script(S["proc_bus"]), "transform": xform((0, 0, 27.6), 90), "boardable": "true"})
    marker(sc, "BusSpot", (0, 0.1, 25.2), 0)
    save(sc, B + "prison.tscn")


prison()


# Point 100: Fort Halden's buildings you can walk into (origin = the middle of the front wall at the ground, the
# building lies behind it towards -Z, the door faces +Z - the same frame as the warehouse Buildings they replace, so
# session B's soldier posts and alarm spots stay where they were).
def army_sign(sc, name, text, pos):
    sc.node(name, "Label3D", ".", props={"transform": xform(pos), "text": q(text), "font_size": "56",
            "pixel_size": "0.006", "outline_size": "8", "modulate": col(0.95, 0.9, 0.7)})


def army_barracks():
    """16 x 8 m dormitory: 8 bunk beds, a locker row, a table, windows front and back."""
    sc = Scene()
    sc.node("Barracks", "Node3D")
    openings = [("S", 0.0, 1.4)] + [("S", x, 1.2, 2.2, 1.1) for x in (-5.0, 5.0)]
    openings += [("N", x, 1.2, 2.2, 1.1) for x in (-5.5, -1.8, 1.8, 5.5)]
    hall(sc, "B", -8.0, 8.0, -8.0, 0.0, 3.2, openings, wall="plaster", floor="planks")
    for i, x in enumerate((-6.8, -4.6, -2.4, 2.4, 4.6, 6.8)):
        aprop(sc, f"Bunk{i}", "bunk", (x, 0.02, -6.7))
    for i, x in enumerate((-6.8, 6.8)):
        aprop(sc, f"BunkF{i}", "bunk", (x, 0.02, -2.4))
    aprop(sc, "Lockers", "lockers", (0.0, 0.02, -7.5), 0, length=3.0)
    counter(sc, "Table", (0.0, 0, -3.8), (2.4, 0.78, 1.0), "planks")
    for j, dz in enumerate((-0.8, 0.8)):
        inst(sc, f"Stool{j}", I + "stool.tscn", (0.0, 0.02, -3.8 + dz), 0)
    for i, x in enumerate((-4.0, 4.0)):
        inst(sc, f"Lamp{i}", I + "ceiling_lamp.tscn", (x, 3.18, -4.0))
    army_sign(sc, "Sign", "BARRACKS", (0.0, 2.6, 0.2))
    save(sc, "prefabs/army/barracks.tscn")


def army_armoury():
    """12 x 10 m: weapon racks along the walls, a caged issue counter, ammo crate stacks."""
    sc = Scene()
    sc.node("Armoury", "Node3D")
    hall(sc, "A", -6.0, 6.0, -10.0, 0.0, 3.4, [("S", 0.0, 1.6)], wall="concrete", floor="concrete")
    for i, (x, z, r, ln) in enumerate([(-5.6, -5.0, 90, 7.0), (5.6, -5.0, -90, 7.0), (0.0, -9.6, 0, 8.0)]):
        aprop(sc, f"Rack{i}", "rack", (x, 0.02, z), r, length=ln)
    bars(sc, "CageL", (-5.85, 0, -3.0), 4.35, 3.4)
    bars(sc, "CageR", (1.5, 0, -3.0), 4.35, 3.4)
    counter(sc, "IssueCounter", (0.0, 0, -3.0), (3.0, 1.0, 0.6), "metal_dark")
    for i, (x, z) in enumerate([(-3.5, -6.5), (-1.8, -6.5), (2.0, -7.0), (3.6, -6.2)]):
        aprop(sc, f"Ammo{i}", "ammo", (x, 0.02, z), 0)
    for i, x in enumerate((-3.0, 3.0)):
        inst(sc, f"Lamp{i}", I + "ceiling_lamp.tscn", (x, 3.38, -6.0))
    army_sign(sc, "Sign", "ARMOURY", (0.0, 2.7, 0.2))
    save(sc, "prefabs/army/armoury.tscn")


def army_command():
    """14 x 10 m command post: map table, desks with screens, a radio wall, windows all round."""
    sc = Scene()
    sc.node("CommandPost", "Node3D")
    hall(sc, "C", -7.0, 7.0, -10.0, 0.0, 3.4, [("S", 0.0, 1.6), ("S", -4.0, 2.2, 2.3, 1.0), ("S", 4.0, 2.2, 2.3, 1.0),
         ("W", -5.0, 2.5, 2.3, 1.0), ("E", -5.0, 2.5, 2.3, 1.0)], wall="plaster", floor="floor_tiles")
    aprop(sc, "MapTable", "map", (0.0, 0.02, -5.0), 0)
    for i, x in enumerate((-4.5, -2.5, 2.5, 4.5)):
        inst(sc, f"Desk{i}", I + "office_desk.tscn", (x, 0.02, -8.9), 0)
        counter(sc, f"Screen{i}", (x, 0.78, -9.3), (0.8, 0.5, 0.06), "car_headlight")
        inst(sc, f"Chair{i}", I + "dining_chair.tscn", (x, 0.02, -8.0), 180)
    for i, z in enumerate((-2.0, -3.2)):
        aprop(sc, f"Radio{i}", "radio", (6.4, 0.02, z), -90)
    counter(sc, "WallMap", (-6.8, 1.0, -8.0), (0.05, 1.4, 2.4), "trim_paint")
    for i, x in enumerate((-3.0, 3.0)):
        inst(sc, f"Lamp{i}", I + "ceiling_lamp.tscn", (x, 3.38, -5.0))
    army_sign(sc, "Sign", "COMMAND POST", (0.0, 2.7, 0.2))
    marker(sc, "CommandSpot", (0.0, 0.1, -3.4), 0)
    save(sc, "prefabs/army/command_post.tscn")


def army_hangar():
    """20 x 14 m vehicle hangar, open front (12 x 6 m gap): a truck inside, workbench, shelves, oil drums."""
    sc = Scene()
    sc.node("ArmyHangar", "Node3D")
    hall(sc, "H", -10.0, 10.0, -14.0, 0.0, 7.5, [("S", 0.0, 12.0, 6.0), ("E", -10.0, 1.2)], roof="roof_dark",
         wall="corrugated", floor="concrete")
    inst(sc, "Truck", "prefabs/army/army_truck.tscn", (-3.0, 0.02, -7.5), 0, {"kind": q("truck")})
    counter(sc, "Workbench", (6.5, 0, -13.3), (4.0, 0.9, 0.9), "metal_dark")
    inst(sc, "ToolCart", I + "tool_cart.tscn", (4.2, 0.02, -12.2), 0)
    inst(sc, "Shelves1", I + "steel_shelves.tscn", (-9.4, 0.02, -11.0), 90)
    inst(sc, "Shelves2", I + "steel_shelves.tscn", (-9.4, 0.02, -8.5), 90)
    for i, (x, z) in enumerate([(8.8, -9.0), (8.8, -8.2), (8.0, -8.6)]):
        inst(sc, f"Drum{i}", P + "barrel.tscn", (x, 0.02, z), 0)
    aprop(sc, "Ammo", "ammo", (5.0, 0.02, -9.0), 0)
    for i, x in enumerate((-5.0, 5.0)):
        inst(sc, f"Lamp{i}", I + "hanging_lamp.tscn", (x, 6.0, -7.0))
    save(sc, "prefabs/army/hangar.tscn")


def army_sandbags():
    """A straight sandbag wall (3 m, 4 rows) for gen_world to place."""
    sc = Scene()
    sc.node("Sandbags", "StaticBody3D", props={"script": sc.script(S["army_prop"]), "kind": "2", "length": "3",
            "rows": "4"})
    save(sc, "prefabs/army/sandbags.tscn")


army_barracks()
army_armoury()
army_command()
army_hangar()
army_sandbags()


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
