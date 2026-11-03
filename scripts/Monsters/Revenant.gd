extends "res://scripts/Monsters/Monster.gd"
## The drowned of the old lakebed, raised by the seepage: the tank. It walks at you and doesn't stop, and throws itself forward when you think
## you have room. Put down, it gets back up, as many times as you let it: only fire keeps it dead. Its numbers are in Bestiary.
## (docs/superpowers/specs/2026-11-03-revenant-design.md)

const RevenantBody := preload("res://scripts/Monsters/RevenantBody.gd")

enum State { WALK, SURGE_TELL, SURGE, SWIPE_WIND, SWIPE, RAKE_WIND, RAKE, GRASP_WIND, GRASP, HOLD, SHOVE, STAGGER, FALL, DOWN, RISE, DYING }

const REACH_OF := {State.SWIPE_WIND: "swipe_reach", State.RAKE_WIND: "rake_reach", State.GRASP_WIND: "grasp_reach"}
const DOING := {
	State.WALK: &"walk", State.SURGE_TELL: &"surge_tell", State.SURGE: &"surge", State.SWIPE_WIND: &"swipe_wind", State.SWIPE: &"swipe",
	State.RAKE_WIND: &"rake_wind", State.RAKE: &"rake", State.GRASP_WIND: &"grasp_wind", State.GRASP: &"grasp", State.HOLD: &"hold",
	State.SHOVE: &"shove", State.STAGGER: &"stagger", State.FALL: &"fall", State.DOWN: &"down", State.RISE: &"rise", State.DYING: &"dying_a",
}
## What gets you out of its hands.
const FREES := [&"power", &"kick", &"blast", &"burst", &"brazier"]
## How far it falls before it counts as lying (s).
const FALLS_IN := 0.7
const GRAVITY := 18.0
## What it is to be struck by, standing and lying (m): the capsule, on the floor at its origin.
const STANDS_TALL := 2.0
const LIES_TALL := 1.15
## What can stand between it and a surge at you.
const SIGHT_MASK := 1

var state := State.WALK
var kills_as := &"swipe"
var _row := {}
var _state_t := 0.0
var _surge_in := 5.0
var _attack_in := 0.0
var _fall_speed := 0.0
var _rng := RandomNumberGenerator.new()
var _dying_left := 0.0
var _burner: Node3D = null
var _shape: CollisionShape3D
var body: Node3D


func _init() -> void:
	kind = &"revenant"


func _ready() -> void:
	_row = Bestiary.info(kind)
	super._ready()
	wall_min_slide_angle = 0.0
	_rng.seed = hash(name) + int(absf(position.x) * 37.0 + absf(position.z) * 61.0)
	_surge_in = _next_surge()
	_shape = get_child(0) as CollisionShape3D
	_stand_tall(STANDS_TALL)
	body = RevenantBody.new()
	body.name = "Body"
	add_child(body)


func hit_radius() -> float:
	return float(Bestiary.info(&"revenant")["hit_radius"])


func _body_shape() -> Shape3D:
	var capsule := CapsuleShape3D.new()
	capsule.radius = hit_radius()
	capsule.height = STANDS_TALL
	return capsule


func _stand_tall(tall: float) -> void:
	(_shape.shape as CapsuleShape3D).height = tall
	_shape.position.y = tall * 0.5


func is_down() -> bool:
	return state == State.FALL or state == State.DOWN or state == State.RISE


func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	if asleep or body == null:
		return

	var you: Node3D = target()

	if dead:
		if _dying_left > 0.0:
			_dying_left -= delta
			body.tick(delta, DOING[state], Vector3.ZERO, _face_of(you), 1.0, 0.0, 0.0)

			if _dying_left <= 0.0:
				_put_out()

		return

	if is_on_floor():
		body.lie_at(global_position.y)

	body.tick(delta, DOING[state], velocity, _face_of(you), 0.6 if statuses.has(&"burning") else 0.0, 0.0, 0.0)


func take_hit(damage: float, attacker: Node3D, hit_kind: StringName, point: Vector3, direction: Vector3) -> StringName:
	if dead:
		return &"none"

	var source := Bestiary.source_of(hit_kind, round_hint)

	if is_down():
		last_hit_at = point
		last_hit_way = direction

		# Fire is the one thing that reaches it, lying there.
		if source == &"fire":
			_finish(attacker)
			struck.emit(&"killed", source)
			return &"killed"

		struck.emit(&"resisted", source)
		return &"resisted"

	var was_holding := state == State.HOLD
	var was_gathering := state == State.GRASP_WIND
	_burner = attacker if source == &"fire" else _burner
	var result: StringName = super.take_hit(damage, attacker, hit_kind, point, direction)

	if dead or is_down():
		return result

	if source == &"fire":
		statuses.apply(&"burning", float(_row["burn_time"]))

		if was_gathering:
			_enter(State.STAGGER)

	# A whip or a boot or a blast: you get free of it. The touch stays.
	if was_holding and state == State.HOLD and FREES.has(hit_kind) and is_instance_valid(target()):
		target().touch.let_go()
		_enter(State.STAGGER)

	return result


func kick(push: Vector3, by: Node3D) -> void:
	if dead or is_down():
		return

	take_hit(KICK_DAMAGE, by, &"kick", global_position, push)
	_push += push * float(_row["push_takes"])


func _hit_pushes(hit_kind: StringName) -> float:
	return float(_row["thrown_takes"]) if hit_kind == &"burst" or hit_kind == &"blast" else float(_row["push_takes"])


func _goes_down(_by: Node3D, source: StringName) -> bool:
	# On fire, it has no getting up.
	if source == &"fire" or statuses.has(&"burning"):
		return false

	health = 0.0
	_enter(State.FALL)
	return true


func _is_opening_to(source: StringName) -> bool:
	return state == State.GRASP_WIND and source == &"fire"


## Dead for good, in fire.
func _finish(by: Node3D) -> void:
	health = 0.0
	_pay_back(by)
	_die(by)


func _die(by: Node3D) -> void:
	_dying_left = float(_row["dies_in"])
	_enter(State.DYING)
	var you: Node3D = target()

	if is_instance_valid(you) and you.get("touch") != null:
		you.touch.clear_if(self)

	super._die(by)


func _lay_down() -> void:
	dead = true

	# Burning out, it stays to be seen; laid down from a save, or done burning, it hides.
	if _dying_left > 0.0:
		velocity = Vector3.ZERO
		get_child(0).set_deferred(&"disabled", true)
	else:
		_put_out()


func _enter(next: State) -> void:
	state = next
	_state_t = 0.0

	if next == State.FALL:
		_stand_tall(LIES_TALL)
	elif next == State.WALK:
		_stand_tall(STANDS_TALL)


func _brain(delta: float) -> Vector3:
	_state_t += delta
	_surge_in = maxf(_surge_in - delta, 0.0)
	_attack_in = maxf(_attack_in - delta, 0.0)
	_fall_speed = 0.0 if is_on_floor() else _fall_speed + GRAVITY * delta
	var drops := Vector3.DOWN * _fall_speed

	# It burns as it comes.
	if statuses.has(&"burning") and not is_down():
		health -= float(_row["burn_rate"]) * delta

		if health <= 0.0:
			_finish(_burner)
			return drops

	var you: Node3D = target()

	if you == null:
		return drops

	var to_you := you.global_position - global_position
	to_you.y = 0.0
	var far := to_you.length()
	var way := to_you / maxf(far, 0.01)

	if not is_down():
		_turn_to(way, delta)

	match state:
		State.WALK:
			_choose(far)
			# (It stops short of you: it reaches, it doesn't walk through you.)
			return way * (float(_row["speed"]) if far > float(_row["keeps_off"]) else 0.0) + drops
		State.SURGE_TELL:
			if _state_t >= float(_row["surge_tell"]):
				_enter(State.SURGE)

			return way * float(_row["speed"]) * float(_row["steps_winding"]) * 0.4 + drops
		State.SURGE:
			if _state_t >= float(_row["surge_time"]) or far < float(_row["swipe_reach"]) or is_on_wall():
				_surge_in = _next_surge()
				_enter(State.WALK)
				_attack_in = 0.0
				_choose(far)
				return drops

			return -global_basis.z * float(_row["surge_speed"]) + drops
		State.SWIPE_WIND, State.RAKE_WIND, State.GRASP_WIND:
			var reach: float = float(_row[REACH_OF[state]])
			_wind_up_ends(you, far)
			# It comes after you with it: backing away as you aim doesn't beat it.
			return way * (float(_row["lurches"]) if far > reach else 0.0) + drops
		State.HOLD:
			if _state_t >= float(_row["grasp_hold"]) or you.get("touch") == null or not you.touch.holding():
				you.touch.let_go()
				_throw_off(you)
		State.SWIPE:
			_ends_after("swipe_time")
		State.RAKE:
			_ends_after("rake_time")
		State.GRASP:
			_ends_after("grasp_time")
		State.SHOVE:
			_ends_after("shove_time")
		State.STAGGER:
			_ends_after("stagger_time")
		State.FALL:
			if _state_t >= FALLS_IN:
				_enter(State.DOWN)
		State.DOWN:
			# (Its fall counts: 5 s from when it went down.)
			if _state_t >= float(_row["down_time"]) - FALLS_IN:
				_enter(State.RISE)
		State.RISE:
			if _state_t >= float(_row["rise_time"]):
				health = float(_row["health"]) * float(_row["rises_with"])
				_attack_in = float(_row["between_attacks"])
				_surge_in = _next_surge()
				_enter(State.WALK)

	return drops


## Walking, in reach of you or with room between you: what it does next.
func _choose(far: float) -> void:
	if state != State.WALK:
		return

	if _attack_in <= 0.0:
		var in_swipe := far <= float(_row["swipe_reach"])
		var in_rake := far <= float(_row["rake_reach"])
		var in_grasp := far <= float(_row["grasp_reach"])

		if in_grasp and (not in_swipe or _rng.randf() < float(_row["grasp_chance"])):
			_enter(State.GRASP_WIND)
			return

		if in_rake and _rng.randf() < 0.45:
			_enter(State.RAKE_WIND)
			return

		if in_swipe:
			_enter(State.SWIPE_WIND)
			return

	if _surge_in <= 0.0 and far > float(_row["surge_from"]) and _clear_run():
		_enter(State.SURGE_TELL)


func _clear_run() -> bool:
	var you: Node3D = target()
	var from := global_position + Vector3.UP * 1.0
	var ray := PhysicsRayQueryParameters3D.create(from, you.global_position, SIGHT_MASK)
	ray.exclude = [get_rid(), you.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()


func _wind_up_ends(you: Node3D, far: float) -> void:
	match state:
		State.SWIPE_WIND:
			if _state_t >= float(_row["swipe_wind"]):
				_land(you, far, "swipe_reach", "swipe_damage")
				_enter(State.SWIPE)
		State.RAKE_WIND:
			if _state_t >= float(_row["rake_wind"]):
				_land(you, far, "rake_reach", "rake_damage")
				_enter(State.RAKE)
		State.GRASP_WIND:
			if _state_t >= float(_row["grasp_wind"]):
				_grasp(you, far)


## The grasp. Out of reach or dodged, it closes on nothing. The first touch holds you and stays on you; the second is the end of you.
func _grasp(you: Node3D, far: float) -> void:
	var touch: Node = you.get("touch")
	var dodged: bool = you.get("combat") != null and you.combat.is_dodging()

	if touch == null or dodged or far > float(_row["grasp_reach"]) + float(_row["finds"]):
		_enter(State.GRASP)
	elif not touch.on_you():
		you.take_damage(float(_row["grasp_damage"]), self)
		touch.lay(self, float(_row["grasp_hold"]), float(_row["touch_grace"]))
		_enter(State.HOLD)
	elif touch.in_grace():
		_throw_off(you)
	else:
		_possess(you)
		_enter(State.GRASP)


func _possess(you: Node3D) -> void:
	if you.is_dead or you.invulnerable:
		return

	you.death.possessed = true
	you.drain_life(you.health + 1.0)


func _throw_off(you: Node3D) -> void:
	var away := you.global_position - global_position
	away.y = 0.0

	if you.has_method("shove"):
		you.shove(away.normalized() * float(_row["shoves"]), float(_row["shove_time"]))

	_enter(State.SHOVE)


## The blow lands, if you are still in reach and not out of its way.
func _land(you: Node3D, far: float, reach: String, damage: String) -> void:
	var dodged: bool = you.get("combat") != null and you.combat.is_dodging()

	if far <= float(_row[reach]) + float(_row["finds"]) and not dodged and you.has_method("take_damage"):
		# (First: if it kills you, you fall away from this side.)
		if you.get("hud") != null and you.hud.has_method("claw_at"):
			you.hud.claw_at(you.camera.to_local(global_position).x if you.get("camera") != null else 1.0)

		you.take_damage(float(_row[damage]), self)

		if you.get("statuses") != null:
			you.statuses.apply(&"soaked", float(_row["soaked_time"]))


func _ends_after(how_long: String) -> void:
	if _state_t >= float(_row[how_long]):
		_attack_in = float(_row["between_attacks"])
		_enter(State.WALK)


func _turn_to(way: Vector3, delta: float) -> void:
	var facing := -global_basis.z
	var angle := facing.signed_angle_to(way, Vector3.UP)
	rotation.y += clampf(angle, -float(_row["turns"]) * delta, float(_row["turns"]) * delta)


## Where it looks: at your face, or ahead with no one there.
func _face_of(you: Node3D) -> Vector3:
	return you.global_position + Vector3.UP * 0.6 if is_instance_valid(you) else global_position - global_basis.z * 4.0 + Vector3.UP * 2.0


func _next_surge() -> float:
	var between: Array = _row["surge_every"]
	return _rng.randf_range(float(between[0]), float(between[1]))
