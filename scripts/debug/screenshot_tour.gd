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
	["19_starter_door_open", Vector3(-31.4, 1.7, -3.2), Vector3(-32, 1.2, -8)],
]

var hide_nodes: Array = []  # CanvasItems hidden during the tour (e.g. the HUD)

var _camera: Camera3D
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
		await _stage(shot[0])
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
