class_name TalkNPCData
extends Resource
## NOTES part 20: an NPC that always stands somewhere and talks (a .tres in data/dialogue/npcs/). `Missions` spawns
## them on the host as "MissionNPC_<npc_id>" (the same NPC a mission step may point at by npc_id) and gives them
## a talk box; E opens `dialogue`.

@export var npc_id: StringName = &""
@export var npc_name: String = ""
@export var marker: String = ""
@export var position: Vector3 = Vector3.ZERO
@export var offset: Vector3 = Vector3.ZERO
@export var yaw: float = 0.0
@export var variant: int = -1
@export var dialogue: DialogueData
