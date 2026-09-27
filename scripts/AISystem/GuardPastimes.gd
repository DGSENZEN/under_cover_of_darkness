extends RefCounted
## What a man at his ease does with himself standing about (at his post, a
## waypoint, between bites of his supper): warms his hands at the fire,
## squats by it, stamps his feet, scratches, takes a drink, folds his arms,
## leans on a wall, looks his blade over, looks up at the tower, paces a few
## steps, spits, rolls his shoulders.
##
## Chosen by dual utility: the most pressing kind first (cold, then tired,
## then plain idleness), then a pick by weight among the options near the
## best, weighted by his temperament and less for what he did lately. Never
## the same twice running, never three times in five. Each has what it
## needs (a fire near, a wall behind him, his blade out, the tower in
## view, room to pace), a length, and a rest before it comes again.
##
## What he does is `activity()` (GuardRig and Expression show it); pacing
## moves him (`wants_step`: Guard walks him there and back). His own ways
## (GuardHabits: a seat, a wall, a friend) come first: he passes the time
## between them, and they wait for it.

## Reached at run time (it reads the guard scripts too).
const NIGHT_ROTA := "res://scripts/AISystem/NightRota.gd"

## Standing still this long, a man finds something to do with himself; then
## between pastimes this long (x his rhythm, Expression).
const IDLE_AFTER := 3.0
const GAP := Vector2(2.0, 6.0)
## Options worth this much of the best are in the running.
const POOL := 0.8
## What he did lately counts against doing it again: the last, the one
## before...
const MEMORY := [0.5, 0.3, 0.2, 0.1, 0.05]
## Kinds, most pressing first, and when each presses.
const COLD_AT := 0.5
const TIRED_AT := 0.6
const STAMP_COLD := 0.4
## id -> {cat, needs, len (s), cd (s)}.
const OPTIONS := {
	&"warm_hands": {"cat": &"cold", "needs": &"fire", "len": Vector2(6.0, 12.0), "cd": 20.0},
	&"squat": {"cat": &"cold", "needs": &"fire_close", "len": Vector2(8.0, 15.0), "cd": 40.0},
	&"stamp": {"cat": &"cold", "needs": &"cold", "len": Vector2(3.0, 5.0), "cd": 15.0},
	&"lean": {"cat": &"tired", "needs": &"wall", "len": Vector2(8.0, 14.0), "cd": 30.0},
	&"scratch": {"cat": &"idle", "needs": &"", "len": Vector2(2.0, 3.6), "cd": 25.0},
	&"drink": {"cat": &"idle", "needs": &"", "len": Vector2(1.33, 1.33), "cd": 30.0},
	&"fold_arms": {"cat": &"idle", "needs": &"", "len": Vector2(5.0, 9.0), "cd": 10.0},
	&"check_blade": {"cat": &"idle", "needs": &"blade", "len": Vector2(2.5, 4.0), "cd": 45.0},
	&"look_up": {"cat": &"idle", "needs": &"tower", "len": Vector2(3.0, 5.0), "cd": 40.0},
	&"pace": {"cat": &"idle", "needs": &"room", "len": Vector2(6.0, 10.0), "cd": 35.0},
	&"spit": {"cat": &"idle", "needs": &"", "len": Vector2(1.0, 1.0), "cd": 50.0},
	&"roll_shoulders": {"cat": &"idle", "needs": &"", "len": Vector2(1.5, 1.5), "cd": 30.0},
}
const CATEGORIES := [&"cold", &"tired", &"idle"]
## At a station (between bites): only what his hands and head can do there.
const IN_PLACE := [&"stamp", &"scratch", &"drink", &"fold_arms", &"check_blade", &"look_up", &"spit", &"roll_shoulders", &"warm_hands"]
## What a temperament does more (over 1) or less of.
const TEMPER_WEIGHT := {
	&"rash": {&"stamp": 1.3, &"spit": 1.5, &"roll_shoulders": 1.4, &"check_blade": 1.5, &"fold_arms": 0.8},
	&"craven": {&"look_up": 1.5, &"pace": 1.5, &"scratch": 1.3, &"drink": 1.3, &"check_blade": 0.6},
	&"stubborn": {&"fold_arms": 1.6, &"lean": 0.6, &"spit": 1.2},
	&"sly": {&"lean": 1.6, &"scratch": 0.7, &"look_up": 1.2},
}
## Near enough to warm his hands; to squat by it.
const FIRE_REACH := 3.0
const FIRE_CLOSE := 2.5
## A wall this near behind or beside him to lean on (felt at this height).
const WALL_REACH := 1.0
const WALL_HEIGHT := 1.1
## The tower this near, in view.
const TOWER_REACH := 35.0
## Pacing: this far out, and back; there when this near (his path stops
## him 0.6 m short of where it goes); at this much of his walking pace.
const PACE_OUT := 2.0
const PACE_THERE := 0.7
const PACE_SPEED := 0.6

var guard: CharacterBody3D

var _clock := 0.0
var _history: Array[StringName] = []
var _ready_at := {}
var _doing: StringName = &""
var _left := 0.0
var _wait := 0.0
var _pace_to := Vector3.INF
var _pace_from := Vector3.INF
var _pacing_back := false
static var _rota_script: GDScript = null


func _init(p_guard: CharacterBody3D) -> void:
	guard = p_guard
	_wait = randf_range(GAP.x, GAP.y)


## Every physics frame (his clock, for the rests between pastimes).
func update(delta: float) -> void:
	_clock += delta


## Standing still (his post, a waypoint, his station between bites).
func at_rest(delta: float) -> void:
	var life: RefCounted = guard.get("_life")

	if (life != null and life.talking()) or bool(guard.get("lookout")):
		_end()
		return

	if _doing != &"":
		_left -= delta

		if _doing == &"pace":
			_pace_on()

		if _left <= 0.0:
			_end()

		return

	if life == null or float(life._resting) < IDLE_AFTER:
		return

	_wait -= delta

	if _wait > 0.0:
		return

	var pick := _pick(true)

	if pick == &"":
		_wait = 1.0
		return

	_begin(pick)


## On the move: whatever he was doing standing is over (but pacing is his).
func walking() -> void:
	if _doing != &"pace":
		_doing = &""
		_left = 0.0


## What he is doing: one of OPTIONS, or "".
func activity() -> StringName:
	return _doing


## Pacing: where he is walking to now; else null.
func wants_step() -> Variant:
	return (_pace_from if _pacing_back else _pace_to) if _doing == &"pace" else null


## `id` begun now, if what it needs is there (GuardHabits hands him its
## "pace": a few steps out and back, facing his ground). False if not.
func start(id: StringName) -> bool:
	if not OPTIONS.has(id) or not _has(StringName(OPTIONS[id]["needs"]), _needs()):
		return false

	_end()
	_begin(id)
	return _doing == id


## Whatever he is passing the time with, over (something of his own has him:
## GuardHabits).
func stop() -> void:
	if _doing != &"":
		_end()


## A pick now (for checks): what he would choose, remembered as if done,
## whatever the rests between them.
func choose() -> StringName:
	var pick := _pick(false)

	if pick != &"":
		_remember(pick)

	return pick


## What he did lately, the newest last.
func history() -> Array[StringName]:
	return _history


# ---------------------------------------------------------------------------
# Choosing
# ---------------------------------------------------------------------------

func _pick(rested_only: bool) -> StringName:
	var needs := _needs()

	for cat in CATEGORIES:
		if cat == &"cold" and float(needs.get("cold", 0.0)) < COLD_AT:
			continue

		if cat == &"tired" and float(needs.get("tired", 0.0)) < TIRED_AT:
			continue

		var pool := _options(cat, rested_only, needs)

		if not pool.is_empty():
			return _weighted(pool)

	return &""


## The options of `cat` open to him now, each with its worth.
func _options(cat: StringName, rested_only: bool, needs: Dictionary) -> Array:
	var tag := _tag()
	var weights: Dictionary = TEMPER_WEIGHT.get(tag, {})
	var at_station := _at_station()
	var found := []

	for id in OPTIONS:
		var option: Dictionary = OPTIONS[id]

		if option["cat"] != cat or (at_station and not IN_PLACE.has(id)):
			continue

		if rested_only and _clock < float(_ready_at.get(id, -INF)):
			continue

		# Never twice running, never three times in five.
		if not _history.is_empty() and _history[-1] == id:
			continue

		if _history.slice(maxi(_history.size() - 4, 0)).count(id) >= 2:
			continue

		if not _has(StringName(option["needs"]), needs):
			continue

		var penalty := 0.0

		for i in range(_history.size()):
			var back := _history.size() - 1 - i

			if back < MEMORY.size() and _history[i] == id:
				penalty += float(MEMORY[back])

		found.append([id, float(weights.get(id, 1.0)) * maxf(1.0 - penalty, 0.05)])

	if found.is_empty():
		return found

	var best: float = found.map(func(f): return float(f[1])).max()
	return found.filter(func(f): return float(f[1]) >= best * POOL)


func _weighted(pool: Array) -> StringName:
	var total := 0.0

	for f in pool:
		total += float(f[1])

	var roll := randf() * total

	for f in pool:
		roll -= float(f[1])

		if roll <= 0.0:
			return f[0]

	return pool[-1][0]


## What an option needs, there.
func _has(need: StringName, needs: Dictionary) -> bool:
	match need:
		&"":
			return true
		&"cold":
			return float(needs.get("cold", 0.0)) >= STAMP_COLD
		&"fire":
			return _fire_within(FIRE_REACH)
		&"fire_close":
			return _fire_within(FIRE_CLOSE)
		&"wall":
			return _wall_near()
		&"blade":
			var rota: RefCounted = guard.get("_rota")
			var rig: Variant = guard.get("_rig")
			return (rota == null or not rota.sheathed()) and rig != null and rig.weapon != null and rig.weapon.visible
		&"tower":
			return _tower_in_view()
		&"room":
			return _pace_point() != Vector3.INF

	return false


# ---------------------------------------------------------------------------
# Doing
# ---------------------------------------------------------------------------

func _begin(id: StringName) -> void:
	var option: Dictionary = OPTIONS[id]
	_doing = id
	_left = randf_range(option["len"].x, option["len"].y)
	_ready_at[id] = _clock + _left + float(option["cd"])
	_remember(id)

	match id:
		&"pace":
			_pace_to = _pace_point()
			_pace_from = guard.global_position
			_pacing_back = false

			if _pace_to == Vector3.INF:
				_end()
		&"spit":
			guard.emote("spits")
		&"roll_shoulders":
			guard.emote("shrugs")


func _end() -> void:
	if _doing != &"":
		var rhythm := 1.0
		var rig: Variant = guard.get("_rig")

		if rig != null and rig.get("expression") != null:
			rhythm = float(rig.expression.traits.get("rhythm", 1.0))

		_wait = randf_range(GAP.x, GAP.y) * rhythm

	_doing = &""
	_left = 0.0
	_pace_to = Vector3.INF


## Pacing: out, then back to where he stood; done once back.
func _pace_on() -> void:
	var goal := _pace_from if _pacing_back else _pace_to
	var there := Vector2(goal.x - guard.global_position.x, goal.z - guard.global_position.z).length() < PACE_THERE

	if not there:
		return

	if _pacing_back:
		_end()
	else:
		_pacing_back = true


func _remember(id: StringName) -> void:
	_history.append(id)

	if _history.size() > MEMORY.size():
		_history.pop_front()


# ---------------------------------------------------------------------------
# Where he is
# ---------------------------------------------------------------------------

func _needs() -> Dictionary:
	if _rota_script == null:
		_rota_script = load(NIGHT_ROTA)

	var rota: RefCounted = _rota_script.of(guard)
	return rota.needs_of(guard) if rota != null else {}


func _at_station() -> bool:
	var rota: RefCounted = guard.get("_rota")
	return rota != null and rota._held() != null


func _fire_within(reach: float) -> bool:
	for fire in guard.get_tree().get_nodes_in_group(&"fires"):
		var at := (fire as Node3D).global_position
		var flat := Vector2(at.x - guard.global_position.x, at.z - guard.global_position.z).length()

		if flat <= reach:
			return true

	return false


func _wall_near() -> bool:
	var space := guard.get_world_3d().direct_space_state
	var from := guard.global_position + Vector3.UP * WALL_HEIGHT
	var basis := guard.global_basis

	for way in [basis.z, basis.x, -basis.x]:
		var query := PhysicsRayQueryParameters3D.create(from, from + (way as Vector3).normalized() * WALL_REACH, 1)
		query.exclude = [guard.get_rid()]

		if not space.intersect_ray(query).is_empty():
			return true

	return false


func _tower_in_view() -> bool:
	for mark in guard.get_tree().get_nodes_in_group(&"landmarks"):
		if String(mark.get_meta(&"landmark", "")) != "the tower":
			continue

		var at := (mark as Node3D).global_position

		if at.distance_to(guard.global_position) <= TOWER_REACH and guard._line_of_sight(guard.eye_position(), at, null):
			return true

	return false


## A point PACE_OUT ahead of him on the navmesh, or INF if there is none.
func _pace_point() -> Vector3:
	var agent := guard.get_node_or_null("NavigationAgent3D") as NavigationAgent3D

	if agent == null:
		return Vector3.INF

	var wanted := guard.global_position - guard.global_basis.z * PACE_OUT
	var map := agent.get_navigation_map()
	var on := NavigationServer3D.map_get_closest_point(map, wanted)

	if Vector2(on.x - wanted.x, on.z - wanted.z).length() > 0.3 or absf(on.y - guard.global_position.y) > 0.5:
		return Vector3.INF

	return on


func _tag() -> StringName:
	var fighter: RefCounted = guard.get("_fighter")
	return fighter.temper.tag if fighter != null and fighter.temper != null else &"steady"
