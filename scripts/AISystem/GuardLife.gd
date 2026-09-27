extends RefCounted
## A guard's life when there is no fight: his rounds as more than a walk.
##   talk      men at their ease and near each other talk: written
##             conversations chosen to fit the moment (TalkDirector, the
##             files in data/talk). You can listen. Anything that stirs one
##             of them ends it.
##   idle      standing his post a while, a man passes the time: warms his
##             hands, stamps his feet, leans on a wall, paces... (GuardPastimes).
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

static var _talk_script: GDScript = null
static var _rota_script: GDScript = null
static var _gathering_script: GDScript = null

var guard: CharacterBody3D
## After a conversation, this long before he talks again (TalkDirector).
var _talk_rest := 0.0
## Standing still this long, and what he does with himself (GuardPastimes).
var _resting := 0.0
var _pastimes: RefCounted
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
	_pastimes = GuardPastimesScript.new(p_guard)
	_watch_time = randf() * LOOKOUT_PERIOD


## Every physics frame, while he is up and about.
func update(delta: float) -> void:
	_talk_rest = maxf(_talk_rest - delta, 0.0)
	_pastimes.update(delta)
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

## Standing still at his post or a waypoint (or settled at a station).
func at_rest(delta: float) -> void:
	_resting += delta
	_pastimes.at_rest(delta)


## On the move: whatever he was doing standing still is over.
func walking() -> void:
	_resting = 0.0
	_pastimes.walking()


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
