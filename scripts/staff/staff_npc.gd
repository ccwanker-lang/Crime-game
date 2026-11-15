class_name StaffNPC
extends Node3D
## A crew member in the world (local visual on every peer, see StaffViews): a stationary
## Pedestrian model + a layer-2 body for the interact ray. Workers stand at the station they
## worked on last; dealers stand on the pavement in their district.
## E: a dealer opens the dealer window, a worker the worker window (CrewWindow: their locker, stations, route).
## A worker who moves to another station walks there (local tween).

const PEDESTRIAN: PackedScene = preload("res://prefabs/npc/pedestrian.tscn")

var uid: String = ""
var rec: Dictionary = {}
var _npc: Pedestrian
var _label: Label3D
var _walk: Tween
var _placed: bool = false


func setup(r: Dictionary) -> void:
	rec = r
	name = "Staff_" + uid
	_npc = PEDESTRIAN.instantiate() as Pedestrian
	_npc.variant = int(r.get("variant", 0)) % Pedestrian.VARIANTS.size()
	_npc.color_seed = int(r.get("color", 0))
	_npc.stationary = true
	_npc.ambient = false
	add_child(_npc)
	var body := StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	body.add_child(cs)
	add_child(body)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.pixel_size = 0.0035
	_label.font_size = 40
	_label.outline_size = 10
	_label.position.y = 2.1
	_label.modulate = Color(0.75, 0.9, 1.0)
	add_child(_label)
	add_to_group(&"interactable")
	add_to_group(&"staff")


func update(r: Dictionary) -> void:
	rec = r
	if r.has("pos"):
		var to: Vector3 = r["pos"]  # (StaffViews sits at the world origin)
		var far: float = position.distance_to(to)
		if _walk:
			_walk.kill()
			_walk = null
		var walk: bool = _placed and far > 0.4 and far < 25.0 and is_inside_tree() and _npc != null
		_placed = true
		if walk:
			var d: Vector3 = to - position
			rotation.y = atan2(-d.x, -d.z)
			_npc.anim_state = Pedestrian.Anim.WALK
			_walk = create_tween()
			_walk.tween_property(self, "position", to, far / 1.3)
			var yaw: float = float(r.get("yaw", 0.0))
			_walk.tween_callback(func() -> void:
				rotation.y = yaw
				_npc.anim_state = Pedestrian.Anim.TALK)
			_label.text = "%s (%s)" % [r["name"], Staff.role_name(str(r["role"]))]
			return
		position = to
	rotation.y = float(r.get("yaw", 0.0))
	_label.text = "%s (%s)" % [r["name"], Staff.role_name(str(r["role"]))]
	if _npc:
		_npc.anim_state = Pedestrian.Anim.IDLE if r["role"] == "dealer" else Pedestrian.Anim.TALK


func get_interaction_prompt() -> String:
	if rec.get("role") == "dealer":
		return "Talk to %s (dealer): %d bags%s, €%d waiting" % [rec["name"], int(rec["stock"]), Staff.meth_text(rec), int(rec["cash"])]
	return "Talk to %s (%s)" % [rec["name"], Staff.role_name(str(rec["role"]))]


func interact() -> void:
	var me: Player = _local_player()
	if me == null or me.ui == null:
		return
	if rec.get("role") == "dealer":
		CrewWindow.open_for(me, "dealer", uid)
	elif str(rec.get("employer", "")) == me.player_name:
		CrewWindow.open_for(me, "worker", uid)
	else:
		var status: String = str(rec.get("status", "working"))
		me.ui.toast("%s: \"%s.\"" % [rec["name"], status.left(1).to_upper() + status.substr(1)])


func _local_player() -> Player:
	for p: Node in get_tree().get_nodes_in_group(&"players"):
		if (p as Player).is_local():
			return p as Player
	return null
