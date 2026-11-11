class_name LootBag
extends StaticBody3D
## Bag dropped where a player died, holding their cash and carried items.
## Anyone (also rivals) can take it with E. Host authoritative: the host spawns
## it (World/LootSpawner), validates the pickup, moves the contents to the
## picker's GameState record and removes the bag (despawned on every peer).

var owner_name: String = ""
var cash: int = 0
## [{ "id": String, "count": int }]
var items: Array = []


func _ready() -> void:
	Net.limit_sync_to_world($Sync)


func get_interaction_prompt() -> String:
	var parts: PackedStringArray = []
	if cash > 0:
		parts.append("€%d" % cash)
	var count: int = 0
	for it: Dictionary in items:
		count += int(it.get("count", 1))
	if count > 0:
		parts.append("%d item%s" % [count, "" if count == 1 else "s"])
	var what: String = ", ".join(parts) if not parts.is_empty() else "empty"
	return "Take %s's bag (%s)" % [owner_name, what]


func interact() -> void:
	if multiplayer.is_server():
		_server_take(multiplayer.get_unique_id())
	else:
		_request_take.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _request_take() -> void:
	if multiplayer.is_server():
		_server_take(multiplayer.get_remote_sender_id())


func _server_take(peer: int) -> void:
	if is_queued_for_deletion():
		return
	var picker := get_tree().current_scene.get_node_or_null("Players/%d" % peer) as Player
	if picker == null or picker.dead or picker.global_position.distance_to(global_position) > Player.INTERACT_DISTANCE + 1.0:
		return
	var leftover: Array = GameState.give(picker.player_name, cash, items)
	print("[Loot] %s took %s's bag (€%d, %d item stacks, %d left)" % [picker.player_name, owner_name, cash,
			items.size(), leftover.size()])
	picker.send_wallet()
	if leftover.is_empty():
		queue_free()
	else:
		# Pockets full: the rest stays in the bag.
		_set_contents(0, leftover)
		for other: int in Net.peers_in_world:
			_set_contents.rpc_id(other, 0, leftover)


## Host -> everyone: what is still in the bag.
@rpc("authority", "call_remote", "reliable")
func _set_contents(new_cash: int, new_items: Array) -> void:
	cash = new_cash
	items = new_items
