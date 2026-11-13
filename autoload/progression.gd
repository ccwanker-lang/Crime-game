extends Node
## Ranks + XP (DESIGN "Progression"), autoload `Progression`. HOST AUTHORITATIVE.
## - XP belongs to the crew (DESIGN: the host owns the rank), stored in
##   GameState.world["progress"]["xp"], so it is saved with the world.
## - The host adds XP (host_add / host_sale / host_kill) and sends the total to every peer;
##   clients only show it (rank panel in the HUD, locked rows in shop windows).
## - Gates: a shop / the estate agent refuses items and properties above the crew's rank
##   (RankConfig.item_rank / property_rank). Off in --selftest runs and in test scenarios
##   (they hand out gear freely), unless `force_gates` (the "ranks" scenario, the rank self-test).
## - Debug: F8 (host) = +100 XP.

const CONFIG_PATH: String = "res://data/progression/ranks.tres"
const MAX_RANK: int = 6
const DEBUG_XP: int = 100

## (every peer) the crew's XP changed.
signal xp_changed(xp: int, rank: int)
## (the earning player's peer) +XP popup.
signal xp_gained(amount: int, reason: String)
## (every peer) the crew reached a new rank.
signal ranked_up(rank: int)

var config: RankConfig
## Every peer: the crew XP as last known (host: mirrors GameState).
var xp: int = 0
## Gates on in tests too (the "ranks" scenario / self-test check).
var force_gates: bool = false
var _selftest: bool = false
## Tests: `--xp=N` sets the crew XP once the host's world exists (e.g. a client sync check).
var _start_xp: int = -1


func _ready() -> void:
	config = load(CONFIG_PATH) as RankConfig
	if config == null:
		config = RankConfig.new()
	_selftest = "--selftest" in OS.get_cmdline_user_args()
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--xp="):
			_start_xp = a.trim_prefix("--xp=").to_int()
	GameState.world_changed.connect(_on_world_changed)
	multiplayer.connected_to_server.connect(func() -> void: xp = 0)


# --- Reading (every peer) ------------------------------------------------------------

func rank() -> int:
	return rank_for(xp)


func rank_for(amount: int) -> int:
	var r: int = 0
	for i: int in config.xp_for_rank.size():
		if amount >= config.xp_for_rank[i]:
			r = i
	return mini(r, MAX_RANK)


func rank_name(r: int) -> String:
	return config.names[r] if r >= 0 and r < config.names.size() else "Rank %d" % r


func unlocks(r: int) -> String:
	return config.unlock_text[r] if r >= 0 and r < config.unlock_text.size() else ""


## XP needed for rank `r` (INF-like -1 past the top).
func xp_for(r: int) -> int:
	return config.xp_for_rank[r] if r >= 0 and r < config.xp_for_rank.size() else -1


func item_rank(id: StringName) -> int:
	return int(config.item_rank.get(id, config.item_rank.get(String(id), 0)))


func property_rank(id: StringName) -> int:
	return int(config.property_rank.get(id, config.property_rank.get(String(id), 0)))


## Are rank gates enforced right now?
func gates_on() -> bool:
	if force_gates:
		return true
	return not _selftest and not SaveManager.scenario_mode


## "" if the crew may buy item `id`, else the reason ("Needs rank 2 (Dealer)").
func item_lock(id: StringName) -> String:
	return _lock(item_rank(id))


func property_lock(id: StringName) -> String:
	return _lock(property_rank(id))


func _lock(need: int) -> String:
	if not gates_on() or need <= rank():
		return ""
	return "Needs rank %d (%s)" % [need, rank_name(need)]


# --- Host: earning XP ----------------------------------------------------------------

func _is_host() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()


## Host: crew XP from the save (0 for a new game or a save from before ranks).
func host_xp() -> int:
	var progress: Variant = GameState.world.get("progress", {})
	return int((progress as Dictionary).get("xp", 0)) if progress is Dictionary else 0


## Host: add `amount` XP for the crew; `by` (a Player, may be null) gets the "+XP" popup.
func host_add(amount: int, reason: String, by: Node = null) -> void:
	if not _is_host() or amount == 0:
		return
	var before: int = rank_for(host_xp())
	var total: int = maxi(0, host_xp() + amount)
	if not GameState.world.get("progress") is Dictionary:
		GameState.world["progress"] = {}
	(GameState.world["progress"] as Dictionary)["xp"] = total
	var who: String = str(by.get("player_name")) if by else "-"
	print("[Rank] %s %+d XP (%s) -> %d XP, rank %d" % [who, amount, reason, total, rank_for(total)])
	_broadcast(total)
	if by and amount > 0:
		var peer: int = int(by.get("peer_id"))
		if peer == multiplayer.get_unique_id() or not multiplayer.has_multiplayer_peer():
			_gained(amount, reason)
		elif peer > 0:
			_gained.rpc_id(peer, amount, reason)
	var after: int = rank_for(total)
	if after > before and reason != "debug":  # (tests / scenarios set a rank without the banner)
		print("[Rank] crew reached rank %d (%s)" % [after, rank_name(after)])
		_ranked_up(after)
		if multiplayer.has_multiplayer_peer():
			_ranked_up.rpc(after)


## Host: a weed sale finished (Pedestrian._server_sell). outcome = fair / short / run.
func host_sale(seller: Node, bags: int, _paid: int, outcome: String, phone_deal: bool) -> void:
	var amount: float = 0.0
	if outcome != "run":
		amount = bags * config.xp_per_bag + (config.xp_phone_deal if phone_deal else 0)
		if outcome == "short":
			amount *= config.xp_short_factor
	host_add(roundi(amount), "phone deal" if phone_deal else "sale", seller)


## Host: `killer` (a Player) killed `victim` (PlayerCombat._host_fire).
func host_kill(killer: Node, victim: Node) -> void:
	if not killer is Player or victim == killer or victim is Player:
		return
	if victim is Rival:
		host_add(config.xp_kill_rival, "Crow down", killer)
	elif victim is PoliceOfficer:
		host_add(config.xp_kill_officer, "officer down", killer)
	elif victim is Pedestrian:
		host_add(config.xp_kill_civilian, "kill", killer)


## Host / tests: set the crew to exactly `r` (XP = that rank's threshold).
func debug_set_rank(r: int) -> void:
	host_add(xp_for(clampi(r, 0, MAX_RANK)) - host_xp(), "debug")


# --- Sync ------------------------------------------------------------------------------

func _on_world_changed() -> void:
	if GameState.world.is_empty():
		force_gates = false  # GameState.reset: leaving / a new scenario
	if _is_host() and _start_xp >= 0 and not GameState.world.is_empty():
		var start: int = _start_xp
		_start_xp = -1
		GameState.world["progress"] = {"xp": start}
		print("[Rank] --xp: crew starts with %d XP" % start)
	if _is_host():
		_broadcast(host_xp())


func _broadcast(total: int) -> void:
	_set_xp(total)
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server() and multiplayer.get_peers().size() > 0:
		_set_xp.rpc(total)


## Client (its HUD is up): ask the host for the current XP.
func request_sync() -> void:
	if _is_host():
		_set_xp(host_xp())
	else:
		_request_sync.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _request_sync() -> void:
	if multiplayer.is_server():
		_set_xp.rpc_id(multiplayer.get_remote_sender_id(), host_xp())


@rpc("authority", "call_remote", "reliable")
func _set_xp(total: int) -> void:
	if total != xp and multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		print("[Rank] client %d: crew XP %d, rank %d" % [multiplayer.get_unique_id(), total, rank_for(total)])
	xp = total
	xp_changed.emit(xp, rank())


@rpc("authority", "call_remote", "reliable")
func _gained(amount: int, reason: String) -> void:
	xp_gained.emit(amount, reason)


@rpc("authority", "call_remote", "reliable")
func _ranked_up(r: int) -> void:
	ranked_up.emit(r)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.physical_keycode == KEY_F8 and _is_host():
		var world: Node = get_tree().current_scene
		if world == null or world.get_node_or_null("Players") == null:
			return
		var me: Node = world.get_node("Players").get_node_or_null(str(multiplayer.get_unique_id()))
		host_add(DEBUG_XP, "debug F8", me)
