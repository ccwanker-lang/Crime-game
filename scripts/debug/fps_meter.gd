class_name FpsMeter
extends RefCounted
## FPS measurement of a scenario (performance rules 2026-11-24): window run, own port, e.g.
##   --path . --position 4000,40 --resolution 1920x1080 -- --scenario=fps_busy --fps-measure --quality=medium --port=7778
## Vsync off, no FPS cap. Lets the spot settle (NPC streaming, grass chunks, shaders), then measures MEASURE seconds
## while the player turns once round (so every direction counts): average FPS, 1% low (99th percentile frame),
## worst frame, draw calls, NPCs awake / total, cars. Prints a [FpsCheck] line, appends it to screenshots/fps_log.txt
## and quits. `--fps-settle=S` / `--fps-time=S` change the times.

const SETTLE: float = 10.0
const MEASURE: float = 10.0
const LOG: String = "res://screenshots/fps_log.txt"


static func run(world: Node, id: String, me: Player) -> void:
	var tree: SceneTree = world.get_tree()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var settle: float = SETTLE
	var measure: float = MEASURE
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--fps-settle="):
			settle = a.get_slice("=", 1).to_float()
		elif a.begins_with("--fps-time="):
			measure = a.get_slice("=", 1).to_float()
	var ov: Node = world.get_node_or_null("PerfOverlay")
	if ov:
		ov.set("visible", false)  # (measure the game, not the overlay)
	await tree.create_timer(settle).timeout
	# Two turns: round 1 = first look round (new materials / shaders compile once), round 2 = steady play.
	var rounds: Array = [[], []]
	var draws: float = 0.0
	var prims: float = 0.0
	var yaw0: float = me.rotation.y
	var t0: int = Time.get_ticks_usec()
	var last: int = t0
	var frames: int = 0
	while true:
		await tree.process_frame
		var now: int = Time.get_ticks_usec()
		var t: float = float(now - t0) / 1000000.0
		(rounds[0 if t < measure else 1] as Array).append(float(now - last) / 1000000.0)
		last = now
		frames += 1
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		me.rotation.y = yaw0 + TAU * clampf(t / measure, 0.0, 2.0)
		if t >= measure * 2.0:
			break
	var st: Array = [_stats(rounds[0]), _stats(rounds[1])]
	var n: int = frames
	var awake: int = 0
	var npcs: int = 0
	for np: Node in tree.get_nodes_in_group(&"npc"):
		npcs += 1
		if (np as Pedestrian).lod != Pedestrian.Lod.ASLEEP:
			awake += 1
	var cars: int = tree.get_nodes_in_group(&"cars").size()
	var vp: Viewport = tree.root
	var line: String = "%s %s quality=%s scale=%.2f: avg %.1f FPS, 1%% low %.1f, worst %.1f ms, %d spikes (first look round: avg %.1f, 1%% low %.1f, %d spikes), %.0f draws, %.0fk tris, npcs %d awake / %d, cars %d, %s" % [
			Time.get_datetime_string_from_system(), id, Settings.QUALITY[clampi(Settings.quality, 0, 3)],
			vp.scaling_3d_scale, st[1]["avg"], st[1]["low"], st[1]["worst"], st[1]["spikes"], st[0]["avg"], st[0]["low"],
			st[0]["spikes"], draws / n, prims / n / 1000.0, awake, npcs, cars, RenderingServer.get_video_adapter_name()]
	print("[FpsCheck] " + line)
	var path: String = ProjectSettings.globalize_path(LOG)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if f:
		f.seek_end()
		f.store_line(line)
		f.close()
	tree.quit()


## avg FPS, 1% low FPS, worst frame ms, spikes (frames over 2.5x the median and over 16.7 ms).
static func _stats(d: Array) -> Dictionary:
	var sorted: PackedFloat32Array = PackedFloat32Array(d)
	sorted.sort()
	var n: int = sorted.size()
	if n == 0:
		return {"avg": 0.0, "low": 0.0, "worst": 0.0, "spikes": 0}
	var total: float = 0.0
	for x: float in sorted:
		total += x
	var med: float = sorted[n / 2]
	var spikes: int = 0
	for x: float in sorted:
		if x > med * 2.5 and x > 0.0167:
			spikes += 1
	return {"avg": n / total, "low": 1.0 / sorted[mini(n - 1, int(n * 0.99))], "worst": sorted[n - 1] * 1000.0,
			"spikes": spikes}
