extends SceneTree
## Renders an icon of every item's 3D model (ItemData.get_model()) into
## res://assets/icons/<id>.png (128x128, transparent). Needs a window (not headless):
##   godot --path . --position 4000,40 --resolution 256x256 --script res://scripts/debug/render_icons.gd [-- --only=soil,ak47]
## Weapons are shown from the side, everything else in a three-quarter view.

const ITEMS_DIR: String = "res://data/items/"
const OUT_DIR: String = "res://assets/icons/"
const SIZE: int = 128

var _only: PackedStringArray = []


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			_only = arg.trim_prefix("--only=").split(",")
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	root.transparent_bg = true
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.57, 0.62)
	env.environment.ambient_light_energy = 0.9
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-0.75, 0.55, 0)
	key.light_energy = 1.3
	world.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation = Vector3(-0.3, PI + 0.6, 0)
	rim.light_energy = 0.6
	world.add_child(rim)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.near = 0.01
	cam.far = 20.0
	world.add_child(cam)
	cam.current = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var count: int = 0
	for file: String in DirAccess.get_files_at(ITEMS_DIR):
		var res_name: String = file.trim_suffix(".remap")
		if not res_name.ends_with(".tres"):
			continue
		var item := load(ITEMS_DIR + res_name) as ItemData
		if item == null or (not _only.is_empty() and not String(item.id) in _only):
			continue
		var scene: PackedScene = item.get_model()
		if scene == null:
			print("[Icons] %s: no model" % item.id)
			continue
		var inst: Node3D = scene.instantiate() as Node3D
		if item is WeaponData:
			inst.rotation.x = deg_to_rad(28.0)  # barrel up to the right: fills the square better
		world.add_child(inst)
		for i: int in 4:
			await process_frame
		var box: AABB = _bounds(inst)
		var view: Vector3 = Vector3(1.0, 0.18, 0.02) if item is WeaponData else Vector3(1.0, 0.85, 1.5)
		_frame(cam, box, view.normalized())
		for i: int in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		img.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
		img.save_png(ProjectSettings.globalize_path(OUT_DIR + String(item.id) + ".png"))
		print("[Icons] %s" % item.id)
		count += 1
		inst.queue_free()
		await process_frame
	print("[Icons] rendered %d icons into %s" % [count, OUT_DIR])
	quit()


func _bounds(n: Node3D) -> AABB:
	var box := AABB()
	var first: bool = true
	for c: Node in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var a: AABB = mi.global_transform * mi.get_aabb()
		box = a if first else box.merge(a)
		first = false
	return box


## Points `cam` along -`view` at the box and zooms so the box fills ~90% of the square.
func _frame(cam: Camera3D, box: AABB, view: Vector3) -> void:
	var centre: Vector3 = box.get_center()
	cam.global_position = centre + view * 5.0
	cam.look_at(centre, Vector3.UP if absf(view.y) < 0.99 else Vector3.FORWARD)
	var inv: Transform3D = cam.global_transform.affine_inverse()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for i: int in 8:
		var p: Vector3 = inv * box.get_endpoint(i)
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	var mid: Vector2 = (lo + hi) * 0.5
	cam.global_position += cam.global_basis.x * mid.x + cam.global_basis.y * mid.y
	cam.size = maxf(hi.x - lo.x, hi.y - lo.y) * 1.12
