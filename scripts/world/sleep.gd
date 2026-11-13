class_name Sleep
extends Node
## Point 37: sleeping in a bed skips the night (World/Sleep, host logic).
## A player presses E on a bed in a crew-owned property between SLEEP_FROM and SLEEP_UNTIL
## (Player.request_sleep -> host). Their screen goes dark ("waiting for the others").
## Once EVERY player in the game is in bed the clock jumps to WAKE_HOUR, all stations
## (plants, drying racks, safes, deliveries) catch up on the skipped hours, everyone wakes
## up healed. Moving (or Esc) gets you out of bed again. Not while you are wanted.

const SLEEP_FROM: float = 20.0
const SLEEP_UNTIL: float = 6.0
const WAKE_HOUR: float = 7.0
const BED_RANGE: float = 3.0

## Host: players in bed (Player -> true).
var sleepers: Dictionary = {}


static func current(tree: SceneTree) -> Sleep:
	return tree.current_scene.get_node_or_null("Sleep") as Sleep if tree and tree.current_scene else null


static func is_sleep_time(hours: float) -> bool:
	return hours >= SLEEP_FROM or hours < SLEEP_UNTIL


## Host: why `p` can't go to bed now ("" = it can).
func refuse_reason(p: Player) -> String:
	var dn := get_tree().get_first_node_in_group(&"day_night") as DayNight
	if p.dead:
		return "You're dead."
	if dn and not is_sleep_time(dn.hours):
		return "You're not tired. You can sleep from %02d:00." % int(SLEEP_FROM)
	if p.wanted_stars > 0:
		return "You can't sleep with the police after you."
	if bed_near(p) == null:
		return "Get closer to your bed."
	return ""


## A bed of your crew (placed furniture "bed") close to `p`, or null.
func bed_near(p: Player) -> Node3D:
	for n: Node in get_tree().get_nodes_in_group(&"placed"):
		var f := n as PlacedFurniture
		if f and f.item_id == "bed" and f.global_position.distance_to(p.global_position) < BED_RANGE:
			return f
	return null


## Host: `p` gets into bed (on) or out of it.
func host_set(p: Player, on: bool) -> void:
	if on:
		var why: String = refuse_reason(p)
		if why != "":
			p.show_message(why)
			return
		sleepers[p] = true
		print("[Sleep] %s goes to bed" % p.player_name)
	else:
		if not sleepers.has(p):
			return
		sleepers.erase(p)
		p.host_sleep_state(false, "You got out of bed.")
		print("[Sleep] %s gets up" % p.player_name)
	_update()


## Host: tell every sleeper how many are in bed; everyone asleep -> morning.
func _update() -> void:
	var everyone: Array[Player] = []
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var pl := n as Player
		if pl and pl.is_inside_tree():
			everyone.append(pl)
	for pl: Variant in sleepers.keys():
		if not is_instance_valid(pl) or not (pl as Player).is_inside_tree():
			sleepers.erase(pl)
	if everyone.is_empty():
		return
	if sleepers.size() >= everyone.size():
		_morning()
		return
	for pl: Variant in sleepers:
		(pl as Player).host_sleep_state(true, "Sleeping... waiting for the others (%d/%d in bed).\nMove to get up." % [
				sleepers.size(), everyone.size()])


## Host: jump to WAKE_HOUR; the stations catch up on the skipped hours.
func _morning() -> void:
	var dn := get_tree().get_first_node_in_group(&"day_night") as DayNight
	var skipped: float = fposmod(WAKE_HOUR - (dn.hours if dn else WAKE_HOUR), 24.0)
	if dn:
		dn.set_hours(WAKE_HOUR)
	for n: Node in get_tree().get_nodes_in_group(&"stations"):
		var st := n as Station
		if st and st.tick(skipped):
			st.changed()
	print("[Sleep] everyone slept: %.1f h skipped, it's %02d:00" % [skipped, int(WAKE_HOUR)])
	for pl: Variant in sleepers:
		var p := pl as Player
		p.health = Player.MAX_HEALTH
		p.host_sleep_state(false, "Good morning. You slept until %02d:00." % int(WAKE_HOUR))
	sleepers.clear()


## Host: a player leaves (called while it is still in the tree): check again once it is gone.
func host_forget(p: Player) -> void:
	sleepers.erase(p)
	_update.call_deferred()
