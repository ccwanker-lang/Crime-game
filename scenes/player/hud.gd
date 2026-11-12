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
var _hotbar_selected: int = -2
var _toast: Label
var _toast_time: float = 0.0
var _last_cash: int = -1
var _shop_panel: Control
var _shop: Shopkeeper
var _shop_title: Label
var _shop_greeting: Label
var _shop_list: VBoxContainer
var _shop_cash: Label
var _shop_msg: Label


func _ready() -> void:
	hitmarker.draw.connect(_draw_hitmarker)
	death_panel.visible = false
	damage_flash.color.a = 0.0
	_build_inventory_bar()
	_build_shop_panel()
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


func set_cash(cash: int) -> void:
	cash_label.text = "€ %d%s" % [cash, "  (∞ dev)" if GameState.infinite_cash else ""]
	if _last_cash >= 0 and cash != _last_cash:
		toast("%s€%d" % ["+" if cash > _last_cash else "-", absi(cash - _last_cash)])
	_last_cash = cash
	if _shop_cash:
		_shop_cash.text = "Your cash: €%d%s" % [cash, "  - buying is free for now" if GameState.infinite_cash else ""]


# --- Inventory bar ---------------------------------------------------------------

func _build_inventory_bar() -> void:
	var bar := HBoxContainer.new()
	bar.name = "InventoryBar"
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_constant_override("separation", 6)
	bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.offset_top = -112.0
	bar.offset_bottom = -48.0
	add_child(bar)
	for i: int in GameState.INVENTORY_SLOTS:
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(78, 64)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.05, 0.05, 0.06, 0.55)
		style.border_color = Color(1, 1, 1, 0.18)
		style.set_border_width_all(1)
		style.set_corner_radius_all(4)
		style.set_content_margin_all(4)
		slot.add_theme_stylebox_override("panel", style)
		_slot_styles.append(style)
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_constant_override("outline_size", 4)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		slot.add_child(label)
		var count := Label.new()
		count.size_flags_horizontal = Control.SIZE_SHRINK_END
		count.size_flags_vertical = Control.SIZE_SHRINK_END
		count.add_theme_font_size_override("font_size", 15)
		count.add_theme_constant_override("outline_size", 5)
		count.add_theme_color_override("font_outline_color", Color.BLACK)
		slot.add_child(count)
		var key := Label.new()  # the number key of this slot
		key.text = str(i + 1)
		key.add_theme_font_size_override("font_size", 11)
		key.modulate = Color(1, 1, 1, 0.55)
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
	_toast.add_theme_font_size_override("font_size", 18)
	_toast.add_theme_constant_override("outline_size", 6)
	_toast.add_theme_color_override("font_outline_color", Color.BLACK)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast)


## Shows the carried stacks ([{ "id", "count" }]) in the bar.
func set_inventory(items: Array) -> void:
	for i: int in _slots.size():
		var name_label := _slots[i].get_child(0) as Label
		var count_label := _slots[i].get_child(1) as Label
		if i < items.size():
			var it: Dictionary = items[i]
			var data: ItemData = ItemDB.get_item(StringName(str(it.get("id", ""))))
			name_label.text = data.display_name if data else str(it.get("id"))
			var n: int = int(it.get("count", 1))
			count_label.text = "x%d" % n if n > 1 else ""
		else:
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
		st.border_color = Color(1.0, 0.82, 0.35, 0.95) if on else Color(1, 1, 1, 0.18)
		st.set_border_width_all(2 if on else 1)
		st.bg_color = Color(0.16, 0.13, 0.06, 0.7) if on else Color(0.05, 0.05, 0.06, 0.55)


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


func open_shop(shop: Shopkeeper, cash: int) -> void:
	_shop = shop
	_shop_title.text = "%s  -  %s" % [shop.npc_name, shop.shop_name]
	_shop_greeting.text = "\"%s\"" % shop.greeting
	_shop_msg.text = ""
	_shop_cash.text = "Your cash: €%d%s" % [cash, "  - buying is free for now" if GameState.infinite_cash else ""]
	for c: Node in _shop_list.get_children():
		c.queue_free()
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


func _process(delta: float) -> void:
	var dn := get_tree().get_first_node_in_group("day_night") as DayNight
	if dn:
		clock_label.text = dn.clock_text() + (" >>" if dn.fast_forward else "")
	damage_flash.color.a = move_toward(damage_flash.color.a, 0.0, delta * 0.8)
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
