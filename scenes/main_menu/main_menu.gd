extends Control
## Title page (session B, user list item 3; built in code): background picture, logo, Play / Join a friend /
## Settings / Quit, the player name, and a side panel that shows the save slots (Continue / New game / Delete) or the
## join form. Music: Soundscape plays the menu track.
## Optional command line args for quick testing (after "--"):
##   --host   --join=127.0.0.1   --name=Alex   --port=7790

const SETTINGS_PATH: String = "user://settings.cfg"
const CONNECT_TIMEOUT_SEC: float = 10.0
## Once the link is up the host may still be loading its world (bigger map since point 47): wait this long for it.
const REGISTER_TIMEOUT_SEC: float = 60.0
const CONFIRM_TIME: float = 4.0

var name_edit: LineEdit
var ip_edit: LineEdit
var play_button: Button
var join_button: Button
var settings_button: Button
var quit_button: Button
var status_label: Label
var side: PanelContainer
var slots_page: VBoxContainer
var join_page: VBoxContainer
var join_go: Button
var steam_list: VBoxContainer
var steam_check: CheckBox
var _connect_timer: Timer
var _busy: bool = false
## Inline "are you sure?": button -> time it was armed.
var _armed: Dictionary = {}


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Back from a test scenario: the menu always works on the real save again.
	if _cmdline_used or not _has_scenario_arg():
		SaveManager.use_real_save()
		Scenarios.pending = ""
	_build()
	_connect_timer = Timer.new()
	_connect_timer.one_shot = true
	_connect_timer.timeout.connect(_on_connect_timeout)
	add_child(_connect_timer)
	Net.connected_to_host.connect(_on_connected_to_host)
	Net.join_succeeded.connect(_on_join_succeeded)
	Net.join_failed.connect(_on_join_failed)
	SteamNet.status.connect(_set_status)
	SteamNet.lobbies_found.connect(_fill_steam_games)
	SteamNet.invites_changed.connect(_refresh_steam_games)
	_load_settings()
	_fill_slots()
	status_label.text = Net.last_message
	Net.last_message = ""
	play_button.grab_focus.call_deferred()
	if "--menu-shots" in OS.get_cmdline_user_args() and not get_tree().root.has_node(^"MenuShots"):
		var shots: Node = (load("res://scripts/debug/menu_shots.gd") as GDScript).new()
		shots.name = "MenuShots"
		shots.set("menu", self)
		get_tree().root.add_child.call_deferred(shots)
	_apply_cmdline_args()
	check_pending_steam.call_deferred()


## Steam "Join game" / an accepted invite / +connect_lobby: join that lobby now (SteamNet.pending_lobby).
func check_pending_steam() -> void:
	if SteamNet.pending_lobby == 0 or _busy:
		return
	var lobby: int = SteamNet.pending_lobby
	SteamNet.pending_lobby = 0
	_join_steam(lobby)


# --- Layout ---------------------------------------------------------------------------

func _build() -> void:
	theme = load("res://assets/ui/game_theme.tres")
	var black := ColorRect.new()
	black.color = Color(0.03, 0.03, 0.05)
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(black)
	var bg := TextureRect.new()
	bg.name = "Background"
	bg.texture = load("res://assets/ui/backgrounds/title_night.jpg")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(bg)
	for fade: GradientTexture2D in [TitleArt.horizontal_fade(Color(0.02, 0.02, 0.04, 0.95), Color(0, 0, 0, 0.1)),
			TitleArt.vertical_fade(Color(0, 0, 0, 0), Color(0, 0, 0, 0.6))]:
		var shade := TextureRect.new()
		shade.texture = fade
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		shade.stretch_mode = TextureRect.STRETCH_SCALE
		add_child(shade)

	var left := VBoxContainer.new()
	left.name = "Left"
	left.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	left.offset_left = 80
	left.offset_right = 600
	left.offset_top = 0
	left.offset_bottom = 0
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override(&"separation", 6)
	add_child(left)
	left.add_child(TitleArt.logo(84))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 40)
	left.add_child(gap)
	play_button = TitleArt.menu_button("Play")
	play_button.name = "PlayButton"
	play_button.pressed.connect(_show_page.bind("slots"))
	join_button = TitleArt.menu_button("Join a friend")
	join_button.name = "JoinButton"
	join_button.pressed.connect(_show_page.bind("join"))
	settings_button = TitleArt.menu_button("Settings")
	settings_button.name = "SettingsButton"
	settings_button.pressed.connect(Settings.open_menu)
	quit_button = TitleArt.menu_button("Quit")
	quit_button.name = "QuitButton"
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	for b: Button in [play_button, join_button, settings_button, quit_button]:
		left.add_child(b)
	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 28)
	left.add_child(gap2)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override(&"separation", 10)
	var nl := Label.new()
	nl.text = "Playing as"
	nl.add_theme_color_override(&"font_color", Color(0.7, 0.7, 0.75))
	name_row.add_child(nl)
	name_edit = LineEdit.new()
	name_edit.name = "NameEdit"
	name_edit.placeholder_text = "Your name"
	name_edit.max_length = 16
	name_edit.custom_minimum_size = Vector2(220, 0)
	name_row.add_child(name_edit)
	left.add_child(name_row)

	side = PanelContainer.new()
	side.name = "Side"
	side.add_theme_stylebox_override(&"panel", TitleArt.panel_style())
	side.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	side.offset_left = -640
	side.offset_right = -80
	side.offset_top = -250
	side.offset_bottom = 250
	side.visible = false
	add_child(side)
	slots_page = VBoxContainer.new()
	slots_page.name = "Slots"
	slots_page.add_theme_constant_override(&"separation", 12)
	side.add_child(slots_page)
	join_page = VBoxContainer.new()
	join_page.name = "Join"
	join_page.add_theme_constant_override(&"separation", 12)
	side.add_child(join_page)
	_build_join_page()

	status_label = Label.new()
	status_label.name = "Status"
	status_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	status_label.offset_left = 80
	status_label.offset_top = -70
	status_label.offset_bottom = -40
	status_label.offset_right = -400
	status_label.add_theme_color_override(&"font_color", Color(1, 0.85, 0.6))
	add_child(status_label)
	var ver := Label.new()
	ver.text = "prototype - milestone 3"
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.offset_left = -300
	ver.offset_top = -50
	ver.offset_right = -24
	ver.offset_bottom = -20
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ver.add_theme_color_override(&"font_color", Color(1, 1, 1, 0.4))
	add_child(ver)
	if SaveManager.slot_dir != "user://":
		var demo := Label.new()
		demo.text = "DEMO SLOTS (scenario title_menu) - your real saves are not shown"
		demo.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		demo.offset_left = -400
		demo.offset_right = 400
		demo.offset_top = 16
		demo.offset_bottom = 46
		demo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		demo.add_theme_color_override(&"font_color", Color(1, 0.45, 0.35))
		add_child(demo)


func _build_join_page() -> void:
	join_page.add_child(_heading("Join a friend"))
	if SteamNet.available():
		var row := HBoxContainer.new()
		var sl := Label.new()
		sl.text = "Friends' games (Steam)"
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sl.add_theme_font_size_override(&"font_size", 20)
		row.add_child(sl)
		var refresh := Button.new()
		refresh.name = "SteamRefresh"
		refresh.text = "Refresh"
		refresh.pressed.connect(_refresh_steam_games)
		row.add_child(refresh)
		join_page.add_child(row)
		steam_list = VBoxContainer.new()
		steam_list.name = "SteamGames"
		join_page.add_child(steam_list)
		var sep := HSeparator.new()
		join_page.add_child(sep)
	var hint := Label.new()
	hint.text = "Or type the host's IP address. On the same network that is their local IP (192.168...); over the " \
			+ "internet the host needs port %d forwarded." % Net.DEFAULT_PORT
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override(&"font_color", Color(0.75, 0.75, 0.8))
	join_page.add_child(hint)
	ip_edit = LineEdit.new()
	ip_edit.name = "IpEdit"
	ip_edit.text = "127.0.0.1"
	ip_edit.placeholder_text = "127.0.0.1"
	ip_edit.add_theme_font_size_override(&"font_size", 22)
	ip_edit.text_submitted.connect(func(_t: String) -> void: _on_join_pressed())
	join_page.add_child(ip_edit)
	join_go = Button.new()
	join_go.name = "JoinGo"
	join_go.text = "Join"
	join_go.custom_minimum_size = Vector2(0, 44)
	join_go.pressed.connect(_on_join_pressed)
	join_page.add_child(join_go)


func _heading(text: String) -> Label:
	var h := Label.new()
	h.text = text
	h.add_theme_font_size_override(&"font_size", 30)
	h.add_theme_color_override(&"font_color", TitleArt.ACCENT)
	return h


func _show_page(page: String) -> void:
	if _busy:
		return
	var already: bool = side.visible and ((page == "slots" and slots_page.visible) or (page == "join" and join_page.visible))
	side.visible = not already
	slots_page.visible = page == "slots"
	join_page.visible = page == "join"
	if page == "slots":
		_fill_slots()
	elif side.visible:
		ip_edit.grab_focus()
		_refresh_steam_games()


# --- Save slots -----------------------------------------------------------------------

func _fill_slots() -> void:
	for c: Node in slots_page.get_children():
		slots_page.remove_child(c)  # (now, so the new nodes keep their names)
		c.queue_free()
	slots_page.add_child(_heading("Play"))
	if SteamNet.available():
		steam_check = CheckBox.new()
		steam_check.name = "SteamHost"
		steam_check.text = "Friends can join via Steam"
		steam_check.button_pressed = SteamNet.host_via_steam
		steam_check.toggled.connect(SteamNet.set_host_via_steam)
		slots_page.add_child(steam_check)
		var note := Label.new()
		note.text = SteamNet.message if SteamNet.message != "" else "Steam starts when you host."
		note.add_theme_font_size_override(&"font_size", 14)
		note.add_theme_color_override(&"font_color", Color(0.65, 0.65, 0.7))
		slots_page.add_child(note)
	if not SaveManager.enabled and not SaveManager.scenario_mode:
		var off := Label.new()
		off.text = "Saving is off in this test run."
		slots_page.add_child(off)
	for n: int in range(1, SaveManager.SLOTS + 1):
		slots_page.add_child(_slot_card(n))


func _slot_card(n: int) -> PanelContainer:
	var info: Dictionary = SaveManager.slot_info(n)
	var card := PanelContainer.new()
	card.name = "Slot%d" % n
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.05)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(12)
	if n == SaveManager.slot and info.get("exists", false):
		sb.border_color = TitleArt.ACCENT
		sb.set_border_width_all(2)
	card.add_theme_stylebox_override(&"panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	card.add_child(row)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override(&"separation", 0)
	row.add_child(text)
	var title := Label.new()
	title.add_theme_font_size_override(&"font_size", 22)
	text.add_child(title)
	var buttons := VBoxContainer.new()
	buttons.custom_minimum_size = Vector2(150, 0)
	row.add_child(buttons)
	if info.get("exists", false):
		title.text = "Slot %d%s" % [n, "   (last played)" if n == SaveManager.slot else ""]
		var names: Array = info.get("players", [])
		var xp: int = int(info.get("xp", 0))
		for line: String in [
				"Saved %s" % str(info.get("saved_at", "?")),
				"%s  -  € %s  -  %s" % [", ".join(PackedStringArray(names)) if not names.is_empty() else "nobody yet",
						_money(int(info.get("money", 0))), Progression.rank_name(Progression.rank_for(xp))],
				"Played %s  -  in the game it is %s" % [TitleArt.play_time_text(float(info.get("play_time", 0.0))),
						_clock(float(info.get("hours", 12.0)))]]:
			var l := Label.new()
			l.text = line
			l.add_theme_font_size_override(&"font_size", 15)
			l.add_theme_color_override(&"font_color", Color(0.78, 0.78, 0.82))
			l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			text.add_child(l)
		var cont := _slot_button(buttons, "Continue", "Continue%d" % n)
		cont.pressed.connect(_play_slot.bind(n, false))
		var fresh := _slot_button(buttons, "New game", "New%d" % n)
		fresh.pressed.connect(_confirm.bind(fresh, "Overwrite?", _play_slot.bind(n, true)))
		var del := _slot_button(buttons, "Delete", "Delete%d" % n)
		del.add_theme_color_override(&"font_color", Color(1, 0.55, 0.5))
		del.pressed.connect(_confirm.bind(del, "Sure?", _delete_slot.bind(n)))
	else:
		title.text = "Slot %d  -  empty" % n
		var l := Label.new()
		l.text = "Start a new game here."
		l.add_theme_color_override(&"font_color", Color(0.6, 0.6, 0.65))
		text.add_child(l)
		var fresh := _slot_button(buttons, "New game", "New%d" % n)
		fresh.pressed.connect(_play_slot.bind(n, true))
	return card


func _slot_button(parent: Control, text: String, node_name: String) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = text
	b.set_meta(&"label", text)
	parent.add_child(b)
	return b


## First press arms the button ("Sure?"), a second press within CONFIRM_TIME runs `action`.
func _confirm(b: Button, ask: String, action: Callable) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	if _armed.has(b) and now - float(_armed[b]) < CONFIRM_TIME:
		_armed.erase(b)
		action.call()
		return
	_armed[b] = now
	b.text = ask
	get_tree().create_timer(CONFIRM_TIME).timeout.connect(func() -> void:
		if is_instance_valid(b) and _armed.has(b):
			_armed.erase(b)
			b.text = str(b.get_meta(&"label")))


func _play_slot(n: int, new_game: bool) -> void:
	SaveManager.use_slot(n)
	_save_settings()
	_on_host_pressed(new_game)


func _delete_slot(n: int) -> void:
	SaveManager.delete_slot(n)
	_set_status("Slot %d deleted (a backup .bak stays in the save folder)." % n)
	_fill_slots()


static func _money(v: int) -> String:
	var s: String = str(absi(v))
	var out: String = ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if v < 0 else "") + s + out


static func _clock(hours: float) -> String:
	var h: float = fposmod(hours, 24.0)
	return "%02d:%02d" % [int(h), int((h - int(h)) * 60.0)]


# --- Host / join -----------------------------------------------------------------------

## new_game: ignore the save (it is overwritten by the next save; the old one stays as .bak).
func _on_host_pressed(new_game: bool = false) -> void:
	_save_settings()
	GameState.reset()
	if not new_game and SaveManager.load_game():
		print("[Menu] Continuing the saved game (slot %d)" % SaveManager.slot)
	if SteamNet.should_host():
		_set_busy(true)
		SteamNet.host_ready.connect(_on_steam_host_ready, CONNECT_ONE_SHOT)
		SteamNet.host_failed.connect(_on_steam_host_failed, CONNECT_ONE_SHOT)
		SteamNet.host(name_edit.text)
		return
	_host_ip()


func _on_steam_host_ready() -> void:
	if SteamNet.host_failed.is_connected(_on_steam_host_failed):
		SteamNet.host_failed.disconnect(_on_steam_host_failed)
	Loading.go_to_world()


## Steam didn't work: host by IP as before (friends can still join with the IP).
func _on_steam_host_failed(reason: String) -> void:
	if SteamNet.host_ready.is_connected(_on_steam_host_ready):
		SteamNet.host_ready.disconnect(_on_steam_host_ready)
	_set_busy(false)
	_set_status("%s Hosting by IP instead." % reason)
	_host_ip()


func _host_ip() -> void:
	var err: Error = Net.host_game(name_edit.text, _port)
	if err != OK:
		_set_status("Could not host on port %d (%s). Is another instance already hosting?" % [_port, error_string(err)])
		return
	Loading.go_to_world()


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


# --- Steam games ---

func _refresh_steam_games() -> void:
	if steam_list == null:
		return
	for c: Node in steam_list.get_children():
		steam_list.remove_child(c)
		c.queue_free()
	if not SteamNet.start():
		steam_list.add_child(_small(SteamNet.message + " Join by IP below."))
		return
	for inv: Dictionary in SteamNet.invites:
		steam_list.add_child(_game_row("%s invited you" % inv["from"], int(inv["lobby"])))
	steam_list.add_child(_small("Looking for friends' games..."))
	SteamNet.find_lobbies()


func _fill_steam_games(list: Array) -> void:
	if steam_list == null:
		return
	for c: Node in steam_list.get_children():
		if c is Label:
			c.queue_free()
	for g: Dictionary in list:
		steam_list.add_child(_game_row("%s  (%d/%d)" % [g["name"], int(g["players"]), Net.MAX_PLAYERS], int(g["lobby"])))
	if list.is_empty() and SteamNet.invites.is_empty():
		steam_list.add_child(_small("No friends are hosting right now."))


func _game_row(text: String, lobby: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = text
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var b := Button.new()
	b.text = "Join"
	b.pressed.connect(_join_steam.bind(lobby))
	row.add_child(b)
	return row


func _small(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override(&"font_size", 15)
	l.add_theme_color_override(&"font_color", Color(0.65, 0.65, 0.7))
	return l


func _join_steam(lobby: int) -> void:
	if _busy:
		return
	_save_settings()
	_set_busy(true)
	SteamNet.invites = SteamNet.invites.filter(func(d: Dictionary) -> bool: return int(d["lobby"]) != lobby)
	SteamNet.join(lobby, name_edit.text)
	_connect_timer.start(REGISTER_TIMEOUT_SEC)


func _on_connected_to_host() -> void:
	if not _connect_timer.is_stopped():
		_set_status("Connected - waiting for the host to let you in...")
		_connect_timer.start(REGISTER_TIMEOUT_SEC)


func _on_connect_timeout() -> void:
	Net.leave_game()
	_on_join_failed("Connection timed out. Check the IP, that the host is running, and the firewall.")


func _on_join_succeeded() -> void:
	_connect_timer.stop()
	Loading.go_to_world()


func _on_join_failed(reason: String) -> void:
	print("[Menu] Join failed: %s" % reason)
	_connect_timer.stop()
	_set_busy(false)
	_set_status(reason)


func _set_busy(busy: bool) -> void:
	_busy = busy
	for b: Button in [play_button, join_button, join_go]:
		b.disabled = busy
	if steam_list:
		for row: Node in steam_list.get_children():
			for b: Node in row.get_children():
				if b is Button:
					(b as Button).disabled = busy


func _set_status(text: String) -> void:
	status_label.text = text
	print("[Menu] %s" % text)


# --- Settings (name, last IP, last slot) --------------------------------------------------

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		name_edit.text = cfg.get_value("player", "name", "")
		ip_edit.text = cfg.get_value("network", "last_ip", "127.0.0.1")
		if SaveManager.slot_dir == "user://":
			SaveManager.use_slot(int(cfg.get_value("player", "last_slot", 1)))


func _save_settings() -> void:
	# Test runs (--name=B etc.) must not overwrite the player's own name.
	if _cmdline_name:
		return
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)  # (keep the Settings autoload's graphics / audio / keys in the same file)
	cfg.set_value("player", "name", name_edit.text.strip_edges())
	cfg.set_value("network", "last_ip", ip_edit.text.strip_edges())
	if SaveManager.slot_dir == "user://":
		cfg.set_value("player", "last_slot", SaveManager.slot)
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
