extends Node
## Debug tool: moves the camera to fixed spots, saves a PNG of each to
## <project>/screenshots/ and quits. Start the game with:  -- --screenshot
## (Only works when running from the project folder, not in exported builds.)

const OUTPUT_DIR: String = "res://screenshots/"
const SETTLE_FRAMES: int = 20

## name, camera position, look-at target
const SHOTS: Array[Array] = [
	["01_overview", Vector3(0, 75, 50), Vector3(0, 0, 0)],
	["02_street", Vector3(-45, 1.7, 3), Vector3(20, 1.5, 0)],
	["03_spawn_view", Vector3(21, 1.7, -10), Vector3(15, 1.5, 10)],
	["04_starter_room_outside", Vector3(-14, 1.7, -3), Vector3(-14, 1.8, -12)],
	["05_starter_room_inside", Vector3(-14, 1.7, -12.8), Vector3(-15, 1.0, -19.5)],
	["06_contact_alley", Vector3(-24.25, 1.7, 8), Vector3(-24.25, 1.2, 20)],
	["07_rival_turf", Vector3(34, 4, 10), Vector3(46, 0.5, 28)],
]

var camera: Camera3D
var hide_nodes: Array = []  # CanvasItems hidden during the tour (e.g. the HUD)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var dir_path: String = ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(dir_path)
	# Keep Godot from importing the PNGs as game assets.
	FileAccess.open(dir_path.path_join(".gdignore"), FileAccess.WRITE)

	for item: CanvasItem in hide_nodes:
		item.visible = false
	camera.set_process(false)  # stop the fly camera's own movement
	camera.current = true

	for shot: Array in SHOTS:
		camera.global_position = shot[1]
		camera.look_at(shot[2])
		for i: int in SETTLE_FRAMES:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image: Image = get_viewport().get_texture().get_image()
		var file: String = dir_path.path_join("%s.png" % shot[0])
		image.save_png(file)
		print("[Screenshot] Saved %s" % file)

	print("[Screenshot] Done")
	Net.leave_game()
	get_tree().quit()
