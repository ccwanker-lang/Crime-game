class_name PlayerHUD
extends CanvasLayer
## On-screen info of the local player: health, ammo, cash, inventory bar,
## hitmarker, damage flash, the death screen and the shop window. Only exists
## on the owning peer. The inventory bar and shop window are built in code.

signal close_requested

@onready var health_bar: ProgressBar = %HealthBar
@onready var health_label: Label = %HealthLabel
@onready var ammo_label: Label = %AmmoLabel
@onready var weapon_label: Label = %WeaponLabel
@onready var cash_label: Label = %CashLabel
@onready var death_panel: PanelContainer = %DeathPanel
@onready var death_label: Label = %DeathLabel
@onready var damage_flash: ColorRect = %DamageFlash
@onready var hitmarker: Control = %Hitmarker
@onready var clock_label: Label = %ClockLabel

var _hit_time: float = 0.0
var _hit_color: Color = Color.WHITE
var _respawn_at: float = 0.0
var _death_text: String = ""
var _scope: Control
var _slots: Array[PanelContainer] = []
var _slot_styles: Array[StyleBoxFlat] = []
var _slot_icons: Array[TextureRect] = []
var _slot_names: Array[Label] = []
var _slot_counts: Array[Label] = []
var _hotbar_selected: int = -2
var _toast: Label
var _toast_time: float = 0.0
var _last_cash: int = -1
var _last_clean: int = -1
var _shop_panel: Control
var _shop: Shopkeeper
var _shop_title: Label
var _shop_greeting: Label
var _shop_list: VBoxContainer
var _shop_cash: Label
var _shop_msg: Label
var phone: Phone
## Point 27: HUD in the game's style (theme assets/ui/game_theme.tres, HudIcon icons).
const ACCENT := Color(0.96, 0.77, 0.27)
const CASH_COLOR := Color(0.62, 0.93, 0.5)
const CLEAN_COLOR := Color(0.56, 0.8, 1.0)
const HELP: Array = [
	["WASD / arrows", "Move"], ["Shift", "Sprint"], ["Space", "Jump"], ["Ctrl / C", "Crouch"],
	["Mouse", "Look"], ["Left mouse", "Shoot / place (build mode)"], ["Right mouse", "Aim / sniper scope"],
	["R", "Reload / rotate (build mode)"], ["B", "Build mode: place, move, pick up"], ["1-8, mouse wheel", "Hotbar slot (a weapon there is drawn)"],
	["H", "Holster"], ["Q", "Previous weapon"], ["V", "First / third person"],
	["E", "Use, talk, sell"], ["Hold E", "Pick up (build mode)"], ["G / Shift+G", "Drop the stack / one"],
	["Tab", "Phone"], ["Esc", "Free the mouse"], ["F9", "Test scenarios"],
	["F4 / F6 / F7", "Debug: hurt yourself / +€1000 / fast time (hold)"], ["F1", "This help"],
	["F10 (host)", "Admin: noclip fly (Space up, Ctrl down, Shift fast)"], ["F11 (host)", "Admin: god mode + endless ammo"],
	["F12 (host)", "Admin: clear wanted stars, police back off"],
]
var _clean_label: Label
## Point 28: wanted stars under the money panel (blink while the police search for you).
var _wanted_row: HBoxContainer
var _wanted_stars: Array[HudIcon] = []
var _wanted_seen: bool = true
var _help: Control


func _ready() -> void:
	hitmarker.draw.connect(_draw_hitmarker)
	death_panel.visible = false
	damage_flash.color.a = 0.0
	_build_inventory_bar()
	_restyle_hud()
	_build_help_panel()
	_build_shop_panel()
	add_child(RankPanel.new())  # ranks: rank + XP, top left
	phone = Phone.new()
	phone.name = "Phone"
	add_child(phone)
	_scope = Control.new()
	_scope.name = "Scope"
	_scope.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scope.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scope.visible = false
	_scope.draw.connect(_draw_scope)
	add_child(_scope)
	move_child(_scope, 1)  # under the HUD labels


func set_health(hp: int, max_hp: int) -> void:
	health_bar.max_value = max_hp
	health_bar.value = hp
	health_label.text = "%d" % hp
	var low: bool = hp <= max_hp * 0.3
	health_label.add_theme_color_override("font_color", Color(1, 0.35, 0.3) if low else Color.WHITE)


func set_ammo(weapon_name: String, mag: int, reserve: int, drawn: bool, reloading: bool) -> void:
	weapon_label.text = weapon_name if drawn else "Hands"
	if not drawn:
		ammo_label.text = ""
	elif reloading:
		ammo_label.text = "Reloading..."
	else:
		ammo_label.text = "%d / %d" % [mag, reserve]
	ammo_label.add_theme_color_override("font_color", Color(1, 0.4, 0.3) if drawn and mag == 0 else Color.WHITE)
	if ammo_label.get_parent() is HBoxContainer:
		ammo_label.get_parent().visible = drawn  # (the bullet icon row, point 27)


## Sniper scope overlay (black outside the lens, reticle).
func set_scope(on: bool) -> void:
	if _scope.visible != on:
		_scope.visible = on
		var cross := get_node_or_null("Crosshair") as CanvasItem
		if cross:
			cross.visible = not on


func _draw_scope() -> void:
	var size: Vector2 = _scope.size
	var c: Vector2 = size / 2.0
	var r: float = size.y * 0.46
	var black := Color(0, 0, 0, 1)
	# Lens ring: polygon between the circle and the screen edges.
	var outer: float = size.length()
	var pts := PackedVector2Array()
	var steps: int = 64
	for i: int in steps + 1:
		var a: float = TAU * i / steps
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	for i: int in range(steps, -1, -1):
		var a: float = TAU * i / steps
		pts.append(c + Vector2(cos(a), sin(a)) * outer)
	_scope.draw_colored_polygon(pts, black)
	_scope.draw_arc(c, r, 0.0, TAU, 96, Color(0.05, 0.05, 0.05), 6.0, true)
	# Reticle: thick outer posts, fine centre cross and mil dots.
	var line := Color(0, 0, 0, 0.9)
	_scope.draw_line(c - Vector2(r, 0), c - Vector2(r * 0.12, 0), line, 3.0)
	_scope.draw_line(c + Vector2(r * 0.12, 0), c + Vector2(r, 0), line, 3.0)
	_scope.draw_line(c + Vector2(0, r * 0.12), c + Vector2(0, r), line, 3.0)
	_scope.draw_line(c - Vector2(r * 0.12, 0), c + Vector2(r * 0.12, 0), line, 1.0)
	_scope.draw_line(c - Vector2(0, r * 0.12), c + Vector2(0, r * 0.12), line, 1.0)
	for k: int in range(1, 4):
		_scope.draw_circle(c + Vector2(0, r * 0.03 * k), 1.6, line)
		_scope.draw_circle(c + Vector2(r * 0.03 * k, 0), 1.6, line)
		_scope.draw_circle(c - Vector2(r * 0.03 * k, 0), 1.6, line)


## Point 9: `cash` = dirty cash in your pocket, `clean` = laundered money (bank).
func set_cash(cash: int, clean: int = 0) -> void:
	cash_label.text = "€ %d%s" % [cash, " (dev)" if GameState.infinite_cash else ""]
	_clean_label.text = "€ %d" % clean
	if _last_cash >= 0 and cash != _last_cash:
		toast("%s€%d" % ["+" if cash > _last_cash else "-", absi(cash - _last_cash)])
	if _last_clean >= 0 and clean != _last_clean:
		toast("%s€%d clean" % ["+" if clean > _last_clean else "-", absi(clean - _last_clean)])
	_last_cash = cash
	_last_clean = clean
	if _shop_cash:
		_shop_cash.text = _money_text(cash, clean)


static func _money_text(cash: int, clean: int) -> String:
	return "Your money: €%d cash + €%d clean%s" % [cash, clean, "  - buying is free for now" if GameState.infinite_cash else ""]


# --- Inventory bar ---------------------------------------------------------------

func _build_inventory_bar() -> void:
	var bar := HBoxContainer.new()
	bar.name = "InventoryBar"
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_constant_override("separation", 6)
	bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.offset_top = -120.0
	bar.offset_bottom = -48.0
	add_child(bar)
	for i: int in GameState.INVENTORY_SLOTS:
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(80, 74)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.08, 0.09, 0.13, 0.78)
		style.border_color = Color(1, 1, 1, 0.22)
		style.set_border_width_all(2)
		style.set_corner_radius_all(9)
		style.set_content_margin_all(5)
		slot.add_theme_stylebox_override("panel", style)
		_slot_styles.append(style)
		var icon := TextureRect.new()  # render of the item's 3D model (assets/icons/)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)
		_slot_icons.append(icon)
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_constant_override("outline_size", 4)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		slot.add_child(label)
		_slot_names.append(label)
		var count := Label.new()
		count.size_flags_horizontal = Control.SIZE_SHRINK_END
		count.size_flags_vertical = Control.SIZE_SHRINK_BEGIN  # top right (the name runs along the bottom)
		count.add_theme_font_size_override("font_size", 15)
		count.add_theme_constant_override("outline_size", 5)
		count.add_theme_color_override("font_outline_color", Color.BLACK)
		slot.add_child(count)
		_slot_counts.append(count)
		var key := Label.new()  # the number key of this slot
		key.text = str(i + 1)
		key.add_theme_font_size_override("font_size", 13)
		key.modulate = Color(1, 1, 1, 0.6)
		key.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		key.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(key)
		bar.add_child(slot)
		_slots.append(slot)
	_toast = Label.new()
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.offset_top = -150.0
	_toast.offset_bottom = -118.0
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 21)
	_toast.add_theme_constant_override("outline_size", 6)
	_toast.add_theme_color_override("font_outline_color", Color.BLACK)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast)


## Shows the carried stacks ([{ "id", "count" }]) in the bar.
func set_inventory(items: Array) -> void:
	for i: int in _slots.size():
		var name_label: Label = _slot_names[i]
		var count_label: Label = _slot_counts[i]
		if i < items.size():
			var it: Dictionary = items[i]
			var data: ItemData = ItemDB.get_item(StringName(str(it.get("id", ""))))
			var tex: Texture2D = data.get_icon() if data else null
			_slot_icons[i].texture = tex
			name_label.text = data.display_name if data else str(it.get("id"))
			# With an icon the name sits small along the bottom edge, else centred.
			name_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM if tex else VERTICAL_ALIGNMENT_CENTER
			name_label.size_flags_vertical = Control.SIZE_SHRINK_END if tex else Control.SIZE_FILL
			name_label.autowrap_mode = TextServer.AUTOWRAP_OFF if tex else TextServer.AUTOWRAP_WORD_SMART
			name_label.clip_text = tex != null
			name_label.add_theme_font_size_override("font_size", 9 if tex else 12)
			name_label.modulate.a = 0.8 if tex else 1.0
			var n: int = int(it.get("count", 1))
			count_label.text = "x%d" % n if n > 1 else ""
		else:
			_slot_icons[i].texture = null
			name_label.text = ""
			count_label.text = ""


## Highlights hotbar slot `slot` (weapon in hand / last picked), -1 = none.
func set_hotbar_selected(slot: int) -> void:
	if slot == _hotbar_selected:
		return
	_hotbar_selected = slot
	for i: int in _slot_styles.size():
		var st: StyleBoxFlat = _slot_styles[i]
		var on: bool = i == slot
		st.border_color = ACCENT if on else Color(1, 1, 1, 0.22)
		st.set_border_width_all(3 if on else 2)
		st.bg_color = Color(0.27, 0.21, 0.08, 0.85) if on else Color(0.08, 0.09, 0.13, 0.78)


## Short message above the inventory bar (purchases, cash changes).
func toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	_toast_time = 2.5


# --- Shop window -----------------------------------------------------------------

func _build_shop_panel() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP  # clicks don't reach the game
	dim.visible = false
	add_child(dim)
	_shop_panel = dim
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(540, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.09, 0.1, 0.94)
	style.border_color = Color(0.75, 0.62, 0.35, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	_shop_title = Label.new()
	_shop_title.add_theme_font_size_override("font_size", 24)
	_shop_title.add_theme_color_override("font_color", Color(0.95, 0.8, 0.5))
	box.add_child(_shop_title)
	_shop_greeting = Label.new()
	_shop_greeting.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_shop_greeting.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	box.add_child(_shop_greeting)
	box.add_child(HSeparator.new())
	_shop_list = VBoxContainer.new()
	_shop_list.add_theme_constant_override("separation", 6)
	box.add_child(_shop_list)
	box.add_child(HSeparator.new())
	_shop_msg = Label.new()
	_shop_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_shop_msg.custom_minimum_size = Vector2(0, 24)
	box.add_child(_shop_msg)
	var bottom := HBoxContainer.new()
	box.add_child(bottom)
	_shop_cash = Label.new()
	_shop_cash.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shop_cash.add_theme_color_override("font_color", Color(0.75, 1, 0.7))
	_shop_cash.add_theme_font_size_override("font_size", 18)
	bottom.add_child(_shop_cash)
	var close := _button("Leave  [E / Esc]")
	close.pressed.connect(func() -> void: close_requested.emit())
	bottom.add_child(close)


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE  # Space/Enter must not buy by accident
	return b


func is_shop_open() -> bool:
	return _shop_panel.visible


func open_shop(shop: Shopkeeper, cash: int, clean: int = 0) -> void:
	_shop = shop
	_shop_title.text = "%s  -  %s" % [shop.npc_name, shop.shop_name]
	_shop_greeting.text = "\"%s\"" % shop.greeting
	_shop_msg.text = ""
	_shop_cash.text = _money_text(cash, clean)
	for c: Node in _shop_list.get_children():
		c.queue_free()
	if shop is EstateAgent:
		_fill_estate(shop as EstateAgent)
	for id: StringName in shop.stock:
		var item: ItemData = ItemDB.get_item(id)
		if item == null:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var info := Label.new()
		info.text = item.display_name + (" (x%d)" % item.pack_size if item.pack_size > 1 else "")
		info.tooltip_text = item.description
		info.mouse_filter = Control.MOUSE_FILTER_PASS
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_font_size_override("font_size", 18)
		row.add_child(info)
		var price := Label.new()
		price.text = "€%d" % shop.price_of(id)
		price.custom_minimum_size = Vector2(60, 0)
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		price.add_theme_font_size_override("font_size", 18)
		row.add_child(price)
		var counts: Array = [1] if item.max_stack <= 1 else ([1, 5] if item.max_stack >= 5 * item.pack_size else [1])
		if Progression.item_lock(id) != "":  # ranks: locked = no Buy buttons
			row.add_child(_rank_lock(Progression.item_rank(id)))
			counts = []
		for n: int in counts:
			var b := _button("Buy %d" % n)
			b.custom_minimum_size = Vector2(76, 0)
			b.pressed.connect(_on_buy_pressed.bind(id, n))
			row.add_child(b)
		_shop_list.add_child(row)
	if not shop.buy_result.is_connected(_on_buy_result):
		shop.buy_result.connect(_on_buy_result)
	_shop_panel.visible = true


func close_shop() -> void:
	if _shop and _shop.buy_result.is_connected(_on_buy_result):
		_shop.buy_result.disconnect(_on_buy_result)
	_shop = null
	_shop_panel.visible = false


func _on_buy_pressed(id: StringName, count: int) -> void:
	if _shop:
		_shop_msg.text = "..."
		_shop.request_buy(id, count)


func _on_buy_result(ok: bool, message: String) -> void:
	_shop_msg.text = message
	_shop_msg.add_theme_color_override("font_color", Color(0.7, 1, 0.6) if ok else Color(1, 0.5, 0.4))
	if ok and _shop is EstateAgent:
		for c: Node in _shop_list.get_children():
			c.queue_free()
		_fill_estate.call_deferred(_shop as EstateAgent)  # "Owned" now


## Point 8: the agent's listings: name + description, price, Buy / Owned.
func _fill_estate(agent: EstateAgent) -> void:
	# Point 35: a map of the town with every property for sale (orange) and yours (green);
	# "Where?" centres it on one listing.
	var map := PhoneMap.new()
	map.show_for_sale = true
	_shop_list.add_child(map)
	map.custom_minimum_size = Vector2(0, 230)
	var listings: Array[Property] = agent.listings()
	if not listings.is_empty():
		map.focus = listings[0]
	for p: Property in listings:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var info := Label.new()
		info.text = "%s\n%s" % [p.display_name, p.description]
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.custom_minimum_size = Vector2(300, 0)
		info.add_theme_font_size_override("font_size", 16)
		row.add_child(info)
		var where := _button("Where?")
		where.custom_minimum_size = Vector2(70, 0)
		where.pressed.connect(func() -> void: map.focus = p)
		row.add_child(where)
		var price := Label.new()
		price.text = "€%s" % Property.money(p.price)
		price.custom_minimum_size = Vector2(80, 0)
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		price.add_theme_font_size_override("font_size", 18)
		row.add_child(price)
		if p.is_crew_owned():
			var owned := Label.new()
			owned.text = "Owned"
			owned.custom_minimum_size = Vector2(76, 0)
			owned.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			owned.add_theme_color_override("font_color", Color(0.6, 1, 0.6))
			row.add_child(owned)
		elif Progression.property_lock(p.property_id) != "":
			row.add_child(_rank_lock(Progression.property_rank(p.property_id)))
		else:
			var b := _button("Buy")
			b.custom_minimum_size = Vector2(76, 0)
			b.pressed.connect(func() -> void:
				_shop_msg.text = "..."
				agent.request_buy_property(p.property_id))
			row.add_child(b)
		_shop_list.add_child(row)


## Ranks: "Rank 2" in place of a Buy button.
func _rank_lock(need: int) -> Label:
	var l := Label.new()
	l.text = "Rank %d" % need
	l.tooltip_text = "Needs rank %d (%s)" % [need, Progression.rank_name(need)]
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	l.custom_minimum_size = Vector2(76, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", Color(1, 0.6, 0.45))
	return l


func flash_damage(amount: int) -> void:
	damage_flash.color.a = clampf(0.15 + amount / 100.0, 0.2, 0.55)


func show_hitmarker(headshot: bool, killed: bool) -> void:
	_hit_time = 0.25 if killed else 0.15
	_hit_color = Color(1, 0.25, 0.2) if killed else (Color(1, 0.85, 0.3) if headshot else Color.WHITE)
	hitmarker.queue_redraw()


func show_death(dropped_text: String, respawn_seconds: float) -> void:
	_death_text = dropped_text
	_respawn_at = Time.get_ticks_msec() / 1000.0 + respawn_seconds
	death_panel.visible = true


func hide_death() -> void:
	death_panel.visible = false


# --- Style + help (point 27) ------------------------------------------------------

## Icons in front of health/ammo, money and clock in one panel top right, the long key
## bar replaced by "F1 help".
func _restyle_hud() -> void:
	var old: Node = get_node_or_null("HelpLabel")
	if old:
		old.queue_free()
	var hint := Label.new()
	hint.text = "F1  help"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_constant_override("outline_size", 4)
	hint.modulate = Color(1, 1, 1, 0.7)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hint.offset_left = 18.0
	hint.offset_top = -34.0
	hint.offset_bottom = -12.0
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)
	# Health: a heart, the bar in the theme's colours.
	var hb := health_bar.get_parent() as HBoxContainer
	var heart := HudIcon.make("heart", Color(0.95, 0.36, 0.33), 28)
	hb.add_child(heart)
	hb.move_child(heart, 0)
	hb.add_theme_constant_override("separation", 8)
	health_bar.modulate = Color.WHITE
	health_bar.custom_minimum_size = Vector2(200, 16)
	health_label.add_theme_font_size_override("font_size", 28)
	# Ammo: a bullet in front of the count.
	var ab := ammo_label.get_parent() as VBoxContainer
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 6)
	ab.add_child(row)
	ab.remove_child(ammo_label)
	row.add_child(HudIcon.make("bullet", ACCENT, 24))
	row.add_child(ammo_label)
	ammo_label.add_theme_font_size_override("font_size", 28)
	weapon_label.add_theme_font_size_override("font_size", 16)
	# Money (dirty / clean) and the clock in one panel, top right.
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = -250.0
	panel.offset_right = -12.0
	panel.offset_top = 12.0
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	_clean_label = Label.new()
	for r: Array in [["cash", CASH_COLOR, cash_label, "dirty", 24], ["bank", CLEAN_COLOR, _clean_label, "clean", 20],
			["clock", Color(0.93, 0.93, 0.95), clock_label, "", 20]]:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		box.add_child(line)
		line.add_child(HudIcon.make(r[0], r[1], 22))
		var lab: Label = r[2]
		if lab.get_parent():
			lab.get_parent().remove_child(lab)
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lab.add_theme_font_size_override("font_size", r[4])
		lab.add_theme_color_override("font_color", r[1])
		lab.add_theme_constant_override("outline_size", 0)
		line.add_child(lab)
		var cap := Label.new()
		cap.text = r[3]
		cap.custom_minimum_size = Vector2(40, 0)
		cap.add_theme_font_size_override("font_size", 13)
		cap.modulate = Color(1, 1, 1, 0.55)
		line.add_child(cap)
	_wanted_row = HBoxContainer.new()
	_wanted_row.alignment = BoxContainer.ALIGNMENT_END
	_wanted_row.add_theme_constant_override("separation", 3)
	_wanted_row.visible = false
	box.add_child(_wanted_row)
	for i: int in 5:
		var star := HudIcon.make("star", ACCENT, 26)
		_wanted_row.add_child(star)
		_wanted_stars.append(star)


## Point 28: show `stars` (0 = hidden); `seen` = the police see you (steady), else blinking.
func set_wanted(stars: int, seen: bool) -> void:
	if _wanted_row == null:
		return
	_wanted_row.visible = stars > 0
	_wanted_seen = seen
	for i: int in _wanted_stars.size():
		_wanted_stars[i].color = ACCENT if i < stars else Color(1, 1, 1, 0.18)
	_wanted_row.modulate.a = 1.0


func _build_help_panel() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.visible = false
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := Label.new()
	title.text = "Controls"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", ACCENT)
	box.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	for e: Array in HELP:
		var k := Label.new()
		k.text = e[0]
		k.add_theme_color_override("font_color", ACCENT)
		k.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(k)
		var v := Label.new()
		v.text = e[1]
		grid.add_child(v)
	var foot := Label.new()
	foot.text = "F1 closes"
	foot.modulate = Color(1, 1, 1, 0.55)
	foot.add_theme_font_size_override("font_size", 14)
	box.add_child(foot)
	_help = center


var _sleep_panel: ColorRect
var _sleep_text: Label


## Point 37: a dark screen while you sleep, with how many are in bed.
func set_sleep(on: bool, text: String) -> void:
	if _sleep_panel == null:
		_sleep_panel = ColorRect.new()
		_sleep_panel.color = Color(0.01, 0.01, 0.03, 0.88)
		_sleep_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_sleep_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_sleep_panel)
		_sleep_text = Label.new()
		_sleep_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_sleep_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_sleep_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_sleep_text.add_theme_font_size_override("font_size", 26)
		_sleep_text.add_theme_color_override("font_color", Color(0.75, 0.8, 1.0))
		_sleep_panel.add_child(_sleep_text)
	_sleep_panel.visible = on
	_sleep_text.text = "Zzz...

" + text if on else ""


var _build_label: Label


## Point 36: "BUILD MODE" above the hotbar while it is on.
func set_build_mode(on: bool) -> void:
	if _build_label == null:
		_build_label = Label.new()
		_build_label.text = "BUILD MODE   LMB place  ·  R / wheel rotate  ·  hold E pick up  ·  B leave"
		_build_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		_build_label.offset_top = -132
		_build_label.offset_bottom = -108
		_build_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_build_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_build_label.add_theme_font_size_override("font_size", 16)
		_build_label.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
		_build_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		_build_label.add_theme_constant_override("outline_size", 5)
		_build_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_build_label)
	_build_label.visible = on


var _admin_label: Label


## Admin mode (host debug): a small red label top centre while noclip / god mode is on ("" = hide).
func set_admin(text: String) -> void:
	if _admin_label == null:
		_admin_label = Label.new()
		_admin_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		_admin_label.offset_top = 8
		_admin_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_admin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_admin_label.add_theme_font_size_override("font_size", 16)
		_admin_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3))
		_admin_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		_admin_label.add_theme_constant_override("outline_size", 5)
		_admin_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_admin_label)
	_admin_label.text = text
	_admin_label.visible = text != ""


func toggle_help() -> void:
	_help.visible = not _help.visible


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.physical_keycode == KEY_F1:
		toggle_help()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	var dn := get_tree().get_first_node_in_group("day_night") as DayNight
	if dn:
		clock_label.text = dn.clock_text() + (" >>" if dn.fast_forward else "")
	damage_flash.color.a = move_toward(damage_flash.color.a, 0.0, delta * 0.8)
	if _wanted_row and _wanted_row.visible:
		_wanted_row.modulate.a = 1.0 if _wanted_seen else 0.45 + 0.55 * absf(sin(Time.get_ticks_msec() / 1000.0 * 3.0))
	if _toast_time > 0.0:
		_toast_time -= delta
		_toast.modulate.a = clampf(_toast_time / 0.6, 0.0, 1.0)
	if _hit_time > 0.0:
		_hit_time -= delta
		hitmarker.queue_redraw()
	if death_panel.visible:
		var left: float = maxf(0.0, _respawn_at - Time.get_ticks_msec() / 1000.0)
		death_label.text = "YOU DIED\n%s\nRespawning at the hospital in %d s" % [_death_text, ceili(left)]


func _draw_hitmarker() -> void:
	if _hit_time <= 0.0:
		return
	var c: Vector2 = hitmarker.size / 2.0
	for d: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		hitmarker.draw_line(c + d * 6.0, c + d * 13.0, _hit_color, 2.0, true)


# --- Storage window (points 18 + 20) ----------------------------------------------------
# Left: your 8 pocket slots, right: the locker's slots. Click = move one item,
# Shift+click = the whole stack, drag a slot onto the other side = the whole stack,
# right click on a pocket slot = drop it on the ground (Shift: just one).

const SLOT_SIZE: Vector2 = Vector2(74, 74)

# --- Deal talk (point 34) ---------------------------------------------------------

var _deal_panel: Control
var _deal_title: Label
var _deal_text: Label
var _deal_confirm: Button
var _deal_npc: Pedestrian


func _build_deal_panel() -> void:
	var dim := Control.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.visible = false
	add_child(dim)
	_deal_panel = dim
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 0)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -230
	panel.offset_right = 230
	panel.offset_top = -330
	panel.offset_bottom = -170
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	dim.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	_deal_title = Label.new()
	_deal_title.add_theme_font_size_override("font_size", 22)
	_deal_title.add_theme_color_override("font_color", Pedestrian.DEAL_OK_COLOR)
	box.add_child(_deal_title)
	_deal_text = Label.new()
	_deal_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_deal_text.add_theme_font_size_override("font_size", 18)
	box.add_child(_deal_text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	_deal_confirm = _button("Confirm deal")
	_deal_confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deal_confirm.pressed.connect(func() -> void:
		if is_instance_valid(_deal_npc):
			_deal_npc.confirm_deal()
		close_requested.emit())
	row.add_child(_deal_confirm)
	var leave := _button("Not now  [E / Esc]")
	leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	leave.pressed.connect(func() -> void: close_requested.emit())
	row.add_child(leave)


func is_deal_open() -> bool:
	return _deal_panel != null and _deal_panel.visible


## Owner: "<name>: You got the 2 bags? €130, like we said."  [Confirm deal] [Not now]
func open_deal(npc: Pedestrian, have: int) -> void:
	if _deal_panel == null:
		_build_deal_panel()
	_deal_npc = npc
	var bags: String = npc.bags_text(npc.wants)
	var item: ItemData = ItemDB.get_item(StringName(npc.product))
	_deal_title.text = npc.customer_name
	_deal_text.text = "\"You got the %s? €%d, like we said.\"

You carry %d x %s." % [
			bags, npc.offer, have, item.display_name if item else npc.product]
	_deal_confirm.disabled = have < npc.wants
	_deal_confirm.text = "Confirm deal  (€%d)" % npc.offer if have >= npc.wants else "Not enough bags"
	_deal_panel.visible = true


func close_deal() -> void:
	_deal_npc = null
	if _deal_panel:
		_deal_panel.visible = false


var _locker_panel: Control
var _locker: StorageLocker
var _locker_player: Player
var _locker_mine: GridContainer
var _locker_theirs: GridContainer
var _locker_title: Label


func _build_locker_panel() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.visible = false
	add_child(dim)
	_locker_panel = dim
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.09, 0.1, 0.94)
	style.border_color = Color(0.55, 0.65, 0.75, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	_locker_title = Label.new()
	_locker_title.add_theme_font_size_override("font_size", 24)
	_locker_title.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	box.add_child(_locker_title)
	var hint := Label.new()
	hint.text = "Click: move one   Shift+click / drag: whole stack   Right click: drop on the ground\nShared with your crew."
	hint.add_theme_color_override("font_color", Color(0.75, 0.75, 0.78))
	box.add_child(hint)
	box.add_child(HSeparator.new())
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 28)
	box.add_child(cols)
	for i: int in 2:
		var col := VBoxContainer.new()
		var head := Label.new()
		head.text = "Your pockets" if i == 0 else "Locker"
		head.add_theme_font_size_override("font_size", 18)
		col.add_child(head)
		var grid := GridContainer.new()
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		col.add_child(grid)
		cols.add_child(col)
		if i == 0:
			_locker_mine = grid
		else:
			_locker_theirs = grid
	box.add_child(HSeparator.new())
	var close := _button("Close  [E / Esc]")
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.pressed.connect(func() -> void: close_requested.emit())
	box.add_child(close)


# --- Point 40: the ledger window of a front business's safe ------------------------------

var _safe_panel: Control
var _safe: LaunderSafe
var _safe_player: Player
var _safe_title: Label
var _safe_info: Label
var _safe_rows: VBoxContainer
var _safe_deposit: Button


func _build_safe_panel() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.visible = false
	add_child(dim)
	_safe_panel = dim
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.09, 0.1, 0.94)
	style.border_color = Color(0.45, 0.75, 0.5, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	_safe_title = Label.new()
	_safe_title.add_theme_font_size_override("font_size", 24)
	_safe_title.add_theme_color_override("font_color", Color(0.6, 0.95, 0.65))
	box.add_child(_safe_title)
	_safe_info = Label.new()
	_safe_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_safe_info.add_theme_color_override("font_color", Color(0.78, 0.78, 0.8))
	box.add_child(_safe_info)
	box.add_child(HSeparator.new())
	var head := Label.new()
	head.text = "Waiting to be laundered (first in, first out)"
	head.add_theme_font_size_override("font_size", 18)
	box.add_child(head)
	_safe_rows = VBoxContainer.new()
	_safe_rows.add_theme_constant_override("separation", 4)
	box.add_child(_safe_rows)
	box.add_child(HSeparator.new())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	_safe_deposit = _button("Deposit")
	_safe_deposit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_safe_deposit.pressed.connect(func() -> void:
		if is_instance_valid(_safe):
			_safe.deposit())
	row.add_child(_safe_deposit)
	var close := _button("Close  [E / Esc]")
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close.pressed.connect(func() -> void: close_requested.emit())
	row.add_child(close)


func is_safe_open() -> bool:
	return _safe_panel != null and _safe_panel.visible


func open_safe(s: LaunderSafe, p: Player) -> void:
	if _safe_panel == null:
		_build_safe_panel()
	close_safe()
	_safe = s
	_safe_player = p
	s.ledger_changed.connect(_refresh_safe)
	p.wallet_changed.connect(_refresh_safe)
	_refresh_safe()
	_safe_panel.visible = true


func close_safe() -> void:
	if _safe and is_instance_valid(_safe) and _safe.ledger_changed.is_connected(_refresh_safe):
		_safe.ledger_changed.disconnect(_refresh_safe)
	if _safe_player and is_instance_valid(_safe_player) and _safe_player.wallet_changed.is_connected(_refresh_safe):
		_safe_player.wallet_changed.disconnect(_refresh_safe)
	_safe = null
	_safe_player = null
	if _safe_panel:
		_safe_panel.visible = false


func _refresh_safe() -> void:
	if _safe == null or not is_instance_valid(_safe) or _safe_player == null:
		return
	var s: LaunderSafe = _safe
	_safe_title.text = "%s - back office safe" % s.business_name()
	_safe_info.text = "Launders €%d a day for a %d%% fee. Room for €%d more. Laundered here so far: €%d.
Your clean money: €%d." % [
			s.daily_max, roundi(s.fee * 100.0), s.capacity_left(), int(s.state.get("laundered", 0)), _safe_player.clean]
	for c: Node in _safe_rows.get_children():
		c.queue_free()
	var dn := get_tree().get_first_node_in_group(&"day_night") as DayNight
	var now: float = dn.hours if dn else 12.0
	var list: Array = s.ledger()
	if list.is_empty():
		var none := Label.new()
		none.text = "Nothing in the safe."
		none.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
		_safe_rows.add_child(none)
	for e: Dictionary in list:
		var l := Label.new()
		var mine: bool = str(e["who"]) == _safe_player.player_name
		l.text = "%s:  €%d dirty  ->  €%d clean, ready %s%s" % [
				"You" if mine else str(e["who"]), int(e["dirty"]), int(e["clean"]),
				LaunderSafe.eta_text(now, float(e["hours"])),
				"   (€%d already paid out)" % int(e["paid"]) if int(e["paid"]) > 0 else ""]
		l.add_theme_color_override("font_color", Color(0.95, 0.95, 0.75) if mine else Color(0.85, 0.85, 0.88))
		_safe_rows.add_child(l)
	var amount: int = mini(_safe_player.cash, s.capacity_left())
	_safe_deposit.disabled = amount <= 0
	_safe_deposit.text = "Deposit €%d dirty cash" % amount if amount > 0 else 			("The safe is full" if s.capacity_left() <= 0 else "You carry no dirty cash")


func is_locker_open() -> bool:
	return _locker_panel != null and _locker_panel.visible


func open_locker(l: StorageLocker, p: Player) -> void:
	if _locker_panel == null:
		_build_locker_panel()
	_locker = l
	_locker_player = p
	if not l.contents_changed.is_connected(_refresh_locker):
		l.contents_changed.connect(_refresh_locker)
	if not p.wallet_changed.is_connected(_refresh_locker):
		p.wallet_changed.connect(_refresh_locker)
	_refresh_locker()
	_locker_panel.visible = true


func close_locker() -> void:
	if _locker and is_instance_valid(_locker) and _locker.contents_changed.is_connected(_refresh_locker):
		_locker.contents_changed.disconnect(_refresh_locker)
	if _locker_player and _locker_player.wallet_changed.is_connected(_refresh_locker):
		_locker_player.wallet_changed.disconnect(_refresh_locker)
	_locker = null
	if _locker_panel:
		_locker_panel.visible = false


func _refresh_locker() -> void:
	if _locker == null or not is_instance_valid(_locker):
		return
	_locker_title.text = "%s  (%d/%d)" % [_locker.storage_name(), _locker.used_slots(), StorageLocker.SLOTS]
	_fill_slot_grid(_locker_mine, _locker_player.inventory, GameState.INVENTORY_SLOTS, false)
	_fill_slot_grid(_locker_theirs, _locker.state["items"], StorageLocker.SLOTS, true)


## One grid of `slots` slots; the first items.size() hold a stack.
func _fill_slot_grid(grid: GridContainer, items: Array, slots: int, in_locker: bool) -> void:
	for c: Node in grid.get_children():
		grid.remove_child(c)
		c.queue_free()
	for i: int in slots:
		var it: Dictionary = items[i] if i < items.size() else {}
		grid.add_child(_storage_slot(it, i, in_locker))


func _storage_slot(it: Dictionary, index: int, in_locker: bool) -> Control:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = SLOT_SIZE
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.17, 0.19, 0.95) if not it.is_empty() else Color(0.1, 0.1, 0.11, 0.8)
	style.border_color = Color(1, 1, 1, 0.22)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	slot.add_theme_stylebox_override("panel", style)
	if it.is_empty():
		slot.set_drag_forwarding(Callable(), _can_drop_on_slot.bind(in_locker), _drop_on_slot.bind(in_locker))
		return slot
	var data: ItemData = ItemDB.get_item(StringName(str(it.get("id", ""))))
	var icon := TextureRect.new()
	icon.texture = data.get_icon() if data else null
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(icon)
	var count := Label.new()
	count.text = "x%d" % int(it.get("count", 1))
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	count.add_theme_font_size_override("font_size", 15)
	count.add_theme_constant_override("outline_size", 4)
	count.add_theme_color_override("font_outline_color", Color.BLACK)
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(count)
	slot.tooltip_text = "%s  x%d" % [data.display_name if data else str(it.get("id")), int(it.get("count", 1))]
	slot.gui_input.connect(_on_storage_slot_input.bind(index, in_locker))
	slot.set_drag_forwarding(_drag_slot.bind(index, in_locker, icon.texture, slot), _can_drop_on_slot.bind(in_locker),
			_drop_on_slot.bind(in_locker))
	return slot


func _on_storage_slot_input(event: InputEvent, index: int, in_locker: bool) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or mb.pressed or _locker == null or not is_instance_valid(_locker):
		return
	if get_viewport().gui_is_dragging():
		return
	if mb.button_index == MOUSE_BUTTON_LEFT:
		_locker.request_move(not in_locker, index, 0 if mb.shift_pressed else 1)
	elif mb.button_index == MOUSE_BUTTON_RIGHT and not in_locker and _locker_player:
		_locker_player.request_drop(index, 1 if mb.shift_pressed else 0)


func _drag_slot(_at: Vector2, index: int, in_locker: bool, tex: Texture2D, source: Control) -> Variant:
	var preview := TextureRect.new()
	preview.texture = tex
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.custom_minimum_size = SLOT_SIZE * 0.8
	preview.size = SLOT_SIZE * 0.8
	preview.modulate = Color(1, 1, 1, 0.8)
	source.set_drag_preview(preview)
	return {"storage_slot": index, "in_locker": in_locker}


func _can_drop_on_slot(_at: Vector2, data: Variant, target_in_locker: bool) -> bool:
	return data is Dictionary and (data as Dictionary).has("storage_slot") and bool(data["in_locker"]) != target_in_locker


func _drop_on_slot(_at: Vector2, data: Variant, target_in_locker: bool) -> void:
	if _locker and is_instance_valid(_locker) and _can_drop_on_slot(_at, data, target_in_locker):
		_locker.request_move(target_in_locker, int(data["storage_slot"]), 0)
