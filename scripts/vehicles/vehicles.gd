class_name Vehicles
extends Node3D
## Point 45: the crew's own cars (node World/Vehicles). Host: spawns them (bought at Carlo's Cars or from the
## save) through its own MultiplayerSpawner; every peer builds them with `_create`. Saved in
## GameState.world["vehicles"] = {uid: {model, paint, pos, yaw}} (where they were last parked).

const PLAYER_CAR := preload("res://scripts/vehicles/player_car.gd")

static var current: Vehicles = null

var spawner: MultiplayerSpawner


func _ready() -> void:
	current = self
	spawner = MultiplayerSpawner.new()
	spawner.name = "Spawner"
	add_child(spawner)
	spawner.spawn_path = spawner.get_path_to(self)
	spawner.spawn_function = _create


func _exit_tree() -> void:
	if current == self:
		current = null


## Host: a new car (or one from the save when uid is given).
func host_spawn(model_id: String, paint: int, pos: Vector3, yaw: float, uid: String = "") -> PlayerCar:
	if uid == "":
		var next: int = int(GameState.world.get("vehicles_next", 1))
		GameState.world["vehicles_next"] = next + 1
		uid = str(next)
	var cars: Dictionary = GameState.world.get_or_add("vehicles", {})
	cars[uid] = {"model": model_id, "paint": paint, "pos": pos, "yaw": yaw}
	return spawner.spawn({"uid": uid, "model": model_id, "paint": paint, "pos": pos, "yaw": yaw}) as PlayerCar


## Host: remove a car for good (tests).
func host_remove(car: PlayerCar) -> void:
	var cars: Dictionary = GameState.world.get_or_add("vehicles", {})
	cars.erase(car.uid)
	for p: int in car.seats:
		if p != 0:
			car.host_exit(car.get_tree().current_scene.get_node_or_null("Players/%d" % p) as Player)
	car.queue_free()


func _create(data: Dictionary) -> Node:
	var car: PlayerCar = PLAYER_CAR.new()
	car.uid = str(data["uid"])
	car.name = "Car" + car.uid
	car.model_id = str(data["model"])
	car.paint_index = int(data["paint"])
	car.net_pos = data["pos"]
	car.net_yaw = float(data["yaw"])
	car.position = data["pos"]
	car.rotation.y = float(data["yaw"])
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var cfg := SceneReplicationConfig.new()
	for prop: String in [":net_pos", ":net_yaw", ":net_speed", ":net_steer"]:
		cfg.add_property(NodePath("." + prop))
		cfg.property_set_replication_mode(NodePath("." + prop), SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	cfg.add_property(NodePath(".:seats"))
	cfg.property_set_replication_mode(NodePath(".:seats"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	sync.replication_config = cfg
	car.add_child(sync)
	Net.limit_sync_to_world(sync)
	return car


func cars() -> Array[PlayerCar]:
	var out: Array[PlayerCar] = []
	for n: Node in get_children():
		if n is PlayerCar and not n.is_queued_for_deletion():
			out.append(n as PlayerCar)
	return out


## Host: every car's parking spot -> the save.
func capture() -> void:
	for car: PlayerCar in cars():
		car._save_record()


## Host (World._restore_from_save): the saved cars come back where they were parked.
func restore() -> void:
	var cars_rec: Dictionary = GameState.world.get_or_add("vehicles", {})
	for uid: String in cars_rec.keys():
		if has_node("Car" + uid):
			continue
		var r: Dictionary = cars_rec[uid]
		if not CarCatalog.MODELS.has(str(r.get("model", ""))):
			cars_rec.erase(uid)
			continue
		host_spawn(str(r["model"]), int(r.get("paint", 0)), r["pos"], float(r.get("yaw", 0.0)), uid)


## Nearest car to a point within `max_dist` of its body (null if none).
func nearest(p: Vector3, max_dist: float) -> PlayerCar:
	var best: PlayerCar = null
	var best_d: float = max_dist
	for car: PlayerCar in cars():
		var d: float = car.distance_to_body(p)
		if d <= best_d and absf(car.global_position.y - p.y) < 2.5:
			best = car
			best_d = d
	return best
