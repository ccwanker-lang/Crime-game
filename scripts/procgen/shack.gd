@tool
class_name Shack
extends StaticBody3D
## Map zone 3 (the slums): a shack of corrugated sheets and planks with a sloping roof, patch panels in odd
## colours, a door and a small window. Origin = the middle of the footprint on the ground; the door faces -Z.
## Not enterable (box collision, layer 1).

@export var size: Vector3 = Vector3(4.0, 2.4, 3.2):
	set(v): size = v; _queue_rebuild()
@export var shack_seed: int = 1:
	set(v): shack_seed = v; _queue_rebuild()

const PATCHES: Array[Color] = [Color(0.55, 0.32, 0.22), Color(0.3, 0.42, 0.55), Color(0.62, 0.6, 0.55),
		Color(0.4, 0.5, 0.32), Color(0.7, 0.55, 0.3), Color(0.5, 0.47, 0.42)]

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
	rng.seed = shack_seed
	var b := MeshBuilder.new()
	var h: Vector3 = size / 2.0
	var wood: bool = rng.randf() < 0.35
	b.color = Color(0.62, 0.6, 0.56) if not wood else Color(0.55, 0.42, 0.3)
	b.box(&"corrugated" if not wood else &"planks", Vector3(0, h.y, 0), size)
	# Patch panels on the walls.
	for i: int in rng.randi_range(2, 5):
		b.color = PATCHES[rng.randi() % PATCHES.size()]
		var side: int = rng.randi() % 4
		var pw: float = rng.randf_range(0.8, 1.6)
		var ph: float = rng.randf_range(0.7, 1.4)
		var py: float = rng.randf_range(0.4, size.y - ph / 2.0 - 0.1)
		match side:
			0: b.box(&"corrugated", Vector3(rng.randf_range(-h.x + pw / 2, h.x - pw / 2), py, -h.z - 0.03), Vector3(pw, ph, 0.04))
			1: b.box(&"corrugated", Vector3(h.x + 0.03, py, rng.randf_range(-h.z + pw / 2, h.z - pw / 2)), Vector3(0.04, ph, pw))
			2: b.box(&"corrugated", Vector3(rng.randf_range(-h.x + pw / 2, h.x - pw / 2), py, h.z + 0.03), Vector3(pw, ph, 0.04))
			_: b.box(&"corrugated", Vector3(-h.x - 0.03, py, rng.randf_range(-h.z + pw / 2, h.z - pw / 2)), Vector3(0.04, ph, pw))
	# Sloping roof (higher at the front), overhanging.
	var tilt: float = deg_to_rad(rng.randf_range(6.0, 12.0))
	b.xform = Transform3D(Basis(Vector3.RIGHT, -tilt), Vector3(0, size.y + 0.2, 0))
	b.color = Color(0.5, 0.48, 0.45).lerp(Color(0.55, 0.35, 0.22), rng.randf() * 0.6)
	b.box(&"corrugated", Vector3.ZERO, Vector3(size.x + 0.6, 0.06, size.z + 0.7))
	b.xform = Transform3D.IDENTITY
	# Door + window + a tyre or crate on the roof.
	b.color = PATCHES[rng.randi() % PATCHES.size()].darkened(0.2)
	var dx: float = rng.randf_range(-h.x + 0.7, h.x - 0.7)
	b.box(&"door_paint", Vector3(dx, 0.95, -h.z - 0.03), Vector3(0.85, 1.9, 0.05))
	b.color = Color.WHITE
	var wx: float = -dx * 0.8 if absf(dx) > 0.6 else h.x - 0.6
	b.box(&"glass_interior", Vector3(wx, 1.45, -h.z - 0.03), Vector3(0.7, 0.55, 0.04))
	if rng.randf() < 0.5:
		b.color = Color(0.1, 0.1, 0.1)
		var t := Vector3(rng.randf_range(-h.x + 0.6, h.x - 0.6), size.y + 0.45, rng.randf_range(-h.z + 0.6, h.z - 0.6))
		b.cylinder(&"car_tire", t - Vector3(0, 0.12, 0), t + Vector3(0, 0.12, 0), 0.38, 0.38, 10)
	var mi := MeshInstance3D.new()
	mi.mesh = b.build()
	add_child(mi)
	_generated.append(mi)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = Vector3(0, h.y, 0)
	add_child(cs)
	_generated.append(cs)
