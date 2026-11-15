class_name MissionHUD
extends CanvasLayer
## NOTES part 19 (every peer, local): the running mission's objective (top right, under the money box), a waypoint
## on screen (diamond + distance, clamped to the screen edge when the target is behind you or off screen) and a
## banner in the middle top ("NEW MISSION", "OBJECTIVE COMPLETE", "MISSION COMPLETE" ...). Made by `Missions`.

const GOLD := Color(1.0, 0.8, 0.25)

var _panel: PanelContainer
var _title: Label
var _text: Label
var _dist: Label
var _marker: Control
var _banner: VBoxContainer
var _banner_head: Label
var _banner_text: Label
var _banner_t: float = 0.0


func _ready() -> void:
	layer = 4
	var theme_res: Theme = load("res://assets/ui/game_theme.tres") as Theme
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if theme_res:
		root.theme = theme_res
	add_child(root)
	_marker = Control.new()
	_marker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marker.draw.connect(_draw_marker)
	root.add_child(_marker)
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_panel.offset_left = -360
	_panel.offset_right = -14
	_panel.offset_top = 132
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.06, 0.07, 0.09, 0.78)
	st.border_color = GOLD.darkened(0.3)
	st.border_width_left = 4
	st.set_corner_radius_all(10)
	st.set_content_margin_all(10)
	_panel.add_theme_stylebox_override("panel", st)
	root.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	_panel.add_child(box)
	_title = _label(box, 15, GOLD)
	_text = _label(box, 18, Color.WHITE)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dist = _label(box, 13, Color(0.7, 0.75, 0.8))
	_banner = VBoxContainer.new()
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_left = -400
	_banner.offset_right = 400
	_banner.offset_top = 110
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_banner)
	_banner_head = _label(_banner, 34, GOLD)
	_banner_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_head.add_theme_constant_override("outline_size", 8)
	_banner_head.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_banner_text = _label(_banner, 20, Color.WHITE)
	_banner_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner_text.add_theme_constant_override("outline_size", 6)
	_banner_text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_banner.visible = false
	Missions.changed.connect(_refresh)
	_refresh()


func _label(parent: Control, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func banner(head: String, text: String) -> void:
	_banner_head.text = head
	_banner_text.text = text
	_banner.visible = true
	_banner.modulate.a = 1.0
	_banner_t = 4.5


func _refresh() -> void:
	var v: Dictionary = Missions.view
	var on: bool = str(v.get("active", "")) != ""
	_panel.visible = on
	if not on:
		return
	var steps: Array = v.get("steps", [])
	_title.text = "%s   (%d/%d)" % [str(v.get("title", "")).to_upper(), int(v.get("step", 0)) + 1, steps.size()]
	_text.text = str(v.get("text", ""))
	if Missions._local_player() and Missions._local_player().player_name in (v.get("late", []) as Array):
		_title.text += "   - joined late, no reward"


func _process(delta: float) -> void:
	if _banner_t > 0.0:
		_banner_t -= delta
		_banner.modulate.a = clampf(_banner_t, 0.0, 1.0)
		if _banner_t <= 0.0:
			_banner.visible = false
	var p: Player = Missions._local_player()
	var target: Variant = Missions.view.get("target")
	if p and target is Vector3 and _panel.visible:
		var d: float = p.global_position.distance_to(target)
		_dist.text = "%d m" % roundi(d) if d > float(Missions.view.get("radius", 4.0)) else "here"
	_marker.queue_redraw()


## The waypoint: a gold diamond over the target (+ distance); at the screen edge with an arrow when off screen.
func _draw_marker() -> void:
	var target: Variant = Missions.view.get("target")
	if not _panel.visible or not target is Vector3:
		return
	var cam: Camera3D = get_viewport().get_camera_3d()
	var p: Player = Missions._local_player()
	if cam == null or p == null:
		return
	var at: Vector3 = (target as Vector3) + Vector3.UP * 2.9
	var vs: Vector2 = _marker.size
	var behind: bool = cam.is_position_behind(at)
	var sp: Vector2 = cam.unproject_position(at)
	if behind:
		sp = vs - sp  # (mirrored when behind)
		sp.y = vs.y - 40.0
	var margin: float = 36.0
	var inside: bool = not behind and Rect2(Vector2(margin, margin), vs - Vector2(margin, margin) * 2.0).has_point(sp)
	var c: Vector2 = Vector2(clampf(sp.x, margin, vs.x - margin), clampf(sp.y, margin, vs.y - margin))
	var r: float = 11.0
	var dia := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
	_marker.draw_colored_polygon(dia, GOLD)
	_marker.draw_polyline(dia + PackedVector2Array([dia[0]]), Color(0, 0, 0, 0.8), 2.0)
	if not inside:
		var dir: Vector2 = (sp - vs * 0.5).normalized() if not behind else Vector2(signf(sp.x - vs.x * 0.5), 1).normalized()
		var tip: Vector2 = c + dir * (r + 12.0)
		var side: Vector2 = dir.orthogonal() * 7.0
		_marker.draw_colored_polygon(PackedVector2Array([tip, c + dir * (r + 3.0) + side, c + dir * (r + 3.0) - side]), GOLD)
	var font: Font = ThemeDB.fallback_font
	var d: float = p.global_position.distance_to(target)
	_marker.draw_string_outline(font, c + Vector2(-30, r + 18), "%d m" % roundi(d), HORIZONTAL_ALIGNMENT_CENTER, 60, 14, 4,
			Color(0, 0, 0, 0.85))
	_marker.draw_string(font, c + Vector2(-30, r + 18), "%d m" % roundi(d), HORIZONTAL_ALIGNMENT_CENTER, 60, 14, Color.WHITE)
