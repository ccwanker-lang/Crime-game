class_name DialogueBox
extends Control
## NOTES part 20: the NPC text box (owner only, in the player's HUD layer): the speaker's name, the text (typed out,
## click / Space shows all), answer buttons (also keys 1-4). Pages come from a DialogueData (answers lead to other
## pages and can start a mission or finish the mission step with this NPC), or from plain lines (Continue).
## Esc or walking away closes it. Made by `Missions._show_talk`.

const GOLD := Color(1.0, 0.8, 0.25)
const CHARS_PER_SECOND: float = 55.0
const WALK_AWAY: float = 7.0

var player: Player
var npc_id: StringName = &""
var who: String = ""
var data: DialogueData
var lines: PackedStringArray = []
## A mission step's talk: when the dialogue has no FINISH_STEP answer, reaching its end finishes the step.
var for_step: bool = false
var node: DialogueNode
var line_index: int = 0
var finished_step: bool = false
## Tests: the answers on screen now.
var shown: Array[DialogueChoice] = []

var _speaker: Label
var _text: Label
var _choices: VBoxContainer
var _typed: float = 0.0


static func open_for(p: Player, id: StringName, name_text: String, d: DialogueData, l: PackedStringArray, step: bool) -> DialogueBox:
	var box := p.ui.get_node_or_null("DialogueBox") as DialogueBox if p.ui else null
	if box == null:
		box = DialogueBox.new()
		box.name = "DialogueBox"
		box.player = p
		if p.ui:
			p.ui.add_child(box)
	box.start(id, name_text, d, l, step)
	return box


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme_res: Theme = load("res://assets/ui/game_theme.tres") as Theme
	if theme_res:
		theme = theme_res
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left = -420
	panel.offset_right = 420
	panel.offset_top = -330
	panel.offset_bottom = -132
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.05, 0.06, 0.08, 0.92)
	st.border_color = GOLD.darkened(0.25)
	st.border_width_top = 3
	st.set_corner_radius_all(14)
	st.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", st)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	_speaker = Label.new()
	_speaker.add_theme_font_size_override("font_size", 22)
	_speaker.add_theme_color_override("font_color", GOLD)
	box.add_child(_speaker)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(0, 54)
	_text.add_theme_font_size_override("font_size", 19)
	box.add_child(_text)
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 4)
	box.add_child(_choices)
	visible = false


func start(id: StringName, name_text: String, d: DialogueData, l: PackedStringArray, step: bool) -> void:
	npc_id = id
	who = name_text
	data = d
	lines = l
	for_step = step
	finished_step = false
	line_index = 0
	visible = true
	if player and not player.auto_walk:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if data:
		_show_node(data.entry())
	else:
		_show_line()


func _show_node(n: DialogueNode) -> void:
	node = n
	if n == null:
		close()
		return
	_set_text(n.speaker if n.speaker != "" else (data.speaker if data.speaker != "" else who), n.text)
	shown = n.visible_choices()
	var buttons: Array = []
	for c: DialogueChoice in shown:
		buttons.append([c.text, _pick.bind(c)])
	if shown.is_empty():
		buttons.append(["Continue" if n.next != &"" else "Bye", _continue_node])
	_fill(buttons)


func _show_line() -> void:
	node = null
	shown = []
	if line_index >= lines.size():
		close()
		return
	_set_text(who, lines[line_index])
	_fill([["Continue" if line_index < lines.size() - 1 else "Bye", _next_line]])


func _set_text(speaker: String, text: String) -> void:
	_speaker.text = speaker
	_text.text = text
	_text.visible_characters = 0
	_typed = 0.0


func _fill(buttons: Array) -> void:
	for c: Node in _choices.get_children():
		c.queue_free()
	for i: int in buttons.size():
		var b := Button.new()
		b.text = "%d.  %s" % [i + 1, buttons[i][0]]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 17)
		b.pressed.connect(buttons[i][1])
		_choices.add_child(b)


## Pick answer `i` on screen (keys 1-4, tests).
func choose(i: int) -> void:
	var live: Array = _choices.get_children().filter(func(b: Node) -> bool: return not b.is_queued_for_deletion())
	if i >= 0 and i < live.size():
		(live[i] as Button).pressed.emit()


func _pick(c: DialogueChoice) -> void:
	match c.action:
		DialogueChoice.Action.START_MISSION:
			Missions.request_start(c.mission)
		DialogueChoice.Action.FINISH_STEP:
			finished_step = true
			Missions.request_step_done(npc_id)
	if c.next == &"":
		close()
	else:
		_show_node(data.get_node_by_id(c.next))


func _continue_node() -> void:
	if node and node.next != &"":
		_show_node(data.get_node_by_id(node.next))
	else:
		close()


func _next_line() -> void:
	line_index += 1
	_show_line()


func _has_finish(d: DialogueData) -> bool:
	for n: DialogueNode in d.nodes:
		for c: DialogueChoice in n.choices:
			if c.action == DialogueChoice.Action.FINISH_STEP:
				return true
	return false


func close() -> void:
	if not visible:
		return
	visible = false
	if for_step and not finished_step and data and not _has_finish(data):
		finished_step = true
		Missions.request_step_done(npc_id)
	if player and not player.auto_walk:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	if not visible:
		return
	if _text.visible_characters >= 0 and _text.visible_characters < _text.text.length():
		_typed += delta * CHARS_PER_SECOND
		_text.visible_characters = mini(int(_typed), _text.text.length())
	var npc: Node3D = Missions.mission_npc(npc_id)
	if player and (player.dead or (npc and player.global_position.distance_to(npc.global_position) > WALK_AWAY)):
		close()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("release_mouse"):
		close()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k: Key = (event as InputEventKey).physical_keycode
		if k >= KEY_1 and k <= KEY_4:
			choose(k - KEY_1)
			get_viewport().set_input_as_handled()
		elif k == KEY_SPACE and _text.visible_characters < _text.text.length():
			_text.visible_characters = -1
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()  # (E doesn't talk again while the box is open)
