class_name CritterMesh
extends RefCounted
## Roadmap 68 (session B): low-poly meshes for the ambient animals (MeshBuilder, item_matte vertex colours), cached
## per look so 40 animals share a handful of meshes. Forward = -Z, origin = between the feet / on the water line.

static var _cache: Dictionary = {}


static func _cached(key: String, make: Callable) -> ArrayMesh:
	if not _cache.has(key):
		var b := MeshBuilder.new()
		make.call(b)
		_cache[key] = b.build()
	return _cache[key]


static func instance(mesh: ArrayMesh, range_end: float = 90.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = range_end
	return mi


# --- Birds (sparrow-ish bird, pigeon, duck: one shape, other proportions) ---------------------------------------

## Body + tail + legs of a bird (no head, no wings). `duck` = flat bottom on the water, no legs.
static func bird_body(body: Color, belly: Color, duck: bool) -> ArrayMesh:
	return _cached("body%s%s%s" % [body.to_html(), belly.to_html(), duck], func(b: MeshBuilder) -> void:
		var y: float = 0.05 if duck else 0.09
		b.color = body
		b.box(&"item_matte", Vector3(0, y, 0), Vector3(0.09, 0.08, 0.17), 0.02)
		b.box(&"item_matte", Vector3(0, y + 0.015, 0.11), Vector3(0.06, 0.02, 0.08), 0.005)  # tail
		b.color = belly
		b.box(&"item_matte", Vector3(0, y - 0.03, -0.01), Vector3(0.075, 0.03, 0.13), 0.01)
		if not duck:
			b.color = Color(0.75, 0.42, 0.3)
			b.box(&"item_matte", Vector3(-0.022, 0.025, 0), Vector3(0.012, 0.05, 0.012))
			b.box(&"item_matte", Vector3(0.022, 0.025, 0), Vector3(0.012, 0.05, 0.012)))


## The head (pivot at the neck) with the beak along -Z.
static func bird_head(head: Color, beak: Color, duck: bool) -> ArrayMesh:
	return _cached("head%s%s%s" % [head.to_html(), beak.to_html(), duck], func(b: MeshBuilder) -> void:
		b.color = head
		b.box(&"item_matte", Vector3(0, 0.03, -0.015), Vector3(0.055, 0.055, 0.06), 0.012)
		b.color = beak
		if duck:
			b.box(&"item_matte", Vector3(0, 0.02, -0.065), Vector3(0.035, 0.012, 0.05), 0.004)
		else:
			b.box(&"item_matte", Vector3(0, 0.025, -0.055), Vector3(0.016, 0.014, 0.025), 0.003)
		b.color = Color(0.03, 0.03, 0.03)
		b.box(&"item_matte", Vector3(-0.028, 0.04, -0.025), Vector3(0.004, 0.01, 0.01))
		b.box(&"item_matte", Vector3(0.028, 0.04, -0.025), Vector3(0.004, 0.01, 0.01)))


## One wing, pivot at the shoulder, reaching out along +X (the left wing is this one mirrored).
static func bird_wing(col: Color, tip: Color) -> ArrayMesh:
	return _cached("wing%s%s" % [col.to_html(), tip.to_html()], func(b: MeshBuilder) -> void:
		b.color = col
		b.box(&"item_matte", Vector3(0.07, 0, 0.01), Vector3(0.14, 0.012, 0.1), 0.004)
		b.color = tip
		b.box(&"item_matte", Vector3(0.17, 0, 0.025), Vector3(0.07, 0.01, 0.07), 0.003))


# --- Cat ----------------------------------------------------------------------------------------------------------

static func cat_body(coat: Color, belly: Color) -> ArrayMesh:
	return _cached("catbody%s%s" % [coat.to_html(), belly.to_html()], func(b: MeshBuilder) -> void:
		b.color = coat
		b.box(&"item_matte", Vector3(0, 0, 0), Vector3(0.13, 0.13, 0.34), 0.035)
		b.color = belly
		b.box(&"item_matte", Vector3(0, -0.045, -0.02), Vector3(0.1, 0.05, 0.24), 0.015))


static func cat_head(coat: Color) -> ArrayMesh:
	return _cached("cathead%s" % coat.to_html(), func(b: MeshBuilder) -> void:
		b.color = coat
		b.box(&"item_matte", Vector3(0, 0.03, -0.04), Vector3(0.12, 0.1, 0.1), 0.03)
		b.box(&"item_matte", Vector3(0, 0.01, -0.095), Vector3(0.06, 0.045, 0.04), 0.012)  # muzzle
		b.box(&"item_matte", Vector3(-0.038, 0.095, -0.035), Vector3(0.03, 0.05, 0.02), 0.004)  # ears
		b.box(&"item_matte", Vector3(0.038, 0.095, -0.035), Vector3(0.03, 0.05, 0.02), 0.004)
		b.color = Color(0.55, 0.75, 0.2)
		b.box(&"item_matte", Vector3(-0.028, 0.045, -0.091), Vector3(0.022, 0.016, 0.004))
		b.box(&"item_matte", Vector3(0.028, 0.045, -0.091), Vector3(0.022, 0.016, 0.004))
		b.color = Color(0.85, 0.5, 0.5)
		b.box(&"item_matte", Vector3(0, 0.024, -0.116), Vector3(0.018, 0.012, 0.006)))


static func cat_leg(coat: Color) -> ArrayMesh:
	return _cached("catleg%s" % coat.to_html(), func(b: MeshBuilder) -> void:
		b.color = coat
		b.box(&"item_matte", Vector3(0, -0.075, 0), Vector3(0.035, 0.15, 0.035), 0.008))


## The tail, pivot at the base, reaching back (+Z) and up.
static func cat_tail(coat: Color) -> ArrayMesh:
	return _cached("cattail%s" % coat.to_html(), func(b: MeshBuilder) -> void:
		b.color = coat
		b.box(&"item_matte", Vector3(0, 0.04, 0.12), Vector3(0.03, 0.03, 0.26), 0.01))
