extends Node
## Host-authoritative game state.
## - world: plants, stations, property ownership (filled in later steps)
## - player_data: persistent data per player NAME (cash + inventory), so a
##   player who rejoins gets their own stuff back.
## Only the host modifies this. Clients receive what they need via RPC/sync.

signal world_changed

const STARTING_CASH: int = 500
## Development: buying never costs money (until earning money works, step 7).
## The self-test turns it off to check the real money rules.
var infinite_cash: bool = true
## Carried item stacks per player (shown as the hotbar).
const INVENTORY_SLOTS: int = 8

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
		## station_id -> state Dictionary (pots, lamps, racks; see Station)
		"stations": {},
		## uid -> {item, pos, yaw}: stations + furniture placed in properties (World.host_place)
		"placed": {},
	}
	world_changed.emit()


## Host only: returns the persistent record for a player, creating it if new.
func get_or_create_player_data(player_name: String) -> Dictionary:
	if not player_data.has(player_name):
		player_data[player_name] = {"cash": STARTING_CASH, "inventory": []}
		give_starter_kit(player_name)
	return player_data[player_name]


## Host only: a service pistol (unless carried) + its starter rounds (new player, respawn).
func give_starter_kit(player_name: String) -> void:
	var pistol := ItemDB.get_item(&"pistol") as WeaponData
	if pistol == null:
		return
	var kit: Array = [{"id": "pistol", "count": 1}] if count_item(player_name, "pistol") == 0 else []
	if pistol.starting_reserve > 0:
		kit.append({"id": String(pistol.ammo_id), "count": pistol.starting_reserve})
	give(player_name, 0, kit)


## Host only: empties a player's cash and carried items and returns them
## ({ "cash": int, "items": Array }), e.g. for the loot bag on death.
func take_all(player_name: String) -> Dictionary:
	var data: Dictionary = get_or_create_player_data(player_name)
	var taken: Dictionary = {"cash": int(data["cash"]), "items": (data["inventory"] as Array).duplicate(true)}
	data["cash"] = 0
	data["inventory"] = []
	return taken


## Host only: adds cash and items ([{ "id", "count" }]) to a player. Items fill
## existing stacks up to the item's max_stack, then free slots (INVENTORY_SLOTS).
## Returns what did not fit (same format), empty if everything fit.
func give(player_name: String, cash: int, items: Array) -> Array:
	var data: Dictionary = get_or_create_player_data(player_name)
	data["cash"] = int(data["cash"]) + cash
	var leftover: Array = []
	for it: Dictionary in items:
		var id: String = str(it.get("id", ""))
		var left: int = _add_to_inventory(data["inventory"], id, int(it.get("count", 1)))
		if left > 0:
			leftover.append({"id": id, "count": left})
	return leftover


## Host only: how many of `id` still fit in the player's inventory.
func space_for(player_name: String, id: String) -> int:
	var inv: Array = get_or_create_player_data(player_name)["inventory"]
	var stack: int = max_stack_of(id)
	var space: int = (INVENTORY_SLOTS - inv.size()) * stack
	for own: Dictionary in inv:
		if own.get("id") == id:
			space += maxi(0, stack - int(own.get("count", 1)))
	return space


## Host only: total count of `id` the player carries.
func count_item(player_name: String, id: String) -> int:
	var total: int = 0
	for own: Dictionary in get_or_create_player_data(player_name)["inventory"]:
		if own.get("id") == id:
			total += int(own.get("count", 1))
	return total


## Host only: removes `count` of `id` (from the last stacks first). Returns false
## (and changes nothing) if the player does not carry that many.
func remove_item(player_name: String, id: String, count: int) -> bool:
	if count <= 0 or count_item(player_name, id) < count:
		return false
	var inv: Array = get_or_create_player_data(player_name)["inventory"]
	for i: int in range(inv.size() - 1, -1, -1):
		var own: Dictionary = inv[i]
		if own.get("id") != id:
			continue
		var take: int = mini(count, int(own.get("count", 1)))
		own["count"] = int(own.get("count", 1)) - take
		count -= take
		if int(own["count"]) <= 0:
			inv.remove_at(i)
		if count == 0:
			break
	return true


## Host only: changes a player's cash (negative = pay). Returns false if they can't pay.
func add_cash(player_name: String, amount: int) -> bool:
	if infinite_cash and amount < 0:
		return true
	var data: Dictionary = get_or_create_player_data(player_name)
	if int(data["cash"]) + amount < 0:
		return false
	data["cash"] = int(data["cash"]) + amount
	return true


static func max_stack_of(id: String) -> int:
	var item: ItemData = ItemDB.get_item(StringName(id))
	return maxi(1, item.max_stack) if item else 1


## Adds `count` of `id` to an inventory array; returns how many did not fit.
static func _add_to_inventory(inv: Array, id: String, count: int) -> int:
	return add_to_stacks(inv, id, count, INVENTORY_SLOTS)


## Adds `count` of `id` to `inv` (stacks up to max_stack, at most `slots` stacks); returns what did not fit.
static func add_to_stacks(inv: Array, id: String, count: int, slots: int) -> int:
	var stack: int = max_stack_of(id)
	for own: Dictionary in inv:
		if count <= 0:
			break
		if own.get("id") == id:
			var add: int = mini(count, stack - int(own.get("count", 1)))
			if add > 0:
				own["count"] = int(own.get("count", 1)) + add
				count -= add
	while count > 0 and inv.size() < slots:
		var add: int = mini(count, stack)
		inv.append({"id": id, "count": add})
		count -= add
	return count


func to_save_dict() -> Dictionary:
	return {"world": world, "players": player_data}


func from_save_dict(data: Dictionary) -> void:
	world = data.get("world", {})
	player_data = data.get("players", {})
	world_changed.emit()
