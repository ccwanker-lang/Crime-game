class_name StaffTest
extends RefCounted
## Self-test check "staff" (called by SelfTest._check_staff): workers + dealers (Staff autoload).


static func run(t: Node, world: Node3D) -> void:
	var cfg: StaffConfig = Staff.config
	var tree: SceneTree = t.get_tree()
	var report := func(ok: bool, text: String) -> void: t.call("_report", ok, text)
	report.call(cfg != null and cfg.roles.has("grower") and cfg.roles.has("packager") and cfg.roles.has("dealer")
			and cfg.districts.size() >= 3, "staff config: roles + districts (data/staff/staff.tres)")
	var cash_rule: bool = GameState.infinite_cash
	GameState.infinite_cash = false
	var p: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	p.auto_walk = true
	p.name = "1"
	p.player_name = "Boss"
	GameState.player_data.erase("Boss")
	world.get_node("Players").add_child(p)
	var sr: Property = world.find_child("StarterRoom", true, false).get_node("Property") as Property
	p.global_position = sr.building().to_global(Vector3(0.0, 0.2, -3.0))
	p.auto_target = p.global_position
	for i: int in 10:
		await tree.physics_frame
	GameState.get_or_create_player_data("Boss")["cash"] = 5000
	GameState.world.erase("staff")
	Staff.tick(0.01)  # fresh data + candidates

	# Rank gates.
	Progression.force_gates = true
	Progression.debug_set_rank(0)
	var msg: String = Staff.debug_hire("Boss", "grower", "starter_room")
	report.call(msg.begins_with("!") and msg.contains("rank 1") and Staff._members().is_empty(),
			"rank 0: no grower ('%s')" % msg)
	report.call(Staff.role_lock("courier").contains("rank 3"), "courier needs rank 3 ('%s')" % Staff.role_lock("courier"))
	Progression.debug_set_rank(2)

	# The weed corner in the Starter Room + its free locker.
	var pots: Array = Staff._stations_in("starter_room", GrowPot)
	if pots.is_empty():
		world.call("debug_weed_corner")
		await tree.physics_frame
		pots = Staff._stations_in("starter_room", GrowPot)
	var racks: Array = Staff._stations_in("starter_room", DryingRack)
	var lockers: Array = Staff._stations_in("starter_room", StorageLocker)
	report.call(pots.size() >= 1 and racks.size() >= 1 and lockers.size() >= 1 and Staff.beds_in("starter_room") >= 1,
			"Starter Room: %d pots, %d racks, %d lockers, room for %d staff" % [pots.size(), racks.size(), lockers.size(),
			Staff.beds_in("starter_room")])
	if pots.is_empty() or racks.is_empty() or lockers.is_empty():
		_cleanup(p, cash_rule)
		return
	for pot: GrowPot in pots:
		pot.state.merge({"stage": GrowPot.Stage.EMPTY, "water": 0.0, "growth": 0.0}, true)
	for r: DryingRack in racks:
		r.state.merge({"wet": 0, "dry": 0, "progress": 0.0}, true)
	var locker: StorageLocker = lockers[0]
	for l: StorageLocker in lockers:
		l.state["items"] = []
	locker.state["items"] = [{"id": "soil", "count": 4}, {"id": "weed_seed", "count": 4}, {"id": "baggie", "count": 10}]

	# Grower: soil -> seed -> water -> (grown) -> harvest onto the rack.
	msg = Staff.debug_hire("Boss", "grower", "starter_room")
	var grower: Dictionary = _member(Staff, "grower")
	report.call(not grower.is_empty() and int(GameState.get_or_create_player_data("Boss")["cash"]) == 5000 - int(grower.get("wage", 0)),
			"hired a grower, first day paid ('%s')" % msg)
	_ticks(float(pots.size() * 3) / cfg.grower_actions_per_hour + 0.01)
	var all_growing: bool = true
	for pot: GrowPot in pots:
		all_growing = all_growing and int(pot.state["stage"]) == GrowPot.Stage.GROWING and float(pot.state["water"]) >= 0.99
	report.call(all_growing and Staff._locker_count(lockers, "soil") == 4 - pots.size(),
			"grower filled, planted and watered every pot (%s)" % grower.get("status", ""))
	var pot0: GrowPot = pots[0]
	pot0.state["stage"] = GrowPot.Stage.READY
	pot0.state["growth"] = 1.0
	_ticks(1.0 / cfg.grower_actions_per_hour + 0.01)
	report.call(int(pot0.state["stage"]) != GrowPot.Stage.READY and int(racks[0].state["wet"]) == GrowPot.YIELD,
			"grower harvested a plant onto the drying rack (rack wet %d)" % int(racks[0].state["wet"]))

	# Packager: dried weed off the rack -> locker -> packaged with baggies.
	var rack: DryingRack = racks[0]
	rack.state.merge({"wet": 0, "dry": 3, "progress": 0.0}, true)
	msg = Staff.debug_hire("Boss", "packager", "starter_room")
	var room: int = Staff.beds_in("starter_room")
	var packager: Dictionary = _member(Staff, "packager")
	if room < 2:
		report.call(packager.is_empty() and msg.contains("No room"), "one bed/locker = one worker ('%s')" % msg)
		# Add a second locker so the packager fits.
		world.call("host_place", "storage_locker", lockers[0].global_position + lockers[0].global_basis.x * 1.0,
				lockers[0].global_rotation.y)
		await tree.physics_frame
		msg = Staff.debug_hire("Boss", "packager", "starter_room")
		packager = _member(Staff, "packager")
		lockers = Staff._stations_in("starter_room", StorageLocker)
	report.call(not packager.is_empty(), "hired a packager ('%s')" % msg)
	_ticks(4.0 / cfg.packager_bags_per_hour + 0.01)
	report.call(int(rack.state["dry"]) == 0 and Staff._locker_count(lockers, "weed_bag") == 3
			and Staff._locker_count(lockers, "baggie") == 7 and Staff._locker_count(lockers, "weed_bud") == 0,
			"packager: 3 Dried Weed off the rack -> 3 Bags of Weed in the locker (%s)" % packager.get("status", ""))

	# A slept night: the group call "hours_skipped" (Sleep) lets the workers catch up.
	GameState.add_to_stacks(locker.state["items"], "soil", 2, StorageLocker.SLOTS)
	GameState.add_to_stacks(locker.state["items"], "weed_seed", 2, StorageLocker.SLOTS)
	for pot: GrowPot in pots:
		pot.state.merge({"stage": GrowPot.Stage.EMPTY, "water": 0.0, "growth": 0.0}, true)
	tree.call_group(&"hours_skipped", "on_hours_skipped", 8.0)
	var planted: int = 0
	for pot: GrowPot in pots:
		if int(pot.state["stage"]) >= GrowPot.Stage.GROWING:
			planted += 1
	report.call(planted == pots.size(), "after a slept night the grower caught up (%d/%d pots planted)" % [planted, pots.size()])

	# Wages once per in-game day; can't pay -> quits.
	var cash0: int = int(GameState.get_or_create_player_data("Boss")["cash"])
	var day_left: float = 24.0 - float(Staff._data()["clock"])
	Staff.tick(day_left + 0.01)
	var paid: int = cash0 - int(GameState.get_or_create_player_data("Boss")["cash"])
	report.call(paid == int(grower["wage"]) + int(packager.get("wage", 0)), "wages paid after a day: €%d" % paid)
	GameState.get_or_create_player_data("Boss")["cash"] = 0
	GameState.get_or_create_player_data("Boss")["clean"] = 0
	Staff.tick(24.0)
	report.call(_member(Staff, "grower").is_empty() and _member(Staff, "packager").is_empty(), "unpaid workers quit")
	GameState.get_or_create_player_data("Boss")["cash"] = 5000

	# Dealers.
	Progression.debug_set_rank(1)
	msg = Staff.debug_hire("Boss", "dealer", "old_town")
	var dealer: Dictionary = _member(Staff, "dealer")
	var anchor: Vector3 = cfg.districts["old_town"]["anchor"]
	report.call(not dealer.is_empty() and (dealer["pos"] as Vector3).distance_to(anchor) < 8.0,
			"hired a dealer in Old Town at %s ('%s')" % [dealer.get("pos"), msg])
	msg = Staff.debug_hire("Boss", "dealer", "main_east")
	report.call(msg.contains("more than 1"), "rank 1: only one dealer ('%s')" % msg)
	Staff.tick(0.01)
	Staff._broadcast()
	await tree.process_frame
	var views := world.get_node_or_null("StaffViews") as StaffViews
	report.call(views != null and views.get_child_count() == 1 and (views.get_child(0) as Node3D).position.distance_to(dealer["pos"]) < 0.01,
			"the dealer stands in the world (StaffViews)")
	GameState.give("Boss", 0, [{"id": "weed_bag", "count": 6}])
	msg = Staff.host_dealer(p, str(dealer["uid"]), "give")
	report.call(msg.begins_with("!Go to") and int(dealer["stock"]) == 0, "giving bags needs you next to the dealer")
	p.teleport(dealer["pos"] + Vector3(1.0, 0.2, 0.0))
	await tree.physics_frame
	msg = Staff.host_dealer(p, str(dealer["uid"]), "give")
	report.call(int(dealer["stock"]) == 6 and GameState.count_item("Boss", "weed_bag") == 0, "gave the dealer 6 bags ('%s')" % msg)
	var xp0: int = Progression.host_xp()
	var rate: float = float(cfg.districts["old_town"]["sales_per_hour"])
	var old_arrest: float = cfg.arrest_chance_per_hour
	cfg.arrest_chance_per_hour = 0.0
	Staff.tick(4.0 / rate + 0.01)
	var price: int = int(cfg.districts["old_town"]["price"])
	var expect: int = 4 * roundi(price * (1.0 - float(dealer["commission"])))
	report.call(int(dealer["stock"]) == 2 and int(dealer["cash"]) == expect and Progression.host_xp() - xp0 == 4 * cfg.xp_per_dealer_bag,
			"dealer sold 4 bags: €%d waiting (cut %d%%), +%d XP" % [int(dealer["cash"]), roundi(float(dealer["commission"]) * 100.0),
			Progression.host_xp() - xp0])
	cash0 = int(GameState.get_or_create_player_data("Boss")["cash"])
	msg = Staff.host_dealer(p, str(dealer["uid"]), "collect")
	report.call(int(GameState.get_or_create_player_data("Boss")["cash"]) == cash0 + expect and int(dealer["cash"]) == 0,
			"collected €%d ('%s')" % [expect, msg])
	# Saved with the world.
	var text: String = JSON.stringify(JSON.from_native(GameState.to_save_dict()))
	var back: Dictionary = JSON.to_native(JSON.parse_string(text)) as Dictionary
	var saved: Dictionary = ((back["world"] as Dictionary)["staff"] as Dictionary)["members"]
	report.call(saved.has(str(dealer["uid"])) and saved[str(dealer["uid"])]["pos"] is Vector3, "staff is saved with the world")
	# Arrest: the dealer and the stock are gone.
	cfg.arrest_chance_per_hour = 1000.0
	Staff.tick(0.5)
	cfg.arrest_chance_per_hour = old_arrest
	report.call(_member(Staff, "dealer").is_empty() and p.last_phone.size() > 0 and str(p.last_phone[1]).contains("arrested"),
			"an arrested dealer is gone (text: %s)" % [p.last_phone])
	_cleanup(p, cash_rule)
	await tree.physics_frame


## Like the game: many small steps (a worker does at most a few actions per step).
static func _ticks(hours: float) -> void:
	var steps: int = ceili(hours / 0.05)
	for i: int in steps:
		Staff.tick(hours / steps)


static func _member(staff: Node, role: String) -> Dictionary:
	for rec: Dictionary in staff.call("_members").values():
		if rec["role"] == role:
			return rec
	return {}


static func _cleanup(p: Player, cash_rule: bool) -> void:
	GameState.world.erase("staff")
	Staff._broadcast()
	Progression.force_gates = false
	GameState.world.erase("progress")
	GameState.infinite_cash = cash_rule
	p.queue_free()
