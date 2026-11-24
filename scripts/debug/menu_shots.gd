extends Node
## `--menu-shots` (window, e.g. `--path . --position 4000,40 --resolution 1600x900 -- --menu-shots --port=7778`):
## screenshots of the title page, the save slots (demo slots, never the real saves), the join page and the loading
## screen into screenshots/menu_*.png, then quits once the world is up. The main menu hangs it on the root.

var menu: Control


func _ready() -> void:
	SaveManager.enabled = false
	SaveManager.slot_dir = DemoSlots.DIR
	DemoSlots.make()
	_run()


func _run() -> void:
	await _wait(2.0)
	_shot("menu_title")
	menu.call("_show_page", "slots")
	await _wait(0.6)
	_shot("menu_slots")
	menu.call("_show_page", "join")
	await _wait(0.6)
	_shot("menu_join")
	Settings.open_menu()
	await _wait(0.6)
	_shot("menu_settings")
	(Settings.get("_menu") as Node).call("close_menu")
	menu.call("_on_host_pressed", true)
	var loading: Node = get_tree().root.get_node("Loading")
	var tree: SceneTree = get_tree()
	await _wait(1.2)
	_shot("menu_loading")
	var t: float = 0.0
	while bool(loading.get("active")) and t < 150.0:
		await _wait(0.5)
		t += 0.5
	await _wait(1.5)
	(tree.current_scene.get_node("PauseMenu") as PauseMenu).open()
	await _wait(0.6)
	_shot("menu_pause")
	print("[MenuShots] done (loading screen up %.0f s)" % t)
	tree.paused = false
	tree.quit()


func _wait(s: float) -> void:
	await get_tree().create_timer(s, true).timeout


func _shot(n: String) -> void:
	var img: Image = get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))
	var path: String = ProjectSettings.globalize_path("res://screenshots/%s.png" % n)
	img.save_png(path)
	print("[MenuShots] saved %s" % path)
