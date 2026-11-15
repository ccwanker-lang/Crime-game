class_name QualityTest
extends RefCounted
## Self-test check "quality" (SelfTest._check_quality): product quality (Quality) for weed, meth and cocaine:
## ids, premium seed + lamp -> Premium weed through rack + table, Pure Reagent + Fume Hood -> Premium meth through
## the cooling plate, Pure Solvent -> Good cocaine, prices, customers asking for it, dealers selling it first.


static func run(t: Node, world: Node3D) -> void:
	var tree: SceneTree = t.get_tree()
	var report := func(ok: bool, text: String) -> void: t.call("_report", ok, text)

	# Ids + items.
	var missing: Array = []
	for b: String in Quality.TIERED:
		for v: String in Quality.variants(b):
			if ItemDB.get_item(StringName(v)) == null:
				missing.append(v)
	for id: String in ["premium_seed", "pure_reagent", "pure_solvent", "fume_hood"]:
		if ItemDB.get_item(StringName(id)) == null:
			missing.append(id)
	report.call(missing.is_empty() and Quality.base("weed_bag_q3") == "weed_bag" and Quality.tier("meth_shard_q2") == 2
			and Quality.tier("weed_bag") == 1 and Quality.with_tier("cocaine", 3) == "cocaine_q3" and Quality.tier("soil") == 1
			and Quality.with_tier("soil", 3) == "soil", "quality items + ids (missing: %s)" % [missing])
	var name3: String = ItemDB.get_item(&"weed_bag_q3").display_name
	report.call(name3 == "Bag of Premium Weed" and Products.short_name("meth_bag_q2") == "good meth",
			"names: '%s', '%s'" % [name3, Products.short_name("meth_bag_q2")])

	# Prices + rank gates.
	var p1: int = Products.price("meth_bag", 60)
	var p3: int = Products.price("meth_bag_q3", 60)
	report.call(p3 == roundi(p1 * 1.9) and Products.price("weed_bag_q2", 60) == 84, "prices: meth €%d -> premium €%d, good weed €%d" % [
			p1, p3, Products.price("weed_bag_q2", 60)])

	var p: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	p.auto_walk = true
	p.name = "1"
	p.player_name = "Chemist"
	GameState.player_data.erase("Chemist")
	world.get_node("Players").add_child(p)
	var sr: Property = world.find_child("StarterRoom", true, false).get_node("Property") as Property
	var b: Node3D = sr.building()
	p.global_position = b.to_global(Vector3(0.0, 0.2, -3.0))
	p.auto_target = p.global_position
	for i: int in 5:
		await tree.physics_frame
	var pd: Dictionary = GameState.get_or_create_player_data("Chemist")
	pd["inventory"] = []
	GameState.world.erase("quality")

	# --- Weed: premium seed + lamp -> Premium all the way to the bag.
	if Staff._stations_in("starter_room", GrowPot).is_empty():
		world.call("debug_weed_corner")
		await tree.physics_frame
	var pot: GrowPot = Staff._stations_in("starter_room", GrowPot)[0]
	var rack: DryingRack = Staff._stations_in("starter_room", DryingRack)[0]
	var table: PackagingTable = Staff._stations_in("starter_room", PackagingTable)[0]
	var pot0: Dictionary = pot.state.duplicate()
	var rack0: Dictionary = rack.state.duplicate()
	pot.state = pot.default_state()
	pot.state["stage"] = GrowPot.Stage.SOIL
	GameState.give("Chemist", 0, [{"id": "premium_seed", "count": 1}, {"id": "weed_seed", "count": 1}, {"id": "baggie", "count": 20}])
	pot.do_action(p)
	report.call(int(pot.state["q"]) == 1 and GameState.count_item("Chemist", "premium_seed") == 0
			and GameState.count_item("Chemist", "weed_seed") == 1, "a premium seed is planted first")
	pot.state["water"] = 1.0
	var lamp_rate: float = pot.growth_rate()
	pot.tick(GrowPot.GROW_HOURS * 0.3)
	var lit: float = float(pot.state["lit"])
	report.call((lamp_rate > 1.0 and lit > 0.3) or (lamp_rate <= 1.0 and lit == 0.0),
			"growth under a lamp is counted (rate %.1f, %.0f%% lit)" % [lamp_rate, lit * 100.0])
	pot.state["lit"] = 0.6
	pot.state["growth"] = 1.0
	pot.state["stage"] = GrowPot.Stage.READY
	var tier_seen: int = pot.harvest_tier()
	pot.state["lit"] = 0.2
	var tier_dim: int = pot.harvest_tier()
	pot.state["lit"] = 0.6
	pot.do_action(p)
	report.call(tier_seen == 3 and tier_dim == 2 and GameState.count_item("Chemist", "fresh_weed_q3") == GrowPot.YIELD
			and Quality.best_made("weed_bag") == 3,
			"premium seed + lamp = Premium (seed only: %s): %d Premium Fresh Weed" % [Quality.NAMES[tier_dim],
			GameState.count_item("Chemist", "fresh_weed_q3")])
	rack.state = rack.default_state()
	GameState.give("Chemist", 0, [{"id": "fresh_weed", "count": 2}])
	rack.do_action(p)
	var hung_q3: bool = int(rack.state["wet"]) == GrowPot.YIELD and rack.rack_tier() == 3
	rack.do_action(p)  # standard fresh weed: refused on a Premium rack
	report.call(hung_q3 and int(rack.state["wet"]) == GrowPot.YIELD and GameState.count_item("Chemist", "fresh_weed") == 2,
			"the rack holds one quality: Premium hung, Standard refused")
	rack.tick(DryingRack.DRY_HOURS + 0.1)
	rack.do_action(p)
	table.do_action(p)
	report.call(GameState.count_item("Chemist", "weed_bag_q3") == GrowPot.YIELD and GameState.count_item("Chemist", "weed_bud_q3") == 0,
			"dried + packaged: %d Bags of Premium Weed" % GameState.count_item("Chemist", "weed_bag_q3"))
	pot.state = pot0
	rack.state = rack0
	pot.changed()
	rack.changed()

	# --- Meth: Pure Reagent + Fume Hood -> Premium trays -> Premium shards.
	var cooker := world.call("host_place", "cook_station", b.to_global(Vector3(1.5, 0.15, -8.2)), b.global_rotation.y) as CookStation
	var plate := world.call("host_place", "cooling_plate", b.to_global(Vector3(1.6, 0.15, -6.9)), b.global_rotation.y) as CoolingPlate
	await tree.physics_frame
	if cooker == null or plate == null:
		report.call(false, "could not place the meth lab")
		_cleanup(p, world, [cooker, plate])
		return
	GameState.give("Chemist", 0, [{"id": "lab_chemicals", "count": 4}, {"id": "activator", "count": 2}, {"id": "pure_reagent", "count": 1}])
	cooker.do_action(p)
	var with_mix: int = int(cooker.state["tier"])
	report.call(with_mix == 2 and GameState.count_item("Chemist", "pure_reagent") == 0, "Pure Reagent: Good cook (tier %d)" % with_mix)
	cooker.state = cooker.default_state()
	var hood := world.call("host_place", "fume_hood", b.to_global(Vector3(3.0, 0.15, -8.2)), b.global_rotation.y) as FumeHood
	await tree.physics_frame
	GameState.give("Chemist", 0, [{"id": "pure_reagent", "count": 1}])
	cooker.do_action(p)
	report.call(hood != null and cooker.hood_near() and int(cooker.state["tier"]) == 3,
			"Pure Reagent + Fume Hood: Premium cook ('%s')" % cooker.prompt_for(p))
	cooker.tick(CookStation.COOK_HOURS * 0.5)
	cooker.do_action(p)  # stir
	cooker.tick(CookStation.COOK_HOURS)
	cooker.do_action(p)  # take
	GameState.give("Chemist", 0, [{"id": "meth_tray", "count": 1}])
	plate.do_action(p)  # the Premium tray goes first
	var plate_tier: int = int(plate.state["tier"])
	plate.tick(CoolingPlate.COOL_HOURS + 0.1)
	plate.do_action(p)
	report.call(plate_tier == 3 and GameState.count_item("Chemist", "meth_shard_q3") == CoolingPlate.SHARDS
			and GameState.count_item("Chemist", "meth_tray_q3") == 1 and GameState.count_item("Chemist", "meth_tray") == 1,
			"cooling plate keeps the quality: %d Premium Meth Shards (best tray first)" % GameState.count_item("Chemist", "meth_shard_q3"))
	table.do_action(p)
	report.call(GameState.count_item("Chemist", "meth_bag_q3") == CoolingPlate.SHARDS, "packaged Bags of Premium Meth")

	# --- Cocaine: the refinery is a quality step too (Pure Solvent; the hood is out of range).
	var refinery := world.call("host_place", "refinery", b.to_global(Vector3(-1.6, 0.15, -6.0)), b.global_rotation.y) as Refinery
	await tree.physics_frame
	pd["inventory"] = []  # (8 slots: full of the weed + meth runs)
	GameState.give("Chemist", 0, [{"id": "coca_paste", "count": 1}, {"id": "pure_solvent", "count": 1}])
	if refinery:
		refinery.do_action(p)
	report.call(refinery != null and not refinery.hood_near() and int(refinery.state["tier"]) == 2
			and refinery.out_id() == "cocaine_q2", "Pure Solvent: Good cocaine run (%s)" % (
			("tier %d, hood %s, stage %d" % [int(refinery.state["tier"]), refinery.hood_near(), int(refinery.state["stage"])]) if refinery else "not placed"))

	# --- Customers + dealers.
	GameState.world["quality"] = {"meth_bag": 3}
	var asked: Dictionary = {}
	for i: int in 200:
		var q: String = Products.pick_quality("meth_bag")
		asked[q] = int(asked.get(q, 0)) + 1
	report.call(int(asked.get("meth_bag_q3", 0)) > 60 and asked.has("meth_bag") and asked.has("meth_bag_q2")
			and Products.pick_quality("weed_bag") == "weed_bag", "customers ask for the quality you made: %s" % [asked])
	var goods: Array = Staff.dealer_goods()
	report.call(str(goods[0][0]) == "coke_bag_q3" and goods.any(func(g: Array) -> bool: return g[0] == "meth_bag" and g[1] == "meth"),
			"dealers sell the dearest bags first (%s first)" % goods[0][0])

	_cleanup(p, world, [cooker, plate, hood, refinery])
	await tree.physics_frame


static func _cleanup(p: Player, world: Node, placed: Array) -> void:
	for s: Variant in placed:
		if s is Station and is_instance_valid(s):
			world.call("host_remove_placed", (s as Station).placed_uid)
	GameState.world.erase("quality")
	GameState.player_data.erase("Chemist")
	p.queue_free()
