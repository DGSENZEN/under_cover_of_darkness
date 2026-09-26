class_name NavBaker
extends NavigationRegion3D
## Bakes the navigation mesh when the level loads, from the level's static
## collision. Add one of these to a map, point `source_root` at the node that
## holds the geometry (it defaults to this node's parent), and guards can
## path-find. TrenchBroom brushes arrive as static bodies, so they just work.
##
## Doors are left out of the bake on purpose: a closed door would cut the mesh
## at every doorway. Guards path through doorways and open the door.

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

var is_baked := false


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

	is_baked = true
	baked.emit()
