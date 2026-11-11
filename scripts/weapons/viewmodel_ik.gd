class_name ViewmodelIK
extends SkeletonModifier3D
## First-person arms: both hands grip the weapon with two-bone IK.
## The weapon itself is placed by Viewmodel (recoil, sway, reload tilt); this
## modifier moves the arms to it, turns each hand so it wraps the grip, curls the
## fingers into a fist and makes the hands a bit smaller (the stylized
## characters have large hands that dwarf a real-size pistol). Hides the head.
##
## Global bone poses are not refreshed while modifying, so every new global
## pose is computed here from the animated poses read up front.

## Weapon the hands hold (its markers RightHand / Support give the targets).
var weapon: WeaponModel
## Gives the view axes (+X right on screen, +Y up, -Z forward). The armature
## itself is Z-up, so its own axes are not used.
var frame: Node3D
## Left hand: Vector3.INF = support grip on the weapon; otherwise a free target
## (reload) where the hand keeps a neutral orientation.
var left_target: Vector3 = Vector3.INF
## 0..1 how much the left arm follows (0 = hangs as animated).
var left_weight: float = 1.0
var hand_scale: float = 0.8

const FINGERS: Array[String] = ["Index", "Middle", "Ring", "Pinky"]
## Curl per finger joint 2..4 (radians) for the right fist; the index finger
## stays straighter (on the trigger).
const CURL_RIGHT: Dictionary = {"Index": [0.35, 0.5, 0.3], "Middle": [1.1, 0.9, 0.5],
		"Ring": [1.15, 0.9, 0.5], "Pinky": [1.2, 0.9, 0.5]}
const CURL_LEFT: Dictionary = {"Index": [0.9, 0.8, 0.4], "Middle": [1.0, 0.8, 0.4],
		"Ring": [1.05, 0.8, 0.4], "Pinky": [1.1, 0.8, 0.4]}

var _idx: Dictionary = {}


func _ready() -> void:
	var sk: Skeleton3D = get_skeleton()
	for i: int in sk.get_bone_count():
		_idx[sk.get_bone_name(i)] = i


func _bone(bone_name: String) -> int:
	return _idx.get(bone_name, -1)


func _process_modification_with_delta(_delta: float) -> void:
	var sk: Skeleton3D = get_skeleton()
	if sk == null or _idx.is_empty() or weapon == null or frame == null:
		return
	sk.set_bone_pose_scale(_bone("Head"), Vector3.ONE * 0.001)
	var to_sk: Transform3D = sk.global_transform.affine_inverse()
	var view: Basis = frame.global_basis.orthonormalized()
	var gun: Transform3D = weapon.global_transform.orthonormalized()
	var gb: Basis = gun.basis

	# Right hand: on the grip, back of the hand to the right, knuckles forward.
	var r_pos: Vector3 = gun * weapon.right_hand.position
	var r_fingers: Vector3 = gb * Vector3(0, 0.25, -1).normalized()
	var r_palm: Vector3 = gb * Vector3(-1, 0, 0)
	_solve_arm(sk, ".R", to_sk * r_pos, _to_sk_dir(sk, r_fingers), _to_sk_dir(sk, r_palm),
			_to_sk_dir(sk, -view.y + view.x * 0.6), CURL_RIGHT, 1.0)

	# Left hand: under and around the right fist, or a free target (reload).
	if left_weight > 0.001:
		if left_target == Vector3.INF:
			var l_pos: Vector3 = gun * weapon.support.position
			var l_fingers: Vector3 = gb * weapon.support_fingers.normalized()
			var l_palm: Vector3 = gb * weapon.support_palm.normalized()
			_solve_arm(sk, ".L", to_sk * l_pos, _to_sk_dir(sk, l_fingers), _to_sk_dir(sk, l_palm),
					_to_sk_dir(sk, -view.y - view.x * 0.6), CURL_LEFT, left_weight)
		else:
			var l_fingers2: Vector3 = (view * Vector3(0.3, 0.2, -1)).normalized()
			var l_palm2: Vector3 = view * Vector3(0.7, 0.7, 0).normalized()
			_solve_arm(sk, ".L", to_sk * left_target, _to_sk_dir(sk, l_fingers2), _to_sk_dir(sk, l_palm2),
					_to_sk_dir(sk, -view.y - view.x * 0.6), CURL_LEFT, left_weight)


static func _to_sk_dir(sk: Skeleton3D, dir: Vector3) -> Vector3:
	return (sk.global_basis.inverse() * dir).normalized()


## Two-bone IK for one arm in skeleton space: shoulder fixed, wrist to `target`,
## elbow towards `pole`; then the hand is turned so its fingers point along
## `fingers` with the palm facing `palm`, and the fingers are curled.
func _solve_arm(sk: Skeleton3D, side: String, target: Vector3, fingers: Vector3, palm: Vector3,
		pole: Vector3, curl: Dictionary, weight: float) -> void:
	var ua: int = _bone("UpperArm" + side)
	var la: int = _bone("LowerArm" + side)
	var wr: int = _bone("Wrist" + side)
	# Knuckles (the *1 bones are metacarpals that all start at the wrist).
	var mid: int = _bone("Middle2" + side)
	var idx1: int = _bone("Index2" + side)
	var pinky: int = _bone("Pinky2" + side)
	if ua < 0 or la < 0 or wr < 0 or mid < 0 or idx1 < 0 or pinky < 0:
		return
	# Read every animated global pose first: changing a bone dirties the cache.
	var g_up: Transform3D = sk.get_bone_global_pose(ua)
	var g_lo: Transform3D = sk.get_bone_global_pose(la)
	var g_wr: Transform3D = sk.get_bone_global_pose(wr)
	var g_mid: Vector3 = sk.get_bone_global_pose(mid).origin
	var g_across: Vector3 = sk.get_bone_global_pose(idx1).origin - sk.get_bone_global_pose(pinky).origin
	var parent: int = sk.get_bone_parent(ua)
	var parent_b: Basis = sk.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis.IDENTITY
	var finger_globals: Dictionary = {}
	for f: String in FINGERS:
		for j: int in 4:
			var fb: int = _bone("%s%d%s" % [f, j + 1, side])
			if fb >= 0:
				finger_globals[fb] = sk.get_bone_global_pose(fb).basis.orthonormalized()
	var shoulder: Vector3 = g_up.origin
	var elbow: Vector3 = g_lo.origin
	var hand: Vector3 = g_wr.origin
	var l1: float = shoulder.distance_to(elbow)
	var l2: float = elbow.distance_to(hand)
	var goal: Vector3 = hand.lerp(target, weight)
	var to_goal: Vector3 = goal - shoulder
	var d: float = clampf(to_goal.length(), absf(l1 - l2) + 0.001, l1 + l2 - 0.001)
	var u: Vector3 = to_goal.normalized()
	var v: Vector3 = pole - u * pole.dot(u)
	if v.length() < 0.001:
		return
	v = v.normalized()
	var cos_a: float = clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
	var new_elbow: Vector3 = shoulder + l1 * (cos_a * u + sqrt(1.0 - cos_a * cos_a) * v)
	var new_hand: Vector3 = shoulder + u * d

	var up_b: Basis = g_up.basis.orthonormalized()
	var lo_b: Basis = g_lo.basis.orthonormalized()
	var wr_b: Basis = g_wr.basis.orthonormalized()
	var q1 := Quaternion((elbow - shoulder).normalized(), (new_elbow - shoulder).normalized())
	var up_new: Basis = Basis(q1) * up_b
	var old_fore: Vector3 = (Basis(q1) * (hand - elbow)).normalized()
	var q2 := Quaternion(old_fore, (new_hand - new_elbow).normalized())
	var lo_new: Basis = Basis(q2) * Basis(q1) * lo_b
	sk.set_bone_pose_rotation(ua, (parent_b.inverse() * up_new).get_rotation_quaternion())
	sk.set_bone_pose_rotation(la, (up_new.inverse() * lo_new).get_rotation_quaternion())

	# Hand orientation: the hand's own finger direction / palm normal (from the
	# animated pose, in wrist space) are turned onto the wanted ones.
	var f_local: Vector3 = wr_b.inverse() * (g_mid - hand)
	var across: Vector3 = wr_b.inverse() * g_across
	var n_local: Vector3 = f_local.cross(across)
	if side == ".R":
		n_local = -n_local  # mirrored hand (index-to-pinky runs the other way)
	var from_b: Basis = _frame(f_local, n_local)
	var to_b: Basis = _frame(fingers, palm)
	var wr_new: Basis = (to_b * from_b.inverse()).orthonormalized()
	wr_new = (Basis(Quaternion(wr_b.get_rotation_quaternion())).slerp(wr_new, weight)) if weight < 1.0 else wr_new
	sk.set_bone_pose_rotation(wr, (lo_new.inverse() * wr_new).get_rotation_quaternion())
	sk.set_bone_pose_scale(wr, Vector3.ONE * hand_scale)

	# Curl the fingers towards the palm (rotation about fingers x palm).
	var axis: Vector3 = fingers.cross(palm).normalized()
	for f: String in FINGERS:
		var angles: Array = curl[f]
		var meta: int = _bone("%s1%s" % [f, side])
		if meta < 0:
			continue
		# The metacarpal is not bent; it just turns with the hand.
		var parent_new: Basis = wr_new * (wr_b.inverse() * (finger_globals[meta] as Basis))
		var total: float = 0.0
		for j: int in 3:
			var b: int = _bone("%s%d%s" % [f, j + 2, side])
			if b < 0:
				break
			var g_old: Basis = finger_globals[b]
			# The finger as animated, turned with the hand, then bent by all
			# joints so far (every joint bends about the same axis).
			total += float(angles[j]) * weight
			var g_new: Basis = Basis(axis, total) * (wr_new * (wr_b.inverse() * g_old))
			sk.set_bone_pose_rotation(b, (parent_new.inverse() * g_new).get_rotation_quaternion())
			parent_new = g_new


## Orthonormal basis with X = a, Y = b (made square to a), Z = a x b.
static func _frame(a: Vector3, b: Vector3) -> Basis:
	var x: Vector3 = a.normalized()
	var y: Vector3 = (b - x * b.dot(x)).normalized()
	return Basis(x, y, x.cross(y))


## Weapon transform for a fist at `wrist` on a forearm coming from `lower`:
## barrel along the forearm, grip in the fist. Used for third-person hands.
static func gun_in_fist(lower: Vector3, wrist: Vector3, up_hint: Vector3) -> Transform3D:
	var fwd: Vector3 = (wrist - lower).normalized()
	var up: Vector3 = (up_hint - fwd * up_hint.dot(fwd)).normalized()
	var z: Vector3 = -fwd
	var x: Vector3 = up.cross(z).normalized()
	var origin: Vector3 = wrist + fwd * 0.075 - up * 0.01
	return Transform3D(Basis(x, up, z), origin)


## Debug: prints where the right hand's fingers / palm point (after modification).
func debug_report() -> void:
	var sk: Skeleton3D = get_skeleton()
	await sk.skeleton_updated  # read the pose with the modifications applied
	var t: Transform3D = sk.global_transform
	for side: String in [".R", ".L"]:
		var w: Vector3 = t * sk.get_bone_global_pose(_bone("Wrist" + side)).origin
		var m: Vector3 = t * sk.get_bone_global_pose(_bone("Middle2" + side)).origin
		var i: Vector3 = t * sk.get_bone_global_pose(_bone("Index2" + side)).origin
		var p: Vector3 = t * sk.get_bone_global_pose(_bone("Pinky2" + side)).origin
		var g: Transform3D = weapon.global_transform
		print("[IK] %s wrist(gun)=%s fingers(gun)=%s across(gun)=%s scale=%s" % [side,
				(g.affine_inverse() * w).snapped(Vector3.ONE * 0.001),
				(g.basis.inverse() * (m - w)).normalized().snapped(Vector3.ONE * 0.01),
				(g.basis.inverse() * (i - p)).normalized().snapped(Vector3.ONE * 0.01),
				sk.get_bone_pose_scale(_bone("Wrist" + side))])
