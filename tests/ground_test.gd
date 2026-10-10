extends Node3D
## Ground.gd (the vertex-paint plan, Task 9): a painted, hex-tiled,
## vertex-weathered ground with its openings and colliders, headless:
##   Godot --headless --path . res://tests/ground_test.tscn

const AREA := Rect2(-10, -8, 20, 16)
const OPENING := Rect2(-1.5, -6.0, 3.0, 6.0)
const ROOFED := Rect2(4.0, -7.0, 4.0, 3.0)
const OPEN_BLOCK := Rect2(-8.0, 2.0, 4.0, 3.0)

var results: Array[String] = []


func _ready() -> void:
	var footprints: Array[Dictionary] = [{"rect": ROOFED, "roofed": true}, {"rect": OPEN_BLOCK, "roofed": false}]
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

	print("\n==== RESULTS ====")
	for r in results:
		print(r)

	get_tree().quit()


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
