extends Control
## Main menu: Host, Join (IP), Quit, plus a player name field.
## Optional command line args for quick testing (after "--"):
##   --host   --join=127.0.0.1   --name=Alex   --port=7790

const WORLD_SCENE: String = "res://scenes/world/world.tscn"
const SETTINGS_PATH: String = "user://settings.cfg"
const CONNECT_TIMEOUT_SEC: float = 10.0

@onready var name_edit: LineEdit = %NameEdit
@onready var ip_edit: LineEdit = %IpEdit
@onready var host_button: Button = %HostButton
@onready var join_button: Button = %JoinButton
@onready var quit_button: Button = %QuitButton
@onready var status_label: Label = %StatusLabel

var _connect_timer: Timer


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_connect_timer = Timer.new()
	_connect_timer.one_shot = true
	_connect_timer.timeout.connect(_on_connect_timeout)
	add_child(_connect_timer)
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	Net.join_succeeded.connect(_on_join_succeeded)
	Net.join_failed.connect(_on_join_failed)

	_load_settings()
	status_label.text = Net.last_message
	Net.last_message = ""
	_apply_cmdline_args()


func _on_host_pressed() -> void:
	_save_settings()
	GameState.reset()  # step 9: load the save here instead
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


func _on_connect_timeout() -> void:
	Net.leave_game()
	_on_join_failed("Connection timed out. Check the IP, that the host is running, and the firewall.")


func _on_join_succeeded() -> void:
	_connect_timer.stop()
	get_tree().change_scene_to_file(WORLD_SCENE)


func _on_join_failed(reason: String) -> void:
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
	var cfg := ConfigFile.new()
	cfg.set_value("player", "name", name_edit.text.strip_edges())
	cfg.set_value("network", "last_ip", ip_edit.text.strip_edges())
	cfg.save(SETTINGS_PATH)


# --- Command line (testing) -------------------------------------------------

## Port for host/join; only changed with --port=N (e.g. for the screenshot tool).
var _port: int = Net.DEFAULT_PORT


## Command line auto host/join happens once; back in the menu you choose yourself.
static var _cmdline_used: bool = false


func _apply_cmdline_args() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if _cmdline_used:
		return
	_cmdline_used = true
	var auto_host: bool = false
	var auto_join: bool = false
	for arg: String in args:
		if arg.begins_with("--name="):
			name_edit.text = arg.trim_prefix("--name=")
		elif arg.begins_with("--join="):
			ip_edit.text = arg.trim_prefix("--join=")
			auto_join = true
		elif arg.begins_with("--port="):
			_port = arg.trim_prefix("--port=").to_int()
		elif arg in ["--host", "--screenshot", "--selftest"]:
			auto_host = true
	# Deferred so the menu is fully ready before switching scenes.
	if auto_host:
		_on_host_pressed.call_deferred()
	elif auto_join:
		_on_join_pressed.call_deferred()
