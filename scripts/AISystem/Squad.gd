extends RefCounted
## Everyone after one enemy together, the way Halo's squads do it: one of
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
##              up, calling for help; then at you again. A rash man keeps
##              pressing regardless.
##   rout       most of them have broken: the call goes up to run for help,
##              and whoever has not broken holds you off while they go.
## A place (`role_of`): engage, flank, reserve, support (an archer), bodyguard
## (between you and an archer you are going for), breaker (the brute, to break
## a turtle), rally, berserk (the brute, his captain cut down), hold (at the
## edge of your reach, guard up, calling for help: a man alone who will not
## face you, or the rearguard), flee (broken), desperate (a rash man broken:
## all in).
##
## Each man's resolve (`resolve_of`) is their heart as he feels it: less the
## fear the garrison's dread puts in a man short of nerve, less his wounds,
## more for friends fighting beside him and a captain over him. Below his
## break point (lower the more nerve he has) he breaks, one man at a time, the
## craven first; he is whole again only well above it. A stubborn man never
## breaks; a rash one breaks into an all-in charge.
##
## A squad is a hunt, not a moment of one. A man is in it from when he first
## takes you on (or is fetched to it) until he dies or gives up the search
## and goes back to his rounds: searching for you, running for help, off his
## feet, he is still one of them, and what they have learned of you and how
## their heart stands carry on through every lull. Only when the last of them
## is gone is it over; the next hunt starts from what the whole garrison knows
## of you (Garrison.gd). `members` is everyone in the hunt, `fighting` the men
## at you now: the plan and the places are theirs.
##
## One is made for each target (`Squad.of`). Its men call `think` every frame,
## whatever they are doing; the plan is made again a few times a second, on
## the squad's own clock (the men's clocks each start when the man does).

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
	&"rout": ["Run! Get help!", "Get out! Get help!"],
}
## Resolve: he breaks under BREAK_BASE - BREAK_PER_NERVE * nerve, wavers
## within WAVER_MARGIN above that, and is whole again only past
## RECOVER_MARGIN above it. A man of UNBREAKABLE_NERVE never breaks; one of
## DESPERATE_DRIVE breaks into an all-in charge, not away.
const BREAK_BASE := 0.55
const BREAK_PER_NERVE := 0.5
const WAVER_MARGIN := 0.2
const RECOVER_MARGIN := 0.25
const UNBREAKABLE_NERVE := 0.8
const DESPERATE_DRIVE := 0.75
## What weighs on it and what holds it up.
const FEAR_WEIGHT := 0.8
const WOUND_WEIGHT := 0.35
const FRIEND_BONUS := 0.08
const FRIEND_RANGE := 8.0
const LEADER_BONUS := 0.12
const LEADER_RANGE := 12.0
## Fear past this, and he will not face you alone.
const TIMID_FEAR := 0.3
## Drive enough to keep pressing when the plan says fall back (more under a
## captain's eye).
const PRESS_THROUGH := 0.75
## Help: how far (along the navmesh) a runner will go to fetch a man, how
## long his coming heartens them, and by how much.
const HELPER_RANGE := 60.0
const HELP_TIME := 25.0
const HELP_BONUS := 0.2
## The hunt: how near a hunter must be to come when one of them finds you
## again, how far apart they search, and how far ahead a sly man goes to cut
## you off.
const CALL_RANGE := 35.0
const SEARCH_SPREAD := 4.0
const CUT_OFF := 10.0
## A flanker with this much drive (and less guile than PATIENT_GUILE) will not
## wait for you to commit to another: he goes in once his patience is gone.
const IMPATIENT_DRIVE := 0.65
const PATIENT_GUILE := 0.65

const GarrisonScript := preload("res://scripts/AISystem/Garrison.gd")

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
## Someone has been in it: once the last is gone, it is over.
var _had_members := false
## Who has fought in it, and when the first did: a man who comes in later is
## help arriving.
var _ever_fought := {}
var _began_at := -1.0
## When one of them was last cut or killed, and what each has left: a lull
## without it lets them catch their breath.
var _last_harm_at := 0.0
var _health_seen := {}
## Each man's resolve, and whether he has broken (by instance id).
var _resolve := {}
var _broken := {}
## Where, when and going which way any of them last saw you.
var last_sighting := {"position": Vector3.ZERO, "time": -100.0, "velocity": Vector3.ZERO}
## Runners (by instance id) and the man each is fetching; who each would
## fetch, as last looked for; until when help is on its way; whether the
## captain has sent a man for help in this falling back.
var _fetching := {}
var _helper_cache := {}
var _help_until := -100.0
var _sent_for_help := false
## Where each hunter is searching (by instance id), so no two search the same
## ground.
var _claims := {}
## Runners who have fetched their man (one errand each), and the men each
## runner could not get to.
var _fetched_once := {}
var _given_up_on := {}
## How many of them are down (killed or knocked senseless), and how many were
## down when they last fell back: they fall back when half are down, not
## when half are elsewhere.
var _lost := 0
var _fell_back_at_lost := 0


## The hunt for `target`: the one under way, or a new one when the last is
## over. A new hunt comes knowing what the garrison knows of you, and with
## the heart your deeds have left them.
static func of(target: Node3D) -> RefCounted:
	if target == null or not is_instance_valid(target):
		return null

	var key := target.get_instance_id()
	var squad: RefCounted = _squads.get(key)

	if squad == null or squad.is_dissolved():
		_prune()
		squad = (load("res://scripts/AISystem/Squad.gd") as GDScript).new()
		squad.target_ref = weakref(target)
		var garrison: RefCounted = GarrisonScript.of(target)
		squad.morale = garrison.opening_heart()
		squad.read = (garrison.habits as Dictionary).duplicate()
		_squads[key] = squad

	return squad


## Whoever they were after is gone (a level reloaded): let the hunt go.
static func _prune() -> void:
	for key in _squads.keys():
		var w: WeakRef = _squads[key].target_ref

		if w == null or w.get_ref() == null:
			_squads.erase(key)


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

	_members.append(weakref(guard))
	_had_members = true


## Out of this hunt for good (gone after another, or freed).
func leave(guard: Node3D) -> void:
	_members = _members.filter(func(w: WeakRef) -> bool: return w.get_ref() != null and w.get_ref() != guard)
	_roles.erase(guard.get_instance_id())
	_slots.erase(guard.get_instance_id())
	# Gone before he got there: nobody is fetching that man now.
	_fetching.erase(guard.get_instance_id())
	_claims.erase(guard.get_instance_id())
	# And nothing of his own kept: back in the hunt, he is judged afresh and
	# his coming back is help arriving.
	var id := guard.get_instance_id()

	for kept in [_resolve, _broken, _ever_fought, _health_seen, _helper_cache, _fetched_once, _given_up_on]:
		(kept as Dictionary).erase(id)


## He gave up the search and went back to his rounds: out of the hunt. The
## last one out ends it.
func stand_down(guard: Node3D) -> void:
	leave(guard)

	if members().is_empty():
		_dissolve()


## One of them fell (`killed`, or knocked senseless): it shakes the rest, and
## the leader's fall most of all. A killing the whole garrison hears of.
func member_died(guard: Node3D, killed := true) -> void:
	var was_leader: bool = _leader != null and _leader.get_ref() == guard
	leave(guard)
	morale = maxf(morale - (0.45 if was_leader else 0.2), 0.0)
	_last_harm_at = clock
	_lost += 1

	if killed and target() != null:
		GarrisonScript.of(target()).on_death(was_leader)

	if was_leader:
		_leader = null
		_leader_fell_at = clock
		_berserk_until = clock + 12.0

	# The brute takes it personally.
	for member in members():
		if _kind(member) == &"brute":
			member.bark("RAAAGH!")


## Everyone in the hunt, whatever he is doing now.
func members() -> Array:
	var alive := []

	for w in _members:
		var guard = w.get_ref()

		if guard == null or not is_instance_valid(guard) or guard.is_queued_for_deletion() or guard.get("_knocked_out") == true:
			continue

		alive.append(guard)

	return alive


## Those at you now (in combat, after this target).
func fighting() -> Array:
	return members().filter(func(guard: Node3D) -> bool: return int(guard.state) == 4 and guard.get("_target") == target())


## What he is doing for the hunt: "fighting", "hunting" (looking for you),
## "running" (for help, or away), or "down" (off his feet).
func status_of(guard: Node3D) -> StringName:
	if role_of(guard) in [&"fetch", &"flee"] and int(guard.state) == 4:
		return &"running"

	if guard.has_method("is_downed") and guard.is_downed():
		return &"down"

	return &"fighting" if int(guard.state) == 4 else &"hunting"


## Everyone who was in it is gone: the hunt is over.
func is_dissolved() -> bool:
	return _had_members and members().is_empty()


func _dissolve() -> void:
	var enemy := target()

	if enemy != null and _squads.get(enemy.get_instance_id()) == self:
		_squads.erase(enemy.get_instance_id())


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
## What they know you do: what they see now, or what the garrison has long
## known of you (never forgotten, if not quite as sure).
func known(what: StringName) -> float:
	var garrison: RefCounted = GarrisonScript.of(target())
	var long_known: float = float(garrison.habits.get(what, 0.0)) if garrison != null else 0.0
	return maxf(float(read.get(what, 0.0)), 0.6 * long_known)


func bonus(what: StringName) -> float:
	match what:
		&"kick":
			return 0.4 * known(&"turtle") + (0.2 if tactic == &"break" else 0.0)
		&"feint":
			return 0.3 * known(&"turtle")
		&"parry":
			return 0.25 * known(&"spam")
		&"guard":
			return 0.25 * known(&"spam") + (0.3 if tactic == &"fall_back" else 0.0)
		&"lunge":
			return 0.35 * known(&"kite") + (0.2 if tactic == &"rush" else 0.0)
		&"backstep":
			return 0.2 * known(&"spam")

	return 0.0


## Where they rally to when they fall back: the leader, or an archer, or
## their middle.
func rally_point() -> Vector3:
	var lead := leader()

	if lead != null:
		return lead.global_position

	var sum := Vector3.ZERO
	var alive := fighting()

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
		&"engage", &"breaker", &"berserk", &"bodyguard", &"desperate":
			return true
		&"flank":
			return _committed_away_from(guard) or impatient_now(guard)
		&"hold":
			# Only when you come to him.
			var foe := target()
			return foe != null and guard.global_position.distance_to(foe.global_position) < float(guard._fighter._reach(&"overhead"))
		&"reserve", &"rally", &"flee", &"fetch":
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
	var everyone := members()

	if everyone.is_empty():
		if _had_members:
			_dissolve()

		return

	var alive := fighting()
	largest = maxi(largest, alive.size())

	# At you, not searching: his ground is free for another.
	for man in alive:
		_claims.erase(man.get_instance_id())
	_count_arrivals_and_harm(alive, everyone, step, now)
	# Nobody at you: the one who leads is whoever of them there is.
	_choose_leader(alive if not alive.is_empty() else everyone)

	if alive.is_empty():
		return

	_read_you(step, alive, now)
	_judge_wills(alive)
	_choose_tactic(alive, now)
	var before := _roles.duplicate()
	_give_places(alive, now)
	_announce(before)


## Help arriving puts heart into them; a lull with nobody cut lets them catch
## their breath.
func _count_arrivals_and_harm(alive: Array, everyone: Array, step: float, now: float) -> void:
	for man in alive:
		var id: int = man.get_instance_id()

		if _ever_fought.has(id):
			continue

		if _began_at < 0.0:
			_began_at = now
		elif now - _began_at > 3.0:
			morale = minf(morale + 0.15, 1.0)

		_ever_fought[id] = true

	for man in everyone:
		var id: int = man.get_instance_id()
		var health := float(man.get("health"))

		if health < float(_health_seen.get(id, health)):
			_last_harm_at = now

		_health_seen[id] = health

	if now - _last_harm_at > 10.0:
		morale = minf(morale + step * 0.01, 1.0)


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

	# Where they last saw you, and which way you were going.
	for member in alive:
		if member.get("can_see_target") == true:
			var going: Variant = enemy.get("velocity")
			last_sighting = {
				"position": member._feet_of(enemy) if member.has_method("_feet_of") else enemy.global_position,
				"time": now,
				"velocity": going if going is Vector3 else Vector3.ZERO,
			}
			break

	# Keeping away from them: out of reach of all of them, and going.
	var velocity: Vector3 = enemy.get("velocity") if enemy.get("velocity") != null else Vector3.ZERO

	if nearest > 4.5 and Vector2(velocity.x, velocity.z).length() > 1.5:
		read[&"kite"] = minf(float(read[&"kite"]) + step * 0.8, 1.0)

	# What they have seen, the garrison learns.
	GarrisonScript.of(enemy).learn(read, step)

	# Your blood gives them heart.
	var health: float = float(enemy.get("health")) if enemy.get("health") != null else 100.0

	if _last_health >= 0.0 and health < _last_health:
		morale = minf(morale + 0.05, 1.0)

	_last_health = health

	# Numbers give it back slowly.
	if alive.size() >= 2:
		morale = minf(morale + step * 0.02, 1.0)


## The best of them leads: a captain who comes into the fight takes it over.
func _choose_leader(pool: Array) -> void:
	var lead := leader()
	var best: Node3D = lead if lead != null and lead in pool else null
	var rank: int = RANK.get(_kind(best), 1) if best != null else -1

	for member in pool:
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
	# Most of them broken (not the ones gone all in): the call to run.
	var broken := 0

	for man in alive:
		if will_of(man) == &"broken" and drive_of(man) < DESPERATE_DRIVE:
			broken += 1

	if broken > 0 and float(broken) >= maxf(1.0, alive.size() / 2.0):
		want = &"rout"
	elif now < _fall_back_until:
		want = &"fall_back"
	elif largest >= 3 and _lost * 2 >= largest and _lost > _fell_back_at_lost and tactic != &"rout":
		# Half of them down (not merely away searching): together again, once
		# for each such blow.
		want = &"fall_back"
		_fall_back_until = now + 6.0
		_fell_back_at_lost = _lost
	elif health < 0.35:
		want = &"press"
	elif float(read[&"turtle"]) > 0.55:
		want = &"break"
	elif float(read[&"kite"]) > 0.5 or float(read[&"bow"]) > 0.5:
		want = &"rush"

	if want == tactic or (now - _tactic_since < KEEP and want != &"rout" and want != &"fall_back"):
		return

	tactic = want
	_tactic_since = now
	_sent_for_help = false

	# The leader calls it (or whoever is left).
	var caller := leader()

	if caller == null and not alive.is_empty():
		caller = alive[0]

	# A call for help always goes out, and carries.
	var for_help := tactic == &"fall_back" or tactic == &"rout"

	if caller != null and alive.size() >= 2 and (now - _last_call > 2.5 or for_help) and caller.has_method("bark"):
		var lines: Array = CALLS.get(tactic, [])

		# Their captain just cut down: that is what they shout.
		if tactic == &"rout" and now - _leader_fell_at < 10.0:
			lines = ["The captain's down! Run!"]

		if not lines.is_empty():
			caller.bark(lines[randi() % lines.size()])
			_last_call = now

	if caller != null and for_help and caller.has_method("shout"):
		caller.shout()


## Places, in order: archers; the brute in his rage; the broken (away, or all
## in); under a rout the rest hold; falling back they rally (a rash man
## presses on); a man alone who will not face you holds; then the front, a
## man for an archer you are going for, the flanks (the slyest behind you),
## and the rest in reserve.
func _give_places(alive: Array, now: float) -> void:
	var enemy := target()

	if enemy == null:
		return

	var garrison: RefCounted = GarrisonScript.of(enemy)
	var melee := []
	var archers := []
	# Fighting you still (not broken, or broken into an all-in charge).
	var standing := 0

	for member in alive:
		var fighter = member.get("_fighter")

		if fighter == null or fighter.stays_put:
			continue

		if fighter.ranged:
			archers.append(member)
		else:
			melee.append(member)

		if will_of(member) != &"broken" or drive_of(member) >= DESPERATE_DRIVE:
			standing += 1

	melee.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.global_position.distance_to(enemy.global_position) < b.global_position.distance_to(enemy.global_position))
	_roles.clear()
	_slots.clear()

	# Already on his way for help: he keeps going until he has fetched him.
	for man in melee.duplicate() + archers.duplicate():
		if helper_of(man) != null:
			_roles[man.get_instance_id()] = &"fetch"
			melee.erase(man)
			archers.erase(man)
		else:
			_fetching.erase(man.get_instance_id())

	for archer in archers:
		_roles[archer.get_instance_id()] = _broken_place(archer) if will_of(archer) == &"broken" else &"support"

	# His captain cut down in front of him: the brute is past caring.
	if now < _berserk_until:
		for man in melee.duplicate():
			if _kind(man) == &"brute":
				_roles[man.get_instance_id()] = &"berserk"
				melee.erase(man)

	# The broken: away, or all in.
	for man in melee.duplicate():
		if will_of(man) == &"broken":
			_roles[man.get_instance_id()] = _broken_place(man)
			melee.erase(man)

	match tactic:
		&"rout":
			# Whoever has not broken holds you off while the others go.
			for man in melee:
				_roles[man.get_instance_id()] = &"hold"

			return
		&"fall_back":
			var rallying := []

			for man in melee:
				var needed := PRESS_THROUGH + (0.1 if held(man) else 0.0)
				_roles[man.get_instance_id()] = &"engage" if drive_of(man) >= needed else &"rally"

				if _roles[man.get_instance_id()] == &"rally":
					rallying.append(man)

			# The captain sends the man with the least heart for it to fetch
			# help, if there is anyone to fetch and nobody has gone yet.
			if _fetching.is_empty():
				var lead_now := leader()
				var sent: Node3D = null

				for man in rallying:
					if man != lead_now and (sent == null or resolve_of(man) < resolve_of(sent)):
						sent = man

				if sent != null and _assign_fetch(sent):
					_roles[sent.get_instance_id()] = &"fetch"

					if not _sent_for_help:
						_sent_for_help = true
						var caller: Node3D = lead_now if lead_now != null else sent

						if caller.has_method("bark"):
							caller.bark("Get help! Go!")

			return

	if melee.is_empty():
		return

	# The only one left facing you: a man short of nerve under the garrison's
	# dread, or one near breaking, will not take you on alone.
	if standing == 1 and melee.size() == 1:
		var alone: Node3D = melee[0]

		var timid: bool = garrison != null and garrison.fear_of(_nerve(alone)) >= TIMID_FEAR

		# A timid man runs for help if there is anyone to fetch.
		if timid and _assign_fetch(alone):
			_roles[alone.get_instance_id()] = &"fetch"
			return

		if timid or will_of(alone) == &"wavering":
			_roles[alone.get_instance_id()] = &"hold"
			return

	var lead := leader()
	var worn: Node3D = _swapped_out.get_ref() as Node3D if _swapped_out != null else null
	var front: Node3D = null
	var breaking := false

	# Under `break` the brute holds you: the blow no guard stops.
	if tactic == &"break":
		for man in melee:
			if _kind(man) == &"brute":
				front = man
				breaking = true

	# Otherwise the nearest, the rashest the readiest, the leader keen to be
	# the one; not a man worn down or near breaking while there are others.
	if front == null:
		var best := INF

		for man in melee:
			var score: float = man.global_position.distance_to(enemy.global_position) + 1.5 * (0.5 - drive_of(man))

			if man == lead:
				score -= 0.8

			if _health_of(man) < 0.3:
				score += 3.0

			if man == worn and melee.size() >= 2:
				score += 5.0

			if will_of(man) == &"wavering":
				score += 2.0

			if score < best:
				best = score
				front = man

	# Worn down in front: he steps back, and a fresher man takes his place.
	if not breaking and now - _last_swap > 5.0 and melee.size() >= 2 and _health_of(front) < 0.3:
		for man in melee:
			if man != front and _health_of(man) > 0.6:
				_swapped_out = weakref(front)
				front = man
				_last_swap = now

				break

	_roles[front.get_instance_id()] = &"breaker" if breaking else &"engage"

	# An archer you are going for: the man with the most nerve steps between.
	for archer in archers:
		if _roles.get(archer.get_instance_id()) != &"support" or archer.global_position.distance_to(enemy.global_position) > 6.0:
			continue

		var guard_man: Node3D = null

		for man in melee:
			if not _roles.has(man.get_instance_id()) and (guard_man == null or _nerve(man) > _nerve(guard_man)):
				guard_man = man

		if guard_man != null:
			_roles[guard_man.get_instance_id()] = &"bodyguard"
			_slots[guard_man.get_instance_id()] = 0.0

		break

	# Round you: the slyest first (behind you, if he is sly enough), then the
	# others at your sides; the rest, and the wavering, wait at the ring.
	var free := melee.filter(func(man: Node3D) -> bool: return not _roles.has(man.get_instance_id()))
	free.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		var a_wavers := will_of(a) == &"wavering"
		var b_wavers := will_of(b) == &"wavering"

		if a_wavers != b_wavers:
			return b_wavers

		if not is_equal_approx(_guile(a), _guile(b)):
			return _guile(a) > _guile(b)

		# Alike: the same order every think, so nobody swaps sides.
		return a.get_instance_id() < b.get_instance_id())
	var flank_angles := [100.0, -100.0, 170.0]

	if not free.is_empty() and _guile(free[0]) >= 0.65:
		flank_angles = [170.0, 100.0, -100.0]

	var flanks := 0
	var waiting := 0

	for man in free:
		var id: int = man.get_instance_id()

		if flanks < (3 if tactic == &"press" else 2) and will_of(man) != &"wavering":
			_roles[id] = &"flank"
			_slots[id] = flank_angles[flanks]
			flanks += 1
		else:
			_roles[id] = &"reserve"
			_slots[id] = [150.0, -150.0, 45.0, -45.0][waiting % 4]
			waiting += 1


# ---------------------------------------------------------------------------
# Resolve: who holds and who breaks
# ---------------------------------------------------------------------------

## His will to fight on, as it was last judged.
func resolve_of(guard: Node3D) -> float:
	return float(_resolve.get(guard.get_instance_id(), 1.0))


## "firm", "wavering" (close to breaking) or "broken".
func will_of(guard: Node3D) -> StringName:
	if bool(_broken.get(guard.get_instance_id(), false)):
		return &"broken"

	return &"wavering" if resolve_of(guard) < _break_point(guard) + WAVER_MARGIN else &"firm"


## Their captain has him in hand: alive, fighting, near, and over him.
func held(guard: Node3D) -> bool:
	var lead := leader()

	if lead == null or lead == guard or not is_instance_valid(lead) or not (lead in fighting()):
		return false

	if lead.global_position.distance_to(guard.global_position) > LEADER_RANGE:
		return false

	return int(RANK.get(_kind(lead), 1)) > int(RANK.get(_kind(guard), 1))


## How hard he presses now (GuardFighter.drive_now: his drive and his anger).
func drive_of(guard: Node3D) -> float:
	var fighter = guard.get("_fighter")
	return float(fighter.drive_now()) if fighter != null and fighter.has_method("drive_now") else 0.5


## Every man's resolve, judged from how things stood (who had broken), then
## all set at once: nobody's breaking this moment decides another's.
func _judge_wills(alive: Array) -> void:
	var garrison: RefCounted = GarrisonScript.of(target())
	var was_broken := _broken.duplicate()
	var judged := {}

	for man in alive:
		var fighter = man.get("_fighter")

		if fighter == null or fighter.stays_put:
			continue

		var resolve := morale
		resolve -= FEAR_WEIGHT * (garrison.fear_of(_nerve(man)) if garrison != null else 0.0)
		resolve -= WOUND_WEIGHT * (1.0 - clampf(_health_of(man), 0.0, 1.0))
		var friends := 0

		for other in alive:
			if other != man and not bool(was_broken.get(other.get_instance_id(), false)) and other.global_position.distance_to(man.global_position) <= FRIEND_RANGE:
				friends += 1

		resolve += FRIEND_BONUS * mini(friends, 3)

		if held(man):
			resolve += LEADER_BONUS

		if help_coming():
			resolve += HELP_BONUS

		judged[man] = resolve

	for man in judged:
		var id: int = man.get_instance_id()
		var resolve: float = judged[man]
		var point := _break_point(man)
		var broken := bool(was_broken.get(id, false))

		if _nerve(man) >= UNBREAKABLE_NERVE:
			broken = false
		elif broken:
			broken = resolve <= point + RECOVER_MARGIN
		else:
			broken = resolve < point

		_resolve[id] = resolve
		_broken[id] = broken


func _break_point(guard: Node3D) -> float:
	return BREAK_BASE - BREAK_PER_NERVE * _nerve(guard)


## How long a flanker waits at his place before he goes in anyway, whether
## you have committed to someone else or not: a rash man not long, and less
## the rasher he is; twice as long with his captain's eye on him. INF for a
## man who waits for you to commit (a steady one, or a sly one).
func patience_of(guard: Node3D) -> float:
	var drive := drive_of(guard)

	if _guile(guard) >= PATIENT_GUILE or drive < IMPATIENT_DRIVE:
		return INF

	var wait := lerpf(4.0, 1.0, clampf((drive - IMPATIENT_DRIVE) / (1.0 - IMPATIENT_DRIVE), 0.0, 1.0))
	return wait * (2.0 if held(guard) else 1.0)


## His patience at his place has run out.
func impatient_now(guard: Node3D) -> bool:
	var fighter = guard.get("_fighter")
	return fighter != null and float(fighter._flank_waited) >= patience_of(guard)


## Where a broken man goes: a rash one all in at you; anyone else for help,
## if there is anyone to fetch, or away.
func _broken_place(guard: Node3D) -> StringName:
	if drive_of(guard) >= DESPERATE_DRIVE:
		return &"desperate"

	return &"fetch" if _assign_fetch(guard) else &"flee"


# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------

## Sends `runner` for help: true if he has (or now has) someone to fetch.
func _assign_fetch(runner: Node3D) -> bool:
	if helper_of(runner) != null:
		return true

	# One errand each: still broken after it, he runs.
	if _fetched_once.has(runner.get_instance_id()):
		return false

	var helper := helper_for(runner)

	if helper == null:
		return false

	_fetching[runner.get_instance_id()] = weakref(helper)
	return true


## The man `runner` is fetching, while he is still worth fetching.
func helper_of(runner: Node3D) -> Node3D:
	var w: WeakRef = _fetching.get(runner.get_instance_id())
	var helper: Node3D = w.get_ref() as Node3D if w != null else null
	return helper if helper != null and _can_fetch(helper, runner) else null


## Who `runner` would fetch: the nearest man along the navmesh (within
## HELPER_RANGE) who is not in the hunt, awake, not fighting, and not being
## fetched already. Looked for again every 2 s at most.
func helper_for(runner: Node3D) -> Node3D:
	var id := runner.get_instance_id()
	var cached: Array = _helper_cache.get(id, [])

	if not cached.is_empty() and clock - float(cached[1]) < 2.0:
		var kept: Node3D = (cached[0] as WeakRef).get_ref() as Node3D if cached[0] != null else null
		return kept if kept != null and _can_fetch(kept, runner) else null

	var best: Node3D = null
	var best_length := HELPER_RANGE
	var map: RID = runner.get_world_3d().navigation_map

	for other in runner.get_tree().get_nodes_in_group(&"guards"):
		if not _can_fetch(other, runner) or other.global_position.distance_to(runner.global_position) > HELPER_RANGE:
			continue

		var path := NavigationServer3D.map_get_path(map, runner.global_position, other.global_position, true)

		if path.is_empty() or path[path.size() - 1].distance_to(other.global_position) > 2.0:
			continue

		var length := 0.0

		for i in range(1, path.size()):
			length += path[i - 1].distance_to(path[i])

		if length < best_length:
			best_length = length
			best = other

	_helper_cache[id] = [weakref(best) if best != null else null, clock]
	return best


func _can_fetch(other: Node, runner: Node3D) -> bool:
	if other == runner or not is_instance_valid(other) or other.is_queued_for_deletion() or other.get("_knocked_out") == true:
		return false

	var fighter = other.get("_fighter")

	if fighter == null or fighter.stays_put or int(other.get("state")) == 4 or other in members():
		return false

	for key in _fetching:
		if key != runner.get_instance_id() and (_fetching[key] as WeakRef).get_ref() == other:
			return false

	for w in _given_up_on.get(runner.get_instance_id(), []):
		if (w as WeakRef).get_ref() == other:
			return false

	return true


## He could not get to the man he was fetching (stuck, or the man somewhere
## no path goes): no more of that one for him.
func abandon_fetch(runner: Node3D, helper: Node3D) -> void:
	var id := runner.get_instance_id()
	_fetching.erase(id)
	_helper_cache.erase(id)
	var tried: Array = _given_up_on.get(id, [])
	tried.append(weakref(helper))
	_given_up_on[id] = tried


## The runner has reached the man he was fetching: he is one of the hunt now,
## and goes to where they last saw you; the others take heart.
func rouse(helper: Node3D, runner: Node3D) -> void:
	_fetching.erase(runner.get_instance_id())
	_helper_cache.erase(runner.get_instance_id())
	_fetched_once[runner.get_instance_id()] = true

	if helper == null or not is_instance_valid(helper):
		return

	join(helper)

	if helper.get("_fighter") != null:
		helper._fighter.squad = self

	if helper.has_method("join_hunt"):
		helper.join_hunt(last_sighting["position"])

	_help_until = clock + HELP_TIME
	morale = minf(morale + 0.1, 1.0)


## A man put in a new place says so, in his own way: going round you (now
## and then), pressing on when the rest fall back, breaking, going all in.
func _announce(before: Dictionary) -> void:
	for id in _roles:
		var place: StringName = _roles[id]

		if before.get(id, &"") == place:
			continue

		var man := instance_from_id(id) as Node3D

		if man == null or not is_instance_valid(man) or not man.has_method("bark") or float(man.get("_bark_timer")) > 0.0:
			continue

		var t := _temper_of(man)

		if t == null:
			continue

		var situation: StringName = &""

		match place:
			&"flank":
				situation = &"flank" if randf() < 0.5 else &""
			&"desperate":
				situation = &"desperate"
			&"flee", &"fetch":
				situation = &"break" if will_of(man) == &"broken" else &""
			&"engage":
				situation = &"press" if tactic == &"fall_back" else &""

		if situation != &"":
			var said: String = t.line(situation)

			if said != "":
				man.bark(said)


## Help is on its way.
func help_coming() -> bool:
	return clock < _help_until


# ---------------------------------------------------------------------------
# The hunt
# ---------------------------------------------------------------------------

## Where `guard` searches next, as the hunt shares the ground out: his own
## piece round where he thinks you are (at least SEARCH_SPREAD from anyone
## else's), leaning the way you were going; a sly man is sent on ahead of you
## to cut you off. null: nowhere of the hunt's, search on his own.
func search_point_for(guard: Node3D) -> Variant:
	var id := guard.get_instance_id()
	_claims.erase(id)
	var seen: Vector3 = last_sighting["position"]
	var centre: Vector3 = guard.last_known_position if guard.get("has_last_known") == true else seen
	var going: Vector3 = last_sighting["velocity"]
	going.y = 0.0
	# The way you went counts only for the sighting he is searching round.
	var heading := going.normalized() if going.length() > 0.5 and _flat(centre, seen) < 3.0 else Vector3.ZERO
	var map: RID = guard.get_world_3d().navigation_map

	if heading != Vector3.ZERO and _guile(guard) >= PATIENT_GUILE:
		var ahead := seen + heading * CUT_OFF + heading.cross(Vector3.UP) * randf_range(-2.0, 2.0)
		var cut_off := NavigationServer3D.map_get_closest_point(map, ahead)

		if _flat(cut_off, ahead) <= 2.0:
			_claims[id] = cut_off
			var t := _temper_of(guard)

			if t != null and guard.get("_bark_timer") != null and float(guard._bark_timer) <= 0.0 and guard.has_method("bark"):
				guard.bark(t.line(&"hunt"))

			return cut_off

	var best: Variant = null
	var best_score := -INF
	# Knowing which way you went, he looks in the ground ahead of it first,
	# and anywhere round only if none of that is free.
	var passes: Array = [true, false] if heading != Vector3.ZERO else [false]
	var ahead_angle := atan2(heading.z, heading.x)

	for ahead_only in passes:
		for i in 10:
			var angle: float = ahead_angle + randf_range(-0.4 * PI, 0.4 * PI) if ahead_only else randf() * TAU
			var guess := centre + Vector3(cos(angle), 0.0, sin(angle)) * randf_range(2.5, 8.0)
			var point := NavigationServer3D.map_get_closest_point(map, guess)

			if _flat(point, guess) > 1.0:
				continue

			var taken := false

			for other in _claims:
				if other != id and _flat(_claims[other], point) < SEARCH_SPREAD:
					taken = true
					break

			if taken:
				continue

			var away := point - centre
			away.y = 0.0
			var score := (heading.dot(away.normalized()) if heading != Vector3.ZERO and away.length() > 0.01 else 0.0) - 0.02 * guard.global_position.distance_to(point)

			if score > best_score:
				best_score = score
				best = point

		if best != null:
			break

	if best != null:
		_claims[id] = best

	return best


## One of them has you again (`by`, just into the fight): the hunters near
## enough hear him and come to where you are.
func sighted(by: Node3D) -> void:
	var enemy := target()

	if enemy == null:
		return

	var feet: Vector3 = by._feet_of(enemy) if by.has_method("_feet_of") else enemy.global_position
	var going: Variant = enemy.get("velocity")
	last_sighting = {"position": feet, "time": clock, "velocity": going if going is Vector3 else Vector3.ZERO}
	_claims.erase(by.get_instance_id())

	for member in members():
		if member == by or status_of(member) != &"hunting" or not member.has_method("hear_call"):
			continue

		if _flat(member.global_position, feet) <= CALL_RANGE:
			member.hear_call(feet)


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _temper_of(guard: Node) -> RefCounted:
	var fighter = guard.get("_fighter") if guard != null else null
	return fighter.temper if fighter != null else null


static func _nerve(guard: Node) -> float:
	var t := _temper_of(guard)
	return float(t.nerve) if t != null else 0.5


static func _guile(guard: Node) -> float:
	var t := _temper_of(guard)
	return float(t.guile) if t != null else 0.5

static func _kind(guard: Node) -> StringName:
	var archetype: Variant = guard.get("archetype")
	return archetype if archetype is StringName else StringName(str(archetype)) if archetype != null else &""


static func _health_of(guard: Node) -> float:
	var most: float = float(guard.get("max_health")) if guard.get("max_health") != null else 100.0
	return float(guard.get("health")) / maxf(most, 1.0) if guard.get("health") != null else 1.0


