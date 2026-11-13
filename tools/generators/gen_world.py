"""Generates res://scenes/world/world.tscn from prefabs (milestone 1 test map).
Usage: python gen_world2.py <project root>"""
import random
import sys
from tscn import Scene, v3, col, xform
from palette_tint import ptint, pcol, MATERIAL_SWATCH  # point 27: colours from the palette

ROOT = sys.argv[1].rstrip("/\\") + "/"
rng = random.Random(42)
# Colours use their own random stream: the layout (rng) stays exactly the same.
crng = random.Random(27)
sc = Scene()

PF = "res://prefabs/"
NAV = "NavRegion"
counter = {}


def uname(base):
    counter[base] = counter.get(base, 0) + 1
    return f"{base}{counter[base]}"


def put(prefab, pos, rot=0.0, parent=NAV, name=None, props=None, scale=1.0):
    p = {"transform": xform(pos, rot, scale)}
    p.update(props or {})
    base = name or prefab.split("/")[-1].replace(".tscn", "").title().replace("_", "")
    nm = name if name else uname(base)
    sc.node(nm, None, parent, instance=PF + prefab, props=p)
    return nm


def q(s):
    return f'"{s}"'


# --------------------------------------------------------------------------- root
sc.node("World", "Node3D", props={"script": sc.script("res://scenes/world/world.gd")})
sc.node("SunAndSky", None, ".", instance=PF + "environment/sun_and_sky.tscn")

navmesh = sc.subres("NavigationMesh", {
    "geometry_parsed_geometry_type": "1", "geometry_collision_mask": "1",
    "cell_size": "0.1", "cell_height": "0.1",
    "agent_height": "1.8", "agent_radius": "0.25", "agent_max_climb": "0.3",
    "filter_baking_aabb": "AABB(-74, -2, -62, 148, 20, 130)"})
sc.node(NAV, "NavigationRegion3D", ".", props={"navigation_mesh": navmesh})

# Ground everywhere (grass/dirt shader) + an outer ring without collision.
ground_mat = sc.res("Material", "res://prefabs/materials/ground.tres")
sc.node("Ground", "StaticBody3D", NAV, props={
    "script": sc.script("res://scripts/procgen/ground_area.gd"), "transform": xform((0, 0, 3)),
    "size": "Vector2(150, 132)", "material": ground_mat})
sc.node("OuterGround", "StaticBody3D", ".", props={
    "script": sc.script("res://scripts/procgen/ground_area.gd"), "transform": xform((0, -0.02, 3)),
    "size": "Vector2(1000, 1000)", "collision": "false", "material": ground_mat})
# Point 27: the edge of the world = tree rows, bushes and two rings of soft hills (no empty plane).
sc.node("Backdrop", "Node3D", ".", props={
    "script": sc.script("res://scripts/procgen/backdrop.gd"), "area": "Rect2(-75, -60, 150, 132)",
    "tree_margin": "9.0", "hill_distance": "45.0", "ground_plane": "false"})

# --------------------------------------------------------------------------- roads
R = "roads/"
for x in range(-66, 67, 12):
    if x == -6:
        put(R + "road_t_junction.tscn", (x, 0, 0))
    elif x == 30:
        put(R + "road_crossing.tscn", (x, 0, 0))
    elif x in (-30, 6):  # mid-block zebra crossings (Starter Room, Store)
        put(R + "road_straight.tscn", (x, 0, 0), props={"crossing": "true"})
    else:
        put(R + "road_straight.tscn", (x, 0, 0))
for z in (-12, -24, -36):
    put(R + "road_straight.tscn", (-6, 0, z), 90)
    put(R + "road_straight.tscn", (30, 0, z), 90)
put(R + "road_curve.tscn", (-6, 0, -48), 90)          # south <-> east
put(R + "road_t_junction.tscn", (30, 0, -48), 180)     # W, E, branch south
for x in (6, 18, 42, 54, 66):
    put(R + "road_straight.tscn", (x, 0, -48))
for z in range(12, 49, 12):
    put(R + "road_straight.tscn", (30, 0, z), 90)
# Point 8: South Street branches west off the side road at z 60 (dead end at x -60).
put(R + "road_t_junction.tscn", (30, 0, 60), 90)
for x in range(-54, 19, 12):
    put(R + "road_straight.tscn", (x, 0, 60), 0, props={"crossing": "true"} if x == -30 else None)

# Road ends: barriers at the map edge.
for x, z, r in [(-71, -1.8, 90), (-71, 1.8, 90), (71, -1.8, 90), (71, 1.8, 90), (71, -49.8, 90), (71, -46.2, 90),
                (28.2, 65, 0), (31.8, 65, 0), (-59.6, 58.2, 90), (-59.6, 61.8, 90)]:
    put("props/road_barrier.tscn", (x, 0, z), r)

# Manholes
for x, z in [(-48, 1.6), (-20, -1.7), (12, 1.5), (46, -1.6), (30, 20), (12, -48.5)]:
    put("props/manhole.tscn", (x, 0.0, z), rng.uniform(0, 90))

# --------------------------------------------------------------------------- houses
HOUSE_W = {"a": 6.0, "b": 5.2, "c": 7.2, "d": 5.6, "e": 6.6, "f": 4.8}
WALLS = ["brick_old", "brick_mixed", "brick_yellow", "brick_white", "plaster"]
PLASTER_TINTS = [ptint("plaster", s) for s in ["plaster_cream", "plaster_green", "plaster_pink", "plaster_blue", "brick_white"]]
DOORS = [pcol(s) for s in ["door_green", "door_red", "door_blue", "trim_dark", "accent_blue", "wood_dark", "roof_slate"]]
ROOFS = [("roof_red", "roof_red"), ("roof_dark", "roof_dark"), ("roof_dark", "roof_slate")]
last_type = [None]


def house(x0, front_z, facing_road_south, max_x, gardens):
    """Place one random row house starting at x0. Returns its right edge."""
    kinds = [k for k in "abcdef" if k != last_type[0]]
    k = rng.choice(kinds)
    last_type[0] = k
    w = HOUSE_W[k]
    if x0 + w > max_x or max_x - (x0 + w) < 4.6:
        w = max_x - x0  # stretch the last one to fill the gap
    cx = x0 + w / 2
    rot = (0 if facing_road_south else 180) + rng.uniform(-0.35, 0.35)
    jitter = rng.uniform(-0.06, 0.08)
    z = front_z + (-jitter if facing_road_south else jitter)
    props = {"width": f"{w:.2f}", "variation_seed": str(rng.randint(1, 9999)),
             "door_color": rng.choice(DOORS)}
    if rng.random() < 0.45:
        wm = rng.choice(WALLS)
        props["wall_material"] = q(wm)
        props["wall_tint"] = rng.choice(PLASTER_TINTS) if wm == "plaster" else ptint(wm, MATERIAL_SWATCH[wm], rng.uniform(0.92, 1.04))
    if crng.random() < 0.5:
        rm, rs = crng.choice(ROOFS)
        props["roof_material"] = q(rm)
        props["roof_tint"] = ptint(rm, rs)
    if rng.random() < 0.3:
        props["floors"] = str(rng.choice([2, 3]))
    put(f"buildings/row_house_{k}.tscn", (cx, 0, z), rot, props=props)
    gardens.append((x0, x0 + w))
    return x0 + w


def row(x_start, x_end, front_z, facing_south, gardens):
    x = x_start
    while x < x_end - 0.5:
        x = house(x, front_z, facing_south, x_end, gardens)


def fixed(prefab, x0, w, front_z, facing_south, gardens, props=None, name=None):
    rot = 0 if facing_south else 180
    put(prefab, (x0 + w / 2, 0, front_z), rot, props=props, name=name)
    gardens.append((x0, x0 + w))
    return x0 + w


def garden_fences(gardens, z_from, z_to, back_fence=True):
    """Board fences between back gardens (along Z) and along the back."""
    sign = -1 if z_to < z_from else 1
    rot = 90 if sign < 0 else -90
    length = abs(z_to - z_from)
    for (a, b) in gardens[1:]:
        put("props/garden_fence.tscn", (a, 0, z_from), rot, props={"length": f"{length:g}"})
    if back_fence:
        x0, x1 = gardens[0][0], gardens[-1][1]
        x = x0
        while x < x1 - 0.1:
            seg = min(8.0, x1 - x)
            put("props/garden_fence.tscn", (x, 0, z_to), 0, props={"length": f"{seg:g}"})
            x += seg


def garden_dressing(gardens, z_from, z_to):
    lo, hi = min(z_from, z_to), max(z_from, z_to)
    for (a, b) in gardens:
        r = rng.random()
        cx = (a + b) / 2
        if r < 0.35:
            put("nature/tree_medium.tscn", (rng.uniform(a + 1.5, b - 1.5), 0, rng.uniform(lo + 4, hi - 3)),
                rng.uniform(0, 360), props={"tree_seed": str(rng.randint(1, 999))})
        elif r < 0.7:
            put(f"nature/shrub_{rng.choice('abcd')}.tscn", (rng.uniform(a + 1, b - 1), 0, rng.uniform(lo + 3, hi - 1.5)),
                rng.uniform(0, 360))
        if rng.random() < 0.4:
            put("nature/hedge.tscn", (cx, 0, hi - 0.8 if z_to > z_from else lo + 0.8), 0,
                props={"size": v3(b - a - 0.6, 1.3, 0.7), "hedge_seed": str(rng.randint(1, 99))})
        if rng.random() < 0.3:
            put("props/trash_can_rusty.tscn" if rng.random() < 0.5 else "props/trash_can.tscn",
                (a + 0.7, 0, (z_from + (1.2 if z_to > z_from else -1.2))), rng.uniform(0, 360))


GRASS_HOLES = [(-38.5, 21.8, -33.0, 27.8), (-36.1, 5.0, -32.9, 22.0)]  # world x0, z0, x1, z1


def grass(cx, cz, sx, sz, seed):
    """Grass split into tiles of at most 15 m so distance culling works."""
    import math
    nx, nz = math.ceil(sx / 15), math.ceil(sz / 15)
    tx, tz = sx / nx, sz / nz
    for ix in range(nx):
        for iz in range(nz):
            x = cx - sx / 2 + tx * (ix + 0.5)
            z = cz - sz / 2 + tz * (iz + 0.5)
            holes = []
            for (hx0, hz0, hx1, hz1) in GRASS_HOLES:
                if hx1 > x - tx / 2 and hx0 < x + tx / 2 and hz1 > z - tz / 2 and hz0 < z + tz / 2:
                    holes.append(f"Rect2({hx0 - x:g}, {hz0 - z:g}, {hx1 - hx0:g}, {hz1 - hz0:g})")
            props = {"transform": xform((x, 0, z)), "size": f"Vector2({tx:g}, {tz:g})",
                     "field_seed": str(seed * 100 + ix * 10 + iz)}
            if holes:
                props["holes"] = "Array[Rect2]([" + ", ".join(holes) + "])"
            sc.node(uname("Grass"), None, ".", instance=PF + "nature/grass_field.tscn", props=props)


# Properties for sale (point 26: spread over the neighbourhoods, never next to the police station).
def property_node(building, pid, title, price, desc, label_x=0.0, label_y=3.4):
    """A Property (for sale) inside an instanced building: ownership, furnishing area, sign."""
    sc.node("Property", "Node3D", NAV + "/" + building, props={
        "transform": xform((label_x, label_y, 0.25)), "script": sc.script("res://scenes/world/property.gd"),
        "property_id": f'&"{pid}"', "display_name": q(title), "for_sale": "true", "price": str(price),
        "description": q(desc)})
    sc.node("Label3D", "Label3D", NAV + "/" + building + "/Property", props={
        "text": q("FOR SALE"), "font_size": "40", "pixel_size": "0.006", "outline_size": "8",
        "modulate": col(1, 0.75, 0.35), "billboard": "0", "double_sided": "false"})


# Block A: north of the main road, west of the side street.
gA = []
row(-72, -60, -6, True, gA)
fixed("buildings/laundromat.tscn", -60, 7.5, -6, True, gA, name="Laundromat")
property_node("Laundromat", "laundromat", "Laundromat", 35000,
              "West End, on the main road. Front business: launders up to €4,000 dirty cash a day (10% fee).", 0.0, 4.6)
row(-52.5, -35, -6, True, gA)
fixed("buildings/starter_room.tscn", -35, 6, -6, True, gA, name="StarterRoom")
row(-29, -19.5, -6, True, gA)
fixed("buildings/corner_house.tscn", -19.5, 7.5, -6, True, gA)
garden_fences(gA, -15.5, -30)
garden_dressing(gA, -15.5, -30)
grass(-42, -23, 60, 14, 1)
# Behind block A: meadow with trees and a hedge line along the gardens.
for i, x in enumerate(range(-68, -14, 9)):
    put("nature/tree_large.tscn" if i % 2 else "nature/tree_medium.tscn",
        (x + rng.uniform(-2, 2), 0, rng.uniform(-50, -38)), rng.uniform(0, 360),
        props={"tree_seed": str(100 + i)})
grass(-42, -45, 56, 26, 2)

# Block B: hospital, parking behind it, houses facing the top road.
gB = []
fixed("buildings/hospital.tscn", 1, 22, -6, True, gB, name="Hospital")
# Pave the 1 m gaps between the hospital and the side-road sidewalks (no sunken grass pockets).
for i, cx in enumerate((0.5, 23.5)):
    sc.node(f"HospitalSidePaving{i + 1}", "StaticBody3D", NAV, props={
        "script": sc.script("res://scripts/procgen/paved_area.gd"), "transform": xform((cx, 0, -13)),
        "size": "Vector2(1, 14)", "surface": q("sidewalk"), "height": "0.15", "edge": "false"})
sc.node("Parking", "StaticBody3D", NAV, props={
    "script": sc.script("res://scripts/procgen/paved_area.gd"), "transform": xform((12, 0, -25)),
    "size": "Vector2(24, 10)", "surface": q("asphalt"), "height": "0.02"})
for i, x in enumerate([2.5, 5.5, 11.0, 17.5, 20.5]):
    put("props/covered_car.tscn", (x, 0.02, -22.6 if i % 2 else -27.4), 180 if i % 2 else 0)
for x in [4.0, 7.0, 10.0, 13.0, 16.0, 19.0]:
    sc.node(uname("ParkLine"), "MeshInstance3D", NAV, props={
        "transform": xform((x + 0.5, 0.03, -25)), "mesh": sc.subres("BoxMesh", {"size": v3(0.1, 0.01, 10)}),
        "material_override": sc.res("Material", "res://prefabs/materials/road_marking.tres")})
gB2 = []
x = 0.5
last_type[0] = None
fixed("buildings/barber.tscn", 0, 6.5, -42, False, gB2, name="Barber")
property_node("Barber", "barber", "Barber Shop", 20000,
              "North Road, behind the hospital. Front business: launders up to €2,500 dirty cash a day (10% fee).",
              0.0, 4.6)
row(6.5, 24, -42, False, gB2)

# Block C: shops on the main road, houses behind.
gC = []
# Point 9: the bakery is a front business (prefab with a back-office safe, sold by Mrs. Vos).
x = fixed("buildings/bakery.tscn", 36.0, 7.0, -6, True, gC, name="Bakery")
SHOPS = [None, ("SNACK BAR", col(0.7, 0.1, 0.08), "plaster")]
for i, (name, c, wm) in list(enumerate(SHOPS))[1:]:
    w = [7.0, 6.5, 6.0][i]
    props = {"width": f"{w:g}", "shop_sign": q(name), "awning_color": c, "wall_material": q(wm),
             "variation_seed": str(200 + i)}
    if wm == "plaster":
        props["wall_tint"] = ptint("plaster", ["plaster_pink", "plaster_cream", "plaster_blue"][i])
    x = fixed("buildings/shop.tscn", x, w, -6, True, gC, props=props)
# Gun shop (Vince sells weapons + ammo).
x = fixed("buildings/gun_shop.tscn", x, 7, -6, True, gC, name="GunShop")
row(x, 72, -6, True, gC)
gC2 = []
row(36, 64.5, -42, False, gC2)
fixed("buildings/corner_house.tscn", 64.5, 7.5, -42, False, gC2, name="FamilyHouse",
      props={"wall_material": q("brick_white"), "variation_seed": "777"})
property_node("FamilyHouse", "family_house", "Family House", 20000,
              "East End, quiet street at the top of town. Three floors, furnished, big rooms.")
garden_fences(gC, -16, -26, back_fence=False)
grass(54, -24, 36, 16, 4)
for x in (40, 52, 64):
    put("nature/tree_medium.tscn", (x + rng.uniform(-2, 2), 0, -26), rng.uniform(0, 360),
        props={"tree_seed": str(300 + x)})

# Block D: south of the main road (fronts face north).
gD1 = []
row(-72, -36, 6, False, gD1)
gD2 = []
row(-33, -20, 6, False, gD2)
fixed("buildings/row_house_b.tscn", -20, 6.0, 6, False, gD2, name="SmallHouse",
      props={"width": "6.0", "floors": "2", "variation_seed": "4242", "door_color": col(0.45, 0.1, 0.1)})
property_node("SmallHouse", "small_house", "Small House", 8000,
              "Old Town, on the square. Two floors, furnished. A step up from the Starter Room.")
garden_fences(gD1, 15.5, 30)
garden_fences(gD2, 15.5, 30)
garden_dressing(gD1, 15.5, 30)
garden_dressing(gD2, 15.5, 30)
grass(-43, 23, 58, 14, 5)

# Contact alley: cobbles between the houses, hideout annex at the end.
sc.node("ContactAlley", "StaticBody3D", NAV, props={
    "script": sc.script("res://scripts/procgen/paved_area.gd"), "transform": xform((-34.5, 0, 14)),
    "size": "Vector2(3, 16)", "surface": q("cobbles"), "height": "0.15"})
put("buildings/contact_hideout.tscn", (-35.75, 0, 22), 180, name="ContactHideout")
put("props/garden_fence.tscn", (-36, 0, 16), -90, props={"length": "6"})
put("props/garden_fence.tscn", (-33, 0, 16), -90, props={"length": "6"})
put("props/trash_can_rusty.tscn", (-35.6, 0.15, 12.5), 20)
put("props/trashbag.tscn", (-35.5, 0.15, 13.4), 40)
put("props/trashbag.tscn", (-35.4, 0.15, 14.0), 160)
put("props/crate_long.tscn", (-33.6, 0.15, 18.5), 5)
put("props/street_lamp.tscn", (-33.35, 0.15, 11.0), 90, name="AlleyLamp")
sc.node("AlleyLight", "OmniLight3D", NAV, props={
    "transform": xform((-34.5, 2.8, 20.5)), "light_color": col(1, 0.75, 0.45), "light_energy": "1.2",
    "omni_range": "7.0"})

# Park / plaza with the customer meet point.
sc.node("Plaza", "StaticBody3D", NAV, props={
    "script": sc.script("res://scripts/procgen/paved_area.gd"), "transform": xform((-4, 0, 12)),
    "size": "Vector2(20, 12)", "surface": q("cobbles"), "height": "0.15"})
grass(-4, 25, 20, 14, 6)
put("nature/tree_large.tscn", (-10.5, 0, 25), 0, props={"tree_seed": "17"})
put("nature/tree_large.tscn", (2.5, 0, 27), 0, props={"tree_seed": "23"})
put("nature/tree_medium.tscn", (-4, 0, 29), 0, props={"tree_seed": "31"})
for x, r in [(-9, 0), (1, 0)]:
    put("props/bench.tscn", (x, 0.15, 16.6), 180)
    put("props/trash_can.tscn", (x + 1.8, 0.15, 16.8), 0)
put("props/bench.tscn", (-12.6, 0.15, 11), 90)
put("props/bench.tscn", (4.6, 0.15, 11), -90)
put("nature/flower_bed.tscn", (-4, 0.15, 17.2), 0, props={"size": "Vector2(5, 1.2)", "bed_seed": "3"})
put("nature/flower_bed.tscn", (-12.6, 0.15, 15.5), 0, props={"size": "Vector2(1.6, 2.4)", "bed_seed": "8"})
put("nature/flower_bed.tscn", (4.6, 0.15, 15.5), 0, props={"size": "Vector2(1.6, 2.4)", "bed_seed": "9"})
for x in (-13, -9, -5, -1, 3):
    put("props/bollard.tscn", (x + 1, 0.15, 6.3))
put("props/bike_rack.tscn", (-11, 0.15, 7.5))
put("props/street_lamp.tscn", (-13.3, 0.15, 7.0), 0)
put("props/street_lamp.tscn", (5.3, 0.15, 7.0), 0)
for x in (-14, 6):
    put("nature/hedge.tscn", (x, 0, 25), 0, props={"size": v3(0.8, 1.2, 14), "hedge_seed": str(x + 50)})

# Store + corner house.
gD3 = []
fixed("buildings/store.tscn", 6, 10, 6, False, gD3, name="Store")
fixed("buildings/corner_house.tscn", 16.5, 7.5, 6, False, gD3,
      props={"wall_material": q("brick_yellow"), "variation_seed": "321", "door_color": col(0.4, 0.1, 0.1)})
put("props/post_box.tscn", (15.5, 0.15, 5.2), 180)
put("props/planter_box.tscn", (7.0, 0.15, 5.4))
put("props/planter_box.tscn", (14.8, 0.15, 5.4))
grass(14, 25, 20, 14, 7)

# Point 7: the garage on the side street (front faces the road at x 30), black market inside.
put("buildings/garage.tscn", (24, 0, 44), 90, name="Garage")
sc.node("GarageApron", "StaticBody3D", NAV, props={
    "script": sc.script("res://scripts/procgen/paved_area.gd"), "transform": xform((22.5, 0, 44)),
    "size": "Vector2(3, 14)", "surface": q("asphalt"), "height": "0.02"})

gS = []
fixed("buildings/warehouse.tscn", -58, 16, 54, True, gS, name="SouthWarehouse")
property_node("SouthWarehouse", "south_warehouse", "Warehouse", 45000,
              "South Street, west end. 16 x 12 m hall, 5.5 m high. Room for a big lab.", 0.0, 4.2)
last_type[0] = None
row(-42, -24, 54, True, gS)
fixed("buildings/real_estate.tscn", -24, 8.0, 54, True, gS, name="RealEstate")
property_node("Bakery", "bakery", "Bakery", 12000,
              "Shop row on the main road. Front business: launders up to €1,500 dirty cash a day (10% fee).", 0.0, 4.6)
row(-16, -1.5, 54, True, gS)
# Point 10: the police station (officers patrol from here; the patrol car drives route 3).
fixed("buildings/police_station.tscn", -1.5, 12.0, 54, True, gS, name="PoliceStation")
for x in (-50, -26, -2, 22):
    put("props/street_lamp.tscn", (x, 0.15, 56.05), 180)

# Block E: Rival Turf (The Black Crows).
sc.node("TurfYard", "StaticBody3D", NAV, props={
    "script": sc.script("res://scripts/procgen/paved_area.gd"), "transform": xform((50, 0, 27)),
    "size": "Vector2(24, 38)", "surface": q("concrete"), "height": "0.05"})
# Fence: north side with a gate at x 48..50, then west, east, south.
for x in range(38, 62, 2):
    if x == 48:
        put("props/chainlink_gate_frame.tscn", (49, 0.05, 8))
        continue
    put("props/chainlink_fence.tscn", (x, 0.05, 8))
for z in range(8, 46, 2):
    put("props/chainlink_fence.tscn", (38, 0.05, z), -90)
    put("props/chainlink_fence.tscn", (62, 0.05, z), -90)
for x in range(38, 62, 2):
    put("props/chainlink_fence.tscn", (x, 0.05, 46))
put("buildings/warehouse.tscn", (50, 0.05, 32), 180, name="Warehouse")
# Point 11: the Black Crows' house in their yard, front to the gate (they come out here at night).
put("buildings/crows_house.tscn", (55.75, 0.05, 17), 180, name="CrowsHouse")
put("props/container_12m.tscn", (41.6, 0.05, 22), 90, props={"color": col(0.55, 0.12, 0.08)})
put("props/container_6m.tscn", (45.5, 0.05, 13.5), 0, props={"color": col(0.12, 0.3, 0.5)})
put("props/container_6m.tscn", (45.5, 2.66, 13.5), 3, props={"color": col(0.15, 0.4, 0.2)})
put("props/container_6m.tscn", (60.0, 0.05, 38), 90, props={"color": col(0.6, 0.45, 0.1)})
sc.node("Graffiti", "Label3D", NAV, props={
    "transform": xform((45.5, 1.6, 12.27), 0), "text": q("BLACK CROWS"), "font_size": "96",
    "pixel_size": "0.012", "modulate": col(0.85, 0.85, 0.85, 0.9), "outline_size": "0", "double_sided": "false"})
for pos, rot, pf in [((53, 0.05, 11), 10, "crate_long"), ((53.6, 0.05, 11.9), 80, "crate_long"),
                     ((53.2, 0.51, 11.3), 20, "crate_flat"), ((40.2, 0.05, 32.6), 0, "barrel"),
                     ((40.9, 0.05, 33.3), 0, "barrel"), ((40, 0.05, 30), 0, "barrel"),
                     ((44, 0.05, 28), 30, "crate_long"), ((51, 0.05, 15.5), 0, "trash_can_rusty"),
                     ((47, 0.05, 10), 0, "road_barrier"), ((51.2, 0.05, 10), 0, "road_barrier"),
                     ((59, 0.05, 30), 0, "utility_box")]:
    put(f"props/{pf}.tscn", pos, rot)
for x in (44, 56):
    put("props/floodlight_pole.tscn", (x, 0.05, 30.9), 180)
for z in (12, 24, 36):
    put("nature/tree_medium.tscn", (66 + rng.uniform(-1, 1), 0, z + rng.uniform(-2, 2)), rng.uniform(0, 360),
        props={"tree_seed": str(400 + z)})
grass(67, 30, 8, 50, 8)
for z in (52, 58):
    put("nature/tree_large.tscn", (46 + z % 7, 0, z), 0, props={"tree_seed": str(z)})

# --------------------------------------------------------------------------- street furniture
for x in (-60, -36, -12, 12, 42, 60):
    put("props/street_lamp.tscn", (x, 0.15, -3.95), 180)
for x in (-48, -24, 24, 48):
    put("props/street_lamp.tscn", (x, 0.15, 3.95), 0)
# Street trees on the party walls between two houses (never in front of a front door).
_walls = sorted({e for g in (gD1, gD2) for (a, b) in g for e in (a, b)})
for x in (-66, -54, -18):
    tx = min(_walls, key=lambda e: abs(e - x))
    put("nature/tree_street.tscn", (tx, 0.15, 4.9), rng.uniform(0, 360), props={"tree_seed": str(500 + x)})
for z in (-18, -30):
    put("props/street_lamp.tscn", (-9.95, 0.15, z), 90)
    put("props/street_lamp.tscn", (26.05, 0.15, z), 90)
for z in (18, 42):
    put("props/street_lamp.tscn", (26.05, 0.15, z), 90)
# Point 33: lamps on BOTH sides of every street (no rng: the layout stays the same).
for z in (-18, -30):
    put("props/street_lamp.tscn", (-2.05, 0.15, z), -90)
    put("props/street_lamp.tscn", (33.95, 0.15, z), -90)
for z in (18, 42):
    put("props/street_lamp.tscn", (33.95, 0.15, z), -90)
# North Road (z -48, barber's street): north side on the party walls (never before a door), south side free.
_nwalls = sorted({e for g in (gB2, gC2) for (a, b) in g for e in (a, b)})
for x in (12, 42, 58):
    put("props/street_lamp.tscn", (min(_nwalls, key=lambda e: abs(e - x)), 0.15, -44.05), 0)
for x in (0, 18, 48, 64):
    put("props/street_lamp.tscn", (x, 0.15, -51.95), 180)
# South Street: the south side too.
for x in (-38, -14, 10):
    put("props/street_lamp.tscn", (x, 0.15, 63.95), 0)
put("props/sign_post.tscn", (-12.6, 0.15, -3.72), 0, props={"sign_text": q("MILL LANE")})
put("props/sign_post.tscn", (23.5, 0.15, -3.72), 0, props={"sign_text": q("STATION ROAD")})
put("props/sign_post.tscn", (-0.6, 0.15, -3.72), 180, props={"sign_text": q("MAIN STREET")})
put("props/utility_box.tscn", (-11.2, 0.15, -5.4), 0)
put("props/utility_box.tscn", (25.0, 0.15, 5.4), 180)
# Between the shop doors (bakery door x 37.2, snack bar 44.1, gun shop 53).
for x in (39.8, 41.6, 50.0):
    put("props/bike_rack.tscn" if x == 41.6 else "props/trash_can.tscn", (x, 0.15, -5.2), 0)
put("props/bench.tscn", (56, 0.15, -5.45), 0)  # faces the street
for x in (2.0, 4.0, 20.0, 22.0):
    put("props/bollard.tscn", (x, 0.15, -3.8))
put("props/post_box.tscn", (-44.5, 0.15, -5.4), 0)
put("props/trashbag.tscn", (-52.3, 0.15, -5.6), 30)
put("props/trashbag.tscn", (-52.8, 0.15, -5.5), 120)
for x in (-23, 64):
    put("props/aircon.tscn", (x, 3.2, -14.9), 180)

# Map edge: tree line outside the playable area.
for i in range(26):
    x = -72 + i * 5.8
    put("nature/tree_large.tscn" if i % 3 == 0 else "nature/tree_medium.tscn",
        (x + rng.uniform(-1.5, 1.5), 0, -58 + rng.uniform(-2, 2)), rng.uniform(0, 360),
        props={"tree_seed": str(600 + i)})
    if i % 2 == 0:
        tx, tz, tr = x + rng.uniform(-1.5, 1.5), 63 + rng.uniform(-2, 2), rng.uniform(0, 360)
        if not -62 < tx < 37:  # South Street runs there (z 54..66)
            put("nature/tree_medium.tscn", (tx, 0, tz), tr, props={"tree_seed": str(700 + i)})
for i in range(18):
    z = -50 + i * 6.5
    if abs(z) < 8 or abs(z + 48) < 8:
        continue
    put("nature/tree_medium.tscn", (-75 + rng.uniform(-1, 1), 0, z), rng.uniform(0, 360),
        props={"tree_seed": str(800 + i)})

# --------------------------------------------------------------------------- invisible walls
sc.node("Bounds", "StaticBody3D", ".")
for name, pos, size in [("N", (0, 5, -61), (150, 10, 1)), ("S", (0, 5, 67), (150, 10, 1)),
                        ("W", (-72.5, 5, 3), (1, 10, 130)), ("E", (72.5, 5, 3), (1, 10, 130))]:
    sc.node("Wall" + name, "CollisionShape3D", "Bounds", props={
        "transform": xform(pos), "shape": sc.subres("BoxShape3D", {"size": v3(*size)})})

# Keep NPCs away from the invisible map-edge walls (no rubbing along them). W/E stop at 71.6:
# the edge houses reach x = +-72 and their stairs must stay on the navmesh.
for name, (x0, z0, x1, z1) in [("N", (-74, -62, 74, -58.5)), ("S", (-74, 64.5, 74, 68)),
                               ("W", (-74, -62, -71.6, 68)), ("E", (71.6, -62, 74, 68))]:
    sc.node("EdgeNoWalk" + name, "NavigationObstacle3D", NAV, props={
        "transform": xform((0, -1, 0)), "height": "4.0", "avoidance_enabled": "false",
        "affect_navigation_mesh": "true", "carve_navigation_mesh": "true",
        "vertices": f"PackedVector3Array({x0}, 0, {z0}, {x1}, 0, {z0}, {x1}, 0, {z1}, {x0}, 0, {z1})"})

# --------------------------------------------------------------------------- markers
sc.node("Markers", "Node3D", ".")
sc.node("SpawnPoints", "Node3D", "Markers")
for i, x in enumerate([10, 12, 14, 16]):
    sc.node(f"Spawn{i + 1}", "Marker3D", "Markers/SpawnPoints", props={"transform": xform((x, 0.3, -4.6), 90)})
sc.node("CustomerSpawn", "Marker3D", "Markers", props={"transform": xform((68, 0.15, 4.8))})
sc.node("CustomerMeetPoint", "Marker3D", "Markers", props={"transform": xform((-4, 0.15, 12.5))})



def debug_label(parent, text):
    """Marker label: visible in the editor, hidden in game (F3 toggles it)."""
    sc.node("DebugLabel", "Label3D", parent, groups=["debug_only"], props={
        "transform": xform((0, 2.2, 0)), "billboard": "1", "text": q(text), "font_size": "40",
        "outline_size": "12", "modulate": col(1, 0.95, 0.75), "no_depth_test": "true"})


debug_label("Markers/CustomerMeetPoint", "MEET POINT")
debug_label("Markers/CustomerSpawn", "CUSTOMER SPAWN")
sc.node("RivalPatrol", "Node3D", "Markers")
for i, (x, z) in enumerate([(42, 12), (58, 12), (58, 28), (42, 28)]):
    sc.node(f"P{i + 1}", "Marker3D", "Markers/RivalPatrol", props={"transform": xform((x, 0.05, z))})
    debug_label(f"Markers/RivalPatrol/P{i + 1}", f"PATROL P{i + 1}")
for i in range(4):
    debug_label(f"Markers/SpawnPoints/Spawn{i + 1}", f"SPAWN {i + 1}")

# --------------------------------------------------------------------------- NPCs
# Host spawns pedestrians under NPCs; the spawner replicates them to clients.
sc.node("NPCs", "Node3D", ".")
sc.node("NPCSpawner", "MultiplayerSpawner", ".", props={
    "_spawnable_scenes": 'PackedStringArray("res://prefabs/npc/pedestrian.tscn", "res://prefabs/npc/police_officer.tscn", "res://prefabs/npc/rival.tscn")',
    "spawn_path": 'NodePath("../NPCs")'})

# --------------------------------------------------------------------------- traffic
# AI cars (host drives them along the Traffic routes; CarSpawner replicates them).
sc.node("Traffic", "Node3D", ".", props={"script": sc.script("res://scripts/traffic/traffic.gd")})
sc.node("CarSpawner", "MultiplayerSpawner", ".", props={
    "_spawnable_scenes": 'PackedStringArray("res://prefabs/vehicles/car.tscn")',
    "spawn_path": 'NodePath("../Traffic")'})

# --------------------------------------------------------------------------- players
# Host spawns one Player per peer under Players (World._create_player is the spawn function).
sc.node("Players", "Node3D", ".")
sc.node("PlayerSpawner", "MultiplayerSpawner", ".", props={"spawn_path": 'NodePath("../Players")'})

# --------------------------------------------------------------------------- loot
# Loot bags dropped on death (World._create_loot_bag is the spawn function).
sc.node("Loot", "Node3D", ".")
sc.node("LootSpawner", "MultiplayerSpawner", ".", props={"spawn_path": 'NodePath("../Loot")'})

# --------------------------------------------------------------------------- placed stations + furniture
# Point 6: things the crew placed in their properties (World._create_placed is the spawn function).
sc.node("Placed", "Node3D", ".")
sc.node("PlacedSpawner", "MultiplayerSpawner", ".", props={"spawn_path": 'NodePath("../Placed")'})

# --------------------------------------------------------------------------- HUD
sc.node("HUD", "CanvasLayer", ".")
sc.node("Panel", "PanelContainer", "HUD", props={
    "offset_left": "12.0", "offset_top": "12.0", "offset_right": "332.0", "offset_bottom": "60.0"})
sc.node("VBox", "VBoxContainer", "HUD/Panel", props={"layout_mode": "2"})
for nm in ("InfoLabel", "PlayersLabel"):
    sc.node(nm, "Label", "HUD/Panel/VBox", props={"unique_name_in_owner": "true", "layout_mode": "2"})
sc.node("LeaveButton", "Button", "HUD/Panel/VBox", props={
    "unique_name_in_owner": "true", "layout_mode": "2", "text": q("Leave to menu")})

sc.save(ROOT + "scenes/world/world.tscn")
print("world.tscn written,", len(sc.nodes), "nodes")
