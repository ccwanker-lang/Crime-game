@tool
class_name FuelPump
extends StaticBody3D
## Point 48 (rest): a pump at the gas station on North Road. Park a crew car next to it, get out, E: the host
## fills the tank (PlayerCar.host_refuel) for FUEL_PRICE per litre, clean money first (a legal purchase).
## HOST AUTHORITATIVE: request_fill -> _host_fill checks distance, the car and the money.

const CAR_REACH: float = 6.5
const PLAYER_REACH: float = 4.0

var _built: bool = false


func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	if not Engine.is_editor_hint():
		add_to_group(&"interactable")
		add_to_group(&"fuel_pumps")
	_build()


func _build() -> void:
	if _built:
		return
	_built = true
	var b := MeshBuilder.new()
	b.color = Color(0.35, 0.36, 0.38)
	b.box(&"item_matte", Vector3(0, 0.05, 0), Vector3(1.2, 0.1, 0.8), 0.02)  # island
	b.color = Color(0.85, 0.2, 0.15)
	b.box(&"item_matte", Vector3(0, 0.85, 0), Vector3(0.7, 1.5, 0.45), 0.04)  # body
	b.color = Color(0.95, 0.95, 0.92)
	b.box(&"item_matte", Vector3(0, 1.3, 0.23), Vector3(0.5, 0.3, 0.02))  # display
	b.color = Color(0.1, 0.1, 0.1)
	b.box(&"item_matte", Vector3(0.38, 0.9, 0), Vector3(0.06, 0.5, 0.12))  # nozzle
	b.cylinder(&"item_matte", Vector3(0.4, 0.7, 0.0), Vector3(0.45, 0.25, 0.25), 0.02, 0.02, 6)  # hose
	var mi := MeshInstance3D.new()
	mi.mesh = b.build()
	add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.7, 1.6, 0.45)
	cs.shape = shape
	cs.position.y = 0.85
	add_child(cs)


## The crew car parked next to this pump (closest, nobody driving), or null.
func car_here() -> PlayerCar:
	var best: PlayerCar = null
	var best_d: float = CAR_REACH
	for n: Node in get_tree().get_nodes_in_group(&"player_cars"):
		var car := n as PlayerCar
		if car == null or car.is_queued_for_deletion():
			continue
		var d: float = car.distance_to_body(global_position)
		if d < best_d:
			best = car
			best_d = d
	return best


static func cost_for(car: PlayerCar) -> int:
	return ceili(car.litres_missing() * PlayerCar.FUEL_PRICE)


func get_interaction_prompt() -> String:
	var car: PlayerCar = car_here()
	if car == null:
		return "Fuel pump (park your car next to it)"
	if car.litres_missing() <= 0:
		return "Fuel pump: the %s is full" % car.spec["name"]
	return "Fill up the %s: %d L for €%d" % [car.spec["name"], car.litres_missing(), cost_for(car)]


func interact() -> void:
	request_fill()


func request_fill() -> void:
	if multiplayer.is_server():
		_host_fill(multiplayer.get_unique_id())
	else:
		_request_fill.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _request_fill() -> void:
	if multiplayer.is_server():
		_host_fill(multiplayer.get_remote_sender_id())


func _host_fill(peer: int) -> void:
	var p := get_tree().current_scene.get_node_or_null("Players/%d" % peer) as Player
	if p == null or p.dead or p.global_position.distance_to(global_position) > PLAYER_REACH:
		return
	if p.vehicle != null:
		p.show_message("Get out of the car first (F).")
		return
	var car: PlayerCar = car_here()
	if car == null:
		p.show_message("Park a car right next to the pump.")
		return
	if car.driver_peer() != 0 or absf(car.net_speed) > 0.5:
		p.show_message("Stop the engine first: nobody at the wheel.")
		return
	var litres: int = car.litres_missing()
	if litres <= 0:
		p.show_message("The %s is already full." % car.spec["name"])
		return
	var cost: int = cost_for(car)
	if not GameState.add_cash(p.player_name, -cost, true):
		p.show_message("Not enough money (€%d)." % cost)
		return
	car.host_refuel()
	p.send_wallet()
	p.show_message("Filled up the %s: %d L for €%d." % [car.spec["name"], litres, cost])
	print("[Fuel] %s filled up %s: %d L, €%d" % [p.player_name, car.name, litres, cost])
