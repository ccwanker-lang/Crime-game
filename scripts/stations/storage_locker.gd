class_name StorageLocker
extends Station
## Point 18 (D): a metal locker you buy and place in a property. It has its own
## inventory (SLOTS stacks) that every crew member can use. E opens the storage
## window (HUD): click a stack to move it between your pockets and the locker.
## HOST AUTHORITATIVE: request_move() -> host checks distance, moves the stack in
## GameState (state["items"] lives in GameState.world["stations"], so it is saved).

signal contents_changed

const SLOTS: int = 16
const WIDTH: float = 0.9
const DEPTH: float = 0.5
const HEIGHT: float = 1.9


func default_state() -> Dictionary:
	return {"items": []}


func _build() -> void:
	var b := MeshBuilder.new()
	var hw: float = WIDTH * 0.5
	var hd: float = DEPTH * 0.5
	b.box(&"metal_dark", Vector3(0, HEIGHT * 0.5, 0), Vector3(WIDTH, HEIGHT, DEPTH), 0.01)
	# Two doors with vents and handles on the front (+Z).
	for s: float in [-1.0, 1.0]:
		var x: float = s * hw * 0.5
		b.box(&"zinc", Vector3(x, HEIGHT * 0.5, hd + 0.005), Vector3(hw - 0.04, HEIGHT - 0.08, 0.012), 0.004)
		for i: int in 4:
			b.box(&"metal_dark", Vector3(x, HEIGHT - 0.2 - i * 0.05, hd + 0.013), Vector3(hw * 0.6, 0.015, 0.004))
		b.box(&"metal_dark", Vector3(x - s * (hw * 0.5 - 0.06), HEIGHT * 0.52, hd + 0.025), Vector3(0.02, 0.16, 0.025))
	var mi := MeshInstance3D.new()
	mi.mesh = b.build()
	add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(WIDTH, HEIGHT, DEPTH)
	cs.shape = shape
	cs.position.y = HEIGHT * 0.5
	add_child(cs)


func state_changed() -> void:
	contents_changed.emit()


func used_slots() -> int:
	return (state["items"] as Array).size()


func prompt_for(_player: Player) -> String:
	return "Open locker (%d/%d)" % [used_slots(), SLOTS]


func pick_up_blocker() -> String:
	return "Empty the locker first." if used_slots() > 0 else ""


## Tap E: open the storage window on this peer (nothing to do on the host).
func interact() -> void:
	var me: Player = _local_player()
	if me:
		me.open_locker(self)


# --- Moving stacks -----------------------------------------------------------------

## Owner: move stack `index` of your inventory into the locker (to_locker) or back.
func request_move(to_locker: bool, index: int) -> void:
	if _is_host():
		_server_move(multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1, to_locker, index)
	else:
		_request_move.rpc_id(1, to_locker, index)


@rpc("any_peer", "call_remote", "reliable")
func _request_move(to_locker: bool, index: int) -> void:
	if multiplayer.is_server():
		_server_move(multiplayer.get_remote_sender_id(), to_locker, index)


func _server_move(peer: int, to_locker: bool, index: int) -> void:
	var player := get_tree().current_scene.get_node_or_null("Players/%d" % peer) as Player
	if player == null or player.dead or player.global_position.distance_to(global_position) > Player.INTERACT_DISTANCE + 1.5:
		return
	var msg: String = host_move(player.player_name, to_locker, index)
	player.send_wallet()
	if msg != "":
		player.show_message(msg)


## Host: moves one stack. Returns a message for the player ("" = all fine).
func host_move(who: String, to_locker: bool, index: int) -> String:
	var items: Array = state["items"]
	var inv: Array = GameState.get_or_create_player_data(who)["inventory"]
	if to_locker:
		if index < 0 or index >= inv.size():
			return ""
		var it: Dictionary = inv[index]
		var id: String = str(it["id"])
		var count: int = int(it.get("count", 1))
		var left: int = GameState.add_to_stacks(items, id, count, SLOTS)
		var moved: int = count - left
		if moved > 0:
			it["count"] = left
			if left <= 0:
				inv.remove_at(index)
			changed()
		return "The locker is full." if left > 0 else ""
	if index < 0 or index >= items.size():
		return ""
	var stack: Dictionary = items[index]
	var leftover: Array = GameState.give(who, 0, [{"id": stack["id"], "count": int(stack["count"])}])
	var left2: int = 0
	for l: Dictionary in leftover:
		left2 += int(l["count"])
	stack["count"] = left2
	if left2 <= 0:
		items.remove_at(index)
	changed()
	return "Your pockets are full." if left2 > 0 else ""
