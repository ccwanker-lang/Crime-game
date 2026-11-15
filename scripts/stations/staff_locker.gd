class_name StaffLocker
extends StorageLocker
## NOTES part 12 (session B): a storage locker for your workers with a wage box. Workers assigned to it (Staff
## "locker") take their supplies from it, put their products back in it and take their daily wage from
## `state["wages"]` (cash you put in). Empty wage box -> they stop working and text you; topped up -> back to work.
## E opens the staff locker window (CrewWindow mode "locker": wages, its workers, "Open storage").

const STRIPE := Color(0.95, 0.72, 0.15)


func default_state() -> Dictionary:
	return {"items": [], "wages": 0}


func _build() -> void:
	super._build()
	var b := MeshBuilder.new()
	b.color = STRIPE
	b.box(&"item_matte", Vector3(0, HEIGHT - 0.08, DEPTH * 0.5 + 0.02), Vector3(WIDTH - 0.06, 0.07, 0.01))
	b.box(&"item_matte", Vector3(0, 0.12, DEPTH * 0.5 + 0.02), Vector3(WIDTH - 0.06, 0.07, 0.01))
	# The wage box on top: a small grey cash box with a slot.
	b.color = Color(0.32, 0.34, 0.36)
	b.box(&"item_matte", Vector3(0, HEIGHT + 0.07, 0.02), Vector3(0.34, 0.14, 0.24), 0.01)
	b.color = Color(0.05, 0.05, 0.05)
	b.box(&"item_matte", Vector3(0, HEIGHT + 0.142, 0.02), Vector3(0.16, 0.006, 0.02))
	var mi := MeshInstance3D.new()
	mi.mesh = b.build()
	add_child(mi)
	var tag := Label3D.new()
	tag.text = "STAFF"
	tag.font_size = 48
	tag.pixel_size = 0.004
	tag.modulate = Color(0.1, 0.1, 0.1)
	tag.outline_size = 0
	tag.position = Vector3(0, HEIGHT - 0.25, DEPTH * 0.5 + 0.03)
	add_child(tag)


func storage_name() -> String:
	return "Staff Locker"


func wages() -> int:
	return int(state.get("wages", 0))


func prompt_for(_player: Player) -> String:
	return "Staff locker (%d/%d, wages €%d)" % [used_slots(), SLOTS, wages()]


func pick_up_blocker() -> String:
	if wages() > 0:
		return "Take the wage money out first."
	return super.pick_up_blocker()


## E: the staff locker window (wages + its workers); "Open storage" there opens the normal locker window.
func interact() -> void:
	var me: Player = _local_player()
	if me:
		CrewWindow.open_for(me, "locker", station_id)
