@tool
class_name ProcBackdrop
extends Node3D
## Point 27 art direction: hides the edge of the world. Around `area` (the playable map,
## XZ rectangle in this node's space) it puts a big grass plane, a row of simple stylized
## trees, low hedge-like bushes and two rings of soft faceted hills further out, so the
## horizon is green hills and treetops instead of an empty plane. No collision (out of
## reach), no shadows from the far hills.

@export var area: Rect2 = Rect2(-80, -60, 160, 130):
	set(v): area = v; _queue_rebuild()
## Distance of the tree row outside the area (m).
@export var tree_margin: float = 10.0:
	set(v): tree_margin = v; _queue_rebuild()
## Distance of the first ring of hills (m).
@export var hill_distance: float = 55.0:
	set(v): hill_distance = v; _queue_rebuild()
@export var backdrop_seed: int = 1:
	set(v): backdrop_seed = v; _queue_rebuild()
@export var ground_plane: bool = true:
	set(v): ground_plane = v; _queue_rebuild()
## Point 47: no trees or hills inside these world rects (xz) - where another backdrop or the sea takes over.
@export var skip_rects: Array[Rect2] = []:
	set(v): skip_rects = v; _queue_rebuild()

var _generated: Array[Node] = []
var _pending: bool = false


func _ready() -> void:
	_rebuild()


func _queue_rebuild() -> void:
	if not is_inside_tree() or _pending:
		return
	_pending = true
	_rebuild.call_deferred()


## Points every `step` metres along the rectangle `r` (clockwise), with the outward normal.
static func _ring(r: Rect2, step: float) -> Array:
	var out: Array = []
	var corners: Array[Vector2] = [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	var normals: Array[Vector2] = [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]
	for i: int in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var n: int = maxi(1, int(a.distance_to(b) / step))
		for k: int in n:
			out.append([a.lerp(b, (float(k) + 0.5) / n), normals[i]])
	return out


func _rebuild() -> void:
	_pending = false
	for n: Node in _generated:
		n.queue_free()
	_generated.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = backdrop_seed
	var near := MeshBuilder.new()
	var far := MeshBuilder.new()
	var greens: Array[Color] = ArtStyle.colors(["leaf_dark", "leaf", "leaf_light"])
	var hill_cols: Array[Color] = ArtStyle.colors(["grass_dark", "grass", "hill"])
	var far_cols: Array[Color] = ArtStyle.colors(["hill", "hill", "grass_light"])
	if ground_plane:
		var g: Rect2 = area.grow(hill_distance + 220.0)
		near.poly(&"ground", PackedVector3Array([Vector3(g.position.x, -0.05, g.position.y), Vector3(g.end.x, -0.05, g.position.y),
				Vector3(g.end.x, -0.05, g.end.y), Vector3(g.position.x, -0.05, g.end.y)]), Vector3.UP)
	# Tree row with bushes in between.
	for p: Array in _ring(area.grow(tree_margin), 7.5):
		var at: Vector2 = p[0] + (p[1] as Vector2) * rng.randf_range(-2.0, 2.5)
		var h: float = rng.randf_range(6.0, 9.5)
		var cr: float = rng.randf_range(2.2, 3.4)
		if _skipped(at):
			continue
		var base := Vector3(at.x, 0, at.y)
		near.cylinder(&"bark", base, base + Vector3(0, h * 0.5, 0), 0.22, 0.14, 6, false, 1.0)
		near.blob(&"leaves", base + Vector3(0, h - cr * 0.8, 0), 1.0, Vector3(cr, cr * 0.9, cr), rng, greens, 0.12)
		if rng.randf() < 0.6:
			near.blob(&"leaves", base + Vector3(rng.randf_range(-1.5, 1.5), h - cr * 1.3, rng.randf_range(-1.5, 1.5)), 1.0,
					Vector3(cr, cr, cr) * 0.7, rng, greens, 0.12)
		var bush: Vector2 = at + Vector2(-(p[1] as Vector2).y, (p[1] as Vector2).x) * 3.7
		near.blob(&"leaves", Vector3(bush.x, 0.5, bush.y), 1.0, Vector3(1.8, 1.0, 1.8), rng, greens, 0.15, 1, -0.5)
	# Two rings of hills: near ones in grass greens, far ones paler (plus the haze).
	for ring: int in 2:
		var dist: float = hill_distance + ring * 70.0
		for p: Array in _ring(area.grow(dist), 38.0 + ring * 20.0):
			var at: Vector2 = p[0] + (p[1] as Vector2) * rng.randf_range(0.0, 25.0)
			var r: float = rng.randf_range(24.0, 40.0) * (1.0 + ring * 0.5)
			var sc := Vector3(rng.randf_range(0.9, 1.3), rng.randf_range(0.28, 0.5), rng.randf_range(0.7, 1.0))
			var bm: MeshBuilder = near if ring == 0 else far
			if _skipped(at):
				continue
			bm.blob(&"leaves", Vector3(at.x, -r * sc.y * 0.35, at.y), r, sc, rng, hill_cols if ring == 0 else far_cols, 0.06, 2, -0.4)
			# A few clumps of trees on the near hills.
			if ring == 0 and rng.randf() < 0.7:
				for k: int in rng.randi_range(2, 4):
					var off := Vector2(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.4, 0.4)) * r
					var top: float = r * sc.y * 0.6 * (1.0 - off.length() / r)
					var tc: float = rng.randf_range(2.5, 4.0)
					near.blob(&"leaves", Vector3(at.x + off.x, maxf(top, 0.0) + tc * 0.8, at.y + off.y), 1.0, Vector3(tc, tc * 1.1, tc),
							rng, greens, 0.12)
	for bm: MeshBuilder in [near, far]:
		if not bm.has_geometry():
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = bm.build()
		if bm == far:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_generated.append(mi)


func _skipped(at: Vector2) -> bool:
	for r: Rect2 in skip_rects:
		if r.has_point(at):
			return true
	return false
