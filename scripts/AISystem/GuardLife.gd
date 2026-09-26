extends RefCounted
## A guard's life when there is no fight: his rounds as more than a walk.
##   talk      two men at their ease and near each other pass the time with
##             whatever is on the garrison's mind (Garrison.gossip): their
##             dead, their fear, what they have heard of how you fight, or the
##             cold. You can listen. Anything that stirs either of them ends
##             it.
##   idle      standing his post a while, a man folds his arms, or takes a
##             pull from his flask.
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
##             (GuardHands); at his ease a while, he puts it out.
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
## Standing still this long, a man finds something to do with himself.
const IDLE_AFTER := 3.0
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

var guard: CharacterBody3D
## Talking with, and whether he leads it (says when each line comes).
var partner: Node3D = null
var _lead := false
var _lines: Array = []
var _line := 0
var _line_timer := 0.0
var _talk_rest := 0.0
var _spoke_at := -10.0
## Standing still, and what he is doing with himself.
var _resting := 0.0
var _idle: StringName = &""
var _idle_left := 0.0
var _idle_wait := 0.0
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


func _init(p_guard: CharacterBody3D) -> void:
	guard = p_guard
	_check = randf() * CHECK
	_talk_rest = randf_range(6.0, 16.0)
	_idle_wait = randf_range(3.0, 8.0)
	_watch_time = randf() * LOOKOUT_PERIOD


## Every physics frame, while he is up and about.
func update(delta: float) -> void:
	_talk_rest = maxf(_talk_rest - delta, 0.0)
	_update_talk(delta)
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


## What he is doing with himself, for the rig: "talk", "listen", "fold_arms",
## "drink", or "".
func activity() -> StringName:
	if talking():
		return &"talk" if Comms.now() - _spoke_at < TALK_GAP * 0.85 else &"listen"

	# Fidgets are for a man at his ease: anything else and they are over.
	if int(guard.state) != RELAXED:
		_idle = &""
		_idle_left = 0.0

	return _idle


# ---------------------------------------------------------------------------
# Standing about
# ---------------------------------------------------------------------------

## Standing still at his post or a waypoint.
func at_rest(delta: float) -> void:
	_resting += delta

	if talking() or bool(guard.get("lookout")):
		_idle = &""
		return

	if _idle_left > 0.0:
		_idle_left -= delta

		if _idle_left <= 0.0:
			_idle = &""
			_idle_wait = randf_range(5.0, 10.0)

		return

	if _resting < IDLE_AFTER:
		return

	_idle_wait -= delta

	if _idle_wait > 0.0:
		return

	# A soldier's fidgets: arms folded a while, a pull from the flask.
	if randf() < 0.6:
		_idle = &"fold_arms"
		_idle_left = randf_range(4.0, 7.0)
	else:
		_idle = &"drink"
		_idle_left = 1.3


## On the move: whatever he was doing standing still is over.
func walking() -> void:
	_resting = 0.0
	_idle = &""
	_idle_left = 0.0


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
	_idle = &""


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
	speaker.bark(String(entry[1]))
	speaker._life._spoke_at = Comms.now()
	_line += 1
	_line_timer = TALK_GAP


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

	if int(guard.state) >= INVESTIGATING or _cover_left <= 0.0:
		stop_covering()
		return

	if looker.get("_knocked_out") == true or not looker.is_inside_tree():
		# He went to look and went quiet: this one goes now, and not easy.
		stop_covering()
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
		elif _easy > DOUSE_AFTER:
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


func _garrison() -> RefCounted:
	var target: Node3D = guard.get("_target")

	if target == null or not is_instance_valid(target):
		target = guard.get_tree().get_first_node_in_group(&"player") as Node3D

	return GarrisonScript.of(target) if target != null else null
