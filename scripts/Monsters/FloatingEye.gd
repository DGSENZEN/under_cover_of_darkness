extends "res://scripts/Monsters/Monster.gd"
## A floating eye: mal de ojo got loose after the Eclipse, envy made flesh. They
## come in packs. Each circles you out of reach, holds still a moment with its
## pupil wide (its tell), then swoops through where you were and bounces off,
## staggering. A swoop can be dodged. While one has you in its line it looks at
## you, and looked at long enough you carry the evil eye (Statuses, what it does:
## PlayerController._feel_statuses). A single ball hardly marks one; shot, a
## shard or copal do (Bestiary). Copal smoke blinds it: slow, no gaze, no swoop.
## A hit in its tell breaks it off and opens it up, whatever the round (the
## Monster's opening). A swoop can be batted back with the whip or the boot, into
## a wall or another eye. The Ward hides you from it, and smokes it if it flies
## in. Badly hurt, it turns, once: torn open, worse to look at, and it spits its curse at you too
## (EyeGob).

const Sfx := preload("res://scripts/Audio/Sfx.gd")
const Fx := preload("res://scripts/Visual/Fx.gd")
const EyeGob := preload("res://scripts/Monsters/EyeGob.gd")
const WardScript := preload("res://scripts/Magic/Ward.gd")
const EyeBody := preload("res://scripts/Monsters/EyeBody.gd")

enum State { DRIFT, CIRCLE, TELL, SWOOP, BOUNCE, BATTED, DAZED, SPIT_UP }
const DOING: Array[StringName] = [&"drift", &"circle", &"tell", &"swoop", &"bounce", &"batted", &"dazed", &"spit_up"]

## It has turned worse.
signal turned_worse

## It turns at this share of its health or under. Then, circling, it spits this often, and takes
## this long gathering it.
const TURNS_AT := 0.5
const SPIT_EVERY := Vector2(2.5, 4.0)
const SPIT_WIND := 0.55
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
## Seconds of being looked at, across the pack.
const GAZE_TO_CURSE := 2.0
const GAZE_TO_DEEPEN := 5.0
const EVIL_EYE_TIME := 8.0
## At once, across the pack, in a tell or a swoop.
const MOST_SWOOPING := 2
const SMOKED_SPEED := 0.6
## Batted out of a swoop (the whip, the boot): how fast, how long, what it does
## to itself on a wall and to another eye it meets.
const BAT_SPEED := 14.0
const BAT_TIME := 0.6
const BAT_HURT := 40.0
const BAT_MEET := 0.95
## How far off the whip can meet a swooping one (m), and one that isn't.
const WHIP_SWOOPING := 3.2
const WHIP_CLOSE := 1.3
## A packmate burst this near (m): it pulls out this much further for this long,
## and waits this much longer to swoop.
const FLINCH_WITHIN := 14.0
const FLINCH_OUT := 2.0
const FLINCH_TIME := 3.0
const FLINCH_WAIT := 1.5
## The limpia sent back on it (the egg): how long it stays shut, how fast it sinks
## and how low.
const DAZED_TIME := 4.0
const LIMPIA_THROW := 4.0
const DAZED_SINK := 0.7
const DAZED_LOWEST := 0.9
const LINE_EVERY := 6
const HIT_RADIUS := 0.42
const FEELER := 1.4

var state := State.DRIFT
## Its own dice, so a pack's flight can be repeated.
@export var seed_value := 1
## Seconds left circling before it wants to swoop.
var next_swoop_in := 2.0
## Whether it has turned, whether it starts so (a check's or a still's), and when it next spits.
var turned := false
var start_turned := false
var spit_in := 2.0
## Whether it is staring at you right now (the HUD marks where from).
var gazing := false

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
var _bat_way := Vector3.FORWARD
var _flinch_left := 0.0
var _bitten := false
## How it looks and moves (EyeBody).
var body: Node3D


func _init() -> void:
	kind = &"floating_eye"


## Big enough for a shell's ring to find within 6 m.
func hit_radius() -> float:
	return HIT_RADIUS


func _ready() -> void:
	super._ready()
	_rng.seed = seed_value
	_ticks = 0
	_home = position
	_radius = _rng.randf_range(CIRCLE_RADIUS.x, CIRCLE_RADIUS.y)
	_height = _rng.randf_range(CIRCLE_HEIGHT.x, CIRCLE_HEIGHT.y)
	_orbit_way = 1.0 if _rng.randf() < 0.5 else -1.0
	next_swoop_in = _rng.randf_range(SWOOP_WAIT.x, SWOOP_WAIT.y)
	exposed_now.connect(_stagger)
	turned = start_turned
	spit_in = _rng.randf_range(SPIT_EVERY.x, SPIT_EVERY.y)
	_build_body()


func _is_opening() -> bool:
	return state == State.TELL or state == State.DAZED or state == State.SPIT_UP


func _max_health() -> float:
	return float(Bestiary.info(kind)["health"])


## Torn open, from inside. Once.
func turn() -> void:
	if turned or dead:
		return

	turned = true
	spit_in = _rng.randf_range(SPIT_EVERY.x, SPIT_EVERY.y)
	Fx.blood(self, global_position, Vector3.UP, 3.0)
	Fx.flash(self, global_position, Color(0.9, 0.12, 0.08), 1.2, 4.0, 0.14)
	Sfx.play(self, &"flesh_heavy", global_position, 1.0, 0.75)
	Sfx.play(self, &"bone_crack", global_position, -4.0, 0.7)
	_swap_body()
	turned_worse.emit()


## Whether it has you in its line, right now.
func sees(you: Node3D) -> bool:
	return _line_to(you)


## The evil eye sent back on it: it squeezes shut, sinks and can do nothing for a
## while, and whatever hits it counts as weak.
func limpia(by: Node3D) -> void:
	_enter(State.DAZED)
	statuses.apply(&"exposed", DAZED_TIME)
	# Struck by it: flung off you, flushing and bleeding.
	var away: Vector3 = global_position - by.global_position
	_push += away.normalized() * LIMPIA_THROW
	Fx.flash(self, global_position, Color(1.0, 0.8, 0.55), 1.5, 4.0, 0.12)

	if body != null:
		body.struck(global_position, away, &"weak")




## How far off the whip can meet it (Revolver.try_whip).
var whip_reach: float:
	get:
		return WHIP_SWOOPING if state == State.SWOOP else WHIP_CLOSE


## Struck by the whip or the boot in a swoop: batted back along the blow.
func take_hit(damage: float, attacker: Node3D, hit_kind: StringName, point: Vector3, direction: Vector3) -> StringName:
	if not dead and state == State.SWOOP and (hit_kind == &"power" or hit_kind == &"kick"):
		_bat_way = direction.normalized()
		_enter(State.BATTED)
		var result := super.take_hit(damage, attacker, hit_kind, point, direction)
		_pay_back(attacker)
		_turn_if_hurt()
		_show_struck(point, direction, &"weak")
		return result if result == &"killed" else &"weak"

	var was_dead := dead
	var outcome := super.take_hit(damage, attacker, hit_kind, point, direction)

	if not was_dead:
		_turn_if_hurt()
		_show_struck(point, direction, outcome)

	return outcome


func _swap_body() -> void:
	var old := body
	old.queue_free()
	_build_body()
	body.take_over_from(old)


## Off a save, a hurt one has already turned: nothing bursts.
func load_state(state: Dictionary) -> void:
	super.load_state(state)

	if not turned and not dead and health <= _max_health() * TURNS_AT:
		turned = true
		_swap_body()


func _turn_if_hurt() -> void:
	if not turned and not dead and health <= _max_health() * TURNS_AT:
		turn()


func _show_struck(point: Vector3, direction: Vector3, result: StringName) -> void:
	if body != null and not dead:
		body.struck(point if point != Vector3.ZERO else global_position, direction, result)


func _batted(you: Node3D) -> Vector3:
	var hit_something := get_slide_collision_count() > 0

	for other in get_tree().get_nodes_in_group(&"monsters"):
		if other != self and not other.dead and not other.asleep and other.global_position.distance_to(global_position) <= BAT_MEET:
			other.round_hint = &"lead"
			other.take_hit(BAT_HURT, you, &"kick", other.global_position, _bat_way)
			other.statuses.apply(&"exposed", EXPOSED_TIME)
			other.exposed_now.emit()
			hit_something = true

	if hit_something:
		_swoop_way = -_bat_way
		_enter(State.BOUNCE)
		take_hit(BAT_HURT, you, &"kick", global_position, -_bat_way)
		return Vector3.ZERO

	if _state_t >= BAT_TIME:
		_enter(State.BOUNCE)
		return Vector3.ZERO

	return _bat_way * BAT_SPEED


## A weak hit throws it back, away from you, off whatever it was doing. Shut, it
## stays shut.
func _stagger() -> void:
	if state == State.DAZED:
		return

	var you: Node3D = target()

	if you != null:
		_swoop_way = (you.global_position - global_position).normalized()

	_enter(State.BOUNCE)


func _build_body() -> void:
	body = EyeBody.new()
	body.name = "BodyTurned" if turned else "Body"
	body.seed_value = seed_value

	if turned:
		body.model = EyeBody.TURNED_MODEL

	add_child(body)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	if dead or asleep or body == null:
		return

	var you: Node3D = target()

	if you != null:
		body.tick(delta, DOING[state], you, velocity, is_exposed(), statuses.has(&"smoked"), health / float(Bestiary.info(kind).get("health", 1.0)))


func _brain(delta: float) -> Vector3:
	_ticks += 1
	_state_t += delta
	_flinch_left = maxf(_flinch_left - delta, 0.0)
	var you: Node3D = target()

	if you == null or you.get("is_dead") == true:
		gazing = false

		if state != State.DRIFT:
			_enter(State.DRIFT)

		return _drift()

	if _ticks % LINE_EVERY == 1:
		_clear_line = _line_to(you)

	var smoked: bool = statuses.has(&"smoked")
	_gaze(you, delta, smoked)
	match state:
		State.DRIFT:
			if _clear_line and global_position.distance_to(you.global_position) <= NOTICE:
				_enter(State.CIRCLE)

			return _drift()
		State.CIRCLE:
			next_swoop_in -= delta

			if turned and not smoked and _clear_line:
				spit_in -= delta

				if spit_in <= 0.0:
					spit_in = _rng.randf_range(SPIT_EVERY.x, SPIT_EVERY.y)
					_enter(State.SPIT_UP)
					return Vector3.ZERO

			if not smoked and next_swoop_in <= 0.0 and _clear_line and _room_to_swoop():
				_enter(State.TELL)
				return Vector3.ZERO

			return _circle(you) * (SMOKED_SPEED if smoked else 1.0)
		State.TELL:
			if smoked or not _clear_line:
				_enter(State.CIRCLE)
				return Vector3.ZERO

			if _state_t < TELL_FIXES:
				_swoop_at = you.global_position + Vector3(0.0, 0.3, 0.0)
			elif _state_t >= TELL_TIME:
				_launch()

			return Vector3.ZERO
		State.SPIT_UP:
			if smoked or not _clear_line:
				_enter(State.CIRCLE)
			elif _state_t >= SPIT_WIND:
				EyeGob.spat_at(get_parent(), global_position - body.global_basis.z * 0.3, you.global_position + Vector3.UP * 0.15, self)
				_enter(State.CIRCLE)

			return Vector3.ZERO
		State.SWOOP:
			return _swoop(you, delta)
		State.BATTED:
			return _batted(you)
		State.DAZED:
			if _state_t >= DAZED_TIME:
				next_swoop_in = _rng.randf_range(SWOOP_WAIT.x, SWOOP_WAIT.y)
				_enter(State.CIRCLE)
				return Vector3.ZERO

			return Vector3.DOWN * DAZED_SINK if global_position.y > you.global_position.y - 1.0 + DAZED_LOWEST else Vector3.ZERO
		State.BOUNCE:
			if _state_t >= BOUNCE_TIME:
				next_swoop_in = _rng.randf_range(SWOOP_WAIT.x, SWOOP_WAIT.y)
				_enter(State.CIRCLE)
				return Vector3.ZERO

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
	var wanted := you.global_position + Vector3(sin(_orbit), 0.0, cos(_orbit)) * circle_radius()
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
	var at := you.global_position + Vector3(0.0, 0.6, 0.0)

	# The Ward's smoke hides what is in it.
	if not WardScript.stopped_by(global_position, at, self).is_empty():
		return false

	var query := PhysicsRayQueryParameters3D.create(global_position, at, 1, [get_rid(), you.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## Being looked at, added up over the pack on the bearer (Statuses.stare).
func _gaze(you: Node3D, delta: float, smoked: bool) -> void:
	gazing = false

	if smoked or not _clear_line or state == State.DRIFT or state == State.BOUNCE or state == State.DAZED or global_position.distance_to(you.global_position) > GAZE_RANGE:
		return

	var bearer: Node = you.get("statuses")

	if bearer == null or bearer.has(&"cleansed"):
		return

	gazing = true

	# Already on you, a stare drives it deeper.
	var curse: Node = you.get("curse")

	if bearer.has(&"evil_eye"):
		if bearer.stare(delta, GAZE_TO_DEEPEN) and curse != null:
			curse.deepen()
	elif bearer.stare(delta, GAZE_TO_CURSE):
		bearer.apply(&"evil_eye", EVIL_EYE_TIME)


func _room_to_swoop() -> bool:
	var busy := 0

	for other in get_tree().get_nodes_in_group(&"monsters"):
		if other != self and other.kind == kind and not other.dead and not other.asleep and (other.state == State.TELL or other.state == State.SWOOP):
			busy += 1

	return busy < MOST_SWOOPING


func _launch() -> void:
	Sfx.play(self, &"whoosh_light", global_position, -2.0, 0.7)
	_swoop_from = global_position
	_swoop_way = (_swoop_at - _swoop_from).normalized()
	_bitten = false
	_enter(State.SWOOP)


func _swoop(you: Node3D, delta: float) -> Vector3:
	# Into the Ward: its smoke, and off.
	if WardScript.covers(global_position) or not WardScript.stopped_by(global_position, global_position + _swoop_way * SWOOP_SPEED * delta * 2.0, self).is_empty():
		statuses.apply(&"smoked", STATUS_TIME)
		_stagger()
		return Vector3.ZERO

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


## It bursts, and what is left of it drops. The rest of the pack starts back.
func _die(by: Node3D) -> void:
	Fx.flash(self, global_position, Color(1.0, 0.45, 0.3), 2.0, 5.0, 0.08)
	Sfx.play(self, &"flesh_heavy", global_position, 2.0, 1.1)
	Sfx.play(self, &"coal_pop", global_position, 0.0, 0.7)
	body.burst(get_parent(), global_position, _push * 0.7 + Vector3.UP * 2.0)

	for other in get_tree().get_nodes_in_group(&"monsters"):
		if other != self and other.has_method("flinch") and not other.dead and not other.asleep and other.global_position.distance_to(global_position) <= FLINCH_WITHIN:
			other.flinch()

	super._die(by)


## One of the pack has burst near it: it breaks off, draws back and holds off a
## moment. Your breath.
func flinch() -> void:
	next_swoop_in += FLINCH_WAIT
	_flinch_left = FLINCH_TIME

	if state == State.TELL or state == State.SPIT_UP:
		_enter(State.CIRCLE)


func flinching() -> bool:
	return _flinch_left > 0.0


## How far out it circles you now.
func circle_radius() -> float:
	return _radius + (FLINCH_OUT if flinching() else 0.0)


## Within reach of the line down your middle.
func _touching(you: Node3D) -> bool:
	var at := you.global_position
	var nearest := Vector3(at.x, clampf(global_position.y, at.y - 0.5, at.y + 0.5), at.z)
	return global_position.distance_to(nearest) <= BITE_REACH


## Glass from the floor through it (ObsidianBurst.gd).
func cracked_by(point: Vector3, direction: Vector3) -> void:
	if body != null:
		body.crack(point, direction)
