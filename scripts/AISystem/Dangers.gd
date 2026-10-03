extends RefCounted
## Queries hazards, explosives, loose throwables, weapons, weights and bells.
## Uses registered groups and physics queries. Item claims identify the reserving
## guard via weak metadata; nearby-item queries exclude items claimed by others.
## Queries return null, empty arrays or an empty StringName when no match exists.

## A blast this much past its own reach still counts: nobody stands at the
## very edge of one on purpose.
const POWDER_MARGIN := 1.0
## Behind a man: how far along the push to look, how near spikes or fire must
## be to that line, and how far down a drop must go to count.
const BEHIND_REACH := 2.2
const HAZARD_NEAR := 0.5
const DROP_HEIGHT := 2.2
## What a man picks up to throw: between these masses (kg), and resting.
const THROW_MASS_MIN := 0.4
const THROW_MASS_MAX := 12.0


## A lit powder barrel whose blast would reach `point`; null if none.
static func lit_powder_near(tree: SceneTree, point: Vector3, margin := POWDER_MARGIN) -> Node3D:
	for barrel in tree.get_nodes_in_group(&"explosives"):
		if not (barrel is Node3D) or barrel.is_queued_for_deletion() or barrel.get("lit") != true:
			continue

		if (barrel as Node3D).global_position.distance_to(point) < blast_reach(barrel) + margin:
			return barrel

	return null


## Unlit powder within `radius` of `point`, nearest first.
static func powder_near(tree: SceneTree, point: Vector3, radius: float) -> Array[Node3D]:
	var found: Array[Node3D] = []

	for barrel in tree.get_nodes_in_group(&"explosives"):
		if not (barrel is Node3D) or barrel.is_queued_for_deletion() or barrel.get("lit") == true:
			continue

		if (barrel as Node3D).global_position.distance_to(point) <= radius:
			found.append(barrel)

	found.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.global_position.distance_to(point) < b.global_position.distance_to(point))
	return found


## How far a barrel's blast reaches.
static func blast_reach(barrel: Object) -> float:
	var r: Variant = barrel.get("radius")
	return float(r) if r != null else 4.0


## What waits behind a man standing at `feet` if he is driven along `away`:
## "hazard" (spikes, fire, lit powder), "drop" (a fall of DROP_HEIGHT or more,
## with no wall to stop him first) or "" for nothing worse than the floor.
static func behind(asker: Node3D, feet: Vector3, away: Vector3, reach := BEHIND_REACH) -> StringName:
	var flat := Vector3(away.x, 0.0, away.z)

	if flat.length() < 0.01:
		return &""

	flat = flat.normalized()
	var tree := asker.get_tree()
	var space := asker.get_world_3d().direct_space_state

	for s in [0.6, 1.2, 1.8]:
		if s > reach:
			break

		var at: Vector3 = feet + flat * s + Vector3.UP * 0.9

		for hazard in tree.get_nodes_in_group(&"hazards"):
			if hazard is Node3D and not hazard.is_queued_for_deletion() and _near_shapes(hazard, at, HAZARD_NEAR):
				return &"hazard"

		if lit_powder_near(tree, at, -1.0) != null:
			return &"hazard"

	# A drop: nothing under the ground he would be driven onto, and no wall on
	# the way to stop him.
	for s in [0.9, 1.5]:
		if s > reach:
			break

		var over: Vector3 = feet + flat * s + Vector3.UP * 0.5
		var wall := PhysicsRayQueryParameters3D.create(feet + Vector3.UP * 0.5, over, 1)

		if not space.intersect_ray(wall).is_empty():
			return &""

		var down := PhysicsRayQueryParameters3D.create(over, over + Vector3.DOWN * (DROP_HEIGHT + 0.6), 1)

		if space.intersect_ray(down).is_empty():
			return &"drop"

	return &""


## Whether `point` is within `margin` of any of `area`'s box or cylinder shapes.
static func _near_shapes(area: Node3D, point: Vector3, margin: float) -> bool:
	for child in area.get_children():
		var holder := child as CollisionShape3D

		if holder == null or holder.shape == null or holder.disabled:
			continue

		var local := holder.global_transform.affine_inverse() * point
		var gap := INF

		if holder.shape is BoxShape3D:
			var half := (holder.shape as BoxShape3D).size * 0.5
			var clamped := Vector3(clampf(local.x, -half.x, half.x), clampf(local.y, -half.y, half.y), clampf(local.z, -half.z, half.z))
			gap = (holder.global_transform.basis * (local - clamped)).length()
		elif holder.shape is CylinderShape3D:
			var cylinder := holder.shape as CylinderShape3D
			var radial := maxf(Vector2(local.x, local.z).length() - cylinder.radius, 0.0)
			var vertical := maxf(absf(local.y) - cylinder.height * 0.5, 0.0)
			gap = Vector2(radial, vertical).length()
		elif holder.shape is SphereShape3D:
			gap = maxf(local.length() - (holder.shape as SphereShape3D).radius, 0.0)

		if gap <= margin:
			return true

	return false


## Loose things within `radius` of `point` that `guard` could pick up and
## throw: light enough, resting, not held (by you: "in_hand"), not a body, powder, treasure, a
## key, a tool or a blade; and not already another man's. Nearest first.
static func throwables_near(guard: Node3D, point: Vector3, radius: float) -> Array[RigidBody3D]:
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, point)
	query.collision_mask = 1
	query.collide_with_areas = false
	var found: Array[RigidBody3D] = []

	for hit in guard.get_world_3d().direct_space_state.intersect_shape(query, 24):
		var body := hit.get("collider") as RigidBody3D

		if body == null or found.has(body) or not throwable(body, guard):
			continue

		found.append(body)

	found.sort_custom(func(a: RigidBody3D, b: RigidBody3D) -> bool: return a.global_position.distance_to(point) < b.global_position.distance_to(point))
	return found


## Whether `body` is something a man picks up to throw.
static func throwable(body: RigidBody3D, guard: Node3D = null) -> bool:
	if body.freeze or body.is_queued_for_deletion() or body.get_script() != null:
		return false

	if body.mass < THROW_MASS_MIN or body.mass > THROW_MASS_MAX or body.gravity_scale < 0.5:
		return false

	for group in [&"bodies", &"dropped_weapons", &"dropped_lights", &"explosives", &"in_hand"]:
		if body.is_in_group(group):
			return false

	if body.linear_velocity.length() > 1.5:
		return false

	return not claimed(body, guard)


## Blades lying where they fell within `radius` of `point`, of the kinds in
## `kinds` (any, if empty), resting, not in your hands and not another man's.
## Nearest first.
static func weapons_near(tree: SceneTree, point: Vector3, radius: float, kinds: Array = [], guard: Node3D = null) -> Array[RigidBody3D]:
	var found: Array[RigidBody3D] = []

	for thing in tree.get_nodes_in_group(&"dropped_weapons"):
		var body := thing as RigidBody3D

		if body == null or body.is_queued_for_deletion() or body.is_in_group(&"in_hand") or claimed(body, guard):
			continue

		if not kinds.is_empty() and not (StringName(body.get_meta(&"weapon_kind", &"sword")) in kinds):
			continue

		if body.global_position.distance_to(point) <= radius and body.linear_velocity.length() < 1.5:
			found.append(body)

	found.sort_custom(func(a: RigidBody3D, b: RigidBody3D) -> bool: return a.global_position.distance_to(point) < b.global_position.distance_to(point))
	return found


## Returns whether a live guard other than by has reserved thing; stale claims are free.
static func claimed(thing: Object, by: Node3D) -> bool:
	if not thing.has_meta(&"claimed_by"):
		return false

	var w: Variant = thing.get_meta(&"claimed_by")
	var other: Object = (w as WeakRef).get_ref() if w is WeakRef else null
	return other != null and other != by and is_instance_valid(other) and other.get("_knocked_out") != true


## Stores a weak guard reservation in claimed_by metadata; null/freed things are ignored.
static func claim(thing: Object, by: Node3D) -> void:
	if thing != null and is_instance_valid(thing):
		thing.set_meta(&"claimed_by", weakref(by))


## Removes claimed_by only when owned by by; null/freed things are ignored.
static func unclaim(thing: Object, by: Node3D) -> void:
	if thing == null or not is_instance_valid(thing) or not thing.has_meta(&"claimed_by"):
		return

	var w: Variant = thing.get_meta(&"claimed_by")

	if w is WeakRef and (w as WeakRef).get_ref() == by:
		thing.remove_meta(&"claimed_by")


## A hanging weight still up whose load hangs over `feet`: its rope's middle
## is what to shoot. null if none.
static func weight_over(tree: SceneTree, feet: Vector3) -> Node3D:
	for weight in tree.get_nodes_in_group(&"hanging_weights"):
		if not (weight is Node3D) or weight.get("cut") == true:
			continue

		var load := weight.get("body") as Node3D

		if load == null or not is_instance_valid(load):
			continue

		var size: Vector3 = weight.get("load_size") if weight.get("load_size") is Vector3 else Vector3.ONE
		var over := Vector2(load.global_position.x - feet.x, load.global_position.z - feet.z).length()

		if over <= maxf(size.x, size.z) * 0.5 + 0.35 and load.global_position.y > feet.y + 0.5:
			return weight

	return null


## The nearest alarm bell within `radius` of `point` that can be rung now.
static func bell_near(tree: SceneTree, point: Vector3, radius: float) -> Node3D:
	var best: Node3D = null
	var nearest := radius

	for bell in tree.get_nodes_in_group(&"alarm_bells"):
		if not (bell is Node3D) or (bell.has_method("can_ring") and not bell.can_ring()):
			continue

		var d := (bell as Node3D).global_position.distance_to(point)

		if d < nearest:
			nearest = d
			best = bell

	return best
