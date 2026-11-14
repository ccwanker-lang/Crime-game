@tool
class_name ProcBus
extends StaticBody3D
## Point 49: a low-poly coach (stylized, flat colours) with collision. Nose at -Z, entry door on the right
## (+X) behind the front wheels. `boardable` = E boards it (the prison bus of the intro: Intro.request_board).

const LENGTH: float = 11.0
const WIDTH: float = 2.5
const HEIGHT: float = 3.1

@export var paint: Color = Color(0.85, 0.72, 0.2):
	set(v): paint = v; _queue_rebuild()
@export var stripe: Color = Color(0.2, 0.32, 0.55):
	set(v): stripe = v; _queue_rebuild()
@export var line_text: String = "12  RIVERTON":
	set(v): line_text = v; _queue_rebuild()
@export var boardable: bool = false

var _pending: bool = false
var _mesh: MeshInstance3D


func _ready() -> void:
	if boardable:
		add_to_group(&"interactable")
	_rebuild()


func _queue_rebuild() -> void:
	if not is_inside_tree() or _pending:
		return
	_pending = true
	_rebuild.call_deferred()


func _rebuild() -> void:
	_pending = false
	for c: Node in get_children():
		c.queue_free()
	var b := MeshBuilder.new()
	var hl: float = LENGTH / 2.0
	var hw: float = WIDTH / 2.0
	var floor_y: float = 0.45
	# Body: lower part painted, a stripe, the window band, the roof.
	b.color = paint
	b.box(&"item_matte", Vector3(0, floor_y + 0.55, 0), Vector3(WIDTH, 1.1, LENGTH), 0.06)
	b.color = stripe
	b.box(&"item_matte", Vector3(0, floor_y + 1.15, 0), Vector3(WIDTH + 0.02, 0.12, LENGTH + 0.02))
	b.color = Color(0.16, 0.2, 0.24)
	b.box(&"car_glass", Vector3(0, floor_y + 1.75, 0), Vector3(WIDTH - 0.04, 1.1, LENGTH - 0.04))
	b.color = paint
	for i: int in 9:  # window pillars
		var z: float = -hl + 0.6 + i * (LENGTH - 1.2) / 8.0
		b.box(&"item_matte", Vector3(0, floor_y + 1.75, z), Vector3(WIDTH + 0.03, 1.1, 0.12))
	b.box(&"item_matte", Vector3(0, floor_y + 2.42, 0), Vector3(WIDTH, 0.26, LENGTH), 0.08)
	b.color = Color(0.85, 0.85, 0.85)
	b.box(&"car_trim", Vector3(0, floor_y + 2.6, 1.0), Vector3(1.4, 0.18, 2.2), 0.04)  # roof unit
	# Front: windscreen, destination sign, lights, bumper.
	b.color = Color(0.12, 0.16, 0.2)
	b.box(&"car_glass", Vector3(0, floor_y + 1.55, -hl - 0.01), Vector3(WIDTH - 0.2, 1.3, 0.04))
	b.color = Color(0.1, 0.1, 0.1)
	b.box(&"car_trim", Vector3(0, floor_y + 2.35, -hl - 0.02), Vector3(WIDTH - 0.4, 0.28, 0.04))
	b.color = Color(1, 1, 0.9)
	for x: float in [-hw + 0.3, hw - 0.3]:
		b.box(&"car_headlight", Vector3(x, floor_y + 0.35, -hl - 0.02), Vector3(0.4, 0.18, 0.04))
		b.box(&"car_taillight", Vector3(x, floor_y + 0.35, hl + 0.02), Vector3(0.3, 0.3, 0.04))
	b.color = Color(0.15, 0.15, 0.16)
	b.box(&"car_trim", Vector3(0, floor_y + 0.08, -hl - 0.05), Vector3(WIDTH, 0.22, 0.12))
	b.box(&"car_trim", Vector3(0, floor_y + 0.08, hl + 0.05), Vector3(WIDTH, 0.22, 0.12))
	# Entry door on the right, behind the front axle.
	b.color = Color(0.14, 0.18, 0.22)
	b.box(&"car_glass", Vector3(hw + 0.01, floor_y + 1.1, -hl + 2.2), Vector3(0.04, 2.0, 1.1))
	# Wheels.
	b.color = Color(0.1, 0.1, 0.1)
	for z: float in [-hl + 1.6, hl - 2.2]:
		for x: float in [-hw + 0.25, hw - 0.25]:
			b.cylinder(&"car_tire", Vector3(x - 0.15, 0.48, z), Vector3(x + 0.15, 0.48, z), 0.48, 0.48, 12)
	_mesh = MeshInstance3D.new()
	_mesh.mesh = b.build()
	add_child(_mesh)
	var sign := Label3D.new()
	sign.text = line_text
	sign.font_size = 64
	sign.pixel_size = 0.004
	sign.modulate = Color(1.0, 0.75, 0.2)
	sign.position = Vector3(0, floor_y + 2.35, -hl - 0.05)
	sign.rotation.y = PI
	add_child(sign)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(WIDTH, HEIGHT - 0.3, LENGTH)
	cs.shape = shape
	cs.position = Vector3(0, 0.3 + (HEIGHT - 0.3) / 2.0, 0)
	add_child(cs)


func get_interaction_prompt() -> String:
	return Intro.bus_prompt() if Intro.current else "Bus"


func interact() -> void:
	if Intro.current:
		Intro.current.request_board()
