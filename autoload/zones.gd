extends Node
## Zones (session B, NOTES part 18), autoload `Zones`: the systems of A's map zones (DESIGN "Map layout").
## - Fort Halden (army base, zone 2): guards (`Soldier`) at the gate, on the watchtowers and on the parade ground; a
##   player at the boom gets a warning; whoever goes inside the fence or shoots a soldier is shot, and the base raises
##   the ALARM: heavy reinforcements come out of the barracks (their own response, no police stars).
## - Rosehill Park (slums, zone 3): poor residents round the fire barrels; some become customers who pay less.
## - The city (zone 7): office workers in front of the towers by day; customers who pay more.
## - The bunker (zone 8): A's BunkerComplex (Mountain/Bunker); here: for sale (BUNKER_PRICE, rank gate in RankConfig),
##   the blast door stays locked until the crew owns it, never raided (Raids.RAID_FREE).
## HOST AUTHORITATIVE: the NPCs are normal networked Pedestrians / Soldiers (World/NPCSpawner; the soldier scene is
## added to its spawnable list on every peer). No map files are touched: places come from A's nodes (ArmyBase,
## Watchtower*, Barracks*, FireBarrel*, Tower*), with fixed fallbacks.

const SOLDIER_SCENE: String = "res://prefabs/npc/soldier.tscn"
const PEDESTRIAN_SCENE: String = "res://prefabs/npc/pedestrian.tscn"
## World rectangles (x0, z0, w, d) from DESIGN "Map layout".
const ARMY_RECT: Rect2 = Rect2(-104.0, -442.0, 340.0, 92.0)  # (A's point 85: the fence now takes in the airfield east of the old base)
const SLUM_RECT: Rect2 = Rect2(-108.0, -132.0, 183.0, 68.0)
const CITY_RECT: Rect2 = Rect2(-65.0, 130.0, 180.0, 240.0)
## The boom gate on the west fence (the pass road ends here).
const ARMY_GATE: Vector3 = Vector3(-104.0, 0.1, -355.6)
const GATE_WARN_RANGE: float = 16.0
const WARN_EVERY: float = 15.0
const HOSTILE_TIME: float = 90.0
const ALARM_TIME: float = 60.0
const REINFORCEMENTS: int = 4
const GUARD_RESPAWN: float = 180.0
## Part 21: the base is manned while a player is this close (m from the fence), emptied past ARMY_LEAVE_RANGE.
const ARMY_MAN_RANGE: float = 220.0
const ARMY_LEAVE_RANGE: float = 300.0
## Customer price factor per zone (the rest of the map = 1.0).
const PRICE: Dictionary = {&"slums": 0.6, &"city": 1.5}
const ZONE_NAMES: Dictionary = {&"army": "Fort Halden", &"slums": "Rosehill Park", &"city": "the city",
		&"bunker": "the bunker", &"": "the village"}
const CUSTOMER_TIME: float = 300.0
## Zone NPCs only while a player is this close to the zone (and gone again past DESPAWN_RANGE).
const SPAWN_RANGE: float = 150.0
const DESPAWN_RANGE: float = 220.0
const CUSTOMER_EVERY: Vector2 = Vector2(40.0, 90.0)
## City office workers: from / until (in-game hours).
const OFFICE_HOURS: Vector2 = Vector2(7.0, 20.0)

## Host: soldiers at the base. Off in the self-test / netcheck (the check turns them on).
var army_on: bool = true
## Host: residents (slums) + office workers (city). Off in the self-test / netcheck.
var npcs_on: bool = true
## Host: lock the bunker's blast door while the crew doesn't own it. Off in the self-test / netcheck and in test
## scenarios (A's bunker checks walk in); `bunker_lock_forced` (my check / scenario) turns it on anyway.
var bunker_lock_on: bool = true
var bunker_lock_forced: bool:
	get:
		return bool(GameState.world.get("bunker_lock", false))  # (per game: a fresh scenario forgets it)
	set(v):
		GameState.world["bunker_lock"] = v

## Every peer: A's bunker property (Mountain/Bunker/Property), set up for sale by `_setup_bunker`.
static var bunker: BunkerProperty
const BUNKER_PRICE: int = 250000
const BUNKER_TEXT: String = "A cold-war bunker deep under the pass: a vehicle lift, a big lab hall, storage, bunks. No neighbours, no raids. Reached by the side road off the summit."
var _world: Node3D
var _scan: float = 0.0
var _hostile: Dictionary = {}   # Player -> until (s)
var _warned: Dictionary = {}    # Player -> last warning (s)
var _passes: Dictionary = {}    # Player -> until (s): missions may let someone in
var _alarm_until: float = -1.0
var alarms: int = 0
var _guards: Dictionary = {}    # post index -> Soldier
var _posts: Array = []          # [{pos, yaw}]
var _reinforcements: Array = []
var _residents: Dictionary = {} # spot key -> {npc, pos, yaw, zone}
var _next_customer: Dictionary = {&"slums": 0.0, &"city": 0.0}
var _spot_cache: Dictionary = {}


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--selftest" in args or "--netcheck" in args:
		army_on = false
		npcs_on = false
		bunker_lock_on = false
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(n: Node) -> void:
	# Every peer: the soldier scene may be spawned by the host's NPCSpawner.
	if n is MultiplayerSpawner and n.name == &"NPCSpawner":
		(n as MultiplayerSpawner).add_spawnable_scene(SOLDIER_SCENE)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _is_host() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()


# --- Zones ---------------------------------------------------------------------------------------

static func zone_at(pos: Vector3) -> StringName:
	var p := Vector2(pos.x, pos.z)
	if ARMY_RECT.has_point(p):
		return &"army"
	if SLUM_RECT.has_point(p):
		return &"slums"
	if CITY_RECT.has_point(p):
		return &"city"
	if bunker and is_instance_valid(bunker) and bunker.contains(pos):
		return &"bunker"
	return &""


static func zone_name(pos: Vector3) -> String:
	return ZONE_NAMES.get(zone_at(pos), "the village")


static func in_army_base(pos: Vector3) -> bool:
	return ARMY_RECT.has_point(Vector2(pos.x, pos.z))


static func near_army_base(pos: Vector3, margin: float) -> bool:
	return ARMY_RECT.grow(margin).has_point(Vector2(pos.x, pos.z))


## Customer price in a zone (A's World.make_customer may call this for any customer: request in B.md).
func customer_price(npc: Node3D, price: int) -> int:
	var zone: StringName = npc.get_meta(&"zone", zone_at(npc.global_position))  # (own residents: their zone)
	return roundi(price * float(PRICE.get(zone, 1.0)))


# --- Main loop -----------------------------------------------------------------------------------

func _process(delta: float) -> void:
	var scene: Node = get_tree().current_scene
	if scene == null or scene.get_node_or_null("Players") == null:
		_world = null
		return
	if _world != scene:
		_world = scene as Node3D
		_on_world()
	_scan -= delta
	if _scan > 0.0:
		return
	_scan = 0.5
	if not _is_host():
		return
	_bunker_door_tick()
	if army_on:
		_army_tick()
	if npcs_on:
		_residents_tick()


## Every peer: a new World.
func _on_world() -> void:
	_hostile.clear()
	_warned.clear()
	_passes.clear()
	_guards.clear()
	_reinforcements.clear()
	_residents.clear()
	_spot_cache.clear()
	_city_traffic = false
	_alarm_until = -1.0
	_posts = []
	bunker = null
	_setup_bunker.call_deferred()


## Every peer (the same on all of them): A's bunker property becomes a buyable one.
func _setup_bunker() -> void:
	var mountain: Node = _world.get_node_or_null("Mountain") if _world else null
	var prop := mountain.get_node_or_null("Bunker/Property") as BunkerProperty if mountain else null
	if prop == null:
		return
	bunker = prop
	prop.display_name = "Mountain Bunker"
	prop.for_sale = true
	prop.price = BUNKER_PRICE
	prop.description = BUNKER_TEXT
	if prop.has_method("_update_label"):
		prop._update_label()
	_bunker_door_tick()


func bunker_door() -> BunkerDoor:
	return bunker.get_parent().get_node_or_null("Door") as BunkerDoor if bunker and is_instance_valid(bunker) else null


## Host: the blast door is locked unless the crew owns the bunker.
func _bunker_door_tick() -> void:
	if not _is_host():
		return
	var door: BunkerDoor = bunker_door()
	if door == null or not (bunker_lock_forced or (bunker_lock_on and not SaveManager.scenario_mode)):
		return
	var lock: bool = not bunker.is_crew_owned()
	if door.locked != lock:
		door.host_set_locked(lock)
		print("[Zones] bunker door %s" % ("locked" if lock else "unlocked"))


func _npcs() -> Node:
	return _world.get_node_or_null("NPCs") if _world else null


func _players() -> Array[Player]:
	var out: Array[Player] = []
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p := n as Player
		if p and not p.dead and p.is_inside_tree():
			out.append(p)
	return out


func _message(p: Player, text: String) -> void:
	if p.has_method("show_message"):
		p.show_message(text)


# --- Fort Halden ---------------------------------------------------------------------------------

## The guard posts: gate (2), the watchtower platforms, the parade ground (2).
func guard_posts() -> Array:
	if not _posts.is_empty() or _world == null:
		return _posts
	var base: Node = _world.get_node_or_null("ArmyBase")
	# A's markers win (ask in B.md): ArmyPost* (Marker3D: a guard looking along -Z), ArmyPatrolA1.. / B1.. (points).
	var face_west: float = PI / 2.0
	var at := func(x: float, z: float) -> Vector3: return Vector3(x, 0.1, z)
	var add := func(pos: Vector3, yaw: float, extra: Dictionary) -> void:
		var d: Dictionary = {"pos": pos, "yaw": yaw}
		d.merge(extra)
		_posts.append(d)
	var markers: Array[Node] = _world.find_children("ArmyPost*", "Node3D", true, false) if base else []
	if not markers.is_empty():
		for m: Node in markers:
			var m3 := m as Node3D
			add.call(m3.global_position, m3.global_rotation.y, {"chatty": str(m.name).contains("Chat")})
	else:
		# The gate: one outside by the boom, one inside watching the yard side of the gate.
		add.call(at.call(-106.5, -350.4), face_west, {"gate": true})
		add.call(at.call(-100.5, -361.5), face_west, {"gate": true})
		# The flag: an honour guard of two.
		add.call(at.call(-72.5, -360.5), PI, {})
		add.call(at.call(-67.5, -360.5), PI, {})
		# The hangars: mechanics / guards chatting in front of the doors.
		for hx: float in [-90.0, -64.0]:
			add.call(at.call(hx - 2.0, -382.5), -PI / 2.0, {"chatty": true})
			add.call(at.call(hx - 0.6, -382.5), PI / 2.0, {"chatty": true})
		# The helipads and the vehicle row.
		add.call(at.call(-49.5, -386.5), PI * 0.75, {"chatty": true})
		add.call(at.call(-48.3, -387.4), -PI * 0.25, {"chatty": true})
		add.call(at.call(-40.5, -398.5), PI, {})
		add.call(at.call(-89.0, -366.5), 0.0, {})
		add.call(at.call(-69.5, -365.5), 0.0, {})
	# Marksmen on top of every watchtower (sniper rifle).
	var space: PhysicsDirectSpaceState3D = _world.get_world_3d().direct_space_state
	if base:
		var centre := Vector3(ARMY_RECT.get_center().x, 0, ARMY_RECT.get_center().y)
		for t: Node in base.find_children("Watchtower*", "", false, false):
			var tw := t as Node3D
			var h: float = float(tw.get("height")) if tw.get("height") != null else 8.0
			var from: Vector3 = tw.global_position + Vector3.UP * (h + 1.0)
			var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 3.0, 1))
			var top: Vector3 = (hit["position"] as Vector3) + Vector3.UP * 0.05 if not hit.is_empty() else tw.global_position + Vector3.UP * h
			var out: Vector3 = tw.global_position - centre
			add.call(top, atan2(-out.x, -out.z), {"tower": true, "gun": &"sniper"})
	# Two patrols of two (A: round the inner yard, B: round the hangars - the front, the helipads, the lane between
	# the hangars (back wall z -405) and the barracks (front z -412)).
	for route_name: String in ["A", "B"]:
		var pts: Array[Vector3] = []
		for m: Node in _world.find_children("ArmyPatrol%s*" % route_name, "Node3D", true, false):
			pts.append((m as Node3D).global_position)
		if pts.is_empty():
			if route_name == "A":
				pts = [at.call(-98.0, -357.5), at.call(-98.0, -377.0), at.call(-57.0, -377.0), at.call(-57.0, -357.5)]
			else:
				pts = [at.call(-41.0, -384.0), at.call(-41.0, -408.5), at.call(-101.0, -408.5), at.call(-101.0, -384.0)]
		for k: int in 2:
			var start: int = k * (pts.size() / 2)
			var route: Array[Vector3] = []
			for i: int in pts.size():
				route.append(pts[(start + i) % pts.size()] + Vector3(0.9 * k, 0, 0.9 * k))
			add.call(route[0], 0.0, {"route": route})
	return _posts


## Is a player near enough for the base to be manned (or the alarm still on)?
func _army_wanted(dist: float) -> bool:
	if alarm_on():
		return true
	for p: Player in _players():
		if near_army_base(p.global_position, dist):
			return true
	return false


func _army_tick() -> void:
	if _world == null or _world.get_node_or_null("ArmyBase") == null:
		return
	var t: float = _now()
	# Part 21: manned only while someone is near (saves the host the AI of 20 soldiers); a dead guard is replaced
	# after GUARD_RESPAWN.
	var posts: Array = guard_posts()
	if not _army_wanted(ARMY_MAN_RANGE):
		if not _army_wanted(ARMY_LEAVE_RANGE):
			for i: int in _guards.keys():
				var g0: Variant = _guards[i]
				if g0 is Soldier and is_instance_valid(g0) and (g0 as Soldier).target == null:
					(g0 as Soldier).queue_free()
					_guards.erase(i)
		return
	for i: int in posts.size():
		var g: Variant = _guards.get(i)
		if g is Soldier and is_instance_valid(g):
			continue
		if g is float and t < float(g):
			continue
		var post: Dictionary = posts[i]
		var s: Soldier = spawn_soldier(post["pos"], post["yaw"], false, post.get("gun", &"ak47"))
		if s:
			s.chatty = post.get("chatty", false)
			s.route.assign(post.get("route", []))
		_guards[i] = s
	for p: Player in _players():
		if _passes.get(p, 0.0) > t:
			continue
		if in_army_base(p.global_position):
			army_hostile(p, "inside the base")
		elif p.global_position.distance_to(ARMY_GATE) < GATE_WARN_RANGE and not is_army_hostile(p):
			if t - float(_warned.get(p, -100.0)) > WARN_EVERY:
				_warned[p] = t
				_message(p, "Gate guard: \"HALT! Military area. Turn around now or we open fire.\"")
				print("[Army] warned %s at the gate" % p.player_name)
				for g: Variant in _guards.values():
					var s := g as Soldier
					if s and is_instance_valid(s) and s.global_position.distance_to(ARMY_GATE) < 12.0 and s.target == null:
						s.face(p.global_position)
						s.anim_state = Pedestrian.Anim.AIM
	if alarm_on():
		for p: Player in _players():
			if is_army_hostile(p) and near_army_base(p.global_position, 20.0):
				_alarm_until = t + ALARM_TIME


## Host: one soldier at `pos` (post look direction `yaw`).
func spawn_soldier(pos: Vector3, yaw: float, reinforce: bool, gun: StringName = &"ak47") -> Soldier:
	var npcs: Node = _npcs()
	if npcs == null:
		return null
	var s: Soldier = (load(SOLDIER_SCENE) as PackedScene).instantiate()
	s.variant = PoliceOfficer.VARIANT
	s.color_seed = randi()
	s.heavy = reinforce
	s.reinforcement = reinforce
	s.gun = gun
	s.position = pos
	s.rotation.y = yaw
	s.post_yaw = yaw
	s.home = pos
	npcs.add_child(s, true)
	return s


## Host: `p` is an enemy of the base now (inside the fence / shot a soldier): every soldier who sees them shoots,
## and the alarm brings the reinforcements.
func army_hostile(p: Player, why: String) -> void:
	if p == null or _passes.get(p, 0.0) > _now():
		return
	var was: bool = is_army_hostile(p)
	_hostile[p] = _now() + HOSTILE_TIME
	if not was:
		print("[Army] %s is hostile (%s)" % [p.player_name, why])
		_message(p, "ALARM at Fort Halden! Soldiers are coming for you.")
	# Guards near the trouble turn round and go for it too (the gate guards face outward, the fence blocks their view).
	for g: Variant in _guards.values():
		var s := g as Soldier
		if s and is_instance_valid(s) and not s.dead and s.target == null and s.global_position.distance_to(p.global_position) < 40.0:
			s._alert(p, p.global_position)
	_start_alarm(p)


func is_army_hostile(p: Player) -> bool:
	return float(_hostile.get(p, -1.0)) > _now()


func alarm_on() -> bool:
	return _now() < _alarm_until


## Missions: let `p` in for `seconds` without the soldiers shooting.
func allow_army(p: Player, seconds: float) -> void:
	_passes[p] = _now() + seconds
	_hostile.erase(p)


func _start_alarm(p: Player) -> void:
	var fresh: bool = not alarm_on()
	_alarm_until = _now() + ALARM_TIME
	if not fresh:
		return
	alarms += 1
	print("[Army] ALARM (%d): reinforcements out of the barracks" % alarms)
	var base: Node = _world.get_node_or_null("ArmyBase") if _world else null
	var spots: Array[Vector3] = []
	if base:
		for b: Node in base.find_children("Barracks*", "", false, false):
			var b3 := b as Node3D
			spots.append(b3.global_position + (Vector3(-70, 0, -390) - b3.global_position).normalized() * 9.0 + Vector3.UP * 0.1)
	if spots.is_empty():
		spots.append(Vector3(-70.0, 0.1, -395.0))
	for i: int in REINFORCEMENTS:
		var at: Vector3 = spots[i % spots.size()] + Vector3(i * 0.9, 0, 0)
		var s: Soldier = spawn_soldier(at, PI / 2.0, true)
		if s:
			s.home = at
			_reinforcements.append(s)
			s._alert(p, p.global_position)
			s.send_to.call_deferred(p.global_position)


## Host (Soldier): a reinforcement is back after the alarm: gone.
func dismiss(s: Soldier) -> void:
	_reinforcements.erase(s)
	s.queue_free()


func reinforcements() -> Array:
	return _reinforcements.filter(func(s: Variant) -> bool: return is_instance_valid(s) and not (s as Soldier).dead)


func guards() -> Array:
	return _guards.values().filter(func(s: Variant) -> bool: return s is Soldier and is_instance_valid(s) and not (s as Soldier).dead)


## Host (Soldier._on_died): a guard post gets a new guard after GUARD_RESPAWN.
func soldier_died(s: Soldier) -> void:
	_reinforcements.erase(s)
	for i: Variant in _guards.keys():
		if _guards[i] == s:
			_guards[i] = _now() + GUARD_RESPAWN


# --- Residents (slums) + office workers (city) ---------------------------------------------------

## Spots for the slum residents: round every fire barrel (2-3 each).
func slum_spots() -> Array:
	if _spot_cache.has(&"slums"):
		return _spot_cache[&"slums"]
	var out: Array = []
	if _world == null:
		return out
	_spot_cache[&"slums"] = out
	for b: Node in _world.find_children("FireBarrel*", "", true, false):
		var c: Vector3 = (b as Node3D).global_position
		var n: int = 2 + (hash(b.name) % 2)
		for i: int in n:
			var a: float = TAU * i / n + float(hash(b.name) % 100) * 0.01
			var pos: Vector3 = c + Vector3(cos(a), 0, sin(a)) * 1.35
			var d: Vector3 = c - pos
			out.append({"key": "%s_%d" % [b.name, i], "pos": Vector3(pos.x, c.y + 0.1, pos.z), "yaw": atan2(-d.x, -d.z), "zone": &"slums"})
	return out


## Spots for the city (part 21, `CityLife.spots`): office groups, apartment doors, bus stops, benches, walkers.
func city_spots() -> Array:
	if _spot_cache.has(&"city"):
		return _spot_cache[&"city"]
	var out: Array = CityLife.spots(_world) if _world else []
	_spot_cache[&"city"] = out
	return out


func _zone_near(rect: Rect2, players: Array[Player], dist: float) -> bool:
	var r: Rect2 = rect.grow(dist)
	for p: Player in players:
		if r.has_point(Vector2(p.global_position.x, p.global_position.z)):
			return true
	return false


func _office_hours() -> bool:
	var dn := get_tree().get_first_node_in_group(&"day_night") as DayNight
	return dn == null or (dn.hours >= OFFICE_HOURS.x and dn.hours < OFFICE_HOURS.y)


func _residents_tick() -> void:
	var players: Array[Player] = _players()
	var want: Dictionary = {
		&"slums": _zone_near(SLUM_RECT, players, SPAWN_RANGE),
		&"city": _zone_near(CITY_RECT, players, SPAWN_RANGE),
	}
	var keep: Dictionary = {
		&"slums": _zone_near(SLUM_RECT, players, DESPAWN_RANGE),
		&"city": _zone_near(CITY_RECT, players, DESPAWN_RANGE),
	}
	var h: float = _hours()
	if want[&"city"] and not _city_traffic:
		_more_city_traffic()
	for zone: StringName in [&"slums", &"city"]:
		if want[zone]:
			for sp: Dictionary in (slum_spots() if zone == &"slums" else city_spots()):
				if not CityLife.in_hours(sp.get("hours", Vector2(0, 24)), h):
					continue
				var r: Dictionary = _residents.get(sp["key"], {})
				var npc: Pedestrian = r.get("npc") as Pedestrian if r.has("npc") and is_instance_valid(r["npc"]) else null
				if npc == null and _now() >= float(r.get("back", 0.0)):
					var nr: Dictionary = sp.duplicate()
					var variant: int = CityLife.office_variant(hash(sp["key"])) if zone == &"city" else -1
					nr["npc"] = add_resident(sp["pos"], sp["yaw"], zone, variant)
					_residents[sp["key"]] = nr
	for key: String in _residents.keys():
		var r: Dictionary = _residents[key]
		var npc := r.get("npc") as Pedestrian if is_instance_valid(r.get("npc")) else null
		if npc == null:
			continue
		if npc.dead:
			_residents[key] = {"back": _now() + 120.0}
			continue
		var gone: bool = not keep[r["zone"]] or not CityLife.in_hours(r.get("hours", Vector2(0, 24)), h)
		if gone and npc.wants <= 0:
			npc.queue_free()
			_residents.erase(key)
			continue
		_resident_step(npc, r)
	for zone: StringName in [&"slums", &"city"]:
		if keep[zone] and _now() >= float(_next_customer[zone]):
			_next_customer[zone] = _now() + randf_range(CUSTOMER_EVERY.x, CUSTOMER_EVERY.y)
			make_zone_customer(zone)


func _hours() -> float:
	var dn := get_tree().get_first_node_in_group(&"day_night") as DayNight
	return dn.hours if dn else 12.0


## Host (part 21): busier city streets - extra cars on the city routes, once a player comes near.
var _city_traffic: bool = false


func _more_city_traffic() -> void:
	_city_traffic = true
	var traffic: Node = _world.get_node_or_null("Traffic") if _world else null
	if traffic and traffic.has_method("spawn_cars") and Traffic.city_first_route >= 0:
		traffic.call("spawn_cars", CityLife.EXTRA_CARS, true)
		print("[Zones] +%d cars in the city" % CityLife.EXTRA_CARS)


## Host: one resident / office worker (a non-wandering, networked pedestrian).
func add_resident(pos: Vector3, yaw: float, zone: StringName, variant: int = -1) -> Pedestrian:
	var npcs: Node = _npcs()
	if npcs == null:
		return null
	var npc: Pedestrian = (load(PEDESTRIAN_SCENE) as PackedScene).instantiate()
	npc.variant = variant if variant >= 0 else randi() % Pedestrian.VARIANTS.size()
	npc.color_seed = randi()
	npc.ambient = false
	npc.position = pos
	npc.rotation.y = yaw
	npc.set_meta(&"zone", zone)
	npcs.add_child(npc, true)
	return npc


## Host: walkers walk the sidewalk graph, sitters sit, the others stand at their spot (back after a scare) and
## now and then have a word with the neighbours.
func _resident_step(npc: Pedestrian, r: Dictionary) -> void:
	var kind: String = str(r.get("kind", "stand"))
	if kind == "walk":
		CityLife.walk_step(npc, r)
		return
	if npc.is_fleeing() or npc.wants > 0 or npc._moving or npc._sitting:
		return
	var spot: Vector3 = r["pos"]
	if kind == "sit":
		var seat := get_node_or_null(r.get("seat", NodePath())) as Node3D
		if seat == null:
			return
		var front: Vector3 = seat.global_position + seat.global_basis.z * 0.8
		if npc.global_position.distance_to(front) > 1.2 and npc.global_position.distance_to(seat.global_position) > 1.2:
			if npc.straight_way_clear(front, 40.0):
				npc._go_direct(front, Pedestrian.Anim.WALK)
			else:
				CityLife.sit(npc, seat)
			return
		CityLife.sit(npc, seat)
		return
	if npc.global_position.distance_to(spot) > 1.5:
		if npc.straight_way_clear(spot, 40.0):
			npc._go_direct(spot, Pedestrian.Anim.WALK)
		elif r["zone"] == &"slums":
			npc._go(spot, Pedestrian.Anim.WALK)
		else:
			npc.global_position = spot  # (no navmesh in the city)
			npc.net_pos = spot
		return
	if absf(angle_difference(npc.rotation.y, float(r["yaw"]))) > 0.1:
		npc.rotation.y = float(r["yaw"])
		npc.net_yaw = npc.rotation.y
	if r.get("talk", true) and randf() < 0.08:
		npc.anim_state = Pedestrian.Anim.TALK if npc.anim_state != Pedestrian.Anim.TALK else Pedestrian.Anim.IDLE


func residents(zone: StringName) -> Array:
	var out: Array = []
	for r: Dictionary in _residents.values():
		if r.get("zone") == zone and is_instance_valid(r.get("npc")) and not (r["npc"] as Pedestrian).dead:
			out.append(r["npc"])
	return out


## Host: a resident of `zone` becomes a customer at the zone price (slums cheap, city dear). Returns them or null.
func make_zone_customer(zone: StringName) -> Pedestrian:
	var free: Array = residents(zone).filter(func(n: Pedestrian) -> bool: return n.wants <= 0 and not n.is_fleeing())
	if free.is_empty():
		return null
	for n: Pedestrian in residents(zone):
		if n.wants > 0:
			return null  # one customer at a time per zone
	var npc: Pedestrian = free.pick_random()
	var bags: int = randi_range(1, 2) if zone == &"slums" else randi_range(2, 4)
	var item: ItemData = ItemDB.get_item(&"weed_bag")
	var price: int = roundi(bags * item.base_price * randf_range(0.85, 1.3))
	var product: String = Products.pick_customer_product()
	price = Products.price(product, price)
	price = customer_price(npc, price)
	npc.become_customer(bags, price, CUSTOMER_TIME, product)
	print("[Zones] %s customer %s wants %d x %s for €%d" % [zone, npc.name, bags, product, price])
	return npc
