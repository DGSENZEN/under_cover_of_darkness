extends RefCounted
## A guard's life when there is no fight: his rounds as more than a walk.
##   talk      two men at their ease and near each other pass the time with
##             whatever is on the garrison's mind (Garrison.gossip): their
##             dead, their fear, what they have heard of how you fight, or the
##             cold. The one listening nods along, or shakes his head (by his
##             temperament). You can listen. Anything that stirs either of
##             them ends it. Talking, each looks at the other, sat or stood.
##   glances   at his ease, he looks round at a man going by, a moment.
##   greeting  going by a man at his ease, a word to him now and then
##             ("Evening, Hendrik."); he looks round and nods, and may say
##             something back. Not the same two again for a good while.
##   idle      what he does with himself standing about, sat, leaning:
##             GuardHabits.gd.
##   oddities  a door you left open, your arrow in a wall: he notices it (it
##             takes light, and a look), goes to it and deals with it (shuts
##             the door, pulls the arrow out), then searches about it; the
##             garrison is roused a little.
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
## Talk: within this of each other, a line this often, then a rest this long
## (s) before either talks again.
const TALK_RANGE := 3.8
const TALK_GAP := 2.6
const TALK_REST := Vector2(40.0, 80.0)
## Listening, he nods (or shakes his head) this long after each line.
const REACT := 1.6
## Seeing something out of place: this long in view (weighted by how near the
## middle of his view it is) before it registers; how far off it can be; and
## the light it needs beyond arm's length.
const NOTICE := 0.9
const DOOR_RANGE := 11.0
const ARROW_RANGE := 7.0
const ODD_LIGHT := 0.08
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

var guard: CharacterBody3D
## Talking with, and whether he leads it (says when each line comes).
var partner: Node3D = null
var _lead := false
var _lines: Array = []
var _line := 0
var _line_timer := 0.0
var _talk_rest := 0.0
var _spoke_at := -10.0
## Standing still this long (talk starts between men at rest).
var _resting := 0.0
## Listening: how he takes the last line ("nod", "shake", "") and when.
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
	_watch_time = randf() * LOOKOUT_PERIOD


## Every physics frame, while he is up and about.
func update(delta: float) -> void:
	_talk_rest = maxf(_talk_rest - delta, 0.0)
	_glance_rest = maxf(_glance_rest - delta, 0.0)
	_greet_rest = maxf(_greet_rest - delta, 0.0)
	_update_talk(delta)
	_update_regard(delta)
	_update_greeting(delta)
	_update_cover(delta)
	_update_lantern(delta)
	_check -= delta

	if _check > 0.0:
		return

	_check = CHECK
	var state := int(guard.state)

	if state == RELAXED or state == SUSPICIOUS:
		_look_for_oddities(CHECK)
		_look_for_missing(CHECK)

	if state == RELAXED:
		_look_for_company()
		_greet_passing()
		_look_round()


## What he is doing with himself, for the rig: "talk", "listen" ("nod" or
## "shake" just after the other's line), or "".
func activity() -> StringName:
	if not talking():
		return &""

	if Comms.now() - _spoke_at < TALK_GAP * 0.85:
		return &"talk"

	if _react != &"" and Comms.now() - _react_at < REACT:
		return _react

	return &"listen"


# ---------------------------------------------------------------------------
# Standing about
# ---------------------------------------------------------------------------

## Standing (or sat, or leaning) still at his post or a waypoint: what he
## does with himself meanwhile is GuardHabits'.
func at_rest(delta: float) -> void:
	_resting += delta


## On the move: he is not at rest.
func walking() -> void:
	_resting = 0.0


## A lookout at his post: the way he faces now, sweeping his ground.
func watch_yaw(home_yaw: float, delta: float) -> float:
	_watch_time += delta
	return home_yaw + sin(_watch_time * TAU / LOOKOUT_PERIOD) * deg_to_rad(LOOKOUT_ARC)


# ---------------------------------------------------------------------------
# Talk
# ---------------------------------------------------------------------------

func talking() -> bool:
	return partner != null and is_instance_valid(partner)


## Which way his partner is (to face him).
func partner_direction() -> Vector3:
	return partner.global_position - guard.global_position if talking() else Vector3.ZERO


## At his ease: nothing on his mind, nothing wrong with him.
static func at_ease(man: Node) -> bool:
	if man == null or not is_instance_valid(man) or man.get("_knocked_out") == true:
		return false

	if int(man.state) != RELAXED or float(man.alert) >= float(man.suspicious_at) * 0.5:
		return false

	if man.is_downed() or float(man._burning) > 0.0 or float(man._stagger) > 0.0:
		return false

	var fighter: RefCounted = man.get("_fighter")
	return fighter == null or not bool(fighter.stays_put)


func _look_for_company() -> void:
	if _talk_rest > 0.0 or talking() or bool(guard.get("lookout")) or _resting < 1.0 or not at_ease(guard):
		return

	for other in guard.get_tree().get_nodes_in_group(&"guards"):
		if other == guard or other.get("_life") == null or bool(other.get("lookout")):
			continue

		var life: RefCounted = other._life

		if life.talking() or float(life._talk_rest) > 0.0 or float(life._resting) < 0.5 or not at_ease(other):
			continue

		if guard.global_position.distance_to(other.global_position) > TALK_RANGE:
			continue

		if not guard._line_of_sight(guard.eye_position(), other.eye_position(), other):
			continue

		_begin_talk(other)
		return


func _begin_talk(other: Node3D) -> void:
	var garrison: RefCounted = _garrison()
	var pair: Array = garrison.gossip() if garrison != null else GarrisonScript.SMALL_TALK[randi() % GarrisonScript.SMALL_TALK.size()]
	_lines = [[0, pair[0]], [1, pair[1]]]

	# Now and then it runs on a while.
	if garrison != null and randf() < 0.4:
		var more: Array = garrison.gossip()

		if more[0] != pair[0]:
			_lines.append_array([[0, more[0]], [1, more[1]]])

	partner = other
	_lead = true
	_line = 0
	_line_timer = 0.4
	other._life._join_talk(guard)


func _join_talk(lead: Node3D) -> void:
	partner = lead
	_lead = false


func _update_talk(delta: float) -> void:
	if partner != null and not is_instance_valid(partner):
		partner = null

	if not talking():
		return

	# Anything that stirs either of them ends it.
	if not at_ease(guard) or not at_ease(partner) or partner._life.partner != guard:
		end_talk()
		return

	if not _lead:
		return

	_line_timer -= delta

	if _line_timer > 0.0:
		return

	if _line >= _lines.size():
		end_talk()
		return

	var entry: Array = _lines[_line]
	var speaker: Node3D = guard if int(entry[0]) == 0 else partner
	var listener: Node3D = partner if speaker == guard else guard
	speaker.bark(String(entry[1]))
	speaker._life._spoke_at = Comms.now()
	listener._life._take_line()
	_line += 1
	_line_timer = TALK_GAP


## Listening to a line: a nod from an easy man, now and then a shake of the
## head from a hard one.
func _take_line() -> void:
	var fighter: RefCounted = guard.get("_fighter")
	var tag: StringName = fighter.temper.tag if fighter != null and fighter.temper != null else &"steady"
	var roll := randf()
	_react_at = Comms.now()

	if tag in [&"rash", &"stubborn"]:
		_react = &"shake" if roll < 0.4 else (&"nod" if roll < 0.6 else &"")
	else:
		_react = &"nod" if roll < 0.6 else (&"shake" if roll < 0.7 else &"")


func end_talk() -> void:
	var other := partner
	partner = null
	_lead = false
	_lines = []
	_talk_rest = randf_range(TALK_REST.x, TALK_REST.y)

	if other != null and is_instance_valid(other) and other.get("_life") != null and other._life.partner == guard:
		other._life.partner = null
		other._life._lead = false
		other._life._talk_rest = randf_range(TALK_REST.x, TALK_REST.y)


# ---------------------------------------------------------------------------
# Glances and greetings
# ---------------------------------------------------------------------------

## Which way the man he looks at is (Guard._update_head turns his head to
## him): the man he talks with, one going by, one who greets him. Zero when
## nobody.
func regard_direction() -> Vector3:
	var who: Node3D = partner if talking() else _regard

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
		guard.say(&"greet_back")


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

		var said: String = guard._fighter.temper.line(&"greet") if guard._fighter != null and guard._fighter.temper != null else "Evening."

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

	for door in tree.get_nodes_in_group(&"doors"):
		if door.has_method("left_open") and door.left_open() and not door.has_meta(&"noticed"):
			var way: Vector3 = door.doorway() if door.has_method("doorway") else door.global_position

			# The panel standing open, or the gap where it should be: a door
			# swung back behind its wall still leaves its doorway gaping.
			if _watch_for(door, [door.panel_centre(), way + Vector3.UP], DOOR_RANGE, eye, step):
				_notice(door, &"door", way)
				return
		else:
			_noticing.erase(door)

	for arrow in tree.get_nodes_in_group(&"stray_arrows"):
		if arrow.is_queued_for_deletion() or arrow.has_meta(&"noticed"):
			continue

		if _watch_for(arrow, [(arrow as Node3D).global_position], ARROW_RANGE, eye, step):
			_notice(arrow, &"arrow", (arrow as Node3D).global_position)
			return


## Whether `thing`, seen at any of `points`, looked at a while, has
## registered (in reach, in view, lit enough or near). Counts the time it has
## been seen, by the best view of it.
func _watch_for(thing: Node3D, points: Array, reach: float, eye: Vector3, step: float) -> bool:
	var best := 0.0

	for at: Vector3 in points:
		var to := at - eye

		if to.length() > reach:
			continue

		var cone: float = guard._cone_factor(to)

		if cone < 0.5 or cone <= best or not guard._line_of_sight(eye, at, thing):
			continue

		if to.length() > 3.0:
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


func _notice(thing: Node3D, kind: StringName, where: Vector3) -> void:
	thing.set_meta(&"noticed", true)
	_noticing.erase(thing)
	_odd = thing
	_odd_kind = kind
	guard.say(&"odd_door" if kind == &"door" else &"odd_arrow")
	var garrison: RefCounted = _garrison()

	if garrison != null:
		garrison.raise_alarm(0.2 if kind == &"door" else 0.35)

	# To the doorway, from his own side of it (clear of its swing); to the arrow.
	var go := where

	if kind == &"door":
		var side := guard.global_position - where
		side.y = 0.0

		if side.length() > 0.1:
			go = where + side.normalized() * 1.1

	guard.notice(go, &"oddity")


## Arrived at what he noticed: he deals with it. True if there was anything
## (he then looks about him as usual).
func deal_with_oddity() -> bool:
	var thing := _odd
	_odd = null

	if thing == null or not is_instance_valid(thing):
		return false

	match _odd_kind:
		&"door":
			if thing.get("is_open") == true:
				thing.frob(guard)
		&"arrow":
			guard._hands.stoop_for(thing, &"evidence")

	return true


## The oddity he is on his way to (for tests and the gym's labels).
func oddity() -> Node3D:
	return _odd if _odd != null and is_instance_valid(_odd) else null


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


func stop_covering() -> void:
	_covering = null
	_cover_left = 0.0


func _update_cover(delta: float) -> void:
	if not covering():
		_covering = null
		return

	var looker: Node3D = _covering.get_ref() as Node3D
	_cover_left -= delta

	# His own eyes on you now: what he sees is his own business, not cover.
	if int(guard.state) >= INVESTIGATING or _cover_left <= 0.0 or guard.can_see_target:
		stop_covering()
		return

	if looker.get("_knocked_out") == true or not looker.is_inside_tree():
		# He went to look and went quiet: this one goes now, and not easy.
		# A man set to watch calls them all to it instead, and watches.
		stop_covering()

		if bool(guard.get("lookout")):
			var said: String = guard._fighter.temper.line(&"quiet") if guard._fighter != null and guard._fighter.temper != null else "%s's gone quiet! To arms!"

			if said.contains("%s"):
				said = said % String(looker.get("given_name"))

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
