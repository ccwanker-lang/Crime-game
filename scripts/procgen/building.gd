@tool
class_name Building
extends StaticBody3D
## Modular Belgian/European town house generated from parameters.
## Facade modules: wall, wall+window, door, shopfront, bay window (erker),
## balcony, corner quoins, string courses. Roofs: gable, hip, flat, plus
## dormer, chimney, cornice, gutter and downpipe.
##
## Local frame: origin = middle of the FRONT facade at ground level.
## The front faces +Z (the street); the building extends to z = -depth.
## Place it with its origin on the back edge of the sidewalk.
## Everything is regenerated from the parameters (nothing is saved in the scene),
## so change the Inspector values to make variants.

const WALL_T: float = 0.3
const LINING: float = 0.02
const DOOR_SCENE: String = "res://prefabs/buildings/door.tscn"
const ROOM_COLORS: Array[Color] = [
	Color(0.85, 0.8, 0.68), Color(0.75, 0.8, 0.82), Color(0.8, 0.84, 0.74),
	Color(0.88, 0.86, 0.82), Color(0.82, 0.72, 0.62), Color(0.7, 0.68, 0.72)]

@export_group("Shape")
@export var width: float = 6.0:
	set(v): width = v; _queue_rebuild()
@export var depth: float = 9.0:
	set(v): depth = v; _queue_rebuild()
@export_range(1, 6) var floors: int = 2:
	set(v): floors = v; _queue_rebuild()
@export var floor_height: float = 3.0:
	set(v): floor_height = v; _queue_rebuild()
## Window columns on the front. 0 = automatic from the width.
@export_range(0, 12) var bays: int = 0:
	set(v): bays = v; _queue_rebuild()

@export_group("Materials")
@export_enum("brick_old", "brick_mixed", "brick_yellow", "brick_white", "plaster", "concrete", "corrugated") var wall_material: String = "brick_old":
	set(v): wall_material = v; _queue_rebuild()
@export var wall_tint: Color = Color.WHITE:
	set(v): wall_tint = v; _apply_tints()
@export_enum("roof_dark", "roof_red") var roof_material: String = "roof_dark":
	set(v): roof_material = v; _queue_rebuild()
@export var roof_tint: Color = Color.WHITE:
	set(v): roof_tint = v; _apply_tints()
@export var trim_color: Color = Color(0.92, 0.92, 0.9):
	set(v): trim_color = v; _apply_tints()
@export var door_color: Color = Color(0.16, 0.27, 0.22):
	set(v): door_color = v; _apply_tints()

@export_group("Roof")
@export_enum("gable", "hip", "flat") var roof_type: String = "gable":
	set(v): roof_type = v; _queue_rebuild()
@export_range(15.0, 60.0) var roof_pitch: float = 42.0:
	set(v): roof_pitch = v; _queue_rebuild()
@export var dormer: bool = false:
	set(v): dormer = v; _queue_rebuild()
@export_enum("none", "left", "right") var chimney: String = "left":
	set(v): chimney = v; _queue_rebuild()

@export_group("Facade")
@export_enum("residential", "shop") var ground_floor: String = "residential":
	set(v): ground_floor = v; _queue_rebuild()
## Bay index of the front door (-1 = no front door).
@export var door_bay: int = 0:
	set(v): door_bay = v; _queue_rebuild()
## Bay index of an erker on the first floor (-1 = none).
@export var bay_window_bay: int = -1:
	set(v): bay_window_bay = v; _queue_rebuild()
## Bay index of a balcony on the first floor (-1 = none).
@export var balcony_bay: int = -1:
	set(v): balcony_bay = v; _queue_rebuild()
@export var string_courses: bool = true:
	set(v): string_courses = v; _queue_rebuild()
@export var corner_quoins: bool = false:
	set(v): corner_quoins = v; _queue_rebuild()
## false = blind side walls (row house), true = windows on the sides too.
@export var side_windows: bool = false:
	set(v): side_windows = v; _queue_rebuild()
@export var shop_sign: String = "":
	set(v): shop_sign = v; _queue_rebuild()
@export var awning: bool = false:
	set(v): awning = v; _queue_rebuild()
@export var awning_color: Color = Color(0.55, 0.1, 0.1):
	set(v): awning_color = v; _queue_rebuild()

@export_group("Interior")
## Ground floor can be entered: real door, interior walls, floor and ceiling.
@export var enterable: bool = false:
	set(v): enterable = v; _queue_rebuild()
@export_enum("wood_floor", "floor_tiles", "concrete") var floor_material: String = "wood_floor":
	set(v): floor_material = v; _queue_rebuild()

@export_group("Variation")
@export var variation_seed: int = 1:
	set(v): variation_seed = v; _queue_rebuild()
@export_range(0.0, 1.0) var lit_windows: float = 0.2:
	set(v): lit_windows = v; _queue_rebuild()

var _generated: Array[Node] = []
var _mesh_instance: MeshInstance3D
var _pending: bool = false
var _rng := RandomNumberGenerator.new()
var _door_slots: Array[Dictionary] = []
var _wall_key: StringName
var _H: float


func _ready() -> void:
	_rebuild()


func _queue_rebuild() -> void:
	if not is_inside_tree() or _pending:
		return
	_pending = true
	_rebuild.call_deferred()


func get_height() -> float:
	return floors * floor_height


# --- Main build ----------------------------------------------------------------

func _rebuild() -> void:
	_pending = false
	for n: Node in _generated:
		if is_instance_valid(n):
			n.queue_free()
	_generated.clear()
	_door_slots.clear()
	_rng.seed = variation_seed
	_wall_key = StringName(wall_material)
	_H = floors * floor_height

	var b := MeshBuilder.new()
	var bay_count: int = bays if bays > 0 else maxi(1, roundi(width / 2.4))
	var side_bays: int = maxi(1, roundi(depth / 3.0))

	# Facade frames: front, back, left, right.
	var front := Transform3D.IDENTITY
	var back := Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, -depth))
	var left := Transform3D(Basis(Vector3.UP, -PI / 2.0), Vector3(-width / 2.0, 0, -depth / 2.0))
	var right := Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(width / 2.0, 0, -depth / 2.0))

	var hip: bool = roof_type == "hip"
	_facade(b, front, width, bay_count, true, false, true)
	_facade(b, back, width, bay_count, false, false, true)
	_facade(b, left, depth, side_bays, false, not side_windows, hip)
	_facade(b, right, depth, side_bays, false, not side_windows, hip)
	b.xform = Transform3D.IDENTITY

	_roof(b)
	if enterable:
		_interior(b)
	if ground_floor == "shop":
		_shop_extras(b)

	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "Mesh"
	_mesh_instance.mesh = b.build()
	_add_generated(_mesh_instance)
	_apply_tints()

	_build_collision(b)
	_spawn_doors()


func _add_generated(n: Node) -> void:
	add_child(n)
	_generated.append(n)


func _apply_tints() -> void:
	if _mesh_instance == null or not is_instance_valid(_mesh_instance):
		return
	_mesh_instance.set_instance_shader_parameter(&"wall_tint", wall_tint)
	_mesh_instance.set_instance_shader_parameter(&"roof_tint", roof_tint)
	_mesh_instance.set_instance_shader_parameter(&"trim_tint", trim_color)
	_mesh_instance.set_instance_shader_parameter(&"door_tint", door_color)
	for n: Node in _generated:
		if n is NetDoor:
			(n as NetDoor).set_color(door_color)


func _build_collision(b: MeshBuilder) -> void:
	var boxes: Array[Dictionary] = []
	if enterable:
		boxes = b.collision_boxes.duplicate()
		# Upper floors as one solid block.
		if floors > 1:
			boxes.append({"xform": Transform3D(Basis.IDENTITY, Vector3(0, (floor_height + _H) / 2.0, -depth / 2.0)),
					"size": Vector3(width, _H - floor_height, depth)})
	else:
		boxes.append({"xform": Transform3D(Basis.IDENTITY, Vector3(0, _H / 2.0, -depth / 2.0)),
				"size": Vector3(width, _H, depth)})
	for box: Dictionary in boxes:
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = box["size"]
		cs.shape = shape
		cs.transform = box["xform"]
		_add_generated(cs)


func _spawn_doors() -> void:
	if _door_slots.is_empty() or not ResourceLoader.exists(DOOR_SCENE):
		return
	var scene: PackedScene = load(DOOR_SCENE)
	for i: int in _door_slots.size():
		var slot: Dictionary = _door_slots[i]
		var door := scene.instantiate() as NetDoor
		door.name = "Door%d" % i
		door.transform = slot["xform"]
		door.width = slot["width"]
		door.height = slot["height"]
		door.glass_panel = slot["glass"]
		_add_generated(door)
		door.set_color(door_color)


# --- Facades -------------------------------------------------------------------

func _facade(b: MeshBuilder, frame: Transform3D, length: float, bay_count: int, is_front: bool, blind: bool, eaves: bool) -> void:
	b.xform = frame
	var half: float = length / 2.0
	var bw: float = length / bay_count
	var door_gap := Vector2(INF, -INF)

	for f: int in floors:
		var y0: float = f * floor_height
		var y1: float = y0 + floor_height
		var lining: bool = enterable and f == 0
		b.collide = enterable and f == 0
		if blind:
			_wall(b, -half, half, y0, y1, lining)
		else:
			for i: int in bay_count:
				var x0: float = -half + i * bw
				var x1: float = x0 + bw
				if is_front and f == 0 and i == door_bay:
					door_gap = _door_cell(b, x0, x1, y0, y1, lining, frame)
				elif is_front and f == 0 and ground_floor == "shop":
					_shop_cell(b, x0, x1, y0, y1, lining)
				elif is_front and f == 1 and i == bay_window_bay:
					_wall(b, x0, x1, y0, y1, false)
					_bay_window(b, x0, x1, y0, y1)
				elif is_front and f == 1 and i == balcony_bay:
					_balcony_cell(b, x0, x1, y0, y1)
				else:
					_window_cell(b, x0, x1, y0, y1, f, lining)
		b.collide = false
		if string_courses and f > 0 and (is_front or not blind):
			b.box_mm(&"bluestone", Vector3(-half, y0 - 0.06, -0.02), Vector3(half, y0 + 0.06, 0.035), 0.01)

	if roof_type == "flat":
		# Parapet with coping.
		b.box_mm(_wall_key, Vector3(-half, _H, -WALL_T), Vector3(half, _H + 0.7, 0))
		b.box_mm(&"zinc", Vector3(-half - 0.03, _H + 0.7, -WALL_T - 0.03), Vector3(half + 0.03, _H + 0.78, 0.04), 0.01)
	elif eaves:
		# Cornice and gutter along the eaves.
		var so: float = _side_overhang()
		b.box_mm(&"trim_paint", Vector3(-half - so, _H - 0.28, -0.05), Vector3(half + so, _H, 0.16), 0.02)
		b.box_mm(&"zinc", Vector3(-half - so, _H - 0.04, 0.16), Vector3(half + so, _H + 0.08, 0.3), 0.03)
		if is_front:
			var px: float = half - 0.22
			b.cylinder(&"zinc", Vector3(px, 0.15, 0.1), Vector3(px, _H - 0.32, 0.1), 0.045, 0.045, 8, false)
			b.cylinder(&"zinc", Vector3(px, _H - 0.32, 0.1), Vector3(px, _H, 0.23), 0.045, 0.045, 8, false)

	if corner_quoins and is_front:
		var y: float = 0.45
		var k: int = 0
		while y < _H - 0.3:
			var w: float = 0.42 if k % 2 == 0 else 0.26
			b.box_mm(&"bluestone", Vector3(-half, y, -0.02), Vector3(-half + w, y + 0.28, 0.025), 0.01)
			b.box_mm(&"bluestone", Vector3(half - w, y, -0.02), Vector3(half, y + 0.28, 0.025), 0.01)
			y += 0.32
			k += 1

	# Plinth (bluestone base), split around the front door.
	if not (is_front and ground_floor == "shop"):
		if door_gap.x < door_gap.y:
			b.box_mm(&"bluestone", Vector3(-half, -0.1, -0.02), Vector3(door_gap.x, 0.42, 0.03), 0.01)
			b.box_mm(&"bluestone", Vector3(door_gap.y, -0.1, -0.02), Vector3(half, 0.42, 0.03), 0.01)
		else:
			b.box_mm(&"bluestone", Vector3(-half, -0.1, -0.02), Vector3(half, 0.42, 0.03), 0.01)


func _side_overhang() -> float:
	return 0.3 if side_windows else 0.04


## Wall piece; with lining the inside gets interior plaster.
func _wall(b: MeshBuilder, x0: float, x1: float, y0: float, y1: float, lining: bool, key: StringName = &"") -> void:
	if x1 - x0 < 0.005 or y1 - y0 < 0.005:
		return
	var k: StringName = key if key != &"" else _wall_key
	if lining:
		b.box_mm(k, Vector3(x0, y0, -WALL_T + LINING), Vector3(x1, y1, 0))
		var c: bool = b.collide
		b.collide = false
		b.box_mm(&"interior_plaster", Vector3(x0, y0, -WALL_T), Vector3(x1, y1, -WALL_T + LINING))
		b.collide = c
	else:
		b.box_mm(k, Vector3(x0, y0, -WALL_T), Vector3(x1, y1, 0))


func _room_color() -> Color:
	var c: Color = ROOM_COLORS[_rng.randi() % ROOM_COLORS.size()]
	c.a = 1.0 if _rng.randf() < lit_windows else _rng.randf() * 0.2
	return c


func _window_cell(b: MeshBuilder, x0: float, x1: float, y0: float, y1: float, f: int, lining: bool) -> void:
	var ww: float = clampf((x1 - x0) - 0.9, 0.7, 1.45)
	var top_floor: bool = f == floors - 1 and floors > 2
	var wh: float = 1.95 if f == 0 else (1.5 if top_floor else 1.8)
	var sill: float = y0 + (0.9 if f == 0 else 0.8)
	var cx: float = (x0 + x1) / 2.0
	var wx0: float = cx - ww / 2.0
	var wx1: float = cx + ww / 2.0
	var wy1: float = minf(sill + wh, y1 - 0.35)
	_wall(b, x0, wx0, y0, y1, lining)
	_wall(b, wx1, x1, y0, y1, lining)
	_wall(b, wx0, wx1, y0, sill, lining)
	_wall(b, wx0, wx1, wy1, y1, lining)
	var clear: bool = lining
	_window(b, wx0, wx1, sill, wy1, &"glass_clear" if clear else &"glass_interior", true, true)
	if clear:
		b.add_collision_box(Vector3(cx, (sill + wy1) / 2.0, -0.15), Vector3(ww, wy1 - sill, 0.1))


## Window frame, glass, sill and lintel inside an opening.
func _window(b: MeshBuilder, wx0: float, wx1: float, wy0: float, wy1: float, glass: StringName, transom: bool, sill: bool) -> void:
	var r: float = 0.12
	var ft: float = 0.065
	var fd: float = 0.07
	var z0: float = -r - fd
	var z1: float = -r
	var c: bool = b.collide
	b.collide = false
	b.box_mm(&"trim_paint", Vector3(wx0, wy0, z0), Vector3(wx0 + ft, wy1, z1), 0.01)
	b.box_mm(&"trim_paint", Vector3(wx1 - ft, wy0, z0), Vector3(wx1, wy1, z1), 0.01)
	b.box_mm(&"trim_paint", Vector3(wx0 + ft, wy0, z0), Vector3(wx1 - ft, wy0 + ft, z1), 0.01)
	b.box_mm(&"trim_paint", Vector3(wx0 + ft, wy1 - ft, z0), Vector3(wx1 - ft, wy1, z1), 0.01)
	var mullion_top: float = wy1 - ft
	if transom and wy1 - wy0 > 1.3:
		var ty: float = wy0 + (wy1 - wy0) * 0.72
		b.box_mm(&"trim_paint", Vector3(wx0 + ft, ty - 0.03, z0 + 0.01), Vector3(wx1 - ft, ty + 0.03, z1 - 0.005), 0.008)
		mullion_top = ty - 0.03
	if wx1 - wx0 > 0.95:
		var cx: float = (wx0 + wx1) / 2.0
		b.box_mm(&"trim_paint", Vector3(cx - 0.03, wy0 + ft, z0 + 0.01), Vector3(cx + 0.03, mullion_top, z1 - 0.005), 0.008)
	# Glass with UV 0..1 across the opening (needed for the fake interior).
	var gz: float = z0 + fd * 0.4
	b.color = _room_color()
	b.quad(glass, Vector3(wx0 + ft, wy0 + ft, gz), Vector3(wx1 - ft, wy0 + ft, gz),
			Vector3(wx1 - ft, wy1 - ft, gz), Vector3(wx0 + ft, wy1 - ft, gz), Vector3.BACK,
			PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]))
	b.color = Color.WHITE
	if sill:
		b.box_mm(&"bluestone", Vector3(wx0 - 0.06, wy0 - 0.07, -r - 0.02), Vector3(wx1 + 0.06, wy0, 0.05), 0.012)
	if wall_material != "plaster" and wall_material != "concrete":
		b.box_mm(&"bluestone", Vector3(wx0 - 0.05, wy1, -0.02), Vector3(wx1 + 0.05, wy1 + 0.13, 0.012), 0.008)
	b.collide = c


## Returns the x range of the door opening (for the plinth).
func _door_cell(b: MeshBuilder, x0: float, x1: float, y0: float, y1: float, lining: bool, frame: Transform3D) -> Vector2:
	var shop: bool = ground_floor == "shop"
	var dw: float = 1.6 if (shop and enterable) else (1.25 if enterable else 1.05)
	var dh: float = 2.3
	var step: float = 0.15
	var cx: float = (x0 + x1) / 2.0
	var dx0: float = cx - dw / 2.0
	var dx1: float = cx + dw / 2.0
	var dy1: float = step + dh
	var ty1: float = minf(dy1 + 0.5, y1 - 0.3)
	_wall(b, x0, dx0, y0, y1, lining)
	_wall(b, dx1, x1, y0, y1, lining)
	_wall(b, dx0, dx1, ty1, y1, lining)
	var c: bool = b.collide
	b.collide = false
	var fk: StringName = &"metal_dark" if shop else &"trim_paint"
	var ft: float = 0.07
	b.box_mm(fk, Vector3(dx0, step, -0.2), Vector3(dx0 + ft, ty1, -0.1), 0.01)
	b.box_mm(fk, Vector3(dx1 - ft, step, -0.2), Vector3(dx1, ty1, -0.1), 0.01)
	b.box_mm(fk, Vector3(dx0 + ft, ty1 - ft, -0.2), Vector3(dx1 - ft, ty1, -0.1), 0.01)
	b.box_mm(fk, Vector3(dx0 + ft, dy1, -0.2), Vector3(dx1 - ft, dy1 + ft, -0.1), 0.01)
	# Transom light above the door.
	b.color = _room_color()
	var gz: float = -0.16
	b.quad(&"glass_clear" if enterable else &"glass_interior",
			Vector3(dx0 + ft, dy1 + ft, gz), Vector3(dx1 - ft, dy1 + ft, gz),
			Vector3(dx1 - ft, ty1 - ft, gz), Vector3(dx0 + ft, ty1 - ft, gz), Vector3.BACK,
			PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]))
	b.color = Color.WHITE
	if enterable:
		_door_slots.append({
			"xform": frame * Transform3D(Basis.IDENTITY, Vector3(dx0 + ft, step, -0.15)),
			"width": dw - ft * 2.0, "height": dh, "glass": shop})
	elif shop:
		# Glass shop door.
		b.box_mm(&"metal_dark", Vector3(dx0 + ft, step, -0.19), Vector3(dx1 - ft, dy1, -0.14), 0.005)
		b.color = _room_color()
		b.quad(&"glass_shop", Vector3(dx0 + 0.14, step + 0.12, -0.135), Vector3(dx1 - 0.14, step + 0.12, -0.135),
				Vector3(dx1 - 0.14, dy1 - 0.12, -0.135), Vector3(dx0 + 0.14, dy1 - 0.12, -0.135), Vector3.BACK,
				PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]))
		b.color = Color.WHITE
	else:
		# Panelled wooden front door with handle and letterbox.
		b.box_mm(&"door_paint", Vector3(dx0 + ft, step, -0.2), Vector3(dx1 - ft, dy1, -0.14), 0.01)
		b.box_mm(&"door_paint", Vector3(dx0 + 0.2, step + 1.3, -0.14), Vector3(dx1 - 0.2, dy1 - 0.2, -0.122), 0.012)
		b.box_mm(&"door_paint", Vector3(dx0 + 0.2, step + 0.2, -0.14), Vector3(dx1 - 0.2, step + 1.05, -0.122), 0.012)
		b.box_mm(&"zinc", Vector3(dx1 - 0.24, step + 1.0, -0.14), Vector3(dx1 - 0.16, step + 1.06, -0.08), 0.01)
		b.box_mm(&"zinc", Vector3(cx - 0.17, step + 1.12, -0.14), Vector3(cx + 0.17, step + 1.18, -0.128), 0.004)
	# Bluestone doorstep.
	b.collide = c
	b.box_mm(&"bluestone", Vector3(dx0 - 0.12, -0.1, -0.12), Vector3(dx1 + 0.12, step, 0.32), 0.015)
	return Vector2(dx0 - 0.12, dx1 + 0.12)


func _shop_cell(b: MeshBuilder, x0: float, x1: float, y0: float, y1: float, lining: bool) -> void:
	var gx0: float = x0 + 0.18
	var gx1: float = x1 - 0.18
	var gy0: float = 0.55
	var gy1: float = y1 - 0.5
	_wall(b, x0, gx0, y0, y1, lining)
	_wall(b, gx1, x1, y0, y1, lining)
	_wall(b, gx0, gx1, gy1, y1, lining)
	_wall(b, gx0, gx1, y0, gy0, lining, &"bluestone")
	var c: bool = b.collide
	b.collide = false
	var z0: float = -0.16
	var z1: float = -0.08
	b.box_mm(&"metal_dark", Vector3(gx0, gy0, z0), Vector3(gx0 + 0.08, gy1, z1), 0.008)
	b.box_mm(&"metal_dark", Vector3(gx1 - 0.08, gy0, z0), Vector3(gx1, gy1, z1), 0.008)
	b.box_mm(&"metal_dark", Vector3(gx0, gy0, z0), Vector3(gx1, gy0 + 0.08, z1), 0.008)
	b.box_mm(&"metal_dark", Vector3(gx0, gy1 - 0.08, z0), Vector3(gx1, gy1, z1), 0.008)
	if gx1 - gx0 > 1.8:
		var cx: float = (gx0 + gx1) / 2.0
		b.box_mm(&"metal_dark", Vector3(cx - 0.035, gy0, z0), Vector3(cx + 0.035, gy1, z1), 0.008)
	b.color = _room_color()
	b.color.a = 1.0
	var gz: float = -0.13
	b.quad(&"glass_clear" if enterable else &"glass_shop",
			Vector3(gx0 + 0.08, gy0 + 0.08, gz), Vector3(gx1 - 0.08, gy0 + 0.08, gz),
			Vector3(gx1 - 0.08, gy1 - 0.08, gz), Vector3(gx0 + 0.08, gy1 - 0.08, gz), Vector3.BACK,
			PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]))
	b.color = Color.WHITE
	b.collide = c
	if enterable:
		b.add_collision_box(Vector3((gx0 + gx1) / 2.0, (gy0 + gy1) / 2.0, -0.12), Vector3(gx1 - gx0, gy1 - gy0, 0.1))


func _bay_window(b: MeshBuilder, x0: float, x1: float, y0: float, y1: float) -> void:
	var ex0: float = x0 + 0.25
	var ex1: float = x1 - 0.25
	var p: float = 0.62
	var ey0: float = y0 + 0.3
	var ey1: float = y1 - 0.15
	var wy0: float = ey0 + 0.7
	var wy1: float = ey1 - 0.35
	b.box_mm(&"bluestone", Vector3(ex0 + 0.25, ey0 - 0.35, 0), Vector3(ex0 + 0.4, ey0, p * 0.7), 0.01)
	b.box_mm(&"bluestone", Vector3(ex1 - 0.4, ey0 - 0.35, 0), Vector3(ex1 - 0.25, ey0, p * 0.7), 0.01)
	b.box_mm(&"trim_paint", Vector3(ex0 - 0.05, ey0 - 0.12, 0), Vector3(ex1 + 0.05, ey0, p + 0.05), 0.02)
	b.box_mm(&"trim_paint", Vector3(ex0, ey0, 0), Vector3(ex1, wy0, p), 0.01)
	b.box_mm(&"trim_paint", Vector3(ex0, wy1, 0), Vector3(ex1, ey1, p), 0.01)
	b.box_mm(&"zinc", Vector3(ex0 - 0.07, ey1, -0.02), Vector3(ex1 + 0.07, ey1 + 0.09, p + 0.09), 0.02)
	# Posts and mullions.
	for x: float in [ex0, ex1 - 0.08]:
		b.box_mm(&"trim_paint", Vector3(x, wy0, p - 0.08), Vector3(x + 0.08, wy1, p), 0.008)
	var third: float = (ex1 - ex0) / 3.0
	for i: int in [1, 2]:
		var mx: float = ex0 + third * i
		b.box_mm(&"trim_paint", Vector3(mx - 0.03, wy0, p - 0.07), Vector3(mx + 0.03, wy1, p - 0.01), 0.006)
	var uv := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	b.color = _room_color()
	b.quad(&"glass_interior", Vector3(ex0 + 0.08, wy0, p - 0.04), Vector3(ex1 - 0.08, wy0, p - 0.04),
			Vector3(ex1 - 0.08, wy1, p - 0.04), Vector3(ex0 + 0.08, wy1, p - 0.04), Vector3.BACK, uv)
	b.quad(&"glass_interior", Vector3(ex0 + 0.03, wy0, 0.02), Vector3(ex0 + 0.03, wy0, p - 0.08),
			Vector3(ex0 + 0.03, wy1, p - 0.08), Vector3(ex0 + 0.03, wy1, 0.02), Vector3.LEFT, uv)
	b.quad(&"glass_interior", Vector3(ex1 - 0.03, wy0, p - 0.08), Vector3(ex1 - 0.03, wy0, 0.02),
			Vector3(ex1 - 0.03, wy1, 0.02), Vector3(ex1 - 0.03, wy1, p - 0.08), Vector3.RIGHT, uv)
	b.color = Color.WHITE


func _balcony_cell(b: MeshBuilder, x0: float, x1: float, y0: float, y1: float) -> void:
	var ww: float = clampf((x1 - x0) - 0.9, 0.8, 1.4)
	var cx: float = (x0 + x1) / 2.0
	var wx0: float = cx - ww / 2.0
	var wx1: float = cx + ww / 2.0
	var wy0: float = y0 + 0.05
	var wy1: float = minf(y0 + 2.4, y1 - 0.3)
	_wall(b, x0, wx0, y0, y1, false)
	_wall(b, wx1, x1, y0, y1, false)
	_wall(b, wx0, wx1, wy1, y1, false)
	_window(b, wx0, wx1, wy0, wy1, &"glass_interior", true, false)
	# Slab and railing.
	var bx0: float = x0 + 0.15
	var bx1: float = x1 - 0.15
	var d: float = 1.0
	b.box_mm(&"concrete", Vector3(bx0, y0 - 0.16, 0), Vector3(bx1, y0, d), 0.02)
	var rail_y: float = y0 + 1.0
	b.box_mm(&"metal_dark", Vector3(bx0 + 0.03, rail_y, d - 0.07), Vector3(bx1 - 0.03, rail_y + 0.04, d - 0.03), 0.005)
	b.box_mm(&"metal_dark", Vector3(bx0 + 0.03, rail_y, 0), Vector3(bx0 + 0.07, rail_y + 0.04, d - 0.03), 0.005)
	b.box_mm(&"metal_dark", Vector3(bx1 - 0.07, rail_y, 0), Vector3(bx1 - 0.03, rail_y + 0.04, d - 0.03), 0.005)
	var x: float = bx0 + 0.05
	while x < bx1 - 0.05:
		b.box_mm(&"metal_dark", Vector3(x - 0.01, y0, d - 0.06), Vector3(x + 0.01, rail_y, d - 0.04))
		x += 0.12
	var z: float = 0.1
	while z < d - 0.1:
		b.box_mm(&"metal_dark", Vector3(bx0 + 0.04, y0, z - 0.01), Vector3(bx0 + 0.06, rail_y, z + 0.01))
		b.box_mm(&"metal_dark", Vector3(bx1 - 0.06, y0, z - 0.01), Vector3(bx1 - 0.04, rail_y, z + 0.01))
		z += 0.12


func _shop_extras(b: MeshBuilder) -> void:
	var half: float = width / 2.0
	var fy: float = floor_height
	# Fascia board for the shop name.
	b.box_mm(&"metal_dark", Vector3(-half + 0.1, fy - 0.5, 0.0), Vector3(half - 0.1, fy - 0.02, 0.1), 0.015)
	if shop_sign != "":
		var label := Label3D.new()
		label.text = shop_sign
		label.font_size = 96
		label.pixel_size = 0.0035
		label.outline_size = 0
		label.modulate = Color(0.96, 0.93, 0.85)
		label.position = Vector3(0, fy - 0.26, 0.105)
		label.shaded = false
		_add_generated(label)
	if awning:
		var ax0: float = -half + 0.25
		var ax1: float = half - 0.25
		var y_top: float = fy - 0.55
		var y_low: float = y_top - 0.55
		var out: float = 1.35
		var stripe: float = 0.45
		var x: float = ax0
		var k: int = 0
		while x < ax1 - 0.01:
			var xe: float = minf(x + stripe, ax1)
			b.color = awning_color if k % 2 == 0 else Color(0.92, 0.9, 0.84)
			b.quad(&"awning", Vector3(x, y_top, 0.1), Vector3(xe, y_top, 0.1),
					Vector3(xe, y_low, out), Vector3(x, y_low, out), Vector3(0, 1, 0.5))
			b.quad(&"awning", Vector3(x, y_low, out), Vector3(xe, y_low, out),
					Vector3(xe, y_low - 0.25, out), Vector3(x, y_low - 0.25, out), Vector3.BACK)
			x = xe
			k += 1
		b.color = Color.WHITE
		# Side arms.
		for ax: float in [ax0 + 0.05, ax1 - 0.05]:
			b.cylinder(&"metal_dark", Vector3(ax, y_top - 0.6, 0.1), Vector3(ax, y_low, out - 0.05), 0.015, 0.015, 6, false)


# --- Roof ------------------------------------------------------------------------

func _roof(b: MeshBuilder) -> void:
	var t: float = tan(deg_to_rad(roof_pitch))
	var roof_key := StringName(roof_material)
	var zc: float = -depth / 2.0
	match roof_type:
		"flat":
			b.box_mm(&"asphalt", Vector3(-width / 2.0 + WALL_T, _H, -depth + WALL_T), Vector3(width / 2.0 - WALL_T, _H + 0.12, -WALL_T))
			if chimney != "none":
				_chimney(b, _H + 1.4)
		"hip":
			var o: float = 0.35
			var a: float = width / 2.0 + o
			var c: float = depth / 2.0 + o
			var ye: float = _H - o * t
			var ry: float = ye + minf(a, c) * t
			if a >= c:
				var rx: float = a - c
				var slope_f := Vector3(0, t, -1).normalized()
				var slope_s := Vector3(-1, t, 0).normalized()
				b.poly(roof_key, PackedVector3Array([Vector3(-a, ye, zc + c), Vector3(a, ye, zc + c), Vector3(rx, ry, zc), Vector3(-rx, ry, zc)]),
						Vector3(0, 1, 1), PackedVector2Array(), Vector3.RIGHT, slope_f)
				b.poly(roof_key, PackedVector3Array([Vector3(-a, ye, zc - c), Vector3(a, ye, zc - c), Vector3(rx, ry, zc), Vector3(-rx, ry, zc)]),
						Vector3(0, 1, -1), PackedVector2Array(), Vector3.RIGHT, Vector3(0, t, 1).normalized())
				b.poly(roof_key, PackedVector3Array([Vector3(a, ye, zc + c), Vector3(a, ye, zc - c), Vector3(rx, ry, zc)]),
						Vector3(1, 1, 0), PackedVector2Array(), Vector3.BACK, slope_s)
				b.poly(roof_key, PackedVector3Array([Vector3(-a, ye, zc + c), Vector3(-a, ye, zc - c), Vector3(-rx, ry, zc)]),
						Vector3(-1, 1, 0), PackedVector2Array(), Vector3.BACK, Vector3(1, t, 0).normalized())
				if rx > 0.05:
					_ridge_cap(b, roof_key, Vector3(0, ry, zc), rx * 2.0 + 0.2)
			else:
				var rz: float = c - a
				b.poly(roof_key, PackedVector3Array([Vector3(-a, ye, zc + c), Vector3(-a, ye, zc - c), Vector3(0, ry, zc - rz), Vector3(0, ry, zc + rz)]),
						Vector3(-1, 1, 0), PackedVector2Array(), Vector3.BACK, Vector3(1, t, 0).normalized())
				b.poly(roof_key, PackedVector3Array([Vector3(a, ye, zc + c), Vector3(a, ye, zc - c), Vector3(0, ry, zc - rz), Vector3(0, ry, zc + rz)]),
						Vector3(1, 1, 0), PackedVector2Array(), Vector3.BACK, Vector3(-1, t, 0).normalized())
				b.poly(roof_key, PackedVector3Array([Vector3(-a, ye, zc + c), Vector3(a, ye, zc + c), Vector3(0, ry, zc + rz)]),
						Vector3(0, 1, 1), PackedVector2Array(), Vector3.RIGHT, Vector3(0, t, -1).normalized())
				b.poly(roof_key, PackedVector3Array([Vector3(-a, ye, zc - c), Vector3(a, ye, zc - c), Vector3(0, ry, zc - rz)]),
						Vector3(0, 1, -1), PackedVector2Array(), Vector3.RIGHT, Vector3(0, t, 1).normalized())
			# Fascia boards and soffit.
			_fascia_rect(b, a, c, ye, zc)
			if dormer:
				_dormer(b, t, roof_key)
			if chimney != "none":
				_chimney(b, ry + 0.8)
		_:
			# Gable roof, ridge parallel to the street.
			var o: float = 0.35
			var so: float = _side_overhang()
			var xl: float = -width / 2.0 - so
			var xr: float = width / 2.0 + so
			var ry: float = _H + depth / 2.0 * t
			var ye: float = _H - o * t
			var zf: float = o
			var zb: float = -depth - o
			b.poly(roof_key, PackedVector3Array([Vector3(xl, ye, zf), Vector3(xr, ye, zf), Vector3(xr, ry, zc), Vector3(xl, ry, zc)]),
					Vector3(0, 1, 1), PackedVector2Array(), Vector3.RIGHT, Vector3(0, t, -1).normalized())
			b.poly(roof_key, PackedVector3Array([Vector3(xl, ye, zb), Vector3(xr, ye, zb), Vector3(xr, ry, zc), Vector3(xl, ry, zc)]),
					Vector3(0, 1, -1), PackedVector2Array(), Vector3.RIGHT, Vector3(0, t, 1).normalized())
			# Underside (soffit) of the overhangs.
			var th: float = 0.16
			b.poly(&"trim_paint", PackedVector3Array([Vector3(xl, ye - th, zf), Vector3(xr, ye - th, zf), Vector3(xr, _H - th, 0), Vector3(xl, _H - th, 0)]), Vector3(0, -1, 0))
			b.poly(&"trim_paint", PackedVector3Array([Vector3(xl, ye - th, zb), Vector3(xr, ye - th, zb), Vector3(xr, _H - th, -depth), Vector3(xl, _H - th, -depth)]), Vector3(0, -1, 0))
			# Fascia (front/back edges) and barge boards (gable edges).
			b.quad(&"trim_paint", Vector3(xl, ye, zf), Vector3(xr, ye, zf), Vector3(xr, ye - th, zf), Vector3(xl, ye - th, zf), Vector3.BACK)
			b.quad(&"trim_paint", Vector3(xl, ye, zb), Vector3(xr, ye, zb), Vector3(xr, ye - th, zb), Vector3(xl, ye - th, zb), Vector3.FORWARD)
			for x: float in [xl, xr]:
				var n := Vector3(signf(x), 0, 0)
				b.quad(&"trim_paint", Vector3(x, ye, zf), Vector3(x, ry, zc), Vector3(x, ry - th, zc), Vector3(x, ye - th, zf), n)
				b.quad(&"trim_paint", Vector3(x, ye, zb), Vector3(x, ry, zc), Vector3(x, ry - th, zc), Vector3(x, ye - th, zb), n)
			# Gable end walls.
			for s: float in [-1.0, 1.0]:
				var x: float = s * width / 2.0
				b.poly(_wall_key, PackedVector3Array([Vector3(x, _H, 0), Vector3(x, _H, -depth), Vector3(x, ry, zc)]), Vector3(s, 0, 0))
			_ridge_cap(b, roof_key, Vector3(0, ry, zc), xr - xl)
			if dormer:
				_dormer(b, t, roof_key)
			if chimney != "none":
				_chimney(b, ry + 0.8)


func _ridge_cap(b: MeshBuilder, key: StringName, center: Vector3, length: float) -> void:
	var saved: Transform3D = b.xform
	b.xform = Transform3D(Basis(Vector3.RIGHT, PI / 4.0), center)
	b.box(key, Vector3.ZERO, Vector3(length, 0.2, 0.2), 0.02)
	b.xform = saved


func _fascia_rect(b: MeshBuilder, a: float, c: float, ye: float, zc: float) -> void:
	var th: float = 0.16
	b.quad(&"trim_paint", Vector3(-a, ye, zc + c), Vector3(a, ye, zc + c), Vector3(a, ye - th, zc + c), Vector3(-a, ye - th, zc + c), Vector3.BACK)
	b.quad(&"trim_paint", Vector3(-a, ye, zc - c), Vector3(a, ye, zc - c), Vector3(a, ye - th, zc - c), Vector3(-a, ye - th, zc - c), Vector3.FORWARD)
	b.quad(&"trim_paint", Vector3(a, ye, zc - c), Vector3(a, ye, zc + c), Vector3(a, ye - th, zc + c), Vector3(a, ye - th, zc - c), Vector3.RIGHT)
	b.quad(&"trim_paint", Vector3(-a, ye, zc - c), Vector3(-a, ye, zc + c), Vector3(-a, ye - th, zc + c), Vector3(-a, ye - th, zc - c), Vector3.LEFT)
	b.quad(&"trim_paint", Vector3(-a, ye - th, zc - c), Vector3(a, ye - th, zc - c), Vector3(a, ye - th, zc + c), Vector3(-a, ye - th, zc + c), Vector3.DOWN)


func _dormer(b: MeshBuilder, t: float, roof_key: StringName) -> void:
	var dw: float = minf(1.8, width - 1.6)
	if dw < 1.0:
		return
	var zf: float = -0.9
	var yb: float = _H + (-zf) * t
	var dh: float = 1.45
	var top: float = yb + dh
	var zb: float = -((top - _H) / t) - 0.2
	var x0: float = -dw / 2.0
	var x1: float = dw / 2.0
	# Cheeks and front panel (zinc cladding).
	b.box_mm(&"zinc", Vector3(x0, yb - 0.3, zb), Vector3(x0 + 0.08, top, zf), 0.01)
	b.box_mm(&"zinc", Vector3(x1 - 0.08, yb - 0.3, zb), Vector3(x1, top, zf), 0.01)
	b.box_mm(&"zinc", Vector3(x0, yb - 0.3, zf - 0.1), Vector3(x1, yb + 0.12, zf), 0.01)
	b.box_mm(&"zinc", Vector3(x0, top - 0.22, zf - 0.1), Vector3(x1, top, zf), 0.01)
	b.box_mm(&"zinc", Vector3(x0 - 0.1, top, zb), Vector3(x1 + 0.1, top + 0.1, zf + 0.12), 0.02)
	var saved: Transform3D = b.xform
	b.xform = Transform3D(Basis.IDENTITY, Vector3(0, 0, zf + 0.1))
	_window(b, x0 + 0.08, x1 - 0.08, yb + 0.12, top - 0.22, &"glass_interior", false, false)
	b.xform = saved


func _chimney(b: MeshBuilder, top: float) -> void:
	var s: float = -1.0 if chimney == "left" else 1.0
	var x: float = s * (width / 2.0 - 0.75)
	var z: float = -depth / 2.0 - 0.45
	b.box_mm(_wall_key, Vector3(x - 0.32, _H - 0.5, z - 0.26), Vector3(x + 0.32, top, z + 0.26))
	b.box_mm(&"bluestone", Vector3(x - 0.38, top, z - 0.32), Vector3(x + 0.38, top + 0.08, z + 0.32), 0.015)
	b.cylinder(&"roof_red", Vector3(x - 0.12, top + 0.08, z), Vector3(x - 0.12, top + 0.35, z), 0.09, 0.075, 8)
	b.cylinder(&"roof_red", Vector3(x + 0.13, top + 0.08, z), Vector3(x + 0.13, top + 0.3, z), 0.09, 0.075, 8)


# --- Interior --------------------------------------------------------------------

func _interior(b: MeshBuilder) -> void:
	var x0: float = -width / 2.0 + WALL_T
	var x1: float = width / 2.0 - WALL_T
	var z0: float = -depth + WALL_T
	var z1: float = -WALL_T
	var fh: float = floor_height
	b.collide = true
	b.box_mm(StringName(floor_material), Vector3(x0, -0.1, z0), Vector3(x1, 0.15, z1))
	b.collide = false
	b.quad(&"interior_plaster", Vector3(x0, fh - 0.02, z0), Vector3(x1, fh - 0.02, z0),
			Vector3(x1, fh - 0.02, z1), Vector3(x0, fh - 0.02, z1), Vector3.DOWN)
	# Skirting boards.
	b.box_mm(&"trim_paint", Vector3(x0, 0.15, z0), Vector3(x1, 0.27, z0 + 0.02))
	b.box_mm(&"trim_paint", Vector3(x0, 0.15, z0), Vector3(x0 + 0.02, 0.27, z1))
	b.box_mm(&"trim_paint", Vector3(x1 - 0.02, 0.15, z0), Vector3(x1, 0.27, z1))
