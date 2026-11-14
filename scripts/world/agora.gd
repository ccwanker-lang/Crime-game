@tool
class_name Agora
extends StaticBody3D
## Point 46 (= 13): the "agora", a fenced mini football pitch next to the park. Built in code
## (artificial turf, lines, wooden kickboards with a gate in the middle of the south (+Z)
## side, posts + wires up to 3.2 m, two small goals, a score board). Pitch length along
## local X, centred on the node.
## The ball (every peer): the HOST simulates it and sends its state (pos, vel, score) on
## every kick / goal and once a second; the other peers run the same simple roll + bounce
## in between. Anyone walking into the ball kicks it (host checks players and NPCs).
## Matches (host): now and then (daytime) World spawns 2-4 ParkGoers with role FOOTBALL
## in two shirt colours; `football_step` is their brain. They leave when the match is over.

const LENGTH: float = 18.0
const WIDTH: float = 11.0
const TURF_TOP: float = 0.05
const BOARD_H: float = 1.0
const FENCE_H: float = 3.2
const GATE_W: float = 1.6
const GOAL_HALF: float = 1.5   # half the goal mouth (along Z)
const GOAL_H: float = 1.6
const GOAL_DEPTH: float = 0.8
const BALL_R: float = 0.11
const FRICTION: float = 0.45   # speed kept per second (rolling on turf)
const BOUNCE: float = 0.6
const KICK_REACH: float = 0.6
const TEAM_NAMES: Array[String] = ["RED", "BLUE"]

## Host: a match starts now and then between these hours (and never at night).
@export var play_hours: Vector2 = Vector2(9.0, 20.0)
## Host: chance per check (every 20 s) that a match starts when none is on.
@export var match_chance: float = 0.12

## Every peer: the ball, in local space (y = on the turf).
var ball_pos: Vector3 = Vector3(0, TURF_TOP + BALL_R, 0)
var ball_vel: Vector3 = Vector3.ZERO
var score: Array[int] = [0, 0]
## Host: the players of the current match (ParkGoers) and when it ends.
var players: Array[ParkGoer] = []
var match_end: float = 0.0
## Tests / scenario: count kicks and goals.
var kicks: int = 0
var goals: int = 0

var _ball: MeshInstance3D
var _board: Label3D
var _goal_label: Label3D
var _last_kick: Dictionary = {}  # Node -> seconds
var _resend: float = 0.0
var _goal_wait: float = 0.0


func _ready() -> void:
	_build()
	if Engine.is_editor_hint():
		return
	add_to_group(&"agora")
	_build_ball()
	if _is_host():
		_match_loop.call_deferred()


func _is_host() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


# --- Geometry (editor + game) -----------------------------------------------------------

func _build() -> void:
	_segments.clear()
	for c: Node in get_children():
		if c.has_meta(&"generated"):
			c.free()
	var hl: float = LENGTH / 2.0
	var hw: float = WIDTH / 2.0
	var b := MeshBuilder.new()
	# Turf (two tones in stripes) + collision so the navmesh lies on top.
	for i: int in 9:
		var x0: float = -hl + LENGTH / 9.0 * i
		b.color = Color(0.22, 0.48, 0.2) if i % 2 == 0 else Color(0.25, 0.53, 0.23)
		b.box(&"item_matte", Vector3(x0 + LENGTH / 18.0, TURF_TOP / 2.0, 0), Vector3(LENGTH / 9.0, TURF_TOP, WIDTH))
	_collision(Vector3(0, TURF_TOP / 2.0, 0), Vector3(LENGTH, TURF_TOP, WIDTH))
	# Lines.
	b.color = Color(0.93, 0.93, 0.9)
	var y: float = TURF_TOP + 0.004
	var lw: float = 0.07
	var inset: float = 0.35
	_line(b, Vector3(-hl + inset, y, -hw + inset), Vector3(hl - inset, y, -hw + inset), lw)
	_line(b, Vector3(-hl + inset, y, hw - inset), Vector3(hl - inset, y, hw - inset), lw)
	_line(b, Vector3(-hl + inset, y, -hw + inset), Vector3(-hl + inset, y, hw - inset), lw)
	_line(b, Vector3(hl - inset, y, -hw + inset), Vector3(hl - inset, y, hw - inset), lw)
	_line(b, Vector3(0, y, -hw + inset), Vector3(0, y, hw - inset), lw)
	for i: int in 20:
		var a0: float = TAU * i / 20.0
		var a1: float = TAU * (i + 1) / 20.0
		_line(b, Vector3(cos(a0) * 1.6, y, sin(a0) * 1.6), Vector3(cos(a1) * 1.6, y, sin(a1) * 1.6), lw)
	for s: float in [-1.0, 1.0]:
		var gx: float = s * (hl - inset)
		var bx: float = s * (hl - inset - 2.2)
		_line(b, Vector3(gx, y, -2.6), Vector3(bx, y, -2.6), lw)
		_line(b, Vector3(gx, y, 2.6), Vector3(bx, y, 2.6), lw)
		_line(b, Vector3(bx, y, -2.6), Vector3(bx, y, 2.6), lw)
	# Kickboards (planks) all round, a gate in the middle of the +Z side.
	var t: float = 0.08
	b.color = Color.WHITE
	_wall(b, Vector3(-hl, 0, -hw - t / 2.0), Vector3(hl, 0, -hw - t / 2.0), t)
	_wall(b, Vector3(-hl - t / 2.0, 0, -hw - t), Vector3(-hl - t / 2.0, 0, hw + t), t)
	_wall(b, Vector3(hl + t / 2.0, 0, -hw - t), Vector3(hl + t / 2.0, 0, hw + t), t)
	_wall(b, Vector3(-hl, 0, hw + t / 2.0), Vector3(-GATE_W / 2.0, 0, hw + t / 2.0), t)
	_wall(b, Vector3(GATE_W / 2.0, 0, hw + t / 2.0), Vector3(hl, 0, hw + t / 2.0), t)
	# Posts every ~3 m + three wires above the boards + a top rail; the gate gets a frame.
	b.color = Color(0.2, 0.22, 0.24)
	var posts: Array[Vector3] = []
	for i: int in 7:
		var x: float = -hl + LENGTH / 6.0 * i
		posts.append(Vector3(x, 0, -hw - t / 2.0))
		posts.append(Vector3(x, 0, hw + t / 2.0))
	for i: int in range(1, 4):
		var z: float = -hw + WIDTH / 4.0 * i
		posts.append(Vector3(-hl - t / 2.0, 0, z))
		posts.append(Vector3(hl + t / 2.0, 0, z))
	posts.append(Vector3(-GATE_W / 2.0, 0, hw + t / 2.0))
	posts.append(Vector3(GATE_W / 2.0, 0, hw + t / 2.0))
	for p: Vector3 in posts:
		b.box(&"item_matte", p + Vector3(0, FENCE_H / 2.0, 0), Vector3(0.07, FENCE_H, 0.07))
	b.color = Color(0.32, 0.34, 0.36)
	for h: float in [1.6, 2.3, FENCE_H - 0.03]:
		var th: float = 0.05 if h > 3.0 else 0.02
		b.box(&"item_matte", Vector3(0, h, -hw - t / 2.0), Vector3(LENGTH, th, th))
		b.box(&"item_matte", Vector3(-hl - t / 2.0, h, 0), Vector3(th, th, WIDTH + 2 * t))
		b.box(&"item_matte", Vector3(hl + t / 2.0, h, 0), Vector3(th, th, WIDTH + 2 * t))
		var seg: float = hl - GATE_W / 2.0
		b.box(&"item_matte", Vector3(-hl + seg / 2.0, h, hw + t / 2.0), Vector3(seg, th, th))
		b.box(&"item_matte", Vector3(hl - seg / 2.0, h, hw + t / 2.0), Vector3(seg, th, th))
	b.box(&"item_matte", Vector3(0, 2.2, hw + t / 2.0), Vector3(GATE_W + 0.07, 0.07, 0.07))  # over the gate
	# Two goals (white frame, grey net bars).
	for s: float in [-1.0, 1.0]:
		# The open mouth faces the pitch; the net is behind it, against the end fence.
		var back: float = s * (hl - 0.05)
		var gx: float = back - s * GOAL_DEPTH
		b.color = Color(0.95, 0.95, 0.95)
		for z: float in [-GOAL_HALF, GOAL_HALF]:
			b.box(&"item_matte", Vector3(gx, GOAL_H / 2.0, z), Vector3(0.08, GOAL_H, 0.08))
		b.box(&"item_matte", Vector3(gx, GOAL_H, 0), Vector3(0.08, 0.08, GOAL_HALF * 2.0 + 0.08))
		b.color = Color(0.75, 0.76, 0.78)
		for z: float in [-GOAL_HALF, GOAL_HALF]:
			b.box(&"item_matte", Vector3((gx + back) / 2.0, GOAL_H - 0.02, z), Vector3(GOAL_DEPTH, 0.04, 0.04))
			b.box(&"item_matte", Vector3((gx + back) / 2.0, TURF_TOP + 0.02, z), Vector3(GOAL_DEPTH, 0.04, 0.04))
		for i: int in 9:
			var z: float = -GOAL_HALF + GOAL_HALF * 2.0 * i / 8.0
			b.box(&"item_matte", Vector3(back, GOAL_H / 2.0, z), Vector3(0.025, GOAL_H, 0.025))
		for i: int in 5:
			var h: float = 0.1 + (GOAL_H - 0.1) * i / 4.0
			b.box(&"item_matte", Vector3(back, h, 0), Vector3(0.025, 0.025, GOAL_HALF * 2.0))
	var mi := MeshInstance3D.new()
	mi.mesh = b.build()
	_mark(mi)
	add_child(mi)
	# The boards in planks (own material).
	var wood := MeshBuilder.new()
	for seg: Array in _board_segments():
		var a: Vector3 = seg[0]
		var c: Vector3 = seg[1]
		var mid: Vector3 = (a + c) / 2.0
		var size := Vector3(maxf(absf(c.x - a.x), t), BOARD_H, maxf(absf(c.z - a.z), t))
		wood.box(&"planks", mid + Vector3(0, BOARD_H / 2.0, 0), size, 0.01)
	var wi := MeshInstance3D.new()
	wi.mesh = wood.build()
	_mark(wi)
	add_child(wi)
	# Score board on the north (-Z) fence, facing the pitch.
	_board = Label3D.new()
	_board.name = "ScoreBoard"
	_board.text = _score_text()
	_board.font_size = 64
	_board.pixel_size = 0.01
	_board.outline_size = 10
	_board.position = Vector3(0, 2.6, -hw - 0.15)
	_board.modulate = Color(1, 0.95, 0.75)
	_mark(_board)
	add_child(_board)


var _segments: Array = []


func _board_segments() -> Array:
	return _segments


func _wall(_b: MeshBuilder, a: Vector3, c: Vector3, t: float) -> void:
	_segments.append([a, c])
	var mid: Vector3 = (a + c) / 2.0
	var size := Vector3(maxf(absf(c.x - a.x), t), FENCE_H, maxf(absf(c.z - a.z), t))
	_collision(mid + Vector3(0, FENCE_H / 2.0, 0), size)


func _line(b: MeshBuilder, a: Vector3, c: Vector3, w: float) -> void:
	var d: Vector3 = c - a
	d.y = 0.0
	if d.length() < 0.001:
		return
	var side: Vector3 = d.normalized().cross(Vector3.UP) * w / 2.0
	b.quad(&"item_matte", a - side, c - side, c + side, a + side, Vector3.UP)


func _collision(center: Vector3, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = center
	_mark(cs)
	add_child(cs)


func _mark(n: Node) -> void:
	n.set_meta(&"generated", true)


func _score_text() -> String:
	return "%s  %d - %d  %s" % [TEAM_NAMES[0], score[0], score[1], TEAM_NAMES[1]]


# --- Ball (every peer) ------------------------------------------------------------------

func _build_ball() -> void:
	var b := MeshBuilder.new()
	b.color = Color(0.96, 0.96, 0.94)
	b.sphere(&"item_matte", Vector3.ZERO, BALL_R, 6, 10)
	b.color = Color(0.08, 0.08, 0.1)
	for d: Vector3 in [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
		b.box(&"item_matte", d * (BALL_R - 0.01), Vector3.ONE * 0.06)
	_ball = MeshInstance3D.new()
	_ball.name = "Ball"
	_ball.mesh = b.build()
	_ball.position = ball_pos
	add_child(_ball)
	_goal_label = Label3D.new()
	_goal_label.text = "GOAL!"
	_goal_label.font_size = 120
	_goal_label.pixel_size = 0.012
	_goal_label.outline_size = 16
	_goal_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_goal_label.modulate = Color(1, 0.85, 0.3)
	_goal_label.position = Vector3(0, 3.0, 0)
	_goal_label.visible = false
	add_child(_goal_label)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or _ball == null:
		return
	_roll(delta)
	if _is_host():
		_host_touches()
		_resend -= delta
		if _resend <= 0.0:
			_resend = 1.0
			_send_state()


## Same on every peer: roll, slow down, bounce off the boards; the host scores goals.
func _roll(delta: float) -> void:
	if _goal_wait > 0.0:
		_goal_wait -= delta
		if _goal_wait <= 0.0 and _is_host():
			ball_pos = Vector3(0, TURF_TOP + BALL_R, 0)
			ball_vel = Vector3.ZERO
			_send_state()
	var speed: float = ball_vel.length()
	if speed > 0.0:
		var step: Vector3 = ball_vel * delta
		ball_pos += step
		ball_vel *= pow(FRICTION, delta)
		if ball_vel.length() < 0.05:
			ball_vel = Vector3.ZERO
		# Spin the ball the way it rolls.
		var axis: Vector3 = Vector3.UP.cross(step.normalized())
		if axis.length() > 0.01:
			_ball.rotate(axis.normalized(), step.length() / BALL_R)
	var lim_x: float = LENGTH / 2.0 - BALL_R - 0.05
	var lim_z: float = WIDTH / 2.0 - BALL_R - 0.05
	if absf(ball_pos.z) > lim_z:
		ball_pos.z = signf(ball_pos.z) * lim_z
		ball_vel.z = -ball_vel.z * BOUNCE
	# Goal line = the goal mouth, GOAL_DEPTH in front of the end fence; the net is the fence behind it.
	var mouth: float = LENGTH / 2.0 - 0.05 - GOAL_DEPTH
	if absf(ball_pos.x) > mouth and absf(ball_pos.z) < GOAL_HALF - BALL_R and _goal_wait <= 0.0:
		if _is_host():
			_goal(0 if ball_pos.x > 0.0 else 1)
		ball_vel *= 0.2
	if absf(ball_pos.x) > lim_x:
		ball_pos.x = signf(ball_pos.x) * lim_x
		ball_vel.x = -ball_vel.x * BOUNCE
	_ball.position = ball_pos


## Host: `team` scored (team 0 attacks +X, team 1 attacks -X).
func _goal(team: int) -> void:
	score[team] += 1
	goals += 1
	_goal_wait = 2.0
	print("[Agora] GOAL for %s: %s" % [TEAM_NAMES[team], _score_text()])
	_show_goal(team, score[0], score[1])
	for peer: int in Net.peers_in_world:
		_show_goal.rpc_id(peer, team, score[0], score[1])
	_send_state()


@rpc("authority", "call_remote", "reliable")
func _show_goal(team: int, s0: int, s1: int) -> void:
	score = [s0, s1]
	_board.text = _score_text()
	_goal_label.text = "GOAL! %s" % TEAM_NAMES[team]
	_goal_label.modulate = ParkGoer.TEAM_SHIRTS[team].lightened(0.3)
	_goal_label.visible = true
	_goal_wait = 2.0
	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(_goal_label):
		_goal_label.visible = false


## Host: kick the ball towards `dir` (world space, flattened) at `power` m/s.
func kick(dir: Vector3, power: float, by: Node = null) -> void:
	if not _is_host() or _goal_wait > 0.0:
		return
	var d: Vector3 = global_basis.inverse() * dir
	d.y = 0.0
	if d.length() < 0.01:
		return
	ball_vel = d.normalized() * power
	kicks += 1
	if by:
		_last_kick[by] = _now()
	_send_state()


func ball_global() -> Vector3:
	return to_global(ball_pos)


func _send_state() -> void:
	for peer: int in Net.peers_in_world:
		_apply_ball.rpc_id(peer, ball_pos, ball_vel, score[0], score[1])


@rpc("authority", "call_remote", "unreliable_ordered")
func _apply_ball(pos: Vector3, vel: Vector3, s0: int, s1: int) -> void:
	ball_pos = pos
	ball_vel = vel
	if score[0] != s0 or score[1] != s1:
		score = [s0, s1]
		_board.text = _score_text()


## Host: players and NPCs that walk into the ball kick it (a short cooldown each).
func _host_touches() -> void:
	var at: Vector3 = ball_global()
	for group: StringName in [&"players", &"park_goers"]:
		for n: Node in get_tree().get_nodes_in_group(group):
			var body := n as Node3D
			if body == null or body.get("dead") == true:
				continue
			if group == &"park_goers" and (n as ParkGoer).role == ParkGoer.Role.FOOTBALL:
				continue  # they kick on purpose (football_step)
			var flat := Vector3(at.x - body.global_position.x, 0, at.z - body.global_position.z)
			if flat.length() > KICK_REACH or absf(at.y - body.global_position.y) > 1.0:
				continue
			if _now() - float(_last_kick.get(n, -10.0)) < 0.5:
				continue
			var power: float = 5.5
			if n is Player and (n as Player).get("net_sprint") == true:
				power = 8.0
			kick(flat, power, n)


func on_pitch(p: Vector3) -> bool:
	var l: Vector3 = to_local(p)
	return absf(l.x) < LENGTH / 2.0 - 0.2 and absf(l.z) < WIDTH / 2.0 - 0.2


## The gate, just outside (out = true) or just inside the pitch (world space).
func gate(out: bool) -> Vector3:
	return to_global(Vector3(0, TURF_TOP, WIDTH / 2.0 + (1.2 if out else -1.0)))


# --- Matches (host) ---------------------------------------------------------------------

func _match_loop() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--selftest" in args or "--netcheck" in args:
		return  # tests start their own matches (random ones would add NPCs to other checks)
	await get_tree().create_timer(5.0).timeout
	while is_inside_tree():
		_tidy_players()
		if players.is_empty() and _daytime() and randf() < match_chance:
			start_match(4 if randf() < 0.6 else 2)
		await get_tree().create_timer(20.0).timeout


func _daytime() -> bool:
	var dn := get_tree().get_first_node_in_group(&"day_night") as DayNight
	return dn != null and dn.hours >= play_hours.x and dn.hours < play_hours.y


func _tidy_players() -> void:
	var keep: Array[ParkGoer] = []
	for p: ParkGoer in _alive():
		if not p.leaving:
			keep.append(p)
	players = keep
	if not players.is_empty() and _now() > match_end:
		end_match()


## Host: `count` NPCs come and play for 3-6 minutes (`minutes` overrides).
func start_match(count: int, minutes: float = -1.0) -> void:
	var world: Node = get_tree().current_scene
	if world == null or not world.has_method("add_park_goer"):
		return
	score = [0, 0]
	_board.text = _score_text()
	match_end = _now() + (minutes * 60.0 if minutes > 0.0 else randf_range(180.0, 360.0))
	var map: RID = get_world_3d().navigation_map
	for i: int in count:
		var at: Vector3 = NavigationServer3D.map_get_closest_point(map, gate(true) + global_basis.x * (i - count / 2.0) * 0.9)
		var p: ParkGoer = world.call("add_park_goer", at, ParkGoer.Role.FOOTBALL, i % 2)
		p.agora = self
		players.append(p)
	print("[Agora] a match starts: %d players" % count)
	_send_state()


func end_match() -> void:
	for p: ParkGoer in _alive():
		p.leaving = true
	players.clear()
	print("[Agora] the match is over: %s" % _score_text())


## Host: the match players that still exist (freed ones skipped safely).
func _alive() -> Array[ParkGoer]:
	var out: Array[ParkGoer] = []
	for v: Variant in players:
		if is_instance_valid(v) and not (v as ParkGoer).dead:
			out.append(v as ParkGoer)
	return out


## Host: one think of a football ParkGoer (about 0.25 s).
func football_step(p: ParkGoer) -> void:
	if not players.has(p) or _now() > match_end:
		p.leaving = true
		return
	if not on_pitch(p.global_position):
		await p.walk_to(gate(false))
		return
	var ball: Vector3 = ball_global()
	var attack: Vector3 = global_basis.x * (1.0 if p.team == 0 else -1.0)
	attack.y = 0.0
	attack = attack.normalized()
	# The one of its team closest to the ball goes for it; the others take a spot.
	var chaser: ParkGoer = null
	var best: float = INF
	for q: ParkGoer in _alive():
		if is_instance_valid(q) and q.team == p.team and not q.dead:
			var d: float = q.global_position.distance_to(ball)
			if d < best:
				best = d
				chaser = q
	var flat_to_ball := Vector3(ball.x - p.global_position.x, 0, ball.z - p.global_position.z)
	if chaser == p:
		if flat_to_ball.length() < KICK_REACH + 0.15 and _now() - float(_last_kick.get(p, -10.0)) > 0.6:
			var target: Vector3 = to_global(Vector3((LENGTH / 2.0) * (1.0 if p.team == 0 else -1.0), 0, randf_range(-GOAL_HALF, GOAL_HALF) * 0.8))
			var mate: ParkGoer = null
			for q: ParkGoer in _alive():
				if q != p and q.team == p.team:
					mate = q
			if mate and randf() < 0.35:
				target = mate.global_position
			var dir: Vector3 = (target - ball)
			dir.y = 0.0
			dir = dir.normalized().rotated(Vector3.UP, randf_range(-0.3, 0.3))
			kick(dir, randf_range(4.5, 8.0), p)
			p.anim_state = Pedestrian.Anim.TALK
			await get_tree().create_timer(0.3).timeout
			return
		# Run round behind the ball (so the kick goes forward).
		var behind: Vector3 = ball - attack * 0.45
		behind.y = p.global_position.y
		p._go_direct(behind, Pedestrian.Anim.RUN if flat_to_ball.length() > 1.5 else Pedestrian.Anim.WALK)
	else:
		var l_ball: Vector3 = to_local(ball)
		var side: float = -1.0 if p.team == 0 else 1.0
		var spot := Vector3(clampf(l_ball.x * 0.5 + side * 2.5, -LENGTH / 2.0 + 1.5, LENGTH / 2.0 - 1.5), 0,
				clampf(-l_ball.z * 0.6 + (1.8 if p.get_index() % 2 == 0 else -1.8), -WIDTH / 2.0 + 1.0, WIDTH / 2.0 - 1.0))
		var g: Vector3 = to_global(spot)
		g.y = p.global_position.y
		if p.global_position.distance_to(g) > 1.0:
			p._go_direct(g, Pedestrian.Anim.RUN if p.global_position.distance_to(g) > 3.0 else Pedestrian.Anim.WALK)
		else:
			if p._moving:
				p._finish_move(true)
			p.face(ball)
	await get_tree().create_timer(0.25).timeout
