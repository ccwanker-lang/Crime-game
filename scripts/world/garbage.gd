class_name Garbage
extends Node
## Point 39: the garbage collection (World/Garbage, host logic). Every morning at
## PICKUP_HOUR (in-game) a garbage truck drives the lane next to every outside trash bin
## that has trash in it (one truck per traffic route), stops next to each bin, empties it
## and goes off duty. Bins inside a building are never emptied (the truck can't reach them).

const PICKUP_HOUR: float = 8.0
## The truck appears this many metres before the first bin on its route.
const LEAD: float = 45.0
## ...and drives this far past the last one before it goes off duty.
const TAIL: float = 50.0

var _last_hours: float = -1.0
var _check: float = 0.0


static func current(tree: SceneTree) -> Garbage:
	return tree.current_scene.get_node_or_null("Garbage") as Garbage if tree and tree.current_scene else null


func _process(delta: float) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	_check -= delta
	if _check > 0.0:
		return
	_check = 1.0
	var dn := get_tree().get_first_node_in_group(&"day_night") as DayNight
	if dn == null:
		return
	var h: float = dn.hours
	if _last_hours >= 0.0:
		var crossed: bool = (_last_hours < PICKUP_HOUR and h >= PICKUP_HOUR) if h >= _last_hours \
				else (_last_hours < PICKUP_HOUR or h >= PICKUP_HOUR)
		if crossed:
			dispatch()
	_last_hours = h


## Outside bins with trash that a truck can reach: [{bin, route, prog}].
func _stops() -> Array:
	var traffic := get_parent().get_node_or_null("Traffic") as Traffic
	var out: Array = []
	if traffic == null:
		return out
	for n: Node in get_tree().get_nodes_in_group(&"trash_bins"):
		var bin := n as TrashBin
		if bin == null or bin.trash() <= 0 or Placement.property_at(get_tree(), bin.global_position) != null:
			continue
		var near: Array = traffic.nearest(bin.global_position)
		if float(near[2]) > Placement.LANE_MAX + 1.0:
			continue
		out.append({"bin": bin, "route": int(near[0]), "prog": float(near[1])})
	return out


## Host: sends the trucks now (also used by tests / the scenario). Returns how many.
func dispatch() -> int:
	var traffic := get_parent().get_node_or_null("Traffic") as Traffic
	if traffic == null:
		return 0
	var per_route: Dictionary = {}
	for s: Dictionary in _stops():
		(per_route.get_or_add(int(s["route"]), []) as Array).append(s)
	var sent: int = 0
	for r: int in per_route:
		var stops: Array = per_route[r]
		var length: float = traffic.routes[r].length
		# Start LEAD m before the first bin, seen from the largest gap between bins.
		stops.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["prog"]) < float(b["prog"]))
		var first: int = 0
		var gap: float = -1.0
		for i: int in stops.size():
			var prev: float = float(stops[i - 1]["prog"]) if i > 0 else float(stops[-1]["prog"]) - length
			var g: float = float(stops[i]["prog"]) - prev
			if g > gap or stops.size() == 1:
				gap = g
				first = i
		var ordered: Array = stops.slice(first) + stops.slice(0, first)
		var start: float = fposmod(float(ordered[0]["prog"]) - LEAD, length)
		var truck: Car = traffic.spawn_garbage_truck(r, start)
		truck.garbage_stops = ordered
		truck.garbage_left = fposmod(float(ordered[-1]["prog"]) - start, length) + TAIL
		sent += 1
		print("[Garbage] truck on route %d for %d bin(s)" % [r, ordered.size()])
	if sent > 0 and get_parent().has_method("phone_all"):
		get_parent().call("phone_all", "City Waste", "Good morning! The garbage truck is on its way to empty your trash bin.", "")
	return sent
