extends Node
## A district's tally as it is played (the harbour's job spec, section 7),
## counted into the job (JobState.count, the district the player is in):
## knockouts, kills, bodies found by the guards, times seen (a man come at
## the player, one in SEEN_MERGE s however many), bells rung, and the time
## spent there (pause and loading not counted). Loot, specials and
## readables are counted where they are taken (DistrictMap, JobState); their
## totals are set here from the district's own markers.

## Guard.Alert.COMBAT.
const COMBAT := 4
## Men coming at him together (or one, again and again) within this long
## are one time seen (s, game time).
const SEEN_MERGE := 10.0

var player: Node = null
var _seen_at := -INF
var _carry := 0.0
var _heard := {}


## What there is to find in `levels` (LevelLoader.Level): the loot's worth,
## the specials, the readables: {loot_total, specials_total, read_total}.
static func totals_of(levels: Array) -> Dictionary:
	var out := {"loot_total": 0, "specials_total": 0, "read_total": 0}

	for level in levels:
		for m in level.of("loot"):
			out["loot_total"] += int(m["props"].get("value", 0))

			if bool(m["props"].get("special", false)):
				out["specials_total"] += 1

		out["read_total"] += (level.of("readable") as Array).size()

	return out


## Counting for `p_player`'s district from now, its totals set.
func setup(p_player: Node, totals: Dictionary) -> void:
	player = p_player

	for key in totals:
		CityState.job.set_total(key, int(totals[key]))

	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(_listen)
	add_child(timer)
	timer.start()
	_listen()


## The men and bells not yet listened to (men come later: followers).
func _listen() -> void:
	for g in get_tree().get_nodes_in_group(&"guards"):
		if _heard.has(g):
			continue

		_heard[g] = true

		if g.has_signal("knocked_out"):
			g.knocked_out.connect(func(_body): CityState.job.count("knockouts"))
			g.died.connect(func(_body): CityState.job.count("kills"))
			g.found_body.connect(func(_body): CityState.job.count("bodies_found"))
			g.alert_changed.connect(_on_alert.bind(g))

	for bell in get_tree().get_nodes_in_group(&"alarm_bells"):
		if not _heard.has(bell):
			_heard[bell] = true
			bell.rung.connect(func(_by): CityState.job.count("alarms"))


func _on_alert(new_state: int, _old_state: int, g: Node) -> void:
	if new_state != COMBAT or g.get("_target") != player:
		return

	var now := Engine.get_physics_frames() / float(Engine.physics_ticks_per_second)

	if now - _seen_at >= SEEN_MERGE:
		CityState.job.count("seen")

	_seen_at = now


func _process(delta: float) -> void:
	_carry += delta / maxf(Engine.time_scale, 0.01)

	while _carry >= 1.0:
		_carry -= 1.0
		CityState.job.count("seconds")
