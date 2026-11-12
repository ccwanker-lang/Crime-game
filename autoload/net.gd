extends Node
## Networking: hosting, joining and the list of connected players.
## The host (peer id 1) is authoritative. Singleplayer = host without clients.
##
## Join flow:
##   client connects -> sends _register_player(name) to host
##   host validates the name -> broadcasts the full player list (_sync_players)
##   client receives its first list -> join_succeeded is emitted

signal players_changed
signal join_succeeded
signal join_failed(reason: String)
signal server_disconnected

const DEFAULT_PORT: int = 7777
const MAX_PLAYERS: int = 4
const MAX_NAME_LENGTH: int = 16
const MAIN_MENU_SCENE: String = "res://scenes/main_menu/main_menu.tscn"

## peer_id (int) -> { "name": String }
var players: Dictionary = {}
## Name of the local player (also used as save key on the host).
var local_name: String = ""
## Message for the main menu after a disconnect or error.
var last_message: String = ""

## Host: peers whose world scene is loaded. Spawns and state sync only go to
## them, otherwise a joining client gets nodes before it has a World to put them in.
var peers_in_world: Array[int] = []

var _joined: bool = false


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


# --- Public API -------------------------------------------------------------

func host_game(player_name: String, port: int = DEFAULT_PORT) -> Error:
	leave_game()
	var peer := ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(port, MAX_PLAYERS - 1)
	if err != OK:
		push_warning("[Net] create_server failed: %s" % error_string(err))
		return err
	multiplayer.multiplayer_peer = peer
	local_name = sanitize_name(player_name)
	players[1] = {"name": local_name}
	_joined = true
	print("[Net] Hosting on port %d as '%s'" % [port, local_name])
	players_changed.emit()
	return OK


func join_game(address: String, player_name: String, port: int = DEFAULT_PORT) -> Error:
	leave_game()
	var peer := ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(address.strip_edges(), port)
	if err != OK:
		push_warning("[Net] create_client failed: %s" % error_string(err))
		return err
	multiplayer.multiplayer_peer = peer
	local_name = sanitize_name(player_name)
	print("[Net] Connecting to %s:%d as '%s'" % [address, port, local_name])
	return OK


## Closes any connection and goes back to offline mode.
func leave_game() -> void:
	var peer: MultiplayerPeer = multiplayer.multiplayer_peer
	if peer != null and not (peer is OfflineMultiplayerPeer):
		peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_joined = false
	peers_in_world.clear()
	if not players.is_empty():
		players.clear()
		players_changed.emit()


## Use for every MultiplayerSynchronizer of a spawned node (players, NPCs):
## it then only syncs (and spawns) to peers that have the world loaded.
func limit_sync_to_world(sync: MultiplayerSynchronizer) -> void:
	sync.public_visibility = false
	sync.add_to_group(&"world_sync")
	sync.set_visibility_for(1, true)  # clients always talk to the host
	for peer: int in peers_in_world:
		sync.set_visibility_for(peer, true)


## Host: a client finished loading the world -> start sending it spawns/sync.
func mark_peer_in_world(peer: int) -> void:
	if peer in peers_in_world:
		return
	peers_in_world.append(peer)
	for sync: Node in get_tree().get_nodes_in_group(&"world_sync"):
		(sync as MultiplayerSynchronizer).set_visibility_for(peer, true)


func is_online() -> bool:
	return multiplayer.multiplayer_peer is ENetMultiplayerPeer


func is_host() -> bool:
	return multiplayer.is_server()


func get_player_name(peer_id: int) -> String:
	if players.has(peer_id):
		return players[peer_id]["name"]
	return "Unknown"


static func sanitize_name(raw: String) -> String:
	var clean: String = raw.strip_edges().substr(0, MAX_NAME_LENGTH)
	if clean.is_empty():
		clean = "Player%d" % randi_range(100, 999)
	return clean


# --- Multiplayer callbacks --------------------------------------------------

func _on_peer_connected(peer_id: int) -> void:
	# Host waits for _register_player before adding the peer to the list.
	if multiplayer.is_server():
		print("[Net] Peer %d connected, waiting for registration" % peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return  # clients get the updated list from the host
	peers_in_world.erase(peer_id)
	if players.erase(peer_id):
		print("[Net] Peer %d left" % peer_id)
		_sync_players.rpc(players)
		players_changed.emit()


func _on_connected_to_server() -> void:
	print("[Net] Connected, registering as '%s'" % local_name)
	_register_player.rpc_id(1, local_name)


func _on_connection_failed() -> void:
	leave_game()
	join_failed.emit("Could not connect to host.")


func _on_server_disconnected() -> void:
	last_message = "Lost connection to the host."
	leave_game()
	server_disconnected.emit()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


# --- RPCs -------------------------------------------------------------------

## Client -> host: ask to join with a name. Host validates.
@rpc("any_peer", "call_remote", "reliable")
func _register_player(player_name: String) -> void:
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	var clean: String = sanitize_name(player_name)
	for info: Dictionary in players.values():
		if String(info["name"]).to_lower() == clean.to_lower():
			_registration_rejected.rpc_id(sender, "Name '%s' is already in use." % clean)
			return
	players[sender] = {"name": clean}
	print("[Net] Registered peer %d as '%s'" % [sender, clean])
	_sync_players.rpc(players)
	players_changed.emit()


## Host -> clients: full player list.
@rpc("authority", "call_remote", "reliable")
func _sync_players(all_players: Dictionary) -> void:
	players = all_players
	players_changed.emit()
	if not _joined:
		print("[Net] Joined (%d players)" % players.size())
		_joined = true
		join_succeeded.emit()


## Host -> one client: join refused (client disconnects itself).
@rpc("authority", "call_remote", "reliable")
func _registration_rejected(reason: String) -> void:
	leave_game()
	join_failed.emit(reason)
