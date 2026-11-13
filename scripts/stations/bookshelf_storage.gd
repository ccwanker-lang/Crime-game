class_name BookshelfStorage
extends StorageLocker
## Point 38: a bookshelf in your own property is storage too (same slots and window as the
## locker). The item "bookshelf" places this station; a bookshelf adopted with a bought
## house becomes one as well (Property.host_adopt_furniture -> placed record "bookshelf").

const SHELF := preload("res://prefabs/interiors/bookshelf.tscn")
const SIZE: Vector3 = Vector3(1.37, 2.06, 0.58)


func _build() -> void:
	var shelf: Node3D = SHELF.instantiate() as Node3D
	shelf.name = "Shelf"
	var col: Node = shelf.get_node_or_null("Collision")
	if col:
		shelf.remove_child(col)
		col.free()
	(shelf as CollisionObject3D).collision_layer = 0
	(shelf as CollisionObject3D).collision_mask = 0
	add_child(shelf)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = SIZE
	cs.shape = shape
	cs.position.y = SIZE.y * 0.5
	add_child(cs)


func storage_name() -> String:
	return "Bookshelf"


func prompt_for(_player: Player) -> String:
	return "Open bookshelf (%d/%d)" % [used_slots(), SLOTS]
