class_name Shopkeeper
extends Node3D
## An NPC behind a counter who sells items (store clerk, seed contact, later the
## gun shop and black market). Placed inside building prefabs, so it exists on
## every peer at the same path; RPCs go through this node.
##
## E opens the shop window on the local player. Buying is HOST AUTHORITATIVE:
## the client sends a request, the host checks distance, stock, cash and free
## inventory space, moves the money/items in GameState and answers the buyer.

## Shown in the prompt and the shop window.
@export var npc_name: String = "Clerk"
@export var shop_name: String = "Store"
@export_multiline var greeting: String = "What can I get you?"
## Item ids for sale (ItemData in data/items/).
@export var stock: Array[StringName] = []
## Price = item base_price * this, rounded.
@export var price_factor: float = 1.0
## Look of the NPC (Pedestrian variants).
@export var variant: int = 0
@export var color_seed: int = 0

const MAX_PER_BUY: int = 20

signal buy_result(ok: bool, message: String)

@onready var body_npc: Pedestrian = $Pedestrian


func _enter_tree() -> void:
	# Before the Pedestrian child builds its model in its _ready.
	var npc := $Pedestrian as Pedestrian
	npc.variant = variant
	npc.color_seed = color_seed
	npc.stationary = true


func _ready() -> void:
	add_to_group(&"interactable")


func get_interaction_prompt() -> String:
	return "Talk to %s (%s)" % [npc_name, shop_name]


func interact() -> void:
	var me := _local_player()
	if me:
		me.open_shop(self)


func price_of(id: StringName) -> int:
	var item: ItemData = ItemDB.get_item(id)
	return roundi(item.base_price * price_factor) if item else 0


## Local player: ask the host to buy `count` of item `id`. The answer comes back as buy_result.
func request_buy(id: StringName, count: int) -> void:
	if multiplayer.is_server():
		_server_buy(multiplayer.get_unique_id(), id, count)
	else:
		_request_buy.rpc_id(1, id, count)


@rpc("any_peer", "call_remote", "reliable")
func _request_buy(id: StringName, count: int) -> void:
	if multiplayer.is_server():
		_server_buy(multiplayer.get_remote_sender_id(), id, count)


func _server_buy(peer: int, id: StringName, count: int) -> void:
	var buyer := get_tree().current_scene.get_node_or_null("Players/%d" % peer) as Player
	if buyer == null or buyer.dead:
		return
	var msg: String = ""
	var item: ItemData = ItemDB.get_item(id)
	if buyer.global_position.distance_to(global_position) > Player.INTERACT_DISTANCE + 2.0:
		msg = "You walked away."
	elif item == null or not id in stock or count < 1 or count > MAX_PER_BUY:
		msg = "\"I don't sell that.\""
	else:
		var total: int = price_of(id) * count
		if GameState.space_for(buyer.player_name, String(id)) < count:
			msg = "Your pockets are full."
		elif not GameState.add_cash(buyer.player_name, -total):
			msg = "Not enough cash (€%d needed)." % total
		else:
			GameState.give(buyer.player_name, 0, [{"id": String(id), "count": count}])
			buyer.send_wallet()
			print("[Shop] %s bought %dx %s from %s for €%d" % [buyer.player_name, count, id, npc_name, total])
			_answer(peer, true, "Bought %dx %s for €%d." % [count, item.display_name, total])
			return
	_answer(peer, false, msg)


func _answer(peer: int, ok: bool, message: String) -> void:
	if peer == multiplayer.get_unique_id():
		buy_result.emit(ok, message)
	else:
		_buy_answer.rpc_id(peer, ok, message)


@rpc("authority", "call_remote", "reliable")
func _buy_answer(ok: bool, message: String) -> void:
	buy_result.emit(ok, message)


func _local_player() -> Player:
	for p: Node in get_tree().get_nodes_in_group(&"players"):
		if (p as Player).is_local():
			return p as Player
	return null
