class_name BunkerProperty
extends Property
## Map zone 8: the bunker as a property. It has no Building parent: `rooms` (AABBs local to the bunker root, the
## parent node) are its interior, so Placement works anywhere inside the complex. Its furniture = the
## prefabs/interiors instances under the root's "Furniture" node (adopted like a building's when the crew owns it).
## Buying, price, rank gate, the lab logic and locking the door = session B.

var rooms: Array[AABB] = []


func _root() -> Node3D:
	return get_parent() as Node3D


func contains(pos: Vector3) -> bool:
	var root: Node3D = _root()
	if root == null:
		return false
	var p: Vector3 = root.to_local(pos)
	for r: AABB in rooms:
		if r.has_point(p):
			return true
	return false


func static_furniture() -> Array[Node3D]:
	var out: Array[Node3D] = []
	var root: Node3D = _root()
	var holder: Node = root.get_node_or_null("Furniture") if root else null
	if holder == null:
		return out
	for n: Node in holder.get_children():
		var n3 := n as Node3D
		if n3 == null or n3.is_queued_for_deletion() or not n3.scene_file_path.begins_with(FURNITURE_DIR):
			continue
		var item: ItemData = ItemDB.get_item(StringName(n3.scene_file_path.get_file().get_basename()))
		if item and item.place_scene:
			out.append(n3)
	return out
