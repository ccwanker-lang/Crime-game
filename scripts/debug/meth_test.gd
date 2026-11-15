class_name MethTest
extends RefCounted
## Self-test check "meth" (called by SelfTest._check_meth): milestone 3 meth. Items + black market stock,
## rank gate, cook -> stir -> trays -> cooling plate -> shards -> packaging table -> Bags of Meth,
## unstirred = half batch, a cook on staff runs the lab from the locker, dealers sell meth for more.


static func run(t: Node, world: Node3D) -> void:
	var tree: SceneTree = t.get_tree()
	var report := func(ok: bool, text: String) -> void: t.call("_report", ok, text)
	var ids: Array = ["lab_chemicals", "activator", "meth_tray", "meth_shard", "meth_bag", "cook_station", "cooling_plate"]
	var missing: Array = ids.filter(func(id: String) -> bool: return ItemDB.get_item(StringName(id)) == null)
	report.call(missing.is_empty(), "meth items exist (missing: %s)" % [missing])
	var rook: Shopkeeper = null
	for k: Node in world.find_children("*", "Shopkeeper", true, false):
		if (k as Shopkeeper).night_only:
			rook = k as Shopkeeper
	report.call(rook != null and Products.BLACK_MARKET_EXTRA.all(func(id: StringName) -> bool: return id in rook.stock),
			"the black market sells the meth supplies + stations")
	Progression.force_gates = true
	Progression.debug_set_rank(1)
	var lock1: String = Progression.item_lock(&"cook_station")
	Progression.debug_set_rank(2)
	report.call(lock1 != "" and Progression.item_lock(&"cook_station") == "" and Progression.item_lock(&"lab_chemicals") == "",
			"meth needs rank 2 ('%s')" % lock1)

	# Customers (A's World.make_customer asks Products): meth only from rank 2, cocaine from rank 4.
	var picks: Dictionary = {}
	Progression.debug_set_rank(1)
	for i: int in 200:
		picks[Quality.base(Products.pick_customer_product())] = true  # (any quality: Quality / quality check)
	var low: Array = picks.keys()
	picks = {}
	Progression.debug_set_rank(4)
	for i: int in 300:
		picks[Quality.base(Products.pick_customer_product())] = true
	report.call(low == ["weed_bag"] and picks.has("meth_bag") and picks.has("coke_bag") and picks.has("weed_bag"),
			"customers: rank 1 only weed %s, rank 4 also meth + cocaine %s" % [low, picks.keys()])
	Progression.debug_set_rank(2)
	var cash_rule: bool = GameState.infinite_cash
	GameState.infinite_cash = false
	var p: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	p.auto_walk = true
	p.name = "1"
	p.player_name = "Cook"
	GameState.player_data.erase("Cook")
	world.get_node("Players").add_child(p)
	var sr: Property = world.find_child("StarterRoom", true, false).get_node("Property") as Property
	var b: Node3D = sr.building()
	p.global_position = b.to_global(Vector3(0.0, 0.2, -3.0))
	p.auto_target = p.global_position
	for i: int in 5:
		await tree.physics_frame
	GameState.get_or_create_player_data("Cook")["cash"] = 5000
	var cooker := world.call("host_place", "cook_station", b.to_global(Vector3(1.5, 0.15, -8.2)), b.global_rotation.y) as CookStation
	var plate := world.call("host_place", "cooling_plate", b.to_global(Vector3(1.6, 0.15, -6.9)), b.global_rotation.y) as CoolingPlate
	await tree.physics_frame
	report.call(cooker != null and plate != null and sr.contains(cooker.global_position) and sr.contains(plate.global_position),
			"cooking station + cooling plate placed in the Starter Room")
	if cooker == null or plate == null:
		_cleanup(p, cash_rule, world, [])
		return
	var placed: Array = [cooker.placed_uid, plate.placed_uid]

	# By hand: load -> stir -> 2 trays.
	GameState.give("Cook", 0, [{"id": "lab_chemicals", "count": 4}, {"id": "activator", "count": 2}, {"id": "baggie", "count": 20}])
	var msg: String = cooker.do_action(p)
	report.call(int(cooker.state["stage"]) == ProcessStation.Stage.RUNNING and GameState.count_item("Cook", "lab_chemicals") == 2
			and GameState.count_item("Cook", "activator") == 1, "started a cook: 2 Lab Chemicals + 1 Activator used ('%s')" % msg)
	cooker.tick(CookStation.COOK_HOURS * 0.5)
	report.call(int(cooker.state["attend"]) == 1 and cooker.prompt_for(p).begins_with("Stir"), "halfway the batch needs a stir")
	msg = cooker.do_action(p)
	cooker.tick(CookStation.COOK_HOURS * 0.6)
	report.call(int(cooker.state["stage"]) == ProcessStation.Stage.DONE and int(cooker.state["out"]) == 2,
			"stirred cook -> 2 Hot Trays ('%s')" % msg)
	cooker.do_action(p)
	report.call(GameState.count_item("Cook", "meth_tray") == 2 and int(cooker.state["stage"]) == ProcessStation.Stage.IDLE,
			"took the 2 Hot Trays")
	# Unstirred: half a batch.
	cooker.do_action(p)
	cooker.tick(CookStation.COOK_HOURS * 1.1)
	report.call(int(cooker.state["out"]) == 1, "a cook nobody stirred -> 1 Hot Tray")
	cooker.do_action(p)
	# Cooling plate: tray -> shards.
	msg = plate.do_action(p)
	plate.tick(CoolingPlate.COOL_HOURS + 0.05)
	plate.do_action(p)
	report.call(GameState.count_item("Cook", "meth_shard") == CoolingPlate.SHARDS and GameState.count_item("Cook", "meth_tray") == 2,
			"cooling plate: 1 Hot Tray -> %d Meth Shards ('%s')" % [CoolingPlate.SHARDS, msg])
	# Packaging table packs meth too.
	var table := PackagingTable.new()
	msg = table.do_action(p)
	table.free()
	report.call(GameState.count_item("Cook", "meth_bag") == CoolingPlate.SHARDS and GameState.count_item("Cook", "meth_shard") == 0,
			"packaging table: shards + baggies -> Bags of Meth ('%s')" % msg)

	# A cook on staff: locker supplies -> shards in the locker.
	GameState.world.erase("staff")
	Staff.tick(0.01)
	var lockers: Array = Staff._stations_in("starter_room", StorageLocker)
	for l: StorageLocker in lockers:
		l.state["items"] = []
	if not lockers.is_empty():
		(lockers[0] as StorageLocker).state["items"] = [{"id": "lab_chemicals", "count": 2}, {"id": "activator", "count": 1}]
	msg = Staff.debug_hire("Cook", "cook", "starter_room")
	report.call(not _member("cook").is_empty(), "hired a cook ('%s')" % msg)
	for i: int in 200:  # 10 in-game hours in small steps; the stations tick along
		Staff.tick(0.05)
		cooker.tick(0.05)
		plate.tick(0.05)
	var shards: int = Staff._locker_count(lockers, "meth_shard")
	report.call(shards == CoolingPlate.SHARDS * 2 and Staff._locker_count(lockers, "lab_chemicals") == 0,
			"the cook ran a full batch: %d Meth Shards in the locker (%s)" % [shards, _member("cook").get("status", "")])

	# Dealers sell meth for more.
	Progression.debug_set_rank(1)
	var old_arrest: float = Staff.config.arrest_chance_per_hour
	Staff.config.arrest_chance_per_hour = 0.0
	msg = Staff.debug_hire("Cook", "dealer", "old_town")
	var dealer: Dictionary = _member("dealer")
	if not dealer.is_empty():
		p.teleport(dealer["pos"] + Vector3(1.0, 0.2, 0.0))
		await tree.physics_frame
		GameState.give("Cook", 0, [{"id": "weed_bag", "count": 2}])
		msg = Staff.host_dealer(p, str(dealer["uid"]), "give")
		report.call(int(dealer["stock"]) == 2 + CoolingPlate.SHARDS and int(dealer["meth"]) == CoolingPlate.SHARDS,
				"gave the dealer weed + meth ('%s')" % msg)
		var dist: Dictionary = Staff.config.districts["old_town"]
		Staff.tick(1.0 / float(dist["sales_per_hour"]) + 0.01)
		var expect: int = roundi(Products.price("meth_bag", int(dist["price"])) * (1.0 - float(dealer["commission"])))
		report.call(int(dealer["meth"]) == CoolingPlate.SHARDS - 1 and int(dealer["cash"]) == expect,
				"the dealer sells meth first, at €%d a bag (after the cut: €%d)" % [Products.price("meth_bag", int(dist["price"])), expect])
	else:
		report.call(false, "hire a dealer ('%s')" % msg)
	Staff.config.arrest_chance_per_hour = old_arrest
	_cleanup(p, cash_rule, world, placed)
	await tree.physics_frame


static func _member(role: String) -> Dictionary:
	for rec: Dictionary in Staff._members().values():
		if rec["role"] == role:
			return rec
	return {}


static func _cleanup(p: Player, cash_rule: bool, world: Node, placed: Array) -> void:
	for uid: String in placed:
		world.call("host_remove_placed", uid)
	GameState.world.erase("staff")
	Staff._broadcast()
	Progression.force_gates = false
	GameState.world.erase("progress")
	GameState.infinite_cash = cash_rule
	GameState.player_data.erase("Cook")
	p.queue_free()
