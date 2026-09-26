extends RefCounted
## All the physics queries of the traversal system live here: measuring the
## obstacle ahead, finding an edge to lower over, and fit-testing the capsule.
##
## The scanner never moves the player. It only answers questions.

const ObstacleProfile := preload("res://scripts/PlayerUtils/ObstacleProfile.gd")

## Query shapes are shrunk by this much so resting contact with the floor or a
## wall the player is touching does not count as "blocked".
const SKIN := 0.02

var body: CharacterBody3D
var mask := 1

var radius := 0.5
var standing_height := 2.0
var crouch_height := 1.2

## Tops lower than this are left to normal walking.
var step_height := 0.35
## Highest top that can be grabbed, measured from the feet.
var max_reach := 2.6
## How far ahead of the capsule axis the scan looks, at standstill.
var scan_distance := 1.2
## Extra look-ahead per m/s of approach speed.
var scan_lookahead_time := 0.1
## How far behind the face the top surface is sampled.
var top_probe_depth := 0.1
var max_thickness_walk := 1.6
var max_far_drop := 3.0
## Tops thinner than this cannot be stood on.
var min_standable_thickness := 0.15
var landing_margin := 0.05
var floor_clearance := 0.03
var min_top_normal_y := 0.7
var max_wall_normal_y := 0.25
var min_facing_dot := 0.5

## Why the last scan returned nothing. Shown by the debug overlay.
var last_reject := ""

## Layers the BODY must not end up inside. Guards (layer 2) are not climbed
## on, so scans ignore them, but a move must never carry you into one.
var body_mask := 1 | 2

## Bodies every query ignores besides the player: whatever is in your hands.
var extra_exclude: Array[RID] = []

var _sweep_box := BoxShape3D.new()
var _stand_shape := CapsuleShape3D.new()
var _crouch_shape := CapsuleShape3D.new()


func setup(
	p_body: CharacterBody3D,
	p_radius: float,
	p_standing_height: float,
	p_crouch_height: float
) -> void:
	body = p_body
	radius = p_radius
	standing_height = p_standing_height
	crouch_height = p_crouch_height

	_stand_shape.radius = radius - SKIN
	_stand_shape.height = standing_height - SKIN * 2.0

	_crouch_shape.radius = radius - SKIN
	_crouch_shape.height = crouch_height - SKIN * 2.0


func feet_position() -> Vector3:
	return body.global_position - Vector3.UP * standing_height * 0.5


## Body origin that puts the feet on `surface_point`.
func origin_for_feet(surface_point: Vector3) -> Vector3:
	return surface_point + Vector3.UP * (standing_height * 0.5 + floor_clearance)


# ---------------------------------------------------------------------------
# Obstacle scan
# ---------------------------------------------------------------------------

func scan(direction: Vector3, velocity: Vector3, airborne: bool) -> ObstacleProfile:
	return scan_from(body.global_position, direction, velocity, airborne)


## The same scan from any body-origin position. Chained moves scan from
## mid-air, and hang leaps scan from points along the view direction.
## `velocity` may be a carried velocity rather than the body's real one.
func scan_from(
	origin: Vector3,
	direction: Vector3,
	velocity: Vector3,
	airborne: bool,
	lookahead_time := -1.0
) -> ObstacleProfile:
	if lookahead_time < 0.0:
		lookahead_time = scan_lookahead_time

	last_reject = ""

	var space := body.get_world_3d().direct_space_state
	var feet := origin - Vector3.UP * standing_height * 0.5
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)

	#
	# How high may the sweep reach? A low ceiling would otherwise be mistaken
	# for a wall, because the sweep box would start inside it.
	#
	var top_limit := feet.y + max_reach
	var ceiling := ray(
		origin,
		Vector3(origin.x, top_limit + 0.1, origin.z)
	)

	if not ceiling.is_empty():
		var ceiling_point: Vector3 = ceiling["position"]
		top_limit = minf(top_limit, ceiling_point.y - 0.05)

	var bottom := feet.y + step_height
	var box_height := top_limit - bottom

	if box_height < 0.2:
		last_reject = "no room to scan"
		return null

	#
	# 1. Sweep a tall thin slab forward. It finds the nearest face at ANY
	#    height between a step and full reach, in one query.
	#
	_sweep_box.size = Vector3(radius * 1.2, box_height, 0.05)

	var reach := scan_distance + maxf(horizontal_velocity.dot(direction), 0.0) * lookahead_time
	var sweep_basis := Basis.looking_at(direction, Vector3.UP)
	var sweep_origin := Vector3(
		origin.x,
		bottom + box_height * 0.5,
		origin.z
	)

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _sweep_box
	query.transform = Transform3D(sweep_basis, sweep_origin)
	query.motion = direction * reach
	query.collision_mask = mask
	query.exclude = [body.get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var fractions := space.cast_motion(query)

	if fractions.size() < 2 or fractions[1] >= 1.0:
		last_reject = "nothing ahead"
		return null

	# cast_motion only returns fractions. To learn WHAT was hit, park the
	# shape at the unsafe fraction and ask for rest info.
	query.motion = Vector3.ZERO
	query.transform = Transform3D(
		sweep_basis,
		sweep_origin + direction * (reach * fractions[1] + 0.01)
	)

	var rest := space.get_rest_info(query)
	var contact_height := bottom + box_height * 0.5

	if not rest.is_empty():
		var rest_point: Vector3 = rest["point"]
		contact_height = clampf(rest_point.y, bottom + 0.02, top_limit - 0.02)

	# A ray at the contact height gives a clean point and normal. The contact
	# can sit exactly on an edge, so try a few heights around it.
	var face := {}

	for offset in [0.0, -0.1, 0.1, -0.25, 0.25]:
		var height := clampf(contact_height + offset, bottom + 0.02, top_limit - 0.02)
		var ray_from := Vector3(origin.x, height, origin.z)
		face = ray(ray_from, ray_from + direction * (reach + 0.3))

		if not face.is_empty():
			break

	if face.is_empty():
		last_reject = "face ray missed"
		return null

	var face_point: Vector3 = face["position"]
	var raw_normal: Vector3 = face["normal"]

	if absf(raw_normal.y) > max_wall_normal_y:
		last_reject = "not a wall (slope)"
		return null

	var normal := Vector3(raw_normal.x, 0.0, raw_normal.z).normalized()
	var facing_dot := direction.dot(-normal)

	if facing_dot < min_facing_dot:
		last_reject = "glancing angle"
		return null

	#
	# 2. Find the top surface just behind the face.
	#
	var across := -normal
	var probe := face_point + across * top_probe_depth
	var top := ray(
		Vector3(probe.x, top_limit, probe.z),
		Vector3(probe.x, feet.y + step_height * 0.5, probe.z),
		false
	)

	if top.is_empty():
		last_reject = "no top within reach"
		return null

	var top_point: Vector3 = top["position"]
	var top_normal: Vector3 = top["normal"]

	if top_normal.y < min_top_normal_y:
		last_reject = "top too steep"
		return null

	var height := top_point.y - feet.y

	if height < step_height:
		last_reject = "just a step"
		return null

	var profile := ObstacleProfile.new()
	profile.face_point = Vector3(face_point.x, top_point.y, face_point.z)
	profile.face_normal = normal
	profile.top_point = top_point
	profile.top_normal = top_normal
	profile.feet_y = feet.y
	profile.height = height
	profile.facing_dot = facing_dot
	profile.airborne = airborne
	profile.approach_speed = maxf(horizontal_velocity.dot(across), 0.0)
	profile.collider = face.get("collider")

	#
	# 3. Thickness: walk across the top until the surface ends.
	#
	var step_size := 0.1
	var steps := int(max_thickness_walk / step_size)

	for i in range(1, steps + 1):
		var walked := step_size * i
		var sample := top_point + across * walked
		var under := ray(sample + Vector3.UP * 0.3, sample - Vector3.UP * 0.15, false)

		if under.is_empty():
			profile.thickness = top_probe_depth + walked - step_size * 0.5
			profile.far_edge = profile.face_point + across * profile.thickness
			break

		var under_point: Vector3 = under["position"]

		# Something rises out of the top: a wall or a higher step. Not thin.
		if under_point.y > top_point.y + 0.2:
			# A low top with another low rise right behind it is a staircase.
			# Walking handles stairs; the traversal system must leave them alone.
			var next_rise := under_point.y - top_point.y

			if height <= step_height * 2.5 and next_rise <= step_height + 0.05 and walked <= 0.6:
				last_reject = "stairs"
				return null

			break

	#
	# 4. Far floor: is there ground to land on beyond the far edge?
	#
	if profile.thickness < INF:
		var beyond := profile.far_edge + across * (radius + landing_margin + 0.1)
		var far := ray(
			Vector3(beyond.x, top_point.y + 0.1, beyond.z),
			Vector3(beyond.x, feet.y - max_far_drop, beyond.z),
			false
		)

		if not far.is_empty():
			var far_normal: Vector3 = far["normal"]

			if far_normal.y >= min_top_normal_y:
				profile.has_far_floor = true
				profile.far_floor = far["position"]

	#
	# 5. Landing spot for a mantle, and how much headroom it has.
	#
	var depth := radius + landing_margin

	if profile.thickness < depth * 2.0:
		depth = maxf(profile.thickness * 0.5, 0.05)

	var landing_probe := profile.face_point + across * depth
	var landing := ray(
		landing_probe + Vector3.UP * 0.4,
		landing_probe - Vector3.UP * 0.3,
		false
	)

	profile.landing = top_point

	if not landing.is_empty():
		profile.landing = landing["position"]

	if profile.thickness < min_standable_thickness:
		profile.headroom = ObstacleProfile.Headroom.BLOCKED
	elif fits(origin_for_feet(profile.landing), false):
		profile.headroom = ObstacleProfile.Headroom.STANDING
	elif fits(origin_for_feet(profile.landing), true):
		profile.headroom = ObstacleProfile.Headroom.CROUCHED
	else:
		profile.headroom = ObstacleProfile.Headroom.BLOCKED

	return profile


# ---------------------------------------------------------------------------
# Edge below the player, for lowering into a hang
# ---------------------------------------------------------------------------

## Returns {} when there is no edge, otherwise
## { "face_point": Vector3, "normal": Vector3, "lip_y": float }.
func edge_below(direction: Vector3, needed_drop: float) -> Dictionary:
	var feet := feet_position()
	var ahead := feet + direction * (radius + 0.35)

	# Floor continues in front of us: no edge.
	if not ray(ahead + Vector3.UP * 0.1, ahead - Vector3.UP * needed_drop).is_empty():
		return {}

	# Look back at the face of the ledge we are standing on.
	var from := ahead - Vector3.UP * 0.3
	var back := ray(from, from - direction * (radius + 0.35 + 0.4))

	if back.is_empty():
		return {}

	var raw_normal: Vector3 = back["normal"]

	if absf(raw_normal.y) > max_wall_normal_y:
		return {}

	var normal := Vector3(raw_normal.x, 0.0, raw_normal.z).normalized()

	if normal.dot(direction) < min_facing_dot:
		return {}

	var face_point: Vector3 = back["position"]
	var lip_y := feet.y
	var lip_probe := face_point - normal * top_probe_depth
	var lip := ray(lip_probe + Vector3.UP * 0.5, lip_probe - Vector3.UP * 0.3, false)

	if not lip.is_empty():
		var lip_point: Vector3 = lip["position"]
		lip_y = lip_point.y

	return {
		"face_point": face_point,
		"normal": normal,
		"lip_y": lip_y,
	}


# ---------------------------------------------------------------------------
# Landing target for an assisted jump
# ---------------------------------------------------------------------------

## Looks along `direction` for a gap followed by a standable surface.
## Returns {} or { "point": Vector3, "distance": float }.
func find_jump_target(
	direction: Vector3,
	min_distance: float,
	max_distance: float,
	max_rise: float,
	max_drop: float
) -> Dictionary:
	var feet := feet_position()
	var seen_gap := false
	var step_size := 0.25
	var distance := 0.75

	while distance <= max_distance:
		var sample := feet + direction * distance
		var hit := ray(
			sample + Vector3.UP * (max_rise + 0.2),
			sample - Vector3.UP * (max_drop + 0.2),
			false
		)

		var is_gap := true

		if not hit.is_empty():
			var hit_point: Vector3 = hit["position"]
			var hit_normal: Vector3 = hit["normal"]
			var rise := hit_point.y - feet.y

			# A surface counts as "ground continues" only near our own height.
			if rise > -0.5 and rise <= max_rise and hit_normal.y >= min_top_normal_y:
				is_gap = false

			if (
				seen_gap
				and distance >= min_distance
				and rise >= -max_drop
				and rise <= max_rise
				and hit_normal.y >= min_top_normal_y
			):
				# Aim a little past the edge so the whole capsule lands.
				var inside := hit_point + direction * radius * 0.6
				var under := ray(inside + Vector3.UP * 0.3, inside - Vector3.UP * 0.3, false)

				if not under.is_empty():
					var landing: Vector3 = under["position"]

					if fits(origin_for_feet(landing), false):
						return {
							"point": landing,
							"distance": distance + radius * 0.6,
						}

		if is_gap:
			seen_gap = true

		distance += step_size

	return {}


# ---------------------------------------------------------------------------
# Primitives
# ---------------------------------------------------------------------------

func _exclude() -> Array[RID]:
	var list: Array[RID] = [body.get_rid()]
	list.append_array(extra_exclude)
	return list


func ray(from: Vector3, to: Vector3, hit_back_faces := true) -> Dictionary:
	var space := body.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to, mask, _exclude())
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.hit_back_faces = hit_back_faces
	query.hit_from_inside = false
	return space.intersect_ray(query)


## Would the capsule be free of geometry with the body ORIGIN at origin_position?
func fits(origin_position: Vector3, crouched: bool) -> bool:
	var space := body.get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	var center := origin_position

	if crouched:
		query.shape = _crouch_shape
		# The crouched capsule keeps the feet planted, so its center drops.
		center -= Vector3.UP * (standing_height - crouch_height) * 0.5
	else:
		query.shape = _stand_shape

	query.transform = Transform3D(Basis.IDENTITY, center)
	query.collision_mask = mask | body_mask
	query.exclude = _exclude()
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.margin = 0.0

	return space.intersect_shape(query, 1).is_empty()


## Fit-tests the capsule along a whole path of origin positions.
func path_is_clear(points: PackedVector3Array, crouched: bool) -> bool:
	var spacing := 0.12
	var skip := 0.05
	var travelled := 0.0

	for i in range(1, points.size()):
		var a := points[i - 1]
		var b := points[i]
		var length := a.distance_to(b)

		if length < 0.0001:
			continue

		var samples := maxi(int(ceil(length / spacing)), 1)

		for s in range(1, samples + 1):
			var u := float(s) / float(samples)

			if travelled + length * u < skip:
				continue

			if not fits(a.lerp(b, u), crouched):
				return false

		travelled += length

	return true
