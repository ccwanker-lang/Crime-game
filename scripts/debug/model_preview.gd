extends SceneTree
## Debug: renders a scene from the side, top and front into screenshots/preview_*.png.
## Needs a window (not headless):
##   godot --path . --position 4000,40 --script res://scripts/debug/model_preview.gd -- --scene=res://...tscn [--size=0.3]
## Axes are drawn at the origin: red +X, green +Y, blue +Z.

var _scene_path: String = ""
var _size: float = 0.4
var _anim: String = ""
var _center: Vector3 = Vector3.ZERO


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			_scene_path = arg.trim_prefix("--scene=")
		elif arg.begins_with("--anim="):
			_anim = arg.trim_prefix("--anim=")
		elif arg.begins_with("--center="):
			var c: PackedStringArray = arg.trim_prefix("--center=").split(",")
			_center = Vector3(c[0].to_float(), c[1].to_float(), c[2].to_float())
		elif arg.begins_with("--size="):
			_size = arg.trim_prefix("--size=").to_float()
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.6, 0.65)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.6, 0)
	world.add_child(sun)
	var inst: Node = (load(_scene_path) as PackedScene).instantiate()
	world.add_child(inst)
	if _anim != "":
		var ap := inst.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		for a: String in ap.get_animation_list():
			if a.ends_with(_anim):
				ap.play(a)
		var sk := inst.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		await process_frame
		for b: String in ["Head", "Shoulder.R", "UpperArm.R", "LowerArm.R", "Wrist.R", "Index1.R", "Wrist.L", "Chest"]:
			print("[Preview] bone %s at %s" % [b, (sk.global_transform * sk.get_bone_global_pose(sk.find_bone(b))).origin])
	for axis: int in 3:
		var m := MeshInstance3D.new()
		var box := BoxMesh.new()
		var s := Vector3.ONE * _size * 0.01
		s[axis] = _size * 0.5
		box.size = s
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = [Color.RED, Color.GREEN, Color.BLUE][axis]
		box.material = mat
		m.mesh = box
		m.position[axis] = _size * 0.25
		world.add_child(m)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = _size * 1.3
	cam.near = 0.01
	world.add_child(cam)
	cam.current = true
	var dir: String = ProjectSettings.globalize_path("res://screenshots/")
	DirAccess.make_dir_recursive_absolute(dir)
	for view: Array in [["side", Vector3(0, 0, 2)], ["top", Vector3(0, 2, 0.001)], ["front", Vector3(-2, 0, 0)],
			["persp", Vector3(1.2, 0.8, 1.6)], ["back", Vector3(-0.3, 0.4, -2)]]:
		cam.position = _center + (view[1] as Vector3)
		cam.look_at(_center)
		for i: int in 10:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(dir.path_join("preview_%s.png" % view[0]))
	print("[Preview] saved to ", dir)
	quit()
