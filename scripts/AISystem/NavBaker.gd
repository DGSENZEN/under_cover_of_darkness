class_name NavBaker
extends NavigationRegion3D
## Bakes the navigation mesh when the level loads, from the level's static
## collision. Add one of these to a map, point `source_root` at the node that
## holds the geometry (it defaults to this node's parent), and guards can
## path-find. TrenchBroom brushes arrive as static bodies, so they just work.
##
## Doors are left out of the bake on purpose: a closed door would cut the mesh
## at every doorway. Guards path through doorways and open the door.
##
## Deep water (WaterVolume) is cut out of the mesh, and baked as a swim region
## of its own, dearer to cross (SWIM_COST). Then the ways across that walking
## cannot take are found and linked (NavLinks: climbing, dropping, leaping,
## ladders, into and out of water) before `baked` is emitted.

const NavLinksScript := preload("res://scripts/AISystem/NavLinks.gd")

## Swimming costs this many times walking the same distance (and getting in
## costs more: NavLinks.COSTS). A guard swims only where the way round is a
## good deal longer.
const SWIM_COST := 4.0

signal baked

## Whose children are the level geometry. Empty means this node's parent.
@export var source_root: NodePath
@export var bake_on_ready := true

@export_group("Agent")
## Keep this at or under the guard's capsule radius. A 1 m doorway needs a
## radius under 0.5 to stay open in the mesh.
@export var agent_radius := 0.3
@export var agent_height := 1.8
## Stairs: risers up to this height are walkable.
@export var agent_max_climb := 0.35
@export var agent_max_slope := 45.0
## Smaller cells follow geometry more closely and bake more slowly.
@export var cell_size := 0.1

@export_group("Source")
## CSG levels have no static bodies to parse: turn this on for them.
@export var parse_meshes := false
@export_flags_3d_physics var collision_mask := 1
## Off, guards only walk: no climbing, dropping or leaping (NavLinks).
@export var traversal_links := true

var is_baked := false
## How many ways across were linked in the last bake.
var link_count := 0
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
		if child.name.begins_with("Swim") or child.name == "TraversalLinks":
			remove_child(child)
			child.queue_free()

	for water in get_tree().get_nodes_in_group(&"water"):
		if water.has_meta(&"swim_region"):
			water.remove_meta(&"swim_region")

	_source = NavigationMeshSourceGeometryData3D.new()
	_source.append_arrays(source.get_vertices(), source.get_indices())

	for water in _deep_waters():
		var corners := _local_corners(water)
		source.add_projected_obstruction(corners, float(water.bottom_y()) - 1.0 - global_position.y, float(water.surface_y()) - float(water.bottom_y()) + 1.05, true)

	NavigationServer3D.bake_from_source_geometry_data_async(mesh, source, _on_baked.bind(mesh))


func _on_baked(mesh: NavigationMesh) -> void:
	navigation_mesh = mesh

	# The map picks the new mesh up on one of its next syncs: wait until a
	# corner of it can be found on the map (a few frames at most).
	var vertices := mesh.get_vertices()
	var corner: Vector3 = global_transform * vertices[0] if not vertices.is_empty() else Vector3.ZERO

	for i in 60:
		await get_tree().physics_frame

		if i >= 1 and (vertices.is_empty() or NavigationServer3D.map_get_closest_point(get_navigation_map(), corner).distance_to(corner) < 0.5):
			break

	await _bake_water(mesh)

	if traversal_links:
		link_count = NavLinksScript.build(self)

	# Links reach the map on one of its next syncs: nobody asks it for a path
	# before then.
	await _map_synced()
	is_baked = true
	baked.emit()


## Waits until the map has taken in what was added (a new iteration of it),
## a few frames at most.
func _map_synced() -> void:
	var map := get_world_3d().navigation_map
	var before := NavigationServer3D.map_get_iteration_id(map)

	for i in 30:
		await get_tree().physics_frame

		if NavigationServer3D.map_get_iteration_id(map) != before and i >= 1:
			return


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


## `water`'s outline seen from above, in this region's space.
func _local_corners(water: Node3D) -> PackedVector3Array:
	var corners := PackedVector3Array()
	var local := global_transform.affine_inverse()

	for corner in water.footprint():
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
