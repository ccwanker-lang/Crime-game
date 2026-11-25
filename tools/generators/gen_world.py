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
# Point 95: every road tile / paved area (x0, z0, x1, z1) and every grass field written, so a last pass can cut holes
# where a (older) grass field lies under a (newer) road - grass grew through the slum road and two village spots.
PAVED_RECTS = []
GRASS_NODES = []  # [index in sc.nodes, cx, cz, sx, sz]

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
    if prefab.startswith("roads/road_"):
        PAVED_RECTS.append((pos[0] - 6.0, pos[2] - 6.0, pos[0] + 6.0, pos[2] + 6.0))
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
    "filter_baking_aabb": "AABB(-198.5, -2, -138.5, 279, 20, 250)"})
sc.node(NAV, "NavigationRegion3D", ".", props={"navigation_mesh": navmesh})

# Ground everywhere (grass/dirt shader) + an outer ring without collision.
ground_mat = sc.res("Material", "res://prefabs/materials/ground.tres")
# Point 57: ONE playable area PLAY (x0, z0, x1, z1) = the whole village, walkable everywhere up to a natural border
# (hedge + tree row + hills, the quay at the sea) - no invisible walls inside it. Ground reaches past the border.
PLAY = (-193.0, -133.0, 75.0, 106.0)
QUAY_Z = 104.8   # the sea starts here west of SEA_X
SEA_X = -72.5
sc.node("Ground", "StaticBody3D", NAV, props={
    "script": sc.script("res://scripts/procgen/ground_area.gd"), "transform": xform((-59, 0, -18.1)),
    "size": "Vector2(284, 245.8)", "material": ground_mat})
sc.node("GroundSouth", "StaticBody3D", NAV, props={
    "script": sc.script("res://scripts/procgen/ground_area.gd"), "transform": xform((5.25, 0, 109.4)),
    "size": "Vector2(155.5, 9.2)", "material": ground_mat})
# Point 47: the outer ground leaves the sea free (south of the quay, west of x -74).
sc.node("OuterGround", "StaticBody3D", ".", props={
    "script": sc.script("res://scripts/procgen/ground_area.gd"), "transform": xform((0, -0.02, -196.5)),
    "size": "Vector2(1000, 601)", "collision": "false", "material": ground_mat})
sc.node("OuterGroundSE", "StaticBody3D", ".", props={
    "script": sc.script("res://scripts/procgen/ground_area.gd"), "transform": xform((213, -0.02, 303.5)),
    "size": "Vector2(574, 399)", "collision": "false", "material": ground_mat})
# Map blueprint zone 9: the snowy border mountains round the whole map (gen_border.py -> data/border); they replace
# the old hedge + tree row + hills (points 27/57) and the walls in the fields.
sc.node("BorderRange", "StaticBody3D", ".", props={"script": sc.script("res://scripts/procgen/border_range.gd")})
# Ground for the new zones: the highway strip east of the village and the city south of it (blueprint zone 7).
sc.node("GroundEast", "StaticBody3D", NAV, props={
    "script": sc.script("res://scripts/procgen/ground_area.gd"), "transform": xform((111.5, 0, -13.5)),
    "size": "Vector2(57, 255)", "material": ground_mat})
# (not under NavRegion: no pedestrians in the city yet - its towers are not baked as obstacles)
sc.node("GroundCity", "StaticBody3D", ".", props={
    "script": sc.script("res://scripts/procgen/ground_area.gd"), "transform": xform((33.75, 0, 257)),
    "size": "Vector2(212.5, 286)", "material": ground_mat})
# Point 85: the airfield east of the army base (x -30..240, z -445..-346; gen_border LAND) - not baked (no navmesh).
sc.node("GroundAirfield", "StaticBody3D", ".", props={
    "script": sc.script("res://scripts/procgen/ground_area.gd"), "transform": xform((105, 0, -395.5)),
    "size": "Vector2(270, 99)", "material": ground_mat})
# Point 49b: the mountain pass to the prison (terrain, road, rails, pines from data/mountain - gen_mountain.py).
sc.node("Mountain", "StaticBody3D", ".", props={"script": sc.script("res://scripts/procgen/mountain.gd")})

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
# (-6, -48): a T junction since map zone 3 (the slums road goes north) - see "the slums".
put(R + "road_t_junction.tscn", (30, 0, -48), 180)     # W, E, branch south
for x in (6, 18, 42, 54):  # (66, -48): a T since point 80 (Rosehill Estate)
    put(R + "road_straight.tscn", (x, 0, -48))
for z in range(12, 49, 12):
    put(R + "road_straight.tscn", (30, 0, z), 90)
# Point 8: South Street branches west off the side road at z 60 (point 60: on to the docks, see the west side).
# (30, 60): a T to the north/west/south (the side road runs on south since point 71) - see "new neighbourhoods".
for x in range(-54, 19, 12):
    put(R + "road_straight.tscn", (x, 0, 60), 0, props={"crossing": "true"} if x == -30 else None)

# (No road-end barriers any more: North Road and the side road x 30 run on since point 71.)

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
            GRASS_NODES.append([len(sc.nodes) - 1, x, z, tx, tz])


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
PAVED_RECTS.append((-36.0, 6.0, -33.0, 22.0))  # ContactAlley (below)
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
for x in (0, 18, 48):  # (x 64: the Estate T since point 80)
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
    tp = (x + rng.uniform(-1.5, 1.5), 0, -58 + rng.uniform(-2, 2))
    tr = rng.uniform(0, 360)
    if not -86 < tp[0] < 7 and not 58 < tp[0] < 76:  # point 79: the slums road (z -60, x -84..0); point 80: x 66
        put("nature/tree_large.tscn" if i % 3 == 0 else "nature/tree_medium.tscn", tp, tr,
            props={"tree_seed": str(600 + i)})
    if i % 2 == 0:
        tx, tz, tr = x + rng.uniform(-1.5, 1.5), 63 + rng.uniform(-2, 2), rng.uniform(0, 360)
        if not -74 < tx < 59:  # South Street runs there (z 54..66, point 60: bend at x -66), then Carlo's car lot
            put("nature/tree_medium.tscn", (tx, 0, tz), tr, props={"tree_seed": str(700 + i)})
for i in range(18):
    z = -50 + i * 6.5
    if abs(z) < 8 or abs(z + 48) < 8:
        continue
    tx, tr = -75 + rng.uniform(-1, 1), rng.uniform(0, 360)
    if z > 50:
        continue  # point 60: South Street bends south there
    put("nature/tree_medium.tscn", (tx, 0, z), tr, props={"tree_seed": str(800 + i)})

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



# Point 96: three more gas stations, the same kit as QuickFuel (raised forecourt, canopy + lamps, two FuelPumps,
# kiosk). Local frame: the pump line runs along local X, the road lies at local +Z (rot turns it), the kiosk stands
# at the +X end (or behind the canopy when `kiosk_behind`, for short plots). Everything sits in one Node3D
# `GasStation<Tag>` (children: Pump1/Pump2 = FuelPump, marker Spot = where a scenario puts the player).
def gas_station(tag, cx, cz, rot, parent, length=22.0, title="QUICKFUEL", kiosk_behind=False, y=0.0):
    import math
    root = f"GasStation{tag}"
    sc.node(root, "Node3D", parent, props={"transform": xform((cx, y, cz), rot)})
    path = (parent + "/" if parent != "." else "") + root
    a = math.radians(rot)
    hx, hz = length / 2, 4.0
    ex = abs(hx * math.cos(a)) + abs(hz * math.sin(a))
    ez = abs(hx * math.sin(a)) + abs(hz * math.cos(a))
    PAVED_RECTS.append((cx - ex, cz - ez, cx + ex, cz + ez))
    sc.node("Forecourt", "StaticBody3D", path, props={"script": sc.script("res://scripts/procgen/paved_area.gd"),
            "size": f"Vector2({length:g}, 8)", "surface": q("concrete"), "height": "0.15", "edge": "false"})
    post = 6.6 if length >= 20 else 5.6
    for i, x in enumerate((-post, 0.0, post)):
        sc.node(f"Post{i}", "StaticBody3D", path, props={"script": sc.script(BOX), "transform": xform((x, 0.15, 0)),
                "size": "Vector3(0.3, 4.4, 0.3)", "material_key": q("metal_dark")})
    sc.node("Canopy", "StaticBody3D", path, props={"script": sc.script(BOX), "transform": xform((0, 4.55, 0)),
            "size": f"Vector3({post * 2 + 0.4:g}, 0.45, 7.2)", "material_key": q("trim_paint"), "tint": col(0.92, 0.92, 0.9)})
    sc.node("Sign", "Label3D", path, props={"transform": xform((0, 4.78, 3.62)), "text": q(title),
            "font_size": "96", "pixel_size": "0.012", "modulate": col(0.95, 0.25, 0.2), "outline_size": "14"})
    for i, x in enumerate((-3.0, 3.0)):
        sc.node(f"Lamp{i}", None, path, instance=PF + "interiors/ceiling_lamp.tscn", props={"transform": xform((x, 4.53, 0))})
        sc.node(f"Pump{i + 1}", "StaticBody3D", path, props={
            "script": sc.script("res://scripts/vehicles/fuel_pump.gd"), "transform": xform((x, 0.15, 0), 90)})
    if kiosk_behind:
        kpos, ksize, spos = (post - 1.0, 0.0, -6.2), "Vector3(5.6, 3.0, 4.0)", (post - 1.0, 2.5, -4.18)
    else:
        kpos, ksize, spos = (hx - 1.4, 0.15, -0.8), "Vector3(4.0, 3.0, 5.6)", (hx - 1.4, 2.5, 2.04)
    sc.node("Kiosk", "StaticBody3D", path, props={"script": sc.script(BOX), "transform": xform(kpos),
            "size": ksize, "material_key": q("plaster"), "tint": col(0.95, 0.9, 0.82)})
    sc.node("KioskSign", "Label3D", path, props={"transform": xform(spos), "text": q("SHOP  24/7"),
            "font_size": "48", "pixel_size": "0.008", "modulate": col(1.0, 0.85, 0.3), "outline_size": "8"})
    sc.node("Spot", "Marker3D", path, props={"transform": xform((-1.4, 0.35, 1.6), 180)})


# --------------------------------------------------------------------------- the west side (point 47)
# Industrial edge (south of Main Road, x -180..-80), the harbour (Quay Road z 84, quay apron, the sea south of
# z 104) and room for the countryside north of Main Road (47b). Own random stream: the town keeps its layout.
wrng = random.Random(47)
CONC = "res://scripts/procgen/paved_area.gd"


def paved(name, cx, cz, sx, sz, surface="concrete", h=0.05, parent=NAV):
    if surface != "soil":
        PAVED_RECTS.append((cx - sx / 2, cz - sz / 2, cx + sx / 2, cz + sz / 2))
    sc.node(name, "StaticBody3D", parent, props={"script": sc.script(CONC), "transform": xform((cx, 0, cz)),
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
put(R + "road_t_junction.tscn", (-114, 0, 84), 0, name="QuayJunction")  # W, E + Industrial Road north (point 60)
for x in range(-126, -175, -12):
    put(R + "road_straight.tscn", (x, 0, 84))
# Point 60: South Street goes on from its old dead end (x -60): bend south at x -66, down to the harbour, bend
# west into Quay Road (z 84) - the police station's street now reaches the docks.
put(R + "road_curve.tscn", (-66, 0, 60), 90)           # east <-> south
put(R + "road_straight.tscn", (-66, 0, 72), 90)
# (-66, 84): a T since point 71 (Garden Row runs east) - see "new neighbourhoods".
for x in (-78, -90, -102):
    put(R + "road_straight.tscn", (x, 0, 84))
for x, z, r in [(-69.95, 70, 90), (-62.05, 76, -90), (-84, 87.95, 0), (-96, 80.05, 180), (-108, 87.95, 0)]:
    put("props/street_lamp.tscn", (x, 0.15, z), r)
put("props/sign_post.tscn", (-60.4, 0.15, 56.3), 0, props={"sign_text": q("TO THE HARBOUR")})
# Point 78 (no dead ends): Main Road and Quay Road no longer end at x -180 - Dock Road (x -186) joins them.
# (The tiles are placed in the "new neighbourhoods" section: road_tile is defined further down.)
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
# Blueprint zone 9: the sea ends under the border mountains (x -345, z 445) instead of running to the horizon.
water_mesh = sc.subres("PlaneMesh", {"size": "Vector2(272.5, 340.2)", "subdivide_width": "55", "subdivide_depth": "68"})
sc.node("Sea", "MeshInstance3D", ".", props={"transform": xform((-208.75, -0.9, 274.9)), "mesh": water_mesh,
        "material_override": sc.res("Material", "res://prefabs/materials/water.tres"), "cast_shadow": "0"})
pbox("Breakwater", (-74, -2.0, 160), (4, 3.2, 112), "concrete", col(0.62, 0.6, 0.56), collision=False)
# Trees round the edges of the yards.
for i, (x, z) in enumerate([(-196.5, 10), (-196.5, 26), (-196.5, 44), (-196.5, 62), (-84, 58), (-84, 72), (-100, 76)]):
    put("nature/tree_medium.tscn", (x + wrng.uniform(-1, 1), 0, z + wrng.uniform(-1, 1)), wrng.uniform(0, 360),
        props={"tree_seed": str(4700 + i)})

gas_station("Docks", -83.5, 94.0, 180, NAV, length=18.0, title="DOCK FUEL", kiosk_behind=True)

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
    pbox(f"HayBale{i}", (x, 0.06 + (i // 4) * 1.0, -89 + frng.uniform(-0.3, 0.3)), (1.5, 1.0, 1.0), "planks", HAY,
         frng.uniform(-8, 8))
put("props/covered_car.tscn", (-160, 0.06, -82), 80)
for i in range(4):
    put("props/barrel.tscn", (-129 + frng.uniform(-1, 1), 0.06, -91 + frng.uniform(-1, 1)), 0)  # (49b: off the road)
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

# --------------------------------------------------------------------------- the border (point 57)
# A hedge 6 m outside PLAY all round (not on the sea side: the quay edge is the border there), the trees of the
# backdrop right behind it, and the invisible walls 7 m out, behind the hedge - never in the open.
x0, z0, x1, z1 = PLAY
HG = 6.0
PASS_GAP = (-129.0, -119.0)  # point 49b: the mountain road leaves the village here (x -127.5..-120.5)
MT = (-262.0, -445.0, -30.0)  # point 49b: mountain area x0, z0 (north), x1 (gen_mountain GRID_*)
sc.node("Bounds", "StaticBody3D", ".")
W = 7.0
for name, pos, size in [
        # Blueprint zone 9: the border mountains stop you now (too steep); walls only stand at the water's edge.
        ("Quay", ((x0 - W + SEA_X) / 2, 5, QUAY_Z), (SEA_X - x0 + W, 10, 0.4)),
        ("SeaEast", (SEA_X, 5, (QUAY_Z + 400.0) / 2), (0.4, 10, 400.0 - QUAY_Z))]:
    sc.node("Wall" + name, "CollisionShape3D", "Bounds", props={
        "transform": xform(pos), "shape": sc.subres("BoxShape3D", {"size": v3(*size)})})

# --------------------------------------------------------------------------- the city (map blueprint zone 7)
# South of the centre (left in the user's drawing): a 12 m road-tile grid (streets x -54/6/66/102, avenues z 144/
# 204/264/324), office towers + skyscrapers, two multi-storey car parks; the highway = Main Road on east past x 72,
# down x 102 into the city. Traffic routes 6-8 + junctions + lights go to data/city/city.json (Traffic loads them).
# Rough layout (roadmap 69); detail later. Not under NavRegion (no city pedestrians yet).
import json as _json
import math as _math
import os as _os
crng = random.Random(7070)
sc.node("City", "Node3D", ".")
CX = [-54, 6, 66, 102]
CZ = [144, 204, 264, 324]
HWY_X = 102
DIRS = {"W": (-1, 0), "E": (1, 0), "N": (0, -1), "S": (0, 1)}
TILE_BASE = {"road_straight.tscn": {"W", "E"}, "road_curve.tscn": {"W", "S"},
             "road_t_junction.tscn": {"W", "E", "N"}, "road_crossing.tscn": {"W", "E", "N", "S"}}


def _rot_dir(d, deg):
    t = _math.radians(deg)
    x, z = DIRS[d]
    rx, rz = round(x * _math.cos(t) + z * _math.sin(t)), round(-x * _math.sin(t) + z * _math.cos(t))
    return next(k for k, v in DIRS.items() if v == (rx, rz))


def road_tile(x, z, arms, parent="City", props=None):
    """A road tile at (x, z) whose open sides are `arms` (set of W/E/N/S): picks the type + rotation."""
    for prefab, base in TILE_BASE.items():
        if len(base) != len(arms):
            continue
        for deg in (0, 90, 180, 270):
            if {_rot_dir(d, deg) for d in base} == set(arms):
                return put(R + prefab, (x, 0, z), deg, parent=parent, props=props)
    raise ValueError(f"no tile for {arms}")


# Links between grid nodes (+ the highway into the top-right node).
links = set()
for i, x in enumerate(CX):
    for j, z in enumerate(CZ):
        if i + 1 < len(CX):
            links.add(((x, z), (CX[i + 1], z)))
        if j + 1 < len(CZ):
            links.add(((x, z), (x, CZ[j + 1])))
arms = {}
for a, b in links:
    da = "E" if b[0] > a[0] else "S"
    db = "W" if da == "E" else "N"
    arms.setdefault(a, set()).add(da)
    arms.setdefault(b, set()).add(db)
arms[(HWY_X, CZ[0])].add("N")
for node, ar in arms.items():
    road_tile(node[0], node[1], ar)
for a, b in links:
    if a[1] == b[1]:
        for x in range(a[0] + 12, b[0], 12):
            put(R + "road_straight.tscn", (x, 0, a[1]), 0, parent="City")
    else:
        for z in range(a[1] + 12, b[1], 12):
            put(R + "road_straight.tscn", (a[0], 0, z), 90, parent="City")
# The highway: Main Road on east (x 78, 90), a bend south at (102, 0), down to the city.
put(R + "road_straight.tscn", (78, 0, 0), 0, name=uname("Highway"))  # (90, 0) is a T since point 71  # under NavRegion: carves the asphalt
road_tile(HWY_X, 0, {"W", "S"}, parent=NAV)
for z in range(12, CZ[0], 12):
    if z != 84:  # (the Garden Row T, point 71)
        put(R + "road_straight.tscn", (HWY_X, 0, z), 90, name=uname("Highway"))
sign = put("props/sign_post.tscn", (HWY_X - 4.6, 0.15, 30), 90, parent="City", name="HighwaySignCity")
sc.node("Label3D", "Label3D", f"City/{sign}", props={
    "transform": xform((0, 2.6, 0.06)), "text": q("CITY  ->"), "font_size": "64", "pixel_size": "0.006",
    "modulate": col(1, 1, 1), "outline_size": "0"})

# Street lamps: one at every grid node corner + along the highway.
for (x, z) in arms:
    put("props/street_lamp.tscn", (x - 4.8, 0.15, z - 3.95), 180, parent="City", name=uname("CityLamp"))
for z in range(24, CZ[0], 24):
    put("props/street_lamp.tscn", (HWY_X - 3.95, 0.15, z), 90, parent="City", name=uname("HighwayLamp"))
    put("props/street_lamp.tscn", (HWY_X + 3.95, 0.15, z + 12), 270, parent="City", name=uname("HighwayLamp"))

# Buildings per block (x0, x1, z0, z1 between the road tiles).
# User feedback (2026-11-15): the towers were 3-4x too tall and too alike. Now 6-15 floors (a few 16-22 in the
# middle as landmarks), the style picked per building (not per block), more tints, podium + tower shapes.
TOWER_TINTS = [col(0.55, 0.62, 0.7), col(0.62, 0.66, 0.7), col(0.45, 0.52, 0.6), col(0.7, 0.72, 0.74),
               col(0.5, 0.58, 0.55), col(0.38, 0.5, 0.52), col(0.6, 0.55, 0.48), col(0.32, 0.36, 0.42)]
BAND_TINTS = [col(0.78, 0.76, 0.72), col(0.7, 0.68, 0.64), col(0.82, 0.8, 0.76), col(0.66, 0.6, 0.55),
              col(0.85, 0.78, 0.62), col(0.62, 0.66, 0.6), col(0.76, 0.66, 0.6)]
BRICK_TINTS = [col(0.85, 0.7, 0.62), col(0.75, 0.6, 0.52), col(0.9, 0.82, 0.72), col(0.68, 0.5, 0.42),
               col(0.8, 0.76, 0.66), col(0.62, 0.58, 0.55)]


# Point 76: apartment blocks - plaster / brick in warm, light tints.
APT_TINTS = [col(0.92, 0.88, 0.78), col(0.86, 0.8, 0.72), col(0.9, 0.84, 0.8), col(0.8, 0.84, 0.82),
             col(0.88, 0.72, 0.6), col(0.82, 0.76, 0.86), col(0.95, 0.92, 0.86), col(0.78, 0.62, 0.52)]


def tower(cx, cz, w, d, floors, style, rot=0, setback_from=0, antenna=False, sign_text="", name=None, setback=3.0,
          enterable=False, shop_faces=0, open_shop=False):
    tint = crng.choice(TOWER_TINTS if style == "glass" else BAND_TINTS if style == "bands" else
                       APT_TINTS if style == "apartment" else BRICK_TINTS)
    props = {"width": f"{w:g}", "depth": f"{d:g}", "floors": str(floors), "style": q(style), "tint": tint,
             "variation_seed": str(crng.randint(1, 9999))}
    if setback_from:
        props["setback_from"] = str(setback_from)
        if setback != 3.0:
            props["setback"] = f"{setback:g}"
    if antenna:
        props["antenna"] = "true"
    if sign_text:
        props["sign_text"] = q(sign_text)
    if enterable:
        props["enterable"] = "true"
    if shop_faces:  # point 101: shops on the ground floor of the street faces
        props["shop_faces"] = str(shop_faces)
    if open_shop:
        props["open_shop"] = "true"
    return put("city/tower.tscn", (cx, 0, cz), rot, parent="City", name=name or uname("Tower"), props=props)


SITE = "res://scripts/procgen/building_site.gd"


def block_towers(x0, x1, z0, z1, styles, fmin, fmax, split, enter=0, site=False):
    """Fill a block with 1-4 buildings (1.5 m in from the sidewalk edge), each its own style (from `styles`),
    height, and shape: plain, a setback crown, or a 2-3 floor podium with a narrower tower on it.
    Point 101: every street face gets shops on the ground floor; one office tower per block (on the north street)
    gets a walk-in shop. The block is paved (a shop street has no grass between the pavement and the shops).
    Point 102: `site` = the block's last building is a building site (BuildingSite) instead, its gate on a street."""
    opened = False
    paved(uname("BlockPave"), (x0 + x1) / 2, (z0 + z1) / 2, x1 - x0, z1 - z0, "sidewalk", 0.15, parent="City")
    m = 1.5
    x0, x1, z0, z1 = x0 + m, x1 - m, z0 + m, z1 - m
    w, d = x1 - x0, z1 - z0
    k = crng.uniform(0.4, 0.6)
    cells = {1: [(0, 0, 1, 1)], 2: [(0, 0, k, 1), (k, 0, 1, 1)] if w >= d else [(0, 0, 1, k), (0, k, 1, 1)],
             3: [(0, 0, k, 1), (k, 0, 1, 0.5), (k, 0.5, 1, 1)] if w >= d else [(0, 0, 1, k), (0, k, 0.5, 1), (0.5, k, 1, 1)],
             4: [(0, 0, k, 0.5), (k, 0, 1, 0.5), (0, 0.5, 1 - k, 1), (1 - k, 0.5, 1, 1)]}[split]
    for a, b, c, e in cells:
        gap = 2.5 if split > 1 else 0.0
        cw, cd = w * (c - a) - gap, d * (e - b) - gap
        fl = crng.randint(fmin, fmax)
        style = crng.choice(styles)
        shape = crng.random()
        setback_from, setback = 0, 3.0
        ent = enter > 0 and style == "apartment" and cw >= 14 and cd >= 12
        if ent:  # point 76: an enterable apartment block (lobby, stairs + lift to the roof) - plain shape
            enter -= 1
            fl = max(fl, 4)
            shape = 1.0
        if shape < 0.3 and min(cw, cd) > 16 and fl >= 6:
            setback_from, setback = crng.randint(2, 3), round(min(cw, cd) * crng.uniform(0.18, 0.28), 1)  # podium
        elif shape < 0.55 and fl >= 6:
            setback_from = fl - crng.randint(1, 2)  # stepped crown
        cx, cz = x0 + w * (a + c) / 2, z0 + d * (b + e) / 2
        faces = (1 if b == 0 else 0) | (2 if c == 1 else 0) | (4 if e == 1 else 0) | (8 if a == 0 else 0)
        op = not opened and not ent and style != "apartment" and b == 0 and cd >= 12.5 and cw >= 8
        opened = opened or op
        if site and (a, b, c, e) == cells[-1] and not op and not ent:
            sw, sd = round(cw, 1), round(cd, 1)
            sc.node(uname("BuildingSite"), "StaticBody3D", "City", props={"script": sc.script(SITE),
                    "transform": xform((cx, 0.0, cz), 0 if faces & 1 or not faces & 4 else 180),
                    "width": f"{sw:g}", "depth": f"{sd:g}", "floors_built": str(max(2, min(4, fl - 2))),
                    "site_seed": str(len(sc.nodes) % 97)})
            continue
        tower(cx, cz, round(cw, 1), round(cd, 1), fl, style, setback_from=setback_from, antenna=fl >= 10 and not ent,
              setback=setback, enterable=ent, name=uname("ApartmentBlock") if ent else uname("ShopTower") if op else None,
              shop_faces=0 if ent else faces, open_shop=op)


XB = [(-48, 0), (12, 60), (72, 96)]
ZB = [(150, 198), (210, 258), (270, 318)]
PLAN = {  # (bx, bz) -> (styles, floors min, max, split) or "garage"; the middle block holds the landmarks
    # Point 75 (user, second round): lower again so the city fits the village - 3-8 floors, the landmarks 8-11.
    # Point 76: apartment blocks in the outer blocks, one enterable (stairs + lift to the roof) per marked block.
    (0, 0): (["apartment", "apartment", "brick"], 4, 6, 3, 1), (0, 1): (["apartment", "glass", "bands"], 4, 7, 4, 0, True),
    (0, 2): "garage",
    (1, 0): (["glass", "bands"], 5, 8, 3), (1, 1): (["glass", "bands"], 8, 11, 2),
    (1, 2): (["apartment", "bands", "brick"], 4, 8, 4, 0, True),
    (2, 0): "garage", (2, 1): (["apartment"], 4, 6, 2, 1), (2, 2): (["apartment", "bands", "glass"], 4, 7, 3, 1),
}
for (bx, bz), plan in PLAN.items():
    x0, x1 = XB[bx]
    z0, z1 = ZB[bz]
    if plan == "garage":
        gw, gd = (x1 - x0) - 3, min(40.0, (z1 - z0) - 3)
        put("city/parking_garage.tscn", ((x0 + x1) / 2, 0, (z0 + z1) / 2), 0, parent="City", name=uname("ParkingGarage"),
            props={"width": f"{gw:g}", "depth": f"{gd:g}", "levels": "3"})
    else:
        block_towers(x0, x1, z0, z1, *plan)
# The east strip along the highway boulevard (x 108..140) and the skyline south of the last avenue.
for z0, z1 in ZB:
    block_towers(110, 138, z0, z1, ["apartment", "glass", "bands", "brick"], 3, 7, 2, 1 if z0 == ZB[0][0] else 0,
                 z0 == ZB[2][0])
SKYLINE = [(-36, 360, 30, 28, 7, "bands"), (6, 352, 24, 22, 9, "glass"), (40, 362, 26, 26, 11, "glass"),
           (78, 352, 26, 22, 6, "brick"), (118, 362, 28, 28, 8, "glass")]
for i, (cx, cz, w, d, fl, st) in enumerate(SKYLINE):
    tower(cx, cz, w, d, fl, st, setback_from=fl - 2, antenna=fl >= 10, name=f"Skyscraper{i + 1}", shop_faces=1)
# Plaza between the village and the city (z 114..138): trees and benches; a promenade along the coast (x -66).
for i, x in enumerate(range(-40, 96, 16)):
    tx, tz, tr = x + crng.uniform(-2, 2), 126 + crng.uniform(-3, 3), crng.uniform(0, 360)
    if 20 <= x <= 52:
        continue  # point 96: the city gas station stands here
    put("nature/tree_medium.tscn", (tx, 0, tz), tr, parent="City", props={"tree_seed": str(7100 + i)})
gas_station("City", 36.0, 134.0, 0, "City", title="CITYFUEL")

# Point 103: street detail along the city's straight roads - bins, bike racks, planters, bollards, post boxes on the
# pavement near the kerb, manholes in the lanes. Each kind is ONE PropScatter (MultiMesh: one draw call per mesh).
drng = random.Random(103)
SCATTER = "res://scripts/procgen/prop_scatter.gd"
GARAGE_RECTS = [(XB[bx][0] - 3, XB[bx][1] + 3, ZB[bz][0] - 3, ZB[bz][1] + 3) for (bx, bz), pl in PLAN.items()
                if pl == "garage"] + [(36 - 16, 36 + 16, 134 - 16, 134 + 16)]  # (+ the city gas station's drive-ins)
street = {k: [] for k in ["trash_can", "bike_rack_bikes", "flower_planter", "bollard", "post_box"]}
holes = []
KIND_CYCLE = ["trash_can", "bike_rack_bikes", "flower_planter", "bollard", "flower_planter", "trash_can",
              "bike_rack_bikes", "post_box"]


def _free_spot(x, z):
    return not any(x0 <= x <= x1 and z0 <= z <= z1 for x0, x1, z0, z1 in GARAGE_RECTS)


for a_, b_ in sorted(links):
    horiz = a_[1] == b_[1]
    lo, hi = (a_[0], b_[0]) if horiz else (a_[1], b_[1])
    for side in (-1, 1):
        t = lo + 9.0 + drng.uniform(0, 3)
        while t < hi - 9.0:
            x, z = (t, a_[1] + side * 4.1) if horiz else (a_[0] + side * 4.1, t)
            if _free_spot(x, z):
                kind = drng.choice(KIND_CYCLE)
                yaw = (0 if side > 0 else 180) if horiz else (90 if side > 0 else 270)
                if kind == "bollard":
                    for k in (-0.8, 0.0, 0.8):
                        street[kind].append((x + (k if horiz else 0), 0.15, z + (0 if horiz else k), yaw))
                else:
                    street[kind].append((x, 0.15, z, yaw))
            t += drng.uniform(7.0, 11.0)
    for t in range(lo + 12, hi, 12):
        if drng.random() < 0.4:
            off = drng.choice((-1.75, 1.75))
            holes.append((t + 2.0, 0.0, a_[1] + off, 0) if horiz else (a_[0] + off, 0.0, t + 2.0, 0))


def scatter(name, prefab, pts, collide=True, rng_end=90):
    if not pts:
        return
    flat = ", ".join(f"{v:g}" for pt in pts for v in pt)
    sc.node(name, "Node3D", "City", props={"script": sc.script(SCATTER), "prefab_path": q(prefab),
            "spots": f"PackedFloat32Array({flat})", "range_end": f"{rng_end:g}",
            "collide": "true" if collide else "false"})


for kind, pts in street.items():
    scatter("Street" + "".join(w.capitalize() for w in kind.split("_")), f"res://prefabs/props/{kind}.tscn", pts)
scatter("StreetManholes", "res://prefabs/props/manhole.tscn", holes, collide=False, rng_end=60)
for z in range(150, 330, 18):
    put("nature/tree_medium.tscn", (-66, 0, z), crng.uniform(0, 360), parent="City", props={"tree_seed": str(7200 + z)})
    put("props/bench.tscn", (-64.5, 0.0, z + 9), 270, parent="City", name=uname("CityBench"))

# Traffic for the city -> data/city/city.json (Traffic loads it after routes 0-5).


def lane_route(nodes, uturn=None):
    """Right-hand lane corners (+ fillet radii) of a closed loop through centre-line `nodes`. `uturn` = index of a
    node where the route turns back on itself (two corners 3.5 m apart, radius 1.75)."""
    corners, radii = [], []
    n = len(nodes)
    for i in range(n):
        p, c, nx = nodes[i - 1], nodes[i], nodes[(i + 1) % n]
        din = (c[0] - p[0], c[1] - p[1])
        dout = (nx[0] - c[0], nx[1] - c[1])
        li, lo = _math.hypot(*din), _math.hypot(*dout)
        din, dout = (din[0] / li, din[1] / li), (dout[0] / lo, dout[1] / lo)
        if i == uturn:
            r_in = (-din[1], din[0])
            corners += [(c[0] + r_in[0] * 1.75, c[1] + r_in[1] * 1.75), (c[0] - r_in[0] * 1.75, c[1] - r_in[1] * 1.75)]
            radii += [1.75, 1.75]
            continue
        cross = din[0] * dout[1] - din[1] * dout[0]
        if abs(cross) < 1e-6:
            continue
        ri, ro = (-din[1], din[0]), (-dout[1], dout[0])
        corners.append((c[0] + (ri[0] + ro[0]) * 1.75, c[1] + (ri[1] + ro[1]) * 1.75))
        radii.append(2.5 if cross > 0 else 5.0)  # right turn tight, left turn wide
    return {"corners": [[round(a, 2), round(b, 2)] for a, b in corners], "radii": radii}


city_routes = [
    # 6: Main Road -> highway -> round the whole city -> back up the highway (U-turn on Main Road at x 42).
    lane_route([(42, 0), (HWY_X, 0), (HWY_X, CZ[-1]), (CX[0], CZ[-1]), (CX[0], CZ[0]), (HWY_X, CZ[0]), (HWY_X, 0)], uturn=0),
    # 7 + 8: block loops downtown.
    lane_route([(CX[1], CZ[1]), (CX[2], CZ[1]), (CX[2], CZ[2]), (CX[1], CZ[2])]),
    lane_route([(CX[1], CZ[2]), (CX[0], CZ[2]), (CX[0], CZ[0]), (CX[1], CZ[0])]),
]
city_junctions = [[x, z] for (x, z), ar in arms.items() if len(ar) >= 3]
# Lights at the four inner crossings.
city_lights = [{"at": [CX[1], CZ[1]], "arms": "WENS", "offset": 0.0}, {"at": [CX[2], CZ[1]], "arms": "WENS", "offset": 9.0},
               {"at": [CX[1], CZ[2]], "arms": "WENS", "offset": 18.0}, {"at": [CX[2], CZ[2]], "arms": "WENS", "offset": 27.0}]
_os.makedirs(_os.path.join(ROOT, "data", "city"), exist_ok=True)
with open(_os.path.join(ROOT, "data", "city", "city.json"), "w") as _f:
    _json.dump({"routes": city_routes, "junctions": city_junctions, "lights": city_lights, "cars": 5}, _f, indent=1)

# --------------------------------------------------------------------------- the slums (map blueprint zone 3)
# The empty field north of the centre (x -108..75, z -132..-64): a road loop off North Road (T at (-6, -48)),
# a shanty town inside the loop round an open yard, a caravan park to the north, a junkyard + container homes to
# the east, a cheap shack for sale to the west. Under NavRegion (pedestrians may come here). Rough layout.
srng = random.Random(3030)
SLUM_LOOP = [(-6, -60), (-6, -96), (-78, -96), (-78, -60)]
slum_arms = {(-6, -48): {"S", "E", "N"}, (-6, -60): {"N", "S", "W"}, (-6, -96): {"S", "W"},
             (-78, -96): {"E", "S"}, (-78, -60): {"N", "E"}}
for (x, z), ar in slum_arms.items():
    road_tile(x, z, ar, parent=NAV)
for z in (-72, -84):
    if z != -84:  # (-6, -84): a T since point 80 (Estate Lane)
        put(R + "road_straight.tscn", (-6, 0, z), 90)
    put(R + "road_straight.tscn", (-78, 0, z), 90)
for x in range(-66, -6, 12):
    put(R + "road_straight.tscn", (x, 0, -96), 0)
    put(R + "road_straight.tscn", (x, 0, -60), 0)
sign = put("props/sign_post.tscn", (-1.4, 0.15, -64), 270, name="SlumSign")
sc.node("Label3D", "Label3D", f"{NAV}/{sign}", props={
    "transform": xform((0, 2.6, 0.06)), "text": q("ROSEHILL PARK"), "font_size": "52", "pixel_size": "0.006",
    "modulate": col(1, 1, 1), "outline_size": "0"})

# Packed earth under the shanty town (inside the loop) and the caravan park.
paved("SlumYard", -42, -78, 60, 24, "soil", 0.04)
paved("CaravanPark", -55, -116, 90, 26, "soil", 0.04)
# (Point 80: the junkyard east of the loop became Rosehill Estate - see "new neighbourhoods".)
SHACK = "slums/shack.tscn"
# Shacks along the inside of the loop, the middle (x -46..-34) left open as a yard with fire barrels.
for row_z, rot in ((-70.5, 180), (-85.5, 0)):
    x = -70.0
    while x < -12:
        if -50 < x < -30:
            x = -30
            continue
        w = srng.uniform(3.2, 5.0)
        put(SHACK, (x + w / 2, 0.04, row_z + srng.uniform(-0.8, 0.8)), rot + srng.uniform(-6, 6), name=uname("Shack"),
            props={"size": v3(round(w, 2), round(srng.uniform(2.2, 2.7), 2), round(srng.uniform(2.8, 3.6), 2)),
                   "shack_seed": str(srng.randint(1, 9999))})
        x += w + srng.uniform(0.8, 2.2)
for i, (x, z) in enumerate([(-44, -75), (-25, -78), (-35, -83), (-12, -91), (-40, -109), (-80, -116)]):
    put("slums/fire_barrel.tscn", (x, 0.04, z), 0, name=f"FireBarrel{i + 1}")
# Rubbish: bags, crates, tyres and barrels.
for i in range(46):
    x, z = srng.uniform(-74, -10), srng.uniform(-92, -64)
    if -46 < x < -34 or abs(z - (-70.5)) < 2.2 or abs(z - (-85.5)) < 2.2:
        continue
    kind = srng.choice(["props/trashbag.tscn", "props/trashbag.tscn", "props/crate_flat.tscn", "props/barrel.tscn",
                        "props/trash_can_rusty.tscn"])
    put(kind, (round(x, 2), 0.04, round(z, 2)), srng.uniform(0, 360), name=uname("SlumJunk"))
# Caravan park: three rows of caravans, doors to the paths between.
CARAVAN_BODY = [col(0.92, 0.9, 0.82), col(0.85, 0.86, 0.8), col(0.9, 0.84, 0.7), col(0.8, 0.82, 0.85)]
CARAVAN_STRIPE = [col(0.55, 0.3, 0.2), col(0.25, 0.4, 0.55), col(0.35, 0.5, 0.3), col(0.6, 0.5, 0.2)]
for r, (z, rot) in enumerate([(-106, 180), (-114, 0), (-126, 180)]):
    x = -96.0
    while x < -12:
        ln = srng.uniform(6.0, 8.5)
        put("slums/caravan.tscn", (x + ln / 2, 0.04, z), rot + srng.uniform(-4, 4), name=uname("Caravan"),
            props={"length": f"{ln:.2f}", "body_color": srng.choice(CARAVAN_BODY), "stripe_color": srng.choice(CARAVAN_STRIPE),
                   "awning": "true" if srng.random() < 0.4 else "false", "rust": f"{srng.uniform(0.1, 0.8):.2f}",
                   "caravan_seed": str(srng.randint(1, 9999))})
        x += ln + srng.uniform(3.0, 5.0)
# (Point 80: no junkyard / container homes any more - Rosehill Estate stands there now.)
for i in range(10):  # (keeps srng's sequence for everything after it)
    srng.uniform(6, 26), srng.uniform(-124, -74), srng.uniform(0, 360)
for i in range(8):
    srng.choice([0, 1, 2, 3])
# The cheap property: a tin shack by the west road.
put("buildings/warehouse.tscn", (-94, 0.04, -78), 90, name="SlumShack", props={
    "width": "8", "depth": "7", "floor_height": "3.2", "bays": "2", "door_bay": "0", "variation_seed": "3031",
    "wall_material": q("corrugated"), "wall_tint": col(0.58, 0.55, 0.5), "roof_material": q("roof_dark"),
    "roof_type": q("flat"), "lit_windows": "0.1"})
property_node("SlumShack", "slum_shack", "Rosehill Shack", 4000,
              "Rosehill Park, the slums. A tin shack nobody asks questions about. Cheap, small, out of sight.", 0.0, 3.6)
# Traffic: a loop round the shanty town (route after the city's), the two new junctions.
city_routes.append(lane_route(SLUM_LOOP))
city_junctions += [[-6, -48], [-6, -60]]
with open(_os.path.join(ROOT, "data", "city", "city.json"), "w", newline="\n") as _f:
    _json.dump({"routes": city_routes, "junctions": city_junctions, "lights": city_lights, "cars": 6}, _f, indent=1)

# --------------------------------------------------------------------------- the army base (map blueprint zone 2)
# East of the prison, behind the ridge (out of sight of the village): Fort Halden. A fenced rectangle (x -104..-36,
# z -430..-350) with the gate (boom + guard booth + closed gate) where the pass road ends (-106, -355.65), four
# watchtowers, barracks, two hangars, a parade ground with trucks and jeeps, a helipad, a flag. Closed: not freely
# accessible (guards + missions come in the detail pass). Rough layout.
arng = random.Random(2020)
sc.node("ArmyBase", "Node3D", ".")
AB = (-104.0, -442.0, 236.0, -350.0)  # point 85: was x -104..-36, z -430..-350; now with the airfield east of it
OLIVE = col(0.36, 0.4, 0.27)
SAND = col(0.78, 0.72, 0.58)


def ab_fence(x0, z0, x1, z1, gaps=()):
    if z0 == z1:
        for x in range(int(min(x0, x1)), int(max(x0, x1)), 2):
            if x not in gaps:
                put("props/chainlink_fence.tscn", (x, 0.0, z0), 0, parent="ArmyBase", name=uname("BaseFence"))
    else:
        for z in range(int(min(z0, z1)), int(max(z0, z1)), 2):
            if z not in gaps:
                put("props/chainlink_fence.tscn", (x0, 0.0, z), -90, parent="ArmyBase", name=uname("BaseFence"))


ab_fence(AB[0], AB[1], AB[2], AB[1])
ab_fence(AB[0], AB[3], AB[2], AB[3])
ab_fence(AB[2], AB[1], AB[2], AB[3])
ab_fence(AB[0], AB[1], AB[0], AB[3], gaps=range(-360, -350))
# Point 100: razor wire on the fence top (RazorWire, in 40 m runs so each run's draw distance works per stretch).
RAZOR = "res://scripts/procgen/razor_wire.gd"


def razor_run(prefix, x0, z0, x1, z1):
    along_x = z0 == z1
    a, b = (min(x0, x1), max(x0, x1)) if along_x else (min(z0, z1), max(z0, z1))
    k = 0
    while a < b - 0.5:
        ln = min(40.0, b - a)
        pos = (a, 2.35, z0) if along_x else (x0, 2.35, a)
        sc.node(f"{prefix}{k}", "Node3D", "ArmyBase", props={"script": sc.script(RAZOR),
                "transform": xform(pos, 0 if along_x else -90), "length": f"{ln:g}"})
        a += ln
        k += 1


razor_run("WireN", AB[0], AB[1], AB[2], AB[1])
razor_run("WireS", AB[0], AB[3], AB[2], AB[3])
razor_run("WireE", AB[2], AB[1], AB[2], AB[3])
razor_run("WireW", AB[0], AB[1], AB[0], -360.0)
# The gate (point 100): an automatic sliding gate - only cars, walking soldiers and players with a pass open it (the
# host decides) - and the red-and-white boom outside lifts with it.
sc.node("BaseGate", "Node3D", "ArmyBase", props={"script": sc.script("res://scripts/world/sliding_gate.gd"),
        "transform": xform((AB[0] + 0.3, 0.0, -355.0), 90), "width": "10.0", "height": "3.0",
        "needs_army_pass": "true"})
sc.node("BaseBoom", "Node3D", "ArmyBase", props={"script": sc.script("res://scripts/world/boom_gate.gd"),
        "transform": xform((AB[0] - 2.5, 0.0, -359.6), 90), "length": "7.0",
        "follow_gate": 'NodePath("../BaseGate")'})
pbox("GuardBooth", (AB[0] - 4.0, 0.0, -362.5), (3.0, 2.8, 3.0), "concrete", SAND, parent="ArmyBase")
pbox("GuardBoothRoof", (AB[0] - 4.0, 2.8, -362.5), (3.6, 0.2, 3.6), "metal_dark", OLIVE, parent="ArmyBase")
sign = put("props/sign_post.tscn", (AB[0] - 6.5, 0.0, -350.6), 270, parent="ArmyBase", name="BaseSign")
sc.node("Label3D", "Label3D", f"ArmyBase/{sign}", props={
    "transform": xform((0, 2.6, 0.06)), "text": q("FORT HALDEN\nMILITARY AREA - NO ENTRY"), "font_size": "40",
    "pixel_size": "0.006", "modulate": col(1, 0.85, 0.3), "outline_size": "6"})
# Inside: a concrete road from the gate, the parade ground, a helipad.
paved("BaseRoad", -70, -355.65, 66, 8, "concrete", 0.04)
paved("ParadeGround", -70, -375, 60, 30, "concrete", 0.04)
paved("Helipad", -45, -393, 16, 16, "concrete", 0.05)
for name, pos, size in [("HelipadH1", (-47.5, 0.1, -393), (0.8, 0.02, 7)), ("HelipadH2", (-42.5, 0.1, -393), (0.8, 0.02, 7)),
                        ("HelipadH3", (-45, 0.1, -393), (5.8, 0.02, 0.8))]:
    pbox(name, pos, size, "road_marking", col(1, 1, 1), parent="ArmyBase", collision=False)
# Watchtowers at the corners.
for i, (x, z) in enumerate([(AB[0] + 3, AB[1] + 3), (AB[2] - 3, AB[1] + 3), (AB[2] - 3, AB[3] - 3), (AB[0] + 3, AB[3] - 14),
                            (80.0, AB[1] + 3), (-34.0, AB[3] - 3)]):
    put("army/watchtower.tscn", (x, 0.0, z), 0, parent="ArmyBase", name=f"Watchtower{i + 1}")
# Barracks along the north fence, two hangars facing the parade ground. Point 100: walk-in prefabs (dormitories
# with bunks + lockers, open-front vehicle hangars) in the same footprints as the warehouses they replace; behind the
# barracks the armoury and the command post.
for i, x in enumerate([-90, -70, -50]):
    put("army/barracks.tscn", (x, 0.04, -412), 0, parent="ArmyBase", name=f"Barracks{i + 1}")
for i, x in enumerate([-92, -69]):  # (point 85: moved west from -90 / -64 to make room for the airfield)
    put("army/hangar.tscn", (x, 0.04, -391), 0, parent="ArmyBase", name=f"Hangar{i + 1}")
put("army/armoury.tscn", (-72, 0.04, -428), 0, parent="ArmyBase", name="Armoury")
put("army/command_post.tscn", (-53, 0.04, -428), 0, parent="ArmyBase", name="CommandPost")
paved("ArmyBackRoad", -66, -424, 44, 6, "concrete", 0.04, parent="ArmyBase")
# Sandbags: the gate post inside, the post outside the boom, a machine-gun nest at the parade ground's east end.
for i, (x, z, rot, ln) in enumerate([(-102.0, -362.0, 90, 3.0), (-108.5, -349.6, 90, 3.0),
                                     (-36.0, -368.4, 0, 3.6), (-37.8, -370.0, 90, 3.0), (-34.2, -370.0, 90, 3.0)]):
    put("army/sandbags.tscn", (x, 0.04, z), rot, parent="ArmyBase", name=f"Sandbags{i + 1}",
        props={"length": f"{ln:g}", "rows": "4"})
# Vehicles on the parade ground.
for i, (x, z, kind, rot) in enumerate([(-92, -370, "truck", 0), (-86, -370, "truck", 0), (-80, -370, "truck", 0),
                                       (-72, -368, "jeep", 0), (-67, -368, "jeep", 0), (-52, -380, "truck", 90),
                                       (-48, -368, "jeep", 0), (-44, -372, "jeep", 20)]):
    put("army/army_truck.tscn", (x, 0.04, z), rot + arng.uniform(-3, 3), parent="ArmyBase", name=f"ArmyTruck{i + 1}",
        props={"kind": q(kind)})
# Flagpole + crates.
pbox("FlagPole", (-70, 0.0, -362), (0.15, 9.0, 0.15), "item_metal", col(0.8, 0.8, 0.8), parent="ArmyBase")
pbox("Flag", (-70, 7.6, -363.1), (0.04, 1.3, 2.0), "item_matte", col(0.2, 0.3, 0.55), parent="ArmyBase", collision=False)
for i in range(8):
    put("props/crate_long.tscn", (arng.uniform(-100, -82), 0.04, arng.uniform(-428, -420)), arng.choice([0, 90]),
        parent="ArmyBase", name=uname("ArmyCrate"))

# ---- Point 85: the airfield (east part of the base): runway along x at z -425, taxiway z -404, apron + three jet
# hangars opening north, a control tower + ops building, a windsock. Airfield (scripts/world/airfield.gd) flies one
# jet per JetHangar (local per peer, shared clock). Not under NavRegion: no navmesh bake for 9000 m2 of concrete.
RW_X0, RW_X1, RW_Z, RW_W = -20.0, 230.0, -425.0, 22.0
TX_Z, TX_W = -404.0, 12.0
LINK_X0, LINK_X1 = -8.0, 215.0
YELLOW = col(0.95, 0.75, 0.15)
paved("Runway", (RW_X0 + RW_X1) / 2, RW_Z, RW_X1 - RW_X0, RW_W, "asphalt", 0.04, parent="ArmyBase")
paved("Taxiway", (LINK_X0 - 6 + LINK_X1 + 6) / 2, TX_Z, LINK_X1 - LINK_X0 + 12, TX_W, "asphalt", 0.035, parent="ArmyBase")
for i, lx in enumerate((LINK_X0, LINK_X1)):
    paved(f"TaxiLink{i + 1}", lx, (TX_Z + RW_Z) / 2, TX_W, TX_Z - RW_Z - 1, "asphalt", 0.035, parent="ArmyBase")
paved("Apron", 100.0, -391.0, 124.0, 14.0, "concrete", 0.04, parent="ArmyBase")
# Markings: centre dashes, edge lines, threshold stripes, the runway numbers; a yellow taxiway line.
for x in range(int(RW_X0) + 30, int(RW_X1) - 25, 15):
    pbox(uname("RunwayDash"), (x, 0.05, RW_Z), (7.0, 0.02, 0.5), "road_marking", col(1, 1, 1), parent="ArmyBase", collision=False)
for side in (-1, 1):
    pbox(uname("RunwayEdge"), ((RW_X0 + RW_X1) / 2, 0.05, RW_Z + side * (RW_W / 2 - 0.8)), (RW_X1 - RW_X0 - 2, 0.02, 0.35),
         "road_marking", col(1, 1, 1), parent="ArmyBase", collision=False)
for end, x in (("W", RW_X0 + 8.0), ("E", RW_X1 - 8.0)):
    for k in range(8):
        z = RW_Z - RW_W / 2 + 2.2 + k * 2.45 + (1.2 if k >= 4 else 0)
        pbox(f"Threshold{end}{k}", (x, 0.05, z), (10.0, 0.02, 1.2), "road_marking", col(1, 1, 1), parent="ArmyBase", collision=False)
# Runway numbers painted flat (Euler YXZ: lie face up, then turn so the top of the text points the way a pilot lands).
for name, x, yaw, text in (("RunwayNumW", RW_X0 + 22.0, -1.5708, "09"), ("RunwayNumE", RW_X1 - 22.0, 1.5708, "27")):
    sc.node(name, "Label3D", "ArmyBase", props={"position": f"Vector3({x:g}, 0.07, {RW_Z:g})",
            "rotation": f"Vector3(-1.5708, {yaw}, 0)", "text": q(text), "font_size": "640", "pixel_size": "0.01",
            "modulate": col(1, 1, 1), "outline_size": "0", "double_sided": "false"})
for x in range(int(LINK_X0), int(LINK_X1), 6):
    pbox(uname("TaxiLine"), (x + 1.5, 0.045, TX_Z), (3.0, 0.02, 0.25), "road_marking", YELLOW, parent="ArmyBase", collision=False)
# Edge lights along the runway (glowing studs, no light nodes).
for x in range(int(RW_X0), int(RW_X1) + 1, 25):
    for side in (-1, 1):
        pbox(uname("RunwayLight"), (x, 0.0, RW_Z + side * (RW_W / 2 + 0.8)), (0.3, 0.35, 0.3), "lamp_glow",
             col(1, 0.95, 0.7), parent="ArmyBase", collision=False)
# Three jet hangars south of the apron, doors to the north (they run back along +Z from the door).
for i, x in enumerate((60.0, 100.0, 140.0)):
    sc.node(f"JetHangar{i + 1}", "StaticBody3D", "ArmyBase", props={
        "script": sc.script("res://scripts/procgen/jet_hangar.gd"), "transform": xform((x, 0.0, -384.0)),
        "number": q(str(i + 1)), "tint": OLIVE})
sc.node("Airfield", "Node3D", "ArmyBase", props={
    "script": sc.script("res://scripts/world/airfield.gd"), "runway_x0": f"{RW_X0:g}", "runway_x1": f"{RW_X1:g}",
    "runway_z": f"{RW_Z:g}", "taxi_z": f"{TX_Z:g}", "link_x0": f"{LINK_X0:g}", "link_x1": f"{LINK_X1:g}"})
# Control tower: a concrete shaft, a glass cab on top, roof + antenna; the ops building at its foot.
TWR = (20.0, -380.0)
pbox("TowerShaft", (TWR[0], 0.0, TWR[1]), (4.0, 15.0, 4.0), "concrete", col(0.8, 0.78, 0.72), parent="ArmyBase")
pbox("TowerCabFloor", (TWR[0], 15.0, TWR[1]), (7.4, 0.5, 7.4), "concrete", col(0.75, 0.73, 0.68), parent="ArmyBase")
pbox("TowerCab", (TWR[0], 15.5, TWR[1]), (7.0, 3.2, 7.0), "glass_shop", col(0.55, 0.7, 0.8), parent="ArmyBase")
pbox("TowerRoof", (TWR[0], 18.7, TWR[1]), (8.0, 0.4, 8.0), "metal_dark", col(0.3, 0.3, 0.3), parent="ArmyBase")
pbox("TowerAntenna", (TWR[0] + 2.5, 19.1, TWR[1] + 2.5), (0.12, 4.0, 0.12), "item_metal", col(0.8, 0.8, 0.8), parent="ArmyBase")
pbox("TowerBeacon", (TWR[0] + 2.5, 23.1, TWR[1] + 2.5), (0.3, 0.3, 0.3), "lamp_glow", col(1, 0.2, 0.15), parent="ArmyBase",
     collision=False)
put("buildings/warehouse.tscn", (TWR[0], 0.04, -362.0), 0, parent="ArmyBase", name="OpsBuilding", props={
    "width": "16", "depth": "8", "floor_height": "3.6", "bays": "4", "door_bay": "1", "variation_seed": "2085",
    "wall_material": q("plaster"), "wall_tint": SAND, "roof_material": q("roof_dark"), "roof_type": q("flat"),
    "lit_windows": "0.5"})
sc.node("Label3D", "Label3D", "ArmyBase/TowerCab", props={
    "transform": xform((0, 3.6, 3.56)), "text": q("FORT HALDEN AIRFIELD"), "font_size": "64", "pixel_size": "0.01",
    "modulate": col(0.95, 0.9, 0.7), "outline_size": "6"})
# Windsock by the west threshold.
pbox("WindsockPole", (-14.0, 0.0, -440.0), (0.12, 6.0, 0.12), "item_metal", col(0.85, 0.85, 0.85), parent="ArmyBase")
pbox("Windsock", (-12.6, 5.4, -440.0), (2.6, 0.7, 0.7), "item_matte", col(0.95, 0.45, 0.1), parent="ArmyBase", collision=False)
# Guards (session B's soldiers stand at ArmyPost* markers, -Z = where they look; "Chat" = chatting pairs) and two
# patrols (ArmyPatrolA*/B*, straight legs under 150 m (Soldier walks no longer legs), closed loops - no walls on them).
for name, pos, rot in [("ArmyPostGate1", (-106.5, -350.4), 90), ("ArmyPostGate2", (-100.5, -361.5), 90),
                       ("ArmyPostFlag1", (-72.5, -360.5), 180), ("ArmyPostFlag2", (-67.5, -360.5), 180),
                       ("ArmyPostChatGarage1a", (-94.0, -382.5), -90), ("ArmyPostChatGarage1b", (-92.6, -382.5), 90),
                       ("ArmyPostChatGarage2a", (-71.0, -382.5), -90), ("ArmyPostChatGarage2b", (-69.6, -382.5), 90),
                       ("ArmyPostChatHeli1", (-49.5, -386.5), 135), ("ArmyPostChatHeli2", (-48.3, -387.4), -45),
                       ("ArmyPostHeli3", (-40.5, -398.5), 180), ("ArmyPostVehicles1", (-89.0, -366.5), 0),
                       ("ArmyPostVehicles2", (-69.5, -365.5), 0), ("ArmyPostTower", (14.5, -376.0), 0),
                       ("ArmyPostChatApron1a", (80.0, -387.0), -90), ("ArmyPostChatApron1b", (81.4, -387.0), 90),
                       ("ArmyPostChatApron2a", (120.0, -387.0), -90), ("ArmyPostChatApron2b", (121.4, -387.0), 90),
                       ("ArmyPostRunwayW", (-16.0, -439.0), 180), ("ArmyPostRunwayE", (233.0, -412.0), 90)]:
    sc.node(name, "Marker3D", "ArmyBase", props={"transform": xform((pos[0], 0.1, pos[1]), rot)})
for route, pts in (("A", [(-98.0, -357.5), (-98.0, -377.0), (-57.0, -377.0), (-57.0, -357.5)]),
                   ("B", [(-40.0, -356.0), (60.0, -356.0), (160.0, -356.0), (228.0, -356.0), (228.0, -392.0),
                         (172.0, -392.0), (172.0, -359.0), (66.0, -359.0)])):
    for k, (x, z) in enumerate(pts):
        sc.node(f"ArmyPatrol{route}{k + 1}", "Marker3D", "ArmyBase", props={"transform": xform((x, 0.1, z))})
sc.node("ArmyBaseSpot", "Marker3D", "ArmyBase", props={"transform": xform((-112.0, 0.1, -352.5), 90)})

# --------------------------------------------------------------------------- new neighbourhoods (point 71)
# User feedback 2026-11-15 (docs/feedback_open_spaces.png): the empty fields round the centre get streets, row houses,
# detached houses with driveways, a pocket park, a square with small shops. The new houses are NOT enterable (no
# interiors: cheap to draw + bake). Green stays between the zones: a park strip west of the highway, a tree belt east
# of it and the plaza strip before the city (z 106..140).
#   Southfield: Garden Row (z 84) from the harbour bend (-66, 84) to the highway (102, 84); the side road x 30 runs on
#   from South Street to it. North-east: North Road on east to (90, -48), then down x 90 to Main Road (90, 0).
nrng = random.Random(7171)
FACING_ROT = {"S": 0, "N": 180, "E": 90, "W": 270}
INTO = {"S": -1, "N": 1, "E": -1, "W": 1}  # from the street into the lot (z for S/N, x for E/W)


def _xz(along, depth, facing):
    return (along, depth) if facing in "SN" else (depth, along)


def nhouse(along, front, facing, w, depth=9.0, props=None, name=None):
    """A non-enterable house; `along` = its middle along the street, `front` = the line of its front wall."""
    x, z = _xz(along, front, facing)
    p = {"width": f"{w:.2f}", "depth": f"{depth:g}", "variation_seed": str(nrng.randint(1, 9999)),
         "door_color": nrng.choice(DOORS), "enterable": "false", "upper_floors": "false", "furnish": q("none"),
         "floors": str(nrng.choice([2, 2, 3]))}
    wm = nrng.choice(WALLS)
    p["wall_material"] = q(wm)
    p["wall_tint"] = nrng.choice(PLASTER_TINTS) if wm == "plaster" else ptint(wm, MATERIAL_SWATCH[wm], nrng.uniform(0.92, 1.04))
    rm, rs = nrng.choice(ROOFS)
    p["roof_material"] = q(rm)
    p["roof_tint"] = ptint(rm, rs)
    if props:
        p.update(props)
    return put(f"buildings/row_house_{nrng.choice('abcdef')}.tscn", (round(x, 2), 0, round(z, 2)),
               FACING_ROT[facing] + nrng.uniform(-0.3, 0.3), props=p, name=name or uname("NHouse"))


def nrow(a0, a1, street_edge, facing, gardens=None):
    """Row houses with their fronts on the street edge, from a0 to a1 along the street."""
    a = a0
    while a < a1 - 4.5:
        w = nrng.uniform(5.0, 7.2)
        if a1 - (a + w) < 4.6:
            w = a1 - a
        nhouse(a + w / 2, street_edge, facing, w)
        if gardens is not None:
            gardens.append((a, a + w))
        a += w


def nhedge(along0, along1, depth, facing, across=False):
    x, z = _xz((along0 + along1) / 2, depth, facing)
    rot = 0 if (facing in "SN") != across else 90
    put("nature/hedge.tscn", (round(x, 2), 0, round(z, 2)), rot, name=uname("NHedge"),
        props={"size": v3(abs(along1 - along0), 1.2, 0.7), "hedge_seed": str(nrng.randint(1, 99))})


def villa(lot0, street_edge, facing, lot_w=12.0):
    """A detached house set back 3 m, a driveway along one side (sometimes a covered car on it), hedges."""
    s = INTO[facing]
    left = nrng.random() < 0.5
    house_a = lot0 + (4.5 if left else lot_w - 4.5)
    drive_a = lot0 + (lot_w - 1.8 if left else 1.8)
    nhouse(house_a, street_edge + s * 3.0, facing, 8.0, 8.5, props={
        "side_windows": "true", "roof_type": q(nrng.choice(["hip", "gable"])), "floors": str(nrng.choice([1, 2, 2])),
        "chimney": q(nrng.choice(["left", "right", "none"]))}, name=uname("Villa"))
    dx, dz = _xz(drive_a, street_edge + s * 6.0, facing)
    sx, sz = _xz(3.0, 12.0, facing)
    paved(uname("Driveway"), dx, dz, sx, sz, "concrete", 0.04)
    if nrng.random() < 0.45:
        cx, cz = _xz(drive_a, street_edge + s * 5.0, facing)
        put("props/covered_car.tscn", (round(cx, 2), 0.04, round(cz, 2)), FACING_ROT[facing] + nrng.uniform(-4, 4),
            name=uname("DrivewayCar"))
    a0, a1 = (lot0 + 0.3, lot0 + lot_w - 3.6) if left else (lot0 + 3.6, lot0 + lot_w - 0.3)
    nhedge(a0, a1, street_edge + s * 0.8, facing)
    # The hedge between this lot and the previous one (along the depth).
    hx, hz = _xz(lot0, street_edge + s * 7.5, facing)
    put("nature/hedge.tscn", (round(hx, 2), 0, round(hz, 2)), 90 if facing in "SN" else 0, name=uname("NHedge"),
        props={"size": v3(12.0, 1.2, 0.6), "hedge_seed": str(nrng.randint(1, 99))})
    if nrng.random() < 0.5:
        tx, tz = _xz(lot0 + nrng.uniform(2, lot_w - 2), street_edge + s * 13.0, facing)
        put("nature/tree_medium.tscn", (round(tx, 2), 0, round(tz, 2)), nrng.uniform(0, 360), name=uname("GardenTree"),
            props={"tree_seed": str(nrng.randint(1, 999))})


def nshop(along, street_edge, facing, w, sign, awning_col):
    return nhouse(along, street_edge, facing, w, 10.0, props={
        "ground_floor": q("shop"), "shop_sign": q(sign), "awning": "true", "awning_color": awning_col,
        "floors": str(nrng.choice([2, 3])), "wall_material": q(nrng.choice(["brick_old", "brick_mixed", "brick_yellow"]))},
        name=uname("NShop"))


def lamps_x(x0, x1, z_road, step=24, skip=()):
    """Lamps both sides of an E-W road, staggered; `skip` = x of junctions (no lamp in their mouths)."""
    for x in range(int(x0), int(x1), step):
        for lx, lz, r in ((x, z_road - 3.95, 180), (x + step // 2, z_road + 3.95, 0)):
            if all(abs(lx - j) > 6.5 for j in skip):
                put("props/street_lamp.tscn", (lx, 0.15, lz), r, name=uname("NLamp"))


def lamps_z(z0, z1, x_road, step=24):
    for z in range(int(z0), int(z1), step):
        put("props/street_lamp.tscn", (x_road - 3.95, 0.15, z), 90, name=uname("NLamp"))
        put("props/street_lamp.tscn", (x_road + 3.95, 0.15, z + step // 2), 270, name=uname("NLamp"))


# Roads: Southfield.
road_tile(30, 60, {"N", "W", "S"}, parent=NAV)
put(R + "road_straight.tscn", (30, 0, 72), 90, name=uname("NRoad"))
road_tile(30, 84, {"N", "W", "E"}, parent=NAV)
road_tile(-66, 84, {"N", "W", "E"}, parent=NAV)
road_tile(HWY_X, 84, {"N", "S", "W"}, parent=NAV)
for x in range(-54, 91, 12):
    if x != 30:
        put(R + "road_straight.tscn", (x, 0, 84), 0, name=uname("NRoad"),
            props={"crossing": "true"} if x in (-6, 66) else None)
# Roads: the north-east (North Road on to x 90, down to Main Road).
put(R + "road_straight.tscn", (78, 0, -48), 0, name=uname("NRoad"))
road_tile(90, -48, {"W", "S", "N"}, parent=NAV)  # (point 80: on north to Estate Lane)
for z in (-36, -24, -12):
    put(R + "road_straight.tscn", (90, 0, z), 90, name=uname("NRoad"))
road_tile(90, 0, {"W", "E", "N"}, parent=NAV)
put("props/sign_post.tscn", (24.6, 0.15, 80.3), 180, name="GardenRowSign", props={"sign_text": q("GARDEN ROW")})
put("props/sign_post.tscn", (84.6, 0.15, -3.72), 0, name="OrchardLaneSign", props={"sign_text": q("ORCHARD LANE")})
lamps_x(-54, 90, 84)
lamps_z(-42, -6, 90)

# Southfield, north side of Garden Row (fronts on z 78, back gardens to z 66.6 behind South Street's lamps).
g1 = []
nrow(-59.5, -12.0, 78.0, "S", g1)
garden_fences(g1, 69.0, 66.6)
SHOPS = [("CORNER DELI", col(0.15, 0.35, 0.2)), ("PHARMACY", col(0.1, 0.4, 0.45)), ("CAFE LENA", col(0.55, 0.18, 0.12)),
         ("HAIR BY INES", col(0.45, 0.2, 0.4)), ("BOOKS", col(0.2, 0.25, 0.45)), ("FLOWERS", col(0.5, 0.45, 0.1))]
a = -11.0
for i in range(3):
    nshop(a + 3.75, 78.0, "S", 7.5, *SHOPS[i])
    a += 7.7
for i in range(2):  # two more homes up to the side road x 30
    nhouse(a + 3.4 + i * 6.9, 78.0, "S", 6.8)
g2 = []
nrow(37.0, 95.0, 78.0, "S", g2)
garden_fences(g2, 69.0, 66.6)
# Southfield, south side (fronts face north onto z 90): detached houses, the pocket park, the square + shops.
for lot in range(-60, -12, 12):
    villa(lot, 90.0, "N")
# Pocket park (x -11..22): paths, trees, benches, a sandpit + swings, planters.
paved("ParkPathN", 5.5, 92.0, 33.0, 2.0, "sidewalk", 0.03)
paved("ParkPathX", 5.5, 97.5, 2.0, 9.0, "sidewalk", 0.03)
for i, (x, z) in enumerate([(-8, 97), (-3, 103), (13, 96), (19, 102), (-9, 103), (16, 103), (1, 102), (10, 104)]):
    put("nature/tree_medium.tscn", (x, 0, z), nrng.uniform(0, 360), name=uname("ParkTree"),
        props={"tree_seed": str(7300 + i)})
for x, z, r in [(3.4, 96.5, 90), (7.6, 96.5, 270), (-4, 93.6, 180), (15, 93.6, 180)]:
    put("props/bench.tscn", (x, 0.03, z), r, name=uname("ParkBench"))
pbox("Sandpit", (-2.0, 0.0, 99.5), (4.0, 0.25, 4.0), "planks", col(0.55, 0.42, 0.28))
paved("SandpitSand", -2.0, 99.5, 3.4, 3.4, "soil", 0.27)
for x in (9.0, 12.5):
    for z in (100.0, 102.0):
        pbox(uname("SwingPost"), (x, 0.0, z), (0.15, 2.4, 0.15), "item_metal", col(0.85, 0.3, 0.2))
    pbox(uname("SwingBar"), (x, 2.4, 101.0), (0.15, 0.12, 2.15), "item_metal", col(0.85, 0.3, 0.2), collision=False)
pbox("SwingTop", (10.75, 2.4, 101.0), (3.65, 0.12, 0.12), "item_metal", col(0.85, 0.3, 0.2), collision=False)
put("props/planter_box.tscn", (-10.0, 0.03, 91.6), 0, name=uname("ParkPlanter"))
put("props/planter_box.tscn", (21.0, 0.03, 91.6), 0, name=uname("ParkPlanter"))
put("props/trash_can.tscn", (5.5, 0.03, 90.8), 0, name=uname("ParkBin"))
# The square south of the Garden Row / x 30 junction, with shops on its east side.
paved("SouthfieldSquare", 29.0, 97.0, 12.0, 14.0, "cobbles", 0.04)
for x, z in [(25, 93), (33, 93), (25, 101), (33, 101)]:
    put("nature/tree_medium.tscn", (x, 0, z), nrng.uniform(0, 360), name=uname("SquareTree"),
        props={"tree_seed": str(nrng.randint(1, 999))})
put("props/bench.tscn", (29.0, 0.04, 97.0), 90, name=uname("SquareBench"))
put("props/post_box.tscn", (34.3, 0.04, 90.8), 0, name=uname("SquarePostBox"))
put("props/bike_rack.tscn", (23.6, 0.04, 95.0), 90, name=uname("SquareBikes"))
a = 36.0
for i in range(3, 6):
    nshop(a + 3.5, 90.0, "N", 7.0, *SHOPS[i])
    a += 7.2
for lot in (58, 70, 82):
    villa(lot, 90.0, "N")

# North-east (Orchard Lane, x 90): row houses facing it from the west (fronts on x 84), detached houses on the east.
nrow(-41.0, -7.0, 84.0, "E")
for lot in (-41.5, -29.5, -17.5):
    villa(lot, 96.0, "W", 11.0)
# Allotments north of North Road's new stretch (x 73..83, z -55..-79; point 80: Orchard Lane runs on north at x 90).
for x in (75.5, 80.5):
    for z in (-58.5, -64.5, -70.5, -76.5):
        paved(uname("Allotment"), x, z, 4.5, 5.0, "soil", 0.06)
pbox("AllotmentShed", (78.0, 0.0, -80.0), (3.0, 2.2, 1.6), "planks", col(0.45, 0.32, 0.2))
fence_line(73.0, -55.0, 83.0, -55.0, gaps=(77,))

# Green between the zones: a park strip west of the highway (x 75..95, z 12..62) and a tree belt east of it.
paved("EastParkPath", 85.0, 37.0, 2.0, 50.0, "sidewalk", 0.03)
for i in range(16):
    x, z = nrng.uniform(75, 95), nrng.uniform(13, 62)
    if abs(x - 85) < 2.5:
        continue
    put(f"nature/tree_{nrng.choice(['medium', 'large'])}.tscn", (round(x, 1), 0, round(z, 1)), nrng.uniform(0, 360),
        name=uname("EastParkTree"), props={"tree_seed": str(7500 + i)})
for z in (24, 44, 58):
    put("props/bench.tscn", (83.6, 0.03, z), 90, name=uname("EastParkBench"))
for i in range(36):
    x, z = nrng.uniform(112, 138), nrng.uniform(-66, 104)
    put(f"nature/tree_{nrng.choice(['medium', 'large'])}.tscn", (round(x, 1), 0, round(z, 1)), nrng.uniform(0, 360),
        name=uname("EastBeltTree"), props={"tree_seed": str(7600 + i)})

# Point 78: Dock Road (x -186) joins the west ends of Main Road and Quay Road (no more dead ends at the docks).
road_tile(-186, 0, {"E", "S"}, parent=NAV)
for z in range(12, 84, 12):
    put(R + "road_straight.tscn", (-186, 0, z), 90, name=uname("DockRoad"))
road_tile(-186, 84, {"E", "N"}, parent=NAV)
for z in (18, 42, 66):
    put("props/street_lamp.tscn", (-182.05, 0.15, z), 270, name=uname("NLamp"))
put("props/sign_post.tscn", (-180.4, 0.15, 6.4), 270, name="DockRoadSign", props={"sign_text": q("DOCK ROAD")})
city_routes.append(lane_route([(-114, 0), (-186, 0), (-186, 84), (-114, 84)]))


# Point 80: Rosehill Estate - the old junkyard + container lot east of the slums (x 0..72, z -130..-62) as a housing
# estate with the original row-house prefabs: Estate Lane (z -84) from the slums loop to x 66 and up to North Road,
# an inner loop (x 18 / z -120 / x 54) round a block of terraces, detached houses, a small park, gardens.
erng = random.Random(8080)
for x in range(6, 66, 12):
    if x not in (18, 54):
        put(R + "road_straight.tscn", (x, 0, -84), 0, name=uname("NRoad"), props={"crossing": "true"} if x == 42 else None)
road_tile(-6, -84, {"N", "S", "E"}, parent=NAV)
road_tile(18, -84, {"W", "E", "N"}, parent=NAV)
road_tile(54, -84, {"W", "E", "N"}, parent=NAV)
road_tile(66, -84, {"W", "S", "E"}, parent=NAV)
put(R + "road_straight.tscn", (78, 0, -84), 0, name=uname("NRoad"))
road_tile(90, -84, {"W", "S"}, parent=NAV)
for z in (-60, -72):
    put(R + "road_straight.tscn", (90, 0, z), 90, name=uname("NRoad"))
lamps_z(-78, -54, 90)
# East of the estate: terraces along Estate Lane's east stretch, detached houses on Orchard Lane's north end.
gF = []
nrow(72.5, 101.0, -90.0, "S", gF)
garden_fences(gF, -99.0, -106.0)
for lot in (-78.0, -66.0):
    villa(lot, 96.0, "W", 12.0)
for i, x in enumerate(range(76, 104, 7)):
    put("nature/tree_medium.tscn", (x + erng.uniform(-1, 1), 0, -112.0 + erng.uniform(-2, 2)), erng.uniform(0, 360),
        name=uname("EstateTree"), props={"tree_seed": str(8300 + i)})
for z in (-72, -60):
    put(R + "road_straight.tscn", (66, 0, z), 90, name=uname("NRoad"))
road_tile(66, -48, {"W", "E", "N"}, parent=NAV)
for z in (-96, -108):
    put(R + "road_straight.tscn", (18, 0, z), 90, name=uname("NRoad"))
    put(R + "road_straight.tscn", (54, 0, z), 90, name=uname("NRoad"))
road_tile(18, -120, {"S", "E"}, parent=NAV)
road_tile(54, -120, {"S", "W"}, parent=NAV)
for x in (30, 42):
    put(R + "road_straight.tscn", (x, 0, -120), 0, name=uname("NRoad"))
put("props/sign_post.tscn", (1.6, 0.15, -78.4), 0, name="EstateSign", props={"sign_text": q("ESTATE LANE")})
lamps_x(6, 60, -84, skip=(54, 66))
lamps_z(-114, -90, 18)
lamps_z(-114, -90, 54)
lamps_z(-78, -54, 66)
# Between North Road and Estate Lane: terraces facing the lane, back gardens up to the gas station's back.
gE = []
nrow(1.0, 59.5, -78.0, "N", gE)
garden_fences(gE, -69.0, -62.8)
# The block inside the inner loop: terraces back to back (gardens between).
gB1, gB2 = [], []
nrow(24.5, 47.5, -90.0, "S", gB1)
nrow(24.5, 47.5, -114.0, "N", gB2)
garden_fences(gB1, -99.0, -102.0, back_fence=True)
garden_fences(gB2, -105.0, -102.0, back_fence=False)
# Detached houses with driveways west of x 18 and along Estate Lane's south end.
for lot in (-114.0, -102.0):
    villa(lot, 12.0, "E")
# A small park east of the inner loop (x 61..72, z -128..-91): a path, trees, benches, a sandpit.
paved("EstateParkPath", 66.0, -109.0, 2.0, 34.0, "sidewalk", 0.03)
for i, (x, z) in enumerate([(62.5, -94), (69.5, -99), (62.5, -106), (69.5, -113), (62.5, -120), (69.5, -125)]):
    put("nature/tree_medium.tscn", (x, 0, z), erng.uniform(0, 360), name=uname("EstateParkTree"),
        props={"tree_seed": str(8100 + i)})
for z in (-102.0, -117.0):
    put("props/bench.tscn", (64.6, 0.03, z), 90, name=uname("EstateBench"))
pbox("EstateSandpit", (69.0, 0.0, -106.0), (3.0, 0.25, 3.0), "planks", col(0.55, 0.42, 0.28))
paved("EstateSand", 69.0, -106.0, 2.5, 2.5, "soil", 0.27)
# South of the inner loop: a hedge + a row of trees towards the border.
nhedge(13.0, 59.0, -127.6, "S")
for i, x in enumerate(range(16, 60, 9)):
    put("nature/tree_medium.tscn", (x + erng.uniform(-1, 1), 0, -130.5), erng.uniform(0, 360), name=uname("EstateTree"),
        props={"tree_seed": str(8200 + i)})
city_routes.append(lane_route([(-6, -84), (66, -84), (66, -48), (-6, -48)]))
city_routes.append(lane_route([(18, -84), (54, -84), (54, -120), (18, -120)]))
city_routes.append(lane_route([(66, -84), (90, -84), (90, -48), (66, -48)]))
city_junctions += [[-6, -84], [18, -84], [54, -84], [66, -48], [66, -84], [90, -48]]

# Traffic: the Southfield loop and the north-east loop (after the city + slum routes).
city_routes.append(lane_route([(30, 60), (30, 84), (-66, 84), (-66, 60)]))
city_routes.append(lane_route([(30, 0), (90, 0), (90, -48), (30, -48)]))
city_junctions += [[30, 84], [-66, 84], [HWY_X, 84], [90, 0]]
with open(_os.path.join(ROOT, "data", "city", "city.json"), "w") as _f:
    _json.dump({"routes": city_routes, "junctions": city_junctions, "lights": city_lights, "cars": 8}, _f, indent=1)


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
PRISON_POS = (-150, 0, -385)  # point 49b: behind the mountain, at the end of the pass road
put("buildings/prison.tscn", PRISON_POS, 0, parent=".", name="Prison")
gas_station("Prison", -128.0, -346.85, 180, ".", title="LAST STOP FUEL")
# Point 49b: the bus comes down Country Lane and drives east, so the stop is on the south side now (facing the road).
sc.node("BusStop", "Marker3D", "Markers", props={"transform": xform((-60.0, 0.15, 4.7), 0)})
# Session B's shooting range (RangeClub): out of the pass road's way, north of the centre.
sc.node("ShootingRangeSpot", "Marker3D", "Markers", props={"transform": xform((-145.0, 0.05, -118.0), 90)})  # zone 3 took the old spot
debug_label("Markers/BusStop", "BUS STOP")
sc.node("GasStation", "Marker3D", "Markers", props={"transform": xform((44.0, 0.2, -52.6), 180)})
# Point 47c: the Crows' pier at the west end of the quay (Rival post "harbour"): turf rect + where they come from.
sc.node("HarbourCrows", "Marker3D", "Markers", props={"transform": xform((-168.0, 0.2, 97.0), 90)})
debug_label("Markers/HarbourCrows", "HARBOUR CROWS")
sc.node("HarbourTurf", "Node3D", NAV, props={"transform": xform((-177.0, 0.15, 96.5)), "metadata/size": "Vector2(26, 15)"})
fence_line(-164, 90, -164, 104, y=0.15, gaps=(96, 98))
sc.node("HarbourTurfSign", "Label3D", NAV, props={"transform": xform((-163.8, 2.6, 93.0), 90),
        "text": q("PRIVATE PIER\nKEEP OUT"), "font_size": "56", "pixel_size": "0.008",
        "modulate": col(0.95, 0.3, 0.2), "outline_size": "10", "double_sided": "false"})
sc.node("BusStopPole", "StaticBody3D", NAV, props={
    "script": sc.script("res://scripts/procgen/proc_box.gd"), "transform": xform((-63.0, 0.15, 4.3), 180),
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

# Point 95: holes in every grass field where a road tile or a paved area lies on it.
cut = 0
for gi, gx, gz, gsx, gsz in GRASS_NODES:
    g0x, g0z, g1x, g1z = gx - gsx / 2, gz - gsz / 2, gx + gsx / 2, gz + gsz / 2
    extra = []
    for (px0, pz0, px1, pz1) in PAVED_RECTS:
        ix0, iz0, ix1, iz1 = max(g0x, px0 - 0.2), max(g0z, pz0 - 0.2), min(g1x, px1 + 0.2), min(g1z, pz1 + 0.2)
        if ix1 - ix0 > 0.05 and iz1 - iz0 > 0.05:
            extra.append(f"Rect2({ix0 - gx:g}, {iz0 - gz:g}, {ix1 - ix0:g}, {iz1 - iz0:g})")
    if not extra:
        continue
    cut += 1
    lines = sc.nodes[gi].split("\n")
    for k, ln in enumerate(lines):
        if ln.startswith("holes = "):
            lines[k] = ln[:-2] + ", " + ", ".join(extra) + "])"
            break
    else:
        lines.append("holes = Array[Rect2]([" + ", ".join(extra) + "])")
    sc.nodes[gi] = "\n".join(lines)
print(f"point 95: holes cut in {cut} grass fields under roads / paving")
sc.save(ROOT + "scenes/world/world.tscn")
print("world.tscn written,", len(sc.nodes), "nodes")
