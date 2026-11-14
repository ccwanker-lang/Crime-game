class_name IntroNPC
extends Shopkeeper
## Point 49: a person in the prison you talk to with E (no shop): "mentor" (Marco, the fellow prisoner),
## "desk" (the release desk guard) or "guard" (just a line). Intro (host) decides what happens.

@export var role: String = "guard"


func get_interaction_prompt() -> String:
	if Intro.current:
		return Intro.current.npc_prompt(role, npc_name)
	return "Talk to %s" % npc_name


func interact() -> void:
	if Intro.current:
		Intro.current.request_talk(role)
