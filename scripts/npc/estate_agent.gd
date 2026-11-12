class_name EstateAgent
extends Shopkeeper
## Point 8: the real estate agent. Instead of items she sells properties (Property nodes
## with for_sale). E opens the estate window (PlayerHUD.open_shop shows the property list).
## Buying is HOST AUTHORITATIVE: request_buy_property -> host checks distance, owner and
## cash -> Property.host_set_owned (furniture adopted, every peer updated).


func get_interaction_prompt() -> String:
	return "Talk to %s (%s)" % [npc_name, shop_name]


## Properties she sells, cheapest first.
func listings() -> Array[Property]:
	var out: Array[Property] = []
	for n: Node in get_tree().get_nodes_in_group(&"properties"):
		var p := n as Property
		if p.for_sale:
			out.append(p)
	out.sort_custom(func(a: Property, b: Property) -> bool: return a.price < b.price)
	return out


func request_buy_property(id: StringName) -> void:
	if multiplayer.is_server():
		_server_buy_property(multiplayer.get_unique_id(), id)
	else:
		_request_buy_property.rpc_id(1, id)


@rpc("any_peer", "call_remote", "reliable")
func _request_buy_property(id: StringName) -> void:
	if multiplayer.is_server():
		_server_buy_property(multiplayer.get_remote_sender_id(), id)


func _server_buy_property(peer: int, id: StringName) -> void:
	var buyer := get_tree().current_scene.get_node_or_null("Players/%d" % peer) as Player
	if buyer == null or buyer.dead:
		return
	var prop: Property = null
	for p: Property in listings():
		if p.property_id == id:
			prop = p
	var msg: String = ""
	if buyer.global_position.distance_to(global_position) > Player.INTERACT_DISTANCE + 2.0:
		msg = "You walked away."
	elif prop == null:
		msg = "\"That one isn't on the market.\""
	elif prop.is_crew_owned():
		msg = "\"Your crew already owns that one.\""
	elif not GameState.add_cash(buyer.player_name, -prop.price, true):
		msg = "Not enough money (€%s needed)." % Property.money(prop.price)
	else:
		prop.host_set_owned(buyer.player_name)
		buyer.send_wallet()
		print("[Estate] %s bought %s for €%d" % [buyer.player_name, prop.display_name, prop.price])
		_answer(peer, true, "Bought the %s for €%s. The keys are yours!" % [prop.display_name, Property.money(prop.price)])
		buyer.phone_message(npc_name, "Congratulations with the %s! Everything inside is yours now: move it, sell it, or put your own stuff in." % prop.display_name, "")
		return
	_answer(peer, false, msg)
