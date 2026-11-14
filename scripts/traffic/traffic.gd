class_name Traffic
extends Node3D
## AI traffic: the driving routes over the road network and (host) the cars on
## them. Cars are children of this node, replicated by World/CarSpawner.
##
## Right-hand traffic, lanes 1.75 m from the road centre. Roads: main road
## z = 0 (x -180..72; point 47: Industrial Road x = -114 (z 0..84) + Quay Road z = 84 (x -180..-114)), side street x = -6 and x = 30 (z 0..-48), top road
## z = -48 (x -6..72), south road x = 30 (z 0..66), South Street z = 60 (x -60..30, dead end west).

const CAR := preload("res://prefabs/vehicles/car.tscn")
const CAR_COUNT: int = 8

## Junction squares (centre x, z; half size JUNCTION_HALF): one car at a time.
const JUNCTIONS: Array[Vector2] = [Vector2(-6, 0), Vector2(30, 0), Vector2(30, -48), Vector2(30, 60), Vector2(-114, 0)]
const JUNCTION_HALF: float = 6.0

var routes: Array[TrafficRoute] = []
var _junction_owner: Dictionary = {}  # junction index -> Car (host)


func _ready() -> void:
	_build_routes()
	if multiplayer.is_server() and not "--selftest" in OS.get_cmdline_user_args():
		var count: int = CAR_COUNT
		for arg: String in OS.get_cmdline_user_args():
			if arg.begins_with("--cars="):
				count = arg.trim_prefix("--cars=").to_int()
		spawn_cars.call_deferred(count)
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
			[2.5, 1.75, 1.75, 5.0, 4.25, 1.75, 1.75, 7.75]))
	# 3: main road west part + the south road + South Street (U-turn at its dead end).
	routes.append(TrafficRoute.new(
			[Vector2(-66, 1.75), Vector2(28.25, 1.75), Vector2(28.25, 58.25), Vector2(-54, 58.25),
			Vector2(-54, 61.75), Vector2(31.75, 61.75), Vector2(31.75, -1.75), Vector2(-66, -1.75)],
			[1.75, 2.5, 2.5, 1.75, 1.75, 5.0, 5.0, 1.75]))
	for r: TrafficRoute in routes:
		r.mark_junctions(JUNCTIONS, JUNCTION_HALF)
		# The driving line as a Path3D (debug: F3 shows it).
		var path := Path3D.new()
		path.name = "Route%d" % (routes.find(r))
		path.curve = r.curve
		path.add_to_group(&"debug_only")
		path.visible = false
		add_child(path)


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
func spawn_cars(count: int) -> void:
	var per_route: Array[int] = []
	per_route.resize(routes.size())
	per_route.fill(0)
	for i: int in count:
		per_route[i % routes.size()] += 1
	var n: int = 0
	for r: int in routes.size():
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
