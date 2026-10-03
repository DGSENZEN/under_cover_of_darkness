extends RefCounted
## Owns individual idle activities and their equipment/spot claims.
## Temperament, quirk and configured habits weight sitting, dozing, leaning, eating,
## working, carrying, visiting and fidgeting. GuardLife owns conversation/oddities;
## GuardPastimes fills idle gaps. Interrupting releases spots and drops carried props.

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
## Closer than this to it, the last of the way is a step into place: walked
## at this pace (m/s, on the whole), and never quicker than SETTLE_TIME.
const SETTLE_FROM := 1.4
const SETTLE_TIME := 0.35
const SETTLE_PACE := 0.9
## At a table: he draws the chair out this far (m) to sit down and to get
## up, clear of the table's edge, and in to the table once he is sat, taking
## this long (s) over it.
const PULL_OUT := 0.25
const SCOOT_TIME := 0.6
## How long at each, (s).
const SIT_TIME := Vector2(15.0, 40.0)
const LEAN_TIME := Vector2(8.0, 22.0)
const RAIL_TIME := Vector2(8.0, 22.0)
const TEND_TIME := Vector2(10.0, 20.0)
const CHOPS := Vector2i(8, 16)
## Each blow of the axe (GuardRig shows it): pulled out of the log and lifted
## back over his head, held there a breath, brought down, and left in the log
## a moment. It lands CHOP_HIT into each.
const CHOP_LIFT := 0.62
const CHOP_HOLD := 0.16
const CHOP_DOWN := 0.15
const CHOP_REST := 0.25
const CHOP_CYCLE := CHOP_LIFT + CHOP_HOLD + CHOP_DOWN + CHOP_REST
const CHOP_HIT := CHOP_LIFT + CHOP_HOLD + CHOP_DOWN
const CHOP_DB := 52.0
## Where the axe bites the log, from where he stands (a man of his class's
## own size; a bigger man reaches further): before him and to his left
## (Furnishings.chopping_block puts him there).
const CHOP_AT := Vector3(-0.37, 0.66, -1.2)
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
## A friend near enough to go over to.
const VISIT_RANGE := 12.0
## Relit after a fight, this long after.
const RELIGHT := 3.0
## The axe through his right fist near the end of its haft (hand bone space,
## as Humanoid.FIST_R), as he holds his sword: the head out of the thumb's
## side, the edge the way his knuckles go.
const AXE_GRIP := Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0)), Vector3(-0.03, 0.08, 0.0)) * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.06, 0.0))
## Bread in the palm of his left hand, along his fist; a bite out of it with
## each mouthful (the eating clip's hand at his mouth this far into each
## loop of it), this much of it left after each.
const BREAD_GRIP := Transform3D(Basis.IDENTITY, Vector3(0.035, 0.07, 0.03))
const EAT_CYCLE := 1.33
const BITE_AT := 0.75
const BITE_LEFT := 0.7
## Sitting down: his weight on the seat this far into it (s).
const SEATED_AT := 0.95
## A flask off his belt for a pull from it, upright in his left fist, its
## neck out of the thumb's side (as Humanoid.FIST_L): up at his mouth as the
## hand comes to it. In his hand this far into the drink.
const FLASK_GRIP := Transform3D(Basis(Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0)), Vector3(0.03, 0.08, 0.0))
const FLASK_AT := 0.12
## At the fire, a log pushed in (sparks up, the flame flares) this often (s),
## the first this long in.
const STOKE_EVERY := 3.3
const STOKE_FIRST := 1.2
## Wary (Guard.wary: a hunt not long since, the garrison roused), nothing
## that takes his hands or his eyes off his ground: a few steps, a look about,
## a word to himself.
const WARY_HABITS := [&"pace", &"fidget"]
const WARY_FIDGETS := [&"look_about", &"mutter"]
## Poses that leave his head free to look round at someone (GuardLife: a
## man going by, a greeting, the man he talks with).
const HEAD_FREE := [&"", &"sit", &"lean", &"rail", &"fold_arms", &"eat", &"carry"]

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
var _settle_time := SETTLE_TIME
## The pace he came into it at (world, flat).
var _settle_v := Vector3.ZERO
## Stepping into place: how fast he goes (world, flat), for his legs (the rig):
## he is put there, not walked, and they would stand still. Zero otherwise.
var _stepping := Vector3.ZERO
## The bread in his hand, bitten into as he eats.
var _bread_held: Node3D = null
## Where he stepped in among the furniture from (on the floor clear of it),
## and whether he is in among it still.
var _came_from := Vector3.ZERO
var _among := false
## Up off his seat in a hurry: the furniture lets him through until he is
## this far from where he got up, or this long after.
var _clear_of := Vector3.ZERO
var _clearing := 0.0
## What a step moves along with him (a chair drawn out or in), from where.
var _moved_from := Vector3.ZERO
## Sat in to a table: its chair, where he and it go to get out from under
## its edge; and, up in a hurry, how far through that shove he is.
var _tucked: Dictionary = {}
var _shove: Dictionary = {}
var _friend: Node3D = null
var _talked := false
var _look_yaw := 0.0
var _look_pitch := 0.0
var _looking: StringName = &""
var _light_in := 0.0


func _init(p_guard: CharacterBody3D) -> void:
	guard = p_guard
	_wait = randf_range(BETWEEN.x, BETWEEN.y)


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


# Every frame

## Every physics frame: stirred, whatever he was about is over; his light on
## his rounds kept lit. (A word to himself, alone, is the TalkDirector's:
## its remarks.)
func update(delta: float) -> void:
	_standing = maxf(_standing - delta, 0.0)
	_stepping = Vector3.ZERO
	_keep_light(delta)
	_shove_back(delta)

	if habit == &"" and not _excepted.is_empty():
		_clearing += delta
		var off := guard.global_position - _clear_of

		if _clearing > CLEAR_TIME or Vector2(off.x, off.z).length() > CLEAR_BY:
			_unexcept()

	# Stirred, or plainly not at ease: whatever it was is over. A little on
	# his mind, short of suspicious, and he carries on.
	if habit != &"" and not _at_ease(true):
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


## On his way over to a friend for a word, or with him for it ("visit"): the
## friend; else null.
func visiting() -> Node3D:
	return _friend if habit == &"visit" and is_instance_valid(_friend) else null


## What the rig shows: the pose he is in ("" for none of this).
func activity() -> StringName:
	if _standing > 0.0:
		return &"stand_up_quick"

	if habit == &"":
		return &""

	if _dozing:
		return &"doze"

	return _pose


## Returns local head yaw/pitch in radians (positive pitch up), including doze pose.
func head() -> Vector2:
	if _dozing:
		return Vector2(0.0, -0.5)

	return Vector2(_look_yaw, _look_pitch)


## Whether what he is doing leaves his head free to look round at someone
## (not asleep, not at work, not a drink at his lips).
func head_free() -> bool:
	return _standing <= 0.0 and not _dozing and (habit == &"" or _pose in HEAD_FREE)


## Stepping into place: how fast his feet carry him (world, flat), for the
## rig; zero when he is not.
func stepping() -> Vector3:
	return _stepping


## Standing at his post or his waypoint, nothing on: after a while he finds
## something to do. `on_rounds`: at a waypoint of his rounds (only what is
## at hand, and quickly).
func at_rest(delta: float, on_rounds := false) -> void:
	if habit != &"":
		return

	if not _rolled:
		roll()

	_rested += delta

	if _rested < IDLE_AFTER or guard.lookout or not _at_ease():
		return

	var life: RefCounted = guard.get("_life")

	# Talking, or passing the time where he stands (GuardPastimes): that first.
	if life != null and (life.talking() or life.pastime() != &""):
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


## Stops the current habit, releases spot reservations and drops carried work props.
## May begin a quick stand-up exit and restore equipment/temporary collision state.
func interrupt() -> void:
	if habit == &"":
		return

	if _pose in [&"sit_down", &"sit", &"doze", &"stand_up"] or _dozing:
		_standing = STAND_QUICK

	# Sat in to the table: he shoves himself and his chair back as he gets
	# up, out from under its edge.
	if not _tucked.is_empty():
		_shove = _tucked.duplicate()
		_shove["from"] = guard.global_position
		_shove["chair_from"] = (_tucked["chair"] as Node3D).global_position if is_instance_valid(_tucked["chair"]) else Vector3.ZERO
		_shove["t"] = 0.0

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


# Choosing

func _choose(on_rounds: bool) -> void:
	var hands: RefCounted = guard.get("_hands")
	var lit: bool = hands != null and hands.lantern != null
	var wary: bool = guard.has_method("wary") and guard.wary()
	var home: Vector3 = guard.global_position if on_rounds else guard._home.origin
	var reach := 4.5 if on_rounds else float(guard.get("habit_range"))
	var options := {}

	for each in HABITS:
		var pull: float = float(leanings.get(each, 0.0))

		# Wary: nothing that takes him off his guard. A man given to none of
		# what is left still looks about him.
		if wary and not (each in WARY_HABITS):
			continue

		if wary and each == &"fidget":
			pull = maxf(pull, 0.5)

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

		if _start(each, home, reach, lit, wary):
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
func _start(each: StringName, home: Vector3, reach: float, lit: bool, wary := false) -> bool:
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
			# A few steps out and back, facing his ground (GuardPastimes: he
			# never turns his back on it).
			var life: RefCounted = guard.get("_life")
			return life != null and life.pace()
		&"fidget":
			return _start_fidget(lit, wary)

	return false


func _start_fidget(lit: bool, wary := false) -> bool:
	var options := {}

	for each in fidgets.keys():
		# A light in his hand: his head only. Wary: his eyes on his ground.
		if lit and not (each in [&"look_about", &"look_up", &"mutter"]):
			continue

		if wary and not (each in WARY_FIDGETS):
			continue

		options[each] = fidgets[each]

	# Wary, whatever his leanings: a look about him.
	if wary and options.is_empty():
		options[&"look_about"] = 1.0

	# A merry man dances, when nobody is by (and nothing is afoot).
	if quirk == &"merry" and not lit and not wary and _alone(10.0):
		options[&"dance"] = 2.0

	if options.is_empty():
		return false

	var each: StringName = _pick(options)

	match each:
		&"fold_arms":
			_begin(&"fidget", [{"do": &"pose", "pose": &"fold_arms", "time": randf_range(4.0, 8.0), "rest": true}])
		&"drink":
			_begin(&"fidget", [{"do": &"pose", "pose": &"drink", "time": 1.33, "at": [FLASK_AT, _take_flask], "exit": _let_go}])
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
			var head_only := lit or wary
			_begin(&"fidget", [{"do": &"pose", "pose": &"" if head_only else &"fold_arms", "time": 3.0, "look": &"about" if head_only else &"", "rest": true}])

	return true


## What doing `each` at `spot` comes to, step by step.
func _plan(each: StringName) -> Array:
	var at: Vector3 = spot.global_position
	var facing: Vector3 = spot.facing()

	match each:
		&"sit":
			var chair: Node3D = spot.get_meta(&"tuck") if spot.has_meta(&"tuck") else null

			if chair != null and is_instance_valid(chair) and chair.has_meta(&"home"):
				return _plan_at_table(at, facing, chair)

			var steps: Array = [
				{"do": &"go", "to": at},
				{"do": &"settle", "to": at, "face": facing, "bodies": spot.get_meta(&"bodies", [])},
				{"do": &"pose", "pose": &"sit_down", "time": 1.6, "face": facing, "enter": _sit_down, "at": [SEATED_AT, _seated]},
				{"do": &"pose", "pose": &"sit", "time": randf_range(SIT_TIME.x, SIT_TIME.y), "rest": true, "doze": true, "face": facing},
				{"do": &"pose", "pose": &"stand_up", "time": 1.25, "face": facing, "enter": _rustle},
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
				{"do": &"pose", "pose": &"eat", "time": 2.66, "face": facing, "every": [EAT_CYCLE, BITE_AT, _bite], "exit": _let_go},
			]
		&"chop":
			var swings := randi_range(CHOPS.x, CHOPS.y)
			# Where he stands for the axe to bite the log: a bigger man
			# stands further back, a smaller one nearer.
			var size: float = guard._rig.get("size") if guard.get("_rig") != null and guard._rig.get("size") != null else 1.0
			at += Basis.looking_at(facing, Vector3.UP) * (Vector3(CHOP_AT.x, 0.0, CHOP_AT.z) * (1.0 - size))
			return [
				{"do": &"go", "to": at},
				{"do": &"settle", "to": at, "face": facing},
				{"do": &"pose", "pose": &"", "time": 0.3, "face": facing, "exit": _take_axe},
				{"do": &"pose", "pose": &"chop", "time": float(swings) * CHOP_CYCLE, "face": facing, "every": [CHOP_CYCLE, CHOP_HIT, _chop]},
				{"do": &"pose", "pose": &"", "time": 0.4, "face": facing, "enter": _let_go},
			]
		&"tend":
			var tending := {"do": &"pose", "pose": &"tend", "time": randf_range(TEND_TIME.x, TEND_TIME.y), "face": facing}

			# At a fire: now and then a log pushed in, and it flares.
			if spot.has_meta(&"fire"):
				tending["every"] = [STOKE_EVERY, STOKE_FIRST, _stoke]

			return [
				{"do": &"go", "to": at},
				{"do": &"settle", "to": at, "face": facing},
				{"do": &"pose", "pose": &"kneel_down", "time": 1.35, "face": facing, "enter": _sheathe},
				tending,
				{"do": &"pose", "pose": &"kneel_up", "time": 1.1, "face": facing},
			]

	return []


## Sitting at a table: the chair drawn out, down onto it, in to the table
## with it; out again with it to get up, and it pushed back in as he goes.
## Sitting down and getting up he leans well forward, and the table's edge
## would go through him.
func _plan_at_table(at: Vector3, facing: Vector3, chair: Node3D) -> Array:
	var back := -facing
	var home: Vector3 = (chair.get_meta(&"home") as Transform3D).origin
	var out_at := at + back * PULL_OUT
	var chair_out := home + back * PULL_OUT
	var tuck := {"chair": chair, "out": out_at, "chair_out": chair_out}
	_doze_in = randf_range(DOZE_AFTER.x, DOZE_AFTER.y)
	return [
		{"do": &"go", "to": out_at},
		{"do": &"settle", "to": out_at, "face": facing, "bodies": spot.get_meta(&"bodies", []), "move": [chair, chair_out]},
		{"do": &"pose", "pose": &"sit_down", "time": 1.6, "face": facing, "enter": _sit_down, "at": [SEATED_AT, _seated]},
		{"do": &"settle", "to": at, "face": facing, "pose": &"sit", "move": [chair, home], "time": SCOOT_TIME, "tuck": tuck},
		{"do": &"pose", "pose": &"sit", "time": randf_range(SIT_TIME.x, SIT_TIME.y), "rest": true, "doze": true, "face": facing},
		{"do": &"settle", "to": out_at, "face": facing, "pose": &"sit", "move": [chair, chair_out], "time": SCOOT_TIME, "untuck": true},
		{"do": &"pose", "pose": &"stand_up", "time": 1.25, "face": facing, "enter": _rustle},
		{"do": &"settle", "back": true, "face": facing, "move": [chair, home]},
	]


## Up in a hurry from the table (interrupt): he and his chair shoved back,
## out from under its edge, before he is up.
func _shove_back(delta: float) -> void:
	if _shove.is_empty():
		return

	_shove["t"] = float(_shove["t"]) + delta
	var u := smoothstep(0.0, 1.0, clampf(float(_shove["t"]) / SETTLE_TIME, 0.0, 1.0))
	var to: Vector3 = (_shove["from"] as Vector3).lerp(_shove["out"], u)
	guard.global_position = Vector3(to.x, guard.global_position.y, to.z)
	var chair: Node3D = _shove["chair"]

	if is_instance_valid(chair):
		chair.global_position = (_shove["chair_from"] as Vector3).lerp(_shove["chair_out"], u)

	if u >= 1.0:
		_shove = {}


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


# Doing it

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
## table's edge), turning to face as he does; on his feet he walks it (his
## legs shown going, stepping()), sat he shuffles his chair with him. "back":
## the step out again, to where he stepped in from.
func _settle(step: Dictionary, delta: float) -> void:
	var back: bool = step.get("back", false)
	var moved: Array = step.get("move", [])
	var to: Vector3 = _came_from if back else step["to"]

	if _t <= delta:
		_settle_from = guard.global_position

		# (Stepping in among the furniture: where he steps out to again.)
		if step.has("bodies"):
			_came_from = guard.global_position

		for body in step.get("bodies", []):
			if body is PhysicsBody3D and is_instance_valid(body):
				guard.add_collision_exception_with(body)
				_excepted.append(body)
				_among = true

		# A chair drawn out or pushed in scrapes the floor.
		if not moved.is_empty() and is_instance_valid(moved[0]):
			_moved_from = (moved[0] as Node3D).global_position
			Sfx.play(guard, &"scuff", _moved_from, -4.0, randf_range(0.7, 0.8))

		if step.has("tuck"):
			_tucked = step["tuck"]

		var way := Vector2(to.x - _settle_from.x, to.z - _settle_from.z).length()
		_settle_time = float(step["time"]) if step.has("time") else maxf(SETTLE_TIME, way / SETTLE_PACE)
		# Walking in, he carries on at the pace he came at and slows into
		# place (never so fast that he would overshoot it); from standing, he
		# steps off and slows the same.
		_settle_v = Vector3(guard.velocity.x, 0.0, guard.velocity.z)

		if _settle_v.length() * _settle_time > way * 2.5:
			_settle_v = _settle_v.normalized() * way * 2.5 / _settle_time

	_pose = step.get("pose", &"")
	var u := clampf(_t / _settle_time, 0.0, 1.0)
	var at := _eased_way(_settle_from, _settle_v * _settle_time, to, u)
	var eased := smoothstep(0.0, 1.0, u)
	var was := guard.global_position
	guard.global_position = Vector3(at.x, was.y, at.z)
	guard.velocity = Vector3(0.0, guard.velocity.y, 0.0)
	guard._face(step["face"], delta, 2.5)

	# On his feet (not sat, shuffling his chair): his legs take him there.
	if _pose == &"" or _pose == &"carry":
		_stepping = Vector3(at.x - was.x, 0.0, at.z - was.z) / maxf(delta, 0.0001)

	# What he moves as he goes (a chair drawn out or in).
	if not moved.is_empty() and is_instance_valid(moved[0]):
		(moved[0] as Node3D).global_position = _moved_from.lerp(moved[1], eased)

	if u >= 1.0:
		if back:
			_among = false

		if step.get("untuck", false):
			_tucked = {}

		_next()


## `u` (0..1) of the way from `from` to `to`, setting off along `off` (the
## pace he came at times the time it takes) and slowing to a stop there.
static func _eased_way(from: Vector3, off: Vector3, to: Vector3, u: float) -> Vector3:
	var u2 := u * u
	var u3 := u2 * u
	return from * (2.0 * u3 - 3.0 * u2 + 1.0) + off * (u3 - 2.0 * u2 + u) + to * (3.0 * u2 - 2.0 * u3)


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
	_tucked = {}
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


func _at_ease(still := false) -> bool:
	var life: RefCounted = guard.get("_life")
	return int(guard.state) == RELAXED and (life == null or life.at_ease(guard, still))


func _dozy() -> bool:
	var fighter: RefCounted = guard.get("_fighter")
	var tag: StringName = fighter.temper.tag if fighter != null and fighter.temper != null else &"steady"
	return tag in [&"steady", &"sly"] and TemperamentScript.rolling and randf() < 0.25


func _alone(reach: float) -> bool:
	for other in guard.get_tree().get_nodes_in_group(&"guards"):
		if other != guard and (other as Node3D).global_position.distance_to(guard.global_position) < reach:
			return false

	return true


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


# Things in his hands

## His hands wanted for his ways at ease (a seat, the axe, bread, a crate,
## kneeling at his work): his blade put by for them if it was out, and free
## for it again after (GuardRig shows it, and is heard).
func _sheathe() -> void:
	_sheathed = true


func _unsheathe() -> void:
	_sheathed = false


## Down onto the seat: his blade put by, his clothes rustling as he goes.
func _sit_down() -> void:
	_sheathe()
	_rustle()


## His weight on the seat: it creaks under him.
func _seated() -> void:
	Sfx.play(guard, &"creak_rope", guard.global_position + Vector3.UP * 0.45, -2.0, randf_range(0.55, 0.7))


## His clothes and his mail as he sits down or gets up.
func _rustle() -> void:
	Sfx.play(guard, &"cloth", guard.global_position + Vector3.UP * 0.8, 2.0)


func _take_bread() -> void:
	_bread_held = _bread()
	_hold_thing(&"hand_l", _bread_held, BREAD_GRIP)


## A mouthful off the bread in his hand: less of it left.
func _bite() -> void:
	if _bread_held != null and is_instance_valid(_bread_held):
		_bread_held.scale *= BITE_LEFT


func _take_flask() -> void:
	_hold_thing(&"hand_l", _flask(), FLASK_GRIP)


## A log pushed into the fire: sparks up off it, and the flame flares a
## moment and crackles.
func _stoke() -> void:
	var flame: Node3D = spot.get_meta(&"fire") if spot != null and is_instance_valid(spot) and spot.has_meta(&"fire") else null

	if flame == null or not is_instance_valid(flame):
		return

	var at := flame.global_position + Vector3.UP * 0.05
	Fx.sparks(guard, at, Vector3.UP, 0.3, false)
	Sfx.play(guard, &"burning", at, -4.0, randf_range(0.9, 1.15))

	if flame.has_method("flare"):
		flame.flare(1.0)


func _take_axe() -> void:
	_sheathe()
	_hold_thing(&"hand_r", _axe(), AXE_GRIP)


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
	_bread_held = null


## A blow of the axe on the log: heard well off, chips flying.
func _chop() -> void:
	var size: float = guard._rig.get("size") if guard.get("_rig") != null and guard._rig.get("size") != null else 1.0
	var at: Vector3 = guard.global_position + guard.global_basis * (CHOP_AT * size)
	Sfx.play(guard, &"thud_wood", at, 2.0, randf_range(0.9, 1.1))
	Fx.chips(guard, at, Vector3.UP, 0.8, "wood")
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


## A leather flask: its body in his fist, the neck and its stopper out of the
## top.
static func _flask() -> Node3D:
	var flask := Node3D.new()
	var leather := StandardMaterial3D.new()
	leather.albedo_color = Color(0.3, 0.19, 0.11)
	leather.roughness = 0.8

	for part in [[0.042, 0.13, 0.0], [0.015, 0.04, 0.085], [0.018, 0.022, 0.112]]:
		var tube := CylinderMesh.new()
		tube.top_radius = part[0]
		tube.bottom_radius = part[0]
		tube.height = part[1]
		tube.radial_segments = 12
		var drawn := MeshInstance3D.new()
		drawn.mesh = tube
		drawn.material_override = leather
		flask.add_child(drawn)
		drawn.position = Vector3(0.0, part[2], 0.0)

	# The stopper, a darker wood.
	var cork := StandardMaterial3D.new()
	cork.albedo_color = Color(0.45, 0.33, 0.2)
	(flask.get_child(2) as MeshInstance3D).material_override = cork
	return flask


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


## The stock ("stock" group) lying by `pile`: not what you hold up there.
static func _stock_at(pile: Node3D) -> Array:
	var ahead: Vector3 = pile.global_position + pile.facing() * 0.75
	var found := []

	for crate in pile.get_tree().get_nodes_in_group(&"stock"):
		if is_instance_valid(crate) and not crate.is_in_group(&"in_hand") and (crate as Node3D).global_position.distance_to(ahead) < 1.4:
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
	# The weight of it.
	guard.voice(&"grunt", -12.0)


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


# A light on his rounds

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
