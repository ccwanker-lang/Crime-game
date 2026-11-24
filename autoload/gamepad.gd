extends Node
## Controller support (session B, user list item 5): Xbox, PlayStation and other SDL game controllers.
## - Buttons / sticks / triggers are ordinary InputMap events (project.godot: every action has its pad event), so the
##   game code needs nothing new. Layout: see LAYOUT (shown per controller type in Settings > Controller).
## - Looking: the right stick sends synthetic InputEventMouseMotion while you play (mouse captured), so on foot, in
##   the car, aiming (slower when zoomed), sway, sensitivity and invert Y all work exactly like the mouse.
## - Sprint: L3 / L1-stick click toggles sprinting; it stops when you stop moving.
## - Menus and windows (mouse visible): the left stick moves the pointer, A / Cross clicks, B / Circle = back
##   (Esc), the right stick scrolls. So every mouse menu works without extra focus code.
## - Rumble on hits taken and own shots (Settings.vibration).

const DEADZONE: float = 0.18
## Right stick at full tilt = this many "mouse pixels" per second (times Settings.stick_sensitivity).
const LOOK_SPEED: float = 1500.0
const CURSOR_SPEED: float = 1100.0
const SCROLL_EVERY: float = 0.09
const BTN_A: int = 0
const BTN_B: int = 1
const BTN_L3: int = 7

## [action label, Xbox, PlayStation]
const LAYOUT: Array = [
	["Move / look", "Left stick / right stick", "Left stick / right stick"],
	["Sprint (toggle)", "Left stick click", "L3"],
	["Jump", "A", "Cross"],
	["Crouch", "B", "Circle"],
	["Interact / talk / use", "X", "Square"],
	["Reload", "Y", "Triangle"],
	["Shoot / aim", "RT / LT", "R2 / L2"],
	["Previous / next slot", "LB / RB", "L1 / R1"],
	["Enter / leave car", "D-pad up", "D-pad up"],
	["Holster weapon", "D-pad down", "D-pad down"],
	["Build mode", "D-pad left", "D-pad left"],
	["Last weapon", "D-pad right", "D-pad right"],
	["First / third person", "Right stick click", "R3"],
	["Horn (in a car)", "Left stick click", "L3"],
	["Phone", "View", "Touchpad / Share"],
	["Pause menu / back", "Menu", "Options"],
]

var device: int = -1
var sprint_latched: bool = false
## Events this node made itself (tests count them).
var looks: int = 0
var clicks: int = 0
var _scroll_t: float = 0.0
var _a_down: bool = false
var _last_health: int = -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.joy_connection_changed.connect(_on_joy_changed)
	_pick_device()


func _on_joy_changed(_dev: int, _connected: bool) -> void:
	_pick_device()
	print("[Gamepad] %s" % (pad_name() if connected() else "no controller"))


func _pick_device() -> void:
	var pads: Array[int] = Input.get_connected_joypads()
	device = pads[0] if not pads.is_empty() else -1


func connected() -> bool:
	return device >= 0


func pad_name() -> String:
	return Input.get_joy_name(device) if connected() else ""


## "playstation" or "xbox" (also for unknown pads: the most common button names).
func pad_kind() -> String:
	var n: String = pad_name().to_lower()
	for k: String in ["ps3", "ps4", "ps5", "playstation", "dualshock", "dualsense", "sony"]:
		if k in n:
			return "playstation"
	return "xbox"


## [[label, button]] for this kind of controller.
static func layout(kind: String) -> Array:
	var out: Array = []
	for row: Array in LAYOUT:
		out.append([row[0], row[2] if kind == "playstation" else row[1]])
	return out


static func stick(dev: int, ax: JoyAxis, ay: JoyAxis) -> Vector2:
	var v := Vector2(Input.get_joy_axis(dev, ax), Input.get_joy_axis(dev, ay))
	var l: float = v.length()
	if l < DEADZONE:
		return Vector2.ZERO
	# Rescale past the dead zone, then a soft curve (fine aim near the centre, full speed at the edge).
	var t: float = clampf((l - DEADZONE) / (1.0 - DEADZONE), 0.0, 1.0)
	return v / l * t * t


func _process(delta: float) -> void:
	if not connected():
		return
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look(stick(device, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y), delta)
		_sprint()
		_rumble_on_hit()
	else:
		if sprint_latched:
			_set_sprint(false)
		_cursor(stick(device, JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y), delta)
		_scroll(stick(device, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y), delta)


## Right stick -> mouse motion (the player turns exactly as with the mouse).
func look(v: Vector2, delta: float) -> void:
	if v == Vector2.ZERO:
		return
	var ev := InputEventMouseMotion.new()
	ev.relative = v * LOOK_SPEED * Settings.stick_sensitivity * delta
	ev.screen_relative = ev.relative
	Input.parse_input_event(ev)
	looks += 1


func _sprint() -> void:
	if not sprint_latched:
		return
	if stick(device, JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y).length() < 0.05:
		_set_sprint(false)  # (stopped walking)


func _set_sprint(on: bool) -> void:
	sprint_latched = on
	if on:
		Input.action_press(&"sprint")
	else:
		Input.action_release(&"sprint")


func _cursor(v: Vector2, delta: float) -> void:
	if v == Vector2.ZERO:
		return
	var vp: Viewport = get_viewport()
	var size: Vector2 = vp.get_visible_rect().size
	var pos: Vector2 = (vp.get_mouse_position() + v * CURSOR_SPEED * delta).clamp(Vector2.ZERO, size - Vector2.ONE)
	vp.warp_mouse(pos)


func _scroll(v: Vector2, delta: float) -> void:
	_scroll_t -= delta
	if absf(v.y) < 0.3 or _scroll_t > 0.0:
		return
	_scroll_t = SCROLL_EVERY / maxf(absf(v.y), 0.3)
	_mouse_button(MOUSE_BUTTON_WHEEL_DOWN if v.y > 0.0 else MOUSE_BUTTON_WHEEL_UP, true)
	_mouse_button(MOUSE_BUTTON_WHEEL_DOWN if v.y > 0.0 else MOUSE_BUTTON_WHEEL_UP, false)


func _mouse_button(index: MouseButton, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = index
	ev.pressed = pressed
	ev.position = get_viewport().get_mouse_position()
	ev.global_position = ev.position
	if index == MOUSE_BUTTON_LEFT:
		ev.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(ev)


func _input(event: InputEvent) -> void:
	var b := event as InputEventJoypadButton
	if b == null:
		return
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if b.button_index == BTN_L3 and b.pressed:
			_set_sprint(not sprint_latched)
		return
	# Menus / windows: A clicks where the pointer is, B goes back. (Handled: no ui_accept on a focused button too.)
	if b.button_index == BTN_A and b.pressed != _a_down:
		_a_down = b.pressed
		_mouse_button(MOUSE_BUTTON_LEFT, b.pressed)
		if b.pressed:
			clicks += 1
		get_viewport().set_input_as_handled()
	elif b.button_index == BTN_B and b.pressed:
		var back := InputEventAction.new()
		back.action = &"release_mouse"
		back.pressed = true
		Input.parse_input_event(back)
		get_viewport().set_input_as_handled()


## Short rumble (both motors) if the player wants it.
func rumble(weak: float, strong: float, seconds: float) -> void:
	if connected() and Settings.vibration:
		Input.start_joy_vibration(device, weak, strong, seconds)


## Soundscape.heard_shot: our own shot (right at the camera) gives a small kick.
func heard_shot(dist: float) -> void:
	if dist < 3.0 and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rumble(0.5, 0.2, 0.08)


func _rumble_on_hit() -> void:
	var scene: Node = get_tree().current_scene
	var players: Node = scene.get_node_or_null(^"Players") if scene else null
	var me := players.get_node_or_null(str(multiplayer.get_unique_id())) as Player if players and multiplayer.has_multiplayer_peer() else null
	if me == null:
		_last_health = -1
		return
	if _last_health >= 0 and me.health < _last_health:
		rumble(0.3, 0.8, 0.25)
	_last_health = me.health
