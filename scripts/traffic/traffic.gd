class_name Traffic
extends Node3D
## AI traffic: the driving routes over the road network and (host) the cars on
## them. Cars are children of this node, replicated by World/CarSpawner.
##
## Right-hand traffic, lanes 1.75 m from the road centre. Roads: main road
## z = 0 (x -72..72), side street x = -6 and x = 30 (z 0..-48), top road
## z = -48 (x -6..72), south road x = 30 (z 0..66).

const CAR := preload("res://prefabs/vehicles/car.tscn")
const CAR_COUNT: int = 8

## Junction squares (centre x, z; half size JUNCTION_HALF): one car at a time.
const JUNCTIONS: Array[Vector2] = [Vector2(-6, 0), Vector2(30, 0), Vector2(30, -48)]
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


func _build_routes() -> void:
	# 0: outer block loop (left turns), shares the main road's east lane.
	routes.append(TrafficRoute.new(
			[Vector2(-7.75, 1.75), Vector2(31.75, 1.75), Vector2(31.75, -49.75), Vector2(-7.75, -49.75)],
			[5.0, 5.0, 5.0, 7.75]))
	# 1: inner block loop (right turns); the north-west corner is the curved tile.
	routes.append(TrafficRoute.new(
			[Vector2(-4.25, -1.75), Vector2(-4.25, -46.25), Vector2(28.25, -46.25), Vector2(28.25, -1.75)],
			[2.5, 4.25, 2.5, 2.5]))
	# 2: main road end to end, U-turns before the barriers.
	routes.append(TrafficRoute.new(
			[Vector2(-66, 1.75), Vector2(66, 1.75), Vector2(66, -1.75), Vector2(-66, -1.75)],
			[1.75, 1.75, 1.75, 1.75]))
	# 3: main road west part + the south road.
	routes.append(TrafficRoute.new(
			[Vector2(-66, 1.75), Vector2(28.25, 1.75), Vector2(28.25, 62), Vector2(31.75, 62),
			Vector2(31.75, -1.75), Vector2(-66, -1.75)],
			[1.75, 2.5, 1.75, 1.75, 5.0, 1.75]))
	for r: TrafficRoute in routes:
		r.mark_junctions(JUNCTIONS, JUNCTION_HALF)


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
