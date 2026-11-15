extends Node
## Missions (NOTES part 19, the base for the story). HOST AUTHORITATIVE:
## - every MissionData .tres in data/missions/ is a mission (`all`, `get_mission(id)`);
## - one mission runs at a time for the whole crew (co-op: everyone has the same mission and shares the progress);
##   state in GameState.world["missions"] (saved with the game): active id, step, count, time, members, late, done;
## - the host checks the current MissionObjective (go to / talk to / deliver / kill / survive), spawns the mission's
##   NPCs (networked non-wandering pedestrians "MissionNPC_<id>") and enemies (Black Crows), and sends a small `view`
##   to every peer (`_sync`); late joiners get it too;
## - rewards: cash + items to every MEMBER (in the game when the mission started), XP once for the crew; players
##   who joined later (`late`) get the progress but no reward;
## - every peer: MissionHUD (objective + waypoint), a talk box on mission NPCs (E -> `request_talk`), a "Missions"
##   app in the phone (`MissionLog`) and a pin on the phone map (`MissionMapPin`), hooked in without changing A's
##   phone / HUD scripts.

signal changed

const DIR: String = "res://data/missions/"
const PEDESTRIAN_SCENE: String = "res://prefabs/npc/pedestrian.tscn"
const NPC_PREFIX: String = "MissionNPC_"
const TALK_RANGE: float = 4.0
const TICK: float = 0.25

var all: Dictionary = {}          # id -> MissionData
## Every peer: what the HUD / phone show (from the host).
var view: Dictionary = {}
var hud: MissionHUD
var _world: Node3D
var _tick: float = 0.0
var _resync: float = 0.0
var _npc_spots: Dictionary = {}   # host: npc_id -> {pos, yaw}


func _ready() -> void:
	_load_all()
	get_tree().node_added.connect(_on_node_added)
	add_to_group(&"kill_hooks")


func _load_all() -> void:
	var dir := DirAccess.open(DIR)
	if dir == null:
		return
	for f: String in dir.get_files():
		f = f.trim_suffix(".remap")
		if not (f.ends_with(".tres") or f.ends_with(".res")):
			continue
		var m := load(DIR + f) as MissionData
		if m and m.id != &"":
			all[m.id] = m


func get_mission(id: StringName) -> MissionData:
	return all.get(id) as MissionData


func _is_host() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func state() -> Dictionary:
	var s: Dictionary = GameState.world.get_or_add("missions", {})
	for k: String in ["active", "step", "count", "time", "members", "late", "done", "enemies", "rewarded"]:
		if not s.has(k):
			s[k] = [] if k in ["members", "late", "done", "enemies", "rewarded"] else ("" if k == "active" else 0)
	return s


func active() -> MissionData:
	return get_mission(StringName(str(state()["active"])))


func objective() -> MissionObjective:
	var m: MissionData = active()
	var step: int = int(state()["step"])
	return m.objectives[step] if m and step < m.objectives.size() else null


func is_done(id: StringName) -> bool:
	return str(id) in (state()["done"] as Array)


## Can the crew start `id` now? "" = yes, else why not.
func why_not(id: StringName) -> String:
	var m: MissionData = get_mission(id)
	if m == null:
		return "No such mission."
	if str(state()["active"]) != "":
		return "Finish \"%s\" first." % active().title if active() else "Another mission is running."
	if is_done(id) and not m.repeatable:
		return "Already done."
	if m.requires != &"" and not is_done(m.requires):
		var r: MissionData = get_mission(m.requires)
		return "First: \"%s\"." % (r.title if r else str(m.requires))
	if m.min_rank > 0 and Progression.rank_for(Progression.host_xp()) < m.min_rank:
		return "Needs rank %d (%s)." % [m.min_rank, Progression.rank_name(m.min_rank)]
	return ""


## Missions the crew can start now (every peer: from the view, host: computed).
func available() -> Array[StringName]:
	var out: Array[StringName] = []
	var ids: Array = all.keys()
	ids.sort()
	for id: StringName in ids:
		if _is_host():
			if why_not(id) == "":
				out.append(id)
		elif str(id) in (view.get("available", []) as Array):
			out.append(id)
	return out


# --- World / every peer ------------------------------------------------------------------------

func _process(delta: float) -> void:
	var scene: Node = get_tree().current_scene
	if scene == null or scene.get_node_or_null("Players") == null:
		_world = null
		return
	if _world != scene:
		_world = scene as Node3D
		_on_world()
	_dress_npcs()
	if hud == null:
		_make_hud()
	if not _is_host():
		return
	_tick -= delta
	if _tick > 0.0:
		return
	var dt: float = TICK - _tick
	_tick = TICK
	_host_tick(dt)


func _on_world() -> void:
	view = {}
	hud = null
	_npc_spots.clear()
	if _is_host():
		_sync_all.call_deferred()
	else:
		request_view.call_deferred()


func _players() -> Array[Player]:
	var out: Array[Player] = []
	if _world == null:
		return out
	for n: Node in _world.get_node("Players").get_children():
		if n is Player and n.is_inside_tree():
			out.append(n)
	return out


func _player_by_peer(peer: int) -> Player:
	return _world.get_node_or_null("Players/%d" % peer) as Player if _world else null


func _local_player() -> Player:
	for p: Player in _players():
		if p.is_local():
			return p
	return null


func _make_hud() -> void:
	if DisplayServer.get_name() == "headless" or _local_player() == null:
		return
	hud = MissionHUD.new()
	hud.name = "MissionHUD"
	_world.add_child(hud)


## Every peer: mission NPCs get a talk box (E) + a name tag.
func _dress_npcs() -> void:
	var npcs: Node = _world.get_node_or_null("NPCs")
	if npcs == null:
		return
	for n: Node in npcs.get_children():
		if n is Pedestrian and str(n.name).begins_with(NPC_PREFIX) and n.get_node_or_null("TalkBox") == null:
			var npc_id: StringName = StringName(str(n.name).trim_prefix(NPC_PREFIX))
			var box := MissionTalkBox.new()
			box.name = "TalkBox"
			box.npc_id = npc_id
			box.npc_name = _npc_display(npc_id)
			n.add_child(box)


func _npc_display(npc_id: StringName) -> String:
	for m: MissionData in all.values():
		for o: MissionObjective in m.objectives:
			if o.npc_id == npc_id and o.npc_name != "":
				return o.npc_name
	return str(npc_id).capitalize()


func _on_node_added(n: Node) -> void:
	if n is PhoneMap:
		var pin := MissionMapPin.new()
		n.add_child.call_deferred(pin)
	elif n is Button and (n as Button).text.begins_with("Crew (") and n.get_parent() and n.get_parent().get_parent() \
			and n.get_parent().get_parent().get_parent() is Phone:
		MissionLog.add_app_button.call_deferred(n.get_parent().get_parent().get_parent() as Phone)


# --- Host: start / steps / end -----------------------------------------------------------------

## Any peer: start mission `id` for the crew.
func request_start(id: StringName) -> void:
	if _is_host():
		var p: Player = _local_player()
		host_start(id, p)
	else:
		_request_start.rpc_id(1, str(id))


@rpc("any_peer", "call_remote", "reliable")
func _request_start(id: String) -> void:
	if multiplayer.is_server():
		host_start(StringName(id), _player_by_peer(multiplayer.get_remote_sender_id()))


## Host: start `id` (everyone in the game now is a member). Returns "" or why not.
func host_start(id: StringName, by: Player = null) -> String:
	var why: String = why_not(id)
	if why != "":
		if by:
			by.show_message(why)
		return why
	var m: MissionData = get_mission(id)
	var s: Dictionary = state()
	s["active"] = str(id)
	s["step"] = 0
	s["count"] = 0
	s["time"] = 0.0
	s["members"] = _players().map(func(p: Player) -> String: return p.player_name)
	s["late"] = []
	s["enemies"] = []
	print("[Missions] start %s (%s), crew %s" % [id, m.title, s["members"]])
	_enter_step()
	_banner_all("NEW MISSION", m.title)
	for p: Player in _players():
		p.phone_message(m.giver, "%s\n%s" % [m.title, m.summary], "")
	return ""


## Any peer: give up the running mission.
func request_abandon() -> void:
	if _is_host():
		host_end(false, "abandoned")
	else:
		_request_abandon.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _request_abandon() -> void:
	if multiplayer.is_server():
		host_end(false, "abandoned")


func _target(o: MissionObjective) -> Vector3:
	if o == null:
		return Vector3.INF
	if o.marker != "" and _world:
		var m: Node3D = _world.find_child(o.marker, true, false) as Node3D
		if m:
			return m.global_transform * o.offset
	return o.position + o.offset


## Host: a new step begins: spawn its NPC / enemies.
func _enter_step() -> void:
	var o: MissionObjective = objective()
	var s: Dictionary = state()
	s["count"] = 0
	s["time"] = 0.0
	s["enemies"] = []
	_despawn_npcs(o.npc_id if o else &"")
	if o == null:
		return
	if o.npc_id != &"":
		_ensure_npc(o)
	if o.spawn_enemies > 0 and o.kind in [MissionObjective.Kind.KILL, MissionObjective.Kind.SURVIVE]:
		_spawn_enemies(o)
	print("[Missions] step %d: %s" % [int(s["step"]) + 1, o.format(0, o.seconds)])
	_sync_all()


func _advance() -> void:
	var s: Dictionary = state()
	var m: MissionData = active()
	s["step"] = int(s["step"]) + 1
	if int(s["step"]) >= m.objectives.size():
		host_end(true, "")
		return
	_banner_all("OBJECTIVE COMPLETE", objective().format(0, objective().seconds))
	_enter_step()


## Host: the mission ends (won = rewards).
func host_end(won: bool, why: String) -> void:
	var s: Dictionary = state()
	var m: MissionData = active()
	if m == null:
		return
	print("[Missions] %s %s%s" % [m.id, "DONE" if won else "FAILED", " (%s)" % why if why != "" else ""])
	s["active"] = ""
	s["step"] = 0
	_despawn_npcs(&"")
	if won:
		if not str(m.id) in (s["done"] as Array):
			(s["done"] as Array).append(str(m.id))
		_reward(m)
	else:
		_banner_all("MISSION FAILED", why.capitalize() if why != "" else m.title)
	s["members"] = []
	s["late"] = []
	s["enemies"] = []
	_sync_all()


func _reward(m: MissionData) -> void:
	var s: Dictionary = state()
	var items: Array = []
	for id: String in m.reward_items:
		items.append({"id": id, "count": int(m.reward_items[id])})
	var got: Array = []
	for p: Player in _players():
		if p.player_name in (s["late"] as Array) or not p.player_name in (s["members"] as Array):
			_banner(p, "MISSION COMPLETE", "%s - you joined late: no reward this time" % m.title)
			continue
		var left: Array = GameState.give(p.player_name, m.reward_cash, items)
		if not left.is_empty() and _world and _world.has_method("spawn_loot_bag"):
			_world.call("spawn_loot_bag", p.global_position + p.global_basis.z * -1.0, p.player_name, 0, left, true)
		p.send_wallet()
		got.append(p.player_name)
		_banner(p, "MISSION COMPLETE", "%s   +%s" % [m.title, m.reward_text()])
		if m.done_text != "":
			p.phone_message(m.giver, m.done_text, "")
	if m.reward_xp > 0:
		var by: Player = null
		for p: Player in _players():
			if p.player_name in got:
				by = p
		Progression.host_add(m.reward_xp, "mission: %s" % m.title, by)
	(s["rewarded"] as Array).append({"id": str(m.id), "who": got})
	print("[Missions] reward %s -> %s" % [m.reward_text(), got])


# --- Host tick ---------------------------------------------------------------------------------

func _host_tick(dt: float) -> void:
	var s: Dictionary = state()
	if str(s["active"]) == "":
		return
	var m: MissionData = active()
	var o: MissionObjective = objective()
	if m == null or o == null:
		s["active"] = ""
		_sync_all()
		return
	# Late joiners: progress yes, reward no.
	for p: Player in _players():
		if not p.player_name in (s["members"] as Array) and not p.player_name in (s["late"] as Array):
			(s["late"] as Array).append(p.player_name)
			print("[Missions] %s joined during %s: progress, no reward" % [p.player_name, m.id])
			p.show_message("Your crew is on a mission: \"%s\". You can help, but the reward goes to who started it." % m.title)
			_sync_all()
	if o.npc_id != &"":
		_ensure_npc(o)
	var target: Vector3 = _target(o)
	var alive: Array = _players().filter(func(p: Player) -> bool: return not p.dead)
	match o.kind:
		MissionObjective.Kind.GO_TO:
			for p: Player in alive:
				if _flat_dist(p.global_position, target) <= o.radius:
					_advance()
					return
		MissionObjective.Kind.KILL:
			if o.spawn_enemies > 0:
				var killed: int = o.spawn_enemies - _enemies_alive()
				if killed != int(s["count"]):
					s["count"] = killed
					_sync_all()
			if int(s["count"]) >= o.need():
				_advance()
				return
			if alive.is_empty():
				host_end(false, "the whole crew went down")
				return
		MissionObjective.Kind.SURVIVE:
			if alive.is_empty():
				host_end(false, "the whole crew went down")
				return
			var near: bool = o.radius <= 0.0
			for p: Player in alive:
				if _flat_dist(p.global_position, target) <= o.radius:
					near = true
			if near:
				s["time"] = float(s["time"]) + dt
			if float(s["time"]) >= o.seconds:
				_advance()
				return
	_resync -= dt
	if _resync <= 0.0:
		_resync = 1.0
		_sync_all()


static func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length() + maxf(0.0, absf(a.y - b.y) - 3.0)


## Kill hook (PlayerCombat / Player): kills without spawned enemies count by group.
func on_kill(killer: Node, victim: Node) -> void:
	if not _is_host() or not killer is Player:
		return
	var o: MissionObjective = objective()
	if o == null or o.kind != MissionObjective.Kind.KILL or o.spawn_enemies > 0:
		return
	if victim and victim.is_in_group(o.kill_group):
		state()["count"] = int(state()["count"]) + 1
		_sync_all()


# --- Host: NPCs + enemies ----------------------------------------------------------------------

func _npcs() -> Node:
	return _world.get_node_or_null("NPCs") if _world else null


func mission_npc(npc_id: StringName) -> Pedestrian:
	var npcs: Node = _npcs()
	return npcs.get_node_or_null(NPC_PREFIX + str(npc_id)) as Pedestrian if npcs else null


func _ensure_npc(o: MissionObjective) -> void:
	var npc: Pedestrian = mission_npc(o.npc_id)
	var at: Vector3 = _target(o)
	if npc == null or npc.dead:
		if npc and npc.dead:
			return  # (killed: the step can't be done any more - abandon it from the phone)
		var npcs: Node = _npcs()
		if npcs == null:
			return
		npc = (load(PEDESTRIAN_SCENE) as PackedScene).instantiate()
		npc.name = NPC_PREFIX + str(o.npc_id)
		npc.variant = o.npc_variant if o.npc_variant >= 0 else (hash(o.npc_id) & 0xffff) % Pedestrian.VARIANTS.size()
		npc.color_seed = hash(str(o.npc_id) + "colors")
		npc.ambient = false
		npc.position = at
		npc.rotation.y = deg_to_rad(o.npc_yaw)
		npc.set_meta(&"mission_npc", o.npc_id)
		npcs.add_child(npc)
		print("[Missions] %s waits at %s" % [o.npc_name, at])
		return
	# Back to the spot after a scare; face the way the mission says.
	if npc.is_fleeing() or npc._moving or npc.wants > 0:
		return
	if npc.global_position.distance_to(at) > 1.5:
		if npc.straight_way_clear(at, 40.0):
			npc._go_direct(at, Pedestrian.Anim.WALK)
		else:
			npc._go(at, Pedestrian.Anim.WALK)
	elif absf(angle_difference(npc.rotation.y, deg_to_rad(o.npc_yaw))) > 0.1 and npc.anim_state != Pedestrian.Anim.TALK:
		npc.rotation.y = deg_to_rad(o.npc_yaw)
		npc.net_yaw = npc.rotation.y


func _despawn_npcs(keep: StringName) -> void:
	var npcs: Node = _npcs()
	if npcs == null:
		return
	for n: Node in npcs.get_children():
		if str(n.name).begins_with(NPC_PREFIX) and str(n.name) != NPC_PREFIX + str(keep):
			n.queue_free()


func _spawn_enemies(o: MissionObjective) -> void:
	if _world == null or not _world.has_method("add_rival"):
		return
	var at: Vector3 = _target(o)
	var names: Array = state()["enemies"]
	for i: int in o.spawn_enemies:
		var a: float = TAU * i / maxf(1.0, o.spawn_enemies) + randf() * 0.5
		var spot: Vector3 = at + Vector3(cos(a), 0, sin(a)) * randf_range(2.0, maxf(3.0, o.radius * 0.5))
		var r: Node = _world.call("add_rival", spot, 1 if o.enemy_ak else 0, o.enemy_post)
		if r:
			r.set_meta(&"mission", str(active().id))
			names.append(str(r.name))
	print("[Missions] %d enemies at %s" % [names.size(), at])


func enemies() -> Array:
	var out: Array = []
	var npcs: Node = _npcs()
	for nm: String in state()["enemies"]:
		var e: Node = npcs.get_node_or_null(nm) if npcs else null
		if e:
			out.append(e)
	return out


func _enemies_alive() -> int:
	return enemies().filter(func(e: Node) -> bool: return not bool(e.get("dead"))).size()


# --- Talking (E on a mission NPC) --------------------------------------------------------------

## Owner (MissionTalkBox.interact): talk to mission NPC `npc_id`.
func request_talk(npc_id: StringName) -> void:
	if _is_host():
		var p: Player = _local_player()
		if p:
			host_talk(p, npc_id)
	else:
		_request_talk.rpc_id(1, str(npc_id))


@rpc("any_peer", "call_remote", "reliable")
func _request_talk(npc_id: String) -> void:
	if multiplayer.is_server():
		var p: Player = _player_by_peer(multiplayer.get_remote_sender_id())
		if p:
			host_talk(p, StringName(npc_id))


## Host: `p` talks to the NPC. Returns what happened ("talked", "delivered", "missing", "too far", "nothing").
func host_talk(p: Player, npc_id: StringName) -> String:
	var npc: Pedestrian = mission_npc(npc_id)
	if npc == null or p.dead or npc.dead:
		return "nothing"
	if p.global_position.distance_to(npc.global_position) > TALK_RANGE + 1.0:
		return "too far"
	npc.face(p.global_position)
	var o: MissionObjective = objective()
	if o == null or o.npc_id != npc_id:
		p.show_message("%s: \"Not now.\"" % _npc_display(npc_id))
		return "nothing"
	if o.kind == MissionObjective.Kind.TALK_TO:
		say(p, o.npc_name, o.lines, o.dialogue)
		_advance()
		return "talked"
	if o.kind == MissionObjective.Kind.DELIVER:
		if GameState.count_item(p.player_name, o.item_id) < o.count:
			var it: ItemData = ItemDB.get_item(StringName(o.item_id))
			p.show_message("%s: \"Where's my stuff? %d x %s.\"" % [o.npc_name, o.count, it.display_name if it else o.item_id])
			return "missing"
		GameState.remove_item(p.player_name, o.item_id, o.count)
		p.send_wallet()
		say(p, o.npc_name, o.lines, o.dialogue)
		_advance()
		return "delivered"
	return "nothing"


## Host: show what an NPC says to `p` (the dialogue box when there is one, part 20; else a toast per line).
func say(p: Player, who: String, lines: PackedStringArray, _dialogue: Resource = null) -> void:
	if lines.is_empty():
		return
	p.show_message("%s: \"%s\"" % [who, "\" \"".join(lines)])


# --- Sync to every peer ------------------------------------------------------------------------

## Host: the small picture every peer needs.
func make_view() -> Dictionary:
	var s: Dictionary = state()
	var v: Dictionary = {"active": str(s["active"]), "done": (s["done"] as Array).duplicate(),
			"late": (s["late"] as Array).duplicate(), "available": available().map(func(i: StringName) -> String: return str(i))}
	var m: MissionData = active()
	var o: MissionObjective = objective()
	if m and o:
		var step: int = int(s["step"])
		var steps: Array = []
		for i: int in m.objectives.size():
			var oi: MissionObjective = m.objectives[i]
			steps.append(oi.format(oi.need() if i < step else 0, oi.seconds))
		var target: Vector3 = _target(o)
		var npc: Pedestrian = mission_npc(o.npc_id) if o.npc_id != &"" else null
		if npc:
			target = npc.global_position
		v["title"] = m.title
		v["step"] = step
		v["steps"] = steps
		v["text"] = o.format(int(s["count"]), o.seconds - float(s["time"]))
		v["target"] = target
		v["radius"] = o.radius
	return v


func _sync_all() -> void:
	if not _is_host():
		return
	var v: Dictionary = make_view()
	_apply_view(v)
	for peer: int in Net.peers_in_world:
		_sync.rpc_id(peer, v)


@rpc("authority", "call_remote", "reliable")
func _sync(v: Dictionary) -> void:
	_apply_view(v)


func _apply_view(v: Dictionary) -> void:
	view = v
	changed.emit()


func _banner_all(head: String, text: String) -> void:
	for p: Player in _players():
		_banner(p, head, text)


func _banner(p: Player, head: String, text: String) -> void:
	if p.peer_id == multiplayer.get_unique_id() or not multiplayer.has_multiplayer_peer():
		_show_banner(head, text)
	elif p.peer_id in Net.peers_in_world:
		_show_banner_rpc.rpc_id(p.peer_id, head, text)


@rpc("authority", "call_remote", "reliable")
func _show_banner_rpc(head: String, text: String) -> void:
	_show_banner(head, text)


var last_banner: String = ""


func _show_banner(head: String, text: String) -> void:
	last_banner = "%s: %s" % [head, text]
	if hud:
		hud.banner(head, text)


## Client: ask the host for the view (a late joiner's World may load after the first sync).
func request_view() -> void:
	if not _is_host():
		_ask_view.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _ask_view() -> void:
	if multiplayer.is_server():
		_sync.rpc_id(multiplayer.get_remote_sender_id(), make_view())
