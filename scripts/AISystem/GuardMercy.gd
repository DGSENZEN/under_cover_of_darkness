extends RefCounted
## A man at your mercy (GuardFighter.fight, for a man the squad has broken:
## Squad.will_of, and placed to flee or fetch help):
##   plead    caught (you within PLEAD_NEAR, he sees you, and you are coming
##            at him or swinging at him, or he is too hurt to run: _caught),
##            and nobody near him begging you already (one at a time: the
##            rest run while they can),
##            he throws his blade down at your feet and begs for his life,
##            never taking his eyes off you: on his knees if he is terrified
##            enough (terror: little nerve, badly hurt), else on his feet with
##            a hand held out to you. He neither guards nor strikes. Not
##            caught (you stand off), he runs while he can. A proud man
##            (PROUD_NERVE and more) does not beg, nor does one who has seen
##            you cut down men who did (Garrison.mercy_hope).
##   spared   walk away from him (past LET_GO, or out of his sight, for
##            SPARED_AFTER) and he is up and running: to the nearest place he
##            would be safe (haven), men of his own well away from you, the
##            more of them the better. There he keeps them between you and
##            him and tells them where you are; a man not already after you
##            comes (Squad.rouse). With nobody to run to, he just runs.
##   struck   hit him while he begs, and he gives up on your mercy: up and
##            running, and he will not beg you again.
##   heart    his heart back while he begs (friends at hand, help coming: the
##            squad no longer has him broken), he gets up to fight on, and
##            goes back for his blade (GuardFighter._fetch_something).
## What you did is remembered (Garrison.on_spared, on_slain_begging): the
## garrison talks of it, and it decides whether the next man begs at all.

const GarrisonScript := preload("res://scripts/AISystem/Garrison.gd")

## Guard.Alert.
const COMBAT := 4
## Caught: you this near, and seen, and coming on at least this fast (m/s)
## or swinging at him; or he below this much of his health, too hurt to run.
const PLEAD_NEAR := 3.2
const CLOSING := 1.0
const TOO_HURT := 0.35
## On his heels this near, you need not be seen: he hears you, and turns.
const HEARD_NEAR := 2.0
## One man begs you at a time: another begging within this (m), he runs
## while he can.
const ONE_AT_A_TIME := 8.0
## A man with this much nerve does not beg.
const PROUD_NERVE := 0.65
## On his knees at this much terror or more.
const KNEEL_TERROR := 0.55
## Let go: you past this far, or out of his sight, this long (s).
const LET_GO := 6.0
const SPARED_AFTER := 1.2
## Down on his knees, and up off them (s); scrambling up when struck.
const KNEEL_TIME := 0.55
const RISE_TIME := 0.6
const SCRAMBLE_TIME := 0.3
## A plea this often while he begs (s).
const LINE_EVERY := Vector2(2.2, 4.0)
## A haven: men of his own at least this far from you, within this far of him,
## and not the other side of you. Looked for again this often (s).
const SAFE_FROM_YOU := 9.0
const HAVEN_RANGE := 60.0
const HAVEN_CHECK := 1.0
## At a haven: within this of the man, keeping this far behind him from you.
const HAVEN_NEAR := 2.5
const SHELTER := 1.4
## Getting no nearer a haven this long, he gives it up for this long (s).
const HAVEN_STALL := 2.5
const HAVEN_SHUN := 20.0
## Let go, he does not go back to his knees for this long (s), whatever you do.
const RUNNING_FOR := 3.0

var guard: CharacterBody3D
var pleading := false
var kneeling := false
## Hit while he begged (or he knows better than to): he will not beg you
## again this fight.
var refused := false
## Seconds into his plea; getting up (seconds left, of how long); you gone
## from him this long.
var _since := 0.0
var _getting_up := 0.0
var _rise_length := 0.0
var _rise_from_knees := false
var _away := 0.0
var _line_timer := 0.0
## Let go: no begging again before then (his clock).
var _running_until := -10.0
## Whether he has made up his mind, this fight, that begging is any use.
var _hope_judged := false
## Where he is running to, and when he last looked; with them yet, and the
## men he gave up on (instance id -> until when).
var _haven: WeakRef = null
var _haven_at := -10.0
var _sheltered := false
var _shelter_at := Vector3.ZERO
var _haven_best := INF
var _haven_stalled := 0.0
var _shunned := {}
var _cry_timer := 0.0
## This man's own lean towards his knees, the same every time.
var _quirk := 0.0


func _init(p_guard: CharacterBody3D) -> void:
	guard = p_guard
	_quirk = (float(posmod(hash(p_guard.get_instance_id()), 97)) / 96.0 - 0.5) * 0.24


## Every frame he fights and is not mid-blow (GuardFighter.fight). `broken`:
## the squad has him broken and running. True while this has him (begging,
## or getting up off his knees): his footwork, guard and blows wait.
func update(delta: float, target: Node3D, sees: bool, broken: bool) -> bool:
	# Where you are, seen or not: a man begging you knows.
	var toward := Vector3.ZERO
	var near := INF

	if target != null and is_instance_valid(target):
		toward = target.global_position - guard.global_position
		toward.y = 0.0
		near = toward.length()

	if _getting_up > 0.0:
		_getting_up -= delta
		guard._stop(delta)

		if near < INF:
			guard._face(toward, delta)

		return true

	if not pleading:
		# One at a time: with another begging you beside him, he runs while
		# he can (unless too hurt to).
		if broken and guard._game_time >= _running_until and _caught(target, sees, near) and would_beg() and (_too_hurt() or not _another_begging()):
			_begin(toward)
			guard._stop(delta)
			return true

		return false

	# His heart back (friends about him, help coming): up, to fight on.
	if not broken:
		_end(&"emboldened")
		return true

	_since += delta
	# You walk off, or slip out of his sight: he takes his chance.
	_away = _away + delta if (near > LET_GO or (not sees and near > PLEAD_NEAR)) else 0.0

	if _away >= SPARED_AFTER:
		_end(&"spared")
		return true

	guard._stop(delta)

	if near < INF:
		guard._face(toward, delta)

	_line_timer -= delta

	if _line_timer <= 0.0:
		_line_timer = randf_range(LINE_EVERY.x, LINE_EVERY.y)
		guard.say(&"plead")

	return true


## Whether there is no running from you: you near (and seen, or right on his
## heels), and coming at him (closing on him, or swinging at him), or he too
## hurt to run.
func _caught(target: Node3D, sees: bool, near: float) -> bool:
	if near > PLEAD_NEAR or (not sees and near > HEARD_NEAR) or target == null or not is_instance_valid(target):
		return false

	if _too_hurt():
		return true

	var going: Variant = target.get("velocity")
	var away := guard.global_position - target.global_position
	away.y = 0.0

	if going is Vector3 and away.length() > 0.01 and Vector3((going as Vector3).x, 0.0, (going as Vector3).z).dot(away.normalized()) > CLOSING:
		return true

	var combat: Variant = target.get("combat")
	return combat is Node and (combat as Node).has_method("threat_phase") and combat.threat_phase() != &""


## Too hurt to run.
func _too_hurt() -> bool:
	return float(guard.health) / maxf(float(guard.max_health), 1.0) < TOO_HURT


## Another of his own begging you within ONE_AT_A_TIME of him.
func _another_begging() -> bool:
	for other in guard.get_tree().get_nodes_in_group(&"guards"):
		if other == guard or not is_instance_valid(other):
			continue

		var mercy: RefCounted = other.get("_mercy")

		if mercy != null and bool(mercy.pleading) and (other as Node3D).global_position.distance_to(guard.global_position) < ONE_AT_A_TIME:
			return true

	return false


## Whether he would beg at all: not a proud man, not after he has been struck
## begging, and not if the garrison has seen you kill men who begged (he
## weighs that once a fight: Garrison.mercy_hope).
func would_beg() -> bool:
	if refused or guard._fighter == null or guard._fighter.stays_put:
		return false

	var temper: RefCounted = guard._fighter.temper

	if temper != null and float(temper.nerve) >= PROUD_NERVE:
		return false

	if not _hope_judged:
		_hope_judged = true
		var garrison: RefCounted = _garrison()

		if garrison != null and randf() >= float(garrison.mercy_hope()):
			refused = true
			return false

	return true


## How frightened he is (about 0..1): little nerve, badly hurt, his hands
## already empty; and his own lean.
func terror() -> float:
	var temper: RefCounted = guard._fighter.temper if guard._fighter != null else null
	var nerve: float = float(temper.nerve) if temper != null else 0.5
	var whole := clampf(float(guard.health) / maxf(float(guard.max_health), 1.0), 0.0, 1.0)
	var bare := 0.0 if guard._hands == null or guard._hands.armed else 0.1
	return (1.0 - nerve) * 0.6 + (1.0 - whole) * 0.6 + bare + _quirk


## Struck while he begged (by `by`: not one of his own, whose stray arrow it
## was): he gives up on your mercy.
func struck(by: Node = null) -> void:
	if pleading and not (by != null and is_instance_valid(by) and by.is_in_group(&"guards")):
		_end(&"struck")


## Out of the fight: none of it carries over to the next.
func reset() -> void:
	pleading = false
	kneeling = false
	refused = false
	_getting_up = 0.0
	_hope_judged = false
	_haven = null
	_sheltered = false
	_shunned.clear()


## Killed while he begged (Guard.take_hit): the garrison hears of it.
func died() -> void:
	if not pleading:
		return

	var garrison: RefCounted = _garrison()

	if garrison != null:
		garrison.on_slain_begging(String(guard.given_name))


## For the rig: "kneel" (going down), "plead_kneel", "plead_stand", "rise"
## (getting up, "rise_knees" off his knees), or "".
func activity() -> StringName:
	if _getting_up > 0.0:
		return &"rise_knees" if _rise_from_knees else &"rise"

	if not pleading:
		return &""

	if kneeling:
		return &"kneel" if _since < KNEEL_TIME else &"plead_kneel"

	return &"plead_stand"


## How far into going down on his knees, or getting up (0..1).
func progress() -> float:
	if _getting_up > 0.0:
		return 1.0 - _getting_up / maxf(_rise_length, 0.01)

	return clampf(_since / KNEEL_TIME, 0.0, 1.0)


func _begin(to: Vector3) -> void:
	pleading = true
	kneeling = terror() >= KNEEL_TERROR
	_since = 0.0
	_away = 0.0
	_line_timer = randf_range(LINE_EVERY.x, LINE_EVERY.y)
	var fighter: RefCounted = guard._fighter
	fighter.guarding = false
	fighter.release_token()

	# His blade thrown down, out towards you: he is not to be feared.
	var toward := to.normalized() if to.length() > 0.01 else -guard.global_basis.z

	if guard._hands != null:
		guard._hands.drop_held()
		guard._hands.lose_weapon(toward * 2.5, true)

	var said: String = fighter.temper.line(&"plead") if fighter.temper != null else ""
	guard.bark(said if said != "" else "Mercy!")


## Done begging: `why` is "spared" (you let him go), "struck" (you did not)
## or "emboldened" (his heart is back). Off his knees first.
func _end(why: StringName) -> void:
	pleading = false
	_rise_from_knees = kneeling
	_rise_length = (SCRAMBLE_TIME if why == &"struck" else RISE_TIME) if kneeling else 0.0
	_getting_up = _rise_length
	kneeling = false
	_haven = null
	_sheltered = false
	_running_until = guard._game_time + _rise_length + RUNNING_FOR
	var garrison: RefCounted = _garrison()

	match why:
		&"spared":
			guard.bark(_line(&"spared", "Thank you... thank you!"))

			if garrison != null:
				garrison.on_spared(String(guard.given_name))
		&"struck":
			refused = true
			guard.bark(_line(&"struck", "No! Please!"))
		&"emboldened":
			guard.bark(_line(&"emboldened", "Now we'll see!"))


# ---------------------------------------------------------------------------
# Running to his own
# ---------------------------------------------------------------------------

## Running from `target` to where he would be safe, and keeping behind his own
## once there (GuardFighter._flee). False if there is nowhere (he just runs).
func run_to_haven(delta: float, target: Node3D, sees: bool, to: Vector3) -> bool:
	# With his own: he stays where he reached them (they may go after you;
	# he does not), until you come near him there.
	if _sheltered:
		if target != null and is_instance_valid(target) and _shelter_at.distance_to(target.global_position) < SAFE_FROM_YOU * 0.8:
			_sheltered = false
			_haven = null
		else:
			guard._go_to(_shelter_at)

			if guard._walk(guard.patrol_speed, delta):
				guard._stop(delta)

				if sees:
					guard._face(to, delta)

			return true

	var haven := _haven_from(target)

	if haven == null:
		return false

	var at: Vector3 = haven.global_position
	var from_you: Vector3 = at - (target.global_position if target != null and is_instance_valid(target) else guard.global_position)
	from_you.y = 0.0
	var spot := at + (from_you.normalized() if from_you.length() > 0.01 else Vector3.ZERO) * SHELTER
	var gap := Vector2(at.x - guard.global_position.x, at.z - guard.global_position.z).length()

	if gap > HAVEN_NEAR + SHELTER:
		guard._go_to(spot)

		if guard._walk(guard.chase_speed * 1.1, delta):
			guard._stop(delta)

		# Getting no nearer (no way there, or stuck): he gives them up.
		if gap < _haven_best - 0.3:
			_haven_best = gap
			_haven_stalled = 0.0
		else:
			_haven_stalled += delta

		if _haven_stalled > HAVEN_STALL:
			_shunned[haven.get_instance_id()] = guard._game_time + HAVEN_SHUN
			_haven = null

		_cry_timer -= delta

		if _cry_timer <= 0.0 and guard._bark_timer <= 0.0:
			_cry_timer = randf_range(2.5, 4.0)
			guard.bark(_line(&"fetch", "Help! Help!"))

		return true

	# With them: behind them from you, and word of you.
	_sheltered = true
	_shelter_at = spot
	_tell(haven, target)
	guard._stop(delta)
	return true


## Whether he has reached his own and is keeping behind them.
func sheltered() -> bool:
	return _sheltered


## The man he is running to (for tests and the gym's labels).
func haven() -> Node3D:
	return _haven.get_ref() as Node3D if _haven != null else null


## At his haven: he says where you are, and a man there not already after you
## is roused to it.
func _tell(haven: Node3D, target: Node3D) -> void:
	guard.bark(_line(&"safe", "He's after me! There!"))
	var squad: RefCounted = guard._fighter.squad if guard._fighter != null else null

	if squad == null or target == null or not is_instance_valid(target):
		return

	if not (haven in squad.members()):
		squad.rouse(haven, guard)


## The haven he is running to, kept while it is still safe, looked for again
## every HAVEN_CHECK.
func _haven_from(target: Node3D) -> Node3D:
	var now: float = guard._game_time
	var kept: Node3D = _haven.get_ref() as Node3D if _haven != null else null

	if kept != null and (not is_instance_valid(kept) or not _safe_with(kept, target)):
		kept = null
		_haven = null

	if kept != null and now < _haven_at + HAVEN_CHECK:
		return kept

	_haven_at = now
	var found := find_haven(guard, target, _shunned, now)

	if found != kept:
		_haven_best = INF
		_haven_stalled = 0.0

	_haven = weakref(found) if found != null else null
	return found


## Whether `man` is still somewhere safe from `target`.
func _safe_with(man: Node3D, target: Node3D) -> bool:
	if not steady(man, guard):
		return false

	if target == null or not is_instance_valid(target):
		return true

	return man.global_position.distance_to(target.global_position) >= SAFE_FROM_YOU * 0.8


## The nearest man of `guard`'s own he would be safe with from `enemy`: awake,
## not broken or begging himself, well away from you and not on the far side
## of you; the more friends about him the better. null if there is nobody
## within HAVEN_RANGE. `shunned`: men given up on, until when (by id).
static func find_haven(guard: Node3D, enemy: Node3D, shunned := {}, now := 0.0) -> Node3D:
	var me := guard.global_position
	var you: Vector3 = enemy.global_position if enemy != null and is_instance_valid(enemy) else Vector3.INF
	var men: Array = guard.get_tree().get_nodes_in_group(&"guards")
	var best: Node3D = null
	var best_score := INF

	for other in men:
		if not steady(other, guard) or float(shunned.get(other.get_instance_id(), -1.0)) > now:
			continue

		var at: Vector3 = (other as Node3D).global_position
		var d := me.distance_to(at)

		if d > HAVEN_RANGE:
			continue

		if you != Vector3.INF:
			if at.distance_to(you) < SAFE_FROM_YOU:
				continue

			# Not past you to get to them.
			if d > 3.0 and Geometry3D.get_closest_point_to_segment(you, me, at).distance_to(you) < 2.5:
				continue

		var company := 0

		for third in men:
			if third != other and third != guard and steady(third, guard) and (third as Node3D).global_position.distance_to(at) < 6.0:
				company += 1

		var score := d - 4.0 * float(mini(company, 3))

		if score < best_score:
			best_score = score
			best = other

	return best


## One of his own a man could be safe with: up, awake, and neither begging
## nor broken himself.
static func steady(other: Object, guard: Object) -> bool:
	if other == guard or not is_instance_valid(other) or not (other is Node3D) or (other as Node).is_queued_for_deletion():
		return false

	if other.get("_knocked_out") == true or (other.has_method("is_downed") and other.is_downed()):
		return false

	var mercy: Variant = other.get("_mercy")

	if mercy != null and bool(mercy.pleading):
		return false

	var fighter: Variant = other.get("_fighter")
	var squad: Variant = fighter.squad if fighter != null else null
	return not (squad != null and int(other.get("state")) == COMBAT and squad.will_of(other) == &"broken")


func _line(situation: StringName, fallback: String) -> String:
	var temper: RefCounted = guard._fighter.temper if guard._fighter != null else null
	var said: String = temper.line(situation) if temper != null else ""
	return said if said != "" else fallback


func _garrison() -> RefCounted:
	var target: Node3D = guard.get("_target") as Node3D

	if target == null or not is_instance_valid(target):
		target = guard.get_tree().get_first_node_in_group(&"player") as Node3D

	return GarrisonScript.of(target) if target != null else null
