extends RefCounted
## A guard's life when there is no fight: his rounds as more than a walk.
##   talk      men at their ease and near each other talk: written
##             conversations chosen to fit the moment (TalkDirector, the
##             files in data/talk). The one listening nods along, or shakes
##             his head (by his temperament). You can listen. Anything that
##             stirs one of them ends it. Talking, each looks at the other.
##   glances   at his ease, he looks round at a man going by, a moment.
##   greeting  going by a man at his ease, a word to him now and then
##             ("Evening, Hendrik."); he looks round and nods, and may say
##             something back. Not the same two again for a good while.
##   idle      what he does with himself standing about, sat, leaning: his
##             own ways (GuardHabits.gd), and between them he passes the time
##             where he stands: warms his hands, stamps his feet, paces...
##             (GuardPastimes).
##   oddities  a door you left open, your arrow in a wall, a torch you put
##             out: he notices it (it takes light, and a look; a torch dark
##             where it should burn takes only the look), goes to it and deals
##             with it (shuts the door, pulls the arrow out, lights the torch
##             again), then searches about it; the garrison is roused a little,
##             and more by a second torch out not long after the first (it is
##             no draught: Garrison.light_found_out).
##   missing   a man who knew another looks at his post and he is not there
##             (Garrison.fallen): "Where's Hendrik got to?", and he goes to see.
##   noises    a man who hears something with a friend at hand says so, and
##             goes to look; the friend covers him from where he stands, and
##             stands easy when he calls that it was nothing.
##   lantern   searching somewhere dark with the garrison roused, he lights one
##             (GuardHands); at his ease a while, he puts it out (not the light
##             he walks his rounds with).
##   lookout   a man set to watch (Guard.lookout) sweeps his ground slowly.

const GarrisonScript := preload("res://scripts/AISystem/Garrison.gd")
const GuardPastimesScript := preload("res://scripts/AISystem/GuardPastimes.gd")
const Comms := preload("res://scripts/AISystem/Comms.gd")
const LightProbe := preload("res://scripts/StimuliSystem/LightProbe.gd")

## Guard.Alert.
const RELAXED := 0
const SUSPICIOUS := 1
const INVESTIGATING := 2
const SEARCHING := 3
const COMBAT := 4
## How often he looks about him for things out of place (staggered).
const CHECK := 0.35
## Who talks to whom (made at run time: it reads this script too); the
## night's rota, where a level has one.
const TALK_DIRECTOR := "res://scripts/AISystem/Talk/TalkDirector.gd"
const NIGHT_ROTA := "res://scripts/AISystem/NightRota.gd"
const GATHERING := "res://scripts/AISystem/Gathering.gd"
## Listening, how he takes a line: a nod or a shake of the head, for this
## long (s).
const REACT := 1.6
## Seeing something out of place: this long in view (weighted by how near the
## middle of his view it is) before it registers; how far off it can be; and
## the light it needs beyond arm's length.
const NOTICE := 0.9
const DOOR_RANGE := 11.0
const ARROW_RANGE := 7.0
const TORCH_RANGE := 14.0
const ODD_LIGHT := 0.08
## How much each rouses the garrison: a door, an arrow, a torch out, and a
## torch out with others not long before it.
const DOOR_ALARM := 0.2
const ARROW_ALARM := 0.35
const TORCH_ALARM := 0.15
const TORCHES_ALARM := 0.45
## A torch he could not get near enough to light again is left alone this
## long (s).
const OUT_OF_REACH := 120.0
## He deals with it only once he is this near it (m); stirred by a noise, he
## notices only what is this near where he heard it.
const ODD_REACH := 2.8
const ODD_NEAR := 5.0
## A missing man: his post in view this long, within this far.
const MISS_NOTICE := 2.5
const MISS_RANGE := 16.0
## Noises: a friend within this far, in sight, is told; he covers this long at
## most.
const FRIEND_RANGE := 12.0
const COVER_MAX := 20.0
## Lantern: darker than this where he is, with the garrison roused past this;
## put out after this long at his ease.
const LANTERN_DARK := 0.1
const LANTERN_ALARM := 0.25
const DOUSE_AFTER := 8.0
## A lookout sweeps this far either side of where his post faces, once in
## this many seconds.
const LOOKOUT_ARC := 70.0
const LOOKOUT_PERIOD := 12.0
## Glances: a man going by within this far (m) and on the move, looked round
## at this long (s); none again for this long after (s). His head turns no
## further than this (rad) to anyone.
const GLANCE_RANGE := 7.0
const GLANCE_MOVING := 0.6
const GLANCE_TIME := Vector2(1.5, 3.0)
const GLANCE_REST := Vector2(4.0, 10.0)
const REGARD_MAX := 1.2
## Greetings: going by within this far (m) of a man at his ease, ahead of
## him, a word this often (by his temperament: a craven man glad of the
## company, a sly or a stubborn one keeping himself to himself); the other
## says something back this often, this long after (s). Not the same two again
## for this long (s), nor either greeting anyone else for this long.
const GREET_RANGE := 4.0
const GREET_CHANCE := {&"steady": 0.7, &"craven": 0.85, &"rash": 0.6, &"sly": 0.45, &"stubborn": 0.45}
const GREET_BACK := 0.5
const GREET_BACK_AFTER := Vector2(0.8, 1.3)
const GREET_AGAIN := 150.0
const GREET_REST := Vector2(15.0, 30.0)
## A nod: his head dipped this far (rad), down and up again in this long (s).
const NOD_DIP := 0.32
const NOD_TIME := 0.7

static var _talk_script: GDScript = null
static var _rota_script: GDScript = null
static var _gathering_script: GDScript = null

var guard: CharacterBody3D
## After a conversation, this long before he talks again (TalkDirector).
var _talk_rest := 0.0
## Standing still this long, and what he does with himself between his own
## ways (GuardPastimes).
var _resting := 0.0
var _pastimes: RefCounted
## Listening: how he took the last line ("nod", "shake", "") and when.
var _react: StringName = &""
var _react_at := -10.0
## Something out of place he is going to deal with.
var _odd: Node3D = null
var _odd_kind: StringName = &""
var _noticing := {}
var _missing := {}
var _check := 0.0
## Covering a friend who went to look (a weakref), and for how much longer;
## and, going to look himself, whether anyone covers him.
var _covering: WeakRef = null
## The friend he covers, by name (he may be gone before he is missed).
var _covering_name := ""
var _cover_left := 0.0
var _covered := false
## Seconds at his ease (for putting the lantern out).
var _easy := 0.0
var _lantern_check := 0.0
var _watch_time := 0.0
## Someone he looks round at (a man going by, one who greets him), for how
## much longer, and how long before he looks round at anyone again.
var _regard: Node3D = null
var _regard_left := 0.0
var _glance_rest := 0.0
## Greetings: whom he last passed a word with and when (instance id -> s),
## how long before he greets anyone again, a word back yet to be said (in
## this long; below zero, none), and when he last nodded (Comms.now).
var _greeted := {}
## How likely he is to say anything going by (GREET_CHANCE by his
## temperament, once it is known; below zero until then).
var greet_chance := -1.0
var _greet_rest := 0.0
var _reply_in := -1.0
var _nod_at := -10.0


func _init(p_guard: CharacterBody3D) -> void:
	guard = p_guard
	_check = randf() * CHECK
	_talk_rest = randf_range(6.0, 16.0)
	_pastimes = GuardPastimesScript.new(p_guard)
	_watch_time = randf() * LOOKOUT_PERIOD


## Every physics frame, while he is up and about.
func update(delta: float) -> void:
	_talk_rest = maxf(_talk_rest - delta, 0.0)
	_glance_rest = maxf(_glance_rest - delta, 0.0)
	_greet_rest = maxf(_greet_rest - delta, 0.0)
	_pastimes.update(delta)

	# Stirred from his ease: his pacing is over too (else, at his ease again,
	# he would walk out to where he paced before).
	if int(guard.state) != RELAXED and _pastimes.activity() == &"pace":
		_pastimes.stop()

	var talk := _director()

	if talk != null:
		talk.tick(delta)

	if _rota_script == null:
		_rota_script = load(NIGHT_ROTA)

	var night: RefCounted = _rota_script.of(guard)

	if night != null:
		night.tick(delta)

	if _gathering_script == null:
		_gathering_script = load(GATHERING)

	var together: RefCounted = _gathering_script.of(guard)

	if together != null:
		together.tick(delta)

	_update_regard(delta)
	_update_greeting(delta)
	_update_cover(delta)
	_update_lantern(delta)
	_check -= delta

	if _check > 0.0:
		return

	_check = CHECK
	var state := int(guard.state)

	# Things out of place, men missing: noticed at his ease (suspicious, only
	# what might be what stirred him: something by where he heard it), and
	# not while he covers a friend's look, nor with his eyes shut.
	var eyes_shut: bool = (guard._rota != null and guard._rota.asleep()) \
		or (guard._habits != null and guard._habits.dozing())

	if (state == RELAXED or state == SUSPICIOUS) and not covering() and not eyes_shut and not (guard.has_method("blinded") and guard.blinded()):
		_look_for_oddities(CHECK)

		if state == RELAXED:
			_look_for_missing(CHECK)

	if state == RELAXED:
		_greet_passing()
		_look_round()


## What he is doing with himself, for the rig: "talk", "listen", a pastime
## (GuardPastimes: "fold_arms", "warm_hands", "pace"...), or "".
func activity() -> StringName:
	if talking():
		return &"talk" if _director().speaking(guard) else &"listen"

	# A log in his arms for the fire (Gathering).
	if guard.has_meta(&"carry_log"):
		return &"carry_log"

	# Pastimes are for a man at his ease: anything else and they are over.
	if int(guard.state) != RELAXED:
		_pastimes.walking()
		return &""

	return _pastimes.activity()


# ---------------------------------------------------------------------------
# Standing about
# ---------------------------------------------------------------------------

## Standing (or sat, or leaning) still at his post or a waypoint (or settled
## at a station). About something of his own (GuardHabits), that is what he
## does; else he passes the time (GuardPastimes).
func at_rest(delta: float) -> void:
	_resting += delta
	var habits: RefCounted = guard.get("_habits")

	if habits != null and habits.busy():
		_pastimes.stop()
		return

	_pastimes.at_rest(delta)


## On the move: whatever he was doing standing still is over.
func walking() -> void:
	_resting = 0.0
	_pastimes.walking()


## What he is passing the time with (GuardPastimes), or "".
func pastime() -> StringName:
	return _pastimes.activity()


## A few steps out and back where he stands (GuardHabits' "pace"): false if
## there is no room.
func pace() -> bool:
	return _pastimes.start(&"pace")


## Pacing (a pastime): where he walks to now; else null.
func pastime_step() -> Variant:
	return _pastimes.wants_step() if int(guard.state) == RELAXED else null


## A lookout at his post: the way he faces now, sweeping his ground.
func watch_yaw(home_yaw: float, delta: float) -> float:
	_watch_time += delta
	return home_yaw + sin(_watch_time * TAU / LOOKOUT_PERIOD) * deg_to_rad(LOOKOUT_ARC)


# ---------------------------------------------------------------------------
# Talk
# ---------------------------------------------------------------------------

func talking() -> bool:
	var talk := _director()
	return talk != null and talk.in_talk(guard)


## Which way the man he listens to is (to face him).
func partner_direction() -> Vector3:
	var talk := _director()
	var other: Variant = talk.speaker_near(guard) if talk != null else null

	if other == null or not is_instance_valid(other):
		return Vector3.ZERO

	return (other as Node3D).global_position - guard.global_position


## Wary (Guard.wary): a hunt not long since, the garrison roused.
static func _wary(man: Node) -> bool:
	return man.has_method("wary") and bool(man.wary())


## Walking somewhere, not standing about.
static func _on_the_move(man: Node) -> bool:
	var body := man as CharacterBody3D
	return body != null and Vector2(body.velocity.x, body.velocity.z).length() > 1.0


## At his ease: nothing on his mind, nothing wrong with him. `still`: to go
## on with what he is at (a word, a seat) a man may have a little more on his
## mind than to start it; short of suspicious, it can wait.
static func at_ease(man: Node, still := false) -> bool:
	if man == null or not is_instance_valid(man) or man.get("_knocked_out") == true:
		return false

	if int(man.state) != RELAXED or float(man.alert) >= float(man.suspicious_at) * (1.0 if still else 0.5):
		return false

	if man.is_downed() or float(man._burning) > 0.0 or float(man._stagger) > 0.0:
		return false

	var fighter: RefCounted = man.get("_fighter")
	return fighter == null or not bool(fighter.stays_put)


## Listening to a line: a nod from an easy man, now and then a shake of the
## head from a hard one (TalkDirector shows it: Guard.emote).
func _take_line() -> void:
	var fighter: RefCounted = guard.get("_fighter")
	var tag: StringName = fighter.temper.tag if fighter != null and fighter.temper != null else &"steady"
	var roll := randf()
	_react_at = Comms.now()

	if tag in [&"rash", &"stubborn"]:
		_react = &"shake" if roll < 0.4 else (&"nod" if roll < 0.6 else &"")
	else:
		_react = &"nod" if roll < 0.6 else (&"shake" if roll < 0.7 else &"")


## He leaves the conversation he is in (broken off).
func end_talk() -> void:
	var talk := _director()

	if talk != null:
		talk.leave(guard)


func _director() -> RefCounted:
	if _talk_script == null:
		_talk_script = load(TALK_DIRECTOR)

	return _talk_script.of(guard) if guard.is_inside_tree() else null


# ---------------------------------------------------------------------------
# Glances and greetings
# ---------------------------------------------------------------------------

## Which way the man he looks at is (Guard._update_head turns his head to
## him): the man he talks with, one going by, one who greets him. Zero when
## nobody.
func regard_direction() -> Vector3:
	if talking():
		var toward := partner_direction()
		toward.y = 0.0
		return toward

	var who: Node3D = _regard

	if who == null or not is_instance_valid(who):
		return Vector3.ZERO

	var to := who.global_position - guard.global_position
	to.y = 0.0
	return to


## Looks round at `who` for `seconds`.
func regard(who: Node3D, seconds: float) -> void:
	_regard = who
	_regard_left = seconds


## His head dipped in a nod just now (rad, down negative), for the rig: none
## (0) but just after a greeting.
func nod() -> float:
	var t := Comms.now() - _nod_at

	if t < 0.0 or t > NOD_TIME:
		return 0.0

	return -NOD_DIP * sin(PI * t / NOD_TIME)


## Greeted by `man` going by: he looks round at him and nods, and now and
## then says something back.
func greeted_by(man: Node3D) -> void:
	regard(man, randf_range(2.0, 3.0))
	_nod_at = Comms.now() + 0.3
	_greet_rest = maxf(_greet_rest, randf_range(GREET_REST.x, GREET_REST.y))
	_greeted[man.get_instance_id()] = Comms.now()
	_reply_in = randf_range(GREET_BACK_AFTER.x, GREET_BACK_AFTER.y) if randf() < GREET_BACK else -1.0


func _update_regard(delta: float) -> void:
	if _regard == null:
		return

	_regard_left -= delta
	var gone: bool = not is_instance_valid(_regard) or not _regard.is_inside_tree()

	if gone or _regard_left <= 0.0 or int(guard.state) != RELAXED or guard.global_position.distance_to(_regard.global_position) > GLANCE_RANGE + 2.0:
		_regard = null
		_glance_rest = randf_range(GLANCE_REST.x, GLANCE_REST.y)


func _update_greeting(delta: float) -> void:
	if _reply_in < 0.0:
		return

	_reply_in -= delta

	if _reply_in > 0.0:
		return

	_reply_in = -1.0

	if at_ease(guard) and not talking():
		guard.say(&"greet_back_wary" if _wary(guard) else &"greet_back")


## Whether `man`'s head is his own to turn (his habits leave it free).
static func _head_free(man: Node) -> bool:
	var habits: RefCounted = man.get("_habits")
	return habits == null or not habits.has_method("head_free") or habits.head_free()


## At his ease, he looks round at a man going by (not a lookout: he watches
## his ground).
func _look_round() -> void:
	if _regard != null or _glance_rest > 0.0 or talking() or bool(guard.get("lookout")) or not at_ease(guard) or not _head_free(guard):
		return

	var eye: Vector3 = guard.eye_position()
	var ahead := -guard.global_basis.z
	var best: Node3D = null
	var nearest := GLANCE_RANGE

	for other in guard.get_tree().get_nodes_in_group(&"guards"):
		if other == guard or not (other is CharacterBody3D) or other.get("_knocked_out") == true:
			continue

		var body := other as CharacterBody3D

		if Vector2(body.velocity.x, body.velocity.z).length() < GLANCE_MOVING:
			continue

		var to := body.global_position - guard.global_position
		var distance := to.length()

		if distance >= nearest:
			continue

		# Before him or beside him (seen), or close behind (heard).
		if Vector2(to.x, to.z).normalized().dot(Vector2(ahead.x, ahead.z)) < -0.3 and distance > 2.5:
			continue

		if not guard._line_of_sight(eye, body.eye_position(), body):
			continue

		best = body
		nearest = distance

	if best != null:
		regard(best, randf_range(GLANCE_TIME.x, GLANCE_TIME.y))


## On the move at his ease, coming up to a man at his: a word to him, now and
## then. Not to a man he is going over to anyway (GuardHabits "visit"), nor
## one talking, asleep or at work.
func _greet_passing() -> void:
	if _greet_rest > 0.0 or talking() or bool(guard.get("lookout")) or not at_ease(guard) or float(guard.get("_bark_timer")) > 0.0:
		return

	if Vector2(guard.velocity.x, guard.velocity.z).length() < GLANCE_MOVING:
		return

	var habits: RefCounted = guard.get("_habits")

	if habits != null and habits.get("habit") == &"visit":
		return

	var eye: Vector3 = guard.eye_position()
	var ahead := -guard.global_basis.z
	var now := Comms.now()

	for other in guard.get_tree().get_nodes_in_group(&"guards"):
		if other == guard or other.get("_life") == null or bool(other.get("lookout")):
			continue

		var theirs: RefCounted = other._life

		if theirs.talking() or float(theirs._greet_rest) > 0.0 or not at_ease(other) or not _head_free(other):
			continue

		var to: Vector3 = other.global_position - guard.global_position

		if to.length() > GREET_RANGE or Vector2(to.x, to.z).normalized().dot(Vector2(ahead.x, ahead.z)) < 0.2:
			continue

		if now - float(_greeted.get(other.get_instance_id(), -INF)) < GREET_AGAIN:
			continue

		if not guard._line_of_sight(eye, other.eye_position(), other):
			continue

		_greeted[other.get_instance_id()] = now
		_greet_rest = randf_range(GREET_REST.x, GREET_REST.y)
		regard(other, randf_range(1.5, 2.5))

		# Now and then only a look between them as he goes by.
		if greet_chance < 0.0:
			greet_chance = float(GREET_CHANCE.get(_tag(), GREET_CHANCE[&"steady"]))

		if randf() >= greet_chance:
			theirs._greeted[guard.get_instance_id()] = now
			theirs.regard(guard, randf_range(1.2, 2.0))
			return

		# Wary (a hunt not long since, the garrison roused): no evenings, only
		# whether he has seen anything.
		var said: String = guard._fighter.temper.line(&"greet_wary" if _wary(guard) else &"greet") if guard._fighter != null and guard._fighter.temper != null else "Evening."

		if said.contains("%s"):
			said = said % String(other.get("given_name"))

		guard.bark(said)
		_nod_at = now
		theirs.greeted_by(guard)
		return


# ---------------------------------------------------------------------------
# Things out of place
# ---------------------------------------------------------------------------

func _look_for_oddities(step: float) -> void:
	var tree := guard.get_tree()
	var eye: Vector3 = guard.eye_position()
	# Stirred: only what is near what stirred him.
	var near: Vector3 = guard.last_known_position if int(guard.state) == SUSPICIOUS else Vector3.INF

	for door in tree.get_nodes_in_group(&"doors"):
		if door.has_method("left_open") and door.left_open() and not _noticed(door):
			var way: Vector3 = door.doorway() if door.has_method("doorway") else door.global_position

			if near != Vector3.INF and way.distance_to(near) > ODD_NEAR:
				continue

			# The panel standing open, or the gap where it should be: a door
			# swung back behind its wall still leaves its doorway gaping.
			if _watch_for(door, [door.panel_centre(), way + Vector3.UP], DOOR_RANGE, eye, step):
				_notice(door, &"door", way)
				return
		else:
			_noticing.erase(door)

	# A torch dark where it should be burning: its not burning is what he
	# sees, so it takes no light to see it.
	for torch in tree.get_nodes_in_group(&"lights"):
		if torch.has_method("left_out") and torch.left_out() and not _noticed(torch) and Comms.now() >= float(torch.get_meta(&"out_of_reach_until", -1.0)):
			# Its flame, where it should be burning (a fixture's origin is on the
			# wall behind it, or on the floor under its basket).
			var at: Vector3 = torch.flame_position() if torch.has_method("flame_position") else (torch as Node3D).global_position

			if near != Vector3.INF and at.distance_to(near) > ODD_NEAR:
				continue

			if _watch_for(torch, [at], TORCH_RANGE, eye, step, false):
				_notice(torch, &"torch", at)
				return
		else:
			_noticing.erase(torch)

	for arrow in tree.get_nodes_in_group(&"stray_arrows"):
		if arrow.is_queued_for_deletion() or _noticed(arrow):
			continue

		if near != Vector3.INF and (arrow as Node3D).global_position.distance_to(near) > ODD_NEAR:
			continue

		if _watch_for(arrow, [(arrow as Node3D).global_position], ARROW_RANGE, eye, step):
			_notice(arrow, &"arrow", (arrow as Node3D).global_position)
			return


## Whether `thing`, seen at any of `points`, looked at a while, has
## registered (in reach, in view, lit enough or near: `lit_to_see`). Counts
## the time it has been seen, by the best view of it.
func _watch_for(thing: Node3D, points: Array, reach: float, eye: Vector3, step: float, lit_to_see := true) -> bool:
	var best := 0.0

	for at: Vector3 in points:
		var to := at - eye

		if to.length() > reach:
			continue

		var cone: float = guard._cone_factor(to)

		if cone < 0.5 or cone <= best or not guard._line_of_sight(eye, at, thing):
			continue

		if to.length() > 3.0 and lit_to_see:
			var exclude: Array[RID] = []

			if thing is CollisionObject3D:
				exclude.append((thing as CollisionObject3D).get_rid())

			if LightProbe.light_at(guard, at, exclude) < ODD_LIGHT:
				continue

		best = cone

	if best <= 0.0:
		_noticing.erase(thing)
		return false

	var seen: float = float(_noticing.get(thing, 0.0)) + step * best
	_noticing[thing] = seen
	return seen >= NOTICE


## Noticed already by a man still able to see to it: not one since killed,
## knocked out or gone (it waits for whoever notices it next).
static func _noticed(thing: Node) -> bool:
	if not thing.has_meta(&"noticed"):
		return false

	var by: Variant = thing.get_meta(&"noticed")

	if not by is WeakRef:
		return true

	var man: Object = (by as WeakRef).get_ref()
	return man != null and not (man as Node).is_queued_for_deletion() and man.get("_knocked_out") != true


func _notice(thing: Node3D, kind: StringName, where: Vector3) -> void:
	thing.set_meta(&"noticed", weakref(guard))
	_noticing.erase(thing)
	_odd = thing
	_odd_kind = kind
	var garrison: RefCounted = _garrison()

	match kind:
		&"door":
			guard.say(&"odd_door")
		&"arrow":
			guard.say(&"odd_arrow")

	if garrison != null:
		match kind:
			&"door":
				garrison.raise_alarm(DOOR_ALARM)
			&"arrow":
				garrison.raise_alarm(ARROW_ALARM)
			&"torch":
				# One out is a draught; another not long after is somebody.
				var out: int = garrison.light_found_out(thing)
				garrison.raise_alarm(TORCHES_ALARM if out >= GarrisonScript.LIGHTS_WORK else TORCH_ALARM)
				guard.say(&"odd_lights" if out >= GarrisonScript.LIGHTS_WORK else &"odd_light")

	# To the doorway, from his own side of it (clear of its swing); to the
	# arrow; to the floor under the torch.
	var go := where

	if kind == &"door":
		var side := guard.global_position - where
		side.y = 0.0

		if side.length() > 0.1:
			go = where + side.normalized() * 1.1
	elif kind == &"torch":
		go = NavigationServer3D.map_get_closest_point(guard.get_world_3d().navigation_map, where + Vector3.DOWN * 2.0)

	guard.notice(go, &"oddity")


## Arrived at what he noticed: he deals with it. True if there was anything
## (he then looks about him as usual). Only there: if he is somewhere else
## (sent off elsewhere on the way), it is left for whoever notices it next.
func deal_with_oddity() -> bool:
	var thing := _odd
	_odd = null

	if thing == null or not is_instance_valid(thing):
		return false

	var at: Vector3 = thing.doorway() if _odd_kind == &"door" and thing.has_method("doorway") else thing.global_position

	if Vector2(at.x - guard.global_position.x, at.z - guard.global_position.z).length() > ODD_REACH:
		thing.remove_meta(&"noticed")

		# A torch he could not get near enough to light: left a while.
		if _odd_kind == &"torch":
			thing.set_meta(&"out_of_reach_until", Comms.now() + OUT_OF_REACH)

		return false

	match _odd_kind:
		&"door":
			if thing.get("is_open") == true:
				thing.frob(guard)
		&"arrow":
			guard._hands.stoop_for(thing, &"evidence")
		&"torch":
			if thing.get("lit") == false:
				guard._hands.relight(thing)

	return true


## The oddity he is on his way to (for tests and the gym's labels).
func oddity() -> Node3D:
	return _odd if _odd != null and is_instance_valid(_odd) else null


## Into a fight: whatever he was going to see to is left for whoever notices
## it next; the look he had claimed is free; and nobody is covering him now,
## so there is no "clear" to call after.
func stirred_to_fight() -> void:
	if _odd != null and is_instance_valid(_odd):
		_odd.remove_meta(&"noticed")

	_odd = null
	_covered = false
	stop_covering()
	var garrison: RefCounted = _garrison()

	if garrison != null:
		garrison.looked(guard)


# ---------------------------------------------------------------------------
# A man missing from his post
# ---------------------------------------------------------------------------

func _look_for_missing(step: float) -> void:
	var garrison: RefCounted = _garrison()

	if garrison == null:
		return

	var eye: Vector3 = guard.eye_position()
	var born: float = float(guard.get("_born_at"))

	for i in range(garrison.fallen.size()):
		var post: Dictionary = garrison.fallen[i]

		# Only a man who knew him misses him.
		if bool(post["noticed"]) or float(post["at"]) < born:
			continue

		var at: Vector3 = (post["where"] as Vector3) + Vector3.UP * 1.3
		var to := at - eye

		if to.length() > MISS_RANGE or guard._cone_factor(to) < 0.4 or not guard._line_of_sight(eye, at, null):
			_missing.erase(i)
			continue

		# In the dark he could not tell whether anyone stands there.
		if to.length() > 5.0 and LightProbe.light_at(guard, at) < ODD_LIGHT:
			_missing.erase(i)
			continue

		_missing[i] = float(_missing.get(i, 0.0)) + step

		if float(_missing[i]) >= MISS_NOTICE:
			post["noticed"] = true
			_missing.erase(i)
			# Asked after by name (TalkDirector), else in his own way.
			if not _director().play_missing(guard, String(post["name"])):
				var said: String = guard._fighter.temper.line(&"missing") if guard._fighter != null and guard._fighter.temper != null else "Where's %s got to?"

				if said.contains("%s"):
					said = said % String(post["name"])

				guard.bark(said)

			garrison.raise_alarm(0.35)
			guard.notice(post["where"], &"missing")
			return


# ---------------------------------------------------------------------------
# Noises: one looks, the others cover him
# ---------------------------------------------------------------------------

## Something heard is worth a look: either another man is already looking
## into it (true: this one covers him), or it is his to look into (false),
## and he tells whichever friend is at hand.
func claim_or_cover(where: Vector3) -> bool:
	var garrison: RefCounted = _garrison()

	if garrison == null:
		return false

	var looker: Node3D = garrison.look_into(where, guard)

	if looker != null:
		cover(looker)
		return true

	# A friend near enough to hear him: he says so, and goes.
	for other in guard.get_tree().get_nodes_in_group(&"guards"):
		if other == guard or int(other.state) > SUSPICIOUS:
			continue

		if guard.global_position.distance_to(other.global_position) > FRIEND_RANGE:
			continue

		if guard._line_of_sight(guard.eye_position(), other.eye_position(), other):
			_covered = true
			var said: String = guard._fighter.temper.line(&"noise_ask") if guard._fighter != null and guard._fighter.temper != null else "Did you hear that?"
			guard.bark(said)
			Comms.call_out(guard, &"noise", where, {}, Comms.SPEECH_DB)
			break

	return false


## Covers `looker` (who went to look): stands watching the place, alert,
## until he comes back or calls.
func cover(looker: Node3D) -> void:
	if covering():
		return

	_covering = weakref(looker)
	_covering_name = String(looker.get("given_name"))
	_cover_left = COVER_MAX


## Sent by the man set to watch to look at `where` (Guard._heard_look): his
## to look into (the garrison knows: a noise there, the others cover him),
## and he calls out what he finds.
func sent_to_look(where: Vector3) -> void:
	var garrison: RefCounted = _garrison()

	if garrison != null:
		garrison.look_into(where, guard)

	_covered = true


func covering() -> bool:
	return _covering != null and _covering.get_ref() != null


## The place the friend he covers went to look at (INF when he covers nobody).
func covered_place() -> Vector3:
	var looker: Node3D = _covering.get_ref() as Node3D if _covering != null else null
	return looker.last_known_position if looker != null and bool(looker.get("has_last_known")) else Vector3.INF


func stop_covering() -> void:
	_covering = null
	_cover_left = 0.0


func _update_cover(delta: float) -> void:
	if _covering == null:
		return

	var looker: Node3D = _covering.get_ref() as Node3D
	_cover_left -= delta

	# His own eyes on you now: what he sees is his own business, not cover.
	if int(guard.state) >= INVESTIGATING or _cover_left <= 0.0 or guard.can_see_target:
		stop_covering()
		return

	# Gone without a "clear" (a club to the head takes him away at once) is
	# gone quiet too.
	if looker == null or looker.is_queued_for_deletion() or looker.get("_knocked_out") == true or not looker.is_inside_tree():
		# He went to look and went quiet: this one goes now, and not easy.
		# A man set to watch calls them all to it instead, and watches.
		stop_covering()

		if bool(guard.get("lookout")):
			var said: String = guard._fighter.temper.line(&"quiet") if guard._fighter != null and guard._fighter.temper != null else "%s's gone quiet! To arms!"

			if said.contains("%s"):
				said = said % _covering_name

			guard.bark(said)
			Comms.call_out(guard, &"alarm", guard.last_known_position)
			var garrison: RefCounted = _garrison()

			if garrison != null:
				garrison.raise_alarm(0.35)

		guard.notice(guard.last_known_position, &"call")
		return

	if int(looker.state) == RELAXED or int(looker.state) == COMBAT:
		# Back at his ease (it was nothing), or at you (his shout says where).
		stop_covering()
		return

	# Watching the place, and not letting it go.
	guard._since_stimulus = 0.0
	guard.alert = clampf(guard.alert, guard.suspicious_at + 1.0, guard.investigate_at - 1.0)


## He has finished looking: if a friend covered him, he calls that it was
## nothing, and the friend stands easy.
func done_looking() -> void:
	var garrison: RefCounted = _garrison()

	if garrison != null:
		garrison.looked(guard)

	if _covered:
		_covered = false
		var said: String = guard._fighter.temper.line(&"clear") if guard._fighter != null and guard._fighter.temper != null else "Nothing here."
		guard.bark(said)
		Comms.call_out(guard, &"clear", guard.last_known_position, {}, Comms.SPEECH_DB)


# ---------------------------------------------------------------------------
# The lantern
# ---------------------------------------------------------------------------

func _update_lantern(delta: float) -> void:
	var hands: RefCounted = guard.get("_hands")

	if hands == null:
		return

	var state := int(guard.state)
	_easy = _easy + delta if state == RELAXED else 0.0

	if hands.lantern != null:
		if state == COMBAT:
			hands.drop_lantern()
		elif _easy > DOUSE_AFTER and hands.light_kind == &"":
			hands.douse()

		return

	_lantern_check -= delta

	if _lantern_check > 0.0:
		return

	_lantern_check = 1.0

	if not bool(guard.get("carries_lantern")) or (state != INVESTIGATING and state != SEARCHING) or hands.busy():
		return

	var garrison: RefCounted = _garrison()

	if garrison == null or float(garrison.alarm) < LANTERN_ALARM:
		return

	if LightProbe.light_at(guard, guard.eye_position()) > LANTERN_DARK:
		return

	hands.light_lantern()
	guard.say(&"lantern", 0.35)


## What shows most in him (Temperament.gd's tag).
func _tag() -> StringName:
	var fighter: RefCounted = guard.get("_fighter")
	return fighter.temper.tag if fighter != null and fighter.temper != null else &"steady"


func _garrison() -> RefCounted:
	var target: Node3D = guard.get("_target")

	if target == null or not is_instance_valid(target):
		target = guard.get_tree().get_first_node_in_group(&"player") as Node3D

	return GarrisonScript.of(target) if target != null else null
