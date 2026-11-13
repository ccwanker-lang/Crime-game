class_name ProcDog
extends Node3D
## Point 46 (park): a low-poly dog on a lead, built in code (MeshBuilder, item_matte vertex
## colours). Purely visual and local on every peer: it is a child of its owner (a
## ParkGoer with role DOG), follows the owner's synced position on its own (top level),
## swings its legs with its speed, wags its tail and sniffs the ground when the owner
## stands still. A thin lead runs from the owner's hand to the collar. No network sync.

const COATS: Array[Color] = [
	Color(0.45, 0.28, 0.14), Color(0.08, 0.07, 0.07), Color(0.86, 0.82, 0.74),
	Color(0.78, 0.55, 0.24), Color(0.35, 0.33, 0.32),
]
const MAX_SPEED: float = 4.0
## Where the dog likes to walk, relative to its owner (right side, a bit ahead).
const SIDE: Vector3 = Vector3(0.75, 0.0, -0.55)

var coat: Color = COATS[0]
var _owner3d: Node3D
var _body: Node3D
var _head: Node3D
var _legs: Array[Node3D] = []
var _tail: Node3D
var _lead: MeshInstance3D
var _phase: float = 0.0
var _speed: float = 0.0
var _last: Vector3 = Vector3.INF
var _sniff: float = 0.0


func setup(owner3d: Node3D, seed_value: int) -> void:
	_owner3d = owner3d
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	coat = COATS[rng.randi() % COATS.size()]
	var s: float = rng.randf_range(0.85, 1.15)
	scale = Vector3.ONE * s


func _ready() -> void:
	name = "Dog"
	top_level = true
	_build()
	if _owner3d:
		global_position = _owner3d.global_position + _owner3d.global_basis * SIDE
	_last = global_position


func _build() -> void:
	var dark: Color = coat.darkened(0.35)
	# Body + head (one pivot each so the head can dip to sniff).
	_body = Node3D.new()
	add_child(_body)
	var b := MeshBuilder.new()
	b.color = coat
	b.box(&"item_matte", Vector3(0, 0.40, 0), Vector3(0.22, 0.2, 0.52), 0.04)
	b.box(&"item_matte", Vector3(0, 0.46, -0.24), Vector3(0.2, 0.16, 0.12), 0.03)  # chest
	b.color = Color(0.7, 0.12, 0.1)
	b.box(&"item_matte", Vector3(0, 0.5, -0.29), Vector3(0.16, 0.05, 0.05))  # collar
	_body.add_child(_mesh(b))
	_head = Node3D.new()
	_head.position = Vector3(0, 0.52, -0.3)
	_body.add_child(_head)
	var h := MeshBuilder.new()
	h.color = coat
	h.box(&"item_matte", Vector3(0, 0.07, -0.06), Vector3(0.16, 0.15, 0.16), 0.03)
	h.box(&"item_matte", Vector3(0, 0.03, -0.18), Vector3(0.09, 0.08, 0.12), 0.02)  # snout
	h.color = Color(0.05, 0.04, 0.04)
	h.box(&"item_matte", Vector3(0, 0.06, -0.245), Vector3(0.04, 0.03, 0.02))  # nose
	h.box(&"item_matte", Vector3(-0.045, 0.1, -0.142), Vector3(0.02, 0.02, 0.01))  # eyes
	h.box(&"item_matte", Vector3(0.045, 0.1, -0.142), Vector3(0.02, 0.02, 0.01))
	h.color = dark
	h.box(&"item_matte", Vector3(-0.07, 0.15, -0.03), Vector3(0.04, 0.08, 0.06))  # ears
	h.box(&"item_matte", Vector3(0.07, 0.15, -0.03), Vector3(0.04, 0.08, 0.06))
	_head.add_child(_mesh(h))
	# Legs: pivots at the hips/shoulders, swung in _process.
	var leg := MeshBuilder.new()
	leg.color = coat
	leg.box(&"item_matte", Vector3(0, -0.14, 0), Vector3(0.06, 0.28, 0.06), 0.015)
	leg.color = dark
	leg.box(&"item_matte", Vector3(0, -0.28, -0.015), Vector3(0.065, 0.03, 0.08))
	var leg_mesh: ArrayMesh = leg.build()
	for p: Vector3 in [Vector3(-0.07, 0.32, -0.2), Vector3(0.07, 0.32, -0.2), Vector3(-0.07, 0.32, 0.2), Vector3(0.07, 0.32, 0.2)]:
		var pivot := Node3D.new()
		pivot.position = p
		_body.add_child(pivot)
		var mi := MeshInstance3D.new()
		mi.mesh = leg_mesh
		pivot.add_child(mi)
		_legs.append(pivot)
	_tail = Node3D.new()
	_tail.position = Vector3(0, 0.46, 0.25)
	_body.add_child(_tail)
	var t := MeshBuilder.new()
	t.color = coat
	t.box(&"item_matte", Vector3(0, 0.06, 0.08), Vector3(0.04, 0.04, 0.18), 0.01)
	var tail_mi: MeshInstance3D = _mesh(t)
	tail_mi.rotation.x = 0.6
	_tail.add_child(tail_mi)
	# The lead: a thin box stretched between hand and collar every frame.
	_lead = MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(0.012, 0.012, 1.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.1, 0.35)
	mat.roughness = 0.9
	lm.material = mat
	_lead.mesh = lm
	_lead.top_level = true
	_lead.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_lead)


func _mesh(b: MeshBuilder) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = b.build()
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mi.visibility_range_end = 70.0
	return mi


func _process(delta: float) -> void:
	if _owner3d == null or not is_instance_valid(_owner3d):
		queue_free()
		return
	var dead: bool = _owner3d.get("dead") == true
	var want: Vector3 = _owner3d.global_position + _owner3d.global_basis * SIDE
	var to := Vector3(want.x - global_position.x, 0, want.z - global_position.z)
	var d: float = to.length()
	if d > 8.0:
		global_position = want  # (teleported owner)
		to = Vector3.ZERO
		d = 0.0
	var step: float = minf(d, MAX_SPEED * delta * clampf(d * 2.0, 0.0, 1.0))
	if d > 0.05 and not dead:
		global_position += to / d * step
		var yaw: float = atan2(-to.x, -to.z)
		rotation.y = lerp_angle(rotation.y, yaw, minf(1.0, 8.0 * delta))
	global_position.y = _owner3d.global_position.y
	# Speed from how far it really moved (same on host and clients).
	var moved: float = Vector2(global_position.x - _last.x, global_position.z - _last.z).length()
	_last = global_position
	_speed = lerpf(_speed, moved / maxf(delta, 0.001), minf(1.0, 6.0 * delta))
	_phase += delta * (4.0 + _speed * 7.0)
	var swing: float = clampf(_speed / 1.5, 0.0, 1.0) * 0.6
	for i: int in _legs.size():
		var opposite: float = 0.0 if i in [0, 3] else PI
		_legs[i].rotation.x = sin(_phase + opposite) * swing
	_tail.rotation.y = sin(_phase * 2.2) * (0.6 if _speed < 0.3 else 0.3)
	# Standing still: now and then the nose goes down to sniff.
	if _speed < 0.2:
		_sniff = minf(1.0, _sniff + delta * 0.8) if int(Time.get_ticks_msec() / 2500 + get_instance_id()) % 3 == 0 \
				else maxf(0.0, _sniff - delta * 1.5)
	else:
		_sniff = maxf(0.0, _sniff - delta * 2.0)
	_head.rotation.x = -0.7 * _sniff
	_body.position.y = absf(sin(_phase)) * 0.015 * swing
	_update_lead()


func _update_lead() -> void:
	var hand: Vector3 = _owner3d.global_position + _owner3d.global_basis * Vector3(0.28, 0.95, -0.1)
	var collar: Vector3 = to_global(Vector3(0, 0.5, -0.29))
	var span: Vector3 = collar - hand
	var length: float = span.length()
	if length < 0.05:
		_lead.visible = false
		return
	_lead.visible = true
	# A lead hangs a little: aim at a point slightly below the middle.
	var mid: Vector3 = (hand + collar) / 2.0 + Vector3.DOWN * 0.08
	_lead.global_transform = Transform3D(Basis.looking_at(span.normalized(), Vector3.UP if absf(span.normalized().y) < 0.95 else Vector3.RIGHT), mid)
	_lead.scale = Vector3(1, 1, length)
