extends Node3D
## Test map (milestone 1), built from prefabs in res://prefabs/. Bakes the
## navigation mesh at startup so it always matches the geometry, provides spawn
## points / markers, and syncs networked props (doors) to late joiners.

const PLAYER: PackedScene = preload("res://scenes/player/player.tscn")
const LOOT_BAG: PackedScene = preload("res://prefabs/props/loot_bag.tscn")
const PEDESTRIAN: PackedScene = preload("res://prefabs/npc/pedestrian.tscn")
const PEDESTRIAN_COUNT: int = 10

@onready var nav_region: NavigationRegion3D = $NavRegion
@onready var spawn_points: Node3D = $Markers/SpawnPoints
@onready var npcs: Node3D = $NPCs
@onready var players_root: Node3D = $Players
@onready var player_spawner: MultiplayerSpawner = $PlayerSpawner
@onready var loot_root: Node3D = $Loot
@onready var loot_spawner: MultiplayerSpawner = $LootSpawner
@onready var players_label: Label = %PlayersLabel
@onready var info_label: Label = %InfoLabel
@onready var leave_button: Button = %LeaveButton


func _enter_tree() -> void:
	# Before the children's _ready: stations register their state in GameState.world.
	if multiplayer.is_server() and GameState.world.is_empty():
		GameState.init_new_world()


func _ready() -> void:
	Net.players_changed.connect(_refresh_players)
	# Every peer builds player nodes with the same function (spawn data from the host).
	player_spawner.spawn_function = _create_player
	loot_spawner.spawn_function = _create_loot_bag
	leave_button.pressed.connect(_on_leave_pressed)

	# Only the host runs NPC AI; clients skip the (slow) bake, which would also
	# stall their connection right after joining.
	if multiplayer.is_server():
		nav_region.bake_finished.connect(_on_nav_baked)
		nav_region.bake_navigation_mesh(false)  # false = bake right now, not on a thread

	var role: String = "HOST" if Net.is_host() else "CLIENT (peer %d)" % multiplayer.get_unique_id()
	info_label.text = "You are the %s" % role
	_refresh_players()

	_set_debug_visible(false)
	if "--screenshot" in OS.get_cmdline_user_args():
		_start_screenshot_tour()
	elif "--vmpreview" in OS.get_cmdline_user_args():
		$HUD/Panel.visible = false
		add_child(preload("res://scripts/debug/viewmodel_preview.gd").new())
	elif "--selftest" in OS.get_cmdline_user_args():
		add_child(preload("res://scripts/debug/self_test.gd").new())

	if not multiplayer.is_server():
		_request_snapshot.rpc_id(1)
	if not ("--screenshot" in OS.get_cmdline_user_args() or "--selftest" in OS.get_cmdline_user_args()
			or "--vmpreview" in OS.get_cmdline_user_args()):
		if multiplayer.is_server():
			Net.players_changed.connect(_remove_left_players)
			_spawn_player_for(1)
		else:
			_ask_for_body()  # the world is loaded here: ask the host for a body
	if "--netcheck" in OS.get_cmdline_user_args():
		_net_check()


## Debug (--netcheck): after 12 s print what this peer sees of the synced NPCs, then quit.
## Client: tell the host our world is loaded, again every 2 s until our player
## exists (the first message can get lost when either side is busy loading).
func _ask_for_body() -> void:
	var me: String = str(multiplayer.get_unique_id())
	for attempt: int in 30:
		if not is_inside_tree() or players_root.has_node(me) or not Net.is_online():
			return
		_client_world_ready.rpc_id(1)
		await get_tree().create_timer(2.0).timeout


func _net_check() -> void:
	if not multiplayer.is_server():
		await get_tree().create_timer(4.0).timeout
		var me: Player = players_root.get_node_or_null(str(multiplayer.get_unique_id()))
		var host: Player = players_root.get_node_or_null("1")
		# Combat: shoot the host until it dies, then take its loot bag.
		if me and host:
			for i: int in 6:
				if host.dead:
					break
				var target: Vector3 = host.global_position + Vector3(0, 1.2, 0)
				var d: Vector3 = target - me.head.global_position
				me.rotation.y = atan2(-d.x, -d.z)
				me.head.rotation.x = asin(d.normalized().y)
				me.combat.try_fire()
				print("[NetCheck] client fired (mag %d) host health %d" % [me.combat.mag, host.health])
				await get_tree().create_timer(0.4).timeout
			await get_tree().create_timer(0.5).timeout
			print("[NetCheck] client sees host dead=%s health=%d, bags: %d" % [host.dead, host.health, $Loot.get_child_count()])
			var cash_before: int = me.cash
			for bag: Node in $Loot.get_children():
				(bag as LootBag).interact()
			await get_tree().create_timer(1.0).timeout
			print("[NetCheck] client cash %d -> %d, bags left: %d" % [cash_before, me.cash, $Loot.get_child_count()])
			await get_tree().create_timer(4.0).timeout
			print("[NetCheck] client sees host after respawn: dead=%s health=%d at %s" % [host.dead, host.health,
					host.global_position.snapped(Vector3.ONE * 0.1)])
			me.head.rotation.x = 0.0
			# Shop RPC round trip: from out here the clerk must refuse ("walked away").
			var clerk: Shopkeeper = null
			for n: Node in find_children("Clerk", "Node3D", true, false):
				clerk = n as Shopkeeper
			if clerk:
				clerk.buy_result.connect(func(ok: bool, msg: String) -> void:
					print("[NetCheck] client buy answer: ok=%s '%s' (inventory %s)" % [ok, msg, me.inventory]))
				clerk.request_buy(&"soil", 1)
		# The client walks its own player 5 m east, crouched; the host must see that.
		if me:
			me.auto_walk = true
			me.auto_target = me.global_position + Vector3(5, 0, 0)
			Input.action_press("crouch")
			print("[NetCheck] client walks from %s" % me.global_position.snapped(Vector3.ONE * 0.1))
		await get_tree().create_timer(6.0).timeout
	else:
		# A growing plant in the starter room: the client must see it (snapshot / sync).
		var pot := find_child("Pot1", true, false) as GrowPot
		pot.state.merge({"stage": GrowPot.Stage.GROWING, "growth": 0.3, "water": 1.0, "seed": 5}, true)
		pot.changed()
		for i: int in 12:  # the host reports what it sees of the client players
			await get_tree().create_timer(3.0).timeout
			for p: Node in players_root.get_children():
				var pl := p as Player
				if not pl.is_local():
					print("[NetCheck] host sees client %s at %s crouch=%s" % [pl.player_name,
							pl.global_position.snapped(Vector3.ONE * 0.1), pl.net_crouch])
	var pot1 := find_child("Pot1", true, false) as GrowPot
	print("[NetCheck] %s sees Pot1: %s (plant visible=%s)" % ["host" if multiplayer.is_server() else "client",
			pot1.status_text(), pot1._plant.visible])
	var parts: PackedStringArray = []
	for npc: Node in npcs.get_children().slice(0, 3):
		parts.append("%s@%s anim=%d" % [npc.name, (npc as Node3D).global_position.snapped(Vector3.ONE * 0.1), npc.get("anim_state")])
	print("[NetCheck] %s sees %d NPCs: %s" % ["host" if multiplayer.is_server() else "client", npcs.get_child_count(), ", ".join(parts)])
	var cars: PackedStringArray = []
	for car: Node in get_tree().get_nodes_in_group(&"cars").slice(0, 3):
		cars.append("%s@%s v=%.1f" % [car.name, (car as Node3D).global_position.snapped(Vector3.ONE * 0.1), car.get("net_speed")])
	var deals: PackedStringArray = []
	for c: Node in get_tree().get_nodes_in_group(&"customer"):
		deals.append("%s wants %d for €%d (€ visible=%s)" % [c.name, c.get("wants"), c.get("offer"), c.get("_deal_label").visible])
	print("[NetCheck] %s sees customers: %s" % ["host" if multiplayer.is_server() else "client", ", ".join(deals)])
	for p: Node in players_root.get_children():
		if (p as Player).is_local():
			print("[NetCheck] %s last phone message: %s" % ["host" if multiplayer.is_server() else "client", (p as Player).last_phone])
	print("[NetCheck] %s sees %d cars: %s" % ["host" if multiplayer.is_server() else "client",
			get_tree().get_nodes_in_group(&"cars").size(), ", ".join(cars)])
	for p: Node in players_root.get_children():
		var pl := p as Player
		print("[NetCheck]   player %s '%s' at %s local=%s crouch=%s move=%s" % [pl.name, pl.player_name,
				pl.global_position.snapped(Vector3.ONE * 0.1), pl.is_local(), pl.net_crouch, pl.net_move])
	await get_tree().create_timer(1.0).timeout
	Net.leave_game()
	get_tree().quit()


# --- Players ---------------------------------------------------------------------

## Client -> host: my world is loaded. The host starts sending it the existing
## players/NPCs and spawns its player.
@rpc("any_peer", "call_remote", "reliable")
func _client_world_ready() -> void:
	if not multiplayer.is_server():
		return
	var peer: int = multiplayer.get_remote_sender_id()
	Net.mark_peer_in_world(peer)
	_spawn_player_for(peer)


## Host only: spawns the player of a peer at a free spawn point (replicated by PlayerSpawner).
func _spawn_player_for(peer: int) -> void:
	if not Net.players.has(peer) or players_root.has_node(str(peer)):
		return
	var used_models: Array[int] = []
	for p: Node in players_root.get_children():
		used_models.append((p as Player).model_index)
	var model: int = 0
	while model in used_models:
		model += 1
	var spawn: Node3D = spawn_points.get_child(players_root.get_child_count() % spawn_points.get_child_count())
	player_spawner.spawn({"peer": peer, "name": Net.get_player_name(peer), "model": model,
			"pos": spawn.global_position, "yaw": spawn.global_rotation.y})


func _create_player(data: Dictionary) -> Node:
	var p: Player = PLAYER.instantiate()
	p.name = str(data["peer"])
	p.peer_id = data["peer"]
	p.player_name = data["name"]
	p.model_index = data["model"]
	p.position = data["pos"]
	p.rotation.y = data["yaw"]
	p.net_pos = data["pos"]
	p.net_yaw = data["yaw"]
	return p


# --- Loot bags --------------------------------------------------------------------

var _loot_counter: int = 0


## Host only: drops a bag with cash + items on the ground below `pos` (replicated by LootSpawner).
func spawn_loot_bag(pos: Vector3, owner_name: String, cash: int, items: Array) -> void:
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 0.5, pos + Vector3.DOWN * 20.0, 1)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	var ground: Vector3 = hit["position"] if not hit.is_empty() else pos
	_loot_counter += 1
	loot_spawner.spawn({"id": _loot_counter, "pos": ground, "yaw": randf() * TAU,
			"owner": owner_name, "cash": cash, "items": items})
	print("[World] Loot bag of %s dropped at %s (€%d)" % [owner_name, ground.snapped(Vector3.ONE * 0.1), cash])


func _create_loot_bag(data: Dictionary) -> Node:
	var bag: LootBag = LOOT_BAG.instantiate()
	bag.name = "Bag%d" % data["id"]
	bag.position = data["pos"]
	bag.rotation.y = data["yaw"]
	bag.owner_name = data["owner"]
	bag.cash = data["cash"]
	bag.items = data["items"]
	return bag


## Host only: remove the bodies of players that left (the spawner despawns them on clients).
func _remove_left_players() -> void:
	for p: Node in players_root.get_children():
		if not Net.players.has((p as Player).peer_id):
			p.queue_free()


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


## Spawn point near the hospital with nobody standing on it (random order).
func get_free_spawn_point() -> Vector3:
	var points: Array[Node] = spawn_points.get_children()
	points.shuffle()
	for pt: Node in points:
		var pos: Vector3 = (pt as Node3D).global_position
		var free: bool = true
		for p: Node in players_root.get_children():
			if (p as Node3D).global_position.distance_to(pos) < 1.5:
				free = false
		if free:
			return pos
	return (points[0] as Node3D).global_position


## Returns a spawn position near the hospital (index wraps around).
func get_spawn_point(index: int) -> Vector3:
	var points: Array[Node] = spawn_points.get_children()
	return (points[index % points.size()] as Node3D).global_position


func _on_nav_baked() -> void:
	var polygons: int = nav_region.navigation_mesh.get_polygon_count()
	print("[World] Navigation mesh baked: %d polygons" % polygons)
	_after_navmesh.call_deferred()


func _after_navmesh() -> void:
	if not multiplayer.is_server():
		return  # clients have no navmesh (see _ready)
	# The navigation server applies the new mesh asynchronously (region first,
	# then the map), so wait until the map actually contains it.
	var map: RID = nav_region.get_navigation_map()
	var start: Vector3 = get_marker("CustomerSpawn").global_position
	for i: int in 300:
		if NavigationServer3D.map_get_iteration_id(map) > 0 \
				and NavigationServer3D.map_get_closest_point(map, start).distance_to(start) < 2.0:
			break
		await get_tree().physics_frame
	_debug_check_paths()
	# The self-test spawns them itself, after its door checks.
	if multiplayer.is_server() and not "--selftest" in OS.get_cmdline_user_args():
		var count: int = PEDESTRIAN_COUNT
		for arg: String in OS.get_cmdline_user_args():
			if arg.begins_with("--npcs="):
				count = arg.trim_prefix("--npcs=").to_int()
		spawn_pedestrians(count)
		_customer_loop()


## Host only: ambient pedestrians on random sidewalk spots (synced by NPCSpawner).
func spawn_pedestrians(count: int) -> void:
	var player_spawn: Vector3 = (spawn_points.get_child(0) as Node3D).global_position
	for i: int in count:
		var p: Vector3 = Vector3.INF
		for attempt: int in 10:
			p = Pedestrian.random_sidewalk_point(self)
			if p != Vector3.INF and p.distance_to(player_spawn) > 6.0:
				break
		if p == Vector3.INF:
			continue
		_add_pedestrian(p, i % Pedestrian.VARIANTS.size())


func _add_pedestrian(p: Vector3, variant: int) -> Pedestrian:
	var npc: Pedestrian = PEDESTRIAN.instantiate()
	npc.variant = variant
	npc.color_seed = randi()
	npc.position = p
	npc.rotation.y = randf() * TAU
	npcs.add_child(npc, true)
	return npc


# --- Phone (step 8) ----------------------------------------------------------------

const PLACE_NAMES: Dictionary = {
	"StarterRoom": "your Starter Room", "Store": "the Store", "Hospital": "the hospital",
	"GunShop": "Vince's gun shop", "ContactHideout": "Dries' place", "Warehouse": "the warehouse",
}


## Host: a phone message to every player.
func phone_all(contact: String, text: String, deal: String = "") -> void:
	for p: Node in players_root.get_children():
		(p as Player).phone_message(contact, text, deal)


## "near the Store" / "on Main Road": roughly where `pos` is, for texts.
func describe_location(pos: Vector3) -> String:
	var best: String = ""
	var best_d: float = 22.0
	for key: String in PLACE_NAMES:
		var n := find_child(key, true, false) as Node3D
		if n and n.global_position.distance_to(pos) < best_d:
			best_d = n.global_position.distance_to(pos)
			best = "near " + PLACE_NAMES[key]
	if best != "":
		return best
	if absf(pos.z) < 9.0:
		return "on Main Road"
	if absf(pos.x - 30.0) < 9.0:
		return "on Station Road"
	if absf(pos.z + 48.0) < 9.0:
		return "on the north road"
	if absf(pos.x + 6.0) < 9.0:
		return "on the side street"
	return "around the block (check the map)"


# --- Customers (step 7) ------------------------------------------------------------

const CUSTOMER_INTERVAL: float = 35.0  # s between new customers (randomised)
const MAX_CUSTOMERS: int = 2
const CUSTOMER_TIME: float = 300.0  # s before a customer gives up


## Host: every now and then a pedestrian becomes a customer ("€" over its head).
func _customer_loop() -> void:
	await get_tree().create_timer(10.0).timeout
	while is_inside_tree():
		if get_tree().get_nodes_in_group(&"customer").size() < MAX_CUSTOMERS:
			make_customer()
		await get_tree().create_timer(CUSTOMER_INTERVAL * randf_range(0.6, 1.4)).timeout


## Host: turns `npc` (or a random free pedestrian) into a customer for 1-3 bags.
func make_customer(npc: Pedestrian = null) -> Pedestrian:
	if npc == null:
		var free: Array[Pedestrian] = []
		for n: Node in get_tree().get_nodes_in_group(&"npc"):
			var p := n as Pedestrian
			if p and not p.dead and p.wants == 0 and not p.is_fleeing():
				free.append(p)
		if free.is_empty():
			return null
		npc = free.pick_random()
	var bags: int = randi_range(1, 3)
	var item: ItemData = ItemDB.get_item(&"weed_bag")
	var price: int = roundi(bags * item.base_price * randf_range(0.85, 1.3))
	npc.become_customer(bags, price, CUSTOMER_TIME)
	print("[World] %s wants %d bags for €%d" % [npc.name, bags, price])
	return npc


## Host only: a pedestrian died -> after `delay` s a new one appears on a
## sidewalk, preferably out of every player's sight (> 25 m away).
func respawn_pedestrian_later(delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if not is_inside_tree() or not multiplayer.is_server():
		return
	var best: Vector3 = Vector3.INF
	var best_dist: float = -1.0
	for attempt: int in 12:
		var p: Vector3 = Pedestrian.random_sidewalk_point(self)
		if p == Vector3.INF:
			continue
		var nearest: float = INF
		for pl: Node in players_root.get_children():
			nearest = minf(nearest, (pl as Node3D).global_position.distance_to(p))
		if nearest > best_dist:
			best = p
			best_dist = nearest
		if nearest > 25.0:
			break
	if best != Vector3.INF:
		var npc := _add_pedestrian(best, randi() % Pedestrian.VARIANTS.size())
		print("[World] Pedestrian %s respawned at %s" % [npc.name, best.snapped(Vector3.ONE * 0.1)])


## Prints whether NPCs can path to the key spots (visible in the Output panel).
func _debug_check_paths() -> void:
	var map: RID = nav_region.get_navigation_map()
	var start: Vector3 = get_marker("CustomerSpawn").global_position
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
