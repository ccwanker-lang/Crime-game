extends CharacterBody3D
## TEMPORARY first-person walker to look around the map like a player until the
## real player controller (step 3) replaces it. Not networked: every instance
## walks around with its own local viewer.
## WASD walk, Shift sprint, Space jump, E interact, Esc frees the mouse.

const WALK_SPEED: float = 4.0
const SPRINT_SPEED: float = 7.0
const JUMP_VELOCITY: float = 4.6
const ACCEL: float = 12.0
const MOUSE_SENSITIVITY: float = 0.0022
const STEP_HEIGHT: float = 0.35
const INTERACT_DISTANCE: float = 3.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var prompt_label: Label = %PromptLabel
@onready var fps_label: Label = %FpsLabel

## Test mode (scripts/debug/self_test.gd): walk straight to auto_target, no
## mouse/camera. The same movement code as a real walk, so doors/steps are tested.
var auto_walk: bool = false
var auto_target: Vector3 = Vector3.ZERO

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _focused: Node = null


func _ready() -> void:
	if auto_walk:
		$UI.visible = false
		set_process_unhandled_input(false)
		return
	camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		rotate_y(-motion.relative.x * MOUSE_SENSITIVITY)
		head.rotation.x = clampf(head.rotation.x - motion.relative.y * MOUSE_SENSITIVITY, -1.5, 1.5)
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.physical_keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif key.physical_keycode == KEY_E and _focused != null:
			_focused.call("interact")


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif Input.is_physical_key_pressed(KEY_SPACE) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		velocity.y = JUMP_VELOCITY

	var input := Vector2.ZERO
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		input.x = float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
		input.y = float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	var dir: Vector3 = (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	if auto_walk:
		dir = Vector3(auto_target.x - global_position.x, 0, auto_target.z - global_position.z)
		dir = dir.normalized() if dir.length() > 0.1 else Vector3.ZERO
	var speed: float = SPRINT_SPEED if Input.is_physical_key_pressed(KEY_SHIFT) else WALK_SPEED
	var target := dir * speed
	velocity.x = move_toward(velocity.x, target.x, ACCEL * speed * delta)
	velocity.z = move_toward(velocity.z, target.z, ACCEL * speed * delta)

	_try_step_up(delta)
	move_and_slide()
	if auto_walk:
		return
	_update_focus()
	fps_label.text = "%d FPS" % Engine.get_frames_per_second()


## Lets the player walk up curbs and doorsteps: if moving forward is blocked but
## the same move one step higher is free, lift the body; floor snap does the rest.
func _try_step_up(delta: float) -> void:
	if not is_on_floor():
		return
	var motion := Vector3(velocity.x, 0, velocity.z) * delta
	if motion.length() < 0.001:
		return
	if not test_move(global_transform, motion):
		return
	var raised := global_transform.translated(Vector3.UP * STEP_HEIGHT)
	if test_move(global_transform, Vector3.UP * STEP_HEIGHT) or test_move(raised, motion):
		return
	# Find the actual step height by moving down from the raised spot.
	var collision := KinematicCollision3D.new()
	var ahead := raised.translated(motion.normalized() * 0.1)
	if test_move(ahead, Vector3.DOWN * STEP_HEIGHT, collision):
		var lift: float = STEP_HEIGHT - collision.get_travel().length()
		if lift > 0.01:
			global_position.y += lift + 0.01


func _update_focus() -> void:
	var space := get_world_3d().direct_space_state
	var from: Vector3 = camera.global_position
	var to: Vector3 = from - camera.global_basis.z * INTERACT_DISTANCE
	var query := PhysicsRayQueryParameters3D.create(from, to, collision_mask, [get_rid()])
	var hit: Dictionary = space.intersect_ray(query)
	var found: Node = null
	if not hit.is_empty():
		var n: Node = hit["collider"]
		while n != null and not n.is_in_group("interactable"):
			n = n.get_parent()
		found = n
	_focused = found
	prompt_label.text = "[E] %s" % _focused.call("get_interaction_prompt") if _focused else ""
