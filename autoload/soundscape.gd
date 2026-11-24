extends Node
## Sound + atmosphere (session B, user list item 2). Local on every peer (nothing networked):
## - Zone ambience on the "Ambience" bus: city, village by day / by night, docks, forest + mountains (also the army
##   base and the prison: open land with wind), bunker. Crossfades when you walk from one zone into the next; softer
##   indoors (something solid over your head).
## - Music on the "Music" bus: calm by day, calm by night, tense while you have wanted stars, took damage or a shot was
##   fired within COMBAT_RANGE (it stays tense COMBAT_HOLD s after the last one).
## - Footsteps: a `Footsteps` node on every Player (scripts/player/footsteps.gd).
## Sounds: assets/audio/ambience (tools/generators/gen_ambience.py) + assets/audio/music (CC0, see CREDITS.md).
## Off in headless runs; `--no-music` / `--no-ambience` switch a part off.

const AMBIENCE: Dictionary = {
	"city": ["res://assets/audio/ambience/city.ogg", -4.0],
	"village_day": ["res://assets/audio/ambience/village_day.ogg", -2.0],
	"village_night": ["res://assets/audio/ambience/village_night.ogg", -3.0],
	"docks": ["res://assets/audio/ambience/docks.ogg", -2.0],
	"forest": ["res://assets/audio/ambience/forest.ogg", -3.0],
	"bunker": ["res://assets/audio/ambience/bunker.ogg", -12.0],
}
const MUSIC: Dictionary = {
	"calm_day": ["res://assets/audio/music/calm_day.ogg", -12.0],
	"calm_night": ["res://assets/audio/music/calm_night.ogg", -3.0],
	"tense": ["res://assets/audio/music/tense.ogg", -9.0],
}
## Title page music (user list item 3).
const MENU_SCENE: String = "res://scenes/main_menu/main_menu.tscn"
const MENU_MUSIC: String = "calm_night"
const AMB_FADE: float = 3.0
const MUSIC_FADE: float = 2.5
const COMBAT_RANGE: float = 90.0
const COMBAT_HOLD: float = 25.0
const INDOOR_DB: float = -9.0
## The village's play area (gen_world PLAY grown a bit): outside it (and outside the zones) = forest / mountains.
const VILLAGE_RECT: Rect2 = Rect2(-200, -140, 290, 260)
## Harbour + quay (west side, Quay Road z 84 and south of it).
const DOCKS_RECT: Rect2 = Rect2(-200, 70, 95, 60)
const DAY_FROM: float = 6.0
const DAY_TO: float = 21.0

var enabled_ambience: bool = true
var enabled_music: bool = true
var zone_key: String = ""
var music_key: String = ""
var indoors: bool = false
var _amb: Array[AudioStreamPlayer] = []
var _mus: Array[AudioStreamPlayer] = []
var _amb_on: int = 0
var _mus_on: int = 0
var _combat_until: float = 0.0
var _last_health: int = -1
var _timer: float = 0.0
var _streams: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args: PackedStringArray = OS.get_cmdline_user_args()
	enabled_ambience = DisplayServer.get_name() != "headless" and not "--no-ambience" in args
	enabled_music = DisplayServer.get_name() != "headless" and not "--no-music" in args
	for i: int in 2:
		_amb.append(_player(&"Ambience"))
		_mus.append(_player(&"Music"))
	get_tree().node_added.connect(_on_node_added)


func _player(bus: StringName) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.set_meta(&"keep_bus", true)
	p.bus = bus
	p.volume_db = -80.0
	add_child(p)
	return p


func _on_node_added(n: Node) -> void:
	if n is Player:
		var fs := Footsteps.new()
		fs.name = "Footsteps"
		n.add_child.call_deferred(fs)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


## Wildlife.scare_at calls this for every shot on every peer.
func heard_shot(pos: Vector3) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam and cam.global_position.distance_to(pos) < COMBAT_RANGE:
		_combat_until = _now() + COMBAT_HOLD
	if cam:
		Gamepad.heard_shot(cam.global_position.distance_to(pos))  # (controller rumble on your own shot)


# --- Decisions (also used by the self-test) ------------------------------------------

## Which ambience loop belongs at `pos` at `hours`.
static func zone_key_at(pos: Vector3, hours: float) -> String:
	var z: StringName = Zones.zone_at(pos)
	if z == &"bunker":
		return "bunker"
	if z == &"city":
		return "city"
	var day: bool = hours >= DAY_FROM and hours < DAY_TO
	if z == &"army":
		return "forest"
	var p := Vector2(pos.x, pos.z)
	if DOCKS_RECT.has_point(p):
		return "docks"
	if z == &"slums" or VILLAGE_RECT.has_point(p):
		return "village_day" if day else "village_night"
	return "forest"


func music_key_for(me: Player, hours: float) -> String:
	if me and (me.wanted_stars > 0 or _now() < _combat_until):
		return "tense"
	return "calm_day" if hours >= DAY_FROM and hours < DAY_TO else "calm_night"


# --- Running ------------------------------------------------------------------------

func _process(delta: float) -> void:
	var me: Player = _local_player()
	if me == null:
		var scene: Node = get_tree().current_scene
		if enabled_music and scene and scene.scene_file_path == MENU_SCENE:
			for p: AudioStreamPlayer in _amb:  # (title page: only the menu music)
				p.volume_db = linear_to_db(maxf(move_toward(db_to_linear(p.volume_db), 0.0, delta / 1.5), 0.0005))
			_drive(_mus, MUSIC, MENU_MUSIC, MUSIC_FADE, 0.0, delta, false)
			return
		_fade_all(delta)
		return
	if _last_health >= 0 and me.health < _last_health:
		_combat_until = _now() + COMBAT_HOLD
	_last_health = me.health
	_timer -= delta
	if _timer <= 0.0:
		_timer = 0.5
		var dn := get_tree().get_first_node_in_group(&"day_night") as DayNight
		var h: float = dn.hours if dn else 12.0
		var cam: Camera3D = get_viewport().get_camera_3d()
		var at: Vector3 = cam.global_position if cam else me.global_position
		zone_key = zone_key_at(at, h)
		music_key = music_key_for(me, h)
		indoors = _roof_over(at)
	if enabled_ambience:
		_drive(_amb, AMBIENCE, zone_key, AMB_FADE, INDOOR_DB if indoors else 0.0, delta, true)
	if enabled_music:
		_drive(_mus, MUSIC, music_key, MUSIC_FADE, 0.0, delta, false)


func _local_player() -> Player:
	if not multiplayer.has_multiplayer_peer():
		return null
	var players: Node = get_tree().current_scene.get_node_or_null(^"Players") if get_tree().current_scene else null
	if players == null:
		return null
	return players.get_node_or_null(str(multiplayer.get_unique_id())) as Player


## Two players per layer: the one for `key` fades in (starting it if needed), the other fades out.
func _drive(pair: Array[AudioStreamPlayer], table: Dictionary, key: String, fade: float, extra_db: float,
		delta: float, is_amb: bool) -> void:
	var on: int = _amb_on if is_amb else _mus_on
	var cur: AudioStreamPlayer = pair[on]
	if key != "" and str(cur.get_meta(&"key", "")) != key:
		on = 1 - on
		cur = pair[on]
		cur.stream = _stream(table[key][0])
		cur.set_meta(&"key", key)
		print("[Soundscape] %s -> %s" % ["ambience" if is_amb else "music", key])
		cur.volume_db = -60.0
		cur.play(randf() * 20.0 if is_amb else 0.0)
		if is_amb:
			_amb_on = on
		else:
			_mus_on = on
	for i: int in 2:
		var p: AudioStreamPlayer = pair[i]
		var k: String = str(p.get_meta(&"key", ""))
		var target: float = (float(table[k][1]) + extra_db) if i == on and k != "" and table.has(k) else -60.0
		var lin: float = move_toward(db_to_linear(p.volume_db), db_to_linear(target), delta / fade)
		p.volume_db = linear_to_db(maxf(lin, 0.0005))
		if i != on and p.playing and p.volume_db <= -59.0:
			p.stop()


func _fade_all(delta: float) -> void:
	for p: AudioStreamPlayer in _amb + _mus:
		if p.playing:
			p.volume_db = linear_to_db(maxf(move_toward(db_to_linear(p.volume_db), 0.0, delta / 1.5), 0.0005))
			if p.volume_db <= -59.0:
				p.stop()
				p.set_meta(&"key", "")


func _stream(path: String) -> AudioStream:
	if not _streams.has(path):
		var s: AudioStream = load(path)
		if s is AudioStreamOggVorbis:
			(s as AudioStreamOggVorbis).loop = true
		_streams[path] = s
	return _streams[path]


func _roof_over(at: Vector3) -> bool:
	var world := get_viewport().get_world_3d()
	if world == null:
		return false
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.3, at + Vector3.UP * 25.0, 1)
	return not world.direct_space_state.intersect_ray(q).is_empty()
