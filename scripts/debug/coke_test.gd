class_name CokeTest
extends RefCounted
## Self-test check "cocaine" (called by SelfTest._check_cocaine): milestone 3 cocaine. Items + black market,
## rank 4 gate, coca bed (water halfway) -> leaves -> leaf press -> paste -> refinery (vent) -> cocaine ->
## packaging table -> Bags of Cocaine; grower + cook run it from the locker; dealers sell cocaine first.


static func run(t: Node, world: Node3D) -> void:
	var tree: SceneTree = t.get_tree()
	var report := func(ok: bool, text: String) -> void: t.call("_report", ok, text)
	var ids: Array = ["coca_seedling", "coca_leaves", "process_fluid", "coca_paste", "cocaine", "coke_bag", "coca_bed",
			"leaf_press", "refinery"]
	var missing: Array = ids.filter(func(id: String) -> bool: return ItemDB.get_item(StringName(id)) == null)
	report.call(missing.is_empty(), "cocaine items exist (missing: %s)" % [missing])
	var rook: Shopkeeper = null
	for k: Node in world.find_children("*", "Shopkeeper", true, false):
		if (k as Shopkeeper).night_only:
			rook = k as Shopkeeper
	report.call(rook != null and [&"coca_seedling", &"process_fluid", &"refinery"].all(func(id: StringName) -> bool: return id in rook.stock),
			"the black market sells the cocaine supplies + machines")
	Progression.force_gates = true
	Progression.debug_set_rank(3)
	var lock3: String = Progression.item_lock(&"refinery")
	Progression.debug_set_rank(4)
	report.call(lock3 != "" and Progression.item_lock(&"refinery") == "", "cocaine needs rank 4 ('%s')" % lock3)

	var cash_rule: bool = GameState.infinite_cash
	GameState.infinite_cash = false
	var p: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	p.auto_walk = true
	p.name = "1"
	p.player_name = "Grower"
	GameState.player_data.erase("Grower")
	world.get_node("Players").add_child(p)
	var sr: Property = world.find_child("StarterRoom", true, false).get_node("Property") as Property
	var b: Node3D = sr.building()
	p.global_position = b.to_global(Vector3(0.0, 0.2, -3.0))
	p.auto_target = p.global_position
	for i: int in 5:
		await tree.physics_frame
	GameState.get_or_create_player_data("Grower")["cash"] = 9000
	var lab: Array = await Scenarios.coke_lab(world, sr)
	var bed: CocaBed = lab[0]
	var press: LeafPress = lab[1]
	var ref: Refinery = lab[2]
	var placed: Array = lab.map(func(s: Station) -> String: return s.placed_uid)
	report.call(sr.contains(bed.global_position) and sr.contains(press.global_position) and sr.contains(ref.global_position),
			"coca bed, leaf press + refinery placed in the Starter Room")

	# By hand.
	GameState.give("Grower", 0, [{"id": "coca_seedling", "count": 4}, {"id": "soil", "count": 2}, {"id": "process_fluid", "count": 2},
			{"id": "baggie", "count": 20}])
	var msg: String = bed.do_action(p)
	bed.tick(CocaBed.GROW_HOURS * 0.55)
	var needs_water: bool = bed.needs_attention() and bed.prompt_for(p).begins_with("Water")
	bed.do_action(p)
	bed.tick(CocaBed.GROW_HOURS * 0.5)
	bed.do_action(p)
	report.call(needs_water and GameState.count_item("Grower", "coca_leaves") == CocaBed.LEAVES,
			"coca bed: planted ('%s'), watered halfway -> %d Coca Leaves" % [msg, CocaBed.LEAVES])
	bed.do_action(p)
	bed.tick(CocaBed.GROW_HOURS * 1.1)
	report.call(int(bed.state["out"]) == 6, "a coca bed nobody watered -> 6 leaves")
	bed.do_action(p)
	msg = press.do_action(p)
	press.tick(LeafPress.PRESS_HOURS + 0.05)
	press.do_action(p)
	report.call(GameState.count_item("Grower", "coca_paste") == 1 and GameState.count_item("Grower", "coca_leaves") == 6,
			"leaf press: 12 leaves + 1 Process Fluid -> 1 Coca Paste ('%s')" % msg)
	ref.do_action(p)
	ref.tick(Refinery.REFINE_HOURS * 0.65)
	var vent: bool = ref.needs_attention()
	ref.do_action(p)
	ref.tick(Refinery.REFINE_HOURS * 0.4)
	ref.do_action(p)
	report.call(vent and GameState.count_item("Grower", "cocaine") == Refinery.OUT, "refinery: vented -> %d Cocaine" % Refinery.OUT)
	var table := PackagingTable.new()
	msg = table.do_action(p)
	table.free()
	report.call(GameState.count_item("Grower", "coke_bag") == Refinery.OUT, "packaging table -> Bags of Cocaine ('%s')" % msg)

	# Staff: a grower tends the coca bed, a cook runs the press + refinery; the locker is the hand-over point.
	GameState.world.erase("staff")
	Staff.tick(0.01)
	var lockers: Array = Staff._stations_in("starter_room", StorageLocker)
	for l: StorageLocker in lockers:
		l.state["items"] = []
	if not lockers.is_empty():
		(lockers[0] as StorageLocker).state["items"] = [{"id": "coca_seedling", "count": 2}, {"id": "soil", "count": 1},
				{"id": "process_fluid", "count": 1}]
	var room_ok: bool = Staff.beds_in("starter_room") >= 2
	if not room_ok and not lockers.is_empty():
		world.call("host_place", "storage_locker", (lockers[0] as Node3D).global_position + (lockers[0] as Node3D).global_basis.x,
				(lockers[0] as Node3D).global_rotation.y)
		await tree.physics_frame
		placed.append(str(int(GameState.world.get("placed_next", 1)) - 1))
		lockers = Staff._stations_in("starter_room", StorageLocker)
	for pot: GrowPot in Staff._stations_in("starter_room", GrowPot):  # weed pots (other checks) keep the grower busy otherwise
		pot.state.merge({"stage": GrowPot.Stage.GROWING, "water": 1.0, "growth": 0.0}, true)
	var m1: String = Staff.debug_hire("Grower", "grower", "starter_room")
	var m2: String = Staff.debug_hire("Grower", "cook", "starter_room")
	report.call(not _member("grower").is_empty() and not _member("cook").is_empty(), "hired a grower + a cook ('%s' / '%s')" % [m1, m2])
	for i: int in 400:  # 20 in-game hours in small steps
		Staff.tick(0.05)
		for s: ProcessStation in [bed, press, ref]:
			s.tick(0.05)
	var coke: int = Staff._locker_count(lockers, "cocaine")
	report.call(coke == Refinery.OUT, "staff: seedlings -> leaves -> paste -> %d Cocaine in the locker (grower: %s, cook: %s)" % [
			coke, _member("grower").get("status", ""), _member("cook").get("status", "")])

	# Dealers sell cocaine first.
	Progression.debug_set_rank(1)
	var old_arrest: float = Staff.config.arrest_chance_per_hour
	Staff.config.arrest_chance_per_hour = 0.0
	msg = Staff.debug_hire("Grower", "dealer", "old_town")
	var dealer: Dictionary = _member("dealer")
	if not dealer.is_empty():
		p.teleport(dealer["pos"] + Vector3(1.0, 0.2, 0.0))
		await tree.physics_frame
		GameState.give("Grower", 0, [{"id": "meth_bag", "count": 2}, {"id": "weed_bag", "count": 2}])
		Staff.host_dealer(p, str(dealer["uid"]), "give")
		var dist: Dictionary = Staff.config.districts["old_town"]
		Staff.tick(1.0 / float(dist["sales_per_hour"]) + 0.01)
		var expect: int = roundi(Products.price("coke_bag", int(dist["price"])) * (1.0 - float(dealer["commission"])))
		report.call(int(dealer["coke"]) == Refinery.OUT - 1 and int(dealer["meth"]) == 2 and int(dealer["cash"]) == expect
				and Staff.dealer_weed(dealer) == 2, "the dealer sells cocaine first (€%d after the cut), stock %s" % [expect, Staff.meth_text(dealer)])
		msg = Staff.host_fire("Grower", str(dealer["uid"]))
		report.call(GameState.count_item("Grower", "coke_bag") == Refinery.OUT - 1 and GameState.count_item("Grower", "meth_bag") == 2
				and GameState.count_item("Grower", "weed_bag") == 2, "firing the dealer gives every kind of bag back ('%s')" % msg)
	else:
		report.call(false, "hire a dealer ('%s')" % msg)
	Staff.config.arrest_chance_per_hour = old_arrest
	for uid: String in placed:
		world.call("host_remove_placed", uid)
	GameState.world.erase("staff")
	Staff._broadcast()
	Progression.force_gates = false
	GameState.world.erase("progress")
	GameState.infinite_cash = cash_rule
	GameState.player_data.erase("Grower")
	p.queue_free()
	await tree.physics_frame


static func _member(role: String) -> Dictionary:
	for rec: Dictionary in Staff._members().values():
		if rec["role"] == role:
			return rec
	return {}
