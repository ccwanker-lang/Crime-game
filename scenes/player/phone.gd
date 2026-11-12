class_name Phone
extends PanelContainer
## The in-game phone (Tab), owner only. Built in code. Apps:
##   Hush  - Telegram-style chat: customers text where they are; answer "On my way"
##           (they wait for you) or "Not now". Contacts are per player, kept here.
##   Map   - top-down town map with players, customers and the shops.
##   Shop  - webshop for LEGAL items; orders arrive in the delivery box in the
##           Starter Room (host: Player.webshop_buy -> DeliveryBox.order).
## Messages come from the host through Player.phone_message().

const APP_NAME: String = "Hush"
const SIZE := Vector2(340, 600)
const ACCENT := Color(0.35, 0.75, 1.0)

var player: Player
## contact -> Array of {"me": bool, "text": String, "deal": String, "answered": bool}
var threads: Dictionary = {}
var unread: Dictionary = {}
var _order: Array[String] = []  # contacts, most recent first

var _title: Label
var _clock: Label
var _back: Button
var _content: VBoxContainer
var _screen: String = "home"
var _contact: String = ""
var _map: PhoneMap


func _ready() -> void:
	visible = false
	custom_minimum_size = SIZE
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_left = -SIZE.x - 24
	offset_top = -SIZE.y - 24
	offset_right = -24
	offset_bottom = -24
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.09, 0.97)
	style.border_color = Color(0.25, 0.27, 0.3)
	style.set_border_width_all(6)
	style.set_corner_radius_all(26)
	style.set_content_margin_all(16)
	add_theme_stylebox_override("panel", style)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	add_child(outer)
	var bar := HBoxContainer.new()
	outer.add_child(bar)
	_back = Button.new()
	_back.text = "<"
	_back.focus_mode = Control.FOCUS_NONE
	_back.custom_minimum_size = Vector2(32, 0)
	_back.pressed.connect(_go_back)
	bar.add_child(_back)
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_font_size_override("font_size", 20)
	bar.add_child(_title)
	_clock = Label.new()
	_clock.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	bar.add_child(_clock)
	outer.add_child(HSeparator.new())
	_content = VBoxContainer.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	outer.add_child(_content)
	var hint := Label.new()
	hint.text = "Tab / Esc: put the phone away"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	outer.add_child(hint)


func is_open() -> bool:
	return visible


func open() -> void:
	visible = true
	_show(_screen if _screen != "" else "home")


func close() -> void:
	visible = false


func total_unread() -> int:
	var n: int = 0
	for c: String in unread:
		n += int(unread[c])
	return n


## A message arrives (from the host). `deal` = customer node name ("" = none).
func add_message(contact: String, text: String, deal: String, from_me: bool = false) -> void:
	var list: Array = threads.get_or_add(contact, [])
	list.append({"me": from_me, "text": text, "deal": deal, "answered": false})
	_order.erase(contact)
	_order.push_front(contact)
	if not from_me and not (visible and _screen == "thread" and _contact == contact):
		unread[contact] = int(unread.get(contact, 0)) + 1
	if visible:
		_show(_screen)


func _process(_delta: float) -> void:
	if not visible:
		return
	var dn := get_tree().get_first_node_in_group(&"day_night") as DayNight
	_clock.text = dn.clock_text() if dn else ""


func _go_back() -> void:
	_show("list" if _screen == "thread" else "home")


func _clear() -> void:
	for c: Node in _content.get_children():
		c.queue_free()
	_map = null


func _show(screen: String) -> void:
	_screen = screen
	_clear()
	_back.visible = screen != "home"
	match screen:
		"home":
			_title.text = "Phone"
			_home()
		"list":
			_title.text = APP_NAME
			_list()
		"thread":
			_title.text = _contact
			_thread()
		"map":
			_title.text = "Map"
			_map = PhoneMap.new()
			_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
			_content.add_child(_map)
		"shop":
			_title.text = "QuickShip"
			_shop()


func _app_button(text: String, color: Color, screen: String) -> void:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 64)
	b.add_theme_font_size_override("font_size", 20)
	var st := StyleBoxFlat.new()
	st.bg_color = color.darkened(0.55)
	st.border_color = color
	st.set_border_width_all(2)
	st.set_corner_radius_all(14)
	b.add_theme_stylebox_override("normal", st)
	var hover := st.duplicate() as StyleBoxFlat
	hover.bg_color = color.darkened(0.35)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.pressed.connect(_show.bind(screen))
	_content.add_child(b)


func _home() -> void:
	var n: int = total_unread()
	_app_button("%s%s" % [APP_NAME, "  (%d new)" % n if n > 0 else ""], ACCENT, "list")
	_app_button("Map", Color(0.45, 0.85, 0.45), "map")
	_app_button("QuickShip (legal shop)", Color(1.0, 0.7, 0.3), "shop")


func _list() -> void:
	if _order.is_empty():
		_content.add_child(_label("No messages yet. Customers text you when they want something.", Color(0.6, 0.6, 0.65)))
		return
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	for contact: String in _order:
		var list: Array = threads[contact]
		var last: Dictionary = list[list.size() - 1]
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		var n: int = int(unread.get(contact, 0))
		b.text = "%s%s\n  %s" % [contact, "  (%d)" % n if n > 0 else "", ("You: " if last["me"] else "") + str(last["text"])]
		b.custom_minimum_size = Vector2(0, 52)
		b.pressed.connect(func() -> void:
			_contact = contact
			_show("thread"))
		box.add_child(b)


func _thread() -> void:
	unread.erase(_contact)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	scroll.add_child(box)
	var list: Array = threads.get(_contact, [])
	for i: int in list.size():
		var m: Dictionary = list[i]
		var bubble := PanelContainer.new()
		var st := StyleBoxFlat.new()
		st.bg_color = Color(0.16, 0.36, 0.55) if m["me"] else Color(0.17, 0.18, 0.21)
		st.set_corner_radius_all(10)
		st.set_content_margin_all(8)
		bubble.add_theme_stylebox_override("panel", st)
		bubble.size_flags_horizontal = Control.SIZE_SHRINK_END if m["me"] else Control.SIZE_SHRINK_BEGIN
		var l := _label(str(m["text"]), Color(0.92, 0.92, 0.95))
		l.custom_minimum_size = Vector2(220, 0)
		bubble.add_child(l)
		box.add_child(bubble)
		# Answer buttons under the newest open deal.
		if str(m["deal"]) != "" and not m["answered"] and i == list.size() - 1:
			var row := HBoxContainer.new()
			for choice: Array in [["On my way", true], ["Not now", false]]:
				var b := Button.new()
				b.text = choice[0]
				b.focus_mode = Control.FOCUS_NONE
				b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				b.pressed.connect(_answer.bind(i, bool(choice[1])))
				row.add_child(b)
			box.add_child(row)
	await get_tree().process_frame
	if is_instance_valid(scroll):
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)


func _answer(index: int, accept: bool) -> void:
	var list: Array = threads.get(_contact, [])
	var m: Dictionary = list[index]
	m["answered"] = true
	add_message(_contact, "On my way." if accept else "Not now.", "", true)
	if player:
		player.phone_reply(str(m["deal"]), accept)


func _shop() -> void:
	_content.add_child(_label("Legal stuff, delivered to the box in your Starter Room in about an hour.", Color(0.7, 0.7, 0.75)))
	var ids: Array = ItemDB.get_all_ids()
	ids.sort()
	for id: StringName in ids:
		var item: ItemData = ItemDB.get_item(id)
		if not item.is_legal or item.base_price <= 0:
			continue
		var row := HBoxContainer.new()
		var name_l := _label("%s  €%d" % [item.display_name, item.base_price], Color(0.92, 0.92, 0.95))
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_l.tooltip_text = item.description
		name_l.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(name_l)
		for n: int in ([1, 5] if item.max_stack >= 5 else [1]):
			var b := Button.new()
			b.text = "Buy %d" % n
			b.focus_mode = Control.FOCUS_NONE
			b.pressed.connect(func() -> void:
				if player:
					player.webshop_buy(item.id, n))
			row.add_child(b)
		_content.add_child(row)


func _label(text: String, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", color)
	return l
