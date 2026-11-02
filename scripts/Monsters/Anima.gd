extends "res://scripts/Monsters/Monster.gd"
## A ravenous ánima: a soul no one lit a candle for, past begging. It comes up out
## of a drain and may lie there a while (`rests`) until something stirs it; then it rushes
## you, tells, and leaps to get on you and drink your willpower and your life. Its forms are data (Bestiary): withered hands, hands and a face, a
## torso dragged by its arms. Lead passes through it. A hit in its tell from anything
## else breaks the leap and opens it up. The Metro's beggars (Animas.gd) are another
## thing altogether.

const AnimaBody := preload("res://scripts/Monsters/AnimaBody.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")
const WardScript := preload("res://scripts/Magic/Ward.gd")
const CopalLine := preload("res://scripts/Hunt/CopalLine.gd")

enum State { RISE, RUSH, CIRCLE, TELL, LEAP, MISSED, ON, THROWN, REST, WAKE }

const DOING := {
	State.RISE: &"rise", State.RUSH: &"rush", State.CIRCLE: &"circle", State.TELL: &"tell",
	State.LEAP: &"leap", State.MISSED: &"missed", State.ON: &"on", State.THROWN: &"thrown",
	State.REST: &"rest", State.WAKE: &"wake",
}
const RISE_TIME := 0.5
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

@export var form: StringName = &"hands"
## Lies where it came up until something stirs it.
@export var rests := false
## How near you can come before it stirs (m).
var notice := NOTICE
## Which of its form's deaths it dies (AnimaDeaths.gd), or any.
var death_kind := -1
var state: int = State.RISE
var body: Node3D
var whip_reach := 1.6
## What it has drunk of your power. Half of it comes back when it dies.
var fed := 0.0
## Whips it can still take before it is thrown off (from its form).
var grip_left := 1

var _form := {}
var _state_t := 0.0
var _leap_way := Vector3.ZERO
var _spread_turn := 0.0
var _agent: NavigationAgent3D
var _fall := 0.0
var _surge_in := 0.6
var _surge_left := 0.0
var _lift := 0.0


func _init() -> void:
	kind = &"anima"


func hit_radius() -> float:
	return float(Bestiary.form(&"anima", form).get("hit_radius", DEFAULT_RADIUS))


## A crawler's body rests on the floor, whatever reach its hands have.
func _body_shape() -> Shape3D:
	var sphere := SphereShape3D.new()
	sphere.radius = minf(hit_radius(), float(_form.get("height", 0.3)))
	return sphere


func _ready() -> void:
	_form = Bestiary.form(&"anima", form)
	health = float(_form["health"])
	grip_left = int(_form["grip"])
	super._ready()
	_spread_turn = TAU * fmod(absf(position.x) * 0.37 + absf(position.z) * 0.61, 1.0)
	_agent = NavigationAgent3D.new()
	_agent.path_desired_distance = 0.6
	_agent.target_desired_distance = 0.6
	add_child(_agent)
	body = AnimaBody.new()
	body.name = "Body"
	body.form = form
	add_child(body)
	struck.connect(_on_struck)


func _is_opening() -> bool:
	return state == State.TELL


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
	_enter(State.ON)
	return true


## Knocked off you: thrown clear of `from`, stunned, and exposed.
func throw_off(from: Vector3) -> void:
	_leave_you()
	var away := global_position - from
	away.y = 0.0
	_push += away.normalized() * THROW_SPEED if away.length() > 0.01 else Vector3.BACK * THROW_SPEED
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
	# (Whatever it is doing: a leap and a hold on you never ask for its height.)
	_lift = move_toward(_lift, 0.0, FLUNG_DIES * delta)
	var you: Node3D = target()

	if you == null:
		return _hold_height(Vector3.ZERO, delta)

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


## The velocity it wants, as it is now.
func _wish(you: Node3D, delta: float) -> Vector3:
	match state:
		State.RISE:
			if _state_t >= RISE_TIME:
				_enter(State.REST if rests else State.RUSH)
		State.REST:
			if _state_t >= REST_LONGEST or _chest_distance(you) <= notice:
				rouse()
		State.WAKE:
			if _state_t >= WAKE_TIME:
				_enter(State.RUSH)
		State.RUSH:
			var reach: float = float(_form["leap_reach"])
			var leech: Node = _leech()

			if leech != null and not leech.has_room() and global_position.distance_to(you.global_position) <= CIRCLE_AT:
				_enter(State.CIRCLE)
			elif _chest_distance(you) <= reach and (leech == null or leech.has_room()) and CopalLine.crossing(get_tree(), global_position, _chest(you)) == null:
				_enter(State.TELL)
			else:
				return _hold_height(_toward(you) * float(_form["speed"]) * _hunger() * _slowed(), delta)
		State.CIRCLE:
			var leech: Node = _leech()

			if leech == null or leech.has_room():
				_enter(State.RUSH)
			else:
				var round_you := (global_position - you.global_position)
				round_you.y = 0.0
				var side := Vector3(-round_you.z, 0.0, round_you.x).normalized()
				var in_out := round_you.normalized() * (CIRCLE_AT - round_you.length())
				return _hold_height(side * CIRCLE_SPEED + in_out, delta)
		State.TELL:
			if _state_t >= float(_form["tell"]):
				_leap_way = (_chest(you) - global_position).normalized()
				_enter(State.LEAP)
		State.LEAP:
			var takes: float = float(_form["leap_reach"]) / float(_form["leap_speed"])

			if _chest_distance(you) <= LATCH_REACH and _lands_on(you):
				_enter(State.ON)
				return Vector3.ZERO

			if _state_t >= takes:
				_enter(State.MISSED)
			else:
				return _leap_way * float(_form["leap_speed"])
		State.ON:
			var leech: Node = _leech()

			if leech == null or leech.slot_of(self) < 0:
				_enter(State.RUSH)
			else:
				global_position = leech.slot_position(leech.slot_of(self))
				_push = Vector3.ZERO
				return Vector3.ZERO
		State.MISSED:
			if _state_t >= MISSED_TIME:
				_enter(State.RUSH)
		State.THROWN:
			if _state_t >= THROWN_TIME:
				_enter(State.RUSH)

	return _hold_height(Vector3.ZERO, delta)


func _chest(you: Node3D) -> Vector3:
	return you.global_position + Vector3.UP * 0.15


func _chest_distance(you: Node3D) -> float:
	return global_position.distance_to(_chest(you))


## It doesn't run at you: it creeps, shaking, slow enough to hit, and then the hunger
## takes it and it surges a little way, and creeps again. Its own rhythm, not the others'.
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
	state = next
	_state_t = 0.0


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

	if body != null:
		body.struck(last_hit_at, last_hit_way, result, source)

	rouse()

	# A hit from anything but lead breaks its leap.
	if state == State.TELL and source != &"lead":
		throw_off(target().global_position if target() != null else global_position + Vector3.FORWARD)
	elif state == State.ON:
		# Copal loosens it at once; a blow, once its grip is spent.
		if source == &"copal" or source == &"blast":
			throw_off(target().global_position)
		elif source == &"blow":
			grip_left -= 1

			if grip_left <= 0:
				throw_off(target().global_position)
