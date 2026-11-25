class_name DinerLife
extends Node
## City life point 2 (session B, 2026-11-25): guests in restaurants, cafes, bars, snack bars and the bakery. They come
## in from the street through the door, sit at a table (food + drink appear in front of them), stay a while and go
## again; in bars and snack bars a few stand at the counter and chat. How busy it is follows the clock (BUSY:
## lunch / dinner peaks, bars in the evening) and the quality level's crowd share.
## Node World/DinerLife, made on every peer by Zones._on_world (same path everywhere: the dishes on the tables are
## synced through it, group net_state for late joiners). Guests are host pedestrians (Zones.add_resident, meta zone
## "diner", not ambient: no customers, no day rhythm) - clients get them from the NPCSpawner like any NPC.
## Seats: Marker3D "DinerSeat*" (A's prefabs: on the floor, -Z = towards the table) or a chair (dining_chair,
## plastic_chair, stool, armchair) inside a food shop with a table within 1.7 m. Places without seats are skipped.

const FOOD_TYPES: Array[String] = ["bakery", "cafe", "restaurant", "bar", "snack_bar"]
const CHAIRS: Array[String] = ["dining_chair", "plastic_chair", "stool", "armchair", "rocking_chair"]
const TABLES: Array[String] = ["dining_table", "round_coffee_table", "picnic_table", "coffee_table", "side_table"]
## Per type: [from hour, to hour, share of the seats taken] (to > 24 = after midnight).
const BUSY: Dictionary = {
	"bakery": [[7.0, 10.0, 0.8], [10.0, 12.0, 0.5], [12.0, 14.0, 0.9], [14.0, 18.0, 0.5]],
	"cafe": [[7.5, 11.0, 0.6], [11.0, 14.0, 0.9], [14.0, 18.0, 0.7], [18.0, 20.5, 0.4]],
	"snack_bar": [[11.0, 14.0, 0.8], [14.0, 17.0, 0.4], [17.0, 21.0, 0.9], [21.0, 24.5, 0.6]],
	"restaurant": [[11.5, 14.5, 0.8], [14.5, 18.0, 0.2], [18.0, 22.5, 1.0], [22.5, 23.5, 0.4]],
	"bar": [[16.0, 19.0, 0.5], [19.0, 24.0, 1.0], [24.0, 26.0, 0.7]],
}
## What they order per type: [food, drink] pools (item ids = ProcGoods models).
const ORDERS: Dictionary = {
	"bakery": [["croissant", "apple_pie", "sandwich"], ["coffee", "tea"]],
	"cafe": [["cake", "sandwich", "croissant"], ["coffee", "tea", "soda"]],
	"snack_bar": [["fries", "burger"], ["soda", "beer"]],
	"restaurant": [["pasta", "steak", "soup"], ["wine", "soda", "beer"]],
	"bar": [["", "fries"], ["beer", "cocktail", "wine"]],
}
## Seconds a guest stays seated (tests shorten it with `speed`).
const STAY: Vector2 = Vector2(70.0, 160.0)
const SERVE_AFTER: Vector2 = Vector2(6.0, 14.0)
## Only near a player (host simulates; elsewhere the places empty out).
const SIM_RANGE: float = 150.0
const TICK: float = 1.0

static var current: DinerLife = null
## Tests: everything this many times faster (stay, serve).
static var speed: float = 1.0
## Tests: ignore the clock (every place counts as at its busiest).
static var always_open: bool = false
## Tests: run even where Zones' NPCs are off (self-test).
static var force: bool = false
static var debug: bool = false

## [{"building": Node3D, "type": String, "door": NetDoor, "seats": [{"pos", "yaw", "side", "top"}], "stands":
##   [{"pos", "yaw"}], "dishes": Node3D}]
var places: Array = []
## seat key "p:s" -> item ids on the table ("food,drink"), every peer.
var dishes: Dictionary = {}
## Host: seat key -> Pedestrian; stand key "p:s" -> Pedestrian.
var taken: Dictionary = {}
var guests: int = 0
var served: int = 0
var _t: float = 0.0


static func attach(world: Node) -> void:
	if world == null or world.get_node_or_null(^"DinerLife") or "--no-diners" in OS.get_cmdline_user_args():
		return  # (--no-diners: A-B performance measurements)
	var d := DinerLife.new()
	d.name = "DinerLife"
	world.add_child(d)


func _ready() -> void:
	current = self
	add_to_group(&"net_state")
	_setup.call_deferred()


func _exit_tree() -> void:
	if current == self:
		current = null


func _setup() -> void:
	for i: int in 6:
		await get_tree().physics_frame
	var world: Node = get_parent()
	if world == null:
		return
	var found: Dictionary = {}  # building -> place
	for n: Node in world.find_children("*", "Node3D", true, false):
		var marker: bool = n is Marker3D and str(n.name).begins_with("DinerSeat")
		var chair: bool = _scene_is(n, CHAIRS)
		if not marker and not chair:
			continue
		var b: Node = ShopStaff._building_of(n)
		if b == null:
			continue
		var type: String = ShopTypes.type_for(b)
		if not type in FOOD_TYPES:
			continue
		if (n as Node3D).global_position.y - (b as Node3D).global_position.y > 1.2:
			continue  # (upper floors of a shop building are flats)
		var seat: Dictionary = _seat_of(n as Node3D, marker)
		if seat.is_empty():
			continue
		if not found.has(b):
			found[b] = {"building": b, "type": type, "door": _door_of(b), "seats": [], "stands": []}
		(found[b]["seats"] as Array).append(seat)
	# Bars / snack bars without tables still get guests standing at the counter.
	for sel: ShopSeller in ShopStaff.sellers:
		if is_instance_valid(sel) and sel.shop_type in ["bar", "snack_bar"] and not found.has(sel.get_parent()):
			found[sel.get_parent()] = {"building": sel.get_parent(), "type": sel.shop_type, "door": _door_of(sel.get_parent()),
					"seats": [], "stands": []}
	var keys: Array = found.keys()
	keys.sort_custom(func(a: Node, c: Node) -> bool: return str(a.get_path()) < str(c.get_path()))
	for b: Node in keys:
		var pl: Dictionary = found[b]
		if pl["type"] in ["bar", "snack_bar"]:
			pl["stands"] = _stands_of(b)
		if (pl["seats"] as Array).is_empty() and (pl["stands"] as Array).is_empty():
			continue
		var vis := Node3D.new()
		vis.name = "Dishes%d" % places.size()
		add_child(vis)
		pl["dishes"] = vis
		places.append(pl)
	for key: String in dishes.keys():
		_apply_dish(key, str(dishes[key]))  # (a late joiner's snapshot may have come before the setup)
	if not places.is_empty():
		print("[DinerLife] %d places: %s" % [places.size(), ", ".join(places.map(func(p: Dictionary) -> String:
				return "%s (%s, %d seats, %d at the counter)" % [p["building"].name, p["type"], p["seats"].size(), p["stands"].size()]))])


static func _scene_is(n: Node, names: Array[String]) -> bool:
	var f: String = n.scene_file_path.get_file().get_basename()
	return f != "" and f in names


## A seat: where the guest sits (chair / marker on the floor), which way it looks (to the table), where it stands up
## (beside the chair, away from the table) and the table top in front of it (for the dishes).
func _seat_of(n: Node3D, marker: bool) -> Dictionary:
	var pos: Vector3 = n.global_position
	var look: Vector3
	var space: PhysicsDirectSpaceState3D = n.get_world_3d().direct_space_state
	if marker:
		look = -n.global_basis.z
	else:
		var best: Node3D = null
		for t: Node in n.get_parent().get_children():
			if t is Node3D and _scene_is(t, TABLES) and (t as Node3D).global_position.distance_to(pos) < 1.7:
				if best == null or (t as Node3D).global_position.distance_to(pos) < best.global_position.distance_to(pos):
					best = t as Node3D
		if best == null:
			return {}
		look = best.global_position - pos
	look.y = 0.0
	if look.length() < 0.05:
		return {}
	look = look.normalized()
	var top: Vector3 = pos + look * 0.45
	var q := PhysicsRayQueryParameters3D.create(top + Vector3.UP * 1.5, top + Vector3.DOWN * 0.2, 1)
	var hit: Dictionary = space.intersect_ray(q)
	top = hit["position"] if not hit.is_empty() and float(hit["position"].y) > pos.y + 0.3 else pos + look * 0.45 + Vector3.UP * 0.75
	var side: Vector3 = Vector3(look.z, 0, -look.x)
	# Where to stand up / sit down from: behind or beside the chair, whichever lies on the navmesh (not into a wall).
	var map: RID = n.get_world_3d().navigation_map
	var stand: Vector3 = pos - look * 0.55
	var best: float = INF
	for c: Vector3 in [pos - look * 0.6, pos + side * 0.6, pos - side * 0.6, pos - look * 0.5 + side * 0.5,
			pos - look * 0.5 - side * 0.5]:
		var snap: Vector3 = NavigationServer3D.map_get_closest_point(map, c)
		var d: float = Vector2(snap.x - c.x, snap.z - c.z).length() + absf(snap.y - pos.y) * 2.0
		if d < best:
			best = d
			stand = snap if d < 0.4 else c
	return {"pos": pos, "yaw": atan2(-look.x, -look.z), "stand": stand, "top": top}


func _door_of(b: Node) -> NetDoor:
	for c: Node in b.find_children("*", "Node3D", true, false):
		if c is NetDoor:
			return c as NetDoor
	return null


## Bars / snack bars: two pairs of guests stand and chat in front of the counter (from the seller there, if any).
func _stands_of(b: Node) -> Array:
	var out: Array = []
	var seller: ShopSeller = null
	for c: Node in b.get_children():
		if c is ShopSeller:
			seller = c as ShopSeller
	if seller == null:
		return out
	var fwd: Vector3 = -seller.global_basis.z
	var side: Vector3 = seller.global_basis.x
	var space: PhysicsDirectSpaceState3D = seller.get_world_3d().direct_space_state
	for pair: float in [-1.0, 1.0]:
		var centre: Vector3 = seller.global_position + fwd * 2.4 + side * pair * 1.2
		for k: float in [-1.0, 1.0]:
			var p: Vector3 = centre + side * k * 0.45
			var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.0, p + Vector3.DOWN * 0.5, 1)
			var hit: Dictionary = space.intersect_ray(q)
			if hit.is_empty() or absf(float(hit["position"].y) - seller.global_position.y) > 0.3:
				continue
			var other: Vector3 = centre - side * k * 0.45
			out.append({"pos": hit["position"], "yaw": atan2(-(other - p).x, -(other - p).z)})
	return out


# --- Host ---------------------------------------------------------------------------------------

func _is_host() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()


func _process(delta: float) -> void:
	if places.is_empty() or not _is_host() or not (Zones.npcs_on or force):
		return
	_t -= delta
	if _t > 0.0:
		return
	_t = TICK
	var h: float = _hours()
	var players: Array[Node] = get_tree().get_nodes_in_group(&"players")
	for i: int in places.size():
		var pl: Dictionary = places[i]
		var b := pl["building"] as Node3D
		if not is_instance_valid(b):
			continue
		var near: bool = force
		for p: Node in players:
			if (p as Node3D).global_position.distance_to(b.global_position) < SIM_RANGE:
				near = true
		var share: float = busy(pl["type"], h) if not always_open else 1.0
		share *= float(QualityProfile.value("crowd"))
		var want_seats: int = roundi((pl["seats"] as Array).size() * share) if near else 0
		var want_stands: int = roundi((pl["stands"] as Array).size() * share) if near else 0
		var have: int = 0
		for s: int in (pl["seats"] as Array).size():
			if taken.has("%d:%d" % [i, s]):
				have += 1
		if have < want_seats:
			var free: Array[int] = []
			for s: int in (pl["seats"] as Array).size():
				if not taken.has("%d:%d" % [i, s]):
					free.append(s)
			if not free.is_empty():
				var pick: int = free[randi() % free.size()]
				# Nobody looking (a player just came near / is outside): they are simply already sitting there.
				_guest(i, pick, not _seen((pl["seats"][pick] as Dictionary)["pos"]) and not _seen(b.global_position))
		var standing: int = 0
		for s: int in (pl["stands"] as Array).size():
			if taken.has("%d:s%d" % [i, s]):
				standing += 1
		if standing < want_stands:
			for s: int in (pl["stands"] as Array).size():
				if not taken.has("%d:s%d" % [i, s]):
					_stander(i, s)
					break


func _hours() -> float:
	var dn := get_tree().get_first_node_in_group(&"day_night") as DayNight
	return dn.hours if dn else 12.0


static func busy(type: String, h: float) -> float:
	for r: Array in BUSY.get(type, []):
		for hh: float in [h, h + 24.0]:
			if hh >= float(r[0]) and hh < float(r[1]):
				return float(r[2])
	return 0.0


## Where a guest appears: on the street a few metres along from the door, out of the players' sight if it can.
func _street_spot(pl: Dictionary) -> Vector3:
	var door: NetDoor = pl["door"]
	var b := pl["building"] as Node3D
	var front: Vector3 = (door.get_center() + door.get_outward() * 1.6) if door else b.global_position + b.global_basis.z * 2.0
	var along: Vector3 = (door.global_basis.x if door else b.global_basis.x).normalized()
	var best: Vector3 = front
	for k: int in 6:
		var p: Vector3 = front + along * (1.0 if k % 2 == 0 else -1.0) * randf_range(8.0, 16.0)
		if not _seen(p):
			return p
		best = p
	return best


func _seen(p: Vector3) -> bool:
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var pl := n as Player
		var d: Vector3 = p - pl.global_position
		if d.length() < 6.0:
			return true
		if d.length() < 40.0 and d.normalized().dot(-pl.global_basis.z) > 0.4:
			return true
	return false


func _spawn(pl: Dictionary) -> Pedestrian:
	var at: Vector3 = _street_spot(pl)
	var npc: Pedestrian = Zones.add_resident(at, randf() * TAU, &"diner")
	if npc:
		npc.set_meta(&"diner", true)
		guests += 1
	return npc


## Walk there: over the navmesh, or straight when there is none (city) and the way is free.
func _walk(npc: Pedestrian, to: Vector3) -> bool:
	if not is_instance_valid(npc) or npc.dead or npc.is_fleeing():
		return false
	var map: RID = npc.get_world_3d().navigation_map
	var snap: Vector3 = NavigationServer3D.map_get_closest_point(map, to)
	if debug:
		print("[DinerLife]   %s walk %s -> %s (snap %.2f, clear %s)" % [npc.name, npc.global_position.snapped(Vector3.ONE * 0.1),
				to.snapped(Vector3.ONE * 0.1), snap.distance_to(to), npc.straight_way_clear(to, 40.0)])
	if snap.distance_to(to) < 0.9:
		return await npc.walk_to(snap)
	if npc.straight_way_clear(to, 40.0):
		return await npc._go_direct(to, Pedestrian.Anim.WALK)
	return false


func _in_through(npc: Pedestrian, door: NetDoor, to: Vector3) -> bool:
	if door:
		var front: Vector3 = door.get_center() + door.get_outward() * 1.4
		if not await _walk(npc, front):
			return false
		npc.target_door = door
		if is_instance_valid(npc):
			await npc.idle(0.4)
	var ok: bool = await _walk(npc, to)
	if is_instance_valid(npc):
		npc.target_door = null
	return ok


func _out_through(npc: Pedestrian, door: NetDoor) -> void:
	if door and is_instance_valid(npc):
		npc.target_door = door
		await _walk(npc, door.get_center() - door.get_outward() * 0.8)
		if is_instance_valid(npc):
			await npc.idle(0.3)
		await _walk(npc, door.get_center() + door.get_outward() * 1.6)
		if is_instance_valid(npc):
			npc.target_door = null


## Gone: walk away along the street, then disappear where nobody looks (after 8 s of walking at the latest, or
## 30 s if someone keeps watching - a guest stuck at a door never stays).
func _leave(npc: Pedestrian, pl: Dictionary) -> void:
	if not is_instance_valid(npc):
		return
	if not npc.is_fleeing():
		_walk(npc, _street_spot(pl))  # (not awaited: the loop below watches it)
	for i: int in 60:
		await get_tree().create_timer(0.5).timeout
		if not is_instance_valid(npc):
			return
		if npc.dead:
			return  # (a body: the World's corpse timer clears it)
		if (not npc._moving or i >= 16) and not _seen(npc.global_position):
			break
	if is_instance_valid(npc) and not npc.dead:
		npc.queue_free()


## One seated guest: in, sit, order, eat, out. `already` = appears sitting (nobody watching), half-way through.
func _guest(i: int, s: int, already: bool = false) -> void:
	var key: String = "%d:%d" % [i, s]
	var pl: Dictionary = places[i]
	var seat: Dictionary = pl["seats"][s]
	var npc: Pedestrian = Zones.add_resident(seat["stand"], 0.0, &"diner") if already else _spawn(pl)
	if npc == null:
		return
	if already:
		npc.set_meta(&"diner", true)
		guests += 1
	taken[key] = npc
	await get_tree().physics_frame
	var ok: bool = true if already else await _in_through(npc, pl["door"], seat["stand"])
	if debug:
		print("[DinerLife] %s -> seat %s: %s at %s (stand %s)" % [npc.name if is_instance_valid(npc) else "?", key, ok,
				npc.global_position if is_instance_valid(npc) else Vector3.ZERO, seat["stand"]])
	if ok and is_instance_valid(npc) and not npc.dead and not npc.is_fleeing():
		_sit(npc, seat)
		var stay: float = randf_range(STAY.x, STAY.y) / speed
		var serve: float = 0.2 if already else randf_range(SERVE_AFTER.x, SERVE_AFTER.y) / speed
		if already:
			stay *= randf_range(0.3, 1.0)
		await _sit_for(npc, serve)
		if _still_sitting(npc):
			var order: Array = ORDERS.get(pl["type"], [[""], ["coffee"]])
			var food: String = (order[0] as Array).pick_random()
			var drink: String = (order[1] as Array).pick_random()
			_set_dish(key, "%s,%s" % [food, drink])
			served += 1
			await _sit_for(npc, stay)
		_set_dish(key, "")
		if _still_sitting(npc):
			npc._stand_up()
			npc.anim_state = Pedestrian.Anim.IDLE
			await _out_through(npc, pl["door"])
	else:
		_set_dish(key, "")
	taken.erase(key)
	if is_instance_valid(npc) and not npc.dead:
		await _leave(npc, pl)


## One guest at the counter: in, stand facing their mate, chat (TALK now and then), out.
func _stander(i: int, s: int) -> void:
	var key: String = "%d:s%d" % [i, s]
	var pl: Dictionary = places[i]
	var spot: Dictionary = pl["stands"][s]
	var npc: Pedestrian = _spawn(pl)
	if npc == null:
		return
	taken[key] = npc
	await get_tree().physics_frame
	if await _in_through(npc, pl["door"], spot["pos"]) and is_instance_valid(npc):
		npc.rotation.y = spot["yaw"]
		npc.net_yaw = spot["yaw"]
		var until: float = Time.get_ticks_msec() / 1000.0 + randf_range(STAY.x, STAY.y) / speed
		while is_instance_valid(npc) and not npc.dead and not npc.is_fleeing() and Time.get_ticks_msec() / 1000.0 < until:
			npc.anim_state = Pedestrian.Anim.TALK if randf() < 0.5 else Pedestrian.Anim.IDLE
			await get_tree().create_timer(randf_range(2.0, 5.0) / speed).timeout
		if is_instance_valid(npc) and not npc.dead and not npc.is_fleeing():
			npc.anim_state = Pedestrian.Anim.IDLE
			await _out_through(npc, pl["door"])
	taken.erase(key)
	if is_instance_valid(npc) and not npc.dead:
		await _leave(npc, pl)


func _sit(npc: Pedestrian, seat: Dictionary) -> void:
	var look: Vector3 = Vector3(-sin(float(seat["yaw"])), 0, -cos(float(seat["yaw"])))
	npc._sitting = true
	npc._sit_front = seat["stand"]
	npc.collision.disabled = true
	npc.global_position = (seat["pos"] as Vector3) + look * Pedestrian.SIT_OFFSET + Vector3.UP * Pedestrian.SIT_HEIGHT
	npc.rotation.y = seat["yaw"]
	npc.net_pos = npc.global_position
	npc.net_yaw = npc.rotation.y
	npc.anim_state = Pedestrian.Anim.SIT


## Waits `seconds`, but stops at once when the guest is no longer sitting (a gunshot, killed).
func _sit_for(npc: Pedestrian, seconds: float) -> void:
	var until: float = Time.get_ticks_msec() / 1000.0 + seconds
	while Time.get_ticks_msec() / 1000.0 < until and _still_sitting(npc):
		await get_tree().create_timer(minf(0.25, seconds)).timeout


func _still_sitting(npc: Pedestrian) -> bool:
	return is_instance_valid(npc) and not npc.dead and npc._sitting and not npc.is_fleeing()


# --- Dishes (every peer) ------------------------------------------------------------------------

func _set_dish(key: String, what: String) -> void:
	if str(dishes.get(key, "")) == what:
		return
	if multiplayer.has_multiplayer_peer():
		_dish_rpc.rpc(key, what)
	else:
		_apply_dish(key, what)


@rpc("authority", "call_local", "reliable")
func _dish_rpc(key: String, what: String) -> void:
	_apply_dish(key, what)


func _apply_dish(key: String, what: String) -> void:
	if what == "":
		dishes.erase(key)
	else:
		dishes[key] = what
	var parts: PackedStringArray = key.split(":")
	var i: int = int(parts[0])
	if i >= places.size():
		return
	var vis: Node3D = places[i]["dishes"]
	var node_name: String = "Seat" + parts[1]
	var old: Node = vis.get_node_or_null(node_name)
	if old:
		vis.remove_child(old)
		old.queue_free()
	if what == "" or DisplayServer.get_name() == "headless":
		return
	var seat: Dictionary = places[i]["seats"][int(parts[1])]
	var holder := Node3D.new()
	holder.name = node_name
	vis.add_child(holder)
	var look: Vector3 = Vector3(-sin(float(seat["yaw"])), 0, -cos(float(seat["yaw"])))
	var side: Vector3 = Vector3(look.z, 0, -look.x)
	var ids: PackedStringArray = what.split(",")
	for k: int in ids.size():
		if ids[k] == "":
			continue
		var g := ProcGoods.new()
		g.kind = ids[k]
		holder.add_child(g)
		g.global_position = (seat["top"] as Vector3) + side * (0.0 if k == 0 else 0.16) + look * (0.0 if k == 0 else 0.06)
		g.rotation.y = float(seat["yaw"])
		g.scale = Vector3.ONE * (0.9 if k == 0 else 0.8)


func get_net_state() -> Dictionary:
	return {"dishes": dishes.duplicate()}


func apply_net_state(st: Dictionary) -> void:
	for key: String in (st.get("dishes", {}) as Dictionary):
		_apply_dish(key, str(st["dishes"][key]))
