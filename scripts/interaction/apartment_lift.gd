@tool
class_name ApartmentLift
extends BunkerLift
## Point 76: the lift of an enterable apartment block - the bunker's platform lift turned upside down: it rides
## `rise` m from the lobby up to the roof stair-house. "open" = at the roof. A boom closes the lobby side while the
## platform is up, a second one the roof side while it is down (nobody walks into the empty shaft).

@export var rise: float = 20.0

var _top_gate: AnimatableBody3D


func _rebuild() -> void:
	drop = -rise
	super._rebuild()
	if _top_gate:
		_top_gate.queue_free()
	_top_gate = AnimatableBody3D.new()
	_top_gate.collision_layer = 1 << (DOOR_LAYER - 1) | 1
	_top_gate.collision_mask = 0
	add_child(_top_gate)
	var g := MeshBuilder.new()
	g.color = Color(0.85, 0.12, 0.1)
	g.box(&"trim_paint", Vector3(0, 1.0, -depth / 2.0 - 0.15), Vector3(width, 0.18, 0.12))
	var gm := MeshInstance3D.new()
	gm.mesh = g.build()
	_top_gate.add_child(gm)
	var gcs := CollisionShape3D.new()
	var gshape := BoxShape3D.new()
	gshape.size = Vector3(width, 1.1, 0.15)
	gcs.shape = gshape
	gcs.position = Vector3(0, 0.55, -depth / 2.0 - 0.15)
	_top_gate.add_child(gcs)
	_set_top_gate(not is_open, true)


func _set_top_gate(blocking: bool, instant: bool) -> void:
	if _top_gate == null:
		return
	var y: float = rise + (0.0 if blocking else 2.6)
	if instant:
		_top_gate.position.y = y
	else:
		create_tween().tween_property(_top_gate, "position:y", y, 0.8)


func get_interaction_prompt() -> String:
	return "Ride down to the lobby" if is_open else "Ride up to the roof"


func at_roof() -> bool:
	return is_open and _pivot != null and absf(_pivot.position.y - rise) < 0.01


func at_lobby() -> bool:
	return not is_open and _pivot != null and absf(_pivot.position.y) < 0.01


@rpc("authority", "call_local", "reliable")
func _set_open(open: bool) -> void:
	is_open = open
	if _tween:
		_tween.kill()
	_set_gate(true, false)
	_set_top_gate(true, false)
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_pivot, "position:y", rise if open else 0.0, travel_time)
	_tween.tween_callback(_arrived)


func _arrived() -> void:
	_set_gate(is_open, false)
	_set_top_gate(not is_open, false)


func apply_net_state(state: Dictionary) -> void:
	is_open = state.get("open", false)
	if _pivot:
		_pivot.position.y = rise if is_open else 0.0
	_set_gate(is_open, true)
	_set_top_gate(not is_open, true)
