@tool
class_name CellDoor
extends HiddenShelfDoor
## Point 49: a barred prison cell door that slides aside (along +X). Locked until the guard opens it
## (Intro.host_open_cell -> `host_unlock`); after that it works like any NetDoor (E, host authoritative,
## late-join state). Origin = the left edge of the opening at floor height.


var locked: bool = true


func _rebuild() -> void:
	_pending = false
	if _pivot:
		_pivot.queue_free()
	var body := AnimatableBody3D.new()
	body.collision_layer = 1 << (DOOR_LAYER - 1)
	body.collision_mask = 0
	_pivot = body
	add_child(body)
	var b := MeshBuilder.new()
	b.color = Color(0.32, 0.34, 0.37)
	var bars: int = maxi(3, int(width / 0.14))
	for i: int in bars + 1:
		var x: float = 0.04 + i * (width - 0.08) / bars
		b.box(&"item_metal", Vector3(x, height / 2.0, -0.03), Vector3(0.035, height, 0.035))
	for y: float in [0.06, height * 0.45, height - 0.06]:
		b.box(&"item_metal", Vector3(width / 2.0, y, -0.03), Vector3(width, 0.06, 0.06))
	_mesh = MeshInstance3D.new()
	_mesh.mesh = b.build()
	body.add_child(_mesh)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, height, 0.08)
	cs.shape = shape
	cs.position = Vector3(width / 2.0, height / 2.0, -0.03)
	body.add_child(cs)
	_pivot.position.x = width if is_open else 0.0


func get_interaction_prompt() -> String:
	if locked:
		return "Cell door (locked - wait for the guard)"
	return "Slide the cell door shut" if is_open else "Slide the cell door open"


func interact() -> void:
	if locked:
		return
	super.interact()


## Host: unlock and slide open (every peer).
func host_unlock() -> void:
	if not multiplayer.is_server():
		return
	_set_locked.rpc(false)
	if not is_open:
		_set_open.rpc(true)


@rpc("authority", "call_local", "reliable")
func _set_locked(on: bool) -> void:
	locked = on


func get_net_state() -> Dictionary:
	return {"open": is_open, "locked": locked}


func apply_net_state(state: Dictionary) -> void:
	locked = state.get("locked", true)
	super.apply_net_state(state)
