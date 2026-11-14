extends Node
## The shooting range (DESIGN "Progression" rank 2), autoload `RangeClub`. Session B. HOST AUTHORITATIVE.
## - Every peer: adds the ShootingRange (local build, "Hollow Creek Gun Club") to the World at the marker
##   "ShootingRangeSpot" if the map has one, else at FALLBACK_POS / FALLBACK_YAW (the free strip north of Hollow Farm).
## - Gunfire inside the range (`covers`) is legal: PlayerCombat skips the "heard a shot" calls (police, pedestrians,
##   cars) for it. Hitting a person there is still a crime.
## - E on Walt (RangeDesk) -> RangeWindow -> `request(kind, arg)` -> host `host_request(p, kind, arg)`:
##     "drill"  - DRILL_FEE: a timed drill on a free lane, targets pop up one at a time (bullseye = 2 points);
##                the score raises the player's skill (diminishing, max SKILL_MAX_PER_DRILL per drill) + a little XP.
##     "try"    - TRY_FEE: borrow any gun (even one your rank can't buy yet) + TRY_MAGS magazines; it goes back
##                when you leave the range (LOAN_RANGE) or after LOAN_SECONDS, or with "return".
##     "return" - hand the loaner back now.
## - Skill (0..1, per player name) in GameState.world["range"]["skill"], synced to every peer: the owner's spread is
##   multiplied by `spread_factor(name)` (1 - SKILL_BONUS * skill, PlayerCombat._spread).

const RANK: int = 2
const DRILL_FEE: int = 40
const TRY_FEE: int = 25
const DRILL_SECONDS: float = 45.0
const POP_GAP: float = 0.5
## Seconds a target stays up: base + per metre of distance.
const UP_BASE: float = 1.7
const UP_PER_M: float = 0.04
const SKILL_PER_POINT: float = 0.004
const SKILL_MAX_PER_DRILL: float = 0.06
## Max spread reduction at skill 1.0.
const SKILL_BONUS: float = 0.2
const XP_MAX_PER_DRILL: int = 10
const TRY_MAGS: int = 2
const LOAN_SECONDS: float = 600.0
const LOAN_RANGE: float = 45.0
const FALLBACK_POS := Vector3(-100.0, 0.0, -124.0)
const FALLBACK_YAW: float = PI * 0.5  # shooters face west (-X)

## Every peer: skill per player name, the loaned gun per player name, synced by the host.
var skill: Dictionary = {}
var loans: Dictionary = {}
## Host: lane -> {name, peer, ends, score, hits, bulls, up (target index or -1), up_until, next}.
var drills: Dictionary = {}
var _range: ShootingRange = null
var _board_timer: float = 0.0
var _loan_timer: float = 0.0


func _is_host() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()


func _data() -> Dictionary:
	var d: Variant = GameState.world.get("range")
	if not d is Dictionary:
		d = {"skill": {}, "best": {}}
		GameState.world["range"] = d
	return d


## Every peer: is `pos` inside the range (gunfire there is legal)?
func covers(pos: Vector3) -> bool:
	return _range != null and is_instance_valid(_range) and _range.covers(pos)


func skill_of(player_name: String) -> float:
	return clampf(float(skill.get(player_name, 0.0)), 0.0, 1.0)


## Spread multiplier for a player's shots (PlayerCombat._spread, on the owner).
func spread_factor(player_name: String) -> float:
	return 1.0 - SKILL_BONUS * skill_of(player_name)


func best_of(player_name: String) -> int:
	return int((_data()["best"] as Dictionary).get(player_name, 0)) if _is_host() else int(_best_seen.get(player_name, 0))


var _best_seen: Dictionary = {}


# --- Every peer: the range in the world ---------------------------------------------------

func _process(delta: float) -> void:
	var scene: Node = get_tree().current_scene
	if scene == null or scene.get_node_or_null("Players") == null:
		_range = null
		drills = {}
		return
	if _range == null or not is_instance_valid(_range):
		_spawn_range(scene)
		if _is_host():
			_load_skill()
	if not _is_host():
		return
	var now: float = _now()
	for lane: int in drills.keys():
		_drill_step(lane, now)
	_board_timer -= delta
	if _board_timer <= 0.0 and not drills.is_empty():
		_board_timer = 0.5
		for lane: int in drills:
			_send_board(lane)
	_loan_timer -= delta
	if _loan_timer <= 0.0:
		_loan_timer = 1.0
		host_check_loans()


func _spawn_range(scene: Node) -> void:
	_range = ShootingRange.new()
	var marker: Node3D = null
	if scene.has_method("get_marker"):
		marker = scene.call("get_marker", "ShootingRangeSpot") as Node3D
	scene.add_child(_range)
	if marker:
		_range.global_position = marker.global_position
		_range.global_rotation = Vector3(0, marker.global_rotation.y, 0)
	else:
		_range.global_position = FALLBACK_POS
		_range.rotation.y = FALLBACK_YAW
	if not _is_host():
		_request_sync.rpc_id(1)


func _load_skill() -> void:
	skill = (_data()["skill"] as Dictionary).duplicate()
	loans = {}
	for n: String in GameState.player_data:
		var loan: Variant = (GameState.player_data[n] as Dictionary).get("range_loan")
		if loan is Dictionary:
			loans[n] = str((loan as Dictionary).get("weapon", ""))


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


# --- Host: requests -------------------------------------------------------------------------

## Owner (RangeWindow): ask the host.
func request(kind: String, arg: String = "") -> void:
	if _is_host():
		_answer(host_request(_local_player(), kind, arg))
	else:
		_request.rpc_id(1, kind, arg)


@rpc("any_peer", "call_remote", "reliable")
func _request(kind: String, arg: String) -> void:
	if not multiplayer.is_server():
		return
	var peer: int = multiplayer.get_remote_sender_id()
	var p := get_tree().current_scene.get_node_or_null("Players/%d" % peer) as Player
	if p and not p.dead:
		_answer_rpc.rpc_id(peer, host_request(p, kind, arg))


## Host: handles a request of `p`; returns the answer ("!" first = refused).
func host_request(p: Player, kind: String, arg: String) -> String:
	if p == null or _range == null:
		return "!The range is closed."
	if Progression.gates_on() and Progression.rank() < RANK:
		return "!Walt: \"Members only. Come back when you're known in town.\" (Needs rank %d, %s)" % [
				RANK, Progression.rank_name(RANK)]
	if p.global_position.distance_to(_range.desk.global_position) > 6.0 and kind != "return":
		return "!Talk to Walt at the counter."
	match kind:
		"drill":
			return _host_start_drill(p)
		"try":
			return _host_lend(p, arg)
		"return":
			return _host_return(p, "Walt takes the loaner back.")
	return "!?"


func _host_start_drill(p: Player) -> String:
	for lane: int in drills:
		if drills[lane]["name"] == p.player_name:
			return "!You are already on lane %d." % (lane + 1)
	var lane: int = -1
	for l: int in ShootingRange.LANES:
		if not drills.has(l):
			lane = l
			break
	if lane < 0:
		return "!All lanes are busy. Wait a moment."
	if not GameState.add_cash(p.player_name, -DRILL_FEE, true):
		return "!A drill costs €%d." % DRILL_FEE
	p.send_wallet()
	host_begin_drill(p, lane)
	return "Lane %d, %d seconds: hit the targets as they pop up (bullseye = 2 points). Go!" % [lane + 1, int(DRILL_SECONDS)]


## Host: starts a drill for `p` on `lane` (also used by tests).
func host_begin_drill(p: Player, lane: int) -> void:
	var now: float = _now()
	drills[lane] = {"name": p.player_name, "peer": p.peer_id, "ends": now + DRILL_SECONDS, "score": 0, "hits": 0,
			"bulls": 0, "up": -1, "up_until": 0.0, "next": now + 1.5}
	_set_targets(lane, -1)
	_send_board(lane)
	print("[Range] %s starts a drill on lane %d" % [p.player_name, lane + 1])


func _drill_step(lane: int, now: float) -> void:
	var d: Dictionary = drills[lane]
	var p: Player = _player(str(d["name"]))
	if p == null or p.dead or not covers(p.global_position):
		_finish(lane, "You left the lane: the drill is over.")
		return
	if now >= float(d["ends"]):
		_finish(lane, "")
		return
	if int(d["up"]) >= 0 and now >= float(d["up_until"]):
		d["up"] = -1
		d["next"] = now + POP_GAP
		_set_targets(lane, -1)
	elif int(d["up"]) < 0 and now >= float(d["next"]):
		host_pop(lane, randi() % ShootingRange.DISTANCES.size())


## Host: target `i` of `lane` pops up (the others are down).
func host_pop(lane: int, i: int) -> void:
	if not drills.has(lane):
		return
	var d: Dictionary = drills[lane]
	d["up"] = i
	d["up_until"] = _now() + UP_BASE + UP_PER_M * ShootingRange.DISTANCES[i]
	_set_targets(lane, i)


## Host (RangeTarget.host_damage): `p` hit a standing target.
func host_hit(t: RangeTarget, p: Player, bull: bool) -> void:
	if not drills.has(t.lane):
		return  # free practice: the hit marker is all
	var d: Dictionary = drills[t.lane]
	if d["name"] != p.player_name or int(d["up"]) != t.index:
		return
	d["score"] = int(d["score"]) + (2 if bull else 1)
	d["hits"] = int(d["hits"]) + 1
	if bull:
		d["bulls"] = int(d["bulls"]) + 1
	d["up"] = -1
	d["next"] = _now() + POP_GAP
	_set_targets(t.lane, -1)
	_send_board(t.lane)


## Host: ends the drill on `lane` now (tests use it too). Returns the result text.
func host_finish(lane: int) -> String:
	return _finish(lane, "")


func _finish(lane: int, why: String) -> String:
	if not drills.has(lane):
		return ""
	var d: Dictionary = drills[lane]
	drills.erase(lane)
	_set_targets(lane, -2)
	var who: String = str(d["name"])
	var score: int = int(d["score"])
	var data: Dictionary = _data()
	var old: float = float((data["skill"] as Dictionary).get(who, 0.0))
	var gain: float = minf(SKILL_MAX_PER_DRILL, score * SKILL_PER_POINT) * (1.0 - old * 0.5)
	var now_skill: float = clampf(old + gain, 0.0, 1.0)
	(data["skill"] as Dictionary)[who] = now_skill
	var best: Dictionary = data["best"]
	var record: bool = score > int(best.get(who, 0))
	if record:
		best[who] = score
	skill[who] = now_skill
	var p: Player = _player(who)
	var xp: int = mini(XP_MAX_PER_DRILL, score / 2)
	if xp > 0 and p:
		Progression.host_add(xp, "range drill", p)
	var text: String = "%sDrill over: %d points (%d hits, %d bullseyes)%s. Skill %d%% (%d%% less spread)." % [
			why + " " if why != "" else "", score, int(d["hits"]), int(d["bulls"]), " - a new best!" if record else "",
			roundi(now_skill * 100.0), roundi((1.0 - spread_factor(who)) * 100.0)]
	print("[Range] %s: %s" % [who, text])
	if p:
		p.show_message(text)
	_send_board(lane, "Lane %d - %s: %d points" % [lane + 1, who, score])
	sync()
	return text


# --- Host: loaner guns --------------------------------------------------------------------

func _host_lend(p: Player, weapon_id: String) -> String:
	var w := ItemDB.get_item(StringName(weapon_id)) as WeaponData
	if w == null or not StringName(weapon_id) in PlayerCombat.LOADOUT:
		return "!Walt doesn't have that one."
	var pd: Dictionary = GameState.get_or_create_player_data(p.player_name)
	if pd.get("range_loan") is Dictionary:
		return "!Bring the %s back first." % _weapon_name(str(pd["range_loan"]["weapon"]))
	if GameState.count_item(p.player_name, weapon_id) > 0:
		return "!You already carry a %s." % w.display_name
	var rounds: int = w.magazine_size * TRY_MAGS
	if GameState.space_for(p.player_name, weapon_id) < 1 or GameState.space_for(p.player_name, String(w.ammo_id)) < rounds:
		return "!Your pockets are full."
	if not GameState.add_cash(p.player_name, -TRY_FEE, true):
		return "!Trying a gun costs €%d." % TRY_FEE
	GameState.give(p.player_name, 0, [{"id": weapon_id, "count": 1}, {"id": String(w.ammo_id), "count": rounds}])
	pd["range_loan"] = {"weapon": weapon_id, "ammo": String(w.ammo_id), "rounds": rounds, "until": _now() + LOAN_SECONDS}
	loans[p.player_name] = weapon_id
	p.send_wallet()
	if p.combat:
		p.combat.host_send_all_ammo()
	sync()
	print("[Range] %s borrows a %s" % [p.player_name, weapon_id])
	return "Walt hands you a %s and %d rounds. Stay on the range: it goes back when you leave." % [w.display_name, rounds]


## Host: takes the loaner back from `p` (the gun, its loaded rounds and up to the lent rounds).
func _host_return(p: Player, text: String) -> String:
	var pd: Dictionary = GameState.get_or_create_player_data(p.player_name)
	var loan: Variant = pd.get("range_loan")
	if not loan is Dictionary:
		return "!You have nothing of Walt's."
	var weapon_id: String = str(loan["weapon"])
	GameState.remove_item(p.player_name, weapon_id, 1)
	var left: int = mini(int(loan["rounds"]), GameState.count_item(p.player_name, str(loan["ammo"])))
	if left > 0:
		GameState.remove_item(p.player_name, str(loan["ammo"]), left)
	if p.combat:
		var idx: int = PlayerCombat.LOADOUT.find(StringName(weapon_id))
		if idx >= 0 and GameState.count_item(p.player_name, weapon_id) == 0:
			p.combat._h_mags[idx] = 0  # the loaded rounds go back with the gun
		p.combat.host_send_all_ammo()
	pd.erase("range_loan")
	loans.erase(p.player_name)
	p.send_wallet()
	sync()
	print("[Range] %s returns the %s" % [p.player_name, weapon_id])
	return text


## Host: loaners go back when their player leaves the range or the time is up; a dead player's loaner is lost
## (it is in their loot bag), the record goes.
func host_check_loans() -> void:
	if _range == null:
		return
	for n: String in GameState.player_data.keys():
		var pd: Dictionary = GameState.player_data[n]
		if not pd.get("range_loan") is Dictionary:
			continue
		var p: Player = _player(n)
		if p == null:
			continue
		if p.dead:
			pd.erase("range_loan")
			loans.erase(n)
			sync()
			continue
		var far: bool = p.global_position.distance_to(_range.global_position) > LOAN_RANGE
		var late: bool = _now() > float(pd["range_loan"].get("until", 0.0))
		if far or late:
			var text: String = _host_return(p, "Walt's loaner went back to the club.")
			p.show_message(text if not late else "Time's up: " + text)


func _weapon_name(id: String) -> String:
	var it: ItemData = ItemDB.get_item(StringName(id))
	return it.display_name if it else id


# --- Sync ----------------------------------------------------------------------------------

## Host: targets of `lane` on every peer: `up` = the standing one, -1 = all down, -2 = all up (free practice).
func _set_targets(lane: int, up: int) -> void:
	_apply_targets(lane, up)
	if multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0:
		_targets_rpc.rpc(lane, up)


@rpc("authority", "call_remote", "reliable")
func _targets_rpc(lane: int, up: int) -> void:
	_apply_targets(lane, up)


func _apply_targets(lane: int, up: int) -> void:
	if _range == null or not is_instance_valid(_range):
		return
	for i: int in ShootingRange.DISTANCES.size():
		var t: RangeTarget = _range.target(lane, i)
		if t:
			t.set_up(up == -2 or up == i)


func _send_board(lane: int, text: String = "") -> void:
	if text == "" and drills.has(lane):
		var d: Dictionary = drills[lane]
		text = "Lane %d - %s   %d s   %d points" % [lane + 1, d["name"], maxi(0, ceili(float(d["ends"]) - _now())),
				int(d["score"])]
	elif text == "":
		text = "Lane %d - free practice" % (lane + 1)
	_apply_board(lane, text)
	if multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0:
		_board_rpc.rpc(lane, text)


@rpc("authority", "call_remote", "reliable")
func _board_rpc(lane: int, text: String) -> void:
	_apply_board(lane, text)


func _apply_board(lane: int, text: String) -> void:
	if _range and is_instance_valid(_range):
		_range.set_board(lane, text)


## Host: skill, best scores and loans to every peer (also on a late join: Staff._broadcast / _request_sync).
func sync() -> void:
	if not _is_host() or GameState.world.is_empty():
		return
	var best: Dictionary = (_data()["best"] as Dictionary).duplicate()
	if multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0:
		_sync.rpc(skill, best, loans)


@rpc("authority", "call_remote", "reliable")
func _sync(s: Dictionary, best: Dictionary, l: Dictionary) -> void:
	skill = s
	_best_seen = best
	loans = l
	var w := _window()
	if w:
		w.refresh()


@rpc("any_peer", "call_remote", "reliable")
func _request_sync() -> void:
	if not multiplayer.is_server():
		return
	var peer: int = multiplayer.get_remote_sender_id()
	_sync.rpc_id(peer, skill, (_data()["best"] as Dictionary).duplicate(), loans)
	for lane: int in ShootingRange.LANES:
		var d: Variant = drills.get(lane)
		_targets_rpc.rpc_id(peer, lane, int((d as Dictionary)["up"]) if d is Dictionary else -2)


@rpc("authority", "call_remote", "reliable")
func _answer_rpc(text: String) -> void:
	_answer(text)


func _answer(text: String) -> void:
	var me: Player = _local_player()
	if me and me.ui and text != "":
		me.ui.toast(text.trim_prefix("!"))
	var w := _window()
	if w:
		w.show_answer(text)


func _window() -> RangeWindow:
	var me: Player = _local_player()
	return me.ui.get_node_or_null("RangeWindow") as RangeWindow if me and me.ui else null


func _player(player_name: String) -> Player:
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		if n is Player and (n as Player).player_name == player_name:
			return n as Player
	return null


func _local_player() -> Player:
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		if n is Player and (n as Player).is_local():
			return n as Player
	return null
