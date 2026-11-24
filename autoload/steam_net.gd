extends Node
## Online co-op through Steam (session B, user list item 4), with GodotSteam (GDExtension in addons/godotsteam) on the
## test app id 480 (Spacewar). Host: a friends-only Steam lobby + a SteamMultiplayerPeer host; friends join from the
## title page ("Friends' games"), from an invite, or from Steam ("Join game" in the friends list / +connect_lobby).
## Everything after the peer is set up is the normal Net flow (registration, join_succeeded, the loading screen).
## LAN / IP (ENet) stays: Steam off, not running, or failing -> the menu hosts / joins by IP as before.
## All Steam calls go through `steam` (Object) so the game still runs where the extension can't load.
## Not started in test runs (headless, --name=, test flags) unless `--steam` is given.

signal status(text: String)
signal host_ready
signal host_failed(reason: String)
## [{lobby, name, players, owner}] of friends' lobbies.
signal lobbies_found(list: Array)
signal invites_changed

const APP_ID: int = 480
## Lobby data "game" = this, so other Spacewar lobbies (app 480 is shared by everyone) are never listed.
const LOBBY_KEY: String = "crime_coop_b1"
const LOBBY_FRIENDS_ONLY: int = 1
const FRIEND_FLAG_IMMEDIATE: int = 4
const LOBBY_COMPARISON_EQUAL: int = 0
const LOBBY_DISTANCE_WORLDWIDE: int = 3
const LOBBY_OK: int = 1
const SETTINGS_PATH: String = "user://settings.cfg"

var steam: Object = null
var started: bool = false
var message: String = ""
var lobby_id: int = 0
## Lobby to join once the title page is up (invite accepted in Steam, +connect_lobby on the command line).
var pending_lobby: int = 0
## [{lobby, from}] invites received (lobby_invite).
var invites: Array = []
## Title page checkbox "Friends can join via Steam" (settings.cfg [network] steam_host).
var host_via_steam: bool = true
var _host_name: String = ""
var _join_name: String = ""
var _hosting: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if Engine.has_singleton("Steam"):
		steam = Engine.get_singleton("Steam")
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		host_via_steam = bool(cfg.get_value("network", "steam_host", true))
	var args: PackedStringArray = OS.get_cmdline_args()
	var i: int = args.find("+connect_lobby")
	if i >= 0 and i + 1 < args.size():
		pending_lobby = args[i + 1].to_int()
	if "--steam-check" in OS.get_cmdline_user_args():
		_live_check.call_deferred()
	elif not test_run():
		start()


## The extension is loaded (Steam class + SteamMultiplayerPeer exist).
func available() -> bool:
	return steam != null and ClassDB.class_exists("SteamMultiplayerPeer")


static func test_run() -> bool:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--steam" in args:
		return false
	if DisplayServer.get_name() == "headless":
		return true
	for a: String in args:
		if a.begins_with("--name=") or a in SaveManager.TEST_FLAGS or a.begins_with("--scenario"):
			return true
	return false


## Starts Steam (once). False (+ `message`) when it can't: no extension, Steam not running, not logged in.
func start() -> bool:
	if started:
		return true
	if not available():
		message = "Steam support is not loaded."
		return false
	if not bool(steam.call("isSteamRunning")):
		message = "Steam is not running."
		return false
	OS.set_environment("SteamAppId", str(APP_ID))
	OS.set_environment("SteamGameId", str(APP_ID))
	var r: Dictionary = steam.call("steamInitEx", APP_ID, true)
	if int(r.get("status", -1)) != 0:
		message = "Steam could not start: %s" % str(r.get("verbal", "?"))
		print("[SteamNet] %s" % message)
		return false
	started = true
	message = "Steam: %s" % str(steam.call("getPersonaName"))
	for pair: Array in [["lobby_created", _on_lobby_created], ["lobby_joined", _on_lobby_joined],
			["lobby_match_list", _on_lobby_match_list], ["join_requested", _on_join_requested],
			["lobby_invite", _on_lobby_invite]]:
		steam.connect(pair[0], pair[1])
	print("[SteamNet] started (app %d) as %s" % [APP_ID, steam.call("getPersonaName")])
	return true


## The title page hosts through Steam (checkbox on and Steam up).
func should_host() -> bool:
	return host_via_steam and not test_run() and start()


func set_host_via_steam(on: bool) -> void:
	host_via_steam = on
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("network", "steam_host", on)
	cfg.save(SETTINGS_PATH)


func my_id() -> int:
	return int(steam.call("getSteamID")) if started else 0


func in_steam_game() -> bool:
	return started and lobby_id != 0 and Net.transport == "steam" and Net.is_online()


# --- Hosting ---------------------------------------------------------------------------

## Creates the lobby; host_ready (peer set, go to the world) or host_failed (fall back to IP) follows.
func host(player_name: String) -> void:
	if not start():
		host_failed.emit(message)
		return
	_host_name = player_name
	_hosting = true
	status.emit("Creating a Steam lobby...")
	steam.call("createLobby", LOBBY_FRIENDS_ONLY, Net.MAX_PLAYERS)


func _on_lobby_created(result: int, new_lobby: int) -> void:
	if not _hosting:
		return
	_hosting = false
	if result != LOBBY_OK:
		host_failed.emit("Steam could not create a lobby (code %d)." % result)
		return
	lobby_id = new_lobby
	steam.call("setLobbyData", lobby_id, "game", LOBBY_KEY)
	steam.call("setLobbyData", lobby_id, "name", "%s's game" % Net.sanitize_name(_host_name))
	steam.call("setLobbyData", lobby_id, "owner", str(my_id()))
	steam.call("setLobbyJoinable", lobby_id, true)
	var peer: MultiplayerPeer = ClassDB.instantiate("SteamMultiplayerPeer")
	var err: int = int(peer.call("create_host", 0))
	if err != OK:
		steam.call("leaveLobby", lobby_id)
		lobby_id = 0
		host_failed.emit("Steam could not host (%s)." % error_string(err))
		return
	Net.leave_game()
	Net.host_with_peer(peer, _host_name, "steam")
	print("[SteamNet] hosting in lobby %d" % lobby_id)
	host_ready.emit()


## Opens Steam's own invite window (needs the Steam overlay).
func invite_overlay() -> void:
	if in_steam_game():
		steam.call("activateGameOverlayInviteDialog", lobby_id)


## [{id, name, online}] of Steam friends, online first.
func friends() -> Array:
	var out: Array = []
	if not started:
		return out
	var n: int = int(steam.call("getFriendCount", FRIEND_FLAG_IMMEDIATE))
	for i: int in n:
		var id: int = int(steam.call("getFriendByIndex", i, FRIEND_FLAG_IMMEDIATE))
		out.append({"id": id, "name": str(steam.call("getFriendPersonaName", id)),
				"online": int(steam.call("getFriendPersonaState", id)) != 0})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["online"] and not b["online"] if a["online"] != b["online"] else str(a["name"]).nocasecmp_to(b["name"]) < 0)
	return out


func invite(friend_id: int) -> bool:
	if not in_steam_game():
		return false
	return bool(steam.call("inviteUserToLobby", lobby_id, friend_id))


# --- Joining ---------------------------------------------------------------------------

## Looks for friends' games (lobbies_found follows).
func find_lobbies() -> void:
	if not start():
		lobbies_found.emit([])
		return
	steam.call("addRequestLobbyListStringFilter", "game", LOBBY_KEY, LOBBY_COMPARISON_EQUAL)
	steam.call("addRequestLobbyListDistanceFilter", LOBBY_DISTANCE_WORLDWIDE)
	steam.call("requestLobbyList")


func _on_lobby_match_list(lobbies: Array) -> void:
	var out: Array = []
	for l: Variant in lobbies:
		var lob: int = int(l)
		var owner: int = str(steam.call("getLobbyData", lob, "owner")).to_int()
		if owner == my_id() or not bool(steam.call("hasFriend", owner, FRIEND_FLAG_IMMEDIATE)):
			continue
		out.append({"lobby": lob, "owner": owner, "name": str(steam.call("getLobbyData", lob, "name")),
				"players": int(steam.call("getNumLobbyMembers", lob))})
	lobbies_found.emit(out)


## Joins a friend's lobby, then connects to its owner; the rest is Net's join flow.
func join(lobby: int, player_name: String) -> void:
	if not start():
		Net.join_failed.emit(message)
		return
	_join_name = player_name
	status.emit("Joining the Steam lobby...")
	steam.call("joinLobby", lobby)


func _on_lobby_joined(lobby: int, _permissions: int, _locked: bool, response: int) -> void:
	if _hosting or (lobby == lobby_id and Net.transport == "steam" and multiplayer.is_server()):
		return  # (the host enters its own lobby, sometimes before lobby_created)
	if response != LOBBY_OK:
		Net.join_failed.emit("Could not join the Steam game (code %d): full, closed or no longer there." % response)
		return
	var owner: int = int(steam.call("getLobbyOwner", lobby))
	if owner == my_id():
		return
	if owner == 0:
		Net.join_failed.emit("That Steam game has no host any more.")
		steam.call("leaveLobby", lobby)
		return
	lobby_id = lobby
	var peer: MultiplayerPeer = ClassDB.instantiate("SteamMultiplayerPeer")
	var err: int = int(peer.call("create_client", owner, 0))
	if err != OK:
		Net.join_failed.emit("Steam could not connect (%s)." % error_string(err))
		return
	Net.leave_game()
	Net.join_with_peer(peer, _join_name, "steam")
	status.emit("Connected through Steam - waiting for the host to let you in...")
	print("[SteamNet] joining lobby %d (host %d)" % [lobby, owner])


## Steam "Join game" (friends list) or an accepted invite: go to the title page, which joins `pending_lobby`.
func _on_join_requested(lobby: int, _friend: int) -> void:
	pending_lobby = lobby
	print("[SteamNet] join requested: lobby %d" % lobby)
	var scene: Node = get_tree().current_scene
	if scene and scene.scene_file_path == Net.MAIN_MENU_SCENE:
		scene.call("check_pending_steam")
		return
	if multiplayer.is_server() and Net.is_online():
		SaveManager.save_game()
	Net.leave_game()
	get_tree().paused = false
	get_tree().change_scene_to_file(Net.MAIN_MENU_SCENE)


func _on_lobby_invite(inviter: int, lobby: int, _game: int) -> void:
	invites = invites.filter(func(d: Dictionary) -> bool: return int(d["lobby"]) != lobby)
	invites.append({"lobby": lobby, "from": str(steam.call("getFriendPersonaName", inviter))})
	invites_changed.emit()


func _process(_delta: float) -> void:
	# Left the game (menu, lost connection): leave the lobby too, so friends no longer see it.
	if lobby_id != 0 and started and not Net.is_online():
		steam.call("leaveLobby", lobby_id)
		print("[SteamNet] left lobby %d" % lobby_id)
		lobby_id = 0


# --- Live check ----------------------------------------------------------------------------

## `-- --steam-check` (needs Steam running + logged in): starts Steam on app 480, lists friends, creates a lobby and a
## SteamMultiplayerPeer host, searches friends' lobbies, leaves and quits. Prints "[SteamCheck] ..." lines.
func _live_check() -> void:
	var ok: bool = start()
	print("[SteamCheck] start: %s (%s)" % [ok, message])
	if not ok:
		get_tree().quit(1)
		return
	var fr: Array = friends()
	print("[SteamCheck] friends: %d (%d online)" % [fr.size(), fr.filter(func(f: Dictionary) -> bool: return f["online"]).size()])
	host("SteamCheck")
	var result: Array = [""]
	var on_ready := func() -> void: result[0] = "ready"
	var on_fail := func(r: String) -> void: result[0] = "failed: " + r
	host_ready.connect(on_ready, CONNECT_ONE_SHOT)
	host_failed.connect(on_fail, CONNECT_ONE_SHOT)
	var t: float = 0.0
	while result[0] == "" and t < 15.0:
		await get_tree().create_timer(0.25).timeout
		t += 0.25
	print("[SteamCheck] host: %s, lobby %d, peer %s, transport %s, data game=%s name=%s" % [result[0], lobby_id,
			multiplayer.multiplayer_peer.get_class(), Net.transport,
			steam.call("getLobbyData", lobby_id, "game") if lobby_id else "-",
			steam.call("getLobbyData", lobby_id, "name") if lobby_id else "-"])
	var found: Array = [null]
	lobbies_found.connect(func(l: Array) -> void: found[0] = l, CONNECT_ONE_SHOT)
	find_lobbies()
	t = 0.0
	while found[0] == null and t < 10.0:
		await get_tree().create_timer(0.25).timeout
		t += 0.25
	print("[SteamCheck] friends' lobbies found: %s (own lobby is never listed)" % [found[0]])
	Net.leave_game()
	await get_tree().create_timer(0.5).timeout
	print("[SteamCheck] left: lobby %d, online %s" % [lobby_id, Net.is_online()])
	steam.call("steamShutdown")
	get_tree().quit(0 if result[0] == "ready" else 1)
