extends Control
## Temporary world: shows who is connected. Replaced by the 3D greybox in step 2.

@onready var info_label: Label = %InfoLabel
@onready var players_label: Label = %PlayersLabel
@onready var leave_button: Button = %LeaveButton


func _ready() -> void:
	Net.players_changed.connect(_refresh)
	leave_button.pressed.connect(_on_leave_pressed)
	if Net.is_host():
		info_label.text = "You are the HOST (port %d). Items in ItemDB: %d" % [Net.DEFAULT_PORT, ItemDB.get_all_ids().size()]
	else:
		info_label.text = "Connected as client (peer id %d). Items in ItemDB: %d" % [multiplayer.get_unique_id(), ItemDB.get_all_ids().size()]
	_refresh()


func _refresh() -> void:
	var lines: PackedStringArray = ["Players (%d/%d):" % [Net.players.size(), Net.MAX_PLAYERS]]
	for peer_id: int in Net.players:
		var tag: String = " (host)" if peer_id == 1 else ""
		var me: String = "  <- you" if peer_id == multiplayer.get_unique_id() else ""
		lines.append("  - %s%s%s" % [Net.get_player_name(peer_id), tag, me])
	players_label.text = "\n".join(lines)
	print("[World] %s" % " | ".join(lines))


func _on_leave_pressed() -> void:
	Net.leave_game()
	get_tree().change_scene_to_file(Net.MAIN_MENU_SCENE)
