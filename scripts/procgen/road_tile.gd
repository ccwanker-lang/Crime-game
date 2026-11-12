@tool
class_name RoadTile
extends StaticBody3D
## 12 x 12 m road tile: asphalt, curbs, raised sidewalks, markings.
## Tiles connect at their edge centres; place them on a 12 m grid and rotate in
## steps of 90 degrees. Local layout: the road runs along X; -Z is "north".
##   STRAIGHT: west <-> east
##   CURVE:    west <-> south (+Z)
##   T:        west <-> east, branch to the north (-Z)
##   CROSS:    all four directions

enum Type { STRAIGHT, CURVE, T, CROSS }

const TILE: float = 12.0
const HALF: float = 6.0
const ROAD_HALF: float = 3.5
const SIDEWALK_TOP: float = 0.15
const SIDE_BOTTOM: float = -0.05
const CORNER_RADIUS: float = 1.8
const CURB_WIDTH: float = 0.22
const MARK_Y: float = 0.006

@export var type: Type = Type.STRAIGHT:
	set(v):
		type = v
		_queue_rebuild()
@export var center_line: bool = true:
	set(v):
		center_line = v
		_queue_rebuild()
@export var zebra: bool = true:
	set(v):
		zebra = v
		_queue_rebuild()

## STRAIGHT only: a zebra crossing across the road in the middle of the tile.
@export var crossing: bool = false:
	set(v):
		crossing = v
		_queue_rebuild()

## Asphalt without the zebra crossings (local XZ, convex parts). Pedestrians may
## not walk here: NavigationObstacle3D children carve it out of the navmesh.
var blocked_areas: Array[PackedVector2Array] = []
## All asphalt (local XZ), zebras included.
var asphalt_areas: Array[PackedVector2Array] = []

var _mesh_instance: MeshInstance3D
var _shape: CollisionShape3D
var _pending: bool = false


func _ready() -> void:
	_rebuild()


func _queue_rebuild() -> void:
	if not is_inside_tree() or _pending:
		return
	_pending = true
	_rebuild.call_deferred()


func _rebuild() -> void:
	_pending = false
	if _mesh_instance == null:
		_mesh_instance = MeshInstance3D.new()
		add_child(_mesh_instance)
		_shape = CollisionShape3D.new()
		add_child(_shape)
	var b := MeshBuilder.new()
	var sidewalks: Array[PackedVector2Array] = _sidewalk_polygons()

	# Asphalt = tile square minus the sidewalks.
	var asphalt: Array[PackedVector2Array] = [PackedVector2Array([
		Vector2(-HALF, -HALF), Vector2(HALF, -HALF), Vector2(HALF, HALF), Vector2(-HALF, HALF)])]
	for sw: PackedVector2Array in sidewalks:
		var next: Array[PackedVector2Array] = []
		for a: PackedVector2Array in asphalt:
			for r: PackedVector2Array in Geometry2D.clip_polygons(a, sw):
				next.append(r)
		asphalt = next
	for a: PackedVector2Array in asphalt:
		b.slab(&"asphalt", &"asphalt", a, 0.0, 0.0)
	_build_obstacles(asphalt)

	for sw: PackedVector2Array in sidewalks:
		_add_sidewalk(b, sw)
	_add_markings(b)

	var mesh: ArrayMesh = b.build()
	_mesh_instance.mesh = mesh
	_shape.shape = mesh.create_trimesh_shape()


## Carves the road (minus zebra crossings) out of the navigation mesh, so
## pedestrians stay on the sidewalks and cross only at zebras.
func _build_obstacles(asphalt: Array[PackedVector2Array]) -> void:
	for c: Node in get_children():
		if c is NavigationObstacle3D:
			c.queue_free()
	blocked_areas.clear()
	asphalt_areas = asphalt.duplicate()
	var parts: Array[PackedVector2Array] = asphalt.duplicate()
	for zone: PackedVector2Array in _crossing_zones():
		var next: Array[PackedVector2Array] = []
		for a: PackedVector2Array in parts:
			# Zones always cross the whole road, so clipping never leaves holes.
			for r: PackedVector2Array in Geometry2D.clip_polygons(a, zone):
				next.append(r)
		parts = next
	for a: PackedVector2Array in parts:
		for convex: PackedVector2Array in Geometry2D.decompose_polygon_in_convex(a):
			blocked_areas.append(convex)
			var ob := NavigationObstacle3D.new()
			ob.avoidance_enabled = false
			ob.affect_navigation_mesh = true
			ob.carve_navigation_mesh = false  # grown by the agent radius: paths keep clear of the road
			ob.height = 1.0
			ob.position.y = -0.5
			var verts := PackedVector3Array()
			for p: Vector2 in convex:
				verts.append(Vector3(p.x, 0, p.y))
			ob.vertices = verts
			add_child(ob)


## Walkable strips across the road (the zebras, widened to the curbs).
func _crossing_zones() -> Array[PackedVector2Array]:
	var zones: Array[Rect2] = []
	match type:
		Type.STRAIGHT:
			if crossing:
				zones.append(Rect2(-1.2, -HALF, 2.4, TILE))
		Type.T:
			if zebra:
				zones.append(Rect2(-HALF, -5.9, TILE, 1.1))
		Type.CROSS:
			if zebra:
				zones.append(Rect2(-HALF, -5.9, TILE, 1.8))
				zones.append(Rect2(-HALF, 4.1, TILE, 1.8))
				zones.append(Rect2(-5.9, -HALF, 1.8, TILE))
				zones.append(Rect2(4.1, -HALF, 1.8, TILE))
	var out: Array[PackedVector2Array] = []
	for r: Rect2 in zones:
		out.append(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]))
	return out


## True if a world position is on the road outside a zebra crossing.
func is_blocked(world_pos: Vector3) -> bool:
	var l: Vector3 = to_local(world_pos)
	for a: PackedVector2Array in blocked_areas:
		if Geometry2D.is_point_in_polygon(Vector2(l.x, l.z), a):
			return true
	return false


## Is world_pos above the asphalt (zebras included)?
func is_on_asphalt(world_pos: Vector3) -> bool:
	var l: Vector3 = to_local(world_pos)
	for a: PackedVector2Array in asphalt_areas:
		if Geometry2D.is_point_in_polygon(Vector2(l.x, l.z), a):
			return true
	return false


# --- Layout ------------------------------------------------------------------

func _sidewalk_polygons() -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	match type:
		Type.STRAIGHT:
			result.append(_strip(1.0))
			result.append(_strip(-1.0))
		Type.T:
			result.append(_strip(1.0))
			result.append(_rounded_corner(-1.0, -1.0))
			result.append(_rounded_corner(1.0, -1.0))
		Type.CROSS:
			for sx: float in [-1.0, 1.0]:
				for sz: float in [-1.0, 1.0]:
					result.append(_rounded_corner(sx, sz))
		Type.CURVE:
			var c := Vector2(-HALF, HALF)
			var inner := PackedVector2Array([c])
			for p: Vector2 in _arc(c, HALF - ROAD_HALF, -PI / 2.0, 0.0, 10):
				inner.append(p)
			result.append(inner)
			var outer := PackedVector2Array([Vector2(-HALF, -HALF), Vector2(HALF, -HALF), Vector2(HALF, HALF)])
			for p: Vector2 in _arc(c, HALF + ROAD_HALF, 0.0, -PI / 2.0, 16):
				outer.append(p)
			result.append(outer)
	return result


## Sidewalk strip along the whole tile on the +Z (side = 1) or -Z side.
func _strip(side: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-HALF, ROAD_HALF * side), Vector2(HALF, ROAD_HALF * side),
		Vector2(HALF, HALF * side), Vector2(-HALF, HALF * side)])


## Corner block of sidewalk with a rounded curb towards the junction.
func _rounded_corner(sx: float, sz: float) -> PackedVector2Array:
	var r: float = CORNER_RADIUS
	var pts := PackedVector2Array([Vector2(sx * ROAD_HALF, sz * HALF)])
	var kc := Vector2(sx * (ROAD_HALF + r), sz * (ROAD_HALF + r))
	for i: int in 9:
		var t: float = float(i) / 8.0 * PI / 2.0
		pts.append(kc + Vector2(-sx * cos(t), -sz * sin(t)) * r)
	pts.append(Vector2(sx * HALF, sz * ROAD_HALF))
	pts.append(Vector2(sx * HALF, sz * HALF))
	return pts


static func _arc(c: Vector2, r: float, a0: float, a1: float, steps: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i: int in steps + 1:
		var a: float = lerpf(a0, a1, float(i) / steps)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


static func _on_boundary(a: Vector2, b: Vector2) -> bool:
	for axis: int in 2:
		if absf(absf(a[axis]) - HALF) < 0.01 and absf(absf(b[axis]) - HALF) < 0.01 and absf(a[axis] - b[axis]) < 0.01:
			return true
	return false


func _add_sidewalk(b: MeshBuilder, sw: PackedVector2Array) -> void:
	var count: int = sw.size()
	var sides: Array = []
	for i: int in count:
		var p0: Vector2 = sw[i]
		var p1: Vector2 = sw[(i + 1) % count]
		# Draw sides facing the road, and long outer edges (towards grass/buildings).
		# Short edges on the tile boundary continue into the next tile: no side.
		sides.append(not _on_boundary(p0, p1) or p0.distance_to(p1) > 2.6)
	b.slab(&"sidewalk", &"curb", sw, SIDEWALK_TOP, SIDE_BOTTOM, sides)
	# Curb stones: a concrete band along the road-facing edges.
	for i: int in count:
		var p0: Vector2 = sw[i]
		var p1: Vector2 = sw[(i + 1) % count]
		if _on_boundary(p0, p1):
			continue
		var d: Vector2 = (p1 - p0)
		if d.length() < 1e-4:
			continue
		var n := Vector2(d.y, -d.x).normalized()
		if not Geometry2D.is_point_in_polygon((p0 + p1) * 0.5 + n * 0.05, sw):
			n = -n
		var y: float = SIDEWALK_TOP + 0.004
		var q0: Vector2 = p0 + n * CURB_WIDTH
		var q1: Vector2 = p1 + n * CURB_WIDTH
		b.quad(&"curb", Vector3(p0.x, y, p0.y), Vector3(p1.x, y, p1.y), Vector3(q1.x, y, q1.y), Vector3(q0.x, y, q0.y), Vector3.UP)


# --- Markings ----------------------------------------------------------------

func _add_markings(b: MeshBuilder) -> void:
	match type:
		Type.STRAIGHT:
			if center_line:
				for x0: float in [-4.5, 1.5]:
					_rect(b, Vector2(x0, -0.06), Vector2(x0 + 3.0, 0.06))
			if crossing:
				_zebra(b, Vector2(-1.2, -3.3), Vector2(1.2, 3.3), false)
		Type.CURVE:
			if center_line:
				var c := Vector2(-HALF, HALF)
				for span: Vector2 in [Vector2(0.6, 3.6), Vector2(6.0, 8.8)]:
					var a0: float = -PI / 2.0 + span.x / HALF
					var a1: float = -PI / 2.0 + span.y / HALF
					var inner: PackedVector2Array = _arc(c, HALF - 0.06, a0, a1, 6)
					var outer: PackedVector2Array = _arc(c, HALF + 0.06, a0, a1, 6)
					for i: int in 6:
						_quad2(b, inner[i], inner[i + 1], outer[i + 1], outer[i])
		Type.T:
			# Shark teeth (yield) on the incoming lane of the branch.
			for i: int in 6:
				var x: float = -3.2 + i * 0.55
				_tri2(b, Vector2(x, -3.9), Vector2(x + 0.45, -3.9), Vector2(x + 0.225, -4.55))
			if zebra:
				_zebra(b, Vector2(-3.3, -5.9), Vector2(3.3, -4.8), true)
		Type.CROSS:
			if zebra:
				_zebra(b, Vector2(-3.3, -5.9), Vector2(3.3, -4.1), true)
				_zebra(b, Vector2(-3.3, 4.1), Vector2(3.3, 5.9), true)
				_zebra(b, Vector2(-5.9, -3.3), Vector2(-4.1, 3.3), false)
				_zebra(b, Vector2(4.1, -3.3), Vector2(5.9, 3.3), false)


## Zebra stripes inside a rectangle; stripes run along Z if along_z, else along X.
func _zebra(b: MeshBuilder, mn: Vector2, mx: Vector2, along_z: bool) -> void:
	var start: float = mn.x if along_z else mn.y
	var end: float = mx.x if along_z else mx.y
	var pos: float = start
	while pos + 0.5 <= end + 0.01:
		if along_z:
			_rect(b, Vector2(pos, mn.y), Vector2(pos + 0.5, mx.y))
		else:
			_rect(b, Vector2(mn.x, pos), Vector2(mx.x, pos + 0.5))
		pos += 1.0


func _rect(b: MeshBuilder, mn: Vector2, mx: Vector2) -> void:
	_quad2(b, mn, Vector2(mx.x, mn.y), mx, Vector2(mn.x, mx.y))


func _quad2(b: MeshBuilder, p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2) -> void:
	b.quad(&"road_marking", Vector3(p0.x, MARK_Y, p0.y), Vector3(p1.x, MARK_Y, p1.y),
			Vector3(p2.x, MARK_Y, p2.y), Vector3(p3.x, MARK_Y, p3.y), Vector3.UP)


func _tri2(b: MeshBuilder, p0: Vector2, p1: Vector2, p2: Vector2) -> void:
	b.poly(&"road_marking", PackedVector3Array([Vector3(p0.x, MARK_Y, p0.y),
			Vector3(p1.x, MARK_Y, p1.y), Vector3(p2.x, MARK_Y, p2.y)]), Vector3.UP)
