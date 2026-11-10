@tool
class_name NetDoor
extends Node3D
## Hinged door that any player can open/close with E.
## Host authoritative: clients ask the host, the host flips the state and tells
## everyone. Late joiners get the state via the world snapshot (group "net_state").
## Hinge at the local origin; the panel extends along +X and opens towards -Z.

const DOOR_LAYER: int = 2  # physics layer 2 ("doors"), ignored by navmesh baking

@export var width: float = 0.9:
	set(v): width = v; _queue_rebuild()
@export var height: float = 2.3:
	set(v): height = v; _queue_rebuild()
@export var glass_panel: bool = false:
	set(v): glass_panel = v; _queue_rebuild()
@export var open_angle: float = 100.0

var is_open: bool = false
var _pivot: Node3D
var _mesh: MeshInstance3D
var _color: Color = Color(0.16, 0.27, 0.22)
var _tween: Tween
var _pending: bool = false


func _ready() -> void:
	add_to_group(&"interactable")
	add_to_group(&"net_state")
	_rebuild()


func _queue_rebuild() -> void:
	if not is_inside_tree() or _pending:
		return
	_pending = true
	_rebuild.call_deferred()


func set_color(c: Color) -> void:
	_color = c
	if _mesh:
		_mesh.set_instance_shader_parameter(&"door_tint", c)


func _rebuild() -> void:
	_pending = false
	if _pivot:
		_pivot.queue_free()
	_pivot = Node3D.new()
	add_child(_pivot)
	var body := AnimatableBody3D.new()
	body.collision_layer = 1 << (DOOR_LAYER - 1)
	body.collision_mask = 0
	_pivot.add_child(body)

	var b := MeshBuilder.new()
	var t: float = 0.05
	if glass_panel:
		var f: float = 0.07
		b.box_mm(&"metal_dark", Vector3(0, 0, -t), Vector3(f, height, 0), 0.005)
		b.box_mm(&"metal_dark", Vector3(width - f, 0, -t), Vector3(width, height, 0), 0.005)
		b.box_mm(&"metal_dark", Vector3(f, 0, -t), Vector3(width - f, 0.15, 0), 0.005)
		b.box_mm(&"metal_dark", Vector3(f, height - f, -t), Vector3(width - f, height, 0), 0.005)
		b.quad(&"glass_clear", Vector3(f, 0.15, -t / 2), Vector3(width - f, 0.15, -t / 2),
				Vector3(width - f, height - f, -t / 2), Vector3(f, height - f, -t / 2), Vector3.BACK)
		b.box_mm(&"zinc", Vector3(width - 0.2, 0.9, 0), Vector3(width - 0.16, 1.3, 0.06), 0.01)
	else:
		b.box_mm(&"door_paint", Vector3(0, 0, -t), Vector3(width, height, 0), 0.008)
		# Raised panels on both faces.
		for zr: Vector2 in [Vector2(0.0, 0.015), Vector2(-t - 0.015, -t)]:
			b.box_mm(&"door_paint", Vector3(0.15, 1.25, zr.x), Vector3(width - 0.15, height - 0.18, zr.y), 0.01)
			b.box_mm(&"door_paint", Vector3(0.15, 0.18, zr.x), Vector3(width - 0.15, 1.05, zr.y), 0.01)
		# Handles on both faces.
		b.box_mm(&"zinc", Vector3(width - 0.17, 1.0, 0.0), Vector3(width - 0.09, 1.06, 0.06), 0.01)
		b.box_mm(&"zinc", Vector3(width - 0.17, 1.0, -t - 0.06), Vector3(width - 0.09, 1.06, -t), 0.01)
	_mesh = MeshInstance3D.new()
	_mesh.mesh = b.build()
	body.add_child(_mesh)
	set_color(_color)

	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, height, t)
	cs.shape = shape
	cs.position = Vector3(width / 2.0, height / 2.0, -t / 2.0)
	body.add_child(cs)
	_pivot.rotation.y = deg_to_rad(open_angle) if is_open else 0.0


# --- Interaction (called by the local player) -------------------------------------

func get_interaction_prompt() -> String:
	return "Press E to close the door" if is_open else "Press E to open the door"


func interact() -> void:
	if multiplayer.is_server():
		_server_toggle()
	else:
		_request_toggle.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _request_toggle() -> void:
	if multiplayer.is_server():
		_server_toggle()


func _server_toggle() -> void:
	_set_open.rpc(not is_open)


@rpc("authority", "call_local", "reliable")
func _set_open(open: bool) -> void:
	is_open = open
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_pivot, "rotation:y", deg_to_rad(open_angle) if open else 0.0, 0.45)


# --- Late-join snapshot ----------------------------------------------------------

func get_net_state() -> Dictionary:
	return {"open": is_open}


func apply_net_state(state: Dictionary) -> void:
	is_open = state.get("open", false)
	if _pivot:
		_pivot.rotation.y = deg_to_rad(open_angle) if is_open else 0.0
