class_name CarDealer
extends Shopkeeper
## Point 45: Carlo of Carlo's Cars. Sells the cars of CarCatalog instead of items: E opens the shop
## window with the car list (PlayerHUD._fill_cars). Buying is HOST AUTHORITATIVE: request_buy_car ->
## host checks distance + money (legal purchase: clean money first) -> Vehicles.host_spawn on a free
## delivery spot on the lot (markers CarDelivery*), the keys are the crew's.


func get_interaction_prompt() -> String:
	return "Talk to %s (%s)" % [npc_name, shop_name]


func request_buy_car(id: String) -> void:
	if multiplayer.is_server():
		_server_buy_car(multiplayer.get_unique_id(), id)
	else:
		_request_buy_car.rpc_id(1, id)


@rpc("any_peer", "call_remote", "reliable")
func _request_buy_car(id: String) -> void:
	if multiplayer.is_server():
		_server_buy_car(multiplayer.get_remote_sender_id(), id)


## Host: a free delivery spot (Marker3D) on the lot, or null when every spot holds a car.
func delivery_spot() -> Node3D:
	var world: Node = get_tree().current_scene
	for i: int in range(1, 9):
		var m := world.find_child("CarDelivery%d" % i, true, false) as Node3D
		if m == null:
			break
		var taken: bool = false
		if Vehicles.current:
			for car: PlayerCar in Vehicles.current.cars():
				if car.global_position.distance_to(m.global_position) < 3.5:
					taken = true
		if not taken:
			return m
	return null


func _server_buy_car(peer: int, id: String) -> void:
	var buyer := get_tree().current_scene.get_node_or_null("Players/%d" % peer) as Player
	if buyer == null or buyer.dead or Vehicles.current == null:
		return
	var msg: String = ""
	var spot: Node3D = delivery_spot()
	if not CarCatalog.MODELS.has(id):
		msg = "\"Never heard of that one.\""
	elif buyer.global_position.distance_to(global_position) > Player.INTERACT_DISTANCE + 2.0:
		msg = "You walked away."
	elif spot == null:
		msg = "\"Clear my lot first, there's no room to hand you the car.\""
	else:
		var m: Dictionary = CarCatalog.get_model(id)
		if not GameState.add_cash(buyer.player_name, -int(m["price"]), true):
			msg = "Not enough money (€%s needed)." % CarCatalog.money(int(m["price"]))
		else:
			var car: PlayerCar = Vehicles.current.host_spawn(id, int(CarCatalog.LOT_PAINT.get(id, 0)),
					spot.global_position, spot.global_rotation.y)
			buyer.send_wallet()
			print("[Cars] %s bought a %s (car %s) for €%d" % [buyer.player_name, m["name"], car.uid, int(m["price"])])
			_answer(peer, true, "The %s is yours! It's waiting on the lot: walk up to it and press F." % m["name"])
			buyer.phone_message(npc_name, "Enjoy the %s! Drive safe... or at least don't tell me about it." % m["name"], "")
			return
	_answer(peer, false, msg)
