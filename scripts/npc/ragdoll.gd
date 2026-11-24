class_name Ragdoll
extends SkeletonModifier3D
## Cosmetic ragdoll for the Quaternius characters (NPCs and players). Runs
## locally on every peer when someone dies: one RigidBody3D capsule per body
## part, joined with ConeTwistJoint3D, and every frame the skeleton bones are
## put where the bodies are. Bodies only collide with the world (layer 1), so
## they never block players, NPCs or bullets.
##
## The bodies live in a container under the world (not under the character),
## so whatever the character node does afterwards (net smoothing, respawn
## teleport) doesn't drag the body along. stop() removes everything.
##
## Usage: var r := Ragdoll.new(); skeleton.add_child(r) (after other modifiers);
## r.start(velocity); r.push(impulse, at).

## Feet hang from the root bone in these rigs (IK feet): they follow the lower leg.
const FEET: Dictionary = {"Foot.L": "LowerLeg.L", "Foot.R": "LowerLeg.R"}
## Seconds until the bodies freeze (lying still, no CPU cost).
const SETTLE_TIME: float = 7.0

## [bone, tip bone(s) (first that exists; "" = along the bone), radius, mass, parent bone]
const PARTS: Array = [
	["Body", ["Abdomen"], 0.13, 12.0, ""],
	["Abdomen", ["Torso"], 0.12, 8.0, "Body"],
	["Torso", ["Neck"], 0.13, 14.0, "Abdomen"],
	["Head", [""], 0.11, 5.0, "Torso"],
	["UpperArm.L", ["LowerArm.L"], 0.05, 2.5, "Torso"],
	["LowerArm.L", ["Wrist.L", "Palm.L"], 0.045, 1.5, "UpperArm.L"],
	["UpperArm.R", ["LowerArm.R"], 0.05, 2.5, "Torso"],
	["LowerArm.R", ["Wrist.R", "Palm.R"], 0.045, 1.5, "UpperArm.R"],
	["UpperLeg.L", ["LowerLeg.L"], 0.075, 8.0, "Body"],
	["LowerLeg.L", ["Foot.L"], 0.06, 4.0, "UpperLeg.L"],
	["UpperLeg.R", ["LowerLeg.R"], 0.075, 8.0, "Body"],
	["LowerLeg.R", ["Foot.R"], 0.06, 4.0, "UpperLeg.R"],
]

var running: bool = false
var _container: Node3D
## bone index -> RigidBody3D, and the bone's transform in that body's space.
var _bodies: Dictionary = {}
var _offsets: Dictionary = {}
var _order: Array[int] = []  # simulated bones, parents first
var _feet: Dictionary = {}  # foot bone -> [lower leg bone, foot in lower-leg space]
var _time: float = 0.0


func _ready() -> void:
	active = false
	set_process(false)  # point 90: only a falling ragdoll needs _process (73 living NPCs ran it for nothing)


## Builds the bodies from the current pose and lets go. `velocity`: start speed.
func start(velocity: Vector3 = Vector3.ZERO) -> void:
	if running:
		return
	var sk: Skeleton3D = get_skeleton()
	if sk == null or not is_inside_tree():
		return
	running = true
	set_process(true)
	_time = 0.0
	_container = Node3D.new()
	_container.name = "Ragdoll"
	var world: Node = get_tree().current_scene if get_tree().current_scene else get_tree().root
	world.add_child(_container)
	var sk_xf: Transform3D = sk.global_transform
	for part: Array in PARTS:
		var bone: int = sk.find_bone(part[0])
		if bone < 0:
			continue
		var w: Transform3D = sk_xf * sk.get_bone_global_pose(bone)
		var p0: Vector3 = w.origin
		var p1: Vector3 = Vector3.INF
		for tip: String in part[1]:
			if tip == "":
				p1 = p0 + w.basis.y.normalized() * 0.22
				break
			var t: int = sk.find_bone(tip)
			if t >= 0:
				p1 = sk_xf * sk.get_bone_global_pose(t).origin
				break
		if p1 == Vector3.INF:
			continue
		var r: float = part[2]
		var seg: Vector3 = p1 - p0
		var length: float = maxf(seg.length(), 0.12)
		var dir: Vector3 = seg.normalized() if seg.length() > 0.001 else Vector3.UP
		var body := RigidBody3D.new()
		body.name = part[0]
		body.mass = part[3]
		body.collision_layer = 0
		body.collision_mask = 1
		body.linear_damp = 0.1
		body.angular_damp = 1.5
		var shape := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = r
		cap.height = length + 2.0 * r
		shape.shape = cap
		body.add_child(shape)
		_container.add_child(body)
		body.global_transform = Transform3D(_basis_along(dir, Vector3.UP), (p0 + p0 + dir * length) * 0.5)
		body.linear_velocity = velocity
		_bodies[bone] = body
		_offsets[bone] = body.global_transform.affine_inverse() * w
		_order.append(bone)
		var parent: int = sk.find_bone(part[4]) if part[4] != "" else -1
		if _bodies.has(parent):
			var joint := ConeTwistJoint3D.new()
			_container.add_child(joint)
			# Twist axis (X) along the child bone.
			joint.global_transform = Transform3D(_basis_along(dir, Vector3.RIGHT), p0)
			joint.set_param(ConeTwistJoint3D.PARAM_SWING_SPAN, deg_to_rad(50.0))
			joint.set_param(ConeTwistJoint3D.PARAM_TWIST_SPAN, deg_to_rad(25.0))
			joint.node_a = joint.get_path_to(_bodies[parent])
			joint.node_b = joint.get_path_to(body)
	_order.sort()  # bone indices are ordered parents first
	for foot: String in FEET:
		var f: int = sk.find_bone(foot)
		var leg: int = sk.find_bone(FEET[foot])
		if f >= 0 and _bodies.has(leg):
			_feet[f] = [leg, sk.get_bone_global_pose(leg).affine_inverse() * sk.get_bone_global_pose(f)]
	active = true


## Kicks the body part closest to `at` (world) with `impulse` (N*s).
func push(impulse: Vector3, at: Vector3) -> void:
	if not running or impulse == Vector3.ZERO:
		return
	var best: RigidBody3D = null
	for b: RigidBody3D in _bodies.values():
		if best == null or b.global_position.distance_to(at) < best.global_position.distance_to(at):
			best = b
	if best:
		best.freeze = false
		best.apply_impulse(impulse, at - best.global_position)


## Lowest point of the head body (tests), INF if not running.
func head_height() -> float:
	var sk: Skeleton3D = get_skeleton()
	var head: int = sk.find_bone("Head") if sk else -1
	return (_bodies[head] as RigidBody3D).global_position.y if _bodies.has(head) else INF


func stop() -> void:
	running = false
	active = false
	if is_instance_valid(_container):
		_container.queue_free()
	_container = null
	_bodies.clear()
	_offsets.clear()
	_order.clear()
	_feet.clear()


func _exit_tree() -> void:
	stop()


func _process(delta: float) -> void:
	if not running:
		return
	_time += delta
	if _time > SETTLE_TIME:
		for b: RigidBody3D in _bodies.values():
			if not b.freeze:
				b.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
				b.freeze = true
		set_process(false)  # settled: nothing left to do per frame


func _process_modification() -> void:
	var sk: Skeleton3D = get_skeleton()
	if sk == null or not running:
		return
	var inv: Transform3D = sk.global_transform.affine_inverse()
	for bone: int in _order:
		var body: RigidBody3D = _bodies[bone]
		if is_instance_valid(body):
			sk.set_bone_global_pose(bone, inv * body.global_transform * (_offsets[bone] as Transform3D))
	for f: int in _feet:
		var leg: int = _feet[f][0]
		sk.set_bone_global_pose(f, sk.get_bone_global_pose(leg) * (_feet[f][1] as Transform3D))


## A basis whose `axis` (Vector3.UP = Y, Vector3.RIGHT = X) points along `dir`.
static func _basis_along(dir: Vector3, axis: Vector3) -> Basis:
	var d: Vector3 = dir.normalized()
	if axis.dot(d) < -0.9999:  # exactly opposite: any half turn
		var perp: Vector3 = Vector3.FORWARD if absf(axis.dot(Vector3.FORWARD)) < 0.9 else Vector3.UP
		return Basis(perp, PI)
	return Basis(Quaternion(axis, d))
