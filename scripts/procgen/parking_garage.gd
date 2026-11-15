@tool
class_name ParkingGarage
extends StaticBody3D
## Map zone 7 (the city): an open multi-storey car park you can drive up. Origin = the centre of the footprint at
## street level; the entrance (the bottom of the ramp lane) is on the +Z side at the +X edge. The ramps lie
## stacked in one lane along the +X side (each 3 m above the one below, 12.5 %); the decks fill the rest, with
## pillars, parapets and painted bays. Everything has collision (layer 1).

@export var width: float = 36.0:
	set(v): width = v; _queue_rebuild()
@export var depth: float = 30.0:
	set(v): depth = v; _queue_rebuild()
@export_range(1, 6) var levels: int = 3:
	set(v): levels = v; _queue_rebuild()
@export var tint: Color = Color(0.7, 0.69, 0.66):
	set(v): tint = v; _queue_rebuild()
@export var sign_text: String = "P":
	set(v): sign_text = v; _queue_rebuild()

const LEVEL_H: float = 3.0
const SLAB: float = 0.3
const LANE: float = 6.0
const PARAPET: float = 1.0

var _generated: Array[Node] = []
var _pending: bool = false


func _ready() -> void:
	_rebuild()


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
	var b := MeshBuilder.new()
	b.collide = true
	var hx: float = width / 2.0
	var hz: float = depth / 2.0
	var lane_x0: float = hx - LANE  # the ramp lane: x lane_x0..hx
	var ramp_len: float = depth - 6.0
	for k: int in range(1, levels + 1):
		var y: float = k * LEVEL_H
		# Deck (minus the ramp lane), with a gap at the lane's ends to drive on and off the ramps.
		b.color = tint
		b.box(&"concrete", Vector3((-hx + lane_x0) / 2.0, y - SLAB / 2.0, 0), Vector3(lane_x0 + hx, SLAB, depth))
		# The landing at the top of ramp k-1 (north end of the lane) at this level.
		b.box(&"concrete", Vector3((lane_x0 + hx) / 2.0, y - SLAB / 2.0, -hz + 1.5), Vector3(LANE, SLAB, 3.0))
		if k < levels:
			# The landing at the bottom of ramp k (south end of the lane): from the deck onto the next ramp.
			b.box(&"concrete", Vector3((lane_x0 + hx) / 2.0, y - SLAB / 2.0, hz - 1.5), Vector3(LANE, SLAB, 3.0))
		else:
			# Top deck: a parapet along the open ramp lane (except next to the landing).
			b.box(&"concrete", Vector3(lane_x0 - 0.15, y + PARAPET / 2.0, 3.0), Vector3(0.3, PARAPET, depth - 6.0))
		# Parapets (not on the lane side's inner edge).
		b.color = tint.darkened(0.08)
		b.box(&"concrete", Vector3(0, y + PARAPET / 2.0, -hz + 0.15), Vector3(width, PARAPET, 0.3))
		b.box(&"concrete", Vector3((-hx + lane_x0) / 2.0, y + PARAPET / 2.0, hz - 0.15), Vector3(lane_x0 + hx, PARAPET, 0.3))
		b.box(&"concrete", Vector3(-hx + 0.15, y + PARAPET / 2.0, 0), Vector3(0.3, PARAPET, depth))
		b.box(&"concrete", Vector3(hx - 0.15, y + PARAPET / 2.0, 0), Vector3(0.3, PARAPET, depth))
		# Bay lines.
		b.collide = false
		b.color = Color(0.95, 0.95, 0.9)
		var bx: float = -hx + 1.0
		while bx < lane_x0 - 6.0:
			for zz: float in [-hz + 2.6, hz - 2.6]:
				b.box(&"road_marking", Vector3(bx, y + 0.01, zz), Vector3(0.12, 0.01, 5.0))
			bx += 2.6
		b.collide = true
	# Ramps: level k-1 at the south end of the lane up to level k at the north end.
	for k: int in range(1, levels + 1):
		var y0: float = (k - 1) * LEVEL_H
		var rise: float = LEVEL_H
		var ang: float = atan2(rise, ramp_len)
		var slope_len: float = sqrt(rise * rise + ramp_len * ramp_len)
		var mid := Vector3((lane_x0 + hx) / 2.0, y0 + rise / 2.0 - SLAB / 2.0, (hz - 3.0 + (-hz + 3.0)) / 2.0)
		b.xform = Transform3D(Basis(Vector3.RIGHT, ang), mid)  # rises towards -Z
		b.color = tint.lightened(0.05)
		b.box(&"concrete", Vector3.ZERO, Vector3(LANE, SLAB, slope_len + 0.4))
		b.color = Color(0.95, 0.85, 0.2)
		b.collide = false
		b.box(&"road_marking", Vector3(0, SLAB / 2.0 + 0.01, 0), Vector3(0.15, 0.01, slope_len - 2.0))
		b.collide = true
		b.xform = Transform3D.IDENTITY
		# Kerb walls along the ramp's open side.
		b.color = tint.darkened(0.1)
		b.xform = Transform3D(Basis(Vector3.RIGHT, ang), mid)
		b.box(&"concrete", Vector3(-LANE / 2.0 + 0.15, 0.55, 0), Vector3(0.3, 0.8, slope_len - 10.0))
		b.xform = Transform3D.IDENTITY
	# Ground floor slab (flush with the street) and the bottom landing of ramp 1.
	b.color = tint.darkened(0.15)
	b.box(&"concrete", Vector3(0, 0.02, 0), Vector3(width, 0.04, depth))
	# Pillars every ~8 m.
	b.color = tint.darkened(0.05)
	var nx: int = maxi(2, int(lane_x0 + hx) / 8)
	var nz: int = maxi(2, int(depth) / 8)
	for i: int in nx + 1:
		for j: int in nz + 1:
			var px: float = -hx + 0.4 + (lane_x0 - 0.4 - (-hx + 0.4)) * i / nx
			var pz: float = -hz + 0.4 + (depth - 0.8) * j / nz
			b.box(&"concrete", Vector3(px, levels * LEVEL_H / 2.0, pz), Vector3(0.6, levels * LEVEL_H, 0.6))
	var mi := MeshInstance3D.new()
	mi.mesh = b.build()
	add_child(mi)
	_generated.append(mi)
	for box: Dictionary in b.collision_boxes:
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = box["size"]
		cs.shape = shape
		cs.transform = box["xform"]
		add_child(cs)
		_generated.append(cs)
	if sign_text != "":
		var lbl := Label3D.new()
		lbl.text = sign_text
		lbl.font_size = 260
		lbl.pixel_size = 0.01
		lbl.modulate = Color(0.2, 0.45, 0.9)
		lbl.outline_modulate = Color.WHITE
		lbl.outline_size = 30
		lbl.position = Vector3(hx - LANE / 2.0, levels * LEVEL_H + 2.0, hz)
		lbl.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		add_child(lbl)
		_generated.append(lbl)
