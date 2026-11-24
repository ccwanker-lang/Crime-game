class_name SettingsMenu
extends Control
## The settings window (session B, user list item 1), built in code: tabs Graphics / Audio / Controls. Every change is
## applied and saved at once (`Settings`). Esc (or Close) closes it; while a key is being rebound Esc cancels that.
## Opened with `Settings.open_menu()`.

var _rebinding: String = ""
var _rebind_button: Button = null
var _key_buttons: Dictionary = {}  # action -> Button
var _key_warnings: Dictionary = {}  # action -> Label
var _old_mouse: int = Input.MOUSE_MODE_VISIBLE
var _res_option: OptionButton
var tabs: TabContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	name = "SettingsMenu"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_old_mouse = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(780, 560)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 10)
	panel.add_child(box)
	var title := Label.new()
	title.text = "Settings"
	title.add_theme_font_size_override(&"font_size", 28)
	box.add_child(title)
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(tabs)
	tabs.add_child(_graphics_tab())
	tabs.add_child(_audio_tab())
	tabs.add_child(_controls_tab())
	tabs.add_child(_controller_tab())
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(bottom)
	var hint := Label.new()
	hint.text = "Changes are saved at once."
	hint.modulate = Color(1, 1, 1, 0.6)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(hint)
	var close := Button.new()
	close.name = "CloseButton"
	close.text = "Close (Esc)"
	close.pressed.connect(close_menu)
	bottom.add_child(close)
	Settings.changed.connect(_refresh_keys)


func close_menu() -> void:
	Settings.save_settings()
	Input.mouse_mode = _old_mouse as Input.MouseMode
	queue_free()


func _input(event: InputEvent) -> void:
	if _rebinding != "":
		var done: InputEvent = null
		if event is InputEventKey and event.pressed and not event.echo:
			if (event as InputEventKey).keycode == KEY_ESCAPE:
				_stop_rebind()
				get_viewport().set_input_as_handled()
				return
			var k := InputEventKey.new()
			k.physical_keycode = (event as InputEventKey).physical_keycode
			done = k
		elif event is InputEventMouseButton and event.pressed:
			var m := InputEventMouseButton.new()
			m.button_index = (event as InputEventMouseButton).button_index
			done = m
		if done:
			var action: String = _rebinding
			_stop_rebind()
			Settings.rebind(action, done)
			get_viewport().set_input_as_handled()
		elif event is InputEventKey or event is InputEventMouseButton:
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_ESCAPE:
		close_menu()
		get_viewport().set_input_as_handled()
	elif (event is InputEventAction or event is InputEventJoypadButton) and event.is_action_pressed(&"release_mouse"):
		close_menu()  # (controller: Start, or B through Gamepad)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey:
		get_viewport().set_input_as_handled()  # no walking / shooting / phone while the window is open


# --- Graphics ---------------------------------------------------------------------

func _graphics_tab() -> Control:
	var grid := _grid("Graphics")
	var mode := _option(Settings.WINDOW_MODES, Settings.window_mode, func(i: int) -> void:
		Settings.window_mode = i
		_res_option.disabled = i != 0
		Settings.apply_display()
		Settings.save_settings())
	_row(grid, "Window", mode)
	var res_names: PackedStringArray = []
	var res_index: int = 0
	for i: int in Settings.RESOLUTIONS.size():
		var r: Vector2i = Settings.RESOLUTIONS[i]
		res_names.append("%d x %d" % [r.x, r.y])
		if r == Settings.resolution:
			res_index = i
	_res_option = _option(res_names, res_index, func(i: int) -> void:
		Settings.resolution = Settings.RESOLUTIONS[i]
		Settings.apply_display()
		Settings.save_settings())
	_res_option.disabled = Settings.window_mode != 0
	_res_option.tooltip_text = "Only for windowed mode (fullscreen uses your screen's own resolution)."
	_row(grid, "Resolution", _res_option)
	_row(grid, "Quality", _option(Settings.QUALITY, Settings.quality, func(i: int) -> void:
		Settings.quality = i
		Settings.apply_quality()
		Settings.save_settings()))
	var fps_names: PackedStringArray = []
	var fps_index: int = Settings.FPS_LIMITS.size() - 1
	for i: int in Settings.FPS_LIMITS.size():
		var f: int = Settings.FPS_LIMITS[i]
		fps_names.append("No limit" if f == 0 else "%d FPS" % f)
		if f == Settings.fps_limit:
			fps_index = i
	_row(grid, "FPS limit", _option(fps_names, fps_index, func(i: int) -> void:
		Settings.fps_limit = Settings.FPS_LIMITS[i]
		Settings.apply_display()
		Settings.save_settings()))
	_row(grid, "VSync", _check(Settings.vsync, func(on: bool) -> void:
		Settings.vsync = on
		Settings.apply_display()
		Settings.save_settings()))
	_row(grid, "Field of view", _slider(60.0, 110.0, 1.0, Settings.fov, "%d°", func(v: float) -> void:
		Settings.fov = v
		Settings.changed.emit()
		Settings.save_settings()))
	return grid.get_parent().get_parent()  # (the ScrollContainer = the tab)


# --- Audio ------------------------------------------------------------------------

func _audio_tab() -> Control:
	var grid := _grid("Audio")
	for b: Array in Settings.BUSES:
		var bus: String = b[0]
		_row(grid, b[1], _slider(0.0, 100.0, 1.0, float(Settings.volumes.get(bus, 1.0)) * 100.0, "%d%%",
				func(v: float) -> void:
					Settings.volumes[bus] = v / 100.0
					Settings.apply_audio()
					Settings.save_settings()))
	var note := Label.new()
	note.text = "Effects = guns, cars, doors, machines. Ambience = the sound of the streets, the docks, the woods."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(300, 0)
	note.modulate = Color(1, 1, 1, 0.6)
	grid.add_child(Control.new())
	grid.add_child(note)
	return grid.get_parent().get_parent()  # (the ScrollContainer = the tab)


# --- Controls ---------------------------------------------------------------------

func _controls_tab() -> Control:
	var grid := _grid("Controls")
	_row(grid, "Mouse sensitivity", _slider(0.2, 3.0, 0.05, Settings.mouse_sensitivity, "%.2fx", func(v: float) -> void:
		Settings.mouse_sensitivity = v
		Settings.save_settings()))
	_row(grid, "Invert mouse Y", _check(Settings.invert_y, func(on: bool) -> void:
		Settings.invert_y = on
		Settings.save_settings()))
	for a: Array in Settings.ACTIONS:
		if not InputMap.has_action(a[0]):
			continue
		var action: String = a[0]
		var cell := HBoxContainer.new()
		var b := Button.new()
		b.name = "Key_" + action
		b.custom_minimum_size = Vector2(150, 0)
		b.pressed.connect(func() -> void: _start_rebind(action, b))
		cell.add_child(b)
		var warn := Label.new()
		warn.modulate = Color(1.0, 0.7, 0.3)
		warn.add_theme_font_size_override(&"font_size", 13)
		cell.add_child(warn)
		_key_buttons[action] = b
		_key_warnings[action] = warn
		_row(grid, a[1], cell)
	var reset := Button.new()
	reset.text = "Reset all keys"
	reset.pressed.connect(Settings.reset_keys)
	grid.add_child(Control.new())
	grid.add_child(reset)
	_refresh_keys()
	return grid.get_parent().get_parent()  # (the ScrollContainer = the tab)


# --- Controller (user list item 5) ----------------------------------------------------------

func _controller_tab() -> Control:
	var grid := _grid("Controller")
	var pad := Label.new()
	pad.name = "PadName"
	pad.text = Gamepad.pad_name() if Gamepad.connected() else "No controller connected (Xbox, PlayStation and most others work)."
	pad.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_row(grid, "Controller", pad)
	_row(grid, "Look speed", _slider(0.3, 3.0, 0.05, Settings.stick_sensitivity, "%.2fx", func(v: float) -> void:
		Settings.stick_sensitivity = v
		Settings.save_settings()))
	_row(grid, "Vibration", _check(Settings.vibration, func(on: bool) -> void:
		Settings.vibration = on
		Settings.save_settings()))
	var kind: String = Gamepad.pad_kind()
	for line: Array in Gamepad.layout(kind):
		var l := Label.new()
		l.text = line[1]
		l.add_theme_color_override(&"font_color", Color(0.85, 0.85, 0.9))
		_row(grid, line[0], l)
	var note := Label.new()
	note.text = "Invert Y (Controls tab) works for the stick too. In menus and windows the left stick moves the " 			+ "pointer, A / Cross clicks, B / Circle goes back, the right stick scrolls."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override(&"font_color", Color(0.65, 0.65, 0.7))
	grid.add_child(Control.new())
	grid.add_child(note)
	return grid.get_parent().get_parent()


func _start_rebind(action: String, b: Button) -> void:
	_stop_rebind()
	_rebinding = action
	_rebind_button = b
	b.text = "Press a key... (Esc = cancel)"


func _stop_rebind() -> void:
	_rebinding = ""
	_rebind_button = null
	_refresh_keys()


func _refresh_keys() -> void:
	for action: String in _key_buttons:
		var b: Button = _key_buttons[action]
		if not is_instance_valid(b) or action == _rebinding:
			continue
		b.text = Settings.event_label(Settings.main_event(action))
		var c: PackedStringArray = Settings.conflicts(action)
		(_key_warnings[action] as Label).text = "also: %s" % ", ".join(c) if not c.is_empty() else ""


# --- Little builders --------------------------------------------------------------

func _grid(tab_name: String) -> GridContainer:
	var scroll := ScrollContainer.new()
	scroll.name = tab_name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	scroll.add_child(margin)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 24)
	grid.add_theme_constant_override(&"v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(grid)
	return grid


func _row(grid: GridContainer, label: String, control: Control) -> void:
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(220, 0)
	grid.add_child(l)
	if not control is CheckBox:
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(control)


func _option(items: PackedStringArray, selected: int, on_pick: Callable) -> OptionButton:
	var o := OptionButton.new()
	for it: String in items:
		o.add_item(it)
	o.select(clampi(selected, 0, items.size() - 1))
	o.item_selected.connect(on_pick)
	return o


func _check(on: bool, on_toggle: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.flat = true  # (the game theme's button styles would paint the whole row)
	for st: StringName in [&"normal", &"pressed", &"hover", &"hover_pressed", &"focus"]:
		c.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	c.button_pressed = on
	c.toggled.connect(on_toggle)
	return c


func _slider(lo: float, hi: float, step: float, value: float, fmt: String, on_change: Callable) -> Control:
	var h := HBoxContainer.new()
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(240, 0)
	var l := Label.new()
	l.custom_minimum_size = Vector2(70, 0)
	l.text = fmt % value
	s.value_changed.connect(func(v: float) -> void:
		l.text = fmt % v
		on_change.call(v))
	h.add_child(s)
	h.add_child(l)
	return h
