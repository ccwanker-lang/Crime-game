class_name CityLife
extends RefCounted
## NOTES part 21 (user feedback 2026-11-15 "de stad voelt leeg"): the city's people, used by `Zones` (host).
## The city has no navmesh (A's City node is not under NavRegion), so walkers follow a SIDEWALK GRAPH built from the
## road grid (same numbers as gen_world's city: CX / CZ junctions, 12 m road tiles, sidewalk line SIDE m off the road
## centre): every junction has 4 corner nodes; edges run along the block sides and across the roads at the junctions.
## Spot kinds (Zones residents): "stand" (office groups, bus stops, apartment doors), "walk" (walkers on the graph),
## "sit" (benches / terraces). A's markers win when they exist: CityBusStop* (Marker3D, -Z = the road),
## TerraceSeat* (seat markers like a bench's), ApartmentBlock* (A's point 76 blocks: people at the front door).

const CX: Array[float] = [-54.0, 6.0, 66.0, 102.0]
const CZ: Array[float] = [144.0, 204.0, 264.0, 324.0]
const SIDE: float = 5.4
const Y: float = 0.15
## Suits, dresses, smart-casual (Pedestrian.VARIANTS indices): office people + business people.
const OFFICE_VARIANTS: Array[int] = [2, 8, 8, 2, 6, 12, 13, 5, 1, 9]
## Walkers by day / at night (22:00-06:00).
const WALKERS_DAY: int = 26
const WALKERS_NIGHT: int = 8
## Extra city cars (host, once a player comes near the city).
const EXTRA_CARS: int = 8

static var _nodes: Array[Vector3] = []
static var _edges: Array = []  # index -> Array[int]


## The sidewalk graph (built once).
static func graph() -> Array[Vector3]:
	if not _nodes.is_empty():
		return _nodes
	var index: Dictionary = {}
	for x: float in CX:
		for z: float in CZ:
			for q: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				index[Vector3(x, 0, z) + Vector3(q.x, 0, q.y)] = _nodes.size()
				_nodes.append(Vector3(x + q.x * SIDE, Y, z + q.y * SIDE))
	_edges.resize(_nodes.size())
	for i: int in _edges.size():
		_edges[i] = []
	var link := func(a: int, b: int) -> void:
		if not b in _edges[a]:
			(_edges[a] as Array).append(b)
			(_edges[b] as Array).append(a)
	for x: float in CX:
		for z: float in CZ:
			var c := Vector3(x, 0, z)
			var nw: int = index[c + Vector3(-1, 0, -1)]
			var ne: int = index[c + Vector3(1, 0, -1)]
			var se: int = index[c + Vector3(1, 0, 1)]
			var sw: int = index[c + Vector3(-1, 0, 1)]
			# Crossings round the junction.
			link.call(nw, ne)
			link.call(ne, se)
			link.call(se, sw)
			link.call(sw, nw)
	for i: int in CX.size():
		for j: int in CZ.size():
			var c := Vector3(CX[i], 0, CZ[j])
			if i + 1 < CX.size():  # the block sides along the road east
				var e := Vector3(CX[i + 1], 0, CZ[j])
				link.call(index[c + Vector3(1, 0, -1)], index[e + Vector3(-1, 0, -1)])
				link.call(index[c + Vector3(1, 0, 1)], index[e + Vector3(-1, 0, 1)])
			if j + 1 < CZ.size():  # ... and south
				var s := Vector3(CX[i], 0, CZ[j + 1])
				link.call(index[c + Vector3(-1, 0, 1)], index[s + Vector3(-1, 0, -1)])
				link.call(index[c + Vector3(1, 0, 1)], index[s + Vector3(1, 0, -1)])
	return _nodes


static func neighbours(i: int) -> Array:
	graph()
	return _edges[i] if i >= 0 and i < _edges.size() else []


static func nearest_node(pos: Vector3) -> int:
	var best: int = -1
	var best_d: float = INF
	for i: int in graph().size():
		var d: float = Vector2(_nodes[i].x - pos.x, _nodes[i].z - pos.z).length()
		if d < best_d:
			best_d = d
			best = i
	return best


static func office_variant(seed_value: int) -> int:
	return OFFICE_VARIANTS[absi(seed_value) % OFFICE_VARIANTS.size()] % Pedestrian.VARIANTS.size()


## All city spots: {key, pos, yaw, zone, kind, hours (Vector2: from, to; to < from = over midnight), talk}.
static func spots(world: Node3D) -> Array:
	var out: Array = []
	# Office groups in front of every 3rd tower (by day).
	var towers: Array[Node] = world.find_children("Tower*", "Tower", true, false)
	towers.sort_custom(func(a: Node, b: Node) -> bool: return str(a.name) < str(b.name))
	for k: int in towers.size():
		if k % 3 != 0:
			continue
		var tw := towers[k] as Tower
		var front: Vector3 = tw.global_transform * Vector3(0, 0.1, -tw.depth * 0.5 - 3.0)
		_ring(out, "%s" % tw.name, front, 3, 0.9, Vector2(7.0, 20.0), true)
	# A's apartment blocks (point 76): two neighbours at the front door, day and evening.
	for ab: Node in world.find_children("ApartmentBlock*", "", true, false):
		var t3 := ab as Node3D
		var depth: float = float(ab.get("depth")) if ab.get("depth") != null else 12.0
		var door: Vector3 = t3.global_transform * Vector3(0, 0.1, -depth * 0.5 - 2.2)
		_ring(out, "%s" % ab.name, door, 2, 0.7, Vector2(8.0, 22.5), true)
	# Bus stops: A's markers, else the middle of the long block sides on the two avenues.
	var stops: Array[Node] = world.find_children("CityBusStop*", "Node3D", true, false)
	if not stops.is_empty():
		for s: Node in stops:
			var m := s as Node3D
			_queue(out, "%s" % m.name, m.global_position + Vector3.UP * 0.1, m.global_basis.z, 3)
	else:
		for z: float in [CZ[1], CZ[2]]:
			for i: int in CX.size() - 1:
				var x: float = (CX[i] + CX[i + 1]) * 0.5
				for sz: float in [-1.0, 1.0]:
					var at := Vector3(x + sz * 4.0, Y, z + sz * (SIDE + 0.4))
					_queue(out, "Stop_%d_%d_%d" % [int(z), i, int(sz)], at, Vector3(0, 0, sz), 3)
	# Terraces: A's seat markers, else the benches along the promenade.
	var seats: Array[Node] = world.find_children("TerraceSeat*", "Node3D", true, false)
	if seats.is_empty():
		for b: Node in world.find_children("CityBench*", "", true, false):
			for s: Node in b.get_children():
				if s is Marker3D and s.is_in_group(&"bench_seat"):
					seats.append(s)
	var k2: int = 0
	for s: Node in seats:
		k2 += 1
		if k2 % 3 == 0:
			continue  # (leave some seats free)
		var m := s as Node3D
		out.append({"key": "Seat_%s_%s" % [m.get_parent().name, m.name], "pos": m.global_position, "yaw": 0.0,
				"zone": &"city", "kind": "sit", "seat": m.get_path(), "hours": Vector2(8.0, 22.0)})
	# Walkers on the sidewalk graph (the first WALKERS_NIGHT also walk at night).
	var nodes: Array[Vector3] = graph()
	for i: int in roundi(WALKERS_DAY * float(QualityProfile.value("crowd"))):  # (quality level)
		var n: int = (i * 7919) % nodes.size()
		out.append({"key": "Walker_%d" % i, "pos": nodes[n], "yaw": 0.0, "zone": &"city", "kind": "walk", "node": n,
				"hours": Vector2(0.0, 24.0) if i < WALKERS_NIGHT else Vector2(6.5, 22.0)})
	return out


static func _ring(out: Array, key: String, centre: Vector3, n: int, radius: float, hours: Vector2, talk: bool) -> void:
	for i: int in n:
		var a: float = TAU * i / n + 0.4
		var pos: Vector3 = centre + Vector3(cos(a), 0, sin(a)) * radius
		var d: Vector3 = centre - pos
		out.append({"key": "%s_%d" % [key, i], "pos": pos, "yaw": atan2(-d.x, -d.z), "zone": &"city", "kind": "stand",
				"hours": hours, "talk": talk})


## People waiting at a bus stop: a short row along the kerb, looking at the road (`road` = direction to the road).
static func _queue(out: Array, key: String, at: Vector3, road: Vector3, n: int) -> void:
	var along := Vector3(road.z, 0, -road.x).normalized()
	for i: int in n:
		var pos: Vector3 = at + along * (i - (n - 1) * 0.5) * 1.1
		out.append({"key": "%s_%d" % [key, i], "pos": pos, "yaw": atan2(-road.x, -road.z), "zone": &"city", "kind": "stand",
				"hours": Vector2(6.0, 23.0), "talk": i == 0})


static func in_hours(hours: Vector2, h: float) -> bool:
	if hours.y >= 24.0 and hours.x <= 0.0:
		return true
	if hours.x <= hours.y:
		return h >= hours.x and h < hours.y
	return h >= hours.x or h < hours.y


## Host: one walker step: from the node they reached to a random neighbour (not straight back if they can help it).
static func walk_step(npc: Pedestrian, r: Dictionary) -> void:
	if npc.is_fleeing() or npc._moving or npc.wants > 0:
		return
	var nodes: Array[Vector3] = graph()
	var at: int = int(r.get("node", -1))
	if at < 0 or npc.global_position.distance_to(nodes[at]) > 3.0:
		at = nearest_node(npc.global_position)
		if npc.global_position.distance_to(nodes[at]) > 1.0:
			r["node"] = at
			_walk(npc, nodes[at])
			return
	if randf() < 0.15:
		npc.anim_state = Pedestrian.Anim.IDLE  # (a short stop now and then)
		return
	var options: Array = neighbours(at).duplicate()
	options.shuffle()
	var prev: int = int(r.get("prev", -1))
	if options.size() > 1:
		options.erase(prev)
	for nb: int in options:
		if npc.straight_way_clear(nodes[nb], 80.0):
			r["prev"] = at
			r["node"] = nb
			npc._go_direct(nodes[nb], Pedestrian.Anim.WALK)
			return
	r["prev"] = -1


static func _walk(npc: Pedestrian, to: Vector3) -> void:
	if npc.straight_way_clear(to, 80.0):
		npc._go_direct(to, Pedestrian.Anim.WALK)
	else:
		npc.global_position = to  # (stuck off the graph: back onto the sidewalk)
		npc.net_pos = to


## Host: sit `npc` on `seat` (a bench_seat-like Marker3D: +Z = the way the sitter faces), in one go.
static func sit(npc: Pedestrian, seat: Node3D) -> void:
	if not npc.can_sit():
		return
	var fwd: Vector3 = seat.global_basis.z
	npc._sitting = true
	npc._sit_front = seat.global_position + fwd * 0.8
	npc.collision.disabled = true
	npc.global_position = seat.global_position + fwd * Pedestrian.SIT_OFFSET + Vector3.UP * Pedestrian.SIT_HEIGHT
	npc.rotation.y = atan2(-fwd.x, -fwd.z)
	npc.net_pos = npc.global_position
	npc.net_yaw = npc.rotation.y
	npc.anim_state = Pedestrian.Anim.SIT
