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
	["grow", "Pot, soil, seeds, water, lamp, rack, table", "B = build mode: place the pot (select it, LMB), B again to leave; add soil, seed, water (E). Place lamp + rack + packaging table. Hold F7 to speed up time. Harvest -> dry -> package. Every E at a pot/rack/table gives a short effect at the object (water drops, a poof; the can tips) - your body no longer kneels. The mouse wheel scrolls through the hotbar."],
	["storage", "Full inventory at the free locker", "E on the locker: click = 1, Shift+click / drag = whole stack, right click in your pockets = drop. G drops the held item, E picks it up."],
	["furnish", "Own Small House + furniture items", "B = build mode: place furniture (R/wheel rotates), hold E to pick things up (also the house's own furniture). Outside build mode E only uses things (no ghost, no pick-up)."],
	["black_market", "Night, in the garage, €6,000", "Walk through the open gate to Rook (only at night): buy seeds, pots, baggies."],
	["gun_shop", "In the gun shop, €8,000", "Buy weapons and ammo boxes from Vince. Are the prices right?"],
	["real_estate", "At the estate agent, €70,000", "Talk to Mrs. Vos: the map on top shows every property for sale; press Where? next to one to see it. Buy one: the sign on the building shows you as owner and it turns into a green house on your phone map (Tab > Map)."],
	["launder", "Own the bakery, €8,000 dirty, €1,200 already in the safe", "E on the safe in the back office opens its screen: what is waiting, how much comes back clean and when. Deposit: the message says '€X deposited -> €Y clean, ready around ...'. Hold F7: the money comes in (HUD clean €), and a text from the Bakery when all of yours is clean."],
	["houses", "Inside the Family House", "Walk all floors: stairs, railings, balconies (E opens the balcony door), furniture."],
	["death_respawn", "Low health, cash + items", "Press F4 a few times: you die and drop a loot bag; you respawn at the hospital. Go back and take your bag."],
	["bookshelf", "A bookshelf to place at home", "B = build mode, LMB places the bookshelf (slot 1), B again. E on it opens the same storage window as the locker (16 stacks). Bookshelves in a house you buy work as storage too. A full one can't be picked up."],
	["sleep", "22:30 next to your bed", "E on the bed: the screen goes dark and the clock jumps to 07:00 (plants and racks catch up). Before 20:00 it says you're not tired. Moving gets you out of bed. In co-op everyone has to be in bed."],
	["trash", "07:48 in front of the Starter Room, a full bin outside", "E on the green bin outside throws your empty boxes + plant waste in it. At 08:00 (about 12 seconds later) a green garbage truck with an orange light drives up, stops next to the bin and empties it. B = build mode: place your own bin (slot 3) on the pavement in front of the door; not on the road, not in front of other people's houses."],
	["health_regen", "30 health, safe at home", "Wait ~8 s: health slowly comes back to 100. F4 (hurt) pauses it again."],
	["road_crossing", "Main road, people crossing everywhere", "Pedestrians cross the road anywhere (not only at zebras): they wait at the kerb for close cars, then walk straight over. Cars brake for them. (Crossing is made 4x more common here.)"],
	["police_life", "South Street at the police station", "Watch the police: two officers on foot stop passers-by for a chat; a patrol car stops with its light bar on, one officer gets out, talks to someone and gets back in."],
	["wanted_one", "An officer nearby, pistol holstered", "Draw the pistol (1) where the officer sees you: NOTHING happens (holding a gun is no crime). Fire a shot: 1 star at once (top right). Gun away + stand still = cuffed. Keep it out or run = 2 stars, they shoot."],
	["wanted_three", "3 stars on the main road, AK-47", "Police cars race in with sirens and shoot on sight. Break their line of sight: the stars blink while they search; after 30 s unseen ALL stars go at once. Seen again = the 30 s start over. Killing officers adds stars."],
	["wanted_five", "5 stars on the main road, AK-47", "The whole force: heavy teams (dark uniform, SMG, take more hits) and a police car across the road ahead of you (road block). Can you get away?"],
	["wanted_hide", "2 stars next to your own Small House", "Go inside your house and stay out of sight: the search runs 3x faster (~7 s instead of 20 s), then both stars go at once. Outside they come for you."],
	["wanted_timer", "3 stars at once, in front of the Small House door, AK-47", "The police know where you are and send 2 cars. Step through the door behind you (E) and stay out of sight: the stars blink and ONE 30 s search timer runs (3 stars x 10 s). Then all 3 stars go at once, and the extra police cars drive off. Let them see you again: the 30 s start over. With 0 stars the town has just its 2 patrol cars again."],
	["police_vs_crows", "23:00 on South Street: a Crow, an officer and a patrol car close by", "Just watch (you stand out of the Crow's reach): the street Crow opens fire on the officer, the officer fires back, the patrol car hears it and its crew gets out. Nobody gets stars for it. Crows killed at night are replaced from a pool of 20 per night; when it's used up no more Crows come until the next night."],
	["park", "15:00 at the park entrance", "Walk through the new park: gravel paths, benches, trees. Two people walk their dog on a lead round the loop (the dog sniffs when they stop). Three youths stand smoking in a circle on the lawn (puffs of smoke). People sit on the benches. The agora (fenced football pitch) is at the end of the cross path."],
	["agora", "15:00 on the agora, a 2-against-2 match going on", "Four NPCs in red and blue shirts play football (passes, shots, GOAL! + score board). Walk into the ball to kick it yourself (Shift = harder). The match ends after a few minutes and they walk off; on a normal day a match starts now and then between 09:00 and 20:00."],
	["car_dealer", "14:00 at Carlo's Cars with €20,000 clean money", "E on Carlo: the car list (Pony Hatch, Comet Sedan, Mule Van) with top speed, seats and price. Buy one: it appears on the lot outside (nose to the road), Carlo texts you. Walk to it: '[F] Drive the ...'. Buying again fills the next spot; with 4 cars on the lot Carlo says to clear it first."],
	["driving", "12:00 on the car lot next to your Comet Sedan (+ a Mule Van)", "F = get in (driver's seat), W/S = gas / brake + reverse, A/D = steer, Space = handbrake, H = horn, mouse = look around (the camera swings back behind the car), F = get out beside the door. Speed at the bottom (km/h). Drive onto the road and around town; walls and cars stop you. People you hit at speed get hurt (that is a crime, like a shot). With 2 instances: the second player presses F at the same car = passenger seat."],
	["cover_garage", "10:00 in your own Corner Garage (South Street) with 3 Spare Parts, a car on the lift", "E on the car on the lift: each press is one work step (sparks, kneel animation, the car rises). Brake pads need 1 Spare Part (you carry 3). After 4 steps: +€260 CLEAN money (a toast message); the next customer comes 2-4 in-game hours later (F7 speeds time up). More parts: phone > Shop > Spare Parts. Then the tool shelf at the back wall: E = it slides aside, walk into the hidden room behind it (build mode B: place stations there). E again closes it."],
	["prison_intro", "A NEW game's start: you wake up in a prison cell (last day inside)", "Follow the box at the top: walk to the cell door (it slides open), talk to Marco in the yard (E: his lines + his number on your phone), get your things at the RELEASE desk by the gate (wallet back), walk out of the gate and E on the yellow bus. Black screen, 'Two hours later', you stand at the bus stop on the west end of Main Road with Marco's package (pistol + rounds) and his text. F2 = skip. With 2 instances: both wake up in their own cell and the bus leaves when both are on it."],
	["late_join", "A friend joins an ongoing game: the short prison intro", "You wake up in a cell with the door already open; the guard tells you to go. Marco's text is on your phone. Walk across the yard to the RELEASE desk by the gate (E), then E on the bus: it leaves at once (black screen) and drops you at the bus stop on Main Road with Marco's package. In a real co-op game the others get a text that you are coming."],
	["west_side", "Point 47: the new west side - Industrial Road, the metalworks, the container yard, the harbour with the ship, your car ready", "Drive (F, WASD) or walk: Main Road goes on west past the tree belt; Industrial Road turns south to the harbour (Quay Road). Check: the Lab Warehouse (FOR SALE, Industrial Road) and the Harbour Storage on the quay can be entered; you can't fall into the sea; the phone map (Tab > Map) shows the new roads, the sea and the labels Metalworks/Harbour; traffic drives down to the quay and back."],
	["countryside", "Point 47b: Hollow Farm at the top of Country Lane - the barn (for sale), farmhouse, silo, fields", "You stand in the farmyard in front of the red barn (FOR SALE, Hollow Farm Barn €30,000): go in (E on the door). Walk down Country Lane between the fields to Main Road. Phone map (Tab > Map) shows the lane and the farm."],
	["harbour_crows", "Point 47c: the Crows' private pier at the west end of the quay - 3 armed Crows, you with a pistol", "You stand on Quay Road by the PRIVATE PIER sign. The Crows stroll between the containers and leave you alone on the road; step through the gap in the fence onto the pier and they open fire (with F11 god mode you can watch). Kill one: a new one comes after 1-2 minutes."],
	["no_kneel", "Point 58: no kneeling on E - a poof at the object instead", "Weed corner at home + a sofa and a pot in slot 1/2. V = third person. E on the pots / rack / table: your body stays standing, a short effect plays at the object. B = build mode: place the sofa (LMB) -> poof; hold E on it -> poof, back in your inventory."],
	["open_border", "Points 56/57: walk anywhere up to the hedge at the edge; the fall safety net", "You stand north of the centre (where the invisible wall used to be) next to your car. Walk or drive north-west across the grass to the farm and on to the hedge at the edge: no invisible walls before it. Safety net: F10 (fly), Ctrl to sink deep under the ground, F10 off -> you fall and land back where you last stood, alive."],
	["gas_station", "QuickFuel on North Road: your Comet Sedan almost empty next to pump 1, €500", "The car panel (bottom right) shows fuel 6% when you sit in it (F). Get out, E on the red pump: 'Fill up: 43 L for €86' -> full, money gone (clean money first). Drive around town: the % drops (a full tank is about 3 km). Second car (Mule Van) at pump 2 is completely empty: get in, W = nothing, it only rolls. Below 15% you get a 'Low fuel' message."],
	["turf_take", "15:00 in front of the Starter Room: this district is at 96% influence, a customer waits (green €)", "Phone (Tab) > Turf: every district with its meter (red = Crow turf). E on the customer > Confirm deal: the sale pushes the meter past 100% -> a text 'X is yours now', Turf shows it green. Walk into another district: a toast with its name and owner. Your turf: customers pay 15% more, no Crows roam there at night."],
	["turf_danger", "13:00 in front of the Starter Room: Crow turf (30%), they already warned you, a customer waits", "E on the customer > Confirm deal: a text 'Told you. Look behind you.' and a Crow (black clothes) runs at you from 25-40 m, by day. Fight back (1 = pistol): a dead Crow pushes the district's meter up (+6%), dying to it pushes it down (-8%). Check phone > Turf before and after."],
	["ranks", "Rank 0 (10 XP short of rank 1) in the gun shop", "Top left: rank, XP bar and what the next rank unlocks. E on Vince: the guns show 'Rank N' instead of Buy. Turn round: the customer (green €, deal already accepted): E, Confirm deal -> +XP -> RANK UP banner (Hustler). Vince again: the shotgun can be bought now. F8 = +100 XP (try the estate agent's list too)."],
	["staff_workers", "Rank 2: a grower + a packager in your Starter Room", "Hold F7 to speed up time and watch: the grower fills the pots with soil, plants, waters and harvests onto the drying rack; the packager takes the dried weed off and packages it (bags end up in the locker: E on it). E on a worker = what they are doing. Tab > Crew: your staff, wages, Fire, and Benny's candidates (Hire tab)."],
	["dealers", "Rank 1, 10 bags, next to your dealer in Old Town", "E on the dealer: Give all my bags, then hold F7: they sell about 1 bag per in-game hour (+XP, top-left panel). E again: Collect. Tab > Crew > Hire: Benny's people (pick a district or a property). Rank 1 allows 1 dealer: F8 a few times for more."],
	["meth_market", "Rank 2, night, €5,000 at Rook's black market", "Rook now also sells Lab Chemicals, Activator, the Cooking Station and the Cooling Plate (rank 2); the cocaine supplies + machines show Rank 4 (F8 a few times = more XP). Buy a station: it goes into your pockets (place it with B in your own property)."],
	["meth_lab", "Rank 2: cooking station + cooling plate in your Starter Room, supplies in your pockets", "E on the cooking station: start a cook. Hold F7: halfway it shows STIR! (E) - stirred = 2 Hot Trays, not stirred = 1. Take the trays, E on the cooling plate, F7, E = Meth Shards. Then the packaging table: shards + baggies = Bags of Meth."],
	["meth_cook", "Rank 2: a cook + a packager run the meth lab in your Starter Room", "Hold F7 and watch: the cook starts a cook (supplies from the locker), stirs, pours the trays on the cooling plate and breaks them; the packager bags the shards (into the locker: E on it). E on a worker = what they are doing."],
	["meth_dealer", "Rank 1, 6 Bags of Meth + 4 Bags of Weed, next to your dealer", "E on the dealer: Give all my bags (weed + meth). Hold F7: they sell meth first, for about twice the price of weed. E again: Collect."],
	["meth_customer", "Rank 2, 5 Bags of Meth, a customer who wants meth next to you", "The customer (green €) wants meth: E = talk, Confirm deal. Customers ask for meth now and then from rank 2 (cocaine from rank 4); the phone texts say \"bags of meth\"."],
	["coke_lab", "Rank 4: coca bed, leaf press + refinery in your Starter Room, supplies in your pockets", "E on the coca bed: plant. Hold F7: halfway WATER! (E) - watered = 12 leaves, dry = 6. Harvest, E on the leaf press (12 leaves + Process Fluid) = Coca Paste, E on the refinery, VENT! halfway (E) = 8 Cocaine. Then the packaging table: Bags of Cocaine."],
	["coke_staff", "Rank 4: a grower + a cook run the cocaine lab in your Starter Room", "Hold F7 and watch: the grower plants + waters the coca bed (seedlings + soil from the locker), the cook presses the leaves and runs the refinery; the cocaine ends up in the locker (E on it). E on a worker = what they are doing."],
	["courier", "Rank 3: a courier in your Starter Room, bags in the locker, a dealer in Old Town", "Hold F7: the courier takes the bags from the locker to your dealer and brings the cash back (phone text), then buys soil/seeds/baggies for the stations into the locker (paid from your money). Tab > Crew: what everybody does."],
	["bribe", "Rank 5, 3 wanted stars, €8,000", "Tab > Crew > Services: Bribe Dekker (€1,500 per star) -> the stars are gone. Hire Mr. Hale too (€400 a day): after an arrest he gets 60% of the fine and half of the confiscated goods back (a text from him)."],
	["raid_live", "Rank 2, night, AK + ammo in front of your meth lab: the Crows are coming", "The Crows texted: they raid your Starter Room in a moment (3 of them at the door). Kill them all within 2.5 minutes = raid won (+XP); if they're still standing they get in: half the product in the locker + a machine gone. Inside your property you're safe."],
	["raid_guards", "Rank 4, 2 guards in your Starter Room, you far away, raid in a moment", "Nobody home: the guards fight. Hold F7: the Crows come; each guard takes one down, then they hold the lab (or not: 35% per guard). Read the texts (Tab). Tab > Crew: the guards' status."],
	["roadside", "Rank 5, your Comet Sedan far away on Carlo's lot, you in front of the Starter Room", "Tab > Crew > Services: Roadside Service, 'Bring it here' (€350). A text; about 30 seconds later the car stands on the pavement of the nearest road (second text with the distance). F = get in. Not near a road / car already close = refused."],
	["bulk_deal", "Rank 4, 30 Bags of Meth in your pockets, the bulk buyer waiting next to you", "Read the Dutchman's text (Tab). E on the buyer (yellow label) = 30 bags of meth sold in one go (+XP, money). With fewer bags he refuses. From rank 4 he texts every 20-30 in-game hours (F7) with a new offer somewhere in town; he waits 6 hours."],
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
			# Point 40: something already waiting (a crew mate's deposit), so the screen shows a queue.
			(safe as LaunderSafe).state["queue"] = {"Crewmate": 1200}
			(safe as LaunderSafe).changed()
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
		"wanted_timer":
			var small2: Property = world.find_child("SmallHouse", true, false).get_node("Property") as Property
			_kit(me, 500, [["ak47", 1], ["ammo_762", 150]])
			var door_front: Vector3 = small2.building().to_global(Vector3(0.0, 0.2, 3.0))
			_place(me, door_front, small2.building().to_global(Vector3(0.0, 1.2, 12.0)), dn, 13.0)
			me.combat.host_refill()
			me.combat.select_slot(0)
			Wanted.current.debug_set(me, 3)
		"police_vs_crows":
			_kit(me, 500, [["pistol", 1], ["ammo_9mm", 60]])
			var spot := Vector3(-27.0, 0.2, 55.6)
			_place(me, spot, spot + Vector3(-18, 1.2, 1.5), dn, 23.0)
			me.combat.select_slot(1)  # hands free
			world.call("add_officer", spot + Vector3(-11, 0, 1.5), spot + Vector3(-11, 0, 1.5))
			Rival.obey_daylight = true
			var crow: Rival = world.call("add_rival", spot + Vector3(-27, 0, 2.0), 0)
			crow.role = Rival.Role.STREET
			crow.home = crow.global_position
			var traffic2: Traffic = world.get_node("Traffic")
			traffic2.spawn_police_car(3, fposmod(_progress_near(traffic2.routes[3], spot) - 40.0, traffic2.routes[3].length))
		"park":
			_kit(me, 300, [["weed_bag", 3]])
			_place(me, Vector3(-7.0, 0.3, 19.0), Vector3(-2.0, 1.2, 30.0), dn, 15.0)
			var path: Array[Vector3] = world.call("park_path")
			if path.size() >= 4:
				world.call("add_park_goer", path[0] + Vector3(0.0, 0.0, 3.0), ParkGoer.Role.DOG)
				world.call("add_park_goer", path[2], ParkGoer.Role.DOG)
			var smoke: Node3D = world.find_child("ParkSmokeSpot", true, false) as Node3D
			if smoke:
				for i: int in 3:
					var y: ParkGoer = world.call("add_park_goer", smoke.global_position + Vector3(cos(TAU * i / 3.0), 0.1, sin(TAU * i / 3.0)) * 0.9, ParkGoer.Role.SMOKER)
					y.slot = TAU * i / 3.0
		"agora":
			_kit(me, 300, [])
			var ag: Agora = world.find_child("Agora", true, false) as Agora
			if ag:
				_place(me, ag.to_global(Vector3(-2.0, 0.3, 3.5)), ag.to_global(Vector3(2.0, 0.8, -1.0)), dn, 15.0)
				ag.start_match(4, 6.0)
				for p: ParkGoer in ag.players:
					p.global_position = ag.to_global(Vector3(randf_range(-5.0, 5.0), 0.1, randf_range(-3.0, 3.0)))
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
		"bookshelf":
			_kit(me, 200, [["bookshelf", 1], ["baggie", 20], ["weed_bag", 5]])
			_place(me, at_home, at_home + sr.building().global_basis.z * -3.0, dn, 12.0)
			me.combat.select_slot(0)
		"sleep":
			_kit(me, 200, [])
			var bed: Node3D = null
			for n: Node in world.get_tree().get_nodes_in_group(&"placed"):
				if n is PlacedFurniture and (n as PlacedFurniture).item_id == "bed":
					bed = n as Node3D
			var spot: Vector3 = at_home
			if bed:
				var nav: Vector3 = NavigationServer3D.map_get_closest_point(world.get_world_3d().navigation_map,
						bed.global_position + (at_home - bed.global_position).normalized() * 1.3)
				spot = nav + Vector3.UP * 0.1
			_place(me, spot, bed.global_position + Vector3.UP * 0.3 if bed else at_home, dn, 22.5)
			me.head.rotation.x = -0.45
		"trash":
			_kit(me, 200, [["empty_box", 3], ["plant_waste", 2], ["trash_bin", 1]])
			var spot: Vector3 = outdoor_bin_spot(world, sr)
			var bin := world.call("host_place", "trash_bin", spot, sr.building().global_rotation.y) as TrashBin
			if bin:
				bin.state["trash"] = 30
				bin.changed()
			var away: Vector3 = home_front - spot
			away.y = 0.0
			_place(me, spot + away.normalized() * 2.6 + Vector3.UP * 0.2, spot + Vector3.UP * 0.5, dn, 7.8)
			me.combat.select_slot(3)  # empty hands: the prompt of the bin, not the held box
			print("[Scenario] trash bin at %s, you at %s" % [spot.snapped(Vector3.ONE * 0.1), me.global_position.snapped(Vector3.ONE * 0.1)])
		"ranks":
			Progression.force_gates = true  # (scenarios normally skip rank gates)
			Progression.host_add(Progression.xp_for(1) - 10 - Progression.host_xp(), "scenario")
			_kit(me, 8000, [["weed_bag", 8]])
			_at_keeper(world, me, "GunShop", dn, 12.0)
			var k: Node3D = (world.find_child("GunShop", true, false).find_children("*", "Shopkeeper", true, false)[0]) as Node3D
			var npc: Pedestrian = world.call("_add_pedestrian", k.global_position + k.global_basis.z * 3.6, 1)
			world.call("make_customer", npc)
			npc.accept_deal()  # (point 34: green €, E = talk + Confirm deal)
			npc.face(me.global_position)
			Pedestrian.force_outcome = "fair"
		"staff_workers":
			Progression.force_gates = true
			Progression.debug_set_rank(2)
			_kit(me, 3000, [])
			world.call("debug_weed_corner")
			await world.get_tree().physics_frame
			for l: StorageLocker in Staff._stations_in("starter_room", StorageLocker):
				l.state["items"] = [{"id": "soil", "count": 6}, {"id": "weed_seed", "count": 6}, {"id": "baggie", "count": 20}]
				l.changed()
			Staff.debug_hire(me.player_name, "grower", "starter_room")
			Staff.debug_hire(me.player_name, "packager", "starter_room")
			_place(me, at_home, at_home + sr.building().global_basis.z * -3.0, dn, 9.0)
		"car_dealer":
			_kit(me, 2000, [])
			GameState.get_or_create_player_data(me.player_name)["clean"] = 20000
			var office: Node3D = world.find_child("CarDealer", true, false) as Node3D
			var carlo: Node3D = office.find_child("Carlo", true, false) as Node3D
			_place(me, office.to_global(Vector3(0.0, 0.2, -3.6)), carlo.global_position + Vector3.UP * 1.5, dn, 14.0)
		"west_side":
			_kit(me, 500, [])
			var veh: Vehicles = Vehicles.current
			if veh:
				veh.host_spawn("sedan", 2, Vector3(-97, 0.2, 2.2), PI / 2.0, "", 1.0)
			_place(me, Vector3(-92, 0.3, 5.0), Vector3(-114, 1.5, 30), dn, 15.0)
		"countryside":
			_kit(me, 500, [])
			_place(me, Vector3(-147, 0.3, -80), Vector3(-150, 2.0, -92), dn, 15.0)
		"harbour_crows":
			_kit(me, 200, [["pistol", 1], ["ammo_9mm", 48]])
			world.rival_harbour = 3
			for k: int in 3 - (world.call("_alive_rivals", &"harbour") as Array).size():
				world.add_rival(Rival.yard_point(world, &"harbour"), -1, &"harbour")
			_place(me, Vector3(-163, 0.3, 86.5), Vector3(-176, 1.2, 96), dn, 14.0)
		"no_kneel":
			_kit(me, 500, [["sofa", 1], ["grow_pot", 1], ["soil", 2], ["weed_seed", 2], ["watering_can", 1]])
			world.call("debug_weed_corner")
			_place(me, at_home, at_home + sr.building().global_basis.z * -3.0, dn, 11.0)
		"open_border":
			_kit(me, 200, [])
			var veh: Vehicles = Vehicles.current
			if veh:
				veh.host_spawn("sedan", 1, Vector3(-36, 0.2, -66), PI, "", 1.0)
			_place(me, Vector3(-40, 0.3, -64), Vector3(-120, 1.5, -95), dn, 13.0)
		"gas_station":
			_kit(me, 500, [])
			var veh: Vehicles = Vehicles.current
			var pump1: Node3D = world.find_child("FuelPump1", true, false) as Node3D
			var pump2: Node3D = world.find_child("FuelPump2", true, false) as Node3D
			if veh and pump1 and pump2:
				veh.host_spawn("sedan", 4, pump1.global_position + Vector3(0, 0, -2.2), PI / 2.0, "", 0.06)
				veh.host_spawn("van", 0, pump2.global_position + Vector3(0, 0, -2.4), PI / 2.0, "", 0.0)
				_place(me, pump1.global_position + Vector3(1.6, 0.1, 1.4), pump1.global_position + Vector3.UP * 1.0, dn, 13.0)
		"late_join":
			_kit(me, 500, [["pistol", 1], ["ammo_9mm", 24]])  # (what a new player has)
			if Intro.current:
				Intro.current.debug_late_join(me)
		"prison_intro":
			_kit(me, 500, [["pistol", 1], ["ammo_9mm", 24]])  # (what a new player has)
			if Intro.current:
				Intro.current.debug_start(me)
			var prison: Node3D = world.find_child("Prison", true, false) as Node3D
			if prison and "--yard" in OS.get_cmdline_user_args():  # (screenshot: the yard, Marco, the gate)
				_place(me, prison.to_global(Vector3(-2, 0.2, -6)), prison.to_global(Vector3(3, 1.2, 14)), dn, 8.0)
		"turf_take", "turf_danger":
			var take: bool = id == "turf_take"
			_kit(me, 100, [["weed_bag", 6], ["pistol", 1], ["ammo_9mm", 36]])
			_place(me, home_front, home_front + sr.building().global_basis.x * 3.0, dn, 15.0 if take else 13.0)
			var terr: Territory = Territory.current
			var here: String = Territory.district_at(home_front)
			if terr:
				terr.debug_set(here, 96.0 if take else 30.0, false)
				terr.state[here]["warned"] = true
				Territory.crow_send_chance = 0.0 if take else 1.0
			var npc: Pedestrian = world.call("_add_pedestrian", home_front + sr.building().global_basis.x * 2.2, 1)
			world.call("make_customer", npc)
			npc.accept_deal()
			npc.face(me.global_position)
			Pedestrian.force_outcome = "fair"
			print("[Scenario] district %s at %d%%" % [here, roundi(terr.influence(here)) if terr else -1])
		"cover_garage":
			_kit(me, 500, [["car_parts", 3]])
			var garage: Node3D = world.find_child("CoverGarage", true, false) as Node3D
			var gprop: Property = garage.get_node_or_null("Property") as Property if garage else null
			var bay: RepairBay = garage.find_child("RepairBay", true, false) as RepairBay if garage else null
			if gprop and bay:
				gprop.host_set_owned(me.player_name)
				bay.new_job(1)
				_place(me, bay.global_position + bay.global_basis.x * 0.6 + bay.global_basis.z * 4.2,
						bay.global_position + Vector3.UP * 1.0, dn, 10.0)
		"driving":
			_kit(me, 500, [])
			var veh: Vehicles = Vehicles.current
			var s2: Node3D = world.find_child("CarDelivery2", true, false) as Node3D
			var s3: Node3D = world.find_child("CarDelivery3", true, false) as Node3D
			if veh and s2 and s3:
				var sedan: PlayerCar = veh.host_spawn("sedan", 4, s2.global_position, s2.global_rotation.y)
				veh.host_spawn("van", 0, s3.global_position, s3.global_rotation.y)
				var door: Vector3 = sedan.global_transform * Vector3(-1.6, 0.1, 0.0)
				_place(me, door, sedan.global_position + Vector3.UP * 0.8, dn, 12.0)
		"dealers":
			Progression.force_gates = true
			Progression.debug_set_rank(1)
			_kit(me, 1000, [["weed_bag", 10]])
			Staff.debug_hire(me.player_name, "dealer", "old_town")
			var dealer: Dictionary = {}
			for rec: Dictionary in Staff._members().values():
				dealer = rec
			var dpos: Vector3 = dealer.get("pos", Vector3(-24, 0, -4.6))
			var yaw: float = float(dealer.get("yaw", 0.0))
			var dfwd := Vector3(-sin(yaw), 0, -cos(yaw))  # where the dealer looks
			_place(me, dpos + dfwd * 2.2 + Vector3.UP * 0.2, dpos + Vector3.UP * 1.4, dn, 15.0)
		"meth_market":
			Progression.force_gates = true
			Progression.debug_set_rank(2)
			_kit(me, 5000, [])
			_place(me, Vector3(23.0, 0.2, 48.6), Vector3(16.4, 1.2, 45.0), dn, 23.0)
		"meth_lab", "meth_cook":
			Progression.force_gates = true
			Progression.debug_set_rank(2)
			var lab: Array = await meth_lab(world, sr)
			world.call("debug_weed_corner")  # the packaging table (+ pots, rack)
			await world.get_tree().physics_frame
			if id == "meth_lab":
				_kit(me, 2000, [["lab_chemicals", 4], ["activator", 2], ["baggie", 20]])
			else:
				_kit(me, 3000, [])
				for l: StorageLocker in Staff._stations_in("starter_room", StorageLocker):
					l.state["items"] = [{"id": "lab_chemicals", "count": 4}, {"id": "activator", "count": 2}, {"id": "baggie", "count": 20}]
					l.changed()
				Staff.debug_hire(me.player_name, "cook", "starter_room")
				Staff.debug_hire(me.player_name, "packager", "starter_room")
			var spot: Vector3 = sr.building().to_global(Vector3(0.6, 0.2, -6.6))
			_place(me, spot, (lab[0] as Node3D).global_position + Vector3.UP * 0.9 if not lab.is_empty() else at_home, dn, 10.0)
		"coke_lab", "coke_staff":
			Progression.force_gates = true
			Progression.debug_set_rank(4)
			var lab: Array = await coke_lab(world, sr)
			world.call("debug_weed_corner")  # the packaging table (+ pots, rack)
			await world.get_tree().physics_frame
			if id == "coke_lab":
				_kit(me, 3000, [["coca_seedling", 4], ["soil", 2], ["process_fluid", 2], ["baggie", 20]])
			else:
				_kit(me, 3000, [])
				for l: StorageLocker in Staff._stations_in("starter_room", StorageLocker):
					l.state["items"] = [{"id": "coca_seedling", "count": 4}, {"id": "soil", "count": 2}, {"id": "process_fluid", "count": 2}]
					l.changed()
				for pot: GrowPot in Staff._stations_in("starter_room", GrowPot):  # pots growing: the grower tends the coca bed
					pot.state.merge({"stage": GrowPot.Stage.GROWING, "water": 1.0, "growth": 0.2, "seed": 7}, true)
					pot.changed()
				Staff.debug_hire(me.player_name, "grower", "starter_room")
				Staff.debug_hire(me.player_name, "cook", "starter_room")
			var spot: Vector3 = sr.building().to_global(Vector3(0.6, 0.2, -6.4))
			_place(me, spot, (lab[0] as Node3D).global_position + Vector3.UP * 0.6 if not lab.is_empty() else at_home, dn, 10.0)
		"courier":
			Progression.force_gates = true
			Progression.debug_set_rank(3)
			_kit(me, 5000, [])
			world.call("debug_weed_corner")
			await world.get_tree().physics_frame
			for l: StorageLocker in Staff._stations_in("starter_room", StorageLocker):
				l.state["items"] = [{"id": "weed_bag", "count": 8}, {"id": "meth_bag", "count": 4}]
				l.changed()
				break
			Staff.debug_hire(me.player_name, "courier", "starter_room")
			Staff.debug_hire(me.player_name, "dealer", "old_town")
			_place(me, at_home, at_home + sr.building().global_basis.z * -3.0, dn, 9.0)
		"bribe":
			Progression.force_gates = true
			Progression.debug_set_rank(5)
			_kit(me, 8000, [["meth_bag", 4]])
			_place(me, at_home, at_home + sr.building().global_basis.z * -3.0, dn, 12.0)
			_no_police(world)  # no officers coming, and the stars stay (Wanted off) until you bribe them away
			if Wanted.current:
				Wanted.current.debug_set(me, 3)
		"meth_customer":
			Progression.force_gates = true
			Progression.debug_set_rank(2)
			_kit(me, 1000, [["meth_bag", 5], ["weed_bag", 2]])
			_place(me, home_front + Vector3.UP * 0.1, home_front + sr.building().global_basis.z * 4.0, dn, 14.0)
			var buyer: Pedestrian = world.call("_add_pedestrian", home_front + sr.building().global_basis.z * 3.0, 1)
			buyer.become_customer(2, Products.price("meth_bag", 60) * 2, 900.0, "meth_bag")
			buyer.accept_deal()
			buyer.face(me.global_position)
			Pedestrian.force_outcome = "fair"
		"bulk_deal":
			Progression.force_gates = true
			Progression.debug_set_rank(4)
			_kit(me, 500, [["meth_bag", 30]])
			var spot: Vector3 = home_front + sr.building().global_basis.z * 3.0
			_place(me, spot, spot + sr.building().global_basis.x * 2.0 + Vector3.UP * 1.4, dn, 15.0)
			BulkDeals._data()["next"] = 1.0e9  # no random second offer
			BulkDeals.new_offer("meth_bag", 30, spot + sr.building().global_basis.x * 2.0, sr.building().global_rotation.y - PI / 2.0)
		"roadside":
			Progression.force_gates = true
			Progression.debug_set_rank(5)
			_kit(me, 2000, [])
			var s2r: Node3D = world.find_child("CarDelivery2", true, false) as Node3D
			if Vehicles.current and s2r:
				Vehicles.current.host_spawn("sedan", 4, s2r.global_position, s2r.global_rotation.y)
			_place(me, home_front + sr.building().global_basis.z * 3.0, home_front + sr.building().global_basis.z * 10.0, dn, 12.0)
		"raid_live", "raid_guards":
			Progression.force_gates = true
			Progression.debug_set_rank(2 if id == "raid_live" else 4)
			await meth_lab(world, sr)
			world.call("debug_weed_corner")
			await world.get_tree().physics_frame
			for l: StorageLocker in Staff._stations_in("starter_room", StorageLocker):
				l.state["items"] = [{"id": "meth_bag", "count": 12}, {"id": "weed_bag", "count": 8}, {"id": "lab_chemicals", "count": 4}]
				l.changed()
				break
			if id == "raid_live":
				_kit(me, 2000, [["ak47", 1], ["ammo_762", 120]])
				_place(me, home_front + sr.building().global_basis.z * 3.0, home_front + sr.building().global_basis.z * 10.0, dn, 23.0)
				me.combat.select_slot(0)
			else:
				_kit(me, 4000, [])
				Staff.debug_hire(me.player_name, "guard", "starter_room")
				Staff.debug_hire(me.player_name, "guard", "starter_room")
				_at_keeper(world, me, "GunShop", dn, 22.5)
			Raids._data()["rolled"] = true  # no random second raid tonight
			Raids.announce("starter_room")
			Raids._data()["pending"]["at"] = float(Raids._data()["time"]) + 0.05
		"meth_dealer":
			Progression.force_gates = true
			Progression.debug_set_rank(1)
			_kit(me, 1000, [["meth_bag", 6], ["weed_bag", 4]])
			Staff.debug_hire(me.player_name, "dealer", "old_town")
			var dealer: Dictionary = {}
			for rec: Dictionary in Staff._members().values():
				dealer = rec
			var dpos: Vector3 = dealer.get("pos", Vector3(-24, 0, -4.6))
			var yaw: float = float(dealer.get("yaw", 0.0))
			_place(me, dpos + Vector3(-sin(yaw), 0, -cos(yaw)) * 2.2 + Vector3.UP * 0.2, dpos + Vector3.UP * 1.4, dn, 15.0)
	if id in ["raid_live", "weapons_light", "weapons_heavy", "traffic_gunfire", "panic", "rivals_night", "crows_turf", "death_respawn"]:
		_no_police(world)
	me.send_wallet()
	me.combat.host_send_all_ammo()
	print("[Scenario] %s ready" % id)
	me.show_message("SCENARIO '%s': %s" % [id, check_text(id)])
	if "--scenario-quit" in OS.get_cmdline_user_args():
		# Check run: report what the scenario set up a few seconds later, then quit.
		await world.get_tree().create_timer(14.0 if id in ["road_crossing", "police_life", "trash", "agora"] else 4.0).timeout
		var data: Dictionary = GameState.get_or_create_player_data(me.player_name)
		var near: PackedStringArray = []
		for n: Node in world.get_tree().get_nodes_in_group(&"npc"):
			if (n as Node3D).global_position.distance_to(me.global_position) < 30.0 and not n is Shopkeeper:
				near.append("%s%s" % [n.name, " (customer)" if (n as Pedestrian).wants > 0 else ""])
		for c: Node in world.get_tree().get_nodes_in_group(&"cars"):
			if (c as Car).police and (c as Node3D).global_position.distance_to(me.global_position) < 40.0:
				near.append("police car %.0f m" % (c as Node3D).global_position.distance_to(me.global_position))
		for c: Node in world.get_tree().get_nodes_in_group(&"player_cars"):
			near.append("own car %s %.0f m" % [(c as PlayerCar).spec["name"], (c as Node3D).global_position.distance_to(me.global_position)])
		var prop: Property = Placement.property_at(world.get_tree(), me.global_position)
		print("[ScenarioCheck] %s: at %s yaw %d (%s), %.1f h, health %d, wanted %d, cash %d clean %d, items %s, near: %s" % [id,
				me.global_position.snapped(Vector3.ONE * 0.1), roundi(rad_to_deg(me.rotation.y)), prop.display_name if prop else "street",
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
			if "--safe" in OS.get_cmdline_user_args():
				for n: Node in world.get_tree().get_nodes_in_group(&"stations"):
					if n is LaunderSafe and (n as Node3D).global_position.distance_to(me.global_position) < 4.0:
						(n as LaunderSafe).deposit()
						await world.get_tree().create_timer(0.3).timeout
						me.open_safe(n as LaunderSafe)
			if "--drive" in OS.get_cmdline_user_args():
				# Point 45: in the nearest own car, 2.5 s of gas with a little steer (chase camera + km/h).
				var car: PlayerCar = Vehicles.current.nearest(me.global_position, 6.0) if Vehicles.current else null
				if car:
					car.host_enter(me)
					await world.get_tree().physics_frame
					car.test_drive = true
					car.test_input = Vector3(0.15, 1.0, 0.0)
					await world.get_tree().create_timer(2.5).timeout
			if "--phone-map" in OS.get_cmdline_user_args():
				me.open_phone()
				me.ui.phone._show("map")
			if "--turf" in OS.get_cmdline_user_args():
				me.open_phone()
				me.ui.phone._show("turf")
			if "--deal" in OS.get_cmdline_user_args():
				for n: Node in world.get_tree().get_nodes_in_group(&"customer"):
					if (n as Pedestrian).deal_ok:
						me.open_deal(n as Pedestrian)
						break
			if "--work" in OS.get_cmdline_user_args():
				# Point 42: third person, watering a pot in front (mid-animation).
				me._set_third_person(true)
				var pot: Node3D = null
				for n: Node in world.get_tree().get_nodes_in_group(&"stations"):
					if n is GrowPot and (pot == null or (n as Node3D).global_position.distance_to(me.global_position)
							< pot.global_position.distance_to(me.global_position)):
						pot = n as Node3D
				for i: int in me.inventory.size():
					if str((me.inventory[i] as Dictionary).get("id")) == "watering_can":
						me.combat.select_slot(i)
				me.host_work("water", pot.global_position if pot else me.global_position - me.global_basis.z)
				await world.get_tree().create_timer(0.45).timeout
			for a: String in OS.get_cmdline_user_args():
				if a.begins_with("--crew="):  # staff window: --crew=crew / hire / dealer
					var tab: String = a.trim_prefix("--crew=")
					var first: String = Staff.members.keys()[0] if not Staff.members.is_empty() else ""
					CrewWindow.open_for(me, "dealer" if tab == "dealer" else "crew", first)
					var w := me.ui.get_node("CrewWindow") as CrewWindow
					w._tab = tab
					w._refresh()
			for f: int in 6:
				await RenderingServer.frame_post_draw
			var path: String = ProjectSettings.globalize_path("res://screenshots/scenario_%s.png" % id)
			world.get_viewport().get_texture().get_image().save_png(path)
			print("[ScenarioCheck] saved %s" % path)
		world.get_tree().quit()
	return true


## Point 39: a free spot on the pavement in front of `prop`'s building where a trash bin may
## stand (Placement.check passes), or the front door spot when there is none.
static func outdoor_bin_spot(world: Node, prop: Property) -> Vector3:
	var b: Building = prop.building()
	var item: ItemData = ItemDB.get_item(&"trash_bin")
	for z: float in [1.5, 2.0, 2.5, 1.0, 3.0]:
		for x: float in [1.8, -1.8, 2.5, -2.5, 1.2, -1.2, 3.2, -3.2]:
			var top: Vector3 = b.to_global(Vector3(x, 1.5, z))
			var q := PhysicsRayQueryParameters3D.create(top, top + Vector3.DOWN * 3.0, 1)
			var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(q)
			if hit.is_empty():
				continue
			var pos: Vector3 = hit["position"]
			if Placement.check(world.get_world_3d(), world.get_tree(), item, pos, b.global_rotation.y) == "":
				return pos
	push_warning("[Scenario] no outdoor bin spot in front of %s" % prop.display_name)
	return b.to_global(Vector3(0, 0, 1.5))


## Inventory = exactly `items` ([id, count]), `cash` dirty money, no clean money.
## Milestone 3 meth: the Starter Room's sofa + table make way for a cooking station + cooling plate.
## Returns [cook station, cooling plate].
static func meth_lab(world: Node, sr: Property) -> Array:
	return await _lab(world, sr, [["cook_station", Vector3(1.5, 0.15, -8.2)], ["cooling_plate", Vector3(1.6, 0.15, -6.9)]])


## Milestone 3 cocaine: coca bed, leaf press + refinery in the Starter Room (sofa, table, the spot between bed
## and sofa). Returns [coca bed, leaf press, refinery].
static func coke_lab(world: Node, sr: Property) -> Array:
	return await _lab(world, sr, [["coca_bed", Vector3(1.5, 0.15, -8.2)], ["leaf_press", Vector3(1.6, 0.15, -6.9)],
			["refinery", Vector3(-0.2, 0.15, -8.3)]])


## Places stations at building-local spots of the Starter Room, removing placed furniture standing there.
static func _lab(world: Node, sr: Property, spots: Array) -> Array:
	var b: Node3D = sr.building()
	var placed: Dictionary = GameState.world.get("placed", {})
	for uid: String in placed.keys():
		for sp: Array in spots:
			if (placed[uid]["pos"] as Vector3).distance_to(b.to_global(sp[1])) < 1.0:
				world.call("host_remove_placed", uid)
				break
	var out: Array = []
	for sp: Array in spots:
		out.append(world.call("host_place", sp[0], b.to_global(sp[1]), b.global_rotation.y))
	await world.get_tree().physics_frame
	return out


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
