extends RefCounted
## Scores reachable hiding places for Guard and shared Squad searches.
## Darkness, enclosure, occlusion, heading, rooms and ledges affect score; taken and
## recently searched points are excluded. Optional hunt_area metadata bounds orders.
## Places contain stand: Vector3, peer: Vector3 (INF means no focus), kind: StringName
## (nook/dark/open/room/ledge), and door: Node3D for rooms. pick() returns {} on failure.

const LightProbe := preload("res://scripts/StimuliSystem/LightProbe.gd")

## Places tried on the floor round the middle (and over each, a ledge): on
## rings RING_GAP (m) apart from RING_FIRST out to the reach, one every
## RING_GAP along each, each a little off it (RING_JITTER, m), so that no two
## searches try quite the same places, and no nook is missed by chance.
const RING_FIRST := 2.0
const RING_GAP := 1.6
const RING_JITTER := 0.45
## How far a place may be off the floor where it was looked for (m, flat), and
## off its level (m).
const ON_FLOOR := 1.0
const SAME_LEVEL := 1.5
## A man crouched: where he would be, off the floor (m). In a nook, he looks
## this far (m) past where he stands into it. A place by a wall is tried
## again DEEPER (m) further in toward it (into the corner, if there is one).
const CROUCH := 0.55
const NOOK_LOOK := 0.7
const DEEPER := 0.8
## Round a place, this many ways, this far (m): how many are shut. Three
## (SHUT_WALL) are only a wall beside it; SHUT_ALL more and it is as shut in
## as a place gets (a corner is two thirds of the way). A nook, from
## SHUT_NOOK of that.
const SHUT_WAYS := 8
const SHUT_REACH := 1.5
const SHUT_WALL := 3
const SHUT_ALL := 3
const SHUT_NOOK := 0.3
## What counts, and how much.
const DARK_WEIGHT := 1.0
const SHUT_WEIGHT := 1.2
const UNSEEN_WEIGHT := 0.7
const AHEAD_WEIGHT := 0.9
const FAR_COST := 0.03
const JITTER := 0.25
## A room: its doorway this near the middle (beyond the reach, m); he goes
## ROOM_IN into it and looks ROOM_LOOK in. Worth this much more than a place
## on the floor.
const ROOM_NEAR := 4.0
const ROOM_IN := 2.5
const ROOM_LOOK := 5.0
const ROOM_WEIGHT := 1.2
## A ledge: this much higher than the floor at least (m), looked for this far
## over it (and as far to the side); he stands on the floor before it,
## LEDGE_BACK (m) out from over where it was found toward the middle (no
## further from it than LEDGE_UNDER more), and looks just over its lip. Worth
## this much more.
const LEDGE_LEAST := 1.3
const LEDGE_UP := 2.6
const LEDGE_UNDER := 2.5
const LEDGE_BACK := 1.5
const LEDGE_LOOK := 0.4
const LEDGE_WEIGHT := 0.4
## The way you went: a place ahead of it, only within this of it (the dot of
## the way to it and yours), when only ahead will do.
const AHEAD_ONLY := 0.3
## A place searched is left alone this near it (m).
const SEARCHED_NEAR := 3.0
## Where a man searches round in his hunt area: of its hiding places and
## doorways, one of the best few: well clear of what has been searched (up to
## AREA_CLEAR m counts), not far to go (AREA_FAR_COST a metre), a little
## chance.
const AREA_CHOICES := 3
const AREA_CLEAR := 12.0
const AREA_FAR_COST := 0.15
const AREA_JITTER := 2.0
## Floor anywhere in it tried besides (points on the navmesh in the box).
const AREA_SAMPLES := 12
## Of the best places, this many at most are tried for a way there.
const REACH_TRIES := 6


## Returns a reachable place dictionary or {} (including an unready nav map).
## World-space centre/heading and reach bound candidates; taken/searched contain
## Vector3 points and spread keeps distance from taken. ahead_only restricts heading.
## Result stand/peer are Vector3, kind is StringName; room results include door.
static func pick(guard: Node3D, centre: Vector3, heading: Vector3, reach: float, taken: Array, spread: float, searched: Array, ahead_only := false) -> Dictionary:
	var map: RID = guard.get_world_3d().navigation_map

	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return {}

	var space := guard.get_world_3d().direct_space_state
	var exclude := _exclude(guard)
	var eye: Vector3 = guard.eye_position() if guard.has_method("eye_position") else guard.global_position + Vector3.UP * 1.6
	var way := Vector3(heading.x, 0.0, heading.z)
	way = way.normalized() if way.length() > 0.01 else Vector3.ZERO
	var ahead_angle := atan2(way.z, way.x)
	# [score, place] for each place worth a look, and the REACH_TRIES best
	# scores so far (least first).
	var places: Array = []
	var best: Array = []
	# The rest of a place on the floor, asked only of one that could be among
	# the best (_weigh).
	var see := func(place: Dictionary) -> void: _see_floor(guard, space, exclude, eye, place)
	var ring := RING_FIRST

	while ring <= reach + 0.01:
		var count := maxi(6, int(ceil(TAU * ring / RING_GAP)))
		var turn := randf() * TAU

		for k in count:
			var angle := turn + TAU * float(k) / float(count)

			if ahead_only and way != Vector3.ZERO and absf(wrapf(angle - ahead_angle, -PI, PI)) > 0.4 * PI:
				continue

			var off := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * RING_JITTER
			var guess := centre + Vector3(cos(angle), 0.0, sin(angle)) * ring + off
			var point := NavigationServer3D.map_get_closest_point(map, guess)

			if _flat(point, guess) <= ON_FLOOR and absf(point.y - centre.y) <= SAME_LEVEL and _free(point, taken, spread, searched):
				var place := _floor_place(space, exclude, point)
				# By a wall: a step further in, into the corner if there is one.
				var inward: Vector3 = place["inward"]
				_weigh(places, best, place, guard, centre, way, ahead_only, see)

				if inward.length() > 0.5:
					var deeper_guess := point + inward.normalized() * DEEPER
					var deeper := NavigationServer3D.map_get_closest_point(map, deeper_guess)

					if _flat(deeper, deeper_guess) <= ON_FLOOR and absf(deeper.y - point.y) < 0.3 and _flat(deeper, point) > 0.2 and _free(deeper, taken, spread, searched):
						_weigh(places, best, _floor_place(space, exclude, deeper), guard, centre, way, ahead_only, see)

			# Over it, somewhere you could have climbed to.
			_weigh(places, best, _ledge_place(guard, space, exclude, map, centre, guess, taken, spread, searched), guard, centre, way, ahead_only)

		ring += RING_GAP

	# Through a door near it: a room to look round.
	for node in guard.get_tree().get_nodes_in_group(&"doors"):
		_weigh(places, best, _room_place(guard, space, exclude, map, node as Node3D, centre, reach, taken, spread, searched), guard, centre, way, ahead_only)

	# The best of them he has a way to.
	places.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	var start := NavigationServer3D.map_get_closest_point(map, guard.global_position)

	for i in mini(places.size(), REACH_TRIES):
		var place: Dictionary = places[i][1]

		if _reachable(map, start, place["stand"], _layers_of(guard)):
			place.erase("score")
			place.erase("inward")
			return place

	return {}


## Adds `place` (if there is one, and it is the way you went when only that
## will do) to `places`, with its score: its own, the way you went, less how
## far he has to go, and a little chance. `best`: the REACH_TRIES best scores
## so far. A place on the floor not yet seen to (`see`: its light, whether he
## sees it) is seen to only if it could be among them, were it as dark and as
## out of his sight as a place gets; else it could never be tried, and is
## left.
static func _weigh(places: Array, best: Array, place: Dictionary, guard: Node3D, centre: Vector3, way: Vector3, ahead_only: bool, see := Callable()) -> void:
	if place.is_empty():
		return

	var stand: Vector3 = place["stand"]

	if not in_area(guard, stand):
		return

	var ahead := _ahead(way, centre, stand)

	if ahead_only and ahead < AHEAD_ONLY:
		return

	var chance := randf() * JITTER

	if see.is_valid():
		var most := float(place["score"]) + DARK_WEIGHT + UNSEEN_WEIGHT + ahead * AHEAD_WEIGHT - FAR_COST * guard.global_position.distance_to(stand) + chance

		if best.size() >= REACH_TRIES and most < float(best[0]) - 0.001:
			return

		see.call(place)

	var score := float(place["score"]) + ahead * AHEAD_WEIGHT - FAR_COST * guard.global_position.distance_to(stand) + chance
	places.append([score, place])
	best.append(score)
	best.sort()

	if best.size() > REACH_TRIES:
		best.pop_front()


## The ground `guard` was sent to search (his "hunt_area"), or an empty box:
## anywhere.
static func area_of(guard: Node) -> AABB:
	return guard.get_meta(&"hunt_area", AABB()) if guard != null else AABB()


static func has_area(guard: Node) -> bool:
	return area_of(guard).has_volume()


## Whether `point` is on `guard`'s ground (anywhere is, if he has none).
static func in_area(guard: Node, point: Vector3) -> bool:
	var area := area_of(guard)
	return not area.has_volume() or area.grow(0.25).has_point(point)


## Somewhere in `guard`'s hunt area to search round: of its hiding places,
## the doorways and some floor in it, one of the AREA_CHOICES best (clear of
## anywhere `searched`, near him, and his to get to); its middle on the
## navmesh if none is.
static func area_centre(guard: Node3D, searched: Array) -> Vector3:
	var area := area_of(guard)
	var map: RID = guard.get_world_3d().navigation_map
	var choices: Array = []

	for node in guard.get_tree().get_nodes_in_group(&"hide_spot"):
		choices.append((node as Node3D).global_position)

	for node in guard.get_tree().get_nodes_in_group(&"doors"):
		if node.has_method("doorway"):
			choices.append(node.doorway())

	# And floor anywhere in it (the walks and a tower top have no hiding
	# places or doors).
	for k in AREA_SAMPLES:
		var guess := area.position + Vector3(randf(), randf(), randf()) * area.size
		choices.append(NavigationServer3D.map_get_closest_point(map, guess))

	var scored: Array = []

	var layers := _layers_of(guard)

	for point in choices:
		# (Only where he can get to: not a room locked against him.)
		if not area.has_point(point) or not _reachable(map, guard.global_position, point, layers):
			continue

		var clear := INF

		for done in searched:
			clear = minf(clear, (point as Vector3).distance_to(done))

		scored.append([minf(clear, AREA_CLEAR) - guard.global_position.distance_to(point) * AREA_FAR_COST + randf() * AREA_JITTER, point])

	if scored.is_empty():
		return NavigationServer3D.map_get_closest_point(map, area.get_center())

	scored.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	return NavigationServer3D.map_get_closest_point(map, scored[randi() % mini(AREA_CHOICES, scored.size())][1])


## Whether a man at `start` has a way along the navmesh to `to` (on his
## `layers`: the doorways his keys open).
static func _reachable(map: RID, start: Vector3, to: Vector3, layers := 1) -> bool:
	var path := NavigationServer3D.map_get_path(map, start, to, true, layers)

	if path.is_empty():
		return false

	var end: Vector3 = path[path.size() - 1]
	return _flat(end, to) < 0.6 and absf(end.y - to.y) < 1.0


## A place on the floor: how shut in; the rest (how dark, whether he can see
## it, what he looks into) once it is worth asking (_see_floor). Its score
## so far is only its being shut in.
static func _floor_place(space: PhysicsDirectSpaceState3D, exclude: Array[RID], point: Vector3) -> Dictionary:
	var low := point + Vector3.UP * CROUCH
	var shut := 0
	# The way into it: toward what shuts it in.
	var inward := Vector3.ZERO

	for k in SHUT_WAYS:
		var angle := TAU * float(k) / float(SHUT_WAYS)
		var out := Vector3(cos(angle), 0.0, sin(angle))

		if not space.intersect_ray(_ray(low, low + out * SHUT_REACH, exclude)).is_empty():
			shut += 1
			inward += out

	var shut_in := clampf(float(shut - SHUT_WALL) / float(SHUT_ALL), 0.0, 1.0)
	return {"stand": point, "inward": inward, "shut_in": shut_in, "score": SHUT_WEIGHT * shut_in}


## The rest of a place on the floor (_floor_place): how dark, whether he can
## see it; and what he looks into on his way (the place itself, if it is
## somewhere to hide).
static func _see_floor(guard: Node3D, space: PhysicsDirectSpaceState3D, exclude: Array[RID], eye: Vector3, place: Dictionary) -> void:
	var low: Vector3 = place["stand"] + Vector3.UP * CROUCH
	var inward: Vector3 = place["inward"]
	var shut_in: float = place["shut_in"]
	var dark := 1.0 - LightProbe.light_at(guard, low, exclude)
	var unseen := 1.0 if not space.intersect_ray(_ray(eye, low, exclude)).is_empty() else 0.5 * dark
	var kind := &"nook" if shut_in >= SHUT_NOOK else (&"dark" if dark > 0.6 else &"open")
	var peer := Vector3.INF

	if kind == &"nook":
		peer = low + (inward.normalized() * NOOK_LOOK if inward.length() > 0.01 else Vector3.ZERO)
	elif kind == &"dark":
		peer = low

	place["peer"] = peer
	place["kind"] = kind
	place["score"] = DARK_WEIGHT * dark + SHUT_WEIGHT * shut_in + UNSEEN_WEIGHT * unseen
	place.erase("shut_in")


## Higher up over `guess` (a ledge, a gallery, a stack you could climb): he
## stands back from its foot and looks up over its lip. {} if there is none,
## or he could not see onto it.
static func _ledge_place(guard: Node3D, space: PhysicsDirectSpaceState3D, exclude: Array[RID], map: RID, centre: Vector3, guess: Vector3, taken: Array, spread: float, searched: Array) -> Dictionary:
	var up := NavigationServer3D.map_get_closest_point(map, guess + Vector3.UP * LEDGE_UP)

	if up.y < centre.y + LEDGE_LEAST or _flat(up, guess) > LEDGE_UP:
		return {}

	# In front of it, the side facing the middle: the floor there (never a
	# scrap inside the block under it), and the lip nearest that.
	var toward := Vector3(centre.x - up.x, 0.0, centre.z - up.z)

	if toward.length() < 0.5:
		return {}

	var front := Vector3(up.x, centre.y, up.z) + toward.normalized() * LEDGE_BACK
	var stand := NavigationServer3D.map_get_closest_point(map, front)

	if absf(stand.y - centre.y) > SAME_LEVEL or _flat(stand, front) > ON_FLOOR or _flat(stand, up) > LEDGE_UNDER + LEDGE_BACK:
		return {}

	var lip := NavigationServer3D.map_get_closest_point(map, Vector3(stand.x, up.y, stand.z))

	if lip.y < centre.y + LEDGE_LEAST or not _free(stand, taken, spread, searched):
		return {}

	var look := lip + Vector3.UP * LEDGE_LOOK

	if not space.intersect_ray(_ray(stand + Vector3.UP * 1.6, look, exclude)).is_empty():
		return {}

	var dark := 1.0 - LightProbe.light_at(guard, lip + Vector3.UP * CROUCH, exclude)
	return {"stand": stand, "peer": look, "kind": &"ledge", "score": LEDGE_WEIGHT + DARK_WEIGHT * dark + UNSEEN_WEIGHT}


## The room through `door`, if its doorway is near the middle and he can go
## in: {} if not.
static func _room_place(guard: Node3D, space: PhysicsDirectSpaceState3D, exclude: Array[RID], map: RID, door: Node3D, centre: Vector3, reach: float, taken: Array, spread: float, searched: Array) -> Dictionary:
	if door == null or not is_instance_valid(door) or not door.has_method("doorway") or not door.has_method("facing"):
		return {}

	if bool(door.get("locked")):
		var keys: Variant = guard.get("inventory")

		if keys == null or not keys.has_method("has_key") or not keys.has_key(door.get("key_id")):
			return {}

	var doorway: Vector3 = door.doorway()

	if _flat(doorway, centre) > reach + ROOM_NEAR or absf(doorway.y - centre.y) > SAME_LEVEL:
		return {}

	# In is the side away from where you were (the side he is not on, if
	# that was at the door itself): back out through it is no room to search.
	var front: Vector3 = door.facing()
	var from := centre if _flat(centre, doorway) > 1.0 else guard.global_position
	var into := -front if front.dot(from - doorway) >= 0.0 else front
	var guess := doorway + into * ROOM_IN
	var stand := NavigationServer3D.map_get_closest_point(map, guess)

	if _flat(stand, guess) > ON_FLOOR or absf(stand.y - doorway.y) > SAME_LEVEL or not _free(stand, taken, spread, searched):
		return {}

	var dark := 1.0 - LightProbe.light_at(guard, stand + Vector3.UP * CROUCH, exclude)
	# Shut, it hides the room from him.
	var unseen := 1.0 if not bool(door.get("is_open")) else 0.5 * dark
	return {"stand": stand, "peer": doorway + into * ROOM_LOOK + Vector3.UP * CROUCH, "kind": &"room", "door": door,
		"score": ROOM_WEIGHT + DARK_WEIGHT * dark + UNSEEN_WEIGHT * unseen}


## Whether `point` is free to search: far enough from what others have, and
## not searched not long since.
static func _free(point: Vector3, taken: Array, spread: float, searched: Array) -> bool:
	for other in taken:
		if _flat(other, point) < spread:
			return false

	for done in searched:
		if _flat(done, point) < SEARCHED_NEAR:
			return false

	return true


## How much `point` is the way you went from the middle: -1..1 (0 if that is
## not known).
static func _ahead(way: Vector3, centre: Vector3, point: Vector3) -> float:
	var away := Vector3(point.x - centre.x, 0.0, point.z - centre.z)
	return way.dot(away.normalized()) if way != Vector3.ZERO and away.length() > 0.01 else 0.0


static func _exclude(guard: Node3D) -> Array[RID]:
	var exclude: Array[RID] = []

	if guard is CollisionObject3D:
		exclude.append((guard as CollisionObject3D).get_rid())

	# You are no wall.
	for body in guard.get_tree().get_nodes_in_group(&"player"):
		if body is CollisionObject3D:
			exclude.append((body as CollisionObject3D).get_rid())

	return exclude


static func _ray(from: Vector3, to: Vector3, exclude: Array[RID]) -> PhysicsRayQueryParameters3D:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1, exclude)
	query.collide_with_areas = false
	return query


## The navmesh layers `guard` walks (his keys' doorways among them).
static func _layers_of(guard: Node) -> int:
	var agent: Variant = guard.get("_agent")
	return (agent as NavigationAgent3D).navigation_layers if agent is NavigationAgent3D else 1


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
