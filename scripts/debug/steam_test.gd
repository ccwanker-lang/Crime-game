class_name SteamTest
extends RefCounted
## Self-test check "steam" (SelfTest._check_steam), session B user list item 4. Without touching Steam itself (tests
## never start it): the extension loads, test runs stay off Steam and host by IP, Net works with any peer, the title
## page / pause menu show the Steam parts only where they belong. The live part: `-- --steam-check` (see SteamNet).


static func run(t: Node, world: Node3D) -> void:
	var tree: SceneTree = t.get_tree()
	var report := func(ok: bool, text: String) -> void: t.call("_report", ok, text)
	var sn: Node = tree.root.get_node("SteamNet")
	report.call(sn.call("available") and ClassDB.class_exists("SteamMultiplayerPeer"),
			"GodotSteam loads: Steam singleton + SteamMultiplayerPeer")
	report.call(sn.call("test_run") and not sn.get("started") and not sn.call("should_host"),
			"test runs never start Steam and host by IP (started %s)" % sn.get("started"))
	report.call(Net.is_online() and Net.transport == "ip" and multiplayer_peer_is_enet(tree),
			"Net: hosting by IP still works (transport %s, is_online %s)" % [Net.transport, Net.is_online()])

	var layer := CanvasLayer.new()
	world.add_child(layer)
	var menu: Control = (load("res://scenes/main_menu/main_menu.tscn") as PackedScene).instantiate()
	layer.add_child(menu)
	await tree.process_frame
	menu.call("_show_page", "slots")
	await tree.process_frame
	var check := menu.find_child("SteamHost", true, false) as CheckBox
	var games := menu.find_child("SteamGames", true, false)
	var refresh := menu.find_child("SteamRefresh", true, false)
	report.call(check != null and games != null and refresh != null and menu.find_child("IpEdit", true, false) != null,
			"title page: 'Friends can join via Steam' on Play, 'Friends' games (Steam)' + the IP form on Join (%s %s %s)" % [check != null, games != null, refresh != null])
	layer.queue_free()

	var pm := world.get_node_or_null(^"PauseMenu") as PauseMenu
	var invite := pm.find_child("Invite", true, false) as Button if pm else null
	if pm:
		pm.open()
		await tree.process_frame
	var hidden: bool = invite != null and not invite.visible
	if pm:
		pm.close()
	tree.paused = false
	report.call(hidden, "pause menu: 'Invite friends (Steam)' only in a Steam game (hidden now: %s)" % hidden)


static func multiplayer_peer_is_enet(tree: SceneTree) -> bool:
	return tree.get_multiplayer().multiplayer_peer is ENetMultiplayerPeer
