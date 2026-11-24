class_name DemoSlots
extends RefCounted
## Two made-up save slots in their own folder (scenario title_menu, --menu-shots, self-test check menus): the real
## saves are never read or written. Slot 1 = a crew of two at night, slot 2 = a fresh game, slot 3 empty.

const DIR: String = "user://demo_slots/"


static func make(dir: String = DIR) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	for f: String in ["savegame.json", "savegame_2.json", "savegame_3.json"]:
		for ext: String in ["", ".info", ".bak", ".info.bak"]:
			if FileAccess.file_exists(dir.path_join(f + ext)):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(dir.path_join(f + ext)))
	_write(dir.path_join("savegame.json"), "2026-11-23T22:41:07", 21.6, 11520.0, 1450,
			{"Alex": {"cash": 18250, "clean": 6400, "inventory": []}, "Sam": {"cash": 3100, "clean": 0, "inventory": []}})
	_write(dir.path_join("savegame_2.json"), "2026-11-20T17:05:44", 9.25, 840.0, 40,
			{"Alex": {"cash": 500, "clean": 0, "inventory": []}})


static func _write(path: String, saved_at: String, hours: float, play_time: float, xp: int, players: Dictionary) -> void:
	var state: Dictionary = {
		"world": {
			"properties": {"starter_room": {"owner": "host"}},
			"stations": {},
			"placed": {},
			"hours": hours,
			"play_time": play_time,
			"progress": {"xp": xp},
			"story": {"intro": "done"},
		},
		"players": players,
	}
	var data: Dictionary = {"version": SaveManager.SAVE_VERSION, "saved_at": saved_at,
			"state": JSON.from_native(state, false)}
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	var info := FileAccess.open(path + ".info", FileAccess.WRITE)
	info.store_string(JSON.stringify(SaveManager.summary_of(state, saved_at)))
	info.close()
