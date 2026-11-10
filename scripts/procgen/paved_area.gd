@tool
class_name PavedArea
extends StaticBody3D
## Rectangular paved surface (plaza, alley, parking, yard). Centred on the node.
## height 0.15 = same level as sidewalks; 0.0 = level with the road.

@export var size: Vector2 = Vector2(10, 10):
	set(v): size = v; _queue_rebuild()
@export_enum("cobbles", "sidewalk", "asphalt", "concrete", "soil") var surface: String = "cobbles":
	set(v): surface = v; _queue_rebuild()
@export var height: float = 0.15:
	set(v): height = v; _queue_rebuild()
## Draw a concrete edge around it.
@export var edge: bool = true:
	set(v): edge = v; _queue_rebuild()

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
	var hx: float = size.x / 2.0
	var hz: float = size.y / 2.0
	var outline := PackedVector2Array([Vector2(-hx, -hz), Vector2(hx, -hz), Vector2(hx, hz), Vector2(-hx, hz)])
	b.slab(StringName(surface), &"curb", outline, height, -0.05)
	if edge:
		var y: float = height + 0.004
		var w: float = 0.15
		b.quad(&"curb", Vector3(-hx, y, -hz), Vector3(hx, y, -hz), Vector3(hx, y, -hz + w), Vector3(-hx, y, -hz + w), Vector3.UP)
		b.quad(&"curb", Vector3(-hx, y, hz - w), Vector3(hx, y, hz - w), Vector3(hx, y, hz), Vector3(-hx, y, hz), Vector3.UP)
		b.quad(&"curb", Vector3(-hx, y, -hz + w), Vector3(-hx + w, y, -hz + w), Vector3(-hx + w, y, hz - w), Vector3(-hx, y, hz - w), Vector3.UP)
		b.quad(&"curb", Vector3(hx - w, y, -hz + w), Vector3(hx, y, -hz + w), Vector3(hx, y, hz - w), Vector3(hx - w, y, hz - w), Vector3.UP)
	var mi := MeshInstance3D.new()
	mi.mesh = b.build()
	add_child(mi)
	_generated.append(mi)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x, height + 0.05, size.y)
	cs.shape = shape
	cs.position.y = (height - 0.05) / 2.0
	add_child(cs)
	_generated.append(cs)
