class_name CrewWindow
extends Control
## Staff + dealers window (owner only, child of the player's HUD). Built in code.
##   mode "crew"   - from the phone app "Crew": your crew (fire) + Benny's candidates (hire, pick a
##                   property for workers or a district for dealers).
##   mode "dealer" - E on one of your dealers: give bags, collect the cash.
## Frees the mouse while open; Esc / E / Tab close it. Requests go to the host via Staff.request().

const ACCENT := Color(0.96, 0.77, 0.27)
const GOOD := Color(0.7, 1, 0.6)
const BAD := Color(1, 0.55, 0.45)

var player: Player
var mode: String = "crew"
var dealer_uid: String = ""
var _tab: String = "crew"
var _title: Label
var _list: VBoxContainer
var _msg: Label
var _tabs: HBoxContainer


## Opens (or reuses) the window on `p`'s HUD.
static func open_for(p: Player, open_mode: String, uid: String) -> void:
	if p == null or p.ui == null or p.dead:
		return
	var w := p.ui.get_node_or_null("CrewWindow") as CrewWindow
	if w == null:
		w = CrewWindow.new()
		w.player = p
		p.ui.add_child(w)
	w.mode = open_mode
	w.dealer_uid = uid
	w.open()


func _ready() -> void:
	name = "CrewWindow"
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
	panel.custom_minimum_size = Vector2(760, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 24)
	_title.add_theme_color_override("font_color", ACCENT)
	box.add_child(_title)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 8)
	box.add_child(_tabs)
	for t: Array in [["crew", "Your crew"], ["hire", "Hire (Benny)"], ["legal", "Lawyer + cop"]]:
		var b := _button(t[1])
		b.pressed.connect(func() -> void:
			_tab = t[0]
			_refresh())
		_tabs.add_child(b)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)
	_msg = Label.new()
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg.add_theme_font_size_override("font_size", 16)
	box.add_child(_msg)
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(bottom)
	var close := _button("Close  [Esc / E]")
	close.pressed.connect(close_window)
	bottom.add_child(close)
	Staff.members_changed.connect(_refresh)
	Staff.answer.connect(_on_answer)


func open() -> void:
	visible = true
	_msg.text = ""
	_tab = "crew" if mode == "crew" else _tab
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Staff.request_sync()
	_refresh()


func close_window() -> void:
	visible = false
	if player and not player.auto_walk:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func is_open() -> bool:
	return visible


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("release_mouse") or event.is_action_pressed("interact") or event.is_action_pressed("phone"):
		close_window()
		get_viewport().set_input_as_handled()


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


func _on_answer(ok: bool, text: String) -> void:
	if not visible:
		if player and player.ui:
			player.ui.toast(text)
		return
	_msg.text = text
	_msg.add_theme_color_override("font_color", GOOD if ok else BAD)


func _refresh() -> void:
	if not visible:
		return
	for c: Node in _list.get_children():
		c.queue_free()
	_tabs.visible = mode == "crew"
	if mode == "dealer":
		_fill_dealer()
	elif _tab == "hire":
		_fill_hire()
	elif _tab == "legal":
		_fill_legal()
	else:
		_fill_crew()


func _row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_list.add_child(row)
	return row


func _fill_crew() -> void:
	_title.text = "Your crew"
	if Staff.members.is_empty():
		_list.add_child(_label("Nobody works for you yet. Benny can find people (Hire tab). Growers, cooks and packagers work in a property you own (one per bed or storage locker there); dealers sell your bags in a district.", 15, Color(0.7, 0.7, 0.75)))
	for uid: String in Staff.members:
		var rec: Dictionary = Staff.members[uid]
		var row := _row()
		var info := _label("%s  -  %s\n%s" % [rec["name"], Staff.role_name(str(rec["role"])), Staff.describe(rec)], 15)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var fire := _button("Fire")
		fire.pressed.connect(func() -> void:
			_msg.text = "..."
			Staff.request("fire", uid))
		row.add_child(fire)
	_list.add_child(_label("Dealers: %d of %d at your rank." % [Staff.dealers().size(), Staff.max_dealers()], 14, Color(0.7, 0.7, 0.75)))


## Lawyer (rank 4) + the corrupt cop (rank 5): Legal autoload, requests through Staff.request.
func _fill_legal() -> void:
	_title.text = "Lawyer + corrupt cop"
	var gates: bool = Progression.gates_on()
	var row := _row()
	var text := _label("%s  -  €%d a day on retainer
Arrested? He gets %d%% of the fine and half of the confiscated goods back.%s" % [
			Legal.LAWYER, Legal.LAWYER_FEE, roundi(Legal.FINE_BACK * 100.0),
			"
Working for your crew." if Legal.lawyer != "" else ""], 15)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	if gates and Progression.rank() < Legal.LAWYER_RANK:
		row.add_child(_label("Rank %d" % Legal.LAWYER_RANK, 15, BAD))
	else:
		var b := _button("Let him go" if Legal.lawyer != "" else "Hire (€%d)" % Legal.LAWYER_FEE)
		b.pressed.connect(func() -> void:
			_msg.text = "..."
			Staff.request("lawyer_fire" if Legal.lawyer != "" else "lawyer_hire"))
		row.add_child(b)
	var stars: int = player.wanted_stars if player else 0
	var row2 := _row()
	var t2 := _label("%s  -  makes your police file disappear: €%d per wanted star.
You have %d star%s now." % [
			Legal.COP, Legal.BRIBE_PER_STAR, stars, "" if stars == 1 else "s"], 15)
	t2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row2.add_child(t2)
	if gates and Progression.rank() < Legal.BRIBE_RANK:
		row2.add_child(_label("Rank %d" % Legal.BRIBE_RANK, 15, BAD))
	else:
		var b2 := _button("Bribe (€%d)" % Legal.bribe_price(stars))
		b2.disabled = stars <= 0
		b2.pressed.connect(func() -> void:
			_msg.text = "..."
			Staff.request("bribe"))
		row2.add_child(b2)


func _fill_hire() -> void:
	_title.text = "Benny (fixer) - people looking for work"
	if Staff.candidates.is_empty():
		_list.add_child(_label("\"Give me a bit, I'll find someone.\"", 15, Color(0.7, 0.7, 0.75)))
	var props: Array = Staff.crew_properties()
	for i: int in Staff.candidates.size():
		var c: Dictionary = Staff.candidates[i]
		var role: String = str(c["role"])
		var info: Dictionary = Staff.role_info(role)
		var row := _row()
		var pay: String = "%d%% cut" % roundi(float(c.get("commission", 0.0)) * 100.0) if role == "dealer" else "€%d/day" % int(c["wage"])
		var text := _label("%s  -  %s  (%s)\n%s" % [c["name"], Staff.role_name(role), pay, info.get("about", "")], 15)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.custom_minimum_size = Vector2(380, 0)
		row.add_child(text)
		var lock: String = Staff.role_lock(role)
		if lock != "":
			var l := _label(lock, 14, BAD)
			l.custom_minimum_size = Vector2(200, 0)
			row.add_child(l)
			continue
		var pick := OptionButton.new()
		pick.focus_mode = Control.FOCUS_NONE
		pick.custom_minimum_size = Vector2(190, 0)
		var ids: Array = []
		if role == "dealer":
			for d: String in Staff.config.districts:
				pick.add_item(Staff.district_name(d))
				ids.append(d)
		else:
			for p: Array in props:
				pick.add_item(p[1])
				ids.append(p[0])
		row.add_child(pick)
		var hire := _button("Hire")
		hire.disabled = ids.is_empty()
		hire.pressed.connect(func() -> void:
			if pick.selected < 0:
				return
			_msg.text = "..."
			Staff.request("hire", i, ids[pick.selected]))
		row.add_child(hire)


func _fill_dealer() -> void:
	var rec: Dictionary = Staff.members.get(dealer_uid, {})
	if rec.is_empty():
		_title.text = "Dealer"
		_list.add_child(_label("They're gone.", 16, BAD))
		return
	_title.text = "%s - your dealer in %s" % [rec["name"], Staff.district_name(str(rec["district"]))]
	_list.add_child(_label("Stock: %d / %d bags%s      Waiting for you: €%d      Their cut: %d%%      Loyalty: %d      Sold so far: %d" % [
			int(rec["stock"]), Staff.config.dealer_capacity, Staff.meth_text(rec), int(rec["cash"]), roundi(float(rec["commission"]) * 100.0),
			roundi(float(rec["loyalty"])), int(rec.get("sold", 0))], 16))
	_list.add_child(_label("Collect often: a dealer sitting on a lot of your money gets ideas.", 14, Color(0.7, 0.7, 0.75)))
	var row := _row()
	var give := _button("Give all my bags")
	give.pressed.connect(func() -> void:
		_msg.text = "..."
		Staff.request("give", dealer_uid))
	row.add_child(give)
	var collect := _button("Collect €%d" % int(rec["cash"]))
	collect.pressed.connect(func() -> void:
		_msg.text = "..."
		Staff.request("collect", dealer_uid))
	row.add_child(collect)
