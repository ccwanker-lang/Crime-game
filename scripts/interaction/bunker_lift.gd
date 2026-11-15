@tool
class_name BunkerLift
extends NetDoor
## Map zone 8: the bunker's vehicle lift - a steel platform (big enough for a car) between the entrance hall and the
## underground garage `drop` m below. A NetDoor: "open" = down. E on the platform or on a call panel
## (`BunkerLiftButton`) sends it to the other level; host authoritative, late-join state. Origin = the platform's
## top at the upper level, centred; the platform spans `width` (X) x `depth` (Z). A boom closes the hall side of the
## shaft while the platform is not up.

@export var depth: float = 9.0
@export var drop: float = 14.0
@export var travel_time: float = 7.0

const THICK: float = 0.3

var _gate: AnimatableBody3D


func _rebuild() -> void:
	_pending = false
	if _pivot:
		_pivot.queue_free()
	if _gate:
		_gate.queue_free()
	var body := AnimatableBody3D.new()
	body.collision_layer = 1 << (DOOR_LAYER - 1) | 1
	body.collision_mask = 0
	_pivot = body
	add_child(body)
	var b := MeshBuilder.new()
	b.color = Color(0.36, 0.37, 0.38)
	b.box(&"item_metal", Vector3(0, -THICK / 2.0, 0), Vector3(width, THICK, depth))
	b.color = Color(0.85, 0.65, 0.1)
	for sx: float in [-1.0, 1.0]:
		b.box(&"item_matte", Vector3(sx * (width / 2.0 - 0.2), 0.005, 0), Vector3(0.25, 0.01, depth - 0.2))
	for sz: float in [-1.0, 1.0]:
		b.box(&"item_matte", Vector3(0, 0.005, sz * (depth / 2.0 - 0.2)), Vector3(width - 0.2, 0.01, 0.25))
	b.color = Color(0.3, 0.31, 0.32)
	for i: int in int(depth):
		b.box(&"item_metal", Vector3(0, 0.01, -depth / 2.0 + 0.5 + i), Vector3(width - 0.8, 0.02, 0.06))
	_mesh = MeshInstance3D.new()
	_mesh.mesh = b.build()
	body.add_child(_mesh)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, THICK, depth)
	cs.shape = shape
	cs.position = Vector3(0, -THICK / 2.0, 0)
	body.add_child(cs)
	_pivot.position.y = -drop if is_open else 0.0
	# The boom on the hall side (-Z edge): down (blocking) while the platform is away.
	_gate = AnimatableBody3D.new()
	_gate.collision_layer = 1 << (DOOR_LAYER - 1) | 1
	_gate.collision_mask = 0
	add_child(_gate)
	var g := MeshBuilder.new()
	g.color = Color(0.85, 0.12, 0.1)
	g.box(&"trim_paint", Vector3(0, 1.0, -depth / 2.0 - 0.15), Vector3(width, 0.18, 0.12))
	var gm := MeshInstance3D.new()
	gm.mesh = g.build()
	_gate.add_child(gm)
	var gcs := CollisionShape3D.new()
	var gshape := BoxShape3D.new()
	gshape.size = Vector3(width, 1.1, 0.15)
	gcs.shape = gshape
	gcs.position = Vector3(0, 0.55, -depth / 2.0 - 0.15)
	_gate.add_child(gcs)
	_set_gate(is_open, true)


func _set_gate(blocking: bool, instant: bool) -> void:
	if _gate == null:
		return
	var y: float = 0.0 if blocking else 2.6
	if instant:
		_gate.position.y = y
	else:
		create_tween().tween_property(_gate, "position:y", y, 0.8)


func set_color(_c: Color) -> void:
	pass


func get_interaction_prompt() -> String:
	return "Bring the lift up" if is_open else "Send the lift down"


func is_up() -> bool:
	return not is_open and _pivot != null and absf(_pivot.position.y) < 0.01


func is_down() -> bool:
	return is_open and _pivot != null and absf(_pivot.position.y + drop) < 0.01


@rpc("authority", "call_local", "reliable")
func _set_open(open: bool) -> void:
	is_open = open
	if _tween:
		_tween.kill()
	if open:
		_set_gate(true, false)
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_pivot, "position:y", -drop if open else 0.0, travel_time)
	if not open:
		_tween.tween_callback(_set_gate.bind(false, false))


func apply_net_state(state: Dictionary) -> void:
	is_open = state.get("open", false)
	if _pivot:
		_pivot.position.y = -drop if is_open else 0.0
	_set_gate(is_open, true)
