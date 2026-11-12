@tool
class_name RollerShutter
extends StaticBody3D
## A closed roller shutter (garage door) on a facade: corrugated slats, a housing box on
## top and side rails. Origin = bottom centre, the front faces +Z. World collision layer.

@export var size: Vector2 = Vector2(4.0, 3.0):
	set(v): size = v; _queue_rebuild()

var _pending: bool = false
var _generated: Array[Node] = []


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
	var b := MeshBuilder.new()
	var hw: float = size.x * 0.5
	b.box(&"corrugated", Vector3(0, size.y * 0.5, 0.03), Vector3(size.x, size.y, 0.04))
	var y: float = 0.12
	while y < size.y - 0.05:
		b.box(&"metal_dark", Vector3(0, y, 0.055), Vector3(size.x - 0.04, 0.012, 0.01))
		y += 0.12
	b.box(&"metal_dark", Vector3(0, size.y + 0.15, 0.1), Vector3(size.x + 0.2, 0.3, 0.2), 0.01)  # housing
	for s: float in [-1.0, 1.0]:
		b.box(&"metal_dark", Vector3(s * (hw + 0.04), size.y * 0.5, 0.05), Vector3(0.08, size.y, 0.1))
	b.box(&"zinc", Vector3(0, 0.05, 0.07), Vector3(size.x - 0.1, 0.1, 0.04))  # bottom bar + handle
	var mi := MeshInstance3D.new()
	mi.mesh = b.build()
	add_child(mi)
	_generated.append(mi)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x + 0.2, size.y + 0.3, 0.2)
	cs.shape = shape
	cs.position = Vector3(0, (size.y + 0.3) * 0.5, 0.1)
	add_child(cs)
	_generated.append(cs)
