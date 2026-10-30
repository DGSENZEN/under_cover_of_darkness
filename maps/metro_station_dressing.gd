extends RefCounted
## The Zócalo station's shell dressed (docs/superpowers/plans/2026-10-30-metro-station.md, Task 4): its walls tiled to
## just over their cap and plastered above, the pit's faces and the track's walls in concrete; the terrazzo floors and
## the platforms' stone copings with the yellow line; the hall's coffers and the plaster ceilings, the platforms' strip
## fittings; the hall's tiled columns and the plain ones between the tracks; the flights' treads and handrails; the
## doors' reveals and the tunnels' portals; the hanging signs, the line maps and the name tablets, their faces blank
## (the user's words, and the tablets' mosaic the user's texture, asked for). station_shell's pieces (and
## underground_walls' tablet) in MultiMeshes, by kind and space: there are thousands. The shell's walls it covers are
## hidden, kept for their collision; its floors and ceilings stay, seen only in the joints, the slabs and panels laid
## LAID off them.

const Painterly := preload("res://scripts/Visual/Painterly.gd")

const SHELL_KIT := "res://assets/eclipse/kit/station_shell.glb"
const WALLS_KIT := "res://assets/eclipse/kit/underground_walls.glb"
## station_shell's measures (tools/eclipse/station_shell.py): a panel's width, the tiled panels' height, the tiles' face
## off the wall, a floor slab's and a ceiling panel's side, the coping's reach, a coffer's side, a pit face's height, a
## tread's depth and rise and a flight's width, a handrail's run, the line map's width.
const PANEL := 1.2
const TILED := 2.5
const FACE := 0.067
const MODULE := 1.2
const COPING := 0.6
const COFFER := 2.4
const PIT := 1.2
const TREAD := 0.4
const RISE := 0.17
const FLIGHT := 2.4
const RAIL := 1.0
const MAP_WIDE := 2.4
## How far the floors' slabs stand over the shell's floor, and the ceilings' panels under its ceiling (m): the shell's
## boxes kept, seen in the joints between them, never in their planes.
const LAID := 0.01
## The doors' reveals the kit has ([width, height, depth]).
const REVEALS := [[3.0, 3.0, 0.6], [3.0, 3.0, 0.31], [4.0, 3.0, 0.31]]
## The hall's columns (x, z): two rows clear of the ways across it (the corridors' mouths to the banks at x ±14, the
## banks to the stairs' heads and the market stairs; the model of Tenochtitlan at its middle); between the tracks, a
## row at most 8 m apart.
const HALL_COLUMNS := [Vector2(-24.0, -7.5), Vector2(-16.0, -7.5), Vector2(-2.0, -7.5), Vector2(2.0, -7.5),
	Vector2(16.0, -7.5), Vector2(24.0, -7.5), Vector2(-24.0, 7.5), Vector2(-16.0, 7.5), Vector2(-2.0, 7.5),
	Vector2(2.0, 7.5), Vector2(16.0, 7.5), Vector2(24.0, 7.5)]
const COLUMN_HALL := Vector2(0.6, 5.0)
const COLUMN_TRACK := Vector2(0.6, 6.7)
const TRACK_COLUMNS_FROM := -44.0
const TRACK_COLUMNS_TO := 38.0
const TRACK_COLUMNS_EVERY := 8.0
## The platforms' strip fittings: how far in from the edge (m).
const STRIP_IN := 1.0
## The name tablets along the platforms' back walls (x), clear of the stairs' doors; their foot over the floor.
const TABLETS_X := [-40.0, -24.0, -8.0, 8.0, 24.0, 40.0]
const TABLET_FOOT := 1.65
## A hanging sign: how far in front of the gap it names (m).
const SIGN_OUT := 1.5


static func dress(station) -> void:
	if not ResourceLoader.exists(SHELL_KIT):
		return
	var root := Node3D.new()
	root.name = "dressing"
	station.add_child(root)
	station.dressing = root
	var kit := SetKit.kit(SHELL_KIT)
	var look := Painterly.material(SetKit.painted(["station_shell.png", "station_shell_base.png"]), &"bespoke")
	var batches := {}
	_walls(station, batches)
	_floors(station, batches)
	_ceilings(station, batches)
	_columns(station, root, batches)
	_flights(station, batches)
	_openings(station, batches)
	_signs(station, batches)
	for key: String in batches:
		var kind := key.get_slice("@", 0)
		if kit.has(kind):
			_many(root, key, kind, kit[kind], look, batches[key])
	_tablets(station, root)


## Each face of wall: tiled panels to just over their cap and plaster above (only plaster over a door); in the track's
## spaces, concrete. Each run fitted with whole panels, a little wider or narrower than their 1.2 m.
static func _walls(station, batches: Dictionary) -> void:
	for face: Dictionary in station.faces:
		var a: Vector2 = face["a"]
		var b: Vector2 = face["b"]
		var length := a.distance_to(b)
		if length < 0.25:
			continue
		var inward: Vector2 = face["inward"]
		var in3 := Vector3(inward.x, 0.0, inward.y)
		var along3 := Vector3.UP.cross(in3)
		var along := Vector2(along3.x, along3.z)
		var start := a if (b - a).dot(along) > 0.0 else b
		var count := maxi(1, roundi(length / PANEL))
		var sx := length / (count * PANEL)
		var y0: float = face["y0"]
		var y1: float = face["y1"]
		var space: String = face["space"]
		var concrete := space.begins_with("track")
		var basis := Basis(along3, Vector3.UP, in3)
		for k in count:
			var foot := start + along * (k * PANEL * sx)
			var at := Vector3(foot.x, 0.0, foot.y)
			if concrete:
				_rows(batches, "pit_face@" + space, basis, at, sx, y0, y1, PIT)
				continue
			var y := y0
			if y0 <= float(face["floor"]) + 0.01 and y1 - y0 >= TILED:
				var worn := _hash(foot.x * 1.37 + foot.y * 2.11) > 0.8
				_add(batches, ("wall_low_worn@" if worn else "wall_low@") + space,
					Transform3D(basis * Basis.from_scale(Vector3(sx, 1.0, 1.0)), at + Vector3.UP * y0))
				y = y0 + TILED
			if y1 - y > 0.01:
				_rows(batches, "plaster_sheet@" + space, basis, at, sx, y, y1, 1.0)
		if face["box"] != null:
			(face["box"] as Node3D).visible = false


## Rows of a sheet `tall` high from `y0` to `y1`, fitted, at `at` along `basis`.
static func _rows(batches: Dictionary, key: String, basis: Basis, at: Vector3, sx: float, y0: float, y1: float,
		tall: float) -> void:
	var rows := maxi(1, roundi((y1 - y0) / tall))
	var sy := (y1 - y0) / (rows * tall)
	for r in rows:
		_add(batches, key, Transform3D(basis * Basis.from_scale(Vector3(sx, sy, 1.0)), at + Vector3.UP * (y0 + r * tall * sy)))


## The floors: terrazzo slabs over each cell, fitted; along a platform's edge, a row of copings with the yellow line.
static func _floors(station, batches: Dictionary) -> void:
	for space: String in ["hall", "stairs_n", "stairs_s", "platform_n", "platform_s"]:
		for box: MeshInstance3D in station._floor_boxes.get(space, []):
			var size: Vector3 = (box.mesh as BoxMesh).size
			var lo := box.position - size / 2.0
			var hi := box.position + size / 2.0
			var top := hi.y
			if space.begins_with("platform"):
				var edge: float = station.EDGE_Z
				# (The edge the cell meets: its high side on the north platform, its low on the south.)
				var north := space == "platform_n"
				var at_edge := absf((hi.z if north else lo.z) - (-edge if north else edge)) < 0.03
				if at_edge:
					var count := maxi(1, roundi((hi.x - lo.x) / PANEL))
					var sx := (hi.x - lo.x) / (count * PANEL)
					# (Its edge at the platform's, reaching in: on the north platform toward -z, on the south toward +z.)
					var basis := Basis.IDENTITY if north else Basis(Vector3(-1.0, 0.0, 0.0), Vector3.UP, Vector3(0.0, 0.0, -1.0))
					for k in count:
						var x := lo.x + k * PANEL * sx if north else hi.x - k * PANEL * sx
						var edge_z := hi.z if north else lo.z
						_add(batches, "coping@" + space, Transform3D(basis * Basis.from_scale(Vector3(sx, 1.0, 1.0)),
							Vector3(x, top + LAID, edge_z)))
					if north:
						hi.z -= COPING
					else:
						lo.z += COPING
			var nx := maxi(1, roundi((hi.x - lo.x) / MODULE))
			var nz := maxi(1, roundi((hi.z - lo.z) / MODULE))
			var sx := (hi.x - lo.x) / (nx * MODULE)
			var sz := (hi.z - lo.z) / (nz * MODULE)
			for i in nx:
				for j in nz:
					var at := Vector3(lo.x + (i + 0.5) * MODULE * sx, top + LAID, lo.z + (j + 0.5) * MODULE * sz)
					var h := _hash(at.x * 0.731 + at.z * 1.913)
					var kind := "floor_slab_c" if h > 0.9 else ("floor_slab_b" if h > 0.45 else "floor_slab_a")
					# (Each turned end for end or not, so the slabs' painting never runs in rows: a half turn only, a
					# fitted slab not being square.)
					var turn := Basis(Vector3.UP, PI if _hash(at.x * 3.1 + at.z * 0.7) > 0.5 else 0.0)
					_add(batches, kind + "@" + space, Transform3D(turn * Basis.from_scale(Vector3(sx, 1.0, sz)), at))


## The ceilings: the hall's coffers, a fitting in each; plaster panels elsewhere; the platforms' strip fittings along
## their edges.
static func _ceilings(station, batches: Dictionary) -> void:
	for space: String in station._ceiling_boxes:
		var hall := space == "hall"
		var side := COFFER if hall else MODULE
		for box: MeshInstance3D in station._ceiling_boxes[space]:
			var size: Vector3 = (box.mesh as BoxMesh).size
			var lo := box.position - size / 2.0
			var hi := box.position + size / 2.0
			var nx := maxi(1, roundi((hi.x - lo.x) / side))
			var nz := maxi(1, roundi((hi.z - lo.z) / side))
			var sx := (hi.x - lo.x) / (nx * side)
			var sz := (hi.z - lo.z) / (nz * side)
			for i in nx:
				for j in nz:
					var at := Vector3(lo.x + (i + 0.5) * side * sx, lo.y - LAID, lo.z + (j + 0.5) * side * sz)
					_add(batches, ("coffer@" if hall else "ceiling_panel@") + space,
						Transform3D(Basis.from_scale(Vector3(sx, 1.0, sz)), at))
	for space: String in ["platform_n", "platform_s"]:
		var z: float = (-1.0 if space == "platform_n" else 1.0) * (float(station.EDGE_Z) + STRIP_IN)
		var top: float = station.spaces()[space]["floor"] + float(station.spaces()[space]["height"]) - 0.04 - LAID
		var count := roundi(98.0 / PANEL)
		var sx := 98.0 / (count * PANEL)
		for k in count:
			_add(batches, "strip_fitting@" + space, Transform3D(Basis.from_scale(Vector3(sx, 1.0, 1.0)),
				Vector3(-49.0 + k * PANEL * sx, top, z)))


## The hall's tiled columns and the plain ones between the tracks, solid.
static func _columns(station, root: Node3D, batches: Dictionary) -> void:
	var hall_floor: float = station.spaces()["hall"]["floor"]
	var bed: float = station.spaces()["track"]["floor"]
	var places := []
	for at: Vector2 in HALL_COLUMNS:
		places.append(["column_hall", Vector3(at.x, hall_floor, at.y), COLUMN_HALL])
	var x := TRACK_COLUMNS_FROM
	while x <= TRACK_COLUMNS_TO + 0.01:
		places.append(["column_track", Vector3(x, bed, 0.0), COLUMN_TRACK])
		x += TRACK_COLUMNS_EVERY
	for spec: Array in places:
		var at: Vector3 = spec[1]
		var size: Vector2 = spec[2]
		_add(batches, spec[0] + "@columns", Transform3D(Basis.IDENTITY, at))
		var body := StaticBody3D.new()
		body.name = spec[0]
		var shape := CollisionShape3D.new()
		var solid := BoxShape3D.new()
		solid.size = Vector3(size.x, size.y, size.x)
		shape.shape = solid
		body.add_child(shape)
		root.add_child(body)
		body.position = at + Vector3.UP * size.y / 2.0
		station.columns.append(body)


## Each flight's treads over its ramp (each half a rise proud of it at its nose, half sunk at its back) and a handrail
## either side.
static func _flights(station, batches: Dictionary) -> void:
	for ends: Array in station.ramps:
		var low: Vector3 = ends[0] if (ends[0] as Vector3).y < (ends[1] as Vector3).y else ends[1]
		var high: Vector3 = ends[1] if low == ends[0] else ends[0]
		var flat := Vector3(high.x - low.x, 0.0, high.z - low.z)
		var run := flat.length()
		var rise := high.y - low.y
		var count := maxi(maxi(1, roundi(rise / RISE)), roundi(run / TREAD))
		var depth := run / count
		var step := rise / count
		var up := flat / run
		var back := -up
		var basis := Basis(Vector3.UP.cross(back), Vector3.UP, back) * Basis.from_scale(Vector3((FLIGHT - 0.02) / FLIGHT,
			step / RISE, depth / TREAD))
		for k in count:
			var nose := low + up * (k * depth) + Vector3.UP * ((k + 0.5) * step)
			_add(batches, "tread@flights", Transform3D(basis, nose))
		var across := Vector3.UP.cross(up).normalized()
		var length := (high - low).length()
		var sections := ceili(length / RAIL)
		var slope := (high - low) / sections
		for side in [-1.0, 1.0]:
			var offset: Vector3 = across * side * (FLIGHT / 2.0 - 0.05)
			for k in sections:
				var x_axis := slope
				var z_axis := x_axis.cross(Vector3.UP).normalized()
				_add(batches, "handrail@flights", Transform3D(Basis(x_axis, Vector3.UP, z_axis), low + offset + slope * k))


## Each door's cement reveal (a door between two of its spaces once), and the tunnels' portals at the track's ends.
static func _openings(station, batches: Dictionary) -> void:
	var records: Dictionary = station.spaces()
	var done := {}
	for space: String in records:
		var record: Dictionary = records[space]
		var floor_y: float = record["floor"]
		var top: float = floor_y + float(record["height"])
		var centre := _centre(record["polygon"])
		for gap: Dictionary in record.get("gaps", []):
			var a := Vector2(gap["a"][0], gap["a"][1])
			var b := Vector2(gap["b"][0], gap["b"][1])
			var mid := (a + b) / 2.0
			var key := "%.1f,%.1f" % [mid.x, mid.y]
			# (Only a door: a lintel over it, a jamb either side.)
			if done.has(key) or float(gap["y1"]) >= top - 0.01 or a.distance_to(b) > 5.0:
				continue
			done[key] = true
			var along := (b - a).normalized()
			var inward := Vector2(-along.y, along.x)
			if inward.dot(centre - mid) < 0.0:
				inward = -inward
			var depth: float = 0.6 if gap.get("to", "") in station.SPACES else 0.31
			var kind := ""
			for size: Array in REVEALS:
				if absf(size[0] - a.distance_to(b)) < 0.05 and absf(size[1] - (float(gap["y1"]) - float(gap["y0"]))) < 0.05 \
						and absf(size[2] - depth) < 0.02:
					kind = "reveal_%dx%dx%d" % [roundi(size[0] * 100.0), roundi(size[1] * 100.0), roundi(size[2] * 100.0)]
			if kind.is_empty():
				continue
			var face: Vector2 = mid + inward * float(station.WALL)
			var in3 := Vector3(inward.x, 0.0, inward.y)
			_add(batches, kind + "@doors", Transform3D(Basis(Vector3.UP.cross(in3), Vector3.UP, in3),
				Vector3(face.x, float(gap["y0"]), face.y)))
	var bed: float = records["track"]["floor"]
	for end in [-1.0, 1.0]:
		var face_x: float = end * (50.0 - station.WALL)
		var toward := Vector3(-end, 0.0, 0.0)
		var basis := Basis(Vector3.UP.cross(toward), Vector3.UP, toward)
		for z: float in station.TRACKS_Z:
			_add(batches, "portal_mouth@portals", Transform3D(basis, Vector3(face_x, bed, z)))
		_add(batches, "portal_tunnel@portals", Transform3D(basis, Vector3(face_x, bed, 0.0)))


## The hanging signs (over each of the hall's doors, and each platform's door to its stairs), and the line maps (on the
## hall's north wall, and each platform's back wall beside its door).
static func _signs(station, batches: Dictionary) -> void:
	var records: Dictionary = station.spaces()
	for space: String in ["hall", "platform_n", "platform_s"]:
		var record: Dictionary = records[space]
		var top: float = float(record["floor"]) + float(record["height"])
		var centre := _centre(record["polygon"])
		for gap: Dictionary in record.get("gaps", []):
			var a := Vector2(gap["a"][0], gap["a"][1])
			var b := Vector2(gap["b"][0], gap["b"][1])
			if a.distance_to(b) > 5.0:
				continue
			var mid := (a + b) / 2.0
			var along := (b - a).normalized()
			var inward := Vector2(-along.y, along.x)
			if inward.dot(centre - mid) < 0.0:
				inward = -inward
			var at := mid + inward * SIGN_OUT
			var in3 := Vector3(inward.x, 0.0, inward.y)
			_add(batches, "sign_board@" + space, Transform3D(Basis(Vector3.UP.cross(in3), Vector3.UP, in3),
				Vector3(at.x, top, at.y)))
	var hall_floor: float = records["hall"]["floor"]
	_wall_piece(batches, "line_map@hall", Vector2(8.0, -14.0 + station.WALL), Vector2(0.0, 1.0), hall_floor + 1.2)
	_wall_piece(batches, "line_map@platform_n", Vector2(4.0, -14.0 + station.WALL), Vector2(0.0, 1.0), 1.2)
	_wall_piece(batches, "line_map@platform_s", Vector2(-4.0 - MAP_WIDE, 14.0 - station.WALL), Vector2(0.0, -1.0), 1.2)


## A piece hung on a wall's tiles: its start `at` (x, z on the wall's face), the wall facing `inward`, its foot `y`.
static func _wall_piece(batches: Dictionary, key: String, at: Vector2, inward: Vector2, y: float) -> void:
	var in3 := Vector3(inward.x, 0.0, inward.y)
	var along := Vector3.UP.cross(in3)
	var start := Vector3(at.x, y, at.y) + in3 * FACE
	# (Its run from `at` along the wall the way its frame runs.)
	if along.x < 0.0:
		start -= along * MAP_WIDE
	_add(batches, key, Transform3D(Basis(along, Vector3.UP, in3), start))


## The platforms' name tablets (underground_walls' mosaic frame, its field blank: the name and the mosaic's texture
## the user's), on the back walls' tiles.
static func _tablets(station, root: Node3D) -> void:
	if not ResourceLoader.exists(WALLS_KIT):
		return
	var walls := SetKit.kit(WALLS_KIT)
	if not walls.has("name_tablet"):
		return
	var look := Painterly.material(SetKit.painted(["underground_walls.png", "underground_walls_base.png"]), &"bespoke")
	var transforms: Array = []
	for side in [-1.0, 1.0]:
		var inward := Vector3(0.0, 0.0, -side)
		var along := Vector3.UP.cross(inward)
		var face_z: float = side * (14.0 - station.WALL) + inward.z * FACE
		for x: float in TABLETS_X:
			var start := Vector3(x, TABLET_FOOT, face_z) - along * 0.5
			transforms.append(Transform3D(Basis(along, Vector3.UP, inward), start))
	_many(root, "name_tablet@platforms", "name_tablet", walls["name_tablet"], look, transforms)


static func _many(root: Node3D, key: String, kind: String, mesh: Mesh, look: Material, transforms: Array) -> void:
	var dressed := mesh.duplicate() as Mesh
	for i in dressed.get_surface_count():
		var slot: Material = mesh.surface_get_material(i)
		var glazed := slot != null and slot.resource_name.begins_with("glass")
		(dressed as ArrayMesh).surface_set_material(i, SetKit.glass() if glazed else look)
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	many.mesh = dressed
	many.instance_count = transforms.size()
	for i in transforms.size():
		many.set_instance_transform(i, transforms[i])
	var node := MultiMeshInstance3D.new()
	node.name = key.replace("@", "_")
	node.multimesh = many
	node.set_meta("kind", kind)
	# (Its instances' transforms kept with it: a headless run's renderer keeps none.)
	node.set_meta("transforms", transforms)
	root.add_child(node)


static func _add(batches: Dictionary, key: String, transform: Transform3D) -> void:
	if not batches.has(key):
		batches[key] = []
	batches[key].append(transform)


static func _centre(outline: Array) -> Vector2:
	var total := Vector2.ZERO
	for q in outline:
		total += Vector2(q[0], q[1])
	return total / outline.size()


static func _hash(v: float) -> float:
	return fposmod(sin(v * 12.9898) * 43758.5453, 1.0)
