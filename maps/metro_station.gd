extends Node3D
## The Zócalo station (docs/superpowers/specs/2026-10-27-metro-station-design.md; plan
## docs/superpowers/plans/2026-10-30-metro-station.md): its ticket hall, its two stairwells, its two platforms and the
## track between them, the Metro's first real place, crowded and working. Judged on its own, or set into maps/metro at
## PLAN_ORIGIN in place of its spaces' greybox (the map's player).
##
## Its frame is the plan's moved to PLAN_ORIGIN: x and z the plan's own, y up from the platforms' floors (the hall's
## at 6, the track's bed at -1.2). Its spaces and their gaps are read from the Metro's greybox, never retyped.

const RetroScript := preload("res://scripts/Visual/Retro.gd")
const PLAYER := preload("res://Player.tscn")
const StationDressing := preload("res://maps/metro_station_dressing.gd")

const PLAN_ORIGIN := Vector3(0.0, -14.0, 0.0)
const GREYBOX := "res://assets/eclipse/metro/greybox.json"
## The spaces it takes over, and the flights in them.
const SPACES := ["hall", "stairs_n", "stairs_s", "platform_n", "platform_s", "track", "track_notch_n", "track_notch_s"]
const ROUTES_TAKEN := ["stairs_n_flight", "stairs_s_flight", "track_steps_n", "track_steps_s"]
## Ready for the MP-68 (build 2): its tracks' centres (z), its running pads' tops (y), its envelope (m: width with its
## sway, height over the pads), the platforms' edges (|z|).
const TRACKS_Z := [-5.6, 5.6]
const PAD_TOP := -1.0
const CAR := Vector2(2.6, 3.6)
const EDGE_Z := 7.0
## The shell's walls, slabs and seams (m): its walls stand inside its spaces, ending SEAM short of every plane they
## meet, as the Pasaje's do.
const WALL := 0.3
const SLAB := 0.25
const SEAM := 0.01
## A flight's width and its ramp's depth (m; the greybox's stair).
const FLIGHT_WIDTH := 2.4
const FLIGHT_DEPTH := 0.3
## Each track's mouth at either end (m: across, up from the bed), how far it runs on into the dark to its black cap;
## the centre's tunnel (the siding's west, the walkers' way east: the greybox's own tunnels go on from it).
const MOUTH := Vector2(3.0, 4.6)
const DARK_RUN := 12.0
const TUNNEL := Vector2(3.0, 3.0)

@export var standalone := true
## The map's player when set into the Metro.
var host_player: Node3D
var player: CharacterBody3D
## Its structural boxes: the collision.
var shell: Array[Node3D] = []
var world: WorldEnvironment

var _plain: StandardMaterial3D
var _dark: StandardMaterial3D
## The walls standing inside a space under a door above its floor: [from, to (x, z), their top].
var _lips: Array = []
## The greybox's other spaces' outlines (x, z), read once.
var _others: Array[PackedVector2Array] = []
## Each face of wall it stands toward a room: {a, b (x, z: its run on the face's plane), inward (x, z: toward the
## room), y0, y1, floor, space, box (the shell's box)}.
var faces: Array = []
## Its dressing (station_shell's pieces and the Metro's own, in MultiMeshes by kind) and the columns it stands.
var dressing: Node3D
var columns: Array[Node3D] = []
## Its own light (the dressing's fluorescents; the big pieces' brass lamps join them).
var lights: Array[Light3D] = []
## Its flights' ramps: [their ends, as built]; the ramps themselves.
var ramps: Array = []
var ramp_boxes: Array[MeshInstance3D] = []
## Its walls' bare ends ({at, out (x, z: the way it faces), inward, y0, y1, key (its opening's, "" at an open corner)})
## and its lintels' undersides ({from, to, y, inward, key}): the dressing lines them where no reveal does.
var ends: Array = []
var heads: Array = []
## Each track's mouth's run, for the dressing: [its x from, x to, z, its bed, its roof].
var mouth_runs: Array = []
## Where its slabs and ceilings are: {space: [its cells (x, z)]} (the shell's floors and ceilings, by space).
var _floor_boxes := {}
var _ceiling_boxes := {}


func _ready() -> void:
	_plain = StandardMaterial3D.new()
	_plain.albedo_color = Color(0.32, 0.31, 0.29)
	_dark = StandardMaterial3D.new()
	_dark.albedo_color = Color.BLACK
	_dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shell()
	_flights()
	_mouths()
	StationDressing.dress(self)
	if standalone:
		_environment()
	if host_player != null:
		player = host_player
	else:
		player = PLAYER.instantiate()
		player.debug_traversal = false
		add_child(player)
		player.position = Vector3(0.0, 1.05, -9.0)
		# (Facing west along the platform, as the Metro's arrival does.)
		player.rotation.y = PI / 2.0


## Its spaces' greybox records ({name: record}), in its own frame: their outlines (x, z), floors, heights and gaps.
static func spaces() -> Dictionary:
	var out := {}
	var grey: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GREYBOX))
	for m: Dictionary in grey["meshes"]:
		if not m["name"] in SPACES:
			continue
		var record := m.duplicate(true)
		record["floor"] = float(m["floor"]) - PLAN_ORIGIN.y
		for gap: Dictionary in record.get("gaps", []):
			gap["y0"] = float(gap["y0"]) - PLAN_ORIGIN.y
			gap["y1"] = float(gap["y1"]) - PLAN_ORIGIN.y
		out[m["name"]] = record
	return out


## Its flights' greybox routes ({name: [its ends]}), in its own frame.
static func flights() -> Dictionary:
	var out := {}
	var grey: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GREYBOX))
	for m: Dictionary in grey["meshes"]:
		if m["name"] in ROUTES_TAKEN:
			var ends := []
			for q in m["points"]:
				ends.append(Vector3(q[0], q[1], q[2]) - PLAN_ORIGIN)
			out[m["name"]] = ends
	return out


## The structural shell: each space's floor and ceiling slabs over its outline, and its walls round it cut round its
## gaps (and, at the track's ends, round its mouths and the centre's tunnel).
func _shell() -> void:
	var records := spaces()
	for name: String in records:
		var record: Dictionary = records[name]
		var floor_y: float = record["floor"]
		var top: float = floor_y + float(record["height"])
		for cell: Rect2 in _cells(record["polygon"]):
			# (Each edge a seam short only where the greybox lies beyond it.)
			var c0 := cell.position
			var c1 := cell.end
			var lo := Vector3(c0.x + _seam(Vector2(c0.x, c0.y), Vector2(c0.x, c1.y), Vector2.LEFT), 0.0,
				c0.y + _seam(Vector2(c0.x, c0.y), Vector2(c1.x, c0.y), Vector2.UP))
			var hi := Vector3(c1.x - _seam(Vector2(c1.x, c0.y), Vector2(c1.x, c1.y), Vector2.RIGHT), 0.0,
				c1.y - _seam(Vector2(c0.x, c1.y), Vector2(c1.x, c1.y), Vector2.DOWN))
			var under := _box(Vector3(lo.x, floor_y - SLAB, lo.z), Vector3(hi.x, floor_y, hi.z), name + "_floor")
			var over := _box(Vector3(lo.x, top, lo.z), Vector3(hi.x, top + SLAB, hi.z), name + "_ceiling")
			shell.append(under)
			shell.append(over)
			if not _floor_boxes.has(name):
				_floor_boxes[name] = []
				_ceiling_boxes[name] = []
			_floor_boxes[name].append(under)
			_ceiling_boxes[name].append(over)
		var outline: Array = record["polygon"]
		var turning := _turning(outline)
		var edges := []
		for i in outline.size():
			var a := Vector2(outline[i][0], outline[i][1])
			var b := Vector2(outline[(i + 1) % outline.size()][0], outline[(i + 1) % outline.size()][1])
			var holes := []
			for gap: Dictionary in record.get("gaps", []):
				var ga := Vector2(gap["a"][0], gap["a"][1])
				var gb := Vector2(gap["b"][0], gap["b"][1])
				if _on_segment(ga, a, b) and _on_segment(gb, a, b):
					var s0 := (ga - a).dot((b - a).normalized())
					var s1 := (gb - a).dot((b - a).normalized())
					holes.append([minf(s0, s1), maxf(s0, s1), gap["y0"], gap["y1"]])
			if name == "track" and absf(a.x - b.x) < 0.01:
				holes += _end_holes(a, b, floor_y)
			# (Open: a gap its whole length and height, no wall at all.)
			var open := holes.any(func(h): return h[0] <= 0.05 and h[1] >= a.distance_to(b) - 0.05 \
				and float(h[2]) <= floor_y + 0.01 and float(h[3]) >= top - 0.01)
			edges.append([a, b, holes, open])
		for i in edges.size():
			var edge: Array = edges[i]
			# (Its ends bare where the wall round the corner is open.)
			var open_before: bool = edges[(i - 1 + edges.size()) % edges.size()][3]
			var open_after: bool = edges[(i + 1) % edges.size()][3]
			_wall(name, edge[0], edge[1], turning, floor_y, top, edge[2], records, open_before, open_after)


## The track's ends cut: each track's mouth and the centre's tunnel, as [from, to (m along the edge), y0, y1].
func _end_holes(a: Vector2, b: Vector2, floor_y: float) -> Array:
	var along := (b - a).normalized()
	var out := []
	for z: float in TRACKS_Z + [0.0]:
		var size: Vector2 = TUNNEL if z == 0.0 else MOUTH
		var s0 := (Vector2(a.x, z - size.x / 2.0) - a).dot(along)
		var s1 := (Vector2(a.x, z + size.x / 2.0) - a).dot(along)
		var length := a.distance_to(b)
		out.append([clampf(minf(s0, s1), 0.0, length), clampf(maxf(s0, s1), 0.0, length), floor_y, floor_y + size.y])
	return out


## A wall along the edge `a`-`b` from `floor_y` to `top`, cut round `holes` ([from, to along it, y0, y1]); inside its
## space (its outline turning `turning`), but where a piece stands wholly under the floor of what lies beyond (a
## platform's edge face under the platform), outside, clear of every space.
func _wall(name: String, a: Vector2, b: Vector2, turning: float, floor_y: float, top: float, holes: Array,
		records: Dictionary, open_before := false, open_after := false) -> void:
	var length := a.distance_to(b)
	var along := (b - a) / length
	# (Inward: the outline's left when it turns counter-clockwise.)
	var inward := Vector2(-along.y, along.x) * signf(turning)
	holes.sort_custom(func(p, q): return p[0] < q[0])
	var pieces := []
	var from := SEAM
	for hole: Array in holes:
		var h0: float = maxf(hole[0], 0.0)
		var h1: float = minf(hole[1], length)
		if h0 - from > 0.01:
			pieces.append([from, h0, floor_y, top])
		if h1 - h0 > 0.01:
			if float(hole[2]) - floor_y > 0.01:
				pieces.append([h0, h1, floor_y, hole[2]])
			if top - float(hole[3]) > 0.01:
				pieces.append([h0, h1, hole[3], top])
		from = maxf(from, h1)
	if length - SEAM - from > 0.01:
		pieces.append([from, length - SEAM, floor_y, top])
	for piece: Array in pieces:
		var p0 := a + along * float(piece[0])
		var p1 := a + along * float(piece[1])
		# (Where the track meets a notch of its own, the notch walls the run: the track's would stand in the trains'
		# way.)
		if name == "track" and _on_notch((p0 + p1) / 2.0, records):
			# (Its face toward the track dressed all the same.)
			faces.append({"a": p0, "b": p1, "inward": inward, "y0": float(piece[2]), "y1": float(piece[3]), "floor": floor_y,
				"space": name, "box": null})
			continue
		var lo := Vector3(minf(p0.x, p1.x), piece[2], minf(p0.y, p1.y))
		var hi := Vector3(maxf(p0.x, p1.x), piece[3], maxf(p0.y, p1.y))
		# (Its back a seam off the plane only where the greybox lies beyond: against its own spaces it meets them.)
		var seam := _seam(p0, p1, -inward)
		var inside_lo := lo + Vector3(inward.x, 0.0, inward.y) * seam
		var inside_hi := hi + Vector3(inward.x, 0.0, inward.y) * WALL
		var outside_lo := lo - Vector3(inward.x, 0.0, inward.y) * _seam(p0, p1, inward)
		var outside_hi := hi - Vector3(inward.x, 0.0, inward.y) * WALL
		var box_lo := Vector3(minf(inside_lo.x, inside_hi.x), lo.y, minf(inside_lo.z, inside_hi.z))
		var box_hi := Vector3(maxf(inside_lo.x, inside_hi.x), hi.y, maxf(inside_lo.z, inside_hi.z))
		# (Outside, under the neighbour's floor slab: never in it.)
		var out_lo := Vector3(minf(outside_lo.x, outside_hi.x), lo.y, minf(outside_lo.z, outside_hi.z))
		var out_hi := Vector3(maxf(outside_lo.x, outside_hi.x), hi.y - SLAB, maxf(outside_lo.z, outside_hi.z))
		# (Under a neighbour's floor and clear of every space: outside, so its face is the space's own edge.)
		if float(piece[3]) < top - 0.01 and _clear(AABB(out_lo, out_hi - out_lo), records):
			var under := _box(out_lo, out_hi, name + "_wall")
			shell.append(under)
			faces.append({"a": p0, "b": p1, "inward": inward, "y0": float(piece[2]), "y1": float(piece[3]), "floor": floor_y,
				"space": name, "box": under})
		else:
			var wall := _box(box_lo, box_hi, name + "_wall")
			shell.append(wall)
			faces.append({"a": p0 + inward * WALL, "b": p1 + inward * WALL, "inward": inward, "y0": float(piece[2]),
				"y1": float(piece[3]), "floor": floor_y, "space": name, "box": wall})
			# (Under a door above the floor: a lip a flight arriving there must climb onto.)
			if float(piece[3]) < top - 0.01 and float(piece[2]) <= floor_y + 0.01:
				_lips.append([p0, p1, float(piece[3])])
			# Its bare ends and underside, where nothing round it covers them: a run's end at an opening's side (as high
			# as the opening), or at a corner whose wall is open (its whole height); a lintel's underside over its
			# opening.
			var s0: float = piece[0]
			var s1: float = piece[1]
			if float(piece[2]) <= floor_y + 0.01:
				for hole: Array in holes:
					var key := _key(a + along * (float(hole[0]) + float(hole[1])) / 2.0)
					if absf(float(hole[1]) - s0) < 0.02:
						ends.append({"at": p0, "out": -along, "inward": inward, "y0": float(hole[2]),
							"y1": minf(float(hole[3]), top), "key": key, "space": name})
					if absf(float(hole[0]) - s1) < 0.02:
						ends.append({"at": p1, "out": along, "inward": inward, "y0": float(hole[2]),
							"y1": minf(float(hole[3]), top), "key": key, "space": name})
				if open_before and s0 <= SEAM + 0.01:
					ends.append({"at": p0, "out": -along, "inward": inward, "y0": floor_y, "y1": float(piece[3]), "key": "", "space": name})
				if open_after and s1 >= length - SEAM - 0.01:
					ends.append({"at": p1, "out": along, "inward": inward, "y0": floor_y, "y1": float(piece[3]), "key": "", "space": name})
			else:
				heads.append({"from": p0, "to": p1, "y": float(piece[2]), "inward": inward,
					"key": _key((p0 + p1) / 2.0), "space": name})


## Whether `box` stands clear of every space's volume (bar a hair at their edges).
func _clear(box: AABB, records: Dictionary) -> bool:
	for name: String in records:
		var record: Dictionary = records[name]
		var floor_y: float = record["floor"]
		for cell: Rect2 in _cells(record["polygon"]):
			var room := AABB(Vector3(cell.position.x, floor_y, cell.position.y),
				Vector3(cell.size.x, float(record["height"]), cell.size.y)).grow(-0.02)
			if room.intersects(box):
				return false
	return true


## The flights: each a ramp under its treads (the treads are the shell's dressing), from one end to the other, its
## top along the line between them.
func _flights() -> void:
	var routes := flights()
	for name: String in routes:
		var ends: Array = routes[name]
		var a: Vector3 = ends[0]
		var b: Vector3 = ends[1]
		# (Its top end drawn back off a lip it arrives at, so it meets the lip's top: no step up onto it.)
		var rising := b.y > a.y
		var high := b if rising else a
		var low := a if rising else b
		for lip: Array in _lips:
			if _on_segment(Vector2(high.x, high.z), lip[0], lip[1]) and absf(high.y - float(lip[2])) < 0.05:
				high += Vector3(low.x - high.x, 0.0, low.z - high.z).normalized() * (WALL + SEAM)
		a = low if rising else high
		b = high if rising else low
		ramps.append([a, b])
		var run := b - a
		var ramp := MeshInstance3D.new()
		ramp.name = name
		var box := BoxMesh.new()
		box.size = Vector3(FLIGHT_WIDTH, FLIGHT_DEPTH, run.length())
		box.material = _plain
		ramp.mesh = box
		add_child(ramp)
		var forward := run.normalized()
		var side := forward.cross(Vector3.UP).normalized()
		var up := side.cross(forward).normalized()
		ramp.transform = Transform3D(Basis(side, up, forward), (a + b) / 2.0 - up * FLIGHT_DEPTH / 2.0)
		_solid(ramp, box.size)
		shell.append(ramp)
		ramp_boxes.append(ramp)


## Each track's mouth at either end running on DARK_RUN into the dark to a black cap: its floor, its roof, its sides.
func _mouths() -> void:
	for end in [-1.0, 1.0]:
		var x0: float = end * 50.0
		var x1: float = end * (50.0 + DARK_RUN)
		var lo_x := minf(x0, x1)
		var hi_x := maxf(x0, x1)
		for z: float in TRACKS_Z:
			var half := MOUTH.x / 2.0
			var bed := -1.2
			var roof := bed + MOUTH.y
			mouth_runs.append([lo_x, hi_x, z, bed, roof])
			shell.append(_box(Vector3(lo_x, bed - SLAB, z - half), Vector3(hi_x, bed, z + half), "mouth_floor"))
			shell.append(_box(Vector3(lo_x, roof, z - half - WALL), Vector3(hi_x, roof + SLAB, z + half + WALL), "mouth_roof"))
			for side in [-1.0, 1.0]:
				var face: float = z + side * half
				shell.append(_box(Vector3(lo_x, bed, minf(face, face + side * WALL)), Vector3(hi_x, roof,
					maxf(face, face + side * WALL)), "mouth_side"))
			var cap := _box(Vector3(minf(x1, x1 + end * WALL), bed, z - half), Vector3(maxf(x1, x1 + end * WALL), roof, z + half),
				"mouth_cap")
			(cap.mesh as BoxMesh).material = _dark
			shell.append(cap)


## The outline's cells: an outline of straight runs along x and z cut into rectangles.
func _cells(outline: Array) -> Array[Rect2]:
	var xs := []
	var zs := []
	var polygon := PackedVector2Array()
	for q in outline:
		polygon.append(Vector2(q[0], q[1]))
		if not xs.has(float(q[0])):
			xs.append(float(q[0]))
		if not zs.has(float(q[1])):
			zs.append(float(q[1]))
	xs.sort()
	zs.sort()
	var out: Array[Rect2] = []
	for i in xs.size() - 1:
		var run_from := -1
		for j in zs.size():
			var inside := j < zs.size() - 1 and Geometry2D.is_point_in_polygon(
				Vector2((xs[i] + xs[i + 1]) / 2.0, (zs[j] + zs[j + 1]) / 2.0), polygon)
			if inside and run_from < 0:
				run_from = j
			elif not inside and run_from >= 0:
				out.append(Rect2(xs[i], zs[run_from], xs[i + 1] - xs[i], zs[j] - zs[run_from]))
				run_from = -1
	return out


## Its outline's turning: its signed area's sign (positive counter-clockwise in x, z).
func _turning(outline: Array) -> float:
	var total := 0.0
	for i in outline.size():
		var p: Array = outline[i]
		var q: Array = outline[(i + 1) % outline.size()]
		total += float(p[0]) * float(q[1]) - float(q[0]) * float(p[1])
	return signf(total)


## The seam a face along `a`-`b` keeps off its plane, looking out along `out`: SEAM where any of the greybox's other
## spaces lies just beyond it (sampled every metre), else none (its own spaces, or bare rock).
func _seam(a: Vector2, b: Vector2, out: Vector2) -> float:
	if _others.is_empty():
		var grey: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GREYBOX))
		for m: Dictionary in grey["meshes"]:
			if m["kind"] == "space" and not m["name"] in SPACES:
				var polygon := PackedVector2Array()
				for q in m["polygon"]:
					polygon.append(Vector2(q[0], q[1]))
				_others.append(polygon)
	var steps := maxi(int(a.distance_to(b)), 1)
	for k in steps + 1:
		var p := a.lerp(b, float(k) / steps) + out.normalized() * 0.05
		for polygon: PackedVector2Array in _others:
			if Geometry2D.is_point_in_polygon(p, polygon):
				return SEAM
	return 0.0


## An opening's key: its middle on its wall's line, to a decimetre (as the dressing names the doors it reveals).
static func _key(p: Vector2) -> String:
	return "%.1f,%.1f" % [p.x, p.y]


## Whether `p` lies on a notch's outline.
func _on_notch(p: Vector2, records: Dictionary) -> bool:
	for name in ["track_notch_n", "track_notch_s"]:
		var outline: Array = records.get(name, {}).get("polygon", [])
		for i in outline.size():
			var q: Array = outline[i]
			var r: Array = outline[(i + 1) % outline.size()]
			if _on_segment(p, Vector2(q[0], q[1]), Vector2(r[0], r[1])):
				return true
	return false


func _on_segment(p: Vector2, a: Vector2, b: Vector2) -> bool:
	return Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) < 0.02


func _environment() -> void:
	var environment := RetroScript.night_environment(Color(0.36, 0.44, 0.58), 0.28)
	world = WorldEnvironment.new()
	world.environment = environment
	add_child(world)


## A solid box from `lo` to `hi` (its frame), plain until the shell is dressed.
func _box(lo: Vector3, hi: Vector3, kind: String) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = kind
	var box := BoxMesh.new()
	box.size = hi - lo
	box.material = _plain
	mesh.mesh = box
	mesh.set_meta("built", true)
	add_child(mesh)
	mesh.position = (lo + hi) / 2.0
	_solid(mesh, box.size)
	return mesh


func _solid(mesh: MeshInstance3D, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var solid := BoxShape3D.new()
	solid.size = size
	shape.shape = solid
	body.add_child(shape)
	mesh.add_child(body)
