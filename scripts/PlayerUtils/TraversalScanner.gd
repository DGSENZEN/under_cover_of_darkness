extends RefCounted
## Measures traversal geometry and checks capsule clearance without moving the body.
## Call setup() before querying. Body origins use the standing capsule centre;
## crouched queries lower their centre to keep the feet at the same position.

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
## A rise behind a top at least this high and within this far of it is a step
## of stairs going on up (ObstacleProfile.on_stairs).
const MIN_STAIR_RISE := 0.08
const STAIR_BEHIND := 0.9
## A rail to lower over (rail_ahead): its top this high over your feet,
## no thicker than this.
const RAIL_LOW := 0.5
const RAIL_HIGH := 1.4
const RAIL_THICK := 0.45
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


## Stores the body and capsule dimensions in metres; rebuilds reusable skin-shrunk shapes.
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


# Obstacle scan

## Scans from the current body origin; returns an ObstacleProfile or null and sets last_reject.
func scan(direction: Vector3, velocity: Vector3, airborne: bool) -> ObstacleProfile:
	return scan_from(body.global_position, direction, velocity, airborne)


## Scans at world body origin with forward direction and world velocity.
## Negative lookahead_time uses scan_lookahead_time; max_top_y limits world top height.
## Returns null on rejection and updates last_reject; never moves the body.
func scan_from(
	origin: Vector3,
	direction: Vector3,
	velocity: Vector3,
	airborne: bool,
	lookahead_time := -1.0,
	max_top_y := INF
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
	var top_limit := minf(feet.y + max_reach, max_top_y)
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
	# can sit exactly on an edge, so try a few heights around it: close ones
	# first, for a thin edge (a top's plank, a deck with no bulwark), whose
	# contact is on its top or bottom face, which a ray there only grazes.
	var face := {}

	for offset in [0.0, -0.03, 0.03, -0.06, 0.06, -0.1, 0.1, -0.25, 0.25]:
		var height := clampf(contact_height + offset, bottom + 0.02, top_limit - 0.02)
		var ray_from := Vector3(origin.x, height, origin.z)
		face = ray(ray_from, ray_from + direction * (reach + 0.3))

		if not face.is_empty():
			break

	# Still missed (the contact on the sweep's side, off the ray's line): the
	# sweep's own contact is the face.
	if face.is_empty() and not rest.is_empty() and absf((rest["normal"] as Vector3).y) < min_top_normal_y:
		face = {"position": rest["point"], "normal": rest["normal"]}

	if face.is_empty():
		last_reject = "face ray missed"
		return null

	var face_point: Vector3 = face["position"]
	var raw_normal: Vector3 = face["normal"]

	# Traversal can use steep tilted banks. Walking handles walkable slopes;
	# dedicated kick and hanging probes keep their vertical-face limit.
	if absf(raw_normal.y) >= min_top_normal_y:
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
	var top := {}
	var measured_depth := top_probe_depth
	# A single 10 cm inset can overshoot a boat rail and measure its lower
	# floor instead. Keep the highest top at the face, including thin lips.
	for depth in [SKIN, top_probe_depth]:
		var probe: Vector3 = face_point + across * depth
		var sample := ray(Vector3(probe.x, top_limit, probe.z), Vector3(probe.x, feet.y + step_height * 0.5, probe.z), false)
		if not sample.is_empty() and (top.is_empty() or (sample["position"] as Vector3).y > (top["position"] as Vector3).y):
			top = sample
			measured_depth = depth

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
	# (A step's rise behind the top, if stairs go on up from it.)
	var stair_rise := 0.0

	for i in range(1, steps + 1):
		var walked := step_size * i
		var sample := top_point + across * walked
		var under := ray(sample + Vector3.UP * 0.3, sample - Vector3.UP * 0.15, false)

		if under.is_empty():
			profile.thickness = measured_depth + walked - step_size * 0.5
			profile.far_edge = profile.face_point + across * profile.thickness
			break

		var under_point: Vector3 = under["position"]

		if stair_rise == 0.0 and walked <= STAIR_BEHIND and under_point.y - top_point.y >= MIN_STAIR_RISE \
				and under_point.y - top_point.y <= step_height + 0.05:
			stair_rise = under_point.y - top_point.y

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

	# Stairs going on up from the top (a water stair out of the sea, a flight
	# met from its side): the capsule never fits flat on a tread with the next
	# riser behind it, but stands across the next tread's nose, a rise or two
	# up, as it does walking a staircase. (A step walked up to is walking's,
	# a jump on a staircase a jump; out of the water, any step is a way out.)
	if profile.headroom == ObstacleProfile.Headroom.BLOCKED and stair_rise > 0.0 and profile.thickness >= min_standable_thickness \
			and (height > step_height * 2.5 or body.get("water") != null):
		for lift in [stair_rise, stair_rise * 2.0]:
			var raised: Vector3 = profile.landing + Vector3.UP * lift

			if fits(origin_for_feet(raised), false):
				profile.landing = raised
				profile.headroom = ObstacleProfile.Headroom.STANDING
				profile.on_stairs = true
				break

	return profile


# Edge below the player, for lowering into a hang

## Returns {} when there is no edge, otherwise
## { "face_point": Vector3, "normal": Vector3, "lip_y": float }.
func edge_below(direction: Vector3, needed_drop: float) -> Dictionary:
	var feet := feet_position()
	var ahead := feet + direction * (radius + 0.35)

	# Floor continues in front of us: no edge.
	if not ray(ahead + Vector3.UP * 0.1, ahead - Vector3.UP * needed_drop).is_empty():
		return {}

	# Look back at the face of the ledge we are standing on: a wall's, or a
	# thin floor's edge just under its lip (a mast's top, a yard, a plank
	# walk), hung from with nothing under it.
	var back := {}

	for depth in [0.3, 0.05]:
		var from: Vector3 = ahead - Vector3.UP * depth
		back = ray(from, from - direction * (radius + 0.35 + 0.4))

		if not back.is_empty():
			break

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


# A rail in front of the player, for lowering over it into a hang

## A low thin barrier in front of you with a drop beyond it (a ship's
## bulwark, a balcony's rail, a parapet over a street): its top RAIL_LOW to
## RAIL_HIGH over your feet, no thicker than RAIL_THICK, and under its far
## face at least `needed_drop` of air. Returns {} or the edge to hang from:
## { "face_point": its far face at its top, "normal": out (away from you),
## "lip_y": its top, "thickness": float }.
func rail_ahead(direction: Vector3, needed_drop: float) -> Dictionary:
	var feet := feet_position()
	var origin := body.global_position
	var near := {}

	for h in [RAIL_LOW * 0.5, RAIL_LOW + 0.1]:
		var from := Vector3(origin.x, feet.y + h, origin.z)
		near = ray(from, from + direction * (radius + 0.6))

		if not near.is_empty():
			break

	if near.is_empty() or absf((near["normal"] as Vector3).y) > max_wall_normal_y:
		return {}

	var near_point: Vector3 = near["position"]
	var probe := near_point + direction * 0.04
	var top := ray(Vector3(probe.x, feet.y + RAIL_HIGH + 0.2, probe.z), Vector3(probe.x, feet.y + RAIL_LOW * 0.5, probe.z), false)

	if top.is_empty():
		return {}

	var lip_y: float = (top["position"] as Vector3).y

	if lip_y < feet.y + RAIL_LOW or lip_y > feet.y + RAIL_HIGH or (top["normal"] as Vector3).y < min_top_normal_y:
		return {}

	# Across its top to where it ends: thin, or it is a wall to climb.
	var thickness := INF

	for i in range(1, int(RAIL_THICK / 0.04) + 2):
		var sample := near_point + direction * (0.04 * i)

		if ray(Vector3(sample.x, lip_y + 0.1, sample.z), Vector3(sample.x, lip_y - 0.15, sample.z), false).is_empty():
			thickness = 0.04 * i
			break

	if thickness > RAIL_THICK:
		return {}

	# Beyond it a drop, not a deck to step down onto.
	var beyond := near_point + direction * (thickness + 0.3)

	if not ray(Vector3(beyond.x, lip_y - 0.05, beyond.z), Vector3(beyond.x, lip_y - needed_drop, beyond.z)).is_empty():
		return {}

	# Its far face, looking back at it under its top.
	var from := Vector3(beyond.x, lip_y - 0.12, beyond.z)
	var back := ray(from, from - direction * 0.6)

	if back.is_empty():
		return {}

	var normal := Vector3((back["normal"] as Vector3).x, 0.0, (back["normal"] as Vector3).z).normalized()

	if normal.dot(direction) < min_facing_dot:
		return {}

	return {"face_point": back["position"], "normal": normal, "lip_y": lip_y, "thickness": thickness}


# Landing target for an assisted jump

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
	var last_gap := 0.0

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
				# Aim a little past the edge so the whole capsule lands: the edge
				# itself, not this sample, which can be most of a step past it
				# (the jump asked for would then move with where you happened
				# to take off, and the assist come and go with it).
				var edge := _landing_edge(feet, direction, last_gap, distance, max_rise, max_drop)
				var inside := feet + direction * (edge + radius * 0.6)
				inside.y = hit_point.y
				var under := ray(inside + Vector3.UP * 0.3, inside - Vector3.UP * 0.3, false)

				if not under.is_empty():
					var landing: Vector3 = under["position"]

					if fits(origin_for_feet(landing), false):
						return {
							"point": landing,
							"distance": edge + radius * 0.6,
						}

		if is_gap:
			seen_gap = true
			last_gap = distance

		distance += step_size

	return {}


## Between a gap `gap_at` and a landing `land_at` (distances from `feet`
## along `direction`), how far off the landing's edge is, to within a
## centimetre.
func _landing_edge(feet: Vector3, direction: Vector3, gap_at: float, land_at: float, max_rise: float, max_drop: float) -> float:
	var short := gap_at
	var far := land_at

	for i in 5:
		var middle := (short + far) * 0.5
		var sample := feet + direction * middle
		var hit := ray(sample + Vector3.UP * (max_rise + 0.2), sample - Vector3.UP * (max_drop + 0.2), false)
		var lands := false

		if not hit.is_empty():
			var rise: float = (hit["position"] as Vector3).y - feet.y
			lands = rise >= -max_drop and rise <= max_rise and (hit["normal"] as Vector3).y >= min_top_normal_y

		if lands:
			far = middle
		else:
			short = middle

	return far


# Primitives

func _exclude() -> Array[RID]:
	var list: Array[RID] = [body.get_rid()]
	list.append_array(extra_exclude)
	return list


## Returns a Godot ray-hit Dictionary, or {} on miss. Excludes player/extra_exclude;
## uses mask, solid bodies only, and does not detect hits from inside geometry.
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


## Sweep the capsule so thin obstacles cannot fall between fit samples.
## Also used during playback: a guard or door can enter a validated path.
func motion_is_clear(from: Vector3, to: Vector3, crouched: bool) -> bool:
	if not fits(to, crouched):
		return false

	if from.distance_squared_to(to) < 0.0000001:
		return true

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _crouch_shape if crouched else _stand_shape
	var center := from
	if crouched:
		center -= Vector3.UP * (standing_height - crouch_height) * 0.5
	query.transform = Transform3D(Basis.IDENTITY, center)
	query.motion = to - from
	query.collision_mask = mask | body_mask
	query.exclude = _exclude()
	query.collide_with_areas = false
	query.margin = 0.0
	var fractions := body.get_world_3d().direct_space_state.cast_motion(query)
	return fractions.size() == 2 and fractions[0] >= 1.0


## Sweeps each consecutive pair of world body origins with the chosen capsule.
## Empty/single-point paths return true without checking the isolated point.
func path_is_clear(points: PackedVector3Array, crouched: bool) -> bool:

	for i in range(1, points.size()):
		if not motion_is_clear(points[i - 1], points[i], crouched):
			return false

	return true
