extends RefCounted
## Places to watch from: the ones a level marks (Marker3D nodes in the group
## "cine_vantage", with metadata `lens` "long" or "medium" if they are only
## good for one), and, where none serves, places sampled on rings round the
## men. A place must see every man's head, stand on the side it is asked to,
## and be about as far off as the lens wants; one with something half in
## the way (a post, a crate's corner: watched from hiding) is better, and a
## marked one better still.

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

		if not sees(space, at, live):
			continue

		var score := maxf(1.0 - absf(flat.length() - ideal) / ideal, 0.0)

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
