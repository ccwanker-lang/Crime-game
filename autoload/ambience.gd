extends Node
## Ambience (session B, Roadmap 66-68), autoload `Ambience`. LOCAL on every peer, no networking of its own.
## - Vehicle sound (66): every traffic Car (group "cars") and PlayerCar (group "player_cars") gets a VehicleSound
##   child (engine, tyres, brakes) - so A's car scripts need no changes for sound.
## - Dogs (67): every dog-walking ParkGoer gets a real `Dog` at World/Dogs/Dog_<owner name> on every peer (same path
##   everywhere, so the host's RPCs reach it); the host drives it.
## - Animals (68): a local `Wildlife` node (World/Wildlife: birds, pigeons, cats, ducks) once the World is loaded.
##   `--animals=0` leaves it out.

const SCAN_EVERY: float = 0.5

var _scan: float = 0.0
var animals_on: bool = true


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	for a: String in OS.get_cmdline_user_args():
		if a == "--animals=0":
			animals_on = false


func _on_node_added(n: Node) -> void:
	if n is ParkGoer or n is CityWalker:
		_make_dog.call_deferred(n)


## Every peer: the dog of a DOG ParkGoer (once).
func _make_dog(npc: Pedestrian) -> Dog:
	if not is_instance_valid(npc) or not npc.is_inside_tree() or npc.dead:
		return null
	if not ((npc is ParkGoer and (npc as ParkGoer).role == ParkGoer.Role.DOG)
			or (npc is CityWalker and (npc as CityWalker).role == CityWalker.Role.DOG)):
		return null
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null
	var dogs: Node = scene.get_node_or_null("Dogs")
	if dogs == null:
		dogs = Node3D.new()
		dogs.name = "Dogs"
		scene.add_child(dogs)
	var dog_name: String = "Dog_%s" % npc.name
	if dogs.has_node(dog_name):
		var old := dogs.get_node(dog_name) as Dog
		if old and old.owner_npc == npc:
			return old
		dogs.remove_child(old)  # (a fleeing / dead dog of an earlier owner with the same name: gone on every peer)
		old.queue_free()
	var dog := Dog.new()
	dog.name = dog_name
	dog.owner_npc = npc
	dogs.add_child(dog)
	return dog


func _process(delta: float) -> void:
	_scan -= delta
	if _scan > 0.0:
		return
	_scan = SCAN_EVERY
	var scene: Node = get_tree().current_scene
	if scene == null or scene.get_node_or_null("Players") == null:
		return
	if animals_on and scene.get_node_or_null("Wildlife") == null:
		var w := Wildlife.new()
		w.name = "Wildlife"
		scene.add_child(w)
	for g: StringName in [&"cars", &"player_cars"]:
		for n: Node in get_tree().get_nodes_in_group(g):
			if (n is Car or n is PlayerCar) and n.get_node_or_null("VehicleSound") == null:
				attach_sound(n as Node3D)


## Gives `v` its engine sound (also used by tests).
func attach_sound(v: Node3D) -> VehicleSound:
	var s := VehicleSound.new()
	s.vehicle = v
	v.add_child(s)
	return s
