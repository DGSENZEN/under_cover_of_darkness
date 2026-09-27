extends RefCounted
## What the intruder does, told by the director (ShowDirector) a verb at a
## time: where to go and how (walking, running, sneaking in a crouch), whom
## to knife, how to fight, which way to run. The guards' side of it is all
## their own; only he follows a script.
##
## Fighting is by a tactic, each chosen to bring out something in the squad:
##   trade   a steady exchange with the front man: he meets most blows (a
##           parry or his guard), steps out of those no guard stops, and cuts
##           back, most of all when his man is recovering from a blow.
##   turtle  his guard up and held (raised again when a boot knocks it
##           down), a blow only now and then: the squad reads it and sends
##           the man who breaks guards.
##   parry   he fights his man (`focus`) and turns nearly every blow aside,
##           answering each parry with a riposte on the man he parried.
##   focus   he goes for one man (`focus`) and cuts only at him, parrying
##           most blows and answering with ripostes.
##   press   he goes for the man whose heart is failing (Squad.resolve_of).
##   spare   he faces the man begging him, then walks away.
## He never cuts a man on his knees (GuardMercy), and never sets out to.

## Guard.Alert: RELAXED stands him easy, COMBAT is his fighting stance (the
## rig reads it).
const RELAXED := 0
const COMBAT := 4
## How fast each gait goes (m/s).
const SNEAK_SPEED := 1.3
const WALK_SPEED := 1.6
## (Running he outpaces them, as a thief does: they chase at 4.6, the
## player sprints at 8.5.)
const RUN_SPEED := 7.5
## Close enough to where he was going.
const ARRIVE := 0.7
## A knife in the back from this near, from this far behind the man.
const STAB_REACH := 1.1
const STAB_BEHIND := 0.9
## Within this of the spot behind him, he steps straight in.
const CLOSE_IN := 2.5
## Where he stands to fight: at this distance from his man, closing if he is
## further than CLOSE_BEYOND past it (never out of CUT_REACH), backing off
## inside BACK_WITHIN of it.
const KEEP := 1.45
const CLOSE_BEYOND := 0.3
const BACK_WITHIN := 0.45
const BACK_SPEED := 1.2
## His blade's reach for choosing to cut (IntruderCombat reaches a little
## further).
const CUT_REACH := 1.8
## Trading: odds of a parry, of his guard (the rest land); how often he cuts.
const TRADE_PARRY := 0.45
const TRADE_BLOCK := 0.45
const CUT_EVERY := Vector2(1.2, 1.8)
## Punishing a man recovering from a blow: this long after he began to.
const PUNISH_AFTER := 0.1
## Turtling: a blow this often.
const TURTLE_CUT_EVERY := 4.0
## Parrying: the odds of a parry (else his guard), and the riposte's delay.
const PARRY_ODDS := 0.85
const RIPOSTE_AFTER := 0.12
## Going for one man: the odds of a parry (else his guard): the parries and
## their ripostes are what open a skilled man.
const FOCUS_PARRY := 0.7
## Pressing: how often he cuts.
const PRESS_EVERY := 1.0
## Sparing: how long he looks at the man begging him, how far he walks off.
const SPARE_LOOK := 1.5
const SPARE_WALK := 10.0
## A defence goes up this long before the blow lands: a parry late (inside
## IntruderCombat.PARRY_WINDOW), a guard early, a dodge just before.
const PARRY_AT := 0.12
const BLOCK_AT := 0.35
const DODGE_AT := 0.3
## A blow landing within this long (s) keeps him from starting a cut.
const COMING_SOON := 0.7
## How far he looks for a man to fight.
const FIGHT_RANGE := 14.0
## His cuts, in turn: most of them quick, now and then the heavy one.
const CUTS := [&"left", &"right", &"overhead", &"left", &"thrust", &"right", &"heavy"]

enum Verb { NONE, GO, HIDE, STAB, FIGHT, FLEE }

var intruder: CharacterBody3D
var combat: Node
var tactic: StringName = &""
var focus: Node3D = null

var _verb := Verb.NONE
var _gait: StringName = &"walk"
var _goal := Vector3.ZERO
var _route: Array[Vector3] = []
var _victim: Node3D = null
var _done := true
var _clock := 0.0
var _cut_at := 0.0
var _cut_index := 0
var _riposte_at := -1.0
var _riposte_on: Node3D = null
var _spare_from: Node3D = null
var _spare_since := -1.0
var _look_at := Vector3.INF
## Blows coming at him: [{"from": Node3D, "answer": StringName}].
var _coming: Array = []


func _init(p_intruder: CharacterBody3D, p_combat: Node) -> void:
	intruder = p_intruder
	combat = p_combat
	combat.defended.connect(_on_defended)


# ---------------------------------------------------------------------------
# Verbs (the director calls these)
# ---------------------------------------------------------------------------

## Walks to `point` along the navmesh: "sneak" (crouched), "walk", "run".
func go_to(point: Vector3, gait: StringName) -> void:
	_begin(Verb.GO)
	_gait = gait
	_goal = point
	intruder.crouched = gait == &"sneak"
	intruder._go_to(point, true)


## Sneaks to `point` and crouches still there.
func hide_at(point: Vector3) -> void:
	go_to(point, &"sneak")
	_verb = Verb.HIDE


## Sneaks up behind `victim` and puts his blade in his back.
func backstab(victim: Node3D) -> void:
	_begin(Verb.STAB)
	_victim = victim
	_gait = &"sneak"
	intruder.crouched = true


## Fights by `tactic` (the list at the top), `target` for "focus".
func fight(p_tactic: StringName, target: Node3D = null) -> void:
	if _verb != Verb.FIGHT:
		_begin(Verb.FIGHT)
		_cut_at = _clock + randf_range(CUT_EVERY.x, CUT_EVERY.y)

	tactic = p_tactic
	focus = target
	_done = false
	_spare_from = null
	_spare_since = -1.0
	intruder.crouched = false
	intruder.state = COMBAT
	combat.guard_up(false)


## Runs the points of `route` in turn (up and over what the links let him:
## GuardClimb carries him).
func flee_by(route: Array[Vector3]) -> void:
	_begin(Verb.FLEE)
	_route = route.duplicate()
	_gait = &"run"

	if not _route.is_empty():
		intruder._go_to(_route[0], true)


## Turns to look at `point` while standing.
func face(point: Vector3) -> void:
	_look_at = point


## Stands easy where he is.
func stand() -> void:
	_begin(Verb.NONE)


## The verb under way is over: there, stabbed, the route run, the spared man
## left behind.
func done() -> bool:
	return _done


## For the rig: "sneak" while crouched on his feet.
func activity() -> StringName:
	return &"sneak" if intruder.crouched else &""


## A guard's blow is coming at him (GuardFighter._start → warn_attack).
func on_warned(from: Node3D) -> void:
	if _verb != Verb.FIGHT or from == null or not is_instance_valid(from):
		return

	_coming = _coming.filter(func(c): return is_instance_valid(c["from"]) and c["from"] != from)
	_coming.append({"from": from, "answer": _answer_for(from)})


# ---------------------------------------------------------------------------
# Every physics frame (Intruder._puppet_drive)
# ---------------------------------------------------------------------------

## Before anything moves him (every frame he is on his feet, in a blow or
## not): the blows coming at him, met as he chose.
func react(_delta: float) -> void:
	if _verb == Verb.FIGHT:
		_defend()


func drive(delta: float) -> void:
	_clock += delta

	match _verb:
		Verb.NONE:
			intruder._stop(delta)
			_face_look(delta)
		Verb.GO, Verb.HIDE:
			_drive_go(delta)
		Verb.STAB:
			_drive_stab(delta)
		Verb.FIGHT:
			_drive_fight(delta)
		Verb.FLEE:
			_drive_flee(delta)


func _begin(verb: Verb) -> void:
	_verb = verb
	_done = verb == Verb.NONE
	_coming.clear()
	_victim = null
	_look_at = Vector3.INF
	intruder.crouched = false
	intruder.state = RELAXED
	combat.guard_up(false)


func _speed() -> float:
	match _gait:
		&"sneak":
			return SNEAK_SPEED
		&"run":
			return RUN_SPEED

	return WALK_SPEED


func _drive_go(delta: float) -> void:
	if _done:
		intruder._stop(delta)
		_face_look(delta)
		return

	if intruder._walk(_speed(), delta) or _flat(intruder.global_position, _goal) < ARRIVE:
		# "Finished" before the navmesh answered is not there: ask again.
		if _flat(intruder.global_position, _goal) > ARRIVE * 1.5 and intruder._agent.get_current_navigation_path().is_empty():
			intruder._go_to(_goal, true)
			return

		_done = true
		intruder._stop(delta)


func _drive_stab(delta: float) -> void:
	if _victim == null or not is_instance_valid(_victim) or _victim.get("_knocked_out") == true:
		_done = true
		intruder.crouched = false
		intruder._stop(delta)
		return

	var behind: Vector3 = _victim.global_position + _victim.global_basis.z * STAB_BEHIND
	var near := _flat(intruder.global_position, _victim.global_position)

	if near > STAB_REACH:
		# The last steps straight in (the navmesh calls a path done short of
		# a knife's reach).
		if _flat(intruder.global_position, behind) < CLOSE_IN:
			var step := behind - intruder.global_position
			step.y = 0.0
			step = step.normalized() * SNEAK_SPEED
			intruder.velocity.x = step.x
			intruder.velocity.z = step.z
			intruder._face(step, delta)
		else:
			intruder._go_to(behind)
			intruder._walk(SNEAK_SPEED, delta)

		return

	intruder._stop(delta)
	intruder._face(_victim.global_position - intruder.global_position, delta, 3.0)

	if not combat.busy():
		combat.backstab(_victim)


func _drive_flee(delta: float) -> void:
	if _route.is_empty():
		_done = true
		intruder._stop(delta)
		return

	var point: Vector3 = _route[0]

	if intruder._walk(RUN_SPEED, delta) or _flat(intruder.global_position, point) < ARRIVE:
		if _flat(intruder.global_position, point) > ARRIVE * 1.5 and intruder._agent.get_current_navigation_path().is_empty():
			intruder._go_to(point, true)
			return

		_route.remove_at(0)

		if not _route.is_empty():
			intruder._go_to(_route[0], true)


# ---------------------------------------------------------------------------
# Fighting
# ---------------------------------------------------------------------------

func _drive_fight(delta: float) -> void:
	if tactic == &"spare":
		_drive_spare(delta)
		return

	var man := _pick_man()

	if man == null:
		intruder._stop(delta)
		combat.guard_up(tactic == &"turtle")
		return

	var to := man.global_position - intruder.global_position
	to.y = 0.0
	var dist := to.length()

	# A man thrown open within reach: whatever the tactic, the deathblow.
	var opened := _opened_near()

	if opened != null and not combat.busy():
		var at := opened.global_position
		intruder.look_at(Vector3(at.x, intruder.global_position.y, at.z), Vector3.UP)
		combat.guard_up(false)
		combat.swing(&"overhead", opened)
		return

	# Footwork: to his distance and no nearer, always facing his man.
	if dist > KEEP + CLOSE_BEYOND:
		intruder._go_to(man.global_position)
		intruder._walk(WALK_SPEED * 1.3, delta)
	elif dist < KEEP - BACK_WITHIN:
		var back := -to.normalized() * BACK_SPEED
		intruder.velocity.x = back.x
		intruder.velocity.z = back.z
	else:
		intruder._stop(delta)

	intruder._face(to, delta, 2.0)

	match tactic:
		&"turtle":
			if not combat.busy() and _clock >= _cut_at and dist <= CUT_REACH:
				_cut()
				_cut_at = _clock + TURTLE_CUT_EVERY
			elif not combat.busy() or combat.phase == combat.Phase.RECOVER:
				combat.guard_up(true)
		&"press":
			if _clock >= _cut_at and dist <= CUT_REACH and not _blow_coming():
				_cut()
				_cut_at = _clock + PRESS_EVERY
		_:
			# trade, focus, parry: a cut on his rhythm (at his man: he faces
			# him), and at once when his man is recovering from a blow of his
			# own or thrown open (the moment to punish). Parrying, first the
			# riposte, on the man he parried.
			if tactic in [&"parry", &"focus"] and _riposte_on != null and is_instance_valid(_riposte_on) and _clock >= _riposte_at:
				var at := _riposte_on.global_position

				if _flat(intruder.global_position, at) <= CUT_REACH and not combat.busy():
					intruder.look_at(Vector3(at.x, intruder.global_position.y, at.z), Vector3.UP)
					_riposte_on = null
					_cut()
					return

			var punish: bool = _opened(man) or (man.get("_phase") == &"recover" and float(man.get("_phase_timer")) < float(man.get("_phase_length")) - PUNISH_AFTER)

			if dist <= CUT_REACH and not _blow_coming() and (punish or _clock >= _cut_at):
				_cut()
				_cut_at = _clock + randf_range(CUT_EVERY.x, CUT_EVERY.y)


## The man he fights now: `focus` if still standing; for press the one
## whose heart is failing; else the nearest who is after him. Never a man
## on his knees.
func _pick_man() -> Node3D:
	if focus != null and _standing(focus):
		return focus

	var best: Node3D = null
	var best_score := INF

	for man in intruder.get_tree().get_nodes_in_group(&"guards"):
		if not (man is Node3D) or not _standing(man as Node3D) or _begging(man as Node3D):
			continue

		var dist := _flat(intruder.global_position, (man as Node3D).global_position)

		if dist > FIGHT_RANGE:
			continue

		var score := dist

		# Parrying: the man most easily thrown open (the least posture to
		# fill), then the nearest.
		if tactic == &"parry" and man.get("_fighter") != null:
			score = float(man._fighter.posture_max) / 10.0 + dist

		if tactic == &"press":
			var squad: RefCounted = man.get("_fighter").get("squad") if man.get("_fighter") != null else null
			score = float(squad.resolve_of(man)) * 10.0 + dist * 0.1 if squad != null else 10.0 + dist

		if score < best_score:
			best_score = score
			best = man as Node3D

	return best


## A blow of theirs about to land that he means to meet: no cut of his own
## into it (a man who swings into a blow cannot meet it).
func _blow_coming() -> bool:
	for coming in _coming:
		if not is_instance_valid(coming["from"]) or coming["answer"] == &"":
			continue

		var from: Node3D = coming["from"]

		if from.get("_phase") == &"windup" and float(from.get("_phase_timer")) < COMING_SOON:
			return true

	return false


func _cut(at: Node3D = null) -> void:
	combat.guard_up(false)
	var man: Node3D = at if at != null else _pick_man()
	var fighter: RefCounted = man.get("_fighter") if man != null else null

	# A man behind his guard: the heavy blow, which breaks it.
	if fighter != null and bool(fighter.get("guarding")) and tactic in [&"parry", &"focus", &"trade"]:
		combat.swing(&"heavy", man)
		return

	combat.swing(CUTS[_cut_index % CUTS.size()], man)
	_cut_index += 1


func _drive_spare(delta: float) -> void:
	if _spare_from == null or not is_instance_valid(_spare_from):
		_spare_from = null

		for man in intruder.get_tree().get_nodes_in_group(&"guards"):
			if man is Node3D and _begging(man as Node3D):
				if _spare_from == null or _flat(intruder.global_position, (man as Node3D).global_position) < _flat(intruder.global_position, _spare_from.global_position):
					_spare_from = man as Node3D

		if _spare_from == null:
			intruder._stop(delta)
			return

		_spare_since = _clock

	# A look at him first; then away, his back to him.
	if _clock - _spare_since < SPARE_LOOK:
		intruder._stop(delta)
		intruder._face(_spare_from.global_position - intruder.global_position, delta, 2.0)
		return

	var away := intruder.global_position - _spare_from.global_position
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else intruder.global_basis.z
	var goal := _spare_from.global_position + away * SPARE_WALK
	intruder.state = RELAXED

	if _goal.distance_to(goal) > 2.0:
		_goal = goal
		intruder._go_to(goal, true)

	if intruder._walk(WALK_SPEED, delta) or _flat(intruder.global_position, _goal) < ARRIVE:
		_done = true
		intruder._stop(delta)


## What he does about a blow coming at him, by his tactic and the blow: a
## boot, the great blow or a charge he steps out of; a low cut too; the rest
## he parries, takes on his guard or (now and then, trading) lets land.
func _answer_for(from: Node3D) -> StringName:
	var info: Dictionary = from.attack_info() if from.has_method("attack_info") else {}

	if bool(info.get("ranged", false)):
		return &"block"

	if bool(info.get("unblockable", false)) or bool(info.get("low", false)):
		return &"block" if tactic == &"turtle" else &"dodge"

	match tactic:
		&"turtle":
			return &"block"
		&"parry":
			return &"parry" if randf() < PARRY_ODDS else &"block"
		&"focus":
			return &"parry" if randf() < FOCUS_PARRY else &"block"

	var roll := randf()

	if roll < TRADE_PARRY:
		return &"parry"

	if roll < TRADE_PARRY + TRADE_BLOCK:
		return &"block"

	return &""


## The blows coming at him, met as he chose, each at its moment.
func _defend() -> void:
	var still: Array = []

	for coming in _coming:
		if not is_instance_valid(coming["from"]):
			continue

		var from: Node3D = coming["from"]

		if from.get("_knocked_out") == true:
			continue

		var phase: StringName = from.get("_phase")

		# Over (landed, missed, feinted or broken off): his guard comes down
		# again, unless he means to keep it up.
		if phase != &"windup":
			if coming.get("raised", false) and tactic != &"turtle":
				combat.guard_up(false)
			continue

		var left: float = float(from.get("_phase_timer"))
		var answer: StringName = coming["answer"]

		match answer:
			&"parry":
				if left <= PARRY_AT and not coming.get("raised", false):
					# Fresh: a guard already up is no parry.
					combat.guard_up(false)
					combat.guard_up(true)
					coming["raised"] = true
			&"block":
				if left <= BLOCK_AT and not coming.get("raised", false):
					combat.guard_up(true)
					coming["raised"] = true
			&"dodge":
				if left <= DODGE_AT and not coming.get("done", false):
					combat.dodge(from.global_position)
					coming["done"] = true

		still.append(coming)

	_coming = still


func _on_defended(result: StringName) -> void:
	if result == &"parry" and _verb == Verb.FIGHT and tactic in [&"parry", &"focus"]:
		_riposte_at = _clock + RIPOSTE_AFTER
		_riposte_on = combat.last_parried if combat.last_parried != null and is_instance_valid(combat.last_parried) else _pick_man()


func _face_look(delta: float) -> void:
	if _look_at != Vector3.INF:
		intruder._face(_look_at - intruder.global_position, delta)


static func _standing(man: Node3D) -> bool:
	if not is_instance_valid(man) or man.get("_knocked_out") == true:
		return false

	return not (man.has_method("is_downed") and man.is_downed())


## A man thrown open within his reach, if any.
func _opened_near() -> Node3D:
	for man in intruder.get_tree().get_nodes_in_group(&"guards"):
		if man is Node3D and _standing(man as Node3D) and not _begging(man as Node3D) and _opened(man as Node3D) and _flat(intruder.global_position, (man as Node3D).global_position) <= CUT_REACH:
			return man as Node3D

	return null


## Thrown off his balance (GuardFighter: OPEN): any blade blow is his death.
static func _opened(man: Node3D) -> bool:
	return man.has_method("is_open") and bool(man.is_open())


static func _begging(man: Node3D) -> bool:
	var mercy: Variant = man.get("_mercy")
	return mercy != null and bool((mercy as Object).get("pleading"))


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
