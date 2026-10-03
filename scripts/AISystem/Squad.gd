extends RefCounted
## Target-scoped hunt shared by combatants, hunters, runners and lookouts.
## Selects a leader, tactic and roles; coordinates attack/throw turns and search areas.
## Local observed habits fade, while Garrison learns persistent habits and dread.
## Resolve combines morale, temperament, wounds and allies. Casualties can trigger
## rally/rout; leaving combat alone does not leave the hunt. Last departure dissolves it.

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
## Grief for a man he knew weighs on a craven man's resolve this much (x his
## grief); craven is nerve under CRAVEN_NERVE (Temperament.CRAVEN_AT).
const GRIEF_WEIGHT := 0.4
const CRAVEN_NERVE := 0.3
## A man under STATUS_HURT of his health is asked after, once in STATUS_EVERY.
const STATUS_HURT := 0.6
const STATUS_EVERY := 20.0
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
## The ground the hunt shares out: this far round where one thinks you are
## (m). A place searched is left alone this long (s), unless you are seen
## again. A man going through a door into a room: one more of them, this
## near the door (m), holds it, HOLD_BACK (m) back from it on this side,
## while he is in there (for ROOM_HOLD s at most).
const SEARCH_FAR := 8.0
const SEARCHED_FOR := 60.0
const HOLD_NEAR := 16.0
const HOLD_BACK := 2.2
const ROOM_HOLD := 14.0
## A flanker with this much drive (and less guile than PATIENT_GUILE) will not
## wait for you to commit to another: he goes in once his patience is gone.
## A patient man waits longer (PATIENT_WAIT, s), not for ever. At your back
## (you facing further from him than BACK_DOT) for BACK_WAIT (s), he strikes.
const IMPATIENT_DRIVE := 0.65
const PATIENT_GUILE := 0.65
const PATIENT_WAIT := 7.0
const BACK_DOT := -0.35
const BACK_WAIT := 1.0
## A man sent for help is not sent to one he would have to run past you
## (within this, m) to reach.
const FETCH_PAST := 3.0
## Where you are, called to the others: at most this often (s).
const SPOT_EVERY := 2.4
## ...or as soon as this, when one of them who cannot see you is about to
## give you up for lost.
const SPOT_URGENT := 0.8
## A man running this fast (m/s) is cut off, not only chased.
const RUNNING := 2.5
## ...and has been this long (s) before a man is sent to cut you off; he keeps
## at it until you have stopped for UNRUN.
const RUN_FOR := 0.5
const UNRUN := 0.8
## The front man is kept unless another is this much better placed (the
## score: metres, give or take): no swapping round every moment.
const FRONT_KEEP := 1.0
## A man set to watch (Guard.lookout) keeps his post while his friends have
## you in hand: you further off him than LOOKOUT_NEAR, at least two of them at
## you (or, for LOOKOUT_CALL after he first sees you, anyone within
## LOOKOUT_CALLS of him to call in), their heart at LOOKOUT_HEART or more,
## none of them cut down in the last LOOKOUT_GRIEF seconds, and you seen from
## up there within LOOKOUT_BLIND. Otherwise he comes down (_keeps_post).
const LOOKOUT_NEAR := 4.0
const LOOKOUT_CALL := 8.0
const LOOKOUT_CALLS := 30.0
const LOOKOUT_HEART := 0.55
const LOOKOUT_GRIEF := 20.0
## A bell this near him to be rung: he rings it first (GuardFighter._keep_lookout).
const LOOKOUT_BELL := 30.0
## Not seen you for this long (s) from up there: he comes down.
const LOOKOUT_BLIND := 4.0
## Something thrown: one man at a time, at most one throw in THROW_GAP
## seconds for the whole squad, and a turn to go for it lasts THROW_TURN.
const THROW_GAP := 3.0
const THROW_TURN := 5.0
## A watcher keeps his vantage this long (s), picked this far from where you
## were last seen.
const WATCH_TIME := 25.0
const WATCH_NEAR := 5.0
const WATCH_FAR := 11.0

const Dangers := preload("res://scripts/AISystem/Dangers.gd")
const SearchSpotsScript := preload("res://scripts/AISystem/SearchSpots.gd")
const Comms := preload("res://scripts/AISystem/Comms.gd")

const GarrisonScript := preload("res://scripts/AISystem/Garrison.gd")
## Calls answered, by the talk (a second man answers: TalkDirector).
const TALK_DIRECTOR := "res://scripts/AISystem/Talk/TalkDirector.gd"

static var _squads := {}

var target_ref: WeakRef
var tactic: StringName = &"envelop"
## What they have seen you do, each 0..1 and fading: turtle (a raised guard),
## spam (blows on each other's heels), kite (keeping away), bow (shooting),
## parry (their blows turned aside), dodge (their blows stepped out of).
var read := {&"turtle": 0.0, &"spam": 0.0, &"kite": 0.0, &"bow": 0.0, &"parry": 0.0, &"dodge": 0.0}
## Their heart, 0..1.
var morale := 1.0
## The most of them there have been in this fight.
var largest := 0

var _members: Array[WeakRef] = []
var _roles := {}
var _slots := {}
var _leader: WeakRef = null
var _leader_fell_at := -100.0
## When the last of them was cut down (anyone, not just the leader).
var _last_death_at := -100.0
## The front man last think; when you started (and stopped) running; who was
## sent to cut you off.
var _front_ref: WeakRef = null
var _running_since := INF
var _stopped_since := -INF
var _intercept_ref: WeakRef = null
## When each man set to watch first had you in sight in this hunt (id ->
## clock).
var _post_seen_at := {}
## Throwing: whose turn it is, until when, and when anyone may next throw.
var _thrower: WeakRef = null
var _thrower_until := -100.0
var _next_throw_at := -100.0
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
## ground; the places searched ([point, clock]); the rooms men have gone into
## through a door (by his instance id: door (weakref), where he went, until
## when, who holds the door (instance id, 0: nobody)).
var _claims := {}
var _searched: Array = []
var _rooms := {}
## Runners who have fetched their man (one errand each), and the men each
## runner could not get to.
var _fetched_once := {}
var _given_up_on := {}
## How many of them are down (killed or knocked senseless), and how many were
## down when they last fell back: they fall back when half are down, not
## when half are elsewhere.
var _lost := 0
## Where their men fell, and who ({where, name}); the men who have refused a
## place there; when a man cut was last asked if he stands.
var _fallen: Array = []
var _excused := {}
var _status_at := -100.0
var _fell_back_at_lost := 0
## When one of them last called where you are.
var _last_spot_call := -100.0
## The hunt's watcher, his vantage, and until when he keeps it; and which
## sighting (its time) was last watched.
var _watcher: WeakRef = null
var _watched_sighting := -INF
var _watch_point := Vector3.INF
var _watch_until := -100.0


## Returns the active hunt for target or creates a new one seeded by Garrison.
## Returns null for null/freed target; dissolved hunts are replaced.
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
		squad._watch_you(target)

	return squad


## Whoever they were after is gone (a level reloaded): let the hunt go.
static func _prune() -> void:
	for key in _squads.keys():
		var w: WeakRef = _squads[key].target_ref

		if w == null or w.get_ref() == null:
			_squads.erase(key)


## Clears the static hunt cache; invoke separately from Garrison.clear_all().
static func clear_all() -> void:
	_squads.clear()


func target() -> Node3D:
	return target_ref.get_ref() as Node3D if target_ref != null else null


## Every blow of theirs you turn aside, every one you step out of: they see
## it (read "parry", "dodge").
func _watch_you(enemy: Node3D) -> void:
	var combat: Variant = enemy.get("combat")

	if not (combat is Object):
		return

	if (combat as Object).has_signal(&"defended"):
		(combat as Object).connect(&"defended", _on_defended)

	if (combat as Object).has_signal(&"dodged"):
		(combat as Object).connect(&"dodged", _on_dodged)


func _on_defended(result: StringName) -> void:
	if fighting().is_empty():
		return

	# A counter is a parry with a blade; a Mikiri a step aside that is also
	# one.
	if result in [&"parry", &"counter", &"mikiri"]:
		read[&"parry"] = minf(float(read.get(&"parry", 0.0)) + (0.3 if result != &"mikiri" else 0.15), 1.0)

	if result == &"mikiri":
		read[&"dodge"] = minf(float(read.get(&"dodge", 0.0)) + 0.22, 1.0)


func _on_dodged(_direction: Vector3) -> void:
	if not fighting().is_empty():
		read[&"dodge"] = minf(float(read.get(&"dodge", 0.0)) + 0.22, 1.0)


## Whether one of them may call where you are now (not on top of the last).
func may_call(urgent := false) -> bool:
	return clock - _last_spot_call >= (SPOT_URGENT if urgent else SPOT_EVERY)


func called() -> void:
	_last_spot_call = clock


# Who is in it

## Adds a guard weak reference to this hunt without duplicating membership.
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
	_rooms.erase(guard.get_instance_id())
	# And nothing of his own kept: back in the hunt, he is judged afresh and
	# his coming back is help arriving.
	var id := guard.get_instance_id()

	for kept in [_resolve, _broken, _ever_fought, _health_seen, _helper_cache, _fetched_once, _given_up_on, _post_seen_at]:
		(kept as Dictionary).erase(id)


## Removes a returning guard from the hunt; last member leaving dissolves it.
func stand_down(guard: Node3D) -> void:
	leave(guard)

	if members().is_empty():
		_dissolve()


## One of them fell (`killed`, or knocked senseless): it shakes the rest, and
## the leader's fall most of all. A killing the whole garrison hears of.
func member_died(guard: Node3D, killed := true) -> void:
	var was_leader: bool = _leader != null and _leader.get_ref() == guard
	var called := String(guard.get("given_name")) if guard.get("given_name") != null else ""
	_fallen.append({"where": guard.global_position, "name": called})
	leave(guard)
	morale = maxf(morale - (0.45 if was_leader else 0.2), 0.0)
	_last_harm_at = clock
	_last_death_at = clock
	_lost += 1

	if killed and target() != null:
		GarrisonScript.of(target()).on_death(was_leader, called)

	if was_leader:
		_leader = null
		_leader_fell_at = clock
		_berserk_until = clock + 12.0

	# The brute takes it personally: a brute in the fight, near enough to have
	# seen it (one roar, not one from every brute in the hunt).
	for member in members():
		if _kind(member) == &"brute" and int(member.state) == 4 and (member as Node3D).global_position.distance_to(guard.global_position) < 15.0 \
				and Comms.may_voice(&"roar", (member as Node3D).global_position):
			member.bark("RAAAGH!")

	# "Man down!", and a man counts them.
	if killed:
		var near: Array = fighting()

		if not near.is_empty():
			_call_pair(&"man_down", near[0], {"dead_name": called})


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
			return 0.3 * known(&"turtle") + 0.3 * known(&"parry")
		&"parry":
			return 0.25 * known(&"spam")
		&"guard":
			return 0.25 * known(&"spam") + (0.3 if tactic == &"fall_back" else 0.0)
		&"lunge":
			return 0.35 * known(&"kite") + (0.2 if tactic == &"rush" else 0.0)
		&"backstep":
			return 0.2 * known(&"spam")
		&"delay":
			# You parry: they hold a follow-up back to catch it too soon.
			return 0.35 * known(&"parry")
		&"track":
			# You dodge: the blows that reach and go low.
			return 0.8 * known(&"dodge")
		&"perilous":
			# You parry: the blows no parry is for.
			return 0.6 * known(&"parry")

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
		&"engage", &"breaker", &"berserk", &"bodyguard", &"desperate", &"intercept":
			return true
		&"lookout":
			# Set to watch: only when you come to him.
			var near := target()
			return near != null and guard.global_position.distance_to(near.global_position) < float(guard._fighter._reach(&"overhead")) + 0.5
		&"flank":
			return _committed_away_from(guard) or impatient_now(guard) or _at_your_back(guard)
		&"hold":
			# Only when you come to him.
			var foe := target()
			return foe != null and guard.global_position.distance_to(foe.global_position) < float(guard._fighter._reach(&"overhead"))
		&"reserve", &"rally", &"flee", &"fetch":
			var enemy := target()
			return enemy != null and guard.global_position.distance_to(enemy.global_position) < 2.0

	return true


## At your back (you face well away from him), and there a moment: your back
## is his to strike, busy or not.
func _at_your_back(guard: Node3D) -> bool:
	var enemy := target()
	var fighter = guard.get("_fighter")

	if enemy == null or fighter == null or float(fighter._flank_waited) < BACK_WAIT:
		return false

	var facing := -enemy.global_basis.z
	facing.y = 0.0
	var to_him := guard.global_position - enemy.global_position
	to_him.y = 0.0
	return to_him.length() > 0.01 and facing.length() > 0.01 and facing.normalized().dot(to_him.normalized()) < BACK_DOT


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


# Making the plan

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
	_ask_after_the_cut(alive, now)


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
			# A second man answers the call if he can (TalkDirector).
			var answered: bool = not (tactic == &"rout" and now - _leader_fell_at < 10.0) and _call_pair(StringName("tactic_" + String(tactic)), caller)

			if not answered:
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

	var lookouts := []
	# Those of them at you who are not set to watch, and still have the heart.
	var hands_on := 0

	for member in alive:
		var fighter = member.get("_fighter")

		if fighter != null and not fighter.stays_put and not bool(member.get("lookout")) and will_of(member) != &"broken":
			hands_on += 1

	for member in alive:
		var fighter = member.get("_fighter")

		if fighter == null or fighter.stays_put:
			continue

		# A man set to watch keeps his post while his friends have you in
		# hand; otherwise he comes down to them (_keeps_post).
		if bool(member.get("lookout")) and _keeps_post(member, enemy, hands_on, now):
			lookouts.append(member)
		elif fighter.ranged:
			archers.append(member)
		else:
			melee.append(member)

		if will_of(member) != &"broken" or drive_of(member) >= DESPERATE_DRIVE:
			standing += 1

	melee.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.global_position.distance_to(enemy.global_position) < b.global_position.distance_to(enemy.global_position))
	_roles.clear()
	_slots.clear()

	for watcher in lookouts:
		_roles[watcher.get_instance_id()] = &"lookout"

	# Already on his way for help: he keeps going until he has fetched him.
	# On his knees begging you, he is going nowhere: the man he was to fetch
	# is free for another to.
	for man in melee.duplicate() + archers.duplicate():
		if not _pleading(man) and helper_of(man) != null:
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
					if man != lead_now and not _pleading(man) and (sent == null or resolve_of(man) < resolve_of(sent)):
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
		var kept: Node3D = _front_ref.get_ref() as Node3D if _front_ref != null else null
		var kept_score := INF

		for man in melee:
			var score: float = man.global_position.distance_to(enemy.global_position) + 1.5 * (0.5 - drive_of(man))

			if man == lead:
				score -= 0.8

			# Knocked off his feet: not the man in front while another is up.
			if man.has_method("is_downed") and man.is_downed():
				score += 50.0

			if _health_of(man) < 0.3:
				score += 3.0

			if man == worn and melee.size() >= 2:
				score += 5.0

			if will_of(man) == &"wavering":
				score += 2.0

			if man == kept:
				kept_score = score

			if score < best:
				best = score
				front = man

		# The man already in front stays there unless another is clearly
		# better placed: no swapping round every moment.
		if kept != null and kept_score <= best + FRONT_KEEP:
			front = kept

	_front_ref = weakref(front) if front != null else null

	# Worn down in front: he steps back, and a fresher man takes his place.
	if not breaking and now - _last_swap > 5.0 and melee.size() >= 2 and _health_of(front) < 0.3:
		for man in melee:
			if man != front and _health_of(man) > 0.6 and not (man.has_method("is_downed") and man.is_downed()):
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
	# You running: the man best placed ahead of you goes to cut you off while
	# the front man comes straight after you.
	var going: Variant = enemy.get("velocity")
	var run := Vector3((going as Vector3).x, 0.0, (going as Vector3).z) if going is Vector3 else Vector3.ZERO

	# Running for a moment, not a step: and whoever was sent keeps at it
	# until you have stopped a while.
	if run.length() > RUNNING:
		_running_since = minf(_running_since, now)
		_stopped_since = INF
	else:
		_stopped_since = minf(_stopped_since, now)

		if now - _stopped_since >= UNRUN:
			_running_since = INF
			_intercept_ref = null

	if now - _running_since >= RUN_FOR and not free.is_empty() and tactic != &"break":
		var ahead_man: Node3D = _intercept_ref.get_ref() as Node3D if _intercept_ref != null else null

		if not (ahead_man in free) and run.length() > 0.5:
			var most_ahead := -INF
			ahead_man = null

			for man in free:
				var ahead: float = (man.global_position - enemy.global_position).dot(run.normalized())

				if ahead > most_ahead:
					most_ahead = ahead
					ahead_man = man

		if ahead_man in free:
			_intercept_ref = weakref(ahead_man)
			_roles[ahead_man.get_instance_id()] = &"intercept"
			free.erase(ahead_man)

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


# Resolve: who holds and who breaks

## His will to fight on, as it was last judged.
func resolve_of(guard: Node3D) -> float:
	return float(_resolve.get(guard.get_instance_id(), 1.0))


## Whether `man`, set to watch, keeps his post against `enemy` (his view is
## worth more to them than his blade): first to ring the bell if there is one
## near to be rung, and for LOOKOUT_CALL after he has seen you to call the
## others in (if there are any near); after that while his friends have you
## in hand, `hands_on` of them (two or more) at you. Always: their heart
## holding, none of them lately cut down, you not on top of him, and you in
## his sight lately (a lookout who cannot see you is no use up there); but a
## bell to ring comes before all that. Otherwise he comes down to help, and
## stays down (Guard._left_post).
func _keeps_post(man: Node3D, enemy: Node3D, hands_on: int, now: float) -> bool:
	if bool(man.get("_left_post")):
		return false

	if _post_kept(man, enemy, hands_on, now):
		return true

	man.set("_left_post", true)
	return false


## _keeps_post's judgement, before he is sent down for good.
func _post_kept(man: Node3D, enemy: Node3D, hands_on: int, now: float) -> bool:
	var id := man.get_instance_id()

	if not _post_seen_at.has(id):
		_post_seen_at[id] = now

	if man.global_position.distance_to(enemy.global_position) <= LOOKOUT_NEAR:
		return false

	# A bell near to be rung: that first, however it goes.
	if Dangers.bell_near(man.get_tree(), man.global_position, LOOKOUT_BELL) != null:
		return true

	if float(man.get("_since_seen")) > LOOKOUT_BLIND:
		return false

	if morale < LOOKOUT_HEART or now - _last_death_at < LOOKOUT_GRIEF or tactic == &"fall_back" or tactic == &"rout":
		return false

	if hands_on >= 2:
		return true

	# Just seen you: he calls the others in first, if there are others to call.
	return now - float(_post_seen_at[id]) < LOOKOUT_CALL and _friends_near(man, LOOKOUT_CALLS) >= 1


## Awake men of theirs (not set to watch) within `reach` of `man`.
func _friends_near(man: Node3D, reach: float) -> int:
	var count := 0

	for other in man.get_tree().get_nodes_in_group(&"guards"):
		if other == man or not is_instance_valid(other) or other.get("_knocked_out") == true or bool(other.get("lookout")):
			continue

		if (other as Node3D).global_position.distance_to(man.global_position) <= reach:
			count += 1

	return count


## Whether `guard` may go for something to throw now: nobody else of them at
## it, and none thrown just now. Taken, the turn is his for THROW_TURN.
func may_throw(guard: Node3D) -> bool:
	if clock < _next_throw_at:
		return false

	var who: Node3D = _thrower.get_ref() as Node3D if _thrower != null else null

	if who != null and who != guard and is_instance_valid(who) and clock < _thrower_until:
		return false

	if who != guard:
		_thrower = weakref(guard)
		_thrower_until = clock + THROW_TURN

	return true


## `guard` has given up the throw he went for: the turn is free.
func not_throwing(guard: Node3D) -> void:
	var who: Node3D = _thrower.get_ref() as Node3D if _thrower != null else null

	if who == guard:
		_thrower = null


## `guard` has thrown: a moment before anyone throws again.
func threw(guard: Node3D) -> void:
	var who: Node3D = _thrower.get_ref() as Node3D if _thrower != null else null

	if who == guard:
		_thrower = null

	_next_throw_at = clock + THROW_GAP


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

		# A craven man's grief for a man he knew takes the heart out of him.
		if _nerve(man) < CRAVEN_NERVE:
			resolve -= GRIEF_WEIGHT * float(man.get("grief") if man.get("grief") != null else 0.0)
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

	# A patient man waits for his moment, but not for ever.
	if _guile(guard) >= PATIENT_GUILE or drive < IMPATIENT_DRIVE:
		return PATIENT_WAIT * (2.0 if held(guard) else 1.0)

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


# Help

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
## fetched already; or an alarm bell (AlarmBell.gd) nearer than any of them,
## to bring everyone at once. Looked for again every 2 s at most.
func helper_for(runner: Node3D) -> Node3D:
	var id := runner.get_instance_id()
	var cached: Array = _helper_cache.get(id, [])

	if not cached.is_empty() and clock - float(cached[1]) < 2.0:
		var kept: Node3D = (cached[0] as WeakRef).get_ref() as Node3D if cached[0] != null else null
		return kept if kept != null and _can_fetch(kept, runner) else null

	var best: Node3D = null
	var best_length := HELPER_RANGE
	var map: RID = runner.get_world_3d().navigation_map
	# Not a man he would have to run past you to reach.
	var enemy := target()

	for other in runner.get_tree().get_nodes_in_group(&"guards"):
		if not _can_fetch(other, runner) or other.global_position.distance_to(runner.global_position) > HELPER_RANGE:
			continue

		var path := NavigationServer3D.map_get_path(map, runner.global_position, other.global_position, true)

		if path.is_empty() or path[path.size() - 1].distance_to(other.global_position) > 2.0:
			continue

		# (Nearer you than that already, only nearer still counts.)
		if enemy != null and _passes(path, enemy.global_position, minf(FETCH_PAST, enemy.global_position.distance_to(runner.global_position) - 0.5)):
			continue

		var length := 0.0

		for i in range(1, path.size()):
			length += path[i - 1].distance_to(path[i])

		if length < best_length:
			best_length = length
			best = other

	var bell: Node3D = Dangers.bell_near(runner.get_tree(), runner.global_position, best_length)

	# The bell, likewise not past you (you nearer it than he is).
	if bell != null and _can_fetch(bell, runner) and (enemy == null or enemy.global_position.distance_to(bell.global_position) > runner.global_position.distance_to(bell.global_position)):
		best = bell

	_helper_cache[id] = [weakref(best) if best != null else null, clock]
	return best


## Whether `path` goes within `clearance` (flat) of `point`.
static func _passes(path: PackedVector3Array, point: Vector3, clearance: float) -> bool:
	for i in range(1, path.size()):
		var a := Vector2(path[i - 1].x, path[i - 1].z)
		var b := Vector2(path[i].x, path[i].z)
		var p := Vector2(point.x, point.z)
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)

		if (a + ab * t).distance_to(p) < clearance:
			return true

	return false


func _can_fetch(other: Node, runner: Node3D) -> bool:
	if other == runner or not is_instance_valid(other) or other.is_queued_for_deletion() or other.get("_knocked_out") == true:
		return false

	# A bell: while it can be rung, and nobody else is going for it.
	if other.is_in_group(&"alarm_bells"):
		if not other.can_ring():
			return false

		for key in _fetching:
			if key != runner.get_instance_id() and (_fetching[key] as WeakRef).get_ref() == other:
				return false

		return true

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

	# A bell: rung, and everyone comes to where you were last seen.
	if helper.is_in_group(&"alarm_bells"):
		if runner.get("_hands") != null:
			runner._hands.ring_bell(helper, last_sighting["position"])

		_help_until = clock + HELP_TIME
		morale = minf(morale + 0.1, 1.0)
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

		if man == null or not is_instance_valid(man) or not man.has_method("bark"):
			continue

		var t := _temper_of(man)

		if t == null:
			continue

		# Down off his post to them: said over anything he was saying.
		if before.get(id, &"") == &"lookout" and not (place in [&"flee", &"fetch", &"rally"]):
			var down: String = t.line(&"descend")

			if down != "":
				man.bark(down)

			continue

		if float(man.get("_bark_timer")) > 0.0:
			continue

		var situation: StringName = &""

		match place:
			&"flank":
				situation = &"flank" if randf() < 0.5 else &""
			&"intercept":
				situation = &"intercept"
			&"desperate":
				situation = &"desperate"
			&"flee", &"fetch":
				situation = &"break" if will_of(man) == &"broken" else &""
			&"engage":
				situation = &"press" if tactic == &"fall_back" else &""

		# Sent where a friend of his fell: a craven man will not go.
		if place == &"flank" and not _fallen.is_empty() and _nerve(man) < CRAVEN_NERVE and not _excused.has(id):
			var giver: Node3D = leader()

			if giver != null and giver != man and _call_pair(&"excuse", giver, {"b": man, "dead_name": String(_fallen[-1]["name"])}):
				_excused[id] = true
				continue

		# The last of them: off for the others.
		if (place == &"flee" or place == &"fetch") and fighting().size() <= 1 and _call_pair(&"last_man", man):
			continue

		if situation != &"":
			var said: String = t.line(situation)

			if said != "":
				man.bark(said)


## A man cut badly: now and then his leader asks if he stands, and he
## answers how he is.
func _ask_after_the_cut(alive: Array, now: float) -> void:
	if now - _status_at < STATUS_EVERY:
		return

	var giver: Node3D = leader()

	if giver == null:
		return

	for man in alive:
		if man != giver and _health_of(man) < STATUS_HURT:
			if _call_pair(&"status", giver, {"b": man}):
				_status_at = now

			return


## A call and its answer (TalkDirector.call_pair). False if nobody answered.
func _call_pair(situation: StringName, caller: Node3D, facts := {}) -> bool:
	if caller == null or not is_instance_valid(caller) or not caller.is_inside_tree() or not ResourceLoader.exists(TALK_DIRECTOR):
		return false

	var talk: RefCounted = (load(TALK_DIRECTOR) as GDScript).call(&"of", caller)
	return talk != null and talk.call_pair(situation, caller, facts)


## Help is on its way.
func help_coming() -> bool:
	return clock < _help_until


# The hunt

## Where `guard` searches next, as the hunt shares the ground out: his own
## piece round where he thinks you are (at least SEARCH_SPREAD from anyone
## else's, and not where one of them has searched since you were last seen),
## the likeliest place in it to be hiding (SearchSpots: somewhere dark, shut
## in, out of sight, a room through a door, a ledge), leaning the way you
## were going; a sly man is sent on ahead of you to cut you off; a door a man
## has just gone through, another holds. A place (as SearchSpots), or {}:
## nowhere of the hunt's, search on his own.
func search_spot_for(guard: Node3D) -> Dictionary:
	var id := guard.get_instance_id()
	_claims.erase(id)
	_rooms.erase(id)
	var seen: Vector3 = last_sighting["position"]
	var centre: Vector3 = guard.last_known_position if guard.get("has_last_known") == true else seen
	var going: Vector3 = last_sighting["velocity"]
	going.y = 0.0
	# The way you went counts only for the sighting he is searching round.
	var heading := going.normalized() if going.length() > 0.5 and _flat(centre, seen) < 3.0 else Vector3.ZERO
	var map: RID = guard.get_world_3d().navigation_map

	# Sent to search a hunt area (the divided hunt): his piece of it, round
	# somewhere in it if where you were is not.
	if not SearchSpotsScript.in_area(guard, centre):
		centre = SearchSpotsScript.area_centre(guard, _searched_since_seen())
		heading = Vector3.ZERO

	if heading != Vector3.ZERO and _guile(guard) >= PATIENT_GUILE:
		var ahead := seen + heading * CUT_OFF + heading.cross(Vector3.UP) * randf_range(-2.0, 2.0)
		var cut_off := NavigationServer3D.map_get_closest_point(map, ahead)

		if _flat(cut_off, ahead) <= 2.0 and SearchSpotsScript.in_area(guard, cut_off):
			_claims[id] = cut_off
			var t := _temper_of(guard)

			if t != null and guard.get("_bark_timer") != null and float(guard._bark_timer) <= 0.0 and guard.has_method("bark"):
				# "Anyone see him?" and a man who did names the place.
				if not _call_pair(&"spotted_ask", guard, {"place_name": Comms.place(seen, guard)}):
					guard.bark(t.line(&"hunt"))

			return {"stand": cut_off, "peer": Vector3.INF, "kind": &"cut_off"}

	# A door one of them has gone through: he holds it.
	var hold := _door_to_hold(guard)

	if not hold.is_empty():
		_claims[id] = hold["stand"]
		return hold

	var taken := []

	for other in _claims:
		if other != id:
			taken.append(_claims[other])

	var searched := _searched_since_seen()
	var spot := {}
	# Knowing which way you went, he looks in the ground ahead of it first,
	# and anywhere round only if none of that is free.
	var passes: Array = [true, false] if heading != Vector3.ZERO else [false]

	for ahead_only in passes:
		spot = SearchSpotsScript.pick(guard, centre, heading, SEARCH_FAR, taken, SEARCH_SPREAD, searched, ahead_only)

		if not spot.is_empty():
			break

	if spot.is_empty():
		return {}

	_claims[id] = spot["stand"]

	if spot["kind"] == &"room":
		_rooms[id] = {"door": weakref(spot["door"]), "stand": spot["stand"], "until": clock + ROOM_HOLD, "held_by": 0}

	return spot


## Returns search_spot_for(guard).stand as Variant (Vector3), or null on failure.
func search_point_for(guard: Node3D) -> Variant:
	var spot := search_spot_for(guard)
	return spot["stand"] if not spot.is_empty() else null


## One of them has searched `point`: the rest leave it alone a while.
func searched(point: Vector3) -> void:
	_searched.append([point, clock])

	if _searched.size() > 24:
		_searched.pop_front()


## The places searched since you were last seen (and not too long ago).
func _searched_since_seen() -> Array:
	var since := float(last_sighting.get("time", -100.0))
	var points := []

	for done in _searched:
		if float(done[1]) >= since and clock - float(done[1]) < SEARCHED_FOR:
			points.append(done[0])

	return points


## A door one of the hunt has just gone through into a room, near `guard`
## and nobody holding it: he holds it, back from it on his side, watching the
## doorway (you do not slip out past the man in there). {} if none.
func _door_to_hold(guard: Node3D) -> Dictionary:
	var own := guard.get_instance_id()
	var map: RID = guard.get_world_3d().navigation_map

	for id in _rooms.keys():
		var room: Dictionary = _rooms[id]
		var door := (room["door"] as WeakRef).get_ref() as Node3D
		var man := instance_from_id(id) as Node3D

		if door == null or man == null or not is_instance_valid(man) or clock > float(room["until"]) or status_of(man) != &"hunting":
			_rooms.erase(id)
			continue

		if id == own or int(room["held_by"]) != 0:
			continue

		var doorway: Vector3 = door.doorway()

		if _flat(guard.global_position, doorway) > HOLD_NEAR:
			continue

		var into: Vector3 = room["stand"] - doorway
		into.y = 0.0

		if into.length() < 0.1:
			continue

		var guess := doorway - into.normalized() * HOLD_BACK
		var stand := NavigationServer3D.map_get_closest_point(map, guess)

		# (Not a door off the ground he was sent to search.)
		if _flat(stand, guess) > 1.0 or not SearchSpotsScript.in_area(guard, stand):
			continue

		room["held_by"] = own
		return {"stand": stand, "peer": doorway + Vector3.UP * 1.0, "kind": &"hold", "door": door}

	return {}


## Returns a watcher's world-space vantage as Variant (Vector3), or null if this
## guard should search normally. Reserves the shared watcher role/point.
func watch_point_for(guard: Node3D) -> Variant:
	var hunters := members().filter(func(man: Node3D) -> bool: return status_of(man) == &"hunting")
	var watcher: Node3D = _watcher.get_ref() as Node3D if _watcher != null else null

	if watcher != null and (not (watcher in hunters) or clock > _watch_until):
		watcher = null
		_watcher = null

	# One watch for each place you were last seen: his time up, he searches
	# with the rest (and is not set to watch the same place over again).
	if watcher == null and float(last_sighting.get("time", -1.0)) == _watched_sighting:
		return null

	if watcher == null:
		# A man set to watch among them keeps watch from his own post
		# (Guard._next_search_point): nobody else need. (Come down to
		# help, he searches as the rest do.)
		if hunters.any(func(man: Node3D) -> bool: return bool(man.get("lookout")) and not bool(man.get("_left_post"))):
			return null

		var archer_among := hunters.any(func(man: Node3D) -> bool: return man.get("_fighter") != null and man._fighter.ranged)

		if hunters.size() < 3 and not (archer_among and hunters.size() >= 2):
			return null

		var best: Node3D = null
		var best_score := -INF

		for man in hunters:
			var fighter = man.get("_fighter")
			var score: float = (2.0 if fighter != null and fighter.ranged else 0.0) + _guile(man) - drive_of(man)

			if score > best_score:
				best_score = score
				best = man

		var point := _vantage(best)

		if point == Vector3.INF:
			return null

		_watcher = weakref(best)
		_watch_point = point
		_watch_until = clock + WATCH_TIME
		_watched_sighting = float(last_sighting.get("time", -1.0))
		var t := _temper_of(best)

		if t != null and best.has_method("bark") and float(best.get("_bark_timer")) <= 0.0:
			best.bark(t.line(&"watch"))

		# Another man it is: he is told, and goes at once.
		if best != guard:
			if best.has_method("keep_watch_at"):
				best.keep_watch_at(point)

			return null

		return point

	return _watch_point if watcher == guard else null


## A place near where you were last seen, on the navmesh, that sees that
## place: higher ground and open ground the better, and not too far for him.
## INF if there is none.
func _vantage(man: Node3D) -> Vector3:
	var seen: Vector3 = last_sighting["position"]
	var map: RID = man.get_world_3d().navigation_map
	var space := man.get_world_3d().direct_space_state
	var best := Vector3.INF
	var best_score := -INF
	# Only the world hides the place; you are no wall.
	var enemy := target()
	var exclude: Array[RID] = []

	if enemy is CollisionObject3D:
		exclude.append((enemy as CollisionObject3D).get_rid())

	for i in 14:
		var angle := TAU * float(i) / 14.0 + randf() * 0.3
		var guess := seen + Vector3(cos(angle), 0.0, sin(angle)) * randf_range(WATCH_NEAR, WATCH_FAR)
		var point := NavigationServer3D.map_get_closest_point(map, guess)

		if _flat(point, guess) > 1.5:
			continue

		var eye := point + Vector3.UP * 1.65

		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, seen + Vector3.UP * 0.8, 1, exclude)).is_empty():
			continue

		var open := 0

		for k in 6:
			var way := Vector3(cos(TAU * float(k) / 6.0), 0.0, sin(TAU * float(k) / 6.0))

			if space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, eye + way * 8.0, 1, exclude)).is_empty():
				open += 1

		var score := (point.y - seen.y) * 0.8 + float(open) * 0.15 - 0.05 * man.global_position.distance_to(point)

		if score > best_score:
			best_score = score
			best = point

	return best


func watcher() -> Node3D:
	return _watcher.get_ref() as Node3D if _watcher != null else null


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


# Helpers

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


## On his knees begging you (GuardMercy).
static func _pleading(guard: Node) -> bool:
	var mercy: RefCounted = guard.get("_mercy")
	return mercy != null and bool(mercy.pleading)


static func _health_of(guard: Node) -> float:
	var most: float = float(guard.get("max_health")) if guard.get("max_health") != null else 100.0
	return float(guard.get("health")) / maxf(most, 1.0) if guard.get("health") != null else 1.0


