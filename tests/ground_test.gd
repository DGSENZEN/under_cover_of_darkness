extends Node3D
## Ground.gd (the vertex-paint plan, Task 9): a painted, hex-tiled,
## vertex-weathered ground with its openings and colliders, headless:
##   Godot --headless --path . res://tests/ground_test.tscn

const AREA := Rect2(-10, -8, 20, 16)
const OPENING := Rect2(-1.5, -6.0, 3.0, 6.0)
const ROOFED := Rect2(4.0, -7.0, 4.0, 3.0)
const OPEN_BLOCK := Rect2(-8.0, 2.0, 4.0, 3.0)
## Off the metre grid, as the lab's bays and copings are.
const OFF_GRID := Rect2(3.35, 2.35, 3.3, 2.2)

var results: Array[String] = []


func _ready() -> void:
	var footprints: Array[Dictionary] = [{"rect": ROOFED, "roofed": true}, {"rect": OPEN_BLOCK, "roofed": false},
		{"rect": OFF_GRID, "roofed": false}]
	var ground := Ground.build(AREA, [OPENING], footprints, 7)
	add_child(ground)
	var mesh: ArrayMesh = (ground.get_node("mesh") as MeshInstance3D).mesh
	var arrays := mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]

	# G1 the opening holds no ground
	var inside := 0
	var longest := 0.0

	for t in range(0, indices.size(), 3):
		var a := points[indices[t]]
		var b := points[indices[t + 1]]
		var c := points[indices[t + 2]]
		var centre := (a + b + c) / 3.0
		inside += int(OPENING.has_point(Vector2(centre.x, centre.z)))

		for e in [[a, b], [b, c], [c, a]]:
			var d: Vector3 = e[1] - e[0]
			# A cell's diagonal is no edge of the grid: count its sides only.
			if absf(d.x) < 1e-4 or absf(d.z) < 1e-4:
				longest = maxf(longest, d.length())

	_check("G1 the opening holds no ground", inside == 0 and indices.size() > 0, "%d triangles inside" % inside)

	# G7 the ground faces up: Godot draws a triangle's front where its corners
	#    run clockwise, so (b - a) x (c - a) points down for one seen from above
	var facing_down := 0

	for t in range(0, indices.size(), 3):
		var a := points[indices[t]]
		facing_down += int((points[indices[t + 1]] - a).cross(points[indices[t + 2]] - a).y > 0.0)

	_check("G7 every ground triangle faces up (drawn from above, culled from below)", facing_down == 0,
		"%d of %d facing down" % [facing_down, indices.size() / 3])
	# G2 every vertex coloured, the grid no coarser than a metre
	_check("G2 every vertex has a colour and the grid is a metre or finer", colours.size() == points.size() and longest <= 1.0 + 1e-4,
		"%d colours for %d vertices, longest side %.3f m" % [colours.size(), points.size(), longest])

	# G3 grime gathers against what stands on the ground
	var near := []
	var far := []

	for i in points.size():
		var at := Vector2(points[i].x, points[i].z)
		var d := _outside_distance(at, OPEN_BLOCK)

		# Against it: on its edge (where wall meets street) or just outside.
		if d < 0.5 and not OPEN_BLOCK.grow(-0.01).has_point(at):
			near.append(colours[i].r)
		elif d > 5.0 and _outside_distance(Vector2(points[i].x, points[i].z), ROOFED) > 5.0 \
				and _outside_distance(Vector2(points[i].x, points[i].z), OPENING) > 2.0:
			far.append(colours[i].r)

	_check("G3 grime is higher against a footprint than out in the open", near.size() > 0 and far.size() > 0
		and _mean(near) > _mean(far) + 0.2, "near %.2f far %.2f" % [_mean(near), _mean(far)])

	# G8 a footprint off the metre grid still has ground along its edges,
	#    grimed where its wall meets the street
	var on_edges := [0, 0, 0, 0]
	var edge_grime := []

	for i in points.size():
		var at := Vector2(points[i].x, points[i].z)
		var along_x := at.x >= OFF_GRID.position.x - 1e-3 and at.x <= OFF_GRID.end.x + 1e-3
		var along_z := at.y >= OFF_GRID.position.y - 1e-3 and at.y <= OFF_GRID.end.y + 1e-3
		var sides := [along_z and absf(at.x - OFF_GRID.position.x) < 1e-3, along_z and absf(at.x - OFF_GRID.end.x) < 1e-3,
			along_x and absf(at.y - OFF_GRID.position.y) < 1e-3, along_x and absf(at.y - OFF_GRID.end.y) < 1e-3]

		for k in 4:
			if sides[k]:
				on_edges[k] += 1
				edge_grime.append(colours[i].r)

	_check("G8 a footprint off the grid has ground along all four edges, grimed", on_edges.all(func(n): return n >= 2)
		and _mean(edge_grime) > 0.5, "vertices per edge %s, mean grime %.2f" % [on_edges, _mean(edge_grime)])

	# G9 the ground wears through round an opening's rim
	var rim := []

	for i in points.size():
		var at := Vector2(points[i].x, points[i].z)

		if _outside_distance(at, OPENING) < 1e-3 and not OPENING.grow(-0.01).has_point(at):
			rim.append(colours[i].g)

	_check("G9 the ground wears through round an opening's rim", rim.size() > 0 and _mean(rim) > 0.45,
		"%d rim vertices, mean wear %.2f" % [rim.size(), _mean(rim)])

	# G4 under a roofed footprint the ground is in shadow
	var under := []

	for i in points.size():
		if ROOFED.grow(-0.2).has_point(Vector2(points[i].x, points[i].z)):
			under.append(colours[i].a)

	_check("G4 a roofed footprint's baked light is low", under.size() > 0 and _mean(under) < 0.7, "mean A %.2f" % _mean(under))

	# G5 the colliders: a ray down falls through the opening and meets the
	#    ground at y 0 everywhere else
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space := get_world_3d().direct_space_state
	var through := _ray(space, OPENING.get_center()).is_empty()
	var solid := true

	for spot in [Vector2(-9.5, -7.5), Vector2(0, 5), Vector2(9.5, 7.5), Vector2(-1.6, -3.0), Vector2(1.6, -0.1)]:
		var hit := _ray(space, spot)
		solid = solid and not hit.is_empty() and absf(hit["position"].y) < 1e-3

	_check("G5 a ray falls through the opening and meets the ground at y 0 elsewhere", through and solid,
		"through %s, solid %s" % [through, solid])

	# G6 one seed, one ground
	var again := Ground.build(AREA, [OPENING], footprints, 7)
	var again_colours: PackedColorArray = ((again.get_node("mesh") as MeshInstance3D).mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	_check("G6 deterministic for one seed", again_colours == colours, "%d colours" % again_colours.size())
	again.free()

	await _district_checks(space)

	print("\n==== RESULTS ====")
	for r in results:
		print(r)

	get_tree().quit()


## The options a district's ground takes (the street and canal kit's plan, Task 3).
func _district_checks(space: PhysicsDirectSpaceState3D) -> void:
	var area := Rect2(0, 0, 30, 30)

	# G10 a level and a tile: every vertex at the level, the collider's top
	#     there, the tile's texture drawn
	var raised := Ground.build(area, [], [], 3, {"level": 0.2, "tile": &"ground_setts"})
	raised.position = Vector3(100, 0, 0)
	add_child(raised)
	var raised_points: PackedVector3Array = _arrays(raised)[Mesh.ARRAY_VERTEX]
	var level_ok := raised_points.size() > 0 and Array(raised_points).all(func(p): return absf(p.y - 0.2) < 1e-5)
	var material: ShaderMaterial = (raised.get_node("mesh") as MeshInstance3D).material_override
	var albedo: Texture2D = material.get_shader_parameter("atlas")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var top := _ray(space, Vector2(115, 15))
	_check("G10 a ground at a level, in its tile", level_ok and not top.is_empty() and absf(top["position"].y - 0.2) < 1e-3
		and albedo != null and albedo.resource_path.ends_with("ground_setts.png"),
		"level %s, hit %s, texture %s" % [level_ok, top.get("position"), albedo.resource_path if albedo else "none"])
	raised.queue_free()

	# G11 a curved inlay (a quarter ring) is cut from the mesh exactly
	var ring := _quarter_ring(Vector2(5, 5), 10.8, 13.2, 16)
	var cut := Ground.build(area, [], [], 3, {"inlays": [ring]})
	add_child(cut)
	var arrays := _arrays(cut)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var inside := 0
	var inside_area := 0.0
	var smallest := INF
	var total := 0.0
	var down := 0

	for t in range(0, indices.size(), 3):
		var a := points[indices[t]]
		var b := points[indices[t + 1]]
		var c := points[indices[t + 2]]
		var centre := (a + b + c) / 3.0
		var n := (b - a).cross(c - a)
		smallest = minf(smallest, n.length() / 2.0)

		if Geometry2D.is_point_in_polygon(Vector2(centre.x, centre.z), ring):
			inside += 1
			inside_area += n.length() / 2.0

		total += n.length() / 2.0
		down += int(n.y > 0.0)

	var expected := 900.0 - _polygon_area(ring)
	# (Slivers along the arc's chords can put a centroid a hair inside: what
	# counts is the area lying over the inlay.)
	_check("G11 a curved inlay is cut from the ground, nothing over it, nothing else lost", inside_area < 1e-4 and down == 0
		and absf(total - expected) < 0.01, "%d inside (%.6f m2), %d facing down, area %.4f of %.4f, smallest %s m2" % [inside, inside_area, down, total, expected, str(smallest)])

	# G12 under the inlay the ground still holds the player up
	await get_tree().physics_frame
	var mid := Vector2(5, 5) + Vector2(12, 0).rotated(PI / 4)
	var held := _ray(space, mid)
	_check("G12 the collider holds under an inlay", not held.is_empty() and absf(held["position"].y) < 1e-3,
		"hit %s at %s" % [held.get("position"), mid])
	cut.queue_free()

	# G13 a covered square holds no ground and wears no rim round it
	var covered := PackedVector2Array([Vector2(10, 10), Vector2(20, 10), Vector2(20, 20), Vector2(10, 20)])
	var under := Ground.build(area, [], [], 3, {"covered": [covered]})
	under.position = Vector3(0, 0, 100)
	add_child(under)
	var under_arrays := _arrays(under)
	var under_points: PackedVector3Array = under_arrays[Mesh.ARRAY_VERTEX]
	var under_colours: PackedColorArray = under_arrays[Mesh.ARRAY_COLOR]
	var under_indices: PackedInt32Array = under_arrays[Mesh.ARRAY_INDEX]
	var in_square := 0
	var rim_wear := []

	for t in range(0, under_indices.size(), 3):
		var centre := (under_points[under_indices[t]] + under_points[under_indices[t + 1]] + under_points[under_indices[t + 2]]) / 3.0
		in_square += int(Rect2(10, 10, 10, 10).has_point(Vector2(centre.x, centre.z)))

	for i in under_points.size():
		if absf(_outside_distance(Vector2(under_points[i].x, under_points[i].z), Rect2(10, 10, 10, 10)) - 0.3) < 0.35 \
				and not Rect2(10, 10, 10, 10).has_point(Vector2(under_points[i].x, under_points[i].z)):
			rim_wear.append(under_colours[i].g)

	_check("G13 a covered square holds no ground and wears no rim", in_square == 0 and rim_wear.size() > 0
		and rim_wear.max() < 0.01, "%d triangles in it, rim wear max %.2f" % [in_square, rim_wear.max() if rim_wear else -1.0])
	under.queue_free()

	# G14 relaid patches: another stone (B 0.65), not worn through
	var patched := Ground.build(area, [], [], 3, {"patches": [Rect2(4, 4, 6, 6)]})
	var patch_arrays := _arrays(patched)
	var patch_points: PackedVector3Array = patch_arrays[Mesh.ARRAY_VERTEX]
	var patch_colours: PackedColorArray = patch_arrays[Mesh.ARRAY_COLOR]
	var in_patch := []

	for i in patch_points.size():
		if Rect2(4, 4, 6, 6).grow(-0.01).has_point(Vector2(patch_points[i].x, patch_points[i].z)):
			in_patch.append(patch_colours[i])

	var relaid := in_patch.all(func(c): return absf(c.b - 0.65) < 0.01 and c.g < 0.01)
	_check("G14 relaid patches are another stone", in_patch.size() > 0 and relaid, "%d vertices in the patch" % in_patch.size())
	patched.free()

	# G15 a district's ground in 50 m chunks: 3 x 2 over 120 x 60, none
	#     wider than a chunk, solid every 7 m but over its opening
	var district := DistrictGround.build({"chunk": 50, "areas": [{"tile": "ground_setts", "level": 0.0,
		"rect": [-300, -300, -180, -240], "openings": [[-250, -280, -240, -270]], "covered": [], "inlays": [],
		"patches": [], "footprints": []}]}, 5)
	add_child(district)
	var chunks := district.find_children("*", "MeshInstance3D", true, false)
	var widest := 0.0

	for m: MeshInstance3D in chunks:
		var box := m.get_aabb()
		widest = maxf(widest, maxf(box.size.x, box.size.z))

	await get_tree().physics_frame
	await get_tree().physics_frame
	var holes := []

	for x in range(-298, -180, 7):
		for z in range(-298, -240, 7):
			var opening := Rect2(-250, -280, 10, 10).has_point(Vector2(x, z))

			if _ray(space, Vector2(x, z)).is_empty() != opening:
				holes.append(Vector2(x, z))

	_check("G15 a district's ground lies in 50 m chunks, solid but for its openings", chunks.size() == 6
		and widest <= 50.0 + 1e-4 and holes.is_empty(), "%d chunks, widest %.1f, wrong at %s" % [chunks.size(), widest, holes])
	district.queue_free()


func _arrays(ground: Node) -> Array:
	return ((ground.get_node("mesh") as MeshInstance3D).mesh as ArrayMesh).surface_get_arrays(0)


func _quarter_ring(centre: Vector2, inner: float, outer: float, segments: int) -> PackedVector2Array:
	var out := PackedVector2Array()

	for i in segments + 1:
		out.append(centre + Vector2(outer, 0).rotated(PI / 2 * i / segments))

	for i in range(segments, -1, -1):
		out.append(centre + Vector2(inner, 0).rotated(PI / 2 * i / segments))

	return out


func _polygon_area(p: PackedVector2Array) -> float:
	var sum := 0.0

	for i in p.size():
		sum += p[i].x * p[(i + 1) % p.size()].y - p[(i + 1) % p.size()].x * p[i].y

	return absf(sum) / 2.0


func _ray(space: PhysicsDirectSpaceState3D, at: Vector2) -> Dictionary:
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(at.x, 5.0, at.y), Vector3(at.x, -5.0, at.y)))


## How far a point lies outside a rectangle (0 inside).
func _outside_distance(p: Vector2, r: Rect2) -> float:
	var dx := maxf(maxf(r.position.x - p.x, 0.0), p.x - r.end.x)
	var dy := maxf(maxf(r.position.y - p.y, 0.0), p.y - r.end.y)
	return Vector2(dx, dy).length()


func _mean(values: Array) -> float:
	var sum := 0.0

	for v in values:
		sum += v

	return sum / maxf(values.size(), 1)


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
