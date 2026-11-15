class_name MissionData
extends Resource
## A mission (NOTES part 19): a .tres in data/missions/ (every file there is loaded by `Missions`). Make a new one
## in Godot: FileSystem > data/missions > right click > New > Resource... > MissionData, then fill it in the
## Inspector (objectives: Add Element > New MissionObjective).

@export var id: StringName = &""
@export var title: String = ""
@export_multiline var summary: String = ""
## Who gives it (the phone contact that texts about it).
@export var giver: String = "Marco"
@export var min_rank: int = 0
## Only after this mission is done (empty = none).
@export var requires: StringName = &""
@export var repeatable: bool = false
@export var objectives: Array[MissionObjective] = []

@export_group("Reward")
## Every crew member who was there from the start gets this cash + these items; the crew gets the XP once.
@export var reward_cash: int = 0
@export var reward_xp: int = 0
## item id -> count
@export var reward_items: Dictionary = {}
@export_multiline var done_text: String = ""


func reward_text() -> String:
	var parts: Array[String] = []
	if reward_cash > 0:
		parts.append("€%s" % Property.money(reward_cash))
	if reward_xp > 0:
		parts.append("%d XP" % reward_xp)
	for id: String in reward_items:
		var it: ItemData = ItemDB.get_item(StringName(id))
		parts.append("%d x %s" % [int(reward_items[id]), it.display_name if it else id])
	return ", ".join(parts) if not parts.is_empty() else "nothing"
