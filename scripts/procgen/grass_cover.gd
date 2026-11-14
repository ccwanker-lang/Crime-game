class_name GrassCover
extends Node3D
## Point 61: grass tufts on EVERY green plane, built in chunks round the camera (local, every peer with a screen).
## A spot gets a tuft when a ray straight down hits a `GroundArea` (with `grass` on) at ground height first:
## roads, pavements, paths, soil fields, buildings and props all stop the ray, so they stay bare by themselves.
## Hand-placed `GrassField`s (gardens, the park) keep their own grass; the cover skips their rectangles. Road tiles
## are skipped as squares too (their asphalt lies at the same height as the ground, so the ray can't tell).

const CHUNK: float = 10.0
## Chunks within this distance of the camera exist; tufts fade out before it.
const RADIUS: float = 52.0
const FADE_END: float = 45.0
## Tufts per square metre (the stylized GrassField uses 14 x 0.3).
const DENSITY: float = 4.2
## Chunks built per frame (each = up to ~420 rays).
const BUILD_PER_FRAME: int = 2

var _chunks: Dictionary = {}  # Vector2i -> MultiMeshInstance3D (or null = no grass in it)
var _skip: Array[Rect2] = []  # world-space rects of GrassFields
var _material: Material
var _ready_done: bool = false


func _ready() -> void:
	name = "GrassCover"
	_material = load("res://prefabs/materials/grass_blades.tres")
	_collect_fields.call_deferred()


func _collect_fields() -> void:
	_skip = field_rects(get_tree())
	_ready_done = true


## World-space rectangles without cover grass: every GrassField (first), then every RoadTile square (both axis
## aligned: the generator never rotates fields, tiles only in 90 degree steps).
static func field_rects(tree: SceneTree) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var root: Node = tree.current_scene
	if root == null:
		return out
	for n: Node in root.find_children("*", "GrassField", true, false):
		var g := n as GrassField
		var c: Vector3 = g.global_position
		out.append(Rect2(c.x - g.size.x / 2.0, c.z - g.size.y / 2.0, g.size.x, g.size.y))
	for n: Node in root.find_children("*", "RoadTile", true, false):
		var t: Vector3 = (n as Node3D).global_position
		out.append(Rect2(t.x - RoadTile.HALF, t.z - RoadTile.HALF, RoadTile.TILE, RoadTile.TILE))
	return out


func _process(_delta: float) -> void:
	if not _ready_done:
		return
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	var at := Vector2(cam.global_position.x, cam.global_position.z)
	if cam.global_position.y > 60.0:
		at = Vector2(INF, INF)  # far above (screenshot top views): no grass
	# Drop chunks that are out of range.
	for key: Vector2i in _chunks.keys():
		if _chunk_centre(key).distance_to(at) > RADIUS + CHUNK:
			var mmi: Node = _chunks[key]
			if mmi:
				mmi.queue_free()
			_chunks.erase(key)
	if at.x == INF:
		return
	# Build the nearest missing chunks first.
	var r: int = ceili(RADIUS / CHUNK)
	var c0 := Vector2i(floori(at.x / CHUNK), floori(at.y / CHUNK))
	var todo: Array = []
	for ix: int in range(-r, r + 1):
		for iz: int in range(-r, r + 1):
			var key := c0 + Vector2i(ix, iz)
			if _chunks.has(key):
				continue
			var d: float = _chunk_centre(key).distance_to(at)
			if d <= RADIUS:
				todo.append([d, key])
	todo.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for i: int in mini(BUILD_PER_FRAME, todo.size()):
		var key: Vector2i = todo[i][1]
		_chunks[key] = _build(key)


func _chunk_centre(key: Vector2i) -> Vector2:
	return Vector2((key.x + 0.5) * CHUNK, (key.y + 0.5) * CHUNK)


func _build(key: Vector2i) -> MultiMeshInstance3D:
	var pts: PackedVector3Array = tuft_points(get_world_3d().direct_space_state, key, _skip)
	if pts.is_empty():
		return null
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key) + 61
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = GrassField._get_tuft_mesh() if ArtStyle.stylized else GrassField._get_clump_mesh()
	mm.instance_count = pts.size()
	for i: int in pts.size():
		var h: float = rng.randf_range(0.22, 0.42) * (0.42 if ArtStyle.stylized else 1.0)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(h * 2.6, h, h * 2.6))
		mm.set_instance_transform(i, Transform3D(b, pts[i]))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _material
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = FADE_END
	mmi.visibility_range_end_margin = 8.0
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(mmi)
	return mmi


## The tuft spots in chunk `key` (world space, y just under the ground top). Static so the self-test can run it
## headless. A jittered grid: deterministic per chunk.
static func tuft_points(space: PhysicsDirectSpaceState3D, key: Vector2i, skip: Array[Rect2] = []) -> PackedVector3Array:
	var out := PackedVector3Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var step: float = 1.0 / sqrt(DENSITY)
	var n: int = int(CHUNK / step)
	var x0: float = key.x * CHUNK
	var z0: float = key.y * CHUNK
	var area := Rect2(x0, z0, CHUNK, CHUNK)
	var near: Array[Rect2] = []
	for r: Rect2 in skip:
		if r.intersects(area):
			near.append(r)
	var q := PhysicsRayQueryParameters3D.new()
	q.collision_mask = 1
	for ix: int in n:
		for iz: int in n:
			var p := Vector2(x0 + (ix + rng.randf()) * step, z0 + (iz + rng.randf()) * step)
			var skipped: bool = false
			for r: Rect2 in near:
				if r.has_point(p):
					skipped = true
					break
			if skipped:
				continue
			q.from = Vector3(p.x, 2.0, p.y)
			q.to = Vector3(p.x, -0.5, p.y)
			var hit: Dictionary = space.intersect_ray(q)
			if hit.is_empty():
				continue
			var g := hit.collider as GroundArea
			if g == null or not g.grass or absf((hit.position as Vector3).y) > 0.08:
				continue
			out.append(Vector3(p.x, -0.03, p.y))
	return out
