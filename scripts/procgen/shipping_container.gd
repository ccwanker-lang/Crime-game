@tool
class_name ShippingContainer
extends StaticBody3D
## ISO shipping container (6 m or 12 m) with corrugated walls, corner posts and
## doors with locking bars at the +X end. Origin at the bottom centre.

@export_enum("6m", "12m") var length_type: String = "6m":
	set(v): length_type = v; _queue_rebuild()
@export var color: Color = Color(0.15, 0.3, 0.55):
	set(v): color = v; _apply_tint()

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
		_mesh_instance.set_instance_shader_parameter(&"wall_tint", color)
		_mesh_instance.set_instance_shader_parameter(&"trim_tint", color * 0.8)


func _rebuild() -> void:
	_pending = false
	for n: Node in _generated:
		n.queue_free()
	_generated.clear()
	var L: float = 6.06 if length_type == "6m" else 12.19
	var W: float = 2.44
	var H: float = 2.59
	var b := MeshBuilder.new()
	var p: float = 0.12
	# Corrugated body (slightly inset) and frame.
	b.box(&"corrugated", Vector3(0, H / 2.0, 0), Vector3(L - p, H - p, W - 0.04))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			b.box(&"trim_paint", Vector3(sx * (L / 2.0 - p / 2.0), H / 2.0, sz * (W / 2.0 - p / 2.0)), Vector3(p, H, p), 0.01)
	for y: float in [p / 2.0, H - p / 2.0]:
		for sz: float in [-1.0, 1.0]:
			b.box(&"trim_paint", Vector3(0, y, sz * (W / 2.0 - p / 2.0)), Vector3(L, p, p), 0.01)
		for sx: float in [-1.0, 1.0]:
			b.box(&"trim_paint", Vector3(sx * (L / 2.0 - p / 2.0), y, 0), Vector3(p, p, W), 0.01)
	# Door locking bars.
	for z: float in [-0.75, -0.35, 0.35, 0.75]:
		b.cylinder(&"zinc", Vector3(L / 2.0 + 0.02, 0.15, z), Vector3(L / 2.0 + 0.02, H - 0.15, z), 0.022, 0.022, 6)
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = b.build()
	add_child(_mesh_instance)
	_generated.append(_mesh_instance)
	_apply_tint()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(L, H, W)
	cs.shape = shape
	cs.position.y = H / 2.0
	add_child(cs)
	_generated.append(cs)
