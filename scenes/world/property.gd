class_name Property
extends Node3D
## A property (building) that can be owned. Ownership lives in GameState.world
## on the host ("host" = the crew of whoever hosts). The parent is the Building:
## its interior is where the crew may place stations and furniture (point 6).
##
## Point 17 (C): once owned, the building's furniture is "adopted": every piece
## becomes a placed object (GameState.world["placed"]) that can be picked up,
## moved, stored or sold. The static copies are removed on every peer
## (host: host_adopt_furniture, clients: through the late-join snapshot).

@export var property_id: StringName = &"starter_room"
@export var display_name: String = "Starter Room"
## Point 8: sold by the real estate agent (EstateAgent) for `price`; "" description = not for sale.
@export var for_sale: bool = false
@export var price: int = 0
@export var description: String = ""

const FURNITURE_DIR: String = "res://prefabs/interiors/"

@onready var _label: Label3D = $Label3D


func _ready() -> void:
	add_to_group(&"properties")
	add_to_group(&"net_state")
	Net.players_changed.connect(_update_label)
	_update_label()


func _data() -> Dictionary:
	var properties: Dictionary = GameState.world.get("properties", {})
	return properties.get(property_id, {})


## "host" means the property belongs to the host's world (whoever is hosting).
## "" = nobody owns it (yet).
func get_owner_id() -> String:
	if not GameState.world.has("properties"):
		# Clients don't have the world data: the snapshot tells them (the starter room is always ours).
		return _client_owner if _client_owner != "" or property_id != &"starter_room" else "host"
	return str(_data().get("owner", ""))


var _client_owner: String = ""


## Co-op: everything owned is shared by the crew (all players of this session).
func is_crew_owned() -> bool:
	return get_owner_id() != ""


func building() -> Building:
	return get_parent() as Building


## Is `pos` (global) inside the building's interior (between the walls, any floor)?
func contains(pos: Vector3) -> bool:
	var b: Building = building()
	if b == null:
		return false
	var p: Vector3 = b.to_local(pos)
	var hw: float = b.width * 0.5 - Building.WALL_T
	return absf(p.x) < hw and p.z < -Building.WALL_T and p.z > -b.depth + Building.WALL_T \
			and p.y > -0.3 and p.y < b.get_height()


func _update_label() -> void:
	var owner_id: String = get_owner_id()
	if owner_id == "" and for_sale:
		_label.text = "FOR SALE\n%s - €%s" % [display_name, Property.money(price)]
		_label.modulate = Color(1.0, 0.75, 0.35)
		return
	var owner_name: String = Net.get_player_name(1) if owner_id == "host" else (owner_id if owner_id != "" else "-")
	_label.text = "%s\nOwner: %s" % [display_name.to_upper(), owner_name]
	_label.modulate = Color(1, 0.95, 0.8)


## 8000 -> "8,000"
static func money(amount: int) -> String:
	var s: String = str(absi(amount))
	var out: String = ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if amount < 0 else "") + s + out


# --- Buying (point 8, host) ------------------------------------------------------------

## Host: the crew buys this property (cash already paid). Furniture becomes movable,
## every peer gets the new owner.
func host_set_owned(buyer_name: String) -> void:
	var data: Dictionary = GameState.world.get_or_add("properties", {}).get_or_add(property_id, {})
	data["owner"] = "host"
	data["buyer"] = buyer_name
	host_adopt_furniture(get_tree().current_scene)
	_update_label()
	for peer: int in Net.peers_in_world:
		_owned_changed.rpc_id(peer, get_net_state())


@rpc("authority", "call_remote", "reliable")
func _owned_changed(s: Dictionary) -> void:
	apply_net_state(s)


# --- Furniture adoption (host) --------------------------------------------------------

## The static furniture of the building that can become a placed object.
func static_furniture() -> Array[Node3D]:
	var out: Array[Node3D] = []
	var b: Building = building()
	if b == null:
		return out
	for n: Node in b.get_children():
		var n3 := n as Node3D
		if n3 == null or n3.is_queued_for_deletion() or not n3.scene_file_path.begins_with(FURNITURE_DIR):
			continue
		var item: ItemData = ItemDB.get_item(StringName(n3.scene_file_path.get_file().get_basename()))
		if item and item.place_scene:
			out.append(n3)
	return out


## Host: turn the building's furniture into placed objects (once per property, saved).
## `world` spawns them (World.host_place). Already adopted: only remove the static copies.
func host_adopt_furniture(world: Node) -> int:
	var data: Dictionary = GameState.world.get_or_add("properties", {}).get_or_add(property_id, {})
	var count: int = 0
	if not data.get("adopted", false) and is_crew_owned():
		for n: Node3D in static_furniture():
			var id: String = n.scene_file_path.get_file().get_basename()
			world.call("host_place", id, n.global_position, n.global_rotation.y)
			count += 1
		data["adopted"] = true
	if data.get("adopted", false):
		_remove_static_furniture()
	return count


func _remove_static_furniture() -> void:
	for n: Node3D in static_furniture():
		n.get_parent().remove_child(n)
		n.queue_free()


func get_net_state() -> Dictionary:
	return {"owner": get_owner_id(), "adopted": bool(_data().get("adopted", false))}


func apply_net_state(s: Dictionary) -> void:
	_client_owner = str(s.get("owner", ""))
	if s.get("adopted", false):
		_remove_static_furniture()
	_update_label()
