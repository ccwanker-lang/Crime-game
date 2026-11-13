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
## Point 25: a culprit who doesn't resist (weapon away, no shots for a few seconds, not
## running off) is not shot but cuffed: the officer walks up and arrests them
## (Player.host_arrest). Officers from a patrol car never go further than LEASH from it.
## Point 28: the wanted level (Wanted, stars per player) decides arrest or shoot
## (`_should_shoot`); heavy teams (4-5 stars) carry an SMG, take more hits, aim better.
## Point 31a: next to `target` (a player) an officer can have a `foe`: an armed NPC of the
## other side (a Crow for the police, an officer for the Crows). Crows that fire are
## reported to the police (report_npc_crime), whoever gets shot fires back and calls its
## mates close by. A player target always goes first.

const UNIFORM: Dictionary = {
	"White": Color(0.55, 0.68, 0.85),       # shirt: light blue
	"Red_Dark": Color(0.07, 0.1, 0.2),      # jacket: navy
	"LightBrown": Color(0.06, 0.07, 0.12),  # trousers: dark navy
	"LightBlue": Color(0.05, 0.05, 0.05),   # shoes: black
}
const HEAVY_UNIFORM: Dictionary = {
	"White": Color(0.16, 0.17, 0.2),        # shirt: dark grey
	"Red_Dark": Color(0.04, 0.05, 0.08),    # vest: black
	"LightBrown": Color(0.05, 0.05, 0.07),
	"LightBlue": Color(0.03, 0.03, 0.03),
}
const HEAVY_PROFILE: NpcCombatProfile = preload("res://data/npc/police_heavy.tres")
const HEAVY_HEALTH: int = 170
const VARIANT: int = 7  # man_longsleeve (CharacterArmature: gun animations)
const HEAR_RANGE: float = 45.0
const MURDER_RANGE: float = 70.0
const SEARCH_TIME: float = 25.0
## Arrest (point 25).
const WARN_TIME: float = 2.5        # after "put your weapon away!" before it counts as resisting
const SHOT_MEMORY: float = 3.0      # fired this recently = resisting
const FLEE_SPEED: float = 4.6       # running off faster than this = resisting
const ARREST_DISTANCE: float = 2.6  # (the navmesh stops ~2.3 m from a player)
const CUFF_TIME: float = 2.0
const LEASH: float = 60.0           # car crews don't chase further than this from their car
const PATROL_RADIUS: float = 80.0
## Point 30: officers stop people for a chat (foot patrols now and then, patrol cars).
const CHAT_RANGE: float = 14.0
static var talk_time: Vector2 = Vector2(6.0, 10.0)  # (tests shorten it)
## Point 21: aim, reaction time, damage, fire rate, bursts (tune data/npc/police_combat.tres).
const DEFAULT_PROFILE: NpcCombatProfile = preload("res://data/npc/police_combat.tres")
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
## Point 28: heavy team (synced at spawn: the SMG and the dark uniform show on every peer).
var heavy: bool = false
## Point 31: weapon item id (synced at spawn); empty = pistol (SMG for heavy teams).
var gun: StringName = &""

var _gun: WeaponModel
var _skeleton: Skeleton3D
var _bone_lower_r: int = -1
var _bone_wrist_r: int = -1
var _search_until: float = 0.0
var _next_shot: float = 0.0
var _burst_left: int = 0
## Combat values (shared resource; tests swap in a sharper one).
var profile: NpcCombatProfile = DEFAULT_PROFILE
var _seen: bool = false
var _seen_now: bool = false  # had the target in sight on the last think
var _warned_at: float = -1.0
var _cuff_time: float = 0.0
var _hostile: Dictionary = {}  # Player -> true: shot at the police, never arrested, always shot
var _last_target_pos: Vector3 = Vector3.INF
var _target_speed: float = 0.0
var _pistol: WeaponData
var _chatting: bool = false
var _next_chat: float = 0.0
## Host (point 31a): the NPC we fight, where we last saw it, and until when we look for it.
var foe: PoliceOfficer = null
var _foe_last: Vector3 = Vector3.INF
var _foe_until: float = 0.0
## Mates this close join a fight against a foe.
const RALLY_RANGE: float = 25.0
## Point 30 (tests/debug): how many chats this officer had.
var chats: int = 0


func uniform_colors() -> Dictionary:
	return HEAVY_UNIFORM if heavy else UNIFORM


## Point 11 hooks (Rival overrides them): its group, its head gear, and players it may not chase.
func _group() -> StringName:
	return &"police"


func _head_mesh() -> ArrayMesh:
	return _cap_mesh()


func _target_off_limits(_p: Player) -> bool:
	return false


func _log(text: String) -> void:
	print("[Police] " + text)


## Point 31 hooks: the chase stops when the target's last spot is further than _leash_range()
## from _leash_center() (INF = no leash). Car crews: their car.
func _leash_center() -> Vector3:
	if from_car != null and is_instance_valid(from_car):
		return from_car.global_position
	return Vector3.INF


func _leash_range() -> float:
	return LEASH


func _ready() -> void:
	ambient = false
	super._ready()
	add_to_group(_group())
	_pistol = ItemDB.get_item(gun if gun != &"" else (&"smg" if heavy else &"pistol")) as WeaponData
	if heavy:
		profile = HEAVY_PROFILE
		health = HEAVY_HEALTH
	_build_gear()
	if _is_host():
		if home == Vector3.INF:
			home = global_position
		_ready_chat()
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
		cap.mesh = _head_mesh()
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


func _ready_chat() -> void:
	_next_chat = _now() + randf_range(10.0, 30.0)


# --- Crimes (host) ---------------------------------------------------------------------

## Host (group "police"): `culprit` fired a gun at `origin` (murder = somebody died).
func report_crime(culprit: Player, origin: Vector3, murder: bool) -> void:
	if not _is_host() or dead or culprit == null or culprit.dead or not is_inside_tree():
		return
	if global_position.distance_to(origin) > (MURDER_RANGE if murder else HEAR_RANGE):
		return
	Wanted.report(culprit, &"heard", origin)  # point 28: the police heard it: at least 1 star
	if target != null and target != culprit and is_instance_valid(target) and not target.dead:
		return  # busy with someone else
	_alert(culprit, origin)


func _alert(culprit: Player, at: Vector3) -> void:
	_chatting = false  # (a chat is cut short)
	if target != culprit:
		_log("%s goes after %s" % [name, culprit.player_name])
		_next_shot = _now() + profile.reaction_time
		_burst_left = profile.burst_size
		_warned_at = -1.0
		_cuff_time = 0.0
		_last_target_pos = Vector3.INF
	target = culprit
	last_known = at
	_search_until = _now() + SEARCH_TIME


## Point 31a: an armed NPC of the other side (Crow vs police), alive.
func is_enemy(o: Node) -> bool:
	return o is PoliceOfficer and o != self and not (o as PoliceOfficer).dead and (o as PoliceOfficer)._group() != _group()


## Host: fight the NPC `o` (seen / heard at `at`).
func set_foe(o: PoliceOfficer, at: Vector3) -> void:
	if dead or not is_enemy(o):
		return
	if foe != o:
		_log("%s takes on %s" % [name, o.name])
		if target == null:
			_next_shot = _now() + profile.reaction_time
			_burst_left = profile.burst_size
			_seen_now = false
	foe = o
	_foe_last = at
	_foe_until = _now() + SEARCH_TIME
	_chatting = false


## Host (group "police", point 31a): an NPC of the other side (a Crow) fired at `origin`.
func report_npc_crime(shooter: PoliceOfficer, origin: Vector3) -> void:
	if not _is_host() or dead or not is_inside_tree() or not is_enemy(shooter):
		return
	if global_position.distance_to(origin) > HEAR_RANGE:
		return
	if foe != null and is_instance_valid(foe) and not foe.dead:
		return  # already in a fight
	set_foe(shooter, origin)


## Host: mates of our side close by join the fight against `o`.
func _rally(o: PoliceOfficer) -> void:
	for n: Node in get_tree().get_nodes_in_group(_group()):
		var m := n as PoliceOfficer
		if m == null or m == self or m.dead or m.global_position.distance_to(global_position) > RALLY_RANGE:
			continue
		if m.foe == null or not is_instance_valid(m.foe) or m.foe.dead:
			m.set_foe(o, o.global_position)


func hear_gunshot(_origin: Vector3, _hit: bool = false) -> void:
	pass  # officers don't flee; report_crime tells them who fired


func host_damage(amount: int, attacker: Node = null, from: Vector3 = Vector3.INF) -> bool:
	if not _is_host() or dead or amount <= 0:
		return false
	health = maxi(0, health - amount)
	if attacker is Player:
		_hostile[attacker] = true
		if _group() == &"police":
			Wanted.report(attacker as Player, &"assault", (attacker as Player).global_position)
		_alert(attacker as Player, (attacker as Player).global_position)
	elif is_enemy(attacker):
		set_foe(attacker as PoliceOfficer, (attacker as Node3D).global_position)
		_rally(attacker as PoliceOfficer)
	if health > 0:
		return false
	_die(from)
	return true


func _on_died(world: Node) -> void:
	target = null
	if from_car == null and world and world.has_method("respawn_officer_later"):
		world.call("respawn_officer_later", respawn_time)


## Can the officer see `p` (in range, nothing solid in between)?
func can_see(p: Node3D) -> bool:
	var eye: Vector3 = global_position + Vector3.UP * 1.6
	var chest: Vector3 = p.global_position + Vector3.UP * 1.2
	if eye.distance_to(chest) > profile.sight_range:
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
	if target != null and _target_off_limits(target):
		_log("%s: %s is somewhere it can't follow" % [name, target.player_name])
		_drop_target()
	if target == null:
		if not _fight_foe():
			_patrol()
		return
	var leash: Vector3 = _leash_center()
	if leash != Vector3.INF and last_known.distance_to(leash) > _leash_range():
		_log("%s: %s got away" % [name, target.player_name])
		_drop_target()
		return
	var sees: bool = can_see(target)
	if not sees:
		_seen_now = false
	_update_target_speed()
	if sees and not _should_shoot(target):
		_try_arrest()
		return
	if sees and _group() == &"police" and target.wanted_stars < 2:
		Wanted.report(target, &"resist", target.global_position)  # point 28: resisting = 2 stars
	if sees:
		_seen = true
		last_known = target.global_position
		_search_until = _now() + SEARCH_TIME
		if _moving:
			_finish_move(false)
		anim_state = Anim.AIM
		var d: Vector3 = target.global_position - global_position
		rotation.y = atan2(-d.x, -d.z)
		net_yaw = rotation.y
		if not _seen_now:
			# (Re)acquired the target: it needs a moment before the first shot.
			_seen_now = true
			_next_shot = maxf(_next_shot, _now() + profile.reaction_time * randf_range(0.7, 1.3))
		_fire_burst(target)
		return
	if _now() > _search_until:
		_log("%s lost %s" % [name, target.player_name])
		_drop_target()
		return
	# Run to where the culprit was last seen / heard (point 29: straight over the road when
	# nothing is in the way, instead of round via a zebra).
	if global_position.distance_to(last_known) > 1.5:
		if not _moving or move_target().distance_to(last_known) > 2.0:
			_chase_to(last_known, Anim.RUN_GUN)
	elif not _moving:
		anim_state = Anim.AIM
		rotation.y += 0.8  # look around
		net_yaw = rotation.y


## Host: shoot at `at` when the burst rhythm allows it.
func _fire_burst(at: Node3D) -> void:
	if _now() < _next_shot:
		return
	_shoot_at(at)
	_burst_left -= 1
	if _burst_left <= 0:
		_burst_left = maxi(1, profile.burst_size + randi_range(-1, 1))
		_next_shot = _now() + profile.burst_pause * randf_range(0.8, 1.4)
	else:
		_next_shot = _now() + 1.0 / maxf(0.1, profile.fire_rate) * randf_range(0.85, 1.25)


## Host (point 31a): fight `foe` (no player target). False = no foe (any more).
func _fight_foe() -> bool:
	if foe == null:
		return false
	var leash: Vector3 = _leash_center()
	var over: bool = not is_instance_valid(foe) or foe.dead or not foe.is_inside_tree() or _now() > _foe_until
	if not over and leash != Vector3.INF and _foe_last.distance_to(leash) > _leash_range():
		over = true
	if over:
		if is_instance_valid(foe):
			_log("%s is done with %s" % [name, foe.name])
		foe = null
		_drop_target()
		return false
	if can_see(foe):
		_foe_last = foe.global_position
		_foe_until = _now() + SEARCH_TIME
		if _moving:
			_finish_move(false)
		anim_state = Anim.AIM
		var d: Vector3 = foe.global_position - global_position
		rotation.y = atan2(-d.x, -d.z)
		net_yaw = rotation.y
		if not _seen_now:
			_seen_now = true
			_next_shot = maxf(_next_shot, _now() + profile.reaction_time * randf_range(0.7, 1.3))
		_fire_burst(foe)
		return true
	_seen_now = false
	if global_position.distance_to(_foe_last) > 1.5:
		if not _moving or move_target().distance_to(_foe_last) > 2.0:
			_chase_to(_foe_last, Anim.RUN_GUN)
	elif not _moving:
		anim_state = Anim.AIM
		rotation.y += 0.8
		net_yaw = rotation.y
	return true


## Point 29: straight there if the way is clear (over the road), else over the navmesh.
func _chase_to(at: Vector3, anim: int) -> void:
	if straight_way_clear(at, 30.0):
		_go_direct(at, anim)
	else:
		_go(at, anim)


func _drop_target() -> void:
	target = null
	_seen = false
	_seen_now = false
	if _moving:
		_finish_move(false)
	anim_state = Anim.IDLE


func _update_target_speed() -> void:
	var p: Vector3 = target.global_position
	if _last_target_pos != Vector3.INF:
		_target_speed = Vector2(p.x - _last_target_pos.x, p.z - _last_target_pos.z).length() / 0.2
	_last_target_pos = p


## Host (point 28): shoot at `p`, or try to arrest them? By the wanted level: 1 star =
## arrest unless they resist, 2 = shoot when they hold a weapon, 3+ = shoot on sight.
func _should_shoot(p: Player) -> bool:
	if _hostile.has(p):
		return true
	var cfg: WantedConfig = Wanted.current.config if Wanted.current else Wanted.CONFIG
	if p.wanted_stars >= cfg.shoot_on_sight_stars:
		return true
	if p.wanted_stars >= cfg.shoot_armed_stars and p.net_weapon != 0:
		return true
	return resisting(p)


## Host: does `p` resist arrest (then the police shoot)?
func resisting(p: Player) -> bool:
	if _hostile.has(p):
		return true
	if _now() - p.host_last_shot < SHOT_MEMORY:
		return true
	if p.net_weapon != 0 and _warned_at >= 0.0 and _now() - _warned_at > WARN_TIME:
		return true
	if _target_speed > FLEE_SPEED and global_position.distance_to(p.global_position) > 4.0:
		return true
	return false


## Host: walk up to a culprit who gives up, and cuff them.
func _try_arrest() -> void:
	var p: Player = target
	_seen = true
	_seen_now = true
	last_known = p.global_position
	_search_until = _now() + SEARCH_TIME
	if _warned_at < 0.0:
		_warned_at = _now()
		p.show_message("POLICE! Put your weapon away and don't move!")
	var d: float = global_position.distance_to(p.global_position)
	if d > ARREST_DISTANCE:
		_cuff_time = 0.0
		if not _moving or move_target().distance_to(p.global_position) > 1.0:
			_chase_to(p.global_position, Anim.RUN_GUN if d > 6.0 else Anim.WALK)
		return
	if _moving:
		_finish_move(false)
	anim_state = Anim.AIM
	var dir: Vector3 = p.global_position - global_position
	rotation.y = atan2(-dir.x, -dir.z)
	net_yaw = rotation.y
	if p.net_weapon != 0:
		_cuff_time = 0.0  # weapon still in hand: keep aiming, no cuffs (resisting after WARN_TIME)
		return
	if _cuff_time == 0.0:
		p.show_message("You're under arrest. Hands behind your back...")
	_cuff_time += 0.2
	if _cuff_time >= CUFF_TIME:
		_log("%s arrests %s" % [name, p.player_name])
		p.host_arrest(self)


## Host (group "police"): `p` was arrested by someone: stop chasing them.
func on_arrested(p: Player) -> void:
	_hostile.erase(p)
	if target == p:
		_drop_target()


## Host (group "police", point 28): `p` is no longer wanted (lost the police, arrested, dead).
func on_wanted_cleared(p: Player) -> void:
	on_arrested(p)


## Host: busy with a culprit or a chat (a patrol car waits for its crew).
func is_busy() -> bool:
	return target != null or _chatting or (foe != null and is_instance_valid(foe) and not foe.dead)


## Host (point 30): walk up to `npc`, have a word (a few seconds, both gesture), carry on.
func question(npc: Pedestrian) -> void:
	if _chatting or target != null or dead or npc == null or not npc.free_for_talk():
		return
	_chatting = true
	_next_chat = _now() + randf_range(30.0, 60.0)
	npc.hold_for_talk(self, 30.0)
	var away := Vector3(global_position.x - npc.global_position.x, 0, global_position.z - npc.global_position.z)
	var spot: Vector3 = npc.global_position + (away.normalized() if away.length() > 0.1 else Vector3.FORWARD) * 1.2
	var ok: bool = await walk_to(spot)
	# The navmesh stops short of other bodies: the last step straight up to them.
	if _chatting and is_instance_valid(npc) and global_position.distance_to(npc.global_position) > 1.6 			and straight_way_clear(spot, 6.0):
		ok = await _go_direct(spot, Anim.WALK)
	if ok and _chatting and target == null and is_instance_valid(npc) and not npc.dead and npc.is_talking():
		_log("%s talks to %s" % [name, npc.name])
		chats += 1
		face(npc.global_position)
		anim_state = Anim.TALK
		npc.anim_state = Anim.TALK
		var until: float = _now() + randf_range(talk_time.x, talk_time.y)
		while is_inside_tree() and _chatting and target == null and _now() < until:
			await get_tree().create_timer(0.3).timeout
			if is_instance_valid(npc) and not npc.dead:
				npc.anim_state = Anim.TALK if int(_now() * 0.5) % 2 == 0 else Anim.IDLE  # take turns
				anim_state = Anim.IDLE if npc.anim_state == Anim.TALK else Anim.TALK
	if is_instance_valid(npc):
		npc.release_talk()
	_chatting = false
	if target == null and not dead and is_inside_tree():
		anim_state = Anim.IDLE


## A passer-by close enough for a chat (or null).
func _pick_chat() -> Pedestrian:
	var best: Pedestrian = null
	var best_d: float = CHAT_RANGE
	for n: Node in get_tree().get_nodes_in_group(&"npc"):
		var p := n as Pedestrian
		if p == null or p is PoliceOfficer or not p.free_for_talk():
			continue
		var d: float = p.global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = p
	return best


func _patrol() -> void:
	if _moving or from_car != null or _chatting:
		return
	if anim_state in [Anim.AIM, Anim.RUN_GUN, Anim.TALK]:
		anim_state = Anim.IDLE
	if _group() == &"police" and _now() > _next_chat and randf() < 0.05:
		var npc: Pedestrian = _pick_chat()
		if npc:
			question(npc)
			return
	if randf() < 0.08:
		var p: Vector3 = Vector3.INF
		for i: int in 4:
			var c: Vector3 = random_sidewalk_point(self, 20)
			if c != Vector3.INF and c.distance_to(home) < PATROL_RADIUS:
				p = c
				break
		if p != Vector3.INF:
			_go(p, Anim.WALK)


## Host: one shot at `p` (a player or an NPC foe, with spread), damage + effects for everyone.
func _shoot_at(p: Node3D) -> void:
	var origin: Vector3 = global_position + Vector3.UP * 1.45 - global_basis.z * 0.45
	var aim: Vector3 = p.global_position + Vector3.UP * randf_range(0.9, 1.5)
	var body := p as CharacterBody3D
	var speed: float = _target_speed if p == target else (Vector2(body.velocity.x, body.velocity.z).length() if body else 0.0)
	var dir: Vector3 = PlayerCombat._cone((aim - origin).normalized(), profile.spread(origin.distance_to(aim), speed))
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
		# Point 31a: no friendly fire within a side; the other side (Crow / officer) can be hit.
		var same_side: bool = victim is PoliceOfficer and (victim as PoliceOfficer)._group() == _group()
		if victim.has_method("host_damage") and not same_side and not (victim is Car and (victim as Car).police):
			var killed: bool = victim.call("host_damage", profile.damage, self, origin)
			_log("%s hit %s%s" % [name, victim.get("player_name") if victim is Player else victim.name,
					" - killed" if killed else ""])
	get_tree().call_group(&"npc", "hear_gunshot", origin)
	if _group() != &"police":
		get_tree().call_group(&"police", "report_npc_crime", self, origin)  # point 31a: the police come for it
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
