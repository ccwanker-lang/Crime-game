@tool
class_name ProcGun
extends Node3D
## Procedural low-poly firearm (child "Model" of a WeaponModel prefab). Built in
## weapon space: origin = middle of the pistol grip, barrel along -Z, up +Y.
## Parts are separate MeshInstance3D children so WeaponModel can animate them:
##   Body, Bolt (charging handle / pump: moves towards the shooter), Magazine.
## Materials: gun_metal, gun_wood, gun_polymer (prefabs/materials, PBR with wear).

enum Kind { RIFLE_AK, SMG, SHOTGUN, PISTOL }

@export var kind: Kind = Kind.RIFLE_AK:
	set(v):
		kind = v
		_queue_rebuild()

var _pending: bool = false


func _ready() -> void:
	_rebuild()


func _queue_rebuild() -> void:
	if not is_inside_tree() or _pending:
		return
	_pending = true
	_rebuild.call_deferred()


func _rebuild() -> void:
	_pending = false
	for c: Node in get_children():
		remove_child(c)
		c.free()
	var body := MeshBuilder.new()
	var bolt := MeshBuilder.new()
	var mag := MeshBuilder.new()
	match kind:
		Kind.RIFLE_AK:
			_build_ak(body, bolt, mag)
		Kind.SMG:
			_build_smg(body, bolt, mag)
		Kind.SHOTGUN:
			_build_shotgun(body, bolt, mag)
		Kind.PISTOL:
			_build_pistol(body, bolt, mag)
	_add_part("Body", body)
	_add_part("Bolt", bolt)
	_add_part("Magazine", mag)


func _add_part(part_name: String, b: MeshBuilder) -> void:
	if not b.has_geometry():
		return
	var mi := MeshInstance3D.new()
	mi.name = part_name
	mi.mesh = b.build()
	add_child(mi)


# --- Shape helpers -----------------------------------------------------------------

## Box from min to max corner (weapon space).
static func _box(b: MeshBuilder, key: StringName, mn: Vector3, mx: Vector3, bevel: float = 0.003) -> void:
	b.box_mm(key, mn, mx, bevel)


## Side profile (points in (z, y), convex, in order) extruded to half-width hw in X.
static func _prism(b: MeshBuilder, key: StringName, profile: PackedVector2Array, hw: float, x0: float = 0.0) -> void:
	var left := PackedVector3Array()
	var right := PackedVector3Array()
	for p: Vector2 in profile:
		left.append(Vector3(x0 - hw, p.y, p.x))
		right.append(Vector3(x0 + hw, p.y, p.x))
	b.poly(key, left, Vector3.LEFT)
	b.poly(key, right, Vector3.RIGHT)
	var n: int = profile.size()
	var center := Vector2.ZERO
	for p: Vector2 in profile:
		center += p
	center /= n
	for i: int in n:
		var j: int = (i + 1) % n
		var mid: Vector2 = (profile[i] + profile[j]) * 0.5
		var out := Vector3(0, mid.y - center.y, mid.x - center.x)
		b.poly(key, PackedVector3Array([left[i], left[j], right[j], right[i]]), out)


## Cylinder along Z from z0 to z1 at (x, y).
static func _tube(b: MeshBuilder, key: StringName, x: float, y: float, z0: float, z1: float, r0: float, r1: float = -1.0, sides: int = 10) -> void:
	b.cylinder(key, Vector3(x, y, z0), Vector3(x, y, z1), r0, r0 if r1 < 0.0 else r1, sides, true, 1.0)


## Banana magazine: top edge from z_front to z_back at y_top, `length` down, the
## bottom swings forward by `curve` metres; `taper` = how much shorter the
## bottom section is (front-to-back).
static func _curved_mag(b: MeshBuilder, key: StringName, z_front: float, z_back: float, y_top: float, length: float,
		curve: float, hw: float, taper: float) -> void:
	var steps: int = 8
	var prev_f := Vector2.ZERO
	var prev_b := Vector2.ZERO
	for i: int in steps + 1:
		var t: float = float(i) / steps
		var shift: float = -curve * t * t
		var y: float = y_top - length * t
		var f := Vector2(z_front + shift, y)
		var bk := Vector2(z_back + shift - taper * t, y)
		if i > 0:
			_prism(b, key, PackedVector2Array([prev_f, prev_b, bk, f]), hw)
		prev_f = f
		prev_b = bk


## Pistol grip slanted backwards (top at y 0, z from zf to zb).
static func _grip(b: MeshBuilder, key: StringName, zf: float, zb: float, length: float, hw: float, slant: float = 0.28) -> void:
	var back: float = length * slant
	_prism(b, key, PackedVector2Array([
		Vector2(zf, 0.0), Vector2(zb, 0.0), Vector2(zb + back, -length), Vector2(zf + back + 0.006, -length)]), hw)


static func _trigger_guard(b: MeshBuilder, zf: float, zb: float, y: float) -> void:
	_box(b, &"gun_metal", Vector3(-0.004, y - 0.004, zf), Vector3(0.004, y, zb), 0.001)
	_box(b, &"gun_metal", Vector3(-0.004, y, zf - 0.004), Vector3(0.004, 0.0, zf), 0.001)
	_box(b, &"gun_metal", Vector3(-0.002, y + 0.008, zb - 0.03), Vector3(0.002, 0.0, zb - 0.024), 0.0)  # trigger


# --- AK-pattern rifle (~0.88 m) ------------------------------------------------------

static func _build_ak(b: MeshBuilder, bolt: MeshBuilder, mag: MeshBuilder) -> void:
	# Receiver with a rounded dust cover.
	_box(b, &"gun_metal", Vector3(-0.024, 0.0, -0.215), Vector3(0.024, 0.066, 0.075))
	_prism(b, &"gun_metal", PackedVector2Array([
		Vector2(-0.215, 0.066), Vector2(0.07, 0.066), Vector2(0.075, 0.074), Vector2(0.06, 0.082), Vector2(-0.2, 0.082)]), 0.021)
	_box(b, &"gun_metal", Vector3(-0.026, 0.066, -0.235), Vector3(0.026, 0.09, -0.205))  # rear sight block
	_box(b, &"gun_metal", Vector3(-0.003, 0.09, -0.225), Vector3(0.003, 0.095, -0.12), 0.0)  # sight leaf
	# Wooden furniture: stock, lower and upper handguard.
	_prism(b, &"gun_wood", PackedVector2Array([
		Vector2(0.075, 0.062), Vector2(0.36, 0.035), Vector2(0.37, 0.025), Vector2(0.37, -0.1),
		Vector2(0.34, -0.11), Vector2(0.075, 0.0)]), 0.021)
	_box(b, &"gun_metal", Vector3(-0.022, -0.112, 0.362), Vector3(0.022, 0.03, 0.375))  # butt plate
	_prism(b, &"gun_wood", PackedVector2Array([
		Vector2(-0.43, 0.02), Vector2(-0.235, 0.02), Vector2(-0.235, 0.062), Vector2(-0.43, 0.058)]), 0.026)
	_box(b, &"gun_wood", Vector3(-0.017, 0.064, -0.42), Vector3(0.017, 0.092, -0.24))
	_grip(b, &"gun_wood", -0.012, 0.03, 0.105, 0.016)
	_trigger_guard(b, -0.07, -0.004, -0.028)
	# Gas tube, barrel, front sight, muzzle brake.
	_tube(b, &"gun_metal", 0, 0.078, -0.42, -0.5, 0.011)
	_box(b, &"gun_metal", Vector3(-0.012, 0.03, -0.5), Vector3(0.012, 0.09, -0.48))  # gas block
	_tube(b, &"gun_metal", 0, 0.042, -0.215, -0.66, 0.011)
	_box(b, &"gun_metal", Vector3(-0.012, 0.03, -0.6), Vector3(0.012, 0.06, -0.58))
	_box(b, &"gun_metal", Vector3(-0.003, 0.06, -0.595), Vector3(0.003, 0.09, -0.585), 0.0)
	_tube(b, &"gun_metal", 0, 0.042, -0.66, -0.7, 0.015)
	# Charging handle on the right (Bolt part).
	_box(bolt, &"gun_metal", Vector3(0.024, 0.05, -0.15), Vector3(0.034, 0.062, -0.13), 0.002)
	_tube(bolt, &"gun_metal", 0.036, 0.056, -0.152, -0.128, 0.007, -1.0, 8)
	# Curved 30-round magazine.
	_curved_mag(mag, &"gun_metal", -0.175, -0.11, 0.0, 0.2, 0.11, 0.015, 0.012)


# --- Compact SMG (~0.6 m) -------------------------------------------------------------

static func _build_smg(b: MeshBuilder, bolt: MeshBuilder, mag: MeshBuilder) -> void:
	_box(b, &"gun_metal", Vector3(-0.022, 0.0, -0.17), Vector3(0.022, 0.05, 0.07))
	_tube(b, &"gun_metal", 0, 0.05, 0.07, -0.25, 0.026, -1.0, 12)  # cocking tube
	_box(b, &"gun_polymer", Vector3(-0.026, -0.006, -0.03), Vector3(0.026, 0.02, 0.07))  # lower
	_grip(b, &"gun_polymer", -0.015, 0.03, 0.1, 0.017)
	_trigger_guard(b, -0.07, -0.006, -0.03)
	_tube(b, &"gun_polymer", 0, 0.035, -0.17, -0.33, 0.03, 0.028, 12)  # handguard
	_tube(b, &"gun_metal", 0, 0.05, -0.25, -0.4, 0.011)
	_tube(b, &"gun_metal", 0, 0.05, -0.38, -0.41, 0.015)
	# Sights: rear drum, front hood.
	_tube(b, &"gun_metal", 0, 0.092, 0.05, 0.03, 0.014)
	_box(b, &"gun_metal", Vector3(-0.004, 0.076, 0.035), Vector3(0.004, 0.09, 0.055))
	_box(b, &"gun_metal", Vector3(-0.012, 0.075, -0.25), Vector3(0.012, 0.095, -0.235))
	# Retracted stock: two rods and a butt plate.
	for x: float in [-0.017, 0.017]:
		_tube(b, &"gun_metal", x, 0.03, 0.07, 0.26, 0.005, -1.0, 6)
	_box(b, &"gun_polymer", Vector3(-0.022, -0.05, 0.255), Vector3(0.022, 0.05, 0.275))
	# Cocking handle on the left front (Bolt part).
	_box(bolt, &"gun_metal", Vector3(-0.04, 0.062, -0.215), Vector3(-0.022, 0.07, -0.2), 0.002)
	# Slightly curved magazine.
	_curved_mag(mag, &"gun_metal", -0.11, -0.07, 0.0, 0.19, 0.035, 0.012, 0.0)


# --- Pump shotgun (~1.0 m) ------------------------------------------------------------

static func _build_shotgun(b: MeshBuilder, bolt: MeshBuilder, _mag: MeshBuilder) -> void:
	_box(b, &"gun_metal", Vector3(-0.023, -0.002, -0.2), Vector3(0.023, 0.068, 0.05))
	_box(b, &"gun_metal", Vector3(-0.0235, 0.012, -0.12), Vector3(-0.022, 0.05, -0.03), 0.0)  # ejection port frame (left side)
	# Wooden stock with a pistol-grip wrist.
	_prism(b, &"gun_wood", PackedVector2Array([
		Vector2(0.05, 0.062), Vector2(0.4, 0.045), Vector2(0.41, 0.035), Vector2(0.41, -0.11),
		Vector2(0.38, -0.12), Vector2(0.11, -0.04), Vector2(0.05, 0.0)]), 0.021)
	_grip(b, &"gun_wood", 0.0, 0.05, 0.08, 0.017, 0.35)
	_box(b, &"gun_polymer", Vector3(-0.022, -0.122, 0.405), Vector3(0.022, 0.04, 0.42))  # recoil pad
	_trigger_guard(b, -0.05, 0.002, -0.03)
	_tube(b, &"gun_metal", 0, 0.05, -0.2, -0.74, 0.012, -1.0, 12)  # barrel
	_tube(b, &"gun_metal", 0, 0.018, -0.2, -0.64, 0.011, -1.0, 10)  # magazine tube
	_box(b, &"gun_metal", Vector3(-0.008, 0.012, -0.645), Vector3(0.008, 0.06, -0.625))  # barrel clamp
	_box(b, &"gun_metal", Vector3(-0.003, 0.062, -0.735), Vector3(0.003, 0.068, -0.729), 0.0)  # bead
	# Pump (Bolt part: slides back towards the shooter).
	_prism(bolt, &"gun_wood", PackedVector2Array([
		Vector2(-0.48, 0.036), Vector2(-0.3, 0.036), Vector2(-0.3, 0.0), Vector2(-0.31, -0.008),
		Vector2(-0.47, -0.008), Vector2(-0.48, 0.0)]), 0.024)


# --- Service pistol (~0.2 m, point 27 art direction: replaces the photo-real model) ---

static func _build_pistol(b: MeshBuilder, slide: MeshBuilder, mag: MeshBuilder) -> void:
	# Polymer frame with a dust-cover rail and a chunky slanted grip.
	_box(b, &"gun_polymer", Vector3(-0.012, 0.0, -0.165), Vector3(0.012, 0.032, 0.03), 0.004)
	_grip(b, &"gun_polymer", -0.022, 0.034, 0.112, 0.016, 0.24)
	_box(b, &"gun_polymer", Vector3(-0.0165, -0.03, -0.012), Vector3(0.0165, -0.006, 0.03), 0.004)  # grip panel bulge
	_box(b, &"gun_polymer", Vector3(-0.013, 0.0, 0.028), Vector3(0.013, 0.03, 0.045), 0.006)  # beavertail
	_trigger_guard(b, -0.07, -0.02, -0.03)
	# Slide (Bolt part: moves back when firing): metal block, a few grooves, sights.
	_box(slide, &"gun_metal", Vector3(-0.0135, 0.032, -0.176), Vector3(0.0135, 0.074, 0.038), 0.004)
	for i: int in 4:
		var z: float = 0.004 + i * 0.008
		_box(slide, &"gun_polymer", Vector3(-0.0142, 0.042, z), Vector3(0.0142, 0.068, z + 0.003), 0.0)
	_box(slide, &"gun_polymer", Vector3(0.0136, 0.05, -0.07), Vector3(0.0142, 0.066, -0.02), 0.0)  # ejection port
	_box(slide, &"gun_metal", Vector3(-0.0025, 0.074, -0.17), Vector3(0.0025, 0.082, -0.16), 0.001)  # front sight
	_box(slide, &"gun_metal", Vector3(-0.012, 0.074, 0.02), Vector3(-0.003, 0.082, 0.03), 0.001)  # rear sight, notch
	_box(slide, &"gun_metal", Vector3(0.003, 0.074, 0.02), Vector3(0.012, 0.082, 0.03), 0.001)
	_tube(slide, &"gun_metal", 0, 0.06, -0.176, -0.18, 0.006, -1.0, 8)  # barrel crown
	# Magazine: seated in the grip, only the base plate shows.
	_prism(mag, &"gun_metal", PackedVector2Array([
		Vector2(-0.016, -0.004), Vector2(0.024, -0.004), Vector2(0.024 + 0.105 * 0.24, -0.108),
		Vector2(-0.016 + 0.105 * 0.24, -0.108)]), 0.011)
	_box(mag, &"gun_polymer", Vector3(-0.015, -0.12, -0.016 + 0.11 * 0.24), Vector3(0.015, -0.108, 0.034 + 0.11 * 0.24), 0.003)
