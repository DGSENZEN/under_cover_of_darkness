extends RefCounted
## Everyone fighting one enemy together, the way Halo's squads do it: one of
## them leads and calls the plan out loud, the whole group follows it, and
## each has a place in it by what he is and where he stands. They read you
## together and change the plan when you change how you fight; they lose
## heart when their leader falls, and the brute loses his temper.
##
## The plan (`tactic`):
##   envelop    one holds you in front; others work round to your sides and
##              back, and strike when you commit to someone else; an archer
##              shoots from behind them; the rest wait their turn at the ring.
##   press      you are hurt: two come at once.
##   break      you hide behind your blade: the brute comes in with the blow it
##              cannot stop; the others feint and kick.
##   rush       you keep away (a bow, backing off): they close fast, and an
##              archer shoots whenever you stand still.
##   fall_back  half of them are down: back together round the leader, guards
##              up, calling for help; then at you again.
##   rout       their leader is dead and their heart gone: they run for help;
##              the brute goes berserk.
## A place (`role_of`): engage, flank, reserve, support (an archer), bodyguard
## (between you and an archer you are going for), breaker (the brute, to break
## a turtle), rally, flee, berserk.
##
## One is made for each target (`Squad.of`). Each fighter calls `think` every
## frame; the plan is made again a few times a second, on the squad's own
## clock (the fighters' clocks each start when the man does). A man alone is
## simply engaged: nothing changes for him.

## How often the plan is made again (seconds), and the least time a plan is
## kept before another is chosen.
const THINK := 0.3
const KEEP := 3.0
## Rank to lead (highest leads).
const RANK := {&"duelist": 4, &"brute": 3, &"swordsman": 2, &"": 1, &"archer": 0}
## What they shout when the plan changes.
const CALLS := {
	&"envelop": ["Surround him!", "Box him in!", "Get round him!"],
	&"press": ["He's done for! Finish him!", "He's bleeding - press him!"],
	&"break": ["He's hiding behind his blade - break it!", "Smash through his guard!"],
	&"rush": ["Close in! Don't let him shoot!", "Rush him!"],
	&"fall_back": ["Fall back! To me!", "Regroup! Together!"],
	&"rout": ["The captain's down! Run!", "Get help! Run!"],
}

static var _squads := {}

var target_ref: WeakRef
var tactic: StringName = &"envelop"
## What they have seen you do, each 0..1 and fading: turtle (a raised guard),
## spam (blows on each other's heels), kite (keeping away), bow (shooting).
var read := {&"turtle": 0.0, &"spam": 0.0, &"kite": 0.0, &"bow": 0.0}
## Their heart, 0..1.
var morale := 1.0
## The most of them there have been in this fight.
var largest := 0

var _members: Array[WeakRef] = []
var _roles := {}
var _slots := {}
var _leader: WeakRef = null
var _leader_fell_at := -100.0
## The brute's temper, once his captain has fallen.
var _berserk_until := -100.0
var _tactic_since := -100.0
var _fall_back_until := -100.0
var _last_think := -100.0
var _last_call := -100.0
var _last_swap := -100.0
## The man worn down in front and sent back: not put in front again while
## there is anyone else.
var _swapped_out: WeakRef = null
var _last_serial := -1
var _last_threat_at := -100.0
var _last_health := -1.0
## The squad's own time, advanced once a physics frame whoever calls.
var clock := 0.0
var _frame := -1


## The squad fighting `target` (made the first time it is asked for).
static func of(target: Node3D) -> RefCounted:
	if target == null or not is_instance_valid(target):
		return null

	var key := target.get_instance_id()
	var squad: RefCounted = _squads.get(key)

	if squad == null:
		squad = (load("res://scripts/AISystem/Squad.gd") as GDScript).new()
		squad.target_ref = weakref(target)
		_squads[key] = squad

	return squad


## Forget every squad (a clean start: tests, a new level).
static func clear_all() -> void:
	_squads.clear()


func target() -> Node3D:
	return target_ref.get_ref() as Node3D if target_ref != null else null


# ---------------------------------------------------------------------------
# Who is in it
# ---------------------------------------------------------------------------

func join(guard: Node3D) -> void:
	for w in _members:
		if w.get_ref() == guard:
			return

	# The first of a new fight: nothing carried over from the last one.
	if members().is_empty():
		_fresh()

	_members.append(weakref(guard))
	largest = maxi(largest, members().size())


func _fresh() -> void:
	_members.clear()
	_roles.clear()
	_slots.clear()
	_leader = null
	_leader_fell_at = -100.0
	_berserk_until = -100.0
	_tactic_since = -100.0
	_fall_back_until = -100.0
	_last_swap = -100.0
	_swapped_out = null
	_last_serial = -1
	_last_health = -1.0
	tactic = &"envelop"
	morale = 1.0
	largest = 0

	for key in read.keys():
		read[key] = 0.0


func leave(guard: Node3D) -> void:
	_members = _members.filter(func(w: WeakRef) -> bool: return w.get_ref() != null and w.get_ref() != guard)
	_roles.erase(guard.get_instance_id())
	_slots.erase(guard.get_instance_id())


## One of them fell: it shakes the rest, and the leader's fall most of all.
func member_died(guard: Node3D) -> void:
	var was_leader: bool = _leader != null and _leader.get_ref() == guard
	leave(guard)
	morale = maxf(morale - (0.45 if was_leader else 0.2), 0.0)

	if was_leader:
		_leader = null
		_leader_fell_at = clock
		_berserk_until = clock + 12.0

	# The brute takes it personally.
	for member in members():
		if _kind(member) == &"brute":
			member.bark("RAAAGH!")


## Those still fighting (alive, in combat, after this target).
func members() -> Array:
	var alive := []

	for w in _members:
		var guard = w.get_ref()

		if guard == null or not is_instance_valid(guard) or guard.is_queued_for_deletion() or guard.get("_knocked_out") == true:
			continue

		if int(guard.state) != 4 or guard.get("_target") != target():
			continue

		alive.append(guard)

	return alive


func leader() -> Node3D:
	return _leader.get_ref() as Node3D if _leader != null else null


func role_of(guard: Node3D) -> StringName:
	return _roles.get(guard.get_instance_id(), &"engage")


## Where round you a man waiting to strike stands: degrees from where you
## face (0 in front of you).
func slot_angle(guard: Node3D) -> float:
	return float(_slots.get(guard.get_instance_id(), 100.0))


## How many may swing at you at once.
func attackers() -> int:
	return 2 if tactic == &"press" else 1


## A plan's push on one of their odds (added to it): kick, feint, parry,
## guard, lunge.
func bonus(what: StringName) -> float:
	match what:
		&"kick":
			return 0.4 * read[&"turtle"] + (0.2 if tactic == &"break" else 0.0)
		&"feint":
			return 0.3 * read[&"turtle"]
		&"parry":
			return 0.25 * read[&"spam"]
		&"guard":
			return 0.25 * read[&"spam"] + (0.3 if tactic == &"fall_back" else 0.0)
		&"lunge":
			return 0.35 * read[&"kite"] + (0.2 if tactic == &"rush" else 0.0)
		&"backstep":
			return 0.2 * read[&"spam"]

	return 0.0


## Where they rally to when they fall back: the leader, or an archer, or
## their middle.
func rally_point() -> Vector3:
	var lead := leader()

	if lead != null:
		return lead.global_position

	var sum := Vector3.ZERO
	var alive := members()

	for member in alive:
		if member.get("_fighter") != null and member._fighter.ranged:
			return member.global_position

		sum += member.global_position

	return sum / maxf(alive.size(), 1.0)


## Whether he may throw a blow at you now, as the plan has it. A man at your
## side or back strikes when you have committed to someone else (a blow
## under way, or your guard turned to another); one waiting his turn only if
## you come to him; the man in front, and anyone pressing, when he likes.
func may_strike(guard: Node3D) -> bool:
	var role := role_of(guard)

	match role:
		&"engage", &"breaker", &"berserk", &"bodyguard":
			return true
		&"flank":
			return _committed_away_from(guard)
		&"reserve", &"rally", &"flee":
			var enemy := target()
			return enemy != null and guard.global_position.distance_to(enemy.global_position) < 2.0

	return true


## You are busy with someone other than `guard`: swinging, winding up,
## drawing, or holding your guard toward another.
func _committed_away_from(guard: Node3D) -> bool:
	var enemy := target()

	if enemy == null:
		return false

	var combat: Node = enemy.get("combat")

	if combat == null:
		return false

	var facing := -enemy.global_basis.z
	facing.y = 0.0
	var to_him := guard.global_position - enemy.global_position
	to_him.y = 0.0
	# You would have to turn to him to deal with him.
	var away := to_him.length() < 0.01 or facing.normalized().dot(to_him.normalized()) < 0.3

	if not away:
		return false

	var phase: int = int(combat.phase)
	var busy: bool = combat.blocking or phase == combat.Phase.WINDUP or phase == combat.Phase.STRIKE or phase == combat.Phase.CHARGING or phase == combat.Phase.DRAWING or phase == combat.Phase.RECOVER
	return busy


# ---------------------------------------------------------------------------
# Making the plan
# ---------------------------------------------------------------------------

func think(delta: float) -> void:
	var frame := Engine.get_physics_frames()

	if frame != _frame:
		_frame = frame
		clock += delta

	var now := clock

	if now - _last_think < THINK:
		return

	var step := now - _last_think if _last_think > 0.0 else THINK
	_last_think = now
	var alive := members()
	largest = maxi(largest, alive.size())

	if alive.is_empty():
		return

	_read_you(step, alive, now)
	_choose_leader(alive)
	_choose_tactic(alive, now)
	_give_places(alive, now)


func _read_you(step: float, alive: Array, now: float) -> void:
	var enemy := target()

	if enemy == null:
		return

	var fade := exp(-step / 5.0)

	for key in read.keys():
		read[key] = float(read[key]) * fade

	var combat: Node = enemy.get("combat")
	var nearest := INF

	for member in alive:
		if member.get("_fighter") != null and not member._fighter.ranged:
			nearest = minf(nearest, member.global_position.distance_to(enemy.global_position))

	if combat != null:
		# A raised guard with one of them in front of it.
		if combat.blocking and nearest < 3.2:
			read[&"turtle"] = minf(float(read[&"turtle"]) + step * 0.9, 1.0)

		# Blows on each other's heels.
		var serial: int = int(combat.threat_serial()) if combat.has_method("threat_serial") else -1

		if serial != _last_serial and serial >= 0:
			if now - _last_threat_at < 1.3:
				read[&"spam"] = minf(float(read[&"spam"]) + 0.28, 1.0)

			_last_threat_at = now
			_last_serial = serial

		# A bow in your hands, drawn.
		if int(combat.phase) == combat.Phase.DRAWING:
			read[&"bow"] = minf(float(read[&"bow"]) + step * 1.2, 1.0)

	# Keeping away from them: out of reach of all of them, and going.
	var velocity: Vector3 = enemy.get("velocity") if enemy.get("velocity") != null else Vector3.ZERO

	if nearest > 4.5 and Vector2(velocity.x, velocity.z).length() > 1.5:
		read[&"kite"] = minf(float(read[&"kite"]) + step * 0.8, 1.0)

	# Your blood gives them heart.
	var health: float = float(enemy.get("health")) if enemy.get("health") != null else 100.0

	if _last_health >= 0.0 and health < _last_health:
		morale = minf(morale + 0.05, 1.0)

	_last_health = health

	# Numbers give it back slowly.
	if alive.size() >= 2:
		morale = minf(morale + step * 0.02, 1.0)


## The best of them leads: a captain who comes into the fight takes it over.
func _choose_leader(alive: Array) -> void:
	var lead := leader()
	var best: Node3D = lead if lead != null and lead in alive else null
	var rank: int = RANK.get(_kind(best), 1) if best != null else -1

	for member in alive:
		var r: int = RANK.get(_kind(member), 1)

		if r > rank:
			rank = r
			best = member

	_leader = weakref(best) if best != null else null


func _choose_tactic(alive: Array, now: float) -> void:
	var enemy := target()
	var health := 1.0

	if enemy != null and enemy.get("health") != null and enemy.get("max_health") != null:
		health = float(enemy.health) / maxf(float(enemy.max_health), 1.0)

	var want: StringName = &"envelop"

	if now - _leader_fell_at < 10.0 and morale < 0.45 and alive.size() <= 3:
		want = &"rout"
	elif now < _fall_back_until:
		want = &"fall_back"
	elif largest >= 3 and alive.size() <= largest / 2 and tactic != &"fall_back" and tactic != &"rout":
		want = &"fall_back"
		_fall_back_until = now + 6.0
	elif health < 0.35:
		want = &"press"
	elif float(read[&"turtle"]) > 0.55:
		want = &"break"
	elif float(read[&"kite"]) > 0.5 or float(read[&"bow"]) > 0.5:
		want = &"rush"

	# A rout ends when their heart comes back (help has come, or you left).
	if tactic == &"rout" and morale >= 0.6:
		want = &"envelop"

	if want == tactic or (now - _tactic_since < KEEP and want != &"rout" and want != &"fall_back"):
		return

	tactic = want
	_tactic_since = now

	# The leader calls it (or whoever is left).
	var caller := leader()

	if caller == null and not alive.is_empty():
		caller = alive[0]

	# A call for help always goes out, and carries.
	var for_help := tactic == &"fall_back" or tactic == &"rout"

	if caller != null and alive.size() >= 2 and (now - _last_call > 2.5 or for_help) and caller.has_method("bark"):
		var lines: Array = CALLS.get(tactic, [])

		if not lines.is_empty():
			caller.bark(lines[randi() % lines.size()])
			_last_call = now

	if caller != null and for_help and caller.has_method("shout"):
		caller.shout()


func _give_places(alive: Array, now: float) -> void:
	var enemy := target()

	if enemy == null:
		return

	var melee := []
	var archers := []

	for member in alive:
		var fighter = member.get("_fighter")

		if fighter == null or fighter.stays_put:
			continue

		if fighter.ranged:
			archers.append(member)
		else:
			melee.append(member)

	melee.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.global_position.distance_to(enemy.global_position) < b.global_position.distance_to(enemy.global_position))
	_roles.clear()
	_slots.clear()

	for archer in archers:
		_roles[archer.get_instance_id()] = &"flee" if tactic == &"rout" else &"support"

	# His captain cut down in front of him: the brute is past caring.
	if now < _berserk_until:
		for man in melee.duplicate():
			if _kind(man) == &"brute":
				_roles[man.get_instance_id()] = &"berserk"
				melee.erase(man)

	match tactic:
		&"rout":
			for man in melee:
				_roles[man.get_instance_id()] = &"flee"

			return
		&"fall_back":
			for man in melee:
				_roles[man.get_instance_id()] = &"rally"

			return

	if melee.is_empty():
		return

	# Who holds you in front: under `break` the brute, else the nearest (the
	# leader, if he is as near as any, likes to be the one).
	var front: Node3D = melee[0]

	if tactic == &"break":
		for man in melee:
			if _kind(man) == &"brute":
				front = man

	var lead := leader()
	var breaking := tactic == &"break" and _kind(front) == &"brute"

	if not breaking and lead != null and lead in melee and lead.global_position.distance_to(enemy.global_position) < front.global_position.distance_to(enemy.global_position) + 0.8:
		front = lead

	# Sent back once worn down: he stays back while another can hold you.
	var worn: Node3D = _swapped_out.get_ref() as Node3D if _swapped_out != null else null

	if worn != null and worn == front and melee.size() >= 2:
		for man in melee:
			if man != worn:
				front = man
				break

	# Worn down in front: he steps back, and a fresher man takes his place.
	if not breaking and now - _last_swap > 5.0 and melee.size() >= 2 and _health_of(front) < 0.3:
		for man in melee:
			if man != front and _health_of(man) > 0.6:
				_swapped_out = weakref(front)
				front = man
				_last_swap = now

				break

	_roles[front.get_instance_id()] = &"breaker" if tactic == &"break" and _kind(front) == &"brute" else &"engage"

	# An archer you are going for: someone steps between.
	var guarded := false

	for archer in archers:
		if guarded or archer.global_position.distance_to(enemy.global_position) > 6.0:
			continue

		for man in melee:
			if man != front and not _roles.has(man.get_instance_id()):
				_roles[man.get_instance_id()] = &"bodyguard"
				_slots[man.get_instance_id()] = 0.0
				guarded = true
				break

	# Round you: two at your sides, the rest wait at the ring behind.
	var flank_angles := [100.0, -100.0, 170.0]
	var flanks := 0
	var waiting := 0

	for man in melee:
		var id: int = man.get_instance_id()

		if _roles.has(id):
			continue

		if flanks < (3 if tactic == &"press" else 2):
			_roles[id] = &"flank"
			_slots[id] = flank_angles[flanks]
			flanks += 1
		else:
			_roles[id] = &"reserve"
			_slots[id] = [150.0, -150.0, 45.0, -45.0][waiting % 4]
			waiting += 1


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _kind(guard: Node) -> StringName:
	var archetype: Variant = guard.get("archetype")
	return archetype if archetype is StringName else StringName(str(archetype)) if archetype != null else &""


static func _health_of(guard: Node) -> float:
	var most: float = float(guard.get("max_health")) if guard.get("max_health") != null else 100.0
	return float(guard.get("health")) / maxf(most, 1.0) if guard.get("health") != null else 1.0


