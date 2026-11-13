extends Node3D
## Point 27: art style comparison (`--scenario=style_compare` or F9). Three pieces of street
## next to each other, each with the same 3 houses, a car, an NPC and the pistol + AK as
## viewmodel, dressed in one proposal:
##   A  stylized low-poly, flat/soft colours, simpler houses
##   B  low-poly with a bit more detail and the PBR materials
##   C  (own proposal) flat colours with faint texture detail, banded light, outlines on
##      people/cars/weapons, simpler houses
## Keys: 1/2/3 = street of A/B/C, 4/5/6 = viewmodel of A/B/C, right mouse + WASD = fly, Esc = menu.
## `--style-shots` saves screenshots/style_<X>_street.png + _view.png + style_overview.png and quits.

const STYLES: Array[String] = ["A", "B", "C"]
const TITLES: Dictionary = {
	"A": "A  Stylized low-poly (flat, soft)",
	"B": "B  Low-poly + PBR materials",
	"C": "C  Flat colours + outlines (own proposal)",
}
const SPACING: float = 60.0
const HOUSES: Array = [["row_house_a", 6.0], ["row_house_c", 7.2], ["corner_house", 7.5]]
const SIMPLE: Dictionary = {"string_courses": false, "corner_quoins": false, "dormer": false, "bay_window_bay": -1,
		"balcony_bay": -1, "chimney": "none", "side_windows": false}
const MORE: Dictionary = {"string_courses": false, "corner_quoins": false, "balcony_bay": -1}

var _cam: Camera3D
var _street_cams: Array[Transform3D] = []
var _view_cams: Array[Camera3D] = []
var _fly: bool = false


func _ready() -> void:
	var sky: Node = (load("res://prefabs/environment/sun_and_sky.tscn") as PackedScene).instantiate()
	add_child(sky)
	if sky.has_method("set_hours"):
		sky.call("set_hours", 11.0)
	_cam = Camera3D.new()
	_cam.fov = 70.0
	add_child(_cam)
	for i: int in STYLES.size():
		_build_stage(STYLES[i], i * SPACING)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame  # buildings build deferred
	for i: int in STYLES.size():
		var stage: Node3D = get_node("Stage" + STYLES[i])
		var outline: float = 0.0
		Stylizer.apply(stage.get_node("Static"), STYLES[i])
		if STYLES[i] == "C":
			outline = 2.0  # pixels
		Stylizer.apply(stage.get_node("Moving"), STYLES[i], outline)
		Stylizer.apply(_view_cams[i], STYLES[i], 3.0 if STYLES[i] == "C" else 0.0)
	_show_street(0)
	if "--style-shots" in OS.get_cmdline_user_args():
		_take_shots()


func _build_stage(style: String, x: float) -> void:
	var stage := Node3D.new()
	stage.name = "Stage" + style
	stage.position = Vector3(x, 0, 0)
	add_child(stage)
	var stat := Node3D.new()
	stat.name = "Static"
	stage.add_child(stat)
	var moving := Node3D.new()
	moving.name = "Moving"
	stage.add_child(moving)
	for tx: float in [-6.0, 6.0]:
		var road: Node3D = (load("res://prefabs/roads/road_straight.tscn") as PackedScene).instantiate()
		road.position = Vector3(tx, 0, 0)
		stat.add_child(road)
	var hx: float = -10.35
	for h: Array in HOUSES:
		var b: Node3D = (load("res://prefabs/buildings/%s.tscn" % h[0]) as PackedScene).instantiate()
		var props: Dictionary = MORE if style == "B" else SIMPLE
		for k: String in props:
			b.set(k, props[k])
		b.set("enterable", false)
		b.set("upper_floors", false)
		b.set("furnish", "none")
		b.position = Vector3(hx + float(h[1]) / 2.0, 0, -6.0)
		hx += float(h[1])
		stat.add_child(b)
	var lamp: Node3D = (load("res://prefabs/props/street_lamp.tscn") as PackedScene).instantiate()
	lamp.position = Vector3(6.0, 0.15, -3.95)
	lamp.rotation.y = PI
	stat.add_child(lamp)
	# Car on the near lane, an NPC on the pavement.
	var car := Node3D.new()
	car.position = Vector3(2.5, 0.0, 1.75)
	car.rotation.y = -PI / 2.0
	moving.add_child(car)
	ProcCar.build(car, 0, Color(0.62, 0.12, 0.1))
	var npc: Node3D = (load(Pedestrian.MODEL_DIR % "man_casual") as PackedScene).instantiate()
	npc.scale = Vector3.ONE * 0.37
	npc.position = Vector3(-3.5, 0.15, -4.4)
	npc.rotation.y = 0.35
	moving.add_child(npc)
	var anim: AnimationPlayer = npc.find_children("*", "AnimationPlayer", true, false)[0]
	for a: String in anim.get_animation_list():
		if a.ends_with("Idle"):
			anim.play(a)
			break
	var label := Label3D.new()
	label.text = TITLES[style]
	label.font_size = 96
	label.pixel_size = 0.012
	label.outline_size = 16
	label.position = Vector3(0, 13.5, -6.0)
	stat.add_child(label)
	# Street view and a viewmodel camera with the pistol (right) and the AK (left).
	_street_cams.append(Transform3D(Basis(), Vector3(x + 1.0, 1.8, 10.5)).looking_at(Vector3(x - 1.0, 4.0, -6.0)))
	var vc := Camera3D.new()
	vc.fov = 70.0
	vc.position = Vector3(x - 4.0, 1.7, 3.2)
	stage.add_child(vc)
	vc.global_transform = Transform3D(Basis(), Vector3(x - 1.5, 1.7, 3.5)).looking_at(Vector3(x - 4.5, 1.5, -5.0))
	var pistol: Node3D = (ItemDB.get_item(&"pistol") as WeaponData).model_scene.instantiate()
	pistol.position = Vector3(0.2, -0.19, -0.42)
	pistol.rotation = Vector3(0.0, 0.08, 0.0)
	vc.add_child(pistol)
	var ak: Node3D = (ItemDB.get_item(&"ak47") as WeaponData).model_scene.instantiate()
	ak.position = Vector3(-0.2, -0.24, -0.62)
	ak.rotation = Vector3(0.05, -0.12, 0.0)
	vc.add_child(ak)
	_view_cams.append(vc)


func _show_street(i: int) -> void:
	_cam.global_transform = _street_cams[i]
	_cam.make_current()


func _show_view(i: int) -> void:
	_view_cams[i].make_current()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo:
		match key.physical_keycode:
			KEY_1, KEY_2, KEY_3:
				_show_street(key.physical_keycode - KEY_1)
			KEY_4, KEY_5, KEY_6:
				_show_view(key.physical_keycode - KEY_4)
			KEY_ESCAPE:
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
	for i: int in STYLES.size():
		_show_street(i)
		await _save("style_%s_street" % STYLES[i])
		_show_view(i)
		await _save("style_%s_view" % STYLES[i])
	_cam.global_transform = Transform3D(Basis(), Vector3(SPACING, 30.0, 48.0)).looking_at(Vector3(SPACING, 2.0, -4.0))
	_cam.make_current()
	await _save("style_overview")
	get_tree().quit()


func _save(shot: String) -> void:
	for f: int in 4:
		await RenderingServer.frame_post_draw
	var path: String = ProjectSettings.globalize_path("res://screenshots/%s.png" % shot)
	get_viewport().get_texture().get_image().save_png(path)
	print("[Style] Saved %s" % path)
