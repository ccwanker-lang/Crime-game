extends Node3D
## Point 27 art direction showcase (`--scenario=style_compare` or F9): ONE street in the game's
## style, stylized low-poly (DESIGN.md "Art direction"), built from the real prefabs. Use it to
## judge style changes in one place. Houses in different colours, heights and roof types, street trees, a
## grass lot with tufts, shrubs and a hedge, cars, NPCs + the player characters, the new
## pistol + the AK as viewmodel, and the hills + tree rows that hide the edge of the world.
## Keys: 1-6 = camera spots (street, nature, wide, weapons, night, characters),
## right mouse + WASD = fly, Esc = menu.
## `--style-shots` saves screenshots/style_<spot>.png and quits.

const SHOTS: Array[String] = ["street", "nature", "wide", "weapons", "night", "characters"]
## [prefab-free Building settings]: width, floors, wall material, wall colour (palette),
## roof type, roof material, roof colour, door colour, extra.
const HOUSES: Array = [
	[6.0, 2, "brick_mixed", "brick_red", "gable", "roof_red", "roof_red", "door_green", {}],
	[7.0, 3, "plaster", "plaster_pink", "hip", "roof_dark", "roof_dark", "door_blue", {}],
	[6.5, 2, "brick_yellow", "brick_yellow", "gable", "roof_dark", "roof_slate", "door_red", {"chimney": "left"}],
	[9.0, 3, "plaster", "plaster_blue", "flat", "roof_dark", "roof_dark", "door_blue",
			{"ground_floor": "shop", "shop_sign": "CORNER CAFE", "awning": true}],
	[6.0, 2, "brick_white", "brick_white", "gable", "roof_red", "roof_red", "door_green", {}],
	[7.5, 3, "brick_old", "brick_brown", "gable", "roof_dark", "roof_dark", "door_red", {"chimney": "right"}],
	[6.0, 2, "plaster", "plaster_green", "hip", "roof_red", "roof_red", "door_blue", {}],
]
## Material -> its palette swatch (the stylized material colour), to aim the tint at a swatch.
const MATERIAL_SWATCH: Dictionary = {"brick_mixed": "brick_red", "brick_old": "brick_brown", "brick_yellow": "brick_yellow",
		"brick_white": "brick_white", "plaster": "plaster_cream", "roof_red": "roof_red", "roof_dark": "roof_dark"}

var _cam: Camera3D
var _view_cam: Camera3D
var _spots: Dictionary = {}  # shot -> Transform3D
var _sky: Node
var _fly: bool = false


func _ready() -> void:
	_sky = (load("res://prefabs/environment/sun_and_sky.tscn") as PackedScene).instantiate()
	add_child(_sky)
	_set_hours(11.0)
	_cam = Camera3D.new()
	_cam.fov = 70.0
	add_child(_cam)
	_build_street()
	_build_nature()
	_build_life()
	_build_weapons()
	var back := ProcBackdrop.new()
	back.area = Rect2(-38, -24, 76, 40)
	back.tree_margin = 6.0
	back.hill_distance = 35.0
	add_child(back)
	_spots["street"] = _look(Vector3(1.5, 1.7, 11.0), Vector3(-0.5, 3.6, -6.0))
	_spots["nature"] = _look(Vector3(22.0, 1.7, 9.0), Vector3(31.0, 2.0, -9.0))
	_spots["wide"] = _look(Vector3(-36.0, 8.0, 17.0), Vector3(8.0, 2.0, -7.0))
	_spots["night"] = _spots["street"]
	_spots["characters"] = _look(Vector3(-11.6, 1.55, -1.2), Vector3(-14.2, 1.15, -4.6))
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame  # buildings build deferred
	_show("street")
	if "--style-shots" in OS.get_cmdline_user_args():
		_take_shots()


func _set_hours(h: float) -> void:
	if _sky.has_method("set_hours"):
		_sky.call("set_hours", h)


static func _look(from: Vector3, to: Vector3) -> Transform3D:
	return Transform3D(Basis(), from).looking_at(to)


## Wall tint that turns the material's own palette colour into `target`'s.
static func _tint(material: String, target: String) -> Color:
	var base: Color = Palette.color(StringName(MATERIAL_SWATCH.get(material, target)))
	var t: Color = Palette.color(StringName(target))
	# (Tints multiply linear colours.)
	var bl: Color = base.srgb_to_linear()
	var tl: Color = t.srgb_to_linear()
	return Color(tl.r / bl.r, tl.g / bl.g, tl.b / bl.b).linear_to_srgb()


func _add(path: String, pos: Vector3, rot_y: float = 0.0, parent: Node = self) -> Node3D:
	var n: Node3D = (load(path) as PackedScene).instantiate()
	n.position = pos
	n.rotation.y = rot_y
	parent.add_child(n)
	return n


func _build_street() -> void:
	for x: float in [-30.0, -18.0, -6.0, 6.0, 18.0, 30.0]:
		_add("res://prefabs/roads/road_straight.tscn", Vector3(x, 0, 0))
	var hx: float = -24.0
	var i: int = 0
	for h: Array in HOUSES:
		var b: Node3D = (load("res://prefabs/buildings/row_house_a.tscn") as PackedScene).instantiate()
		var w: float = h[0]
		b.set("string_courses", false)
		b.set("corner_quoins", false)
		b.set("dormer", false)
		b.set("bay_window_bay", -1)
		b.set("balcony_bay", -1)
		b.set("chimney", "none")
		b.set("side_windows", false)
		b.set("enterable", false)
		b.set("upper_floors", false)
		b.set("furnish", "none")
		b.set("width", w)
		b.set("floors", h[1])
		b.set("wall_material", h[2])
		b.set("wall_tint", _tint(h[2], h[3]))
		b.set("roof_type", h[4])
		b.set("roof_material", h[5])
		b.set("roof_tint", _tint(h[5], h[6]))
		b.set("door_color", Palette.color(StringName(h[7])))
		b.set("trim_color", Color.WHITE)
		b.set("variation_seed", 11 + i)
		for k: String in (h[8] as Dictionary):
			b.set(k, h[8][k])
		b.position = Vector3(hx + w / 2.0, 0, -6.0)
		hx += w
		add_child(b)
		i += 1
	for x: float in [-12.0, 12.0]:
		_add("res://prefabs/props/street_lamp.tscn", Vector3(x, 0.15, -3.95), PI)
	_add("res://prefabs/props/street_lamp.tscn", Vector3(0.0, 0.15, 3.95))
	for x: float in [-9.5, -6.5, 15.5]:
		_add("res://prefabs/props/bollard.tscn", Vector3(x, 0.15, -3.75))


func _build_nature() -> void:
	# Street trees on both pavements.
	for p: Vector3 in [Vector3(-17.0, 0.15, -4.2), Vector3(7.0, 0.15, -4.2), Vector3(-6.0, 0.15, 4.2), Vector3(18.0, 0.15, 4.2)]:
		var t: Node3D = _add("res://prefabs/nature/tree_street.tscn", p)
		t.set("tree_seed", int(p.x * 7.0) + 50)
	# A grass lot at the east end: a big tree, shrubs, a hedge along the pavement, tufts.
	var field := GrassField.new()
	field.size = Vector2(12, 14)
	field.position = Vector3(31, 0.0, -13)
	add_child(field)
	var big: Node3D = _add("res://prefabs/nature/tree_large.tscn", Vector3(32.0, 0, -13.0))
	big.set("tree_seed", 4)
	var sizes: Array = [[Vector3(27.5, 0, -9.0), Vector3(1.6, 1.2, 1.4), ["leaf_dark", "leaf", "leaf_light"]],
			[Vector3(35.0, 0, -10.0), Vector3(1.2, 1.0, 1.2), ["leaf_dark", "leaf", "accent_yellow"]],
			[Vector3(29.5, 0, -17.0), Vector3(2.0, 1.5, 1.8), ["leaf_dark", "leaf", "leaf_light"]]]
	for i: int in sizes.size():
		var s := ProcShrub.new()
		s.shrub_seed = 3 + i
		s.size = sizes[i][1]
		s.swatches = PackedStringArray(sizes[i][2])
		s.position = sizes[i][0]
		add_child(s)
	var hedge := Hedge.new()
	hedge.size = Vector3(9.0, 0.9, 0.7)
	hedge.position = Vector3(31.5, 0.0, -6.6)
	add_child(hedge)
	# Grass verge behind the far pavement.
	var verge := GrassField.new()
	verge.size = Vector2(70, 5)
	verge.position = Vector3(0, 0.0, 9.0)
	verge.field_seed = 3
	add_child(verge)


func _build_life() -> void:
	var cars: Array = [[Vector3(4.0, 0, 1.75), -PI / 2.0, 1, Color(0.82, 0.2, 0.15)],
			[Vector3(-15.0, 0, -1.75), PI / 2.0, 0, Color(0.22, 0.42, 0.78)],
			[Vector3(21.0, 0, 1.75), -PI / 2.0, 2, Color(0.96, 0.77, 0.27)]]
	for c: Array in cars:
		var car := Node3D.new()
		car.position = c[0]
		car.rotation.y = c[1]
		add_child(car)
		ProcCar.build(car, c[2], c[3])
	# Pedestrians on the pavement and the four player characters by a house wall.
	var people: Array = [["man_casual", 0.37, Vector3(-3.5, 0.15, -4.4), 0.35], ["woman_casual", 0.37, Vector3(9.5, 0.15, -4.6), -0.6],
			["hoodie", 0.94, Vector3(-15.2, 0.15, -5.0), 0.4], ["worker", 0.95, Vector3(-14.2, 0.15, -5.2), 0.1],
			["punk", 0.93, Vector3(-13.2, 0.15, -5.0), -0.2], ["man_longsleeve", 0.95, Vector3(-12.2, 0.15, -4.8), -0.5]]
	for p: Array in people:
		var npc: Node3D = (load(Pedestrian.MODEL_DIR % p[0]) as PackedScene).instantiate()
		npc.scale = Vector3.ONE * float(p[1])
		npc.position = p[2]
		npc.rotation.y = p[3]
		add_child(npc)
		var players: Array = npc.find_children("*", "AnimationPlayer", true, false)
		if players.is_empty():
			continue
		var anim: AnimationPlayer = players[0]
		for a: String in anim.get_animation_list():
			if a.ends_with("Idle"):
				anim.play(a)
				break


func _build_weapons() -> void:
	_view_cam = Camera3D.new()
	_view_cam.fov = 70.0
	add_child(_view_cam)
	_view_cam.global_transform = _look(Vector3(-1.0, 1.7, 3.6), Vector3(-4.0, 1.5, -5.0))
	var pistol: Node3D = (ItemDB.get_item(&"pistol") as WeaponData).model_scene.instantiate()
	pistol.position = Vector3(0.2, -0.17, -0.42)
	pistol.rotation = Vector3(0.0, 0.1, 0.0)
	_view_cam.add_child(pistol)
	var ak: Node3D = (ItemDB.get_item(&"ak47") as WeaponData).model_scene.instantiate()
	ak.position = Vector3(-0.2, -0.24, -0.62)
	ak.rotation = Vector3(0.05, -0.12, 0.0)
	_view_cam.add_child(ak)


func _show(shot: String) -> void:
	_set_hours(22.5 if shot == "night" else 11.0)
	if shot == "weapons":
		_view_cam.make_current()
		return
	_cam.global_transform = _spots[shot]
	_cam.make_current()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo:
		var i: int = key.physical_keycode - KEY_1
		if i >= 0 and i < SHOTS.size():
			_show(SHOTS[i])
		elif key.physical_keycode == KEY_ESCAPE:
			Scenarios.pending = ""
			get_tree().change_scene_to_file(Net.MAIN_MENU_SCENE)
	var mb := event as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_RIGHT:
		_fly = mb.pressed
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _fly else Input.MOUSE_MODE_VISIBLE
		if _fly:
			_cam.make_current()
	var mm := event as InputEventMouseMotion
	if mm and _fly:
		_cam.rotate_y(-mm.relative.x * 0.003)
		_cam.rotate_object_local(Vector3.RIGHT, -mm.relative.y * 0.003)


func _process(delta: float) -> void:
	if not _fly:
		return
	var dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		dir -= _cam.global_basis.z
	if Input.is_key_pressed(KEY_S):
		dir += _cam.global_basis.z
	if Input.is_key_pressed(KEY_A):
		dir -= _cam.global_basis.x
	if Input.is_key_pressed(KEY_D):
		dir += _cam.global_basis.x
	_cam.global_position += dir * 8.0 * delta


func _take_shots() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))
	await get_tree().create_timer(1.5).timeout
	var only: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			only = arg.trim_prefix("--shots=")
	for shot: String in SHOTS:
		if only != "" and not shot in only.split(","):
			continue
		_show(shot)
		await get_tree().create_timer(0.6 if shot == "night" else 0.1).timeout
		await _save("style_" + shot)
	get_tree().quit()


func _save(shot: String) -> void:
	for f: int in 6:
		await RenderingServer.frame_post_draw
	var path: String = ProjectSettings.globalize_path("res://screenshots/%s.png" % shot)
	get_viewport().get_texture().get_image().save_png(path)
	print("[Style] Saved %s" % path)
