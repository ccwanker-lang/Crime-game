@tool
class_name ProcBox
extends StaticBody3D
## Box with a project material and bevelled edges (counters, desks, canopies,
## planters...). Origin at the bottom centre.

@export var size: Vector3 = Vector3(1, 1, 1):
	set(v): size = v; _queue_rebuild()
## Material file name in res://prefabs/materials/ (e.g. "concrete", "planks").
@export var material_key: String = "concrete":
	set(v): material_key = v; _queue_rebuild()
@export var bevel: float = 0.02:
	set(v): bevel = v; _queue_rebuild()
@export var tint: Color = Color.WHITE:
	set(v): tint = v; _apply_tint()
@export var collision: bool = true:
	set(v): collision = v; _queue_rebuild()

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
		for p: StringName in [&"wall_tint", &"trim_tint", &"door_tint"]:
			_mesh_instance.set_instance_shader_parameter(p, tint)


func _rebuild() -> void:
	_pending = false
	for n: Node in _generated:
		n.queue_free()
	_generated.clear()
	var b := MeshBuilder.new()
	b.box(StringName(material_key), Vector3(0, size.y / 2.0, 0), size, bevel)
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = b.build()
	add_child(_mesh_instance)
	_generated.append(_mesh_instance)
	_apply_tint()
	if collision:
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		cs.shape = shape
		cs.position.y = size.y / 2.0
		add_child(cs)
		_generated.append(cs)
