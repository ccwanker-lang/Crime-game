class_name GamepadTest
extends RefCounted
## Self-test check "gamepad" (SelfTest._check_gamepad), session B user list item 5. No real controller: joypad events
## are fed in with Input.parse_input_event and the effects are counted by a small listener node.


class Listener:
	extends Node
	var motion: Vector2 = Vector2.ZERO
	var clicks: int = 0
	var backs: int = 0

	func _input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			motion += (event as InputEventMouseMotion).relative
		elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT \
				and event.pressed:
			clicks += 1
		elif event is InputEventAction and event.is_action_pressed(&"release_mouse"):
			backs += 1


static func run(t: Node, world: Node3D) -> void:
	var tree: SceneTree = t.get_tree()
	var report := func(ok: bool, text: String) -> void: t.call("_report", ok, text)
	var gp: Node = tree.root.get_node("Gamepad")

	# Every action (except drop / lights) has a controller button, stick or trigger.
	var missing: PackedStringArray = []
	for a: Array in Settings.ACTIONS:
		var slot_key: bool = str(a[0]).begins_with("weapon_") and str(a[0]).right(1).is_valid_int()  # (1-8: LB / RB)
		if a[0] in ["drop", "night_lights", "sprint"] or slot_key or not InputMap.has_action(a[0]):
			continue
		var has_pad: bool = false
		for ev: InputEvent in InputMap.action_get_events(a[0]):
			if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
				has_pad = true
		if not has_pad:
			missing.append(a[0])
	report.call(missing.is_empty(), "every action has a controller input (sprint = L3 toggle; slots 1-8 = LB / RB; drop / lights only on "
			+ "the keyboard)%s" % ("" if missing.is_empty() else ": missing " + ", ".join(missing)))

	var press := func(btn: int, on: bool) -> void:
		var e := InputEventJoypadButton.new()
		e.device = 0
		e.button_index = btn as JoyButton
		e.pressed = on
		Input.parse_input_event(e)
		Input.flush_buffered_events()
	var axis := func(ax: int, v: float) -> void:
		var e := InputEventJoypadMotion.new()
		e.device = 0
		e.axis = ax as JoyAxis
		e.axis_value = v
		Input.parse_input_event(e)
		Input.flush_buffered_events()
	press.call(JOY_BUTTON_X, true)
	var interact: bool = Input.is_action_pressed(&"interact")
	press.call(JOY_BUTTON_X, false)
	axis.call(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	var fire: bool = Input.is_action_pressed(&"fire")
	axis.call(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	var fire_off: bool = not Input.is_action_pressed(&"fire")
	axis.call(JOY_AXIS_LEFT_Y, -1.0)
	var fwd: float = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back").y
	axis.call(JOY_AXIS_LEFT_Y, 0.0)
	report.call(interact and fire and fire_off and fwd < -0.9, "X = interact (%s), RT = shoot (%s, released %s), left "
			% [interact, fire, fire_off] + "stick forward = move (%.2f)" % fwd)

	# Right stick look = mouse motion; A / B in menus = click / back.
	var lis := Listener.new()
	world.add_child(lis)
	await tree.process_frame
	gp.call("look", Vector2(1.0, 0.0), 0.1)
	Input.flush_buffered_events()
	await tree.process_frame
	var want: float = 1500.0 * Settings.stick_sensitivity * 0.1
	var looked: bool = absf(lis.motion.x - want) < 1.0 and absf(lis.motion.y) < 0.01
	report.call(looked, "right stick look sends mouse motion (%.0f px for a full push for 0.1 s, want %.0f): turning, "
			% [lis.motion.x, want] + "cars, aiming and invert Y work as with the mouse")
	var c0: int = int(gp.get("clicks"))
	press.call(JOY_BUTTON_A, true)
	press.call(JOY_BUTTON_A, false)
	press.call(JOY_BUTTON_B, true)
	press.call(JOY_BUTTON_B, false)
	Input.flush_buffered_events()
	await tree.process_frame
	await tree.process_frame
	var menu_ok: bool = Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
	report.call(not menu_ok or (int(gp.get("clicks")) == c0 + 1 and lis.clicks >= 1 and lis.backs >= 1),
			"menus (pointer visible): A clicks where the pointer is (%d), B = back (%d)" % [lis.clicks, lis.backs])
	lis.queue_free()

	gp.call("_set_sprint", true)
	var sprint_on: bool = Input.is_action_pressed(&"sprint")
	gp.call("_set_sprint", false)
	var xb: Array = Gamepad.layout("xbox")
	var ps: Array = Gamepad.layout("playstation")
	report.call(sprint_on and not Input.is_action_pressed(&"sprint") and xb[2][1] == "A" and ps[2][1] == "Cross"
			and xb.size() == ps.size(), "sprint toggle holds the sprint action; button names per controller "
			+ "(Xbox %s / PlayStation %s)" % [xb[2][1], ps[2][1]])

	Settings.open_menu()
	await tree.process_frame
	var menu: Node = Settings.get("_menu")
	var tab: Node = menu.find_child("Controller", true, false) if menu else null
	var rows: bool = tab != null and tab.find_child("PadName", true, false) != null
	if menu:
		menu.call("close_menu")
	report.call(rows, "Settings has a Controller tab (controller name, look speed, vibration, the layout)")
