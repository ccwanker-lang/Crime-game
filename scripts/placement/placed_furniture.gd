class_name PlacedFurniture
extends Node3D
## A piece of furniture placed in a property (point 6/17), spawned by World/PlacedSpawner.
## The furniture prefab is its child. Hold E picks it up (Player handles the hold).

var placed_uid: String = ""
var item_id: String = ""


func _ready() -> void:
	add_to_group(&"interactable")
	add_to_group(&"placed")
	# Props layer like the stations: not baked into the navmesh, hit by the interact ray.
	for n: Node in find_children("*", "CollisionObject3D", true, false) + [get_child(0)]:
		var body := n as CollisionObject3D
		if body:
			body.collision_layer = 2


func get_interaction_prompt() -> String:
	var item: ItemData = ItemDB.get_item(StringName(item_id))
	return "Hold to pick up %s" % (item.display_name if item else item_id)


func interact() -> void:
	pass
