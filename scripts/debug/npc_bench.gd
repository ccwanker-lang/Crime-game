class_name NpcBench
extends Node
## Roadmap 89 (session B): how many ACTIVE NPCs does this PC carry? Started by the F9 scenario `npc_bench` (or
## `--scenario=npc_bench` in a window). For each spot (city centre, slums, docks) the player stands there (god mode),
## and the bench raises the number of awake NPCs step by step (STEPS), STEP_TIME s per step, measuring the mean FPS
## and the 1% low (the 99th percentile frame). Extra NPCs are ordinary pedestrians round the player (10-70 m, so A's
## NpcStreamer gives them FULL and MID levels like real ones) that keep walking short straight legs. The highest count
## whose 1% low stays above TARGET_LOW is the spot's limit; the advice for `max_active_npcs` (data/npc/streaming.tres)
## is the lowest spot limit x MARGIN. Prints [NpcBench] lines, shows a panel on screen, writes screenshots/npc_bench.txt.

const SPOTS: Array[Array] = [
	# name, stand at, look at
	["city centre", Vector3(60.5, 0.3, 270.0), Vector3(36.0, 6.0, 210.0)],
	["slums", Vector3(-40.0, 0.3, -64.8), Vector3(-60.0, 1.5, -90.0)],
	["docks", Vector3(-150.0, 0.3, 94.0), Vector3(-90.0, 2.0, 40.0)],
]
## 0 = baseline (every ordinary NPC asleep): what the spot costs without NPCs.
const STEPS: Array[int] = [0, 20, 40, 60, 80, 100, 120, 140, 160]
const STEP_TIME: float = 20.0
const SETTLE: float = 5.0
## Below the target already without NPCs: a count passes while its 1% low stays within this share of the baseline.
const BASELINE_SHARE: float = 0.9
const TARGET_LOW: float = 55.0
## Advice = lowest passing count x this (headroom for cars, fights, a second player).
const MARGIN: float = 0.8
const META: StringName = &"bench"
const PEDESTRIAN_SCENE: String = "res://prefabs/npc/pedestrian.tscn"

var world: Node3D
var step_time: float = STEP_TIME
var results: Dictionary = {}  # spot name -> Array of {count, active, fps, low1}
var advice: int = -1
var _label: Label
var _lines: PackedStringArray = []
var _old_cap: int = -1


func _ready() -> void:
	world = get_parent() as Node3D
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--bench-step="):
			step_time = a.trim_prefix("--bench-step=").to_float()
	if DisplayServer.get_name() != "headless":
		var layer := CanvasLayer.new()
		layer.layer = 50
		add_child(layer)
		_label = Label.new()
		_label.position = Vector2(24, 160)
		_label.add_theme_font_size_override(&"font_size", 18)
		_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
		_label.add_theme_constant_override(&"outline_size", 6)
		layer.add_child(_label)
	_run.call_deferred()


func _log(s: String) -> void:
	print("[NpcBench] " + s)
	_lines.append(s)
	if _label:
		var tail: PackedStringArray = _lines.slice(maxi(0, _lines.size() - 16))
		_label.text = "NPC BENCH (Roadmap 89) - don't touch, measuring\n" + "\n".join(tail)


func _run() -> void:
	var me: Player = null
	for i: int in 600:
		me = world.get_node("Players").get_node_or_null("1") as Player
		if me:
			break
		await get_tree().create_timer(0.1).timeout
	if me == null:
		_log("no local player - abort")
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var old_fps: int = Engine.max_fps
	Engine.max_fps = 0
	_old_cap = NpcStreamer.cap_override
	NpcStreamer.cap_override = 100000  # the bench decides how many are awake
	me.admin_god = true
	Zones.allow_army(me, 3600.0)
	_log("%s, window %s, vsync off, %d s per step" % [RenderingServer.get_video_adapter_name(),
			get_viewport().get_visible_rect().size, int(step_time)])
	for spot: Array in SPOTS:
		await _bench_spot(me, spot)
	_clear_bench()
	NpcStreamer.cap_override = _old_cap
	Engine.max_fps = old_fps
	_report()


func _bench_spot(me: Player, spot: Array) -> void:
	var name_: String = spot[0]
	me.teleport(spot[1])
	_look(me, spot[2])
	await get_tree().create_timer(SETTLE * 2.0).timeout  # (new spot: shaders, streaming)
	var rows: Array = []
	results[name_] = rows
	var base_low: float = -1.0
	for count: int in STEPS:
		NpcStreamer.cap_override = count
		_fill_to(me, count)
		var st := world.get_node_or_null(^"NpcStreamer") as NpcStreamer
		if st:
			st.update_now()
		await get_tree().create_timer(SETTLE).timeout
		var m: Dictionary = await _measure(step_time, me)
		m["count"] = count
		rows.append(m)
		if count == 0:
			base_low = float(m["low1"])
		var ok: bool = _passes(m, base_low)
		_log("%-11s %3d NPCs (%3d awake): %5.1f fps, 1%% low %5.1f %s" % [name_, count, int(m["active"]), m["fps"], m["low1"],
				"baseline" if count == 0 else ("ok" if ok else "TOO LOW")])
		if count > 0 and not ok:
			break  # more only gets worse
	_clear_bench()


## A step passes at a 1% low of TARGET_LOW, or (when even the empty spot is below that) within BASELINE_SHARE of it.
func _passes(m: Dictionary, base_low: float) -> bool:
	var need: float = TARGET_LOW if base_low < 0.0 or base_low >= TARGET_LOW / BASELINE_SHARE else base_low * BASELINE_SHARE
	return float(m["low1"]) >= need


## Spawns bench pedestrians round the player until at least `count` NPCs are within 70 m (the streamer's cap then
## keeps exactly the nearest `count` awake).
func _fill_to(me: Player, count: int) -> void:
	var near: int = 0
	for n: Node in get_tree().get_nodes_in_group(&"npc"):
		var p := n as Pedestrian
		if p and not p.stationary and not p.dead and not p.is_queued_for_deletion() 				and p.global_position.distance_to(me.global_position) < 70.0:
			near += 1
	var tries: int = 0
	while near < count and tries < count * 8:
		tries += 1
		var a: float = randf() * TAU
		var d: float = randf_range(10.0, 70.0)
		var ground: Vector3 = _ground(me.global_position + Vector3(cos(a) * d, 0.0, sin(a) * d))
		if ground == Vector3.INF:
			continue
		var npc: Pedestrian = (load(PEDESTRIAN_SCENE) as PackedScene).instantiate()
		npc.variant = randi() % Pedestrian.VARIANTS.size()
		npc.color_seed = randi()
		npc.ambient = false
		npc.position = ground + Vector3.UP * 0.05
		npc.rotation.y = randf() * TAU
		npc.set_meta(META, true)
		world.get("npcs").add_child(npc, true)
		_stroll(npc)
		near += 1


## Open ground (not inside / under something) at `p`, or INF.
func _ground(p: Vector3) -> Vector3:
	var space := world.get_world_3d().direct_space_state
	var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 30.0, p + Vector3.DOWN * 5.0, 1))
	if hit.is_empty() or (hit["position"] as Vector3).y > 1.0 or (hit["normal"] as Vector3).y < 0.8:
		return Vector3.INF
	return hit["position"]


## A bench NPC keeps walking short straight legs (works with or without a navmesh, like the city walkers).
func _stroll(npc: Pedestrian) -> void:
	await get_tree().create_timer(randf_range(0.2, 2.0)).timeout
	while is_instance_valid(npc) and npc.is_inside_tree() and not npc.dead:
		var a: float = randf() * TAU
		var to: Vector3 = npc.global_position + Vector3(cos(a), 0.0, sin(a)) * randf_range(5.0, 15.0)
		if npc.lod != Pedestrian.Lod.ASLEEP and not npc.is_fleeing() and npc.straight_way_clear(to, 20.0):
			await npc._go_direct(to, Pedestrian.Anim.WALK)
		if not is_instance_valid(npc):
			return
		await get_tree().create_timer(randf_range(0.5, 2.5)).timeout


func _awake() -> int:
	var n: int = 0
	for x: Node in get_tree().get_nodes_in_group(&"npc"):
		var p := x as Pedestrian
		if p and not p.stationary and not p.is_queued_for_deletion() and p.lod != Pedestrian.Lod.ASLEEP and not p.dead:
			n += 1
	return n


func _clear_bench() -> void:
	for n: Node in get_tree().get_nodes_in_group(&"npc"):
		if n.has_meta(META):
			n.queue_free()


func _look(me: Player, at: Vector3) -> void:
	var d: Vector3 = at - me.global_position
	me.rotation.y = atan2(-d.x, -d.z)


func _measure(seconds: float, me: Player) -> Dictionary:
	var frames: PackedFloat32Array = []
	var t0: int = Time.get_ticks_usec()
	var last: int = t0
	var awake_sum: int = 0
	while Time.get_ticks_usec() - t0 < int(seconds * 1e6):
		await get_tree().process_frame
		var now: int = Time.get_ticks_usec()
		frames.append((now - last) / 1000.0)
		last = now
		if frames.size() % 30 == 0:
			awake_sum += _awake()
	var total: float = 0.0
	for ft: float in frames:
		total += ft
	var sorted: PackedFloat32Array = frames.duplicate()
	sorted.sort()
	var worst: float = sorted[int(sorted.size() * 0.99)] if sorted.size() > 0 else 1000.0
	var samples: int = maxi(frames.size() / 30, 1)
	return {"count": 0, "active": awake_sum / samples, "fps": frames.size() / maxf(total / 1000.0, 0.001),
			"low1": 1000.0 / maxf(worst, 0.001)}


func _report() -> void:
	_log("--- result: 1%% low >= %d FPS, or >= %d%% of the spot's baseline when the baseline is lower ---"
			% [int(TARGET_LOW), int(BASELINE_SHARE * 100.0)])
	var lowest: int = 1 << 30
	for name_: String in results:
		var rows: Array = results[name_]
		var base_low: float = float(rows[0]["low1"]) if not rows.is_empty() else -1.0
		var best: int = 0
		for m: Dictionary in rows:
			if int(m["count"]) > 0 and _passes(m, base_low):
				best = int(m["count"])
		_log("%-11s: up to %d active NPCs (baseline 1%% low %.0f)%s" % [name_, best, base_low,
				" - more than the last step" if best == STEPS[-1] else ""])
		lowest = mini(lowest, best)
	advice = maxi(20, int(floor(lowest * MARGIN / 5.0)) * 5) if lowest < (1 << 30) else -1
	_log("advice: max_active_npcs = %d (lowest spot x %.1f); now %d" % [advice, MARGIN,
			(load("res://data/npc/streaming.tres") as NpcStreamConfig).max_active_npcs])
	var f := FileAccess.open("res://screenshots/npc_bench.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(_lines) + "\n")
		f.close()
	if "--bench-quit" in OS.get_cmdline_user_args():
		get_tree().quit()
