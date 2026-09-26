extends RefCounted
## A man's own ways at his ease: what he does with himself when there is
## nothing to do (GuardLife does the talking and notices what is out of
## place; this does the rest). Each man has his own leanings, from his
## temperament and a quirk of his own (roll), so no two keep their watch
## alike:
##   sit     a seat near his post (IdleSpot "seat"): down, a while, and up
##           again; two sat near each other talk. A dozy man in the dark nods
##           off, head down: he sees nothing and hears little until a noise
##           or a touch wakes him with a start (a man given to it, "dozes",
##           nods off wherever he sits).
##   lean    back against a wall: a "lean" spot, or the wall right behind
##           where he stands.
##   rail    forearms on a rail, looking out over it.
##   eat     bread off the provisions, eaten there.
##   chop    wood split at the block with an axe, blow on blow (heard well
##           off).
##   tend    down on his knees at the fire, or at a job of work (a cart).
##   carry   a crate from one pile to the other, and back another time.
##   visit   over to a friend at his ease nearby, for a word (GuardLife).
##   pace    a few steps off and back: a restless man.
##   fidget  where he stands: arms folded, a pull from his flask, a look
##           about or up at the sky, a nod or a shake of the head, a
##           mutter to himself, a few steps of a dance (a merry man alone).
## Carrying a light on his rounds (Guard.rounds_light), he has his head
## free only: looks and mutters. Anything that stirs him ends whatever it is
## at once: up off his seat, the crate let fall, the axe away, and he is a
## guard again.

const IdleSpotScript := preload("res://scripts/Interaction/IdleSpot.gd")
const TemperamentScript := preload("res://scripts/AISystem/Temperament.gd")
const LightProbe := preload("res://scripts/StimuliSystem/LightProbe.gd")
const SoundBus := preload("res://scripts/StimuliSystem/SoundBus.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")
const Fx := preload("res://scripts/Visual/Fx.gd")

## Guard.Alert.RELAXED, COMBAT.
const RELAXED := 0
const COMBAT := 4
## What he may do, and each one's pull on him by his temperament.
const HABITS := [&"sit", &"lean", &"rail", &"eat", &"chop", &"tend", &"carry", &"visit", &"pace", &"fidget"]
const LEANINGS := {
	&"steady": {&"sit": 1.0, &"lean": 1.0, &"rail": 0.8, &"eat": 0.7, &"chop": 0.8, &"tend": 0.8, &"carry": 0.8, &"visit": 0.8, &"pace": 0.2, &"fidget": 1.0},
	&"stubborn": {&"sit": 0.3, &"lean": 0.4, &"rail": 1.0, &"eat": 0.4, &"chop": 1.2, &"tend": 1.2, &"carry": 1.2, &"visit": 0.4, &"pace": 0.6, &"fidget": 0.7},
	&"craven": {&"sit": 1.2, &"lean": 1.4, &"rail": 0.5, &"eat": 1.2, &"chop": 0.3, &"tend": 1.0, &"carry": 0.4, &"visit": 1.6, &"pace": 0.3, &"fidget": 1.4},
	&"rash": {&"sit": 0.4, &"lean": 0.6, &"rail": 0.6, &"eat": 1.0, &"chop": 1.6, &"tend": 0.4, &"carry": 1.2, &"visit": 1.2, &"pace": 1.6, &"fidget": 1.0},
	&"sly": {&"sit": 0.8, &"lean": 1.6, &"rail": 1.4, &"eat": 1.0, &"chop": 0.3, &"tend": 0.5, &"carry": 0.3, &"visit": 0.6, &"pace": 0.4, &"fidget": 0.8},
}
## Where he stands: which fidget, by his temperament.
const FIDGETS := {
	&"steady": {&"fold_arms": 1.0, &"drink": 0.7, &"look_about": 1.0, &"look_up": 0.5, &"nod": 0.2, &"mutter": 0.4},
	&"stubborn": {&"fold_arms": 1.4, &"drink": 0.2, &"look_about": 1.2, &"look_up": 0.2, &"nod": 0.1, &"mutter": 0.3},
	&"craven": {&"fold_arms": 0.6, &"drink": 1.2, &"look_about": 1.8, &"look_up": 0.3, &"shake": 0.5, &"mutter": 0.8},
	&"rash": {&"fold_arms": 0.8, &"drink": 1.0, &"look_about": 0.6, &"look_up": 0.3, &"shake": 0.6, &"mutter": 0.6},
	&"sly": {&"fold_arms": 1.2, &"drink": 0.5, &"look_about": 1.2, &"look_up": 0.6, &"nod": 0.3, &"mutter": 0.3},
}
## Quirks, one to a man at most: what he does more than anyone (a habit or a
## fidget made much likelier), or that only he does ("dozes": nods off in his
## seat; "merry": dances when nobody is by).
const QUIRKS := [&"dozes", &"merry", &"sit", &"lean", &"eat", &"drink", &"mutter", &"pace", &"visit"]
## A quirk pulls this many times harder.
const QUIRK_PULL := 3.0
## Standing still this long, he finds something to do (and waits this long
## again after, more or less).
const IDLE_AFTER := 3.0
const BETWEEN := Vector2(3.0, 9.0)
## How far from his post (or his waypoint) he goes for it.
const RANGE := 10.0
## At ease, walking to it: this much of his patrol pace.
const STROLL := 0.85
## Given up if he cannot get there in this long.
const GO_TIMEOUT := 25.0
## Closer than this to it, the last of the way is a step into place.
const SETTLE_FROM := 1.4
const SETTLE_TIME := 0.35
## How long at each, (s).
const SIT_TIME := Vector2(15.0, 40.0)
const LEAN_TIME := Vector2(8.0, 22.0)
const RAIL_TIME := Vector2(8.0, 22.0)
const TEND_TIME := Vector2(10.0, 20.0)
const CHOPS := Vector2i(8, 16)
const CHOP_CYCLE := 0.97
## The axe meets the log this far into each swing (TreeChopping).
const CHOP_HIT := 0.32
const CHOP_DB := 52.0
## Sat this long, a dozy man in the dark may nod off; he sleeps this long if
## nothing wakes him; asleep he hears this share of what he would awake.
const DOZE_AFTER := Vector2(6.0, 12.0)
const DOZE_TIME := Vector2(20.0, 45.0)
const DOZE_DARK := 0.25
const DOZE_HEARING := 0.35
## Up off his seat in a hurry (a stir): this long.
const STAND_QUICK := 0.7
## Up in a hurry from among the furniture, it lets him through until he is
## this far off (m), or this long after (s).
const CLEAR_BY := 1.0
const CLEAR_TIME := 4.0
## A mutter to himself every this often, alone.
const MUTTER_EVERY := Vector2(45.0, 110.0)
## A friend near enough to go over to.
const VISIT_RANGE := 12.0
## Relit after a fight, this long after.
const RELIGHT := 3.0

var guard: CharacterBody3D
## His leanings (habit -> pull), his fidgets (fidget -> pull), his quirk.
var leanings := {}
var fidgets := {}
var quirk: StringName = &""
## What he is about ("" when nothing), and the spot he has for it (IdleSpot).
var habit: StringName = &""
var spot: Node3D = null

var _rolled := false
var _steps: Array = []
var _step := 0
var _t := 0.0
var _pose: StringName = &""
var _rested := 0.0
var _wait := 0.0
var _standing := 0.0
var _dozing := false
var _doze_in := INF
var _doze_left := 0.0
var _crate: RigidBody3D = null
var _crate_layers := Vector2i(1, 1)
var _held: Array = []
var _excepted: Array = []
var _sheathed := false
var _settle_from := Vector3.ZERO
## Where he stepped in among the furniture from (on the floor clear of it),
## and whether he is in among it still.
var _came_from := Vector3.ZERO
var _among := false
## Up off his seat in a hurry: the furniture lets him through until he is
## this far from where he got up, or this long after.
var _clear_of := Vector3.ZERO
var _clearing := 0.0
var _friend: Node3D = null
var _talked := false
var _look_yaw := 0.0
var _look_pitch := 0.0
var _looking: StringName = &""
var _mutter_in := 0.0
var _light_in := 0.0


func _init(p_guard: CharacterBody3D) -> void:
	guard = p_guard
	_wait = randf_range(BETWEEN.x, BETWEEN.y)
	_mutter_in = randf_range(MUTTER_EVERY.x, MUTTER_EVERY.y)


## His leanings, once his temperament is known: his class's man's (by his
## temperament's tag), each rolled either way and a quirk of his own unless
## the level pins them (Guard.habits, Guard.quirk) or nothing is rolled
## (Temperament.rolling off: exactly his tag's).
func roll() -> void:
	_rolled = true
	var tag: StringName = &"steady"
	var fighter: RefCounted = guard.get("_fighter")

	if fighter != null and fighter.temper != null:
		tag = fighter.temper.tag

	leanings = (LEANINGS.get(tag, LEANINGS[&"steady"]) as Dictionary).duplicate()
	fidgets = (FIDGETS.get(tag, FIDGETS[&"steady"]) as Dictionary).duplicate()
	var pinned: Array = guard.get("habits") if guard.get("habits") != null else []

	if not pinned.is_empty():
		for each in leanings.keys():
			leanings[each] = 1.0 if pinned.has(each) else 0.0

	if TemperamentScript.rolling:
		for each in leanings.keys():
			leanings[each] = float(leanings[each]) * randf_range(0.5, 1.5)

		for each in fidgets.keys():
			fidgets[each] = float(fidgets[each]) * randf_range(0.5, 1.5)

		if randf() < 0.6:
			quirk = QUIRKS[randi() % QUIRKS.size()]

	var set_quirk: Variant = guard.get("quirk")

	if set_quirk is StringName and set_quirk != &"":
		quirk = set_quirk

	if leanings.has(quirk):
		leanings[quirk] = float(leanings[quirk]) * QUIRK_PULL + 0.5

	if fidgets.has(quirk):
		fidgets[quirk] = float(fidgets[quirk]) * QUIRK_PULL + 0.5


# ---------------------------------------------------------------------------
# Every frame
# ---------------------------------------------------------------------------

## Every physics frame: stirred, whatever he was about is over; his light on
## his rounds kept lit; a mutter now and then.
func update(delta: float) -> void:
	_standing = maxf(_standing - delta, 0.0)
	_keep_light(delta)

	if habit == &"" and not _excepted.is_empty():
		_clearing += delta
		var off := guard.global_position - _clear_of

		if _clearing > CLEAR_TIME or Vector2(off.x, off.z).length() > CLEAR_BY:
			_unexcept()

	if habit != &"" and not _at_ease():
		interrupt()

	if _dozing:
		_doze_left -= delta

		if _doze_left <= 0.0:
			wake(false)


## Something has him (walking to it, about it).
func busy() -> bool:
	return habit != &""


## Asleep in his seat.
func dozing() -> bool:
	return _dozing


## What the rig shows: the pose he is in ("" for none of this).
func activity() -> StringName:
	if _standing > 0.0:
		return &"stand_up_quick"

	if habit == &"":
		return &""

	if _dozing:
		return &"doze"

	return _pose


## Which way his head is turned by what he is doing (yaw, pitch; radians,
## pitch up positive): a look about, up at the sky, down asleep.
func head() -> Vector2:
	if _dozing:
		return Vector2(0.0, -0.5)

	return Vector2(_look_yaw, _look_pitch)


## Standing at his post or his waypoint, nothing on: after a while he finds
## something to do. `on_rounds`: at a waypoint of his rounds (only what is
## at hand, and quickly).
func at_rest(delta: float, on_rounds := false) -> void:
	if habit != &"":
		return

	if not _rolled:
		roll()

	_rested += delta
	_mutter(delta)

	if _rested < IDLE_AFTER or guard.lookout or not _at_ease():
		return

	var life: RefCounted = guard.get("_life")

	if life != null and life.talking():
		return

	_wait -= delta

	if _wait > 0.0:
		return

	_wait = randf_range(BETWEEN.x, BETWEEN.y)
	_choose(on_rounds)


## On the move on his own business: whatever he was standing about for is
## over.
func walking() -> void:
	_rested = 0.0


## Everything he was about, dropped at once (stirred, struck): off his seat
## in a hurry, the crate let fall, the axe away.
func interrupt() -> void:
	if habit == &"":
		return

	if _pose in [&"sit_down", &"sit", &"doze", &"stand_up"] or _dozing:
		_standing = STAND_QUICK

	_dozing = false
	_drop_crate()
	_done()


## Woken by a noise, a touch, or waking of himself: a start and a word.
func wake(startled := true) -> void:
	if not _dozing:
		return

	_dozing = false
	_doze_in = INF

	if startled:
		guard.say(&"woken")

	# Awake, he sits on a little and gets up.
	if _step < _steps.size():
		_t = maxf(_t, float(_steps[_step].get("time", 0.0)) - 3.0)


# ---------------------------------------------------------------------------
# Choosing
# ---------------------------------------------------------------------------

func _choose(on_rounds: bool) -> void:
	var hands: RefCounted = guard.get("_hands")
	var lit: bool = hands != null and hands.lantern != null
	var home: Vector3 = guard.global_position if on_rounds else guard._home.origin
	var reach := 4.5 if on_rounds else float(guard.get("habit_range"))
	var options := {}

	for each in HABITS:
		var pull: float = float(leanings.get(each, 0.0))

		if pull <= 0.0:
			continue

		# A light in his hand leaves him his head only.
		if lit and each != &"fidget":
			continue

		# On his rounds only what is quick and at hand; a restless man paces
		# at his post, not on his rounds.
		if on_rounds and each in [&"chop", &"tend", &"carry", &"visit", &"pace"]:
			continue

		options[each] = pull

	while not options.is_empty():
		var each: StringName = _pick(options)
		options.erase(each)

		if _start(each, home, reach, lit):
			return


## One of `options` (name -> pull), by pull.
static func _pick(options: Dictionary) -> StringName:
	var total := 0.0

	for each in options.keys():
		total += float(options[each])

	var roll_at := randf() * total

	for each in options.keys():
		roll_at -= float(options[each])

		if roll_at <= 0.0:
			return each

	return options.keys()[0]


## Starts `each` near `home` (within `reach`) if it can be done there.
func _start(each: StringName, home: Vector3, reach: float, lit: bool) -> bool:
	var tree := guard.get_tree()

	match each:
		&"sit", &"rail", &"eat", &"chop", &"tend":
			var kind: StringName = {&"sit": &"seat", &"rail": &"rail", &"eat": &"table", &"chop": &"chop", &"tend": &"fire"}[each]
			var found := IdleSpotScript.nearest(tree, kind, home, reach, guard)

			if found == null and each == &"tend":
				found = IdleSpotScript.nearest(tree, &"work", home, reach, guard)

			if found == null or not found.claim(guard):
				return false

			spot = found
			_begin(each, _plan(each))
			return true
		&"lean":
			var found := IdleSpotScript.nearest(tree, &"lean", home, reach, guard)

			if found != null and found.claim(guard):
				spot = found
				_begin(each, _plan(each))
				return true

			# The wall right behind where he stands.
			var wall := _wall_behind()

			if wall.is_empty():
				return false

			_begin(each, [
				{"do": &"go", "to": wall["stand"]},
				{"do": &"settle", "to": wall["stand"], "face": wall["out"]},
				{"do": &"pose", "pose": &"lean", "time": randf_range(LEAN_TIME.x, LEAN_TIME.y), "rest": true, "face": wall["out"]},
			])
			return true
		&"carry":
			return _start_carry(home, reach)
		&"visit":
			return _start_visit()
		&"pace":
			var side: Vector3 = guard._home.basis.x * (1.0 if randf() < 0.5 else -1.0) * randf_range(2.5, 4.0)
			var to := NavigationServer3D.map_get_closest_point(guard.get_world_3d().navigation_map, guard._home.origin + side)

			if to.distance_to(guard._home.origin + side) > 1.0:
				return false

			_begin(each, [{"do": &"go", "to": to}, {"do": &"pose", "pose": &"", "time": 2.0, "look": &"about"}])
			return true
		&"fidget":
			return _start_fidget(lit)

	return false


func _start_fidget(lit: bool) -> bool:
	var options := {}

	for each in fidgets.keys():
		# A light in his hand: his head only.
		if lit and not (each in [&"look_about", &"look_up", &"mutter"]):
			continue

		options[each] = fidgets[each]

	# A merry man dances, when nobody is by.
	if quirk == &"merry" and not lit and _alone(10.0):
		options[&"dance"] = 2.0

	if options.is_empty():
		return false

	var each: StringName = _pick(options)

	match each:
		&"fold_arms":
			_begin(&"fidget", [{"do": &"pose", "pose": &"fold_arms", "time": randf_range(4.0, 8.0), "rest": true}])
		&"drink":
			_begin(&"fidget", [{"do": &"pose", "pose": &"drink", "time": 1.33}])
		&"look_about":
			_begin(&"fidget", [{"do": &"pose", "pose": &"", "time": 4.0, "look": &"about", "rest": true}])
		&"look_up":
			_begin(&"fidget", [{"do": &"pose", "pose": &"", "time": 3.0, "look": &"up", "rest": true}])
		&"nod":
			_begin(&"fidget", [{"do": &"pose", "pose": &"nod", "time": 2.4}])
		&"shake":
			_begin(&"fidget", [{"do": &"pose", "pose": &"shake", "time": 2.4}])
		&"dance":
			_begin(&"fidget", [{"do": &"pose", "pose": &"dance", "time": 3.75}])
		&"mutter":
			guard.say(&"mutter")
			_begin(&"fidget", [{"do": &"pose", "pose": &"" if lit else &"fold_arms", "time": 3.0, "look": &"about" if lit else &"", "rest": true}])

	return true


## What doing `each` at `spot` comes to, step by step.
func _plan(each: StringName) -> Array:
	var at: Vector3 = spot.global_position
	var facing: Vector3 = spot.facing()

	match each:
		&"sit":
			var steps: Array = [
				{"do": &"go", "to": at},
				{"do": &"settle", "to": at, "face": facing, "bodies": spot.get_meta(&"bodies", [])},
				{"do": &"pose", "pose": &"sit_down", "time": 1.6, "face": facing, "enter": _sheathe},
				{"do": &"pose", "pose": &"sit", "time": randf_range(SIT_TIME.x, SIT_TIME.y), "rest": true, "doze": true, "face": facing},
				{"do": &"pose", "pose": &"stand_up", "time": 1.25, "face": facing},
				{"do": &"settle", "back": true, "face": facing},
			]
			_doze_in = randf_range(DOZE_AFTER.x, DOZE_AFTER.y)
			return steps
		&"lean":
			return [
				{"do": &"go", "to": at},
				{"do": &"settle", "to": at, "face": facing},
				{"do": &"pose", "pose": &"lean", "time": randf_range(LEAN_TIME.x, LEAN_TIME.y), "rest": true, "face": facing},
			]
		&"rail":
			return [
				{"do": &"go", "to": at},
				{"do": &"settle", "to": at, "face": facing},
				{"do": &"pose", "pose": &"rail", "time": randf_range(RAIL_TIME.x, RAIL_TIME.y), "rest": true, "face": facing, "look": &"out"},
			]
		&"eat":
			return [
				{"do": &"go", "to": at},
				{"do": &"settle", "to": at, "face": facing},
				{"do": &"pose", "pose": &"reach", "time": 1.04, "face": facing, "at": [0.55, _take_bread], "enter": _sheathe},
				{"do": &"pose", "pose": &"eat", "time": 2.66, "face": facing, "exit": _let_go},
			]
		&"chop":
			var swings := randi_range(CHOPS.x, CHOPS.y)
			return [
				{"do": &"go", "to": at},
				{"do": &"settle", "to": at, "face": facing},
				{"do": &"pose", "pose": &"", "time": 0.3, "face": facing, "exit": _take_axe},
				{"do": &"pose", "pose": &"chop", "time": float(swings) * CHOP_CYCLE, "face": facing, "every": [CHOP_CYCLE, CHOP_HIT, _chop]},
				{"do": &"pose", "pose": &"", "time": 0.4, "face": facing, "enter": _let_go},
			]
		&"tend":
			return [
				{"do": &"go", "to": at},
				{"do": &"settle", "to": at, "face": facing},
				{"do": &"pose", "pose": &"kneel_down", "time": 1.35, "face": facing, "enter": _sheathe},
				{"do": &"pose", "pose": &"tend", "time": randf_range(TEND_TIME.x, TEND_TIME.y), "face": facing},
				{"do": &"pose", "pose": &"kneel_up", "time": 1.1, "face": facing},
			]

	return []


## A crate from the pile that has more of them to the one with fewer (even,
## from either).
func _start_carry(home: Vector3, reach: float) -> bool:
	for pile in guard.get_tree().get_nodes_in_group(&"idle_spots"):
		if pile.get("kind") != &"pile" or not pile.has_meta(&"other"):
			continue

		var other: Node3D = pile.get_meta(&"other")

		if not is_instance_valid(other) or (pile as Node3D).global_position.distance_to(home) > reach:
			continue

		# From the fuller pile; even, either way (there is always work).
		var here := _stock_at(pile).size()
		var there := _stock_at(other).size()

		if here == 0 or here < there or (here == there and randf() < 0.5) or not pile.free_for(guard) or not other.free_for(guard):
			continue

		pile.claim(guard)
		spot = pile
		var from: Vector3 = (pile as Node3D).global_position
		var to: Vector3 = other.global_position
		_begin(&"carry", [
			{"do": &"go", "to": from},
			{"do": &"settle", "to": from, "face": pile.facing()},
			{"do": &"pose", "pose": &"reach", "time": 1.04, "face": pile.facing(), "at": [0.5, _take_crate]},
			{"do": &"go", "to": to, "pose": &"carry", "spot": other},
			{"do": &"settle", "to": to, "face": other.facing(), "pose": &"carry"},
			{"do": &"pose", "pose": &"set_down", "time": 1.04, "face": other.facing(), "at": [0.5, _put_crate]},
		])
		return true

	return false


## Over to a friend at his ease, for a word.
func _start_visit() -> bool:
	var life: RefCounted = guard.get("_life")

	if life == null or float(life._talk_rest) > 0.0:
		return false

	var best: Node3D = null
	var best_distance := VISIT_RANGE

	for other in guard.get_tree().get_nodes_in_group(&"guards"):
		if other == guard or other.get("_life") == null or bool(other.get("lookout")):
			continue

		var theirs: RefCounted = other._life

		if theirs.talking() or float(theirs._talk_rest) > 0.0 or not life.at_ease(other):
			continue

		var habits: RefCounted = other.get("_habits")

		if habits != null and habits.busy():
			continue

		var distance: float = guard.global_position.distance_to(other.global_position)

		if distance < best_distance and distance > 3.0:
			best_distance = distance
			best = other

	if best == null:
		return false

	_friend = best
	_talked = false
	var toward := guard.global_position - best.global_position
	toward.y = 0.0
	var to := best.global_position + toward.normalized() * 1.4
	_begin(&"visit", [{"do": &"go", "to": to}, {"do": &"pose", "pose": &"", "time": 16.0, "rest": true, "friend": true}])
	return true


func _begin(each: StringName, steps: Array) -> void:
	habit = each
	_steps = steps
	_step = -1
	_next()


# ---------------------------------------------------------------------------
# Doing it
# ---------------------------------------------------------------------------

## Every physics frame while something has him (Guard._do_patrol): the next
## of its steps.
func run(delta: float) -> void:
	if habit == &"":
		return

	if _step >= _steps.size():
		_done()
		return

	var step: Dictionary = _steps[_step]
	_t += delta

	match step["do"]:
		&"go":
			_go(step, delta)
		&"settle":
			_settle(step, delta)
		&"pose":
			_hold(step, delta)


func _go(step: Dictionary, delta: float) -> void:
	_pose = step.get("pose", &"")
	var to: Vector3 = step["to"]
	var life: RefCounted = guard.get("_life")

	# On his way: not a man at rest for a word (GuardLife) until he is there.
	if life != null:
		life.walking()

	var arrived: bool = guard._walk(float(guard.patrol_speed) * STROLL, delta)
	var flat := Vector2(to.x - guard.global_position.x, to.z - guard.global_position.z).length()

	if (arrived and flat < SETTLE_FROM) or flat < 0.25:
		_next()
		return

	# Nowhere near and no way on: not today.
	if _t > GO_TIMEOUT or (arrived and flat >= SETTLE_FROM) or guard._path_blocked:
		interrupt()


## The last of the way: a step into place (among the seat's legs, under the
## table's edge), turning to face as he does. "back": the step out again, to
## where he stepped in from.
func _settle(step: Dictionary, delta: float) -> void:
	var back: bool = step.get("back", false)

	if _t <= delta:
		_settle_from = guard.global_position

		if not back:
			_came_from = guard.global_position

		for body in step.get("bodies", []):
			if body is PhysicsBody3D and is_instance_valid(body):
				guard.add_collision_exception_with(body)
				_excepted.append(body)
				_among = true

	_pose = step.get("pose", &"")
	var to: Vector3 = _came_from if back else step["to"]
	var u := clampf(_t / SETTLE_TIME, 0.0, 1.0)
	var at := _settle_from.lerp(to, smoothstep(0.0, 1.0, u))
	guard.global_position = Vector3(at.x, guard.global_position.y, at.z)
	guard.velocity = Vector3(0.0, guard.velocity.y, 0.0)
	guard._face(step["face"], delta, 2.5)

	if u >= 1.0:
		if back:
			_among = false

		_next()


func _hold(step: Dictionary, delta: float) -> void:
	_pose = step.get("pose", &"")
	guard.velocity = Vector3(0.0, guard.velocity.y, 0.0)
	var life: RefCounted = guard.get("_life")

	if step.has("face"):
		guard._face(step["face"], delta, 2.0)

	# Where talk may start (GuardLife: two men at rest near each other).
	if step.get("rest", false) and life != null:
		life.at_rest(delta)

	if step.get("friend", false):
		_with_friend(step, delta, life)

	_look(step.get("look", &""), delta)

	# Sat in the dark, a dozy man nods off.
	if step.get("doze", false) and not _dozing:
		_doze_in -= delta

		if _doze_in <= 0.0:
			_doze_in = INF

			# A man given to it sleeps anywhere; others only in the dark.
			if quirk == &"dozes" or (_dozy() and LightProbe.light_at(guard, guard.eye_position()) < DOZE_DARK):
				_dozing = true
				_doze_left = randf_range(DOZE_TIME.x, DOZE_TIME.y)
				# Asleep, he sits out his sleep.
				_t = minf(_t, float(step["time"]) - _doze_left - 3.0)

	if _dozing:
		return

	var timed: Array = step.get("at", [])

	if not timed.is_empty() and _t - delta < float(timed[0]) and _t >= float(timed[0]):
		(timed[1] as Callable).call()

	var every: Array = step.get("every", [])

	if not every.is_empty():
		var period: float = every[0]
		var offset: float = every[1]

		if fmod(_t - offset + period, period) < delta and _t >= offset:
			(every[2] as Callable).call()

	if _t >= float(step["time"]):
		_next()


## Visiting: facing his friend, and once they have talked (or plainly will
## not), done.
func _with_friend(step: Dictionary, delta: float, life: RefCounted) -> void:
	if _friend == null or not is_instance_valid(_friend) or not life.at_ease(_friend):
		_t = float(step["time"])
		return

	if life.talking():
		_talked = true
		guard._face(life.partner_direction(), delta)
		_t = minf(_t, float(step["time"]) - 1.0)
		return

	guard._face(_friend.global_position - guard.global_position, delta)

	# The word over; or none forthcoming.
	if _talked or _t > 6.0:
		_t = float(step["time"])


## His head, by what he is looking at: about him, up at the sky, out over the
## rail; else straight.
func _look(kind: StringName, delta: float) -> void:
	_looking = kind
	var yaw := 0.0
	var pitch := 0.0

	match kind:
		&"about":
			yaw = sin(_t * 1.6) * 1.0
		&"up":
			pitch = 0.55 * clampf(_t / 0.8, 0.0, 1.0)
		&"out":
			yaw = sin(_t * 0.5) * 0.5
			pitch = -0.15

	_look_yaw = lerpf(_look_yaw, yaw, 1.0 - exp(-4.0 * delta))
	_look_pitch = lerpf(_look_pitch, pitch, 1.0 - exp(-4.0 * delta))


func _next() -> void:
	if _step >= 0 and _step < _steps.size():
		var leaving: Dictionary = _steps[_step]

		if leaving.has("exit"):
			(leaving["exit"] as Callable).call()

	_step += 1
	_t = 0.0

	if _step >= _steps.size():
		_done()
		return

	var step: Dictionary = _steps[_step]

	if step["do"] == &"go":
		guard._go_to(step["to"], true)

		# To the other pile: that one is his now.
		if step.has("spot"):
			var next_spot: Node3D = step["spot"]

			if spot != null and is_instance_valid(spot):
				spot.release(guard)

			spot = next_spot

			if spot != null:
				spot.claim(guard)

	if step.has("enter"):
		(step["enter"] as Callable).call()


## Over (done, or dropped): the spot free, his hands empty, his blade back in
## them, and nothing between him and the furniture.
func _done() -> void:
	if spot != null and is_instance_valid(spot):
		spot.release(guard)

	spot = null
	habit = &""
	_steps = []
	_step = 0
	_pose = &""
	_friend = null
	_looking = &""
	_look_yaw = 0.0
	_look_pitch = 0.0
	_dozing = false
	_let_go()
	_unsheathe()
	_rested = 0.0

	# Stepped back out: nothing between him and the furniture. Still in among
	# it (up in a hurry): not until he is clear of it (update).
	if _among:
		_among = false
		_clear_of = guard.global_position
		_clearing = 0.0
	else:
		_unexcept()


func _unexcept() -> void:
	for body in _excepted:
		if is_instance_valid(body):
			guard.remove_collision_exception_with(body)

	_excepted.clear()


func _at_ease() -> bool:
	var life: RefCounted = guard.get("_life")
	return int(guard.state) == RELAXED and (life == null or life.at_ease(guard))


func _dozy() -> bool:
	var fighter: RefCounted = guard.get("_fighter")
	var tag: StringName = fighter.temper.tag if fighter != null and fighter.temper != null else &"steady"
	return tag in [&"steady", &"sly"] and TemperamentScript.rolling and randf() < 0.25


func _alone(reach: float) -> bool:
	for other in guard.get_tree().get_nodes_in_group(&"guards"):
		if other != guard and (other as Node3D).global_position.distance_to(guard.global_position) < reach:
			return false

	return true


## Alone and at rest a long while, he says something to himself.
func _mutter(delta: float) -> void:
	_mutter_in -= delta * (2.0 if quirk == &"mutter" else 1.0)

	if _mutter_in > 0.0:
		return

	_mutter_in = randf_range(MUTTER_EVERY.x, MUTTER_EVERY.y)

	if _alone(6.0):
		guard.say(&"mutter")


## The wall right behind him at his post, if there is one: where he stands
## to lean on it, and the way he looks from it.
func _wall_behind() -> Dictionary:
	var back: Vector3 = guard._home.basis.z
	back.y = 0.0

	if back.length() < 0.01:
		return {}

	back = back.normalized()
	var from: Vector3 = guard._home.origin + Vector3.UP * 1.2
	var query := PhysicsRayQueryParameters3D.create(from, from + back * 1.3, 1, [guard.get_rid()])
	var hit := guard.get_world_3d().direct_space_state.intersect_ray(query)

	if hit.is_empty():
		return {}

	var normal: Vector3 = hit["normal"]

	if normal.dot(-back) < 0.8 or absf(normal.y) > 0.3:
		return {}

	var out := Vector3(normal.x, 0.0, normal.z).normalized()
	var stand := Vector3((hit["position"] as Vector3).x, guard._home.origin.y, (hit["position"] as Vector3).z) + out * 0.36
	return {"stand": stand, "out": out}


# ---------------------------------------------------------------------------
# Things in his hands
# ---------------------------------------------------------------------------

## His blade put by while his hands are busy (and back after).
func _sheathe() -> void:
	var rig: Node = guard.get("_rig")

	if rig != null and rig.get("weapon") != null:
		rig.weapon.visible = false
		_sheathed = true


func _unsheathe() -> void:
	if not _sheathed:
		return

	_sheathed = false
	var rig: Node = guard.get("_rig")
	var hands: RefCounted = guard.get("_hands")

	if rig != null and rig.get("weapon") != null and hands != null:
		rig.weapon.visible = hands.armed and hands.held == null and not (hands.lantern != null and hands.light_kind == &"lantern")


func _take_bread() -> void:
	_hold_thing(&"hand_l", _bread(), Transform3D(Basis.IDENTITY, Vector3(0.0, 0.08, 0.04)))


func _take_axe() -> void:
	_sheathe()
	_hold_thing(&"hand_r", _axe(), Transform3D(Basis.IDENTITY, Vector3(0.0, 0.1, 0.0)))


## Something put in his hand (on `bone`), until he lets go of it.
func _hold_thing(bone: StringName, thing: Node3D, offset: Transform3D) -> void:
	var rig: Node = guard.get("_rig")
	var man: Node3D = rig.get("man") if rig != null else null

	if man == null or not man.has_method("attach"):
		thing.free()
		return

	_held.append(man.attach(bone, thing, offset))


func _let_go() -> void:
	for holder in _held:
		if is_instance_valid(holder):
			holder.queue_free()

	_held.clear()


## A blow of the axe on the log: heard well off, chips flying.
func _chop() -> void:
	var at: Vector3 = guard.global_position + guard.global_basis * Vector3(0.0, 0.5, -0.7)
	Sfx.play(guard, &"thud_wood", at, 2.0, randf_range(0.9, 1.1))
	Fx.dust(guard, at, Vector3.UP, 0.35, "wood")
	SoundBus.emit_sound(at, CHOP_DB, guard, &"chop")


static func _bread() -> Node3D:
	var box := BoxMesh.new()
	box.size = Vector3(0.1, 0.06, 0.14)
	var bread := MeshInstance3D.new()
	bread.mesh = box
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.62, 0.43, 0.2)
	bread.material_override = paint
	return bread


## A woodsman's axe: a haft, and the head across its end.
static func _axe() -> Node3D:
	var axe := Node3D.new()
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.4, 0.28, 0.16)
	var haft := MeshInstance3D.new()
	var haft_mesh := BoxMesh.new()
	haft_mesh.size = Vector3(0.035, 0.62, 0.035)
	haft.mesh = haft_mesh
	haft.material_override = paint
	axe.add_child(haft)
	haft.position = Vector3(0.0, 0.2, 0.0)
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.35, 0.35, 0.38)
	iron.metallic = 0.7
	var head := MeshInstance3D.new()
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.03, 0.12, 0.17)
	head.mesh = head_mesh
	head.material_override = iron
	axe.add_child(head)
	head.position = Vector3(0.0, 0.47, -0.06)
	return axe


## The stock ("stock" group) lying by `pile`.
static func _stock_at(pile: Node3D) -> Array:
	var ahead: Vector3 = pile.global_position + pile.facing() * 0.75
	var found := []

	for crate in pile.get_tree().get_nodes_in_group(&"stock"):
		if is_instance_valid(crate) and (crate as Node3D).global_position.distance_to(ahead) < 1.4:
			found.append(crate)

	return found


## A crate off the pile, up against his chest.
func _take_crate() -> void:
	var stock := _stock_at(spot) if spot != null else []

	if stock.is_empty():
		interrupt()
		return

	var best: RigidBody3D = null
	var best_distance := INF

	for crate in stock:
		var distance: float = (crate as Node3D).global_position.distance_to(guard.global_position)

		if crate is RigidBody3D and distance < best_distance:
			best_distance = distance
			best = crate

	var rig: Node = guard.get("_rig")
	var man: Node3D = rig.get("man") if rig != null else null

	if best == null or man == null:
		interrupt()
		return

	_sheathe()
	_crate = best
	_crate_layers = Vector2i(best.collision_layer, best.collision_mask)
	best.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	best.freeze = true
	best.collision_layer = 0
	best.collision_mask = 0
	var holder := Node3D.new()
	_held.append(man.attach(&"spine_03", holder, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 0.0))))
	best.reparent(holder, false)
	# Held out before him at his chest, whichever way the bone lies.
	best.global_position = guard.global_position + guard.global_basis * Vector3(0.0, 1.02, -0.36)
	best.global_basis = guard.global_basis
	best.reset_physics_interpolation()
	Sfx.play(guard, &"grab", best.global_position, -4.0)


## The crate set down on this pile.
func _put_crate() -> void:
	if _crate == null or not is_instance_valid(_crate) or spot == null:
		return

	var crate := _crate
	_crate = null
	var level: Node = guard.get_parent()
	crate.reparent(level, true)
	var ahead: Vector3 = spot.global_position + spot.facing() * 0.75
	var drop := ahead + Vector3.UP * 0.35 + Vector3(randf_range(-0.2, 0.2), 0.0, randf_range(-0.2, 0.2))

	# Stacked on what is there.
	for other in _stock_at(spot):
		if other != crate and (other as Node3D).global_position.y + 0.45 > drop.y:
			drop.y = (other as Node3D).global_position.y + 0.46

	crate.global_position = drop
	crate.global_basis = Basis.IDENTITY
	crate.collision_layer = _crate_layers.x
	crate.collision_mask = _crate_layers.y
	crate.freeze = false
	crate.linear_velocity = Vector3.ZERO
	crate.reset_physics_interpolation()
	Sfx.play(guard, &"thud_wood", drop, -6.0, 0.9)


## Stirred with a crate in his arms: he lets it fall.
func _drop_crate() -> void:
	if _crate == null or not is_instance_valid(_crate):
		_crate = null
		return

	var crate := _crate
	_crate = null
	crate.reparent(guard.get_parent(), true)
	crate.collision_layer = _crate_layers.x
	crate.collision_mask = _crate_layers.y
	crate.freeze = false
	crate.linear_velocity = guard.velocity * 0.5 + Vector3.DOWN


# ---------------------------------------------------------------------------
# A light on his rounds
# ---------------------------------------------------------------------------

## A man set to walk his rounds with a light (Guard.rounds_light) has it lit:
## at once at first, and again a while after a fight took it from him.
func _keep_light(delta: float) -> void:
	var kind: StringName = guard.get("rounds_light") if guard.get("rounds_light") != null else &""
	var hands: RefCounted = guard.get("_hands")

	if kind == &"" or hands == null:
		return

	if hands.lantern != null or int(guard.state) == COMBAT:
		_light_in = RELIGHT
		return

	_light_in -= delta

	if _light_in > 0.0 or hands.busy() or guard.is_downed() or guard.get("_knocked_out") == true:
		return

	var climb: RefCounted = guard.get("_climb")
	var water: RefCounted = guard.get("_water")

	if (climb != null and climb.active()) or (water != null and water.swimming):
		return

	hands.carry_light(kind)
