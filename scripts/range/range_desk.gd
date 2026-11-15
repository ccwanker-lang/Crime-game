class_name RangeDesk
extends Node3D
## The gun club's counter with Walt, the range master (ShootingRange, local on every peer): a stationary
## Pedestrian model + a layer-2 body for the interact ray. E opens the RangeWindow (drills, try a gun, your skill).

const PEDESTRIAN: PackedScene = preload("res://prefabs/npc/pedestrian.tscn")
const MASTER: String = "Walt"

var _npc: Pedestrian


func _ready() -> void:
	_npc = PEDESTRIAN.instantiate() as Pedestrian
	_npc.variant = 2 % Pedestrian.VARIANTS.size()
	_npc.color_seed = 7311
	_npc.stationary = true
	_npc.ambient = false
	_npc.rotation.y = PI  # (the model faces +Z: towards the counter)
	add_child(_npc)
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
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.0035
	label.font_size = 40
	label.outline_size = 10
	label.position.y = 2.1
	label.modulate = Color(0.96, 0.77, 0.27)
	label.text = "%s (range master)" % MASTER
	add_child(label)
	add_to_group(&"interactable")
	add_to_group(&"range_desk")


func get_interaction_prompt() -> String:
	return "Talk to %s (shooting range)" % MASTER


func interact() -> void:
	for p: Node in get_tree().get_nodes_in_group(&"players"):
		if (p as Player).is_local():
			RangeWindow.open_for(p as Player)
			return
