class_name PoliceOfficer
extends Pedestrian
## Point 10: a police officer (basic police, milestone 2). Patrols on foot around its
## station (or drives a police car, see Car.police). HOST AUTHORITATIVE AI:
## - Crimes are reported to the group "police" (report_crime): a player who fires a
##   gun (heard within HEAR_RANGE) or kills someone (MURDER_RANGE).
## - The officer runs to the spot, and as soon as it sees the culprit (line of sight,
##   SIGHT_RANGE) it stops, aims and shoots until the culprit is dead or gone.
## - Not seen for SEARCH_TIME seconds: it gives up and patrols again.
## - Shooting at an officer makes you its target as well.
## Later (heat system): wanted levels, arrests, bribes.

const UNIFORM: Dictionary = {
	"White": Color(0.55, 0.68, 0.85),       # shirt: light blue
	"Red_Dark": Color(0.07, 0.1, 0.2),      # jacket: navy
	"LightBrown": Color(0.06, 0.07, 0.12),  # trousers: dark navy
	"LightBlue": Color(0.05, 0.05, 0.05),   # shoes: black
}
const VARIANT: int = 7  # man_longsleeve (CharacterArmature: gun animations)
const HEAR_RANGE: float = 45.0
const MURDER_RANGE: float = 70.0
const SIGHT_RANGE: float = 32.0
const SEARCH_TIME: float = 25.0
const PATROL_RADIUS: float = 45.0
const FIRE_INTERVAL: float = 0.75
const REACTION_TIME: float = 0.6
const DAMAGE: int = 12
const SPREAD: float = 0.045  # radians
const SIGHT_MASK: int = 1 | 2  # world, doors/cars
const HIT_MASK: int = 1 | 2 | 4 | 8
## Cap position relative to the head bone (metres), tuned with the screenshot tour.
const CAP_OFFSET: Vector3 = Vector3(0, 0.0, 0)

## Host: who we are after (null = nobody) and where we last saw / heard them.
var target: Player = null
var last_known: Vector3 = Vector3.INF
## Host: where the officer patrols around (its station, or its car).
var home: Vector3 = Vector3.INF
## Host: set by a police car whose driver got out: don't patrol, the car calls it back.
var from_car: Node3D = null

var _gun: WeaponModel
var _skeleton: Skeleton3D
var _bone_lower_r: int = -1
var _bone_wrist_r: int = -1
var _search_until: float = 0.0
var _next_shot: float = 0.0
var _seen: bool = false
var _pistol: WeaponData


func uniform_colors() -> Dictionary:
	return UNIFORM


func _ready() -> void:
	ambient = false
	super._ready()
	add_to_group(&"police")
	_pistol = ItemDB.get_item(&"pistol") as WeaponData
	_build_gear()
	if _is_host():
		if home == Vector3.INF:
			home = global_position
		_brain.call_deferred()


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


# --- Looks: cap + pistol (every peer) ---------------------------------------------------

func _build_gear() -> void:
	var model: Node3D = get_node_or_null("Model") as Node3D
	if model == null:
		return
	_skeleton = model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var head: int = _skeleton.find_bone("Head")
	if head >= 0:
		var att := BoneAttachment3D.new()
		att.bone_idx = head
		_skeleton.add_child(att)
		var cap := MeshInstance3D.new()
		cap.mesh = _cap_mesh()
		# Bone space may be scaled (model scale, armature import scale): cap in metres.
		var s: float = maxf(0.001, _skeleton.global_basis.get_scale().x / global_basis.get_scale().x)
		cap.scale = Vector3.ONE / s
		cap.position = CAP_OFFSET / s
		att.add_child(cap)
	if _pistol and _pistol.model_scene:
		_gun = _pistol.model_scene.instantiate() as WeaponModel
		_gun.name = "Gun"
		_gun.visible = false
		add_child(_gun)
		WeaponFX.make_flash(_gun.muzzle, false)
		_bone_lower_r = _skeleton.find_bone("LowerArm.R")
		_bone_wrist_r = _skeleton.find_bone("Wrist.R")
		_skeleton.skeleton_updated.connect(_place_gun)


static var _cap_cache: ArrayMesh


## Navy police cap with a black visor and a small badge (origin = head bone).
static func _cap_mesh() -> ArrayMesh:
	if _cap_cache:
		return _cap_cache
	var b := MeshBuilder.new()
	b.color = Color(0.07, 0.09, 0.18)
	b.cylinder(&"item_matte", Vector3(0, 0.17, 0), Vector3(0, 0.25, 0), 0.115, 0.13, 14, true)
	b.color = Color(0.03, 0.03, 0.03)
	b.box(&"item_glossy", Vector3(0, 0.175, 0.13), Vector3(0.2, 0.015, 0.09))
	b.cylinder(&"item_matte", Vector3(0, 0.165, 0), Vector3(0, 0.185, 0), 0.118, 0.118, 14, false)
	b.color = Color(0.85, 0.7, 0.25)
	b.box(&"item_metal", Vector3(0, 0.215, 0.125), Vector3(0.04, 0.04, 0.012))
	_cap_cache = b.build()
	return _cap_cache


func _place_gun() -> void:
	if _gun == null or not _gun.visible or _bone_wrist_r < 0 or not is_inside_tree():
		return
	var t: Transform3D = _skeleton.global_transform
	var lower: Vector3 = t * _skeleton.get_bone_global_pose(_bone_lower_r).origin
	var wrist: Vector3 = t * _skeleton.get_bone_global_pose(_bone_wrist_r).origin
	_gun.global_transform = ViewmodelIK.gun_in_fist(lower, wrist, global_basis.y)


func _anim_changed() -> void:
	if _gun:
		_gun.visible = anim_state in [Anim.AIM, Anim.RUN_GUN] and not dead


func _go_limp() -> void:
	super._go_limp()
	if _gun:
		_gun.visible = false


func _move_speed() -> float:
	return RUN_SPEED if anim_state == Anim.RUN_GUN else WALK_SPEED


# --- Crimes (host) ---------------------------------------------------------------------

## Host (group "police"): `culprit` fired a gun at `origin` (murder = somebody died).
func report_crime(culprit: Player, origin: Vector3, murder: bool) -> void:
	if not _is_host() or dead or culprit == null or culprit.dead or not is_inside_tree():
		return
	if global_position.distance_to(origin) > (MURDER_RANGE if murder else HEAR_RANGE):
		return
	if target != null and target != culprit and is_instance_valid(target) and not target.dead:
		return  # busy with someone else
	_alert(culprit, origin)


func _alert(culprit: Player, at: Vector3) -> void:
	if target != culprit:
		print("[Police] %s goes after %s" % [name, culprit.player_name])
		_next_shot = _now() + REACTION_TIME
	target = culprit
	last_known = at
	_search_until = _now() + SEARCH_TIME


func hear_gunshot(_origin: Vector3, _hit: bool = false) -> void:
	pass  # officers don't flee; report_crime tells them who fired


func host_damage(amount: int, attacker: Node = null, from: Vector3 = Vector3.INF) -> bool:
	if not _is_host() or dead or amount <= 0:
		return false
	health = maxi(0, health - amount)
	if attacker is Player:
		_alert(attacker as Player, (attacker as Player).global_position)
	if health > 0:
		return false
	_die(from)
	return true


func _on_died(world: Node) -> void:
	target = null
	if from_car == null and world and world.has_method("respawn_officer_later"):
		world.call("respawn_officer_later", respawn_time)


## Can the officer see `p` (in range, nothing solid in between)?
func can_see(p: Player) -> bool:
	var eye: Vector3 = global_position + Vector3.UP * 1.6
	var chest: Vector3 = p.global_position + Vector3.UP * 1.2
	if eye.distance_to(chest) > SIGHT_RANGE:
		return false
	var q := PhysicsRayQueryParameters3D.create(eye, chest, SIGHT_MASK, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


# --- Brain (host) ----------------------------------------------------------------------

func _brain() -> void:
	await get_tree().create_timer(randf_range(0.2, 1.5)).timeout
	while is_inside_tree() and not dead:
		_think()
		await get_tree().create_timer(0.2).timeout


func _think() -> void:
	if target != null and (not is_instance_valid(target) or target.dead or not target.is_inside_tree()):
		target = null
		if _moving:
			_finish_move(false)
	if target == null:
		_patrol()
		return
	if can_see(target):
		_seen = true
		last_known = target.global_position
		_search_until = _now() + SEARCH_TIME
		if _moving:
			_finish_move(false)
		anim_state = Anim.AIM
		var d: Vector3 = target.global_position - global_position
		rotation.y = atan2(-d.x, -d.z)
		net_yaw = rotation.y
		if _now() >= _next_shot:
			_next_shot = _now() + FIRE_INTERVAL * randf_range(0.8, 1.3)
			_shoot_at(target)
		return
	if _now() > _search_until:
		print("[Police] %s lost %s" % [name, target.player_name])
		target = null
		_seen = false
		anim_state = Anim.IDLE
		return
	# Run to where the culprit was last seen / heard.
	if global_position.distance_to(last_known) > 1.5:
		if not _moving or agent.target_position.distance_to(last_known) > 2.0:
			_go(last_known, Anim.RUN_GUN)
	elif not _moving:
		anim_state = Anim.AIM
		rotation.y += 0.8  # look around
		net_yaw = rotation.y


func _patrol() -> void:
	if _moving or from_car != null:
		return
	if anim_state in [Anim.AIM, Anim.RUN_GUN]:
		anim_state = Anim.IDLE
	if randf() < 0.08:
		var p: Vector3 = Vector3.INF
		for i: int in 4:
			var c: Vector3 = random_sidewalk_point(self, 20)
			if c != Vector3.INF and c.distance_to(home) < PATROL_RADIUS:
				p = c
				break
		if p != Vector3.INF:
			_go(p, Anim.WALK)


## Host: one shot at `p` (with spread), damage + effects for everyone.
func _shoot_at(p: Player) -> void:
	var origin: Vector3 = global_position + Vector3.UP * 1.45 - global_basis.z * 0.45
	var aim: Vector3 = p.global_position + Vector3.UP * randf_range(0.9, 1.5)
	var dir: Vector3 = PlayerCombat._cone((aim - origin).normalized(), SPREAD)
	var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * 80.0, HIT_MASK, [get_rid()])
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	var end: Vector3 = origin + dir * 80.0
	var normal: Vector3 = Vector3.UP
	var surface: String = ""
	if not hit.is_empty():
		end = hit["position"]
		normal = hit["normal"]
		surface = WeaponFX.surface_of(hit["collider"])
		var victim: Node = hit["collider"]
		if victim.has_method("host_damage") and not victim is PoliceOfficer:
			var killed: bool = victim.call("host_damage", DAMAGE, self, origin)
			print("[Police] %s hit %s%s" % [name, victim.get("player_name") if victim is Player else victim.name,
					" - killed" if killed else ""])
	get_tree().call_group(&"npc", "hear_gunshot", origin)
	_shot_fx(origin, end, normal, surface)
	for peer: int in Net.peers_in_world:
		_shot_fx.rpc_id(peer, origin, end, normal, surface)


@rpc("authority", "call_remote", "unreliable")
func _shot_fx(origin: Vector3, end: Vector3, normal: Vector3, surface: String) -> void:
	if _gun:
		_gun.visible = true
		_gun.cycle(false)
		WeaponFX.flash(_gun.muzzle)
	if _pistol and not _pistol.shot_sounds.is_empty():
		WeaponFX.play_3d(get_parent(), _pistol.shot_sounds.pick_random(), origin, 4.0 + _pistol.sound_volume_db, 400.0, 0.05,
				_pistol.sound_pitch)
	if surface != "":
		WeaponFX.impact(get_parent(), end, normal, surface)
