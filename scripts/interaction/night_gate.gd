@tool
class_name NightGate
extends NetDoor
## Point 7: the chain-link gate in front of the black market (inside the garage).
## Locked during the day: from the workshop side it only opens at night (when the street
## lights are on, DayNight.is_night). From the market side it always opens, so nobody gets
## locked in. At dawn the host closes it. Hinge at the origin, the gate extends along +X,
## the market is on the -Z side (it swings open into the market).

const GATE_MODEL: PackedScene = preload("res://assets/polyhaven/modular_chainlink_fence/modular_chainlink_fence.gltf")

var _was_night: bool = true


func _rebuild() -> void:
	_pending = false
	if _pivot:
		_pivot.queue_free()
	var body := AnimatableBody3D.new()
	body.collision_layer = 1 << (DOOR_LAYER - 1)
	body.collision_mask = 0
	_pivot = body
	add_child(body)
	# The chain-link gate leaf of the fence model, stretched to width x height.
	var leaf := ModelPart.new()
	leaf.model = GATE_MODEL
	leaf.parts = PackedStringArray(["modular_chainlink_fence_door_gate"])
	body.add_child(leaf)
	var box := AABB()
	var first: bool = true
	for c: Node in leaf.get_children():
		var mi := c as MeshInstance3D
		if mi and mi.mesh:
			var bb: AABB = mi.transform * mi.mesh.get_aabb()
			box = bb if first else box.merge(bb)
			first = false
	if not first:
		var sc := Vector3(width / box.size.x, height / box.size.y, 1.0)
		leaf.scale = sc
		leaf.position = Vector3(-box.position.x * sc.x, -box.position.y * sc.y, -box.get_center().z)
	# Padlock on the latch side.
	var b := MeshBuilder.new()
	b.box(&"metal_dark", Vector3(width - 0.08, 1.05, 0.04), Vector3(0.06, 0.07, 0.03))
	b.box(&"zinc", Vector3(width - 0.08, 1.1, 0.04), Vector3(0.04, 0.04, 0.012))
	_mesh = MeshInstance3D.new()
	_mesh.mesh = b.build()
	body.add_child(_mesh)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, height, 0.06)
	cs.shape = shape
	cs.position = Vector3(width / 2.0, height / 2.0, 0)
	body.add_child(cs)
	_pivot.rotation.y = deg_to_rad(open_angle) if is_open else 0.0


static func night_now(tree: SceneTree) -> bool:
	var dn := tree.get_first_node_in_group(&"day_night") as DayNight
	return dn == null or dn.is_night()


## True when `pos` is on the market side of the gate.
func is_inside(pos: Vector3) -> bool:
	return to_local(pos).z < 0.0


func get_interaction_prompt() -> String:
	if not is_open and not night_now(get_tree()):
		var me: Node3D = _local_player_body()
		if me == null or not is_inside(me.global_position):
			return "Locked - the black market opens at night"
	return "Close the gate" if is_open else "Open the gate"


func _local_player_body() -> Node3D:
	for p: Node in get_tree().get_nodes_in_group(&"players"):
		if (p as Player).is_local():
			return p as Node3D
	return null


func interact() -> void:
	if multiplayer.is_server():
		_gate_toggle(multiplayer.get_unique_id())
	else:
		_request_gate.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _request_gate() -> void:
	if multiplayer.is_server():
		_gate_toggle(multiplayer.get_remote_sender_id())


## Host: opens/closes unless it is locked for this player.
func _gate_toggle(peer: int) -> void:
	var player := get_tree().current_scene.get_node_or_null("Players/%d" % peer) as Player
	if player == null or player.global_position.distance_to(get_center()) > Player.INTERACT_DISTANCE + 1.5:
		return
	if not is_open and not night_now(get_tree()) and not is_inside(player.global_position):
		player.show_message("The gate is locked. The black market opens at night.")
		return
	_server_toggle()


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	var night: bool = night_now(get_tree())
	if _was_night and not night and is_open:
		_set_open.rpc(false)  # dawn: the market closes
	_was_night = night
