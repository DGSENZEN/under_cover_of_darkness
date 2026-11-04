extends CharacterBody3D
## What every monster shares. Its kind (Bestiary) says what each hit does to
## it: a resisted hit barely tells, and a weak one exposes it for a moment and
## pays the shooter back in power, so the right answer feeds the next one.
## Takes blows as a guard does (take_hit), so the gun, the shard and the boot
## reach it unchanged. A kind says how it moves in _brain. Dead, it hides and
## stays, so a save can keep it. Stands on the guards' layer, so shots find
## it, but neither it nor the player is stopped by the other.

const Bestiary := preload("res://scripts/Monsters/Bestiary.gd")
const Rounds := preload("res://scripts/Combat/Rounds.gd")
const StatusesScript := preload("res://scripts/Monsters/Statuses.gd")
const CopalCloud := preload("res://scripts/Monsters/CopalCloud.gd")
const TimeFx := preload("res://scripts/Visual/TimeFx.gd")
const SaveFields := preload("res://scripts/Save/SaveFields.gd")

signal died(by: Node)
signal exposed_now
## Each hit: what it came to (Revolver's confirm words), and what it counted as.
signal struck(result: StringName, source: StringName)

## A weak hit leaves it open this long; any hit in that time is doubled.
const EXPOSED_TIME := 0.8
const EXPOSED_SCALE := 2.0
## A hit while it has opened itself (_is_opening): whatever the round.
const OPENING_SCALE := 3.0
## Power back for a weak hit, and how soon it can pay again, so a whole shell
## pays once.
const REFUND := 8.0
const REFUND_GAP := 0.25
## What a copal round's smoke lasts.
const STATUS_TIME := 4.0
## How hard each kind of hit throws it (m/s); how fast that dies away.
const PUSH := {&"bullet": 3.0, &"shot": 1.0, &"blast": 9.0, &"shard": 3.0, &"burst": 9.0, &"splash": 7.0}
const PUSH_DEFAULT := 2.0
const PUSH_FADE := 12.0
const KICK_DAMAGE := 20.0
const DEFAULT_RADIUS := 0.3
## A kill's hold (real seconds) and its jolt to the view.
const KILL_HOLD := 0.11
const KILL_TRAUMA := 0.3
const SAVED := ["health", "dead", "asleep", "global_position"]

@export var kind: StringName
var health := 0.0
## No headshots, unless a kind has a head.
var eye_height := 99.0
## The round about to hit it (Revolver, just before take_hit).
var round_hint: StringName = &"lead"
var dead := false
## Where and which way it was last hit.
var last_hit_at := Vector3.ZERO
var last_hit_way := Vector3.FORWARD
## Not in play yet (a wave to come): hidden, and it does nothing until woken.
var asleep := false
var statuses: Node

var _push := Vector3.ZERO
var _game_time := 0.0
var _refund_at := -100.0
var _player: Node3D


## The awake monster a line comes nearest, if it comes within `generous` metres
## of its edge (more, `per_metre`, the farther off): a shot need not be exact, and
## a thing that flies won't wait to be aimed at. `skip` is passed over. Nearest
## along the line wins. {} if none, else {monster, point, along}.
static func on_line(tree: SceneTree, from: Vector3, to: Vector3, generous: float, per_metre: float, skip: Array = []) -> Dictionary:
	var way := to - from
	var length := way.length()

	if length <= 0.001:
		return {}

	var dir := way / length
	var found := {}

	for monster in tree.get_nodes_in_group(&"monsters"):
		if monster.dead or monster.asleep or skip.has(monster):
			continue

		var along: float = (monster.global_position - from).dot(dir)

		if along < 0.0 or along > length:
			continue

		var on: Vector3 = from + dir * along
		var off: float = on.distance_to(monster.global_position)

		if off <= monster.hit_radius() + generous + per_metre * along and (found.is_empty() or along < found["along"]):
			found = {"monster": monster, "point": on, "along": along}

	return found


## How far from its middle it is struck.
func hit_radius() -> float:
	return DEFAULT_RADIUS


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	add_to_group(&"monsters")

	if get_child_count() == 0 or not get_child(0) is CollisionShape3D:
		var shape := CollisionShape3D.new()
		shape.shape = _body_shape()
		add_child(shape)
		move_child(shape, 0)

	statuses = StatusesScript.new()
	statuses.name = "Statuses"
	add_child(statuses)

	if health <= 0.0:
		health = float(Bestiary.info(kind).get("health", 1.0))

	# At once: a body that starts where the player stands and is then moved
	# carries them off like a lift.
	_meet_player()
	SaveGame.register(self)


## What it is hit by, and stands in.
func _body_shape() -> Shape3D:
	var sphere := SphereShape3D.new()
	sphere.radius = hit_radius()
	return sphere


func _physics_process(delta: float) -> void:
	_game_time += delta

	if dead or asleep:
		return

	_meet_player()
	velocity = _brain(delta) + _push
	_push = _push.move_toward(Vector3.ZERO, PUSH_FADE * delta)
	move_and_slide()


## The velocity it wants this tick. A kind's whole behaviour hangs off this.
func _brain(_delta: float) -> Vector3:
	return Vector3.ZERO


## The player, once there is one: they pass through each other.
func target() -> Node3D:
	return _player


func _meet_player() -> void:
	if is_instance_valid(_player):
		return

	_player = get_tree().get_first_node_in_group(&"player") as Node3D

	if _player != null:
		add_collision_exception_with(_player)
		_player.add_collision_exception_with(self)


func take_hit(damage: float, attacker: Node3D, hit_kind: StringName, point: Vector3, direction: Vector3) -> StringName:
	if dead:
		return &"none"

	last_hit_at = point
	last_hit_way = direction

	var source := Bestiary.source_of(hit_kind, round_hint)
	var opening := _is_opening_to(source)
	var weak := Bestiary.is_weak(kind, source) or opening
	var was_exposed := is_exposed()
	health -= damage * Bestiary.scale_for(kind, source) * (EXPOSED_SCALE if was_exposed else 1.0) * (OPENING_SCALE if opening else 1.0)
	_push += direction.normalized() * float(PUSH.get(hit_kind, PUSH_DEFAULT)) * _hit_pushes(hit_kind)

	if hit_kind == &"bullet":
		var round_is: Dictionary = Rounds.info(round_hint)
		var status: StringName = round_is.get("status", &"")

		if status != &"":
			statuses.apply(status, STATUS_TIME)

		if round_is.get("cloud", false):
			CopalCloud.burst(get_parent(), global_position)

	if weak:
		_pay_back(attacker)
		statuses.apply(&"exposed", EXPOSED_TIME)
		exposed_now.emit()

	var result := &"hit"

	if health <= 0.0 and _goes_down(attacker, source):
		result = &"hit"
	elif health <= 0.0:
		result = &"killed"
		_die(attacker)
	elif weak:
		result = &"weak"
	elif Bestiary.is_resisted(kind, source):
		result = &"resisted"

	struck.emit(result, source)
	return result


## How much of a hit's push it takes: all, unless a kind is heavy.
func _hit_pushes(_hit_kind: StringName) -> float:
	return 1.0


## Its health has run out: whether this only puts it down, for a kind that gets up.
func _goes_down(_by: Node3D, _source: StringName) -> bool:
	return false


## A boot: it hurts, and throws it along `push`.
func kick(push: Vector3, by: Node3D) -> void:
	if dead:
		return

	take_hit(KICK_DAMAGE, by, &"kick", global_position, push)
	_push += push


## Whether it has opened itself right now: any hit counts as a weak one, and
## more. A kind says when (a floating eye's tell).
func _is_opening() -> bool:
	return false


## Whether it has opened itself to this source: to anything, unless a kind says.
func _is_opening_to(_source: StringName) -> bool:
	return _is_opening()


func is_exposed() -> bool:
	return statuses.has(&"exposed")


func _pay_back(attacker: Node3D) -> void:
	if not is_instance_valid(attacker) or _game_time - _refund_at < REFUND_GAP:
		return

	var pool: Node = attacker.get("power")

	if pool != null:
		pool.refund(REFUND)
		_refund_at = _game_time


func _die(by: Node3D) -> void:
	_lay_down()
	TimeFx.hitstop(get_tree(), KILL_HOLD)
	var view: Variant = by.get("juice") if is_instance_valid(by) else null

	if view != null:
		view.add_trauma(KILL_TRAUMA)

	died.emit(by)


func _lay_down() -> void:
	dead = true
	_put_out()


func _put_out() -> void:
	visible = false
	velocity = Vector3.ZERO
	get_child(0).set_deferred(&"disabled", true)


## Out of play until wake().
func sleep() -> void:
	asleep = true
	_put_out()


func wake() -> void:
	asleep = false
	visible = true
	get_child(0).set_deferred(&"disabled", false)


func save_state() -> Dictionary:
	var state := SaveFields.save(self, SAVED)
	state["statuses"] = statuses.save_state()
	return state


func load_state(state: Dictionary) -> void:
	SaveFields.restore(self, state, SAVED)
	statuses.load_state(state.get("statuses", {}))

	if dead:
		_lay_down()
	elif asleep:
		sleep()
	else:
		wake()
