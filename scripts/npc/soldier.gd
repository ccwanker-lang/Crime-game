class_name Soldier
extends PoliceOfficer
## Map zone 2 (session B, NOTES part 18): a soldier of Fort Halden. HOST AUTHORITATIVE AI on the officer's armed brain
## (AK-47, the Crows' AK profile, more health), spawned by `Zones` (through World/NPCSpawner; the scene is added to its
## spawnable list at runtime).
## - Guards stand at their post (`home` + `post_yaw`) and look out; there is no navmesh at the base, so they only walk
##   straight lines (`_go_direct`).
## - Anyone inside the fence (Zones.in_army_base) whom they see is shot; anyone who shot at a soldier is shot on sight
##   anywhere near the base (`Zones.army_hostile`). No arrests, no police stars: the army handles it itself.
## - `reinforcement`: sent by the alarm (Zones), heavier, walks back to the barracks and is removed after the alarm.

const CAMO: Dictionary = {
	"White": Color(0.33, 0.37, 0.25),       # shirt: olive
	"Red_Dark": Color(0.28, 0.31, 0.21),    # jacket: dark olive
	"LightBrown": Color(0.42, 0.4, 0.3),    # trousers: khaki
	"LightBlue": Color(0.08, 0.08, 0.08),   # boots: black
}
## Part 21: their own profiles (better than the Crows' and the police: sight 60 m, accurate bursts); the tower
## guards are marksmen with a sniper rifle (sight 95 m, one heavy shot).
const SOLDIER_PROFILE: NpcCombatProfile = preload("res://data/npc/soldier.tres")
const MARKSMAN_PROFILE: NpcCombatProfile = preload("res://data/npc/soldier_marksman.tres")
const HEALTH: int = 150
const REINFORCEMENT_HEALTH: int = 220
## How far from their post (and from the base) soldiers follow someone.
const CHASE_RANGE: float = 70.0
## Sees intruders this far.
const WATCH_RANGE: float = 60.0

## Spawn-synced: the guard post's look direction.
var post_yaw: float = 0.0
var reinforcement: bool = false
## Host (part 21): a patrol walks these points in a loop (straight lines); empty = a post.
var route: Array[Vector3] = []
var _route_i: int = 0
## Host: a post where two soldiers chat (TALK now and then).
var chatty: bool = false


func _ready() -> void:
	if gun == &"":
		gun = &"ak47"
	var prof: NpcCombatProfile = MARKSMAN_PROFILE if gun == &"sniper" else SOLDIER_PROFILE
	profile = prof
	super._ready()
	profile = prof
	health = REINFORCEMENT_HEALTH if reinforcement else HEALTH
	add_to_group(&"soldiers")


func uniform_colors() -> Dictionary:
	return CAMO


func _group() -> StringName:
	return &"soldiers"


func _log(text: String) -> void:
	print("[Army] " + text)


## No arrests: whoever they go after gets shot.
func resisting(_p: Player) -> bool:
	return true


func report_crime(_culprit: Player, _origin: Vector3, _murder: bool) -> void:
	pass


## Only the Crows / police start NPC fights; a soldier just defends itself.
func is_enemy(_o: Node) -> bool:
	return false


## They don't follow anyone far from the base.
func _target_off_limits(p: Player) -> bool:
	return not Zones.near_army_base(p.global_position, 30.0)


func _leash_center() -> Vector3:
	return home


func _leash_range() -> float:
	return CHASE_RANGE


func host_damage(amount: int, attacker: Node = null, from: Vector3 = Vector3.INF) -> bool:
	if attacker is Player and not dead:
		Zones.army_hostile(attacker as Player, "shot a soldier")
	return super.host_damage(amount, attacker, from)


## Host: someone to shoot at - an intruder inside the fence or a known attacker, in sight.
func spot_intruder() -> Player:
	var best: Player = null
	var best_d: float = WATCH_RANGE
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p := n as Player
		if p == null or p.dead or not p.is_inside_tree():
			continue
		var d: float = global_position.distance_to(p.global_position)
		if d >= best_d:
			continue
		if not (Zones.in_army_base(p.global_position) or Zones.is_army_hostile(p)):
			continue
		if not can_see(p):
			continue
		best = p
		best_d = d
	return best


func _patrol() -> void:
	var p: Player = spot_intruder()
	if p:
		Zones.army_hostile(p, "inside the base")
		_alert(p, p.global_position)
		return
	if anim_state in [Anim.AIM, Anim.RUN_GUN] and not _moving:
		anim_state = Anim.IDLE
	if _moving:
		return
	if not route.is_empty() and not (reinforcement and not Zones.alarm_on()):
		_walk_route()
		return
	if global_position.distance_to(home) > 1.2:
		if straight_way_clear(home, 120.0):
			_go_direct(home, Anim.WALK)
		else:
			global_position = home  # (no navmesh at the base: blocked straight line = put back on post)
			net_pos = home
		return
	if reinforcement and not Zones.alarm_on():
		Zones.dismiss(self)
		return
	if absf(angle_difference(rotation.y, post_yaw)) > 0.05 and anim_state != Anim.TALK:
		rotation.y = post_yaw
		net_yaw = post_yaw
	if chatty and randf() < 0.06:
		anim_state = Anim.TALK if anim_state != Anim.TALK else Anim.IDLE


## Host: on to the next patrol point (a short look round at each one).
func _walk_route() -> void:
	var to: Vector3 = route[_route_i % route.size()]
	if Vector2(global_position.x - to.x, global_position.z - to.z).length() < 1.2:
		_route_i += 1
		anim_state = Anim.IDLE
		return
	if straight_way_clear(to, 150.0):
		_go_direct(to, Anim.WALK)
	else:
		_route_i += 1  # (blocked leg - a truck parked in the way: skip that point)


## Host: head for `at` (the alarm), shooting what they see on the way.
func send_to(at: Vector3) -> void:
	last_known = at
	_chase_to(at, Anim.RUN_GUN)


## No navmesh at the base (a navmesh path from here runs off to the town): straight lines only, round an obstacle
## by one side step (a point from which both legs are clear); else hold the position and keep watching.
func _chase_to(at: Vector3, anim: int) -> void:
	if home.y > 4.0 and not reinforcement:
		return  # (a tower guard stays up there and shoots from the platform)
	if straight_way_clear(at, 120.0):
		_go_direct(at, anim)
		return
	var best: Vector3 = Vector3.INF
	var best_len: float = INF
	var mid: Vector3 = (global_position + at) * 0.5
	for i: int in 16:
		var a: float = TAU * i / 16.0
		for r: float in [6.0, 12.0]:
			var c: Vector3 = mid + Vector3(cos(a), 0, sin(a)) * r
			c.y = global_position.y
			var length: float = global_position.distance_to(c) + c.distance_to(at)
			if length < best_len and straight_way_clear(c, 120.0) and _clear_between(c, at):
				best = c
				best_len = length
	if best != Vector3.INF:
		_go_direct(best, anim)


func _clear_between(a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a + Vector3.UP * 0.6, b + Vector3.UP * 0.6, 1, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


static var _helmet_cache: ArrayMesh


## Olive helmet (origin = head bone).
func _head_mesh() -> ArrayMesh:
	if _helmet_cache:
		return _helmet_cache
	var b := MeshBuilder.new()
	b.color = Color(0.3, 0.34, 0.22)
	b.cylinder(&"item_matte", Vector3(0, 0.12, 0), Vector3(0, 0.25, 0), 0.135, 0.09, 14, true)
	b.cylinder(&"item_matte", Vector3(0, 0.115, 0), Vector3(0, 0.135, 0), 0.155, 0.155, 14, false)
	_helmet_cache = b.build()
	return _helmet_cache


## Host: some ammo (now and then the rifle); Zones sends a new guard after a while.
func _on_died(world: Node) -> void:
	target = null
	Zones.soldier_died(self)
	if world == null or not world.has_method("spawn_loot_bag"):
		return
	var items: Array = [{"id": "ammo_762", "count": randi_range(8, 20)}]
	if randf() < 0.15:
		items.append({"id": "ak47", "count": 1})
	world.call("spawn_loot_bag", global_position, "Soldier", 0, items)
	_log("%s is down" % name)
