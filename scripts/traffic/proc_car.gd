class_name ProcCar
extends RefCounted
## Procedural low-poly cars (same style as the procedural guns): a body, a glass
## cabin with a painted roof, bumpers, lights and four separate wheels.
## Car space: origin on the ground in the middle, front = -Z, up = +Y.

enum Kind { SEDAN, HATCHBACK, VAN }

const PAINTS: Array[Color] = [
	Color(0.85, 0.85, 0.83), Color(0.55, 0.57, 0.6), Color(0.06, 0.06, 0.07), Color(0.1, 0.16, 0.32),
	Color(0.5, 0.06, 0.05), Color(0.12, 0.25, 0.16), Color(0.62, 0.56, 0.44), Color(0.3, 0.31, 0.33),
	Color(0.75, 0.6, 0.12), Color(0.2, 0.35, 0.5),
]

## Size per kind: length, width, body top, roof height, cabin front/back z, wheel base.
const SPECS: Dictionary = {
	Kind.SEDAN: {"len": 4.4, "w": 1.78, "body": 0.82, "roof": 1.42, "cab_f": -0.75, "cab_b": 1.05, "base": 2.65},
	Kind.HATCHBACK: {"len": 3.9, "w": 1.72, "body": 0.84, "roof": 1.46, "cab_f": -0.55, "cab_b": 1.75, "base": 2.45},
	Kind.VAN: {"len": 4.9, "w": 1.9, "body": 1.05, "roof": 1.98, "cab_f": -1.55, "cab_b": 2.3, "base": 3.0},
}
const WHEEL_R: float = 0.33
const WHEEL_W: float = 0.22

static var _paint_cache: Dictionary = {}


## Builds the body mesh (one MeshInstance3D) and returns it; wheels are added as
## children of `parent` named Wheel0..3 (spin them around X).
static func build(parent: Node3D, kind: int, paint: Color) -> MeshInstance3D:
	var s: Dictionary = SPECS[kind]
	var hl: float = s["len"] / 2.0
	var hw: float = s["w"] / 2.0
	var body_top: float = s["body"]
	var roof: float = s["roof"]
	var b := MeshBuilder.new()
	var bottom: float = 0.3
	# Lower body: side profile (z, y), chamfered nose and tail.
	var nose: float = 0.25 if kind != Kind.VAN else 0.1
	_prism(b, &"car_paint", PackedVector2Array([
		Vector2(-hl, bottom + 0.1), Vector2(-hl + 0.05, body_top - 0.18), Vector2(-hl + nose + 0.3, body_top),
		Vector2(hl - 0.3, body_top), Vector2(hl, body_top - 0.12), Vector2(hl, bottom + 0.08), Vector2(hl - 0.1, bottom),
		Vector2(-hl + 0.1, bottom)]), hw)
	# Cabin: glass, narrower than the body, sloped screens.
	var cf: float = s["cab_f"]
	var cb: float = s["cab_b"]
	var chw: float = hw - 0.1
	var rake_f: float = 0.55 if kind != Kind.VAN else 0.25
	var rake_b: float = 0.35 if kind == Kind.SEDAN else 0.12
	_prism(b, &"car_glass", PackedVector2Array([
		Vector2(cf - rake_f, body_top), Vector2(cf, roof - 0.03), Vector2(cb - rake_b, roof - 0.03), Vector2(cb, body_top)]), chw)
	# Painted roof and pillars over the glass.
	_prism(b, &"car_paint", PackedVector2Array([
		Vector2(cf + 0.02, roof - 0.06), Vector2(cf + 0.06, roof), Vector2(cb - rake_b - 0.04, roof), Vector2(cb - rake_b, roof - 0.06)]), chw + 0.01)
	var mid: float = (cf + cb - rake_b) / 2.0
	b.box_mm(&"car_paint", Vector3(-chw - 0.012, body_top, mid - 0.06), Vector3(chw + 0.012, roof - 0.04, mid + 0.06))
	if kind == Kind.VAN:
		# Long van: a second pillar and a blind rear section.
		b.box_mm(&"car_paint", Vector3(-chw - 0.015, body_top, cb - 1.1), Vector3(chw + 0.015, roof - 0.03, cb - 0.12))
	# Bumpers, grille, mirrors.
	b.box_mm(&"car_trim", Vector3(-hw + 0.02, bottom - 0.02, -hl - 0.06), Vector3(hw - 0.02, bottom + 0.22, -hl + 0.2), 0.03)
	b.box_mm(&"car_trim", Vector3(-hw + 0.02, bottom - 0.02, hl - 0.2), Vector3(hw - 0.02, bottom + 0.22, hl + 0.06), 0.03)
	b.box_mm(&"car_trim", Vector3(-0.4, bottom + 0.3, -hl - 0.01), Vector3(0.4, body_top - 0.25, -hl + 0.05))
	for side: float in [-1.0, 1.0]:
		b.box_mm(&"car_paint", Vector3(side * (chw + 0.02) - 0.07, body_top + 0.08, cf - rake_f + 0.15),
				Vector3(side * (chw + 0.02) + 0.07, body_top + 0.2, cf - rake_f + 0.27), 0.01)
		# Lights: headlights front, tail lights back.
		var lx: float = side * (hw - 0.28)
		b.box_mm(&"car_headlight", Vector3(lx - 0.2, body_top - 0.24, -hl - 0.005), Vector3(lx + 0.2, body_top - 0.1, -hl + 0.1), 0.01)
		b.box_mm(&"car_taillight", Vector3(lx - 0.2, body_top - 0.26, hl - 0.08), Vector3(lx + 0.2, body_top - 0.12, hl + 0.005), 0.01)
		# Dark wheel wells so the tyres don't sit against bright paint.
		for z: float in [-s["base"] / 2.0, s["base"] / 2.0]:
			b.box_mm(&"car_trim", Vector3(side * hw - 0.02 if side < 0 else hw - 0.02, bottom, z - 0.42),
					Vector3(side * hw + 0.02 if side < 0 else hw + 0.02, bottom + 0.42, z + 0.42))
	b.box_mm(&"car_chrome", Vector3(-0.2, bottom + 0.06, hl + 0.06), Vector3(0.2, bottom + 0.16, hl + 0.075))  # plate
	var mi := MeshInstance3D.new()
	mi.name = "Body"
	mi.mesh = b.build()
	for i: int in mi.mesh.get_surface_count():
		if mi.mesh.surface_get_material(i) == MeshBuilder.get_material(&"car_paint"):
			mi.set_surface_override_material(i, _paint(paint))
	mi.visibility_range_end = 160.0
	parent.add_child(mi)
	# Wheels: tyre + hub, one node each so they can spin.
	var wb := MeshBuilder.new()
	wb.cylinder(&"car_tire", Vector3(-WHEEL_W / 2.0, 0, 0), Vector3(WHEEL_W / 2.0, 0, 0), WHEEL_R, WHEEL_R, 14, true)
	wb.cylinder(&"car_chrome", Vector3(WHEEL_W / 2.0 - 0.01, 0, 0), Vector3(WHEEL_W / 2.0 + 0.012, 0, 0), WHEEL_R * 0.55, WHEEL_R * 0.5, 10, true)
	wb.box_mm(&"car_trim", Vector3(WHEEL_W / 2.0, -0.04, -0.12), Vector3(WHEEL_W / 2.0 + 0.016, 0.04, 0.12))  # shows the spin
	var wheel_mesh: ArrayMesh = wb.build()
	var i: int = 0
	for z: float in [-s["base"] / 2.0, s["base"] / 2.0]:
		for side: float in [-1.0, 1.0]:
			var w := MeshInstance3D.new()
			w.name = "Wheel%d" % i
			w.mesh = wheel_mesh
			w.rotation.y = PI if side < 0 else 0.0  # hub faces outwards
			w.visibility_range_end = 90.0
			var at := Vector3(side * (hw - WHEEL_W / 2.0 + 0.02), WHEEL_R, z)
			if z < 0.0:
				# Front wheel: inside a pivot that steers around Y.
				var pivot := Node3D.new()
				pivot.name = "Steer%d" % i
				pivot.position = at
				parent.add_child(pivot)
				pivot.add_child(w)
			else:
				w.position = at
				parent.add_child(w)
			i += 1
	return mi


## Collision box size + centre height for a kind.
static func collision_size(kind: int) -> Vector3:
	var s: Dictionary = SPECS[kind]
	return Vector3(s["w"], s["roof"] - 0.25, s["len"])


static func _paint(c: Color) -> Material:
	var key: String = c.to_html()
	if not _paint_cache.has(key):
		var m := (MeshBuilder.get_material(&"car_paint") as StandardMaterial3D).duplicate() as StandardMaterial3D
		m.albedo_color = c
		_paint_cache[key] = m
	return _paint_cache[key]


## Side profile (points in (z, y), convex, in order) extruded to half-width hw in X.
static func _prism(b: MeshBuilder, key: StringName, profile: PackedVector2Array, hw: float) -> void:
	var left := PackedVector3Array()
	var right := PackedVector3Array()
	for p: Vector2 in profile:
		left.append(Vector3(-hw, p.y, p.x))
		right.append(Vector3(hw, p.y, p.x))
	b.poly(key, left, Vector3.LEFT)
	b.poly(key, right, Vector3.RIGHT)
	var n: int = profile.size()
	var center := Vector2.ZERO
	for p: Vector2 in profile:
		center += p
	center /= n
	for i: int in n:
		var j: int = (i + 1) % n
		var m: Vector2 = (profile[i] + profile[j]) * 0.5
		b.poly(key, PackedVector3Array([left[i], left[j], right[j], right[i]]), Vector3(0, m.y - center.y, m.x - center.x))
