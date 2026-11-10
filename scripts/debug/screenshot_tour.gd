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
]

var hide_nodes: Array = []  # CanvasItems hidden during the tour (e.g. the HUD)

var _camera: Camera3D


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

	var only: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			only = arg.trim_prefix("--shots=")

	for shot: Array in SHOTS:
		if only != "" and not (shot[0] as String).substr(0, 2) in only.split(","):
			continue
		await _place(shot[1], shot[2], SETTLE_FRAMES)
		await RenderingServer.frame_post_draw
		var image: Image = get_viewport().get_texture().get_image()
		var file: String = dir_path.path_join("%s.png" % shot[0])
		image.save_png(file)
		print("[Screenshot] Saved %s" % file)

	# Performance: uncapped FPS at a few typical views.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for shot: Array in [SHOTS[0], SHOTS[1], SHOTS[2], SHOTS[6]]:
		await _place(shot[1], shot[2], 30)
		var start: int = Time.get_ticks_usec()
		for i: int in FPS_FRAMES:
			await get_tree().process_frame
		var fps: float = FPS_FRAMES / ((Time.get_ticks_usec() - start) / 1000000.0)
		print("[Screenshot] FPS at %s: %.0f  (draw calls %d, primitives %d)" % [shot[0], fps,
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])

	print("[Screenshot] Done")
	Net.leave_game()
	get_tree().quit()


func _place(pos: Vector3, target: Vector3, frames: int) -> void:
	_camera.global_position = pos
	_camera.look_at(target)
	for i: int in frames:
		await get_tree().process_frame
