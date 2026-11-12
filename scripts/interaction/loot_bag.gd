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
## Point 20: an item a player dropped (G): shows the item itself instead of a bag.
var dropped: bool = false


func _ready() -> void:
	Net.limit_sync_to_world($Sync)
	if dropped:
		_show_item()


## Dropped item: hide the bag, lay the item's model on the ground instead.
func _show_item() -> void:
	for n: String in ["Body", "BandL", "BandR", "HandleL", "HandleR", "Zipper"]:
		var m := get_node_or_null(n) as Node3D
		if m:
			m.visible = false
	var data: ItemData = ItemDB.get_item(StringName(str(items[0].get("id", "")))) if not items.is_empty() else null
	var scene: PackedScene = data.get_model() if data else null
	if scene == null:
		for n: String in ["Body", "BandL", "BandR", "HandleL", "HandleR", "Zipper"]:
			var m := get_node_or_null(n) as Node3D
			if m:
				m.visible = true
		return
	var model := scene.instantiate() as Node3D
	model.name = "ItemModel"
	if data is WeaponData:
		model.rotation.z = PI / 2.0  # guns lie on their side
	var holder := Node3D.new()
	holder.add_child(model)
	add_child(holder)
	# Sit the model on the ground (its lowest point at y 0, centred).
	var box := AABB()
	var first: bool = true
	for c: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi.mesh == null:
			continue
		var t: Transform3D = holder.global_transform.affine_inverse() * mi.global_transform if mi.is_inside_tree() else Transform3D.IDENTITY
		var bb: AABB = t * mi.mesh.get_aabb()
		box = bb if first else box.merge(bb)
		first = false
	if not first:
		holder.position = Vector3(-box.get_center().x, -box.position.y + 0.01, -box.get_center().z)


func _total_count() -> int:
	var count: int = 0
	for it: Dictionary in items:
		count += int(it.get("count", 1))
	return count


func get_interaction_prompt() -> String:
	if dropped and not items.is_empty():
		var data: ItemData = ItemDB.get_item(StringName(str(items[0].get("id", ""))))
		return "Pick up %dx %s" % [_total_count(), data.display_name if data else str(items[0].get("id"))]
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
