class_name MissionTalkBox
extends StaticBody3D
## NOTES part 19: put by `Missions` (every peer, local) on a mission NPC "MissionNPC_<id>": a box on layer 2 round
## them (interactable: E = Missions.request_talk) + a name tag. The NPC's own body (layer 3) is off on clients.

var npc_id: StringName = &""
var npc_name: String = ""
var _tag: Label3D


func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.45
	shape.height = 1.9
	cs.shape = shape
	cs.position = Vector3(0, 0.95, 0)
	add_child(cs)
	add_to_group(&"interactable")
	_tag = Label3D.new()
	_tag.text = npc_name
	_tag.font_size = 40
	_tag.pixel_size = 0.005
	_tag.outline_size = 10
	_tag.modulate = Color(1.0, 0.85, 0.35)
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.position = Vector3(0, 2.25, 0)
	add_child(_tag)


func _process(_delta: float) -> void:
	var talk: bool = false
	var v: Dictionary = Missions.view
	if str(v.get("active", "")) != "":
		var m: MissionData = Missions.get_mission(StringName(str(v["active"])))
		var step: int = int(v.get("step", 0))
		if m and step < m.objectives.size() and m.objectives[step].npc_id == npc_id:
			talk = true
	_tag.text = ("!  %s" % npc_name) if talk else npc_name


func get_interaction_prompt() -> String:
	return "Talk to %s" % npc_name


func interact() -> void:
	Missions.request_talk(npc_id)
