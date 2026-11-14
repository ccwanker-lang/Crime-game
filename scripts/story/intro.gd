class_name Intro
extends Node
## Point 49: the story start / tutorial. A NEW game starts on the last day in the prison (prefabs/buildings/
## prison.tscn, far outside the village): every player wakes in a cell and goes through the steps
##   WALK  walk to the cell door (WASD + mouse) -> the guard slides it open
##   TALK  talk to Marco, the fellow prisoner, in the yard (E) -> his number on your phone (first mentor)
##   DESK  collect your things at the release desk (E) -> your phone and wallet back
##   BUS   walk out of the gate and board the bus (E) -> wait until every player in the intro is on it
## then the bus "drives" (fade, two hours later) and drops everyone at the bus stop on the west edge of the
## village; Marco texts and his package (the starter pistol + rounds) is in your pocket.
## HOST AUTHORITATIVE: GameState.world["story"]["intro"] = "running" / "done"; per player
## player_data["intro_step"] (0-4) + "intro_stash" (what they carried, held until the desk / the bus stop).
## A new game = no save data yet; existing saves, the self-test, netcheck, screenshots and scenarios skip it
## (`--intro` forces it, scenario prison_intro). F2 = skip (host: everyone, client: just you).

enum Step { WALK, TALK, DESK, BUS, BOARDED }

const STEP_TEXT: Array[String] = [
	"Your last day inside. Look around (mouse) and walk to the cell door (W A S D).",
	"The door is open. Find Marco in the yard and talk to him (E).",
	"Collect your things at the release desk (E), next to the gate (out of the cell block, across the yard).",
	"Walk out through the gate and get on the bus (E).",
	"On the bus. Waiting for the others...",
]
const CELL_REACH: float = 1.6
const ARRIVE_HOURS: float = 11.0
const MARCO_LINES: Array[String] = [
	"So this is it. Out, after three years. For a job the Crows walked away from.",
	"Viktor Kraal let you rot in here. Me too. He runs the whole village now.",
	"Here's my number. When you're out, call me. We start small: weed.",
	"I paid a month on a room on Main Road. The Starter Room. It's yours.",
	"And watch the black jackets. Crows. They don't like new faces.",
]

static var current: Intro
## Tests: run the late-join intro despite --selftest.
static var late_join_in_tests: bool = false

## Every peer: the local player's step (-1 = not in the intro), for prompts and the HUD.
var local_step: int = -1
var _check_acc: float = 0.0
var _departing: bool = false


func _ready() -> void:
	current = self
	if multiplayer.is_server():
		_decide()


func _exit_tree() -> void:
	if current == self:
		current = null


static func _test_run() -> bool:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for flag: String in ["--selftest", "--netcheck", "--screenshot", "--vmpreview", "--style-shots", "--no-intro"]:
		if flag in args:
			return true
	var sm: Node = Engine.get_main_loop().root.get_node_or_null("/root/SaveManager") if Engine.get_main_loop() else null
	return sm != null and bool(sm.get("scenario_mode"))


## Host: a new game (nothing saved yet) starts with the intro; everything else skips it.
func _decide() -> void:
	var story: Dictionary = GameState.world.get_or_add("story", {})
	if "--intro" in OS.get_cmdline_user_args():
		story["intro"] = "running"
	elif not story.has("intro"):
		var fresh: bool = GameState.player_data.is_empty() and not GameState.world.has("hours")
		story["intro"] = "running" if fresh and not _test_run() else "done"
	print("[Intro] %s" % story["intro"])


func is_running() -> bool:
	return str((GameState.world.get("story", {}) as Dictionary).get("intro", "done")) == "running"


## Host: scenario / test: (re)start the intro for everyone who spawns from now on (and `p` right away).
func debug_start(p: Player = null) -> void:
	(GameState.world.get_or_add("story", {}) as Dictionary)["intro"] = "running"
	if p:
		GameState.get_or_create_player_data(p.player_name).erase("intro_step")
		host_on_spawn(p)


func _prison() -> Node3D:
	return get_parent().find_child("Prison", true, false) as Node3D if get_parent() else null


func _step_of(p: Player) -> int:
	return int(GameState.get_or_create_player_data(p.player_name).get("intro_step", -1))


func _intro_players() -> Array[Player]:
	var out: Array[Player] = []
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p := n as Player
		if p and p.is_inside_tree() and _step_of(p) >= 0:
			out.append(p)
	return out


# --- Host flow ----------------------------------------------------------------------

## Host (World._spawn_player_for): a player joined the world. While the intro runs, new players start in a cell.
## Point 50: a NEW player joining after the intro (`new_player`) gets the short version (`_begin_late`).
func host_on_spawn(p: Player, new_player: bool = false) -> void:
	if not multiplayer.is_server() or _prison() == null:
		return
	var data: Dictionary = GameState.get_or_create_player_data(p.player_name)
	if not is_running():
		if new_player and not data.has("intro_step") and (late_join_in_tests or not _test_run()
				or "--late-intro" in OS.get_cmdline_user_args()):
			_begin_late(p)
		elif data.has("intro_step"):
			_send_step(p)  # (a late joiner who left and came back mid-way)
		return
	if not data.has("intro_step"):
		# Everything they carry waits at the desk (wallet) and with Marco's package (the rest).
		data["intro_stash"] = GameState.take_all(p.player_name)
		data["intro_step"] = Step.WALK
		var cell: int = _free_cell()
		data["intro_cell"] = cell
		var spot := _prison().find_child("Cell%d" % cell, true, false) as Node3D
		if spot:
			_put(p, spot.global_position, spot.global_rotation.y)
		if _intro_players().size() <= 1:
			var dn := get_tree().get_first_node_in_group(&"day_night") as DayNight
			if dn:
				dn.set_hours(8.0)
		p.send_wallet()
		print("[Intro] %s wakes up in cell %d" % [p.player_name, cell])
	elif int(data["intro_step"]) >= Step.TALK:
		_cell_door(int(data.get("intro_cell", 1))).call_deferred("host_unlock")
	_send_step(p)
	_resend_later(p)


## Point 50: the short intro of a later joiner: the cell door already open, Marco's number already on the phone,
## straight to the release desk and the bus (it leaves as soon as they board); the crew gets a text.
func _begin_late(p: Player) -> void:
	var data: Dictionary = GameState.get_or_create_player_data(p.player_name)
	data["intro_stash"] = GameState.take_all(p.player_name)
	data["intro_step"] = Step.DESK
	var cell: int = _free_cell()
	data["intro_cell"] = cell
	var spot := _prison().find_child("Cell%d" % cell, true, false) as Node3D
	if spot:
		_put(p, spot.global_position, spot.global_rotation.y)
	_cell_door(cell).call_deferred("host_unlock")
	p.send_wallet()
	_send_step(p)
	_resend_later(p)
	_say_to(p, "Guard", ["%s! Your release came through. Desk, then the bus. Move." % p.player_name])
	p.phone_message("Marco", "Heard you're out today. Your crew runs things in Riverton now - get on bus 12, they'll fill you in.", "")
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var q := n as Player
		if q and q != p:
			q.phone_message("Marco", "%s gets out today. Bus 12 drops them at the stop on Main Road (west end). Pick them up." % p.player_name, "")
	print("[Intro] %s joins late: short intro in cell %d" % [p.player_name, cell])


## Host, scenario / test: `p` joins as a new player after the intro (the short version).
func debug_late_join(p: Player) -> void:
	(GameState.world.get_or_add("story", {}) as Dictionary)["intro"] = "done"
	GameState.get_or_create_player_data(p.player_name).erase("intro_step")
	_begin_late(p)


func _free_cell() -> int:
	var used: Array = []
	for d: Dictionary in GameState.player_data.values():
		if d.has("intro_step"):
			used.append(int(d.get("intro_cell", 0)))
	for i: int in range(1, 5):
		if i not in used:
			return i
	return 1


func _cell_door(cell: int) -> CellDoor:
	return _prison().find_child("CellDoor%d" % cell, true, false) as CellDoor if _prison() else null


func _put(p: Player, pos: Vector3, yaw: float) -> void:
	p.teleport(pos)
	p.rotation.y = yaw  # (the owner turns its own body; on a client it keeps its yaw)


## Host: a client's player may not exist on its side yet when it spawns: send the step box again a bit later.
func _resend_later(p: Player) -> void:
	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(p) and p.is_inside_tree() and _step_of(p) >= 0:
		_send_step(p)


func _set_step(p: Player, step: int) -> void:
	GameState.get_or_create_player_data(p.player_name)["intro_step"] = step
	_send_step(p)


func _send_step(p: Player) -> void:
	var step: int = _step_of(p)
	var text: String = STEP_TEXT[step] if step >= 0 and step < STEP_TEXT.size() else ""
	if step == Step.BOARDED:
		var all: Array[Player] = _intro_players()
		var on: int = all.filter(func(q: Player) -> bool: return _step_of(q) == Step.BOARDED).size()
		text = "On the bus. Waiting for the others (%d/%d on board)..." % [on, all.size()]
	if p.peer_id == multiplayer.get_unique_id():
		_show_step(step, text)
	else:
		_show_step.rpc_id(p.peer_id, step, text)


func _process(delta: float) -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server() or not is_running():
		return
	_check_acc += delta
	if _check_acc < 0.25:
		return
	_check_acc = 0.0
	for p: Player in _intro_players():
		if _step_of(p) != Step.WALK:
			continue
		var door: CellDoor = _cell_door(int(GameState.get_or_create_player_data(p.player_name).get("intro_cell", 1)))
		if door and p.global_position.distance_to(door.get_center()) < CELL_REACH:
			door.host_unlock()
			_say_to(p, "Guard", ["Cell %s, you're done here. Out you go." % door.name.right(1)])
			_set_step(p, Step.TALK)


## Client -> host: E on an IntroNPC.
func request_talk(role: String) -> void:
	if multiplayer.is_server():
		_host_talk(multiplayer.get_unique_id(), role)
	else:
		_request_talk.rpc_id(1, role)


@rpc("any_peer", "call_remote", "reliable")
func _request_talk(role: String) -> void:
	if multiplayer.is_server():
		_host_talk(multiplayer.get_remote_sender_id(), role)


func _player(peer: int) -> Player:
	return get_parent().get_node_or_null("Players/%d" % peer) as Player


func _host_talk(peer: int, role: String) -> void:
	var p: Player = _player(peer)
	if p == null:
		return
	var step: int = _step_of(p)
	match role:
		"mentor":
			if step == Step.TALK:
				_say_to(p, "Marco", MARCO_LINES)
				p.phone_message("Marco", "It's Marco. Save the number. When you're out: Starter Room on Main Road, the key is under the mat. Benny in Old Town knows people. Weed first, then we grow.", "")
				_set_step(p, Step.DESK)
			elif step > Step.TALK:
				_say_to(p, "Marco", ["Go on, get your things. I'll see you on the outside."])
			else:
				_say_to(p, "Marco", ["Not now. They're watching."])
		"desk":
			if step == Step.DESK:
				var stash: Dictionary = GameState.get_or_create_player_data(p.player_name).get("intro_stash", {})
				var cash: int = int(stash.get("cash", 0))
				GameState.give(p.player_name, cash, [])
				stash["cash"] = 0
				p.send_wallet()
				_say_to(p, "Officer Daems", ["One phone, one wallet. €%d. Sign here." % cash, "Bus is outside. Don't come back."])
				_set_step(p, Step.BUS)
			elif step < Step.DESK:
				_say_to(p, "Officer Daems", ["Not yet. Your friend in the yard wanted a word."] if step == Step.TALK else ["Back to your cell."])
			else:
				_say_to(p, "Officer Daems", ["Bus is outside. Go."])
		_:
			_say_to(p, "Guard", ["Keep moving."])


## Prompt text for an IntroNPC (every peer, from the local step).
func npc_prompt(role: String, npc_name: String) -> String:
	match role:
		"desk":
			return "Collect your things (%s)" % npc_name if local_step == Step.DESK else "Talk to %s" % npc_name
		_:
			return "Talk to %s" % npc_name


static func bus_prompt() -> String:
	if current == null or current.local_step < 0:
		return "The prison bus"
	if current.local_step == Step.BUS:
		return "Get on the bus"
	if current.local_step == Step.BOARDED:
		return "Waiting for the others"
	return "The bus (collect your things first)"


## Client -> host: E on the bus.
func request_board() -> void:
	if multiplayer.is_server():
		_host_board(multiplayer.get_unique_id())
	else:
		_request_board.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _request_board() -> void:
	if multiplayer.is_server():
		_host_board(multiplayer.get_remote_sender_id())


func _host_board(peer: int) -> void:
	var p: Player = _player(peer)
	if p == null or _step_of(p) != Step.BUS:
		return
	_set_step(p, Step.BOARDED)
	print("[Intro] %s is on the bus" % p.player_name)
	var all: Array[Player] = _intro_players()
	for q: Player in all:
		if _step_of(q) == Step.BOARDED:
			_send_step(q)  # (the "n/m on board" count)
	if all.all(func(q: Player) -> bool: return _step_of(q) == Step.BOARDED):
		_depart(all)


## Host: the bus leaves with `riders`: black screen, then the bus stop in the village.
func _depart(riders: Array[Player]) -> void:
	if _departing:
		return
	_departing = true
	var story_start: bool = is_running()  # (a late joiner's ride doesn't change everyone's clock)
	for p: Player in riders:
		_fade_for(p, "Two hours later...")
	await get_tree().create_timer(2.2).timeout
	_departing = false
	if not is_inside_tree():
		return
	var dn := get_tree().get_first_node_in_group(&"day_night") as DayNight
	if dn and story_start and dn.hours < ARRIVE_HOURS:
		dn.set_hours(ARRIVE_HOURS)
	for i: int in riders.size():
		if is_instance_valid(riders[i]):
			_arrive(riders[i], i)
	if _intro_players().is_empty():
		(GameState.world.get_or_add("story", {}) as Dictionary)["intro"] = "done"
		print("[Intro] done: everyone is in the village")


## Host: `p` gets off at the village bus stop (also used to skip): Marco's package, step cleared.
func _arrive(p: Player, index: int = 0) -> void:
	var data: Dictionary = GameState.get_or_create_player_data(p.player_name)
	var stash: Dictionary = data.get("intro_stash", {})
	var leftover: Array = GameState.give(p.player_name, int(stash.get("cash", 0)), stash.get("items", []))
	if not leftover.is_empty() and get_parent().has_method("spawn_loot_bag"):
		get_parent().call("spawn_loot_bag", p.global_position, p.player_name, 0, leftover, true)
	for k: String in ["intro_step", "intro_stash", "intro_cell"]:
		data.erase(k)
	var stop := get_parent().find_child("BusStop", true, false) as Node3D
	if stop:
		var side: Vector3 = stop.global_basis.x * (float(index) * 1.2 - 1.8)
		_put(p, stop.global_position + side + Vector3.UP * 0.2, stop.global_rotation.y)
	p.send_wallet()
	_send_step(p)
	p.phone_message("Marco", "Welcome back to Riverton. I slipped a little package in your bag: a pistol, for the Crows. Starter Room is east along Main Road. Text me when you sold your first bag.", "")
	print("[Intro] %s arrives at the bus stop" % p.player_name)


## Client -> host: F2. The host skips the intro for everyone in it, a client just for themselves.
func request_skip() -> void:
	if multiplayer.is_server():
		_host_skip(multiplayer.get_unique_id())
	else:
		_request_skip.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _request_skip() -> void:
	if multiplayer.is_server():
		_host_skip(multiplayer.get_remote_sender_id())


func _host_skip(peer: int) -> void:
	var p: Player = _player(peer)
	if p == null or _step_of(p) < 0:
		return
	var who: Array[Player] = _intro_players() if peer == 1 else [p] as Array[Player]
	print("[Intro] %s skips the intro%s" % [p.player_name, " for everyone" if peer == 1 else ""])
	_depart(who)


# --- Every peer: HUD -------------------------------------------------------------------

func _local_hud() -> PlayerHUD:
	var me := _player(multiplayer.get_unique_id())
	return me.ui if me else null


@rpc("authority", "call_remote", "reliable")
func _show_step(step: int, text: String) -> void:
	if step != local_step:
		print("[Intro] my step: %d %s" % [step, text.left(40)])
	local_step = step
	var hud: PlayerHUD = _local_hud()
	if hud:
		hud.set_tutorial(text)


func _say_to(p: Player, speaker: String, lines: Array) -> void:
	if p.peer_id == multiplayer.get_unique_id():
		_say(speaker, lines)
	else:
		_say.rpc_id(p.peer_id, speaker, lines)


@rpc("authority", "call_remote", "reliable")
func _say(speaker: String, lines: Array) -> void:
	var hud: PlayerHUD = _local_hud()
	if hud:
		hud.say(speaker, lines)


func _fade_for(p: Player, text: String) -> void:
	if p.peer_id == multiplayer.get_unique_id():
		_fade(text)
	else:
		_fade.rpc_id(p.peer_id, text)


@rpc("authority", "call_remote", "reliable")
func _fade(text: String) -> void:
	var hud: PlayerHUD = _local_hud()
	if hud:
		hud.fade(text, 4.0)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.physical_keycode == KEY_F2 and local_step >= 0:
		request_skip()
		get_viewport().set_input_as_handled()
