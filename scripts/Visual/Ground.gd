class_name Ground
extends StaticBody3D
## A district's ground (the vertex-paint spec, section 6.3): a 1 m grid with
## openings cut out (stair mouths), the painted cobble tile hex-tiled across
## it in the district's palette, packed earth under the cobbles, and vertex
## paint from the same stories the kit pieces tell, measured in plan:
##   R grime banked against what stands on it and gathered in its corners
##   G the cobbles worn through to earth along walking lines and round openings
##   B damp in patches (below 0.5)
##   A baked light: low under roofed footprints, a little low along walls
## Colliders: a box per run of cells, its top at y 0.

const Painterly := preload("res://scripts/Visual/Painterly.gd")
const COBBLES: Texture2D = preload("res://textures/painted/eclipse/ground_cobbles.png")
const COBBLES_NORMAL: Texture2D = preload("res://textures/painted/eclipse/ground_cobbles_normal.png")
const EARTH: Texture2D = preload("res://textures/painted/eclipse/ground_earth.png")
const EARTH_NORMAL: Texture2D = preload("res://textures/painted/eclipse/ground_earth_normal.png")

## Metres a cobble tile covers (eclipse_atlas.GROUND_PERIOD).
const TILE_M := 1.5
## The grid (m).
const CELL := 1.0
## How far grime banks out from a footprint (m), and corners gather more within.
const BANK := 0.8
const CORNER := 1.0
## Walking lines wear this wide (m) to either side, openings this far round.
const PATH := 0.7
const RIM := 0.6
## Baked light under a roof and along a wall (within WALL m).
const ROOFED_LIGHT := 0.55
const WALL_LIGHT := 0.85
const WALL := 0.5
## The collider's depth (m).
const DEPTH := 0.5


## The ground over `area` (x, z), open at `openings`, weathered against
## `footprints` ([{"rect": Rect2, "roofed": bool, "door": Vector2 (optional)}]).
static func build(area: Rect2, openings: Array[Rect2], footprints: Array[Dictionary], seed: int) -> Ground:
	var ground := Ground.new()
	ground.name = "ground"
	# Lines at every opening's edges, and at every footprint's edges and BANK
	# out from them, so the stories have vertices where they start and end.
	var x_edges := openings.map(func(o): return [o.position.x, o.end.x])
	var z_edges := openings.map(func(o): return [o.position.y, o.end.y])

	for f in footprints:
		var r: Rect2 = f["rect"]
		x_edges.append([r.position.x - BANK, r.position.x, r.end.x, r.end.x + BANK])
		z_edges.append([r.position.y - BANK, r.position.y, r.end.y, r.end.y + BANK])

	var xs := _lines(area.position.x, area.end.x, x_edges)
	var zs := _lines(area.position.y, area.end.y, z_edges)
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.frequency = 0.35
	var damp := FastNoiseLite.new()
	damp.seed = seed + 1
	damp.frequency = 0.12
	var paths := _paths(footprints, openings)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var index := {}

	for j in zs.size() - 1:
		var run_from := -1

		for i in xs.size():
			var open := i == xs.size() - 1
			var cell := Rect2()

			if not open:
				cell = Rect2(xs[i], zs[j], xs[i + 1] - xs[i], zs[j + 1] - zs[j])
				open = openings.any(func(o: Rect2): return o.encloses(cell))

			if not open:
				var corners := [Vector2(cell.position.x, cell.position.y), Vector2(cell.end.x, cell.position.y),
					Vector2(cell.end.x, cell.end.y), Vector2(cell.position.x, cell.end.y)]
				var ids := []

				for c: Vector2 in corners:
					if not index.has(c):
						index[c] = index.size()
						tool.set_normal(Vector3.UP)
						tool.set_tangent(Plane(1, 0, 0, 1))
						tool.set_uv(c / TILE_M)
						tool.set_color(_paint(c, footprints, openings, paths, noise, damp))
						tool.add_vertex(Vector3(c.x, 0, c.y))

					ids.append(index[c])

				# Clockwise from above: Godot's front, so it faces up.
				for k in [0, 1, 2, 0, 2, 3]:
					tool.add_index(ids[k])

				if run_from < 0:
					run_from = i
			elif run_from >= 0:
				ground._collider(Rect2(xs[run_from], zs[j], xs[i] - xs[run_from], zs[j + 1] - zs[j]))
				run_from = -1

	var mesh := MeshInstance3D.new()
	mesh.name = "mesh"
	mesh.mesh = tool.commit()
	var material := Painterly.material(COBBLES, &"shader_led", Painterly.ZOCALO, COBBLES_NORMAL, EARTH, EARTH_NORMAL)
	material.set_shader_parameter("tiled", 1.0)
	material.set_shader_parameter("hex_tiling", 1.0)
	material.set_shader_parameter("vertex_paint", 1.0)
	mesh.material_override = material
	ground.add_child(mesh)
	return ground


## Grid lines every CELL across [from, to], with the openings' edges added.
static func _lines(from: float, to: float, edges: Array) -> Array:
	var out := {}
	var x := from

	while x < to - 1e-6:
		out[snappedf(x, 1e-4)] = true
		x += CELL

	out[snappedf(to, 1e-4)] = true

	for pair in edges:
		for e in pair:
			if e > from and e < to:
				out[snappedf(e, 1e-4)] = true

	var lines := out.keys()
	lines.sort()
	return lines


func _collider(cell: Rect2) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(cell.size.x, DEPTH, cell.size.y)
	shape.shape = box
	shape.position = Vector3(cell.get_center().x, -DEPTH / 2, cell.get_center().y)
	add_child(shape)


## Where people walk: from each footprint's door to the next one's, and from
## each to the nearest opening's mouth.
static func _paths(footprints: Array[Dictionary], openings: Array[Rect2]) -> Array:
	var doors := footprints.map(func(f): return f.get("door", _door(f["rect"])))
	var out := []

	for i in doors.size():
		if i + 1 < doors.size():
			out.append([doors[i], doors[i + 1]])

		var nearest := Vector2.INF

		for o in openings:
			var mouth := Vector2(o.get_center().x, o.end.y)

			if doors[i].distance_to(mouth) < doors[i].distance_to(nearest):
				nearest = mouth

		if nearest != Vector2.INF:
			out.append([doors[i], nearest])

	return out


## A footprint's door when none is named: the middle of its side toward +z
## (the plaza side, in the lab).
static func _door(r: Rect2) -> Vector2:
	return Vector2(r.get_center().x, r.end.y)


static func _paint(c: Vector2, footprints: Array[Dictionary], openings: Array[Rect2], paths: Array,
		noise: FastNoiseLite, damp: FastNoiseLite) -> Color:
	var patch := noise.get_noise_2d(c.x, c.y) * 0.5 + 0.5
	var grime := 0.0
	var light := 1.0

	for f in footprints:
		var r: Rect2 = f["rect"]
		var d := _outside(c, r)

		# Strictly inside: under it. On its edge is where wall meets street.
		if r.grow(-0.01).has_point(c):
			light = minf(light, ROOFED_LIGHT if f.get("roofed", false) else 1.0)
			continue

		grime = maxf(grime, clampf(1.0 - d / BANK, 0.0, 1.0))

		for k in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
			grime = maxf(grime, 0.6 * clampf(1.0 - c.distance_to(k) / CORNER, 0.0, 1.0))

		if d < WALL:
			light = minf(light, WALL_LIGHT)

	var worn := 0.0

	for p in paths:
		var along := Geometry2D.get_closest_point_to_segment(c, p[0], p[1])
		worn = maxf(worn, clampf(1.0 - c.distance_to(along) / PATH, 0.0, 1.0))

	for o in openings:
		# On the rim too (d 0), not in the opening itself.
		if not o.grow(-0.01).has_point(c):
			worn = maxf(worn, clampf(1.0 - _outside(c, o) / RIM, 0.0, 1.0))

	var wet := clampf((damp.get_noise_2d(c.x, c.y) - 0.15) * 2.5, 0.0, 1.0)
	return Color(grime * (0.6 + 0.4 * patch), worn * (0.5 + 0.5 * patch), 0.5 - 0.3 * wet, light)


## How far a point lies outside a rectangle (0 inside).
static func _outside(p: Vector2, r: Rect2) -> float:
	var dx := maxf(maxf(r.position.x - p.x, 0.0), p.x - r.end.x)
	var dy := maxf(maxf(r.position.y - p.y, 0.0), p.y - r.end.y)
	return Vector2(dx, dy).length()
