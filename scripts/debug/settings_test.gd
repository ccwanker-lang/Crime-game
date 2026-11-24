class_name SettingsTest
extends RefCounted
## Self-test check "settings" (SelfTest._check_settings), session B user list item 1: audio buses + volumes, sound
## players routed to Effects, key rebinding (saved, loaded again, reset), conflicts, mouse look scale, FOV, the menu
## opens with its three tabs and Esc closes it. Works on user://settings_test.cfg (never the player's own file).


static func run(t: Node, _world: Node3D) -> void:
	var tree: SceneTree = t.get_tree()
	var report := func(ok: bool, text: String) -> void: t.call("_report", ok, text)
	var s: Node = tree.root.get_node("Settings")
	report.call(str(s.get("path")) == "user://settings_test.cfg", "test runs use their own settings file (%s)" % s.get("path"))
	var missing: PackedStringArray = []
	for b: Array in s.get("BUSES"):
		if AudioServer.get_bus_index(b[0]) < 0:
			missing.append(b[0])
	report.call(missing.is_empty(), "audio buses Master / Music / SFX / Voice / Ambience exist%s" % (
			" (missing %s)" % ", ".join(missing) if not missing.is_empty() else ""))
	var vols: Dictionary = (s.get("volumes") as Dictionary).duplicate()
	s.get("volumes")["Music"] = 0.5
	s.get("volumes")["SFX"] = 0.0
	s.call("apply_audio")
	var music_db: float = AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))
	var sfx_muted: bool = AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX"))
	report.call(absf(music_db - linear_to_db(0.5)) < 0.01 and sfx_muted,
			"volume sliders: Music 50%% = %.1f dB, Effects 0%% = muted" % music_db)
	s.set("volumes", vols)
	s.call("apply_audio")
	var p3 := AudioStreamPlayer3D.new()
	var keep := AudioStreamPlayer.new()
	keep.set_meta(&"keep_bus", true)
	tree.root.add_child(p3)
	tree.root.add_child(keep)
	report.call(p3.bus == &"SFX" and keep.bus == &"Master", "a new sound player plays on Effects (%s); meta keep_bus stays (%s)"
			% [p3.bus, keep.bus])
	p3.queue_free()
	keep.queue_free()

	# Keys: rebind jump to J, save, scramble, load again -> J; conflict warning; reset -> Space again.
	var space: String = Settings.event_text(s.call("main_event", "jump"))
	var j := InputEventKey.new()
	j.physical_keycode = KEY_J
	s.call("rebind", "jump", j)
	var after: String = Settings.event_text(s.call("main_event", "jump"))
	var cfg := ConfigFile.new()
	cfg.load(str(s.get("path")))
	var saved: String = str(cfg.get_value("keys", "jump", ""))
	var k := InputEventKey.new()
	k.physical_keycode = KEY_K
	s.call("_set_main_event", "jump", k)
	s.call("load_settings")
	var loaded: String = Settings.event_text(s.call("main_event", "jump"))
	var w := InputEventKey.new()
	w.physical_keycode = (s.call("main_event", "move_forward") as InputEventKey).physical_keycode
	s.call("rebind", "jump", w)
	var clash: PackedStringArray = s.call("conflicts", "jump")
	s.call("reset_keys")
	var reset: String = Settings.event_text(s.call("main_event", "jump"))
	report.call(after == "key:%d" % KEY_J and saved == after and loaded == after and "Move forward" in clash and reset == space,
			"rebinding: jump -> J (%s), saved + loaded again (%s), same key as W warns (%s), reset -> %s"
			% [Settings.event_label(j), loaded, ", ".join(clash), Settings.event_label(Settings.event_from_text(reset))])
	var released: bool = InputMap.event_is_action(Settings.event_from_text(space), "jump")
	report.call(released, "after the reset the old key works again for jump")

	# Mouse + FOV.
	s.set("mouse_sensitivity", 1.5)
	s.set("invert_y", true)
	var look: Vector2 = s.call("look_scale")
	s.set("mouse_sensitivity", 1.0)
	s.set("invert_y", false)
	report.call(look.is_equal_approx(Vector2(1.5, -1.5)), "mouse sensitivity x1.5 + invert Y -> look scale %s" % look)

	# The window: three tabs, Esc closes it.
	s.call("open_menu")
	await tree.process_frame
	var menu: Control = s.get("_menu") as Control
	var tab_names: PackedStringArray = []
	if menu:
		for c: Node in (menu.get("tabs") as TabContainer).get_children():
			tab_names.append(str(c.name))
	var keys: int = menu.find_children("Key_*", "Button", true, false).size() if menu else 0
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	if menu:
		menu.call("_input", esc)
	await tree.process_frame
	await tree.process_frame
	report.call(tab_names == PackedStringArray(["Graphics", "Audio", "Controls", "Controller"]) and keys >= 25 and not s.call("is_menu_open"),
			"settings window: tabs %s, %d rebindable keys, Esc closes it" % [", ".join(tab_names), keys])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(str(s.get("path"))))
