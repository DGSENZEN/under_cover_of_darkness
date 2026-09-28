class_name NavBaker
extends NavigationRegion3D
## Bakes the navigation mesh when the level loads, from the level's static
## collision. Add one of these to a map, point `source_root` at the node that
## holds the geometry (it defaults to this node's parent), and guards can
## path-find. TrenchBroom brushes arrive as static bodies, so they just work.
##
## Doors are left out of the bake on purpose: a closed door would cut the mesh
## at every doorway. Guards path through doorways and open the door. Each
## doorway (Door.footprint) is cut out of the mesh and baked as a region of
## its own, on the layers its door says (Door.nav_layers): locked, it is off
## the navmesh of a guard without the key, and he goes round.
##
## Furniture low enough to pass for a step (group "nav_blocks": a chair's
## seat, a stump; Furnishings) is kept off, with room round it, instead of
## being walked over.
##
## The baker sees the faces of what it bakes, not that a block is solid: a
## block taller than a man leaves a scrap of floor sealed inside it, which
## anything asking for the floor nearest a point could be sent to. Every
## polygon with something solid just over it (a static body, SEALED_PROBE m
## above its middle) is dropped.
##
## Deep water (WaterVolume) is cut out of the mesh, and baked as a swim region
## of its own, dearer to cross (SWIM_COST). Then the ways across that walking
## cannot take are found and linked (NavLinks: climbing, dropping, leaping,
## ladders, into and out of water) before `baked` is emitted.
##
## With drop_unreached, any island of floor nobody can get to or from the
## rest (a house's flat roof, a far bank), links and all, is left out: no man
## asked for the floor nearest a point is ever sent up there.

const NavLinksScript := preload("res://scripts/AISystem/NavLinks.gd")

## Swimming costs this many times walking the same distance (and getting in
## costs more: NavLinks.COSTS). A guard swims only where the way round is a
## good deal longer.
const SWIM_COST := 4.0
## How far over a polygon's middle it is tested for being inside something
## solid (m): under a man's knee, over any step.
const SEALED_PROBE := 0.45

signal baked

## Whose children are the level geometry. Empty means this node's parent.
@export var source_root: NodePath
@export var bake_on_ready := true

@export_group("Agent")
## Near the guard's capsule radius (0.3): a little over keeps his shoulders
## off the walls (a man standing nearer a wall than this starts his way from
## the nearest point on the mesh). A 1 m doorway needs a radius under 0.5 to
## stay open in the mesh.
@export var agent_radius := 0.3
@export var agent_height := 1.8
## Stairs: risers up to this height are walkable.
@export var agent_max_climb := 0.35
@export var agent_max_slope := 45.0
## Smaller cells follow geometry more closely and bake more slowly.
@export var cell_size := 0.1
## The smallest island of floor kept (m²): the tops of small things (a sack
## pile, a barrel) are left out, so nobody is routed over them. 0 keeps all.
@export var min_island := 0.0
## The box baked (this region's space; zero: all the geometry). Its corner
## pins the baker's grid, so what is built at the level's edges (a tree on
## a far bank) never shifts the cells, and with them the thin places (a
## stair's last step), everywhere else.
@export var bake_bounds := AABB()

@export_group("Source")
## CSG levels have no static bodies to parse: turn this on for them.
@export var parse_meshes := false
@export_flags_3d_physics var collision_mask := 1
## Off, guards only walk: no climbing, dropping or leaping (NavLinks).
@export var traversal_links := true
## Islands of floor with no way to or from the biggest one are left out.
@export var drop_unreached := false

var is_baked := false
## How many ways across were linked in the last bake; how many scraps of
## floor sealed inside blocks were dropped from it.
var link_count := 0
var sealed_count := 0
## How many polygons the last bake left out as out of anyone's reach.
var unreached_count := 0
var _source: NavigationMeshSourceGeometryData3D


func _ready() -> void:
	# The region is built at once, never in the background. Left to the
	# worker threads, a build started before the bake lands can wait behind
	# the renderer (the lightgem's cameras) for good, and every build after
	# it waits too: in a window the map stays empty and nobody can path,
	# step or dash. This has to be set before any build starts.
	NavigationServer3D.region_set_use_async_iterations(get_rid(), false)

	if bake_on_ready:
		# Let the rest of the level finish building first.
		bake.call_deferred()


func bake() -> void:
	is_baked = false

	var root: Node = get_parent() if source_root.is_empty() else get_node(source_root)

	var mesh := NavigationMesh.new()
	mesh.agent_radius = agent_radius
	mesh.agent_height = agent_height
	mesh.agent_max_slope = agent_max_slope
	mesh.cell_size = cell_size
	mesh.cell_height = cell_size
	# The baker works in whole cells. Round the climb UP to one, or a riser
	# exactly at the limit gets rounded out of the mesh.
	mesh.agent_max_climb = ceilf(agent_max_climb / cell_size - 0.001) * cell_size

	if min_island > 0.0:
		mesh.region_min_size = ceilf(sqrt(min_island) / cell_size)

	if bake_bounds.size != Vector3.ZERO:
		mesh.filter_baking_aabb = bake_bounds
	mesh.geometry_collision_mask = collision_mask
	mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN

	if parse_meshes:
		mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_BOTH
	else:
		mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS

	# The map's cell size has to match the mesh's, or edges fail to connect.
	var map := get_world_3d().navigation_map
	NavigationServer3D.map_set_cell_size(map, cell_size)
	NavigationServer3D.map_set_cell_height(map, cell_size)
	# Its updates made on the main thread, a frame after each change (links
	# and regions added after the bake are in it the frame after: _map_synced).
	NavigationServer3D.map_set_use_async_iterations(map, false)

	# Hide everything that must not shape the mesh, parse, then put it back.
	var hidden: Array = []

	for node in get_tree().get_nodes_in_group(&"nav_ignore"):
		if node is CollisionObject3D:
			hidden.append([node, node.collision_layer])
			node.collision_layer = 0

	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh, source, root)

	for entry in hidden:
		entry[0].collision_layer = entry[1]

	# The last bake's swim regions and links go; deep water is cut out of the
	# mesh (walked on it would be its bottom), and baked on its own after.
	for child in get_children():
		if child.name.begins_with("Swim") or child.name.begins_with("Doorway") or child.name == "TraversalLinks":
			remove_child(child)
			child.queue_free()

	for water in get_tree().get_nodes_in_group(&"water"):
		if water.has_meta(&"swim_region"):
			water.remove_meta(&"swim_region")

	for door in _doors():
		if door.has_meta(&"nav_region"):
			door.remove_meta(&"nav_region")

	_source = NavigationMeshSourceGeometryData3D.new()
	_source.append_arrays(source.get_vertices(), source.get_indices())

	for water in _deep_waters():
		var corners := _local_corners(water)
		source.add_projected_obstruction(corners, float(water.bottom_y()) - 1.0 - global_position.y, float(water.surface_y()) - float(water.bottom_y()) + 1.05, true)

	for door in _doors():
		source.add_projected_obstruction(_local_corners(door), float(door.doorway().y) - global_position.y - 0.5, 2.0, true)

	# Furniture low enough to pass for a step (a seat, a stump: Furnishings)
	# is kept off, with room for a man round it, rather than walked over.
	var local := global_transform.affine_inverse()

	for body in get_tree().get_nodes_in_group(&"nav_blocks"):
		if not root.is_ancestor_of(body):
			continue

		for block in body.get_meta(&"nav_blocks", []):
			var corners := PackedVector3Array()

			for corner in block["corners"]:
				corners.append(local * corner)

			source.add_projected_obstruction(corners, float(block["bottom"]) - global_position.y, float(block["height"]), false)

	NavigationServer3D.bake_from_source_geometry_data_async(mesh, source, _on_baked.bind(mesh))


func _on_baked(mesh: NavigationMesh) -> void:
	if not is_inside_tree():
		return

	sealed_count = _drop_sealed(mesh)
	navigation_mesh = mesh

	# The map picks the new mesh up on one of its next syncs: wait until a
	# corner of it can be found on the map (a few frames at most).
	var vertices := mesh.get_vertices()
	var corner: Vector3 = global_transform * vertices[0] if not vertices.is_empty() else Vector3.ZERO

	for i in 60:
		await get_tree().physics_frame

		# The level gone meanwhile (a reload, a test's next scene): no more.
		if not is_inside_tree():
			return

		if i >= 1 and (vertices.is_empty() or NavigationServer3D.map_get_closest_point(get_navigation_map(), corner).distance_to(corner) < 0.5):
			break

	# The doorways reach the map with the water (_bake_water waits for it).
	_bake_doorways(mesh)
	await _bake_water(mesh)

	if not is_inside_tree():
		return

	if traversal_links:
		link_count = NavLinksScript.build(self)

	# Links reach the map on one of its next syncs: nobody asks it for a path
	# before then.
	await _map_synced()

	if not is_inside_tree():
		return

	if drop_unreached:
		unreached_count = _drop_unreached(mesh)

		if unreached_count > 0:
			NavigationServer3D.region_set_navigation_mesh(get_rid(), mesh)
			await _map_synced()

			if not is_inside_tree():
				return

	is_baked = true
	baked.emit()


## Waits until the map has taken in what was added (a new iteration of it),
## a few frames at most.
func _map_synced() -> void:
	var map := get_world_3d().navigation_map
	var before := NavigationServer3D.map_get_iteration_id(map)

	for i in 30:
		await get_tree().physics_frame

		if not is_inside_tree():
			return

		if NavigationServer3D.map_get_iteration_id(map) != before and i >= 1:
			return


## Drops from `mesh` every polygon sealed inside something solid (see the
## header): a static body just over its middle, not one left out of the bake
## (a door: nav_ignore). How many were dropped.
func _drop_sealed(mesh: NavigationMesh) -> int:
	var space := get_world_3d().direct_space_state
	var vertices := mesh.get_vertices()
	var kept: Array[PackedInt32Array] = []
	var query := PhysicsPointQueryParameters3D.new()
	query.collision_mask = collision_mask
	query.collide_with_areas = false
	query.collide_with_bodies = true

	for i in mesh.get_polygon_count():
		var polygon := mesh.get_polygon(i)
		var middle := Vector3.ZERO

		for index in polygon:
			middle += vertices[index]

		middle /= float(maxi(polygon.size(), 1))
		query.position = global_transform * middle + Vector3.UP * SEALED_PROBE
		var sealed := false

		for hit in space.intersect_point(query, 8):
			var body: Object = hit.get("collider")

			if body is StaticBody3D and not (body as Node).is_in_group(&"nav_ignore"):
				sealed = true
				break

		if not sealed:
			kept.append(polygon)

	var dropped := mesh.get_polygon_count() - kept.size()

	if dropped > 0:
		mesh.clear_polygons()

		for polygon in kept:
			mesh.add_polygon(polygon)

	return dropped


## Drops from `mesh` every island of polygons (sharing corners) that has no
## way on the map, links and all, to or from the biggest island. How many
## polygons were dropped.
func _drop_unreached(mesh: NavigationMesh) -> int:
	var vertices := mesh.get_vertices()
	var count := mesh.get_polygon_count()
	var parent := PackedInt32Array()
	parent.resize(vertices.size())

	for i in vertices.size():
		parent[i] = i

	for i in count:
		var polygon := mesh.get_polygon(i)

		for k in range(1, polygon.size()):
			var a := _island_of(parent, polygon[0])
			var b := _island_of(parent, polygon[k])

			if a != b:
				parent[a] = b

	# Each island: its area, and the middle of its biggest polygon (where a
	# way to it is asked for).
	var area := {}
	var biggest := {}
	var middle := {}

	for i in count:
		var polygon := mesh.get_polygon(i)
		var island := _island_of(parent, polygon[0])
		var size := 0.0
		var centre := Vector3.ZERO

		for k in polygon.size():
			centre += vertices[polygon[k]]

			if k >= 2:
				size += (vertices[polygon[k - 1]] - vertices[polygon[0]]).cross(vertices[polygon[k]] - vertices[polygon[0]]).length() * 0.5

		area[island] = float(area.get(island, 0.0)) + size

		if size > float(biggest.get(island, -1.0)):
			biggest[island] = size
			middle[island] = global_transform * (centre / float(polygon.size()))

	if area.size() < 2:
		return 0

	var home: int = area.keys().reduce(func(best, island): return island if area[island] > area[best] else best)
	var map := get_navigation_map()
	var kept := {home: true}

	for island in area:
		if island != home and (_way_between(map, middle[home], middle[island]) or _way_between(map, middle[island], middle[home])):
			kept[island] = true

	var polygons: Array[PackedInt32Array] = []

	for i in count:
		if kept.has(_island_of(parent, mesh.get_polygon(i)[0])):
			polygons.append(mesh.get_polygon(i))

	var dropped := count - polygons.size()

	if dropped > 0:
		mesh.clear_polygons()

		for polygon in polygons:
			mesh.add_polygon(polygon)

	return dropped


static func _island_of(parent: PackedInt32Array, i: int) -> int:
	while parent[i] != i:
		parent[i] = parent[parent[i]]
		i = parent[i]

	return i


## The map has a way from `a` all the way to `b` (links and all, and through
## doorways on any layer: a room behind a locked door is reached by the man
## with its key).
static func _way_between(map: RID, a: Vector3, b: Vector3) -> bool:
	var way := NavigationServer3D.map_get_path(map, a, b, true, 0xFFFFFFFF)
	return not way.is_empty() and way[way.size() - 1].distance_to(b) < 0.5


## The water deep enough to swim in (WaterVolume.deep_at, anywhere in it).
func _deep_waters() -> Array:
	var deep := []

	for water in get_tree().get_nodes_in_group(&"water"):
		if not water.has_method("deep_at"):
			continue

		var middle: Vector3 = water.global_position
		var size: Vector3 = water.size

		for offset in [Vector3.ZERO, Vector3(size.x * 0.3, 0, size.z * 0.3), Vector3(-size.x * 0.3, 0, -size.z * 0.3), Vector3(size.x * 0.3, 0, -size.z * 0.3), Vector3(-size.x * 0.3, 0, size.z * 0.3)]:
			if water.deep_at(middle + offset):
				deep.append(water)
				break

	return deep


## The doors whose doorways are regions of their own.
func _doors() -> Array:
	return get_tree().get_nodes_in_group(&"doors").filter(func(door): return door.has_method("footprint"))


## `thing`'s outline seen from above (water, a doorway), in this region's space.
func _local_corners(thing: Node3D) -> PackedVector3Array:
	var corners := PackedVector3Array()
	var local := global_transform.affine_inverse()

	for corner in thing.footprint():
		corners.append(local * corner)

	return corners


## Each body of deep water: its surface, as a region of its own (a swim
## costs SWIM_COST), cut where walls stand in it, and nowhere else.
func _bake_water(land: NavigationMesh) -> void:
	for water in _deep_waters():
		var mesh := NavigationMesh.new()

		for property in ["agent_radius", "agent_height", "agent_max_slope", "agent_max_climb", "cell_size", "cell_height", "geometry_collision_mask"]:
			mesh.set(property, land.get(property))

		var source := NavigationMeshSourceGeometryData3D.new()
		source.append_arrays(_source.get_vertices(), _source.get_indices())
		var local := global_transform.affine_inverse()
		var surface: float = float(water.surface_y()) - global_position.y
		var c := _local_corners(water)

		# The surface, as though it were a floor (both faces, whichever way
		# up the baker reads them).
		for corner in range(4):
			c[corner].y = surface

		source.add_faces(PackedVector3Array([c[0], c[1], c[2], c[0], c[2], c[3], c[0], c[2], c[1], c[0], c[3], c[2]]), Transform3D.IDENTITY)

		# Everything outside it, cut away.
		var far := 5000.0
		var lo: Vector3 = c[0]
		var hi: Vector3 = c[2]
		var low := minf(lo.x, hi.x)
		var high := maxf(lo.x, hi.x)
		var near := minf(lo.z, hi.z)
		var back := maxf(lo.z, hi.z)

		for band in [[-far, low, -far, far], [high, far, -far, far], [low, high, -far, near], [low, high, back, far]]:
			source.add_projected_obstruction(PackedVector3Array([Vector3(band[0], 0, band[2]), Vector3(band[1], 0, band[2]), Vector3(band[1], 0, band[3]), Vector3(band[0], 0, band[3])]), -far, far * 2.0, true)

		NavigationServer3D.bake_from_source_geometry_data(mesh, source)
		var region := NavigationRegion3D.new()
		region.name = "Swim_%s" % water.name
		region.navigation_mesh = _surface_only(mesh, surface)
		region.travel_cost = SWIM_COST
		NavigationServer3D.region_set_use_async_iterations(region.get_rid(), false)
		add_child(region)
		water.set_meta(&"swim_region", region)

	# Let the map take the regions before anything asks it about them.
	await _map_synced()


## Each doorway: its strip of floor, as a region of its own, cut where the
## frame stands, and nowhere else; on its door's layers (Door.nav_layers).
func _bake_doorways(land: NavigationMesh) -> void:
	for door in _doors():
		var mesh := NavigationMesh.new()

		for property in ["agent_radius", "agent_height", "agent_max_slope", "agent_max_climb", "cell_size", "cell_height", "geometry_collision_mask"]:
			mesh.set(property, land.get(property))

		var source := NavigationMeshSourceGeometryData3D.new()
		source.append_arrays(_source.get_vertices(), _source.get_indices())
		var floor_y: float = float(door.doorway().y) - global_position.y
		var c := _local_corners(door)
		var middle: Vector3 = (c[0] + c[2]) * 0.5
		var bounds := AABB(Vector3(middle.x, floor_y, middle.z), Vector3(0.0, land.agent_height, 0.0))

		# Everything outside it, cut away: past each side, far along it.
		for k in 4:
			var a: Vector3 = c[k]
			var b: Vector3 = c[(k + 1) % 4]
			var along := (b - a).normalized() * 50.0
			var out := Vector3(along.z, 0.0, -along.x)

			if out.dot((a + b) * 0.5 - middle) < 0.0:
				out = -out

			source.add_projected_obstruction(PackedVector3Array([a - along, b + along, b + along + out, a - along + out]), floor_y - 50.0, 100.0, true)
			bounds = bounds.expand(a)

		# Baked only round it, with room for the frame's erosion.
		mesh.filter_baking_aabb = bounds.grow(1.5)
		NavigationServer3D.bake_from_source_geometry_data(mesh, source)
		_drop_sealed(mesh)
		var region := NavigationRegion3D.new()
		region.name = "Doorway_%s" % door.name
		region.navigation_mesh = _surface_only(mesh, floor_y)
		region.navigation_layers = door.nav_layers()
		NavigationServer3D.region_set_use_async_iterations(region.get_rid(), false)
		add_child(region)
		door.set_meta(&"nav_region", region)


## Only the polygons of `mesh` lying at `height` (the water's surface): not
## the bottom of deep water, or anything else that stands in it.
static func _surface_only(mesh: NavigationMesh, height: float) -> NavigationMesh:
	var out := NavigationMesh.new()

	for property in ["agent_radius", "agent_height", "agent_max_slope", "agent_max_climb", "cell_size", "cell_height"]:
		out.set(property, mesh.get(property))

	var vertices := mesh.get_vertices()
	var kept := PackedVector3Array()
	var remap := {}
	var polygons := []

	for i in mesh.get_polygon_count():
		var poly := mesh.get_polygon(i)
		var y := 0.0

		for index in poly:
			y += vertices[index].y

		y /= float(maxi(poly.size(), 1))

		if absf(y - height) > 0.5:
			continue

		var renumbered := PackedInt32Array()

		for index in poly:
			if not remap.has(index):
				remap[index] = kept.size()
				kept.append(vertices[index])

			renumbered.append(int(remap[index]))

		polygons.append(renumbered)

	out.set_vertices(kept)

	for poly in polygons:
		out.add_polygon(poly)

	return out
