extends Node
## Headless map checks. Start with:
##   --headless --path . -- --selftest --port=7791
## 1. Lamps: every light in group "street_lights" belongs to a pole prefab that
##    stands on the ground (no floating lamps).
## 2. Doors: opens every NetDoor, then a real walk body (walk_viewer.tscn, same
##    movement code as the player) walks from the street to 2.5 m inside.
##    Also checks that the navigation mesh has a path through the door.
## 3. Debug labels (group "debug_only") are hidden in game.
## Prints "[SelfTest] PASS/FAIL ..." lines and quits.

const WALKER: PackedScene = preload("res://scenes/world/walk_viewer.tscn")
const LAMP_PREFABS: Array[String] = ["street_lamp.tscn", "floodlight_pole.tscn"]

var _fails: int = 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var world: Node3D = get_parent()
	await _wait_for_navmesh(world)
	_check_lamps(world)
	_check_debug_labels()
	await _check_doors(world)
	print("[SelfTest] Done: %s" % ("ALL PASSED" if _fails == 0 else "%d FAILED" % _fails))
	Net.leave_game()
	get_tree().quit(1 if _fails > 0 else 0)


func _report(ok: bool, text: String) -> void:
	print("[SelfTest] %s %s" % ["PASS" if ok else "FAIL", text])
	if not ok:
		_fails += 1


func _wait_for_navmesh(world: Node3D) -> void:
	var region: NavigationRegion3D = world.get_node("NavRegion")
	var map: RID = region.get_navigation_map()
	for i: int in 600:
		if NavigationServer3D.map_get_iteration_id(map) > 0 and region.navigation_mesh.get_polygon_count() > 0:
			break
		await get_tree().physics_frame
	for i: int in 10:
		await get_tree().physics_frame


# --- Lamps -----------------------------------------------------------------------

func _check_lamps(world: Node3D) -> void:
	var space := world.get_world_3d().direct_space_state
	var count: int = 0
	for light: Node in get_tree().get_nodes_in_group("street_lights"):
		count += 1
		var root: Node3D = light.get_parent() as Node3D
		var prefab: String = root.scene_file_path.get_file() if root else ""
		if not prefab in LAMP_PREFABS:
			_report(false, "lamp %s is not in a pole prefab (%s)" % [light.get_path(), prefab])
			continue
		# Pole foot must touch the ground: ray down from 0.5 m above the origin.
		var from: Vector3 = root.global_position + Vector3.UP * 0.5
		var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 1.0, 1)
		q.exclude = [(root as CollisionObject3D).get_rid()] if root is CollisionObject3D else []
		var hit: Dictionary = space.intersect_ray(q)
		var gap: float = (from.y - 0.5 - (hit["position"] as Vector3).y) if not hit.is_empty() else INF
		if absf(gap) > 0.05:
			_report(false, "lamp %s at %s floats %.2f m above the ground" % [root.name, root.global_position, gap])
	_report(true, "checked %d lamps" % count)


# --- Debug labels ------------------------------------------------------------------

func _check_debug_labels() -> void:
	var shown: int = 0
	var nodes: Array[Node] = get_tree().get_nodes_in_group("debug_only")
	for n: Node in nodes:
		if (n as Node3D).is_visible_in_tree():
			shown += 1
			_report(false, "debug label visible in game: %s" % n.get_path())
	_report(shown == 0 and not nodes.is_empty(), "%d debug labels hidden in game" % nodes.size())


# --- Doors -----------------------------------------------------------------------

func _check_doors(world: Node3D) -> void:
	var doors: Array[Node] = world.find_children("*", "NetDoor", true, false)
	_report(not doors.is_empty(), "found %d doors" % doors.size())
	var map: RID = (world.get_node("NavRegion") as NavigationRegion3D).get_navigation_map()
	for d: Node in doors:
		var door := d as NetDoor
		var building: String = door.get_parent().name
		door._set_open(true)
		await get_tree().create_timer(0.7).timeout

		var out: Vector3 = door.global_basis.z.normalized()
		var center: Vector3 = door.global_position + door.global_basis.x.normalized() * door.width / 2.0
		center.y = door.global_position.y
		var start: Vector3 = center + out * 1.6
		var inside: Vector3 = center - out * 2.5

		var walker: CharacterBody3D = WALKER.instantiate()
		walker.set("auto_walk", true)
		walker.set("auto_target", inside)
		world.add_child(walker)
		walker.global_position = start + Vector3.UP * 0.1
		var ok: bool = false
		for i: int in 360:  # 6 s
			await get_tree().physics_frame
			var p: Vector3 = walker.global_position
			if Vector2(p.x - inside.x, p.z - inside.z).length() < 0.4:
				ok = true
				break
		var end: Vector3 = walker.global_position
		walker.queue_free()
		_report(ok, "walk through %s/%s (ended %.1f m from target)" % [building, door.name,
				Vector2(end.x - inside.x, end.z - inside.z).length()])

		var path: PackedVector3Array = NavigationServer3D.map_get_path(map, start, inside, true)
		var reached: bool = not path.is_empty() and path[path.size() - 1].distance_to(inside) < 0.6
		var detour: float = 0.0
		for i: int in range(1, path.size()):
			detour += path[i].distance_to(path[i - 1])
		# A path that goes in through the door is about 4 m long, not a detour.
		_report(reached and detour < 6.0, "navmesh through %s/%s (path %.1f m)" % [building, door.name, detour])

		door._set_open(false)
		await get_tree().create_timer(0.6).timeout
		# Closed door must block.
		walker = WALKER.instantiate()
		walker.set("auto_walk", true)
		walker.set("auto_target", inside)
		world.add_child(walker)
		walker.global_position = start + Vector3.UP * 0.1
		for i: int in 180:
			await get_tree().physics_frame
		var p2: Vector3 = walker.global_position
		walker.queue_free()
		_report((p2 - center).dot(out) > 0.0, "closed %s/%s blocks the walker" % [building, door.name])
