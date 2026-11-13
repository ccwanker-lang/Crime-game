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
	if item_id == "bed":  # point 37
		var dn := get_tree().get_first_node_in_group(&"day_night") as DayNight
		if dn and Sleep.is_sleep_time(dn.hours):
			return "Sleep until morning"
		return "Bed (you can sleep from %02d:00)" % int(Sleep.SLEEP_FROM)
	return item.display_name if item else item_id


## E: a bed puts you to sleep (point 37); other furniture does nothing (build mode moves it).
func interact() -> void:
	if item_id != "bed":
		return
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p := n as Player
		if p and p.is_local():
			p.request_sleep(true)
