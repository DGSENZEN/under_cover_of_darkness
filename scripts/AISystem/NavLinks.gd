extends RefCounted
## The ways across that a man walking the navmesh cannot take: made after
## every bake (NavBaker), as NavigationLink3D nodes, and crossed by a guard
## as his path comes to one (GuardClimb). Each link's "kind" meta says how:
##   climb   up onto a top he can reach (CLIMB_MIN to CLIMB_MAX above his
##           feet: a wall, a crate stack, a cart), and down off it again.
##   drop    down from higher than that (to DROP_MAX): he lowers himself off
##           the edge and lets go. One way.
##   leap    across a gap (LEAP_MIN to LEAP_MAX) to about the same height.
##   ladder  up or down a ClimbVolume (a ladder, a vine wall), from the floor
##           at its foot to the top it leads to; "rope" for a rope.
##   water   off a bank into deep water (WaterVolume, and the swim region
##           NavBaker bakes for it), and out again where the bank is low
##           enough to haul himself out (WATER_CLIMB). Deeper drops in, one way.
## They are found by walking the edges of the navmesh and looking out from
## each: up for a top, down for a floor, across for the far side of a gap.
## Each kind has its cost (COSTS): a guard goes round by the stairs if they
## are not far, and climbs if they are.

const WaterScript := preload("res://scripts/Interaction/WaterVolume.gd")

const CLIMB_MIN := 0.45
const CLIMB_MAX := 2.3
const DROP_MAX := 4.5
const LEAP_MIN := 1.0
const LEAP_MAX := 2.6
## A leap lands this much higher or lower at most.
const LEAP_RISE := 0.6
## A bank this far over the water (at most) he can haul himself out onto;
## he goes in off one this high at most.
const WATER_CLIMB := 1.1
const WATER_DROP := 6.0
## A look out from the navmesh's edge every STEP along it, this far out (m).
const STEP := 0.8
const OUT := [0.3, 0.55, 0.85, 1.15]
const ACROSS := [1.2, 1.6, 2.0, 2.4]
## Links of a kind with both ends this near another's are the same way.
const SPACING := 1.4
## The navmesh lies this far over the floor it was baked from.
const NAV_LIFT := 0.2
## What each kind costs to cross: [travel_cost (per metre), enter_cost (m)].
const COSTS := {
	&"climb": [3.0, 1.5],
	&"drop": [1.5, 1.0],
	&"leap": [2.0, 1.5],
	&"ladder": [2.5, 2.0],
	&"rope": [3.5, 3.0],
	&"water": [1.0, 8.0],
}


## Makes the links for what `region` has baked, under a "TraversalLinks"
## node of its own (the last ones gone). Returns how many.
static func build(region: NavigationRegion3D) -> int:
	var old := region.get_node_or_null("TraversalLinks")

	if old != null:
		region.remove_child(old)
		old.queue_free()

	var holder := Node3D.new()
	holder.name = "TraversalLinks"
	region.add_child(holder)
	var mesh := region.navigation_mesh

	if mesh == null:
		return 0

	var ctx := {
		"holder": holder,
		"space": region.get_world_3d().direct_space_state,
		"map": region.get_world_3d().navigation_map,
		"tree": region.get_tree(),
		"grid": {},
		"count": 0,
		"exclude": _moving_things(region.get_tree()),
	}

	for edge in _border_edges(mesh, region.global_transform):
		var a: Vector3 = edge[0]
		var b: Vector3 = edge[1]
		var out: Vector3 = edge[2]
		var steps := maxi(1, int(ceil(Vector2(b.x - a.x, b.z - a.z).length() / STEP)))

		for i in steps:
			_look_out(ctx, a.lerp(b, (float(i) + 0.5) / float(steps)), out)

	for volume in region.get_tree().get_nodes_in_group(&"climb_volumes"):
		_ladder(ctx, volume)

	return int(ctx["count"])


## The edges of the navmesh's outline (each used by one polygon only), in the
## world: [from, to, outward], outward the flat way off the mesh.
static func _border_edges(mesh: NavigationMesh, xform: Transform3D) -> Array:
	var vertices := mesh.get_vertices()
	var seen := {}

	for pi in mesh.get_polygon_count():
		var poly := mesh.get_polygon(pi)

		for k in poly.size():
			var a: int = poly[k]
			var b: int = poly[(k + 1) % poly.size()]
			var key := Vector2i(mini(a, b), maxi(a, b))

			if seen.has(key):
				seen[key][2] += 1
			else:
				seen[key] = [a, b, 1, pi]

	var edges := []

	for key in seen:
		var entry: Array = seen[key]

		if int(entry[2]) != 1:
			continue

		var a: Vector3 = xform * vertices[int(entry[0])]
		var b: Vector3 = xform * vertices[int(entry[1])]
		var along := Vector3(b.x - a.x, 0.0, b.z - a.z)

		if along.length() < 0.05:
			continue

		along = along.normalized()
		var out := Vector3(along.z, 0.0, -along.x)

		# Out is away from the middle of the polygon it bounds.
		var poly := mesh.get_polygon(int(entry[3]))
		var middle := Vector3.ZERO

		for index in poly:
			middle += xform * vertices[index]

		middle /= float(poly.size())

		if (middle - (a + b) * 0.5).dot(out) > 0.0:
			out = -out

		edges.append([a, b, out])

	return edges


## From `p` on the edge of the navmesh, looking `out` off it: up for a top
## he can climb onto, down for a floor to drop to, over water, and across a
## gap. The nearest of each.
static func _look_out(ctx: Dictionary, p: Vector3, out: Vector3) -> void:
	var floor_y := _floor_y(ctx, p)

	for d in OUT:
		var at: Vector3 = p + out * float(d)
		var water := _water_below(ctx, at, floor_y)

		if water != null:
			_water_link(ctx, p, out, float(d), floor_y, water)
			break

		# A top within reach, a wall face in front of him.
		var up := _ray(ctx, Vector3(at.x, floor_y + CLIMB_MAX + 0.15, at.z), Vector3(at.x, floor_y + CLIMB_MIN - 0.02, at.z))

		if not up.is_empty():
			if (up["normal"] as Vector3).y >= 0.7:
				_climb_link(ctx, p, out, floor_y, up["position"])

			break

		# Nothing that high: a floor lower down, or nothing at all.
		var down := _ray(ctx, Vector3(at.x, floor_y + 0.25, at.z), Vector3(at.x, floor_y - DROP_MAX - 0.1, at.z))

		if down.is_empty():
			continue

		var dy: float = (down["position"] as Vector3).y - floor_y

		if dy < -CLIMB_MAX and (down["normal"] as Vector3).y >= 0.7:
			_drop_link(ctx, p, out, down["position"])
			break

		# Within a climb of here: the climb up from there is this way too.
		if dy < -CLIMB_MIN:
			break

	_leap_link(ctx, p, out, floor_y)


## Up onto `top` from `p`: a top he stands on (on the navmesh), with nothing
## over him as he goes up, or over the edge as he goes over it.
static func _climb_link(ctx: Dictionary, p: Vector3, out: Vector3, floor_y: float, top: Vector3) -> void:
	var land := _on_mesh(ctx, top + out * 0.35, top.y)

	if land == Vector3.INF:
		return

	if not _ray(ctx, p + Vector3.UP * 0.3, Vector3(p.x, top.y + 1.2, p.z)).is_empty():
		return

	if not _ray(ctx, Vector3(p.x, top.y + 1.0, p.z), Vector3(land.x, top.y + 1.0, land.z)).is_empty():
		return

	_add(ctx, &"climb", p, land, true, top.y - floor_y)


## Down to `ground` from `p`, lowered off the edge: clear to step off.
static func _drop_link(ctx: Dictionary, p: Vector3, out: Vector3, ground: Vector3) -> void:
	var land := _on_mesh(ctx, ground + out * 0.3, ground.y)

	if land == Vector3.INF:
		return

	if not _ray(ctx, p + Vector3.UP * 1.0, Vector3(land.x, p.y + 1.0, land.z)).is_empty():
		return

	_add(ctx, &"drop", p, land, false, ground.y - (p.y - NAV_LIFT))


## Across a gap from `p`: the far side at about his height, nothing to walk
## on (within a metre down) between, and nothing in the way at head height.
static func _leap_link(ctx: Dictionary, p: Vector3, out: Vector3, floor_y: float) -> void:
	for d in ACROSS:
		var at: Vector3 = p + out * float(d)
		var hit := _ray(ctx, Vector3(at.x, floor_y + LEAP_RISE + 0.3, at.z), Vector3(at.x, floor_y - LEAP_RISE - 0.1, at.z))

		if hit.is_empty() or (hit["normal"] as Vector3).y < 0.7:
			continue

		var far: Vector3 = hit["position"]

		if absf(far.y - floor_y) > LEAP_RISE:
			continue

		# The gap itself: clear of the edges he leaves and lands on.
		var gap := 0.5

		while gap <= float(d) - 0.5:
			var mid: Vector3 = p + out * gap
			gap += 0.3

			if not _ray(ctx, Vector3(mid.x, floor_y + 0.3, mid.z), Vector3(mid.x, floor_y - 1.0, mid.z)).is_empty():
				return

		var land := _on_mesh(ctx, far + out * 0.3, far.y)

		if land == Vector3.INF or land.distance_to(p) < LEAP_MIN:
			return

		if not _ray(ctx, p + Vector3.UP * 1.0, land + Vector3.UP * 1.0).is_empty():
			return

		_add(ctx, &"leap", p, land, true, far.y - floor_y)
		return


## Off the bank at `p` into `water` (its swim region), and out again where
## the bank is low enough.
static func _water_link(ctx: Dictionary, p: Vector3, out: Vector3, d: float, floor_y: float, water: Node3D) -> void:
	var region: Variant = water.get_meta(&"swim_region") if water.has_meta(&"swim_region") else null

	if not (region is NavigationRegion3D) or not is_instance_valid(region):
		return

	var surface: float = water.surface_y()
	var rise := surface - floor_y

	if rise > 0.3 or rise < -WATER_DROP:
		return

	var at := p + out * (d + 0.35)
	var into := NavigationServer3D.region_get_closest_point((region as NavigationRegion3D).get_rid(), Vector3(at.x, surface + NAV_LIFT, at.z))

	if Vector2(into.x - at.x, into.z - at.z).length() > 1.0 or absf(into.y - (surface + NAV_LIFT)) > 0.4:
		return

	_add(ctx, &"water", p, into, rise >= -WATER_CLIMB, rise)


## A ladder or a rope: from the floor at its foot, in front of it, to the top
## it leads to, behind its top.
static func _ladder(ctx: Dictionary, volume: Node) -> void:
	if not (volume is Area3D) or not volume.has_method("get_climb_normal"):
		return

	var box := _box_of(volume as Area3D)

	if box.size == Vector3.ZERO:
		return

	var out: Vector3 = volume.get_climb_normal()
	var centre: Vector3 = (volume as Area3D).global_position
	var bottom := box.position.y
	var top := box.end.y
	var foot_at := Vector3(centre.x, bottom + 0.6, centre.z) + out * 0.55
	var foot := _ray(ctx, foot_at, foot_at + Vector3.DOWN * 2.0)

	if foot.is_empty():
		return

	var start := _on_mesh(ctx, (foot["position"] as Vector3) + out * 0.2, (foot["position"] as Vector3).y)
	var over_at := Vector3(centre.x, top + 0.7, centre.z) - out * 0.7
	var over := _ray(ctx, over_at, over_at + Vector3.DOWN * 1.8)

	if start == Vector3.INF or over.is_empty():
		return

	var land := _on_mesh(ctx, (over["position"] as Vector3) - out * 0.3, (over["position"] as Vector3).y)

	if land == Vector3.INF or land.y - start.y < CLIMB_MIN:
		return

	var rope := bool(volume.get("rope"))
	_add(ctx, &"rope" if rope else &"ladder", start, land, true, land.y - start.y, {"volume": volume})


## The world box of a climb volume's shape.
static func _box_of(volume: Area3D) -> AABB:
	for child in volume.get_children():
		if child is CollisionShape3D and (child as CollisionShape3D).shape is BoxShape3D:
			var size: Vector3 = ((child as CollisionShape3D).shape as BoxShape3D).size
			var xform := (child as CollisionShape3D).global_transform
			var box := AABB(xform * (-size * 0.5), Vector3.ZERO)

			for corner in [Vector3(1, 1, 1), Vector3(-1, 1, 1), Vector3(1, -1, 1), Vector3(1, 1, -1), Vector3(-1, -1, 1), Vector3(-1, 1, -1), Vector3(1, -1, -1)]:
				box = box.expand(xform * (size * 0.5 * corner))

			return box

	return AABB()


## Deep water right under `at` (a bank's edge looking out): its surface below
## the floor he stands on (or about level with it).
static func _water_below(ctx: Dictionary, at: Vector3, floor_y: float) -> Node3D:
	for water in (ctx["tree"] as SceneTree).get_nodes_in_group(&"water"):
		if water.has_method("over") and water.over(at) and water.has_meta(&"swim_region") and float(water.surface_y()) <= floor_y + 0.3:
			return water

	return null


## The navmesh point near `point` at height `ground` (a floor), or INF if the
## mesh is not there (a top too narrow to stand on, a crate).
static func _on_mesh(ctx: Dictionary, point: Vector3, ground: float) -> Vector3:
	var want := Vector3(point.x, ground + NAV_LIFT, point.z)
	var on := NavigationServer3D.map_get_closest_point(ctx["map"], want)

	if Vector2(on.x - want.x, on.z - want.z).length() > 0.9 or absf(on.y - want.y) > 0.35:
		return Vector3.INF

	return on


## The floor under a navmesh point.
static func _floor_y(ctx: Dictionary, p: Vector3) -> float:
	var hit := _ray(ctx, p + Vector3.UP * 0.4, p + Vector3.DOWN * 0.8)
	return (hit["position"] as Vector3).y if not hit.is_empty() else p.y - NAV_LIFT


static func _ray(ctx: Dictionary, from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1, ctx["exclude"])
	query.collide_with_areas = false
	return (ctx["space"] as PhysicsDirectSpaceState3D).intersect_ray(query)


## Everything that moves (crates, the living, the dead): not the level.
static func _moving_things(tree: SceneTree) -> Array[RID]:
	var rids: Array[RID] = []

	for node in tree.root.find_children("*", "PhysicsBody3D", true, false):
		if node is RigidBody3D or node is CharacterBody3D or node is AnimatableBody3D:
			rids.append((node as CollisionObject3D).get_rid())

	return rids


## A link of `kind` from `from` to `to` (both ways if `both`), unless one
## already goes much the same way.
static func _add(ctx: Dictionary, kind: StringName, from: Vector3, to: Vector3, both: bool, rise: float, extra := {}) -> void:
	var grid: Dictionary = ctx["grid"]
	var cell := Vector2i(floori(from.x / SPACING), floori(from.z / SPACING))

	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			for other in grid.get(cell + Vector2i(dx, dz), []):
				if other[0] != kind:
					continue

				var same: bool = (other[1] as Vector3).distance_to(from) < SPACING and (other[2] as Vector3).distance_to(to) < SPACING
				var back: bool = bool(other[3]) and (other[1] as Vector3).distance_to(to) < SPACING and (other[2] as Vector3).distance_to(from) < SPACING

				if same or back:
					return

	# The reverse way, from the other end's cell.
	if both:
		var far_cell := Vector2i(floori(to.x / SPACING), floori(to.z / SPACING))

		for dx in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				for other in grid.get(far_cell + Vector2i(dx, dz), []):
					if other[0] == kind and (other[1] as Vector3).distance_to(to) < SPACING and (other[2] as Vector3).distance_to(from) < SPACING:
						return

	var entry := [kind, from, to, both]
	grid[cell] = grid.get(cell, []) + [entry]

	var holder: Node3D = ctx["holder"]
	var link := NavigationLink3D.new()
	link.name = "%s_%d" % [kind, int(ctx["count"])]
	var local := holder.global_transform.affine_inverse()
	link.start_position = local * from
	link.end_position = local * to
	link.bidirectional = both
	var cost: Array = COSTS.get(kind, [2.0, 1.0])
	link.travel_cost = float(cost[0])
	link.enter_cost = float(cost[1])
	link.set_meta(&"kind", kind)
	link.set_meta(&"rise", rise)

	for key in extra:
		link.set_meta(StringName(key), extra[key])

	holder.add_child(link)
	ctx["count"] = int(ctx["count"]) + 1
