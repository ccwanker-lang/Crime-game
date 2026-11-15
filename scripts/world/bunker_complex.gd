class_name BunkerComplex
extends Node3D
## Map zone 8 (user 2026-11-15: "de stalen deur gaat open en leidt naar een ondergronds complex"): the hidden bunker
## at the end of the pass side road. Built in code on every peer (deterministic: the same node paths everywhere, so
## the door and the lift sync like any NetDoor). Made by Mountain._build_bunker at Mountain.bunker_spot().
##
## Local frame: origin = the middle of the doorway at the apron's height; -Z = out (west), +Z = into the mountain,
## +X = north. Upper level (y 0): a concrete face in the rock with the sliding blast door (BunkerDoor), the entrance
## hall with a control desk, the vehicle lift (BunkerLift) and the stairwell. Lower level (y -DEPTH): the garage
## under the lift, a corridor, the lab hall, storage, the sleeping quarters. Layer 1 (world). Markers for session B
## (buying + lab logic): LabSpot1-6, StorageSpot1-4, BedSpot1-4, GarageSpot1-3, ControlSpot, plus the Property
## "bunker" (BunkerProperty) and Door / Lift nodes.

const DEPTH: float = 14.0
const WALL_T: float = 0.4
const HALL := Rect2i(-7, 0, 14, 16)  # x, z, w, d (1 m cells)
const HALL_H: float = 6.0
const DOOR_W: float = 6.0
const DOOR_H: float = 4.5
const LIFT := Rect2i(-5, 2, 6, 9)
const STAIRS := Rect2i(2, 2, 4, 10)  # shaft: near landing z 2..4, flights z 4..10, far landing z 10..12
const FLIGHT_RISE: float = 3.5
## Lower level rooms: [name, rect, height]. The lift cells are part of the garage (open up to the hall).
const ROOMS: Array = [
	["garage", Rect2i(-13, 0, 15, 16), 5.0],
	["stairs", Rect2i(2, 2, 4, 10), DEPTH],
	["corridor", Rect2i(-4, 16, 4, 32), 3.5],
	["lab", Rect2i(0, 20, 24, 20), 6.0],
	["storage", Rect2i(-16, 18, 12, 12), 3.5],
	["quarters", Rect2i(-16, 32, 12, 14), 3.5],
	["generator", Rect2i(-7, 48, 12, 9), 4.5],  # point 83: the corridor's far end leads somewhere now
]
## Extra walker legs for the self-test (point 83 adds the generator room).
const EXTRA_LEGS: Array = [["generator room", Vector3(-2, -DEPTH, 44), Vector3(-1, -DEPTH, 55.5)]]
## Extra lamps (point 83: the generator room), same format as in _build_lights.
const EXTRA_LAMPS: Array = [[Vector3(-1, -DEPTH + 4.5, 51), 11.0, Vector3.ZERO], [Vector3(-1, -DEPTH + 4.5, 55), 11.0, Vector3.ZERO]]
## Openings in the lower level's walls: [axis, line, from, to, height] - axis "x" = the wall line x = line (cells
## from..to along z), "z" = the line z = line (along x).
const OPENINGS: Array = [
	["x", 2, 2, 4, 2.6],     # stairwell -> garage
	["z", 16, -4, 0, 3.5],   # garage -> corridor
	["x", 0, 27, 31, 3.0],   # corridor -> lab
	["x", -4, 22, 24, 2.4],  # corridor -> storage
	["x", -4, 38, 40, 2.4],  # corridor -> quarters
	["z", 48, -4, 0, 3.0],   # corridor -> generator room (the whole corridor width)
]

var _b := MeshBuilder.new()
var _gb := MeshBuilder.new()  # the generator room's machines (own builder: _b is built before them)
var _body: StaticBody3D
var _cells: Dictionary = {}  # Vector2i -> [room name, height] (lower level)


func _ready() -> void:
	_body = StaticBody3D.new()
	_body.name = "ComplexBody"
	_body.collision_layer = 1
	_body.collision_mask = 0
	add_child(_body)
	_build_face()
	_build_hall()
	_build_lower()
	_build_stairs()
	var mi := MeshInstance3D.new()
	mi.name = "ComplexMesh"
	mi.mesh = _b.build()
	add_child(mi)
	_build_generator_room()
	var gm := MeshInstance3D.new()
	gm.name = "GeneratorMesh"
	gm.mesh = _gb.build()
	add_child(gm)
	_build_moving_parts()
	_build_furniture()
	_build_markers()
	_build_property()
	_build_lights()


# --- helpers -------------------------------------------------------------------------------

## A solid box: mesh + collision (basis optional for ramps).
func _solid(mat: StringName, center: Vector3, size: Vector3, color: Color, basis := Basis.IDENTITY,
		visible_mesh: bool = true) -> void:
	if visible_mesh:
		_b.color = color
		_b.xform = Transform3D(basis, center)
		_b.box(mat, Vector3.ZERO, size)
		_b.xform = Transform3D.IDENTITY
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.transform = Transform3D(basis, center)
	_body.add_child(cs)


func _deco(mat: StringName, center: Vector3, size: Vector3, color: Color) -> void:
	_b.color = color
	_b.box(mat, center, size)


const CONCRETE := Color(0.62, 0.62, 0.6)
const CONCRETE_DARK := Color(0.5, 0.5, 0.49)
const FLOOR := Color(0.3, 0.32, 0.31)
const DADO := Color(0.33, 0.4, 0.36)  # the painted lower band of the walls (bunker green)
const WALL := Color(0.72, 0.73, 0.7)
const STRIPE := Color(0.85, 0.65, 0.1)


# --- outside: the face in the rock ---------------------------------------------------------

func _build_face() -> void:
	var hw: float = DOOR_W / 2.0
	# A 28 m concrete retaining face across the cutting, the doorway in the middle.
	_solid(&"concrete", Vector3(-(14.0 + hw) / 2.0, 5.0, -0.3), Vector3(14.0 - hw, 10.0, 0.6), CONCRETE)
	_solid(&"concrete", Vector3((14.0 + hw) / 2.0, 5.0, -0.3), Vector3(14.0 - hw, 10.0, 0.6), CONCRETE)
	_solid(&"concrete", Vector3(0, (10.0 + DOOR_H) / 2.0, -0.3), Vector3(DOOR_W, 10.0 - DOOR_H, 0.6), CONCRETE)
	# Buttresses, a frame round the door, the door's guide rail, vents on top.
	for x: float in [-13.0, -9.5, 10.0, 13.0]:  # (the door slides to x 3..9 in front of the face)
		_solid(&"concrete", Vector3(x, 4.5, -1.0), Vector3(1.0, 9.0, 0.9), CONCRETE_DARK)
	_deco(&"concrete", Vector3(-hw - 0.3, DOOR_H / 2.0, -0.75), Vector3(0.6, DOOR_H, 0.3), CONCRETE_DARK)
	_deco(&"concrete", Vector3(0, DOOR_H + 0.3, -0.75), Vector3(DOOR_W + 1.2, 0.6, 0.3), CONCRETE_DARK)
	_deco(&"metal_dark", Vector3(hw + 3.0, DOOR_H + 0.05, -0.75), Vector3(DOOR_W + 6.5, 0.12, 0.25), Color(0.25, 0.25, 0.25))
	_deco(&"metal_dark", Vector3(hw + 3.0, 0.03, -0.75), Vector3(DOOR_W + 6.5, 0.06, 0.25), Color(0.25, 0.25, 0.25))
	for x: float in [-4.0, 4.0]:
		_b.color = Color(0.25, 0.25, 0.25)
		_b.cylinder(&"item_metal", Vector3(x, 10.0, 3.0), Vector3(x, 11.4, 3.0), 0.35, 0.35, 8)
	# The apron in front.
	_deco(&"concrete", Vector3(0, 0.03, -5.0), Vector3(16.0, 0.06, 9.4), Color(0.5, 0.48, 0.45))
	for i: int in 6:
		_deco(&"item_matte", Vector3(-hw + 0.5 + i * (DOOR_W - 1.0) / 5.0, 0.065, -1.2), Vector3(0.6, 0.01, 0.5), STRIPE)
	var lbl := Label3D.new()
	lbl.name = "Sign"
	lbl.text = "AUTHORISED PERSONNEL ONLY"
	lbl.font_size = 56
	lbl.pixel_size = 0.007
	lbl.modulate = Color(0.95, 0.9, 0.75)
	lbl.position = Vector3(0, 6.2, -0.62)
	lbl.rotation.y = PI
	add_child(lbl)
	# The hall's shell behind the face (roof + side + back walls are part of the hall build).


# --- upper level: the entrance hall --------------------------------------------------------

func _build_hall() -> void:
	var x0: float = HALL.position.x
	var x1: float = HALL.end.x
	var z0: float = HALL.position.y
	var z1: float = HALL.end.y
	# Floor rows (holes for the lift and the stairwell's flights).
	for z: int in range(HALL.position.y, HALL.end.y):
		var run_start: int = -999
		for x: int in range(HALL.position.x, HALL.end.x + 1):
			var hole: bool = x >= HALL.end.x or LIFT.has_point(Vector2i(x, z)) or \
					(Rect2i(STAIRS.position.x, STAIRS.position.y + 2, STAIRS.size.x, STAIRS.size.y - 2).has_point(Vector2i(x, z)))
			if not hole and run_start == -999:
				run_start = x
			elif hole and run_start != -999:
				_solid(&"item_matte", Vector3((run_start + x) / 2.0, -0.2, z + 0.5), Vector3(x - run_start, 0.4, 1.0), FLOOR)
				run_start = -999
	# Roof (thick, it carries the mountain's rubble on top) and the walls.
	_solid(&"concrete", Vector3((x0 + x1) / 2.0, HALL_H + 0.4, (z0 + z1) / 2.0), Vector3(x1 - x0 + 2 * WALL_T, 0.8, z1 - z0 + 0.6), CONCRETE)
	_deco(&"item_matte", Vector3(x0 - WALL_T / 2.0, 0.65, (z0 + z1) / 2.0), Vector3(WALL_T + 0.04, 1.3, z1 - z0), DADO)
	_deco(&"item_matte", Vector3(x1 + WALL_T / 2.0, 0.65, (z0 + z1) / 2.0), Vector3(WALL_T + 0.04, 1.3, z1 - z0), DADO)
	_deco(&"item_matte", Vector3((x0 + x1) / 2.0, 0.65, z1 + WALL_T / 2.0), Vector3(x1 - x0, 1.3, WALL_T + 0.04), DADO)
	_solid(&"concrete", Vector3(x0 - WALL_T / 2.0, HALL_H / 2.0, (z0 + z1) / 2.0), Vector3(WALL_T, HALL_H, z1 - z0), WALL)
	_solid(&"concrete", Vector3(x1 + WALL_T / 2.0, HALL_H / 2.0, (z0 + z1) / 2.0), Vector3(WALL_T, HALL_H, z1 - z0), WALL)
	_solid(&"concrete", Vector3((x0 + x1) / 2.0, HALL_H / 2.0, z1 + WALL_T / 2.0), Vector3(x1 - x0 + 2 * WALL_T, HALL_H, WALL_T), WALL)
	# Railings round the shafts (open on the door side of the lift for cars, at the stairwell's near landing).
	var rail := Color(0.85, 0.65, 0.1)
	_solid(&"item_metal", Vector3(LIFT.position.x - 0.05, 0.55, LIFT.get_center().y), Vector3(0.1, 1.1, LIFT.size.y), rail)
	_solid(&"item_metal", Vector3(LIFT.end.x + 0.5, 0.55, (LIFT.position.y + STAIRS.end.y) / 2.0), Vector3(1.0, 1.1, STAIRS.end.y - LIFT.position.y), CONCRETE_DARK)
	_solid(&"item_metal", Vector3(LIFT.get_center().x, 0.55, LIFT.end.y + 0.05), Vector3(LIFT.size.x, 1.1, 0.1), rail)
	_solid(&"item_metal", Vector3(STAIRS.end.x + 0.05, 0.55, STAIRS.position.y + 2 + (STAIRS.size.y - 2) / 2.0), Vector3(0.1, 1.1, STAIRS.size.y - 2), rail)
	_solid(&"item_metal", Vector3(STAIRS.get_center().x, 0.55, STAIRS.end.y + 0.05), Vector3(STAIRS.size.x, 1.1, 0.1), rail)
	# (The shaft walls down to the lower level come from the lower level's grid: the lift cells are 14 m high.)
	# Hazard stripes on the floor at the lift edge and a painted "LIFT" box.
	_deco(&"item_matte", Vector3(LIFT.get_center().x, 0.005, LIFT.position.y - 0.25), Vector3(LIFT.size.x, 0.01, 0.4), STRIPE)


# --- lower level: grid of rooms ----------------------------------------------------------

func _build_lower() -> void:
	var y0: float = -DEPTH
	for r: Array in ROOMS:
		var rect: Rect2i = r[1]
		for x: int in range(rect.position.x, rect.end.x):
			for z: int in range(rect.position.y, rect.end.y):
				_cells[Vector2i(x, z)] = [r[0], float(r[2])]
	for x: int in range(LIFT.position.x, LIFT.end.x):
		for z: int in range(LIFT.position.y, LIFT.end.y):
			_cells[Vector2i(x, z)] = ["garage", DEPTH]
	# Floors + ceilings per row run of equal height (the lift cells get a pit floor 0.35 lower).
	var zs: Array = []
	var xs: Array = []
	for c: Vector2i in _cells:
		xs.append(c.x)
		zs.append(c.y)
	var minx: int = xs.min()
	var maxx: int = xs.max()
	for z: int in range(zs.min(), zs.max() + 1):
		var start: int = -999
		var start_h: float = 0.0
		var start_lift: bool = false
		for x: int in range(minx, maxx + 2):
			var c := Vector2i(x, z)
			var here: bool = _cells.has(c)
			var h: float = float(_cells[c][1]) if here else -1.0
			var lift: bool = here and LIFT.has_point(c)
			if start != -999 and (not here or h != start_h or lift != start_lift):
				var cx: float = (start + x) / 2.0
				var w: float = float(x - start)
				var fy: float = y0 - (0.35 if start_lift else 0.0)
				_solid(&"item_matte", Vector3(cx, fy - 0.2, z + 0.5), Vector3(w, 0.4, 1.0), FLOOR)
				if start_h < DEPTH - 0.01:
					_solid(&"concrete", Vector3(cx, y0 + start_h + 0.2, z + 0.5), Vector3(w, 0.4, 1.0), CONCRETE_DARK)
				start = -999
			if here and start == -999:
				start = x
				start_h = h
				start_lift = lift
	# Walls along every cell edge that needs one (merged into runs along each line).
	var segs: Dictionary = {}  # [axis, line, y0, y1] -> Array of cell indices along the line
	for c: Vector2i in _cells:
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			var axis: String = "x" if d.x != 0 else "z"
			var line: int = c.x + (1 if d.x > 0 else 0) if axis == "x" else c.y + (1 if d.y > 0 else 0)
			var along: int = c.y if axis == "x" else c.x
			var hc: float = _cells[c][1]
			var lo: float = 0.0
			var hi: float = hc
			if _cells.has(n):
				var hn: float = _cells[n][1]
				if _cells[n][0] == _cells[c][0]:
					if hc <= hn:
						continue
					lo = hn  # a header down to the lower ceiling
				else:
					if c > n:
						continue  # each shared edge once
					hi = maxf(hc, hn)
					lo = _opening(axis, line, along)
			if hi - lo < 0.01:
				continue
			var key: Array = [axis, line, lo, hi]
			segs.get_or_add(key, []).append(along)
	for key: Array in segs:
		var cells: Array = segs[key]
		cells.sort()
		var run0: int = cells[0]
		var prev: int = cells[0]
		for i: int in range(1, cells.size() + 1):
			if i < cells.size() and cells[i] == prev + 1:
				prev = cells[i]
				continue
			_wall(key[0], key[1], run0, prev + 1, y0 + key[2], y0 + key[3])
			if i < cells.size():
				run0 = cells[i]
				prev = cells[i]


## The height of the opening at this edge (0 = none: a full wall).
func _opening(axis: String, line: int, along: int) -> float:
	for o: Array in OPENINGS:
		if o[0] == axis and int(o[1]) == line and along >= int(o[2]) and along < int(o[3]):
			return float(o[4])
	return 0.0


func _wall(axis: String, line: int, a0: int, a1: int, y_lo: float, y_hi: float) -> void:
	var len: float = a1 - a0 + WALL_T
	var mid: float = (a0 + a1) / 2.0
	var h: float = y_hi - y_lo
	var c := Vector3(line, y_lo + h / 2.0, mid) if axis == "x" else Vector3(mid, y_lo + h / 2.0, line)
	var s := Vector3(WALL_T, h, len) if axis == "x" else Vector3(len, h, WALL_T)
	_solid(&"concrete", c, s, WALL)
	if y_lo <= -DEPTH + 0.01:  # a wall from the floor: the painted dado band on both faces
		var band := Vector3(WALL_T + 0.04, 1.3, len - 0.02) if axis == "x" else Vector3(len - 0.02, 1.3, WALL_T + 0.04)
		_deco(&"item_matte", Vector3(c.x, y_lo + 0.65, c.z), band, DADO)


# --- the stairwell -----------------------------------------------------------------------

func _build_stairs() -> void:
	var sx0: float = STAIRS.position.x
	var mid: float = STAIRS.get_center().x
	var sx1: float = STAIRS.end.x
	var near0: float = STAIRS.position.y
	var f0: float = near0 + 2.0
	var f1: float = STAIRS.end.y - 2.0
	var run: float = f1 - f0
	var flights: int = int(round(DEPTH / FLIGHT_RISE))
	var length: float = Vector2(run, FLIGHT_RISE).length()
	for k: int in flights:
		var top: float = -FLIGHT_RISE * k
		var down_z: bool = k % 2 == 0  # even flights go +Z in the north lane, odd ones -Z in the south lane
		var lx: float = (mid + sx1) / 2.0 if down_z else (sx0 + mid) / 2.0
		var dir := Vector3(0, -FLIGHT_RISE, run if down_z else -run).normalized()
		var up := Vector3(0, run, FLIGHT_RISE if down_z else -FLIGHT_RISE).normalized()
		var basis := Basis(up.cross(dir), up, dir)
		var za: float = f0 if down_z else f1
		var zb: float = f1 if down_z else f0
		var centre := Vector3(lx, top - FLIGHT_RISE / 2.0, (za + zb) / 2.0) - up * 0.1
		_solid(&"concrete", centre, Vector3(2.0, 0.2, length), CONCRETE, basis, false)
		var steps: int = int(round(FLIGHT_RISE / 0.175))
		var tread: float = run / steps
		for i: int in steps:
			var zc: float = za + (tread * (i + 0.5)) * (1.0 if down_z else -1.0)
			var ytop: float = top - FLIGHT_RISE * float(i + 1) / steps
			_deco(&"concrete", Vector3(lx, ytop - 0.2, zc), Vector3(1.9, 0.4, tread), CONCRETE if i % 2 == 0 else CONCRETE_DARK)
		# The landing at the end of this flight (the last one ends on the lower floor).
		if k < flights - 1:
			var lz: float = (f1 + STAIRS.end.y) / 2.0 if down_z else (near0 + f0) / 2.0
			_solid(&"concrete", Vector3(mid, top - FLIGHT_RISE - 0.2, lz), Vector3(STAIRS.size.x, 0.4, 2.0), FLOOR)
	# The wall between the two lanes, the whole height of the shaft.
	_solid(&"concrete", Vector3(mid, -DEPTH / 2.0, (f0 + f1) / 2.0), Vector3(0.2, DEPTH, run), WALL)
	# Handrails on the outer walls.
	for x: float in [sx0 + 0.15, sx1 - 0.15]:
		_deco(&"item_metal", Vector3(x, -DEPTH / 2.0, (f0 + f1) / 2.0), Vector3(0.05, DEPTH, 0.05), STRIPE)


# --- door, lift, call panels -------------------------------------------------------------

func _build_moving_parts() -> void:
	var door := BunkerDoor.new()
	door.name = "Door"
	door.width = DOOR_W
	door.height = DOOR_H
	door.position = Vector3(-DOOR_W / 2.0, 0, -0.6)
	add_child(door)
	var lift := BunkerLift.new()
	lift.name = "Lift"
	lift.width = LIFT.size.x - 0.1
	lift.depth = LIFT.size.y - 0.1
	lift.drop = DEPTH
	lift.position = Vector3(LIFT.get_center().x, 0, LIFT.get_center().y)
	add_child(lift)
	for i: int in 2:
		var btn := BunkerLiftButton.new()
		btn.name = "LiftButtonTop" if i == 0 else "LiftButtonBottom"
		btn.lift = lift
		btn.upper = i == 0
		btn.position = Vector3(LIFT.position.x - 0.7, 0 if i == 0 else -DEPTH, LIFT.position.y - 0.5)
		add_child(btn)


func _build_furniture() -> void:
	var holder := Node3D.new()
	holder.name = "Furniture"
	add_child(holder)
	var y: float = -DEPTH
	# [scene, position, yaw degrees]
	var list: Array = [
		["office_desk", Vector3(4.5, 0, 14.0), 180.0],
		["steel_shelves", Vector3(-15.3, y, 20.0), 90.0], ["steel_shelves", Vector3(-15.3, y, 23.0), 90.0],
		["metal_rack", Vector3(-15.3, y, 27.0), 90.0], ["cardboard_box", Vector3(-10.0, y, 28.5), 15.0],
		["bed", Vector3(-15.0, y, 34.0), 90.0], ["bed", Vector3(-15.0, y, 37.0), 90.0],
		["bed", Vector3(-15.0, y, 41.0), 90.0], ["bed", Vector3(-15.0, y, 44.0), 90.0],
		["wardrobe", Vector3(-8.0, y, 45.4), 180.0], ["dining_table", Vector3(-8.5, y, 36.0), 0.0],
		["tool_cart", Vector3(-12.3, y, 14.5), 90.0],
	]
	for f: Array in list:
		var path: String = "res://prefabs/interiors/%s.tscn" % f[0]
		if not ResourceLoader.exists(path):
			continue
		var n: Node3D = (load(path) as PackedScene).instantiate()
		n.position = f[1]
		n.rotation.y = deg_to_rad(f[2])
		holder.add_child(n)
	# The lab's floor markings (where B's machines go): a yellow square per spot.
	var b := MeshBuilder.new()
	for i: int in 6:
		var p: Vector3 = _lab_spot(i)
		b.color = STRIPE
		b.box(&"item_matte", p + Vector3(0, 0.005, 0), Vector3(2.6, 0.01, 2.6))
		b.color = FLOOR
		b.box(&"concrete", p + Vector3(0, 0.008, 0), Vector3(2.3, 0.01, 2.3))
	var mi := MeshInstance3D.new()
	mi.name = "LabMarkings"
	mi.mesh = b.build()
	add_child(mi)


## Point 83: the generator room at the corridor's far end - two diesel generators on plinths with exhaust pipes up
## through the ceiling, fuel tanks, a switchboard with breakers, cable trays, a warning stripe. Solid (layer 1).
func _build_generator_room() -> void:
	var y: float = -DEPTH
	var machines := StaticBody3D.new()  # (own body "Machines": visible kit, not a wall - see the bunker_rooms check)
	machines.name = "Machines"
	machines.collision_layer = 1
	machines.collision_mask = 0
	add_child(machines)
	var olive := Color(0.33, 0.38, 0.28)
	var steel := Color(0.42, 0.44, 0.45)
	for gx: float in [-4.6, 2.6]:
		_gb.color = CONCRETE_DARK
		_gb.box(&"concrete", Vector3(gx, y + 0.1, 53.5), Vector3(3.0, 0.2, 5.0))
		_gb.color = olive
		_gb.box(&"item_matte", Vector3(gx, y + 1.0, 53.5), Vector3(2.2, 1.6, 4.2))
		_gb.color = steel
		_gb.box(&"item_metal", Vector3(gx, y + 1.9, 52.2), Vector3(1.6, 0.25, 1.2))
		_gb.box(&"item_metal", Vector3(gx + 1.15, y + 1.0, 53.5), Vector3(0.1, 1.2, 3.6))
		_gb.cylinder(&"item_metal", Vector3(gx - 0.5, y + 1.8, 55.0), Vector3(gx - 0.5, y + 4.5, 55.0), 0.16, 0.16, 8)
		_gb.color = STRIPE
		_gb.box(&"item_matte", Vector3(gx, y + 0.005, 50.6), Vector3(3.0, 0.01, 0.25))
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(2.2, 1.8, 4.2)
		cs.shape = shape
		cs.position = Vector3(gx, y + 1.1, 53.5)
		machines.add_child(cs)
	# Fuel tanks along the back wall, a switchboard on the west wall by the door.
	for tx: float in [-5.5, -3.2]:
		_gb.color = Color(0.55, 0.18, 0.12)
		_gb.cylinder(&"item_glossy", Vector3(tx, y, 56.3), Vector3(tx, y + 1.9, 56.3), 0.55, 0.55, 10)
	var tank := CollisionShape3D.new()
	var tshape := BoxShape3D.new()
	tshape.size = Vector3(3.5, 1.9, 1.1)
	tank.shape = tshape
	tank.position = Vector3(-4.35, y + 0.95, 56.3)
	machines.add_child(tank)
	_gb.color = Color(0.6, 0.62, 0.6)
	_gb.box(&"item_metal", Vector3(-6.75, y + 1.3, 50.5), Vector3(0.5, 2.2, 2.4))
	var board := CollisionShape3D.new()
	var bshape := BoxShape3D.new()
	bshape.size = Vector3(0.5, 2.2, 2.4)
	board.shape = bshape
	board.position = Vector3(-6.75, y + 1.3, 50.5)
	machines.add_child(board)
	_gb.color = Color(0.15, 0.15, 0.16)
	for i: int in 6:
		_gb.box(&"item_matte", Vector3(-6.48, y + 1.7 - (i / 3) * 0.6, 49.7 + (i % 3) * 0.8), Vector3(0.04, 0.35, 0.5))
	_gb.color = Color(0.85, 0.12, 0.1)
	_gb.box(&"item_glossy", Vector3(-6.46, y + 0.6, 51.3), Vector3(0.04, 0.25, 0.25))
	# Cable trays along the ceiling from the switchboard into the corridor.
	_gb.color = steel
	_gb.box(&"item_metal", Vector3(-6.0, y + 4.25, 52.0), Vector3(0.5, 0.08, 7.0))
	_gb.box(&"item_metal", Vector3(-2.0, y + 3.35, 32.0), Vector3(0.4, 0.06, 31.0))
	var sign := Label3D.new()
	sign.text = "GENERATORS - DANGER HIGH VOLTAGE"
	sign.font_size = 36
	sign.pixel_size = 0.006
	sign.modulate = Color(0.95, 0.75, 0.1)
	sign.outline_size = 6
	sign.position = Vector3(-2.0, y + 3.25, 48.0 - 0.02)
	sign.rotation.y = PI
	add_child(sign)


func _lab_spot(i: int) -> Vector3:
	return Vector3(6.0 + (i % 3) * 7.0, -DEPTH, 25.0 + (i / 3) * 9.0)


func _build_markers() -> void:
	var y: float = -DEPTH
	var spots: Array = []
	for i: int in 6:
		spots.append(["LabSpot%d" % (i + 1), _lab_spot(i)])
	for i: int in 4:
		spots.append(["StorageSpot%d" % (i + 1), Vector3(-12.0 + (i % 2) * 4.0, y, 21.0 + (i / 2) * 5.0)])
		spots.append(["BedSpot%d" % (i + 1), Vector3(-15.0, y, [34.0, 37.0, 41.0, 44.0][i])])
	for i: int in 3:
		spots.append(["GarageSpot%d" % (i + 1), Vector3(-10.0, y, 3.5 + i * 4.5)])
	spots.append(["ControlSpot", Vector3(4.5, 0, 13.0)])
	spots.append(["GeneratorSpot", Vector3(-1.0, y, 52.5)])
	for s: Array in spots:
		var m := Marker3D.new()
		m.name = s[0]
		m.position = s[1]
		add_child(m)


func _build_property() -> void:
	var prop := BunkerProperty.new()
	prop.name = "Property"
	prop.property_id = &"bunker"
	prop.display_name = "The Bunker"
	prop.for_sale = false
	prop.price = 0
	prop.description = "A cold-war bunker under the pass. A lift big enough for a car, a lab hall, storage, bunks."
	prop.position = Vector3(-3.0, 3.4, 15.5)
	prop.rotation.y = PI
	var lbl := Label3D.new()
	lbl.name = "Label3D"
	lbl.font_size = 40
	lbl.pixel_size = 0.006
	lbl.outline_size = 8
	prop.add_child(lbl)
	var h := HALL
	prop.rooms.append(AABB(Vector3(h.position.x, -0.3, h.position.y), Vector3(h.size.x, HALL_H, h.size.y)))
	for r: Array in ROOMS:
		var rect: Rect2i = r[1]
		prop.rooms.append(AABB(Vector3(rect.position.x, -DEPTH - 0.4, rect.position.y),
				Vector3(rect.size.x, minf(float(r[2]), 6.0) + 0.4, rect.size.y)))
	add_child(prop)


func _build_lights() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var y: float = -DEPTH
	# Point 82: every lamp sits against a ceiling (y = the room's ceiling) or high on a wall - the stairwell's used
	# to hang off the divider wall 1.25 m above the steps (hip height), one floated in the middle of the lift shaft.
	# [position of the lamp's top, range, wall normal (zero = ceiling lamp)]
	var lamps: Array = [
		[Vector3(0, DOOR_H + 0.9, -1.0), 9.0, Vector3.ZERO],  # outside over the door (under the face's lintel)
		[Vector3(-3, HALL_H, 5), 12.0, Vector3.ZERO], [Vector3(3, HALL_H, 13.5), 12.0, Vector3.ZERO],
		[Vector3(-9, y + 5.0, 4), 12.0, Vector3.ZERO], [Vector3(-9, y + 5.0, 12), 12.0, Vector3.ZERO],
		[Vector3(-2, y + 5.0, 14), 10.0, Vector3.ZERO],
		[Vector3(STAIRS.position.x + 0.03, -7.0 + 2.9, 3), 8.0, Vector3.RIGHT],
		[Vector3(STAIRS.position.x + 0.03, -14.0 + 2.9, 3), 8.0, Vector3.RIGHT],
		[Vector3(STAIRS.end.x - 0.03, -3.5 + 2.9, 11), 8.0, Vector3.LEFT],
		[Vector3(STAIRS.end.x - 0.03, -10.5 + 2.9, 11), 8.0, Vector3.LEFT],
		[Vector3(-2, y + 3.5, 22), 9.0, Vector3.ZERO], [Vector3(-2, y + 3.5, 34), 9.0, Vector3.ZERO],
		[Vector3(-2, y + 3.5, 45), 9.0, Vector3.ZERO],
		[Vector3(6, y + 6.0, 25), 13.0, Vector3.ZERO], [Vector3(18, y + 6.0, 25), 13.0, Vector3.ZERO],
		[Vector3(6, y + 6.0, 35), 13.0, Vector3.ZERO], [Vector3(18, y + 6.0, 35), 13.0, Vector3.ZERO],
		[Vector3(-10, y + 3.5, 24), 10.0, Vector3.ZERO], [Vector3(-10, y + 3.5, 39), 10.0, Vector3.ZERO],
	]
	for extra: Array in EXTRA_LAMPS:
		lamps.append(extra)
	var b := MeshBuilder.new()
	for l: Array in lamps:
		var p: Vector3 = l[0]
		var wall: Vector3 = l[2]
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.92, 0.78)
		light.light_energy = 1.4
		light.omni_range = l[1]
		light.shadow_enabled = false
		light.position = p + (wall * 0.4 if wall != Vector3.ZERO else Vector3(0, -0.4, 0))
		add_child(light)
		b.color = Color(0.3, 0.31, 0.32)
		if wall == Vector3.ZERO:
			b.box(&"item_metal", p - Vector3(0, 0.03, 0), Vector3(1.3, 0.06, 0.32))  # the fitting on the ceiling
			b.color = Color(1.0, 0.95, 0.8)
			b.box(&"lamp_glow", p - Vector3(0, 0.1, 0), Vector3(1.2, 0.08, 0.25))
		else:  # a wall lamp: a box on the wall, the glowing face towards the room
			b.box(&"item_metal", p + wall * 0.05, Vector3(0.1, 0.32, 1.3))
			b.color = Color(1.0, 0.95, 0.8)
			b.box(&"lamp_glow", p + wall * 0.12, Vector3(0.06, 0.24, 1.2))
	var mi := MeshInstance3D.new()
	mi.name = "Lamps"
	mi.mesh = b.build()
	add_child(mi)
