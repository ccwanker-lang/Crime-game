extends Node
## Debug tool: moves its own camera to fixed spots, saves a PNG of each to
## <project>/screenshots/, measures FPS and quits. Start the game with:
##   -- --screenshot --port=7790     (separate port, so it never clashes with a
##                                     running game on 7777)
## (Only works when running from the project folder, not in exported builds.)

const OUTPUT_DIR: String = "res://screenshots/"
const SETTLE_FRAMES: int = 30
const FPS_FRAMES: int = 150

## name, camera position, look-at target
const SHOTS: Array[Array] = [
	["01_overview", Vector3(-5, 62, 70), Vector3(-5, 0, -2)],
	["02_street", Vector3(-58, 1.75, -4.4), Vector3(0, 2.5, 1)],
	["03_spawn_view", Vector3(10, 1.95, -4.6), Vector3(-25, 2.5, 4)],
	["04_starter_room_outside", Vector3(-30, 1.9, 2.5), Vector3(-32, 3.5, -6)],
	["05_starter_room_inside", Vector3(-30.2, 1.75, -7.0), Vector3(-33.5, 1.0, -13.5)],
	["06_contact_alley", Vector3(-34.5, 1.9, 3.5), Vector3(-34.5, 1.8, 22)],
	["07_rival_turf", Vector3(34.5, 3.5, 4.5), Vector3(50, 1, 26)],
	["08_plaza", Vector3(-4, 1.9, 4.5), Vector3(-4, 1.5, 25)],
	["09_store_inside", Vector3(11, 1.75, 7.0), Vector3(11, 1.0, 15)],
	["10_hospital", Vector3(18, 1.9, 4.6), Vector3(9, 5, -6)],
	["11_backyards", Vector3(-50, 7, -32), Vector3(-42, 1, -14)],
	["12_contact_inside", Vector3(-34.7, 1.75, 22.5), Vector3(-35.6, 1.0, 26.5)],
	["13_sign_main_back", Vector3(-0.9, 2.2, -1.9), Vector3(-0.6, 2.35, -3.9)],
	["14_sign_main_front", Vector3(-0.3, 2.2, -5.6), Vector3(-0.6, 2.35, -3.9)],
	["15_sign_station", Vector3(23.1, 2.2, -1.6), Vector3(23.5, 2.35, -3.72)],
	["16_alley_lamp", Vector3(-34.2, 1.7, 5.0), Vector3(-33.6, 3.0, 11.5)],
	["17_floodlights", Vector3(50, 1.8, 22), Vector3(50, 3.5, 31)],
	["18_lamps_street", Vector3(-30, 1.8, -1.5), Vector3(-48, 2.5, 3.0)],
	["20_hosp_west_corner", Vector3(-1.5, 5.5, -2.0), Vector3(1.2, 0, -7.5)],
	["21_hosp_east_corner", Vector3(26.0, 5.5, -2.0), Vector3(23.2, 0, -7.5)],
	["22_npc_bench", Vector3(-9.0, 1.5, 13.4), Vector3(-9.0, 0.7, 16.6)],
	["23_npc_walk", Vector3(-12, 1.7, -3.6), Vector3(-19, 1.0, -4.9)],
	["24_npc_lineup", Vector3(-3.5, 1.6, 4.6), Vector3(-3.5, 1.0, 9.0)],
	["25_bench_east", Vector3(58.5, 2.2, -2.5), Vector3(56, 0.3, -6.2)],
	["26_players_front", Vector3(-10.5, 1.5, -0.6), Vector3(-10.5, 0.9, -4.6)],
	["27_players_side", Vector3(-10.5, 1.3, -0.6), Vector3(-10.5, 0.8, -4.6)],
	["28_player_crouch_close", Vector3(-10.0, 1.0, -2.2), Vector3(-10.0, 0.6, -4.6)],
	# 29/30 use the camera of a staged local player (third / first person), not these spots.
	["29_third_person", Vector3(-8, 1.7, -4.6), Vector3(-20, 1.5, -4.6)],
	["30_first_person", Vector3(-8, 1.7, -4.6), Vector3(-20, 1.5, -4.6)],
	["19_starter_door_open", Vector3(-31.4, 1.7, -3.2), Vector3(-32, 1.2, -8)],
	["31_loot_bag", Vector3(-9.0, 1.3, -3.4), Vector3(-10.0, 0.15, -4.8)],
	# 32/33: a staged local player at the store counter (HUD with inventory, then the shop window).
	["32_store_counter", Vector3.ZERO, Vector3.FORWARD],
	["33_shop_window", Vector3.ZERO, Vector3.FORWARD],
	# 34-36: the weed corner in the starter room with staged plant/rack states.
	["34_weed_corner", Vector3(-30.0, 1.7, -7.3), Vector3(-33.2, 0.8, -11.2)],
	["35_plants_close", Vector3(-33.2, 1.35, -9.9), Vector3(-33.2, 0.6, -11.2)],
	["36_drying_rack", Vector3(-31.3, 1.45, -10.8), Vector3(-29.45, 1.1, -12.0)],
	# Gun shop (Block C, centre x 53, front z -6).
	["37_gun_shop_outside", Vector3(53, 1.8, 3.0), Vector3(53, 2.6, -6)],
	["38_gun_shop_inside", Vector3(51.6, 1.7, -7.2), Vector3(53.4, 1.4, -15.7)],
	["39_ragdolls", Vector3(-17.8, 1.6, -1.6), Vector3(-17.8, 0.2, -4.6)],
	# Corner house (x -19.5..-12, front z -6): living room, stairwell, upstairs bedroom.
	["40_house_living", Vector3(-13.0, 1.7, -7.0), Vector3(-16.5, 0.9, -13.5)],
	["41_house_stairs", Vector3(-14.6, 1.7, -6.8), Vector3(-18.7, 2.2, -11.5)],
	["42_house_upstairs", Vector3(-13.0, 4.85, -7.0), Vector3(-16.5, 3.9, -13.5)],
	["43_houses_night_street", Vector3(-30, 1.8, 3.5), Vector3(-15, 3, -6)],
	["44_snackbar_door", Vector3(44.1, 1.7, -4.2), Vector3(44.1, 0.9, -9.5)],
	# AI traffic: main road at street level, the x=30 crossing from above, a car close up.
	["45_traffic_street", Vector3(14, 1.7, 5.2), Vector3(-8, 0.8, 0)],
	["46_traffic_crossing", Vector3(18, 16, 14), Vector3(30, 0, -2)],
	["47_traffic_side_street", Vector3(26.5, 1.7, -20), Vector3(30, 0.6, -40)],
	# Step 7: packaging table in the starter room, a customer ("$") on the sidewalk.
	["48_packaging_table", Vector3(-31.0, 1.6, -9.7), Vector3(-31.0, 0.8, -11.4)],
	["49_customer", Vector3(-17.8, 1.7, -1.2), Vector3(-17.8, 1.3, -4.6)],
	# Step 8: the phone (staged local player): chat thread and map.
	["50_phone_chat", Vector3(-8, 1.7, -4.6), Vector3(-20, 1.5, -4.6)],
	["51_phone_map", Vector3(-8, 1.7, -4.6), Vector3(-20, 1.5, -4.6)],
	# Corner house top floor: railing round the stairwell opening; second floor seen from the stairs.
	["52_house_top_railing", Vector3(-15.0, 7.85, -7.0), Vector3(-18.7, 6.6, -11.0)],
	["53_house_floor2_back", Vector3(-17.0, 4.85, -7.0), Vector3(-13.0, 3.6, -14.0)],
	# Balcony of RowHouseB1 (x -58, front z -6): open door from inside, then from the street.
	["54_balcony_door_open", Vector3(-59.0, 4.65, -9.0), Vector3(-59.3, 3.9, -4.0)],
	["55_balcony_outside_door_open", Vector3(-57.0, 2.0, 2.5), Vector3(-59.3, 3.9, -6.0)],
	# Point 5: held items (first person, third person, seen by someone else: soil bag).
	["56_held_first", Vector3(-8, 1.7, -4.6), Vector3(-20, 1.5, -4.6)],
	["57_held_third", Vector3(-8, 1.7, -4.6), Vector3(-20, 1.5, -4.6)],
	["58_held_seen", Vector3(-10.2, 1.3, -3.6), Vector3(-8, 0.9, -4.6)],
	# Point 6/18: placement ghost in the starter room, storage locker window, the empty starter room.
	["59_place_ghost", Vector3(-31.5, 1.7, -6.0), Vector3(-31.5, 0.2, -8.5)],
	["60_place_ghost_bad", Vector3(-31.5, 1.7, -6.0), Vector3(-31.5, 0.2, -8.5)],
	["61_locker_window", Vector3(-31.5, 1.7, -6.0), Vector3(-31.5, 1.0, -8.5)],
	# Point 7: the garage, its workshop with the locked fence, the black market at night.
	["62_garage_outside", Vector3(33, 2.2, 53), Vector3(24, 2.5, 44)],
	["63_garage_workshop", Vector3(23.0, 1.85, 48.6), Vector3(16.4, 1.2, 45.0)],
	["64_black_market_night", Vector3(16.0, 1.85, 46.0), Vector3(13.4, 1.3, 42.4)],
	# Point 8: South Street with the properties for sale and the real estate agent (window open).
	["65_south_street", Vector3(8, 2.2, 63), Vector3(-30, 3.0, 52)],
	["66_estate_window", Vector3(-19.2, 1.7, 50.5), Vector3(-19.2, 1.3, 46.7)],
	["67_laundromat_west_end", Vector3(-49, 2.2, 3.5), Vector3(-56, 3.0, -6)],
	["68_bakery_inside", Vector3(39.5, 1.7, -6.9), Vector3(40.4, 1.0, -13.5)],
	["69_barber_inside", Vector3(1.1, 1.7, -41.0), Vector3(5.0, 1.0, -36.0)],
	["70_laundromat_inside", Vector3(-53.5, 1.7, -7.0), Vector3(-59.0, 0.8, -12.5)],
	# Point 10: police station, an officer aiming next to a patrol car (light bar on).
	["71_police_station", Vector3(16, 2.2, 64), Vector3(3, 3.0, 52)],
	["72_police_officer", Vector3(3.6, 1.6, 59.6), Vector3(1.6, 1.1, 56.4)],
	["73_police_car_night", Vector3(10.5, 2.0, 63.0), Vector3(4.0, 0.8, 57.5)],
	# Point 26: the properties in their neighbourhoods.
	["74_small_house_square", Vector3(-10, 2.2, -2.5), Vector3(-17, 3.0, 6)],
	["75_barber_north_road", Vector3(10, 2.2, -50), Vector3(3, 3.0, -42)],
	["76_family_house_east", Vector3(60, 2.2, -50.5), Vector3(68, 3.0, -42)],
	# Point 11: the Black Crows' house in their yard, members out front at night.
	["77_crows_house_night", Vector3(50.5, 1.8, 10.2), Vector3(56.5, 2.0, 17.0)],
	["78_crows_house_day", Vector3(49.0, 3.0, 9.0), Vector3(56.0, 4.0, 17.0)],
	["79_scenario_menu", Vector3(-30, 1.9, 2.5), Vector3(-32, 3.5, -6)],
	# Point 47: the west side (industrial edge + harbour), from above and at eye level.
	["80_west_top", Vector3(-130, 150, 120), Vector3(-130, 0, 30)],
	["81_industrial_road", Vector3(-110.5, 1.8, 2.5), Vector3(-114, 2.0, 40)],
	["82_metalworks", Vector3(-128, 2.2, -4.5), Vector3(-150, 4.0, 10)],
	["83_harbour", Vector3(-112, 2.0, 88), Vector3(-150, 3.0, 100)],
	["84_quay_edge", Vector3(-120, 1.9, 101.5), Vector3(-160, 1.0, 112)],
	["85_lab_warehouse", Vector3(-118, 2.0, 22), Vector3(-104, 3.0, 20)],
	["86_container_yard", Vector3(-120, 3.5, 49), Vector3(-150, 1.0, 50)],
	# Point 47b: the countryside (Country Lane, Hollow Farm with the barn, fields).
	["87_country_top", Vector3(-140, 110, 10), Vector3(-140, 0, -60)],
	["88_country_lane", Vector3(-148.5, 1.8, -8), Vector3(-150, 2.0, -70)],
	["89_barn", Vector3(-146, 1.8, -78), Vector3(-150, 3.5, -94)],
]

var hide_nodes: Array = []  # CanvasItems hidden during the tour (e.g. the HUD)

var _camera: Camera3D
var _corner: Dictionary = {}  # the weed corner placed for shots 34-36 (World.debug_weed_corner)
var _staged: Array[Node] = []  # posed NPCs of the current shot, removed after it


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var dir_path: String = ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(dir_path)
	# Keep Godot from importing the PNGs as game assets.
	FileAccess.open(dir_path.path_join(".gdignore"), FileAccess.WRITE)

	for item: CanvasItem in hide_nodes:
		item.visible = false
	_camera = Camera3D.new()
	_camera.fov = 75.0
	_camera.near = 0.05
	add_child(_camera)
	_camera.current = true

	# Experiments: --env:key=value overrides an Environment property for the whole tour.
	var env: Environment = get_viewport().find_world_3d().environment
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--env:"):
			var kv: PackedStringArray = arg.trim_prefix("--env:").split("=")
			env.set(kv[0], str_to_var(kv[1]))
			print("[Screenshot] env %s = %s" % [kv[0], env.get(kv[0])])

	var only: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			only = arg.trim_prefix("--shots=")

	for shot: Array in SHOTS:
		if only != "" and not (shot[0] as String).substr(0, 2) in only.split(","):
			continue
		var dn := get_tree().get_first_node_in_group(&"day_night") as DayNight
		if dn:
			dn.set_hours(23.0 if (shot[0] as String).contains("night") else 10.0)
		await _stage(shot[0])
		if (shot[0] as String) == "64_black_market_night":
			for gate: Node in get_tree().current_scene.find_children("*", "NightGate", true, false):
				(gate as NightGate)._set_open(true)
		if (shot[0] as String).ends_with("door_open"):
			for door: Node in get_tree().current_scene.find_children("*", "NetDoor", true, false):
				(door as NetDoor)._set_open(true)
		await _place(shot[1], shot[2], SETTLE_FRAMES)
		await RenderingServer.frame_post_draw
		var image: Image = get_viewport().get_texture().get_image()
		var file: String = dir_path.path_join("%s.png" % shot[0])
		image.save_png(file)
		print("[Screenshot] Saved %s" % file)
		for n: Node in _staged:
			n.queue_free()
		_staged.clear()
		_camera.current = true

	# Performance: uncapped FPS at a few typical views.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for shot: Array in [SHOTS[0], SHOTS[1], SHOTS[2], SHOTS[6]]:
		await _place(shot[1], shot[2], 30)
		var start: int = Time.get_ticks_usec()
		for i: int in FPS_FRAMES:
			await get_tree().process_frame
		var fps: float = FPS_FRAMES / ((Time.get_ticks_usec() - start) / 1000000.0)
		print("[Screenshot] FPS at %s: %.0f  (%d NPCs, draw calls %d, primitives %d)" % [shot[0], fps,
				get_tree().get_nodes_in_group(&"npc").size(),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])

	print("[Screenshot] Done")
	Net.leave_game()
	get_tree().quit()


## Puts posed pedestrians (ambient AI off) in front of the NPC camera spots.
func _stage(shot_name: String) -> void:
	var scene: PackedScene = load("res://prefabs/npc/pedestrian.tscn")
	var npcs: Node = get_tree().current_scene.get_node("NPCs")
	match shot_name:
		"22_npc_bench":
			for i: int in 2:
				var seat: Node3D = null
				for s: Node in get_tree().get_nodes_in_group(&"bench_seat"):
					var p: Vector3 = (s as Node3D).global_position
					if absf(p.z - 16.6) < 0.5 and absf(p.x - (-9.0 + (0.55 if i == 0 else -0.55))) < 0.2:
						seat = s
				var npc := _posed(scene, npcs, [0, 3][i], seat.global_position + seat.global_basis.z * 0.8, 0.0)
				npc.sit_on(seat, 60.0)
			await get_tree().create_timer(1.5).timeout
		"23_npc_walk":
			for i: int in 3:
				var npc := _posed(scene, npcs, [8, 5, 11][i], Vector3(-22.0 - i * 1.6, 0.15, -4.4 - (i % 2) * 0.9), 0.0)
				npc.walk_to(Vector3(-4.0, 0.15, -4.6 - (i % 2) * 0.9))
			await get_tree().create_timer(1.6).timeout
		"26_players_front", "27_players_side", "28_player_crouch_close":
			# Remote-player look (peer 99 = not local): idle, run, sprint, crouch,
			# crouch-walk, looking up, looking down.
			var states: Array[Dictionary] = [
				{}, {"net_move": Vector2(0, -1)}, {"net_move": Vector2(0, -1), "net_sprint": true},
				{"net_crouch": true}, {"net_crouch": true, "net_move": Vector2(0, -1)},
				{"net_pitch": 0.8}, {"net_pitch": -0.8}]
			for i: int in states.size():
				var pl: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
				pl.peer_id = 99
				pl.player_name = "Player %d" % (i + 1)
				pl.model_index = i
				var pos := Vector3(-14.0 + i * 1.2, 0.15, -4.6)
				pl.position = pos
				pl.net_pos = pos
				var yaw: float = PI if shot_name == "26_players_front" else -PI / 2.0  # 27/28: profile
				pl.rotation.y = yaw
				pl.net_yaw = yaw
				for k: String in states[i]:
					pl.set(k, states[i][k])
				get_tree().current_scene.add_child(pl)
				_staged.append(pl)
			await get_tree().create_timer(0.7).timeout
		"49_customer":
			var buyer := _posed(scene, npcs, 3, Vector3(-17.8, 0.15, -4.6), 0.0)
			await get_tree().physics_frame
			buyer.become_customer(2, 140, 60.0)
		"39_ragdolls":
			# Three pedestrians (both character packs) shot dead on the sidewalk.
			for i: int in 3:
				var npc := _posed(scene, npcs, [0, 8, 4][i], Vector3(-16.0 - i * 1.8, 0.15, -4.6), PI / 2.0)
				await get_tree().physics_frame
				npc.host_damage(500, null, npc.global_position + Vector3(-3.0, 1.4, 0.5 * i))
			await get_tree().create_timer(3.0).timeout
			for n: Node in _staged:
				var r: Ragdoll = n.get("_ragdoll")
				if r:
					print("[Screenshot] ragdoll %s head %.2f, feet %.2f" % [n.name, r.head_height(), (n as Node3D).global_position.y])
		"29_third_person", "30_first_person":
			# A local player (auto_walk: no mouse capture) whose own camera takes the shot.
			var me: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
			me.peer_id = multiplayer.get_unique_id()
			me.player_name = "Me"
			me.auto_walk = true
			me.position = Vector3(-8, 0.15, -4.6)
			me.auto_target = me.position
			me.rotation.y = PI / 2.0  # looking west along the sidewalk
			get_tree().current_scene.add_child(me)
			_staged.append(me)
			me.ui.visible = true
			me.camera.current = true
			me.head.rotation.x = -0.08
			me._set_third_person(shot_name == "29_third_person")
			await get_tree().create_timer(0.5).timeout
		"56_held_first", "57_held_third", "58_held_seen":
			# Point 5: a player holding the watering can (slot 2) / soil bag (seen by another peer).
			var me: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
			var seen: bool = shot_name == "58_held_seen"
			me.peer_id = 4242 if seen else multiplayer.get_unique_id()  # 58: someone else's player
			me.player_name = "Other" if seen else "Me"
			me.auto_walk = not seen
			me.position = Vector3(-8, 0.15, -4.6)
			me.auto_target = me.position
			me.net_pos = me.position
			me.rotation.y = PI / 2.0
			me.net_yaw = me.rotation.y
			get_tree().current_scene.add_child(me)
			_staged.append(me)
			if seen:
				me.net_weapon = 0
				me.net_held = &"soil"
			else:
				await get_tree().create_timer(0.3).timeout  # after the host's own wallet message
				me._set_wallet(500, [{"id": "pistol", "count": 1}, {"id": "watering_can", "count": 1}, {"id": "soil", "count": 3}])
				me.combat.select_slot(1)
				me.ui.visible = true
				me.camera.current = true
				me.head.rotation.x = -0.08
				me._set_third_person(shot_name == "57_held_third")
			await get_tree().create_timer(0.6).timeout
		"59_place_ghost", "60_place_ghost_bad", "61_locker_window":
			var me: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
			me.peer_id = multiplayer.get_unique_id()
			me.player_name = "Me"
			me.auto_walk = true
			var room := get_tree().current_scene.find_child("StarterRoom", true, false) as Node3D
			me.position = room.to_global(Vector3(0.6, 0.15, -2.6))
			me.auto_target = me.position
			me.rotation.y = room.global_rotation.y + (0.5 if shot_name == "60_place_ghost_bad" else 0.0)
			get_tree().current_scene.add_child(me)
			_staged.append(me)
			me.ui.visible = true
			me.camera.current = true
			me.head.rotation.x = -0.55 if shot_name != "61_locker_window" else -0.1
			await get_tree().create_timer(0.3).timeout
			if shot_name == "61_locker_window":
				var locker := get_tree().current_scene.call("host_place", "storage_locker",
						room.to_global(Vector3(0.6, 0.15, -4.6)), room.global_rotation.y) as StorageLocker
				_staged.append(locker)
				locker.state["items"] = [{"id": "weed_bag", "count": 12}, {"id": "ak47", "count": 1}, {"id": "ammo_762", "count": 60}]
				me._set_wallet(320, [{"id": "pistol", "count": 1}, {"id": "weed_bud", "count": 6}, {"id": "baggie", "count": 10}])
				await get_tree().create_timer(0.2).timeout
				me.open_locker(locker)
			else:
				me._set_wallet(320, [{"id": "pistol", "count": 1}, {"id": "grow_pot", "count": 3}, {"id": "sofa", "count": 1}])
				me.placement.set_build_mode(true)  # (point 36)
				me.combat.select_slot(1 if shot_name == "59_place_ghost" else 2)
				await get_tree().create_timer(0.4).timeout
				me.prompt_label.text = me.placement.prompt_text()
			await get_tree().create_timer(0.4).timeout
		"72_police_officer", "73_police_car_night":
			var world: Node = get_tree().current_scene
			var traffic: Traffic = world.get_node("Traffic")
			var route: TrafficRoute = traffic.routes[3]
			var best: float = 0.0
			for i: int in int(route.length * 2.0):
				if (route.sample(i * 0.5)[0] as Vector3).distance_to(Vector3(5.5, 0, 58.25)) 						< (route.sample(best)[0] as Vector3).distance_to(Vector3(5.5, 0, 58.25)):
					best = i * 0.5
			var car: Car = traffic.spawn_police_car(3, best)
			car.abandoned = true
			car.siren = true
			_staged.append(car)
			var cop: PoliceOfficer = world.add_officer(Vector3(1.6, 0.15, 56.4), Vector3(1.6, 0.15, 56.4), car)
			cop.rotation.y = deg_to_rad(150.0)
			_staged.append(cop)
			await get_tree().create_timer(0.6).timeout
			cop.anim_state = Pedestrian.Anim.AIM
			cop.net_yaw = cop.rotation.y
			await get_tree().create_timer(0.4).timeout
		"79_scenario_menu":
			var menu: ScenarioMenu = get_tree().current_scene.find_children("*", "ScenarioMenu", true, false)[0]
			menu.toggle()
			await get_tree().create_timer(0.3).timeout
		"77_crows_house_night":
			var world: Node = get_tree().current_scene
			Rival.obey_daylight = false
			for i: int in 2:
				var r: Rival = world.add_rival(Vector3(54.0 + i * 1.6, 0.1, 13.6 - i * 0.6))
				r.rotation.y = deg_to_rad(200.0 + i * 30.0)
				r.net_yaw = r.rotation.y
				_staged.append(r)
			await get_tree().create_timer(0.6).timeout
			(_staged[-1] as Rival).anim_state = Pedestrian.Anim.AIM
			await get_tree().create_timer(0.4).timeout
		"66_estate_window":
			var agent: EstateAgent = get_tree().current_scene.find_child("Agent", true, false) as EstateAgent
			var me: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
			me.peer_id = multiplayer.get_unique_id()
			me.player_name = "Me"
			me.auto_walk = true
			me.position = agent.global_position - agent.global_basis.z * 3.0
			me.auto_target = me.position
			me.rotation.y = agent.global_rotation.y + PI
			get_tree().current_scene.add_child(me)
			_staged.append(me)
			me.ui.visible = true
			me.camera.current = true
			me.combat.set_equipped(false)
			await get_tree().create_timer(0.3).timeout
			me._set_wallet(12500, [])
			me.open_shop(agent)
			await get_tree().create_timer(0.5).timeout
		"50_phone_chat", "51_phone_map":
			var me: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
			me.peer_id = multiplayer.get_unique_id()
			me.player_name = "Me"
			me.auto_walk = true
			me.position = Vector3(-8, 0.15, -4.6)
			me.auto_target = me.position
			me.rotation.y = PI / 2.0
			get_tree().current_scene.add_child(me)
			_staged.append(me)
			me.ui.visible = true
			me.camera.current = true
			me.combat.set_equipped(false)
			var phone: Phone = me.ui.phone
			phone.player = me
			phone.add_message("QuickShip", "Your order has been delivered to the box in your Starter Room.", "")
			phone.add_message("Lotte", "Hey, it's Lotte. Need 2 bags, I'll pay €140. I'm near the Store.", "Pedestrian3")
			me.open_phone()
			if shot_name == "50_phone_chat":
				phone._contact = "Lotte"
				phone._show("thread")
			else:
				get_tree().current_scene.call("make_customer")
				phone._show("map")
			await get_tree().create_timer(0.6).timeout
		"32_store_counter", "33_shop_window":
			var clerk: Shopkeeper = get_tree().current_scene.find_child("Clerk", true, false) as Shopkeeper
			var me: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
			me.peer_id = multiplayer.get_unique_id()
			me.player_name = "Me"
			me.auto_walk = true
			me.position = clerk.global_position - clerk.global_basis.z * 1.7
			me.auto_target = me.position
			me.rotation.y = clerk.global_rotation.y + PI  # face the clerk
			get_tree().current_scene.add_child(me)
			_staged.append(me)
			me.ui.visible = true
			me.camera.current = true
			me.head.rotation.x = -0.12
			me.combat.set_equipped(false)
			me._set_wallet(455, [{"id": "weed_seed", "count": 5}, {"id": "soil", "count": 3}, {"id": "watering_can", "count": 1}])
			me.prompt_label.text = "[E] %s" % clerk.get_interaction_prompt()
			if shot_name == "33_shop_window":
				me.open_shop(clerk)
			await get_tree().create_timer(0.6).timeout
			me.prompt_label.text = "[E] %s" % clerk.get_interaction_prompt()
		"34_weed_corner", "35_plants_close", "36_drying_rack":
			if _corner.is_empty():
				_corner = get_tree().current_scene.call("debug_weed_corner")
				await get_tree().physics_frame
			var pot1: GrowPot = _corner["Pot1"]
			var pot2: GrowPot = _corner["Pot2"]
			var rack: DryingRack = _corner["DryingRack"]
			pot1.apply_net_state({"stage": GrowPot.Stage.GROWING, "growth": 0.45, "water": 0.6, "seed": 3})
			pot2.apply_net_state({"stage": GrowPot.Stage.READY, "growth": 1.0, "water": 0.0, "seed": 8})
			rack.apply_net_state({"wet": 5, "dry": 4, "progress": 0.3})
			await get_tree().create_timer(0.3).timeout
		"31_loot_bag":
			var bag: LootBag = (load("res://prefabs/props/loot_bag.tscn") as PackedScene).instantiate()
			bag.position = Vector3(-10.0, 0.15, -4.8)
			bag.rotation.y = 0.5
			bag.owner_name = "Alex"
			bag.cash = 500
			get_tree().current_scene.add_child(bag)
			_staged.append(bag)
			await get_tree().create_timer(0.2).timeout
		"25_bench_east":
			for s: Node in get_tree().get_nodes_in_group(&"bench_seat"):
				var p: Vector3 = (s as Node3D).global_position
				if absf(p.z + 5.45) < 0.3 and absf(p.x - 55.45) < 0.2:
					var npc := _posed(scene, npcs, 1, p + (s as Node3D).global_basis.z * 0.8, 0.0)
					npc.sit_on(s, 60.0)
			await get_tree().create_timer(1.5).timeout
		"24_npc_lineup":
			for i: int in Pedestrian.VARIANTS.size():
				_posed(scene, npcs, i, Vector3(-10.0 + i * 1.0, 0.15, 9.0 + (i % 2) * 0.5), 0.0)
			await get_tree().create_timer(0.5).timeout


func _posed(scene: PackedScene, parent: Node, variant: int, pos: Vector3, yaw: float) -> Pedestrian:
	var npc: Pedestrian = scene.instantiate()
	npc.ambient = false
	npc.variant = variant
	npc.color_seed = variant * 7
	npc.position = pos
	npc.rotation.y = yaw
	parent.add_child(npc, true)
	_staged.append(npc)
	return npc


func _place(pos: Vector3, target: Vector3, frames: int) -> void:
	_camera.global_position = pos
	_camera.look_at(target)
	for i: int in frames:
		await get_tree().process_frame
