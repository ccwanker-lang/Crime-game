extends Node
## Player settings (session B, user list item 1): graphics, audio and controls, saved in user://settings.cfg (the same
## file the main menu keeps the player name + last IP in; own sections here). Applied at start-up and on every change.
## The menu itself is `SettingsMenu` (scripts/ui/settings_menu.gd): `Settings.open_menu()` from the main menu and the
## in-game panel. Test runs (headless, --selftest, --netcheck, --screenshot, --perf, a fixed --resolution/--position...)
## keep the project's own display/quality settings so screenshots and FPS numbers stay comparable.

signal changed

const PATH: String = "user://settings.cfg"
## Test runs use their own file: they never read or change the player's settings.
const TEST_PATH: String = "user://settings_test.cfg"
var path: String = PATH
const RESOLUTIONS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900),
		Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3440, 1440), Vector2i(3840, 2160)]
const WINDOW_MODES: PackedStringArray = ["Windowed", "Borderless fullscreen", "Fullscreen"]
const QUALITY: PackedStringArray = ["Low", "Medium", "High", "Ultra"]
## 0 = no limit.
const FPS_LIMITS: Array[int] = [30, 60, 75, 120, 144, 165, 240, 0]
## Audio buses: [bus name, label]. Made at start-up when the project has no bus layout for them.
const BUSES: Array[Array] = [["Master", "Master"], ["Music", "Music"], ["SFX", "Effects"], ["Voice", "Voices"],
		["Ambience", "Ambience"]]
## Actions that can be rebound (label per action); debug keys (F-keys) are not in the list.
const ACTIONS: Array[Array] = [
	["move_forward", "Move forward"], ["move_back", "Move back"], ["move_left", "Move left"], ["move_right", "Move right"],
	["sprint", "Sprint"], ["jump", "Jump"], ["crouch", "Crouch"], ["interact", "Interact / talk / use"],
	["fire", "Shoot"], ["aim", "Aim"], ["reload", "Reload"], ["weapon_holster", "Holster weapon"],
	["weapon_toggle", "Last weapon"], ["weapon_next", "Next slot"], ["weapon_prev", "Previous slot"],
	["weapon_1", "Slot 1"], ["weapon_2", "Slot 2"], ["weapon_3", "Slot 3"], ["weapon_4", "Slot 4"],
	["weapon_5", "Slot 5"], ["weapon_6", "Slot 6"], ["weapon_7", "Slot 7"], ["weapon_8", "Slot 8"],
	["drop", "Drop item"], ["build_mode", "Build mode"], ["phone", "Phone"], ["toggle_view", "First / third person"],
	["vehicle", "Enter / leave car"], ["horn", "Horn"], ["night_lights", "Lights"], ["release_mouse", "Free the mouse / back"],
]

# --- Values (defaults) ---
var resolution: Vector2i = Vector2i(1920, 1080)
var window_mode: int = 1
var quality: int = 2
var fps_limit: int = 0
var vsync: bool = true
var fov: float = 75.0
var volumes: Dictionary = {"Master": 0.9, "Music": 0.6, "SFX": 0.9, "Voice": 1.0, "Ambience": 0.8}
var mouse_sensitivity: float = 1.0
var invert_y: bool = false
## Controller (user list item 5): right stick look speed (x) and rumble.
var stick_sensitivity: float = 1.0
var vibration: bool = true

## The project's own bindings (for "Reset"), per action: Array[InputEvent].
var _defaults: Dictionary = {}
var _menu: Control = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a: Array in ACTIONS:
		if InputMap.has_action(a[0]):
			_defaults[a[0]] = InputMap.action_get_events(a[0]).duplicate()
	_ensure_buses()
	if test_run():
		path = TEST_PATH
	load_settings()
	apply_all()
	get_tree().node_added.connect(_on_node_added)


## True for automated runs: keep the project's display + quality settings.
static func test_run() -> bool:
	if DisplayServer.get_name() == "headless":
		return true
	for a: String in OS.get_cmdline_args():
		if a in ["--resolution", "--position"] or a.begins_with("--resolution=") or a.begins_with("--position="):
			return true
	for a: String in OS.get_cmdline_user_args():
		if a in ["--selftest", "--netcheck", "--screenshot", "--perf", "--scenario-quit", "--style-shots", "--vmpreview",
				"--bench-quit"]:
			return true
	return false


# --- Save / load ------------------------------------------------------------------

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		resolution = DisplayServer.screen_get_size() if DisplayServer.get_name() != "headless" else resolution
		return
	resolution = cfg.get_value("graphics", "resolution", resolution)
	window_mode = cfg.get_value("graphics", "window_mode", window_mode)
	quality = cfg.get_value("graphics", "quality", quality)
	fps_limit = cfg.get_value("graphics", "fps_limit", fps_limit)
	vsync = cfg.get_value("graphics", "vsync", vsync)
	fov = cfg.get_value("graphics", "fov", fov)
	for bus: String in volumes:
		volumes[bus] = float(cfg.get_value("audio", bus, volumes[bus]))
	mouse_sensitivity = cfg.get_value("controls", "mouse_sensitivity", mouse_sensitivity)
	invert_y = cfg.get_value("controls", "invert_y", invert_y)
	stick_sensitivity = cfg.get_value("controls", "stick_sensitivity", stick_sensitivity)
	vibration = cfg.get_value("controls", "vibration", vibration)
	if cfg.has_section("keys"):
		for action: String in cfg.get_section_keys("keys"):
			if not InputMap.has_action(action):
				continue
			var ev: InputEvent = event_from_text(str(cfg.get_value("keys", action, "")))
			if ev:
				_set_main_event(action, ev)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(path)  # keep the menu's name / last IP
	cfg.set_value("graphics", "resolution", resolution)
	cfg.set_value("graphics", "window_mode", window_mode)
	cfg.set_value("graphics", "quality", quality)
	cfg.set_value("graphics", "fps_limit", fps_limit)
	cfg.set_value("graphics", "vsync", vsync)
	cfg.set_value("graphics", "fov", fov)
	for bus: String in volumes:
		cfg.set_value("audio", bus, volumes[bus])
	cfg.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("controls", "invert_y", invert_y)
	cfg.set_value("controls", "stick_sensitivity", stick_sensitivity)
	cfg.set_value("controls", "vibration", vibration)
	if cfg.has_section("keys"):
		cfg.erase_section("keys")
	for a: Array in ACTIONS:
		var ev: InputEvent = main_event(a[0])
		var def: InputEvent = _main_of(_defaults.get(a[0], []))
		if ev and (def == null or event_text(ev) != event_text(def)):
			cfg.set_value("keys", a[0], event_text(ev))
	cfg.save(path)


# --- Apply ------------------------------------------------------------------------

func apply_all() -> void:
	apply_display()
	apply_quality()
	apply_audio()
	changed.emit()


func apply_display() -> void:
	if test_run():
		return
	match window_mode:
		0:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_size(resolution)
			var screen: Vector2i = DisplayServer.screen_get_size()
			DisplayServer.window_set_position(DisplayServer.screen_get_position() + (screen - resolution) / 2)
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = fps_limit


## Quality presets: render scale, anti-aliasing, shadows, screen-space effects, LOD and draw distance.
func apply_quality() -> void:
	if test_run():
		return
	var vp: Viewport = get_tree().root
	var q: int = clampi(quality, 0, QUALITY.size() - 1)
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if q == 0 else Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = [0.75, 1.0, 1.0, 1.0][q]
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][q]
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if q <= 1 else Viewport.SCREEN_SPACE_AA_DISABLED
	vp.mesh_lod_threshold = [4.0, 2.0, 1.0, 0.5][q]
	RenderingServer.directional_shadow_atlas_set_size([1024, 2048, 4096, 8192][q], true)
	RenderingServer.directional_soft_shadow_filter_set_quality([RenderingServer.SHADOW_QUALITY_HARD,
			RenderingServer.SHADOW_QUALITY_SOFT_LOW, RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM,
			RenderingServer.SHADOW_QUALITY_SOFT_HIGH][q])
	RenderingServer.positional_soft_shadow_filter_set_quality([RenderingServer.SHADOW_QUALITY_HARD,
			RenderingServer.SHADOW_QUALITY_SOFT_LOW, RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM,
			RenderingServer.SHADOW_QUALITY_SOFT_HIGH][q])
	vp.positional_shadow_atlas_size = [1024, 2048, 4096, 8192][q]
	for n: Node in get_tree().get_nodes_in_group(&"settings_environment"):
		_apply_environment(n as WorldEnvironment)


func _apply_environment(we: WorldEnvironment) -> void:
	if we == null or we.environment == null or test_run():
		return
	var env: Environment = we.environment
	if not we.has_meta(&"orig_ssil"):
		we.set_meta(&"orig_ssil", env.ssil_enabled)
		we.set_meta(&"orig_ssao", env.ssao_enabled)
		we.set_meta(&"orig_glow", env.glow_enabled)
	# Low: no screen-space light/shadow; Medium: SSAO only; High/Ultra: what the level designer set.
	env.ssil_enabled = bool(we.get_meta(&"orig_ssil")) and quality >= 2
	env.ssao_enabled = bool(we.get_meta(&"orig_ssao")) and quality >= 1
	env.glow_enabled = bool(we.get_meta(&"orig_glow")) and quality >= 1


func apply_audio() -> void:
	for bus: String in volumes:
		var i: int = AudioServer.get_bus_index(bus)
		if i < 0:
			continue
		var v: float = clampf(float(volumes[bus]), 0.0, 1.0)
		AudioServer.set_bus_volume_db(i, linear_to_db(v) if v > 0.001 else -80.0)
		AudioServer.set_bus_mute(i, v <= 0.001)


func _ensure_buses() -> void:
	for b: Array in BUSES:
		if AudioServer.get_bus_index(b[0]) >= 0:
			continue
		AudioServer.add_bus()
		var i: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, b[0])
		AudioServer.set_bus_send(i, &"Master")


## Every sound player that still plays on Master goes through "SFX" (so the Effects slider works); music and
## ambience players set their own bus (meta "keep_bus" leaves a player alone).
func _on_node_added(n: Node) -> void:
	if n is WorldEnvironment:
		n.add_to_group(&"settings_environment")
		_apply_environment.call_deferred(n)
		return
	if n.has_meta(&"keep_bus"):
		return
	if n is AudioStreamPlayer3D:
		if (n as AudioStreamPlayer3D).bus == &"Master":
			(n as AudioStreamPlayer3D).bus = &"SFX"
	elif n is AudioStreamPlayer:
		if (n as AudioStreamPlayer).bus == &"Master":
			(n as AudioStreamPlayer).bus = &"SFX"
	elif n is AudioStreamPlayer2D:
		if (n as AudioStreamPlayer2D).bus == &"Master":
			(n as AudioStreamPlayer2D).bus = &"SFX"


# --- Controls ---------------------------------------------------------------------

## Mouse look factor (Player multiplies its base sensitivity by this; y gets the invert sign).
func look_scale() -> Vector2:
	return Vector2(mouse_sensitivity, mouse_sensitivity * (-1.0 if invert_y else 1.0))


## The keyboard/mouse binding shown and changed in the menu (the first one; controller events stay as they are).
func main_event(action: String) -> InputEvent:
	return _main_of(InputMap.action_get_events(action)) if InputMap.has_action(action) else null


static func _main_of(events: Array) -> InputEvent:
	for ev: InputEvent in events:
		if ev is InputEventKey or ev is InputEventMouseButton:
			return ev
	return null


func rebind(action: String, ev: InputEvent) -> void:
	_set_main_event(action, ev)
	save_settings()
	changed.emit()


func _set_main_event(action: String, ev: InputEvent) -> void:
	var old: InputEvent = main_event(action)
	if old:
		InputMap.action_erase_event(action, old)
	InputMap.action_add_event(action, ev)


func reset_keys() -> void:
	for action: String in _defaults:
		InputMap.action_erase_events(action)
		for ev: InputEvent in _defaults[action]:
			InputMap.action_add_event(action, ev)
	save_settings()
	changed.emit()


## Other actions that use the same key/button as `action` (shown as a warning in the menu).
func conflicts(action: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var ev: InputEvent = main_event(action)
	if ev == null:
		return out
	for a: Array in ACTIONS:
		if a[0] != action:
			var other: InputEvent = main_event(a[0])
			if other and event_text(other) == event_text(ev):
				out.append(a[1])
	return out


static func event_text(ev: InputEvent) -> String:
	if ev is InputEventKey:
		var k := ev as InputEventKey
		var code: int = k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
		return "key:%d" % code
	if ev is InputEventMouseButton:
		return "mouse:%d" % (ev as InputEventMouseButton).button_index
	return ""


static func event_from_text(t: String) -> InputEvent:
	if t.begins_with("key:"):
		var k := InputEventKey.new()
		k.physical_keycode = t.trim_prefix("key:").to_int() as Key
		return k
	if t.begins_with("mouse:"):
		var m := InputEventMouseButton.new()
		m.button_index = t.trim_prefix("mouse:").to_int() as MouseButton
		return m
	return null


## "W", "Left mouse", "Space"...
static func event_label(ev: InputEvent) -> String:
	if ev is InputEventKey:
		var k := ev as InputEventKey
		var code: int = k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
		var shown: int = code
		if k.physical_keycode != KEY_NONE and DisplayServer.get_name() != "headless":
			shown = DisplayServer.keyboard_get_keycode_from_physical(code)
		return OS.get_keycode_string(shown)
	if ev is InputEventMouseButton:
		match (ev as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT: return "Left mouse"
			MOUSE_BUTTON_RIGHT: return "Right mouse"
			MOUSE_BUTTON_MIDDLE: return "Middle mouse"
			MOUSE_BUTTON_WHEEL_UP: return "Wheel up"
			MOUSE_BUTTON_WHEEL_DOWN: return "Wheel down"
			MOUSE_BUTTON_XBUTTON1: return "Mouse 4"
			MOUSE_BUTTON_XBUTTON2: return "Mouse 5"
		return "Mouse %d" % (ev as InputEventMouseButton).button_index
	return "-"


# --- The menu ---------------------------------------------------------------------

func is_menu_open() -> bool:
	return is_instance_valid(_menu)


## Opens the settings window on top of everything (main menu or in game).
func open_menu() -> void:
	if is_menu_open():
		return
	var layer := CanvasLayer.new()
	layer.layer = 90
	layer.name = "SettingsLayer"
	layer.process_mode = Node.PROCESS_MODE_ALWAYS  # (works over the paused game)
	get_tree().root.add_child(layer)
	_menu = SettingsMenu.new()
	layer.add_child(_menu)
	_menu.tree_exited.connect(func() -> void:
		if is_instance_valid(layer):
			layer.queue_free())
