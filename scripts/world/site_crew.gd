class_name SiteCrew
extends Node
## City life point 4 (session B, 2026-11-26): builders on A's building sites (BuildingSite, group building_sites,
## markers BuilderSpot1-6 with meta task, SiteGate). Node World/SiteCrew, made by Zones._on_world on every peer; the
## logic runs on the host only, the builders are CityWalkers with role BUILDER (host NPCs, synced like every
## resident; hard hat + vest + tools are local visuals from the synced role / carry).
## - Work hours WORK_START..WORK_END (07:00-17:00): one builder per BuilderSpot of every site within SIM_RANGE of a
##   player. Seen arriving: they walk in through the gate; nobody looking: they are simply at work already.
## - Tasks: "mixer" / "scaffold" / "upper" / "floor" = hammering at the spot (turning a bit now and then); "bricks" =
##   carries bricks from the pallet to the mixer and back; "office" = stands at the site office, chats (TALK).
## - Upper floors: no navmesh in the city and the stair is steep: a builder whose spot is up there walks to the
##   stair foot and appears on its spot once nobody looks (A's advice: place / teleport, don't path).
## - End of the day: down, out through the gate, gone out of sight. A gunshot: they run (Pedestrian flee); a builder
##   that ran is replaced after BACK_AFTER seconds.

const WORK_START: float = 7.0
const WORK_END: float = 17.0
const SIM_RANGE: float = 110.0  # (performance: only the sites a player can really see)
const TICK: float = 1.0
const BACK_AFTER: float = 90.0
const VARIANTS: Array[int] = [9, 7, 1, 0, 10]  # (worker, longsleeve, casual, t-shirt, hoodie)

static var current: SiteCrew = null
## Tests: always work hours / every site active / faster task loops.
static var always_open: bool = false
static var force: bool = false
static var speed: float = 1.0

## Host: key "site_path|spot" -> {"npc", "site", "spot", "task", "pos", "yaw", "state", "back"}.
var crew: Dictionary = {}
var arrivals: int = 0
var deliveries: int = 0
var _t: float = 0.0


static func attach(world: Node) -> void:
	if world == null or world.get_node_or_null(^"SiteCrew") or "--no-builders" in OS.get_cmdline_user_args():
		return
	var c := SiteCrew.new()
	c.name = "SiteCrew"
	world.add_child(c)


func _ready() -> void:
	current = self


func _exit_tree() -> void:
	if current == self:
		current = null


func _is_host() -> bool:
	return multiplayer.multiplayer_peer == null or multiplayer.is_server()


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _hours() -> float:
	var dn := get_tree().get_first_node_in_group(&"day_night") as DayNight
	return dn.hours if dn else 12.0


static func work_time(h: float) -> bool:
	return h >= WORK_START and h < WORK_END


## Which tasks get a builder first: on Low / Medium (QualityProfile crowd < 1) the last ones stay empty.
const TASK_ORDER: Array[String] = ["mixer", "scaffold", "bricks", "upper", "office", "floor"]


## The spots that get a builder at this quality level.
static func staffed_spots(site: Node3D) -> Array:
	var all: Array = spots_of(site)
	all.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return TASK_ORDER.find(str(a["task"])) < TASK_ORDER.find(str(b["task"])))
	var n: int = clampi(roundi(all.size() * minf(1.0, float(QualityProfile.value("crowd")))), mini(2, all.size()), all.size())
	return all.slice(0, n)


## The builder spots of a site: [{"key", "pos", "yaw", "task"}] (global).
static func spots_of(site: Node3D) -> Array:
	var out: Array = []
	for m: Node in site.get_children():
		if m is Marker3D and str(m.name).begins_with("BuilderSpot"):
			var mk := m as Marker3D
			out.append({"key": "%s|%s" % [site.get_path(), mk.name], "pos": mk.global_position,
					"yaw": mk.global_rotation.y, "task": str(mk.get_meta(&"task", "floor"))})
	return out


static func gate_of(site: Node3D) -> Vector3:
	var g := site.get_node_or_null(^"SiteGate") as Node3D
	return g.global_position if g else site.global_position


func _process(delta: float) -> void:
	if not _is_host() or not (Zones.npcs_on or force):
		return
	_t -= delta
	if _t > 0.0:
		return
	_t = TICK
	var open: bool = always_open or work_time(_hours())
	var players: Array[Node] = get_tree().get_nodes_in_group(&"players")
	for n: Node in get_tree().get_nodes_in_group(&"building_sites"):
		var site := n as Node3D
		var near: bool = force
		for p: Node in players:
			if (p as Node3D).global_position.distance_to(site.global_position) < SIM_RANGE:
				near = true
		for sp: Dictionary in staffed_spots(site):
			var key: String = sp["key"]
			var r: Dictionary = crew.get(key, {})
			var npc := r.get("npc") as CityWalker if is_instance_valid(r.get("npc")) else null
			if npc == null:
				if open and near and _now() >= float(r.get("back", 0.0)):
					_hire(site, sp)
				elif not r.is_empty() and r.get("npc") != null:
					crew.erase(key)
				continue
			if npc.dead:
				crew[key] = {"back": _now() + BACK_AFTER}
				continue
			if npc.is_fleeing():
				r["state"] = "fled"
				continue
			if r["state"] == "fled":
				if not _seen(npc.global_position):  # (ran off: gone, a new one comes later)
					npc.queue_free()
					crew[key] = {"back": _now() + BACK_AFTER}
				continue
			if not near:
				npc.queue_free()
				crew.erase(key)
				continue
			if not open and r["state"] == "work":
				r["state"] = "leaving"
				_go_home(key)


## Host: a new builder for one spot.
func _hire(site: Node3D, sp: Dictionary) -> void:
	var key: String = sp["key"]
	var gate: Vector3 = gate_of(site)
	var outside: Vector3 = gate + (gate - site.global_position).normalized() * 3.0
	outside.y = gate.y
	var at_work: bool = not _seen(sp["pos"]) and not _seen(gate)
	var start: Vector3 = sp["pos"] if at_work else outside
	var variant: int = VARIANTS[absi(hash(key)) % VARIANTS.size()]
	var npc := Zones.add_resident(start + Vector3.UP * 0.1, sp["yaw"], &"site", variant, CityWalker.Role.BUILDER) as CityWalker
	if npc == null:
		return
	npc.set_meta(&"builder", true)
	crew[key] = {"npc": npc, "site": site, "spot": sp, "task": sp["task"], "pos": sp["pos"], "yaw": sp["yaw"],
			"state": "arrive"}
	arrivals += 1
	_shift(key, at_work)


func _rec(key: String) -> Dictionary:
	var r: Dictionary = crew.get(key, {})
	if r.is_empty() or not is_instance_valid(r.get("npc")):
		return {}
	return r


func _alive(key: String, npc_v: Variant) -> bool:  # (untyped: the builder may be freed meanwhile)
	if not is_instance_valid(npc_v):
		return false
	var npc := npc_v as CityWalker
	var r: Dictionary = _rec(key)
	return not r.is_empty() and r["npc"] == npc and not npc.dead and not npc.is_fleeing() and r["state"] != "leaving"


## Host: the builder's day: get to the spot, then work until SiteCrew sends it home.
func _shift(key: String, at_work: bool) -> void:
	var r: Dictionary = _rec(key)
	if r.is_empty():
		return
	var npc: CityWalker = r["npc"]
	var site: Node3D = r["site"]
	var spot: Vector3 = r["pos"]
	await get_tree().physics_frame
	if not at_work:
		var gate: Vector3 = gate_of(site)
		await _go(npc, gate)
		if not _alive(key, npc):
			return
		if spot.y - gate.y > 1.0:
			# Up the stair: walk to its foot, then appear on the floor once nobody looks.
			var foot: Vector3 = site.to_global((site as BuildingSite).flight(0)[0]) if site is BuildingSite else gate
			await _go(npc, foot)
			var t0: float = _now()
			while _alive(key, npc) and _seen(npc.global_position) and _now() - t0 < 25.0:
				await get_tree().create_timer(0.5).timeout
			if not _alive(key, npc):
				return
			_put(npc, spot)
		else:
			await _go(npc, spot)
	if not _alive(key, npc):
		return
	r["state"] = "work"
	match str(r["task"]):
		"bricks":
			await _carry_loop(key, npc)
		"office":
			await _office_loop(key, npc)
		_:
			await _hammer_loop(key, npc)


func _face(npc: CityWalker, yaw: float) -> void:
	npc.rotation.y = yaw
	npc.net_yaw = yaw


func _hammer_loop(key: String, npc: CityWalker) -> void:
	var r: Dictionary = _rec(key)
	var base_yaw: float = r["yaw"]
	while _alive(key, npc):
		npc.carry = CityWalker.CARRY_HAMMER
		npc.anim_state = Pedestrian.Anim.IDLE
		_face(npc, base_yaw + randf_range(-0.6, 0.6))
		await get_tree().create_timer(randf_range(6.0, 14.0) / speed).timeout
		if not _alive(key, npc):
			break
		if randf() < 0.3:  # (a break: hammer down, a word with whoever is near)
			npc.carry = 0
			npc.anim_state = Pedestrian.Anim.TALK if randf() < 0.5 else Pedestrian.Anim.IDLE
			await get_tree().create_timer(randf_range(3.0, 6.0) / speed).timeout
	if is_instance_valid(npc) and npc.carry == CityWalker.CARRY_HAMMER:
		npc.carry = 0


func _office_loop(key: String, npc: CityWalker) -> void:
	var r: Dictionary = _rec(key)
	while _alive(key, npc):
		_face(npc, float(r["yaw"]) + randf_range(-0.8, 0.8))
		npc.anim_state = Pedestrian.Anim.TALK if randf() < 0.6 else Pedestrian.Anim.IDLE
		await get_tree().create_timer(randf_range(3.0, 7.0) / speed).timeout


## Bricks: from the pallet (its own spot) to the mixer and back, a stack in the hands one way.
func _carry_loop(key: String, npc: CityWalker) -> void:
	var r: Dictionary = _rec(key)
	var site: Node3D = r["site"]
	var pallet: Vector3 = r["pos"]
	var drop: Vector3 = pallet
	for sp: Dictionary in spots_of(site):
		if sp["task"] == "mixer":
			drop = (sp["pos"] as Vector3) + (pallet - (sp["pos"] as Vector3)).normalized() * 1.2
	if drop.distance_to(pallet) < 1.5:
		await _hammer_loop(key, npc)
		return
	while _alive(key, npc):
		npc.anim_state = Pedestrian.Anim.IDLE
		await get_tree().create_timer(randf_range(1.5, 3.0) / speed).timeout  # (picking up)
		if not _alive(key, npc):
			break
		npc.carry = CityWalker.CARRY_BRICKS
		await _go(npc, drop)
		if not _alive(key, npc):
			break
		npc.anim_state = Pedestrian.Anim.IDLE
		await get_tree().create_timer(randf_range(1.0, 2.0) / speed).timeout
		npc.carry = 0
		deliveries += 1
		await _go(npc, pallet)
	if is_instance_valid(npc) and npc.carry == CityWalker.CARRY_BRICKS:
		npc.carry = 0


## End of the day: tools down, down from the floors, out through the gate, gone where nobody looks.
func _go_home(key: String) -> void:
	var r: Dictionary = _rec(key)
	if r.is_empty():
		return
	var npc: CityWalker = r["npc"]
	var site: Node3D = r["site"]
	npc.carry = 0
	var gate: Vector3 = gate_of(site)
	await get_tree().create_timer(randf_range(0.5, 6.0) / speed).timeout
	if not is_instance_valid(npc) or npc.dead:
		return
	if npc.global_position.y - gate.y > 1.0:
		var foot: Vector3 = site.to_global((site as BuildingSite).flight(0)[0]) if site is BuildingSite else gate
		var t0: float = _now()
		while is_instance_valid(npc) and _seen(npc.global_position) and _now() - t0 < 25.0:
			await get_tree().create_timer(0.5).timeout
		if not is_instance_valid(npc):
			return
		_put(npc, foot)
	await _go(npc, gate)
	if not is_instance_valid(npc):
		return
	var away: Vector3 = gate + (gate - site.global_position).normalized() * 12.0
	away.y = gate.y
	await _go(npc, away)
	for i: int in 60:
		if not is_instance_valid(npc) or not _seen(npc.global_position):
			break
		await get_tree().create_timer(0.5).timeout
	if is_instance_valid(npc):
		npc.queue_free()
	crew.erase(key)


func _put(npc: CityWalker, at: Vector3) -> void:
	npc.global_position = at + Vector3.UP * 0.05
	npc.net_pos = npc.global_position
	npc.velocity = Vector3.ZERO


## A move that always ends (straight line; through a short detour; put there when nobody looks or it sleeps).
func _go(npc_v: Variant, to: Vector3) -> bool:  # (untyped: the builder may be freed meanwhile)
	if not is_instance_valid(npc_v):
		return false
	var npc := npc_v as CityWalker
	if npc == null or npc.dead or npc.is_fleeing():
		return false
	var flat := Vector3(to.x - npc.global_position.x, 0, to.z - npc.global_position.z)
	if flat.length() < 0.4:
		return true
	if npc.lod == Pedestrian.Lod.ASLEEP:
		_put(npc, to)
		return true
	if not npc.straight_way_clear(to, 60.0):
		if not _seen(npc.global_position) and not _seen(to):
			_put(npc, to)
			return true
		npc.anim_state = Pedestrian.Anim.IDLE
		var t0: float = _now()
		while is_instance_valid(npc) and (_seen(npc.global_position) or _seen(to)) and _now() - t0 < 20.0:
			await get_tree().create_timer(0.5).timeout
		if is_instance_valid(npc) and not npc.dead and not npc.is_fleeing():
			_put(npc, to)
			return true
		return false
	var state: Array = [false]
	var run := func() -> void:
		await npc._go_direct(to, Pedestrian.Anim.WALK)
		state[0] = true
	run.call()
	var limit: float = _now() + flat.length() / Pedestrian.WALK_SPEED * 2.0 + 4.0
	while not state[0]:
		await get_tree().create_timer(0.25).timeout
		if not is_instance_valid(npc) or npc.dead:
			return false
		if npc.lod == Pedestrian.Lod.ASLEEP or _now() > limit:
			npc._finish_move(false)
			if not _seen(npc.global_position):
				_put(npc, to)
			return true
	return true


func _seen(p: Vector3) -> bool:
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var pl := n as Player
		var d: Vector3 = p - pl.global_position
		if d.length() < 6.0:
			return true
		if d.length() < 60.0 and d.normalized().dot(-pl.global_basis.z) > 0.4:
			return true
	return false


## Builders at work right now (tests, F3).
func working() -> Array[CityWalker]:
	var out: Array[CityWalker] = []
	for k: String in crew:
		var r: Dictionary = crew[k]
		if is_instance_valid(r.get("npc")) and r.get("state") == "work":
			out.append(r["npc"])
	return out
