extends Camera3D
## TEMPORARY debug camera for step 2 (the player replaces it in step 3).
## Hold right mouse button to look around, WASD to move, Q/E down/up, Shift = fast.

const SPEED: float = 12.0
const FAST_MULTIPLIER: float = 3.0
const MOUSE_SENSITIVITY: float = 0.003

var _yaw: float = 0.0
var _pitch: float = 0.0


func _ready() -> void:
	look_at(Vector3(0, 0, 0))
	_yaw = rotation.y
	_pitch = rotation.x


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		_yaw -= motion.relative.x * MOUSE_SENSITIVITY
		_pitch = clampf(_pitch - motion.relative.y * MOUSE_SENSITIVITY, -1.5, 1.5)
		rotation = Vector3(_pitch, _yaw, 0.0)


func _process(delta: float) -> void:
	var dir := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W): dir -= basis.z
	if Input.is_physical_key_pressed(KEY_S): dir += basis.z
	if Input.is_physical_key_pressed(KEY_A): dir -= basis.x
	if Input.is_physical_key_pressed(KEY_D): dir += basis.x
	if Input.is_physical_key_pressed(KEY_E): dir += Vector3.UP
	if Input.is_physical_key_pressed(KEY_Q): dir -= Vector3.UP
	var speed: float = SPEED * (FAST_MULTIPLIER if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0)
	position += dir.normalized() * speed * delta
