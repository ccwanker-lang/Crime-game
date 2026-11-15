class_name BunkerKeypad
extends StaticBody3D
## NOTES part 18: the keypad by the bunker portal / by the lift inside (layer 2, interactable). E = BunkerLab.request_use.

var lab: BunkerLab
var prompt: String = "Use"
var going_in: bool = true


func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.5, 0.6, 0.3)
	cs.shape = shape
	add_child(cs)
	var b := MeshBuilder.new()
	b.color = Color(0.2, 0.22, 0.22)
	b.box(&"metal_dark", Vector3(0, 0, 0), Vector3(0.32, 0.42, 0.08), 0.01)
	b.color = Color(0.1, 0.8, 0.3) if going_in else Color(0.9, 0.7, 0.1)
	b.box(&"item_matte", Vector3(0, 0.12, -0.045), Vector3(0.2, 0.08, 0.01))
	b.color = Color(0.7, 0.7, 0.7)
	for i: int in 9:
		b.box(&"item_matte", Vector3(-0.07 + (i % 3) * 0.07, -0.02 - (i / 3) * 0.06, -0.045), Vector3(0.045, 0.04, 0.012))
	var mi := MeshInstance3D.new()
	mi.mesh = b.build()
	add_child(mi)
	add_to_group(&"interactable")


func get_interaction_prompt() -> String:
	if going_in and lab and lab.property and not lab.property.is_crew_owned():
		return "Keypad (locked - for sale at the estate agent)"
	return prompt


func interact() -> void:
	if lab:
		lab.request_use(going_in)
