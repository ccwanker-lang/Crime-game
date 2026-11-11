extends Node
## Host-authoritative game state.
## - world: plants, stations, property ownership (filled in later steps)
## - player_data: persistent data per player NAME (cash + inventory), so a
##   player who rejoins gets their own stuff back.
## Only the host modifies this. Clients receive what they need via RPC/sync.

signal world_changed

const STARTING_CASH: int = 500

var world: Dictionary = {}
## player name -> { "cash": int, "inventory": Array of { "id": String, "count": int } }
var player_data: Dictionary = {}


func reset() -> void:
	world = {}
	player_data = {}
	world_changed.emit()


## Host only: fresh world for a new game. "host" = owned by whoever hosts.
func init_new_world() -> void:
	world = {
		"properties": {
			"starter_room": {"owner": "host"},
		},
	}
	world_changed.emit()


## Host only: returns the persistent record for a player, creating it if new.
func get_or_create_player_data(player_name: String) -> Dictionary:
	if not player_data.has(player_name):
		player_data[player_name] = {"cash": STARTING_CASH, "inventory": []}
	return player_data[player_name]


## Host only: empties a player's cash and carried items and returns them
## ({ "cash": int, "items": Array }), e.g. for the loot bag on death.
func take_all(player_name: String) -> Dictionary:
	var data: Dictionary = get_or_create_player_data(player_name)
	var taken: Dictionary = {"cash": int(data["cash"]), "items": (data["inventory"] as Array).duplicate(true)}
	data["cash"] = 0
	data["inventory"] = []
	return taken


## Host only: adds cash and items ([{ "id", "count" }], stacks merged) to a player.
func give(player_name: String, cash: int, items: Array) -> void:
	var data: Dictionary = get_or_create_player_data(player_name)
	data["cash"] = int(data["cash"]) + cash
	var inv: Array = data["inventory"]
	for it: Dictionary in items:
		var merged: bool = false
		for own: Dictionary in inv:
			if own.get("id") == it.get("id"):
				own["count"] = int(own.get("count", 1)) + int(it.get("count", 1))
				merged = true
				break
		if not merged:
			inv.append(it.duplicate())


func to_save_dict() -> Dictionary:
	return {"world": world, "players": player_data}


func from_save_dict(data: Dictionary) -> void:
	world = data.get("world", {})
	player_data = data.get("players", {})
	world_changed.emit()
