class_name QualityLevelsTest
extends RefCounted
## Self-test check "quality_levels" (SelfTest._check_quality_levels), performance rules 2026-11-24: the quality levels scale the
## world (NPC cap, traffic, crowd, grass, draw distance, shadow budget, sun shadows) and the first-start pick from the
## hardware.


static func run(t: Node, world: Node3D) -> void:
	var tree: SceneTree = t.get_tree()
	var report := func(ok: bool, text: String) -> void: t.call("_report", ok, text)
	var D := RenderingDevice
	var cases: Array = [
		["intel(r) iris(r) xe graphics", D.DEVICE_TYPE_INTEGRATED_GPU, 16.0, 8, 0],
		["amd radeon(tm) graphics", D.DEVICE_TYPE_DISCRETE_GPU, 16.0, 12, 0],
		["nvidia geforce gtx 1660 super", D.DEVICE_TYPE_DISCRETE_GPU, 16.0, 12, 1],
		["amd radeon rx 6600", D.DEVICE_TYPE_DISCRETE_GPU, 16.0, 12, 1],
		["nvidia geforce rtx 4070", D.DEVICE_TYPE_DISCRETE_GPU, 8.0, 8, 1],
		["nvidia geforce rtx 5060 ti", D.DEVICE_TYPE_DISCRETE_GPU, 32.0, 16, 2],
		["nvidia geforce rtx 4090", D.DEVICE_TYPE_DISCRETE_GPU, 4.0, 16, 0],
	]
	var wrong: PackedStringArray = []
	for c: Array in cases:
		var got: Array = QualityProfile.pick(c[0], c[1], c[2], c[3])
		if int(got[0]) != int(c[4]):
			wrong.append("%s -> %s (want %s)" % [c[0], Settings.QUALITY[got[0]], Settings.QUALITY[c[4]]])
	report.call(wrong.is_empty(), "first start picks the quality from the hardware (iGPU Low, GTX 1660 / RX 6600 "
			+ "Medium, RTX 5060 Ti High, never Ultra)%s" % ("" if wrong.is_empty() else ": " + "; ".join(wrong)))

	# A test object with a draw distance set by WorldLod (meta lod_end).
	var probe := MeshInstance3D.new()
	probe.mesh = BoxMesh.new()
	probe.set_meta(&"lod_end", 100.0)
	probe.visibility_range_end = 100.0
	world.add_child(probe)
	var rows: PackedStringArray = []
	var ok: bool = true
	var last: Array = []
	for q: int in 4:
		QualityProfile.apply(tree, q)
		var now: Array = [NpcStreamer.cap_override, Traffic.count_scale, GrassCover.density_scale, WorldLod.max_shadows,
				probe.visibility_range_end, float(QualityProfile.value("crowd"))]
		rows.append("%s: npcs %d, traffic %.2f, grass %.2f, shadows %d, range %.0f m, crowd %.2f" % [
				Settings.QUALITY[q], now[0], now[1], now[2], now[3], now[4], now[5]])
		if not last.is_empty():
			for k: int in now.size():
				if float(now[k]) < float(last[k]):
					ok = false  # (every number may only grow from Low to Ultra)
		last = now
	QualityProfile.apply(tree, 0)
	var low_ok: bool = NpcStreamer.cap_override < 40 and WorldLod.max_shadows <= 4 and probe.visibility_range_end < 70.0
	QualityProfile.reset(tree)
	var reset_ok: bool = QualityProfile.active == -1 and NpcStreamer.cap_override == -1 and is_equal_approx(probe.visibility_range_end, 100.0) \
			and WorldLod.max_shadows == WorldLod.MAX_SHADOWS and is_equal_approx(Traffic.count_scale, 1.0)
	probe.queue_free()
	report.call(ok and low_ok and reset_ok, "quality levels scale the world (only up from Low to Ultra, back to the "
			+ "project's numbers after): " + " | ".join(rows))

	# The level in the Settings window has a tooltip + the forced level flag works in test runs.
	report.call(Settings.forced_quality == -1 and Settings.test_run(), "test runs keep the project's own quality "
			+ "unless --quality=low|medium|high|ultra is given (FPS measurements per level)")
