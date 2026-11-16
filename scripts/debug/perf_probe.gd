extends Node
## Debug (point 86): measures where the frame time goes in a real hosted game. Start (window, own port):
##   --path . --position 4000,40 --resolution 1920x1080 -- --perf --port=7790 [--perf-spots=docks,city] [--perf-quick]
## For every spot: teleport the local player there (god mode + army pass), let things settle, measure a baseline
## (FPS, 1% low, CPU process/physics ms, GPU ms, draw calls, primitives, nodes, NPCs), then switch one subsystem off at
## a time ("ablation") and measure again: the FPS / ms it frees is what that subsystem costs. Prints [Perf] lines and
## writes screenshots/perf_report.txt. Never saves (TEST flag).

const SPOTS: Array[Array] = [
	# name, position, look at
	["docks", Vector3(-150.0, 0.3, 94.0), Vector3(-90.0, 2.0, 40.0)],
	["city", Vector3(60.5, 0.3, 270.0), Vector3(36.0, 6.0, 210.0)],
	["army_base", Vector3(-60.0, 0.3, -372.0), Vector3(60.0, 2.0, -400.0)],
	["village", Vector3(-8.0, 0.3, -4.6), Vector3(-40.0, 2.0, -4.6)],
]
const SETTLE: float = 8.0
const BASE_TIME: float = 6.0
const ABLATE_TIME: float = 3.0

var world: Node3D
var _lines: PackedStringArray = []


func _ready() -> void:
	world = get_parent()
	_run.call_deferred()


func _log(s: String) -> void:
	print("[Perf] " + s)
	_lines.append(s)


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	var me: Player = null
	for i: int in 600:
		me = world.get_node("Players").get_node_or_null("1") as Player
		if me and world.get("_nav_baked") != false:
			break
		await get_tree().create_timer(0.1).timeout
	await get_tree().create_timer(6.0).timeout
	if me == null:
		_log("no local player - abort")
		get_tree().quit(1)
		return
	me.admin_god = true
	var only: PackedStringArray = []
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--perf-spots="):
			only = a.trim_prefix("--perf-spots=").split(",")
	var quick: bool = "--perf-quick" in OS.get_cmdline_user_args()
	_log("screen %s, vsync off, %s" % [get_viewport().get_visible_rect().size, RenderingServer.get_video_adapter_name()])
	for spot: Array in SPOTS:
		if not only.is_empty() and not (spot[0] in only):
			continue
		var at: Vector3 = spot[1]
		var look: Vector3 = spot[2]
		if Engine.has_singleton("Zones") or get_node_or_null("/root/Zones"):
			get_node("/root/Zones").call("allow_army", me, 3600.0)
		me.teleport(at)
		var d: Vector3 = look - (at + Vector3.UP * 1.6)
		me.rotation.y = atan2(-d.x, -d.z)
		me.head.rotation.x = asin(clampf(d.normalized().y, -0.9, 0.9))
		await get_tree().create_timer(SETTLE).timeout
		var base: Dictionary = await _measure(BASE_TIME)
		_log("%s BASE: %s" % [spot[0], _fmt(base)])
		_log("%s npcs by kind (all / within 250 m): %s" % [spot[0], _npc_histogram(me)])
		_log("%s processing nodes: %s" % [spot[0], _process_census()])
		if "--perf-spikes" in OS.get_cmdline_user_args():
			await _spike_hunt()
			continue
		if quick:
			continue
		var abl: Array[String] = ["phys_other", "proc_other", "autoloads", "npc_physproc", "npc_anim", "npc_skel_vis", "npc_signals", "far_npcs", "npcs_ai", "npcs_render", "cars", "shadows", "lights", "grass", "jets",
				"env_fx", "far_geometry", "terrain", "hud", "physics_npcs"]
		for k: String in _npc_kinds():
			abl.append("ai:" + k)
		for a: String in OS.get_cmdline_user_args():
			if a.begins_with("--perf-abl="):
				abl.assign(a.get_slice("=", 1).split(","))
		for ab: String in abl:
			# A-B-A: a fresh baseline before and after, so drift (NPCs walking in/out) doesn't fake a gain.
			var a1: Dictionary = await _measure(ABLATE_TIME)
			var undo: Callable = _ablate(ab, me)
			await get_tree().create_timer(0.6).timeout
			var m: Dictionary = await _measure(ABLATE_TIME)
			undo.call()
			await get_tree().create_timer(0.6).timeout
			var a2: Dictionary = await _measure(ABLATE_TIME)
			var ref: float = (float(a1["ms"]) + float(a2["ms"])) / 2.0
			_log("%s  -%-22s %s   saves %6.2f ms/frame (ref %.2f ms = %.0f fps)" % [spot[0], ab, _fmt(m), ref - float(m["ms"]),
					ref, 1000.0 / ref])
	var f := FileAccess.open("res://screenshots/perf_report.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(_lines) + "\n")
	_log("done")
	get_tree().quit()


var _pf0: int = 0


## Frames over SPIKE_MS in `seconds` (counts hitches, not the mean).
const SPIKE_MS: float = 25.0


func _spikes(seconds: float) -> Array:
	var n: int = 0
	var worst: float = 0.0
	var frames: int = 0
	var t0: int = Time.get_ticks_usec()
	var last: int = t0
	while Time.get_ticks_usec() - t0 < int(seconds * 1e6):
		await get_tree().process_frame
		var now: int = Time.get_ticks_usec()
		var ms: float = (now - last) / 1000.0
		last = now
		frames += 1
		worst = maxf(worst, ms)
		if ms > SPIKE_MS:
			n += 1
	return [n, worst, frames]


## Turns every autoload and every scripted World child off in turn (8 s each) and counts the hitches.
func _spike_hunt() -> void:
	var suspects: Array[Node] = []
	for n: Node in get_tree().root.get_children():
		if n != world and n.get_script() and not (n.name in ["Net", "GameState", "ItemDB", "SaveManager"]):
			suspects.append(n)
	for n: Node in world.get_children():
		if n.get_script() and n != self and not n is PerfOverlay:
			suspects.append(n)
		elif n.name in ["NPCs", "Players"]:
			pass
	var b0: Array = await _spikes(8.0)
	_log("spikes BASE: %d in %d frames (worst %.0f ms)" % [b0[0], b0[2], b0[1]])
	for sus: Node in suspects:
		var was: int = sus.process_mode
		sus.process_mode = Node.PROCESS_MODE_DISABLED
		var r: Array = await _spikes(8.0)
		sus.process_mode = was
		var rb: Array = await _spikes(4.0)
		_log("spikes -%-22s %3d in %4d frames (worst %3.0f ms)   with it: %3d in %4d (worst %3.0f)" % [
				sus.name, r[0], r[2], r[1], rb[0], rb[2], rb[1]])


func _measure(seconds: float) -> Dictionary:
	var vp: RID = get_viewport().get_viewport_rid()
	var frames: PackedFloat32Array = []
	var proc: float = 0.0
	var phys: float = 0.0
	var gpu: float = 0.0
	var cpu_r: float = 0.0
	var draws: float = 0.0
	var prims: float = 0.0
	var t0: int = Time.get_ticks_usec()
	_pf0 = Engine.get_physics_frames()
	var last: int = t0
	while Time.get_ticks_usec() - t0 < int(seconds * 1e6):
		await get_tree().process_frame
		var now: int = Time.get_ticks_usec()
		frames.append((now - last) / 1000.0)
		last = now
		proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		cpu_r += RenderingServer.viewport_get_measured_render_time_cpu(vp)
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var n: float = maxf(frames.size(), 1)
	var total: float = 0.0
	for ft: float in frames:
		total += ft
	var sorted: PackedFloat32Array = frames.duplicate()
	sorted.sort()
	var worst: float = sorted[int(sorted.size() * 0.99)] if sorted.size() > 0 else 0.0
	if sorted.size() > 10:
		_log("   frame ms: p50 %.1f  p90 %.1f  p99 %.1f  max %.1f  | phys ticks/frame %.2f" % [sorted[sorted.size() / 2],
				sorted[int(sorted.size() * 0.9)], worst, sorted[-1], float(Engine.get_physics_frames() - _pf0) / sorted.size()])
	return {"fps": n / maxf(total / 1000.0, 0.001), "ms": total / n, "low1": 1000.0 / maxf(worst, 0.001),
			"proc": proc / n, "phys": phys / n, "gpu": gpu / n, "cpu_r": cpu_r / n, "draws": draws / n, "prims": prims / n,
			"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			"npcs": get_tree().get_nodes_in_group(&"npc").size()}


func _fmt(m: Dictionary) -> String:
	return "%5.1f fps (%5.2f ms, 1%% low %4.0f) | process %5.2f ms, physics %5.2f ms, render cpu %5.2f ms, gpu %5.2f ms | %5.0f draws, %4.1f M prims | %d nodes, %d npcs" % [
			m["fps"], m["ms"], m["low1"], m["proc"], m["phys"], m["cpu_r"], m["gpu"], m["draws"], float(m["prims"]) / 1e6,
			int(m["nodes"]), int(m["npcs"])]


## Which scripts run _process / _physics_process every frame (count per class, top 25).
func _process_census() -> String:
	var cnt: Dictionary = {}
	var stack: Array[Node] = [get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c: Node in n.get_children():
			stack.append(c)
		if n.get_script() == null:
			continue
		var p: bool = n.is_processing() and n.can_process()
		var ph: bool = n.is_physics_processing() and n.can_process()
		if not (p or ph):
			continue
		var k: String = _kind(n) + ("(p)" if p and not ph else "(ph)" if ph and not p else "(p+ph)")
		cnt[k] = int(cnt.get(k, 0)) + 1
	var keys: Array = cnt.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return int(cnt[a]) > int(cnt[b]))
	var parts: PackedStringArray = []
	for k: String in keys.slice(0, 25):
		parts.append("%s %d" % [k, cnt[k]])
	return ", ".join(parts)


func _kind(n: Node) -> String:
	var sc: Script = n.get_script()
	return sc.get_global_name() if sc and sc.get_global_name() != &"" else n.get_class()


func _npc_kinds() -> Array[String]:
	var kinds: Array[String] = []
	for n: Node in get_tree().get_nodes_in_group(&"npc"):
		var k: String = _kind(n)
		if not k in kinds:
			kinds.append(k)
	return kinds


func _npc_histogram(me: Player) -> String:
	var all: Dictionary = {}
	var near: Dictionary = {}
	for n: Node in get_tree().get_nodes_in_group(&"npc"):
		var k: String = _kind(n)
		all[k] = int(all.get(k, 0)) + 1
		if (n as Node3D).global_position.distance_to(me.global_position) < 250.0:
			near[k] = int(near.get(k, 0)) + 1
	var names: Dictionary = {}
	for n: Node in get_tree().get_nodes_in_group(&"npc"):
		var nm: String = str(n.name).rstrip("0123456789").trim_suffix("_")
		var par: String = str(n.get_parent().name)
		var key: String = par + "/" + nm
		names[key] = int(names.get(key, 0)) + 1
	_log("npcs by parent/name: %s" % str(names))
	var parts: PackedStringArray = []
	for k: String in all.keys():
		parts.append("%s %d/%d" % [k, all[k], near.get(k, 0)])
	return ", ".join(parts)


## Switch one subsystem off; returns the Callable that switches it back on.
func _ablate(what: String, me: Player) -> Callable:
	var undo: Array[Callable] = []
	var set_prop := func(o: Object, prop: StringName, v: Variant) -> void:
		var old: Variant = o.get(prop)
		o.set(prop, v)
		undo.append(func() -> void:
			if is_instance_valid(o):
				o.set(prop, old))
	if what.begins_with("ai:"):
		var k: String = what.trim_prefix("ai:")
		for n: Node in get_tree().get_nodes_in_group(&"npc"):
			if _kind(n) == k:
				set_prop.call(n, &"process_mode", Node.PROCESS_MODE_DISABLED)
	match what:
		"phys_other":
			# Every _physics_process except players, NPCs and traffic cars (doors, sounds, lifts, dogs...).
			var stack: Array[Node] = [world]
			while not stack.is_empty():
				var n: Node = stack.pop_back()
				for c: Node in n.get_children():
					stack.append(c)
				if n.get_script() and n.is_physics_processing() and not (n is Player or n is Pedestrian or n is Car):
					var nn: Node = n
					nn.set_physics_process(false)
					undo.append(func() -> void:
						if is_instance_valid(nn):
							nn.set_physics_process(true))
		"proc_other":
			var stack2: Array[Node] = [world]
			while not stack2.is_empty():
				var n: Node = stack2.pop_back()
				for c: Node in n.get_children():
					stack2.append(c)
				if n.get_script() and n.is_processing() and not (n is Player or n is Pedestrian or n is Car or n is PerfOverlay or n == self):
					var nn: Node = n
					nn.set_process(false)
					undo.append(func() -> void:
						if is_instance_valid(nn):
							nn.set_process(true))
		"autoloads":
			for n: Node in get_tree().root.get_children():
				if n != world and n.get_script() and n.name != "Net" and n.name != "GameState":
					set_prop.call(n, &"process_mode", Node.PROCESS_MODE_DISABLED)
		"npc_physproc":
			for n: Node in get_tree().get_nodes_in_group(&"npc"):
				var was: bool = n.is_physics_processing()
				n.set_physics_process(false)
				undo.append(func() -> void:
					if is_instance_valid(n):
						n.set_physics_process(was))
		"npc_anim":
			for n: Node in get_tree().get_nodes_in_group(&"npc"):
				for a: Node in n.find_children("*", "AnimationMixer", true, false):
					set_prop.call(a, &"process_mode", Node.PROCESS_MODE_DISABLED)
		"npc_skel_vis":
			# Only the meshes hidden (skeletons/animations still run).
			for n: Node in get_tree().get_nodes_in_group(&"npc"):
				for m: Node in n.find_children("*", "MeshInstance3D", true, false):
					set_prop.call(m, &"visible", false)
		"npc_signals":
			# Labels, synchronizers and other children (everything but the body + model).
			for n: Node in get_tree().get_nodes_in_group(&"npc"):
				for c: Node in n.find_children("*", "MultiplayerSynchronizer", true, false):
					set_prop.call(c, &"process_mode", Node.PROCESS_MODE_DISABLED)
				for c: Node in n.find_children("*", "Label3D", true, false):
					set_prop.call(c, &"visible", false)
		"far_npcs":
			# What streaming would give: every NPC more than 250 m from the player gone (no AI, no physics, not drawn).
			for n: Node in get_tree().get_nodes_in_group(&"npc"):
				if (n as Node3D).global_position.distance_to(me.global_position) > 250.0:
					set_prop.call(n, &"process_mode", Node.PROCESS_MODE_DISABLED)
					set_prop.call(n, &"visible", false)
		"npcs_render":
			for n: Node in get_tree().get_nodes_in_group(&"npc"):
				set_prop.call(n, &"visible", false)
		"physics_npcs":
			for n: Node in get_tree().get_nodes_in_group(&"npc"):
				if n is CharacterBody3D:
					set_prop.call(n, &"collision_layer", 0)
					set_prop.call(n, &"collision_mask", 0)
		"npcs_ai", "npcs_all":
			for n: Node in get_tree().get_nodes_in_group(&"npc"):
				set_prop.call(n, &"process_mode", Node.PROCESS_MODE_DISABLED)
				if what == "npcs_all":
					set_prop.call(n, &"visible", false)
		"cars":
			for n: Node in world.find_children("*", "Car", true, false):
				set_prop.call(n, &"process_mode", Node.PROCESS_MODE_DISABLED)
				set_prop.call(n, &"visible", false)
		"shadows":
			for n: Node in world.find_children("*", "Light3D", true, false):
				set_prop.call(n, &"shadow_enabled", false)
		"lights":
			for n: Node in world.find_children("*", "Light3D", true, false):
				if not n is DirectionalLight3D:
					set_prop.call(n, &"visible", false)
		"grass":
			for n: Node in world.find_children("*", "GrassCover", true, false):
				set_prop.call(n, &"visible", false)
				set_prop.call(n, &"process_mode", Node.PROCESS_MODE_DISABLED)
			for n: Node in world.find_children("*", "GrassField", true, false):
				set_prop.call(n, &"visible", false)
		"jets":
			for n: Node in world.find_children("*", "Airfield", true, false):
				set_prop.call(n, &"process_mode", Node.PROCESS_MODE_DISABLED)
				set_prop.call(n, &"visible", false)
		"env_fx":
			for n: Node in world.find_children("*", "WorldEnvironment", true, false):
				var env: Environment = (n as WorldEnvironment).environment
				for prop: StringName in [&"ssil_enabled", &"ssao_enabled", &"glow_enabled", &"volumetric_fog_enabled",
						&"sdfgi_enabled", &"ssr_enabled", &"fog_enabled"]:
					set_prop.call(env, prop, false)
		"far_geometry":
			# What a visibility range of 220 m on everything would give (LOD / visibility ranges).
			for n: Node in world.find_children("*", "GeometryInstance3D", true, false):
				var g := n as GeometryInstance3D
				if g.visibility_range_end == 0.0 or g.visibility_range_end > 220.0:
					set_prop.call(g, &"visibility_range_end", 220.0)
		"terrain":
			for name: String in ["BorderRange", "Mountain", "OuterGround", "OuterGroundSE"]:
				var n: Node = world.get_node_or_null(name)
				if n:
					set_prop.call(n, &"visible", false)
		"hud":
			for n: Node in me.find_children("*", "CanvasLayer", true, false):
				set_prop.call(n, &"visible", false)
	return func() -> void:
		for u: Callable in undo:
			u.call()
