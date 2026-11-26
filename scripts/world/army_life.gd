class_name ArmyLife
extends Node
## City life point 5b (session B, 2026-11-26): Fort Halden's day rhythm on top of Zones' guard posts (part 18/21).
## Node World/ArmyLife, made by Zones._on_world on every peer; logic on the host. Uses `Soldier.start_errand` (walk a
## few straight legs, then sit / stand and chat, or be dismissed); every alarm or intruder ends an errand at once.
## - Lunch LUNCH (12:00-13:00): the chatty posts (hangars, helipads) eat in Barracks1 - two on the stools at the
##   table, the others stand round it and talk; back to their posts afterwards.
## - Night NIGHT (22:00-06:00): the chatty posts are off duty - they walk into Barracks2 and are gone; Zones doesn't
##   man those posts at night (`off_duty`). The gate, the flag, the towers and the patrols stay manned.
## - Shift change SHIFTS (06:00 / 14:00 / 22:00): every gate / flag / tower post gets a relief from Barracks3 who
##   walks to the post (a tower guard appears up there); the old one walks back to the barracks and is gone.

const LUNCH: Vector2 = Vector2(12.0, 13.0)
const NIGHT: Vector2 = Vector2(22.0, 6.0)
const SHIFTS: Array[float] = [6.0, 14.0, 22.0]
const TICK: float = 1.0
## Barracks-local places (gen_prefabs army_barracks: door gap in the S wall at x 0, table at z -3.8).
const DOOR_OUT := Vector3(0.0, 0.1, 1.6)
const DOOR_IN := Vector3(0.0, 0.1, -1.2)
const STOOLS: Array[Vector3] = [Vector3(0.0, 0.05, -4.6), Vector3(0.0, 0.05, -3.0)]
const STAND: Array[Vector3] = [Vector3(1.7, 0.1, -3.4), Vector3(-1.7, 0.1, -4.2), Vector3(1.7, 0.1, -4.4),
		Vector3(-1.7, 0.1, -3.2), Vector3(0.9, 0.1, -2.2), Vector3(-0.9, 0.1, -2.2)]
const SLEEP_SPOT := Vector3(0.0, 0.1, -5.5)

static var current: ArmyLife = null

var lunches: int = 0
var reliefs: int = 0
var _t: float = 0.0
var _last_shift: int = -1


static func attach(world: Node) -> void:
	if world == null or world.get_node_or_null(^"ArmyLife") or "--no-army-life" in OS.get_cmdline_user_args():
		return
	var c := ArmyLife.new()
	c.name = "ArmyLife"
	world.add_child(c)


func _ready() -> void:
	current = self


func _exit_tree() -> void:
	if current == self:
		current = null


func _is_host() -> bool:
	return multiplayer.multiplayer_peer == null or multiplayer.is_server()


func _hours() -> float:
	var dn := get_tree().get_first_node_in_group(&"day_night") as DayNight
	return dn.hours if dn else 12.0


static func in_window(w: Vector2, h: float) -> bool:
	return (h >= w.x and h < w.y) if w.x <= w.y else (h >= w.x or h < w.y)


## Kinds of post: "chat" (hangars / helipads: lunch + off at night), "watch" (gate / flag / towers / single posts:
## relieved per shift), "patrol" (walk all day).
static func kind_of(post: Dictionary) -> String:
	if not (post.get("route", []) as Array).is_empty():
		return "patrol"
	if post.get("chatty", false):
		return "chat"
	return "watch"


## Zones asks this before manning a post: chatty posts are empty at night.
static func off_duty(post: Dictionary, h: float) -> bool:
	return current != null and kind_of(post) == "chat" and in_window(NIGHT, h)


func _barracks(n: int) -> Node3D:
	var base: Node = get_parent().get_node_or_null(^"ArmyBase") if get_parent() else null
	return base.get_node_or_null(NodePath("Barracks%d" % n)) as Node3D if base else null


func _process(delta: float) -> void:
	if not _is_host() or Zones.alarm_on():
		return
	_t -= delta
	if _t > 0.0:
		return
	_t = TICK
	var b1: Node3D = _barracks(1)
	var b2: Node3D = _barracks(2)
	var b3: Node3D = _barracks(3)
	if b1 == null:
		return
	var h: float = _hours()
	var lunch: bool = in_window(LUNCH, h)
	var night: bool = in_window(NIGHT, h)
	var shift: int = 0
	for k: int in SHIFTS.size():
		if h >= SHIFTS[k]:
			shift = k + 1
	shift = shift % SHIFTS.size()
	var change: bool = _last_shift >= 0 and shift != _last_shift
	_last_shift = shift
	var posts: Array = Zones.guard_posts()
	var chat_i: int = 0
	for i: int in posts.size():
		var s := Zones._guards.get(i) as Soldier if Zones._guards.get(i) is Soldier else null
		if s == null or not is_instance_valid(s) or s.dead or s.target != null or s.reinforcement:
			continue
		var post: Dictionary = posts[i]
		match kind_of(post):
			"chat":
				var slot: int = chat_i
				chat_i += 1
				if night and s.errand != "dismiss" and b2:
					s.end_errand()
					s.start_errand("dismiss", _path_into(b2, SLEEP_SPOT + Vector3(0.8 * (slot % 3), 0, 0)))
					Zones._guards[i] = Zones._now() + 1.0  # (Zones won't man it again before the morning)
				elif lunch and s.errand == "":
					var sit: bool = slot < STOOLS.size()
					var spot: Vector3 = STOOLS[slot] if sit else STAND[(slot - STOOLS.size()) % STAND.size()]
					var yaw: float = NAN
					if sit:
						var to_table: Vector3 = b1.global_basis * (Vector3(0, 0, -3.8) - spot)
						yaw = atan2(-to_table.x, -to_table.z)
					s.start_errand("lunch", _path_into(b1, spot), yaw)
					lunches += 1
				elif not lunch and s.errand == "lunch":
					s.end_errand()
					s.start_errand("back", _path_out_of(b1, s.home))
				elif s.errand == "back" and s.errand_done:
					s.end_errand()
			"watch":
				if change and s.errand == "" and b3:
					_relieve(i, post, s, b3)
	# (Zones mans the chatty posts again in the morning: they come out of Barracks2 - see Zones._army_tick.)


func _path_into(b: Node3D, local: Vector3) -> Array[Vector3]:
	var out: Array[Vector3] = [b.to_global(DOOR_OUT), b.to_global(DOOR_IN), b.to_global(local)]
	return out


func _path_out_of(b: Node3D, to: Vector3) -> Array[Vector3]:
	var out: Array[Vector3] = [b.to_global(DOOR_IN), b.to_global(DOOR_OUT), to]
	return out


## Shift change at a watch post: the relief comes out of Barracks3 and walks to the post (Soldier._patrol goes home
## by itself); the old one walks into the barracks and is gone.
func _relieve(i: int, post: Dictionary, old: Soldier, b3: Node3D) -> void:
	var relief: Soldier = Zones.spawn_soldier(b3.to_global(DOOR_OUT), post["yaw"], false, post.get("gun", &"ak47"))
	if relief == null:
		return
	relief.home = post["pos"]
	relief.post_yaw = post["yaw"]
	Zones._guards[i] = relief
	reliefs += 1
	var path: Array[Vector3] = []
	if old.global_position.y - b3.global_position.y > 3.0:
		path.append(Vector3(old.global_position.x, b3.global_position.y + 0.1, old.global_position.z))  # (down the tower)
	path.append_array(_path_into(b3, Vector3(0.6, 0.1, -5.0)))
	old.start_errand("dismiss", path)


## Morning: where Zones puts a chatty post's soldier (out of Barracks2's door; the post itself otherwise).
func spawn_pos(post: Dictionary, h: float) -> Vector3:
	var b2: Node3D = _barracks(2)
	if b2 and kind_of(post) == "chat" and in_window(Vector2(NIGHT.y, NIGHT.y + 1.0), h):
		return b2.to_global(DOOR_OUT)
	return post["pos"]


## Counts for tests: {"lunch", "sitting", "off", "errands"}.
func status() -> Dictionary:
	var out: Dictionary = {"lunch": 0, "sitting": 0, "errands": 0, "soldiers": 0}
	for g: Variant in Zones._guards.values():
		if g is Soldier and is_instance_valid(g):
			var s := g as Soldier
			out["soldiers"] += 1
			if s.errand != "":
				out["errands"] += 1
			if s.errand == "lunch":
				out["lunch"] += 1
				if s._sitting:
					out["sitting"] += 1
	return out
