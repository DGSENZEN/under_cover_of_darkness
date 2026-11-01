extends "res://scripts/Monsters/Monster.gd"
## A floating eye: mal de ojo got loose after the Eclipse, envy made flesh. They
## come in packs. Each circles you out of reach, holds still a moment with its
## pupil wide (its tell), then swoops through where you were and bounces off,
## staggering. A swoop can be dodged. While one has you in its line it looks at
## you, and looked at long enough you carry the evil eye (Statuses, what it does:
## PlayerController._feel_statuses). A single ball hardly marks one; shot, a
## shard or copal do (Bestiary). Copal smoke blinds it: slow, no gaze, no swoop.
## A stand-in body until its model is made.

const Sfx := preload("res://scripts/Audio/Sfx.gd")
const Fx := preload("res://scripts/Visual/Fx.gd")

enum State { DRIFT, CIRCLE, TELL, SWOOP, BOUNCE }

## Sees you this far, with a clear line (m).
const NOTICE := 18.0
const CIRCLE_RADIUS := Vector2(6.0, 9.0)
const CIRCLE_HEIGHT := Vector2(1.6, 3.0)
const CIRCLE_SPEED := 5.5
const ORBIT_AHEAD := 0.5
## Seconds circling between swoops.
const SWOOP_WAIT := Vector2(1.5, 3.5)
const TELL_TIME := 0.5
## How far through the tell it fixes on where you are: leave after that and it
## misses.
const TELL_FIXES := 0.35
const SWOOP_SPEED := 11.0
## It flies this far past where it aimed before it gives up.
const SWOOP_PAST := 3.0
const SWOOP_MOST := 1.6
const BOUNCE_TIME := 0.7
const BITE := 12.0
## How near your capsule's middle line a bite lands (m).
const BITE_REACH := 0.8
const GAZE_RANGE := 12.0
## Seconds of being looked at, across the pack; a look away this long starts over.
const GAZE_TO_CURSE := 2.0
const GAZE_FORGOTTEN := 1.0
const EVIL_EYE_TIME := 8.0
## At once, across the pack, in a tell or a swoop.
const MOST_SWOOPING := 2
const SMOKED_SPEED := 0.6
const LINE_EVERY := 6
const HIT_RADIUS := 0.42
const BODY_RADIUS := 0.36
const FEELER := 1.4

var state := State.DRIFT
## Its own dice, so a pack's flight can be repeated.
@export var seed_value := 1
## Seconds left circling before it wants to swoop.
var next_swoop_in := 2.0

var _rng := RandomNumberGenerator.new()
var _ticks := 0
var _clear_line := false
var _state_t := 0.0
var _radius := 7.0
var _height := 2.0
var _orbit := 0.0
var _orbit_way := 1.0
var _home := Vector3.ZERO
var _swoop_from := Vector3.ZERO
var _swoop_at := Vector3.ZERO
var _swoop_way := Vector3.FORWARD
var _bitten := false
var _body_mesh: Node3D


func _init() -> void:
	kind = &"floating_eye"


## Big enough for a shell's ring to find within 6 m.
func _body_shape() -> Shape3D:
	var sphere := SphereShape3D.new()
	sphere.radius = HIT_RADIUS
	return sphere


func _ready() -> void:
	super._ready()
	_rng.seed = seed_value
	_ticks = 0
	_home = position
	_radius = _rng.randf_range(CIRCLE_RADIUS.x, CIRCLE_RADIUS.y)
	_height = _rng.randf_range(CIRCLE_HEIGHT.x, CIRCLE_HEIGHT.y)
	_orbit_way = 1.0 if _rng.randf() < 0.5 else -1.0
	next_swoop_in = _rng.randf_range(SWOOP_WAIT.x, SWOOP_WAIT.y)
	_build_body()


func _build_body() -> void:
	_body_mesh = Node3D.new()
	add_child(_body_mesh)
	var ball := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = BODY_RADIUS
	sphere.height = BODY_RADIUS * 2.0
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.78, 0.72, 0.62)
	sphere.material = white
	ball.mesh = sphere
	_body_mesh.add_child(ball)
	var pupil := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.14
	disc.bottom_radius = 0.14
	disc.height = 0.02
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.05, 0.03, 0.03)
	disc.material = dark
	pupil.mesh = disc
	pupil.rotation.x = PI * 0.5
	pupil.position.z = -BODY_RADIUS + 0.005
	_body_mesh.add_child(pupil)


func _brain(delta: float) -> Vector3:
	_ticks += 1
	_state_t += delta
	var you: Node3D = target()

	if you == null or you.get("is_dead") == true:
		if state != State.DRIFT:
			_enter(State.DRIFT)

		return _drift()

	if _ticks % LINE_EVERY == 1:
		_clear_line = _line_to(you)

	var smoked: bool = statuses.has(&"smoked")
	_gaze(you, delta, smoked)
	_turn_to(you)

	if is_exposed() and state != State.BOUNCE:
		_enter(State.BOUNCE)

	match state:
		State.DRIFT:
			if _clear_line and global_position.distance_to(you.global_position) <= NOTICE:
				_enter(State.CIRCLE)

			return _drift()
		State.CIRCLE:
			next_swoop_in -= delta

			if not smoked and next_swoop_in <= 0.0 and _clear_line and _room_to_swoop():
				_enter(State.TELL)
				return Vector3.ZERO

			return _circle(you) * (SMOKED_SPEED if smoked else 1.0)
		State.TELL:
			if smoked:
				_enter(State.CIRCLE)
				return Vector3.ZERO

			if _state_t < TELL_FIXES:
				_swoop_at = you.global_position + Vector3(0.0, 0.3, 0.0)
			elif _state_t >= TELL_TIME:
				_launch()

			return Vector3.ZERO
		State.SWOOP:
			return _swoop(you)
		State.BOUNCE:
			if _state_t >= BOUNCE_TIME:
				next_swoop_in = _rng.randf_range(SWOOP_WAIT.x, SWOOP_WAIT.y)
				_enter(State.CIRCLE)

			return (Vector3.UP * 3.0 - _swoop_way * 2.5) * (1.0 - _state_t / BOUNCE_TIME)

	return Vector3.ZERO


func _enter(next: State) -> void:
	state = next
	_state_t = 0.0


func _drift() -> Vector3:
	return Vector3(0.0, sin(float(_ticks) * 0.05) * 0.3, 0.0)


func _circle(you: Node3D) -> Vector3:
	var from_you := global_position - you.global_position
	# A little way on round you, so it keeps its pace.
	_orbit = atan2(from_you.x, from_you.z) + _orbit_way * ORBIT_AHEAD
	var wanted := you.global_position + Vector3(sin(_orbit), 0.0, cos(_orbit)) * _radius
	# Its height is above your feet.
	wanted.y = you.global_position.y - 1.0 + _height
	return _steer((wanted - global_position).normalized() * CIRCLE_SPEED)


## Off a wall ahead rather than into it; and if nothing will take it there, the
## other way round.
func _steer(way: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var ahead := way.normalized() * FEELER
	var query := PhysicsRayQueryParameters3D.create(global_position, global_position + ahead, 1, [get_rid()])
	var hit := space.intersect_ray(query)

	if hit.is_empty():
		return way

	_orbit_way = -_orbit_way if _ticks % 120 == 0 else _orbit_way
	var along: Vector3 = way.slide(hit["normal"])
	return (along + Vector3(hit["normal"]) * 1.5 + Vector3.UP * 0.8).limit_length(way.length())


func _line_to(you: Node3D) -> bool:
	var query := PhysicsRayQueryParameters3D.create(global_position, you.global_position + Vector3(0.0, 0.6, 0.0), 1, [get_rid(), you.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## Being looked at, over the pack: kept on you, and forgotten after a look away.
func _gaze(you: Node3D, delta: float, smoked: bool) -> void:
	if smoked or not _clear_line or state == State.DRIFT or state == State.BOUNCE or global_position.distance_to(you.global_position) > GAZE_RANGE:
		return

	var bearer: Node = you.get("statuses")

	if bearer == null:
		return

	var now := _game_time
	var last: float = you.get_meta(&"gaze_last", -100.0)
	var held: float = you.get_meta(&"gaze", 0.0) if now - last <= GAZE_FORGOTTEN else 0.0
	held += delta
	you.set_meta(&"gaze_last", now)

	if held >= GAZE_TO_CURSE:
		bearer.apply(&"evil_eye", EVIL_EYE_TIME)
		held = 0.0

	you.set_meta(&"gaze", held)


func _room_to_swoop() -> bool:
	var busy := 0

	for other in get_tree().get_nodes_in_group(&"monsters"):
		if other != self and other.get("state") != null and not other.dead and not other.asleep and (other.state == State.TELL or other.state == State.SWOOP):
			busy += 1

	return busy < MOST_SWOOPING


func _launch() -> void:
	Sfx.play(self, &"whoosh_light", global_position, -2.0, 0.7)
	_swoop_from = global_position
	_swoop_way = (_swoop_at - _swoop_from).normalized()
	_bitten = false
	_enter(State.SWOOP)


func _swoop(you: Node3D) -> Vector3:
	if not _bitten and _touching(you):
		_bitten = true
		Sfx.play(self, &"thud", global_position, -4.0, 1.3)
		you.take_damage(BITE, self)

	var flown := (global_position - _swoop_from).dot(_swoop_way)
	var aimed_for := _swoop_from.distance_to(_swoop_at)

	if flown >= aimed_for + SWOOP_PAST or _state_t >= SWOOP_MOST or get_slide_collision_count() > 0:
		_enter(State.BOUNCE)
		return Vector3.ZERO

	return _swoop_way * SWOOP_SPEED


## It bursts.
func _die(by: Node3D) -> void:
	Fx.blood(self, global_position, Vector3.UP, 1.2)
	Sfx.play(self, &"arrow_flesh", global_position, 0.0, 0.8)
	super._die(by)


## Within reach of the line down your middle.
func _touching(you: Node3D) -> bool:
	var at := you.global_position
	var nearest := Vector3(at.x, clampf(global_position.y, at.y - 0.5, at.y + 0.5), at.z)
	return global_position.distance_to(nearest) <= BITE_REACH


func _turn_to(you: Node3D) -> void:
	if _body_mesh != null and global_position.distance_to(you.global_position) > 0.2:
		_body_mesh.look_at(you.global_position + Vector3(0.0, 0.6, 0.0), Vector3.UP)
