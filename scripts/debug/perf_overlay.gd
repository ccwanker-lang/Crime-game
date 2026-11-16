class_name PerfOverlay
extends CanvasLayer
## Point 86: F3 debug overlay (with the marker labels): FPS, frame time, active / sleeping NPCs, draw calls,
## primitives, nodes, physics + script time. Updated 4x a second. World/PerfOverlay, hidden by default.

var _label: Label
var _t: float = 0.0
var _frames: int = 0
var _worst: float = 0.0


func _ready() -> void:
	layer = 90
	visible = false
	var panel := PanelContainer.new()
	panel.position = Vector2(12, 160)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.6)
	sb.set_content_margin_all(8)
	panel.add_theme_stylebox_override(&"panel", sb)
	add_child(panel)
	_label = Label.new()
	_label.add_theme_font_size_override(&"font_size", 15)
	_label.add_theme_color_override(&"font_color", Color(0.9, 1.0, 0.8))
	panel.add_child(_label)


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_frames += 1
	_worst = maxf(_worst, delta)
	if _t < 0.25:
		return
	var st: NpcStreamer = NpcStreamer.current
	var npcs: int = get_tree().get_nodes_in_group(&"npc").size()
	_label.text = "FPS %d  (%.1f ms, worst %.1f ms)\nNPCs active %d / asleep %d / total %d\nDraw calls %d   primitives %.1f M\nNodes %d   script %.1f ms   physics %.1f ms" % [
			roundi(_frames / _t), 1000.0 * _t / _frames, _worst * 1000.0,
			st.active if st else npcs, st.asleep if st else 0, npcs,
			int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1e6,
			int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0]
	_t = 0.0
	_frames = 0
	_worst = 0.0
