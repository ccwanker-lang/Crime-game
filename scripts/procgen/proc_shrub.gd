@tool
class_name ProcShrub
extends StaticBody3D
## Point 27 art direction: a stylized shrub, 2-4 faceted blobs in palette greens (replaces
## the Poly Haven shrub models). Origin at the bottom centre.

@export var shrub_seed: int = 1:
	set(v): shrub_seed = v; _queue_rebuild()
@export var size: Vector3 = Vector3(1.2, 1.0, 1.2):
	set(v): size = v; _queue_rebuild()
## Palette swatches dark -> light (e.g. end with accent_yellow for a flowering shrub).
@export var swatches: PackedStringArray = PackedStringArray(["leaf_dark", "leaf", "leaf_light"]):
	set(v): swatches = v; _queue_rebuild()
## Solid (players and NPCs walk around it; the navmesh bakes it). Off for small plants.
@export var collide: bool = true:
	set(v): collide = v; _queue_rebuild()

var _generated: Array[Node] = []
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
	for n: Node in _generated:
		n.queue_free()
	_generated.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = shrub_seed
	var b := MeshBuilder.new()
	var cols: Array[Color] = ArtStyle.colors(Array(swatches))
	var r: Vector3 = size * 0.5
	b.blob(&"leaves", Vector3(0, r.y * 0.9, 0), 1.0, r, rng, cols, 0.12, 1, -0.5)
	for i: int in rng.randi_range(1, 3):
		var a: float = rng.randf() * TAU
		var c := Vector3(cos(a) * r.x * 0.5, r.y * rng.randf_range(0.55, 0.8), sin(a) * r.z * 0.5)
		b.blob(&"leaves", c, 1.0, r * rng.randf_range(0.55, 0.7), rng, cols, 0.12, 1, -0.4)
	var mi := MeshInstance3D.new()
	mi.mesh = b.build()
	add_child(mi)
	_generated.append(mi)
	if not collide:
		return
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = maxf(r.x, r.z) * 0.8
	shape.height = size.y
	cs.shape = shape
	cs.position.y = size.y / 2.0
	add_child(cs)
	_generated.append(cs)
