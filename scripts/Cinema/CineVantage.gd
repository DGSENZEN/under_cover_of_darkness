extends RefCounted
## Places to watch from: the ones a level marks (Marker3D nodes in the group
## "cine_vantage", with metadata `lens` "long" or "medium" if they are only
## good for one), and, where none serves, places sampled on rings round the
## men. A place must see every man's head, stand on the side it is asked to,
## and be about as far off as the lens wants, standing clear of any wall (a
## ray from inside one sees out through it); one with something half in the
## way (a post, a crate's corner: watched from hiding) is better, a marked one
## better still, and one whose frame a wall fills worse.

const CineShot := preload("res://scripts/Cinema/CineShot.gd")

## How far off each lens wants to be (m), and where it samples.
const IDEAL := {&"long": 18.0, &"medium": 5.0}
const RINGS := {&"long": [12.0, 18.0, 24.0], &"medium": [4.0, 6.0]}
const HEIGHTS := [1.6, 3.5]
const BEARINGS := 16
## Markers further than this from the men are not considered.
const MARKER_REACH := 30.0
## Something this far to the side of the sight line counts as half in the way.
const FOREGROUND := 0.8
const FOREGROUND_BONUS := 0.3
const MARKER_BONUS := 0.5
## Nothing this near a camera (m).
const CLEARANCE := 0.4
## A frame walled in (open() false) counts this much against a place.
const WALLED := 0.6
## How much of the frame's half-width out its sight lines go.
const FRAME_OUT := 2.0 / 3.0


## The best place to watch `men` from through `lens` (&"long", &"medium"), on
## `side` (ZERO for any); INF if none sees them.
static func best(tree: SceneTree, men: Array, lens: StringName, side: Vector3, space: PhysicsDirectSpaceState3D) -> Vector3:
	var live := men.filter(func(m): return m != null and is_instance_valid(m))

	if live.is_empty() or space == null:
		return Vector3.INF

	var centre := CineShot.centre_of(live)
	var ideal := float(IDEAL.get(lens, IDEAL[&"long"]))
	var best_at := Vector3.INF
	var best_score := -INF

	for place in _candidates(tree, centre, lens):
		var at: Vector3 = place[0]
		var flat := Vector3(at.x - centre.x, 0.0, at.z - centre.z)

		if side != Vector3.ZERO and flat.dot(side) <= 0.0:
			continue

		if not clear(space, at) or not sees(space, at, live):
			continue

		var score := maxf(1.0 - absf(flat.length() - ideal) / ideal, 0.0)

		if not open(space, at, centre, rad_to_deg(2.0 * atan(3.0 / (2.0 * maxf(at.distance_to(centre), 1.0)))) * 1.5, 16.0 / 9.0, _rids(live)):
			score -= WALLED

		if _half_hidden(space, at, centre, live):
			score += FOREGROUND_BONUS

		if bool(place[1]):
			score += MARKER_BONUS

		if score > best_score:
			best_score = score
			best_at = at

	return best_at


## Whether every man's head can be seen from `at` (the men's own bodies do
## not count against it).
static func sees(space: PhysicsDirectSpaceState3D, at: Vector3, men: Array) -> bool:
	var exclude := _rids(men)

	for m in men:
		if m == null or not is_instance_valid(m):
			continue

		var query := PhysicsRayQueryParameters3D.create(at, CineShot.head_of(m), 1, exclude)
		query.collide_with_areas = false

		if not space.intersect_ray(query).is_empty():
			return false

	return true


## Whether a camera at `at` stands clear of every wall (nothing within
## CLEARANCE).
static func clear(space: PhysicsDirectSpaceState3D, at: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	var ball := SphereShape3D.new()
	ball.radius = CLEARANCE
	query.shape = ball
	query.transform = Transform3D(Basis.IDENTITY, at)
	query.collision_mask = 1
	return space.intersect_shape(query, 1).is_empty()


## Whether the frame from `at` onto `head` (through `fov`, `aspect`) is open:
## of four sight lines two thirds out across it (left, right, up, down) at
## his depth, no more than one meets a wall nearer than halfway to him.
static func open(space: PhysicsDirectSpaceState3D, at: Vector3, head: Vector3, fov: float, aspect: float, exclude: Array[RID]) -> bool:
	var view := head - at
	var distance := view.length()

	if distance < 0.1:
		return false

	var forward := view / distance
	var right := forward.cross(Vector3.UP)
	right = right.normalized() if right.length() > 0.01 else Vector3.RIGHT
	var up := right.cross(forward).normalized()
	var half_v := tan(deg_to_rad(fov) * 0.5) * distance * FRAME_OUT
	var half_h := half_v * aspect
	var walled := 0

	for point in [head + right * half_h, head - right * half_h, head + up * half_v, head - up * half_v]:
		var query := PhysicsRayQueryParameters3D.create(at, point, 1, exclude)
		query.collide_with_areas = false
		var hit := space.intersect_ray(query)

		if not hit.is_empty() and at.distance_to(hit["position"]) < distance * 0.5:
			walled += 1

	return walled <= 1


## [place, marked], markers first.
static func _candidates(tree: SceneTree, centre: Vector3, lens: StringName) -> Array:
	var found := []

	for mark in tree.get_nodes_in_group(&"cine_vantage"):
		if not (mark is Node3D) or not is_instance_valid(mark):
			continue

		var only: StringName = StringName(mark.get_meta(&"lens", &""))

		if only != &"" and only != lens:
			continue

		if (mark as Node3D).global_position.distance_to(centre) <= MARKER_REACH:
			found.append([(mark as Node3D).global_position, true])

	for distance in RINGS.get(lens, RINGS[&"long"]):
		for i in BEARINGS:
			var bearing := TAU * float(i) / float(BEARINGS)
			var out := Vector3(sin(bearing), 0.0, cos(bearing)) * float(distance)

			for height in HEIGHTS:
				found.append([Vector3(centre.x, 0.0, centre.z) + out + Vector3.UP * float(height), false])

	return found


## Whether a sight line beside the real one, FOREGROUND off it, is blocked:
## something stands half in the way.
static func _half_hidden(space: PhysicsDirectSpaceState3D, at: Vector3, centre: Vector3, men: Array) -> bool:
	var line := centre - at
	line.y = 0.0

	if line.length() < 0.01:
		return false

	var across := Vector3.UP.cross(line.normalized()) * FOREGROUND
	var exclude := _rids(men)

	for offset in [across, -across]:
		var query := PhysicsRayQueryParameters3D.create(at + offset, centre + offset, 1, exclude)
		query.collide_with_areas = false

		if not space.intersect_ray(query).is_empty():
			return true

	return false


static func _rids(men: Array) -> Array[RID]:
	var rids: Array[RID] = []

	for m in men:
		if m is CollisionObject3D and is_instance_valid(m):
			rids.append((m as CollisionObject3D).get_rid())

	return rids
