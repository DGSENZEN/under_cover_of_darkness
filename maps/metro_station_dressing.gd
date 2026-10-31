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
const Layers := preload("res://scripts/Visual/Layers.gd")

const SHELL_KIT := "res://assets/eclipse/kit/station_shell.glb"
const TRACK_KIT := "res://assets/eclipse/kit/station_track.glb"
const WALLS_KIT := "res://assets/eclipse/kit/underground_walls.glb"
const TAQUILLAS_KIT := "res://assets/eclipse/kit/station_taquillas.glb"
const TURNSTILES_KIT := "res://assets/eclipse/kit/station_turnstiles.glb"
const TurnstileLane := preload("res://scripts/Level/TurnstileLane.gd")
const CompanyLamp := preload("res://scripts/Visual/CompanyLamp.gd")
## station_shell's measures (tools/eclipse/station_shell.py): a panel's width, the tiled panels' height, the tiles' face
## off the wall, a floor slab's and a ceiling panel's side, the coping's reach, a coffer's side, a pit face's height, a
## tread's depth and rise and a flight's width, a handrail's run, the line map's width.
const PANEL := 1.2
const TILED := 2.42
const FACE := 0.067
const MODULE := 1.2
const COPING := 0.6
const COFFER := 2.4
const PIT := 1.2
const TREAD := 0.4
const RISE := 0.17
const FLIGHT := 2.4
const RAIL := 1.0
## The track kit's module along x, a guide bar's flare, the drain's piece and its stop (m; station_track.py's).
const TRACK_MODULE := 10.0
const FLARE := 0.4
const DRAIN_LONG := 1.2
const DRAIN_STOP := 0.1
## A cut's rim rail stands this far back from its edge, on the copings (m).
const RIM_BACK := 0.1
const MAP_WIDE := 2.4
## How far the floors' slabs stand over the shell's floor, and the ceilings' panels under its ceiling (m): the shell's
## boxes kept, seen in the joints between them, never in their planes.
const LAID := 0.01
## A door's threshold stands this proud of the floors either side (m); a reveal's lining's thickness (m).
const SILL_PROUD := 0.004
const REVEAL_LINING := 0.05
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
## Its light in Deadlock's key (docs/superpowers/specs/2026-10-31-station-machinery-design.md): the 1969 fittings
## burn warm (the haze's amber), against the Light Company's cold blue lamps, its arcs, and its engine's red leap. The
## fittings: the hall's grid under its coffers, a lamp over each platform's strip every 15 m, three down each
## stairwell; how bright, how far each reaches; the tubes' own glow.
const HAZE := Color("#FFB060")
const COMPANY_BLUE := Color("#5AB4FF")
const ARC_RED := Color("#FF5A3C")
const HALL_LAMPS_X := [-24.0, -12.0, 0.0, 12.0, 24.0]
const HALL_LAMPS_Z := [-7.0, 0.0, 7.0]
const HALL_LAMP := Vector2(1.1, 13.0)
const PLATFORM_LAMPS_X := [-45.0, -30.0, -15.0, 0.0, 15.0, 30.0, 45.0]
const PLATFORM_LAMP := Vector2(1.8, 12.0)
const STAIR_LAMPS := [Vector3(-4.0, 3.5, -27.0), Vector3(-4.0, 3.5, -19.0), Vector3(-4.0, 9.5, -17.0),
	Vector3(4.0, 3.5, 27.0), Vector3(4.0, 3.5, 19.0), Vector3(4.0, 9.5, 17.0)]
const STAIR_LAMP := Vector2(1.2, 9.0)
const TUBE_GLOW := 2.5
## The Company's bracket lamps (the station_lamps kit): on the hall's columns, facing the hall's middle, and on the
## platforms' back walls between the name tablets (x); their mount's height over the floor; the globe's middle from the
## mount (m: out, down: the kit's GLOBE); their energy and reach (CompanyLamp breathes round it).
const LAMPS_KIT := "res://assets/eclipse/kit/station_lamps.glb"
const BRACKETS_X := [-32.0, -16.0, 16.0, 32.0]
const BRACKET_MOUNT := 3.6
## The plaster's face over the tiles: in from a wall's face (the kit's MORTAR), in from a hall column's tiles.
const PLASTER := 0.032
const COLUMN_PLASTER := 0.01
const BRACKET_GLOBE := Vector2(0.62, -0.52)
const BRACKET_LAMP := Vector2(1.6, 8.0)
## The haze over each of the station's spaces: its density (the map's fog is 0.045).
const HAZE_DENSITY := 0.02
## The taquillas (tools/eclipse/station_taquillas.py's measures): each booth's middle along x, its windows' count, the
## wall it stands on (-1 the north, 1 the south); a window's width and the pier between two, the corner post's; how far
## the counter's edge stands out from the wall and its height; the ward lamp's globe out from the wall and up.
const TAQUILLAS := {"east": [20.0, 3, -1.0], "west": [-20.0, 2, 1.0]}
const TAQUILLA_WINDOW := 1.4
const TAQUILLA_PIER := 0.4
const TAQUILLA_POST := 0.36
const TAQUILLA_COUNTER := Vector2(2.32, 1.05)
const TAQUILLA_LAMP := Vector2(2.45, 2.86)
## The turnstile banks (tools/eclipse/station_turnstiles.py's measures): each bank's x and its turn (the kit's paid
## side, +y, toward the hall's middle); its cabinets' middles along the bank and their width; a lane's hub (its height,
## how far out from its cabinet's face) and the arms' axis tipped down into the lane; a lane's room for the Area3D that
## turns them (m: along the walk, its height).
const BANKS := {"west": [-14.0, -PI / 2.0], "east": [14.0, PI / 2.0]}
const BANK_CABINETS := [-3.72, -1.86, 0.0, 1.86, 3.72]
const BANK_CABINET := 0.56
const BANK_HUB := Vector2(0.86, 0.07)
const BANK_TILT := PI / 4.0
const BANK_LANE := Vector2(2.4, 2.0)
## The Company's ward light (KitLoader's ward_cage_lamp), its energy and reach, and its globe's glow.
const WARD := Color("#CFE8F0")
const WARD_LAMP := Vector2(0.6, 4.5)
const WARD_GLOW := 2.0


static func dress(station) -> void:
	if not ResourceLoader.exists(SHELL_KIT):
		return
	var root := Node3D.new()
	root.name = "dressing"
	station.add_child(root)
	station.dressing = root
	var kit := SetKit.kit(SHELL_KIT)
	var look := Painterly.material(SetKit.painted(["station_shell.png", "station_shell_base.png"]), &"bespoke")
	_plainly_lit(look)
	var batches := {}
	_walls(station, batches)
	_floors(station, batches)
	_ceilings(station, batches)
	_columns(station, root, batches)
	_flights(station, batches)
	_cuts(station, batches)
	var revealed := _openings(station, batches)
	_linings(station, batches, revealed)
	_bed(station, batches)
	_mouth_runs(station, batches)
	_signs(station, batches)
	for key: String in batches:
		var kind := key.get_slice("@", 0)
		if kit.has(kind):
			_many(root, key, kind, kit[kind], look, batches[key])
	_track(station, root)
	_tablets(station, root)
	_taquillas(station, root)
	_turnstiles(station, root)
	_light(station, root)
	_company_lamps(station, root)
	_haze(station, root)
	_shell_layers(station)


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
		# (The track steps' walls stand over the platform: the pit's concrete under its floor, its tiles and plaster
		# over it.)
		var platform: float = station.spaces()["platform_n"]["floor"]
		var tiled_from: float = platform if space.begins_with("track_notch") else float(face["floor"])
		var basis := Basis(along3, Vector3.UP, in3)
		for k in count:
			var foot := start + along * (k * PANEL * sx)
			var at := Vector3(foot.x, 0.0, foot.y)
			var y := y0
			if concrete:
				var pit_top := y1 if not space.begins_with("track_notch") else minf(y1, platform)
				if pit_top - y0 > 0.01:
					_rows(batches, "pit_face@" + space, basis, at, sx, y0, pit_top, PIT)
				if pit_top >= y1 - 0.01:
					continue
				y = pit_top
			if y <= tiled_from + 0.01 and y1 - y >= TILED:
				var worn := _hash(foot.x * 1.37 + foot.y * 2.11) > 0.8
				_add(batches, ("wall_low_worn@" if worn else "wall_low@") + space,
					Transform3D(basis * Basis.from_scale(Vector3(sx, 1.0, 1.0)), at + Vector3.UP * y))
				y += TILED
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
				# (The edge the cell meets: its high side on the north platform, its low on the south; coped where the
				# drop lies beyond it, the track's or the track steps' cut.)
				var north := space == "platform_n"
				var at_edge := _over_drop(station, Vector2((lo.x + hi.x) / 2.0, hi.z + 0.05 if north else lo.z - 0.05))
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
		_add(batches, spec[0] + ("@hall" if spec[0] == "column_hall" else "@track"), Transform3D(Basis.IDENTITY, at))
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


## Whether `at` (plan x, z) lies over a drop off a platform: the track's, or a cut for the track steps.
static func _over_drop(station, at: Vector2) -> bool:
	for name: String in ["track", "track_notch_n", "track_notch_s"]:
		var outline := PackedVector2Array()
		for q in station.spaces()[name]["polygon"]:
			outline.append(Vector2(q[0], q[1]))
		if Geometry2D.is_point_in_polygon(at, outline):
			return true
	return false


## The track steps' cuts in the platforms' far ends, guarded where they lie open over their drop: a guard rail along
## the rim on the platform (on its copings, a little back from the edge) and along the parapet between the steps and the
## track, from the head to the steps' foot; the parapet capped with a stone over its top and its faces.
static func _cuts(station, batches: Dictionary) -> void:
	var wall: float = station.WALL
	for notch: String in ["track_notch_n", "track_notch_s"]:
		var sz := -1.0 if notch == "track_notch_n" else 1.0
		var floor_y: float = station.spaces()["platform_n" if sz < 0.0 else "platform_s"]["floor"]
		var xs := []
		for q in station.spaces()[notch]["polygon"]:
			xs.append(float(q[0]))
		var x0: float = xs.min()
		var x1: float = xs.max()
		var rim_z := sz * (float(station.EDGE_Z) + float(station.CUT_DEEP) + RIM_BACK)
		var parapet_z := sz * (float(station.EDGE_Z) + wall / 2.0)
		# (The rim's rail from the head's corner to the end wall's tiles; the parapet's from the head to its end at the
		# steps' foot.)
		var far := 50.0 - wall - FACE - 0.03
		var rim_run := [x0 + 0.05, far] if sz < 0.0 else [-far, x1 - 0.05]
		var foot := x1 - float(station.FOOT) if sz < 0.0 else x0 + float(station.FOOT)
		var parapet_run := [x0 + 0.05, foot - 0.05] if sz < 0.0 else [foot + 0.05, x1 - 0.05]
		for run: Array in [[rim_run, rim_z], [parapet_run, parapet_z]]:
			var a: float = run[0][0]
			var b: float = run[0][1]
			var count := maxi(1, roundi((b - a) / RAIL))
			var sx := (b - a) / (count * RAIL)
			for k in count:
				_add(batches, "guard_rail@cuts", Transform3D(Basis.from_scale(Vector3(sx, 1.0, 1.0)),
					Vector3(a + k * RAIL * sx, floor_y + LAID, run[1])))
			_add(batches, "guard_post@cuts", Transform3D(Basis.IDENTITY, Vector3(b, floor_y + LAID, run[1])))
		# (The cap over the whole parapet, its end's lining too.)
		var c0 := x0 if sz < 0.0 else foot - REVEAL_LINING
		var c1 := foot + REVEAL_LINING if sz < 0.0 else x1
		_add(batches, "parapet_cap@cuts", Transform3D(Basis.from_scale(Vector3(c1 - c0, 1.0, 1.0)),
			Vector3(c0, floor_y + LAID, parapet_z)))


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
		var wide: float = ends[2] if ends.size() > 2 else FLIGHT
		var basis := Basis(Vector3.UP.cross(back), Vector3.UP, back) * Basis.from_scale(Vector3((wide - 0.02) / FLIGHT,
			step / RISE, depth / TREAD))
		for k in count:
			var nose := low + up * (k * depth) + Vector3.UP * ((k + 0.5) * step)
			_add(batches, "tread@flights", Transform3D(basis, nose))
		var across := Vector3.UP.cross(up).normalized()
		var length := (high - low).length()
		var sections := ceili(length / RAIL)
		var slope := (high - low) / sections
		for side in [-1.0, 1.0]:
			var offset: Vector3 = across * side * (wide / 2.0 - 0.05)
			for k in sections:
				var x_axis := slope
				var z_axis := x_axis.cross(Vector3.UP).normalized()
				_add(batches, "handrail@flights", Transform3D(Basis(x_axis, Vector3.UP, z_axis), low + offset + slope * k))
			# (Its last post, at the top, the rail's end over it.)
			var heading := Vector3(up.x, 0.0, up.z).normalized()
			_add(batches, "rail_post@flights", Transform3D(Basis(heading, Vector3.UP, heading.cross(Vector3.UP)),
				high + offset))
	# Each ramp clad under its treads: cement boards along its two sides and its underside, a hair off them.
	for ramp: MeshInstance3D in station.ramp_boxes:
		var size: Vector3 = (ramp.mesh as BoxMesh).size
		var basis: Basis = ramp.transform.basis
		var centre: Vector3 = ramp.transform.origin
		var side := basis.x
		var up := basis.y
		var forward := basis.z
		var sections := maxi(1, roundi(size.z / 1.0))
		var step := forward * (size.z / sections)
		var start := centre - forward * size.z / 2.0
		for k in sections:
			var at := start + step * k
			# (Its two sides, facing out from it, their foot along its underside.)
			for s in [-1.0, 1.0]:
				var out: Vector3 = side * s
				var foot := at + out * (size.x / 2.0 + 0.001) - up * size.y / 2.0
				var x_axis := step if step.cross(up).dot(out) > 0.0 else -step
				var origin := foot if x_axis == step else foot + step
				_add(batches, "lining@ramps", Transform3D(Basis(x_axis, up * size.y, out), origin))
			# (Its underside, facing down.)
			var down := -up
			var corner := at - up * (size.y / 2.0 + 0.001) - side * size.x / 2.0
			var across := side * size.x
			var x_axis := step if step.cross(across).dot(down) > 0.0 else -step
			var origin := corner if x_axis == step else corner + step
			_add(batches, "lining@ramps", Transform3D(Basis(x_axis, across, down), origin))
		ramp.visible = false


## Each door's cement reveal (a door between two of its spaces once), and the tunnels' portals at the track's ends.
static func _openings(station, batches: Dictionary) -> Dictionary:
	var records: Dictionary = station.spaces()
	var done := {}
	var revealed := {}
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
			var basis := Basis(Vector3.UP.cross(in3), Vector3.UP, in3)
			_add(batches, kind + "@doors", Transform3D(basis, Vector3(face.x, float(gap["y0"]), face.y)))
			revealed[key] = true
			# Its threshold: a stone across its floor through the wall's depth, a little proud of the floors either
			# side (never in their plane), its front at this room's face.
			var wide := a.distance_to(b) - 2.0 * REVEAL_LINING
			var start := Vector3(face.x, float(gap["y0"]) + LAID + SILL_PROUD, face.y) - basis.x * wide / 2.0
			_add(batches, "sill@doors", Transform3D(basis * Basis.from_scale(Vector3(wide, 1.0, depth)), start))
	var bed: float = records["track"]["floor"]
	for end in [-1.0, 1.0]:
		var face_x: float = end * (50.0 - station.WALL)
		var toward := Vector3(-end, 0.0, 0.0)
		var basis := Basis(Vector3.UP.cross(toward), Vector3.UP, toward)
		for z: float in station.TRACKS_Z:
			_add(batches, "portal_mouth@portals", Transform3D(basis, Vector3(face_x, bed, z)))
		_add(batches, "portal_tunnel@portals", Transform3D(basis, Vector3(face_x, bed, 0.0)))
	return revealed


## Every bare end of wall and underside of a lintel no reveal covers (the notch's, the track's mouths' and tunnels',
## the corners whose wall is open): cement linings, in rows a metre tall (or along), each fitted to its run.
static func _linings(station, batches: Dictionary, revealed: Dictionary) -> void:
	var wall: float = station.WALL
	for end: Dictionary in station.ends:
		if revealed.has(end["key"]):
			continue
		var inward: Vector2 = end["inward"]
		var out: Vector2 = end["out"]
		var in3 := Vector3(inward.x, 0.0, inward.y)
		var out3 := Vector3(out.x, 0.0, out.y)
		var at: Vector2 = end["at"]
		var foot := Vector3(at.x, 0.0, at.y)
		# (Its board across the wall's depth, facing the way the end faces.)
		var x_axis := in3 if in3.cross(Vector3.UP).dot(out3) > 0.0 else -in3
		var origin := foot if x_axis == in3 else foot + in3 * wall
		var y0: float = end["y0"]
		var y1: float = end["y1"]
		var rows := maxi(1, roundi(y1 - y0))
		var tall := (y1 - y0) / rows
		for r in rows:
			_add(batches, "lining@" + String(end["space"]), Transform3D(Basis(x_axis * wall, Vector3.UP * tall, out3),
				origin + Vector3.UP * (y0 + r * tall)))
	for head: Dictionary in station.heads:
		if revealed.has(head["key"]):
			continue
		var a: Vector2 = head["from"]
		var b: Vector2 = head["to"]
		var inward: Vector2 = head["inward"]
		var in3 := Vector3(inward.x, 0.0, inward.y)
		var along := Vector3(b.x - a.x, 0.0, b.y - a.y)
		var count := maxi(1, roundi(along.length()))
		var piece := along / count
		var y: float = head["y"]
		for k in count:
			var at := Vector3(a.x, y, a.y) + piece * k
			# (Facing down: along it, across the wall's depth.)
			var y_axis := in3 * wall if piece.cross(in3).dot(Vector3.DOWN) > 0.0 else -in3 * wall
			var origin := at if y_axis.dot(in3) > 0.0 else at + in3 * wall
			_add(batches, "lining@" + String(head["space"]), Transform3D(Basis(piece, y_axis, Vector3.DOWN), origin))


## The track's bed and its notches': concrete slabs, fitted, laid LAID over the shell's bed.
static func _bed(station, batches: Dictionary) -> void:
	for space: String in ["track", "track_notch_n", "track_notch_s"]:
		for box: MeshInstance3D in station._floor_boxes.get(space, []):
			# (The drain's trench: the track's kit lays the drain in it.)
			if box.has_meta("trench"):
				continue
			var size: Vector3 = (box.mesh as BoxMesh).size
			var lo := box.position - size / 2.0
			var hi := box.position + size / 2.0
			var nx := maxi(1, roundi((hi.x - lo.x) / MODULE))
			var nz := maxi(1, roundi((hi.z - lo.z) / MODULE))
			var sx := (hi.x - lo.x) / (nx * MODULE)
			var sz := (hi.z - lo.z) / (nz * MODULE)
			for i in nx:
				for j in nz:
					_add(batches, "bed_slab@" + space, Transform3D(Basis.from_scale(Vector3(sx, 1.0, sz)),
						Vector3(lo.x + (i + 0.5) * MODULE * sx, hi.y + LAID, lo.z + (j + 0.5) * MODULE * sz)))


## The track laid for the MP-68 (the station_track kit, its own atlas) over the set's solid stand-ins, which it hides:
## each track's modules from one mouth's cap to the other; its guide bars either side, bolted to the pit's face and the
## mouths' walls on the outside and to the kerb under its guard board between the tracks, each run ending in a flare at
## the crossing where the track steps come down; the drain along the trench down the middle, stopped at its ends.
static func _track(station, root: Node3D) -> void:
	if not ResourceLoader.exists(TRACK_KIT):
		return
	var kit := SetKit.kit(TRACK_KIT)
	var look := Painterly.material(SetKit.painted(["station_track.png", "station_track_base.png"]), &"bespoke")
	_plainly_lit(look)
	var batches := {}
	var reach: float = 50.0 + float(station.DARK_RUN)
	for z: float in station.TRACKS_Z:
		var count := roundi(2.0 * reach / TRACK_MODULE)
		var sx := 2.0 * reach / (count * TRACK_MODULE)
		for k in count:
			_add(batches, "track_bed@track", Transform3D(Basis.from_scale(Vector3(sx, 1.0, 1.0)),
				Vector3(-reach + k * TRACK_MODULE * sx, float(station.PAD_TOP), z)))
		# (The crossing: the north track's at its east end, the south's at its west, where their steps come down; the
		# flare on the station's side of it reaching out into it, the mouth's inside the mouth.)
		var east := z < 0.0
		var c0: float = 50.0 - float(station.FOOT) if east else -50.0
		var c1: float = 50.0 if east else -50.0 + float(station.FOOT)
		var runs := [[-reach, c0 + (FLARE if east else 0.0)], [c1 - (0.0 if east else FLARE), reach]]
		for out in [signf(z), -signf(z)]:
			var face: float = z + out * float(station.GUIDE_FACE)
			_guide(batches, "guide_bar", runs[0][0], runs[0][1], station.PAD_TOP, face, out, false, true)
			_guide(batches, "guide_bar", runs[1][0], runs[1][1], station.PAD_TOP, face, out, true, false)
		# (The kerb under its guard board, between the tracks, along the set's.)
		var kerb: MeshInstance3D = station.kerbs[station.TRACKS_Z.find(z)]
		var size: Vector3 = (kerb.mesh as BoxMesh).size
		_guide(batches, "guide_kerb", kerb.position.x - size.x / 2.0, kerb.position.x + size.x / 2.0, station.PAD_TOP,
			z - signf(z) * float(station.GUIDE_FACE), -signf(z), false, false)
	for box: MeshInstance3D in station._floor_boxes.get("track", []):
		if not box.has_meta("trench"):
			continue
		var size: Vector3 = (box.mesh as BoxMesh).size
		var x0 := box.position.x - size.x / 2.0
		var x1 := box.position.x + size.x / 2.0
		var top: float = station.spaces()["track"]["floor"] + LAID
		_add(batches, "drain_end@track", Transform3D(Basis.IDENTITY, Vector3(x0, top, 0.0)))
		_add(batches, "drain_end@track", Transform3D(Basis(Vector3.UP, PI), Vector3(x1, top, 0.0)))
		var run := x1 - x0 - 2.0 * DRAIN_STOP
		var pieces := maxi(1, roundi(run / DRAIN_LONG))
		var sx := run / (pieces * DRAIN_LONG)
		for k in pieces:
			_add(batches, "drain@track", Transform3D(Basis.from_scale(Vector3(sx, 1.0, 1.0)),
				Vector3(x0 + DRAIN_STOP + k * DRAIN_LONG * sx, top, 0.0)))
	for key: String in batches:
		var kind := key.get_slice("@", 0)
		if kit.has(kind):
			_many(root, key, kind, kit[kind], look, batches[key])
	for box: MeshInstance3D in station.pads + station.kerbs:
		box.visible = false


## A run of `kind` (the guide bar's metre, or the kerb's) along x from `a` to `b` over the pads' tops at `y`, its face at
## `face` (z), turned to stand
## out from the car toward `out` (the kit's +y is Godot's -z: as laid, toward -z); a guide bar's run ending in a flare at
## its low end, its high end, or neither.
static func _guide(batches: Dictionary, kind: String, a: float, b: float, y: float, face: float, out: float,
		flare_lo: bool, flare_hi: bool) -> void:
	var turned := out > 0.0
	var basis := Basis(Vector3.UP, PI) if turned else Basis.IDENTITY
	var from := a + (FLARE if flare_lo else 0.0)
	var to := b - (FLARE if flare_hi else 0.0)
	var count := maxi(1, roundi((to - from) / 1.0))
	var sx := (to - from) / count
	for k in count:
		# (Turned, a piece runs back along -x from its origin: its origin at its high end.)
		var x := from + k * sx + (sx if turned else 0.0)
		_add(batches, kind + "@track", Transform3D(basis * Basis.from_scale(Vector3(sx, 1.0, 1.0)), Vector3(x, y, face)))
	# (The flares: guide_flare turns away at its +x end, guide_flare_l at its origin.)
	if flare_hi:
		_add(batches, ("guide_flare_l" if turned else "guide_flare") + "@track",
			Transform3D(basis, Vector3(b if turned else b - FLARE, y, face)))
	if flare_lo:
		_add(batches, ("guide_flare" if turned else "guide_flare_l") + "@track",
			Transform3D(basis, Vector3(a + FLARE if turned else a, y, face)))


## Each track's mouth's run into the dark: concrete on its two sides and under its roof, slabs on its bed, to its cap.
static func _mouth_runs(station, batches: Dictionary) -> void:
	for run: Array in station.mouth_runs:
		var x0: float = run[0]
		var x1: float = run[1]
		var z: float = run[2]
		var bed: float = run[3]
		var roof: float = run[4]
		var half: float = station.MOUTH.x / 2.0
		var count := maxi(1, roundi((x1 - x0) / PANEL))
		var sx := (x1 - x0) / (count * PANEL)
		for k in count:
			var x := x0 + k * PANEL * sx
			for s in [-1.0, 1.0]:
				var inward := Vector3(0.0, 0.0, -s)
				var along := Vector3.UP.cross(inward)
				var foot := Vector3(x if along.x > 0.0 else x + PANEL * sx, 0.0, z + s * half)
				var basis := Basis(along, Vector3.UP, inward)
				_rows(batches, "pit_face@mouths", basis, foot, sx, bed, roof, PIT)
			for j in 3:
				var wide := 2.0 * half / 3.0
				_add(batches, "bed_slab@mouths", Transform3D(Basis.from_scale(Vector3(sx * PANEL / MODULE, 1.0,
					wide / MODULE)), Vector3(x + PANEL * sx / 2.0, bed + LAID, z - half + (j + 0.5) * wide)))
			_add(batches, "lining@mouths", Transform3D(Basis(Vector3.RIGHT * PANEL * sx, Vector3.BACK * 2.0 * half,
				Vector3.DOWN), Vector3(x, roof - 0.001, z - half)))


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
	_plainly_lit(look)
	var transforms: Array = []
	for side in [-1.0, 1.0]:
		var inward := Vector3(0.0, 0.0, -side)
		var along := Vector3.UP.cross(inward)
		var face_z: float = side * (14.0 - station.WALL) + inward.z * FACE
		for x: float in TABLETS_X:
			var start := Vector3(x, TABLET_FOOT, face_z) - along * 0.5
			transforms.append(Transform3D(Basis(along, Vector3.UP, inward), start))
	_many(root, "name_tablet@platform_n", "name_tablet", walls["name_tablet"], look, transforms)


## The Company's taquillas, where it sells the rides through brass bars: the east booth's three windows on the north
## wall on the unpaid side of the east bank, the west booth's two on the south wall; each solid (its own faces), on the
## hall's layer, a ward lamp over each window lit in the Company's cold light.
static func _taquillas(station, root: Node3D) -> void:
	if not ResourceLoader.exists(TAQUILLAS_KIT):
		return
	var kit := SetKit.kit(TAQUILLAS_KIT)
	var look := Painterly.material(SetKit.painted(["station_taquillas.png", "station_taquillas_base.png"]), &"bespoke")
	_plainly_lit(look)
	var globe := _ward_globe()
	var hall_floor: float = station.spaces()["hall"]["floor"]
	var tiles: float = 14.0 - float(station.WALL) - FACE
	for side: String in TAQUILLAS:
		var spec: Array = TAQUILLAS[side]
		var wall: float = spec[2]
		var kind := "taquilla_" + side
		if not kit.has(kind):
			continue
		# (The kit faces +z; on the south wall it is turned to face north.)
		var yaw := 0.0 if wall < 0.0 else PI
		var booth := SetKit.place(root, kit[kind], look, kind, Vector3(spec[0], hall_floor, wall * tiles), yaw, true,
			true)
		booth.layers = Layers.STATION_HALL
		for i in booth.mesh.get_surface_count():
			var slot: Material = booth.mesh.surface_get_material(i)
			if slot != null and slot.resource_name.begins_with("glass"):
				booth.set_surface_override_material(i, globe)
		var facing := Vector3(0.0, 0.0, -wall)
		var count: int = spec[1]
		var length := count * TAQUILLA_WINDOW + (count - 1) * TAQUILLA_PIER + 2.0 * TAQUILLA_POST
		var windows: Array[Vector3] = []
		for k in count:
			var along := -length / 2.0 + TAQUILLA_POST + TAQUILLA_WINDOW / 2.0 + k * (TAQUILLA_WINDOW + TAQUILLA_PIER)
			var x: float = spec[0] + along * (1.0 if wall < 0.0 else -1.0)
			windows.append(Vector3(x, hall_floor + TAQUILLA_COUNTER.y, wall * tiles + facing.z * TAQUILLA_COUNTER.x))
			var lamp := OmniLight3D.new()
			lamp.name = "ward_lamp"
			lamp.light_color = WARD
			lamp.light_energy = WARD_LAMP.x
			lamp.omni_range = WARD_LAMP.y
			lamp.shadow_enabled = false
			lamp.light_cull_mask = Layers.STATION_HALL | Layers.WORLD | Layers.ACTORS | Layers.VIEWMODEL | Layers.FX \
				| Layers.GEM_PROBE
			root.add_child(lamp, true)
			lamp.position = Vector3(x, hall_floor + TAQUILLA_LAMP.y, wall * tiles + facing.z * TAQUILLA_LAMP.x)
			station.lights.append(lamp)
		booth.set_meta("side", side)
		booth.set_meta("footprint", _footprint(station, booth))
		booth.set_meta("windows", windows)
		booth.set_meta("facing", facing)
		station.taquillas.append(booth)


## The turnstile banks across the hall: each bank solid (its own faces), its working lanes' arms on pivots that turn
## as anyone walks through; the west's north half fused (no arms that turn: its melted arms are the bank's own).
static func _turnstiles(station, root: Node3D) -> void:
	if not ResourceLoader.exists(TURNSTILES_KIT):
		return
	var kit := SetKit.kit(TURNSTILES_KIT)
	var look := Painterly.material(SetKit.painted(["station_turnstiles.png", "station_turnstiles_base.png"]),
		&"bespoke")
	_plainly_lit(look)
	var hall_floor: float = station.spaces()["hall"]["floor"]
	for side: String in BANKS:
		var kind := "bank_" + side
		if not kit.has(kind):
			continue
		var x: float = BANKS[side][0]
		var yaw: float = BANKS[side][1]
		var turn := Basis(Vector3.UP, yaw)
		var at := Vector3(x, hall_floor, 0.0)
		var bank := SetKit.place(root, kit[kind], look, kind, at, yaw, true, true)
		bank.layers = Layers.STATION_HALL
		# (The kit's frame, Blender's x along the bank, y the walk, z up: Godot's (x, z, -y) turned to its place.)
		var kit_to_set := func(p: Vector3) -> Vector3: return at + turn * Vector3(p.x, p.z, -p.y)
		var axis: Vector3 = turn * Vector3(cos(BANK_TILT), -sin(BANK_TILT), 0.0)
		var walk: Vector3 = turn * Vector3(0.0, 0.0, -1.0)
		var lanes: Array[Vector3] = []
		var arms: Array = []
		for k in BANK_CABINETS.size() - 1:
			var middle: Vector3 = kit_to_set.call(Vector3((BANK_CABINETS[k] + BANK_CABINETS[k + 1]) / 2.0, 0.0, 0.0))
			lanes.append(middle)
			if side == "west" and middle.z < 0.0 or not kit.has("rotor"):
				arms.append(null)
				continue
			var hub: Vector3 = kit_to_set.call(Vector3(BANK_CABINETS[k] + BANK_CABINET / 2.0 + BANK_HUB.y, 0.0,
				BANK_HUB.x))
			var pivot := Node3D.new()
			pivot.name = "arms"
			pivot.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
			root.add_child(pivot, true)
			pivot.position = hub
			var rotor := SetKit.place(pivot, kit["rotor"], look, "rotor", Vector3.ZERO, yaw, false)
			rotor.layers = Layers.STATION_HALL
			rotor.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
			var lane := TurnstileLane.new()
			lane.name = "lane"
			lane.arms = pivot
			lane.axis = axis
			lane.walk = walk
			var shape := CollisionShape3D.new()
			var room := BoxShape3D.new()
			room.size = Vector3(BANK_LANE.x, BANK_LANE.y, BANK_CABINETS[1] - BANK_CABINETS[0] - BANK_CABINET)
			shape.shape = room
			lane.add_child(shape)
			root.add_child(lane, true)
			lane.position = middle + Vector3(0.0, BANK_LANE.y / 2.0, 0.0)
			arms.append(pivot)
		bank.set_meta("side", side)
		bank.set_meta("footprint", _footprint(station, bank))
		bank.set_meta("lanes", lanes)
		bank.set_meta("arms", arms)
		station.turnstiles.append(bank)


## A piece's footprint (its mesh's box seen from above, in the set's x-z), for the crowd's routes.
static func _footprint(station, piece: MeshInstance3D) -> Rect2:
	var box: AABB = station.global_transform.affine_inverse() * piece.global_transform * piece.mesh.get_aabb()
	return Rect2(box.position.x, box.position.z, box.size.x, box.size.z)


## A ward lamp's globe: the Company's cold light through its glass.
static func _ward_globe() -> StandardMaterial3D:
	var glow := StandardMaterial3D.new()
	glow.albedo_color = WARD
	glow.emission_enabled = true
	glow.emission = WARD
	glow.emission_energy_multiplier = WARD_GLOW
	glow.roughness = 0.3
	return glow


static func _many(root: Node3D, key: String, kind: String, mesh: Mesh, look: Material, transforms: Array) -> void:
	var dressed := mesh.duplicate() as Mesh
	for i in dressed.get_surface_count():
		var slot: Material = mesh.surface_get_material(i)
		var glazed := slot != null and slot.resource_name.begins_with("glass")
		var lit := glazed and kind in ["strip_fitting", "coffer"]
		(dressed as ArrayMesh).surface_set_material(i, _tube() if lit else (SetKit.glass() if glazed else look))
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
	# (On its level's layer alone: lit only by its own level's lights.)
	node.layers = level_of(key.get_slice("@", 1))
	# (Its instances' transforms kept with it: a headless run's renderer keeps none.)
	node.set_meta("transforms", transforms)
	root.add_child(node)


## The layer of a group of dressing (its space, or what it serves): the hall, its stairwells, or the level below them;
## a door its both sides.
static func level_of(group: String) -> int:
	if group == "hall":
		return Layers.STATION_HALL
	if group.begins_with("stairs") or group in ["flights", "ramps"]:
		return Layers.STATION_STAIRS
	if group == "doors":
		return Layers.STATION_HALL | Layers.STATION_STAIRS | Layers.STATION_BELOW
	return Layers.STATION_BELOW


## The station's light: each lamp lighting its own level's layer and the world's movers (the player, actors, hands,
## effects, the lightgem's probe), never another level's: the hall's slab between it and the platforms stops nothing a
## shadowless light sends.
static func _light(station, root: Node3D) -> void:
	var movers := Layers.WORLD | Layers.ACTORS | Layers.VIEWMODEL | Layers.FX | Layers.GEM_PROBE
	var hall_top: float = float(station.spaces()["hall"]["floor"]) + float(station.spaces()["hall"]["height"])
	var places := []
	for x: float in HALL_LAMPS_X:
		for z: float in HALL_LAMPS_Z:
			places.append([Vector3(x, hall_top - 0.8, z), HALL_LAMP, Layers.STATION_HALL])
	var platform_top: float = float(station.spaces()["platform_n"]["floor"]) + float(station.spaces()["platform_n"]["height"])
	for side in [-1.0, 1.0]:
		for x: float in PLATFORM_LAMPS_X:
			places.append([Vector3(x, platform_top - 0.6, side * (float(station.EDGE_Z) + STRIP_IN)), PLATFORM_LAMP,
				Layers.STATION_BELOW])
	for at: Vector3 in STAIR_LAMPS:
		places.append([at, STAIR_LAMP, Layers.STATION_STAIRS])
	for spec: Array in places:
		var lamp := OmniLight3D.new()
		lamp.name = "fluorescent"
		lamp.light_color = HAZE
		lamp.light_energy = (spec[1] as Vector2).x
		lamp.omni_range = (spec[1] as Vector2).y
		lamp.shadow_enabled = false
		lamp.light_cull_mask = int(spec[2]) | movers
		root.add_child(lamp, true)
		lamp.position = spec[0]
		station.lights.append(lamp)


## The Light Company's blue lamps on brackets: on the hall's columns, each facing the hall's middle, and on the
## platforms' back walls; a light at each globe, on its level's layer.
static func _company_lamps(station, root: Node3D) -> void:
	if not ResourceLoader.exists(LAMPS_KIT):
		return
	var kit := SetKit.kit(LAMPS_KIT)
	if not kit.has("ward_bracket"):
		return
	var look := Painterly.material(SetKit.painted(["station_lamps.png", "station_lamps_base.png"]), &"bespoke")
	_plainly_lit(look)
	var movers := Layers.WORLD | Layers.ACTORS | Layers.VIEWMODEL | Layers.FX | Layers.GEM_PROBE
	var hall_floor: float = station.spaces()["hall"]["floor"]
	var platform_floor: float = station.spaces()["platform_n"]["floor"]
	var back := 14.0 - float(station.WALL) - PLASTER
	var places := []
	for at: Vector2 in HALL_COLUMNS:
		# (On the column's face toward the hall's middle.)
		var facing := -signf(at.y)
		places.append([Vector3(at.x, hall_floor + BRACKET_MOUNT, at.y + facing * (COLUMN_HALL.x / 2.0 - COLUMN_PLASTER)),
			facing,
			Layers.STATION_HALL])
	for side in [-1.0, 1.0]:
		for x: float in BRACKETS_X:
			places.append([Vector3(x, platform_floor + BRACKET_MOUNT, side * back), -side, Layers.STATION_BELOW])
	for k in places.size():
		var spec: Array = places[k]
		var facing: float = spec[1]
		var yaw := 0.0 if facing > 0.0 else PI
		var bracket := SetKit.place(root, kit["ward_bracket"], look, "ward_bracket", spec[0], yaw, false)
		bracket.layers = int(spec[2])
		# (Its breath: its light, the ward glass behind its panes, its halo, its pocket of haze.)
		var lamp := CompanyLamp.new()
		lamp.name = "company_lamp"
		lamp.colour = COMPANY_BLUE
		lamp.energy = BRACKET_LAMP.x
		lamp.reach = BRACKET_LAMP.y
		lamp.seed = k + 1
		lamp.mask = int(spec[2]) | movers
		lamp.layer = int(spec[2])
		root.add_child(lamp, true)
		lamp.position = (spec[0] as Vector3) + Vector3(0.0, BRACKET_GLOBE.y, facing * BRACKET_GLOBE.x)
		for i in bracket.mesh.get_surface_count():
			var slot: Material = bracket.mesh.surface_get_material(i)
			if slot != null and slot.resource_name.begins_with("glass"):
				bracket.set_surface_override_material(i, lamp.glass)
		station.lights.append(lamp.light)
		station.company_lamps.append(lamp)


## A warm haze over each of the station's spaces (its own fog, the map's elsewhere).
static func _haze(station, root: Node3D) -> void:
	for space: String in ["hall", "stairs_n", "stairs_s", "platform_n", "platform_s", "track"]:
		var record: Dictionary = station.spaces()[space]
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for q in record["polygon"]:
			lo = Vector2(minf(lo.x, q[0]), minf(lo.y, q[1]))
			hi = Vector2(maxf(hi.x, q[0]), maxf(hi.y, q[1]))
		var fog := FogVolume.new()
		fog.name = "haze_" + space
		fog.size = Vector3(hi.x - lo.x, float(record["height"]), hi.y - lo.y)
		var material := FogMaterial.new()
		material.albedo = HAZE
		material.density = HAZE_DENSITY
		material.edge_fade = 0.2
		fog.material = material
		root.add_child(fog, true)
		fog.position = Vector3((lo.x + hi.x) / 2.0, float(record["floor"]) + float(record["height"]) / 2.0,
			(lo.y + hi.y) / 2.0)


## The shell's own boxes still seen (its floors and ceilings in the joints, the mouths' runs) on their levels' layers.
static func _shell_layers(station) -> void:
	for space: String in station._floor_boxes:
		for box: MeshInstance3D in station._floor_boxes[space] + station._ceiling_boxes[space]:
			box.layers = level_of(space)
	for box: MeshInstance3D in station.shell:
		if box.layers == Layers.WORLD:
			box.layers = Layers.STATION_BELOW if box.name.begins_with("mouth") or box.name.begins_with("track") \
				else level_of(String(box.name).get_slice("_wall", 0))


## Lit plainly by the station's own light: the painted light's broken bands off (on its tall plain walls they threw
## dark camouflage blotches; the look pass after the Metro sets the house's painted treatment for every kit).
static func _plainly_lit(look: ShaderMaterial) -> void:
	look.set_shader_parameter("painted_light", 0.0)
	look.set_shader_parameter("ramp_amount", 0.0)


## The fluorescent tubes' glow.
static func _tube() -> StandardMaterial3D:
	var glow := StandardMaterial3D.new()
	glow.albedo_color = HAZE
	glow.emission_enabled = true
	glow.emission = HAZE
	glow.emission_energy_multiplier = TUBE_GLOW
	glow.roughness = 0.3
	return glow


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
