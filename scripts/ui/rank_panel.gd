class_name RankPanel
extends Control
## HUD (top left): the crew's rank, an XP bar and what the next rank unlocks; "+XP" popups
## and a rank-up banner. Reads the Progression autoload (synced by the host).
## Added by PlayerHUD._ready (only on the owning peer).

const ACCENT := Color(0.96, 0.77, 0.27)
const XP_COLOR := Color(0.55, 0.85, 1.0)
const BANNER_TIME: float = 6.0

var _rank_label: Label
var _bar: ProgressBar
var _xp_label: Label
var _next_label: Label
var _pop: Label
var _pop_time: float = 0.0
var _pop_sum: int = 0
var _banner: PanelContainer
var _banner_title: Label
var _banner_text: Label
var _banner_time: float = 0.0


func _ready() -> void:
	name = "RankPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	Progression.xp_changed.connect(_on_xp_changed)
	Progression.xp_gained.connect(_on_xp_gained)
	Progression.ranked_up.connect(_on_ranked_up)
	_on_xp_changed(Progression.xp, Progression.rank())
	Progression.request_sync()


func _build() -> void:
	# Bottom left, just above the health bar (the top left holds the session panel).
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(260, 0)
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = 12.0
	panel.offset_bottom = -92.0
	panel.offset_top = -92.0
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	panel.add_child(box)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	box.add_child(top)
	top.add_child(HudIcon.make("star", ACCENT, 24))
	_rank_label = Label.new()
	_rank_label.add_theme_font_size_override("font_size", 20)
	_rank_label.add_theme_color_override("font_color", ACCENT)
	top.add_child(_rank_label)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(236, 10)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = XP_COLOR
	fill.set_corner_radius_all(4)
	_bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.12)
	bg.set_corner_radius_all(4)
	_bar.add_theme_stylebox_override("background", bg)
	box.add_child(_bar)
	_xp_label = Label.new()
	_xp_label.add_theme_font_size_override("font_size", 14)
	_xp_label.add_theme_color_override("font_color", XP_COLOR)
	box.add_child(_xp_label)
	_next_label = Label.new()
	_next_label.add_theme_font_size_override("font_size", 12)
	_next_label.modulate = Color(1, 1, 1, 0.65)
	_next_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_next_label.custom_minimum_size = Vector2(236, 0)
	box.add_child(_next_label)
	_pop = Label.new()
	_pop.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_pop.offset_left = 286.0
	_pop.offset_top = -150.0
	_pop.add_theme_font_size_override("font_size", 22)
	_pop.add_theme_color_override("font_color", XP_COLOR)
	_pop.add_theme_constant_override("outline_size", 6)
	_pop.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_pop.modulate.a = 0.0
	add_child(_pop)
	# Rank-up banner, top centre.
	var top_center := CenterContainer.new()
	top_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_center.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	top_center.offset_top = 90.0
	add_child(top_center)
	_banner = PanelContainer.new()
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.visible = false
	top_center.add_child(_banner)
	var bbox := VBoxContainer.new()
	bbox.add_theme_constant_override("separation", 4)
	_banner.add_child(bbox)
	_banner_title = Label.new()
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_title.add_theme_font_size_override("font_size", 30)
	_banner_title.add_theme_color_override("font_color", ACCENT)
	bbox.add_child(_banner_title)
	_banner_text = Label.new()
	_banner_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner_text.custom_minimum_size = Vector2(460, 0)
	_banner_text.add_theme_font_size_override("font_size", 16)
	bbox.add_child(_banner_text)


func _on_xp_changed(xp: int, rank: int) -> void:
	_rank_label.text = "Rank %d  %s" % [rank, Progression.rank_name(rank)]
	var next_xp: int = Progression.xp_for(rank + 1)
	if rank >= Progression.MAX_RANK or next_xp < 0:
		_bar.max_value = 1.0
		_bar.value = 1.0
		_xp_label.text = "%d XP  (top rank)" % xp
		_next_label.text = ""
		return
	var base: int = Progression.xp_for(rank)
	_bar.max_value = float(next_xp - base)
	_bar.value = float(xp - base)
	_xp_label.text = "%d / %d XP" % [xp, next_xp]
	_next_label.text = "Next: %s - %s" % [Progression.rank_name(rank + 1), Progression.unlocks(rank + 1)]


func _on_xp_gained(amount: int, reason: String) -> void:
	_pop_sum = (_pop_sum if _pop_time > 0.0 else 0) + amount
	_pop.text = "+%d XP  %s" % [_pop_sum, reason]
	_pop_time = 2.5


func _on_ranked_up(rank: int) -> void:
	_banner_title.text = "RANK UP!  %d  %s" % [rank, Progression.rank_name(rank)]
	_banner_text.text = "Unlocked: %s" % Progression.unlocks(rank)
	_banner.visible = true
	_banner.modulate.a = 1.0
	_banner_time = BANNER_TIME


func _process(delta: float) -> void:
	if _pop_time > 0.0:
		_pop_time -= delta
		_pop.modulate.a = clampf(_pop_time / 0.6, 0.0, 1.0)
	if _banner_time > 0.0:
		_banner_time -= delta
		_banner.modulate.a = clampf(_banner_time / 0.8, 0.0, 1.0)
		if _banner_time <= 0.0:
			_banner.visible = false
