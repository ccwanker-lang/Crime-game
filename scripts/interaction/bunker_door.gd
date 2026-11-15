@tool
class_name BunkerDoor
extends NetDoor
## Map zone 8: the bunker's blast door - a heavy steel slab that slides aside (along +X) in front of the portal face.
## A NetDoor (E, host authoritative, late-join state). `locked` (host-owned, synced in the net state) is for session
## B's buying logic: a locked door does not open. Origin = the left edge of the opening at floor height; the slab
## sits on the -Z (outer) side of the face.

@export var thickness: float = 0.35

var locked: bool = false


func _rebuild() -> void:
	_pending = false
	if _pivot:
		_pivot.queue_free()
	var body := AnimatableBody3D.new()
	body.collision_layer = 1 << (DOOR_LAYER - 1) | 1  # also layer 1: cars + the walker checks stop at it
	body.collision_mask = 0
	_pivot = body
	add_child(body)
	var b := MeshBuilder.new()
	var t: float = thickness
	b.color = Color(0.32, 0.36, 0.3)
	b.box(&"metal_dark", Vector3(width / 2.0, height / 2.0, -t / 2.0 - 0.05), Vector3(width, height, t))
	# Ribs, rivet strips and hazard stripes at the foot.
	b.color = Color(0.27, 0.3, 0.25)
	for i: int in 5:
		b.box(&"metal_dark", Vector3(0.4 + i * (width - 0.8) / 4.0, height / 2.0, -t - 0.1), Vector3(0.18, height - 0.3, 0.1))
	b.box(&"metal_dark", Vector3(width / 2.0, height * 0.5, -t - 0.1), Vector3(width - 0.3, 0.2, 0.1))
	b.color = Color(0.85, 0.65, 0.1)
	for i: int in 7:
		b.box(&"item_matte", Vector3(0.45 + i * (width - 0.9) / 6.0, 0.3, -t - 0.07), Vector3(0.5, 0.3, 0.04))
	b.color = Color(0.2, 0.2, 0.2)
	b.box(&"item_metal", Vector3(width - 0.5, 1.2, -t - 0.15), Vector3(0.12, 0.6, 0.12))
	_mesh = MeshInstance3D.new()
	_mesh.mesh = b.build()
	body.add_child(_mesh)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, height, t)
	cs.shape = shape
	cs.position = Vector3(width / 2.0, height / 2.0, -t / 2.0 - 0.05)
	body.add_child(cs)
	_pivot.position.x = width if is_open else 0.0


func set_color(_c: Color) -> void:
	pass


func get_interaction_prompt() -> String:
	if locked and not is_open:
		return "The blast door is locked"
	return "Close the blast door" if is_open else "Open the blast door"


func _server_toggle() -> void:
	if locked and not is_open:
		return
	super._server_toggle()


## Host: lock / unlock (B's buying logic). Locking also shuts it.
func host_set_locked(on: bool) -> void:
	locked = on
	_set_locked.rpc(on)
	if on and is_open:
		_set_open.rpc(false)


@rpc("authority", "call_remote", "reliable")
func _set_locked(on: bool) -> void:
	locked = on


@rpc("authority", "call_local", "reliable")
func _set_open(open: bool) -> void:
	is_open = open
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_pivot, "position:x", width if open else 0.0, 2.5)


func get_net_state() -> Dictionary:
	return {"open": is_open, "locked": locked}


func apply_net_state(state: Dictionary) -> void:
	is_open = state.get("open", false)
	locked = state.get("locked", false)
	if _pivot:
		_pivot.position.x = width if is_open else 0.0
