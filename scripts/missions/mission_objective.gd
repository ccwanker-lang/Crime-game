class_name MissionObjective
extends Resource
## One step of a mission (NOTES part 19). A MissionData holds a list of these; the host (`Missions`) checks the current
## one. Write them in the Inspector (or in the .tres in data/missions/).
##
## Where: `marker` (a node name, found with world.get_marker; empty = use `position`) + `offset` (in the marker's own
## frame, so "2 m in front of it" stays right if the marker turns). `radius` = how close counts as "there".
## Text placeholders: {count} {need} {time} {npc} {item}.

enum Kind {
	GO_TO,     ## someone of the crew reaches the spot (within `radius`)
	TALK_TO,   ## E on the mission NPC `npc_id` (spawned at the spot while this step runs)
	DELIVER,   ## E on the NPC with `count` x `item_id` in your pockets: they are taken
	KILL,      ## `count` kills in `kill_group`; with `spawn_enemies` > 0 only those enemies count (all of them)
	SURVIVE,   ## stay alive `seconds` (within `radius` of the spot, 0 = anywhere); `spawn_enemies` come at you
}

@export var kind: Kind = Kind.GO_TO
## What the HUD shows, e.g. "Bring {npc} {need} x {item}" or "Take out the Crows ({count}/{need})".
@export_multiline var text: String = ""
@export var marker: String = ""
@export var position: Vector3 = Vector3.ZERO
@export var offset: Vector3 = Vector3.ZERO
@export var radius: float = 6.0

@export_group("NPC (talk to / deliver)")
@export var npc_id: StringName = &""
@export var npc_name: String = ""
## The NPC's look (-1 = random per game).
@export var npc_variant: int = -1
## Which way they face (degrees, world yaw; 0 = -Z).
@export var npc_yaw: float = 0.0
## What they say when you talk to them (one page per line; shown in the dialogue box).
@export var lines: PackedStringArray = []
## Optional: a DialogueData for this talk (part 20): choices; its "continue" ending finishes the step.
@export var dialogue: Resource

@export_group("Deliver / kill")
@export var item_id: String = ""
@export var count: int = 1
@export var kill_group: StringName = &"rivals"

@export_group("Enemies (kill / survive)")
@export var spawn_enemies: int = 0
## Black Crows post the spawned enemies belong to (&"harbour" / &"yard").
@export var enemy_post: StringName = &"harbour"
@export var enemy_ak: bool = false

@export_group("Survive")
@export var seconds: float = 30.0


## How many the step needs (kills / items / seconds).
func need() -> int:
	match kind:
		Kind.KILL:
			return spawn_enemies if spawn_enemies > 0 else count
		Kind.DELIVER:
			return count
		Kind.SURVIVE:
			return int(seconds)
	return 1


func format(done: int, time_left: float) -> String:
	var item: ItemData = ItemDB.get_item(StringName(item_id)) if item_id != "" else null
	return text.format({"count": done, "need": need(), "time": "%d s" % ceili(maxf(time_left, 0.0)),
			"npc": npc_name, "item": item.display_name if item else item_id})
