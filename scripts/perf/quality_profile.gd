class_name QualityProfile
extends RefCounted
## Quality levels Low / Medium / High / Ultra (session B, performance rules 2026-11-24): everything heavy scales with
## Settings.quality. Settings.apply_quality() handles the viewport / environment (render scale, AA, SSAO, SSIL, glow,
## shadow atlas + filter); this table handles the world:
## - npc_cap: NPCs awake + drawn at once per peer (NpcStreamer cap; a mission / police target always stays awake)
## - traffic: share of the host's ambient traffic cars (village + city routes)
## - crowd: share of the ambient crowd (DayRhythm village crowd, CityLife walkers)
## - grass: grass tufts per m2 (share) + the radius round the camera they grow in (share)
## - range: draw distances of props / trees / lamps / facade parts (WorldLod, share)
## - shadows: lights with real shadows at once (WorldLod budget) + the sun's shadow distance (m) + splits
## Default on first start: `auto_level()` from the hardware (never Ultra: the player picks that).

const LEVELS: Array[Dictionary] = [
	{"npc_cap": 28, "traffic": 0.5, "crowd": 0.55, "grass": 0.35, "grass_radius": 0.6, "range": 0.6, "shadows": 4,
			"sun_shadow": 45.0, "sun_splits": 1},
	{"npc_cap": 42, "traffic": 0.75, "crowd": 0.8, "grass": 0.65, "grass_radius": 0.8, "range": 0.8, "shadows": 8,
			"sun_shadow": 70.0, "sun_splits": 2},
	{"npc_cap": 60, "traffic": 1.0, "crowd": 1.0, "grass": 1.0, "grass_radius": 1.0, "range": 1.0, "shadows": 16,
			"sun_shadow": 90.0, "sun_splits": 2},
	{"npc_cap": 80, "traffic": 1.0, "crowd": 1.2, "grass": 1.3, "grass_radius": 1.25, "range": 1.35, "shadows": 24,
			"sun_shadow": 140.0, "sun_splits": 4},
]

## The level last applied (-1 = none yet: tests keep the project's own numbers).
static var active: int = -1


static func level(q: int) -> Dictionary:
	return LEVELS[clampi(q, 0, LEVELS.size() - 1)]


## The current value of `key` (the High value while no level is applied, e.g. in tests).
static func value(key: String) -> Variant:
	return level(active if active >= 0 else 2)[key]


## Applies the world part of level `q` (statics read by the streamer / grass / LOD / traffic, plus the sun).
static func apply(tree: SceneTree, q: int) -> void:
	active = clampi(q, 0, LEVELS.size() - 1)
	var l: Dictionary = level(active)
	if not _cmdline_has("--npc-cap="):
		NpcStreamer.cap_override = int(l["npc_cap"])
	WorldLod.max_shadows = int(l["shadows"])
	WorldLod.set_range_scale(tree, float(l["range"]))
	GrassCover.density_scale = float(l["grass"])
	GrassCover.radius_scale = float(l["grass_radius"])
	Traffic.count_scale = float(l["traffic"])
	if NpcStreamer.current:
		NpcStreamer.current.update_now()
	var scene: Node = tree.current_scene
	if scene:
		for n: Node in scene.find_children("*", "DirectionalLight3D", true, false):
			apply_sun(n as DirectionalLight3D)
	for g: Node in tree.get_nodes_in_group(&"grass_cover"):
		if g.has_method(&"rebuild"):
			g.call(&"rebuild")


## Back to the project's own numbers (tests).
static func reset(tree: SceneTree) -> void:
	active = -1
	NpcStreamer.cap_override = -1
	WorldLod.max_shadows = WorldLod.MAX_SHADOWS
	WorldLod.set_range_scale(tree, 1.0)
	GrassCover.density_scale = 1.0
	GrassCover.radius_scale = 1.0
	Traffic.count_scale = 1.0


## The sun's shadow distance + splits (also for a sun added later: Settings._on_node_added).
static func apply_sun(sun: DirectionalLight3D) -> void:
	if active < 0 or sun == null or not sun.shadow_enabled:
		return
	sun.directional_shadow_max_distance = float(level(active)["sun_shadow"])
	sun.directional_shadow_mode = [DirectionalLight3D.SHADOW_ORTHOGONAL, DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS,
			DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS][active]


## A first guess from the hardware: integrated graphics or little RAM -> Low, older / entry cards -> Medium,
## else High. Returns [level, reason].
static func auto_level() -> Array:
	var name: String = RenderingServer.get_video_adapter_name()
	var low_name: String = name.to_lower()
	var kind: int = RenderingServer.get_video_adapter_type()
	var ram_gb: float = float(OS.get_memory_info().get("physical", 16 * 1024 * 1024 * 1024)) / (1024.0 * 1024.0 * 1024.0)
	var cores: int = OS.get_processor_count()
	return pick(low_name, kind, ram_gb, cores, name)


## The rule itself (tests feed it made-up hardware).
static func pick(low_name: String, kind: int, ram_gb: float, cores: int, shown: String = "") -> Array:
	var what: String = "%s, %.0f GB RAM, %d threads" % [shown if shown != "" else low_name, ram_gb, cores]
	if kind == RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU or kind == RenderingDevice.DEVICE_TYPE_CPU \
			or kind == RenderingDevice.DEVICE_TYPE_VIRTUAL_GPU:
		return [0, "integrated graphics (%s)" % what]
	for k: String in ["intel", "uhd", "iris", "vega 8", "radeon graphics", "radeon(tm) graphics", "780m", "680m",
			"adreno", "mali", "apple m", "llvmpipe", "swiftshader", "microsoft basic"]:
		if k in low_name:
			return [0, "integrated graphics (%s)" % what]
	if ram_gb < 7.5 or cores < 4:
		return [0, "little memory / few cores (%s)" % what]
	for k: String in ["gtx", "mx1", "mx2", "mx3", "mx4", "mx5", "rx 4", "rx 5", "rx 64", "rx 65", "rx 66", "rx 7600",
			"rtx 2050", "rtx 2060", "rtx 3050", "arc a3", "quadro", "rx vega"]:
		if k in low_name:
			return [1, "mid-range / older card (%s)" % what]
	if ram_gb < 12.0 or cores < 6:
		return [1, "average PC (%s)" % what]
	return [2, "fast PC (%s)" % what]


static func _cmdline_has(prefix: String) -> bool:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return true
	return false
