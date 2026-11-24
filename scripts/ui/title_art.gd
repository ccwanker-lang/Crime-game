class_name TitleArt
extends RefCounted
## Shared look of the title page, loading screen and pause menu (session B, user list item 3).

const ACCENT: Color = Color(0.98, 0.72, 0.25)
const TITLE: String = "CRIME CO-OP"
const TAGLINE: String = "a co-op crime sandbox"


## The game's logo: big title with a shadow + a small tagline under it.
static func logo(size: int = 72, tagline: bool = true) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", -int(size * 0.1))
	var t := Label.new()
	t.text = TITLE
	t.add_theme_font_size_override(&"font_size", size)
	t.add_theme_color_override(&"font_color", Color(1, 0.97, 0.9))
	t.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0.6))
	t.add_theme_constant_override(&"shadow_offset_x", 0)
	t.add_theme_constant_override(&"shadow_offset_y", int(size * 0.06))
	t.add_theme_color_override(&"font_outline_color", Color(0.08, 0.06, 0.04))
	t.add_theme_constant_override(&"outline_size", int(size * 0.08))
	box.add_child(t)
	if tagline:
		var s := Label.new()
		s.text = TAGLINE.to_upper()
		s.add_theme_font_size_override(&"font_size", int(size * 0.26))
		s.add_theme_color_override(&"font_color", ACCENT)
		s.add_theme_constant_override(&"outline_size", 4)
		s.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.7))
		box.add_child(s)
	return box


## A 1-pixel-wide vertical gradient texture (top -> bottom); stretch it over a TextureRect.
static func vertical_fade(top: Color, bottom: Color) -> GradientTexture2D:
	return _fade(top, bottom, Vector2(0, 0), Vector2(0, 1))


## A horizontal gradient texture (left -> right).
static func horizontal_fade(left: Color, right: Color) -> GradientTexture2D:
	return _fade(left, right, Vector2(0, 0), Vector2(1, 0))


static func _fade(a: Color, b: Color, from: Vector2, to: Vector2) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, a)
	g.set_color(1, b)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = from
	tex.fill_to = to
	tex.width = 64
	tex.height = 64
	return tex


## A big menu button (flat, left aligned, accent on hover).
static func menu_button(text: String, size: int = 30) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override(&"font_size", size)
	b.add_theme_color_override(&"font_color", Color(0.92, 0.92, 0.95))
	b.add_theme_color_override(&"font_hover_color", ACCENT)
	b.add_theme_color_override(&"font_focus_color", ACCENT)
	b.add_theme_color_override(&"font_pressed_color", ACCENT.darkened(0.2))
	b.add_theme_color_override(&"font_disabled_color", Color(0.5, 0.5, 0.55))
	b.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.8))
	b.add_theme_constant_override(&"outline_size", 4)
	var empty := StyleBoxEmpty.new()
	for st: StringName in [&"normal", &"hover", &"pressed", &"focus", &"disabled", &"hover_pressed"]:
		b.add_theme_stylebox_override(st, empty)
	return b


## A dark, rounded panel style.
static func panel_style(alpha: float = 0.82) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.08, alpha)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(18)
	sb.border_color = Color(1, 1, 1, 0.08)
	sb.set_border_width_all(1)
	return sb


## "3 h 20 min" / "12 min".
static func play_time_text(seconds: float) -> String:
	var m: int = int(seconds / 60.0)
	if m < 60:
		return "%d min" % m
	return "%d h %02d min" % [m / 60, m % 60]
