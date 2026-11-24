class_name PauseMenu
extends CanvasLayer
## Pause menu (session B, user list item 3): a child of World on every peer. Esc while you play (mouse captured) opens
## it; Esc / Resume closes it. Alone (host without clients) the game really pauses (SceneTree.paused); in co-op it
## keeps running (a note says so) and it unpauses by itself when a friend joins. Holds Resume, Settings, Save game
## (host), Leave to menu (host saves first), Quit to desktop, and who is playing (was the old top-left panel).

var world: Node
var is_open: bool = false
var _root: Control
var _note: Label
var _players: Label
var _save_button: Button
var _invite_button: Button
var _toast: Label
var _player_box: VBoxContainer
var _friend_box: VBoxContainer


func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	world = get_parent()
	_build()
	_root.visible = false
	Net.players_changed.connect(_refresh)


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"release_mouse") or (event is InputEventKey and (event as InputEventKey).echo):
		return
	if is_open:
		if Settings.is_menu_open():
			return  # (the settings window closes itself first)
		close()
		get_viewport().set_input_as_handled()
	elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not Settings.is_menu_open():
		open()  # (not handled: the player also lets go of the trigger / aim as before)


func solo() -> bool:
	return multiplayer.is_server() and Net.players.size() <= 1


func open() -> void:
	if is_open:
		return
	is_open = true
	_root.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_toast.text = ""
	_refresh()
	if solo():
		get_tree().paused = true
	(_root.find_child("Resume", true, false) as Button).grab_focus.call_deferred()


func close() -> void:
	if not is_open:
		return
	is_open = false
	_root.visible = false
	get_tree().paused = false
	if not Settings.is_menu_open():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _refresh() -> void:
	if solo():
		_note.text = "Paused"
	else:
		_note.text = "Co-op: the game keeps running"
		if get_tree().paused and is_open:
			get_tree().paused = false  # (a friend joined while you were paused)
	var lines: PackedStringArray = []
	for peer_id: int in Net.players:
		var tag: String = "  (host)" if peer_id == 1 else ""
		var me: String = "  - you" if peer_id == multiplayer.get_unique_id() else ""
		lines.append("%s%s%s" % [Net.get_player_name(peer_id), tag, me])
	_players.text = "\n".join(lines)
	_save_button.visible = multiplayer.is_server() and SaveManager.enabled
	_invite_button.visible = SteamNet.in_steam_game()
	if not _invite_button.visible:
		_show_friends(false)


func _build() -> void:
	_root = Control.new()
	_root.name = "Pause"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.theme = load("res://assets/ui/game_theme.tres")
	add_child(_root)
	var shade := TextureRect.new()
	shade.texture = TitleArt.horizontal_fade(Color(0.02, 0.02, 0.04, 0.92), Color(0, 0, 0, 0.35))
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	_root.add_child(shade)
	var left := VBoxContainer.new()
	left.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	left.offset_left = 80
	left.offset_right = 600
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override(&"separation", 4)
	_root.add_child(left)
	left.add_child(TitleArt.logo(56, false))
	_note = Label.new()
	_note.add_theme_font_size_override(&"font_size", 20)
	_note.add_theme_color_override(&"font_color", TitleArt.ACCENT)
	left.add_child(_note)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 26)
	left.add_child(gap)
	var items: Array = [
		["Resume", "Resume", close],
		["Settings", "Settings", Settings.open_menu],
		["Invite", "Invite friends (Steam)", _toggle_friends],
		["SaveGame", "Save game", _save],
		["Leave", "Leave to menu", _leave],
		["Quit", "Quit to desktop", _quit],
	]
	for it: Array in items:
		var b := TitleArt.menu_button(it[1], 28)
		b.name = it[0]
		b.pressed.connect(it[2])
		left.add_child(b)
		if it[0] == "SaveGame":
			_save_button = b
		if it[0] == "Invite":
			_invite_button = b
	_toast = Label.new()
	_toast.add_theme_color_override(&"font_color", Color(0.7, 1, 0.7))
	left.add_child(_toast)

	var side := PanelContainer.new()
	side.add_theme_stylebox_override(&"panel", TitleArt.panel_style(0.75))
	side.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	side.offset_left = -420
	side.offset_right = -80
	side.offset_top = -80
	side.offset_bottom = 80
	_root.add_child(side)
	var both := VBoxContainer.new()
	side.add_child(both)
	var box := VBoxContainer.new()
	_player_box = box
	both.add_child(box)
	_friend_box = VBoxContainer.new()
	_friend_box.name = "Friends"
	_friend_box.visible = false
	both.add_child(_friend_box)
	var h := Label.new()
	h.text = "Players"
	h.add_theme_font_size_override(&"font_size", 24)
	h.add_theme_color_override(&"font_color", TitleArt.ACCENT)
	box.add_child(h)
	_players = Label.new()
	_players.add_theme_font_size_override(&"font_size", 18)
	box.add_child(_players)
	var keys := Label.new()
	keys.text = "\nF1 in the game: every key"
	keys.add_theme_color_override(&"font_color", Color(0.65, 0.65, 0.7))
	box.add_child(keys)


func _save() -> void:
	if SaveManager.save_game():
		_toast.text = "Saved in slot %d (%s)" % [SaveManager.slot, Time.get_time_string_from_system().left(5)]
	else:
		_toast.text = "Could not save."


func _leave() -> void:
	get_tree().paused = false
	is_open = false
	world.call("_on_leave_pressed")


func _quit() -> void:
	get_tree().paused = false
	if multiplayer.is_server():
		SaveManager.save_game()
	Net.leave_game()
	get_tree().quit()


# --- Steam invites (user list item 4) ---------------------------------------------------

func _toggle_friends() -> void:
	_show_friends(not _friend_box.visible)


func _show_friends(on: bool) -> void:
	_friend_box.visible = on
	_player_box.visible = not on
	if not on:
		return
	for c: Node in _friend_box.get_children():
		c.queue_free()
	var h := Label.new()
	h.text = "Invite friends"
	h.add_theme_font_size_override(&"font_size", 24)
	h.add_theme_color_override(&"font_color", TitleArt.ACCENT)
	_friend_box.add_child(h)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 260)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_friend_box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var shown: int = 0
	for f: Dictionary in SteamNet.friends():
		if not f["online"]:
			continue
		var row := HBoxContainer.new()
		var l := Label.new()
		l.text = str(f["name"])
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(l)
		var b := Button.new()
		b.text = "Invite"
		b.pressed.connect(func() -> void:
			b.text = "Sent" if SteamNet.invite(int(f["id"])) else "Failed"
			b.disabled = true)
		row.add_child(b)
		list.add_child(row)
		shown += 1
	if shown == 0:
		var none := Label.new()
		none.text = "None of your Steam friends is online."
		list.add_child(none)
	var overlay := Button.new()
	overlay.text = "Steam overlay invite..."
	overlay.pressed.connect(SteamNet.invite_overlay)
	_friend_box.add_child(overlay)
