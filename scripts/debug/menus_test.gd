class_name MenusTest
extends RefCounted
## Self-test check "menus" (SelfTest._check_menus), session B user list item 3: save slots (paths, headers, delete to
## .bak, play time), the title page's slot cards + "are you sure?" buttons (demo folder, never the real saves), the
## loading screen's tips / pictures, and the pause menu (pauses alone, Esc closes, old panel hidden).

const DIR: String = "user://menus_test_slots/"


static func run(t: Node, world: Node3D) -> void:
	var tree: SceneTree = t.get_tree()
	var report := func(ok: bool, text: String) -> void: t.call("_report", ok, text)
	var old: Dictionary = {"path": SaveManager.save_path, "slot": SaveManager.slot, "dir": SaveManager.slot_dir,
			"normal": SaveManager.get("_normal_path"), "enabled": SaveManager.enabled}

	# Slots.
	SaveManager.slot_dir = DIR
	DemoSlots.make(DIR)
	var p1: String = SaveManager.slot_path(1)
	var p3: String = SaveManager.slot_path(3)
	var i1: Dictionary = SaveManager.slot_info(1)
	var i3: Dictionary = SaveManager.slot_info(3)
	report.call(p1.ends_with("menus_test_slots/savegame.json") and p3.ends_with("savegame_3.json") and i1.get("exists", false)
			and (i1["players"] as Array).size() == 2 and int(i1["money"]) == 27750 and int(i1["xp"]) == 1450
			and not i3.get("exists", true), "save slots: slot 1 = savegame.json (the old save), slot 3 = savegame_3.json; "
			+ "header %s" % [i1])
	FileAccess.open(p1 + ".info", FileAccess.WRITE).close()  # (an old save without a header: read from the file)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(p1 + ".info"))
	var again: Dictionary = SaveManager.slot_info(1)
	report.call(again.get("exists", false) and int(again.get("money", 0)) == 27750 and FileAccess.file_exists(p1 + ".info"),
			"a save without a header (made before the slots) is read once and gets one")
	var pt0: float = float(GameState.world.get("play_time", 0.0))
	await tree.create_timer(1.0).timeout
	var pt1: float = float(GameState.world.get("play_time", 0.0))
	report.call(pt1 - pt0 > 0.7 and pt1 - pt0 < 1.5, "play time counts while hosting (+%.2f s in 1 s)" % (pt1 - pt0))

	# The title page (in the demo folder).
	SaveManager.slot = 1
	var layer := CanvasLayer.new()
	world.add_child(layer)
	var menu: Control = (load("res://scenes/main_menu/main_menu.tscn") as PackedScene).instantiate()
	layer.add_child(menu)
	await tree.process_frame
	menu.call("_show_page", "slots")
	await tree.process_frame
	var slots: Node = menu.find_child("Slots", true, false)
	var names: PackedStringArray = []
	for n: String in ["Continue1", "New1", "Delete1", "Continue2", "Delete2", "New3"]:
		if slots.find_child(n, true, false) == null:
			names.append(n)
	report.call(names.is_empty() and slots.find_child("Continue3", true, false) == null and menu.find_child("PlayButton", true, false)
			and menu.find_child("JoinButton", true, false) and menu.find_child("SettingsButton", true, false),
			"title page: Play / Join / Settings / Quit, cards for 3 slots (full: Continue/New/Delete, empty: New)%s"
			% ("" if names.is_empty() else " missing " + ", ".join(names)))
	var del: Button = slots.find_child("Delete2", true, false)
	del.pressed.emit()
	var still: bool = FileAccess.file_exists(SaveManager.slot_path(2))
	var asked: String = del.text
	del.pressed.emit()
	await tree.process_frame
	var gone: bool = not FileAccess.file_exists(SaveManager.slot_path(2)) and FileAccess.file_exists(SaveManager.slot_path(2) + ".bak")
	report.call(still and asked == "Sure?" and gone, "Delete asks 'Sure?' first (%s), the second press moves the save to .bak (%s)"
			% [asked, gone])
	layer.queue_free()

	SaveManager.slot_dir = old["dir"]
	SaveManager.slot = old["slot"]
	SaveManager.set("_normal_path", old["normal"])
	SaveManager.save_path = old["path"]
	SaveManager.enabled = old["enabled"]
	for f: String in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR.path_join(f)))

	# Loading screen.
	var loading: Node = tree.root.get_node("Loading")
	var tips: Array = loading.get("TIPS")
	var pics: int = 0
	for b: String in loading.get("BACKGROUNDS"):
		if load(b) is Texture2D:
			pics += 1
	report.call(tips.size() >= 10 and pics == (loading.get("BACKGROUNDS") as Array).size(),
			"loading screen: %d tips, %d background pictures" % [tips.size(), pics])

	# Pause menu.
	var pm := world.get_node_or_null(^"PauseMenu") as PauseMenu
	var panel_hidden: bool = not (world.get_node(^"HUD/Panel") as Control).visible
	var paused: bool = false
	var closed: bool = false
	if pm:
		pm.open()
		await tree.process_frame
		paused = tree.paused and pm.is_open and pm.solo()
		var esc := InputEventAction.new()
		esc.action = &"release_mouse"
		esc.pressed = true
		pm._input(esc)
		closed = not pm.is_open and not tree.paused
	tree.paused = false
	report.call(pm != null and panel_hidden and paused and closed,
			"pause menu: the old top-left panel is hidden, alone the game pauses (%s), Esc resumes (%s)" % [paused, closed])
