class_name PrisonLife
extends Node
## City life point 5a (session B, 2026-11-26): life in A's prison (prefabs/buildings/prison.tscn, node Prison).
## Node World/PrisonLife, made by Zones._on_world on every peer; logic on the host. Inmates (CityWalker role INMATE,
## orange) and guards (role GUARD, grey uniform + cap) are host NPCs like every resident; off while the intro runs
## (it has its own people) and when no player is within SIM_RANGE.
## Inmates' day (prison local hours, SCHEDULE): breakfast / lunch / dinner on the canteen benches, yard time in
## between (weights, pull-up bar, basketball court, benches, picnic tables, groups that chat), locked up 20:00-07:00.
## Guards: A's posts PrisonGuardPost1 (gatehouse) / 2 (yard) / 3 (Block B gallery, up) / 4 (canteen) + one walking
## the yard loop PrisonPatrol1-4. Shift change at 07:00, 15:00 and 23:00: the relief walks from the gatehouse to the
## post, the old guard walks out (aflossing). After the inmates' lunch the patrol guard eats in the canteen.
## Moves are straight lines; where something is in the way the NPC is put there once nobody looks (SiteCrew._go).

const SIM_RANGE: float = 160.0
const TICK: float = 1.0
## New NPCs per tick (spawning a model costs a few ms: never a whole crowd in one frame).
const SPAWN_PER_TICK: int = 3
const INMATES: int = 14
const INMATE_VARIANTS: Array[int] = [0, 1, 7]
const GUARD_VARIANTS: Array[int] = [7, 0]
## [start, end, what] in hours; what = "meal" / "yard" / "cells".
const SCHEDULE: Array = [[0.0, 7.0, "cells"], [7.0, 8.0, "meal"], [8.0, 12.0, "yard"], [12.0, 13.0, "meal"],
		[13.0, 17.5, "yard"], [17.5, 18.5, "meal"], [18.5, 20.0, "yard"], [20.0, 24.0, "cells"]]
const SHIFTS: Array[float] = [7.0, 15.0, 23.0]
## Guard lunch: the patrol guard eats in the canteen (after the inmates).
const GUARD_LUNCH: Vector2 = Vector2(13.0, 13.75)

## Prison-local places (see tools/generators/gen_prefabs.py prison()).
const CELL_EXIT := Vector3(0.0, 0.1, -9.0)          # Block A's door to the yard
const CANTEEN_DOOR := Vector3(16.5, 0.1, -15.0)      # outside the canteen's west door
const CANTEEN_IN := Vector3(19.5, 0.1, -15.0)
const TABLES: Array[Vector2] = [Vector2(22.5, -23.5), Vector2(29.5, -23.5), Vector2(22.5, -19.5), Vector2(29.5, -19.5),
		Vector2(22.5, -15.5), Vector2(29.5, -15.5)]
## Yard activities: [name, local pos, kind, local yaw]; kind sit = bench-like seat on the floor, stand / talk / court.
const YARD: Array = [
	["weights_bench", Vector3(-20.0, 0.1, -6.0), "sit", 0.0],
	["court1", Vector3(-30.0, 0.1, 2.0), "court", 0.0],
	["bench", Vector3.ZERO, "bench", 0.0],
	["pullup", Vector3(-3.0, 0.1, 2.0), "stand", 3.14],
	["picnic1", Vector3(-18.0, 0.1, 11.2), "talk", 0.0],
	["court2", Vector3(-28.0, 0.1, 4.0), "court", 0.0],
	["bench", Vector3.ZERO, "bench", 0.0],
	["group1", Vector3(-6.5, 0.1, 9.0), "talk", 0.6],
	["weights_spot", Vector3(-19.1, 0.1, -6.2), "talk", -1.57],
	["court3", Vector3(-32.0, 0.1, 0.0), "court", 0.0],
	["picnic2", Vector3(-16.8, 0.1, 12.6), "talk", 1.57],
	["group2", Vector3(-5.2, 0.1, 10.2), "talk", -2.4],
	["pullup_wait", Vector3(-3.0, 0.1, 3.4), "talk", 0.0],
	["court4", Vector3(-27.0, 0.1, 0.5), "court", 0.0],
	["picnic3", Vector3(-18.0, 0.1, 15.3), "talk", 3.14],
	["group3", Vector3(-7.4, 0.1, 10.4), "talk", 2.6],
]

static var current: PrisonLife = null
## Tests: clock override (-1 = DayNight), every NPC active, faster loops.
static var force: bool = false
static var speed: float = 1.0

## Host: "inmate_<i>" / "guard_<post>" -> {"npc", "state", ...}
var people: Dictionary = {}
var meals_served: int = 0
var reliefs: int = 0
var _t: float = 0.0
var _last_shift: int = -1
var _prison: Node3D = null
var _bench_seats: Array[Node3D] = []


static func attach(world: Node) -> void:
	if world == null or world.get_node_or_null(^"PrisonLife") or "--no-prison-life" in OS.get_cmdline_user_args():
		return
	var c := PrisonLife.new()
	c.name = "PrisonLife"
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


static func phase(h: float) -> String:
	for s: Array in SCHEDULE:
		if h >= float(s[0]) and h < float(s[1]):
			return s[2]
	return "cells"


func prison() -> Node3D:
	if _prison == null or not is_instance_valid(_prison):
		_prison = get_parent().find_child("Prison", true, false) as Node3D if get_parent() else null
		_bench_seats.clear()
		if _prison:
			for b: Node in _prison.find_children("Bench*", "Node3D", false, false):
				for s: Node in b.get_children():
					if s is Marker3D and s.is_in_group(&"bench_seat"):
						_bench_seats.append(s as Node3D)
	return _prison


func _g(local: Vector3) -> Vector3:
	return _prison.to_global(local)


func _yaw(local_yaw: float) -> float:
	return _prison.global_rotation.y + local_yaw


## Canteen seats (global): [{"pos", "yaw"}], 3 per bench side, both sides of every table.
func canteen_seats() -> Array:
	var out: Array = []
	for t: Vector2 in TABLES:
		for side: float in [-1.0, 1.0]:
			for dx: float in [-1.6, 0.0, 1.6]:
				out.append({"pos": _g(Vector3(t.x + dx, 0.05, t.y + side * 0.9)), "yaw": _yaw(PI if side < 0.0 else 0.0)})
	return out


func _process(delta: float) -> void:
	if not _is_host() or not (Zones.npcs_on or force):
		return
	_t -= delta
	if _t > 0.0:
		return
	_t = TICK
	if prison() == null:
		return
	var near: bool = force
	for p: Node in get_tree().get_nodes_in_group(&"players"):
		if (p as Node3D).global_position.distance_to(_prison.global_position) < SIM_RANGE:
			near = true
	var intro: bool = Intro.current != null and Intro.current.is_running()
	if not near or intro:
		_clear()
		return
	var h: float = _hours()
	var ph: String = phase(h)
	var spawns: int = SPAWN_PER_TICK
	# Inmates.
	var want: int = 0 if ph == "cells" else roundi(INMATES * minf(1.0, float(QualityProfile.value("crowd"))))
	for i: int in INMATES:
		var key: String = "inmate_%d" % i
		var r: Dictionary = people.get(key, {})
		var npc := r.get("npc") as CityWalker if is_instance_valid(r.get("npc")) else null
		if npc == null:
			if r.get("state", "") != "" and r.get("npc") != null:
				people.erase(key)
			if i < want and _now() >= float(r.get("back", 0.0)) and spawns > 0:
				spawns -= 1
				_add_inmate(i, ph)
			continue
		if npc.dead:
			people[key] = {"back": _now() + 120.0}
			continue
		if i >= want and r["state"] != "in":
			r["state"] = "in"
			_lock_up(key)
		elif r["phase"] != ph and r["state"] == "busy":
			r["phase"] = ph
			_inmate_day(key)
	# Guards: shift change.
	var shift: int = 0
	for k: int in SHIFTS.size():
		if h >= SHIFTS[k]:
			shift = k + 1
	shift = shift % SHIFTS.size()
	var change: bool = _last_shift >= 0 and shift != _last_shift
	_last_shift = shift
	for post: String in ["1", "2", "3", "4", "patrol"]:
		var key: String = "guard_%s" % post
		var r: Dictionary = people.get(key, {})
		var npc := r.get("npc") as CityWalker if is_instance_valid(r.get("npc")) else null
		if npc == null:
			if _now() >= float(r.get("back", 0.0)) and spawns > 0:
				spawns -= 1
				_add_guard(post, false)
			continue
		if npc.dead:
			people[key] = {"back": _now() + 120.0}
			continue
		if change and r.get("state") == "post":
			_relieve(post)


func _clear() -> void:
	for k: String in people.keys():
		var npc: Variant = people[k].get("npc")
		if is_instance_valid(npc):
			(npc as Node).queue_free()
	people.clear()
	_last_shift = -1


# --- Inmates -------------------------------------------------------------------------------------

func _add_inmate(i: int, ph: String) -> void:
	var key: String = "inmate_%d" % i
	var unseen: bool = not _seen(_g(CELL_EXIT)) and not _seen(_prison.global_position)
	var variant: int = INMATE_VARIANTS[i % INMATE_VARIANTS.size()]
	var start: Vector3 = _g(CELL_EXIT)
	var npc := Zones.add_resident(start + Vector3.UP * 0.1, _yaw(0.0), &"prison", variant, CityWalker.Role.INMATE) as CityWalker
	if npc == null:
		return
	npc.set_meta(&"inmate", true)
	people[key] = {"npc": npc, "state": "busy", "phase": ph, "unseen": unseen, "i": i}
	_inmate_day(key)


func _rec(key: String) -> Dictionary:
	var r: Dictionary = people.get(key, {})
	return r if not r.is_empty() and is_instance_valid(r.get("npc")) else {}


func _alive(key: String, npc_v: Variant, ph: String) -> bool:
	if not is_instance_valid(npc_v):
		return false
	var npc := npc_v as CityWalker
	var r: Dictionary = _rec(key)
	return not r.is_empty() and r["npc"] == npc and not npc.dead and not npc.is_fleeing() and r["state"] == "busy" \
			and r["phase"] == ph


## Host: one inmate's block of the day (meal or yard), until the phase changes.
func _inmate_day(key: String) -> void:
	var r: Dictionary = _rec(key)
	if r.is_empty():
		return
	var npc: CityWalker = r["npc"]
	var ph: String = r["phase"]
	var first: bool = bool(r.get("unseen", false))
	r["unseen"] = false
	_stand(npc)
	await get_tree().physics_frame
	if ph == "meal":
		var seats: Array = canteen_seats()
		var seat: Dictionary = seats[(int(r["i"]) * 5) % seats.size()]
		if first:
			_put(npc, seat["pos"])
		else:
			await _go(npc, _g(CANTEEN_DOOR))
			await _go(npc, _g(CANTEEN_IN))
			await _go(npc, seat["pos"])
		if not _alive(key, npc, ph):
			return
		_sit_at(npc, seat["pos"], seat["yaw"])
		r["was"] = "meal"
		meals_served += 1
		while _alive(key, npc, ph):
			await get_tree().create_timer(randf_range(4.0, 9.0) / speed).timeout
		return
	# Yard: pick an activity (spread over the inmates), stay with it till the phase changes.
	var act: Array = YARD[int(r["i"]) % YARD.size()]
	var pos: Vector3
	var yaw: float = _yaw(float(act[3]))
	var bench: Node3D = null
	if act[2] == "bench":
		var k: int = int(r["i"]) % maxi(1, _bench_seats.size())
		bench = _bench_seats[k] if not _bench_seats.is_empty() else null
		pos = bench.global_position if bench else _g(Vector3(-6.0, 0.1, 9.0))
	else:
		pos = _g(act[1])
	if first:
		_put(npc, pos)
	else:
		if (r.get("was", "") as String) == "meal":
			await _go(npc, _g(CANTEEN_IN))
			await _go(npc, _g(CANTEEN_DOOR))
		await _go(npc, pos)
	r["was"] = ph
	if not _alive(key, npc, ph):
		return
	match str(act[2]):
		"sit":
			_sit_at(npc, pos, yaw)
			while _alive(key, npc, ph):
				await get_tree().create_timer(5.0 / speed).timeout
		"bench":
			if bench:
				CityLife.sit(npc, bench)
			while _alive(key, npc, ph):
				await get_tree().create_timer(5.0 / speed).timeout
		"court":
			var centre: Vector3 = _g(Vector3(-30.0, 0.1, 2.0))
			while _alive(key, npc, ph):
				var to: Vector3 = centre + Vector3(randf_range(-5.0, 5.0), 0.0, randf_range(-4.0, 4.0))
				if npc.straight_way_clear(to, 20.0):
					npc._go_direct(to, Pedestrian.Anim.RUN if randf() < 0.5 else Pedestrian.Anim.WALK)
				await get_tree().create_timer(randf_range(2.0, 4.0) / speed).timeout
				if _alive(key, npc, ph) and not npc._moving:
					npc.anim_state = Pedestrian.Anim.IDLE
		_:
			_face(npc, yaw)
			while _alive(key, npc, ph):
				npc.anim_state = Pedestrian.Anim.TALK if act[2] == "talk" and randf() < 0.55 else Pedestrian.Anim.IDLE
				await get_tree().create_timer(randf_range(3.0, 6.0) / speed).timeout


## Lock-up: back to Block A's door, gone where nobody looks.
func _lock_up(key: String) -> void:
	var r: Dictionary = _rec(key)
	if r.is_empty():
		return
	var npc: CityWalker = r["npc"]
	_stand(npc)
	if r.get("was", "") == "meal" or r.get("phase", "") == "meal":
		await _go(npc, _g(CANTEEN_IN))
		await _go(npc, _g(CANTEEN_DOOR))
	await _go(npc, _g(CELL_EXIT))
	await _go(npc, _g(CELL_EXIT + Vector3(0, 0, -2.0)))
	for i: int in 50:
		if not is_instance_valid(npc) or not _seen(npc.global_position):
			break
		await get_tree().create_timer(0.5).timeout
	if is_instance_valid(npc):
		npc.queue_free()
	people.erase(key)


# --- Guards --------------------------------------------------------------------------------------

func _post_of(post: String) -> Dictionary:
	if post == "patrol":
		var m := _prison.get_node_or_null(^"PrisonPatrol1") as Node3D
		return {"pos": m.global_position if m else _g(Vector3(-12, 0.1, 8)), "yaw": _yaw(0.0)}
	var mk := _prison.get_node_or_null(NodePath("PrisonGuardPost" + post)) as Node3D
	if mk == null:
		return {"pos": _g(Vector3(0, 0.1, 4)), "yaw": _yaw(0.0)}
	return {"pos": mk.global_position, "yaw": mk.global_rotation.y}


func _gatehouse() -> Vector3:
	return _post_of("1")["pos"]


func _add_guard(post: String, relief: bool) -> CityWalker:
	var key: String = "guard_%s" % post
	var spot: Dictionary = _post_of(post)
	var unseen: bool = not _seen(spot["pos"]) and not _seen(_gatehouse())
	var start: Vector3 = spot["pos"] if unseen and not relief else _gatehouse()
	var variant: int = GUARD_VARIANTS[absi(hash(key + str(reliefs))) % GUARD_VARIANTS.size()]
	var npc := Zones.add_resident(start + Vector3.UP * 0.1, spot["yaw"], &"prison", variant, CityWalker.Role.GUARD) as CityWalker
	if npc == null:
		return null
	npc.set_meta(&"guard", true)
	people[key] = {"npc": npc, "state": "going", "post": post}
	_guard_shift(key, npc, spot)
	return npc


func _guard_shift(key: String, npc: CityWalker, spot: Dictionary) -> void:
	await get_tree().physics_frame
	if (spot["pos"] as Vector3).y - npc.global_position.y > 1.5:
		var t0: float = _now()
		while is_instance_valid(npc) and _seen(npc.global_position) and _now() - t0 < 20.0:
			await get_tree().create_timer(0.5).timeout
		if is_instance_valid(npc):
			_put(npc, spot["pos"])
	else:
		await _go(npc, spot["pos"])
	var r: Dictionary = _rec(key)
	if r.is_empty() or r["npc"] != npc:
		return
	r["state"] = "post"
	if r["post"] == "patrol":
		await _patrol(key, npc)
		return
	while _guard_on(key, npc):
		_face(npc, float(spot["yaw"]) + randf_range(-0.7, 0.7))
		npc.anim_state = Pedestrian.Anim.IDLE
		await get_tree().create_timer(randf_range(4.0, 9.0) / speed).timeout


func _guard_on(key: String, npc_v: Variant) -> bool:
	if not is_instance_valid(npc_v):
		return false
	var npc := npc_v as CityWalker
	var r: Dictionary = _rec(key)
	return not r.is_empty() and r["npc"] == npc and not npc.dead and r["state"] == "post"


## The yard loop (PrisonPatrol1-4); lunch in the canteen after the inmates.
func _patrol(key: String, npc: CityWalker) -> void:
	var pts: Array[Vector3] = []
	for k: int in 4:
		var m := _prison.get_node_or_null(NodePath("PrisonPatrol%d" % (k + 1))) as Node3D
		if m:
			pts.append(m.global_position)
	if pts.is_empty():
		return
	var k: int = 0
	while _guard_on(key, npc):
		var h: float = _hours()
		if h >= GUARD_LUNCH.x and h < GUARD_LUNCH.y and not npc.has_meta(&"ate"):
			npc.set_meta(&"ate", true)
			await _go(npc, _g(CANTEEN_DOOR))
			await _go(npc, _g(CANTEEN_IN))
			var seat: Dictionary = canteen_seats()[17]
			await _go(npc, seat["pos"])
			if not _guard_on(key, npc):
				return
			_sit_at(npc, seat["pos"], seat["yaw"])
			while _guard_on(key, npc) and _hours() < GUARD_LUNCH.y and _hours() >= GUARD_LUNCH.x:
				await get_tree().create_timer(3.0 / speed).timeout
			_stand(npc)
			await _go(npc, _g(CANTEEN_IN))
			await _go(npc, _g(CANTEEN_DOOR))
			continue
		await _go(npc, pts[k])
		k = (k + 1) % pts.size()
		if _guard_on(key, npc):
			npc.anim_state = Pedestrian.Anim.IDLE
			await get_tree().create_timer(randf_range(1.0, 3.0) / speed).timeout


## Shift change: a relief walks in from the gatehouse; when it is at the post the old guard walks out.
func _relieve(post: String) -> void:
	var key: String = "guard_%s" % post
	var old: Dictionary = _rec(key)
	if old.is_empty():
		return
	var old_npc: CityWalker = old["npc"]
	old["state"] = "relieved"
	reliefs += 1
	var relief: CityWalker = _add_guard(post, true)
	if relief == null:
		return
	var t0: float = _now()
	while is_instance_valid(relief) and (people.get(key, {}) as Dictionary).get("state") != "post" and _now() - t0 < 60.0:
		await get_tree().create_timer(0.5).timeout
	if not is_instance_valid(old_npc):
		return
	_stand(old_npc)
	if old_npc.global_position.y - _gatehouse().y > 1.5:
		_put(old_npc, _g(Vector3(-26.0, 0.1, -20.0)))
	await _go(old_npc, _gatehouse())
	await _go(old_npc, _gatehouse() + (_gatehouse() - _prison.global_position).normalized() * 6.0)
	for i: int in 50:
		if not is_instance_valid(old_npc) or not _seen(old_npc.global_position):
			break
		await get_tree().create_timer(0.5).timeout
	if is_instance_valid(old_npc):
		old_npc.queue_free()


# --- Helpers -------------------------------------------------------------------------------------

func _face(npc: CityWalker, yaw: float) -> void:
	npc.rotation.y = yaw
	npc.net_yaw = yaw


func _sit_at(npc: CityWalker, pos: Vector3, yaw: float) -> void:
	var look := Vector3(-sin(yaw), 0, -cos(yaw))
	npc._sitting = true
	npc._sit_front = pos - look * 0.6
	npc.collision.disabled = true
	npc.global_position = pos + look * Pedestrian.SIT_OFFSET + Vector3.UP * Pedestrian.SIT_HEIGHT
	_face(npc, yaw)
	npc.net_pos = npc.global_position
	npc.anim_state = Pedestrian.Anim.SIT


func _stand(npc_v: Variant) -> void:
	if not is_instance_valid(npc_v):
		return
	var npc := npc_v as CityWalker
	if npc._sitting:
		npc._stand_up()
	npc.anim_state = Pedestrian.Anim.IDLE


func _put(npc: CityWalker, at: Vector3) -> void:
	npc.global_position = at + Vector3.UP * 0.05
	npc.net_pos = npc.global_position
	npc.velocity = Vector3.ZERO


## A move that always ends: straight line; else (or asleep, or far too slow) put there once nobody looks.
func _go(npc_v: Variant, to: Vector3) -> bool:
	if not is_instance_valid(npc_v):
		return false
	var npc := npc_v as CityWalker
	if npc.dead or npc.is_fleeing():
		return false
	var flat := Vector3(to.x - npc.global_position.x, 0, to.z - npc.global_position.z)
	if flat.length() < 0.4:
		return true
	if npc.lod == Pedestrian.Lod.ASLEEP:
		_put(npc, to)
		return true
	if not npc.straight_way_clear(to, 80.0):
		var map: RID = npc.get_world_3d().navigation_map
		var snap: Vector3 = NavigationServer3D.map_get_closest_point(map, to)
		if snap.distance_to(to) < 0.8 and NavigationServer3D.map_get_closest_point(map, npc.global_position).distance_to(npc.global_position) < 0.8:
			return await _timed(npc, to, true, flat.length() * 1.8)
		var t0: float = _now()
		while is_instance_valid(npc) and (_seen(npc.global_position) or _seen(to)) and _now() - t0 < 15.0:
			npc.anim_state = Pedestrian.Anim.IDLE
			await get_tree().create_timer(0.5).timeout
		if is_instance_valid(npc) and not npc.dead and not npc.is_fleeing():
			_put(npc, to)
			return true
		return false
	return await _timed(npc, to, false, flat.length())


func _timed(npc: CityWalker, to: Vector3, nav: bool, length: float) -> bool:
	var state: Array = [false]
	var run := func() -> void:
		if nav:
			await npc.walk_to(to)
		else:
			await npc._go_direct(to, Pedestrian.Anim.WALK)
		state[0] = true
	run.call()
	var limit: float = _now() + length / Pedestrian.WALK_SPEED * 2.0 + 4.0
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


## Counts for tests / F3: {"inmates", "guards", "sitting", "canteen", "yard"}.
func status() -> Dictionary:
	var out: Dictionary = {"inmates": 0, "guards": 0, "sitting": 0, "posted": 0}
	for k: String in people:
		var r: Dictionary = people[k]
		if not is_instance_valid(r.get("npc")):
			continue
		var npc := r["npc"] as CityWalker
		if k.begins_with("inmate"):
			out["inmates"] += 1
			if npc._sitting:
				out["sitting"] += 1
		else:
			out["guards"] += 1
			if r.get("state") == "post":
				out["posted"] += 1
	return out
