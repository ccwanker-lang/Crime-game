class_name TrashBin
extends Station
## Point 39: a wheelie bin. E throws every piece of trash you carry into it (empty delivery
## boxes, plant waste). It may stand OUTSIDE, on the pavement in front of a property the
## crew owns (Placement.OUTDOOR); the garbage truck (World/Garbage, every morning at
## Garbage.PICKUP_HOUR) stops next to full outside bins and empties them.

const CAPACITY: int = 40
## Items that count as trash (category "trash" in their ItemData).
const TRASH: Array[String] = ["empty_box", "plant_waste"]
const W: float = 0.6
const H: float = 1.05
const D: float = 0.7

var _lid: Node3D
var _bags: Node3D


func _ready() -> void:
	super()
	if not ghost:
		add_to_group(&"trash_bins")


func default_state() -> Dictionary:
	return {"trash": 0}


func _build() -> void:
	var b := MeshBuilder.new()
	b.color = Color(0.16, 0.3, 0.18)
	# Tapered body (a bit narrower at the bottom), rim, two wheels at the back.
	b.box(&"item_matte", Vector3(0, H * 0.5, 0), Vector3(W, H - 0.06, D), 0.03)
	b.color = Color(0.12, 0.24, 0.14)
	b.box(&"item_matte", Vector3(0, H - 0.05, 0), Vector3(W + 0.04, 0.05, D + 0.04), 0.01)
	b.box(&"item_matte", Vector3(0, H - 0.02, -D * 0.5 - 0.05), Vector3(W * 0.8, 0.04, 0.05), 0.01)  # handle
	b.color = Color(0.08, 0.08, 0.08)
	for s: float in [-1.0, 1.0]:
		b.cylinder(&"item_matte", Vector3(s * (W * 0.5 - 0.04), 0.1, -D * 0.5 + 0.05),
				Vector3(s * (W * 0.5 + 0.02), 0.1, -D * 0.5 + 0.05), 0.1, 0.1, 10)
	var mi := MeshInstance3D.new()
	mi.mesh = b.build()
	add_child(mi)
	# Lid: hinged at the back, opens when the bin is (almost) full.
	_lid = Node3D.new()
	_lid.position = Vector3(0, H, -D * 0.5)
	add_child(_lid)
	var lb := MeshBuilder.new()
	lb.color = Color(0.14, 0.27, 0.16)
	lb.box(&"item_matte", Vector3(0, 0.02, D * 0.5 + 0.02), Vector3(W + 0.06, 0.04, D + 0.06), 0.01)
	var lid_mesh := MeshInstance3D.new()
	lid_mesh.mesh = lb.build()
	_lid.add_child(lid_mesh)
	# Black bags sticking out of a full bin.
	_bags = Node3D.new()
	add_child(_bags)
	var gb := MeshBuilder.new()
	var black: Array[Color] = [Color(0.06, 0.06, 0.07), Color(0.1, 0.1, 0.11)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 39
	gb.blob(&"item_glossy", Vector3(-0.1, H + 0.02, 0.05), 0.2, Vector3(1, 0.8, 1), rng, black)
	gb.blob(&"item_glossy", Vector3(0.12, H + 0.04, -0.06), 0.18, Vector3(1, 0.9, 1), rng, black)
	var bag_mesh := MeshInstance3D.new()
	bag_mesh.mesh = gb.build()
	_bags.add_child(bag_mesh)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(W, H, D)
	cs.shape = shape
	cs.position.y = H * 0.5
	add_child(cs)


func state_changed() -> void:
	if _lid == null:
		return
	var full: float = float(state.get("trash", 0)) / CAPACITY
	_bags.visible = full >= 0.75
	_lid.rotation.x = -1.1 if full >= 0.75 else 0.0


func trash() -> int:
	return int(state.get("trash", 0))


static func carried_trash(player: Player) -> int:
	var n: int = 0
	for id: String in TRASH:
		n += carried(player, id)
	return n


func prompt_for(player: Player) -> String:
	var have: int = carried_trash(player) if player else 0
	if have > 0 and trash() < CAPACITY:
		return "Throw away %d trash (bin %d/%d)" % [have, trash(), CAPACITY]
	if trash() >= CAPACITY:
		return "Trash bin is full - the garbage truck comes at %02d:00 (bin must stand outside)" % int(Garbage.PICKUP_HOUR)
	return "Trash bin (%d/%d) - put it outside, the garbage truck empties it at %02d:00" % [
			trash(), CAPACITY, int(Garbage.PICKUP_HOUR)]


func do_action(player: Player) -> String:
	var who: String = player.player_name
	var thrown: int = 0
	for id: String in TRASH:
		var n: int = mini(GameState.count_item(who, id), CAPACITY - trash() - thrown)
		if n > 0 and GameState.remove_item(who, id, n):
			thrown += n
	if thrown == 0:
		return "The bin is full." if trash() >= CAPACITY else "You have no trash on you."
	state["trash"] = trash() + thrown
	changed()
	work = "throw"
	return "Threw away %d trash." % thrown


## Host: the garbage truck empties the bin.
func host_empty() -> int:
	var n: int = trash()
	if n > 0:
		state["trash"] = 0
		changed()
	return n
