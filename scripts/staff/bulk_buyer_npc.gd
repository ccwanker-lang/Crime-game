class_name BulkBuyerNPC
extends Node3D
## The bulk buyer waiting for the crew (BulkDeals.offer), a local visual on every peer like StaffNPC:
## a stationary Pedestrian model + a layer-2 body for the interact ray. E -> BulkDeals.request_sell().

const PEDESTRIAN: PackedScene = preload("res://prefabs/npc/pedestrian.tscn")

var offer_id: String = ""
var offer: Dictionary = {}
var _label: Label3D


func show_offer(o: Dictionary) -> void:
	offer = o
	name = "BulkBuyer"
	position = o["pos"]
	rotation.y = float(o.get("yaw", 0.0))
	var npc := PEDESTRIAN.instantiate() as Pedestrian
	npc.variant = 2 % Pedestrian.VARIANTS.size()
	npc.color_seed = 77
	npc.stationary = true
	npc.ambient = false
	add_child(npc)
	npc.anim_state = Pedestrian.Anim.IDLE
	var body := StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	body.add_child(cs)
	add_child(body)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.pixel_size = 0.0035
	_label.font_size = 40
	_label.outline_size = 10
	_label.position.y = 2.1
	_label.modulate = Color(1.0, 0.85, 0.4)
	_label.text = "%s (bulk buyer)\n%d bags of %s - €%d" % [o["name"], int(o["bags"]), Products.short_name(str(o["product"])), int(o["price"])]
	add_child(_label)
	add_to_group(&"interactable")


func get_interaction_prompt() -> String:
	return "Sell %d bags of %s to %s (€%d)" % [int(offer["bags"]), Products.short_name(str(offer["product"])), offer["name"], int(offer["price"])]


func interact() -> void:
	BulkDeals.request_sell()
