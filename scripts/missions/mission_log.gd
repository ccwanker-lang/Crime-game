class_name MissionLog
extends RefCounted
## NOTES part 19: the "Missions" app in the phone (A's Phone, hooked in by `Missions._on_node_added` when the home
## screen adds its Crew button; nothing in phone.gd changed). The log: the running mission with its steps (done ones
## ticked, the current one gold), the ones you can start (Start), the finished ones.

const COLOR := Color(1.0, 0.8, 0.25)


static func add_app_button(phone: Phone) -> void:
	if not is_instance_valid(phone) or phone._screen != "home" or phone._content.get_node_or_null("MissionsApp"):
		return
	var running: bool = str(Missions.view.get("active", "")) != ""
	var b := Button.new()
	b.name = "MissionsApp"
	b.text = "Missions%s" % ("  (running)" if running else "  (%d new)" % Missions.available().size() if not Missions.available().is_empty() else "")
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 64)
	b.add_theme_font_size_override("font_size", 20)
	var st := StyleBoxFlat.new()
	st.bg_color = COLOR.darkened(0.55)
	st.border_color = COLOR
	st.set_border_width_all(2)
	st.set_corner_radius_all(14)
	b.add_theme_stylebox_override("normal", st)
	var hover := st.duplicate() as StyleBoxFlat
	hover.bg_color = COLOR.darkened(0.35)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.pressed.connect(open.bind(phone))
	phone._content.add_child(b)
	phone._content.move_child(b, 0)


## Shows the log in the phone (the phone's "<" goes back home).
static func open(phone: Phone) -> void:
	phone._clear()
	phone._screen = "missions"
	phone._back.visible = true
	phone._title.text = "Missions"
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	phone._content.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	scroll.add_child(box)
	fill(box, phone)
	if not Missions.changed.is_connected(_refresh.bind(phone, box)):
		Missions.changed.connect(_refresh.bind(phone, box), CONNECT_ONE_SHOT)


static func _refresh(phone: Variant, box: Variant) -> void:
	if is_instance_valid(phone) and is_instance_valid(box) and (phone as Phone)._screen == "missions" and (phone as Phone).visible:
		open(phone as Phone)


static func fill(box: VBoxContainer, phone: Phone) -> void:
	var v: Dictionary = Missions.view
	var act: String = str(v.get("active", ""))
	if act != "":
		_head(box, "NOW")
		_text(box, str(v.get("title", "")), COLOR, 19)
		var m: MissionData = Missions.get_mission(StringName(act))
		if m and m.summary != "":
			_text(box, m.summary, Color(0.75, 0.75, 0.8), 13)
		var steps: Array = v.get("steps", [])
		var cur: int = int(v.get("step", 0))
		for i: int in steps.size():
			var t: String = str(v.get("text", "")) if i == cur else str(steps[i])
			var mark: String = "[x] " if i < cur else ("> " if i == cur else "[ ] ")
			_text(box, mark + t, COLOR if i == cur else (Color(0.5, 0.8, 0.5) if i < cur else Color(0.6, 0.6, 0.65)), 15)
		if m:
			_text(box, "Reward: %s" % m.reward_text(), Color(0.6, 0.85, 1.0), 13)
		var late: Array = v.get("late", [])
		if phone.player and phone.player.player_name in late:
			_text(box, "You joined late: you help, but get no reward.", Color(1, 0.55, 0.45), 13)
		_button(box, "Give up", Color(0.9, 0.4, 0.35), func() -> void: Missions.request_abandon())
	var avail: Array[StringName] = Missions.available()
	if not avail.is_empty():
		_head(box, "AVAILABLE")
		for id: StringName in avail:
			var m: MissionData = Missions.get_mission(id)
			if m == null:
				continue
			_text(box, "%s  (from %s)" % [m.title, m.giver], Color.WHITE, 17)
			_text(box, m.summary, Color(0.7, 0.7, 0.75), 13)
			_text(box, "Reward: %s" % m.reward_text(), Color(0.6, 0.85, 1.0), 13)
			_button(box, "Start", Color(0.4, 0.85, 0.45), func() -> void: Missions.request_start(id))
	var done: Array = v.get("done", [])
	if not done.is_empty():
		_head(box, "DONE")
		for id: String in done:
			var m: MissionData = Missions.get_mission(StringName(id))
			_text(box, "[x] %s" % (m.title if m else id), Color(0.5, 0.8, 0.5), 15)
	if act == "" and avail.is_empty() and done.is_empty():
		_text(box, "No missions yet. People will call you.", Color(0.6, 0.6, 0.65), 15)


static func _head(box: VBoxContainer, t: String) -> void:
	var l := _text(box, t, Color(0.55, 0.58, 0.65), 12)
	l.add_theme_constant_override("line_spacing", 0)


static func _text(box: VBoxContainer, t: String, color: Color, font_size: int) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	box.add_child(l)
	return l


static func _button(box: VBoxContainer, t: String, color: Color, action: Callable) -> void:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_color_override("font_color", color)
	b.pressed.connect(action)
	box.add_child(b)
