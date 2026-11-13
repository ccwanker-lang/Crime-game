class_name RankTest
extends RefCounted
## Self-test check "ranks" (called by SelfTest._check_ranks): ranks + XP (Progression).
## Kept in its own file so self_test.gd only needs a one-line hook.


static func run(t: Node, world: Node3D) -> void:
	var cfg: RankConfig = Progression.config
	var ok_cfg: bool = cfg != null and cfg.names.size() == 7 and cfg.xp_for_rank.size() == 7 and cfg.xp_for_rank[0] == 0
	for i: int in range(1, cfg.xp_for_rank.size() if cfg else 0):
		ok_cfg = ok_cfg and cfg.xp_for_rank[i] > cfg.xp_for_rank[i - 1]
	t.call("_report", ok_cfg, "rank config: 7 ranks with rising XP thresholds (data/progression/ranks.tres)")
	if not ok_cfg:
		return
	t.call("_report", Progression.rank_for(0) == 0 and Progression.rank_for(cfg.xp_for_rank[1]) == 1
			and Progression.rank_for(cfg.xp_for_rank[1] - 1) == 0 and Progression.rank_for(999999) == 6,
			"rank_for follows the thresholds")
	t.call("_report", not Progression.gates_on(), "rank gates are off in the self-test by default")
	Progression.force_gates = true
	Progression.debug_set_rank(0)
	var tree: SceneTree = t.get_tree()

	# A player at Vince's counter.
	var dealer: Shopkeeper = null
	for n: Node in world.find_children("*", "Node3D", true, false):
		if n is Shopkeeper and (n as Shopkeeper).shop_name == "Gun Shop":
			dealer = n as Shopkeeper
	var p: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	p.auto_walk = true
	p.name = "1"
	p.player_name = "Ranker"
	var front: Vector3 = dealer.global_position - dealer.global_basis.z * 1.6
	p.auto_target = front
	GameState.player_data.erase("Ranker")
	world.get_node("Players").add_child(p)
	p.global_position = front + Vector3.UP * 0.1
	for i: int in 20:
		await tree.physics_frame
	GameState.get_or_create_player_data("Ranker")["cash"] = 10000
	var results: Array = []
	dealer.buy_result.connect(func(ok: bool, msg: String) -> void: results.append([ok, msg]))
	dealer.request_buy(&"shotgun", 1)
	dealer.request_buy(&"ammo_12g", 1)
	await tree.physics_frame
	t.call("_report", results.size() == 2 and not results[0][0] and str(results[0][1]).contains("rank 1")
			and results[1][0] and GameState.count_item("Ranker", "shotgun") == 0,
			"rank 0: Vince refuses the shotgun, sells ammo: %s" % [results])

	# XP from sales: a fair deal per bag, a phone deal bonus, half for a short deal, none when they run.
	var gained: Array = []
	var on_gain := func(amount: int, reason: String) -> void: gained.append([amount, reason])
	Progression.xp_gained.connect(on_gain)
	var ups: Array = []
	var on_up := func(r: int) -> void: ups.append(r)
	Progression.ranked_up.connect(on_up)
	var npc: Pedestrian = world.call("_add_pedestrian", front + dealer.global_basis.z * -2.0, 1)
	npc.stationary = true
	for i: int in 5:
		await tree.physics_frame
	GameState.give("Ranker", 0, [{"id": "weed_bag", "count": 12}])
	var sell := func(bags: int, outcome: String, phone: bool) -> int:
		var before: int = Progression.host_xp()
		npc.become_customer(bags, 100, 60.0)
		if phone:
			npc._meet_accepted = true
		p.teleport(npc.global_position + Vector3(1.2, 0.1, 0))
		Pedestrian.force_outcome = outcome
		npc._server_sell(1)
		return Progression.host_xp() - before
	var fair: int = sell.call(2, "fair", false)
	var phone_xp: int = sell.call(1, "fair", true)
	var short: int = sell.call(2, "short", false)
	var ran: int = sell.call(1, "run", false)
	t.call("_report", fair == 2 * cfg.xp_per_bag and phone_xp == cfg.xp_per_bag + cfg.xp_phone_deal
			and short == roundi(2 * cfg.xp_per_bag * cfg.xp_short_factor) and ran == 0,
			"sale XP: fair 2 bags %d, phone deal %d, short %d, run %d" % [fair, phone_xp, short, ran])
	t.call("_report", gained.size() >= 3 and int(gained[0][0]) == fair, "the seller gets the +XP popup: %s" % [gained])

	# Fights.
	var crow := Rival.new()
	var cop := PoliceOfficer.new()
	var civ := Pedestrian.new()
	var x0: int = Progression.host_xp()
	Progression.host_kill(p, crow)
	var x1: int = Progression.host_xp()
	Progression.host_kill(p, cop)
	var x2: int = Progression.host_xp()
	Progression.host_kill(p, civ)
	Progression.host_kill(null, crow)  # not a player: nothing
	var x3: int = Progression.host_xp()
	crow.free()
	cop.free()
	civ.free()
	t.call("_report", x1 - x0 == cfg.xp_kill_rival and x2 - x1 == cfg.xp_kill_officer and x3 - x2 == cfg.xp_kill_civilian,
			"fight XP: Crow %d, officer %d, civilian %d" % [x1 - x0, x2 - x1, x3 - x2])

	# Rank up by a sale -> the shotgun unlocks; the estate agent's gates follow.
	Progression.host_add(cfg.xp_for_rank[1] - 5 - Progression.host_xp(), "test")
	ups.clear()
	sell.call(1, "fair", false)
	t.call("_report", Progression.rank() == 1 and ups == [1] and Progression.xp == Progression.host_xp(),
			"a sale over the threshold: rank 1 (%s), banner %s" % [Progression.rank_name(Progression.rank()), ups])
	p.teleport(front + Vector3.UP * 0.1)
	await tree.physics_frame
	results.clear()
	dealer.request_buy(&"shotgun", 1)
	await tree.physics_frame
	t.call("_report", results.size() == 1 and results[0][0] and GameState.count_item("Ranker", "shotgun") == 1,
			"rank 1: the shotgun can be bought: %s" % [results])
	t.call("_report", Progression.property_lock(&"small_house") == "" and Progression.property_lock(&"bakery") != ""
			and Progression.item_lock(&"smg") != "" and Progression.item_lock(&"pistol") == "",
			"rank 1 unlocks: Small House yes, Bakery / SMG not yet")

	# Saved with the world: survives a JSON round trip (SaveManager format).
	var xp_now: int = Progression.host_xp()
	var text: String = JSON.stringify(JSON.from_native(GameState.to_save_dict()))
	GameState.world["progress"] = {"xp": 0}
	GameState.from_save_dict(JSON.to_native(JSON.parse_string(text)) as Dictionary)
	t.call("_report", Progression.host_xp() == xp_now and Progression.xp == xp_now and Progression.rank() == 1,
			"crew XP is saved and loaded (%d XP)" % Progression.xp)

	Progression.xp_gained.disconnect(on_gain)
	Progression.ranked_up.disconnect(on_up)
	GameState.world.erase("progress")
	Progression.force_gates = false
	Progression.request_sync()
	p.queue_free()
	npc.queue_free()
	await tree.physics_frame
