class_name RangeTarget
extends StaticBody3D
## A pop-up target on the shooting range (ShootingRange, local on every peer). A paper target on a hinged plate:
## up = standing, down = flat on the ground. Layer 2 (props) so PlayerCombat's ray hits it; the host's
## `host_damage` / `is_head_hit` (same names as Player/Pedestrian) report hits to RangeClub. Up/down is set by
## RangeClub on every peer (`set_up`).

const PLATE := Vector3(0.6, 0.8, 0.03)
const CENTER_Y: float = 1.05  # the bullseye's height over the hinge's foot
const BULL_RADIUS: float = 0.09

var lane: int = 0
var index: int = 0
var up: bool = true
var _pivot: Node3D
var _plate_shape: CollisionShape3D  # (a direct child of the body: shapes under a plain Node3D don't count)
var _bull: bool = false
var _tween: Tween


func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	var post := MeshBuilder.new()
	post.box(&"metal_dark", Vector3(0, 0.15, 0.15), Vector3(0.7, 0.3, 0.3))  # the steel base (protects the hinge)
	var base := MeshInstance3D.new()
	base.mesh = post.build()
	add_child(base)
	_pivot = Node3D.new()
	_pivot.position = Vector3(0, 0.3, 0)
	add_child(_pivot)
	var b := MeshBuilder.new()
	b.box(&"planks", Vector3(0, 0.2, 0), Vector3(0.05, 0.4, 0.05))
	b.box(&"trim_paint", Vector3(0, CENTER_Y - 0.3, 0), PLATE)
	# Rings (front = +Z, towards the shooters).
	var z: float = PLATE.z * 0.5
	var rings: Array = [[0.27, Color(0.1, 0.1, 0.1)], [0.2, Color(0.95, 0.95, 0.92)], [0.14, Color(0.1, 0.1, 0.1)],
			[BULL_RADIUS, Color(0.85, 0.12, 0.1)]]
	for i: int in rings.size():
		b.color = rings[i][1]
		var front: float = z + 0.002 + i * 0.002
		b.cylinder(&"item_matte", Vector3(0, CENTER_Y - 0.3, front - 0.001), Vector3(0, CENTER_Y - 0.3, front),
				rings[i][0], rings[i][0], 20, true)
	var mi := MeshInstance3D.new()
	mi.mesh = b.build()
	_pivot.add_child(mi)
	_plate_shape = CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = PLATE + Vector3(0, 0, 0.02)
	_plate_shape.shape = shape
	_plate_shape.position = Vector3(0, CENTER_Y, 0)
	_plate_shape.disabled = not up
	add_child(_plate_shape)
	var base_cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.7, 0.3, 0.3)
	base_cs.shape = bs
	base_cs.position = Vector3(0, 0.15, 0.15)
	add_child(base_cs)


## Every peer: stand up / fold down (animated unless `instant`).
func set_up(on: bool, instant: bool = false) -> void:
	if on == up and not instant:
		return
	up = on
	if _plate_shape:
		_plate_shape.disabled = not on  # a folded target lets shots through
	var want: float = 0.0 if on else -PI * 0.5
	if _tween:
		_tween.kill()
	if instant or not is_inside_tree():
		_pivot.rotation.x = want
		return
	_tween = create_tween()
	_tween.tween_property(_pivot, "rotation:x", want, 0.18 if on else 0.12)


## World position of the bullseye (while up).
func center() -> Vector3:
	return _pivot.to_global(Vector3(0, CENTER_Y - 0.3, PLATE.z * 0.5))


## Host (PlayerCombat, per pellet): a hit within BULL_RADIUS of the centre = bullseye.
func is_head_hit(pos: Vector3) -> bool:
	var hit: bool = up and pos.distance_to(center()) <= BULL_RADIUS + 0.01
	_bull = _bull or hit
	return hit


## Host (PlayerCombat): a hit. Targets never "die" (returns false).
func host_damage(_amount: int, attacker: Node = null, _from: Vector3 = Vector3.INF) -> bool:
	var bull: bool = _bull
	_bull = false
	if up and attacker is Player:
		RangeClub.host_hit(self, attacker as Player, bull)
	return false
