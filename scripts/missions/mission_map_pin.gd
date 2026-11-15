class_name MissionMapPin
extends Control
## NOTES part 19: put by `Missions` on every PhoneMap (phone Map app, estate window): the mission waypoint as a gold
## diamond (+ radius ring), clamped to the map edge when it lies outside the shown part. Uses PhoneMap._to_map.


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var map := get_parent() as PhoneMap
	var target: Variant = Missions.view.get("target")
	if map == null or str(Missions.view.get("active", "")) == "" or not target is Vector3:
		return
	var t: Vector3 = target
	var p: Vector2 = map._to_map(Vector2(t.x, t.z))
	var m: float = 12.0
	var inside: bool = Rect2(Vector2(m, m), size - Vector2(m, m) * 2.0).has_point(p)
	p = Vector2(clampf(p.x, m, size.x - m), clampf(p.y, m, size.y - m))
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 250.0)
	var radius: float = float(Missions.view.get("radius", 0.0)) * PhoneMap.PIXELS_PER_M
	if inside and radius > 6.0:
		draw_arc(p, radius, 0, TAU, 32, Color(1, 0.8, 0.25, 0.5), 1.5)
	var r: float = 7.0 + 2.0 * pulse
	var dia := PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0)])
	draw_colored_polygon(dia, Color(1, 0.8, 0.25))
	draw_polyline(dia + PackedVector2Array([dia[0]]), Color(0, 0, 0, 0.9), 1.5)
