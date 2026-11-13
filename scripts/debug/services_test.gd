class_name ServicesTest
extends RefCounted
## Self-test check "services" (SelfTest._check_services): courier (rank 3), lawyer (rank 4), bribe (rank 5).


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
	p.global_position = sr.building().to_global(Vector3(0.0, 0.2, -3.0))
	p.auto_target = p.global_position
	for i: int in 5:
		await tree.physics_frame
	var data: Dictionary = GameState.get_or_create_player_data("Boss")
	data["cash"] = 20000
	GameState.world.erase("staff")
	GameState.world.erase("legal")
	Staff.tick(0.01)
	Progression.force_gates = true

	# Courier: rank 3, buys the supplies of the stations in the property, restocks + collects a dealer.
	Progression.debug_set_rank(2)
	var msg: String = Staff.debug_hire("Boss", "courier", "starter_room")
	report.call(msg.begins_with("!") and msg.contains("rank 3"), "courier needs rank 3 ('%s')" % msg)
	Progression.debug_set_rank(3)
	if Staff._stations_in("starter_room", PackagingTable).is_empty():
		world.call("debug_weed_corner")
		await tree.physics_frame
	var lockers: Array = Staff._stations_in("starter_room", StorageLocker)
	for l: StorageLocker in lockers:
		l.state["items"] = []
	if not lockers.is_empty():
		(lockers[0] as StorageLocker).state["items"] = [{"id": "weed_bag", "count": 6}, {"id": "meth_bag", "count": 3}]
	msg = Staff.debug_hire("Boss", "courier", "starter_room")
	var courier: Dictionary = _member("courier")
	report.call(not courier.is_empty(), "hired a courier ('%s')" % msg)
	msg = Staff.debug_hire("Boss", "dealer", "old_town")
	var dealer: Dictionary = _member("dealer")
	if dealer.is_empty():
		report.call(false, "hire a dealer ('%s')" % msg)
	else:
		dealer["cash"] = 500
		var cash0: int = int(data["cash"])
		Staff.courier_test_trip(courier)
		report.call(int(dealer["stock"]) == 9 and int(dealer["meth"]) == 3 and int(dealer["cash"]) == 0
				and int(data["cash"]) == cash0 + 500 and Staff._locker_count(lockers, "weed_bag") == 0,
				"courier: 9 bags from the locker to the dealer (3 meth), €500 back to you (%s)" % courier.get("status", ""))
		cash0 = int(data["cash"]) + int(data.get("clean", 0))
		for i: int in 4:
			Staff.courier_test_trip(courier)
		var bought: int = Staff._locker_count(lockers, "soil") + Staff._locker_count(lockers, "weed_seed") + Staff._locker_count(lockers, "baggie")
		report.call(Staff._locker_count(lockers, "baggie") == 20 and Staff._locker_count(lockers, "soil") == 4
				and int(data["cash"]) + int(data.get("clean", 0)) < cash0, "courier bought supplies for the stations there (%d items, %s)" % [
				bought, courier.get("status", "")])
		Staff.host_fire("Boss", str(dealer["uid"]))

	# Lawyer: rank 4, daily fee, gets part of the fine + half the confiscated goods back after an arrest.
	Progression.debug_set_rank(3)
	msg = Legal.host_hire("Boss")
	report.call(msg.begins_with("!") and not Legal.has_lawyer(), "lawyer needs rank 4 ('%s')" % msg)
	Progression.debug_set_rank(4)
	var money0: int = GameState.total_money("Boss")
	msg = Legal.host_hire("Boss")
	report.call(Legal.has_lawyer() and GameState.total_money("Boss") == money0 - Legal.LAWYER_FEE and Legal.lawyer == "Boss",
			"hired the lawyer, first day paid ('%s')" % msg)
	money0 = GameState.total_money("Boss")
	var meth0: int = GameState.count_item("Boss", "meth_bag")
	var back: Dictionary = Legal.on_player_arrested(p, 1000, [{"id": "meth_bag", "count": 5}, {"id": "pistol", "count": 1}])
	report.call(int(back.get("cash", 0)) == 600 and GameState.total_money("Boss") == money0 + 600
			and GameState.count_item("Boss", "meth_bag") == meth0 + 3, "after an arrest the lawyer got €600 + 3 of 5 bags back (%s)" % [back])
	money0 = GameState.total_money("Boss")
	Legal.tick(24.01)
	report.call(GameState.total_money("Boss") == money0 - Legal.LAWYER_FEE, "lawyer fee every in-game day")
	data["cash"] = 0
	data["clean"] = 0
	Legal.tick(24.0)
	report.call(not Legal.has_lawyer(), "an unpaid lawyer quits")
	data["cash"] = 20000

	# Bribe: rank 5, € per star, clears the stars, cooldown.
	var wanted: Wanted = Wanted.current
	if wanted == null:
		report.call(false, "World/Wanted exists")
	else:
		var was_enabled: bool = Wanted.enabled
		Wanted.enabled = true
		wanted.debug_set(p, 2)
		Progression.debug_set_rank(4)
		msg = Legal.host_bribe(p)
		report.call(msg.begins_with("!") and p.wanted_stars == 2, "bribes need rank 5 ('%s')" % msg)
		Progression.debug_set_rank(5)
		money0 = int(data["cash"])
		msg = Legal.host_bribe(p)
		report.call(p.wanted_stars == 0 and int(data["cash"]) == money0 - 2 * Legal.BRIBE_PER_STAR, "bribe: 2 stars gone for €%d ('%s')" % [
				2 * Legal.BRIBE_PER_STAR, msg])
		wanted.debug_set(p, 1)
		msg = Legal.host_bribe(p)
		report.call(p.wanted_stars == 1 and msg.contains("Too hot"), "no second bribe right away ('%s')" % msg)
		Wanted.clear(p, "test")
		Wanted.enabled = was_enabled
	GameState.world.erase("staff")
	GameState.world.erase("legal")
	Legal._bribed_at.clear()
	Staff._broadcast()
	Progression.force_gates = false
	GameState.world.erase("progress")
	GameState.infinite_cash = cash_rule
	GameState.player_data.erase("Boss")
	p.queue_free()
	await tree.physics_frame


static func _member(role: String) -> Dictionary:
	for rec: Dictionary in Staff._members().values():
		if rec["role"] == role:
			return rec
	return {}
