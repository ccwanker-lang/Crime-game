class_name StaffAssignTest
extends RefCounted
## Self-test check "staff_assign" (SelfTest._check_staff_assign), NOTES part 12: E on a worker -> their locker, their
## stations (max per role) and the route; a staff locker with a wage box pays them; empty box -> they stop and text,
## money in -> back to work. The worker only uses their own locker + stations.


static func run(t: Node, world: Node3D) -> void:
	var tree: SceneTree = t.get_tree()
	var report := func(ok: bool, text: String) -> void: t.call("_report", ok, text)
	var cash_rule: bool = GameState.infinite_cash
	GameState.infinite_cash = false
	var p: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	p.auto_walk = true
	p.name = "1"
	p.player_name = "Boss"
	GameState.player_data.erase("Boss")
	world.get_node("Players").add_child(p)
	var sr: Property = world.find_child("StarterRoom", true, false).get_node("Property") as Property
	for i: int in 5:
		await tree.physics_frame
	GameState.get_or_create_player_data("Boss")["cash"] = 5000
	GameState.world.erase("staff")
	Staff.tick(0.01)
	Progression.force_gates = true
	Progression.debug_set_rank(4)

	var pots: Array = Staff._stations_in("starter_room", GrowPot)
	if pots.is_empty():
		world.call("debug_weed_corner")
		await tree.physics_frame
		pots = Staff._stations_in("starter_room", GrowPot)
	var lockers: Array = Staff._stations_in("starter_room", StorageLocker)
	if pots.size() < 2 or lockers.is_empty():
		report.call(false, "Starter Room needs 2 pots + a locker (%d, %d)" % [pots.size(), lockers.size()])
		_cleanup(p, cash_rule, null, world)
		return
	pots.sort_custom(func(x: Station, y: Station) -> bool: return x.station_id < y.station_id)
	var l0: StorageLocker = lockers[0]
	var sl := world.call("host_place", "staff_locker", l0.global_position - l0.global_basis.x * 1.2, l0.global_rotation.y) as StaffLocker
	await tree.physics_frame
	report.call(sl != null and sl.station_id.begins_with("placed/") and Staff.beds_in("starter_room") >= 2
			and Placement.shapes(ItemDB.get_item(&"staff_locker"))[0]["size"] == Vector3(0.9, 1.9, 0.5),
			"a staff locker placed in the Starter Room (%s), it counts as a bed" % (sl.station_id if sl else "none"))
	if sl == null:
		_cleanup(p, cash_rule, null, world)
		return
	p.global_position = sl.global_position + sl.global_basis.z * 1.2 + Vector3.UP * 0.1
	p.auto_target = p.global_position
	for pot: GrowPot in pots:
		pot.state.merge({"stage": GrowPot.Stage.EMPTY, "water": 0.0, "growth": 0.0}, true)
	for l: StorageLocker in lockers:
		l.state["items"] = []
	l0.state["items"] = [{"id": "soil", "count": 10}, {"id": "weed_seed", "count": 10}]
	sl.state["items"] = [{"id": "soil", "count": 4}, {"id": "weed_seed", "count": 4}]

	Staff.debug_hire("Boss", "grower", "starter_room")
	var rec: Dictionary = {}
	for r: Dictionary in Staff._members().values():
		if r["role"] == "grower":
			rec = r
	var uid: String = str(rec.get("uid", ""))
	var choices: Array = Staff.assignable_stations(rec)
	var all_pots: bool = pots.all(func(x: Station) -> bool: return choices.has(x))
	report.call(not rec.is_empty() and all_pots and Staff.assignable_lockers(rec).has(sl) and Staff.max_stations("grower") == 6,
			"E on the grower: %d stations to pick from (all pots), lockers incl. the staff locker, max %d" % [choices.size(),
			Staff.max_stations("grower")])

	# Their locker + one pot on the route.
	var msg: String = Staff.host_set_locker("Boss", uid, sl.station_id)
	var msg2: String = Staff.host_assign("Boss", uid, (pots[0] as Station).station_id)
	var route: String = Staff.route_text(rec)
	report.call(str(rec.get("locker")) == sl.station_id and (rec["stations"] as Array) == [(pots[0] as Station).station_id]
			and route.begins_with("Staff Locker -> " + Staff.station_title(pots[0])) and route.ends_with("-> Staff Locker"),
			"locker + one pot assigned: route '%s' ('%s' / '%s')" % [route, msg, msg2])

	# Works only their pot, from their locker.
	Staff._data()["clock"] = 0.0
	Staff.tick(1.0)
	var p0: GrowPot = pots[0]
	var others_empty: bool = true
	for i: int in range(1, pots.size()):
		others_empty = others_empty and int((pots[i] as GrowPot).state["stage"]) == GrowPot.Stage.EMPTY
	report.call(int(p0.state["stage"]) == GrowPot.Stage.GROWING and others_empty
			and Staff._locker_count([sl], "soil") == 3 and Staff._locker_count([l0], "soil") == 10,
			"the grower only works their pot, with soil + seed from the staff locker (staff soil %d, other locker %d, %s)" % [
			Staff._locker_count([sl], "soil"), Staff._locker_count([l0], "soil"), rec.get("status", "")])

	# Max stations per worker.
	var old_max: Dictionary = Staff.config.max_stations.duplicate()
	Staff.config.max_stations["grower"] = 1
	msg = Staff.host_assign("Boss", uid, (pots[1] as Station).station_id)
	report.call(msg.begins_with("!") and msg.contains("at most 1") and (rec["stations"] as Array).size() == 1,
			"max stations per worker ('%s')" % msg)
	Staff.config.max_stations = old_max
	# Not a station for this worker (the bakery's safe).
	var safe: Station = null
	for n: Node in tree.get_nodes_in_group(&"stations"):
		if n is LaunderSafe:
			safe = n
			break
	msg = Staff.host_assign("Boss", uid, safe.station_id if safe else "nope")
	report.call(msg.begins_with("!"), "a station elsewhere can't be assigned ('%s')" % msg)
	# Someone else's worker.
	msg = Staff.host_assign("Stranger", uid, (pots[1] as Station).station_id)
	report.call(msg.begins_with("!"), "only the boss assigns ('%s')" % msg)

	# The worker walks to their new station (StaffViews tween).
	Staff._broadcast()  # (the view stands at the first pot)
	await tree.process_frame
	msg = Staff.host_assign("Boss", uid, (pots[1] as Station).station_id)
	Staff._broadcast()
	await tree.process_frame
	var views := world.get_node_or_null("StaffViews") as StaffViews
	var npc: StaffNPC = views._npcs.get(uid) if views else null
	var walking: bool = npc != null and npc._npc.anim_state == Pedestrian.Anim.WALK
	var start_d: float = npc.position.distance_to(rec["pos"]) if npc else -1.0
	await tree.create_timer(2.5).timeout
	report.call(walking and npc.position.distance_to(rec["pos"]) < 0.05 and npc._npc.anim_state == Pedestrian.Anim.TALK,
			"assigned a second pot: the worker walks over to it (%.2f m, walking %s, anim %s) ('%s')" % [start_d, walking,
			npc._npc.anim_state if npc else -1, msg])

	# Wages from the wage box.
	var wage: int = int(rec["wage"])
	var cash0: int = int(GameState.get_or_create_player_data("Boss")["cash"])
	sl.state["wages"] = wage + 20
	Staff.tick(24.0 - float(Staff._data()["clock"]) + 0.01)
	report.call(int(GameState.get_or_create_player_data("Boss")["cash"]) == cash0 and sl.wages() == 20 and not rec.get("unpaid", false),
			"a day later the wage (€%d) comes out of the wage box, not your pocket (box €%d)" % [wage, sl.wages()])
	for pot: GrowPot in pots:
		pot.state.merge({"stage": GrowPot.Stage.EMPTY, "water": 0.0, "growth": 0.0}, true)
	Staff.tick(24.0 - float(Staff._data()["clock"]) + 0.01)
	var still: bool = Staff._members().has(uid)
	report.call(still and rec.get("unpaid", false) and str(rec["status"]).contains("no wage money"),
			"box short of a wage: the grower stops (doesn't quit) and texts you ('%s')" % rec.get("status", ""))
	for pot: GrowPot in pots:
		pot.state.merge({"stage": GrowPot.Stage.EMPTY, "water": 0.0, "growth": 0.0}, true)
	Staff.tick(1.0)
	report.call(int(p0.state["stage"]) == GrowPot.Stage.EMPTY, "... and does no work while unpaid")
	cash0 = int(GameState.get_or_create_player_data("Boss")["cash"])
	msg = Staff.host_wages(p, sl.station_id, 500)
	report.call(not rec.get("unpaid", false) and sl.wages() == 520 - wage
			and int(GameState.get_or_create_player_data("Boss")["cash"]) == cash0 - 500,
			"€500 in the wage box: they take the wage and go back to work ('%s')" % msg)
	Staff.tick(1.0)
	report.call(int(p0.state["stage"]) == GrowPot.Stage.GROWING, "... and work again (%s)" % rec.get("status", ""))
	msg = Staff.host_wages(p, sl.station_id, -100000)
	report.call(sl.wages() == 0 and int(GameState.get_or_create_player_data("Boss")["cash"]) == cash0 + 20 - wage,
			"take the money back out ('%s')" % msg)
	p.global_position += Vector3(0, 0, 25)
	msg = Staff.host_wages(p, sl.station_id, 100)
	report.call(msg.begins_with("!") and sl.wages() == 0, "too far from the locker: refused ('%s')" % msg)

	# Unassign everything: back to automatic.
	Staff.host_assign("Boss", uid, (pots[0] as Station).station_id)
	Staff.host_assign("Boss", uid, (pots[1] as Station).station_id)
	Staff.host_set_locker("Boss", uid, "")
	report.call((rec["stations"] as Array).is_empty() and Staff.route_text(rec).contains("every grow pot"),
			"nothing ticked: automatic again ('%s')" % Staff.route_text(rec))

	# The shop that sells storage lockers sells the staff locker too.
	var sells: bool = false
	for n: Node in world.find_children("*", "Shopkeeper", true, false):
		if &"storage_locker" in (n as Shopkeeper).stock:
			sells = &"staff_locker" in (n as Shopkeeper).stock
			break
	report.call(sells, "the hardware shop sells the staff locker")
	_cleanup(p, cash_rule, sl, world)


static func _cleanup(p: Player, cash_rule: bool, sl: StaffLocker, world: Node3D) -> void:
	if sl:
		sl.state["items"] = []
		sl.state["wages"] = 0
		world.call("host_remove_placed", sl.station_id.trim_prefix("placed/"))
	GameState.world.erase("staff")
	Staff._broadcast()
	Progression.force_gates = false
	GameState.world.erase("progress")
	GameState.infinite_cash = cash_rule
	p.queue_free()
