@tool
class_name SlidingGate
extends Node3D
## Point 99: an automatic sliding gate (prison, army base): a steel frame panel that rolls along +X behind the wall
## when a player, a car or a walking NPC comes within `reach` m of the opening, and rolls shut behind them.
## Local on every peer like BoomGate: everyone near it is seen by every peer within 0.2 s, and the panel opens long
## before you reach it (reach 11 m against a walk of a few m/s), so it never stops a player on a lagging peer.
## NPCs (group "npc") only count while they walk (velocity, so on the host; the gate guard stands next to it).
## The panel is an AnimatableBody3D on layer 2 (doors/props: not baked into the navmesh). Origin = the middle of
## the opening at the ground; the opening spans x -width/2..+width/2, the panel parks at +X.

@export var width: float = 6.0:
	set(v): width = v; _queue_rebuild()
@export var height: float = 3.6:
	set(v): height = v; _queue_rebuild()
@export var reach: float = 11.0
## Extra groups that open the gate (besides players / cars / npc).
@export var also_groups: PackedStringArray = []
## Point 100 (the army base): players on foot only open it with a pass (`Zones.allow_army`) - the host decides and
## tells every peer (RPC + net_state for late joiners), because only the host knows the passes. Cars, crew cars
## and walking NPCs (soldiers) still open it.
@export var needs_army_pass: bool = false

const CHECK_EVERY: float = 0.2
const SPEED: float = 2.2  # m/s
const GROUPS: Array[StringName] = [&"players", &"player_cars", &"cars", &"npc"]

var is_open: bool = false
var openness: float = 0.0  # 0 shut .. 1 open
var _panel: AnimatableBody3D
var _generated: Array[Node] = []
var _pending: bool = false
var _t: float = 0.0


func _ready() -> void:
	_rebuild()
	if needs_army_pass and not Engine.is_editor_hint():
		add_to_group(&"net_state")


func _queue_rebuild() -> void:
	if not is_inside_tree() or _pending:
		return
	_pending = true
	_rebuild.call_deferred()


func _rebuild() -> void:
	_pending = false
	for n: Node in _generated:
		n.queue_free()
	_generated.clear()
	# The rail on the ground (visual) and the guide posts at the ends of the opening.
	var fb := MeshBuilder.new()
	fb.color = Color(0.25, 0.26, 0.28)
	fb.box(&"item_metal", Vector3(width / 2.0, 0.03, 0.0), Vector3(width * 2.0 + 0.4, 0.06, 0.12))
	var fm := MeshInstance3D.new()
	fm.mesh = fb.build()
	add_child(fm)
	_generated.append(fm)
	_panel = AnimatableBody3D.new()
	_panel.collision_layer = 2
	_panel.collision_mask = 0
	_panel.sync_to_physics = false
	add_child(_panel)
	_generated.append(_panel)
	var b := MeshBuilder.new()
	b.color = Color(0.3, 0.32, 0.34)
	var hw: float = width / 2.0
	b.box(&"item_metal", Vector3(0, height - 0.08, 0), Vector3(width, 0.16, 0.12))  # top + bottom rails
	b.box(&"item_metal", Vector3(0, 0.16, 0), Vector3(width, 0.16, 0.12))
	b.box(&"item_metal", Vector3(-hw + 0.06, height / 2.0, 0), Vector3(0.12, height, 0.12))
	b.box(&"item_metal", Vector3(hw - 0.06, height / 2.0, 0), Vector3(0.12, height, 0.12))
	var bars: int = int(width / 0.16)
	b.color = Color(0.36, 0.38, 0.4)
	for i: int in bars:
		var x: float = -hw + 0.12 + i * (width - 0.24) / maxf(bars - 1, 1)
		b.box(&"item_metal", Vector3(x, height / 2.0, 0), Vector3(0.04, height - 0.3, 0.04))
	b.color = Color(0.85, 0.65, 0.1)  # yellow-black warning strip at the leading edge
	for k: int in 6:
		b.color = Color(0.9, 0.7, 0.1) if k % 2 == 0 else Color(0.12, 0.12, 0.12)
		b.box(&"item_matte", Vector3(-hw + 0.07, 0.4 + k * 0.35, 0.07), Vector3(0.1, 0.35, 0.02))
	var mi := MeshInstance3D.new()
	mi.mesh = b.build()
	_panel.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, height, 0.15)
	cs.shape = shape
	cs.position.y = height / 2.0
	_panel.add_child(cs)
	_apply()


func _apply() -> void:
	if _panel:
		_panel.position = Vector3(openness * (width + 0.2), 0, 0)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or _panel == null:
		return
	_t -= delta
	if _t <= 0.0:
		_t = CHECK_EVERY
		if not needs_army_pass:
			is_open = someone_near()
		elif multiplayer.is_server():
			var v: bool = someone_near()
			if v != is_open:
				is_open = v
				if multiplayer.has_multiplayer_peer() and Net.is_online():
					_net_open.rpc(v)
	var target: float = 1.0 if is_open else 0.0
	if not is_equal_approx(openness, target):
		openness = move_toward(openness, target, SPEED * delta / (width + 0.2))
		_apply()


func someone_near() -> bool:
	var at: Vector3 = global_position
	var r2: float = reach * reach
	var groups: Array = GROUPS.duplicate()
	for g: String in also_groups:
		groups.append(StringName(g))
	for group: StringName in groups:
		for n: Node in get_tree().get_nodes_in_group(group):
			var n3 := n as Node3D
			if n3 == null or not n3.is_visible_in_tree() or n3.global_position.distance_squared_to(at) >= r2:
				continue
			# NPCs only while walking: the gate guard and guards on post stand right next to it.
			if group == &"npc" and n3 is CharacterBody3D and (n3 as CharacterBody3D).velocity.length() < 0.3:
				continue
			if group == &"players" and needs_army_pass and not has_army_pass(n3):
				continue
			return true
	return false


## Host: `p` may walk through an army gate (a mission pass; never while the base is after them).
static func has_army_pass(p: Node) -> bool:
	var z: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null(^"Zones")
	if z == null or not p is Player:
		return false
	if z.has_method(&"has_pass"):
		return bool(z.call(&"has_pass", p))
	var passes: Variant = z.get(&"_passes")
	return passes is Dictionary and float((passes as Dictionary).get(p, 0.0)) > float(z.call(&"_now")) 			and not bool(z.call(&"is_army_hostile", p))


@rpc("authority", "call_remote", "reliable")
func _net_open(v: bool) -> void:
	is_open = v


func get_net_state() -> Dictionary:
	return {"open": is_open}


func apply_net_state(s: Dictionary) -> void:
	is_open = bool(s.get("open", false))
