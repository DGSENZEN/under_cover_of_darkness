extends RefCounted
## A guard's stations (GuardStation), when he is at his ease: he walks to his
## station and does its thing, the next one of his rota when he is done with
## one (rummaging through one chest after another). Getting up is part of it:
## whatever stirs him (Guard._set_state leaving RELAXED: stir) ends it the way
## the station ends: a sitter stands, a sleeper scrambles up (slowest to react
## of anyone), the carrier drops his crate where he is (loose: something to
## throw), the quartermaster lets the lid bang shut. He does not go back until
## he has been at his ease a while (STATION_RETURN).
##
## Asleep, he sees nothing (Guard._sense_vision) and hears only loud things
## (Guard.hear_sound: SLEEP_HEARING of what an awake man hears).
##
## Pure behaviour: what the rig shows comes from `activity()` (GuardRig's
## activity clips), timed to the clips by the lengths below.

const GuardStationScript := preload("res://scripts/AISystem/GuardStation.gd")
const SoundBus := preload("res://scripts/StimuliSystem/SoundBus.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")

## Guard.Alert.RELAXED.
const RELAXED := 0
## Getting down and up (the clips' lengths, s): onto a seat, off it, down onto
## a bedroll, up off it (LayToIdle).
const SIT_DOWN := 1.6
const STAND_UP := 1.3
const LIE_DOWN := 1.5
const WAKE := 1.5
## A chest's lid, up or down; a crate lifted or set down (s).
const LID := 0.9
const LIFT := 1.0
const SET_DOWN := 1.0
## How long he goes through a chest (s).
const RUMMAGE_TIME := Vector2(6.0, 10.0)
## Eating: a bite or a drink this often, lasting this long (s).
const EAT_EVERY := Vector2(6.0, 11.0)
const CONSUME := 1.33
## Chopping: a rest (a pull from his flask) this often, lasting this long.
const REST_EVERY := Vector2(15.0, 25.0)
const REST := 1.3
## Stirred from his station, this long at his ease before he goes back (s).
const STATION_RETURN := 6.0
## Asleep, this much of an awake man's hearing.
const SLEEP_HEARING := 0.15
## Where a crate sits as he carries it, in his own frame.
const CARRY_OFFSET := Vector3(0.0, 1.0, -0.42)
## A crate this near a pick-up point is his to carry; where he sets them down,
## each goes this far along from the last.
const CARGO_REACH := 1.8
## He lifts a crate this near him; one up on a cart, from this near when he
## can get no nearer.
const CRATE_REACH := 1.3
const CRATE_REACH_UP := 1.8
const STACK_STEP := 0.55
## Near enough his station to settle onto it (m), and how fast he eases the
## rest of the way.
const ARRIVE := 0.6
const SETTLE := 4.0
## What a man going through chests mutters.
const RUMMAGE_LINES := [
	"Where's the damned lamp oil...",
	"Who's been at the salt pork?",
	"Candles, candles... not a one left.",
]
## The lid banged shut: how loud.
const LID_BANG_DB := 50.0

enum Step { NONE, GOING, ENTER, DOING, EXIT }

var guard: CharacterBody3D
## The crate in his arms (carry).
var carried: RigidBody3D = null

var _stations: Array[Node3D] = []
var _index := 0
var _step := Step.NONE
var _t := 0.0
var _length := 0.0
var _activity: StringName = &""
var _asleep := false
## Stirred: at his ease this long since (going back at STATION_RETURN).
var _stirred := false
var _calm := 0.0
## What he does next while at it: a bite, a rest, the time left at a chest.
var _next_at := 0.0
var _left := 0.0
var _said := false
## Carrying: the crate he is going for, and which end is which.
var _crate: RigidBody3D = null
var _swapped := false
var _set_count := 0
## Where his path was last asked for.
var _going_to := Vector3.INF
## Lent a station for a while (a gathering): his own rota kept aside.
var _lent := false
var _own: Array[Node3D] = []


func _init(p_guard: CharacterBody3D) -> void:
	guard = p_guard


## His stations, from Guard.stations.
func setup(paths: Array[NodePath]) -> void:
	for path in paths:
		var station := guard.get_node_or_null(path) as Node3D

		if station != null and station.get_script() == GuardStationScript:
			_stations.append(station)


func has_stations() -> bool:
	return not _stations.is_empty()


## What the rig shows: "sit_down", "sit", "sit_talk", "stand_up", "eat",
## "lie_down", "sleep", "wake", "lid", "rummage", "lift", "carry",
## "set_down", "chop", "lean", "drink", or "".
func activity() -> StringName:
	return _activity if _step != Step.NONE and _step != Step.GOING else (&"carry" if carried != null else &"")


## Standing up or getting up off his bedroll: nothing else until he is up.
func busy() -> bool:
	return _step == Step.EXIT and (_activity == &"stand_up" or _activity == &"wake")


func asleep() -> bool:
	return _asleep


## At a station (not on his way to one) with his blade put away: all but the
## chopper, whose blade is what he chops with.
func sheathed() -> bool:
	if carried != null:
		return true

	if _step == Step.NONE or _step == Step.GOING:
		return false

	var station := _held()
	return station == null or StringName(station.kind) != &"chop"


## Every physics frame he is up and about, whatever his state: the crate in
## his arms goes where he goes; getting up runs its course.
func update(delta: float) -> void:
	if carried != null and is_instance_valid(carried):
		carried.global_transform = Transform3D(guard.global_basis, guard.global_transform * CARRY_OFFSET)

	# Getting up runs its course (stirred, or taken off his station).
	if _step == Step.EXIT:
		_t += delta

		if _t >= _length:
			_step = Step.NONE
			_activity = &""


## At his ease (Guard._do_patrol): to his station, and at it.
func patrol(delta: float) -> void:
	if _stirred:
		_calm += delta
		guard._stop(delta)
		guard._life.at_rest(delta)

		if _calm < STATION_RETURN:
			return

		_stirred = false
		_step = Step.NONE

	var station := _current()

	if station == null:
		guard._stop(delta)
		guard._life.at_rest(delta)
		return

	_t += delta

	match StringName(station.kind):
		&"rummage":
			_rummage(station, delta)
		&"carry":
			_carry(station, delta)
		_:
			_stay(station, delta)


## Woken and kept up (a boot from the captain): off his station the way it
## ends, and not back to it for `seconds` at his ease.
func roused(seconds := 60.0) -> void:
	stir()
	_calm = STATION_RETURN - seconds


## His stations now `nodes` (a new duty: NightRota); off the one he is at,
## the way it ends.
func set_stations(nodes: Array) -> void:
	_leave_station()
	_stations.clear()

	for node in nodes:
		if node is Node3D:
			_stations.append(node)

	_index = 0
	_lent = false


## Lent `station` for a while (a gathering): he goes to it and does its
## thing; his own rota waits.
func lend(station: Node3D) -> void:
	if not _lent:
		_own = _stations.duplicate()

	_leave_station()
	_stations.clear()
	_stations.append(station)
	_index = 0
	_lent = true


## The loan over: off it, back to his own rota.
func end_loan() -> void:
	if not _lent:
		return

	_leave_station()
	_stations = _own.duplicate()
	_own.clear()
	_index = 0
	_lent = false


func on_loan() -> bool:
	return _lent


## Settled at his station and at it.
func at_station() -> bool:
	return _step == Step.DOING


## Off the station he holds, the way it ends (a sitter stands, a sleeper gets
## up, a crate is dropped, an open lid shut), without being stirred.
func _leave_station() -> void:
	if carried != null and is_instance_valid(carried):
		_drop(carried, guard.velocity)

	carried = null
	_crate = null
	_asleep = false
	_going_to = Vector3.INF
	var station := _held()

	if station == null:
		if _step != Step.EXIT:
			_step = Step.NONE
			_activity = &""

		return

	var kind := StringName(station.kind)

	if kind == &"rummage":
		var chest: Node3D = station.chest_node()

		if chest != null and bool(chest.get("is_open")):
			chest.frob(guard)

	station.release(guard)

	if kind == &"sit" and (_step == Step.ENTER or _step == Step.DOING):
		_begin(Step.EXIT, &"stand_up", STAND_UP)
	elif kind == &"sleep" and (_step == Step.ENTER or _step == Step.DOING):
		# Got up at nobody's alarm: he yawns.
		_begin(Step.EXIT, &"wake", WAKE)
		Sfx.play(guard, &"yawn", guard.eye_position(), -2.0)
	else:
		_step = Step.NONE
		_activity = &""


## Down or dead (Guard._let_go): the crate in his arms falls loose, an open
## lid is shut, his station is free for another.
func release() -> void:
	if carried != null and is_instance_valid(carried):
		_drop(carried, guard.velocity)

	carried = null
	_crate = null
	_asleep = false
	var station := _held()

	if station != null:
		var chest: Node3D = station.chest_node() if StringName(station.kind) == &"rummage" else null

		if chest != null and bool(chest.get("is_open")):
			chest.frob(guard)

		station.release(guard)

	_step = Step.NONE
	_activity = &""


## Something stirred him: his station is over, the way it ends.
func stir() -> void:
	var station := _held()

	_asleep = false
	_stirred = true
	_calm = 0.0
	_going_to = Vector3.INF

	if carried != null and is_instance_valid(carried):
		_drop(carried, guard.velocity)

	carried = null
	_crate = null

	if station != null:
		var kind := StringName(station.kind)

		if kind == &"rummage":
			var chest: Node3D = station.chest_node()

			if chest != null and bool(chest.get("is_open")):
				chest.frob(guard)
				SoundBus.emit_sound(chest.global_position + Vector3.UP * 0.4, LID_BANG_DB, guard, &"clang")

		station.release(guard)

		if kind == &"sit" and (_step == Step.ENTER or _step == Step.DOING or _step == Step.EXIT):
			_begin(Step.EXIT, &"stand_up", STAND_UP)
			return

		if kind == &"sleep" and (_step == Step.ENTER or _step == Step.DOING):
			_begin(Step.EXIT, &"wake", WAKE)
			return

	_step = Step.NONE
	_activity = &""


# ---------------------------------------------------------------------------
# At a station
# ---------------------------------------------------------------------------

## The station of his rota he is on, claimed; the next free one if another
## man has it; null if none is free.
func _current() -> Node3D:
	for i in range(_stations.size()):
		var station: Node3D = _stations[(_index + i) % _stations.size()]

		if station != null and is_instance_valid(station) and station.claim(guard):
			if i != 0:
				_index = (_index + i) % _stations.size()
				_step = Step.NONE

			return station

	return null


## The station he holds now, if any.
func _held() -> Node3D:
	for station in _stations:
		if station != null and is_instance_valid(station) and station.holder == guard:
			return station

	return null


func _begin(step: Step, activity: StringName, length := 0.0) -> void:
	_step = step
	_activity = activity
	_t = 0.0
	_length = length


## Walks to `point`. True once there.
func _walk_to(point: Vector3, delta: float) -> bool:
	if _flat(guard.global_position, point) < ARRIVE:
		_going_to = Vector3.INF
		return true

	if _step == Step.NONE:
		_begin(Step.GOING, &"")

	if _going_to == Vector3.INF or _going_to.distance_to(point) > 0.3:
		_going_to = point
		guard._go_to(point, true)

	guard._life.walking()

	if guard._walk(guard.patrol_speed, delta):
		# Done before the navmesh answered is not there: ask again.
		if _flat(guard.global_position, point) >= ARRIVE:
			guard._go_to(point, true)

	return false


## Eased onto the spot and turned to face the station's way.
func _settle(station: Node3D, delta: float) -> void:
	var to: Vector3 = station.global_position - guard.global_position
	to.y = 0.0
	var ease := to * SETTLE
	guard.velocity.x = ease.x
	guard.velocity.z = ease.z
	guard._face(station.facing(), delta, 2.0)


## Sit, eat, sleep, lean, chop: there, and at it until something stirs him.
func _stay(station: Node3D, delta: float) -> void:
	var kind := StringName(station.kind)

	if _step == Step.NONE or _step == Step.GOING:
		if not _walk_to(station.global_position, delta):
			return

		match kind:
			&"sit":
				_begin(Step.ENTER, &"sit_down", SIT_DOWN)
			&"sleep":
				_begin(Step.ENTER, &"lie_down", LIE_DOWN)
			&"eat":
				_begin(Step.DOING, &"")
				_next_at = randf_range(EAT_EVERY.x, EAT_EVERY.y) * 0.5
			_:
				_begin(Step.DOING, kind)
				_next_at = randf_range(REST_EVERY.x, REST_EVERY.y)

	_settle(station, delta)

	if _step == Step.ENTER:
		if _t >= _length:
			_begin(Step.DOING, &"sleep" if kind == &"sleep" else &"sit")
			_next_at = randf_range(EAT_EVERY.x, EAT_EVERY.y)

		return

	match kind:
		&"sit":
			guard._life.at_rest(delta)
			_activity = &"sit_talk" if guard._life.talking() else &"sit"
		&"eat":
			# On his feet with his bowl (the library eats standing): a bite
			# now and then; between, whatever GuardLife has him do (a word
			# with a friend, arms folded).
			guard._life.at_rest(delta)

			if _activity == &"eat" and _t >= _next_at + CONSUME:
				_activity = &""
				_next_at = _t + randf_range(EAT_EVERY.x, EAT_EVERY.y)
			elif _activity != &"eat" and _t >= _next_at and not guard._life.talking():
				_activity = &"eat"
		&"sleep":
			_asleep = true
			_activity = &"sleep"
		&"chop":
			if _activity == &"drink" and _t >= _next_at + REST:
				_activity = &"chop"
				_next_at = _t + randf_range(REST_EVERY.x, REST_EVERY.y)
			elif _activity == &"chop" and _t >= _next_at:
				_activity = &"drink"
		&"lean":
			# (Set to watch, his eyes sweep his ground as he leans: Guard's
			# own head does that at his ease.)
			_activity = &"lean"


## Rummage: lid up, a look through it (a line muttered), lid down, the next.
func _rummage(station: Node3D, delta: float) -> void:
	var chest: Node3D = station.chest_node()

	if _step == Step.NONE or _step == Step.GOING:
		if not _walk_to(station.global_position, delta):
			return

		_begin(Step.ENTER, &"lid", LID)
		_said = false

		if chest != null and not bool(chest.get("is_open")):
			chest.frob(guard)

	_settle(station, delta)

	match _step:
		Step.ENTER:
			if _t >= _length:
				_begin(Step.DOING, &"rummage")
				_left = randf_range(RUMMAGE_TIME.x, RUMMAGE_TIME.y)
		Step.DOING:
			if not _said and _t >= _left * 0.5:
				_said = true
				guard.bark(RUMMAGE_LINES[randi() % RUMMAGE_LINES.size()])

			if _t >= _left:
				_begin(Step.EXIT, &"lid", LID)

				if chest != null and bool(chest.get("is_open")):
					chest.frob(guard)
		Step.EXIT:
			if _t >= _length:
				station.release(guard)
				_index = (_index + 1) % _stations.size()
				_step = Step.NONE
				_activity = &""


## Carry: to a crate at one end, up with it, to the other end, down with it.
func _carry(station: Node3D, delta: float) -> void:
	var drop: Node3D = station.drop_node()

	if drop == null:
		guard._stop(delta)
		return

	var from: Vector3 = drop.global_position if _swapped else station.global_position
	var to: Vector3 = station.global_position if _swapped else drop.global_position

	# In his arms: to the other end, and down with it.
	if carried != null:
		if _step == Step.EXIT:
			guard._stop(delta)

			if _t >= _length:
				_drop(carried, Vector3.ZERO, to + _stack_offset(station))
				carried = null
				_set_count += 1
				_step = Step.NONE
				_activity = &""

			return

		if _walk_to(to, delta):
			_begin(Step.EXIT, &"set_down", SET_DOWN)

		return

	if _step == Step.ENTER:
		guard._stop(delta)

		if _crate != null and is_instance_valid(_crate):
			guard._face(_crate.global_position - guard.global_position, delta, 2.0)

		if _t >= _length:
			if _crate != null and is_instance_valid(_crate):
				_lift(_crate)

			_crate = null
			_step = Step.NONE
			_activity = &""

		return

	# To the next crate at this end; none left here, the other end's are
	# carried back.
	if _crate == null or not is_instance_valid(_crate) or _flat(_crate.global_position, from) > CARGO_REACH:
		_crate = _cargo_near(from)

		if _crate == null:
			if _cargo_near(to) != null:
				_swapped = not _swapped
				_set_count = 0

			guard._stop(delta)
			return

	# Within arm's reach of it; or, a crate up on something (the cart), as
	# near as the ground lets him get.
	var near := _flat(guard.global_position, _crate.global_position)
	var beside: Vector3 = _crate.global_position + (guard.global_position - _crate.global_position).normalized() * 0.55
	beside.y = guard.global_position.y

	if near < CRATE_REACH:
		_begin(Step.ENTER, &"lift", LIFT)
		return

	_walk_to(beside, delta)

	if near < CRATE_REACH_UP and guard._agent.is_navigation_finished():
		_begin(Step.ENTER, &"lift", LIFT)


func _cargo_near(point: Vector3) -> RigidBody3D:
	var best: RigidBody3D = null
	var best_distance := CARGO_REACH

	for thing in guard.get_tree().get_nodes_in_group(&"cargo"):
		if not (thing is RigidBody3D) or thing == carried:
			continue

		var d := _flat((thing as Node3D).global_position, point)

		if d <= best_distance:
			best_distance = d
			best = thing as RigidBody3D

	return best


## Where the next crate set down goes: along from the last, sideways to the
## way he faces at that end.
func _stack_offset(station: Node3D) -> Vector3:
	var side: Vector3 = station.facing().cross(Vector3.UP).normalized()
	return side * (float(_set_count % 4) - 1.5) * STACK_STEP + Vector3.UP * 0.3


func _lift(crate: RigidBody3D) -> void:
	carried = crate
	crate.freeze = true
	crate.collision_layer = 0
	crate.collision_mask = 0
	_begin(Step.GOING, &"carry")
	Sfx.play(guard, &"thud_wood", crate.global_position, -8.0, 1.2)


## Out of his arms: set down at `at`, or dropped where he is with `velocity`.
func _drop(crate: RigidBody3D, velocity: Vector3, at := Vector3.INF) -> void:
	if at != Vector3.INF:
		crate.global_transform = Transform3D(guard.global_basis, at)

	crate.collision_layer = 1
	crate.collision_mask = 1
	crate.freeze = false
	crate.linear_velocity = velocity
	crate.reset_physics_interpolation()


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
