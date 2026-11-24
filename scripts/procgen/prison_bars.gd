@tool
class_name PrisonBars
extends StaticBody3D
## Point 93: a fixed barred grille (cell fronts, windows, the canteen hatch) - vertical bars every `spacing` m and
## three cross bars, one thin collision box (bullets and players stop, you can look through). Origin = the left
## edge of the grille at its bottom; the bars run along +X, like a CellDoor.

@export var width: float = 2.0:
	set(v): width = v; _queue_rebuild()
@export var height: float = 2.6:
	set(v): height = v; _queue_rebuild()
@export var spacing: float = 0.14:
	set(v): spacing = v; _queue_rebuild()

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
	var b := MeshBuilder.new()
	b.color = Color(0.32, 0.34, 0.37)
	var bars: int = maxi(2, int(width / maxf(spacing, 0.05)))
	for i: int in bars + 1:
		var x: float = 0.03 + i * (width - 0.06) / bars
		b.box(&"item_metal", Vector3(x, height / 2.0, 0.0), Vector3(0.035, height, 0.035))
	for y: float in [0.05, height * 0.45, height - 0.05]:
		b.box(&"item_metal", Vector3(width / 2.0, y, 0.0), Vector3(width, 0.06, 0.06))
	var mi := MeshInstance3D.new()
	mi.mesh = b.build()
	add_child(mi)
	_generated.append(mi)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, height, 0.08)
	cs.shape = shape
	cs.position = Vector3(width / 2.0, height / 2.0, 0.0)
	add_child(cs)
	_generated.append(cs)
