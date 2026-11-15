class_name DialogueNode
extends Resource
## NOTES part 20: one page of a talk: who speaks, the text, the answers. No answers = a "Continue" button to `next`
## (or "Bye" when `next` is empty).

enum Show {
	ALWAYS,
	MISSION_AVAILABLE,   ## `show_mission` can be started now
	MISSION_DONE,        ## `show_mission` was finished
	MISSION_NOT_DONE,    ## `show_mission` not finished yet
	MISSION_RUNNING,     ## `show_mission` is the running mission (empty = any)
	NO_MISSION_RUNNING,
}

@export var id: StringName = &""
## Empty = the dialogue's speaker.
@export var speaker: String = ""
@export_multiline var text: String = ""
@export var choices: Array[DialogueChoice] = []
@export var next: StringName = &""
## Entry pages: a talk starts on the FIRST entry page whose condition holds.
@export var entry: bool = false
@export var show_if: Show = Show.ALWAYS
@export var show_mission: StringName = &""


## Every peer (from Missions.view): does `cond` hold?
static func holds(cond: Show, mission: StringName) -> bool:
	var v: Dictionary = Missions.view
	var act: String = str(v.get("active", ""))
	match cond:
		Show.MISSION_AVAILABLE:
			return str(mission) in (v.get("available", []) as Array)
		Show.MISSION_DONE:
			return str(mission) in (v.get("done", []) as Array)
		Show.MISSION_NOT_DONE:
			return not str(mission) in (v.get("done", []) as Array)
		Show.MISSION_RUNNING:
			return act != "" and (mission == &"" or act == str(mission))
		Show.NO_MISSION_RUNNING:
			return act == ""
	return true


func visible_choices() -> Array[DialogueChoice]:
	var out: Array[DialogueChoice] = []
	for c: DialogueChoice in choices:
		if holds(c.show_if, c.show_mission):
			out.append(c)
	return out
