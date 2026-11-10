extends Node
## Saves/loads GameState as JSON in user:// (host only).
## Autosave + save-on-quit are added in step 9.
## Note: JSON turns all numbers into floats; convert back to int when loading.

const SAVE_PATH: String = "user://savegame.json"
const SAVE_VERSION: int = 1


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> bool:
	if not multiplayer.is_server():
		return false
	var data: Dictionary = {
		"version": SAVE_VERSION,
		"saved_at": Time.get_datetime_string_from_system(),
		"state": GameState.to_save_dict(),
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("[Save] Cannot write %s: %s" % [SAVE_PATH, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	print("[Save] Saved to %s" % ProjectSettings.globalize_path(SAVE_PATH))
	return true


func load_game() -> bool:
	if not has_save():
		return false
	var text: String = FileAccess.get_file_as_string(SAVE_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_error("[Save] Save file is corrupt: %s" % SAVE_PATH)
		return false
	var data: Dictionary = parsed
	GameState.from_save_dict(data.get("state", {}))
	print("[Save] Loaded save from %s" % data.get("saved_at", "?"))
	return true
