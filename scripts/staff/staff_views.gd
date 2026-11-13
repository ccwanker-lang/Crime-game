class_name StaffViews
extends Node3D
## Every peer: one StaffNPC per crew member (Staff.members), built locally - no network nodes.
## Added to the World by the Staff autoload; rebuild() after every members sync.

var _npcs: Dictionary = {}  # uid -> StaffNPC


func _ready() -> void:
	name = "StaffViews"


func rebuild(members: Dictionary) -> void:
	for uid: String in _npcs.keys():
		if not members.has(uid):
			(_npcs[uid] as Node).queue_free()
			_npcs.erase(uid)
	for uid: String in members:
		var rec: Dictionary = members[uid]
		var npc: StaffNPC = _npcs.get(uid)
		if npc == null or not is_instance_valid(npc):
			npc = StaffNPC.new()
			npc.uid = uid
			npc.setup(rec)
			add_child(npc)
			_npcs[uid] = npc
		npc.update(rec)
