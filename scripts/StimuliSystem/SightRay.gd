extends RefCounted
## A ray that sees through glass (the real-windows spec, 3): a window's
## glass stops bodies but not sight or light, so a guard's line of sight and
## the light probe's shadow ray go on past any collider in a `skip` group.

## At most this many casts (each pane or skipped body one more).
const CASTS := 8


## The first hit of `query` that is not in a `skip` group, or {} if none:
## each skipped collider is excluded and the ray cast again.
## The query's own exclusions are given back as they were (a caller that
## keeps one query, a halo's, sees no change).
static func first_solid(space: PhysicsDirectSpaceState3D, query: PhysicsRayQueryParameters3D, skip: Array[StringName] = [&"glass"]) -> Dictionary:
	var hit := space.intersect_ray(query)

	# (Nothing, or something solid, at the first cast: the common case,
	# nothing copied.)
	if hit.is_empty() or not _skipped(hit, skip):
		return hit

	var given := query.exclude
	var exclude := given.duplicate()
	var found := {}

	for i in CASTS - 1:
		exclude.append(hit["rid"])
		query.exclude = exclude
		hit = space.intersect_ray(query)

		if hit.is_empty():
			break

		if not _skipped(hit, skip):
			found = hit
			break

	query.exclude = given
	return found


static func _skipped(hit: Dictionary, skip: Array[StringName]) -> bool:
	var collider := hit.get("collider") as Node

	if collider == null:
		return false

	for group in skip:
		if collider.is_in_group(group):
			return true

	return false
