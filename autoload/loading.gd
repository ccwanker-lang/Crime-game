extends CanvasLayer
## Loading screen (session B, user list item 3). `Loading.go_to_world()` replaces change_scene_to_file(world): it loads
## world.tscn on a thread with a progress bar, a background picture and rotating tips, switches scenes and stays up
## until the local player stands in the world (the host also bakes the navmesh first; a client waits for the host).
## Headless runs switch scenes straight away (tests keep their timing).

const WORLD_SCENE: String = "res://scenes/world/world.tscn"
const BACKGROUNDS: Array[String] = ["res://assets/ui/backgrounds/title_night.jpg",
		"res://assets/ui/backgrounds/loading_day.jpg"]
const TIP_TIME: float = 6.0
const GIVE_UP: float = 120.0
const TIPS: Array[String] = [
	"Press Tab for your phone: texts from customers, the map, the webshop, your crew and the turf app.",
	"Press F1 in the game for every key.",
	"Esc opens the pause menu: settings, save, leave. Alone the game pauses; in co-op it keeps running.",
	"Customers text you a price. Accept, decline or haggle - but a picky customer walks away.",
	"Dirty money is dropped when you die. Launder it in a safe in a bakery, barber or laundromat you own.",
	"Wanted stars fade once the police lose sight of you: hide, and wait out the search.",
	"Holding a gun is no crime; firing one in town is.",
	"Press B for build mode: place stations and furniture inside a property your crew owns.",
	"Sleep in your own bed to skip the night - every player in the crew has to lie down.",
	"Crouch to walk quietly: your footsteps are softer.",
	"Black Crows own the yard and the pier. Their turf is no place to deal at night.",
	"Higher quality product sells for more. Try premium seeds, a grow lamp or pure reagents.",
	"Hire dealers and growers in the Crew app; they need wages from a staff locker.",
	"Cars need fuel. Three gas stations: the city, the docks and the road to the prison.",
	"Press F to get in a car, H to honk. Running people over gets you stars fast.",
	"Rook's black market only opens at night, behind the garage.",
	"Three save slots: a new game never overwrites another slot.",
	"All keys can be rebound in Settings > Controls.",
]

var active: bool = false
var _phase: int = 0  # 0 off, 1 loading the scene, 3 switching scenes, 2 waiting for the player
var _t: float = 0.0
var _tip_t: float = 0.0
var _tip_i: int = 0
var _root: Control
var _bg: TextureRect
var _bar: ProgressBar
var _status: Label
var _tip: Label
var _shown: float = 0.0


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


## Host / join: load the world behind the loading screen.
func go_to_world() -> void:
	if DisplayServer.get_name() == "headless":
		get_tree().change_scene_to_file(WORLD_SCENE)
		return
	_build()
	active = true
	_phase = 1
	_t = 0.0
	_shown = 0.0
	_tip_i = randi() % TIPS.size()
	_tip.text = TIPS[_tip_i]
	_tip_t = TIP_TIME
	_bg.texture = load(BACKGROUNDS[randi() % BACKGROUNDS.size()])
	_bar.value = 0.0
	_status.text = "Loading the map..."
	_root.modulate.a = 1.0
	visible = true
	ResourceLoader.load_threaded_request(WORLD_SCENE)
	print("[Loading] world")


func _process(delta: float) -> void:
	if not active:
		return
	_t += delta
	_shown += delta
	_tip_t -= delta
	if _tip_t <= 0.0:
		_tip_t = TIP_TIME
		_tip_i = (_tip_i + 1) % TIPS.size()
		_tip.text = TIPS[_tip_i]
	if _phase == 1:
		var progress: Array = []
		var st: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(WORLD_SCENE, progress)
		if st == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_bar.value = 60.0 * float(progress[0] if not progress.is_empty() else 0.0)
		elif st == ResourceLoader.THREAD_LOAD_LOADED:
			_bar.value = 60.0
			_status.text = "Building the town..." if multiplayer.is_server() else "Joining the host..."
			_phase = 3
			_switch.call_deferred(ResourceLoader.load_threaded_get(WORLD_SCENE) as PackedScene)
		else:
			push_error("[Loading] could not load %s" % WORLD_SCENE)
			_phase = 3
			get_tree().change_scene_to_file(WORLD_SCENE)
			await get_tree().scene_changed
			_phase = 2
			_t = 0.0
	elif _phase == 2:
		_bar.value = minf(97.0, _bar.value + delta * 4.0)
		var scene: Node = get_tree().current_scene
		if scene and scene.scene_file_path == Net.MAIN_MENU_SCENE and _t > 1.0:
			finish()  # (back in the menu: the join failed or the player left)
			return
		if _player_ready() or _t > GIVE_UP:
			finish()


func _switch(packed: PackedScene) -> void:
	await get_tree().process_frame  # (show "Building the town..." before the long frame)
	await get_tree().process_frame
	get_tree().change_scene_to_packed(packed)
	await get_tree().scene_changed  # (the old world, e.g. a scenario restart, must not count as "ready")
	_phase = 2
	_t = 0.0


func _player_ready() -> bool:
	var scene: Node = get_tree().current_scene
	if scene == null or not scene.has_node(^"Players"):
		return false
	var me: Node = scene.get_node(^"Players").get_node_or_null(str(multiplayer.get_unique_id()))
	return me != null and me.is_inside_tree()


## Fades the screen out (also used by tests).
func finish() -> void:
	if not active:
		return
	active = false
	_phase = 0
	_bar.value = 100.0
	print("[Loading] done after %.1f s" % _shown)
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func() -> void: visible = false)


func _build() -> void:
	if _root:
		return
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.theme = load("res://assets/ui/game_theme.tres")
	add_child(_root)
	var black := ColorRect.new()
	black.color = Color(0.03, 0.03, 0.05)
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(black)
	_bg = TextureRect.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg.modulate = Color(0.55, 0.55, 0.6)
	_root.add_child(_bg)
	var shade := TextureRect.new()  # dark band at the bottom for the text
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.texture = TitleArt.vertical_fade(Color(0, 0, 0, 0), Color(0, 0, 0, 0.92))
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	_root.add_child(shade)
	var title := TitleArt.logo(54)
	title.position = Vector2(56, 40)
	_root.add_child(title)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	box.offset_left = 56
	box.offset_right = -56
	box.offset_top = -190
	box.offset_bottom = -48
	box.add_theme_constant_override(&"separation", 10)
	_root.add_child(box)
	var head := Label.new()
	head.text = "TIP"
	head.add_theme_font_size_override(&"font_size", 18)
	head.add_theme_color_override(&"font_color", TitleArt.ACCENT)
	box.add_child(head)
	_tip = Label.new()
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.add_theme_font_size_override(&"font_size", 24)
	_tip.custom_minimum_size = Vector2(0, 64)
	box.add_child(_tip)
	_status = Label.new()
	_status.add_theme_font_size_override(&"font_size", 16)
	_status.add_theme_color_override(&"font_color", Color(0.75, 0.75, 0.8))
	box.add_child(_status)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 8)
	var fill := StyleBoxFlat.new()
	fill.bg_color = TitleArt.ACCENT
	fill.set_corner_radius_all(4)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(1, 1, 1, 0.12)
	back.set_corner_radius_all(4)
	_bar.add_theme_stylebox_override(&"fill", fill)
	_bar.add_theme_stylebox_override(&"background", back)
	box.add_child(_bar)
