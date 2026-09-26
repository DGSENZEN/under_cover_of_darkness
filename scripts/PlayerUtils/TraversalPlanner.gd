extends RefCounted
## Turns measurements into movement: picks rows from the variant table that
## match an obstacle profile, and builds a validated TraversalMove for one.

const ObstacleProfile := preload("res://scripts/PlayerUtils/ObstacleProfile.gd")
const MoveVariantRes := preload("res://scripts/PlayerUtils/MoveVariant.gd")
const TraversalMove := preload("res://scripts/PlayerUtils/TraversalMove.gd")
const TraversalScanner := preload("res://scripts/PlayerUtils/TraversalScanner.gd")

## Kinds that do not come from the table.
const KIND_PULL_UP := 100
const KIND_LOWER := 101
const KIND_CORNER := 102
const KIND_LEAP := 103
const KIND_DROP_RELEASE := 104

var scanner: TraversalScanner

## How far above the top the feet rise before moving across.
var lift_extra := 0.12
## Gap between the feet and the obstacle top at the peak of a vault.
var vault_clearance := 0.08
## Gap between the capsule and the wall while hanging.
var hang_gap := 0.02
## How far the eyes sit below the lip while hanging.
var hang_eye_drop := 0.25
## Height of the eyes above the body origin when standing.
var eye_height := 0.8
## Rounds the corners of the path. 0 = sharp polyline.
var corner_rounding := 2

## Hang leaps: speed along the arc, and how high the arc bulges.
var leap_speed := 6.5
var leap_arc_base := 0.25
var leap_arc_per_metre := 0.12
## How far a leap swings out from the wall it leaves.
var leap_push_off := 0.25
## The body gathers itself before launching.
var leap_windup_time := 0.12
var leap_windup_dip := 0.12
## Launch fast, slow into the catch.
var leap_ease_out := 0.45

## Corners: speed along the swing.
var corner_speed := 3.2

## Why the last generate() returned nothing.
var last_reject := ""

var _pull_up_variant: MoveVariantRes
var _lower_variant: MoveVariantRes


func _init() -> void:
	_pull_up_variant = MoveVariantRes.make(
		&"pull up", MoveVariantRes.Kind.MANTLE, 0.0, 99.0, 3.2, 0.45, 0.80, 1.0, 0.0
	) as MoveVariantRes
	_pull_up_variant.noise_db = 40.0
	_lower_variant = MoveVariantRes.make(
		&"lower", MoveVariantRes.Kind.HANG_ENTER, 0.0, 99.0, 2.6, 0.60, 1.10, 1.0, 0.0
	) as MoveVariantRes


# ---------------------------------------------------------------------------
# Classify
# ---------------------------------------------------------------------------

## Every row that matches, in table order. The caller tries them one by one,
## because a row can match on paper and still fail its fit tests.
func classify(
	profile: ObstacleProfile,
	is_sneaking: bool,
	is_sprinting: bool,
	table: Array[Resource]
) -> Array[MoveVariantRes]:
	var matches: Array[MoveVariantRes] = []

	for entry in table:
		var variant := entry as MoveVariantRes

		if variant == null:
			continue

		if _matches(variant, profile, is_sneaking, is_sprinting):
			matches.append(variant)

	return matches


func _matches(
	v: MoveVariantRes,
	p: ObstacleProfile,
	is_sneaking: bool,
	is_sprinting: bool
) -> bool:
	if p.height < v.min_height or p.height > v.max_height:
		return false

	if v.air == MoveVariantRes.Air.GROUNDED and p.airborne:
		return false

	if v.air == MoveVariantRes.Air.AIRBORNE and not p.airborne:
		return false

	match v.stance:
		MoveVariantRes.Stance.SNEAK:
			if not is_sneaking:
				return false
		MoveVariantRes.Stance.NOT_SNEAK:
			if is_sneaking:
				return false
		MoveVariantRes.Stance.SPRINT:
			if not is_sprinting:
				return false

	if p.approach_speed < v.min_speed:
		return false

	if v.needs_thin:
		var limit := v.thickness_base + v.thickness_per_speed * p.approach_speed

		if p.thickness > limit:
			return false

		if p.far_drop() > v.max_drop:
			return false

	if v.kind == MoveVariantRes.Kind.MANTLE:
		if p.headroom == ObstacleProfile.Headroom.BLOCKED:
			return false

	return true


# ---------------------------------------------------------------------------
# Generate
# ---------------------------------------------------------------------------

func generate(
	profile: ObstacleProfile,
	variant: MoveVariantRes,
	start: Vector3
) -> TraversalMove:
	last_reject = ""

	match variant.kind:
		MoveVariantRes.Kind.VAULT:
			return _generate_vault(profile, variant, start)
		MoveVariantRes.Kind.HANG_ENTER:
			return _generate_hang(profile, variant, start)
		_:
			return _generate_mantle(profile, variant, start)


func _generate_mantle(
	p: ObstacleProfile,
	variant: MoveVariantRes,
	start: Vector3
) -> TraversalMove:
	var half := scanner.standing_height * 0.5
	var standoff := scanner.radius + scanner.landing_margin

	# Rise in front of the face, just far enough out for the capsule to clear it.
	var lift_y := maxf(p.top_point.y, p.landing.y) + half + lift_extra
	var lift := p.face_point + p.face_normal * standoff
	lift.y = lift_y

	var landing := scanner.origin_for_feet(p.landing)
	var raw := PackedVector3Array([start, lift, landing])

	var try_standing := p.headroom == ObstacleProfile.Headroom.STANDING
	var shapes: Array[bool] = []

	if try_standing:
		shapes.append(false)

	shapes.append(true)

	for crouched in shapes:
		var path := _best_clear_path(raw, crouched)

		if path.is_empty():
			continue

		var move := _new_move(variant, path, p)
		move.use_crouch_shape = crouched

		# Landing on a rail or a fence top: arrive balanced, with no momentum
		# to carry you off the far side.
		if p.thickness < scanner.radius * 2.0:
			move.exit_velocity = Vector3.ZERO
			move.speed_kept = 0.0

		return move

	last_reject = "%s: path blocked" % variant.label
	return null


func _generate_vault(
	p: ObstacleProfile,
	variant: MoveVariantRes,
	start: Vector3
) -> TraversalMove:
	if not p.has_far_floor:
		last_reject = "vault: nothing to land on"
		return null

	var half := scanner.standing_height * 0.5
	var standoff := scanner.radius + scanner.landing_margin
	var over_y := p.top_point.y + half + vault_clearance

	var rise := p.face_point + p.face_normal * standoff
	rise.y = over_y

	var past := Vector3(p.far_floor.x, over_y, p.far_floor.z)
	var landing := scanner.origin_for_feet(p.far_floor)

	var raw := PackedVector3Array([start, rise, past, landing])

	for crouched in [false, true]:
		var path := _best_clear_path(raw, crouched)

		if path.is_empty():
			continue

		var move := _new_move(variant, path, p)
		move.use_crouch_shape = crouched

		# A vault never slows you down: play it at least as fast as you arrived.
		var speed := maxf(variant.move_speed, p.approach_speed)
		move.duration = clampf(move.total_length / speed, variant.min_time, variant.max_time)
		return move

	last_reject = "vault: path blocked"
	return null


func _generate_hang(
	p: ObstacleProfile,
	variant: MoveVariantRes,
	start: Vector3
) -> TraversalMove:
	var anchor := hang_anchor(p.face_point, p.face_normal, p.top_point.y)

	if not scanner.fits(anchor, false):
		last_reject = "hang: no room for the body"
		return null

	var path := PackedVector3Array([start, anchor])

	if not scanner.path_is_clear(path, false):
		last_reject = "hang: path blocked"
		return null

	var move := _new_move(variant, path, p)
	move.exit_velocity = Vector3.ZERO
	move.ends_in_hang = true
	move.hang_normal = p.face_normal
	move.hang_lip_y = p.top_point.y
	return move


## Body origin while hanging from a lip at lip_y on a face.
func hang_anchor(face_point: Vector3, normal: Vector3, lip_y: float) -> Vector3:
	var anchor := face_point + normal * (scanner.radius + hang_gap)
	anchor.y = lip_y - hang_eye_drop - eye_height
	return anchor


## From a hang, climb onto the ledge above.
func pull_up(hang_normal: Vector3, start: Vector3) -> TraversalMove:
	var profile := scanner.scan(-hang_normal, Vector3.ZERO, true)

	if profile == null:
		last_reject = "pull up: " + scanner.last_reject
		return null

	if profile.headroom == ObstacleProfile.Headroom.BLOCKED:
		last_reject = "pull up: no room on top"
		return null

	var move := _generate_mantle(profile, _pull_up_variant, start)

	if move != null:
		move.kind = KIND_PULL_UP

	return move


## From standing at an edge, climb down into a hang below it.
func lower(edge: Dictionary, start: Vector3, current_yaw: float) -> TraversalMove:
	last_reject = ""

	var face_point: Vector3 = edge["face_point"]
	var normal: Vector3 = edge["normal"]
	var lip_y: float = edge["lip_y"]
	var anchor := hang_anchor(face_point, normal, lip_y)

	if not scanner.fits(anchor, false):
		last_reject = "lower: no room to hang"
		return null

	var out := Vector3(anchor.x, start.y, anchor.z)
	var raw := PackedVector3Array([start, out, anchor])
	var path := _best_clear_path(raw, false)
	var crouched := false

	if path.is_empty():
		path = _best_clear_path(raw, true)
		crouched = true

	if path.is_empty():
		last_reject = "lower: path blocked"
		return null

	var move := TraversalMove.new()
	move.label = _lower_variant.label
	move.noise_db = 25.0
	move.kind = KIND_LOWER
	move.points = path
	move.smoothing = _lower_variant.smoothing
	move.use_crouch_shape = crouched
	move.bake()
	move.duration = clampf(
		move.total_length / _lower_variant.move_speed,
		_lower_variant.min_time,
		_lower_variant.max_time
	)
	move.ends_in_hang = true
	move.hang_normal = normal
	move.hang_lip_y = lip_y

	move.has_contact = true
	move.contact_point = Vector3(face_point.x, lip_y, face_point.z)
	move.contact_normal = normal

	# Turn to face the wall. Looking along -normal means yaw = atan2(n.x, n.z).
	var target_yaw := atan2(normal.x, normal.z)
	move.yaw_delta = wrapf(target_yaw - current_yaw, -PI, PI)
	return move


# ---------------------------------------------------------------------------
# Hanging: probing for lips, corners, leaps
# ---------------------------------------------------------------------------

## Is there a lip to hang from beside `point`, on a face whose normal is
## roughly `normal`, at about `lip_y`? Shimmy, corners and sideways leaps all
## ask this same question.
## Returns {} or { "anchor", "normal", "lip_y", "face_point" }.
func probe_hang(
	point: Vector3,
	normal: Vector3,
	lip_y: float,
	max_lip_change: float
) -> Dictionary:
	last_reject = ""

	# Is there a face here? Probe just under the lip.
	var chest := Vector3(point.x, lip_y - 0.2, point.z)
	var wall := scanner.ray(chest, chest - normal * (scanner.radius + 0.6))

	if wall.is_empty():
		last_reject = "ledge ends"
		return {}

	var raw_normal: Vector3 = wall["normal"]

	if absf(raw_normal.y) > scanner.max_wall_normal_y:
		last_reject = "not a wall"
		return {}

	var face_normal := Vector3(raw_normal.x, 0.0, raw_normal.z).normalized()
	var face_point: Vector3 = wall["position"]

	# Is there a lip on top of it, near the expected height?
	var lip_probe := face_point - face_normal * scanner.top_probe_depth
	var lip := scanner.ray(
		Vector3(lip_probe.x, lip_y + max_lip_change + 0.15, lip_probe.z),
		Vector3(lip_probe.x, lip_y - max_lip_change - 0.05, lip_probe.z),
		false
	)

	if lip.is_empty():
		last_reject = "no lip"
		return {}

	var lip_point: Vector3 = lip["position"]
	var lip_normal: Vector3 = lip["normal"]

	if lip_normal.y < scanner.min_top_normal_y:
		last_reject = "lip too steep"
		return {}

	var anchor := hang_anchor(face_point, face_normal, lip_point.y)

	if not scanner.fits(anchor, false):
		last_reject = "blocked"
		return {}

	return {
		"anchor": anchor,
		"normal": face_normal,
		"lip_y": lip_point.y,
		"face_point": face_point,
	}


## The ledge ended, or a wall is in the way: carry the hang around the corner.
## `direction` is the sideways direction the player was shimmying in.
func corner(
	start: Vector3,
	hang_normal: Vector3,
	lip_y: float,
	direction: Vector3
) -> TraversalMove:
	var r := scanner.radius
	var raw := PackedVector3Array()
	var target := {}

	# Inside corner: a wall faces us along the ledge. Slide onto it.
	target = probe_hang(start, -direction, lip_y, 0.12)

	if not target.is_empty():
		var inside_anchor: Vector3 = target["anchor"]
		raw = PackedVector3Array([start, inside_anchor])
	else:
		# Outside corner: the wall ends and its side face continues the ledge.
		var beside := (
			start
			+ direction * (r + 0.3)
			- hang_normal * (r * 2.0 + hang_gap + 0.15)
		)
		target = probe_hang(beside, direction, lip_y, 0.12)

		if target.is_empty():
			last_reject = "corner: nothing to hold around it"
			return null

		# Swing wide of the corner so the capsule clears it.
		var outside_anchor: Vector3 = target["anchor"]
		var via := start + direction * (r + hang_gap + 0.15)
		via.y = (start.y + outside_anchor.y) * 0.5
		raw = PackedVector3Array([start, via, outside_anchor])

	var path := _best_clear_path(raw, false)

	if path.is_empty():
		last_reject = "corner: path blocked"
		return null

	var new_normal: Vector3 = target["normal"]
	var move := TraversalMove.new()
	move.label = &"corner"
	move.noise_db = 30.0
	move.kind = KIND_CORNER
	move.points = path
	move.smoothing = 0.6
	move.bake()
	move.duration = clampf(move.total_length / corner_speed, 0.25, 0.55)
	move.ends_in_hang = true
	move.hang_normal = new_normal
	move.hang_lip_y = target["lip_y"]

	# Keep facing the wall as it turns.
	move.yaw_delta = hang_normal.signed_angle_to(new_normal, Vector3.UP)
	_set_contact_from_target(move, target)
	return move


## From one hang to another. `target` comes from probe_hang or from a scan:
## { "anchor", "normal", "lip_y" }. Only validated targets produce a move, so
## a leap can be refused but never missed.
func leap(start: Vector3, target: Dictionary, from_normal: Vector3) -> TraversalMove:
	last_reject = ""

	var finish: Vector3 = target["anchor"]
	var to_normal: Vector3 = target["normal"]
	var travel := finish - start
	var flat := Vector3(travel.x, 0.0, travel.z).length()
	var lift := leap_arc_base + leap_arc_per_metre * flat
	var middle := (start + finish) * 0.5

	# Where the arc bulges. Straight across is tried first. When the two
	# ledges face different ways there is usually a corner between them, so
	# also try leaving ALONG the wall we hold and turning in late, and
	# arriving ALONG the new wall after turning early.
	var from_lateral := from_normal.cross(Vector3.UP).normalized()
	var to_lateral := to_normal.cross(Vector3.UP).normalized()
	var controls: Array[Vector3] = [middle + from_normal * leap_push_off]

	if from_normal.angle_to(to_normal) > deg_to_rad(20.0):
		controls.append(start + from_lateral * travel.dot(from_lateral) + from_normal * 0.3)
		controls.append(finish - to_lateral * travel.dot(to_lateral) + to_normal * 0.3)

		var outward := from_normal + to_normal

		if outward.length() > 0.2:
			controls.append(middle + outward.normalized() * 1.0)

	var path := PackedVector3Array()

	for lift_scale in [1.0, 1.8]:
		for control_flat in controls:
			var control: Vector3 = control_flat
			control.y = maxf(start.y, finish.y) + lift * lift_scale

			var candidate := _arc(start, control, finish, 14)

			if scanner.path_is_clear(candidate, false):
				path = candidate
				break

		if not path.is_empty():
			break

	if path.is_empty():
		last_reject = "leap: no clear path to that ledge"
		return null

	var move := TraversalMove.new()
	move.label = &"leap"
	move.noise_db = 50.0
	move.kind = KIND_LEAP
	move.points = path
	move.smoothing = 0.0
	move.ease_out = leap_ease_out
	move.windup_time = leap_windup_time
	move.windup_dip = leap_windup_dip
	move.bake()
	move.duration = clampf(move.total_length / leap_speed, 0.3, 0.8)
	move.ends_in_hang = true
	move.hang_normal = to_normal
	move.hang_lip_y = target["lip_y"]
	_set_contact_from_target(move, target)
	return move


## A quadratic curve from a to c, bulging toward b.
func _arc(a: Vector3, b: Vector3, c: Vector3, samples: int) -> PackedVector3Array:
	var points := PackedVector3Array()

	for i in range(samples + 1):
		var u := float(i) / float(samples)
		points.append(a.lerp(b, u).lerp(b.lerp(c, u), u))

	return points


func _set_contact_from_target(move: TraversalMove, target: Dictionary) -> void:
	if not target.has("face_point"):
		return

	var face: Vector3 = target["face_point"]
	var lip: float = target["lip_y"]
	move.has_contact = true
	move.contact_point = Vector3(face.x, lip, face.z)
	move.contact_normal = target["normal"]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _new_move(
	variant: MoveVariantRes,
	path: PackedVector3Array,
	p: ObstacleProfile
) -> TraversalMove:
	var move := TraversalMove.new()
	move.label = variant.label
	move.kind = variant.kind
	move.points = path
	move.smoothing = variant.smoothing
	move.bake()
	move.duration = clampf(
		move.total_length / variant.move_speed,
		variant.min_time,
		variant.max_time
	)
	move.exit_velocity = -p.face_normal * p.approach_speed * variant.speed_kept
	move.entry_speed = p.approach_speed
	move.speed_kept = variant.speed_kept
	move.noise_db = variant.noise_db
	move.has_contact = true
	move.contact_point = p.face_point
	move.contact_normal = p.face_normal
	return move


## Prefers the rounded path; falls back to the sharp one; empty if neither fits.
func _best_clear_path(raw: PackedVector3Array, crouched: bool) -> PackedVector3Array:
	if corner_rounding > 0:
		var rounded := _round_corners(raw, corner_rounding)

		if scanner.path_is_clear(rounded, crouched):
			return rounded

	if scanner.path_is_clear(raw, crouched):
		return raw

	return PackedVector3Array()


## Chaikin corner cutting that keeps the first and last point in place.
func _round_corners(points: PackedVector3Array, iterations: int) -> PackedVector3Array:
	var current := points

	for _i in range(iterations):
		if current.size() < 3:
			break

		var next := PackedVector3Array()
		next.append(current[0])

		for i in range(current.size() - 1):
			var a := current[i]
			var b := current[i + 1]

			if i > 0:
				next.append(a.lerp(b, 0.25))

			if i < current.size() - 2:
				next.append(a.lerp(b, 0.75))

		next.append(current[current.size() - 1])
		current = next

	return current
