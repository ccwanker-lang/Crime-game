extends Node3D
## Test map (milestone 1), built from prefabs in res://prefabs/. Bakes the
## navigation mesh at startup so it always matches the geometry, provides spawn
## points / markers, and syncs networked props (doors) to late joiners.

const WALK_VIEWER: PackedScene = preload("res://scenes/world/walk_viewer.tscn")

@onready var nav_region: NavigationRegion3D = $NavRegion
@onready var spawn_points: Node3D = $Markers/SpawnPoints
@onready var players_label: Label = %PlayersLabel
@onready var info_label: Label = %InfoLabel
@onready var leave_button: Button = %LeaveButton


func _ready() -> void:
	Net.players_changed.connect(_refresh_players)
	leave_button.pressed.connect(_on_leave_pressed)

	if multiplayer.is_server() and GameState.world.is_empty():
		GameState.init_new_world()

	nav_region.bake_finished.connect(_on_nav_baked)
	nav_region.bake_navigation_mesh(false)  # false = bake right now, not on a thread

	var role: String = "HOST" if Net.is_host() else "CLIENT (peer %d)" % multiplayer.get_unique_id()
	info_label.text = "You are the %s" % role
	_refresh_players()

	_set_debug_visible(false)
	if "--screenshot" in OS.get_cmdline_user_args():
		_start_screenshot_tour()
	elif "--selftest" in OS.get_cmdline_user_args():
		add_child(preload("res://scripts/debug/self_test.gd").new())
	else:
		_spawn_walk_viewer()

	if not multiplayer.is_server():
		_request_snapshot.rpc_id(1)


## TEMPORARY until step 3: a local first-person walker on the street.
func _spawn_walk_viewer() -> void:
	var viewer: Node3D = WALK_VIEWER.instantiate()
	var spawn: Node3D = spawn_points.get_child(maxi(0, Net.players.keys().find(multiplayer.get_unique_id())) % spawn_points.get_child_count())
	add_child(viewer)
	viewer.global_transform = spawn.global_transform


## F3 toggles debug helpers (marker labels like "MEET POINT", group "debug_only").
## They are always visible in the editor, hidden in game by default.
func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.physical_keycode == KEY_F3:
		_debug_visible = not _debug_visible
		_set_debug_visible(_debug_visible)


var _debug_visible: bool = false


func _set_debug_visible(on: bool) -> void:
	for n: Node in get_tree().get_nodes_in_group("debug_only"):
		(n as Node3D).visible = on


## Finds a marker anywhere in the map (markers can live inside building prefabs).
func get_marker(marker_name: String) -> Node3D:
	return find_child(marker_name, true, false) as Node3D


# --- Late join: networked props (group "net_state") -------------------------------

@rpc("any_peer", "call_remote", "reliable")
func _request_snapshot() -> void:
	if not multiplayer.is_server():
		return
	var data: Dictionary = {}
	for n: Node in get_tree().get_nodes_in_group("net_state"):
		data[str(get_path_to(n))] = n.call("get_net_state")
	_apply_snapshot.rpc_id(multiplayer.get_remote_sender_id(), data)


@rpc("authority", "call_remote", "reliable")
func _apply_snapshot(data: Dictionary) -> void:
	for path: String in data:
		var n: Node = get_node_or_null(path)
		if n and n.has_method("apply_net_state"):
			n.call("apply_net_state", data[path])


## Debug: take screenshots from fixed spots and quit (scripts/debug/screenshot_tour.gd).
func _start_screenshot_tour() -> void:
	var tour: Node = preload("res://scripts/debug/screenshot_tour.gd").new()
	tour.hide_nodes = [$HUD/Panel]
	add_child(tour)


## Returns a spawn position near the hospital (index wraps around).
func get_spawn_point(index: int) -> Vector3:
	var points: Array[Node] = spawn_points.get_children()
	return (points[index % points.size()] as Node3D).global_position


func _on_nav_baked() -> void:
	var polygons: int = nav_region.navigation_mesh.get_polygon_count()
	print("[World] Navigation mesh baked: %d polygons" % polygons)
	_debug_check_paths.call_deferred()


## Prints whether NPCs can path to the key spots (visible in the Output panel).
func _debug_check_paths() -> void:
	# The navigation server applies the new mesh asynchronously (region first,
	# then the map), so wait until the map actually contains it.
	var map: RID = nav_region.get_navigation_map()
	var start: Vector3 = get_marker("CustomerSpawn").global_position
	for i: int in 300:
		if NavigationServer3D.map_get_iteration_id(map) > 0 \
				and NavigationServer3D.map_get_closest_point(map, start).distance_to(start) < 2.0:
			break
		await get_tree().physics_frame
	for target_name: String in ["CustomerMeetPoint", "ContactSpot", "StoreSpot", "PotSpot", "P3"]:
		var target: Vector3 = get_marker(target_name).global_position
		var path: PackedVector3Array = NavigationServer3D.map_get_path(map, start, target, true)
		var reached: bool = not path.is_empty() and path[path.size() - 1].distance_to(target) < 1.0
		print("[World] Path CustomerSpawn -> %s: %s" % [target_name, "OK" if reached else "NOT REACHABLE"])

func _refresh_players() -> void:
	var lines: PackedStringArray = ["Players (%d/%d):" % [Net.players.size(), Net.MAX_PLAYERS]]
	for peer_id: int in Net.players:
		var tag: String = " (host)" if peer_id == 1 else ""
		var me: String = "  <- you" if peer_id == multiplayer.get_unique_id() else ""
		lines.append("  - %s%s%s" % [Net.get_player_name(peer_id), tag, me])
	players_label.text = "\n".join(lines)


func _on_leave_pressed() -> void:
	Net.leave_game()
	get_tree().change_scene_to_file(Net.MAIN_MENU_SCENE)
