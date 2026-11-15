class_name BunkerLab
extends Node3D
## Map zone 8 (session B, NOTES part 18): the secret lab inside the mountain behind A's bunker portal
## (Mountain/Bunker, `Mountain.bunker_spot()`). Built in code on EVERY peer by `Zones` at World/BunkerLab (same path
## everywhere, so the RPCs and the property's net state work):
## - a big concrete hall (30 x 18 m, 4.2 m high) deep under the portal, out of sight, with lamps and pillars;
## - `BunkerProperty` (property id "bunker", for sale at the estate agent, expensive, rank-gated by RankConfig);
##   inside it you place stations like in any property; Raids never come here (Raids.RAID_FREE);
## - a keypad next to the portal (E = go in, only when the crew owns it) and one inside by the lift (E = go out):
##   the host teleports the player.

static var current: BunkerLab

const PROPERTY_ID: StringName = &"bunker"
const PRICE: int = 250000
const SIZE: Vector3 = Vector3(30.0, 4.2, 18.0)
## The hall's floor this far under the portal floor (more if the slope above is low).
const DEPTH: float = 14.0
const KEYPAD_RANGE: float = 3.5

var spot: Transform3D = Transform3D.IDENTITY
## The hall: floor centre + the portal's yaw (local -Z = towards the portal side).
var hall: Transform3D = Transform3D.IDENTITY
var property: BunkerProperty
var outside_pad: StaticBody3D
var inside_pad: StaticBody3D
var entries: int = 0


func _ready() -> void:
	current = self
	spot = Mountain.bunker_spot()
	if spot == Transform3D.IDENTITY:
		return
	_place_hall()
	_build_hall()
	_build_property()
	outside_pad = _keypad("OutsidePad", spot * Transform3D(Basis.IDENTITY, Vector3(-4.2, 1.35, -0.95)), "Enter the bunker")
	inside_pad = _keypad("InsidePad", hall * Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, 1.35, -SIZE.z * 0.5 + 0.35)), "Take the lift up")
	if not _is_host():
		_ask_state.rpc_id.call_deferred(1)


func _exit_tree() -> void:
	if current == self:
		current = null


func _is_host() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()


## The hall sits behind the portal (into the slope) and DEPTH under it, deeper if the mountain above is too low.
func _place_hall() -> void:
	var b: Basis = spot.basis
	var centre: Vector3 = spot.origin + b * Vector3(0, 0, SIZE.z * 0.5 + 4.0)
	var floor_y: float = spot.origin.y - DEPTH
	for cx: float in [-0.5, 0.5]:
		for cz: float in [-0.5, 0.5]:
			var c: Vector3 = centre + b * Vector3(cx * SIZE.x, 0, cz * SIZE.z)
			var ground: float = Mountain.height_at(c.x, c.z)
			if ground > 0.0:
				floor_y = minf(floor_y, ground - SIZE.y - 3.0)
	floor_y = maxf(floor_y, Player.FALL_Y + 3.0)
	hall = Transform3D(b, Vector3(centre.x, floor_y, centre.z))


## Every peer: is `pos` inside the hall?
func inside(pos: Vector3) -> bool:
	if hall == Transform3D.IDENTITY:
		return false
	var l: Vector3 = hall.affine_inverse() * pos
	return absf(l.x) < SIZE.x * 0.5 - 0.2 and absf(l.z) < SIZE.z * 0.5 - 0.2 and l.y > -0.3 and l.y < SIZE.y


func entry_point() -> Vector3:
	return hall * Vector3(0, 0.15, -SIZE.z * 0.5 + 2.0)


func exit_point() -> Vector3:
	return spot * Vector3(0, 0.15, -3.0)


func _build_hall() -> void:
	var root := Node3D.new()
	root.name = "Hall"
	root.transform = hall
	add_child(root)
	var b := MeshBuilder.new()
	b.collide = true
	var hx: float = SIZE.x * 0.5
	var hz: float = SIZE.z * 0.5
	var t: float = 0.4
	b.color = Color(0.55, 0.55, 0.53)
	b.box(&"concrete", Vector3(0, -t * 0.5, 0), Vector3(SIZE.x + 2 * t, t, SIZE.z + 2 * t))   # floor
	b.color = Color(0.48, 0.48, 0.47)
	b.box(&"concrete", Vector3(0, SIZE.y + t * 0.5, 0), Vector3(SIZE.x + 2 * t, t, SIZE.z + 2 * t))  # ceiling
	b.color = Color(0.6, 0.6, 0.58)
	b.box(&"concrete", Vector3(-hx - t * 0.5, SIZE.y * 0.5, 0), Vector3(t, SIZE.y, SIZE.z))
	b.box(&"concrete", Vector3(hx + t * 0.5, SIZE.y * 0.5, 0), Vector3(t, SIZE.y, SIZE.z))
	b.box(&"concrete", Vector3(0, SIZE.y * 0.5, -hz - t * 0.5), Vector3(SIZE.x + 2 * t, SIZE.y, t))
	b.box(&"concrete", Vector3(0, SIZE.y * 0.5, hz + t * 0.5), Vector3(SIZE.x + 2 * t, SIZE.y, t))
	# Two rows of pillars.
	b.color = Color(0.52, 0.52, 0.5)
	for px: float in [-hx * 0.5, 0.0, hx * 0.5]:
		for pz: float in [-hz * 0.35, hz * 0.35]:
			b.box(&"concrete", Vector3(px, SIZE.y * 0.5, pz), Vector3(0.6, SIZE.y, 0.6))
	b.collide = false
	# Yellow-black floor stripes by the lift, a lift door on the front wall.
	b.color = Color(0.9, 0.72, 0.12)
	b.box(&"item_matte", Vector3(0, 0.005, -hz + 1.2), Vector3(4.0, 0.01, 0.3))
	b.color = Color(0.3, 0.33, 0.3)
	b.box(&"metal_dark", Vector3(0, 1.25, -hz + 0.03), Vector3(2.4, 2.5, 0.06))
	# Ceiling lamps.
	b.color = Color(1.0, 0.97, 0.85)
	for lx: float in [-hx * 0.66, -hx * 0.2, hx * 0.2, hx * 0.66]:
		for lz: float in [-hz * 0.5, hz * 0.5]:
			b.box(&"item_matte", Vector3(lx, SIZE.y - 0.06, lz), Vector3(1.6, 0.08, 0.25))
	var mi := MeshInstance3D.new()
	mi.mesh = b.build()
	root.add_child(mi)
	var body := StaticBody3D.new()
	body.name = "HallBody"
	body.collision_layer = 1
	body.collision_mask = 0
	root.add_child(body)
	for box: Dictionary in b.collision_boxes:
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = box["size"]
		cs.shape = shape
		cs.transform = box["xform"]
		body.add_child(cs)
	var sign := Label3D.new()
	sign.text = "LEVEL -2  /  LAB"
	sign.font_size = 64
	sign.pixel_size = 0.005
	sign.modulate = Color(0.95, 0.85, 0.4)
	sign.position = Vector3(0, 3.1, -hz + 0.05)
	root.add_child(sign)
	if DisplayServer.get_name() != "headless":
		for lx: float in [-hx * 0.5, 0.0, hx * 0.5]:
			var lamp := OmniLight3D.new()
			lamp.light_color = Color(1.0, 0.95, 0.85)
			lamp.light_energy = 1.4
			lamp.omni_range = 13.0
			lamp.shadow_enabled = false
			lamp.position = Vector3(lx, SIZE.y - 0.4, 0)
			root.add_child(lamp)


func _build_property() -> void:
	property = BunkerProperty.new()
	property.name = "Property"
	property.property_id = PROPERTY_ID
	property.display_name = "Mountain Bunker"
	property.for_sale = true
	property.price = PRICE
	property.description = "A cold-war bunker deep in the mountain. A huge hidden hall for a big lab: no neighbours, no raids. Reached by the side road off the pass."
	property.lab = self
	var lbl := Label3D.new()
	lbl.name = "Label3D"
	lbl.font_size = 48
	lbl.pixel_size = 0.005
	lbl.outline_size = 10
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.top_level = true
	property.add_child(lbl)
	property.transform = hall
	add_child(property)
	lbl.global_position = spot * Vector3(0, 6.6, -1.2)


func _keypad(pad_name: String, xform: Transform3D, prompt: String) -> StaticBody3D:
	var pad := BunkerKeypad.new()
	pad.name = pad_name
	pad.lab = self
	pad.prompt = prompt
	pad.going_in = pad_name == "OutsidePad"
	pad.transform = xform
	add_child(pad)
	return pad


# --- Going in / out (host teleports) -------------------------------------------------------------

## Owner (BunkerKeypad.interact): ask the host to go in / out.
func request_use(going_in: bool) -> void:
	if _is_host():
		host_use(multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1, going_in)
	else:
		_request_use.rpc_id(1, going_in)


@rpc("any_peer", "call_remote", "reliable")
func _request_use(going_in: bool) -> void:
	if multiplayer.is_server():
		host_use(multiplayer.get_remote_sender_id(), going_in)


## Host: teleport player `peer` in (crew owns the bunker) or out. Returns "" or why not.
func host_use(peer: int, going_in: bool) -> String:
	var world: Node = get_tree().current_scene
	return host_use_player(world.get_node_or_null("Players/%d" % peer) as Player if world else null, going_in)


## Host: teleport `p` in / out (the keypad's checks). Returns "" or why not.
func host_use_player(p: Player, going_in: bool) -> String:
	if p == null or p.dead:
		return "no player"
	var pad: Node3D = outside_pad if going_in else inside_pad
	if p.global_position.distance_to(pad.global_position) > KEYPAD_RANGE + 1.0:
		return "too far"
	if going_in and not property.is_crew_owned():
		var lock: String = Progression.property_lock(PROPERTY_ID) if Progression.has_method("property_lock") else ""
		var why: String = "Access denied. The bunker is for sale at the estate agent (€%s)%s." % [Property.money(PRICE),
				", " + lock.to_lower() if lock != "" else ""]
		p.show_message(why)
		return why
	if p.vehicle != null:
		return "in a car"
	p.teleport(entry_point() if going_in else exit_point())
	if going_in:
		entries += 1
	print("[Bunker] %s goes %s" % [p.player_name, "in" if going_in else "out"])
	return ""


## Client: the property's owner after joining (the late-join snapshot may come before this node exists).
@rpc("any_peer", "call_remote", "reliable")
func _ask_state() -> void:
	if multiplayer.is_server() and property:
		property._owned_changed.rpc_id(multiplayer.get_remote_sender_id(), property.get_net_state())
