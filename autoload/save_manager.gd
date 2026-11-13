extends Node
## Saves/loads GameState in user:// (host only). Step 9.
##
## - Format: JSON via JSON.from_native/to_native, so ints stay ints and
##   Vector3s stay Vector3s (no objects allowed).
## - Written to a .tmp file first, the previous save is kept as .bak.
## - Autosave every AUTOSAVE_INTERVAL s while hosting a world, and on Leave/quit.
##   Before writing, the world scene puts live data (player positions, health,
##   loaded magazines, time of day, loot bags) into GameState (capture_for_save).
## - Test runs (--selftest, --screenshot, --netcheck, --vmpreview) never load
##   or write the real save (`enabled` = false). `--save=user://x.json` uses
##   another file (and saves even in test runs), `--autosave=N` changes the interval.

const SAVE_PATH: String = "user://savegame.json"
## Test scenarios (Scenarios, F9 / --scenario=) play on this file, never on the real save.
const SCENARIO_PATH: String = "user://scenario_test.json"
const SAVE_VERSION: int = 2
const AUTOSAVE_INTERVAL: float = 120.0
const TEST_FLAGS: Array[String] = ["--selftest", "--screenshot", "--netcheck", "--vmpreview"]

var enabled: bool = true
var save_path: String = SAVE_PATH
var autosave_interval: float = AUTOSAVE_INTERVAL
var _autosave_timer: float = 0.0
var scenario_mode: bool = false
var _normal_path: String = SAVE_PATH
var _normal_enabled: bool = true


func _ready() -> void:
	var explicit_path: bool = false
	for arg: String in OS.get_cmdline_user_args():
		if arg in TEST_FLAGS:
			enabled = false
		elif arg.begins_with("--save="):
			# Tests: own save file (never the real one); saving stays on.
			save_path = arg.trim_prefix("--save=")
			explicit_path = true
		elif arg.begins_with("--autosave="):
			autosave_interval = arg.trim_prefix("--autosave=").to_float()
	if explicit_path:
		enabled = true
	_normal_path = save_path
	_normal_enabled = enabled
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--scenario="):
			use_scenario_save()


## Scenarios: from now on load/save the scenario test file (the real save is left alone).
func use_scenario_save() -> void:
	scenario_mode = true
	save_path = SCENARIO_PATH
	enabled = true
	_autosave_timer = 0.0


## Back to the real save (main menu).
func use_real_save() -> void:
	if not scenario_mode:
		return
	scenario_mode = false
	save_path = _normal_path
	enabled = _normal_enabled


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


## "2026-11-12 21:04" of the save file, "" if none.
func save_date() -> String:
	if not has_save():
		return ""
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if parsed is Dictionary:
		return str((parsed as Dictionary).get("saved_at", "")).replace("T", " ").left(16)
	return ""


func _hosting_world() -> bool:
	if not multiplayer.is_server() or not (multiplayer.multiplayer_peer is ENetMultiplayerPeer):
		return false
	var scene: Node = get_tree().current_scene
	return scene != null and scene.has_method("capture_for_save")


func _process(delta: float) -> void:
	if not enabled or not _hosting_world():
		_autosave_timer = 0.0
		return
	_autosave_timer += delta
	if _autosave_timer >= autosave_interval:
		_autosave_timer = 0.0
		save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and enabled and _hosting_world():
		save_game()


## Host: writes the save. Returns true on success.
func save_game() -> bool:
	if not enabled or not multiplayer.is_server():
		return false
	var scene: Node = get_tree().current_scene
	if scene and scene.has_method("capture_for_save"):
		scene.call("capture_for_save")
	# Plain header (readable, used by the menu) + the typed state.
	var data: Dictionary = {
		"version": SAVE_VERSION,
		"saved_at": Time.get_datetime_string_from_system(),
		"state": JSON.from_native(GameState.to_save_dict(), false),
	}
	var tmp: String = save_path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		push_error("[Save] Cannot write %s: %s" % [tmp, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	var abs_path: String = ProjectSettings.globalize_path(save_path)
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(abs_path + ".bak")
		DirAccess.rename_absolute(abs_path, abs_path + ".bak")
	var err: Error = DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), abs_path)
	if err != OK:
		push_error("[Save] Cannot move the save into place: %s" % error_string(err))
		return false
	print("[Save] Saved to %s" % abs_path)
	return true


## Host, before the world loads: puts the save into GameState.
func load_game() -> bool:
	if not enabled or not has_save():
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not (parsed is Dictionary):
		push_error("[Save] Save file is corrupt: %s" % save_path)
		return false
	var data: Dictionary = parsed
	if int(data.get("version", 0)) != SAVE_VERSION:
		push_error("[Save] Unknown save version in %s" % save_path)
		return false
	var state: Variant = JSON.to_native(data.get("state", {}), false)
	if not (state is Dictionary):
		push_error("[Save] Save file is corrupt: %s" % save_path)
		return false
	GameState.from_save_dict(state)
	print("[Save] Loaded save from %s" % data.get("saved_at", "?"))
	return true
