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


# Point 52: random row houses replaced by a fixed building. Their rng calls and names still happen (so every
# other house keeps its look and name); only the node is left out.
SKIP_NODES = {"RowHouseB5", "RowHouseC3",
              # Point 48 (fuel): the gas station north of North Road (x 34..56) replaces these trees + one lamp.
              "TreeMedium30", "TreeMedium31", "TreeLarge13", "TreeMedium32", "StreetLamp34"}


def put(prefab, pos, rot=0.0, parent=NAV, name=None, props=None, scale=1.0):
    p = {"transform": xform(pos, rot, scale)}
    p.update(props or {})
    base = name or prefab.split("/")[-1].replace(".tscn", "").title().replace("_", "")
    nm = name if name else uname(base)
    if nm in SKIP_NODES:
        return nm
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
    "filter_baking_aabb": "AABB(-194, -2, -134, 268, 20, 240)"})
sc.node(NAV, "NavigationRegion3D", ".", props={"navigation_mesh": navmesh})

# Ground everywhere (grass/dirt shader) + an outer ring without collision.
ground_mat = sc.res("Material", "res://prefabs/materials/ground.tres")
sc.node("Ground", "StaticBody3D", NAV, props={
    "script": sc.script("res://scripts/procgen/ground_area.gd"), "transform": xform((0, 0, 3)),
    "size": "Vector2(150, 132)", "material": ground_mat})
# Point 47: the outer ground leaves the sea free (south of the quay, west of x -74).
sc.node("OuterGround", "StaticBody3D", ".", props={
    "script": sc.script("res://scripts/procgen/ground_area.gd"), "transform": xform((0, -0.02, -196.5)),
    "size": "Vector2(1000, 601)", "collision": "false", "material": ground_mat})
sc.node("OuterGroundSE", "StaticBody3D", ".", props={
    "script": sc.script("res://scripts/procgen/ground_area.gd"), "transform": xform((213, -0.02, 303.5)),
    "size": "Vector2(574, 399)", "collision": "false", "material": ground_mat})
# Point 47: the west side (industrial edge, harbour, countryside) has its own ground with collision.
sc.node("GroundWest", "StaticBody3D", NAV, props={
    "script": sc.script("res://scripts/procgen/ground_area.gd"), "transform": xform((-134, 0, -14)),
    "size": "Vector2(118, 236)", "material": ground_mat})
# Point 27: the edge of the world = tree rows, bushes and two rings of soft hills (no empty plane).
sc.node("Backdrop", "Node3D", ".", props={
    "script": sc.script("res://scripts/procgen/backdrop.gd"), "area": "Rect2(-75, -60, 150, 132)",
    "tree_margin": "9.0", "hill_distance": "45.0", "ground_plane": "false",
    "skip_rects": "Array[Rect2]([Rect2(-600, -600, 524, 1200)])"})  # point 47: the west side has its own
sc.node("BackdropWest", "Node3D", ".", props={
    "script": sc.script("res://scripts/procgen/backdrop.gd"), "area": "Rect2(-193, -133, 120, 238)",
    "tree_margin": "9.0", "hill_distance": "45.0", "ground_plane": "false", "backdrop_seed": "47",
    "skip_rects": "Array[Rect2]([Rect2(-77, -64, 600, 140), Rect2(-600, 104, 640, 600)])"})

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
for x, z, r in [(71, -1.8, 90), (71, 1.8, 90), (71, -49.8, 90), (71, -46.2, 90),
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
# Point 46: park paths (centre x, z, size x, z) and the agora pitch; no grass on them.
PARK_PATHS = [(-7.0, 29.0, 2.2, 22.0), (-1.4, 22.0, 13.4, 2.0), (4.3, 29.5, 2.0, 15.0),
              (1.55, 36.0, 31.1, 2.2), (16.0, 34.25, 2.2, 1.3)]
AGORA_POS = (16.0, 28.0)
for (cx, cz, sx, sz) in PARK_PATHS:
    GRASS_HOLES.append((cx - sx / 2, cz - sz / 2, cx + sx / 2, cz + sz / 2))
GRASS_HOLES.append((AGORA_POS[0] - 9.2, AGORA_POS[1] - 5.7, AGORA_POS[0] + 9.2, AGORA_POS[1] + 5.7))


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
# Point 52: the cover garage where RowHouseB5 + RowHouseC3 stood (x -42..-29.6).
put("buildings/cover_garage.tscn", (-35.8, 0, 54), 0, name="CoverGarage")
property_node("CoverGarage", "cover_garage", "Corner Garage", 25000,
              "South Street. A real car workshop (repairs pay clean money) with a hidden room behind the tool shelf.", -4.2, 4.6)
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
# (Point 45: the two big trees at x 46-49, z 52/58 made way for Carlo's car lot.)

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
        if not -62 < tx < 59:  # South Street runs there (z 54..66), then Carlo's car lot (point 45)
            put("nature/tree_medium.tscn", (tx, 0, tz), tr, props={"tree_seed": str(700 + i)})
for i in range(18):
    z = -50 + i * 6.5
    if abs(z) < 8 or abs(z + 48) < 8:
        continue
    put("nature/tree_medium.tscn", (-75 + rng.uniform(-1, 1), 0, z), rng.uniform(0, 360),
        props={"tree_seed": str(800 + i)})

# --------------------------------------------------------------------------- park + agora (point 46)
# Own random stream: everything above keeps its exact layout.
prng = random.Random(46)
for i, (cx, cz, sx, sz) in enumerate(PARK_PATHS):
    sc.node(f"ParkPath{i + 1}", "StaticBody3D", NAV, props={
        "script": sc.script("res://scripts/procgen/paved_area.gd"), "transform": xform((cx, 0, cz)),
        "size": f"Vector2({sx:g}, {sz:g})", "surface": q("soil"), "height": "0.12", "edge": "false"})
grass(-4, 38.5, 20, 7, 46)
grass(13, 38.5, 14, 6, 47)
# Benches along the paths (rot 90 faces +X, 180 faces -Z), a bin next to each.
for pos, rot in [((-8.75, 0, 24.0), 90), ((-8.75, 0, 28.0), 90), ((-9.0, 0, 37.75), 180),
                 ((0.5, 0, 37.75), 180), ((10.0, 0, 37.75), 180)]:
    put("props/bench.tscn", pos, rot)
    off = (0, 0, 1.6) if rot == 90 else (1.6, 0, 0)
    put("props/trash_can.tscn", (pos[0] + off[0], pos[1], pos[2] + off[2]), prng.uniform(0, 90))
for pos in [(-8.6, 0, 33.5), (3.0, 0, 37.6), (13.0, 0, 37.6), (-5.6, 0, 20.0)]:
    put("props/street_lamp.tscn", pos, 0)
for i, (x, z) in enumerate([(-12.8, 21.0), (0.5, 31.5), (-1.0, 40.0), (8.5, 40.0), (-12.5, 37.5)]):
    put("nature/tree_large.tscn" if i % 2 else "nature/tree_medium.tscn", (x, 0, z), prng.uniform(0, 360),
        props={"tree_seed": str(4600 + i)})
for (x, z) in [(-13.4, 30.2), (-13.2, 34.2), (-10.2, 33.9), (-13.0, 24.5), (5.0, 39.5), (-6.0, 40.5), (-2.5, 24.5)]:
    put(f"nature/shrub_{prng.choice('abcd')}.tscn", (x, 0, z), prng.uniform(0, 360))
put("nature/flower_bed.tscn", (-1.0, 0.0, 27.0), 0, props={"size": "Vector2(3, 1.4)", "bed_seed": "46"})
put("nature/hedge.tscn", (-4, 0, 41.8), 0, props={"size": v3(20, 1.2, 0.8), "hedge_seed": "460"})
# The agora: fenced mini pitch, gate on the park side.
sc.node("Agora", "StaticBody3D", NAV, props={
    "script": sc.script("res://scripts/world/agora.gd"), "transform": xform((AGORA_POS[0], 0, AGORA_POS[1]))})

# --------------------------------------------------------------------------- Carlo's Cars (point 45)
# Car lot east of the side road (x 36..50, z 49.5..63.5) + the sales office (front at x 50, facing the road).
CAR_LOT = (43.0, 56.5, 14.0, 14.0)
sc.node("CarLot", "StaticBody3D", NAV, props={
    "script": sc.script("res://scripts/procgen/paved_area.gd"), "transform": xform((CAR_LOT[0], 0, CAR_LOT[1])),
    "size": f"Vector2({CAR_LOT[2]:g}, {CAR_LOT[3]:g})", "surface": q("concrete"), "height": "0.15", "edge": "false"})
put("buildings/car_dealer.tscn", (50, 0.15, 56), -90, name="CarDealer")
for model, pos, rot in [("hatch", (45.6, 0.15, 51.4), 120), ("sedan", (45.6, 0.15, 61.4), 60)]:
    sc.node(uname("DisplayCar"), "StaticBody3D", NAV, props={
        "script": sc.script("res://scripts/vehicles/display_car.gd"), "transform": xform(pos, rot),
        "model_id": q(model)})
for pos in [(36.6, 0.15, 49.9), (36.6, 0.15, 63.1)]:
    put("props/street_lamp.tscn", pos, 90)
sc.node("CarLotSign", "Label3D", NAV, props={
    "transform": xform((36.4, 2.6, 56.5), -90), "text": q("CARLO'S CARS\nused + new"), "font_size": "64",
    "pixel_size": "0.01", "modulate": col(1.0, 0.85, 0.3), "outline_size": "14", "double_sided": "false"})

# Point 48 (fuel): QuickFuel, the gas station on the north side of North Road: a raised forecourt (cars drive
# up like onto Carlo's lot), a canopy with lights over two pumps (FuelPump), a small kiosk. Marker GasStation.
GAS = (45.0, -56.4, 22.0, 8.0)
sc.node("GasForecourt", "StaticBody3D", NAV, props={
    "script": sc.script("res://scripts/procgen/paved_area.gd"), "transform": xform((GAS[0], 0, GAS[1])),
    "size": f"Vector2({GAS[2]:g}, {GAS[3]:g})", "surface": q("concrete"), "height": "0.15", "edge": "false"})
BOX = "res://scripts/procgen/proc_box.gd"
# Posts on the pump line (z -56.4) so both lanes (z -54.2 / -58.6) stay free to drive through along X.
for i, (x, z) in enumerate([(37.4, -56.4), (44.0, -56.4), (50.6, -56.4)]):
    sc.node(f"GasPost{i}", "StaticBody3D", NAV, props={"script": sc.script(BOX), "transform": xform((x, 0.15, z)),
            "size": "Vector3(0.3, 4.4, 0.3)", "material_key": q("metal_dark")})
sc.node("GasCanopy", "StaticBody3D", NAV, props={"script": sc.script(BOX), "transform": xform((44.0, 4.55, -56.4)),
        "size": "Vector3(13.6, 0.45, 7.2)", "material_key": q("trim_paint"), "tint": col(0.92, 0.92, 0.9)})
sc.node("GasSign", "Label3D", NAV, props={"transform": xform((44.0, 4.78, -52.78)), "text": q("QUICKFUEL"),
        "font_size": "96", "pixel_size": "0.012", "modulate": col(0.95, 0.25, 0.2), "outline_size": "14"})
for i, x in enumerate((41.0, 47.0)):
    put("interiors/ceiling_lamp.tscn", (x, 4.53, -56.4), 0, name=f"GasLamp{i}")
for i, x in enumerate((41.0, 47.0)):
    sc.node(f"FuelPump{i + 1}", "StaticBody3D", NAV, props={
        "script": sc.script("res://scripts/vehicles/fuel_pump.gd"), "transform": xform((x, 0.15, -56.4), 90)})
sc.node("GasKiosk", "StaticBody3D", NAV, props={"script": sc.script(BOX), "transform": xform((53.6, 0.15, -57.2)),
        "size": "Vector3(4.0, 3.0, 5.6)", "material_key": q("plaster"), "tint": col(0.95, 0.9, 0.82)})
sc.node("GasKioskSign", "Label3D", NAV, props={"transform": xform((53.6, 2.5, -54.36)), "text": q("SHOP  24/7"),
        "font_size": "48", "pixel_size": "0.008", "modulate": col(1.0, 0.85, 0.3), "outline_size": "8"})

# --------------------------------------------------------------------------- the west side (point 47)
# Industrial edge (south of Main Road, x -180..-80), the harbour (Quay Road z 84, quay apron, the sea south of
# z 104) and room for the countryside north of Main Road (47b). Own random stream: the town keeps its layout.
wrng = random.Random(47)
CONC = "res://scripts/procgen/paved_area.gd"


def paved(name, cx, cz, sx, sz, surface="concrete", h=0.05):
    sc.node(name, "StaticBody3D", NAV, props={"script": sc.script(CONC), "transform": xform((cx, 0, cz)),
            "size": f"Vector2({sx:g}, {sz:g})", "surface": q(surface), "height": f"{h:g}", "edge": "false"})


def pbox(name, pos, size, mat, tint=None, rot=0.0, parent=NAV, collision=True):
    props = {"script": sc.script(BOX), "transform": xform(pos, rot), "size": v3(*size), "material_key": q(mat)}
    if tint:
        props["tint"] = tint
    if not collision:
        props["collision"] = "false"
    sc.node(name, "StaticBody3D", parent, props=props)


def fence_line(x0, z0, x1, z1, y=0.05, gaps=()):
    """Chain-link fence in 2 m panels from (x0, z0) to (x1, z1) (along X or Z); `gaps` = panel starts left open."""
    if z0 == z1:
        for x in range(int(min(x0, x1)), int(max(x0, x1)), 2):
            if x not in gaps:
                put("props/chainlink_fence.tscn", (x, y, z0))
    else:
        for z in range(int(min(z0, z1)), int(max(z0, z1)), 2):
            if z not in gaps:
                put("props/chainlink_fence.tscn", (x0, y, z), -90)


CONTAINER_COLS = [col(0.62, 0.16, 0.12), col(0.15, 0.3, 0.55), col(0.2, 0.42, 0.3),
                  col(0.75, 0.5, 0.15), col(0.5, 0.52, 0.55), col(0.85, 0.85, 0.82)]


def container_stack(x, y, z, rot, levels, length="12m"):
    for lv in range(levels):
        put(f"props/container_{length}.tscn", (x, y + lv * 2.6, z), rot + wrng.uniform(-1.5, 1.5),
            name=uname("Container"), props={"color": wrng.choice(CONTAINER_COLS)})


# Roads: Main Road on to the west (road end x -180), Industrial Road south at x -114, round the corner
# into Quay Road (z 84) along the harbour.
for x in range(-78, -175, -12):
    if x == -114:
        put(R + "road_t_junction.tscn", (x, 0, 0), 180)
    elif x == -150:
        pass  # point 47b: the Country Lane junction (countryside section)
    else:
        put(R + "road_straight.tscn", (x, 0, 0))
for z in range(12, 73, 12):
    put(R + "road_straight.tscn", (-114, 0, z), 90)
put(R + "road_curve.tscn", (-114, 0, 84), -90)        # north <-> west
for x in range(-126, -175, -12):
    put(R + "road_straight.tscn", (x, 0, 84))
for x, z in [(-181, -1.8), (-181, 1.8), (-181, 82.2), (-181, 85.8)]:
    put("props/road_barrier.tscn", (x, 0, z), 90)
for x, z, r in [(-90, -3.95, 180), (-132, -3.95, 180), (-162, -3.95, 180),
                (-84, 3.95, 0), (-102, 3.95, 0), (-138, 3.95, 0), (-168, 3.95, 0),
                (-117.95, 18, 90), (-117.95, 42, 90), (-117.95, 66, 90),
                (-110.05, 38, -90), (-110.05, 60, -90),
                (-132, 80.05, 180), (-156, 80.05, 180), (-128, 87.95, 0), (-172, 87.95, 0)]:
    put("props/street_lamp.tscn", (x, 0.15, z), r)
put("props/sign_post.tscn", (-108.6, 0.15, 3.72), 0, props={"sign_text": q("INDUSTRIAL ROAD")})
put("props/sign_post.tscn", (-120.4, 0.15, 80.3), 180, props={"sign_text": q("QUAY ROAD")})

# West block: the metalworks (front on Main Road) and a fenced container yard behind it.
paved("FactoryYard", -150, 17, 60, 22)
paved("ContainerYard", -150, 52, 60, 48)
put("buildings/warehouse.tscn", (-150, 0.05, 6.4), 180, name="Factory", props={
    "width": "30", "depth": "19", "floor_height": "8.5", "bays": "6", "door_bay": "2", "enterable": "false",
    "furnish": q("none"), "wall_material": q("concrete"), "wall_tint": col(0.72, 0.7, 0.66), "roof_type": q("flat"),
    "variation_seed": "4701"})
sc.node("FactorySign", "Label3D", NAV, props={"transform": xform((-150, 7.2, 6.3), 180),
        "text": q("RIVERTON METALWORKS"), "font_size": "96", "pixel_size": "0.014",
        "modulate": col(0.92, 0.9, 0.85), "outline_size": "16", "double_sided": "false"})
for i, x in enumerate((-160.0, -155.5)):
    pbox(f"FactoryChimney{i}", (x, 8.5, 18), (1.6, 10 - i * 2, 1.6), "brick_old")
fence_line(-178, 30, -122, 30, gaps=(-126, -124))
fence_line(-178, 30, -178, 74)
fence_line(-122, 30, -122, 74, gaps=(48,))
fence_line(-178, 74, -122, 74)
for x, z in [(-176.5, 31.5), (-123.5, 31.5), (-176.5, 72.5), (-123.5, 72.5)]:
    put("props/floodlight_pole.tscn", (x, 0.05, z), 45 if x > -150 else -45)
for i in range(7):
    container_stack(-170 + (i % 2) * 2.7, 0.05, 36 + i * 5.2, 0, wrng.choice([1, 2, 2, 3]))
for i in range(5):
    container_stack(-144 + i * 4.6, 0.05, 66, 90, wrng.choice([1, 2, 3]))
for i in range(3):
    container_stack(-140 + i * 3.0, 0.05, 40, 90, 1, "6m")
for pos in [(-150, 0.05, 50), (-145, 0.05, 54.5), (-157, 0.05, 46)]:
    put("props/covered_car.tscn", pos, wrng.uniform(0, 360))
for i in range(6):
    put("props/barrel.tscn", (-131.5 + wrng.uniform(-1.5, 1.5), 0.05, 58 + wrng.uniform(-2, 2)), 0)
for i in range(4):
    put("props/crate_long.tscn", (-162 + i * 0.7, 0.05, 28.2), 0)

# East block: the lab warehouse (property, front on Industrial Road), a small yard and a workshop.
paved("EastIndustrial", -94, 42, 28, 72)
put("buildings/warehouse.tscn", (-108.2, 0.05, 20), -90, name="LabWarehouse", props={
    "variation_seed": "4702", "wall_tint": col(0.62, 0.55, 0.48)})
property_node("LabWarehouse", "lab_warehouse", "Lab Warehouse", 60000,
              "Industrial Road. 16 x 12 m hall with a loading door; the neighbours make metal, not questions.",
              0.0, 4.2)
fence_line(-106, 34, -82, 34, gaps=(-106, -104))
fence_line(-106, 50, -82, 50)
fence_line(-82, 34, -82, 50)
for i in range(3):
    container_stack(-96 + i * 4.4, 0.05, 42 + wrng.uniform(-2, 2), 90, wrng.choice([1, 2]), "6m")
put("buildings/warehouse.tscn", (-108.2, 0.05, 64), -90, name="Workshop", props={
    "width": "18", "depth": "14", "floor_height": "6", "bays": "4", "enterable": "false", "furnish": q("none"),
    "wall_tint": col(0.35, 0.5, 0.42), "variation_seed": "4703"})

# The harbour: quay apron (z 90..104), the harbour storage hall (property), stacks, a crane, a moored ship.
paved("QuayApron", -133, 97, 118, 14, "concrete", 0.15)
pbox("QuayWall", (-133, -3.0, 104.6), (118, 3.15, 1.2), "concrete", col(0.75, 0.74, 0.7))
put("buildings/warehouse.tscn", (-150, 0.15, 90.2), 180, name="HarborStorage", props={
    "width": "22", "depth": "12", "floor_height": "6.5", "bays": "5", "door_bay": "2", "variation_seed": "4704",
    "wall_tint": col(0.4, 0.52, 0.66)})
property_node("HarborStorage", "harbor_storage", "Harbour Storage", 90000,
              "Quay Road, on the water. 22 x 12 m hall; shipments come in right outside the door.", 0.0, 4.6)
sc.node("HarborSign", "Label3D", NAV, props={"transform": xform((-150, 6.0, 90.0), 180),
        "text": q("RIVERTON HARBOUR"), "font_size": "80", "pixel_size": "0.012",
        "modulate": col(0.95, 0.95, 0.92), "outline_size": "14", "double_sided": "false"})
for x in range(-186, -76, 8):
    if not -162 <= x <= -138:
        put("props/bollard.tscn", (x + 0.5, 0.15, 103.6))
for i in range(4):
    container_stack(-182 + i * 3.0, 0.15, 96, 90, wrng.choice([2, 3]))
for i in range(3):
    container_stack(-128 + i * 3.0, 0.15, 95.5, 90, wrng.choice([1, 2, 3]))
YEL = col(0.95, 0.72, 0.12)
for i, (x, z) in enumerate([(-104, 92.5), (-94, 92.5), (-104, 102.5), (-94, 102.5)]):
    pbox(f"CraneLeg{i}", (x, 0.15, z), (0.7, 14, 0.7), "trim_paint", YEL)
pbox("CraneBeamN", (-99, 14.15, 92.5), (11, 1.0, 1.0), "trim_paint", YEL)
pbox("CraneBeamS", (-99, 14.15, 102.5), (11, 1.0, 1.0), "trim_paint", YEL)
pbox("CraneBoom", (-99, 15.15, 108), (2.0, 1.0, 30), "trim_paint", YEL, collision=False)
pbox("CraneCab", (-99, 12.4, 97.5), (3, 2.2, 3), "trim_paint", col(0.9, 0.9, 0.88), collision=False)
# The ship along the quay (in the water, not reachable).
pbox("ShipHull", (-150, -2.5, 111.5), (58, 5.5, 11), "trim_paint", col(0.62, 0.16, 0.12), collision=False)
pbox("ShipDeck", (-150, 3.0, 111.5), (57, 0.3, 10.4), "concrete", col(0.5, 0.5, 0.5), collision=False)
pbox("ShipBridge", (-173, 3.3, 111.5), (8, 7, 9.4), "trim_paint", col(0.92, 0.92, 0.9), collision=False)
pbox("ShipFunnel", (-175, 10.3, 111.5), (2.4, 3.5, 2.4), "trim_paint", col(0.85, 0.3, 0.12), collision=False)
for i in range(6):
    put("props/container_12m.tscn", (-160 + (i % 3) * 12.6, 3.3 + (i // 3) * 2.6, 110.2 + (i // 3) * 1.3), 0,
        name=uname("ShipContainer"), props={"color": wrng.choice(CONTAINER_COLS)})
# The sea + a breakwater hiding where the water meets the land east of the harbour.
water_mesh = sc.subres("PlaneMesh", {"size": "Vector2(426, 800)", "subdivide_width": "85", "subdivide_depth": "160"})
sc.node("Sea", "MeshInstance3D", ".", props={"transform": xform((-287, -0.9, 504)), "mesh": water_mesh,
        "material_override": sc.res("Material", "res://prefabs/materials/water.tres"), "cast_shadow": "0"})
pbox("Breakwater", (-74, -2.0, 160), (4, 3.2, 112), "concrete", col(0.62, 0.6, 0.56), collision=False)
# Trees round the edges of the yards.
for i, (x, z) in enumerate([(-186, 10), (-186, 26), (-186, 44), (-186, 62), (-84, 58), (-84, 72), (-100, 76)]):
    put("nature/tree_medium.tscn", (x + wrng.uniform(-1, 1), 0, z + wrng.uniform(-1, 1)), wrng.uniform(0, 360),
        props={"tree_seed": str(4700 + i)})

# --------------------------------------------------------------------------- the countryside (point 47b)
# North of Main Road on the west side: Country Lane (x -150) up to Hollow Farm - the Barn (property), the
# farmhouse, a silo, hay, fenced fields with crop rows. Own random stream.
frng = random.Random(471)
put(R + "road_t_junction.tscn", (-150, 0, 0), 0, name="CountryLaneJunction")
for z in range(-12, -73, -12):
    put(R + "road_straight.tscn", (-150, 0, z), 90)
for x, z, r in [(-153.95, -18, 90), (-153.95, -42, 90), (-153.95, -66, 90), (-146.05, -30, -90), (-146.05, -54, -90)]:
    put("props/street_lamp.tscn", (x, 0.15, z), r)
put("props/sign_post.tscn", (-144.6, 0.15, -3.72), 0, props={"sign_text": q("COUNTRY LANE")})
# The farmyard at the top of the lane (packed earth), the barn facing it from the north.
paved("Farmyard", -150, -88, 44, 20, "soil", 0.06)
put("buildings/warehouse.tscn", (-150, 0.06, -92), 0, name="Barn", props={
    "width": "14", "depth": "16", "floor_height": "6", "bays": "3", "door_bay": "1", "variation_seed": "4710",
    "wall_material": q("corrugated"), "wall_tint": col(0.62, 0.2, 0.16), "roof_material": q("roof_dark"),
    "roof_type": q("gable"), "roof_pitch": "32", "lit_windows": "0.0"})
property_node("Barn", "barn", "Hollow Farm Barn", 30000,
              "Country Lane, Hollow Farm. A big barn far from prying eyes: room for growing and cooking.", 0.0, 4.4)
put("buildings/row_house_c.tscn", (-166.5, 0.06, -92), 0, name="Farmhouse", props={
    "width": "8", "floors": "2", "variation_seed": "4711", "wall_material": q("plaster"),
    "wall_tint": col(0.93, 0.9, 0.8), "enterable": "false"})
pbox("Silo", (-133, 0.06, -96), (4.2, 11, 4.2), "zinc", col(0.82, 0.84, 0.86))
pbox("SiloRoof", (-133, 11.06, -96), (4.6, 0.6, 4.6), "roof_dark")
HAY = col(0.86, 0.72, 0.38)
for i in range(7):
    x = -140 + (i % 4) * 1.7 + frng.uniform(-0.2, 0.2)
    pbox(f"HayBale{i}", (x, 0.06 + (i // 4) * 1.0, -82 + frng.uniform(-0.3, 0.3)), (1.5, 1.0, 1.0), "planks", HAY,
         frng.uniform(-8, 8))
put("props/covered_car.tscn", (-160, 0.06, -82), 80)
for i in range(4):
    put("props/barrel.tscn", (-131 + frng.uniform(-1, 1), 0.06, -86 + frng.uniform(-1, 1)), 0)
# Fields either side of the lane: soil with crop rows, a picket fence along the lane.
CROP = [col(0.38, 0.58, 0.22), col(0.52, 0.66, 0.26), col(0.78, 0.7, 0.32)]
for fi, (cx, cz, sx, sz) in enumerate([(-174, -42, 28, 56), (-120, -40, 48, 52)]):
    paved(f"Field{fi}", cx, cz, sx, sz, "soil", 0.04)
    c = CROP[fi % len(CROP)]
    for r in range(int(sx / 2.4)):
        x = cx - sx / 2 + 1.2 + r * 2.4
        pbox(f"CropRow{fi}_{r}", (x, 0.04, cz), (0.9, 0.55 + frng.uniform(-0.1, 0.15), sz - 2), "trim_paint", c,
             collision=False)
for z in range(-76, -8, 6):
    put("props/garden_fence.tscn", (-157, 0, z), -90, props={"length": "6", "style": q("picket"), "height": "1.1"})
    put("props/garden_fence.tscn", (-143, 0, z), -90, props={"length": "6", "style": q("picket"), "height": "1.1"})
# Tree rows along the field edges and round the farm.
for i in range(12):
    put("nature/tree_large.tscn" if i % 3 == 0 else "nature/tree_medium.tscn",
        (-188 + frng.uniform(-1, 1), 0, -120 + i * 9.5), frng.uniform(0, 360), props={"tree_seed": str(4720 + i)})
for i in range(10):
    put("nature/tree_medium.tscn", (-176 + i * 10 + frng.uniform(-1.5, 1.5), 0, -112 + frng.uniform(-2, 2)),
        frng.uniform(0, 360), props={"tree_seed": str(4740 + i)})
for i, (x, z) in enumerate([(-92, -14), (-84, -30), (-90, -66), (-100, -80), (-112, -100), (-178, -98)]):
    put("nature/tree_large.tscn", (x, 0, z), frng.uniform(0, 360), props={"tree_seed": str(4760 + i)})
for (x, z) in [(-160, -78.5), (-140, -78.5), (-128, -90), (-172, -80)]:
    put(f"nature/shrub_{frng.choice('abcd')}.tscn", (x, 0, z), frng.uniform(0, 360))

# --------------------------------------------------------------------------- invisible walls
sc.node("Bounds", "StaticBody3D", ".")
# Point 47: the west side widened the playable area (x -192..-72.5, z -132..105 = the quay edge).
for name, pos, size in [("N", (0, 5, -61), (150, 10, 1)), ("S", (0, 5, 67), (150, 10, 1)),
                        ("E", (72.5, 5, 3), (1, 10, 130)),
                        ("W", (-192.5, 5, -13.5), (1, 10, 238)), ("NW", (-132.5, 5, -132.5), (121, 10, 1)),
                        ("Quay", (-132.5, 5, 104.8), (121, 10, 0.4)),
                        ("WestN", (-72.5, 5, -96.75), (1, 10, 71.5)), ("WestS", (-72.5, 5, 86), (1, 10, 38))]:
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
# Point 45: where Carlo hands over a bought car (nose to the road).
for i, z in enumerate([51.6, 55.0, 58.4, 61.8]):
    sc.node(f"CarDelivery{i + 1}", "Marker3D", "Markers", props={"transform": xform((39.0, 0.15, z), 90)})
for i, x in enumerate([10, 12, 14, 16]):
    sc.node(f"Spawn{i + 1}", "Marker3D", "Markers/SpawnPoints", props={"transform": xform((x, 0.3, -4.6), 90)})
sc.node("CustomerSpawn", "Marker3D", "Markers", props={"transform": xform((68, 0.15, 4.8))})
sc.node("CustomerMeetPoint", "Marker3D", "Markers", props={"transform": xform((-4, 0.15, 12.5))})



def debug_label(parent, text):
    """Marker label: visible in the editor, hidden in game (F3 toggles it)."""
    sc.node("DebugLabel", "Label3D", parent, groups=["debug_only"], props={
        "transform": xform((0, 2.2, 0)), "billboard": "1", "text": q(text), "font_size": "40",
        "outline_size": "12", "modulate": col(1, 0.95, 0.75), "no_depth_test": "true"})


# Point 46: the dog walkers' loop and the youths' smoke spot in the park.
sc.node("ParkPath", "Node3D", "Markers")
for i, (x, z) in enumerate([(-7.0, 22.0), (4.3, 22.0), (4.3, 36.0), (-7.0, 36.0)]):
    sc.node(f"P{i + 1}", "Marker3D", "Markers/ParkPath", props={"transform": xform((x, 0.12, z))})
sc.node("ParkSmokeSpot", "Marker3D", "Markers", props={"transform": xform((-11.5, 0.05, 31.0))})
debug_label("Markers/CustomerMeetPoint", "MEET POINT")
debug_label("Markers/ParkSmokeSpot", "SMOKE SPOT")
debug_label("Markers/CustomerSpawn", "CUSTOMER SPAWN")
sc.node("RivalPatrol", "Node3D", "Markers")
for i, (x, z) in enumerate([(42, 12), (58, 12), (58, 28), (42, 28)]):
    sc.node(f"P{i + 1}", "Marker3D", "Markers/RivalPatrol", props={"transform": xform((x, 0.05, z))})
    debug_label(f"Markers/RivalPatrol/P{i + 1}", f"PATROL P{i + 1}")
for i in range(4):
    debug_label(f"Markers/SpawnPoints/Spawn{i + 1}", f"SPAWN {i + 1}")

# Point 49: the prison of the intro, far outside the village (own ground, outside NavRegion: no navmesh there),
# and the bus stop on Main Road's west edge where the bus drops the released players (marker BusStop, facing east).
PRISON_POS = (0, 0, -340)
put("buildings/prison.tscn", PRISON_POS, 0, parent=".", name="Prison")
sc.node("BusStop", "Marker3D", "Markers", props={"transform": xform((-60.0, 0.15, -4.4), -90)})
debug_label("Markers/BusStop", "BUS STOP")
sc.node("GasStation", "Marker3D", "Markers", props={"transform": xform((44.0, 0.2, -52.6), 180)})
sc.node("BusStopPole", "StaticBody3D", NAV, props={
    "script": sc.script("res://scripts/procgen/proc_box.gd"), "transform": xform((-62.4, 0.15, -5.5)),
    "size": "Vector3(0.1, 2.7, 0.1)", "material_key": q("metal_dark")})
sc.node("BusStopSign", "Label3D", NAV + "/BusStopPole", props={
    "transform": xform((0, 2.45, 0.08)), "text": q("BUS 12\nRiverton - Prison"), "font_size": "40",
    "pixel_size": "0.006", "outline_size": "8", "modulate": col(1.0, 0.85, 0.3), "double_sided": "true"})

# --------------------------------------------------------------------------- NPCs
# Host spawns pedestrians under NPCs; the spawner replicates them to clients.
sc.node("NPCs", "Node3D", ".")
sc.node("NPCSpawner", "MultiplayerSpawner", ".", props={
    "_spawnable_scenes": 'PackedStringArray("res://prefabs/npc/pedestrian.tscn", "res://prefabs/npc/police_officer.tscn", "res://prefabs/npc/rival.tscn", "res://prefabs/npc/park_goer.tscn")',
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
