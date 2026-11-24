extends Control
## Main menu: Host, Join (IP), Quit, plus a player name field.
## Optional command line args for quick testing (after "--"):
##   --host   --join=127.0.0.1   --name=Alex   --port=7790

const WORLD_SCENE: String = "res://scenes/world/world.tscn"
const SETTINGS_PATH: String = "user://settings.cfg"
const CONNECT_TIMEOUT_SEC: float = 10.0
## Once the link is up the host may still be loading its world (bigger map since point 47): wait this long for it.
const REGISTER_TIMEOUT_SEC: float = 60.0

@onready var name_edit: LineEdit = %NameEdit
@onready var ip_edit: LineEdit = %IpEdit
@onready var host_button: Button = %HostButton
@onready var join_button: Button = %JoinButton
@onready var quit_button: Button = %QuitButton
@onready var new_game_button: Button = %NewGameButton
@onready var status_label: Label = %StatusLabel

var _connect_timer: Timer


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Back from a test scenario: the menu always works on the real save again.
	if _cmdline_used or not _has_scenario_arg():
		SaveManager.use_real_save()
		Scenarios.pending = ""
	_connect_timer = Timer.new()
	_connect_timer.one_shot = true
	_connect_timer.timeout.connect(_on_connect_timeout)
	Net.connected_to_host.connect(_on_connected_to_host)
	add_child(_connect_timer)
	host_button.pressed.connect(_on_host_pressed)
	new_game_button.pressed.connect(_on_host_pressed.bind(true))
	var date: String = SaveManager.save_date() if SaveManager.enabled else ""
	host_button.text = "Host - continue (saved %s)" % date if date != "" else "Host - new game"
	new_game_button.visible = date != ""
	join_button.pressed.connect(_on_join_pressed)
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	var settings_button := Button.new()
	settings_button.name = "SettingsButton"
	settings_button.text = "Settings"
	settings_button.pressed.connect(Settings.open_menu)
	quit_button.add_sibling(settings_button)
	quit_button.get_parent().move_child(settings_button, quit_button.get_index())
	Net.join_succeeded.connect(_on_join_succeeded)
	Net.join_failed.connect(_on_join_failed)

	_load_settings()
	status_label.text = Net.last_message
	Net.last_message = ""
	_apply_cmdline_args()


## new_game: ignore the save (it is overwritten by the next save; the old one stays as .bak).
func _on_host_pressed(new_game: bool = false) -> void:
	_save_settings()
	GameState.reset()
	if not new_game and SaveManager.load_game():
		print("[Menu] Continuing the saved game")
	var err: Error = Net.host_game(name_edit.text, _port)
	if err != OK:
		_set_status("Could not host on port %d (%s). Is another instance already hosting?" % [_port, error_string(err)])
		return
	get_tree().change_scene_to_file(WORLD_SCENE)


func _on_join_pressed() -> void:
	var address: String = ip_edit.text.strip_edges()
	if address.is_empty():
		_set_status("Enter the host's IP address.")
		return
	_save_settings()
	var err: Error = Net.join_game(address, name_edit.text, _port)
	if err != OK:
		_set_status("Could not start connection (%s)." % error_string(err))
		return
	_set_busy(true)
	_set_status("Connecting to %s..." % address)
	# Give up after a timeout (ENet can take long to notice an unreachable host).
	_connect_timer.start(CONNECT_TIMEOUT_SEC)


func _on_connected_to_host() -> void:
	if not _connect_timer.is_stopped():
		_set_status("Connected - waiting for the host to let you in...")
		_connect_timer.start(REGISTER_TIMEOUT_SEC)


func _on_connect_timeout() -> void:
	Net.leave_game()
	_on_join_failed("Connection timed out. Check the IP, that the host is running, and the firewall.")


func _on_join_succeeded() -> void:
	_connect_timer.stop()
	get_tree().change_scene_to_file(WORLD_SCENE)


func _on_join_failed(reason: String) -> void:
	print("[Menu] Join failed: %s" % reason)
	_connect_timer.stop()
	_set_busy(false)
	_set_status(reason)


func _set_busy(busy: bool) -> void:
	host_button.disabled = busy
	join_button.disabled = busy


func _set_status(text: String) -> void:
	status_label.text = text
	print("[Menu] %s" % text)


# --- Settings (remember name + last IP) ------------------------------------

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		name_edit.text = cfg.get_value("player", "name", "")
		ip_edit.text = cfg.get_value("network", "last_ip", "127.0.0.1")


func _save_settings() -> void:
	# Test runs (--name=B etc.) must not overwrite the player's own name.
	if _cmdline_name:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("player", "name", name_edit.text.strip_edges())
	cfg.set_value("network", "last_ip", ip_edit.text.strip_edges())
	cfg.save(SETTINGS_PATH)


# --- Command line (testing) -------------------------------------------------

## Port for host/join; only changed with --port=N (e.g. for the screenshot tool).
var _port: int = Net.DEFAULT_PORT


static func _has_scenario_arg() -> bool:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--scenario="):
			return true
	return false


## Command line auto host/join happens once; back in the menu you choose yourself.
static var _cmdline_used: bool = false
## True when --name= was given: settings are then not saved.
var _cmdline_name: bool = false


func _apply_cmdline_args() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if _cmdline_used:
		return
	_cmdline_used = true
	var auto_host: bool = false
	var auto_join: bool = false
	var scenario: bool = false
	for arg: String in args:
		if arg.begins_with("--scenario="):
			Scenarios.pending = arg.trim_prefix("--scenario=")
			scenario = true
			auto_host = true
		if arg.begins_with("--name="):
			name_edit.text = arg.trim_prefix("--name=")
			_cmdline_name = true
		elif arg.begins_with("--join="):
			ip_edit.text = arg.trim_prefix("--join=")
			auto_join = true
		elif arg.begins_with("--port="):
			_port = arg.trim_prefix("--port=").to_int()
		elif arg in ["--host", "--screenshot", "--selftest", "--vmpreview", "--perf"]:
			auto_host = true
	# Deferred so the menu is fully ready before switching scenes.
	if scenario and Scenarios.SCENES.has(Scenarios.pending):
		get_tree().change_scene_to_file.call_deferred(Scenarios.SCENES[Scenarios.pending])
	elif auto_host:
		_on_host_pressed.call_deferred(scenario)  # a scenario always starts a fresh test game
	elif auto_join:
		_on_join_pressed.call_deferred()
