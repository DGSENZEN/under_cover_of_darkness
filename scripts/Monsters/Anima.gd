extends "res://scripts/Monsters/Monster.gd"
## A ravenous ánima: a soul no one lit a candle for, past begging. It comes up out
## of a drain and may lie there a while (`rests`) until something stirs it; then it rushes
## you. Up close it cuts you and backs off; from further off it tells, and leaps to get on you
## and drink your willpower and your life. Its forms are data (Bestiary): withered hands, hands and a face, a
## torso dragged by its arms. Lead passes through it. A hit in its tell from anything
## else breaks the leap and opens it up. The Metro's beggars (Animas.gd) are another
## thing altogether.

const AnimaBody := preload("res://scripts/Monsters/AnimaBody.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")
const WardScript := preload("res://scripts/Magic/Ward.gd")
const CopalLine := preload("res://scripts/Hunt/CopalLine.gd")

enum State { RISE, RUSH, CIRCLE, TELL, LEAP, MISSED, ON, THROWN, REST, WAKE, WIND_UP, SWIPE, BACK_OFF, LEAVE, CROWD, REACH, DRAG }

const DOING := {
	State.RISE: &"rise", State.RUSH: &"rush", State.CIRCLE: &"circle", State.TELL: &"tell",
	State.LEAP: &"leap", State.MISSED: &"missed", State.ON: &"on", State.THROWN: &"thrown",
	State.REST: &"rest", State.WAKE: &"wake",
	State.WIND_UP: &"wind_up", State.SWIPE: &"swipe", State.BACK_OFF: &"back_off", State.REACH: &"reach", State.DRAG: &"drag", State.LEAVE: &"leave", State.CROWD: &"crowd",
}
const RISE_TIME := 0.5
## Finished with you: how fast it crawls off, and how long before it rests.
const LEAVE_SPEED := 1.4
const LEAVE_TIME := 6.0
## What is near while you are being finished comes to watch, and hopes: from how far, how fast,
## how close it stands.
const CROWD_REACH := 12.0
const CROWD_SPEED := 6.0
const CROWD_RING := 1.3
## Stopped dead this long, moving slower than this, it feels along what stopped it for this long,
## and goes on the same way round for this long after.
const FEEL_AFTER := 0.2
const FEEL_MOVES_LESS := 0.25
const FEEL_FOR := 0.9
const FEEL_KEEPS := 2.5
## A swipe (its damage, reach and wind-up by form, in Bestiary): how long the swing, how hard it
## lunges into it; how long it backs off, how fast; how long till the next.
const SWIPE_TIME := 0.16
const SWIPE_LUNGE := 4.0
const BACK_OFF_TIME := 0.7
const BACK_OFF_SPEED := 3.0
const SWIPE_EVERY := Vector2(1.4, 2.4)
## How far past its reach a swing still finds you (m); how it edges round you, waiting.
const SWIPE_FINDS := 0.3
const EDGES_ROUND := 1.0
## What a cut does to your view.
const CUT_TRAUMA := 0.14
const CUT_ROLL := 1.1
## At most one leap in this long (s).
const LEAP_EVERY := 4.0
## At rest: how near you can come (m), how long it can lie there at most (hunger gets it up
## in the end), how long it takes to come to, and how far off that stirs the others.
const NOTICE := 9.0
const REST_LONGEST := 9.0
const WAKE_TIME := 0.5
const STIRS := 7.0
const MISSED_TIME := 0.8
## Thrown off: how long it is stunned and exposed, how hard it is thrown.
const THROWN_TIME := 1.5
const THROW_SPEED := 9.0
## How far past its own size a mouth comes back when thrown off you (m).
const THROWN_MOUTH_CLEARS := 1.6
## Small ones and an elite: how far off it they know it; while you are how many of their leaps off they stay
## round it, how far out, and how fast.
const WAITS_WITHIN := 14.0
const WAITS_WHILE_YOU_ARE := 2.0
const WAITS_ROUND := 2.2
const WAITS_PACE := 0.55
const WAITS_IN_A_RING := 6.0
const WAITS_GO_ROUND := 0.3
## Shot, how long it forgets all that (s).
const RILED_FOR := 10.0
## What weighs anything: how much of its speed it starts a leap with; coming down, how much it
## carries on with, how much you feel it, and from how far (m).
const LEAP_STARTS_AT := 0.12
const COMES_DOWN_CARRIES := 0.4
const COMES_DOWN_SHAKES := 0.3
const COMES_DOWN_FELT := 8.0
## What hauls itself: each haul, how much you feel it, from how far (m).
const HAUL_SHAKES := 0.16
const HAUL_FELT := 7.0
## Flung up by the Burst: how hard, how fast that dies.
const FLUNG_UP := 6.5
const FLUNG_DIES := 10.0
## Knocked by a Shard going through it, how hard.
const JOLT_UP := 2.2
## They spread out, so they come at you from more than one side (m beside you).
const SPREAD := 1.6
const GRAVITY := 18.0
## How quickly a face holds its height.
const FLOAT_RATE := 4.0
## A leap lands this close to your chest.
const LATCH_REACH := 1.0
## Waiting its turn at this far off (m), with no room on you.
const CIRCLE_AT := 4.5
const CIRCLE_SPEED := 2.5
## Smoked: how much slower it goes, and how much less it drinks.
const SMOKED_SPEED := 0.5
const SMOKED_DRAIN := 0.5
## The creep and the surge, of its speed; how long a surge lasts, and how long between.
const CREEP := 0.55
const SURGE := 2.1
const SURGE_TIME := 0.32
const SURGE_EVERY := Vector2(0.7, 1.5)
## How far ahead it looks for a line of copal (m).
const LINE_LOOKS := 0.5
## How much it has to drink to be fully fed (shown on it).
const FULL := 60.0

## It has swung at you, and whether it cut.
signal swiped(hit: bool)

@export var form: StringName = &"hands"
## Lies where it came up until something stirs it.
@export var rests := false
## How near you can come before it stirs (m).
var notice := NOTICE
## Which of its form's deaths it dies (AnimaDeaths.gd), or any.
var death_kind := -1
## If it kills you, how you die (PlayerDeath.gd).
var kills_as: StringName = &"swipe"
var _feel_was := Vector3.ZERO
var _feel_stuck := 0.0
var _feel_left := 0.0
var _feel_keeps := 0.0
var _feel_side := 0.0
var _feel_way := Vector3.ZERO
## How likely, each time it could leap, that it does. If not, it comes on to cut you.
var leap_chance := 1.0
var state: int = State.RISE
var body: Node3D
var whip_reach := 1.6
## What it has drunk of your power. Half of it comes back when it dies.
var fed := 0.0
## Whips it can still take before it is thrown off (from its form).
## The elite mouth (set before it enters the tree), and who it has taken in.
var elite := false
## The small one it means to take, when it may look again, and where that one was seized. On a small one: who has
## picked it, and who has hold of it.
var _prey: Node3D = null
var _hungry_in := 0.0
var _drag_from := Vector3.ZERO
var _claimed_by: Node3D = null
var seized_by: Node3D = null
## On a small one: where in the ring it has its place, and how long it is riled. On the elite: how many have taken a place.
var _wait_turn := -1.0
var _riled := 0.0
var _waiting_here := 0
var _taken: Array[StringName] = []
var grip_left := 1
## The mouth's ribs, broken by a whip, as long as it goes on holding you.
var ribs_cracked := false
## What it is still carrying, if it has the weight to carry anything.
var _carried := Vector3.ZERO
var _hauls_heard := 0

var _form := {}
var _state_t := 0.0
var _leap_way := Vector3.ZERO
var _spread_turn := 0.0
var _agent: NavigationAgent3D
var _fall := 0.0
var _surge_in := 0.6
var _surge_left := 0.0
var _lift := 0.0
var _swipe_in := 0.0
var _leap_in := 0.0
var _swung := false
var _back_way := Vector3.ZERO


func _init() -> void:
	kind = &"anima"


func hit_radius() -> float:
	if elite:
		return float(Bestiary.elite_form(_taken.size())["hit_radius"])

	return float(Bestiary.form(&"anima", form).get("hit_radius", DEFAULT_RADIUS))


## One of this one's numbers, as it stands now.
func form_number(what: String) -> float:
	return float(_form[what])


## Stand-ins for the mouth's own (docs/superpowers/refs/hunt/sounds_needed.md).
func _sounds_for(next: int) -> void:
	if form != &"torso":
		return

	match next:
		State.TELL, State.WIND_UP:
			Sfx.play(self, &"bone_crack", global_position, -10.0, 0.55)
			Sfx.play(self, &"flesh", global_position, -8.0, 0.5)
		State.SWIPE:
			Sfx.play(self, &"flesh", global_position, -4.0, 0.62)
			Sfx.play(self, &"bone_crack", global_position, -8.0, 0.9)
		State.ON:
			Sfx.play(self, &"flesh_heavy", global_position, -2.0, 0.6)
			Sfx.play(self, &"anima_moan", global_position, -6.0, 0.5)
		State.DRAG:
			Sfx.play(self, &"whoosh_light", global_position, -6.0, 0.7)
			Sfx.play(self, &"flesh", global_position, -6.0, 0.8)


## What it is feeding on, if anything.
func prey() -> Node3D:
	return _prey if is_instance_valid(_prey) else null


## Whether a mouth has this one, and is taking it in.
func is_seized() -> bool:
	return seized_by != null


func let_go_of_prey() -> void:
	if is_instance_valid(_prey):
		_prey._claimed_by = null

		if _prey.seized_by == self:
			_prey._dropped()

	_prey = null

	if body != null and form == &"torso":
		body.unseize()


## Let go of, it drops where it is, and gets on with what it was doing.
func _dropped() -> void:
	seized_by = null
	_claimed_by = null
	_enter(State.RUSH)


## Hurt, with room in it and something near: it looks to feed, if it isn't busy with you.
func _look_for_prey(you: Node3D) -> void:
	if not elite or _hungry_in > 0.0 or (state != State.RUSH and state != State.CIRCLE and state != State.BACK_OFF):
		return

	var row: Dictionary = _form["elite"]

	if _taken.size() >= int(row["most_taken"]) or health >= float(row["health"]) * float(row["hungry_below"]) or statuses.has(&"smoked"):
		return

	var best := float(row["looks_within"])
	var nearest: Node3D = null

	for other in get_tree().get_nodes_in_group(&"monsters"):
		if other == self or other.dead or other.asleep or other.get("form") == null or other.form == &"torso":
			continue

		if other.state == State.ON or other._claimed_by != null or other.is_seized():
			continue

		var off: float = other.global_position.distance_to(global_position)

		if off < best and _clear_to(other):
			best = off
			nearest = other

	if nearest != null:
		_prey = nearest
		_prey._claimed_by = self
		_hungry_in = float(row["hungry_every"])
		_enter(State.REACH)


## Nothing in the way of that one: a wall, or a copal line.
func _clear_to(other: Node3D) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(global_position, other.global_position, 1)
	ray.exclude = [get_rid(), other.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty() and CopalLine.crossing(get_tree(), global_position, other.global_position) == null


## Hauling itself to the one it has picked, until an arm will get there.
func _reach_for_prey(delta: float) -> Vector3:
	var row: Dictionary = _form["elite"]
	var who := prey()

	if who == null or who.dead or who.asleep or who.state == State.ON or _state_t >= float(row["gives_up"]) or not _clear_to(who):
		_enter(State.RUSH)
		return _hold_height(Vector3.ZERO, delta)

	var to: Vector3 = (who.global_position - global_position) * Vector3(1.0, 0.0, 1.0)

	if to.length() <= float(row["seizes_within"]) + float(row["seizes_up"]) * float(_taken.size()) and not statuses.has(&"smoked"):
		who.seized_by = self
		who._enter(State.THROWN)
		_drag_from = who.global_position
		_enter(State.DRAG)
		return _hold_height(Vector3.ZERO, delta)

	return _hold_height(_feel_round(to.normalized(), delta) * float(_form["speed"]) * _pace() * _slowed(), delta)


## It has it: dragged in, thrashing, and under its skin.
func _drag_in_prey(delta: float) -> Vector3:
	var row: Dictionary = _form["elite"]
	var who := prey()

	if who == null or who.dead or who.asleep:
		_enter(State.RUSH)
		return _hold_height(Vector3.ZERO, delta)

	var u := clampf(_state_t / float(row["drags"]), 0.0, 1.0)
	var eased := u * u
	var into: Vector3 = global_position + Vector3.UP * 0.25
	who.global_position = _drag_from.lerp(into, eased)
	body.seize(who.global_position)

	if u >= 1.0:
		var kind_of: StringName = who.form
		_prey = null
		who.seized_by = null
		who._claimed_by = null
		who._lay_down()
		who._leave_you()
		take_in(kind_of)
		body.unseize()
		_enter(State.RUSH)

	return _hold_height(Vector3.ZERO, delta)


## A place in the ring round it, for one that has come to wait: each its own, evenly round.
func place_round_it() -> float:
	_waiting_here += 1
	return TAU * float(_waiting_here - 1) / WAITS_IN_A_RING


## The elite these small ones are drawn to, if there is one about: not itself, nor another mouth.
func elite_near() -> Node3D:
	if form == &"torso":
		return null

	var nearest: Node3D = null
	var best := WAITS_WITHIN

	for other in get_tree().get_nodes_in_group(&"elite_mouths"):
		var off: float = other.global_position.distance_to(global_position)

		if not other.dead and not other.asleep and off < best:
			best = off
			nearest = other

	return nearest


## It has all it can hold: if it gets you now, that's the end of you.
func is_full() -> bool:
	return elite and _taken.size() >= int(_form["elite"]["most_taken"])


## How many of a form it has taken in.
func taken_of(kind_of: StringName) -> int:
	return _taken.count(kind_of)


## What it has taken goes with it. What it was doing doesn't: off a save nothing is mid-drag, and nothing held.
func save_state() -> Dictionary:
	var saved := super.save_state()

	if elite:
		saved["taken"] = _taken.map(func(one): return String(one))

	return saved


func load_state(saved: Dictionary) -> void:
	let_go_of_prey()
	seized_by = null
	_claimed_by = null
	var health_was: float = float(saved.get("health", health))

	if elite and _taken.is_empty():
		for one in saved.get("taken", []):
			take_in(StringName(one))

	super.load_state(saved)
	health = health_was

	if state == State.REACH or state == State.DRAG or state == State.THROWN:
		_enter(State.RUSH)


## How many it has taken in.
func taken_count() -> int:
	return _taken.size()


## It has taken one in, a `kind` of form: back comes some of its health, and it is worse for it.
func take_in(kind: StringName) -> void:
	var row: Dictionary = _form["elite"]

	if _taken.size() >= int(row["most_taken"]):
		return

	_taken.append(kind)
	_form = Bestiary.elite_form(_taken.size())
	health = minf(health + float(row["health"]) * float(row["heals"]), float(row["health"]))
	body.has_taken(kind, float(_form["size"]))
	Sfx.play(self, &"flesh_heavy", global_position, -3.0, 0.5)

	# It has all it can hold, and you hear that.
	if is_full():
		Sfx.play(self, &"anima_moan", global_position, 0.0, 0.42)


## A crawler's body rests on the floor, whatever reach its hands have.
func _body_shape() -> Shape3D:
	var sphere := SphereShape3D.new()
	sphere.radius = minf(hit_radius(), float(_form.get("height", 0.3)))
	return sphere


func _ready() -> void:
	_form = Bestiary.elite_form(_taken.size()) if elite else Bestiary.form(&"anima", form)
	health = float(_form["health"])

	if elite:
		add_to_group(&"elite_mouths")

	grip_left = int(_form["grip"])
	super._ready()
	# (Godot stops a body dead against a wall it meets nearly square, unless told not to.)
	wall_min_slide_angle = 0.0
	_spread_turn = TAU * fmod(absf(position.x) * 0.37 + absf(position.z) * 0.61, 1.0)
	_agent = NavigationAgent3D.new()
	_agent.path_desired_distance = 0.6
	_agent.target_desired_distance = 0.6
	add_child(_agent)
	body = AnimaBody.new()
	body.name = "Body"
	body.form = form
	body.elite_size = float(_form["size"]) if elite else 0.0
	add_child(body)
	struck.connect(_on_struck)


func _is_opening() -> bool:
	return state == State.TELL or state == State.WIND_UP or state == State.REACH or state == State.DRAG


## Lead passes through it, even then.
func _is_opening_to(source: StringName) -> bool:
	return _is_opening() and source != &"lead"


func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	if dead or asleep or body == null:
		return

	body.tick(delta, DOING[state], target(), velocity, clampf(fed / FULL, 0.0, 1.0), is_exposed(), statuses.has(&"smoked"))


func _exit_tree() -> void:
	_leave_you()
	let_go_of_prey()


func drain_power() -> float:
	return float(_form["power_drain"]) * (SMOKED_DRAIN if statuses.has(&"smoked") else 1.0)


func drain_life() -> float:
	return float(_form["life_drain"]) * (SMOKED_DRAIN if statuses.has(&"smoked") else 1.0)


## Comes up out of where it was laid (a wave's coming).
func rise() -> void:
	_enter(State.RISE)


## Something has stirred it: it comes to, and so do those lying near it.
func rouse() -> void:
	if state != State.REST:
		return

	_enter(State.WAKE)
	Sfx.play(self, &"anima_voice", global_position, -9.0, randf_range(0.8, 1.0))

	for other in get_tree().get_nodes_in_group(&"monsters"):
		if other != self and other.get("kind") == &"anima" and other.state == State.REST and other.global_position.distance_to(global_position) <= STIRS:
			other.rouse()


## On you, at once (a leap that lands).
func put_on_you() -> bool:
	var leech: Node = _leech()

	if leech == null or not leech.latch(self):
		return false

	grip_left = int(_form["grip"])
	ribs_cracked = false
	_enter(State.ON)

	if is_full():
		leech.swallowed_by(self)

	return true


## Knocked off you: thrown clear of `from`, stunned, and exposed.
func throw_off(from: Vector3) -> void:
	_leave_you()
	var away := global_position - from
	away.y = 0.0
	var out: Vector3 = away.normalized() if away.length() > 0.01 else Vector3.BACK
	_push += out * _weighs("throw_speed", THROW_SPEED)

	# (The mouth had you in front of you, unseen: it comes back clear of you, not round your head.)
	if form == &"torso":
		move_and_collide(out * maxf(hit_radius() + THROWN_MOUTH_CLEARS - away.length(), 0.0))
		body.come_back()

	statuses.apply(&"exposed", THROWN_TIME)
	_enter(State.THROWN)


## Torn off you, as a blink does: it comes straight after you.
func let_go() -> void:
	_leave_you()
	_enter(State.RUSH)


func _leave_you() -> void:
	var you: Node3D = target()

	if is_instance_valid(you) and you.get("leech") != null:
		you.leech.release(self)


func _leech() -> Node:
	var you: Node3D = target()
	return you.get("leech") if is_instance_valid(you) else null


func _die(by: Node3D) -> void:
	_leave_you()
	let_go_of_prey()
	var you: Node3D = target()

	if is_instance_valid(you) and you.get("power") != null and fed > 0.0:
		you.power.refund(fed * 0.5)

	# Its body stays to burn; the monster goes out of play.
	if body != null:
		var burning := body
		body = null
		burning.burn_away(get_parent(), _push, target(), death_kind)

	super._die(by)


func _brain(delta: float) -> Vector3:
	_state_t += delta
	_hungry_in = maxf(_hungry_in - delta, 0.0)
	_riled = maxf(_riled - delta, 0.0)

	if is_seized():
		if not is_instance_valid(seized_by) or seized_by.dead or seized_by.asleep or seized_by.prey() != self:
			_dropped()
		else:
			return Vector3.ZERO

	# (Whatever it is doing: a leap and a hold on you never ask for its height.)
	_lift = move_toward(_lift, 0.0, FLUNG_DIES * delta)
	_swipe_in = maxf(_swipe_in - delta, 0.0)
	_leap_in = maxf(_leap_in - delta, 0.0)
	var you: Node3D = target()

	if you == null:
		return _hold_height(Vector3.ZERO, delta)

	if you.get("is_dead") == true:
		return _after_you(you, delta)

	var wish := _wish(you, delta)

	# Nothing of theirs goes into a ward's smoke.
	if WardScript.covers(global_position + Vector3(wish.x, 0.0, wish.z) * delta) and state != State.ON:
		if state == State.LEAP:
			_enter(State.MISSED)

		wish.x = 0.0
		wish.z = 0.0

	# Nor over a line of copal: along it, to get round if it can.
	if state != State.ON:
		var ahead := Vector3(wish.x, 0.0, wish.z)

		if ahead.length() > 0.01:
			var line: Node3D = CopalLine.crossing(get_tree(), global_position, global_position + ahead.normalized() * LINE_LOOKS)

			if line != null:
				if state == State.LEAP:
					_enter(State.MISSED)
					ahead = Vector3.ZERO
				else:
					ahead = line.way_round(global_position, ahead) * ahead.length()

				wish.x = ahead.x
				wish.z = ahead.z

	return wish


## You are dead. What has you finishes; the rest have no more use for you, and crawl off, and rest.
func _after_you(you: Node3D, delta: float) -> Vector3:
	if state == State.ON:
		var leech: Node = _leech()

		if leech != null and leech.slot_of(self) >= 0:
			global_position = leech.slot_position(leech.slot_of(self))
			_push = Vector3.ZERO
			return Vector3.ZERO

		_enter(State.LEAVE)
	elif state != State.LEAVE and state != State.REST and state != State.CROWD:
		_enter(State.CROWD if you.death.holding() and global_position.distance_to(you.global_position) <= CROWD_REACH else State.LEAVE)

	if state == State.CROWD:
		if not you.death.holding():
			_enter(State.LEAVE)
		else:
			var spot := you.global_position + Vector3(cos(_spread_turn), 0.0, sin(_spread_turn)) * CROWD_RING
			var to_spot := spot - global_position
			to_spot.y = 0.0
			return _hold_height(_feel_round(to_spot.limit_length(1.0), delta) * CROWD_SPEED, delta)

	if state == State.LEAVE:
		if _state_t >= LEAVE_TIME:
			_enter(State.REST)
		else:
			var away := global_position - you.global_position
			away.y = 0.0
			return _hold_height(_feel_round(away.normalized(), delta) * LEAVE_SPEED, delta)

	return _hold_height(Vector3.ZERO, delta)


## Stopped dead against something between it and where it is going, it feels along it, the same
## way, till it is past.
func _feel_round(way: Vector3, delta: float) -> Vector3:
	var moved := (global_position - _feel_was) * Vector3(1.0, 0.0, 1.0)
	_feel_was = global_position
	_feel_stuck = _feel_stuck + delta if is_on_wall() and moved.length() < FEEL_MOVES_LESS * delta else 0.0

	if _feel_stuck >= FEEL_AFTER:
		_feel_stuck = 0.0
		_feel_left = FEEL_FOR
		var wall := get_wall_normal()
		_feel_way = Vector3(-wall.z, 0.0, wall.x).normalized()

		# Whichever way along it is nearer where it is going; once chosen, kept, or it dithers.
		if _feel_side == 0.0:
			_feel_side = signf(_feel_way.dot(way)) if absf(_feel_way.dot(way)) > 0.05 else (1.0 if _spread_turn < PI else -1.0)

		_feel_way *= _feel_side

	if _feel_left <= 0.0:
		_feel_keeps = maxf(_feel_keeps - delta, 0.0)
		_feel_side = _feel_side if _feel_keeps > 0.0 else 0.0
		return way

	_feel_left -= delta
	_feel_keeps = FEEL_KEEPS
	return _feel_way


## It has no more use for you.
func lose_interest() -> void:
	_leave_you()
	_enter(State.LEAVE)


## The velocity it wants, as it is now.
func _wish(you: Node3D, delta: float) -> Vector3:
	_look_for_prey(you)
	match state:
		State.RISE:
			if _state_t >= _weighs("rise_time", RISE_TIME):
				_enter(State.REST if rests else State.RUSH)
		State.REST:
			if _state_t >= REST_LONGEST or _chest_distance(you) <= notice:
				rouse()
		State.WAKE:
			if _state_t >= _weighs("wake_time", WAKE_TIME):
				_enter(State.RUSH)
		State.RUSH:
			var reach: float = float(_form["leap_reach"])
			var close: float = float(_form["swipe_reach"])
			var leech: Node = _leech()
			var far: float = _chest_distance(you)
			var line_clear: bool = CopalLine.crossing(get_tree(), global_position, _chest(you)) == null
			var waits_by := elite_near()

			# With you far off, the small ones stay round what they will feed.
			if waits_by != null and far > reach * WAITS_WHILE_YOU_ARE and _riled <= 0.0:
				if _wait_turn < 0.0:
					_wait_turn = waits_by.place_round_it()

				_wait_turn = fposmod(_wait_turn + WAITS_GO_ROUND * delta, TAU)
				var spot: Vector3 = waits_by.global_position + Vector3(cos(_wait_turn), 0.0, sin(_wait_turn)) * WAITS_ROUND
				var to_spot: Vector3 = (spot - global_position) * Vector3(1.0, 0.0, 1.0)
				return _hold_height(_feel_round(to_spot.limit_length(1.0), delta) * float(_form["speed"]) * WAITS_PACE * _slowed(), delta)

			if far <= close:
				if _swipe_in <= 0.0 and line_clear:
					_enter(State.WIND_UP)
				else:
					return _hold_height(_round_you(you) * _weighs("edges_round", EDGES_ROUND), delta)
			elif leech != null and not leech.has_room() and far <= CIRCLE_AT and _swipe_in > 0.0:
				_enter(State.CIRCLE)
			elif far <= reach and (leech == null or leech.has_room()) and line_clear and _leap_in <= 0.0:
				_leap_in = LEAP_EVERY

				if randf() < leap_chance:
					_enter(State.TELL)
			else:
				return _hold_height(_feel_round(_toward(you), delta) * float(_form["speed"]) * _pace() * _slowed(), delta)
		State.CIRCLE:
			var leech: Node = _leech()

			# Waiting its turn on you, it can still come in and cut you.
			if leech == null or leech.has_room() or _swipe_in <= 0.0:
				_enter(State.RUSH)
			else:
				var round_you := (global_position - you.global_position)
				round_you.y = 0.0
				var side := Vector3(-round_you.z, 0.0, round_you.x).normalized()
				var in_out := round_you.normalized() * (CIRCLE_AT - round_you.length())
				return _hold_height(side * _weighs("circle_speed", CIRCLE_SPEED) + in_out, delta)
		State.WIND_UP:
			if _state_t >= float(_form["swipe_wind"]):
				_swung = false
				Sfx.play(self, &"anima_voice", global_position, -11.0, randf_range(1.0, 1.25))
				_enter(State.SWIPE)
		State.SWIPE:
			var swing_takes := _weighs("swipe_time", SWIPE_TIME)

			if not _swung and _state_t >= swing_takes * 0.5:
				_swung = true
				_cut(you)

			if _state_t >= swing_takes:
				_swung = false
				_swipe_in = _weighs("back_off_time", BACK_OFF_TIME) + randf_range(SWIPE_EVERY.x, SWIPE_EVERY.y)
				_back_way = ((global_position - you.global_position) * Vector3(1.0, 0.0, 1.0)).normalized() + _round_you(you) * 0.6
				_enter(State.BACK_OFF)
			else:
				return _hold_height(_toward(you) * _weighs("swipe_lunge", SWIPE_LUNGE), delta)
		State.BACK_OFF:
			if _state_t >= _weighs("back_off_time", BACK_OFF_TIME):
				_enter(State.RUSH)
			else:
				return _hold_height(_back_way * _weighs("back_off_speed", BACK_OFF_SPEED) * _slowed(), delta)
		State.REACH:
			return _reach_for_prey(delta)
		State.DRAG:
			return _drag_in_prey(delta)
		State.TELL:
			if _state_t >= float(_form["tell"]):
				_leap_way = (_chest(you) - global_position).normalized()
				_enter(State.LEAP)
		State.LEAP:
			var gathers := _weighs("leap_gathers", 0.0)
			var takes: float = float(_form["leap_reach"]) / float(_form["leap_speed"]) + gathers * 0.5

			if _chest_distance(you) <= LATCH_REACH and _lands_on(you):
				_enter(State.ON)
				return Vector3.ZERO

			if _state_t >= takes:
				_comes_down()
				_enter(State.MISSED)
			else:
				# (What weighs anything gets going slowly: it goes over, rather than springs.)
				var going := clampf(_state_t / gathers, LEAP_STARTS_AT, 1.0) if gathers > 0.0 else 1.0
				return _leap_way * float(_form["leap_speed"]) * going
		State.ON:
			var leech: Node = _leech()

			if leech == null or leech.slot_of(self) < 0:
				_enter(State.RUSH)
			else:
				global_position = leech.slot_position(leech.slot_of(self))
				_push = Vector3.ZERO
				return Vector3.ZERO
		State.MISSED:
			if _state_t >= _weighs("missed_time", MISSED_TIME):
				_enter(State.RUSH)
		State.THROWN:
			if _state_t >= THROWN_TIME:
				_enter(State.RUSH)

	return _hold_height(Vector3.ZERO, delta)


## The way round you, its own side of you.
func _round_you(you: Node3D) -> Vector3:
	var off := global_position - you.global_position
	off.y = 0.0
	var side := Vector3(-off.z, 0.0, off.x).normalized()
	return side if _spread_turn < PI else -side


## The swing lands, if you are still in reach and not out of its way.
func _cut(you: Node3D) -> void:
	var dodged: bool = you.get("combat") != null and you.combat.is_dodging()
	var clear: bool = CopalLine.crossing(get_tree(), global_position, _chest(you)) == null
	var cut: bool = _chest_distance(you) <= float(_form["swipe_reach"]) + SWIPE_FINDS and not dodged and clear and you.get("is_dead") != true

	Sfx.play(self, &"whoosh_light", global_position, -7.0, randf_range(0.7, 0.95))

	if cut:
		# (First: if it kills you, you fall away from this side.)
		if you.get("hud") != null and you.hud.has_method("claw_at"):
			var side: float = you.camera.to_local(global_position).x if you.get("camera") != null else 1.0
			you.hud.claw_at(side)

		you.take_damage(float(_form["swipe_damage"]), self)
		Sfx.play(self, &"flesh", global_position, -6.0, randf_range(0.9, 1.15))

		var juice = you.get("juice")

		if juice != null:
			juice.add_trauma(CUT_TRAUMA)
			juice.punch(0.0, 0.0, CUT_ROLL * (-1.0 if randf() < 0.5 else 1.0))

	swiped.emit(cut)


func _chest(you: Node3D) -> Vector3:
	return you.global_position + Vector3.UP * 0.15


func _chest_distance(you: Node3D) -> float:
	return global_position.distance_to(_chest(you))


## It doesn't run at you: it creeps, shaking, slow enough to hit, and then the hunger
## takes it and it surges a little way, and creeps again. Its own rhythm, not the others'.
## How fast it goes for now, of its speed. What hauls itself goes as its arms do; the rest in surges.
func _pace() -> float:
	if not _form.get("hauls", false) or body == null:
		return _hunger()

	var done: int = body.hauls_done()

	if done != _hauls_heard:
		_hauls_heard = done
		_thud(-13.0, HAUL_SHAKES, HAUL_FELT)

	return float(body.lurch())


## What this form's weight says, if it says, or what they all do.
func _weighs(what: String, otherwise: float) -> float:
	return float(_form.get(what, otherwise))


## All that weight, come down: it carries on a little, and you feel it through the floor if you're near.
func _comes_down() -> void:
	if not _form.has("inertia"):
		return

	_carried = Vector3(velocity.x, 0.0, velocity.z) * COMES_DOWN_CARRIES
	_thud(-2.0, COMES_DOWN_SHAKES, COMES_DOWN_FELT)


## It lands: you hear it, and if you are near, you feel it through the floor.
func _thud(loudness: float, shakes: float, felt_from: float) -> void:
	Sfx.play(self, &"flesh", global_position, loudness, randf_range(0.38, 0.46))
	var you: Node3D = target()
	var juice: Variant = you.get("juice") if you != null else null

	if juice != null:
		juice.add_trauma(shakes * (1.0 - smoothstep(1.0, felt_from, global_position.distance_to(you.global_position))))


func _hunger() -> float:
	_surge_in -= get_physics_process_delta_time()

	if _surge_in <= 0.0:
		_surge_left = SURGE_TIME
		_surge_in = SURGE_TIME + randf_range(SURGE_EVERY.x, SURGE_EVERY.y)
		Sfx.play(self, &"anima_voice", global_position, -9.0, randf_range(0.7, 0.95))
		Sfx.play(self, &"gear", global_position, -20.0, randf_range(0.5, 0.75))

	_surge_left = maxf(_surge_left - get_physics_process_delta_time(), 0.0)
	return SURGE if _surge_left > 0.0 else CREEP


func _slowed() -> float:
	return SMOKED_SPEED if statuses.has(&"smoked") else 1.0


## Whether a leap this close gets its hands on you.
func _lands_on(you: Node3D) -> bool:
	var leech: Node = _leech()

	if leech == null or statuses.has(&"smoked"):
		return false

	if you.get("combat") != null and you.combat.is_dodging():
		return false

	if WardScript.covers(_chest(you)):
		return false

	return put_on_you()


func _enter(next: int) -> void:
	# Whatever takes it off what it was feeding on, it lets go.
	if next != State.REACH and next != State.DRAG:
		let_go_of_prey()

	state = next
	_state_t = 0.0
	_sounds_for(next)


## Which way to go to get at you: along the navmesh if there is one, spread out to
## one side of you while it is still far off.
func _toward(you: Node3D) -> Vector3:
	var to: Vector3 = you.global_position - global_position
	var far: float = to.length()
	var goal: Vector3 = you.global_position

	if far > float(_form["leap_reach"]) * 1.5:
		goal += Vector3(cos(_spread_turn), 0.0, sin(_spread_turn)) * SPREAD

	to = goal - global_position
	to.y = 0.0

	if _agent != null and NavigationServer3D.map_get_iteration_id(_agent.get_navigation_map()) > 0:
		_agent.target_position = goal
		var along: Vector3 = _agent.get_next_path_position() - global_position
		along.y = 0.0

		# (A map with nothing baked on it gives no way at all: straight, then.)
		if along.length() > 0.05:
			to = along

	return to.normalized() if to.length() > 0.01 else Vector3.ZERO


## Crawlers fall to the floor; a face holds its height. Either can be flung up off it.
func _hold_height(wanted: Vector3, delta: float) -> Vector3:
	var inertia := _weighs("inertia", 0.0)

	if inertia > 0.0:
		_carried = _carried.move_toward(Vector3(wanted.x, 0.0, wanted.z), inertia * delta)
		wanted.x = _carried.x
		wanted.z = _carried.z

	if bool(_form["floats"]):
		wanted.y = (float(_form["height"]) - global_position.y) * FLOAT_RATE * (1.0 if _lift <= 0.0 else 0.0) + _lift
		return wanted

	_fall = 0.0 if is_on_floor() and _lift <= 0.0 else _fall + GRAVITY * delta
	wanted.y = _lift - _fall
	return wanted


## Glass has gone through it: it is knocked, and goes on. No stun, no opening.
func jolted(way: Vector3) -> void:
	_lift = maxf(_lift, JOLT_UP)
	_fall = 0.0

	if body != null:
		body.jolt(way)


## Thrown up off its feet by the wave, and over. Nothing else changes: no stun, no opening.
func flung_up(from: Vector3) -> void:
	_lift = FLUNG_UP
	_fall = 0.0

	if body != null:
		body.tumble(global_position - from)


func _on_struck(result: StringName, source: StringName) -> void:
	if result == &"killed":
		return

	_riled = RILED_FOR

	if body != null:
		body.struck(last_hit_at, last_hit_way, result, source)

	rouse()

	# A hit from anything but lead breaks its leap, or its swing.
	if (state == State.TELL or state == State.WIND_UP or state == State.REACH or state == State.DRAG) and source != &"lead":
		throw_off(target().global_position if target() != null else global_position + Vector3.FORWARD)
	elif state == State.ON:
		# Copal loosens it at once; a blow, once its grip is spent.
		if source == &"copal" or source == &"blast":
			throw_off(target().global_position)
		elif source == &"blow":
			grip_left -= 1

			if grip_left <= 0:
				throw_off(target().global_position)
			else:
				# It holds on, what it holds you with broken.
				ribs_cracked = true
				Sfx.play(self, &"bone_crack", global_position, 0.0, 0.8)
