class_name RangeWindow
extends Control
## Shooting range window (owner only, child of the player's HUD, built in code): E on Walt (RangeDesk).
## Start a drill, borrow a gun to try it, hand the loaner back, see your skill + best score.
## Requests go to the host via RangeClub.request(); Esc / E / Tab close it.

const ACCENT := Color(0.96, 0.77, 0.27)
const GOOD := Color(0.7, 1, 0.6)
const BAD := Color(1, 0.55, 0.45)

var player: Player
var _list: VBoxContainer
var _msg: Label


static func open_for(p: Player) -> void:
	if p == null or p.ui == null or p.dead:
		return
	var w := p.ui.get_node_or_null("RangeWindow") as RangeWindow
	if w == null:
		w = RangeWindow.new()
		w.player = p
		p.ui.add_child(w)
	w.open()


func _ready() -> void:
	name = "RangeWindow"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	box.add_child(_label(ShootingRange.SIGN.capitalize(), 24, ACCENT))
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	box.add_child(_list)
	_msg = _label("", 16, GOOD)
	box.add_child(_msg)
	var close := _button("Close  (Esc)")
	close.pressed.connect(close_window)
	box.add_child(close)


func open() -> void:
	visible = true
	_msg.text = ""
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	refresh()


func close_window() -> void:
	visible = false
	if player and not player.auto_walk:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func is_open() -> bool:
	return visible


func show_answer(text: String) -> void:
	_msg.text = text.trim_prefix("!")
	_msg.add_theme_color_override("font_color", BAD if text.begins_with("!") else GOOD)
	refresh()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("release_mouse") or event.is_action_pressed("interact") or event.is_action_pressed("phone"):
		close_window()
		get_viewport().set_input_as_handled()


func refresh() -> void:
	if _list == null or player == null:
		return
	for c: Node in _list.get_children():
		c.queue_free()
	var who: String = player.player_name
	var s: float = RangeClub.skill_of(who)
	_list.add_child(_label("Walt: \"Ear protection on. Shoot only downrange.\"", 16))
	_list.add_child(_label("Your skill: %d%%  (%d%% less spread with every gun)   Best drill: %d points" % [
			roundi(s * 100.0), roundi((1.0 - RangeClub.spread_factor(who)) * 100.0), RangeClub.best_of(who)], 16, ACCENT))
	if Progression.gates_on() and Progression.rank() < RangeClub.RANK:
		_list.add_child(_label("Members only: needs rank %d (%s)." % [RangeClub.RANK, Progression.rank_name(RangeClub.RANK)],
				16, BAD))
	var drill := _button("Start a drill  (€%d, %d s: targets pop up, bullseye = 2 points, skill goes up)" % [
			RangeClub.DRILL_FEE, int(RangeClub.DRILL_SECONDS)])
	drill.pressed.connect(func() -> void: RangeClub.request("drill"))
	_list.add_child(drill)
	var loan: String = str(RangeClub.loans.get(who, ""))
	if loan != "":
		var back := _button("Hand the %s back" % _name(loan))
		back.pressed.connect(func() -> void: RangeClub.request("return"))
		_list.add_child(back)
	_list.add_child(_label("Try a gun (€%d: the gun + %d magazines while you stay on the range, any rank):" % [
			RangeClub.TRY_FEE, RangeClub.TRY_MAGS], 15))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	_list.add_child(row)
	for id: StringName in PlayerCombat.LOADOUT:
		var b := _button(_name(String(id)))
		b.disabled = loan != "" or _carries(String(id))
		b.tooltip_text = "You carry one" if _carries(String(id)) else ""
		b.pressed.connect(func() -> void: RangeClub.request("try", String(id)))
		row.add_child(b)
	_list.add_child(_label("Free practice: shoot the standing targets with your own guns any time. Gunfire on the range "
			+ "doesn't bring the police.", 14, Color(0.75, 0.78, 0.82)))


func _carries(id: String) -> bool:
	for it: Variant in player.inventory:
		if it is Dictionary and str((it as Dictionary).get("id", "")) == id:
			return true
	return false


func _name(id: String) -> String:
	var it: ItemData = ItemDB.get_item(StringName(id))
	return it.display_name if it else id


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 16)
	return b


func _label(text: String, size: int = 16, color: Color = Color(0.93, 0.93, 0.95)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
