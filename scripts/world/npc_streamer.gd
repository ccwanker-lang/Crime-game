class_name NpcStreamer
extends Node
## Point 87: NPC streaming + level of detail, on every peer (node World/NpcStreamer).
## Every `interval` s each NPC (group "npc") gets a level from its distance to the nearest player:
##   FULL  (< full_radius)  : everything, every tick
##   MID   (< spawn_radius) : AI + physics every Pedestrian.MID_STEP ticks, animation at mid_anim_hz
##   ASLEEP (> despawn_radius, or over max_active_npcs): no scripts, physics, collision or drawing; it keeps its
##          position + state and wakes up where it was. Between spawn and despawn radius nothing changes (hysteresis).
## The host decides for the union of ALL players (it runs the AI); a client only decides what it draws, round its
## own player. Mission NPCs never sleep; NPCs with a deal or a mission go first when the cap is reached; a sleeping
## NPC does not wake up in a player's view closer than no_pop_radius.

const CONFIG_PATH: String = "res://data/npc/streaming.tres"

static var current: NpcStreamer
## Tests (npc_bench): override the cap (-1 = the config's).
static var cap_override: int = -1

var config: NpcStreamConfig
var active: int = 0
var asleep: int = 0
var _timer: float = 0.0
var _anim_timer: float = 0.0
var _mid: Array[Pedestrian] = []


func _ready() -> void:
	current = self
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--npc-cap="):
			cap_override = int(a.get_slice("=", 1))
	config = load(CONFIG_PATH) as NpcStreamConfig if ResourceLoader.exists(CONFIG_PATH) else NpcStreamConfig.new()


func _exit_tree() -> void:
	if current == self:
		current = null


func max_active() -> int:
	return cap_override if cap_override >= 0 else config.max_active_npcs


## Mission NPCs (and their guards) always stay awake, and so does anyone on their way to / fighting a player or a
## foe (an officer after a player, a Crow sent after one, a fight between police and Crows).
static func pinned(npc: Pedestrian) -> bool:
	if str(npc.name).begins_with("MissionNPC_") or npc.has_meta(&"mission"):
		return true
	var po := npc as PoliceOfficer
	if po and (is_instance_valid(po.target) or is_instance_valid(po.foe)):
		return true
	var rv := npc as Rival
	return rv != null and is_instance_valid(rv.sent_target)


## Deals and missions first when the cap is reached.
static func important(npc: Pedestrian) -> bool:
	return npc.wants > 0 or pinned(npc) or npc.dead


func _viewers() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var world: Node = get_parent()
	var players: Node = world.get_node_or_null("Players")
	if players == null:
		return out
	var host: bool = multiplayer.is_server()
	for n: Node in players.get_children():
		var p := n as Player
		if p == null:
			continue
		if not host and not p.is_multiplayer_authority():
			continue
		var fwd: Vector3 = -p.head.global_basis.z if p.head else -p.global_basis.z
		out.append({"pos": p.global_position, "fwd": fwd})
	return out


func _process(delta: float) -> void:
	_anim_timer += delta
	if _anim_timer >= 1.0 / config.mid_anim_hz:
		for npc: Pedestrian in _mid:
			if is_instance_valid(npc):
				npc.lod_animate(_anim_timer)
		_anim_timer = 0.0
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = config.interval
	update_now()


func update_now() -> void:
	var viewers: Array[Dictionary] = _viewers()
	if viewers.is_empty():
		return
	var cands: Array = []  # [score, npc, distance]
	var sleep_now: Array[Pedestrian] = []
	for n: Node in get_tree().get_nodes_in_group(&"npc"):
		var npc := n as Pedestrian
		if npc == null or npc.stationary or not npc.is_inside_tree():
			continue
		var d: float = INF
		for v: Dictionary in viewers:
			d = minf(d, (v["pos"] as Vector3).distance_to(npc.global_position))
		if pinned(npc):
			cands.append([-1.0, npc, d])
			continue
		var awake: bool = npc.lod != Pedestrian.Lod.ASLEEP
		if d > config.despawn_radius or (not awake and d > config.spawn_radius):
			sleep_now.append(npc)
			continue
		cands.append([(0.0 if important(npc) else 1000.0) + d, npc, d])
	cands.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var cap: int = max_active()
	_mid.clear()
	active = 0
	var counted: int = 0  # (pinned mission NPCs come on top of the cap)
	for c: Array in cands:
		var npc: Pedestrian = c[1]
		var d: float = c[2]
		if counted >= cap and float(c[0]) >= 0.0:
			sleep_now.append(npc)
			continue
		if npc.lod == Pedestrian.Lod.ASLEEP and not pinned(npc) and _in_view(npc.global_position, viewers):
			continue  # (stays asleep for now: it would pop up right in front of someone)
		var l: int = Pedestrian.Lod.FULL if d < config.full_radius or npc.dead else Pedestrian.Lod.MID
		npc.set_lod(l)
		active += 1
		if float(c[0]) >= 0.0:
			counted += 1
		if l == Pedestrian.Lod.MID and d < config.anim_radius:
			_mid.append(npc)  # (further away the model is not drawn anyway: no animation at all)
	_update_cars(viewers)
	asleep = 0
	for npc: Pedestrian in sleep_now:
		npc.set_lod(Pedestrian.Lod.ASLEEP)
		asleep += 1


## Cars: far from every player -> lighter lane sensing (host) and not drawn beyond the despawn radius.
func _update_cars(viewers: Array[Dictionary]) -> void:
	for n: Node in get_tree().get_nodes_in_group(&"cars"):
		var car := n as Car
		if car == null:
			continue
		var d: float = INF
		for v: Dictionary in viewers:
			d = minf(d, (v["pos"] as Vector3).distance_to(car.global_position))
		car.far = d > config.far_car_radius
		var show: bool = d < config.despawn_radius if car.visible else d < config.spawn_radius
		if car.visible != show:
			car.visible = show


func _in_view(pos: Vector3, viewers: Array[Dictionary]) -> bool:
	for v: Dictionary in viewers:
		var to: Vector3 = pos - (v["pos"] as Vector3)
		var dist: float = to.length()
		if dist < config.no_pop_radius and dist > 0.01 and (v["fwd"] as Vector3).dot(to / dist) > 0.35:
			return true
	return false
