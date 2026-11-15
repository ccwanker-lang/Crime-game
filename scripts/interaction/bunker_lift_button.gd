class_name BunkerLiftButton
extends StaticBody3D
## A call panel for the bunker's vehicle lift (one at each level): E sends / calls the lift.

var lift: BunkerLift
var upper: bool = true  # the panel at the hall (true) or in the garage
var here_text: String = ""  # optional prompts (point 76: the apartment lift) when the platform is here / away
var call_text: String = ""


func _ready() -> void:
	add_to_group(&"interactable")
	collision_layer = 2
	collision_mask = 0
	var b := MeshBuilder.new()
	b.color = Color(0.25, 0.27, 0.28)
	b.box(&"item_metal", Vector3(0, 1.3, 0), Vector3(0.4, 0.6, 0.12))
	b.color = Color(0.2, 0.75, 0.25)
	b.box(&"item_glossy", Vector3(0, 1.42, -0.07), Vector3(0.14, 0.14, 0.04))
	b.color = Color(0.85, 0.15, 0.1)
	b.box(&"item_glossy", Vector3(0, 1.2, -0.07), Vector3(0.14, 0.14, 0.04))
	var mi := MeshInstance3D.new()
	mi.mesh = b.build()
	add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.45, 0.65, 0.2)
	cs.shape = shape
	cs.position = Vector3(0, 1.3, 0)
	add_child(cs)


func get_interaction_prompt() -> String:
	if lift == null:
		return ""
	var here: bool = lift.is_open != upper  # the platform is at this level (or on its way here)
	if here:
		return here_text if here_text != "" else ("Send the lift down" if upper else "Send the lift up")
	return call_text if call_text != "" else "Call the lift"


func interact() -> void:
	if lift:
		lift.interact()
