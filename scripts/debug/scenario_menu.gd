class_name ScenarioMenu
extends CanvasLayer
## F9: list of test scenarios (Scenarios.LIST). Clicking one restarts the host into a fresh
## test game set up for it (the real save is written first and left alone).
## While a scenario runs, a small banner at the top says so.

var _panel: CenterContainer
var _info: Label
var _banner: Label


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_banner = Label.new()
	_banner.text = "TEST SCENARIO - not your real save (Leave -> Host - continue = your own game)   F9 = scenarios"
	_banner.add_theme_color_override("font_color", Color(1, 0.8, 0.3))
	_banner.add_theme_color_override("font_outline_color", Color.BLACK)
	_banner.add_theme_constant_override("outline_size", 6)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.position.y = 6
	_banner.visible = SaveManager.scenario_mode
	add_child(_banner)

	_panel = CenterContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	add_child(_panel)
	var frame := PanelContainer.new()
	_panel.add_child(frame)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	frame.add_child(box)
	var head := Label.new()
	head.text = "Test scenarios (F9 / Esc closes). Starts a fresh TEST game - your real save is kept safe."
	box.add_child(head)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	box.add_child(grid)
	for s: Array in Scenarios.LIST:
		var b := Button.new()
		b.text = "%s  -  %s" % [s[0], s[1]]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(500, 0)
		b.clip_text = true
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_entered.connect(func() -> void: _info.text = str(s[2]))
		b.pressed.connect(_start.bind(str(s[0])))
		grid.add_child(b)
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(1000, 70)
	_info.text = "Hover a scenario to see what to check."
	box.add_child(_info)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.physical_keycode == KEY_F9:
		toggle()
		get_viewport().set_input_as_handled()
	elif key.physical_keycode == KEY_ESCAPE and _panel.visible:
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	_panel.visible = not _panel.visible
	if _panel.visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _start(id: String) -> void:
	if not multiplayer.is_server():
		_info.text = "Only the host can start a scenario (it restarts the game)."
		return
	_panel.visible = false
	Scenarios.restart_into(get_tree(), id)
