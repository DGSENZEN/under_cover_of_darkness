extends RefCounted
## Places to watch from: the ones a level marks (Marker3D nodes in the group
## "cine_vantage", with metadata `lens` "long" or "medium" if they are only
## good for one), and, where none serves, places sampled on rings round the
## men. A place must see every man's head (past walls and past other men),
## stand on the side it is asked to, and be about as far off as the lens
## wants, standing clear of any wall (a ray from inside one sees out through
## it) and out of every man's body; one whose frame the stones fill at the
## lens (a crenel, a wall's end) is never taken; one with something half in
## the way (a post, a crate's corner: watched from hiding) is better, a marked
## one better still, and one whose frame a wall closes in worse.

const CineShot := preload("res://scripts/Cinema/CineShot.gd")

## How far off each lens wants to be (m), and where it samples.
const IDEAL := {&"long": 18.0, &"medium": 5.0, &"near": 2.6}
const RINGS := {&"long": [12.0, 18.0, 24.0], &"medium": [4.0, 6.0], &"near": [2.0, 2.8, 3.6]}
const HEIGHTS := [1.6, 3.5]
## Close quarters (a room, a passage): nearer, and not up by the ceiling.
const NEAR_HEIGHTS := [1.5, 2.1]
const BEARINGS := 16
## Markers further than this from the men are not considered.
const MARKER_REACH := 30.0
## Something this far to the side of the sight line counts as half in the way.
const FOREGROUND := 0.8
const FOREGROUND_BONUS := 0.3
const MARKER_BONUS := 0.5
## Nothing this near a camera (m); no man's body this near it (m, from the
## body's surface: no camera in a shoulder).
const CLEARANCE := 0.4
const BODY_CLEARANCE := 0.35
## The men's bodies (the guards' collision layer): they hide who is behind
## them.
const BODIES := 2
## A frame's fill: sight lines across it (columns, rows, as shares of its
## half-width and half-height); one meeting stone nearer than FILL_NEAR (m)
## or FILL_SHARE of the way to him fills its part. A frame over WALLED_FILL
## filled is never taken.
const FILL_COLUMNS := [-0.8, -0.4, 0.0, 0.4, 0.8]
const FILL_ROWS := [-0.7, 0.0, 0.7]
const FILL_NEAR := 1.5
const FILL_SHARE := 0.45
const WALLED_FILL := 0.3
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
		var lens_fov := rad_to_deg(2.0 * atan(3.0 / (2.0 * maxf(at.distance_to(centre), 1.0)))) * 1.5

		if fill(space, at, centre, lens_fov, 16.0 / 9.0, _rids(live)) > WALLED_FILL:
			continue

		if not open(space, at, centre, lens_fov, 16.0 / 9.0, _rids(live)):
			score -= WALLED

		if _half_hidden(space, at, centre, live):
			score += FOREGROUND_BONUS

		if bool(place[1]):
			score += MARKER_BONUS

		if score > best_score:
			best_score = score
			best_at = at

	return best_at


## Whether every man's head can be seen from `at`, past walls and (with
## `bodies`) past any other man standing in the way (the men's own bodies do
## not count against it).
static func sees(space: PhysicsDirectSpaceState3D, at: Vector3, men: Array, bodies := true) -> bool:
	var exclude := _rids(men)

	for m in men:
		if m == null or not is_instance_valid(m):
			continue

		var query := PhysicsRayQueryParameters3D.create(at, CineShot.head_of(m), (1 | BODIES) if bodies else 1, exclude)
		query.collide_with_areas = false

		if not space.intersect_ray(query).is_empty():
			return false

	return true


## Whether a camera at `at` stands clear of every wall (nothing within
## CLEARANCE) and out of every man (BODY_CLEARANCE).
static func clear(space: PhysicsDirectSpaceState3D, at: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	var ball := SphereShape3D.new()
	ball.radius = CLEARANCE
	query.shape = ball
	query.transform = Transform3D(Basis.IDENTITY, at)
	query.collision_mask = 1

	if not space.intersect_shape(query, 1).is_empty():
		return false

	ball.radius = BODY_CLEARANCE
	query.collision_mask = BODIES
	return space.intersect_shape(query, 1).is_empty()


## How much of the frame from `at` onto `look` (through `fov`, `aspect`) is
## filled at the lens (0..1): of sight lines across it, the share that meet a
## wall, or another man's back (`exclude`: the shot's own men), nearer than
## FILL_NEAR or FILL_SHARE of the way to what it looks at.
static func fill(space: PhysicsDirectSpaceState3D, at: Vector3, look: Vector3, fov: float, aspect: float, exclude: Array[RID]) -> float:
	var view := look - at
	var distance := view.length()

	if distance < 0.1:
		return 1.0

	var forward := view / distance
	var right := forward.cross(Vector3.UP)
	right = right.normalized() if right.length() > 0.01 else Vector3.RIGHT
	var up := right.cross(forward).normalized()
	var half_v := tan(deg_to_rad(fov) * 0.5) * distance
	var half_h := half_v * aspect
	var near := minf(FILL_NEAR, FILL_SHARE * distance)
	var filled := 0

	for column in FILL_COLUMNS:
		for row in FILL_ROWS:
			var query := PhysicsRayQueryParameters3D.create(at, look + right * half_h * float(column) + up * half_v * float(row), 1 | BODIES, exclude)
			query.collide_with_areas = false
			var hit := space.intersect_ray(query)

			if not hit.is_empty() and at.distance_to(hit["position"]) < near:
				filled += 1

	return float(filled) / float(FILL_COLUMNS.size() * FILL_ROWS.size())


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

			# (Heights from the floor he stands on: his head, less his height.)
			for height in NEAR_HEIGHTS if lens == &"near" else HEIGHTS:
				found.append([Vector3(centre.x, centre.y - CineShot.HEAD_STANDING, centre.z) + out + Vector3.UP * float(height), false])

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

