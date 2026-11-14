class_name BulkTest
extends RefCounted
## Self-test check "bulk" (SelfTest._check_bulk): the bulk buyer (BulkDeals autoload, rank 4).


static func run(t: Node, world: Node3D) -> void:
	var tree: SceneTree = t.get_tree()
	var report := func(ok: bool, text: String) -> void: t.call("_report", ok, text)
	var p: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	p.auto_walk = true
	p.name = "1"
	p.player_name = "Boss"
	GameState.player_data.erase("Boss")
	world.get_node("Players").add_child(p)
	var sr: Property = world.find_child("StarterRoom", true, false).get_node("Property") as Property
	var front: Vector3 = sr.building().to_global(Vector3(0.0, 0.2, 5.0))
	p.teleport(front)
	p.auto_target = front
	for i: int in 5:
		await tree.physics_frame
	GameState.world.erase("bulk")
	var was_enabled: bool = BulkDeals.enabled
	BulkDeals.enabled = true
	var pd: Dictionary = GameState.get_or_create_player_data("Boss")
	pd["cash"] = 0
	pd["inventory"] = []

	# No offers below rank 4.
	Progression.debug_set_rank(3)
	BulkDeals.tick(BulkDeals.OFFER_EVERY + BulkDeals.OFFER_SPREAD + 1.0)
	report.call((BulkDeals._data()["offer"] as Dictionary).is_empty(), "rank 3: no bulk buyer")

	# Rank 4: an offer after OFFER_EVERY hours, with a text and a buyer in the world.
	Progression.debug_set_rank(4)
	BulkDeals._data()["next"] = float(BulkDeals._data()["time"]) + 2.0
	BulkDeals.tick(1.0)
	var none_yet: bool = (BulkDeals._data()["offer"] as Dictionary).is_empty()
	BulkDeals.tick(1.5)
	var o: Dictionary = BulkDeals._data()["offer"]
	await tree.process_frame
	await tree.process_frame
	var npc := world.get_node_or_null("BulkBuyer") as BulkBuyerNPC
	report.call(none_yet and not o.is_empty() and int(o["bags"]) >= 20 and int(o["price"]) > 0 and npc != null
			and str(p.last_phone[0]) == BulkDeals.CONTACT and Staff.config.districts.has(str(o["district"])),
			"rank 4: offer %d x %s for €%d in %s, texted, buyer standing there" % [int(o.get("bags", 0)),
			o.get("product", "?"), int(o.get("price", 0)), o.get("district", "?")])
	if npc:
		report.call(npc.global_position.distance_to(o["pos"]) < 0.1, "buyer at the meeting spot")

	# Hand-over: too far, too few bags, then the deal.
	var product: String = str(o["product"])
	var bags: int = int(o["bags"])
	var res: String = BulkDeals.host_sell(p)
	report.call(res.begins_with("!Go"), "too far away: refused")
	p.teleport(o["pos"] + Vector3(1.0, 0.2, 0.0))
	await tree.physics_frame
	await tree.physics_frame
	GameState.give("Boss", 0, [{"id": product, "count": bags - 1}])
	res = BulkDeals.host_sell(p)
	report.call(res.begins_with("!") and GameState.count_item("Boss", product) == bags - 1, "one bag short: refused ('%s')" % res)
	GameState.give("Boss", 0, [{"id": product, "count": 1}])
	var xp0: int = Progression.host_xp()
	res = BulkDeals.host_sell(p)
	await tree.process_frame
	await tree.process_frame
	report.call(not res.begins_with("!") and GameState.count_item("Boss", product) == 0 and int(pd["cash"]) == int(o["price"])
			and Progression.host_xp() - xp0 == bags * BulkDeals.XP_PER_BAG and (BulkDeals._data()["offer"] as Dictionary).is_empty()
			and world.get_node_or_null("BulkBuyer") == null,
			"sold %d bags in one go: €%d, +%d XP, buyer gone ('%s')" % [bags, int(pd["cash"]), Progression.host_xp() - xp0, res])

	# A missed offer expires with a text.
	BulkDeals.new_offer("weed_bag", 20, front + Vector3(3, 0, 0))
	BulkDeals.tick(BulkDeals.WAIT_HOURS + 0.1)
	report.call((BulkDeals._data()["offer"] as Dictionary).is_empty() and int(BulkDeals._data()["missed"]) == 1
			and str(p.last_phone[1]).contains("Waited"), "missed offer expires after %d h with a text" % roundi(BulkDeals.WAIT_HOURS))

	BulkDeals.enabled = was_enabled
	GameState.world.erase("bulk")
	BulkDeals.sync()
	GameState.world.erase("progress")
	GameState.player_data.erase("Boss")
	p.queue_free()
	await tree.physics_frame
