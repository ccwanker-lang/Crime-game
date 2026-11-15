@tool
class_name ArmyTruck
extends StaticBody3D
## Map zone 2 (the army base): a parked army vehicle - a canvas-backed truck or a small jeep, olive drab. Origin on
## the ground at the middle of the vehicle, the nose towards -Z. Box collision (layer 1). Not drivable (yet).

@export_enum("truck", "jeep") var kind: String = "truck":
	set(v): kind = v; _queue_rebuild()
@export var tint: Color = Color(0.36, 0.4, 0.27):
	set(v): tint = v; _queue_rebuild()

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
	var truck: bool = kind == "truck"
	var length: float = 7.2 if truck else 3.9
	var width: float = 2.4 if truck else 1.8
	var wheel_r: float = 0.55 if truck else 0.4
	var hl: float = length / 2.0
	b.color = Color(0.12, 0.12, 0.12)
	var axles: Array[float] = [-hl + 0.75, hl - 0.75]
	if truck:
		axles = [-hl + 1.2, hl - 1.4, hl - 2.6]
	for az: float in axles:
		for sx: float in [-1.0, 1.0]:
			var x: float = sx * (width / 2.0 - 0.15)
			b.cylinder(&"car_tire", Vector3(x - 0.18, wheel_r, az), Vector3(x + 0.18, wheel_r, az), wheel_r, wheel_r, 12)
	b.color = tint.darkened(0.3)
	b.box(&"item_metal", Vector3(0, wheel_r + 0.2, 0), Vector3(width - 0.4, 0.3, length - 0.4))
	b.color = tint
	if truck:
		# Cab at the front, canvas-covered bed behind.
		b.box(&"item_matte", Vector3(0, wheel_r + 1.15, -hl + 1.1), Vector3(width, 1.6, 2.2), 0.08)
		b.color = Color.WHITE
		b.box(&"car_glass", Vector3(0, wheel_r + 1.5, -hl - 0.01), Vector3(width - 0.4, 0.6, 0.04))
		b.color = tint.darkened(0.1)
		b.box(&"item_matte", Vector3(0, wheel_r + 0.65, 1.0), Vector3(width, 0.6, length - 2.4))
		b.color = Color(0.45, 0.47, 0.33)
		b.box(&"string", Vector3(0, wheel_r + 1.75, 1.0), Vector3(width - 0.05, 1.6, length - 2.5), 0.25)
	else:
		b.box(&"item_matte", Vector3(0, wheel_r + 0.6, 0), Vector3(width, 0.75, length), 0.08)
		b.color = Color.WHITE
		b.box(&"car_glass", Vector3(0, wheel_r + 1.2, -0.5), Vector3(width - 0.2, 0.5, 0.05))
		b.color = Color(0.2, 0.2, 0.2)
		b.box(&"item_metal", Vector3(0, wheel_r + 1.45, 0.2), Vector3(width - 0.1, 0.06, 1.6))
	# A white star on the side.
	b.color = Color(0.9, 0.9, 0.85)
	b.box(&"item_matte", Vector3(width / 2.0 + 0.01, wheel_r + 0.8, 0.2 if truck else 0.4), Vector3(0.02, 0.4, 0.4))
	b.box(&"item_matte", Vector3(-width / 2.0 - 0.01, wheel_r + 0.8, 0.2 if truck else 0.4), Vector3(0.02, 0.4, 0.4))
	var mi := MeshInstance3D.new()
	mi.mesh = b.build()
	add_child(mi)
	_generated.append(mi)
	var h: float = wheel_r + (2.6 if truck else 1.5)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, h, length)
	cs.shape = shape
	cs.position = Vector3(0, h / 2.0, 0)
	add_child(cs)
	_generated.append(cs)
