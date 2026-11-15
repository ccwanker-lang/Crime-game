class_name DialogueChoice
extends Resource
## NOTES part 20: one answer button in a DialogueNode. `next` = the node it leads to (empty = the talk ends).

enum Action {
	NONE,           ## only go to `next`
	START_MISSION,  ## start `mission` for the crew (Missions.request_start)
	FINISH_STEP,    ## the current mission step with this NPC is done (talk to / deliver)
}

@export var text: String = ""
@export var next: StringName = &""
@export var action: Action = Action.NONE
@export var mission: StringName = &""
## Only shown when this holds (see DialogueNode.Show).
@export var show_if: DialogueNode.Show = DialogueNode.Show.ALWAYS
@export var show_mission: StringName = &""
