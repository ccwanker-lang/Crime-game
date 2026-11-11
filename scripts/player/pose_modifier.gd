class_name PoseModifier
extends SkeletonModifier3D
## Adds procedural pose changes on top of the playing animation:
## - crouch (0..1): lowers the body, bends the knees forward (two-bone IK so the
##   ankles stay on the feet) and leans the torso forward.
## - pitch (radians, + = look up): bends chest and head so others see where you look.
## - aim (0..1): right arm in the gun-aim pose (sampled from an animation by
##   set_aim_pose), on top of whatever the legs do; kick (0..1) = recoil.
## The Quaternius characters have no crouch animation. In their rig the feet hang
## from the root (IK setup), so lowering "Body" leaves the feet planted and the
## legs are solved towards them.
##
## Global bone poses are not refreshed while modifying, so everything is computed
## from the animated pose read up front.

const CROUCH_DROP: float = 0.42  # metres the body goes down at full crouch
const LEAN_ANGLE: float = deg_to_rad(24.0)
const BONES: Array[String] = ["Body", "Hips", "Abdomen", "Torso", "Chest", "Neck", "Head",
		"UpperLeg.L", "UpperLeg.R", "LowerLeg.L", "LowerLeg.R", "Foot.L", "Foot.R"]

var crouch: float = 0.0
var pitch: float = 0.0
var aim: float = 0.0
var kick: float = 0.0

## bone index -> local rotation of the aim pose
var _aim_pose: Dictionary = {}

var _idx: Dictionary = {}  # bone name -> index


func _ready() -> void:
	var sk: Skeleton3D = get_skeleton()
	if sk == null:
		return
	for b: String in BONES:
		_idx[b] = sk.find_bone(b)


## Stores the right-arm rotations of `anim` at `time` as the aim pose.
func set_aim_pose(anim: Animation, time: float) -> void:
	var sk: Skeleton3D = get_skeleton()
	_aim_pose.clear()
	for t: int in anim.get_track_count():
		if anim.track_get_type(t) != Animation.TYPE_ROTATION_3D:
			continue
		var bone_name: String = str(anim.track_get_path(t).get_concatenated_subnames())
		if bone_name.ends_with(".R") and not bone_name.begins_with("UpperLeg") 				and not bone_name.begins_with("LowerLeg") and not bone_name.begins_with("Foot") 				and not bone_name.begins_with("PT"):
			var b: int = sk.find_bone(bone_name)
			if b >= 0:
				_aim_pose[b] = anim.rotation_track_interpolate(t, time)


func _process_modification_with_delta(_delta: float) -> void:
	var sk: Skeleton3D = get_skeleton()
	if sk == null or _idx.is_empty():
		return
	if aim > 0.001:
		for b: int in _aim_pose:
			sk.set_bone_pose_rotation(b, sk.get_bone_pose_rotation(b).slerp(_aim_pose[b], aim))
	if crouch < 0.001 and absf(pitch) < 0.001 and kick < 0.001:
		return
	# Character axes in skeleton space (the armature is Z-up and scaled x100).
	var to_sk: Basis = sk.global_basis.inverse()
	var body: Basis = _body_basis()
	var right: Vector3 = (to_sk * body.x).normalized()
	var forward: Vector3 = (to_sk * -body.z).normalized()

	# Animated global poses, read before changing anything.
	var g: Dictionary = {}
	for b: String in BONES:
		if _idx[b] >= 0:
			g[b] = sk.get_bone_global_pose(_idx[b])

	# Upper body: lean (crouch) and look up/down. Every bend is around `right`, so
	# a bone's total extra rotation is the sum of its own and its parents' in the chain.
	# Aiming: the chest takes most of the pitch, so the gun arm points where you look.
	var chest_pitch: float = pitch * lerpf(0.45, 0.85, aim) + kick * 0.12
	var neck_pitch: float = pitch * lerpf(0.2, 0.05, aim)
	var head_pitch: float = pitch * lerpf(0.35, 0.1, aim) - kick * 0.08
	var chain: Array = [["Abdomen", "Hips", -LEAN_ANGLE * crouch], ["Chest", "Torso", chest_pitch],
			["Neck", "Chest", neck_pitch], ["Head", "Neck", head_pitch]]
	var total: float = 0.0
	for link: Array in chain:
		var bone: String = link[0]
		var parent_total: float = total
		total += float(link[2])
		if absf(float(link[2])) < 0.0001 or not g.has(bone) or not g.has(link[1]):
			continue
		var new_global: Basis = Basis(right, total) * (g[bone] as Transform3D).basis
		var parent_global: Basis = Basis(right, parent_total) * (g[link[1]] as Transform3D).basis
		sk.set_bone_pose_rotation(_idx[bone], (parent_global.inverse() * new_global).get_rotation_quaternion())

	if crouch < 0.001 or not g.has("Body"):
		return
	# Lower the body (hips + leg roots); the feet stay where the animation put them.
	var drop: Vector3 = to_sk * (Vector3.DOWN * CROUCH_DROP * crouch)
	var body_bone: int = _idx["Body"]
	var root: int = sk.get_bone_parent(body_bone)
	var root_basis: Basis = sk.get_bone_global_pose(root).basis if root >= 0 else Basis.IDENTITY
	sk.set_bone_pose_position(body_bone, sk.get_bone_pose_position(body_bone) + root_basis.inverse() * drop)
	var body_basis: Basis = (g["Body"] as Transform3D).basis
	for side: String in [".L", ".R"]:
		_solve_leg(sk, g, side, drop, forward, body_basis)


## Two-bone IK: hip joint moved by `drop`, ankle stays on the foot, knee bends forward.
func _solve_leg(sk: Skeleton3D, g: Dictionary, side: String, drop: Vector3, forward: Vector3, body_basis: Basis) -> void:
	if not (g.has("UpperLeg" + side) and g.has("LowerLeg" + side) and g.has("Foot" + side)):
		return
	var thigh: Transform3D = g["UpperLeg" + side]
	var shin: Transform3D = g["LowerLeg" + side]
	var hip: Vector3 = thigh.origin
	var knee: Vector3 = shin.origin
	var ankle: Vector3 = (g["Foot" + side] as Transform3D).origin
	var l1: float = hip.distance_to(knee)
	var l2: float = knee.distance_to(ankle)
	var new_hip: Vector3 = hip + drop
	var to_ankle: Vector3 = ankle - new_hip
	var d: float = clampf(to_ankle.length(), absf(l1 - l2) + 0.001, l1 + l2 - 0.001)
	var u: Vector3 = to_ankle.normalized()
	var v: Vector3 = forward - u * forward.dot(u)  # knee direction: forward, square to the leg
	if v.length() < 0.001:
		return
	v = v.normalized()
	var cos_hip: float = clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
	var new_knee: Vector3 = new_hip + l1 * (cos_hip * u + sqrt(1.0 - cos_hip * cos_hip) * v)

	var q1 := Quaternion((knee - hip).normalized(), (new_knee - new_hip).normalized())
	var thigh_new: Basis = Basis(q1) * thigh.basis
	var old_shin_dir: Vector3 = (Basis(q1) * (ankle - knee)).normalized()
	var q2 := Quaternion(old_shin_dir, (ankle - new_knee).normalized())
	var shin_new: Basis = Basis(q2) * thigh_new * (thigh.basis.inverse() * shin.basis)
	# The Body bone only moved, so its rotation (the thigh's parent) is unchanged.
	sk.set_bone_pose_rotation(_idx["UpperLeg" + side], (body_basis.inverse() * thigh_new).get_rotation_quaternion())
	sk.set_bone_pose_rotation(_idx["LowerLeg" + side], (thigh_new.inverse() * shin_new).get_rotation_quaternion())


## The basis of the body this skeleton belongs to (Player), for its axes.
func _body_basis() -> Basis:
	var n: Node = self
	while n != null and not n is CharacterBody3D:
		n = n.get_parent()
	return (n as Node3D).global_basis if n else Basis.IDENTITY
