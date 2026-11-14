class_name Roadside
extends RefCounted
## Roadside service team (DESIGN "Progression" rank 5 Kingpin: "roadside service team"; Core rules: "phone ...
## calling the roadside service team"; Buildings: "roadside service depot (tow truck team drives to the player)").
## Session B. HOST AUTHORITATIVE. Request: CrewWindow tab "Services" -> `Staff.request("tow", car_uid)` ->
## `host_tow(p, uid)`: the fee is paid, a text, and `tow_seconds` later the crew car is dropped on the pavement of
## the road nearest to the caller (`kerb_spot`), facing along the traffic. Not saved: a tow in progress when the game
## is left simply did not happen (the fee is only paid... at the call, so it is refunded then: see `_deliver`).

const RANK: int = 5
const FEE: int = 350
const CONTACT: String = "Roadside Service"
## Metres from the lane centre to the parked car's centre (lane 1.75 m from the road centre, road half 3.5 m,
## pavement 3.5..6 m): the car stands on the pavement, out of the AI traffic's lane.
const KERB_OFFSET: float = 2.9
## Farthest a road may be from the caller.
const MAX_ROAD: float = 45.0
const JUNCTION_MARGIN: float = 4.0
## Point 48 (A's fuel): an (almost) empty car gets a jerrycan up to this much fuel - enough for the gas station.
const JERRYCAN: float = 0.15

## Seconds from the call to the drop (tests make it 0).
static var tow_seconds: float = 30.0
## Host: car uid -> player name of a tow on its way.
static var busy: Dictionary = {}


static func car_name(car: PlayerCar) -> String:
	return str(CarCatalog.MODELS.get(car.model_id, {}).get("name", "car"))


static func _rank_ok() -> bool:
	return not Progression.gates_on() or Progression.rank() >= RANK


## The crew's cars (every peer: they are spawned everywhere).
static func cars() -> Array[PlayerCar]:
	return Vehicles.current.cars() if Vehicles.current else ([] as Array[PlayerCar])


static func _car(uid: String) -> PlayerCar:
	for c: PlayerCar in cars():
		if c.uid == uid:
			return c
	return null


static func _occupied(car: PlayerCar) -> bool:
	for s: int in car.seats:
		if s != 0:
			return true
	return false


## Host: a free spot on the pavement next to the road nearest `near`: [position, yaw] or [] (no road close by).
static func kerb_spot(tree: SceneTree, near: Vector3, car: PlayerCar = null) -> Array:
	var world := tree.current_scene as Node3D
	var traffic := world.get_node_or_null("Traffic") as Traffic if world else null
	if traffic == null or traffic.routes.is_empty():
		return []
	var best: Array = traffic.nearest(near)
	if float(best[2]) > MAX_ROAD:
		return []
	var route: TrafficRoute = traffic.routes[int(best[0])]
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var size: Vector3 = ProcCar.collision_size(int(CarCatalog.MODELS.get(car.model_id if car else "van", {}).get("kind", ProcCar.Kind.VAN)))
	for k: int in 30:
		# 0, +4, -4, +8, -8 ... metres along the route from the nearest point.
		var along: float = float(best[1]) + (ceilf(k / 2.0) * 4.0) * (1.0 if k % 2 == 1 else -1.0)
		var s: Array = route.sample(along)
		var dir: Vector3 = Vector3((s[1] as Vector3).x, 0, (s[1] as Vector3).z).normalized()
		var right: Vector3 = dir.cross(Vector3.UP)
		var p: Vector3 = (s[0] as Vector3) + right * KERB_OFFSET
		if _in_junction(p):
			continue
		var ground: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 3.0, p + Vector3.DOWN * 3.0, 1))
		if ground.is_empty():
			continue
		p.y = (ground["position"] as Vector3).y
		var yaw: float = atan2(-dir.x, -dir.z)
		var q := PhysicsShapeQueryParameters3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(size.x + 0.4, 1.2, size.z + 0.6)
		q.shape = box
		q.transform = Transform3D(Basis(Vector3.UP, yaw), p + Vector3.UP * 0.95)
		q.collision_mask = 1 | 2 | 4
		if car:
			q.exclude = [car.get_rid()]
		if space.intersect_shape(q, 1).is_empty():
			return [p, yaw]
	return []


static func _in_junction(p: Vector3) -> bool:
	for j: Vector2 in Traffic.JUNCTIONS:
		if absf(p.x - j.x) < Traffic.JUNCTION_HALF + JUNCTION_MARGIN and absf(p.z - j.y) < Traffic.JUNCTION_HALF + JUNCTION_MARGIN:
			return true
	return false


## Host: `p` calls the tow truck for crew car `uid` ("" = the crew car farthest away). Returns the answer text
## ("!" = refused).
static func host_tow(p: Player, uid: String) -> String:
	if not _rank_ok():
		return "!The roadside team works for rank %d (%s) crews." % [RANK, Progression.rank_name(RANK)]
	if p.vehicle != null:
		return "!Get out of the car first."
	var car: PlayerCar = _car(uid) if uid != "" else null
	if uid == "":
		var far: float = -1.0
		for c: PlayerCar in cars():
			var d: float = c.global_position.distance_to(p.global_position)
			if d > far and not busy.has(c.uid):
				far = d
				car = c
	if car == null:
		return "!You don't have a car."
	if busy.has(car.uid):
		return "!The truck is already on its way with your %s." % car_name(car)
	if _occupied(car):
		return "!Somebody is sitting in your %s." % car_name(car)
	var empty: bool = car.fuel < JERRYCAN
	if car.global_position.distance_to(p.global_position) < 20.0 and not empty:
		return "!Your %s is right here." % car_name(car)
	if kerb_spot(p.get_tree(), p.global_position, car).is_empty():
		return "!\"Can't find you. Walk to a road and call again.\""
	if not GameState.add_cash(p.player_name, -FEE, true):
		return "!The tow costs €%d." % FEE
	p.send_wallet()
	busy[car.uid] = p.player_name
	var cuid: String = car.uid
	var who: String = p.player_name
	print("[Roadside] %s called the tow for %s (%s)" % [who, cuid, car.model_id])
	p.phone_message(CONTACT, "Truck's on the way with your %s. Wait by the road, about %d seconds." % [car_name(car),
			roundi(tow_seconds)], "")
	if tow_seconds <= 0.0:
		_deliver(p.get_tree(), who, cuid)
	else:
		p.get_tree().create_timer(tow_seconds).timeout.connect(func() -> void: _deliver(p.get_tree() if is_instance_valid(p) else null, who, cuid))
	return "Called the roadside team: €%d. Your %s arrives in about %d seconds." % [FEE, car_name(car), roundi(tow_seconds)]


## Host: the truck arrives: the car is set down next to the road nearest to the caller. When that is impossible
## now (caller gone, car taken, no free spot) the fee is refunded.
static func _deliver(tree: SceneTree, who: String, uid: String) -> void:
	busy.erase(uid)
	if tree == null or tree.current_scene == null:
		return
	var p: Player = null
	for n: Node in tree.get_nodes_in_group(&"players"):
		if n is Player and (n as Player).player_name == who:
			p = n as Player
	var car: PlayerCar = _car(uid)
	var spot: Array = []
	if p and car and not _occupied(car) and not p.dead:
		spot = kerb_spot(tree, p.global_position, car)
		if spot.is_empty() and car.global_position.distance_to(p.global_position) < 20.0:
			spot = [car.global_position, car.rotation.y]  # (an empty car close by: they only bring fuel)
	if spot.is_empty():
		if GameState.player_data.has(who):
			GameState.add_clean(who, FEE)
		if p:
			p.send_wallet()
			p.phone_message(CONTACT, "Couldn't deliver, sorry. Your €%d is back." % FEE, "")
		print("[Roadside] delivery of %s to %s failed, refunded" % [uid, who])
		return
	car.speed = 0.0
	car.global_position = spot[0]
	car.rotation.y = float(spot[1])
	car.net_pos = spot[0]
	car.net_yaw = float(spot[1])
	car.net_speed = 0.0
	var can: bool = car.fuel < JERRYCAN
	if can:
		car.fuel = JERRYCAN
	car._save_record()
	var dist: int = roundi((spot[0] as Vector3).distance_to(p.global_position))
	p.phone_message(CONTACT, "Your %s is parked by the road, %d m from you. Keys are in it.%s" % [car_name(car), dist,
			" Put a jerrycan in, enough for the gas station." if can else ""], "")
	print("[Roadside] delivered %s to %s at %s (%d m)" % [uid, who, spot[0], dist])
