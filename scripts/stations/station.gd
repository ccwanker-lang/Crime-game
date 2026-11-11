class_name Station
extends StaticBody3D
## Base for production stations (grow pot, grow lamp, drying rack, later the
## packaging table, cooking station...). Stations live inside building prefabs,
## so they exist on every peer at the same path.
##
## HOST AUTHORITATIVE: `state` (a Dictionary) is owned by the host and stored in
## GameState.world["stations"][station_id] (so the save in step 9 keeps it).
## A player presses E -> request_action() -> the host runs do_action() with that
## player (checks + changes GameState inventory and the state) -> the new state
## goes to everyone. Time-based progress (growing, drying) runs in tick() on the
## host AND on clients (smooth visuals); the host re-sends the state every few
## seconds. Late joiners get it through the world snapshot (group "net_state").
## Time is in in-game hours (DayNight), so F7 fast-forward speeds it up too.

const SYNC_INTERVAL: float = 3.0

## Unique per map. Empty = the node path inside the world scene.
@export var station_id: String = ""

var state: Dictionary = {}
var _sync_timer: float = 0.0


func _ready() -> void:
	add_to_group(&"interactable")
	add_to_group(&"net_state")
	add_to_group(&"stations")
	collision_layer = 2  # props layer: not baked into the navmesh, hit by the interact ray
	collision_mask = 0
	if station_id == "":
		var world: Node = get_tree().current_scene
		station_id = str(world.get_path_to(self)) if world and world.is_ancestor_of(self) else str(name)
	state = default_state()
	if _is_host():
		var all: Dictionary = GameState.world.get_or_add("stations", {})
		if all.has(station_id):
			state.merge(all[station_id], true)
		all[station_id] = state  # same Dictionary: changes are in GameState automatically
	_build()
	state_changed()


func _is_host() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()


# --- To override -------------------------------------------------------------------

## Fresh state of a new station.
func default_state() -> Dictionary:
	return {}


## Builds the visuals once (called in _ready, before the first state_changed()).
func _build() -> void:
	pass


## Updates the visuals from `state` (every peer).
func state_changed() -> void:
	pass


## Advances time-based progress by `hours` in-game hours (every peer).
## Return true when something visible changed.
func tick(_hours: float) -> bool:
	return false


## Text after "[E] " for this player (uses the owner's own inventory list).
func prompt_for(_player: Player) -> String:
	return ""


## Host: the player pressed E. Change GameState/state and return a message for
## the player ("" = none). Call changed() if the state changed.
func do_action(_player: Player) -> String:
	return ""


# --- Helpers for subclasses ------------------------------------------------------------

## Owner side: how many of `id` the player carries (from the owner's inventory copy).
static func carried(player: Player, id: String) -> int:
	var total: int = 0
	for it: Dictionary in player.inventory:
		if str(it.get("id")) == id:
			total += int(it.get("count", 1))
	return total


static func item_name(id: String) -> String:
	var item: ItemData = ItemDB.get_item(StringName(id))
	return item.display_name if item else id


## Host: the state changed -> visuals + send it to everyone.
func changed() -> void:
	state_changed()
	_broadcast()


# --- Interaction + network -----------------------------------------------------------

func get_interaction_prompt() -> String:
	var me: Player = _local_player()
	return prompt_for(me) if me else ""


func interact() -> void:
	if _is_host():
		_server_action(multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1)
	else:
		_request_action.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _request_action() -> void:
	if multiplayer.is_server():
		_server_action(multiplayer.get_remote_sender_id())


func _server_action(peer: int) -> void:
	var player := get_tree().current_scene.get_node_or_null("Players/%d" % peer) as Player
	if player == null or player.dead:
		return
	if player.global_position.distance_to(global_position) > Player.INTERACT_DISTANCE + 1.5:
		return
	var msg: String = do_action(player)
	player.send_wallet()
	if msg != "":
		player.show_message(msg)


func _process(delta: float) -> void:
	var dn := get_tree().get_first_node_in_group(&"day_night") as DayNight
	var hours: float = delta * (dn.hours_per_second() if dn else 1.0 / 60.0)
	if tick(hours):
		state_changed()
	if _is_host() and multiplayer.has_multiplayer_peer():
		_sync_timer -= delta
		if _sync_timer <= 0.0:
			_sync_timer = SYNC_INTERVAL
			_broadcast()


func _broadcast() -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	for peer: int in Net.peers_in_world:
		_apply_state.rpc_id(peer, state)


@rpc("authority", "call_remote", "reliable")
func _apply_state(new_state: Dictionary) -> void:
	apply_net_state(new_state)


func get_net_state() -> Dictionary:
	return state


func apply_net_state(new_state: Dictionary) -> void:
	state = default_state()
	state.merge(new_state, true)
	state_changed()


func _local_player() -> Player:
	for p: Node in get_tree().get_nodes_in_group(&"players"):
		if (p as Player).is_local():
			return p as Player
	return null
