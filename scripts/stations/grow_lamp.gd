class_name GrowLamp
extends Station
## LED grow light on a free-standing frame. E switches it on/off. Pots under the
## panel (inside the frame footprint) grow BOOST times faster while it is on.

const BOOST: float = 1.6
const FRAME_WIDTH: float = 1.3
const FRAME_DEPTH: float = 0.5
const POST_HEIGHT: float = 1.75
const PANEL_HEIGHT: float = 1.45

var _light: SpotLight3D
var _glow_on: MeshInstance3D
var _glow_off: MeshInstance3D


func default_state() -> Dictionary:
	return {"on": true}


func _ready() -> void:
	add_to_group(&"grow_lamps")
	super()


func _build() -> void:
	var b := MeshBuilder.new()
	b.collide = true
	var hw: float = FRAME_WIDTH * 0.5
	var hd: float = FRAME_DEPTH * 0.5
	for x: float in [-hw, hw]:
		# Post with a flat foot along the depth.
		b.box(&"metal_dark", Vector3(x, POST_HEIGHT * 0.5, 0), Vector3(0.035, POST_HEIGHT, 0.035))
		b.box(&"metal_dark", Vector3(x, 0.015, 0), Vector3(0.05, 0.03, FRAME_DEPTH))
	b.box(&"metal_dark", Vector3(0, POST_HEIGHT - 0.0175, 0), Vector3(FRAME_WIDTH + 0.035, 0.035, 0.035))
	# Panel hanging from the crossbar on two cords.
	var panel_size := Vector3(FRAME_WIDTH - 0.3, 0.05, FRAME_DEPTH - 0.12)
	b.box(&"lamp_housing", Vector3(0, PANEL_HEIGHT, 0), panel_size, 0.01)
	b.collide = false
	for x: float in [-panel_size.x * 0.4, panel_size.x * 0.4]:
		b.cylinder(&"string", Vector3(x, PANEL_HEIGHT + 0.025, 0), Vector3(x, POST_HEIGHT - 0.035, 0), 0.004, 0.004, 4, false)
	var mi := MeshInstance3D.new()
	mi.mesh = b.build()
	add_child(mi)
	for box: Dictionary in b.collision_boxes:
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = box["size"]
		cs.shape = shape
		cs.transform = box["xform"]
		add_child(cs)

	# LED surface under the panel: glowing when on, dark when off.
	var y: float = PANEL_HEIGHT - 0.026
	var sx: float = panel_size.x * 0.46
	var sz: float = panel_size.z * 0.42
	var quad := PackedVector3Array([Vector3(-sx, y, -sz), Vector3(sx, y, -sz), Vector3(sx, y, sz), Vector3(-sx, y, sz)])
	_glow_on = _quad(&"grow_light_glow", quad)
	_glow_off = _quad(&"metal_dark", quad)

	_light = SpotLight3D.new()
	_light.position = Vector3(0, PANEL_HEIGHT - 0.04, 0)
	_light.rotation.x = -PI / 2.0  # point down
	_light.spot_angle = 62.0
	_light.spot_range = 2.6
	_light.light_color = Color(1.0, 0.78, 0.95)
	_light.light_energy = 2.2
	_light.shadow_enabled = true
	_light.distance_fade_enabled = true
	_light.distance_fade_begin = 25.0
	_light.distance_fade_length = 5.0
	add_child(_light)


func _quad(key: StringName, pts: PackedVector3Array) -> MeshInstance3D:
	var b := MeshBuilder.new()
	b.poly(key, pts, Vector3.DOWN)
	var mi := MeshInstance3D.new()
	mi.mesh = b.build()
	add_child(mi)
	return mi


func state_changed() -> void:
	if _light == null:
		return
	var on: bool = bool(state["on"])
	_light.visible = on
	_glow_on.visible = on
	_glow_off.visible = not on


## True if a pot at `world_pos` stands under the lit panel.
func boosts(world_pos: Vector3) -> bool:
	if not bool(state.get("on", false)):
		return false
	var p: Vector3 = to_local(world_pos)
	return absf(p.x) < FRAME_WIDTH * 0.5 and absf(p.z) < FRAME_DEPTH * 0.6 and p.y < PANEL_HEIGHT


func prompt_for(_player: Player) -> String:
	return "Switch grow light %s" % ("off" if bool(state["on"]) else "on")


func do_action(_player: Player) -> String:
	state["on"] = not bool(state["on"])
	changed()
	return ""
