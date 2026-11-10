@tool
class_name GardenFence
extends StaticBody3D
## Wooden garden fence running along +X from the origin.
## Styles: picket (low, front gardens) or boards (tall, between back gardens).

@export var length: float = 6.0:
	set(v): length = v; _queue_rebuild()
@export_enum("picket", "boards") var style: String = "boards":
	set(v): style = v; _queue_rebuild()
@export var height: float = 1.8:
	set(v): height = v; _queue_rebuild()
@export var tint: Color = Color(0.85, 0.8, 0.72):
	set(v): tint = v; _apply_tint()

var _generated: Array[Node] = []
var _mesh_instance: MeshInstance3D
var _pending: bool = false


func _ready() -> void:
	_rebuild()


func _queue_rebuild() -> void:
	if not is_inside_tree() or _pending:
		return
	_pending = true
	_rebuild.call_deferred()


func _apply_tint() -> void:
	if _mesh_instance:
		_mesh_instance.set_instance_shader_parameter(&"wall_tint", tint)


func _rebuild() -> void:
	_pending = false
	for n: Node in _generated:
		n.queue_free()
	_generated.clear()
	var b := MeshBuilder.new()
	var posts: int = maxi(1, ceili(length / 2.0))
	var step: float = length / posts
	for i: int in posts + 1:
		b.box(&"planks", Vector3(i * step, height / 2.0, 0), Vector3(0.09, height + 0.05, 0.09), 0.01)
	if style == "picket":
		b.box(&"planks", Vector3(length / 2.0, height * 0.3, 0.06), Vector3(length, 0.07, 0.03), 0.005)
		b.box(&"planks", Vector3(length / 2.0, height * 0.75, 0.06), Vector3(length, 0.07, 0.03), 0.005)
		var x: float = 0.06
		while x < length - 0.04:
			b.box(&"planks", Vector3(x, height * 0.47, 0.085), Vector3(0.07, height * 0.94, 0.02), 0.005)
			x += 0.13
	else:
		var x: float = 0.0
		while x < length - 0.01:
			var w: float = minf(0.145, length - x)
			b.box(&"planks", Vector3(x + w / 2.0, height / 2.0, 0.06), Vector3(w - 0.008, height - 0.06, 0.022), 0.004)
			x += 0.15
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = b.build()
	add_child(_mesh_instance)
	_generated.append(_mesh_instance)
	_apply_tint()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(length, height, 0.15)
	cs.shape = shape
	cs.position = Vector3(length / 2.0, height / 2.0, 0.04)
	add_child(cs)
	_generated.append(cs)
