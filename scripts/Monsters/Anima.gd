extends "res://scripts/Monsters/Monster.gd"
## A ravenous ánima: a soul no one lit a candle for, past begging. It comes up out
## of a drain, rushes you, tells, and leaps to get on you and drink your willpower
## and your life. Its forms are data (Bestiary): withered hands, hands and a face, a
## torso dragged by its arms. Lead passes through it. A hit in its tell from anything
## else breaks the leap and opens it up. The Metro's beggars (Animas.gd) are another
## thing altogether.

const AnimaBody := preload("res://scripts/Monsters/AnimaBody.gd")

enum State { RISE, RUSH, CIRCLE, TELL, LEAP, MISSED, ON, THROWN }

const DOING := {
	State.RISE: &"rise", State.RUSH: &"rush", State.CIRCLE: &"circle", State.TELL: &"tell",
	State.LEAP: &"leap", State.MISSED: &"missed", State.ON: &"on", State.THROWN: &"thrown",
}
const RISE_TIME := 0.5
const MISSED_TIME := 0.8
## Thrown off: how long it is stunned and exposed, how hard it is thrown.
const THROWN_TIME := 1.5
const THROW_SPEED := 9.0
## They spread out, so they come at you from more than one side (m beside you).
const SPREAD := 1.6
const GRAVITY := 18.0
## How quickly a face holds its height.
const FLOAT_RATE := 4.0

@export var form: StringName = &"hands"
var state: int = State.RISE
var body: Node3D
var whip_reach := 1.6

var _form := {}
var _state_t := 0.0
var _leap_way := Vector3.ZERO
var _spread_turn := 0.0
var _agent: NavigationAgent3D
var _fall := 0.0


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

	body.tick(delta, DOING[state], target(), velocity, 0.0, is_exposed(), statuses.has(&"smoked"))


func _brain(delta: float) -> Vector3:
	_state_t += delta
	var you: Node3D = target()

	if you == null:
		return _hold_height(Vector3.ZERO, delta)

	match state:
		State.RISE:
			if _state_t >= RISE_TIME:
				_enter(State.RUSH)
		State.RUSH:
			var reach: float = float(_form["leap_reach"])

			if global_position.distance_to(you.global_position) <= reach:
				_leap_way = (you.global_position - global_position).normalized()
				_enter(State.TELL)
			else:
				return _hold_height(_toward(you) * float(_form["speed"]), delta)
		State.TELL:
			if _state_t >= float(_form["tell"]):
				_leap_way = (you.global_position - global_position).normalized()
				_enter(State.LEAP)
		State.LEAP:
			var takes: float = float(_form["leap_reach"]) / float(_form["leap_speed"])

			if _state_t >= takes:
				_enter(State.MISSED)
			else:
				return _leap_way * float(_form["leap_speed"])
		State.MISSED:
			if _state_t >= MISSED_TIME:
				_enter(State.RUSH)
		State.THROWN:
			if _state_t >= THROWN_TIME:
				_enter(State.RUSH)

	return _hold_height(Vector3.ZERO, delta)


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


## Crawlers fall to the floor; a face holds its height.
func _hold_height(wanted: Vector3, delta: float) -> Vector3:
	if bool(_form["floats"]):
		wanted.y = (float(_form["height"]) - global_position.y) * FLOAT_RATE
		return wanted

	_fall = 0.0 if is_on_floor() else _fall + GRAVITY * delta
	wanted.y = -_fall
	return wanted


func _on_struck(result: StringName, source: StringName) -> void:
	if result == &"killed":
		return

	if body != null:
		body.struck(global_position, Vector3.FORWARD, result)

	# A hit from anything but lead breaks its leap.
	if state == State.TELL and source != &"lead":
		_enter(State.THROWN)
