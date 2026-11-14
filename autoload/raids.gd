extends Node
## Lab raids (DESIGN "Rivals & story": "Lab raids: rivals steal stock/machines unless guards or players defend";
## act 2 "the Crows raid your barn" at rank 2), autoload `Raids`. Session B. HOST AUTHORITATIVE.
## State in GameState.world["raids"] = {rolled: bool (tonight's roll done), pending: {prop, at}, wins, losses}.
## - Once per night (DayNight.is_night) the Crows may pick a crew-owned "lab" (a property with production stations)
##   when the crew is rank 2+: a warning text, WARN_HOURS later the raid.
## - Guards (Staff role "guard", rank 4) in that property each take one raider down first.
## - A crew player within DEFEND_RANGE: a LIVE raid: real Crows (World.add_rival, street role, they remember the
##   crew) gather in front of the building. Kill them all before LIVE_SECONDS run out = won; else they get in.
## - Nobody there: decided at once; guards give GUARD_DEFENSE chance each to hold the lab.
## - Lost: STEAL_SHARE of the drugs/bags/supplies in the property's lockers is gone; without guards also one machine;
##   every guard there may die. Won: XP for the crew.

const WARN_HOURS: float = 2.0
const RAID_CHANCE: float = 0.3
const MIN_RANK: int = 2
const DEFEND_RANGE: float = 35.0
const LIVE_SECONDS: float = 150.0
const GUARD_DEFENSE: float = 0.35
const STEAL_SHARE: float = 0.5
const GUARD_DEATH_CHANCE: float = 0.4
const XP_WIN: int = 80
const CROWS: String = "Black Crows"
## What raiders take from the lockers (drugs, bags, supplies).
const LOOT_IDS: Array[String] = ["weed_bag", "meth_bag", "coke_bag", "weed_bud", "fresh_weed", "meth_shard", "meth_tray",
		"cocaine", "coca_paste", "coca_leaves", "lab_chemicals", "activator", "coca_seedling", "process_fluid"]

## Host: the live raid going on now ({} = none): {prop, raiders: Array[Rival], until (s), guards}.
var live: Dictionary = {}


func _is_host() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()


func _data() -> Dictionary:
	var d: Variant = GameState.world.get("raids")
	if not d is Dictionary:
		d = {"rolled": false, "pending": {}, "wins": 0, "losses": 0, "time": 0.0}
		GameState.world["raids"] = d
	return d


func _process(delta: float) -> void:
	if not _is_host() or GameState.world.is_empty() or get_tree().current_scene == null \
			or get_tree().current_scene.get_node_or_null("Players") == null:
		live = {}
		return
	var dn := get_tree().get_first_node_in_group(&"day_night") as DayNight
	if dn == null:
		return
	tick(delta * dn.hours_per_second(), dn.is_night())
	if not live.is_empty():
		_live_tick()


## Host: in-game time passes (`night` = DayNight.is_night()).
func tick(hours: float, night: bool) -> void:
	var d: Dictionary = _data()
	d["time"] = float(d.get("time", 0.0)) + hours
	var pending: Dictionary = d["pending"]
	if not pending.is_empty():
		if float(d["time"]) >= float(pending["at"]) and live.is_empty():
			d["pending"] = {}
			start(str(pending["prop"]))
		return
	if not night:
		d["rolled"] = false
		return
	if bool(d["rolled"]):
		return
	d["rolled"] = true
	if Progression.rank() < MIN_RANK or randf() >= RAID_CHANCE:
		return
	var labs: Array = lab_properties()
	if labs.is_empty():
		return
	announce(String((labs.pick_random() as Property).property_id))


## Crew-owned properties with production stations in them.
func lab_properties() -> Array:
	var out: Array = []
	for n: Node in get_tree().get_nodes_in_group(&"properties"):
		var p := n as Property
		if p.is_crew_owned() and _production_in(p) > 0:
			out.append(p)
	return out


func _production_in(p: Property) -> int:
	var n: int = 0
	for s: Node in get_tree().get_nodes_in_group(&"stations"):
		if (s is ProcessStation or s is GrowPot or s is DryingRack or s is PackagingTable) and p.contains((s as Node3D).global_position):
			n += 1
	return n


## Host: the Crows text the crew and come WARN_HOURS later.
func announce(prop_id: String) -> void:
	var d: Dictionary = _data()
	d["pending"] = {"prop": prop_id, "at": float(d.get("time", 0.0)) + WARN_HOURS}
	var p: Property = Staff.property_node(prop_id)
	_text_crew("Nice little setup in the %s. We're coming to take a look. Soon." % (p.display_name if p else prop_id))
	print("[Raids] announced: %s in %.1f h" % [prop_id, WARN_HOURS])


## Host: the raid on `prop_id` starts now. Returns "live" / "won" / "lost" (tests).
func start(prop_id: String) -> String:
	var prop: Property = Staff.property_node(prop_id)
	if prop == null or not prop.is_crew_owned():
		return ""
	var guards: Array = _guards_in(prop_id)
	var raiders: int = clampi(2 + Progression.rank() / 2, 2, 5)
	var downed: int = mini(guards.size(), raiders)
	raiders -= downed
	print("[Raids] raid on %s: %d raiders (%d taken down by guards)" % [prop_id, raiders, downed])
	if raiders <= 0:
		_won(prop, "Your guards took them all down before they got close.")
		return "won"
	var defenders: Array = _crew_near(prop)
	if not defenders.is_empty():
		_start_live(prop, raiders, defenders, guards.size())
		return "live"
	if randf() < guards.size() * GUARD_DEFENSE:
		_won(prop, "Your guards held the %s. The Crows ran." % prop.display_name)
		return "won"
	_lost(prop, guards)
	return "lost"


func _guards_in(prop_id: String) -> Array:
	return Staff._members().values().filter(func(r: Dictionary) -> bool:
		return r["role"] == "guard" and str(r.get("property", "")) == prop_id)


func _crew_near(prop: Property) -> Array:
	var out: Array = []
	var b: Node3D = prop.building()
	var c: Vector3 = b.global_position if b else prop.global_position
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p := n as Player
		if p and not p.dead and p.global_position.distance_to(c) < DEFEND_RANGE:
			out.append(p)
	return out


func _start_live(prop: Property, count: int, defenders: Array, guards: int) -> void:
	var world: Node = get_tree().current_scene
	var b: Node3D = prop.building()
	var raiders: Array = []
	for i: int in count:
		var at: Vector3 = _front_spot(b, i)
		var r: Rival = world.call("add_rival", at, -1) as Rival
		if r == null:
			continue
		r.role = Rival.Role.STREET
		r.home = at
		for p: Player in defenders:
			r.remember(p, false)
		raiders.append(r)
	live = {"prop": String(prop.property_id), "raiders": raiders, "until": _now() + LIVE_SECONDS, "guards": guards, "front": _front_spot(b, 0)}
	_text_crew("We're at the %s. Come out or we come in." % prop.display_name)
	print("[Raids] LIVE raid on %s: %d Crows at the door" % [prop.property_id, raiders.size()])


## A walkable spot a few metres in front of the building (front = +Z).
func _front_spot(b: Node3D, i: int) -> Vector3:
	var want: Vector3 = b.to_global(Vector3(-2.0 + (i % 5) * 1.0, 0.1, 4.0 + floorf(i / 5.0)))
	var w3d: World3D = (get_tree().current_scene as Node3D).get_world_3d()
	var map: RID = w3d.navigation_map
	if NavigationServer3D.map_get_iteration_id(map) > 0:
		var p: Vector3 = NavigationServer3D.map_get_closest_point(map, want)
		if p.distance_to(want) < 4.0:
			return p
	return want


func _live_tick() -> void:
	var alive: Array = (live["raiders"] as Array).filter(func(r: Rival) -> bool: return is_instance_valid(r) and not r.dead)
	var prop: Property = Staff.property_node(str(live["prop"]))
	if prop == null:
		live = {}
		return
	if alive.is_empty():
		live = {}
		_won(prop, "You fought them off. The %s is still yours." % prop.display_name)
		return
	# Keep them at the building: a raider that wandered off without a target walks back.
	for r: Rival in alive:
		if r.target == null and r.global_position.distance_to(live["front"]) > 15.0 and not r._moving:
			r._go(live["front"], Pedestrian.Anim.RUN)
	if _now() >= float(live["until"]):
		live = {}
		for r: Rival in alive:
			r.role = Rival.Role.YARD  # done here: back to the yard
			r.memory.clear()
		_lost(prop, _guards_in(String(prop.property_id)))


## Tests: how many raiders of the live raid are still standing (-1 = no live raid).
func live_left() -> int:
	if live.is_empty():
		return -1
	return (live["raiders"] as Array).filter(func(r: Rival) -> bool: return is_instance_valid(r) and not r.dead).size()


func _won(prop: Property, text: String) -> void:
	var d: Dictionary = _data()
	d["wins"] = int(d.get("wins", 0)) + 1
	Progression.host_add(XP_WIN, "raid defended")
	_text_crew(text, "Your crew")
	print("[Raids] won at %s" % prop.property_id)


func _lost(prop: Property, guards: Array) -> Dictionary:
	var d: Dictionary = _data()
	d["losses"] = int(d.get("losses", 0)) + 1
	var pid: String = String(prop.property_id)
	var lockers: Array = Staff._stations_in(pid, StorageLocker)
	var stolen: int = 0
	for id: String in LOOT_IDS:
		var n: int = floori(Staff._locker_count(lockers, id) * STEAL_SHARE)
		if n > 0 and Staff._locker_take(lockers, id, n):
			stolen += n
	var machine: String = ""
	if guards.is_empty():
		var machines: Array = []
		for s: Node in get_tree().get_nodes_in_group(&"stations"):
			var st := s as Station
			if st is ProcessStation and st.placed_uid != "" and prop.contains(st.global_position):
				machines.append(st)
		if not machines.is_empty():
			var m: ProcessStation = machines.pick_random()
			machine = m.label
			get_tree().current_scene.call("host_remove_placed", m.placed_uid)
	var dead: PackedStringArray = []
	for g: Dictionary in guards:
		if randf() < GUARD_DEATH_CHANCE:
			Staff._members().erase(str(g["uid"]))
			dead.append(str(g["name"]))
	Staff._mark()
	var text: String = "The Crows got into the %s: %d items gone from the lockers%s%s." % [prop.display_name, stolen,
			(", and they took your %s" % machine.to_lower()) if machine != "" else "",
			(". %s didn't make it" % ", ".join(dead)) if not dead.is_empty() else ""]
	_text_crew(text, "Your crew")
	print("[Raids] lost at %s: %d stolen, machine '%s', guards dead %s" % [pid, stolen, machine, dead])
	return {"stolen": stolen, "machine": machine, "dead": dead}


func _text_crew(text: String, contact: String = CROWS) -> void:
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p := n as Player
		if p:
			p.phone_message(contact, text, "")


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
