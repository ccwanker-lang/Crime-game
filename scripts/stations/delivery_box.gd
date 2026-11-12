class_name DeliveryBox
extends Station
## Where phone webshop (QuickShip) orders arrive, in the Starter Room. Orders
## arrive after DELIVERY_HOURS in-game hours; E takes everything that fits.
## Shared by the crew. Host: order() from Player.webshop_buy.

const DELIVERY_HOURS: float = 1.0
const CARDBOARD := preload("res://prefabs/interiors/cardboard_box.tscn")

var _boxes: Array[Node3D] = []


func _ready() -> void:
	add_to_group(&"delivery_box")
	super._ready()


func default_state() -> Dictionary:
	# items: [{id, count}] waiting in the box; pending: [{id, count, hours}] on the way.
	return {"items": [], "pending": []}


func _build() -> void:
	# A pallet-ish base with up to three parcels on it (shown when something's there).
	var b := MeshBuilder.new()
	b.box(&"planks", Vector3(0, 0.05, 0), Vector3(0.8, 0.1, 0.6))
	var mi := MeshInstance3D.new()
	mi.mesh = b.build()
	add_child(mi)
	for i: int in 3:
		var box: Node3D = CARDBOARD.instantiate()
		box.position = [Vector3(-0.18, 0.1, 0.02), Vector3(0.2, 0.1, -0.04), Vector3(0.0, 0.44, 0.0)][i]
		box.rotation.y = [0.1, -0.15, 0.4][i]
		(box as CollisionObject3D).collision_layer = 0
		add_child(box)
		_boxes.append(box)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.8, 0.5, 0.6)
	cs.shape = shape
	cs.position.y = 0.25
	add_child(cs)
	var label := Label3D.new()
	label.text = "DELIVERIES"
	label.font_size = 28
	label.pixel_size = 0.004
	label.position = Vector3(0, 0.95, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(1, 0.85, 0.55)
	add_child(label)


func _stack_count(key: String) -> int:
	var n: int = 0
	for it: Dictionary in state[key]:
		n += int(it["count"])
	return n


func state_changed() -> void:
	var stacks: int = (state["items"] as Array).size()
	for i: int in _boxes.size():
		_boxes[i].visible = i < stacks


func tick(hours: float) -> bool:
	var pending: Array = state["pending"]
	if pending.is_empty():
		return false
	var arrived: Array = []
	for p: Dictionary in pending:
		p["hours"] = float(p["hours"]) - hours
		if float(p["hours"]) <= 0.0:
			arrived.append(p)
	if arrived.is_empty() or not _is_host():
		return false
	for p: Dictionary in arrived:
		pending.erase(p)
		_add_item(str(p["id"]), int(p["count"]))
	changed()
	var world: Node = get_tree().current_scene
	if world and world.has_method("phone_all"):
		world.call("phone_all", "QuickShip", "Your order has been delivered to the box in your Starter Room.", "")
	return false


func _add_item(id: String, count: int) -> void:
	for it: Dictionary in state["items"]:
		if str(it["id"]) == id:
			it["count"] = int(it["count"]) + count
			return
	(state["items"] as Array).append({"id": id, "count": count})


## Host: a paid order is on its way.
func order(id: String, count: int) -> void:
	(state["pending"] as Array).append({"id": id, "count": count, "hours": DELIVERY_HOURS})
	changed()


func prompt_for(_player: Player) -> String:
	var waiting: int = _stack_count("items")
	if waiting > 0:
		var names: PackedStringArray = []
		for it: Dictionary in state["items"]:
			names.append("%d %s" % [int(it["count"]), item_name(str(it["id"]))])
		return "Take delivery: %s" % ", ".join(names)
	if not (state["pending"] as Array).is_empty():
		var soonest: float = INF
		for p: Dictionary in state["pending"]:
			soonest = minf(soonest, float(p["hours"]))
		return "Delivery box - order arrives in about %d min (game time)" % maxi(1, ceili(soonest * 60.0))
	return "Delivery box - order legal stuff on your phone (Tab)"


func do_action(player: Player) -> String:
	var items: Array = state["items"]
	if items.is_empty():
		return "Nothing delivered yet."
	var left: Array = GameState.give(player.player_name, 0, items.duplicate(true))
	state["items"] = left
	changed()
	return "Took the delivery." if left.is_empty() else "Your pockets are full - some is still in the box."
