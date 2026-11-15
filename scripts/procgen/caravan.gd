@tool
class_name Caravan
extends StaticBody3D
## Map zone 3 (the slums): an old caravan / mobile home on blocks. Origin = the middle of its footprint on the
## ground, the long side along X, the door side faces -Z. Box collision (layer 1).

@export var length: float = 7.0:
	set(v): length = v; _queue_rebuild()
@export var body_color: Color = Color(0.9, 0.88, 0.8):
	set(v): body_color = v; _queue_rebuild()
@export var stripe_color: Color = Color(0.55, 0.3, 0.2):
	set(v): stripe_color = v; _queue_rebuild()
@export var awning: bool = false:
	set(v): awning = v; _queue_rebuild()
@export var rust: float = 0.3:
	set(v): rust = v; _queue_rebuild()
@export var caravan_seed: int = 1:
	set(v): caravan_seed = v; _queue_rebuild()

const W: float = 2.4
const H: float = 2.3
const LIFT: float = 0.55

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
	rng.seed = caravan_seed
	var b := MeshBuilder.new()
	var hl: float = length / 2.0
	var body: Color = body_color.lerp(Color(0.55, 0.42, 0.3), rust * 0.5)
	b.color = body
	b.box(&"item_matte", Vector3(0, LIFT + H / 2.0, 0), Vector3(length, H, W), 0.12)
	# Roof: a slightly rounded cap.
	b.color = body.darkened(0.08)
	b.box(&"item_matte", Vector3(0, LIFT + H + 0.06, 0), Vector3(length - 0.15, 0.14, W - 0.15), 0.06)
	# Stripe along both long sides.
	b.color = stripe_color.lerp(Color(0.4, 0.3, 0.25), rust * 0.4)
	for z: float in [-W / 2.0 - 0.01, W / 2.0 + 0.01]:
		b.box(&"item_matte", Vector3(0, LIFT + H * 0.42, z), Vector3(length - 0.1, 0.22, 0.02))
	# Windows (front side + back side + ends) and the door on the -Z side.
	b.color = Color.WHITE
	var door_x: float = rng.randf_range(-hl + 1.2, hl - 1.2)
	var x: float = -hl + 1.0
	while x < hl - 0.8:
		if absf(x - door_x) > 1.0:
			b.box(&"glass_interior", Vector3(x, LIFT + H * 0.66, -W / 2.0 - 0.02), Vector3(0.9, 0.6, 0.03))
		b.box(&"glass_interior", Vector3(x, LIFT + H * 0.66, W / 2.0 + 0.02), Vector3(0.9, 0.6, 0.03))
		x += rng.randf_range(1.6, 2.2)
	for ex: float in [-hl - 0.02, hl + 0.02]:
		b.box(&"glass_interior", Vector3(ex, LIFT + H * 0.66, 0), Vector3(0.03, 0.55, 1.1))
	b.color = body.darkened(0.3)
	b.box(&"door_paint", Vector3(door_x, LIFT + 0.95, -W / 2.0 - 0.02), Vector3(0.75, 1.85, 0.04))
	# Step + blocks + wheels + the tow bar.
	b.color = Color(0.5, 0.5, 0.48)
	b.box(&"concrete", Vector3(door_x, 0.2, -W / 2.0 - 0.45), Vector3(0.8, 0.4, 0.6))
	for bx: float in [-hl + 0.8, hl - 0.8]:
		for bz: float in [-W / 2.0 + 0.4, W / 2.0 - 0.4]:
			b.box(&"concrete", Vector3(bx, LIFT / 2.0, bz), Vector3(0.4, LIFT, 0.4))
	b.color = Color(0.12, 0.12, 0.12)
	for wz: float in [-W / 2.0 + 0.15, W / 2.0 - 0.15]:
		b.cylinder(&"car_tire", Vector3(0, 0.38, wz - 0.12), Vector3(0, 0.38, wz + 0.12), 0.36, 0.36, 10)
	b.color = Color(0.3, 0.3, 0.3)
	b.box(&"item_metal", Vector3(-hl - 0.6, 0.45, 0), Vector3(1.2, 0.08, 0.08))
	if awning:
		b.color = Color(0.25, 0.45, 0.35).lerp(Color(0.6, 0.3, 0.2), rng.randf())
		b.box(&"awning", Vector3(door_x, LIFT + H - 0.15, -W / 2.0 - 1.1), Vector3(3.0, 0.06, 2.2))
		b.color = Color(0.6, 0.6, 0.6)
		for ax: float in [door_x - 1.4, door_x + 1.4]:
			b.cylinder(&"item_metal", Vector3(ax, 0, -W / 2.0 - 2.1), Vector3(ax, LIFT + H - 0.15, -W / 2.0 - 2.1), 0.03, 0.03, 5)
	var mi := MeshInstance3D.new()
	mi.mesh = b.build()
	add_child(mi)
	_generated.append(mi)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(length, H + LIFT, W)
	cs.shape = shape
	cs.position = Vector3(0, (H + LIFT) / 2.0, 0)
	add_child(cs)
	_generated.append(cs)
