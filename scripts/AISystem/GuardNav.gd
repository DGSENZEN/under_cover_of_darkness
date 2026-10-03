extends RefCounted
## Navigation support for Guard walking: crowd velocity, temporary detours,
## closed-door detection and pursuit prediction. Positions are world-space feet.
## Detours handle obstacles absent from the baked mesh; doors are returned for Guard
## to open. Lead/scent fall back to the supplied position if prediction is unusable.

## Men nearer each other than this ease apart, at most this fast (m/s).
const CROWD_RADIUS := 1.1
const CROWD_PUSH := 1.4
## A man in the way this far ahead is passed on the right, this hard.
const PASS_AHEAD := 2.4
const PASS_PUSH := 1.2
## Stuck this long, he looks for a way round; at most this many on one path.
const DETOUR_AFTER := 0.45
const DETOURS := 2
## A way round: this far aside (and a little ahead), given this long.
const DETOUR_SIDE := 1.1
const DETOUR_AHEAD := 0.6
const DETOUR_TIME := 0.9
## A closed door this near, on the line to where he is going, is opened.
const DOOR_AHEAD := 1.7
const DOOR_LINE := 0.9
## Leading a runner: never more than this many seconds ahead of him, and only
## a man moving at least this fast (m/s) is led at all.
const LEAD_MAX := 1.2
const LEAD_SPEED := 1.5
## Following the scent: this far on past where he lost you.
const SCENT := 3.5

static var _crowd: Array = []
static var _crowd_frame := -1

var guard: CharacterBody3D
## Ways round taken on the current path.
var detours := 0
var _detour := Vector3.INF
var _detour_left := 0.0
var _door_check := 0.0


func _init(p_guard: CharacterBody3D) -> void:
	guard = p_guard


# The crowd

## The push away from the men standing too close (flat, m/s). Going
## `forward`, a man coming the other way just ahead is passed on the right,
## both of them veering early instead of meeting nose to nose.
func crowd(forward := Vector3.ZERO) -> Vector3:
	var push := Vector3.ZERO
	var me := guard.global_position
	var going := Vector3(forward.x, 0.0, forward.z)
	going = going.normalized() if going.length() > 0.01 else Vector3.ZERO

	for other in _men(guard.get_tree()):
		if other == guard or not is_instance_valid(other) or other.is_queued_for_deletion():
			continue

		if other.has_method("is_downed") and other.is_downed():
			continue

		var off: Vector3 = me - (other as Node3D).global_position

		if absf(off.y) > 1.5:
			continue

		off.y = 0.0
		var d := off.length()

		if going != Vector3.ZERO and d < PASS_AHEAD and going.dot(-off / maxf(d, 0.001)) > 0.7:
			var theirs := Vector3((other as CharacterBody3D).velocity.x, 0.0, (other as CharacterBody3D).velocity.z) if other is CharacterBody3D else Vector3.ZERO

			# Coming this way, or standing in it: round him, to the right.
			if theirs.dot(going) < 0.3:
				push += -Vector3.UP.cross(going) * PASS_PUSH * (1.0 - d / PASS_AHEAD)

		if d >= CROWD_RADIUS:
			continue

		if d < 0.02:
			# Standing in one another: apart by who they are.
			var turn := float(guard.get_instance_id() % 628) / 100.0
			off = Vector3(cos(turn), 0.0, sin(turn))
			d = 0.02

		push += off / d * (1.0 - d / CROWD_RADIUS) * CROWD_PUSH

	return push.limit_length(CROWD_PUSH)


## Every guard, looked up once a physics frame for all of them.
static func _men(tree: SceneTree) -> Array:
	var frame := Engine.get_physics_frames()

	if frame != _crowd_frame:
		_crowd_frame = frame
		_crowd = tree.get_nodes_in_group(&"guards")

	return _crowd


# Detours

## A new path: its ways round are its own.
func new_path() -> void:
	detours = 0
	_detour = Vector3.INF


func detouring() -> bool:
	return _detour != Vector3.INF


## Stuck going `ahead`: takes a way round if there is one. True if he does.
func try_detour(ahead: Vector3) -> bool:
	if detours >= DETOURS:
		return false

	var forward := Vector3(ahead.x, 0.0, ahead.z)
	forward = forward.normalized() if forward.length() > 0.01 else -guard.global_basis.z
	# To his left (+) and right (-).
	var side := Vector3.UP.cross(forward)
	var sides: Array = [1.0, -1.0] if guard.get_instance_id() % 2 == 0 else [-1.0, 1.0]

	# A man in the way: each keeps to his own right, so two men nose to nose
	# in a passage pass each other.
	if _man_ahead(forward) != null:
		sides = [-1.0, 1.0]

	for sgn in sides:
		for ahead_by in [DETOUR_AHEAD, 0.0]:
			var point: Vector3 = guard.global_position + side * float(sgn) * DETOUR_SIDE + forward * float(ahead_by)

			if _clear_to(point):
				_detour = point
				_detour_left = DETOUR_TIME
				detours += 1
				return true

	return false


## Walks the way round. True once it is done (the path is asked for again from
## where he now stands).
func walk_detour(speed: float, delta: float) -> bool:
	_detour_left -= delta
	var to := _detour - guard.global_position
	to.y = 0.0

	if to.length() < 0.25 or _detour_left <= 0.0:
		_detour = Vector3.INF

		if guard._agent != null:
			# The same goal, asked for again: a path from here.
			guard._agent.target_position = guard._agent.target_position

		return true

	var direction := to.normalized()
	var flat := Vector3(guard.velocity.x, 0.0, guard.velocity.z).move_toward(direction * minf(speed, 2.2), guard.acceleration * delta)
	guard.velocity.x = flat.x
	guard.velocity.z = flat.z
	guard._face(direction, delta)
	return false


## Another man right in front of him.
func _man_ahead(forward: Vector3) -> Node3D:
	var me := guard.global_position

	for other in _men(guard.get_tree()):
		if other == guard or not is_instance_valid(other):
			continue

		var off: Vector3 = (other as Node3D).global_position - me
		off.y = 0.0

		if off.length() < 1.3 and forward.dot(off.normalized()) > 0.5:
			return other

	return null


## On the navmesh at his level, and room to stand there with nothing solid in
## between.
func _clear_to(point: Vector3) -> bool:
	var map: RID = guard.get_world_3d().navigation_map
	var closest := NavigationServer3D.map_get_closest_point(map, point)

	if Vector2(closest.x - point.x, closest.z - point.z).length() > 0.25 or absf(closest.y - guard.global_position.y) > 0.45:
		return false

	var space := guard.get_world_3d().direct_space_state
	var from := guard.global_position + Vector3.UP * 0.5
	var to := Vector3(point.x, from.y, point.z)
	var ray := PhysicsRayQueryParameters3D.create(from, to, 1 | 2, [guard.get_rid()])

	if not space.intersect_ray(ray).is_empty():
		return false

	var sphere := SphereShape3D.new()
	sphere.radius = 0.32
	var room := PhysicsShapeQueryParameters3D.new()
	room.shape = sphere
	room.transform = Transform3D(Basis.IDENTITY, to)
	room.collision_mask = 1 | 2
	room.exclude = [guard.get_rid()]
	return space.intersect_shape(room, 1).is_empty()


# Doors

## A closed door he is about to walk through on his way to `next`; null if
## none (looked for a few times a second).
func door_ahead(next: Vector3, delta: float) -> Node3D:
	_door_check -= delta

	if _door_check > 0.0:
		return null

	_door_check = 0.15
	var me := guard.global_position
	var goal := Vector3(next.x, me.y, next.z)

	var going := goal - me

	if going.length() < 0.05:
		return null

	for door in guard.get_tree().get_nodes_in_group(&"doors"):
		if not is_instance_valid(door) or door.get("is_open") != false or not door.has_method("doorway"):
			continue

		var way: Vector3 = door.doorway()

		if absf(way.y - me.y) > 1.2:
			continue

		var level := Vector3(way.x, me.y, way.z)

		if level.distance_to(me) > DOOR_AHEAD:
			continue

		# Through it, not along the wall it is in.
		if absf(going.normalized().dot(door.facing())) < 0.4:
			continue

		if Geometry3D.get_closest_point_to_segment(level, me, me + going.normalized() * DOOR_AHEAD * 1.5).distance_to(level) > DOOR_LINE:
			continue

		return door

	return null


# Pursuit

## Where to run to catch `target`, whose feet are at `feet`, `dist` away:
## where he will be by the time you get there (not further ahead than
## LEAD_MAX, and on the navmesh); just his feet if he is not going anywhere.
func lead(target: Node3D, feet: Vector3, dist: float, speed: float) -> Vector3:
	var going: Variant = target.get("velocity")

	if not (going is Vector3):
		return feet

	var flat := Vector3((going as Vector3).x, 0.0, (going as Vector3).z)

	if flat.length() < LEAD_SPEED:
		return feet

	var ahead := feet + flat * clampf(dist / maxf(speed, 0.5), 0.0, LEAD_MAX)
	var map: RID = guard.get_world_3d().navigation_map
	var closest := NavigationServer3D.map_get_closest_point(map, ahead)

	if closest.distance_to(ahead) > 1.5:
		return feet

	return closest


## A few steps on from `lost_at`, the way the man was going (`heading`): on
## the navmesh, or `lost_at` itself if that way goes nowhere.
func scent(lost_at: Vector3, heading: Vector3) -> Vector3:
	var flat := Vector3(heading.x, 0.0, heading.z)

	if flat.length() < 0.8:
		return lost_at

	var ahead := lost_at + flat.normalized() * SCENT
	var map: RID = guard.get_world_3d().navigation_map
	var closest := NavigationServer3D.map_get_closest_point(map, ahead)
	return closest if closest.distance_to(ahead) < 1.2 else lost_at
