class_name HudIcon
extends Control
## Point 27 (HUD in the game's style): small flat icons drawn in code, so they stay crisp
## at any size and need no image files. Kinds: heart, bullet, cash, bank, clock, star.

@export_enum("heart", "bullet", "cash", "bank", "clock", "star") var kind: String = "heart":
	set(v): kind = v; queue_redraw()
@export var color: Color = Color.WHITE:
	set(v): color = v; queue_redraw()


static func make(icon_kind: String, icon_color: Color, px: float = 22.0) -> HudIcon:
	var i := HudIcon.new()
	i.kind = icon_kind
	i.color = icon_color
	i.custom_minimum_size = Vector2(px, px)
	i.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return i


func _draw() -> void:
	var s: float = minf(size.x, size.y)
	var o := Vector2((size.x - s) / 2.0, (size.y - s) / 2.0)
	var shadow := Color(0, 0, 0, 0.45)
	for pass_i: int in 2:
		var off: Vector2 = o + (Vector2(1.5, 1.5) if pass_i == 0 else Vector2.ZERO)
		var c: Color = shadow if pass_i == 0 else color
		match kind:
			"heart":
				draw_circle(off + Vector2(0.3, 0.35) * s, 0.22 * s, c)
				draw_circle(off + Vector2(0.7, 0.35) * s, 0.22 * s, c)
				draw_colored_polygon(PackedVector2Array([off + Vector2(0.1, 0.45) * s, off + Vector2(0.9, 0.45) * s,
						off + Vector2(0.5, 0.9) * s]), c)
			"bullet":
				draw_rect(Rect2(off + Vector2(0.35, 0.42) * s, Vector2(0.3, 0.48) * s), c)
				draw_circle(off + Vector2(0.5, 0.42) * s, 0.15 * s, c)
				draw_colored_polygon(PackedVector2Array([off + Vector2(0.35, 0.42) * s, off + Vector2(0.5, 0.08) * s,
						off + Vector2(0.65, 0.42) * s]), c)
			"cash":
				draw_rect(Rect2(off + Vector2(0.05, 0.25) * s, Vector2(0.9, 0.5) * s), c)
				if pass_i == 1:
					draw_circle(off + Vector2(0.5, 0.5) * s, 0.13 * s, c.darkened(0.45))
			"bank":
				draw_colored_polygon(PackedVector2Array([off + Vector2(0.05, 0.32) * s, off + Vector2(0.5, 0.08) * s,
						off + Vector2(0.95, 0.32) * s]), c)
				for k: int in 4:
					draw_rect(Rect2(off + Vector2(0.14 + k * 0.2, 0.38) * s, Vector2(0.11, 0.38) * s), c)
				draw_rect(Rect2(off + Vector2(0.05, 0.8) * s, Vector2(0.9, 0.12) * s), c)
			"clock":
				draw_circle(off + Vector2(0.5, 0.5) * s, 0.42 * s, c)
				if pass_i == 1:
					var d: Color = c.darkened(0.6)
					draw_line(off + Vector2(0.5, 0.5) * s, off + Vector2(0.5, 0.22) * s, d, maxf(1.5, s * 0.08))
					draw_line(off + Vector2(0.5, 0.5) * s, off + Vector2(0.7, 0.55) * s, d, maxf(1.5, s * 0.08))
			"star":
				var pts := PackedVector2Array()
				for k: int in 10:
					var a: float = -PI / 2.0 + k * PI / 5.0
					var r: float = 0.46 if k % 2 == 0 else 0.2
					pts.append(off + (Vector2(0.5, 0.52) + Vector2(cos(a), sin(a)) * r) * s)
				draw_colored_polygon(pts, c)
