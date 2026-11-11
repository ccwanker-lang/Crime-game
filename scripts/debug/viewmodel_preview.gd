extends Node
## Debug: renders the first-person viewmodel alone (player camera view + a side
## view) into screenshots/vm_*.png, then quits. Started by World with:
##   godot --path . --position 4000,40 --resolution 1600x900 -- --vmpreview --port=7790
## Optional: --reload=0.5 (seconds into the reload), --fire, --model=1


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var reload_t: float = -1.0
	var fire: bool = false
	var model: int = 0
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--reload="):
			reload_t = arg.trim_prefix("--reload=").to_float()
		elif arg == "--fire":
			fire = true
		elif arg.begins_with("--model="):
			model = arg.trim_prefix("--model=").to_int()
	var world := Node3D.new()
	world.position = Vector3(0, 300, 0)  # far above the map: plain background
	add_child(world)
	var cam := Camera3D.new()
	cam.fov = 75.0
	cam.near = 0.05
	world.add_child(cam)
	cam.current = true
	var vm := Viewmodel.new()
	cam.add_child(vm)
	var v: Dictionary = Player.MODELS[model]
	vm.setup(Player.MODEL_DIR % v["model"], float(v["scale"]), ItemDB.get_item(&"pistol") as WeaponData)
	for i: int in 30:
		vm.update(1.0 / 60.0, 0.0, false, true)
		await get_tree().process_frame
	if reload_t >= 0.0:
		vm.reload(1.6)
		var t: float = 0.0
		while t < reload_t:
			vm.update(1.0 / 60.0, 0.0, false, true)
			t += 1.0 / 60.0
			await get_tree().process_frame
	if fire:
		vm.fire(false)
		for i: int in 3:
			vm.update(1.0 / 60.0, 0.0, false, true)
			await get_tree().process_frame
	(vm.find_children("*", "ViewmodelIK", true, false)[0] as ViewmodelIK).debug_report.call_deferred()
	var dir: String = ProjectSettings.globalize_path("res://screenshots/")
	DirAccess.make_dir_recursive_absolute(dir)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join("vm_view.png"))
	# Side view: a second camera looking at the rig from the right.
	var side := Camera3D.new()
	side.projection = Camera3D.PROJECTION_ORTHOGONAL
	side.size = 0.9
	world.add_child(side)
	side.global_position = cam.global_position + Vector3(1.5, -0.1, -0.2)
	side.look_at(cam.global_position + Vector3(0, -0.1, -0.2))
	side.current = true
	# The viewmodel shader squashes depth; for the side view show true depth.
	for m: Node in vm.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		for s: int in mi.mesh.get_surface_count():
			var sm := mi.get_surface_override_material(s) as ShaderMaterial
			if sm:
				sm.set_shader_parameter("depth_scale", 1.0)
	for i: int in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join("vm_side.png"))
	print("[VM] saved")
	Net.leave_game()
	get_tree().quit()
