class_name ShopSellersTest
extends RefCounted
## Self-test check "shop_sellers" (SelfTest._check_shop_sellers), city life point 1: ShopStaff puts a seller behind
## the till of every enterable shop (bakery, snack bar), meals heal instead of filling your pockets, other goods
## (flowers, clothes) are normal items, shop types come from signs / names.


static func run(t: Node, world: Node3D) -> void:
	var tree: SceneTree = t.get_tree()
	var report := func(ok: bool, text: String) -> void: t.call("_report", ok, text)
	for i: int in 120:
		if not ShopStaff.sellers.is_empty():
			break
		await tree.physics_frame
	var rows: PackedStringArray = []
	var types: Dictionary = {}
	var bad: PackedStringArray = []
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	for s: ShopSeller in ShopStaff.sellers:
		types[s.shop_type] = true
		var b := s.get_parent() as Node3D
		var front: Vector3 = b.global_basis.z
		var looks: Vector3 = -s.global_basis.z
		# On a floor, inside the building, looking at the front, with free room in front of it (the counter is
		# at most ~1.2 m away, then the shop floor).
		var q := PhysicsRayQueryParameters3D.create(s.global_position + Vector3.UP * 0.5, s.global_position + Vector3.DOWN * 0.4, 1)
		var floor_hit: bool = not space.intersect_ray(q).is_empty()
		var local: Vector3 = b.to_local(s.global_position)
		var ok: bool = floor_hit and looks.dot(front) > 0.95 and absf(local.x) < float(b.get(&"width")) / 2.0 \
				and s.stock.size() >= 3 and s.npc_name != ""
		rows.append("%s (%s, %s)" % [s.npc_name, s.shop_name, s.shop_type])
		if not ok:
			bad.append("%s floor %s look %.2f x %.1f" % [s.name, floor_hit, looks.dot(front), local.x])
	report.call(types.has("bakery") and types.has("snack_bar") and bad.is_empty(), "a seller behind every shop till: %s%s"
			% [", ".join(rows), "" if bad.is_empty() else " - wrong: " + "; ".join(bad)])
	var dup: PackedStringArray = []
	for s: ShopSeller in ShopStaff.sellers:
		for c: Node in s.get_parent().find_children("*", "Node3D", true, false):
			if c is Shopkeeper and c != s:
				dup.append("%s + %s" % [s.npc_name, (c as Shopkeeper).npc_name])
	report.call(dup.is_empty(), "no shop gets two people behind the till (the store, gun shop and dealers keep their own)%s"
			% ("" if dup.is_empty() else ": " + ", ".join(dup)))

	var signs: Array = [["FLOWER POWER", "florist"], ["Pizza Napoli", "restaurant"], ["CAFE DE HOEK", "cafe"],
			["THE RED LION PUB", "bar"], ["URBAN WEAR", "clothing"], ["SNACK BAR", "snack_bar"], ["BARBER", "-"],
			["Steakhouse", "restaurant"]]
	var wrong: PackedStringArray = []
	for sg: Array in signs:
		var b2 := Building.new()
		b2.shop_sign = sg[0]
		var got: String = ShopTypes.type_for(b2)
		b2.free()
		if got != sg[1]:
			wrong.append("%s -> %s" % [sg[0], got])
	report.call(wrong.is_empty(), "shop type from the sign: florist, restaurant, cafe, bar, clothing, snack bar; a barber "
			+ "gets no seller%s" % ("" if wrong.is_empty() else ": " + ", ".join(wrong)))

	# Buying: a meal heals and costs money, flowers go in the pockets.
	var snack: ShopSeller = null
	for s: ShopSeller in ShopStaff.sellers:
		if s.shop_type == "snack_bar":
			snack = s
	if snack == null:
		report.call(false, "no snack bar seller")
		return
	var me: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	me.auto_walk = true
	me.name = "1"
	me.player_name = "Diner"
	var front_pos: Vector3 = snack.global_position - snack.global_basis.z * 2.0
	me.auto_target = front_pos
	world.get_node("Players").add_child(me)
	me.global_position = front_pos + Vector3.UP * 0.1
	for i: int in 20:
		await tree.physics_frame
	GameState.player_data.erase("Diner")
	GameState.get_or_create_player_data("Diner")["cash"] = 100
	me.health = 40
	var answers: Array = []
	var cb := func(ok: bool, msg: String) -> void: answers.append([ok, msg])
	snack.buy_result.connect(cb)
	var cash0: int = int(GameState.get_or_create_player_data(me.player_name)["cash"])
	snack.request_buy(&"burger", 1)
	await tree.process_frame
	var cash1: int = int(GameState.get_or_create_player_data(me.player_name)["cash"])
	var healed: int = me.health
	var in_pockets: bool = GameState.count_item(me.player_name, "burger") > 0
	report.call(healed == 40 + int(ShopTypes.MEAL_HEAL[&"burger"]) and cash0 - cash1 == snack.price_of(&"burger")
			and not in_pockets and not answers.is_empty() and answers[-1][0],
			"a burger at the snack bar: health 40 -> %d, €%d paid, eaten on the spot (%s)" % [healed, cash0 - cash1,
			answers[-1][1] if not answers.is_empty() else "no answer"])
	me.health = Player.MAX_HEALTH - 2
	snack.request_buy(&"steak", 1)  # (not on this menu)
	await tree.process_frame
	report.call(not answers[-1][0] and me.health == Player.MAX_HEALTH - 2, "a snack bar doesn't serve steak (%s)" % answers[-1][1])
	snack.request_buy(&"fries", 2)
	await tree.process_frame
	report.call(answers[-1][0] and me.health == Player.MAX_HEALTH, "health never goes over the maximum (%d)" % me.health)
	snack.buy_result.disconnect(cb)

	# A florist (made for the test in the snack bar's place): roses are an item.
	var flor := (load(ShopStaff.SCENE) as PackedScene).instantiate() as ShopSeller
	flor.shop_type = "florist"
	flor.npc_name = "Rosa"
	flor.stock.assign(ShopTypes.info("florist")["stock"])
	world.add_child(flor)
	flor.global_position = snack.global_position + Vector3(0, 0, 0.01)
	flor.buy_result.connect(cb)
	flor.request_buy(&"rose_bouquet", 1)
	await tree.process_frame
	var roses: int = GameState.count_item(me.player_name, "rose_bouquet")
	report.call(roses == 1 and answers[-1][0], "a florist sells roses into your pockets (%d)" % roses)
	GameState.remove_item(me.player_name, "rose_bouquet", roses)
	flor.queue_free()
	me.queue_free()
	GameState.player_data.erase("Diner")
	await tree.process_frame
