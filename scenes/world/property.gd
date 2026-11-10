class_name Property
extends Node3D
## A property (building) that can be owned. Ownership lives in GameState.world
## on the host. In milestone 1 the host owns the starter room.

@export var property_id: StringName = &"starter_room"
@export var display_name: String = "Starter Room"

@onready var _label: Label3D = $Label3D


func _ready() -> void:
	Net.players_changed.connect(_update_label)
	_update_label()


## "host" means the property belongs to the host's world (whoever is hosting).
func get_owner_id() -> String:
	var properties: Dictionary = GameState.world.get("properties", {})
	var data: Dictionary = properties.get(property_id, {"owner": "host"})
	return data.get("owner", "host")


func _update_label() -> void:
	var owner_name: String = Net.get_player_name(1) if get_owner_id() == "host" else get_owner_id()
	_label.text = "%s\nOwner: %s" % [display_name.to_upper(), owner_name]
