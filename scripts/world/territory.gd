class_name Territory
extends Node
## Point 51: territory per district. At the start the Black Crows hold every district of the village; each
## district has an influence meter (0-100) that sales and won fights push towards the crew. At 100 the crew
## takes the district; below LOSE_AT it falls back to the Crows.
## - Crow districts are dangerous: the first sale there gets a warning text, later sales can bring a Crow
##   after the seller (also by day: Rival.send_after). Crow districts slowly drift back to 0.
## - Crew districts are safe: street Crows don't roam there at night, nobody is sent after you there, and
##   customers pay CREW_PRICE_BONUS more.
## Districts = Staff.config.districts (session B's ids + anchors); a position belongs to the nearest anchor.
## HOST AUTHORITATIVE: state in GameState.world["territory"] = {id: {"inf": float, "held": bool, "warned": bool}};
## every peer gets the whole dictionary (`_set_all`) when it changes. Node World/Territory.

const TAKE_AT: float = 100.0
const LOSE_AT: float = 50.0
## Influence per bag sold, by outcome.
const SALE_GAIN: Dictionary = {"fair": 4.0, "short": 2.0, "run": -2.0}
const KILL_CROW_GAIN: float = 6.0
const DIED_TO_CROW_LOSS: float = 8.0
## Crow districts lose this much influence per in-game hour.
const DECAY_PER_HOUR: float = 0.5
const CREW_PRICE_BONUS: float = 0.15
## Chance per sale in a Crow district (after the warning) that a Crow is sent after the seller.
const CROW_SEND_DEFAULT: float = 0.3
static var crow_send_chance: float = CROW_SEND_DEFAULT
## Fallback when the Staff autoload / config is missing.
const DEFAULT_DISTRICTS: Dictionary = {
	"old_town": {"name": "Old Town", "anchor": Vector3(-24.0, 0.0, -4.6)},
	"main_east": {"name": "Main Road East", "anchor": Vector3(36.0, 0.0, 4.6)},
	"north": {"name": "North Road", "anchor": Vector3(18.0, 0.0, -43.4)},
	"south": {"name": "South Street", "anchor": Vector3(-34.0, 0.0, 55.4)},
}

static var current: Territory

## Every peer: id -> {"inf", "held", ...} (the host's is GameState.world["territory"]).
var state: Dictionary = {}
var _dirty: bool = false
var _last_hours: float = -1.0
var _my_district: String = ""


func _ready() -> void:
	current = self
	crow_send_chance = CROW_SEND_DEFAULT  # (a scenario / test may have changed it)
	add_to_group(&"sale_hooks")
	add_to_group(&"kill_hooks")
	add_to_group(&"hours_skipped")  # Sleep._morning
	if multiplayer.is_server():
		state = GameState.world.get_or_add("territory", {})
		for id: String in districts().keys():
			if not state.has(id):
				state[id] = {"inf": 0.0, "held": false, "warned": false}
	else:
		_request_sync.rpc_id(1)
	var t := Timer.new()
	t.wait_time = 1.0
	t.autostart = true
	t.timeout.connect(_tick)
	add_child(t)


func _exit_tree() -> void:
	if current == self:
		current = null


static func districts() -> Dictionary:
	var staff: Node = Engine.get_main_loop().root.get_node_or_null("/root/Staff") if Engine.get_main_loop() else null
	if staff and staff.get("config") and (staff.get("config") as Resource).get("districts") is Dictionary:
		return staff.get("config").get("districts")
	return DEFAULT_DISTRICTS


## The district a position belongs to (nearest anchor, flat distance), or "".
static func district_at(pos: Vector3) -> String:
	var best: String = ""
	var best_d: float = INF
	var all: Dictionary = districts()
	for id: String in all.keys():
		var a: Vector3 = all[id]["anchor"]
		var d: float = Vector2(a.x - pos.x, a.z - pos.z).length()
		if d < best_d:
			best_d = d
			best = id
	return best


static func district_name(id: String) -> String:
	return str((districts().get(id, {}) as Dictionary).get("name", id))


func influence(id: String) -> float:
	return float((state.get(id, {}) as Dictionary).get("inf", 0.0))


func is_held(id: String) -> bool:
	return bool((state.get(id, {}) as Dictionary).get("held", false))


## True when the crew holds the district at `pos`.
static func crew_holds(pos: Vector3) -> bool:
	return current != null and current.is_held(district_at(pos))


func held_count() -> int:
	var n: int = 0
	for id: String in state.keys():
		if is_held(id):
			n += 1
	return n


## One line for the HUD / phone: "Old Town - Crow turf (35%)".
func status_text(id: String) -> String:
	return "%s - %s (%d%%)" % [district_name(id), "your turf" if is_held(id) else "Crow turf", roundi(influence(id))]


# --- Host --------------------------------------------------------------------------------

## Host: change a district's influence; takes / loses it at the thresholds and texts everyone.
func host_add(id: String, amount: float, why: String = "") -> void:
	if not multiplayer.is_server() or not state.has(id) or amount == 0.0:
		return
	var rec: Dictionary = state[id]
	var before: float = float(rec["inf"])
	rec["inf"] = clampf(before + amount, 0.0, TAKE_AT)
	if not bool(rec["held"]) and float(rec["inf"]) >= TAKE_AT:
		rec["held"] = true
		print("[Territory] %s taken from the Crows (%s)" % [id, why])
		_phone_all("Unknown", "%s is yours now. The Crows pulled their boys out. For now." % district_name(id))
	elif bool(rec["held"]) and float(rec["inf"]) < LOSE_AT:
		rec["held"] = false
		print("[Territory] %s lost to the Crows (%s)" % [id, why])
		_phone_all("Unknown", "The Crows are back in %s. You lost the street." % district_name(id))
	if roundi(before) != roundi(float(rec["inf"])) or why != "":
		_dirty = true


## Host, tests + scenarios: set a district's meter directly (held follows the thresholds).
func debug_set(id: String, inf: float, held: bool) -> void:
	if not state.has(id):
		return
	state[id]["inf"] = clampf(inf, 0.0, TAKE_AT)
	state[id]["held"] = held
	_dirty = true


## Group "sale_hooks" (Pedestrian._server_sell): every finished sale.
func on_sale(seller: Node, npc: Node, bags: int, _paid: int, outcome: String) -> void:
	var p := seller as Player
	if p == null or not multiplayer.is_server():
		return
	var pos: Vector3 = (npc as Node3D).global_position if npc is Node3D else p.global_position
	var id: String = district_at(pos)
	if id == "":
		return
	host_add(id, float(SALE_GAIN.get(outcome, 0.0)) * bags, "sale")
	if is_held(id):
		return
	var rec: Dictionary = state[id]
	if not bool(rec.get("warned", false)):
		rec["warned"] = true
		_dirty = true
		p.phone_message("Unknown", "You're selling on Crow turf in %s. Do it again and we come for you." % district_name(id), "")
		return
	if randf() < crow_send_chance and not _hunted(p):
		send_crow(p)


## True while a Crow sent after `p` is still on its way (one at a time).
func _hunted(p: Player) -> bool:
	for n: Node in get_tree().get_nodes_in_group(&"rivals"):
		var r := n as Rival
		if r and not r.dead and r.sent_target == p:
			return true
	return false


## Host: one Crow walks out after `p` from a spot out of sight 25-40 m away (by day too).
func send_crow(p: Player) -> Rival:
	var world: Node = get_parent()
	if world == null or not world.has_method("add_rival") or p == null:
		return null
	var from: Vector3 = spot_near(p, 25.0, 38.0)
	if from == Vector3.INF:
		var ang: float = randf() * TAU
		from = p.global_position + Vector3(cos(ang), 0, sin(ang)) * 30.0
	var crow: Rival = world.call("add_rival", from) as Rival
	if crow == null:
		return null
	crow.send_after(p)
	print("[Territory] a Crow (%s) is sent after %s in %s" % [crow.name, p.player_name, district_at(p.global_position)])
	p.phone_message("Unknown", "Told you. Look behind you.", "")
	return crow


## A walkable outdoor spot (navmesh, nothing overhead) `near`..`far` m from `who`, or INF. The walking path from it
## to `who` may be at most `detour` x the straight distance (no spot behind a block that means a long way round).
static func spot_near(who: Node3D, near: float, far: float, detour: float = 1.35) -> Vector3:
	var w3d: World3D = who.get_world_3d()
	var space := w3d.direct_space_state
	var goal: Vector3 = NavigationServer3D.map_get_closest_point(w3d.navigation_map, who.global_position)
	var fallback: Vector3 = Vector3.INF
	for i: int in 32:
		var ang: float = randf() * TAU
		var cand: Vector3 = who.global_position + Vector3(cos(ang), 0, sin(ang)) * randf_range(near, far)
		var pt: Vector3 = NavigationServer3D.map_get_closest_point(w3d.navigation_map, cand)
		if pt.distance_to(cand) > 4.0 or pt.y > 0.6:
			continue
		var up := PhysicsRayQueryParameters3D.create(pt + Vector3.UP * 0.5, pt + Vector3.UP * 12.0, 1)
		if not space.intersect_ray(up).is_empty():
			continue
		var path: PackedVector3Array = NavigationServer3D.map_get_path(w3d.navigation_map, pt, goal, true)
		var length: float = 0.0
		for k: int in range(1, path.size()):
			length += path[k - 1].distance_to(path[k])
		if path.size() >= 2 and path[path.size() - 1].distance_to(goal) < 2.0 and length <= pt.distance_to(goal) * detour:
			return pt
		if fallback == Vector3.INF:
			fallback = pt
	return fallback


## Group "kill_hooks" (PlayerCombat / Player): a player killed someone, or a player was killed.
func on_kill(killer: Node, victim: Node) -> void:
	if not multiplayer.is_server():
		return
	if killer is Player and victim is Rival:
		host_add(district_at((victim as Node3D).global_position), KILL_CROW_GAIN, "Crow killed")
	elif killer is Rival and victim is Player:
		host_add(district_at((victim as Node3D).global_position), -DIED_TO_CROW_LOSS, "killed by a Crow")


func _tick() -> void:
	if multiplayer.is_server():
		var dn := get_tree().get_first_node_in_group(&"day_night") as DayNight
		if dn:
			var h: float = dn.hours
			if _last_hours >= 0.0:
				var passed: float = fposmod(h - _last_hours, 24.0)
				if passed > 0.0 and passed < 2.0:
					for id: String in state.keys():
						if not is_held(id) and influence(id) > 0.0:
							state[id]["inf"] = maxf(0.0, influence(id) - DECAY_PER_HOUR * passed)
			_last_hours = h
		if _dirty:
			_dirty = false
			for peer: int in Net.peers_in_world:
				if peer != multiplayer.get_unique_id():
					_set_all.rpc_id(peer, state)
	_check_my_district()


## Host (Sleep): the night was skipped.
func on_hours_skipped(hours: float) -> void:
	for id: String in state.keys():
		if not is_held(id):
			state[id]["inf"] = maxf(0.0, influence(id) - DECAY_PER_HOUR * hours)
	_dirty = true


## Every peer: a toast when the local player walks into another district.
func _check_my_district() -> void:
	var me := get_parent().get_node_or_null("Players/%d" % multiplayer.get_unique_id()) as Player
	if me == null or me.dead:
		return
	var id: String = district_at(me.global_position)
	if id == _my_district:
		return
	var first: bool = _my_district == ""
	_my_district = id
	if not first and me.ui and me.ui.has_method("toast"):
		me.ui.call("toast", status_text(id))


@rpc("any_peer", "call_remote", "reliable")
func _request_sync() -> void:
	if multiplayer.is_server():
		_set_all.rpc_id(multiplayer.get_remote_sender_id(), state)


@rpc("authority", "call_remote", "reliable")
func _set_all(all: Dictionary) -> void:
	state = all


func _phone_all(contact: String, text: String) -> void:
	var world: Node = get_parent()
	if world and world.has_method("phone_all"):
		world.call("phone_all", contact, text)
