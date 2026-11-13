class_name Wanted
extends Node
## Point 28: the wanted level (GTA style, 1-5 stars per player). Lives under World; the
## logic runs on the host only, the stars reach every peer through Player.wanted_stars /
## wanted_seen (HostSync). Numbers in data/police/wanted.tres (WantedConfig).
## - Stars come from crimes (`report`): a gun heard by the police = 1 (point 28a: only
##   holding a weapon gives nothing), kills add heat (heat_for_star), killing / shooting at
##   an officer or resisting = 2+.
## - The host checks every tick who the police can see (officers, patrol cars). Point 28b:
##   out of sight the search phase runs (HUD stars blink): ONE timer of search_time[stars]
##   seconds (faster inside your own property); when it runs out ALL stars go at once,
##   seen again = it starts over. 0 stars: every officer drops you, sent cars go home.
## - Response: police cars are sent along the roads to the last known spot
##   (units_per_star), with bigger, heavier crews and road blocks at 4-5 stars.
##   How they treat you (arrest / shoot) is PoliceOfficer._should_shoot.
## - Arrest or death clears the stars.

const CONFIG: WantedConfig = preload("res://data/police/wanted.tres")
const TICK: float = 0.25

static var current: Wanted
## Tests / scenarios without police: no stars at all.
static var enabled: bool = true

var config: WantedConfig = CONFIG
## Host: send cars after wanted players (off in the self-test / netcheck, which spawn their own).
var dispatch: bool = true

## Host: Player -> { heat, away (seconds unseen, scaled), last_known, next_dispatch, roadblocks: [Car] }
var _state: Dictionary = {}


func _ready() -> void:
	name = "Wanted"
	current = self
	enabled = true  # (a scenario without police switches it off again)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--selftest" in args or "--netcheck" in args:
		dispatch = false
	if multiplayer.is_server():
		_loop()


func _exit_tree() -> void:
	if current == self:
		current = null


static func stars_of(p: Player) -> int:
	return p.wanted_stars if p else 0


# --- Crimes (host) ---------------------------------------------------------------------

## Host: a crime by `p` at `pos`. Kinds: &"heard" (the police heard a shot),
## &"kill", &"kill_officer", &"kill_rival" (only counts when the police see it), &"assault",
## &"resist".
static func report(p: Player, kind: StringName, pos: Vector3) -> void:
	if current == null or not enabled or p == null or p.dead or not current.multiplayer.is_server():
		return
	current._report(p, kind, pos)


func _report(p: Player, kind: StringName, pos: Vector3) -> void:
	var st: Dictionary = _st(p)
	var floor_stars: int = 0
	match kind:
		&"heard":
			floor_stars = 1
		&"kill":
			st["heat"] = int(st["heat"]) + config.kill_heat
		&"kill_rival":
			if not _police_sees(p):
				return
			st["heat"] = int(st["heat"]) + config.kill_heat
		&"kill_officer":
			st["heat"] = int(st["heat"]) + config.officer_kill_heat
			floor_stars = config.officer_kill_stars
		&"assault":
			floor_stars = config.assault_stars
		&"resist":
			floor_stars = config.resist_stars
	var stars: int = maxi(p.wanted_stars, maxi(floor_stars, _stars_for_heat(int(st["heat"]))))
	stars = mini(stars, 5)
	# The police know where it happened: the search starts there, the clock restarts.
	st["last_known"] = pos
	st["away"] = 0.0
	if stars > p.wanted_stars:
		print("[Wanted] %s: %d star(s) (%s)" % [p.player_name, stars, kind])
		var first: bool = p.wanted_stars == 0
		p.wanted_stars = stars
		if first:
			p.show_message("WANTED! Lose the police: stay out of sight, or hide in your own place.")
		st["next_dispatch"] = 0.0  # send help now
	# Heat never sits below what the stars stand for (stars can come from other things).
	st["heat"] = maxi(int(st["heat"]), _heat_for(stars))


func _stars_for_heat(heat: int) -> int:
	var s: int = 0
	for i: int in config.heat_for_star.size():
		if heat >= config.heat_for_star[i]:
			s = i + 1
	return s


func _heat_for(stars: int) -> int:
	return 0 if stars <= 0 else config.heat_for_star[mini(stars, config.heat_for_star.size()) - 1]


## Host: arrested or dead: no stars any more.
static func clear(p: Player, why: String) -> void:
	if current == null or p == null or not current.multiplayer.is_server():
		return
	current._clear(p, why)


func _clear(p: Player, why: String) -> void:
	var had: int = p.wanted_stars
	_state.erase(p)
	p.wanted_stars = 0
	p.wanted_seen = false
	_end_roadblocks_for(p)
	if had > 0:
		print("[Wanted] %s: cleared (%s)" % [p.player_name, why])
		get_tree().call_group(&"police", "on_wanted_cleared", p)


func _st(p: Player) -> Dictionary:
	if not _state.has(p):
		_state[p] = {"heat": 0, "away": 0.0, "last_known": p.global_position, "next_dispatch": 0.0, "roadblocks": []}
	return _state[p]


## Host: where the police think `p` is.
static func last_known(p: Player) -> Vector3:
	if current == null or not current._state.has(p):
		return p.global_position if p else Vector3.INF
	return current._state[p]["last_known"]


## Tests / scenarios: put `p` at `stars` right away (the police know where they are).
func debug_set(p: Player, stars: int) -> void:
	var st: Dictionary = _st(p)
	st["heat"] = _heat_for(stars)
	st["last_known"] = p.global_position
	st["away"] = 0.0
	st["next_dispatch"] = 0.0
	p.wanted_stars = stars


# --- Every tick (host) -----------------------------------------------------------------

func _loop() -> void:
	while is_inside_tree():
		await get_tree().create_timer(TICK).timeout
		if not enabled:
			continue
		var now: float = Time.get_ticks_msec() / 1000.0
		for n: Node in get_tree().get_nodes_in_group(&"players"):
			var p := n as Player
			if p == null or not p.is_inside_tree():
				continue
			if p.dead:
				if p.wanted_stars > 0:
					_clear(p, "dead")
				continue
			if p.wanted_stars > 0:
				_tick_wanted(p, now)
		for p: Variant in _state.keys():
			if not is_instance_valid(p):
				_state.erase(p)


func _tick_wanted(p: Player, now: float) -> void:
	var st: Dictionary = _st(p)
	var seen: bool = false
	for o: PoliceOfficer in _officers():
		if o.can_see(p):
			seen = true
			if o.target == null or not is_instance_valid(o.target) or o.target.dead:
				o._alert(p, p.global_position)
	for c: Car in _cars():
		if not c.abandoned and c.global_position.distance_to(p.global_position) < config.car_sight_range and c.can_see(p):
			seen = true
			c.respond(p, p.global_position)
	if seen:
		st["last_known"] = p.global_position
		st["away"] = 0.0
	else:
		var rate: float = config.hide_multiplier if _hiding(p) else 1.0
		st["away"] = float(st["away"]) + TICK * rate
		if float(st["away"]) >= search_left(p, 0.0):
			_clear(p, "lost the police")
			p.show_message("You lost the police.")
			return
	if p.wanted_seen != seen:
		p.wanted_seen = seen
	if dispatch:
		_dispatch(p, st, now)
		_roadblocks(p, st)


## Inside a property the player's crew owns (the Crows don't go there either).
func _hiding(p: Player) -> bool:
	var prop: Property = Placement.property_at(get_tree(), p.global_position)
	return prop != null and prop.is_crew_owned()


func _officers() -> Array[PoliceOfficer]:
	var out: Array[PoliceOfficer] = []
	for n: Node in get_tree().get_nodes_in_group(&"police"):
		if n is PoliceOfficer and not (n as PoliceOfficer).dead and (n as Node).is_inside_tree():
			out.append(n)
	return out


func _cars() -> Array[Car]:
	var out: Array[Car] = []
	for n: Node in get_tree().get_nodes_in_group(&"police"):
		if n is Car and (n as Car).police and not (n as Car).wrecked and (n as Node).is_inside_tree():
			out.append(n)
	return out


## Host: seconds of the search phase still to go for `p` (`away` = seconds already out
## of sight; pass 0.0 for the full time).
func search_left(p: Player, away: float = -1.0) -> float:
	if away < 0.0:
		away = float(_st(p)["away"]) if _state.has(p) else 0.0
	var full: float = config.search_time[mini(p.wanted_stars, config.search_time.size() - 1)]
	return maxf(0.0, full - away)


func _police_sees(p: Player) -> bool:
	for o: PoliceOfficer in _officers():
		if o.can_see(p):
			return true
	return false


# --- Response (host) -------------------------------------------------------------------

func _traffic() -> Traffic:
	return get_parent().get_node_or_null("Traffic") as Traffic


## Send police cars until units_per_star extra cars are after the player (point 28c: the
## normal patrol cars don't count, so every star adds units).
func _dispatch(p: Player, st: Dictionary, now: float) -> void:
	if now < float(st["next_dispatch"]):
		return
	var traffic: Traffic = _traffic()
	if traffic == null or traffic.routes.is_empty():
		return
	var cars: Array[Car] = _cars()
	var after: int = 0
	for c: Car in cars:
		if c.chase == p and c.dispatched and not c.roadblock:
			after += 1
	var want: int = config.units_per_star[mini(p.wanted_stars, config.units_per_star.size() - 1)]
	if after >= want or cars.size() >= config.max_police_cars:
		return
	st["next_dispatch"] = now + config.dispatch_interval
	var at: Vector3 = st["last_known"]
	var near: Array = traffic.nearest(at)
	var route: TrafficRoute = traffic.routes[near[0]]
	# Upstream: the car drives towards the spot along its own lane.
	var prog: float = fposmod(float(near[1]) - config.dispatch_distance, route.length)
	var car: Car = traffic.spawn_police_car(near[0], prog, _crew(p), p.wanted_stars >= config.heavy_stars)
	car.dispatched = true
	car.chase = p
	car.siren = true
	print("[Wanted] car %s sent after %s (%d star(s), %d/%d cars)" % [car.name, p.player_name, p.wanted_stars, after + 1, want])


func _crew(p: Player) -> int:
	return config.crew_per_star[mini(p.wanted_stars, config.crew_per_star.size() - 1)]


## 4-5 stars: a police car across the road somewhere ahead of the player, crew out.
func _roadblocks(p: Player, st: Dictionary) -> void:
	var blocks: Array = st["roadblocks"]
	for b: Variant in blocks.duplicate():
		if not is_instance_valid(b):
			blocks.erase(b)
		elif (b as Car).global_position.distance_to(p.global_position) > 130.0:
			(b as Car).end_roadblock()
			blocks.erase(b)
	if p.wanted_stars < config.roadblock_stars:
		for b: Variant in blocks:
			(b as Car).end_roadblock()
		blocks.clear()
		return
	if not blocks.is_empty():
		return
	var total: int = 0
	for c: Car in _cars():
		if c.roadblock:
			total += 1
	if total >= config.max_roadblocks:
		return
	var traffic: Traffic = _traffic()
	if traffic == null:
		return
	var dir := Vector3(p.velocity.x, 0, p.velocity.z)
	var spot: Array = traffic.spot_ahead(p.global_position, dir, 35.0, 60.0)
	if spot.is_empty():
		return
	var car: Car = traffic.spawn_police_car(spot[0], spot[1], _crew(p), p.wanted_stars >= config.heavy_stars)
	car.chase = p
	car.start_roadblock()
	blocks.append(car)
	print("[Wanted] road block %s for %s at %s" % [car.name, p.player_name, car.global_position.snapped(Vector3.ONE)])


func _end_roadblocks_for(p: Player) -> void:
	for c: Car in _cars():
		if c.roadblock and c.chase == p:
			c.end_roadblock()
