class_name Scenarios
extends RefCounted
## Test scenarios: put the (host) player straight into a situation to check by hand,
## with everything needed (items, money, time of day, place, NPCs nearby).
## - Start: `--scenario=<id>` on the command line, or F9 in the game (host only).
## - A scenario always starts a FRESH game on its own save file (SaveManager.use_scenario_save):
##   the real save is written once before switching and never touched by the scenario.
## - Back to the real game: Leave -> main menu -> "Host - continue".
## Rule (CLAUDE.md): every manual check asked of the user gets a scenario here.

## id -> [title, what to check]. The order is the order in the F9 menu.
const LIST: Array = [
	["style_compare", "Art style proposals A / B / C", "Not a game: three pieces of street side by side. 1/2/3 = streets, 4/5/6 = pistol + AK in view, right mouse + WASD = fly, Esc = back. Tell me which style you want."],
	["weapons_light", "Pistol, SMG, AK-47 + ammo (no police)", "Gun feel: recoil, sound, muzzle flash, reload (R), aiming (RMB), hit marks on walls. 1-3 = weapons, V = first/third person."],
	["weapons_heavy", "Shotgun + sniper + ammo (no police)", "Gun feel of the shotgun (spread) and the sniper (scope zoom, loud shot)."],
	["police_arrest", "Police called on you, pistol holstered", "A patrol car stops next to you and 2 officers come for you. Stand still with the gun away: you get cuffed (illegal items + fine gone, released at the police station). Second try (F9 again): draw the gun (1) and keep it out, or run: they shoot."],
	["rivals_night", "Night at the Crows' yard, AK-47 (no police)", "Two Crows (the night group) come out of their yard and attack anyone in town. Is the fight fair? Can you see them in the dark? Kill one and pick up its loot bag (a new Crow only comes after 1-2 min). Run into your own property: they stop."],
	["crows_turf", "Daytime outside the Crows' fenced yard, AK-47 (no police)", "The Crows hang out all over their yard (walk around, chat; some carry an AK). Outside the fence they leave you alone. Step through the gate: they attack and REMEMBER you, and tell their mates. Back on the street those keep coming; a fresh Crow doesn't know you."],
	["traffic_gunfire", "Main road, pistol (no police)", "Fire near cars: they speed off or turn round, no drivers get out. Horns: short and not too loud."],
	["panic", "Busy main road, pistol (no police)", "Fire a few shots: cars race off and never stop (not at junctions, not for people: they honk and squeeze past). Pedestrians run, and keep running until they are far away and out of your sight (up to ~45 s), then calm down."],
	["night_town", "Main road at 23:00", "Night lighting: street lamps, lit windows, can you see where you walk? F7 (hold) fast-forwards time to dawn."],
	["sell_weed", "6 bags of weed + a customer with an accepted deal", "The customer right in front of you has a GREEN € (deal accepted): E = a short talk, then 'Confirm deal'. New customers text a proposal (Tab > Hush): Accept, Decline or Counter (+10/25/50%: the higher, the more often they say no or walk off). Only an accepted deal turns their € green."],
	["phone", "Phone with a customer text, money", "Tab: chat (Accept / Counter / Decline the customer's proposal), map, webshop (buy something legal, it arrives in the delivery box in the Starter Room)."],
	["grow", "Pot, soil, seeds, water, lamp, rack, table", "Place the pot (select it, LMB), add soil, seed, water (E). Place lamp + rack + packaging table. Hold F7 to speed up time. Harvest -> dry -> package."],
	["storage", "Full inventory at the free locker", "E on the locker: click = 1, Shift+click / drag = whole stack, right click in your pockets = drop. G drops the held item, E picks it up."],
	["furnish", "Own Small House + furniture items", "Place furniture (R/wheel rotates), hold E to pick things up (also the house's own furniture)."],
	["black_market", "Night, in the garage, €6,000", "Walk through the open gate to Rook (only at night): buy seeds, pots, baggies."],
	["gun_shop", "In the gun shop, €8,000", "Buy weapons and ammo boxes from Vince. Are the prices right?"],
	["real_estate", "At the estate agent, €70,000", "Talk to Mrs. Vos: the map on top shows every property for sale; press Where? next to one to see it. Buy one: the sign on the building shows you as owner and it turns into a green house on your phone map (Tab > Map)."],
	["launder", "Own the bakery, €8,000 dirty", "E on the safe in the back office: deposit dirty cash. Hold F7: it comes back as clean money (90%), max per day."],
	["houses", "Inside the Family House", "Walk all floors: stairs, railings, balconies (E opens the balcony door), furniture."],
	["death_respawn", "Low health, cash + items", "Press F4 a few times: you die and drop a loot bag; you respawn at the hospital. Go back and take your bag."],
	["health_regen", "30 health, safe at home", "Wait ~8 s: health slowly comes back to 100. F4 (hurt) pauses it again."],
	["road_crossing", "Main road, people crossing everywhere", "Pedestrians cross the road anywhere (not only at zebras): they wait at the kerb for close cars, then walk straight over. Cars brake for them. (Crossing is made 4x more common here.)"],
	["police_life", "South Street at the police station", "Watch the police: two officers on foot stop passers-by for a chat; a patrol car stops with its light bar on, one officer gets out, talks to someone and gets back in."],
	["wanted_one", "An officer nearby, pistol holstered", "Draw the pistol (1) where the officer sees you: 1 star at once (top right), even if you put it away quickly. Gun away + stand still = cuffed. Keep it out or run = 2 stars, they shoot."],
	["wanted_three", "3 stars on the main road, AK-47", "Police cars race in with sirens and shoot on sight. Break their line of sight: the stars blink, one drops after ~45 s unseen. Killing officers adds stars."],
	["wanted_five", "5 stars on the main road, AK-47", "The whole force: heavy teams (dark uniform, SMG, take more hits) and a police car across the road ahead of you (road block). Can you get away?"],
	["wanted_hide", "2 stars next to your own Small House", "Go inside your house and stay out of sight: the stars drop 3x faster (~15 s instead of ~50 s). Outside they come for you."],
]

## The scenario to set up when the World is ready ("" = none).
static var pending: String = ""
## Scenarios that are their own scene instead of a game.
const SCENES: Dictionary = {"style_compare": "res://scenes/art_test/style_compare.tscn"}


static func title(id: String) -> String:
	for s: Array in LIST:
		if s[0] == id:
			return s[1]
	return ""


static func check_text(id: String) -> String:
	for s: Array in LIST:
		if s[0] == id:
			return s[2]
	return ""


## Host (F9 menu): save the real game, then restart hosting a fresh test game for `id`.
static func restart_into(tree: SceneTree, id: String) -> void:
	if not tree.get_multiplayer().is_server():
		return
	if not SaveManager.scenario_mode:
		SaveManager.save_game()  # the real progress is safe first
	if SCENES.has(id):
		Net.leave_game()
		tree.change_scene_to_file(SCENES[id])
		return
	pending = id
	SaveManager.use_scenario_save()
	var player_name: String = Net.get_player_name(1)
	var port: int = Net.port
	Net.leave_game()
	GameState.reset()
	if Net.host_game(player_name, port) != OK:
		push_error("[Scenario] could not host again on port %d" % port)
		tree.change_scene_to_file(Net.MAIN_MENU_SCENE)
		return
	tree.change_scene_to_file("res://scenes/world/world.tscn")


# --- Setting up (host, World ready + navmesh) ---------------------------------------------

## World calls this once the navmesh is up. Returns false for an unknown id.
static func run(world: Node, id: String) -> bool:
	pending = ""
	var me: Player = world.get_node("Players").get_node_or_null("1") as Player
	if me == null:
		await world.get_tree().create_timer(0.5).timeout
		me = world.get_node("Players").get_node_or_null("1") as Player
	if me == null or check_text(id) == "":
		push_error("[Scenario] unknown scenario '%s' or no host player" % id)
		return false
	var dn := world.get_tree().get_first_node_in_group(&"day_night") as DayNight
	var sr: Property = world.find_child("StarterRoom", true, false).get_node("Property") as Property
	var at_home: Vector3 = sr.building().to_global(Vector3(0.0, 0.2, -3.0))
	var home_front: Vector3 = sr.building().to_global(Vector3(0.0, 0.2, 2.2))
	match id:
		"weapons_light":
			_kit(me, 2000, [["pistol", 1], ["smg", 1], ["ak47", 1], ["ammo_9mm", 120], ["ammo_762", 120]])
			_place(me, Vector3(47.0, 0.2, 17.0), Vector3(47.0, 1.5, 30.0), dn, 11.0)
		"weapons_heavy":
			_kit(me, 2000, [["shotgun", 1], ["sniper", 1], ["ammo_12g", 40], ["ammo_308", 30]])
			_place(me, Vector3(47.0, 0.2, 17.0), Vector3(47.0, 1.5, 30.0), dn, 11.0)
		"police_arrest":
			_kit(me, 3000, [["pistol", 1], ["ammo_9mm", 30], ["weed_bag", 3]])
			var spot := Vector3(-27.0, 0.2, 55.6)
			_place(me, spot, spot + Vector3(-5, 1.5, 3), dn, 13.0)
			var traffic: Traffic = world.get_node("Traffic")
			var car: Car = traffic.spawn_police_car(3, _progress_near(traffic.routes[3], spot + Vector3(9, 0, 3)))
			car.speed = 0.0
			await world.get_tree().create_timer(1.0).timeout
			car.report_crime(me, me.global_position, false)  # (as if you just fired a shot)
		"rivals_night":
			_kit(me, 500, [["ak47", 1], ["ammo_762", 150], ["pistol", 1], ["ammo_9mm", 40]])
			_place(me, Vector3(49.0, 0.2, 4.6), Vector3(55.0, 1.5, 17.0), dn, 22.5)
			Rival.obey_daylight = true
			# Point 31: the night group goes out at once (instead of on the World's 5 s tick).
			var sent: int = 0
			for n: Node in world.get_tree().get_nodes_in_group(&"rivals"):
				if sent < 2 and (n as Rival).role == Rival.Role.YARD:
					(n as Rival).role = Rival.Role.STREET
					sent += 1
		"crows_turf":
			_kit(me, 500, [["ak47", 1], ["ammo_762", 150]])
			_place(me, Vector3(49.0, 0.2, 4.4), Vector3(50.0, 1.5, 20.0), dn, 14.0)
			Rival.obey_daylight = true
			# Two Crows close to the gate so you see them at once (+ the yard's own six).
			world.call("add_rival", Vector3(48.0, 0.1, 13.0), 0)
			world.call("add_rival", Vector3(51.0, 0.1, 15.0), 1)
		"traffic_gunfire":
			_kit(me, 500, [["pistol", 1], ["ammo_9mm", 60]])
			_place(me, Vector3(-4.0, 0.2, -4.6), Vector3(10.0, 1.0, 0.0), dn, 12.0)
		"panic":
			_kit(me, 500, [["pistol", 1], ["ammo_9mm", 60]])
			_place(me, Vector3(-4.0, 0.2, -4.6), Vector3(10.0, 1.0, 0.0), dn, 12.0)
			for i: int in 8:  # people all around you
				var at: Vector3 = Vector3(-4.0 + randf_range(-14.0, 14.0), 0.2, -5.2 if i % 2 == 0 else 5.2)
				world.call("_add_pedestrian", NavigationServer3D.map_get_closest_point(world.get_world_3d().navigation_map, at), i % Pedestrian.VARIANTS.size())
		"night_town":
			_kit(me, 200, [])
			_place(me, home_front, home_front + Vector3(20, 2, 0), dn, 23.0)
		"sell_weed":
			_kit(me, 100, [["weed_bag", 6]])
			_place(me, home_front, home_front + sr.building().global_basis.x * 3.0, dn, 15.0)
			# Point 34: right in front of you, deal already accepted (green €): E = talk, "Confirm deal".
			var npc: Pedestrian = world.call("_add_pedestrian", home_front + sr.building().global_basis.x * 2.2, 1)
			world.call("make_customer", npc)
			npc.accept_deal()
			npc.face(me.global_position)
		"phone":
			_kit(me, 1500, [["weed_bag", 4]])
			_place(me, home_front, home_front + Vector3(10, 1.5, 0), dn, 14.0)
			world.call("make_customer")
		"grow":
			_kit(me, 1000, [["grow_pot", 2], ["soil", 4], ["weed_seed", 6], ["watering_can", 1], ["grow_lamp", 1],
					["drying_rack", 1], ["packaging_table", 1], ["baggie", 20]])
			_place(me, at_home, at_home + sr.building().global_basis.z * -3.0, dn, 10.0)
		"storage":
			_kit(me, 300, [["weed_bag", 10], ["baggie", 20], ["soil", 6], ["weed_seed", 12], ["ammo_9mm", 40],
					["sofa", 1], ["armchair", 1], ["television", 1]])
			var spot: Node3D = world.call("get_marker", "LockerSpot")
			var front: Vector3 = spot.global_position + spot.global_basis.z * 1.3 + Vector3.UP * 0.1
			_place(me, front, spot.global_position + Vector3.UP, dn, 10.0)
		"furnish":
			var house: Property = world.find_child("SmallHouse", true, false).get_node("Property") as Property
			house.host_set_owned(me.player_name)
			_kit(me, 500, [["sofa", 1], ["armchair", 1], ["television", 1], ["bookshelf", 1], ["storage_locker", 1],
					["coffee_table", 1], ["potted_plant", 2]])
			var inside: Vector3 = house.building().to_global(Vector3(0.0, 0.2, -2.5))
			_place(me, inside, house.building().to_global(Vector3(0.0, 1.0, -7.0)), dn, 14.0)
		"black_market":
			_kit(me, 6000, [])
			_place(me, Vector3(23.0, 0.2, 48.6), Vector3(16.4, 1.2, 45.0), dn, 23.0)
		"gun_shop":
			_kit(me, 8000, [])
			_at_keeper(world, me, "GunShop", dn, 12.0)
		"real_estate":
			_kit(me, 40000, [])
			GameState.add_clean(me.player_name, 30000)
			_at_keeper(world, me, "RealEstate", dn, 12.0)
		"launder":
			var bakery: Property = world.find_child("Bakery", true, false).get_node("Property") as Property
			bakery.host_set_owned(me.player_name)
			_kit(me, 8000, [])
			var safe: Node3D = world.find_child("Bakery", true, false).get_node("Safe") as Node3D
			_place(me, safe.global_position + safe.global_basis.z * 1.3 + Vector3.UP * 0.1, safe.global_position + Vector3.UP,
					dn, 12.0)
		"houses":
			var fam: Property = world.find_child("FamilyHouse", true, false).get_node("Property") as Property
			_kit(me, 200, [])
			_place(me, fam.building().to_global(Vector3(0.0, 0.2, -2.0)), fam.building().to_global(Vector3(-2.0, 1.5, -7.0)),
					dn, 13.0)
		"death_respawn":
			_kit(me, 750, [["pistol", 1], ["ammo_9mm", 24], ["weed_bag", 2]])
			_place(me, Vector3(-4.0, 0.2, 4.8), Vector3(-4.0, 1.0, 12.0), dn, 12.0)
			me.health = 30
		"road_crossing":
			_kit(me, 200, [])
			Pedestrian.jaywalk_chance = 0.8
			_place(me, Vector3(12.0, 0.2, 5.0), Vector3(12.0, 1.0, -6.0), dn, 12.0)
			for i: int in 6:
				var p: Vector3 = Vector3(randf_range(-2.0, 26.0), 0.2, 5.2 if i % 2 == 0 else -5.2)
				world.call("_add_pedestrian", p, i % Pedestrian.VARIANTS.size())
		"police_life":
			_kit(me, 300, [])
			var spot := Vector3(-27.0, 0.2, 55.6)
			_place(me, spot + Vector3(-2.0, 0, 0.6), spot + Vector3(8, 1.5, 3), dn, 11.0)
			for i: int in 6:
				var side: float = 0.0 if i % 2 == 0 else 8.8  # both pavements
				world.call("_add_pedestrian", spot + Vector3(randf_range(-12.0, 12.0), 0, side + randf_range(-0.6, 0.6)), i)
			world.call("add_officer", spot + Vector3(7.0, 0, 0.5), spot + Vector3(7.0, 0, 0.5))
			var traffic: Traffic = world.get_node("Traffic")
			var car: Car = traffic.spawn_police_car(3, _progress_near(traffic.routes[3], spot + Vector3(-40, 0, 3)))
			car.question_in = 6.0
			for n: Node in world.get_tree().get_nodes_in_group(&"police"):
				if n is PoliceOfficer:
					(n as PoliceOfficer)._next_chat = 0.0
		"wanted_one":
			_kit(me, 1500, [["weed_bag", 2], ["pistol", 1], ["ammo_9mm", 30]])
			var spot := Vector3(-27.0, 0.2, 55.6)
			_place(me, spot, spot + Vector3(-9, 1.5, 1), dn, 13.0)
			me.combat.select_slot(0)  # hands free (the starter pistol was drawn)
			me.combat.set_equipped(false)
			world.call("add_officer", spot + Vector3(-11, 0, 1.5), spot + Vector3(-11, 0, 1.5))
		"wanted_three", "wanted_five":
			var five: bool = id == "wanted_five"
			_kit(me, 1000, [["ak47", 1], ["ammo_762", 300], ["pistol", 1], ["ammo_9mm", 60]])
			_place(me, Vector3(-4.0, 0.2, 4.8), Vector3(10.0, 1.0, 4.8), dn, 13.0)
			me.combat.host_refill()
			me.combat.select_slot(0)  # the AK in hand
			Wanted.current.debug_set(me, 5 if five else 3)
		"wanted_hide":
			var small: Property = world.find_child("SmallHouse", true, false).get_node("Property") as Property
			small.host_set_owned(me.player_name)
			_kit(me, 500, [["pistol", 1], ["ammo_9mm", 30]])
			var door_out: Vector3 = small.building().to_global(Vector3(0.0, 0.2, 4.0))
			_place(me, door_out, small.building().to_global(Vector3(0.0, 1.2, 0.0)), dn, 13.0)
			Wanted.current.debug_set(me, 2)
		"health_regen":
			_kit(me, 200, [])
			_place(me, at_home, at_home + sr.building().global_basis.z * -3.0, dn, 12.0)
			me.health = 30
	if id in ["weapons_light", "weapons_heavy", "traffic_gunfire", "panic", "rivals_night", "crows_turf", "death_respawn"]:
		_no_police(world)
	me.send_wallet()
	me.combat.host_send_all_ammo()
	print("[Scenario] %s ready" % id)
	me.show_message("SCENARIO '%s': %s" % [id, check_text(id)])
	if "--scenario-quit" in OS.get_cmdline_user_args():
		# Check run: report what the scenario set up a few seconds later, then quit.
		await world.get_tree().create_timer(14.0 if id in ["road_crossing", "police_life"] else 4.0).timeout
		var data: Dictionary = GameState.get_or_create_player_data(me.player_name)
		var near: PackedStringArray = []
		for n: Node in world.get_tree().get_nodes_in_group(&"npc"):
			if (n as Node3D).global_position.distance_to(me.global_position) < 30.0 and not n is Shopkeeper:
				near.append("%s%s" % [n.name, " (customer)" if (n as Pedestrian).wants > 0 else ""])
		for c: Node in world.get_tree().get_nodes_in_group(&"cars"):
			if (c as Car).police and (c as Node3D).global_position.distance_to(me.global_position) < 40.0:
				near.append("police car %.0f m" % (c as Node3D).global_position.distance_to(me.global_position))
		var prop: Property = Placement.property_at(world.get_tree(), me.global_position)
		print("[ScenarioCheck] %s: at %s (%s), %.1f h, health %d, wanted %d, cash %d clean %d, items %s, near: %s" % [id,
				me.global_position.snapped(Vector3.ONE * 0.1), prop.display_name if prop else "street",
				dn.hours if dn else -1.0, me.health, me.wanted_stars, int(data["cash"]), int(data.get("clean", 0)),
				(data["inventory"] as Array).map(func(it: Dictionary) -> String: return "%dx %s" % [int(it["count"]), it["id"]]),
				", ".join(near)])
		if "--scenario-shot" in OS.get_cmdline_user_args():
			# Window runs: also a screenshot of the player's view (HUD included).
			if "--help" in OS.get_cmdline_user_args():
				me.ui.toggle_help()
			if "--shop" in OS.get_cmdline_user_args():
				var best: Shopkeeper = null
				for n: Node in world.get_tree().get_nodes_in_group(&"interactable"):
					if n is Shopkeeper and (best == null or (n as Node3D).global_position.distance_to(me.global_position)
							< best.global_position.distance_to(me.global_position)):
						best = n as Shopkeeper
				if best:
					me.open_shop(best)
			if "--phone-map" in OS.get_cmdline_user_args():
				me.open_phone()
				me.ui.phone._show("map")
			if "--deal" in OS.get_cmdline_user_args():
				for n: Node in world.get_tree().get_nodes_in_group(&"customer"):
					if (n as Pedestrian).deal_ok:
						me.open_deal(n as Pedestrian)
						break
			for f: int in 6:
				await RenderingServer.frame_post_draw
			var path: String = ProjectSettings.globalize_path("res://screenshots/scenario_%s.png" % id)
			world.get_viewport().get_texture().get_image().save_png(path)
			print("[ScenarioCheck] saved %s" % path)
		world.get_tree().quit()
	return true


## Inventory = exactly `items` ([id, count]), `cash` dirty money, no clean money.
static func _kit(me: Player, cash: int, items: Array) -> void:
	var data: Dictionary = GameState.get_or_create_player_data(me.player_name)
	me.combat.host_unload()
	data["inventory"] = []
	data["cash"] = cash
	data["clean"] = 0
	var list: Array = []
	for it: Array in items:
		list.append({"id": it[0], "count": it[1]})
	GameState.give(me.player_name, 0, list)


static func _place(me: Player, pos: Vector3, look_at: Vector3, dn: DayNight, hours: float) -> void:
	if dn:
		dn.set_hours(hours)
	me.teleport(pos)
	var d: Vector3 = look_at - pos
	me.rotation.y = atan2(-d.x, -d.z)
	me.head.rotation.x = 0.0


## In front of the shopkeeper inside `building`.
static func _at_keeper(world: Node, me: Player, building: String, dn: DayNight, hours: float) -> void:
	var b: Node = world.find_child(building, true, false)
	var keepers: Array = b.find_children("*", "Shopkeeper", true, false) if b else []
	if keepers.is_empty():
		push_error("[Scenario] no shopkeeper in %s" % building)
		return
	var k: Node3D = keepers[0]
	_place(me, k.global_position + k.global_basis.z * 2.2 + Vector3.UP * 0.1, k.global_position + Vector3.UP * 1.5, dn, hours)


## Scenarios about other things: no patrol cars that would come after the gunfire.
static func _no_police(world: Node) -> void:
	Wanted.enabled = false  # point 28: no stars either
	for n: Node in world.get_tree().get_nodes_in_group(&"police"):
		n.queue_free()


static func _progress_near(route: TrafficRoute, p: Vector3) -> float:
	var best: float = 0.0
	var best_d: float = INF
	for i: int in int(route.length * 2.0):
		var d: float = (route.sample(i * 0.5)[0] as Vector3).distance_to(p)
		if d < best_d:
			best_d = d
			best = i * 0.5
	return best
