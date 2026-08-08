extends CharacterBody3D

enum MoveState {
	LOCOMOTION,
	MANTLING,
}


@export_category("View")
@export var mouse_sensitivity := 0.002
@export_range(1.0, 89.0, 1.0) var max_pitch_degrees := 88.0


@export_category("Locomotion")
@export var walk_speed := 6.5
@export var sprint_speed := 8.5

@export var ground_acceleration := 45.0
@export var ground_deceleration := 55.0
@export var air_acceleration := 15.0

@export var gravity := 24.0
@export var fall_gravity_multiplier := 1.35
@export var maximum_fall_speed := 35.0

@export var jump_speed := 8.3
@export_range(0.0, 1.0, 0.05) var jump_cut_multiplier := 0.5

@export var coyote_time := 0.12
@export var jump_buffer_time := 0.15


@export_category("Mantling")
@export_flags_3d_physics var mantle_mask := 1

@export var mantle_reach := 0.9
@export var mantle_probe_height := 1.05

@export var mantle_minimum_height := 0.45
@export var mantle_maximum_height := 1.55

@export var mantle_landing_depth := 0.5
@export var mantle_top_probe_extra := 0.25
@export var mantle_floor_clearance := 0.03

@export var mantle_duration := 0.30
@export var mantle_lift_extra := 0.18

@export_range(0.0, 1.0, 0.05) var minimum_top_normal_y := 0.70
@export_range(0.0, 1.0, 0.05) var maximum_wall_normal_y := 0.25

@export var maximum_mantle_fall_speed := 12.0


@onready var collider: CollisionShape3D = $CollisionShape3D
@onready var neck: Node3D = $Neck


var movement_state := MoveState.LOCOMOTION

var coyote_timer := 0.0
var jump_buffer_timer := 0.0

var mantle_start := Vector3.ZERO
var mantle_lift := Vector3.ZERO
var mantle_target := Vector3.ZERO
var mantle_elapsed := 0.0
var current_mantle_duration := 0.0


func _ready() -> void:
	assert(collider.shape != null)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Helps the player remain attached to stairs and descending slopes.
	floor_snap_length = 0.25

	# Prevents movement speed changing merely because the floor is sloped.
	floor_constant_speed = true


func _unhandled_input(event: InputEvent) -> void:
	if (
		event is InputEventMouseMotion
		and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	):
		var mouse_event := event as InputEventMouseMotion

		# The body handles horizontal rotation.
		rotate_y(-mouse_event.relative.x * mouse_sensitivity)

		# The neck handles vertical rotation.
		neck.rotate_x(-mouse_event.relative.y * mouse_sensitivity)
		neck.rotation.x = clamp(
			neck.rotation.x,
			-deg_to_rad(max_pitch_degrees),
			deg_to_rad(max_pitch_degrees)
		)

	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
	_update_jump_windows(delta)

	if movement_state == MoveState.MANTLING:
		_update_mantle(delta)
		return

	var input_axis := Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_back"
	)

	var wish_direction := (
		global_transform.basis
		* Vector3(input_axis.x, 0.0, input_axis.y)
	)

	wish_direction.y = 0.0
	wish_direction = wish_direction.normalized()

	var facing_direction := -global_transform.basis.z
	facing_direction.y = 0.0
	facing_direction = facing_direction.normalized()

	# The player must hold jump and provide at least some forward input.
	var wants_to_mantle := (
		Input.is_action_pressed("jump")
		and wish_direction.dot(facing_direction) > 0.25
	)

	if wants_to_mantle:
		var candidate := _find_mantle_candidate(facing_direction)

		if not candidate.is_empty():
			_start_mantle(candidate)
			return

	_try_buffered_jump()
	_apply_horizontal_movement(wish_direction, delta)
	_apply_vertical_movement(delta)

	move_and_slide()


func _update_jump_windows(delta: float) -> void:
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer = max(jump_buffer_timer - delta, 0.0)

	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer = max(coyote_timer - delta, 0.0)


func _try_buffered_jump() -> void:
	if jump_buffer_timer <= 0.0:
		return

	if coyote_timer <= 0.0:
		return

	velocity.y = jump_speed

	jump_buffer_timer = 0.0
	coyote_timer = 0.0


func _apply_horizontal_movement(
	wish_direction: Vector3,
	delta: float
) -> void:
	var target_speed := walk_speed

	if Input.is_action_pressed("sprint"):
		target_speed = sprint_speed

	var target_velocity := wish_direction * target_speed
	var horizontal_velocity := Vector3(
		velocity.x,
		0.0,
		velocity.z
	)

	if is_on_floor():
		var acceleration := ground_acceleration

		if wish_direction == Vector3.ZERO:
			acceleration = ground_deceleration

		horizontal_velocity = horizontal_velocity.move_toward(
			target_velocity,
			acceleration * delta
		)

	elif wish_direction != Vector3.ZERO:
		# With no air input, momentum is preserved.
		# With input, the player can redirect gradually.
		horizontal_velocity = horizontal_velocity.move_toward(
			target_velocity,
			air_acceleration * delta
		)

	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z


func _apply_vertical_movement(delta: float) -> void:
	if Input.is_action_just_released("jump") and velocity.y > 0.0:
		velocity.y *= jump_cut_multiplier

	if is_on_floor() and velocity.y <= 0.0:
		# A small downward velocity helps maintain floor contact.
		velocity.y = -0.5
		return

	var applied_gravity := gravity

	if velocity.y < 0.0:
		applied_gravity *= fall_gravity_multiplier

	velocity.y = max(
		velocity.y - applied_gravity * delta,
		-maximum_fall_speed
	)


func _find_mantle_candidate(direction: Vector3) -> Dictionary:
	if velocity.y < -maximum_mantle_fall_speed:
		return {}

	var space_state := get_world_3d().direct_space_state

	#
	# Test 1: Is there a wall in front of the player's torso?
	#
	var wall_ray_start := (
		global_position
		+ Vector3.UP * mantle_probe_height
	)

	var wall_ray_end := (
		wall_ray_start
		+ direction * mantle_reach
	)

	var wall_hit := _raycast(
		space_state,
		wall_ray_start,
		wall_ray_end,
		mantle_mask
	)

	if wall_hit.is_empty():
		return {}

	var wall_position: Vector3 = wall_hit["position"]
	var wall_normal: Vector3 = wall_hit["normal"]

	# Reject floors, ramps, and heavily sloped surfaces.
	if abs(wall_normal.y) > maximum_wall_normal_y:
		return {}

	# Ensure the wall faces the player.
	if direction.dot(-wall_normal) < 0.5:
		return {}

	#
	# Test 2: Search downward for a top surface behind the wall.
	#
	# wall_normal points out of the wall, toward the player.
	# Therefore -wall_normal points across the ledge.
	var over_ledge_position := (
		wall_position
		- wall_normal * mantle_landing_depth
	)

	var top_ray_start := Vector3(
		over_ledge_position.x,
		global_position.y
			+ mantle_maximum_height
			+ mantle_top_probe_extra,
		over_ledge_position.z
	)

	var top_ray_end := Vector3(
		over_ledge_position.x,
		global_position.y + mantle_minimum_height,
		over_ledge_position.z
	)

	var top_hit := _raycast(
		space_state,
		top_ray_start,
		top_ray_end,
		mantle_mask
	)

	if top_hit.is_empty():
		return {}

	var top_position: Vector3 = top_hit["position"]
	var top_normal: Vector3 = top_hit["normal"]

	var ledge_height := top_position.y - global_position.y

	if ledge_height < mantle_minimum_height:
		return {}

	if ledge_height > mantle_maximum_height:
		return {}

	# Reject sharply sloped or vertical landing surfaces.
	if top_normal.dot(Vector3.UP) < minimum_top_normal_y:
		return {}

	#
	# Test 3: Would the complete player capsule fit there?
	#
	var landing_position := (
		top_position
		+ Vector3.UP * mantle_floor_clearance
	)

	if not _capsule_fits_at(landing_position):
		return {}

	return {
		"position": landing_position,
		"wall_normal": wall_normal,
		"height": ledge_height,
	}


func _raycast(
	space_state: PhysicsDirectSpaceState3D,
	from: Vector3,
	to: Vector3,
	mask: int
) -> Dictionary:
	var excluded_bodies: Array[RID] = [get_rid()]

	var query := PhysicsRayQueryParameters3D.create(
		from,
		to,
		mask,
		excluded_bodies
	)

	query.collide_with_areas = false
	query.collide_with_bodies = true

	return space_state.intersect_ray(query)


func _capsule_fits_at(root_position: Vector3) -> bool:
	var space_state := get_world_3d().direct_space_state

	var query := PhysicsShapeQueryParameters3D.new()

	query.shape = collider.shape
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	query.margin = 0.01

	# Reconstruct where the CollisionShape3D would be if the
	# CharacterBody3D root were at root_position.
	var proposed_player_transform := Transform3D(
		global_transform.basis,
		root_position
	)

	query.transform = (
		proposed_player_transform
		* collider.transform
	)

	var overlaps := space_state.intersect_shape(query, 1)

	return overlaps.is_empty()


func _start_mantle(candidate: Dictionary) -> void:
	movement_state = MoveState.MANTLING

	velocity = Vector3.ZERO

	mantle_elapsed = 0.0
	mantle_start = global_position
	mantle_target = candidate["position"]

	var wall_normal: Vector3 = candidate["wall_normal"]
	var ledge_height: float = candidate["height"]

	# First move mostly upward and slightly away from the wall.
	# Then move across the edge toward the landing position.
	mantle_lift = (
		mantle_start
		+ Vector3.UP * (ledge_height + mantle_lift_extra)
		+ wall_normal * 0.04
	)

	var height_fraction := inverse_lerp(
		mantle_minimum_height,
		mantle_maximum_height,
		ledge_height
	)

	current_mantle_duration = lerp(
		mantle_duration * 0.8,
		mantle_duration * 1.15,
		clamp(height_fraction, 0.0, 1.0)
	)

	jump_buffer_timer = 0.0
	coyote_timer = 0.0


func _update_mantle(delta: float) -> void:
	mantle_elapsed += delta

	var t = clamp(
		mantle_elapsed / current_mantle_duration,
		0.0,
		1.0
	)

	var desired_position: Vector3

	# The first 55% of the animation raises the capsule.
	# The final 45% moves it across the ledge.
	if t < 0.55:
		var lift_t := _ease_in_out(t / 0.55)

		desired_position = mantle_start.lerp(
			mantle_lift,
			lift_t
		)
	else:
		var landing_t := _ease_in_out(
			(t - 0.55) / 0.45
		)

		desired_position = mantle_lift.lerp(
			mantle_target,
			landing_t
		)

	var requested_motion := desired_position - global_position

	# move_and_collide performs the requested displacement while still
	# respecting collision, unlike directly assigning global_position.
	var collision := move_and_collide(requested_motion)

	if collision != null:
		_abort_mantle()
		return

	if t >= 1.0:
		_finish_mantle()


func _finish_mantle() -> void:
	movement_state = MoveState.LOCOMOTION
	velocity = Vector3.ZERO

	apply_floor_snap()


func _abort_mantle() -> void:
	movement_state = MoveState.LOCOMOTION
	velocity = Vector3.ZERO


func _ease_in_out(t: float) -> float:
	t = clamp(t, 0.0, 1.0)

	# Smoothstep:
	# starts slowly, accelerates, then settles smoothly.
	return t * t * (3.0 - 2.0 * t)
