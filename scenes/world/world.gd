extends Node3D
## Greybox test map (milestone 1). Bakes the navigation mesh at startup so it
## always matches the geometry, and provides spawn points / markers for later steps.

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

	if "--screenshot" in OS.get_cmdline_user_args():
		_start_screenshot_tour()


## Debug: take screenshots from fixed spots and quit (scripts/debug/screenshot_tour.gd).
func _start_screenshot_tour() -> void:
	var tour: Node = preload("res://scripts/debug/screenshot_tour.gd").new()
	tour.camera = $DebugFlyCamera
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
	var start: Vector3 = ($Markers/CustomerSpawn as Node3D).global_position
	for i: int in 300:
		if NavigationServer3D.map_get_iteration_id(map) > 0 \
				and NavigationServer3D.map_get_closest_point(map, start).distance_to(start) < 2.0:
			break
		await get_tree().physics_frame
	for target_name: String in ["CustomerMeetPoint", "ContactSpot", "StoreSpot", "PotSpot", "RivalPatrol/P3"]:
		var target: Vector3 = (get_node("Markers/" + target_name) as Node3D).global_position
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
