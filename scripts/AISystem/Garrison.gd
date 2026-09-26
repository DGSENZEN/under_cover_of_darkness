extends RefCounted
## What the whole level knows of you. Every squad that fights you tells it
## what it saw you do, and every guard who comes after you knows it already:
## word spreads through a garrison.
##   habits  how you fight, each 0..1: turtle (behind a raised guard), spam
##           (blows on each other's heels), kite (keeping away), bow. Built
##           slowly from what the squads see (it takes a habit, not one
##           moment), and never forgotten for the level. A new squad comes
##           knowing them, and keeps the answer to them in its hands.
##   dread   0..1, what you have done to them: each man of theirs you kill in
##           a hunt, their captains most, a man cut apart in front of them, a
##           body found. It fades once it has been quiet a while. It weighs
##           on a man by how little nerve he has (fear_of), and turns to anger
##           in a man with plenty (anger_of).
##
## One for each target (`of`), kept for the level; `clear_all` forgets.

## A habit comes to match what they see over this many seconds.
const HABIT_TIME := 20.0
## What each thing adds to their dread.
const DREAD_KILL := 0.1
const DREAD_CAPTAIN := 0.15
const DREAD_GORE := 0.05
const DREAD_BODY := 0.03
## Quiet this long, dread starts to fade, at this much a second.
const DREAD_HOLD := 30.0
const DREAD_FADE := 0.1 / 60.0
## A man with this much nerve turns dread into anger.
const BOLD_NERVE := 0.7

static var _garrisons := {}

var target_ref: WeakRef
var habits := {&"turtle": 0.0, &"spam": 0.0, &"kite": 0.0, &"bow": 0.0}
var dread := 0.0
## Their dead, and their captains among them.
var dead := 0
var captains := 0
## The garrison's own time, advanced once a physics frame whoever calls.
var clock := 0.0
var _frame := -1
var _last_dread_at := -100.0


## The garrison's memory of `target` (made the first time it is asked for).
static func of(target: Node3D) -> RefCounted:
	if target == null or not is_instance_valid(target):
		return null

	var key := target.get_instance_id()
	var garrison: RefCounted = _garrisons.get(key)

	if garrison == null:
		_prune()
		garrison = (load("res://scripts/AISystem/Garrison.gd") as GDScript).new()
		garrison.target_ref = weakref(target)
		_garrisons[key] = garrison

	return garrison


## Forget everything (a new level, a test, the gym's F5).
static func clear_all() -> void:
	_garrisons.clear()


## Whoever it remembered is gone (a level reloaded): let it go.
static func _prune() -> void:
	for key in _garrisons.keys():
		var w: WeakRef = _garrisons[key].target_ref

		if w == null or w.get_ref() == null:
			_garrisons.erase(key)


## Once a physics frame, whoever calls first.
func tick(delta: float) -> void:
	var frame := Engine.get_physics_frames()

	if frame == _frame:
		return

	_frame = frame
	advance(delta)


## Time passes: dread fades for as much of it as came after the quiet began.
func advance(seconds: float) -> void:
	var before := clock
	clock += seconds
	var fading := clampf(clock - maxf(before, _last_dread_at + DREAD_HOLD), 0.0, seconds)
	dread = maxf(dread - DREAD_FADE * fading, 0.0)


## What a squad has seen of you (its `read`) over `step` seconds: a habit
## grows toward it, never back.
func learn(read: Dictionary, step: float) -> void:
	var k := 1.0 - exp(-step / HABIT_TIME)

	for key in habits.keys():
		var seen := float(read.get(key, 0.0))

		if seen > float(habits[key]):
			habits[key] = float(habits[key]) + (seen - float(habits[key])) * k


## One of theirs killed in a hunt (their leader, the worse).
func on_death(was_leader: bool) -> void:
	dead += 1

	if was_leader:
		captains += 1

	_dread(DREAD_KILL + (DREAD_CAPTAIN if was_leader else 0.0))


## A man cut apart where they could see it.
func on_gore() -> void:
	_dread(DREAD_GORE)


## One of theirs found lying where you left him.
func on_body_found() -> void:
	_dread(DREAD_BODY)


func _dread(amount: float) -> void:
	dread = minf(dread + amount, 1.0)
	_last_dread_at = clock


## How much the dread weighs on a man of this nerve.
func fear_of(nerve: float) -> float:
	return dread * (1.0 - nerve)


## How much of it a bold man turns to anger.
func anger_of(nerve: float) -> float:
	return dread * nerve if nerve >= BOLD_NERVE else 0.0


## A new squad's heart, before a blow is struck.
func opening_heart() -> float:
	return 1.0 - 0.3 * dread
