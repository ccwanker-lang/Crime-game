class_name DayRhythm
extends Node
## Roadmap 88 (session B): the village's ambient pedestrians live by the clock. Each one belongs to a time block
## (`DayRhythmConfig`: morning / afternoon / evening / night) and a house; outside its block it is "inside" (data
## only, no node). At the end of its block it walks to its front door and goes in; at the start of the next it steps
## out of its door (never right in front of a player's eyes). Home deliveries: a customer can be someone at home -
## they step out of the door, deal, and go back in. Host only; clients get the pedestrians from World/NPCSpawner.
## Made by World.spawn_pedestrians (not in the self-test, which spawns its own; `--no-rhythm` = the old fixed crowd).

enum State { INSIDE, OUT, HOMEWARD, DEAL }

const CONFIG_PATH: String = "res://data/npc/day_rhythm.tres"
const PEDESTRIAN_SCENE: String = "res://prefabs/npc/pedestrian.tscn"
const META: StringName = &"rhythm"

static var current: DayRhythm = null

var config: DayRhythmConfig
## The host's records: {id, block, home, state, npc, since, back}.
var people: Array[Dictionary] = []
## Front doors: {door (navmesh point on the step), out (outward dir), building}.
var homes: Array[Dictionary] = []
## Busiest-block outside count (World passes `--npcs=N` here).
var outside_busiest: int = -1
var _timer: float = 0.0
var _started: bool = false


static func wanted() -> bool:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	return not "--selftest" in args and not "--no-rhythm" in args


func _ready() -> void:
	current = self
	config = load(CONFIG_PATH) as DayRhythmConfig
	if config == null:
		config = DayRhythmConfig.new()
	if outside_busiest < 0:
		outside_busiest = config.outside_busiest


func _exit_tree() -> void:
	if current == self:
		current = null


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	if not _started:
		var region := get_parent().get("nav_region") as NavigationRegion3D if get_parent() else null
		if region and (NavigationServer3D.map_get_iteration_id(region.get_navigation_map()) == 0
				or region.navigation_mesh == null or region.navigation_mesh.get_polygon_count() == 0):
			return  # wait for the navmesh (front doors are looked up on it)
		_started = true
		_build()
		_tick(true)
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = config.interval
	_tick(false)


# --- Setup ----------------------------------------------------------------------

## The population and every house front door the navmesh reaches.
func _build() -> void:
	homes = find_homes(get_parent() as Node3D)
	var biggest: float = 0.0
	for s: float in config.block_share:
		biggest = maxf(biggest, s)
	var total: int = roundi(outside_busiest / maxf(biggest, 0.01))
	var rng := RandomNumberGenerator.new()
	rng.seed = 880088
	var id: int = 0
	for b: int in config.block_share.size():
		var n: int = roundi(total * config.block_share[b])
		for i: int in n:
			people.append({"id": id, "block": b, "home": rng.randi() % maxi(homes.size(), 1), "state": State.INSIDE,
					"npc": null, "since": 0.0, "back": 0.0})
			id += 1
	print("[DayRhythm] %d people in %d homes (%s), busiest block %d outside" % [people.size(), homes.size(),
			", ".join(Array(config.block_names).map(func(n: String) -> String: return "%s %d" % [n, count_block(n)])),
			outside_busiest])


## Every residential Building's front door with a navmesh point on its step.
static func find_homes(world: Node3D) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if world == null:
		return out
	var region := world.get("nav_region") as NavigationRegion3D
	var map: RID = region.get_navigation_map() if region else world.get_world_3d().navigation_map
	var stats: Dictionary = {"buildings": 0, "no_door": 0, "no_nav": 0}
	var stack: Array[Node] = [world]
	var buildings: Array[Building] = []
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Building:
			buildings.append(n as Building)
			continue
		stack.append_array(n.get_children())
	for b: Building in buildings:
		stats["buildings"] += 1
		if not b.is_visible_in_tree() or b.door_bay < 0 or b.ground_floor != "residential" or b.public_building:
			stats["no_door"] += 1
			continue
		var bay_count: int = b.bays if b.bays > 0 else maxi(1, roundi(b.width / 2.4))
		if b.door_bay >= bay_count:
			continue
		var x: float = -b.width / 2.0 + (b.door_bay + 0.5) * b.width / bay_count
		var door: Vector3 = b.global_transform * Vector3(x, 0, 0)
		var outward: Vector3 = b.global_basis.z
		outward.y = 0.0
		if outward.length() < 0.01:
			continue
		outward = outward.normalized()
		if Zones.zone_at(door) != &"":
			stats["no_door"] += 1  # army base / slums / city / bunker: Zones has its own people there
			continue
		var want: Vector3 = door + outward * 0.9
		var nav: Vector3 = NavigationServer3D.map_get_closest_point(map, want)
		if Vector2(nav.x - want.x, nav.z - want.z).length() > 1.0 or absf(nav.y - want.y) > 0.7:
			stats["no_nav"] += 1
			continue
		out.append({"door": nav, "out": outward, "building": b})
	print("[DayRhythm] homes: %d of %s" % [out.size(), stats])
	return out


# --- The clock ------------------------------------------------------------------

func hours() -> float:
	var dn := get_tree().get_first_node_in_group(&"day_night") as DayNight
	return dn.hours if dn else 12.0


## Index of the block `h` falls in.
func block_at(h: float) -> int:
	var starts: PackedFloat32Array = config.block_start
	var best: int = starts.size() - 1  # before the first start = the last block (wraps round midnight)
	for i: int in starts.size():
		if h >= starts[i]:
			best = i
	return best


func block_name(i: int) -> String:
	return config.block_names[i] if i >= 0 and i < config.block_names.size() else "?"


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _tick(first: bool) -> void:
	var block: int = block_at(hours())
	for r: Dictionary in people:
		var npc := r["npc"] as Pedestrian if is_instance_valid(r["npc"]) else null
		if npc and npc.is_queued_for_deletion():
			npc = null
		var state: int = r["state"]
		if state != State.INSIDE and (npc == null or npc.dead):
			# Died (or freed by someone else): back out of the door after a while.
			r["npc"] = null
			r["state"] = State.INSIDE
			r["back"] = _now() + config.respawn_time
			continue
		match state:
			State.INSIDE:
				if int(r["block"]) == block and _now() >= float(r["back"]) and not homes.is_empty():
					if first:
						_come_out(r, Pedestrian.random_sidewalk_point(get_parent() as Node3D))
					else:
						_come_out(r, Vector3.INF)
			State.OUT:
				if int(r["block"]) != block and npc.wants <= 0:
					if npc.lod == Pedestrian.Lod.ASLEEP:
						_go_in(r)  # far from everyone: just data again
					else:
						r["state"] = State.HOMEWARD
						r["since"] = _now()
						npc.call_home(home_of(r)["door"])
			State.HOMEWARD:
				if npc.home_reached or npc.lod == Pedestrian.Lod.ASLEEP or _at_door(npc) \
						or (_now() - float(r["since"]) > config.go_home_timeout and not _seen(npc.global_position)):
					_go_in(r)
				elif int(r["block"]) == block:
					# Its block came round again before it got home (time skipped): carry on outside.
					npc.call_home(Vector3.INF)
					r["state"] = State.OUT
			State.DEAL:
				if npc.wants <= 0 and not npc.is_fleeing():
					if npc.home_call == Vector3.INF:
						r["since"] = _now()
						npc.call_home(home_of(r)["door"])
						_walk_home(npc)
					elif npc.home_reached or npc.lod == Pedestrian.Lod.ASLEEP or _at_door(npc) \
							or (_now() - float(r["since"]) > config.go_home_timeout and not _seen(npc.global_position)):
						_go_in(r)


## On its own doorstep (a walk that ends a hair short still counts).
func _at_door(npc: Pedestrian) -> bool:
	var d: Vector3 = npc.home_call - npc.global_position
	return npc.home_call != Vector3.INF and Vector2(d.x, d.z).length() < 1.2 and absf(d.y) < 1.0


func home_of(r: Dictionary) -> Dictionary:
	return homes[int(r["home"]) % homes.size()] if not homes.is_empty() else {}


## Spawns the record's pedestrian: at `at`, or else stepping out of its front door (not while a player looks).
func _come_out(r: Dictionary, at: Vector3, ambient: bool = true) -> Pedestrian:
	var home: Dictionary = home_of(r)
	var door: bool = at == Vector3.INF
	var pos: Vector3 = home["door"] if door else at
	if door and _seen(pos):
		return null
	var world := get_parent() as Node3D
	var parent: Node = world.get("npcs") as Node if world else null
	if parent == null:
		return null
	var npc: Pedestrian = (load(PEDESTRIAN_SCENE) as PackedScene).instantiate()
	npc.variant = int(r["id"]) % Pedestrian.VARIANTS.size()
	npc.color_seed = hash(int(r["id"]) * 7919)
	npc.ambient = ambient
	npc.position = pos
	var out: Vector3 = home["out"]
	npc.rotation.y = atan2(-out.x, -out.z) if door else randf() * TAU
	npc.set_meta(META, int(r["id"]))
	parent.add_child(npc, true)
	r["npc"] = npc
	r["state"] = State.OUT
	r["since"] = _now()
	r["spawned_at"] = pos
	return npc


## Back inside: the node goes, the record stays.
func _go_in(r: Dictionary) -> void:
	var npc := r["npc"] as Pedestrian if is_instance_valid(r["npc"]) else null
	if npc:
		npc.queue_free()  # NPCSpawner removes it on the clients too
	r["npc"] = null
	r["state"] = State.INSIDE
	r["back"] = 0.0


## A non-wandering pedestrian (home deal) walks its own way home.
func _walk_home(npc: Pedestrian) -> void:
	if npc.ambient:
		return  # the wander loop does it
	var ok: bool = await npc.walk_to(npc.home_call)
	if is_instance_valid(npc):
		npc.home_reached = ok


## Would a player see `pos` pop up? (Close and inside the view cone, or right next to them.)
func _seen(pos: Vector3) -> bool:
	var world := get_parent() as Node3D
	var players: Node = world.get("players_root") as Node if world else null
	if players == null:
		return false
	var cos_half: float = cos(deg_to_rad(config.view_half_angle))
	for n: Node in players.get_children():
		var p := n as Player
		if p == null:
			continue
		var to: Vector3 = pos - p.global_position
		to.y = 0.0
		var d: float = to.length()
		if d < 4.0:
			return true
		if d > config.no_pop_radius:
			continue
		var fwd: Vector3 = -p.head.global_basis.z if p.head else -p.global_basis.z
		fwd.y = 0.0
		if fwd.length() > 0.01 and fwd.normalized().dot(to / d) > cos_half:
			return true
	return false


# --- Home deliveries ------------------------------------------------------------

## Host (World.make_customer): someone at home whose door is near a player steps out to deal. Null = nobody.
func home_customer() -> Pedestrian:
	var world := get_parent() as Node3D
	var players: Node = world.get("players_root") as Node if world else null
	if players == null or homes.is_empty():
		return null
	var options: Array[Dictionary] = []
	for r: Dictionary in people:
		if int(r["state"]) != State.INSIDE or _now() < float(r["back"]):
			continue
		var door: Vector3 = home_of(r)["door"]
		for n: Node in players.get_children():
			var d: float = (n as Node3D).global_position.distance_to(door)
			if d < config.home_deal_range and d > 8.0:
				options.append(r)
				break
	options.shuffle()
	for r: Dictionary in options:
		var npc: Pedestrian = _come_out(r, Vector3.INF, false)
		if npc:
			r["state"] = State.DEAL
			var home: Dictionary = home_of(r)
			npc.walk_to.call_deferred(home["door"] + (home["out"] as Vector3) * 1.6)
			print("[DayRhythm] %s steps out of their door for a deal" % npc.name)
			return npc
	return null


# --- Tests / debug --------------------------------------------------------------

func count_block(block_name_: String) -> int:
	var b: int = Array(config.block_names).find(block_name_)
	return people.filter(func(r: Dictionary) -> bool: return int(r["block"]) == b).size()


## {state name: count} of the records (+ "nodes" = live pedestrians).
func status() -> Dictionary:
	var out: Dictionary = {"inside": 0, "out": 0, "homeward": 0, "deal": 0}
	var names: Array[String] = ["inside", "out", "homeward", "deal"]
	for r: Dictionary in people:
		out[names[int(r["state"])]] += 1
	return out


func record_of(npc: Node) -> Dictionary:
	if npc == null or not npc.has_meta(META):
		return {}
	var id: int = int(npc.get_meta(META))
	return people[id] if id >= 0 and id < people.size() else {}
