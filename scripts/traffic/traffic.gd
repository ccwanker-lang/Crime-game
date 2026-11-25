class_name Traffic
extends Node3D
## AI traffic: the driving routes over the road network and (host) the cars on
## them. Cars are children of this node, replicated by World/CarSpawner.
##
## Right-hand traffic, lanes 1.75 m from the road centre. Roads: main road
## z = 0 (x -180..72; point 47: Industrial Road x = -114 (z 0..84) + Quay Road z = 84 (x -180..-114)), side street x = -6 and x = 30 (z 0..-48), top road
## z = -48 (x -6..72), south road x = 30 (z 0..66), South Street z = 60 (x -66..30; point 60: it bends
## south at x -66 down to Quay Road at z 84 = a loop through the harbour).

const CAR := preload("res://prefabs/vehicles/car.tscn")
## Point 63: fewer cars (was 8): calmer streets, no queues. Point 49b: 6 = one per route, the 6th on the pass.
const CAR_COUNT: int = 6
## Quality level of the host (session B, QualityProfile): share of the ambient cars (--cars=N is taken as given).
static var count_scale: float = 1.0

## Junction squares (centre x, z; half size JUNCTION_HALF): one car at a time. The village + pass ones here; the
## city's (map zone 7) come from data/city/city.json: `JUNCTIONS` = both, rebuilt by `load_city()`.
const VILLAGE_JUNCTIONS: Array[Vector2] = [Vector2(-6, 0), Vector2(30, 0), Vector2(30, -48), Vector2(30, 60), Vector2(-114, 0), Vector2(-114, 84),
		Vector2(-150, 0)]
const JUNCTION_HALF: float = 6.0
## Point 63: junctions with traffic lights (JUNCTIONS index -> arms that have a road + the cycle offset in s).
## There the lights decide who goes (cars of the green axis share the junction); the others keep the
## one-car-at-a-time reservation.
const VILLAGE_LIGHTS: Dictionary = {0: {"arms": "WEN", "offset": 0.0}, 1: {"arms": "WENS", "offset": 11.0},
		4: {"arms": "WES", "offset": 5.0}}
const CITY_PATH: String = "res://data/city/city.json"
static var JUNCTIONS: Array[Vector2] = VILLAGE_JUNCTIONS.duplicate()
static var LIGHTS: Dictionary = VILLAGE_LIGHTS.duplicate(true)
## Map zone 7: the city routes (6..) and how many cars drive them.
static var _city: Dictionary = {}
static var city_first_route: int = -1


## (Re)builds JUNCTIONS + LIGHTS with the city's; returns the city data (empty without the file).
static func load_city() -> Dictionary:
	if _city.is_empty() and FileAccess.file_exists(CITY_PATH):
		_city = JSON.parse_string(FileAccess.get_file_as_string(CITY_PATH))
	JUNCTIONS = VILLAGE_JUNCTIONS.duplicate()
	LIGHTS = VILLAGE_LIGHTS.duplicate(true)
	for j: Array in _city.get("junctions", []):
		JUNCTIONS.append(Vector2(j[0], j[1]))
	for l: Dictionary in _city.get("lights", []):
		var idx: int = JUNCTIONS.find(Vector2(l["at"][0], l["at"][1]))
		if idx >= 0:
			LIGHTS[idx] = {"arms": l["arms"], "offset": float(l["offset"])}
	return _city
## Light cycle (s): x green, amber, all red, z green, amber, all red.
const X_GREEN: float = 16.0
const Z_GREEN: float = 10.0
const AMBER: float = 2.5
const ALL_RED: float = 2.5
const CYCLE: float = X_GREEN + Z_GREEN + 2.0 * (AMBER + ALL_RED)
## Corner spot of a light pole (m from the junction centre, on the sidewalk corner).
const LIGHT_CORNER: float = 4.8
## Every peer runs the clock; the host re-sends it now and then.
var light_clock: float = 0.0
var _light_sync_t: float = 0.0

var routes: Array[TrafficRoute] = []
var _junction_owner: Dictionary = {}  # junction index -> Car (host)


func _ready() -> void:
	_build_routes()
	_build_lights()
	if multiplayer.is_server() and not "--selftest" in OS.get_cmdline_user_args():
		var count: int = roundi(CAR_COUNT * count_scale)
		var city_count: int = roundi(int(_city.get("cars", 0)) * count_scale)
		for arg: String in OS.get_cmdline_user_args():
			if arg.begins_with("--cars="):
				count = arg.trim_prefix("--cars=").to_int()
				city_count = int(_city.get("cars", 0))
		spawn_cars.call_deferred(count)
		spawn_cars.call_deferred(city_count if count > 0 else 0, true)
		# (The network check stays deterministic: no patrols that arrest its client mid-walk.)
		var police_cars: int = 0 if "--netcheck" in OS.get_cmdline_user_args() else 2
		for arg: String in OS.get_cmdline_user_args():
			if arg.begins_with("--police-cars="):
				police_cars = arg.trim_prefix("--police-cars=").to_int()
		spawn_police_cars.call_deferred(police_cars)


func _build_routes() -> void:
	# 0: outer block loop (left turns), shares the main road's east lane.
	routes.append(TrafficRoute.new(
			[Vector2(-7.75, 1.75), Vector2(31.75, 1.75), Vector2(31.75, -49.75), Vector2(-7.75, -49.75)],
			[5.0, 5.0, 5.0, 7.75]))
	# 1: inner block loop (right turns); the north-west corner is the curved tile.
	routes.append(TrafficRoute.new(
			[Vector2(-4.25, -1.75), Vector2(-4.25, -46.25), Vector2(28.25, -46.25), Vector2(28.25, -1.75)],
			[2.5, 4.25, 2.5, 2.5]))
	# 2: main road east end <-> Industrial Road + Quay Road (point 47), U-turns before the barriers.
	routes.append(TrafficRoute.new(
			[Vector2(-112.25, 1.75), Vector2(66, 1.75), Vector2(66, -1.75), Vector2(-115.75, -1.75),
			Vector2(-115.75, 82.25), Vector2(-174, 82.25), Vector2(-174, 85.75), Vector2(-112.25, 85.75)],
			[2.5, 1.75, 1.75, 5.0, 2.5, 1.75, 1.75, 5.0]))
	# 3 (point 60): harbour loop clockwise: main road east, the south road down, South Street west, its bend down to
	# the harbour, Quay Road west, Industrial Road up (all right turns).
	routes.append(TrafficRoute.new(
			[Vector2(-112.25, 1.75), Vector2(28.25, 1.75), Vector2(28.25, 58.25), Vector2(-67.75, 58.25),
			Vector2(-67.75, 82.25), Vector2(-112.25, 82.25)],
			[2.5, 2.5, 2.5, 7.75, 4.25, 2.5]))
	# 4 (point 60): the same loop the other way round (left turns).
	routes.append(TrafficRoute.new(
			[Vector2(31.75, -1.75), Vector2(-115.75, -1.75), Vector2(-115.75, 85.75), Vector2(-64.25, 85.75),
			Vector2(-64.25, 61.75), Vector2(31.75, 61.75)],
			[5.0, 5.0, 5.0, 7.75, 4.25, 5.0]))
	# 5 (point 49b): over the mountain pass: Main Road's west end, Country Lane, the farm, the hairpins, the prison
	# gate and back (with heights, from data/mountain).
	var pass_pts: PackedVector3Array = Mountain.route_points()
	if pass_pts.size() > 10:
		routes.append(TrafficRoute.from_points(pass_pts))
	# 6.. (map zone 7): the highway + the city loops (data/city/city.json from gen_world.py).
	var city: Dictionary = load_city()
	city_first_route = routes.size()
	for cr: Dictionary in city.get("routes", []):
		var corners: Array[Vector2] = []
		for c: Array in cr["corners"]:
			corners.append(Vector2(c[0], c[1]))
		var radii: Array[float] = []
		for v: float in cr["radii"]:
			radii.append(v)
		routes.append(TrafficRoute.new(corners, radii))
	for r: TrafficRoute in routes:
		r.mark_junctions(JUNCTIONS, JUNCTION_HALF)
		# The driving line as a Path3D (debug: F3 shows it).
		var path := Path3D.new()
		path.name = "Route%d" % (routes.find(r))
		path.curve = r.curve
		path.add_to_group(&"debug_only")
		path.visible = false
		add_child(path)


## Point 63: a pole with a head for every arm that has traffic coming in (right-hand corner before the junction).
func _build_lights() -> void:
	# approach arm -> [corner sign x, corner sign z, axis, head facing]
	var heads: Dictionary = {"E": [1.0, -1.0, &"x", Vector3.RIGHT], "W": [-1.0, 1.0, &"x", Vector3.LEFT],
			"S": [1.0, 1.0, &"z", Vector3.BACK], "N": [-1.0, -1.0, &"z", Vector3.FORWARD]}
	for j: int in LIGHTS:
		var c: Vector2 = JUNCTIONS[j]
		for arm: String in (LIGHTS[j]["arms"] as String):
			var h: Array = heads[arm]
			var tl := TrafficLight.new()
			tl.name = "Light%d%s" % [j, arm]
			tl.junction = j
			tl.axis = h[2]
			tl.facing = h[3]
			tl.position = Vector3(c.x + float(h[0]) * LIGHT_CORNER, 0.15, c.y + float(h[1]) * LIGHT_CORNER)
			add_child(tl)


func _process(delta: float) -> void:
	light_clock += delta
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	_light_sync_t -= delta
	if _light_sync_t <= 0.0:
		_light_sync_t = 4.0
		for peer: int in Net.peers_in_world:
			if peer != multiplayer.get_unique_id():
				_sync_lights.rpc_id(peer, light_clock)


@rpc("authority", "call_remote", "unreliable")
func _sync_lights(t: float) -> void:
	light_clock = t


## Point 63: &"green" / &"amber" / &"red" for traffic along `axis` (&"x" or &"z") at junction j
## (always green at a junction without lights).
func light_state(j: int, axis: StringName) -> StringName:
	if not LIGHTS.has(j):
		return &"green"
	var t: float = fposmod(light_clock + float(LIGHTS[j]["offset"]), CYCLE)
	var z_start: float = X_GREEN + AMBER + ALL_RED
	if axis == &"z":
		t = fposmod(t - z_start, CYCLE)
	var green: float = X_GREEN if axis == &"x" else Z_GREEN
	if t < green:
		return &"green"
	if t < green + AMBER:
		return &"amber"
	return &"red"


## Host: may `car` drive into junction j? Grants it if nobody else holds it.
func request_junction(j: int, car: Car) -> bool:
	var holder: Variant = _junction_owner.get(j)
	if holder == null or not is_instance_valid(holder) or holder == car:
		_junction_owner[j] = car
		return true
	return false


func release_junction(j: int, car: Car) -> void:
	if _junction_owner.get(j) == car:
		_junction_owner.erase(j)


## Host (point 24): where a car at `pos` heading `fwd` can turn round to flee from
## `origin`: [route index, progress] of the closest point on the opposite lane (2.5-6 m
## away, heading the other way, away from the shot), or [] if there is none.
func find_escape(pos: Vector3, origin: Vector3, fwd: Vector3) -> Array:
	var best: Array = []
	var best_d: float = INF
	var away: Vector3 = Vector3(pos.x - origin.x, 0, pos.z - origin.z).normalized()
	for r: int in routes.size():
		var route: TrafficRoute = routes[r]
		var d: float = 0.0
		while d < route.length:
			var s: Array = route.sample(d)
			var p: Vector3 = s[0]
			var gap: float = Vector2(p.x - pos.x, p.z - pos.z).length()
			if gap > 2.5 and gap < 6.0 and gap < best_d:
				var dir: Vector3 = s[1]
				if dir.dot(fwd) < -0.8 and dir.dot(away) > 0.3:
					best = [r, d]
					best_d = gap
			d += 1.0
	return best


## Host: a wreck (or a car whose driver died) is towed away: removed, and a new car
## turns up on the same route a bit later, out of sight of the players if possible.
func replace_car(old: Car) -> void:
	var r: int = old.route_id
	var kind: int = old.kind
	var police: bool = old.police
	var extra: bool = old.dispatched or old.roadblock  # point 28: sent cars are not replaced
	for j: int in JUNCTIONS.size():
		release_junction(j, old)
	old.queue_free()
	if extra:
		return
	await get_tree().create_timer(5.0).timeout
	if not is_inside_tree():
		return
	var route: TrafficRoute = routes[r]
	var best: float = randf() * route.length
	var best_d: float = -1.0
	for attempt: int in 12:
		var prog: float = randf() * route.length
		var p: Vector3 = route.sample(prog)[0]
		var nearest: float = INF
		for pl: Node in get_tree().get_nodes_in_group(&"players"):
			nearest = minf(nearest, (pl as Node3D).global_position.distance_to(p))
		for c: Node in get_children():
			if c is Car:
				nearest = minf(nearest, (c as Car).global_position.distance_to(p) * 3.0)
		if nearest > best_d:
			best_d = nearest
			best = prog
	var car: Car = CAR.instantiate()
	car.route_id = r
	car.progress = best
	car.kind = kind
	car.police = police
	car.color_seed = randi()
	add_child(car, true)


## Host: spreads `count` cars over the routes.
## Host: `count` cars spread over the village + pass routes (0..5); `city` = over the city routes instead.
func spawn_cars(count: int, city: bool = false) -> void:
	var first: int = city_first_route if city else 0
	var last: int = routes.size() if city else (city_first_route if city_first_route >= 0 else routes.size())
	if last <= first:
		return
	var per_route: Array[int] = []
	per_route.resize(routes.size())
	per_route.fill(0)
	for i: int in count:
		per_route[first + i % (last - first)] += 1
	var n: int = 0
	for r: int in range(first, last):
		for k: int in per_route[r]:
			var car: Car = CAR.instantiate()
			car.route_id = r
			car.progress = routes[r].length * (float(k) + 0.25) / per_route[r]
			car.kind = n % ProcCar.Kind.size()
			car.color_seed = randi()
			add_child(car, true)
			n += 1
	print("[Traffic] %d cars on %d routes" % [n, routes.size()])


## Host: point 10, police patrol cars on the route past the police station (South Street).
func spawn_police_cars(count: int) -> void:
	for k: int in count:
		spawn_police_car(3, routes[3].length * (0.6 + 0.15 * k))


## Host: a police patrol car on route `r` at `prog` metres (`crew` officers, point 28:
## `heavy` = a heavy team with SMGs).
func spawn_police_car(r: int, prog: float, crew: int = 2, heavy: bool = false) -> Car:
	var car: Car = CAR.instantiate()
	car.route_id = r
	car.progress = prog
	car.kind = ProcCar.Kind.SEDAN
	car.police = true
	car.crew_size = crew
	car.heavy = heavy
	car.color_seed = randi()
	add_child(car, true)
	return car


## Host (point 39): the garbage truck (a green van) on route `r` at `prog` metres.
func spawn_garbage_truck(r: int, prog: float) -> Car:
	var car: Car = CAR.instantiate()
	car.route_id = r
	car.progress = prog
	car.kind = ProcCar.Kind.VAN
	car.garbage = true
	car.color_seed = randi()
	add_child(car, true)
	return car


## Point 28: the route point closest to `p`: [route index, progress (m), distance].
func nearest(p: Vector3) -> Array:
	var best: Array = [0, 0.0, INF]
	for r: int in routes.size():
		var route: TrafficRoute = routes[r]
		for i: int in int(route.length):
			var d: float = (route.sample(float(i))[0] as Vector3).distance_to(p)
			if d < best[2]:
				best = [r, float(i), d]
	return best


## Point 28 (road blocks): a route point between `near` and `far` metres from `p`, preferably
## in direction `dir` (where the player is heading), away from other police cars.
## Returns [route index, progress] or [] when there is none.
func spot_ahead(p: Vector3, dir: Vector3, near: float, far: float) -> Array:
	var fwd: Vector3 = dir.normalized() if dir.length() > 0.5 else Vector3.ZERO
	var best: Array = []
	var best_score: float = -INF
	for r: int in routes.size():
		var route: TrafficRoute = routes[r]
		for i: int in int(route.length / 2.0):
			var q: Vector3 = route.sample(i * 2.0)[0]
			var d: float = q.distance_to(p)
			if d < near or d > far:
				continue
			var clear: bool = true
			for c: Node in get_children():
				if c is Car and (c as Car).police and (c as Car).global_position.distance_to(q) < 20.0:
					clear = false
					break
			if not clear:
				continue
			var score: float = fwd.dot((q - p).normalized()) + randf() * 0.4
			if score > best_score:
				best_score = score
				best = [r, i * 2.0]
	return best
