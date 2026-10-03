extends RefCounted
## A ray that sees through glass (the real-windows spec, 3): a window's
## glass stops bodies but not sight or light, so a guard's line of sight and
## the light probe's shadow ray go on past any collider in a `skip` group.

## At most this many casts (each pane or skipped body one more).
const CASTS := 8


## The first hit of `query` that is not in a `skip` group, or {} if none:
## each skipped collider is excluded and the ray cast again.
static func first_solid(space: PhysicsDirectSpaceState3D, query: PhysicsRayQueryParameters3D, skip: Array[StringName] = [&"glass"]) -> Dictionary:
	for i in CASTS:
		var hit := space.intersect_ray(query)

		if hit.is_empty():
			return hit

		var collider := hit.get("collider") as Node

		if collider == null or not skip.any(func(group): return collider.is_in_group(group)):
			return hit

		var exclude := query.exclude
		exclude.append(hit["rid"])
		query.exclude = exclude

	return {}
