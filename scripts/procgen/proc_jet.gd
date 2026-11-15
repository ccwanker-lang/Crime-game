@tool
class_name ProcJet
extends Node3D
## Point 85: a generic single-engine fighter jet (unbranded, plain grey), built in code. Origin on the ground between
## the main wheels (gear down), nose towards -Z. Visual only: `Airfield` moves it; `gear_down` and `burner` switch the
## landing gear and the afterburner flame.

const LENGTH: float = 15.0
const SPAN: float = 9.6
const BODY_Y: float = 2.0  # fuselage axis above the ground with the gear down

@export var tint: Color = Color(0.56, 0.59, 0.63):
	set(v): tint = v; _queue_rebuild()
@export var gear_down: bool = true:
	set(v):
		gear_down = v
		if _gear:
			_gear.visible = v
@export var burner: bool = false:
	set(v):
		burner = v
		if _flame:
			_flame.visible = v

var _generated: Array[Node] = []
var _pending: bool = false
var _gear: MeshInstance3D
var _flame: MeshInstance3D


func _ready() -> void:
	_rebuild()


func _queue_rebuild() -> void:
	if not is_inside_tree() or _pending:
		return
	_pending = true
	_rebuild.call_deferred()


## Loft of 8-sided rings [z, centre y, half width, half height] (nose first).
static func _loft(b: MeshBuilder, key: StringName, rings: Array) -> void:
	var sides: int = 8
	for r: int in range(rings.size() - 1):
		var a: Array = rings[r]
		var c: Array = rings[r + 1]
		for i: int in sides:
			var t0: float = TAU * i / sides + PI / sides
			var t1: float = TAU * (i + 1) / sides + PI / sides
			var p := func(ring: Array, t: float) -> Vector3:
				return Vector3(cos(t) * float(ring[2]), float(ring[1]) + sin(t) * float(ring[3]), float(ring[0]))
			var mid: float = (t0 + t1) / 2.0
			b.quad(key, p.call(a, t0), p.call(a, t1), p.call(c, t1), p.call(c, t0), Vector3(cos(mid), sin(mid), 0))
	# Caps at both ends (flat; the nose ring is tiny).
	for end: int in [0, rings.size() - 1]:
		var ring: Array = rings[end]
		var pts := PackedVector3Array()
		for i: int in sides:
			var t: float = TAU * i / sides + PI / sides
			pts.append(Vector3(cos(t) * float(ring[2]), float(ring[1]) + sin(t) * float(ring[3]), float(ring[0])))
		b.poly(key, pts, Vector3(0, 0, -1.0 if end == 0 else 1.0))


## A thin flat plate (wing, stabiliser) from an outline in its own plane: `u`/`v` axes, `n` = its normal.
static func _plate(b: MeshBuilder, key: StringName, outline: Array, origin: Vector3, u: Vector3, v: Vector3, n: Vector3,
		thick: float) -> void:
	var top := PackedVector3Array()
	var bot := PackedVector3Array()
	for q: Vector2 in outline:
		var p: Vector3 = origin + u * q.x + v * q.y
		top.append(p + n * thick / 2.0)
		bot.append(p - n * thick / 2.0)
	b.poly(key, top, n)
	b.poly(key, bot, -n)
	for i: int in outline.size():
		var j: int = (i + 1) % outline.size()
		var mid: Vector3 = (top[i] + top[j]) / 2.0 - origin
		var side: Vector3 = (mid - n * mid.dot(n)).normalized()
		b.quad(key, top[i], top[j], bot[j], bot[i], side)


func _rebuild() -> void:
	_pending = false
	for n: Node in _generated:
		n.queue_free()
	_generated.clear()
	var y: float = BODY_Y
	var b := MeshBuilder.new()
	b.color = tint
	# Fuselage: a pointed nose, the cockpit hump, a slim tail ending in the nozzle.
	_loft(b, &"item_matte", [[-7.5, y - 0.05, 0.04, 0.04], [-6.6, y - 0.02, 0.32, 0.34], [-5.2, y + 0.02, 0.52, 0.55],
			[-3.6, y + 0.05, 0.62, 0.68], [-1.0, y + 0.0, 0.72, 0.72], [2.0, y + 0.0, 0.72, 0.66],
			[5.2, y + 0.05, 0.62, 0.58], [6.9, y + 0.05, 0.5, 0.5]])
	# Belly intake under the cockpit.
	b.color = tint.darkened(0.15)
	b.box(&"item_matte", Vector3(0, y - 0.8, -0.6), Vector3(1.1, 0.6, 3.6), 0.08)
	b.color = Color(0.08, 0.08, 0.09)
	b.box(&"item_matte", Vector3(0, y - 0.8, -2.42), Vector3(0.9, 0.42, 0.04))
	# Wings (swept leading edge), horizontal stabilisers, the fin.
	b.color = tint
	var wing: Array = [Vector2(0.6, -1.6), Vector2(4.75, 2.2), Vector2(4.75, 3.3), Vector2(0.6, 3.6)]
	for s: float in [-1.0, 1.0]:
		var o: Array = []
		for q: Vector2 in wing:
			o.append(Vector2(q.x * s, q.y))
		if s < 0:
			o.reverse()
		_plate(b, &"item_matte", o, Vector3(0, y - 0.05, 0), Vector3.RIGHT, Vector3.BACK, Vector3.UP, 0.1)
		var stab: Array = [Vector2(0.5 * s, 5.0), Vector2(2.9 * s, 6.6), Vector2(2.9 * s, 7.3), Vector2(0.5 * s, 7.2)]
		if s < 0:
			stab.reverse()
		_plate(b, &"item_matte", stab, Vector3(0, y - 0.1, 0), Vector3.RIGHT, Vector3.BACK, Vector3.UP, 0.08)
		# A missile on each wing tip.
		b.color = Color(0.85, 0.85, 0.82)
		b.cylinder(&"item_matte", Vector3(4.85 * s, y - 0.05, 1.0), Vector3(4.85 * s, y - 0.05, 3.6), 0.09, 0.09, 6)
		b.color = tint
	_plate(b, &"item_matte", [Vector2(3.6, 0.6), Vector2(6.1, 3.2), Vector2(7.0, 3.2), Vector2(7.1, 0.6)],
			Vector3(0, y, 0), Vector3.BACK, Vector3.UP, Vector3.RIGHT, 0.1)
	# Engine nozzle.
	b.color = Color(0.22, 0.22, 0.24)
	b.cylinder(&"metal_dark", Vector3(0, y + 0.05, 6.85), Vector3(0, y + 0.05, 7.7), 0.5, 0.44, 10)
	# Bubble canopy (tinted).
	b.color = Color(0.25, 0.3, 0.38)
	b.xform = Transform3D(Basis.from_scale(Vector3(0.42, 0.42, 1.5)), Vector3(0, y + 0.62, -3.9))
	b.sphere(&"car_glass", Vector3.ZERO, 1.0, 5, 10)
	b.xform = Transform3D.IDENTITY
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = b.build()
	add_child(body)
	_generated.append(body)
	# Landing gear: nose leg + two main legs.
	var g := MeshBuilder.new()
	g.color = Color(0.75, 0.75, 0.75)
	for leg: Vector3 in [Vector3(0, 0, -4.6), Vector3(-1.1, 0, 0.0), Vector3(1.1, 0, 0.0)]:
		g.cylinder(&"item_metal", leg + Vector3(0, 0.35, 0), leg + Vector3(0, y - 0.55, 0), 0.07, 0.07, 6)
		g.color = Color(0.1, 0.1, 0.1)
		g.cylinder(&"car_tire", leg + Vector3(-0.13, 0.35, 0), leg + Vector3(0.13, 0.35, 0), 0.35, 0.35, 10)
		g.color = Color(0.75, 0.75, 0.75)
	_gear = MeshInstance3D.new()
	_gear.name = "Gear"
	_gear.mesh = g.build()
	_gear.visible = gear_down
	add_child(_gear)
	_generated.append(_gear)
	# Afterburner flame (glowing cone behind the nozzle).
	var f := MeshBuilder.new()
	f.color = Color(1.0, 0.55, 0.2)
	f.cylinder(&"lamp_glow", Vector3(0, y + 0.05, 7.7), Vector3(0, y + 0.05, 10.2), 0.4, 0.05, 10)
	_flame = MeshInstance3D.new()
	_flame.name = "Flame"
	_flame.mesh = f.build()
	_flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flame.visible = burner
	add_child(_flame)
	_generated.append(_flame)
