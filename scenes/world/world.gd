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
@onready var placed_root: Node3D = $Placed
@onready var placed_spawner: MultiplayerSpawner = $PlacedSpawner
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
	placed_spawner.spawn_function = _create_placed
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
	add_child(ScenarioMenu.new())  # F9
	if "--screenshot" in OS.get_cmdline_user_args():
		_start_screenshot_tour()
	elif "--vmpreview" in OS.get_cmdline_user_args():
		$HUD/Panel.visible = false
		add_child(preload("res://scripts/debug/viewmodel_preview.gd").new())
	elif "--selftest" in OS.get_cmdline_user_args():
		add_child(preload("res://scripts/debug/self_test.gd").new())

	if not multiplayer.is_server():
		_request_snapshot.rpc_id(1)
	else:
		migrate_layout()  # (before the host's player spawns at its saved spot)
		_restore_from_save.call_deferred()
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
			me.combat.select_slot(1)  # the 9mm rounds in the free hand: the host must see them
			me.auto_walk = true
			me.auto_target = me.global_position + Vector3(5, 0, 0)
			Input.action_press("crouch")
			print("[NetCheck] client walks from %s" % me.global_position.snapped(Vector3.ONE * 0.1))
		await get_tree().create_timer(6.0).timeout
		if me:
			# Placement RPC round trip: placing on the street must be refused by the host.
			me.request_place("grow_pot", me.global_position, 0.0)
			await get_tree().create_timer(1.0).timeout
			print("[NetCheck] client place on the street -> '%s'" % me.last_message)
	else:
		# A growing plant in the starter room: the client must see it (snapshot / sync).
		var pot := host_place("grow_pot", get_marker("Pot1Spot").global_position, 0.0) as GrowPot
		pot.state.merge({"stage": GrowPot.Stage.GROWING, "growth": 0.3, "water": 1.0, "seed": 5}, true)
		pot.changed()
		# Point 9: dirty cash waiting in the bakery safe (the client must see it).
		var safe := find_child("Bakery", true, false).get_node("Safe") as LaunderSafe
		safe.state["queue"] = {"Nobody": 1234}
		safe.changed()
		# Point 11: a Crow standing in its yard (far from the players): the client must see it.
		Rival.obey_daylight = false
		var crow: Rival = add_rival()
		# Start the timeline once a client's world is loaded (slow under load), max 90 s.
		for i: int in 180:
			if not Net.peers_in_world.is_empty():
				break
			await get_tree().create_timer(0.5).timeout
		for i: int in 12:  # the host reports what it sees of the client players
			await get_tree().create_timer(3.0).timeout
			for p: Node in players_root.get_children():
				var pl := p as Player
				if not pl.is_local() and i == 1:
					GameState.add_clean(pl.player_name, 250)  # laundered money reaches the owner's wallet
					pl.send_wallet()
				if not pl.is_local():
					print("[NetCheck] host sees client %s at %s crouch=%s weapon=%d held='%s' (model %s)" % [pl.player_name,
							pl.global_position.snapped(Vector3.ONE * 0.1), pl.net_crouch, pl.net_weapon, pl.net_held,
							pl.get_node_or_null("HeldItem") != null])
	var pot1: GrowPot = null
	for n: Node in placed_root.get_children():
		if n is GrowPot:
			pot1 = n as GrowPot
	print("[NetCheck] %s sees placed pot: %s (plant visible=%s), %d placed things" % ["host" if multiplayer.is_server() else "client",
			pot1.status_text() if pot1 else "NONE", pot1._plant.visible if pot1 else false, placed_root.get_child_count()])
	var sr := find_child("StarterRoom", true, false).get_node("Property") as Property
	print("[NetCheck] %s sees %d static starter room furniture (0 = adopted)" % ["host" if multiplayer.is_server() else "client",
			sr.static_furniture().size()])
	var bsafe := find_child("Bakery", true, false).get_node("Safe") as LaunderSafe
	var mine: Player = players_root.get_node_or_null(str(multiplayer.get_unique_id())) as Player
	print("[NetCheck] %s sees the bakery safe with €%d, own clean money €%d" % ["host" if multiplayer.is_server() else "client",
			bsafe.queued_total(), mine.clean if mine else -1])
	var crows: Array = npcs.get_children().filter(func(n: Node) -> bool: return n is Rival)
	print("[NetCheck] %s sees %d Crow(s)%s" % ["host" if multiplayer.is_server() else "client", crows.size(),
			(" at %s, beanie %s" % [(crows[0] as Node3D).global_position.snapped(Vector3.ONE * 0.1),
			(crows[0] as Node).find_children("*", "BoneAttachment3D", true, false).size() > 0]) if not crows.is_empty() else ""])
	var sh := find_child("SmallHouse", true, false).get_node("Property") as Property
	print("[NetCheck] %s sees the Small House sign: %s" % ["host" if multiplayer.is_server() else "client",
			sh._label.text.replace("
", " / ")])
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
	var pos: Vector3 = spawn.global_position
	var yaw: float = spawn.global_rotation.y
	var player_name: String = Net.get_player_name(peer)
	var saved: Dictionary = GameState.player_data.get(player_name, {})
	if saved.get("pos") is Vector3:
		pos = saved["pos"]  # back where this player was when the game was saved / they left
		yaw = float(saved.get("yaw", yaw))
	player_spawner.spawn({"peer": peer, "name": player_name, "model": model, "pos": pos, "yaw": yaw})
	var p := players_root.get_node_or_null(str(peer)) as Player
	if saved.get("pos") is Vector3:
		print("[World] %s is back where they were saved: %s" % [player_name, pos.snapped(Vector3.ONE * 0.1)])
	if p and saved.has("health"):
		p.health = clampi(int(saved["health"]), 1, Player.MAX_HEALTH)
	if p and saved.get("mags") is Array:
		p.combat.host_set_mags(saved["mags"])


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
func spawn_loot_bag(pos: Vector3, owner_name: String, cash: int, items: Array, dropped: bool = false) -> void:
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 0.5, pos + Vector3.DOWN * 20.0, 1)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	var ground: Vector3 = hit["position"] if not hit.is_empty() else pos
	_loot_counter += 1
	loot_spawner.spawn({"id": _loot_counter, "pos": ground, "yaw": randf() * TAU,
			"owner": owner_name, "cash": cash, "items": items, "dropped": dropped})
	print("[World] Loot bag of %s dropped at %s (€%d)" % [owner_name, ground.snapped(Vector3.ONE * 0.1), cash])


func _create_loot_bag(data: Dictionary) -> Node:
	var bag: LootBag = LOOT_BAG.instantiate()
	bag.name = "Bag%d" % data["id"]
	bag.position = data["pos"]
	bag.rotation.y = data["yaw"]
	bag.owner_name = data["owner"]
	bag.cash = data["cash"]
	bag.items = data["items"]
	bag.dropped = bool(data.get("dropped", false))
	return bag


# --- Placed stations + furniture (point 6) ------------------------------------------

## Host: puts a placeable item (station / furniture) in the world and records it in
## GameState.world["placed"] (saved). No checks here (see Placement.check / Player._host_place).
func host_place(item_id: String, pos: Vector3, yaw: float, uid: String = "") -> Node:
	var placed: Dictionary = GameState.world.get_or_add("placed", {})
	if uid == "":
		var next: int = int(GameState.world.get("placed_next", 1))
		GameState.world["placed_next"] = next + 1
		uid = str(next)
	placed[uid] = {"item": item_id, "pos": pos, "yaw": yaw}
	return placed_spawner.spawn({"uid": uid, "item": item_id, "pos": pos, "yaw": yaw})


## Every peer: builds a placed thing from the spawn data. Stations keep their state under
## "placed/<uid>" in GameState.world["stations"]; furniture gets a PlacedFurniture parent.
func _create_placed(data: Dictionary) -> Node:
	var uid: String = str(data["uid"])
	var item: ItemData = ItemDB.get_item(StringName(str(data["item"])))
	var inst: Node3D = item.place_scene.instantiate() as Node3D
	var node: Node3D = inst
	if inst is Station:
		(inst as Station).placed_uid = uid
		(inst as Station).station_id = "placed/" + uid
	else:
		var f := PlacedFurniture.new()
		f.placed_uid = uid
		f.item_id = str(data["item"])
		inst.name = "Model"
		f.add_child(inst)
		node = f
	node.name = "P" + uid
	node.position = data["pos"]
	node.rotation.y = data["yaw"]
	node.set_meta(&"placed_item", str(data["item"]))
	# An empty synchronizer only so the spawn waits until a joining client's world is loaded.
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	sync.replication_config = SceneReplicationConfig.new()
	node.add_child(sync)
	Net.limit_sync_to_world(sync)
	return node


func get_placed(uid: String) -> Node3D:
	return placed_root.get_node_or_null("P" + uid) as Node3D


## Host: removes a placed thing (the spawner removes it on the clients too) and its record.
func host_remove_placed(uid: String) -> void:
	(GameState.world.get("placed", {}) as Dictionary).erase(uid)
	(GameState.world.get("stations", {}) as Dictionary).erase("placed/" + uid)
	var n: Node = get_placed(uid)
	if n:
		placed_root.remove_child(n)
		n.queue_free()


## Before point 6 the weed stations stood in the Starter Room prefab. Old saves keep their
## state under these paths: they become placed stations at the same spots (marker in the prefab).
const OLD_STATIONS: Dictionary = {
	"NavRegion/StarterRoom/GrowLamp": ["grow_lamp", "LampSpot"],
	"NavRegion/StarterRoom/Pot1": ["grow_pot", "Pot1Spot"],
	"NavRegion/StarterRoom/Pot2": ["grow_pot", "Pot2Spot"],
	"NavRegion/StarterRoom/DryingRack": ["drying_rack", "RackSpot"],
	"NavRegion/StarterRoom/PackagingTable": ["packaging_table", "PackagingSpot"],
}


func _migrate_old_stations() -> void:
	var stations: Dictionary = GameState.world.get_or_add("stations", {})
	for old: String in OLD_STATIONS:
		if not stations.has(old):
			continue
		var spot: Node3D = get_marker(OLD_STATIONS[old][1])
		var st: Dictionary = stations[old]
		stations.erase(old)
		if spot == null:
			continue
		var n := host_place(OLD_STATIONS[old][0], spot.global_position, spot.global_rotation.y) as Station
		n.state.merge(st, true)
		n.changed()
		print("[World] Old save: %s is now a placed %s" % [old, OLD_STATIONS[old][0]])


## Debug/tests: places the classic weed corner of the Starter Room (2 pots, lamp, rack,
## packaging table) at its markers. Returns {"Pot1": GrowPot, "Pot2", "GrowLamp", "DryingRack", "PackagingTable"}.
func debug_weed_corner() -> Dictionary:
	var out: Dictionary = {}
	for old: String in OLD_STATIONS:
		var spot: Node3D = get_marker(OLD_STATIONS[old][1])
		out[old.get_file()] = host_place(OLD_STATIONS[old][0], spot.global_position, spot.global_rotation.y)
	return out


## Host only: remove the bodies of players that left (the spawner despawns them on clients).
func _remove_left_players() -> void:
	for p: Node in players_root.get_children():
		if not Net.players.has((p as Player).peer_id):
			_capture_player(p as Player)
			p.queue_free()


# --- Save / load (step 9) -------------------------------------------------------------

## Host (SaveManager, before writing): live data -> GameState.
func capture_for_save() -> void:
	for p: Node in players_root.get_children():
		_capture_player(p as Player)
	var dn := get_tree().get_first_node_in_group(&"day_night") as DayNight
	if dn:
		GameState.world["hours"] = dn.hours
	var bags: Array = []
	for bag: Node in loot_root.get_children():
		var b := bag as LootBag
		if b and not b.is_queued_for_deletion():
			bags.append({"pos": b.global_position, "owner": b.owner_name, "cash": b.cash, "items": b.items,
					"dropped": b.dropped})
	GameState.world["loot_bags"] = bags


## Host: a player's position, health and loaded magazines -> their save record.
func _capture_player(p: Player) -> void:
	if p == null or p.player_name == "" or not GameState.player_data.has(p.player_name):
		return
	var rec: Dictionary = GameState.player_data[p.player_name]
	if p.dead:
		rec.erase("pos")  # respawns normally
		rec["health"] = Player.MAX_HEALTH
	else:
		rec["pos"] = p.global_position + Vector3.UP * 0.05
		rec["yaw"] = p.rotation.y
		rec["health"] = p.health
	rec["mags"] = p.combat.host_mags()


## Point 26: the properties for sale moved from South Street into other neighbourhoods.
## Where their buildings stood before (front centre, facing south), per property_id.
const LAYOUT_VERSION: int = 2
const OLD_PROPERTY_SPOTS: Dictionary = {
	"small_house": Vector3(-37, 0, 54), "family_house": Vector3(-29.25, 0, 54),
	"barber": Vector3(-12.75, 0, 54), "laundromat": Vector3(-5.75, 0, 54)}


## Host: a save from before the move carries everything that was inside a moved building
## (placed stations/furniture, loot bags, players standing there) along to its new spot.
## Returns how many things moved.
func migrate_layout() -> int:
	var w: Dictionary = GameState.world
	if int(w.get("layout", 1)) >= LAYOUT_VERSION or not w.has("hours"):
		w["layout"] = LAYOUT_VERSION  # new game (or already moved)
		return 0
	var moved: int = 0
	for n: Node in get_tree().get_nodes_in_group(&"properties"):
		var prop := n as Property
		if prop == null or not OLD_PROPERTY_SPOTS.has(str(prop.property_id)) or prop.building() == null:
			continue
		var b: Building = prop.building()
		var old: Vector3 = OLD_PROPERTY_SPOTS[str(prop.property_id)]
		var carry := func(pos: Vector3) -> Variant:
			var local: Vector3 = pos - old
			if absf(local.x) < b.width * 0.5 and local.z < 0.3 and local.z > -b.depth \
					and local.y > -0.5 and local.y < b.get_height():
				return b.global_transform * local
			return null
		for rec: Dictionary in (w.get("placed", {}) as Dictionary).values():
			var to: Variant = carry.call(rec["pos"])
			if to != null:
				rec["pos"] = to
				rec["yaw"] = float(rec["yaw"]) + b.global_rotation.y
				moved += 1
		for bag: Dictionary in w.get("loot_bags", []):
			var to: Variant = carry.call(bag["pos"])
			if to != null:
				bag["pos"] = to
				moved += 1
		for rec: Dictionary in GameState.player_data.values():
			if rec.has("pos"):
				var to: Variant = carry.call(rec["pos"])
				if to != null:
					rec["pos"] = to
					rec["yaw"] = float(rec.get("yaw", 0.0)) + b.global_rotation.y
					moved += 1
	w["layout"] = LAYOUT_VERSION
	print("[World] Properties moved to their new neighbourhoods: %d things carried along" % moved)
	return moved


## Host, once the world is up: time of day and loot bags from the save.
func _restore_from_save() -> void:
	var dn := get_tree().get_first_node_in_group(&"day_night") as DayNight
	if dn and GameState.world.has("hours"):
		dn.set_hours(float(GameState.world["hours"]))
	for bag: Dictionary in GameState.world.get("loot_bags", []):
		spawn_loot_bag(bag["pos"], str(bag["owner"]), int(bag["cash"]), bag["items"], bool(bag.get("dropped", false)))
	GameState.world["loot_bags"] = []
	# Placed stations/furniture (point 6), stations from old saves, then furniture adoption (point 17).
	var placed: Dictionary = GameState.world.get_or_add("placed", {})
	for uid: String in placed.keys():
		var rec: Dictionary = placed[uid]
		var item: ItemData = ItemDB.get_item(StringName(str(rec.get("item", ""))))
		if item == null or item.place_scene == null:
			placed.erase(uid)
			continue
		if get_placed(uid) != null:
			continue  # already there (placed before the restore ran)
		host_place(str(rec["item"]), rec["pos"], float(rec["yaw"]), uid)
	_migrate_old_stations()
	if not GameState.world.get("free_locker", false):
		var spot: Node3D = get_marker("LockerSpot")
		if spot:
			host_place("storage_locker", spot.global_position, spot.global_rotation.y)
			GameState.world["free_locker"] = true
			print("[World] A free storage locker in the Starter Room")
	for p: Node in get_tree().get_nodes_in_group(&"properties"):
		var adopted: int = (p as Property).host_adopt_furniture(self)
		if adopted > 0:
			print("[World] %s: %d pieces of furniture can now be moved" % [(p as Property).display_name, adopted])
	if GameState.world.has("hours"):
		print("[World] Restored from the save: time %.1f h" % float(GameState.world["hours"]))


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
		var cops: int = POLICE_COUNT
		for arg: String in OS.get_cmdline_user_args():
			if arg.begins_with("--police="):
				cops = arg.trim_prefix("--police=").to_int()
		spawn_police(cops)
	if multiplayer.is_server() and not ("--selftest" in OS.get_cmdline_user_args()
			or "--netcheck" in OS.get_cmdline_user_args()):
		for arg: String in OS.get_cmdline_user_args():
			if arg.begins_with("--rivals="):
				rival_count = arg.trim_prefix("--rivals=").to_int()
		_rival_loop()
	# Test scenario (F9 / --scenario=): set the host player up now that NPCs can walk.
	if multiplayer.is_server() and Scenarios.pending != "":
		Scenarios.run(self, Scenarios.pending)
	elif multiplayer.is_server() and not SaveManager.scenario_mode:
		# Check run of the F9 path: a normal game that switches into a scenario by itself.
		for arg: String in OS.get_cmdline_user_args():
			if arg.begins_with("--f9-test="):
				Scenarios.restart_into(get_tree(), arg.trim_prefix("--f9-test="))


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


# --- Police (point 10, host) -------------------------------------------------------------

const POLICE_OFFICER := preload("res://prefabs/npc/police_officer.tscn")
## Point 25: officers belong to a patrol car (Traffic.spawn_police_cars); no foot patrols
## by default (`--police=N` still adds foot officers at the station, e.g. for tests).
const POLICE_COUNT: int = 0


## Host: `count` officers on foot, starting at the police station's spawn markers.
func spawn_police(count: int) -> void:
	var station: Node3D = find_child("PoliceStation", true, false) as Node3D
	if station == null:
		return
	for i: int in count:
		var m := station.find_child("OfficerSpawn%d" % (i % 3 + 1), true, false) as Node3D
		var p: Vector3 = m.global_position if m else station.global_position + station.global_basis.z * 2.0
		add_officer(p, station.global_position + station.global_basis.z * 3.0)


## Host: a police officer at `p` that patrols around `home` (`car` = its patrol car).
func add_officer(p: Vector3, home: Vector3, car: Node3D = null) -> PoliceOfficer:
	var cop: PoliceOfficer = POLICE_OFFICER.instantiate()
	cop.variant = PoliceOfficer.VARIANT
	cop.color_seed = randi()
	cop.position = p
	cop.home = home
	cop.from_car = car
	npcs.add_child(cop, true)
	return cop


# --- Black Crows (point 11, host) -------------------------------------------------------

const RIVAL := preload("res://prefabs/npc/rival.tscn")
## How many Crows are out at night at most (--rivals=N; 0 = none).
var rival_count: int = 3
var _crows_warned_night: bool = false


## Host: at night the Crows come out of their house one by one, up to rival_count.
func _rival_loop() -> void:
	var dn := get_tree().get_first_node_in_group(&"day_night") as DayNight
	while is_inside_tree() and rival_count > 0:
		await get_tree().create_timer(5.0).timeout
		if dn == null or not dn.is_night():
			_crows_warned_night = false
			continue
		var out: int = get_tree().get_nodes_in_group(&"rivals").filter(
				func(r: Node) -> bool: return not (r as Pedestrian).dead).size()
		if out >= rival_count:
			continue
		add_rival()
		if not _crows_warned_night:
			_crows_warned_night = true
			phone_all("Unknown", "The Crows are out tonight. Stay off the streets or stay strapped.")


## Host: one Crow at its house's door (RivalSpawn markers), going home there at daybreak.
func add_rival(at: Vector3 = Vector3.INF) -> Rival:
	var house: Node3D = find_child("CrowsHouse", true, false) as Node3D
	var spots: Array = house.find_children("RivalSpawn*", "Marker3D", true, false) if house else []
	var spawn: Vector3 = (spots.pick_random() as Node3D).global_position if not spots.is_empty() else at
	if at == Vector3.INF:
		at = spawn
	var r: Rival = RIVAL.instantiate()
	r.variant = PoliceOfficer.VARIANT
	r.color_seed = randi()
	r.position = at
	r.home = spawn if spawn != Vector3.INF else at
	npcs.add_child(r, true)
	print("[Crows] %s comes out" % r.name)
	return r


## Host: a dead officer is replaced at the station after `delay` seconds.
func respawn_officer_later(delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if is_inside_tree() and multiplayer.is_server():
		spawn_police(1)


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
	"Garage": "the garage", "PoliceStation": "the police station", "CrowsHouse": "the Crows' house",
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
			if p and not p.dead and p.wants == 0 and not p.is_fleeing() and not p is PoliceOfficer:
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
	if multiplayer.is_server():
		SaveManager.save_game()
	Net.leave_game()
	get_tree().change_scene_to_file(Net.MAIN_MENU_SCENE)
