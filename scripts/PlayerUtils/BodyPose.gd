extends RefCounted
## Movement pose and world-space hand targets for an arm rig.
## update() selects pose from player state and eases each hand weight toward
## 0 (animation only) or 1 (world contact); it does not move the player.

const MoveVariantRes := preload("res://scripts/PlayerUtils/MoveVariant.gd")
const TraversalPlanner := preload("res://scripts/PlayerUtils/TraversalPlanner.gd")

var pose: StringName = &"idle"

var left_target := Transform3D.IDENTITY
var right_target := Transform3D.IDENTITY
var left_weight := 0.0
var right_weight := 0.0

## Half the distance between the hands on a ledge.
var hand_spread := 0.24
## Ladder rung spacing, for alternating hands.
var rung_spacing := 0.3

var _left_goal := 0.0
var _right_goal := 0.0


## Reads PlayerController fields from player and updates pose, targets, and weights.
## delta is game seconds; targets stay world-space and weights ease toward state goals.
func update(player: CharacterBody3D, delta: float) -> void:
	_left_goal = 0.0
	_right_goal = 0.0

	match player.movement_state:
		player.MoveState.MOVING:
			_update_move(player)
		player.MoveState.HANGING:
			_update_hang(player)
		player.MoveState.CLIMBING:
			_update_climb(player)
		_:
			_update_locomotion(player)

	# Hands reach and let go over a few frames, never in one.
	var rate := 1.0 - exp(-14.0 * delta)
	left_weight = lerpf(left_weight, _left_goal, rate)
	right_weight = lerpf(right_weight, _right_goal, rate)



func _update_locomotion(player: CharacterBody3D) -> void:
	var speed := Vector3(player.velocity.x, 0.0, player.velocity.z).length()

	# A body over the shoulder: one arm holds it there. That is a pose for the
	# animation to play, with nothing in the world to pin a hand to.
	if player.frob != null and player.frob.is_shouldering():
		pose = &"carry_body"
		return

	if player.frob != null and player.frob.held != null:
		pose = &"carry"
		var held: RigidBody3D = player.frob.held
		var side := player.global_transform.basis.x
		var basis := player.global_transform.basis
		left_target = Transform3D(basis, held.global_position - side * 0.28)
		right_target = Transform3D(basis, held.global_position + side * 0.28)
		_left_goal = 1.0
		_right_goal = 1.0
		return

	if not player._on_floor_now() and not player._on_stairs:
		pose = &"air_rise" if player.velocity.y > 0.5 else &"air_fall"
	elif player.is_crouched:
		pose = &"crouch_walk" if speed > 0.5 else &"crouch_idle"
	elif speed > player.walk_speed + 0.5:
		pose = &"sprint"
	elif speed > 0.5:
		pose = &"walk"
	else:
		pose = &"idle"


func _update_move(player: CharacterBody3D) -> void:
	var move = player.current_move

	if move == null:
		return

	pose = StringName(String(move.label).replace(" ", "_"))

	if move.windup_time > 0.0 and player.move_windup > 0.0:
		pose = &"leap_windup"

	if not move.has_contact:
		return

	var lateral: Vector3 = move.contact_normal.cross(Vector3.UP).normalized()
	var basis := _grip_basis(move.contact_normal)
	var s: float = player.move_progress

	# Project the body onto the edge so the hands plant beside it, not where
	# the scan happened to hit.
	var along: float = (player.global_position - move.contact_point).dot(lateral)
	var center: Vector3 = move.contact_point + lateral * along

	left_target = Transform3D(basis, center + lateral * hand_spread)
	right_target = Transform3D(basis, center - lateral * hand_spread)

	match move.kind:
		MoveVariantRes.Kind.VAULT:
			# Vault: one hand plants, the other swings free. Hands leave as
			# the body passes over.
			_right_goal = 1.0 - smoothstep(0.55, 0.8, s)
		MoveVariantRes.Kind.MANTLE, TraversalPlanner.KIND_PULL_UP:
			# Mantle, or pulling up from a hang: both hands push down on the
			# edge until the body is up.
			var push := 1.0 - smoothstep(0.6, 0.9, s)
			_left_goal = push
			_right_goal = push
		_:
			# Reaching for a hang, leaping, cornering, lowering: hands arrive.
			var reach := smoothstep(0.3, 0.9, s)
			_left_goal = reach
			_right_goal = reach


func _update_hang(player: CharacterBody3D) -> void:
	pose = &"hang_peek" if player.is_peeking else &"hang"

	var normal: Vector3 = player.hang_normal
	var lateral := normal.cross(Vector3.UP).normalized()
	var basis := _grip_basis(normal)

	# On the lip, directly in front of the body, fingers over the edge.
	var center: Vector3 = player.global_position - normal * (player._radius + 0.02)
	center.y = player.hang_lip_y

	left_target = Transform3D(basis, center + lateral * hand_spread)
	right_target = Transform3D(basis, center - lateral * hand_spread)
	_left_goal = 1.0
	_right_goal = 1.0


func _update_climb(player: CharacterBody3D) -> void:
	var volume: Area3D = player.current_climb

	if volume == null:
		return

	if volume.has_method("rope_point"):
		pose = &"climb_rope"
		# Hand over hand above you: one at your face, one reaching over your
		# head (the rope is measured from its top, so up the rope is less).
		var grip: Vector3 = volume.rope_point(maxf(player.rope_param - 0.6, 0.0))
		var upper: Vector3 = volume.rope_point(maxf(player.rope_param - 0.98, 0.0))
		var basis := _grip_basis(volume.get_rope_normal(player.global_position))
		left_target = Transform3D(basis, upper)
		right_target = Transform3D(basis, grip)
		_left_goal = 1.0
		_right_goal = 1.0
		return

	pose = &"climb_ladder"
	var normal: Vector3 = volume.get_climb_normal()
	var lateral := normal.cross(Vector3.UP).normalized()
	var basis := _grip_basis(normal)
	var wall: Vector3 = player.global_position - normal * (player._radius + 0.05)

	# Hands snap to rungs, one rung apart, swapping as the body climbs: the
	# higher one about eye level, where you can see it take the rung.
	var reach_y := player.global_position.y + 0.8
	var rung := floorf(reach_y / rung_spacing)
	var left_high := int(rung) % 2 == 0
	var high := rung * rung_spacing
	var low := (rung - 1.0) * rung_spacing

	left_target = Transform3D(basis, Vector3(wall.x, high if left_high else low, wall.z) + lateral * 0.2)
	right_target = Transform3D(basis, Vector3(wall.x, low if left_high else high, wall.z) - lateral * 0.2)
	_left_goal = 1.0
	_right_goal = 1.0


## Hand orientation for gripping an edge: -Z into the wall, +Y up.
func _grip_basis(normal: Vector3) -> Basis:
	var n := Vector3(normal.x, 0.0, normal.z)

	if n.length_squared() < 0.0001:
		return Basis.IDENTITY

	return Basis.looking_at(-n.normalized(), Vector3.UP)
