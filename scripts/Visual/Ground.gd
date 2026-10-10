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


## Metres one tile covers, by tile (eclipse_atlas.GROUND_PERIODS); TILE_M otherwise.
const TILE_METRES := {&"ground_flags": 2.4}
## Tiles laid in regular courses (slabs): tiled straight, since hex-tiling's
## turned, blended patches would break their joints into scratches.
const STRAIGHT := [&"ground_flags"]
## How near a cell's edge may come to an opening's or inlay's and still count
## as inside it (m): the grid's lines are snapped to 1e-4, the edges are not.
const EDGE := 1e-3
## Relaid stone's tint (B) in a patch.
const RELAID := 0.65


## The ground over `area` (x, z), open at `openings`, weathered against
## `footprints` ([{"rect": Rect2, "roofed": bool, "door": Vector2 (optional)}]).
## `options` (the street and canal kit's plan, Task 3):
##   "tile": StringName      the painted tile (ground_cobbles); earth under it
##   "level": float          the height of its top and its collider's (0)
##   "inlays": [PackedVector2Array]   flush pieces set in it: cut from the
##                           mesh, the collider kept under them
##   "covered": [PackedVector2Array]  under buildings: cells wholly inside
##                           are left out, collider and all, no rim worn
##   "patches": [Rect2]      stone relaid in another stone
##   "cell": float           the grid (CELL)
##   "paths": Array          walking lines [[Vector2, Vector2]] (else from the footprints)
##   "depth": float          the collider's depth (DEPTH)
static func build(area: Rect2, openings: Array[Rect2], footprints: Array[Dictionary], seed: int,
		options := {}) -> Ground:
	var ground := Ground.new()
	ground.name = "ground"
	var tile: StringName = options.get("tile", &"ground_cobbles")
	var level: float = options.get("level", 0.0)
	var cell: float = options.get("cell", CELL)
	var inlays: Array = options.get("inlays", [])
	var covered: Array = options.get("covered", [])
	var patches: Array = options.get("patches", [])
	var depth: float = options.get("depth", DEPTH)
	# Lines at every opening's edges, and at every footprint's edges and BANK
	# out from them, so the stories have vertices where they start and end;
	# at rectangular inlays' and covers' edges, so they cut along grid lines.
	var x_edges := openings.map(func(o): return [o.position.x, o.end.x])
	var z_edges := openings.map(func(o): return [o.position.y, o.end.y])

	for f in footprints:
		var r: Rect2 = f["rect"]
		x_edges.append([r.position.x - BANK, r.position.x, r.end.x, r.end.x + BANK])
		z_edges.append([r.position.y - BANK, r.position.y, r.end.y, r.end.y + BANK])

	var curved: Array[PackedVector2Array] = []

	for polygon: PackedVector2Array in inlays + covered:
		var box := _box(polygon)

		if _is_rect(polygon):
			x_edges.append([box.position.x, box.end.x])
			z_edges.append([box.position.y, box.end.y])
		elif polygon in inlays:
			curved.append(polygon)

	for r: Rect2 in patches:
		x_edges.append([r.position.x, r.end.x])
		z_edges.append([r.position.y, r.end.y])

	var xs := _lines(area.position.x, area.end.x, x_edges, cell)
	var zs := _lines(area.position.y, area.end.y, z_edges, cell)
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.frequency = 0.35
	var damp := FastNoiseLite.new()
	damp.seed = seed + 1
	damp.frequency = 0.12
	var paths: Array = options.get("paths", _paths(footprints, openings))
	var rect_inlays: Array[Rect2] = []

	for polygon: PackedVector2Array in inlays:
		if _is_rect(polygon):
			rect_inlays.append(_box(polygon))

	var curved_boxes := curved.map(func(p): return _box(p))
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var index := {}
	var paint := func(c: Vector2) -> Color:
		var colour := _paint(c, footprints, openings, paths, noise, damp)

		for r: Rect2 in patches:
			if r.has_point(c) or _outside(c, r) < 1e-4:
				colour.b = RELAID
				colour.g = 0.0

		return colour
	var vertex := func(c: Vector2) -> int:
		var key := c.snappedf(1e-4)

		if not index.has(key):
			index[key] = index.size()
			tool.set_normal(Vector3.UP)
			tool.set_tangent(Plane(1, 0, 0, 1))
			tool.set_uv(c / TILE_METRES.get(tile, TILE_M))
			tool.set_color(paint.call(c))
			tool.add_vertex(Vector3(c.x, level, c.y))

		return index[key]

	for j in zs.size() - 1:
		var run_from := -1

		for i in xs.size():
			var solid := i < xs.size() - 1
			var cell_rect := Rect2()

			if solid:
				cell_rect = Rect2(xs[i], zs[j], xs[i + 1] - xs[i], zs[j + 1] - zs[j])
				# (Within EDGE: grid lines are snapped, the rectangles' edges not.)
				solid = not openings.any(func(o: Rect2): return o.grow(EDGE).encloses(cell_rect)) \
					and not covered.any(func(p): return _covers(p, cell_rect))

			if solid:
				if not rect_inlays.any(func(r: Rect2): return r.grow(EDGE).encloses(cell_rect)):
					_add_cell(tool, vertex, cell_rect, curved, curved_boxes, level)

				if run_from < 0:
					run_from = i
			elif run_from >= 0:
				ground._collider(Rect2(xs[run_from], zs[j], xs[i] - xs[run_from], zs[j + 1] - zs[j]), level, depth)
				run_from = -1

	var mesh := MeshInstance3D.new()
	mesh.name = "mesh"
	mesh.mesh = tool.commit()
	var root := "res://textures/painted/eclipse/"
	var material := Painterly.material(load(root + tile + ".png"), &"shader_led", Painterly.ZOCALO,
		load(root + tile + "_normal.png"), EARTH, EARTH_NORMAL)
	material.set_shader_parameter("tiled", 1.0)
	material.set_shader_parameter("hex_tiling", 0.0 if tile in STRAIGHT else 1.0)
	material.set_shader_parameter("vertex_paint", 1.0)
	mesh.material_override = material
	ground.add_child(mesh)
	return ground


## One cell's triangles, clockwise from above (Godot's front, so it faces
## up), cut round any curved inlay that reaches into it.
static func _add_cell(tool: SurfaceTool, vertex: Callable, cell: Rect2, curved: Array[PackedVector2Array],
		boxes: Array, level: float) -> void:
	var corners := PackedVector2Array([cell.position, Vector2(cell.end.x, cell.position.y), cell.end,
		Vector2(cell.position.x, cell.end.y)])
	var remains: Array[PackedVector2Array] = [corners]

	for k in curved.size():
		if not (boxes[k] as Rect2).intersects(cell):
			continue

		var next: Array[PackedVector2Array] = []

		for r in remains:
			for piece: PackedVector2Array in Geometry2D.clip_polygons(r, curved[k]):
				if Geometry2D.is_polygon_clockwise(piece) != Geometry2D.is_polygon_clockwise(corners):
					push_error("Ground: an inlay lies wholly inside a %s cell; the grid is too coarse for it" % cell)
					continue

				next.append(piece)

		remains = next

	if remains.size() == 1 and remains[0] == corners:
		var ids := []

		for c in corners:
			ids.append(vertex.call(c))

		for k in [0, 1, 2, 0, 2, 3]:
			tool.add_index(ids[k])

		return

	for piece in remains:
		var triangles := Geometry2D.triangulate_polygon(piece)

		for t in range(0, triangles.size(), 3):
			var a := piece[triangles[t]]
			var b := piece[triangles[t + 1]]
			var c := piece[triangles[t + 2]]
			# Facing up from above: (b - a) x (c - a) points down in Godot's
			# x-right, z-south plane when the corners run clockwise.
			var up := (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x) > 0.0

			for q in ([a, b, c] if up else [a, c, b]):
				tool.add_index(vertex.call(q))


static func _box(polygon: PackedVector2Array) -> Rect2:
	var box := Rect2(polygon[0], Vector2.ZERO)

	for p in polygon:
		box = box.expand(p)

	return box


## Whether a polygon is an axis-aligned rectangle (its box, corner for corner).
static func _is_rect(polygon: PackedVector2Array) -> bool:
	if polygon.size() != 4:
		return false

	var box := _box(polygon)

	for p in polygon:
		var on_x := absf(p.x - box.position.x) < 1e-4 or absf(p.x - box.end.x) < 1e-4
		var on_z := absf(p.y - box.position.y) < 1e-4 or absf(p.y - box.end.y) < 1e-4

		if not (on_x and on_z):
			return false

	return true


## Whether a cell lies wholly under a covering polygon (its corners pulled a
## hair inward, so a cell sharing the polygon's edge counts).
static func _covers(polygon: PackedVector2Array, cell: Rect2) -> bool:
	var inner := cell.grow(-1e-3)

	for c in [inner.position, Vector2(inner.end.x, inner.position.y), inner.end, Vector2(inner.position.x, inner.end.y)]:
		if not Geometry2D.is_point_in_polygon(c, polygon):
			return false

	return true


## Grid lines every CELL across [from, to], with the openings' edges added.
static func _lines(from: float, to: float, edges: Array, cell := CELL) -> Array:
	var out := {}
	# On the world's grid, so neighbouring areas' lines meet.
	var x := ceilf(from / cell - 1e-6) * cell
	out[snappedf(from, 1e-4)] = true

	while x < to - 1e-6:
		out[snappedf(x, 1e-4)] = true
		x += cell

	out[snappedf(to, 1e-4)] = true

	for pair in edges:
		for e in pair:
			if e > from and e < to:
				out[snappedf(e, 1e-4)] = true

	var lines := out.keys()
	lines.sort()
	return lines


func _collider(cell: Rect2, level := 0.0, depth := DEPTH) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(cell.size.x, depth, cell.size.y)
	shape.shape = box
	shape.position = Vector3(cell.get_center().x, level - depth / 2, cell.get_center().y)
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
