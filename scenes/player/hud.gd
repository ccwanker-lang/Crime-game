class_name PlayerHUD
extends CanvasLayer
## On-screen info of the local player: health, ammo, cash, hitmarker, damage
## flash and the death screen. Only exists on the owning peer.

@onready var health_bar: ProgressBar = %HealthBar
@onready var health_label: Label = %HealthLabel
@onready var ammo_label: Label = %AmmoLabel
@onready var weapon_label: Label = %WeaponLabel
@onready var cash_label: Label = %CashLabel
@onready var death_panel: PanelContainer = %DeathPanel
@onready var death_label: Label = %DeathLabel
@onready var damage_flash: ColorRect = %DamageFlash
@onready var hitmarker: Control = %Hitmarker

var _hit_time: float = 0.0
var _hit_color: Color = Color.WHITE
var _respawn_at: float = 0.0
var _death_text: String = ""


func _ready() -> void:
	hitmarker.draw.connect(_draw_hitmarker)
	death_panel.visible = false
	damage_flash.color.a = 0.0


func set_health(hp: int, max_hp: int) -> void:
	health_bar.max_value = max_hp
	health_bar.value = hp
	health_label.text = "%d" % hp
	var low: bool = hp <= max_hp * 0.3
	health_label.add_theme_color_override("font_color", Color(1, 0.35, 0.3) if low else Color.WHITE)


func set_ammo(weapon_name: String, mag: int, reserve: int, drawn: bool, reloading: bool) -> void:
	weapon_label.text = weapon_name if drawn else "Hands"
	if not drawn:
		ammo_label.text = ""
	elif reloading:
		ammo_label.text = "Reloading..."
	else:
		ammo_label.text = "%d / %d" % [mag, reserve]
	ammo_label.add_theme_color_override("font_color", Color(1, 0.4, 0.3) if drawn and mag == 0 else Color.WHITE)


func set_cash(cash: int) -> void:
	cash_label.text = "€ %d" % cash


func flash_damage(amount: int) -> void:
	damage_flash.color.a = clampf(0.15 + amount / 100.0, 0.2, 0.55)


func show_hitmarker(headshot: bool, killed: bool) -> void:
	_hit_time = 0.25 if killed else 0.15
	_hit_color = Color(1, 0.25, 0.2) if killed else (Color(1, 0.85, 0.3) if headshot else Color.WHITE)
	hitmarker.queue_redraw()


func show_death(dropped_text: String, respawn_seconds: float) -> void:
	_death_text = dropped_text
	_respawn_at = Time.get_ticks_msec() / 1000.0 + respawn_seconds
	death_panel.visible = true


func hide_death() -> void:
	death_panel.visible = false


func _process(delta: float) -> void:
	damage_flash.color.a = move_toward(damage_flash.color.a, 0.0, delta * 0.8)
	if _hit_time > 0.0:
		_hit_time -= delta
		hitmarker.queue_redraw()
	if death_panel.visible:
		var left: float = maxf(0.0, _respawn_at - Time.get_ticks_msec() / 1000.0)
		death_label.text = "YOU DIED\n%s\nRespawning at the hospital in %d s" % [_death_text, ceili(left)]


func _draw_hitmarker() -> void:
	if _hit_time <= 0.0:
		return
	var c: Vector2 = hitmarker.size / 2.0
	for d: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		hitmarker.draw_line(c + d * 6.0, c + d * 13.0, _hit_color, 2.0, true)
