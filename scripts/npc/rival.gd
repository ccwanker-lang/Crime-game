class_name Rival
extends PoliceOfficer
## Point 11 / 31: a member of the Black Crows. HOST AUTHORITATIVE AI, built on the officer's
## armed brain (sight, reaction time, bursts, spread: data/npc/rival_combat.tres).
## - Point 31: they live in their fenced yard (the turf, World "TurfYard"), spread over it,
##   walking around and talking to each other, day and night (role YARD).
## - A YARD Crow only attacks players on the turf, or players it remembers: a Crow that sees
##   you on the turf (or gets shot by you) remembers you and tells the Crows near it. New
##   Crows know nobody, so outside the turf they leave you alone. It doesn't chase far
##   out of the yard (YARD_LEASH).
## - At night a small group (role STREET, World._rival_loop) roams the town and attacks any
##   player it sees; at daybreak it walks back to the yard and becomes YARD again.
## - Never follows a player into a crew-owned property (and never picks one inside it).
## - Some carry an AK-47 (`gun`, synced), the rest a pistol.
## - Killed: drops a loot bag with cash and sometimes weed, ammo or its gun; World replaces
##   it after 1-2 minutes.

enum Role { YARD, STREET }

const GANG: Dictionary = {
	"White": Color(0.08, 0.08, 0.09),       # shirt: black
	"Red_Dark": Color(0.16, 0.16, 0.17),    # jacket: dark grey
	"LightBrown": Color(0.12, 0.12, 0.14),  # trousers: charcoal
	"LightBlue": Color(0.75, 0.75, 0.75),   # shoes: white sneakers
}
const RIVAL_PROFILE: NpcCombatProfile = preload("res://data/npc/rival_combat.tres")
const RIVAL_AK_PROFILE: NpcCombatProfile = preload("res://data/npc/rival_ak.tres")
const AGGRO_RANGE: float = 22.0
const ROAM_RADIUS: float = 90.0
## Yard Crows don't chase further than this from the middle of the yard.
const YARD_LEASH: float = 42.0
## Seeing someone on the turf: the Crows this close hear about it too.
const SHARE_RANGE: float = 25.0
## Loot: cash range and chances for the extras.
const LOOT_CASH: Vector2i = Vector2i(40, 220)
const LOOT_WEED_CHANCE: float = 0.5
const LOOT_AMMO_CHANCE: float = 0.35
const LOOT_GUN_CHANCE: float = 0.1

## Tests: false = street Crows don't go back in daylight.
static var obey_daylight: bool = true

var role: int = Role.YARD
## Host: players this Crow saw on the turf (or that shot at it): attacked anywhere.
var memory: Dictionary = {}
var _talk_end: float = 0.0


func _ready() -> void:
	profile = RIVAL_AK_PROFILE if gun == &"ak47" else RIVAL_PROFILE
	super._ready()
	if gun == &"ak47":
		profile = RIVAL_AK_PROFILE


func uniform_colors() -> Dictionary:
	return GANG


func _group() -> StringName:
	return &"rivals"


func _log(text: String) -> void:
	print("[Crows] " + text)


## No arrests: anyone they go after gets shot.
func resisting(_p: Player) -> bool:
	return true


## Not police: crimes don't concern them (they are not in the "police" group anyway).
func report_crime(_culprit: Player, _origin: Vector3, _murder: bool) -> void:
	pass


## Inside a crew-owned property a player is safe.
func _target_off_limits(p: Player) -> bool:
	return is_safe(p.global_position)


func is_safe(pos: Vector3) -> bool:
	var prop: Property = Placement.property_at(get_tree(), pos)
	return prop != null and prop.is_crew_owned()


# --- The turf ---------------------------------------------------------------------------

static var _turf_cache: Rect2 = Rect2()


## The Crows' fenced yard (XZ), from the World's "TurfYard" paved area.
static func turf(tree: SceneTree) -> Rect2:
	if _turf_cache.size == Vector2.ZERO and tree and tree.current_scene:
		var yard: Node3D = tree.current_scene.find_child("TurfYard", true, false) as Node3D
		if yard:
			var size: Vector2 = yard.get("size")
			_turf_cache = Rect2(yard.global_position.x - size.x / 2.0, yard.global_position.z - size.y / 2.0, size.x, size.y)
	return _turf_cache


static func on_turf(tree: SceneTree, pos: Vector3) -> bool:
	return turf(tree).has_point(Vector2(pos.x, pos.z))


## Host: a random walkable spot in the yard (or INF).
static func yard_point(from: Node3D) -> Vector3:
	var r: Rect2 = turf(from.get_tree()).grow(-2.0)
	var map: RID = from.get_world_3d().navigation_map
	for i: int in 12:
		var want := Vector3(randf_range(r.position.x, r.end.x), 0.1, randf_range(r.position.y, r.end.y))
		var p: Vector3 = NavigationServer3D.map_get_closest_point(map, want)
		if p.y < 1.0 and Vector2(p.x - want.x, p.z - want.z).length() < 1.5 and on_turf(from.get_tree(), p):
			return p
	return Vector3.INF


## Host: remember `p` (and tell the Crows close by).
func remember(p: Player, share: bool = true) -> void:
	if p == null:
		return
	if not memory.has(p):
		_log("%s will remember %s" % [name, p.player_name])
	memory[p] = true
	if share:
		for n: Node in get_tree().get_nodes_in_group(&"rivals"):
			var r := n as Rival
			if r and r != self and not r.dead and r.global_position.distance_to(global_position) < SHARE_RANGE:
				r.remember(p, false)


func host_damage(amount: int, attacker: Node = null, from: Vector3 = Vector3.INF) -> bool:
	if attacker is Player and not dead:
		remember(attacker as Player)
	return super.host_damage(amount, attacker, from)


## Yard Crows stay near their yard; street Crows go anywhere.
func _leash_center() -> Vector3:
	if role == Role.YARD:
		var t: Rect2 = turf(get_tree())
		return Vector3(t.get_center().x, 0, t.get_center().y)
	return Vector3.INF


func _leash_range() -> float:
	return YARD_LEASH


# --- Behaviour (host) -------------------------------------------------------------------

func _patrol() -> void:
	if anim_state in [Anim.AIM, Anim.RUN_GUN] and not _moving:
		anim_state = Anim.IDLE
	var victim: Player = spot_victim()
	if victim:
		_talk_end = 0.0
		_alert(victim, victim.global_position)
		return
	if role == Role.STREET and obey_daylight and not _night():
		# Daybreak: back to the yard.
		if on_turf(get_tree(), global_position):
			role = Role.YARD
			_log("%s is back in the yard" % name)
		elif not _moving or move_target().distance_to(home) > 1.0:
			_go(home, Anim.WALK)
		return
	if _now() < _talk_end:
		return
	if anim_state == Anim.TALK:
		anim_state = Anim.IDLE
	if _moving:
		return
	if role == Role.STREET:
		if randf() < 0.1:
			for i: int in 4:
				var c: Vector3 = random_sidewalk_point(self, 20)
				if c != Vector3.INF and c.distance_to(home) < ROAM_RADIUS:
					_go(c, Anim.WALK)
					break
		return
	# In the yard: stroll around, now and then a word with a mate.
	var roll: float = randf()
	if roll < 0.04:
		var p: Vector3 = yard_point(self)
		if p != Vector3.INF:
			_go(p, Anim.WALK)
	elif roll < 0.07:
		for n: Node in get_tree().get_nodes_in_group(&"rivals"):
			var mate := n as Rival
			if mate and mate != self and not mate.dead and mate.target == null and not mate._moving \
					and mate.global_position.distance_to(global_position) < 5.0:
				var t: float = _now() + randf_range(3.0, 7.0)
				_talk_end = t
				mate._talk_end = t
				face(mate.global_position)
				mate.face(global_position)
				anim_state = Anim.TALK
				mate.anim_state = Anim.IDLE
				break


## Host: a player in sight and in range it should attack (on the turf, remembered, or
## anyone at night for the street group), not safe at home; or null.
func spot_victim() -> Player:
	var best: Player = null
	var best_d: float = AGGRO_RANGE
	var hunting: bool = role == Role.STREET and (_night() or not obey_daylight)
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p := n as Player
		if p == null or p.dead or not p.is_inside_tree():
			continue
		var d: float = global_position.distance_to(p.global_position)
		if d >= best_d or is_safe(p.global_position) or not can_see(p):
			continue
		var on: bool = on_turf(get_tree(), p.global_position)
		if on:
			remember(p)
		if on or memory.has(p) or hunting:
			best = p
			best_d = d
	return best


func _night() -> bool:
	var dn := get_tree().get_first_node_in_group(&"day_night") as DayNight
	return dn == null or dn.is_night()


static var _beanie_cache: ArrayMesh


## Black beanie (origin = head bone).
func _head_mesh() -> ArrayMesh:
	if _beanie_cache:
		return _beanie_cache
	var b := MeshBuilder.new()
	b.color = Color(0.05, 0.05, 0.06)
	b.cylinder(&"item_matte", Vector3(0, 0.15, 0), Vector3(0, 0.25, 0), 0.118, 0.1, 14, true)
	b.color = Color(0.5, 0.06, 0.05)
	b.cylinder(&"item_matte", Vector3(0, 0.15, 0), Vector3(0, 0.175, 0), 0.122, 0.122, 14, false)
	_beanie_cache = b.build()
	return _beanie_cache


## Host: the loot; World sends a new Crow after 1-2 minutes.
func _on_died(world: Node) -> void:
	target = null
	if world == null:
		return
	if world.has_method("rival_died"):
		world.call("rival_died")
	if not world.has_method("spawn_loot_bag"):
		return
	var items: Array = []
	if randf() < LOOT_WEED_CHANCE:
		items.append({"id": "weed_bag", "count": randi_range(1, 3)})
	var ak: bool = gun == &"ak47"
	if randf() < LOOT_AMMO_CHANCE:
		items.append({"id": "ammo_762" if ak else "ammo_9mm", "count": randi_range(6, 14)})
	if randf() < LOOT_GUN_CHANCE:
		items.append({"id": "ak47" if ak else "pistol", "count": 1})
	world.call("spawn_loot_bag", global_position, "Black Crows", randi_range(LOOT_CASH.x, LOOT_CASH.y), items)
	_log("%s is down" % name)
