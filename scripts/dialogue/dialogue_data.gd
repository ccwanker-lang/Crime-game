class_name DialogueData
extends Resource
## NOTES part 20: a talk with an NPC (a .tres, e.g. data/dialogue/marco.tres): pages (DialogueNode) with answers
## (DialogueChoice) that lead to other pages and can start missions. New one in Godot: right click a folder > New >
## Resource... > DialogueData; Nodes: Add Element > New DialogueNode; per page Choices > New DialogueChoice.

@export var speaker: String = ""
@export var nodes: Array[DialogueNode] = []


func get_node_by_id(id: StringName) -> DialogueNode:
	for n: DialogueNode in nodes:
		if n.id == id:
			return n
	return null


## The page a talk starts on: the first entry page whose condition holds (else the first page).
func entry() -> DialogueNode:
	for n: DialogueNode in nodes:
		if n.entry and DialogueNode.holds(n.show_if, n.show_mission):
			return n
	return nodes[0] if not nodes.is_empty() else null
