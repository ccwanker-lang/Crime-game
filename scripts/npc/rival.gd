class_name Rival
extends PoliceOfficer
## Point 11: a member of the Black Crows. HOST AUTHORITATIVE AI, built on the officer's
## armed brain (sight, reaction time, bursts, spread: data/npc/rival_combat.tres).
## - Comes out of the Crows' house at night (World._rival_loop) and roams the town.
## - Attacks any player it sees within AGGRO_RANGE: no warning, no arrest.
## - Never follows a player into a crew-owned property (and never picks one inside it).
## - Killed: drops a loot bag with cash and sometimes weed, ammo or its pistol.
## - At daybreak it walks back to the house and disappears.

const GANG: Dictionary = {
	"White": Color(0.08, 0.08, 0.09),       # shirt: black
	"Red_Dark": Color(0.16, 0.16, 0.17),    # jacket: dark grey
	"LightBrown": Color(0.12, 0.12, 0.14),  # trousers: charcoal
	"LightBlue": Color(0.75, 0.75, 0.75),   # shoes: white sneakers
}
const RIVAL_PROFILE: NpcCombatProfile = preload("res://data/npc/rival_combat.tres")
const AGGRO_RANGE: float = 22.0
const ROAM_RADIUS: float = 75.0
## Loot: cash range and chances for the extras.
const LOOT_CASH: Vector2i = Vector2i(40, 220)
const LOOT_WEED_CHANCE: float = 0.5
const LOOT_AMMO_CHANCE: float = 0.35
const LOOT_PISTOL_CHANCE: float = 0.1

## Tests: false = they don't go home in daylight.
static var obey_daylight: bool = true


func _ready() -> void:
	profile = RIVAL_PROFILE
	super._ready()


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


func _patrol() -> void:
	if anim_state in [Anim.AIM, Anim.RUN_GUN] and not _moving:
		anim_state = Anim.IDLE
	if obey_daylight and not _night():
		# Daybreak: back to the house, then gone.
		if global_position.distance_to(home) < 2.5:
			_log("%s goes inside for the day" % name)
			queue_free()  # NPCSpawner removes it on the clients too
		elif not _moving or agent.target_position.distance_to(home) > 1.0:
			_go(home, Anim.WALK)
		return
	var victim: Player = spot_victim()
	if victim:
		_alert(victim, victim.global_position)
		return
	if _moving:
		return
	if randf() < 0.1:
		for i: int in 4:
			var c: Vector3 = random_sidewalk_point(self, 20)
			if c != Vector3.INF and c.distance_to(home) < ROAM_RADIUS:
				_go(c, Anim.WALK)
				break


## Host: a player in sight and in range who is not safe at home, or null.
func spot_victim() -> Player:
	var best: Player = null
	var best_d: float = AGGRO_RANGE
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p := n as Player
		if p == null or p.dead or not p.is_inside_tree():
			continue
		var d: float = global_position.distance_to(p.global_position)
		if d < best_d and not is_safe(p.global_position) and can_see(p):
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


## Host: the loot, no respawn (the World's night loop sends new ones).
func _on_died(world: Node) -> void:
	target = null
	if world == null or not world.has_method("spawn_loot_bag"):
		return
	var items: Array = []
	if randf() < LOOT_WEED_CHANCE:
		items.append({"id": "weed_bag", "count": randi_range(1, 3)})
	if randf() < LOOT_AMMO_CHANCE:
		items.append({"id": "ammo_9mm", "count": randi_range(6, 14)})
	if randf() < LOOT_PISTOL_CHANCE:
		items.append({"id": "pistol", "count": 1})
	world.call("spawn_loot_bag", global_position, "Black Crows", randi_range(LOOT_CASH.x, LOOT_CASH.y), items)
	_log("%s is down" % name)
