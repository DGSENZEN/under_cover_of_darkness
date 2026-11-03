extends "res://scripts/Monsters/Monster.gd"
## The drowned of the old lakebed, raised by the seepage: the tank. It walks at you and doesn't stop, and throws itself forward when you think
## you have room. Put down, it gets back up, as many times as you let it: only fire keeps it dead. Its numbers are in Bestiary.
## (docs/superpowers/specs/2026-11-03-revenant-design.md)

const RevenantBody := preload("res://scripts/Monsters/RevenantBody.gd")

enum State { WALK, SURGE_TELL, SURGE, SWIPE_WIND, SWIPE, RAKE_WIND, RAKE, GRASP_WIND, GRASP, HOLD, SHOVE, STAGGER, FALL, DOWN, RISE, DYING }

const DOING := {
	State.WALK: &"walk", State.SURGE_TELL: &"surge_tell", State.SURGE: &"surge", State.SWIPE_WIND: &"swipe_wind", State.SWIPE: &"swipe",
	State.RAKE_WIND: &"rake_wind", State.RAKE: &"rake", State.GRASP_WIND: &"grasp_wind", State.GRASP: &"grasp", State.HOLD: &"hold",
	State.SHOVE: &"shove", State.STAGGER: &"stagger", State.FALL: &"fall", State.DOWN: &"down", State.RISE: &"rise", State.DYING: &"dying_a",
}
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

	if dead or asleep or body == null:
		return

	var you: Node3D = target()

	if is_on_floor():
		body.lie_at(global_position.y)

	body.tick(delta, DOING[state], velocity, _face_of(you), 0.0, 0.0, 0.0)


func take_hit(damage: float, attacker: Node3D, hit_kind: StringName, point: Vector3, direction: Vector3) -> StringName:
	if dead:
		return &"none"

	if is_down():
		last_hit_at = point
		last_hit_way = direction
		struck.emit(&"resisted", Bestiary.source_of(hit_kind, round_hint))
		return &"resisted"

	return super.take_hit(damage, attacker, hit_kind, point, direction)


func kick(push: Vector3, by: Node3D) -> void:
	if dead or is_down():
		return

	take_hit(KICK_DAMAGE, by, &"kick", global_position, push)
	_push += push * float(_row["push_takes"])


func _hit_pushes(hit_kind: StringName) -> float:
	return float(_row["thrown_takes"]) if hit_kind == &"burst" or hit_kind == &"blast" else float(_row["push_takes"])


func _goes_down(_by: Node3D, _source: StringName) -> bool:
	health = 0.0
	_enter(State.FALL)
	return true


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
			return way * float(_row["speed"]) + drops
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
			_wind_up_ends(you, far)
			return way * float(_row["speed"]) * float(_row["steps_winding"]) + drops
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
				_enter(State.GRASP)


## The blow lands, if you are still in reach and not out of its way.
func _land(you: Node3D, far: float, reach: String, damage: String) -> void:
	var dodged: bool = you.get("combat") != null and you.combat.is_dodging()

	if far <= float(_row[reach]) + float(_row["finds"]) and not dodged and you.has_method("take_damage"):
		you.take_damage(float(_row[damage]), self)


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
