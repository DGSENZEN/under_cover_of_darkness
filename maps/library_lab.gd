extends Node3D
## The rare-book librarian's shop's look-dev bay (docs/superpowers/specs/2026-10-17-librarian-shop-design.md;
## docs/superpowers/plans/2026-10-17-librarian-shop-part-1.md): his vaulted room off a strip of the Metro
## corridor, painted in the bespoke blend. The player starts in the corridor, looking in through the arch.
##   F1  work lights on / off
##   F2  form light: everything neutral grey under one white light, to judge shape
##   F3  decals (his chalk ward and its salt) on / off

const PLAYER := preload("res://Player.tscn")
const Painterly := preload("res://scripts/Visual/Painterly.gd")
const RetroScript := preload("res://scripts/Visual/Retro.gd")

## The room's kit (tools/eclipse/library_room.py), set at the origin: the shopfront's corridor face at
## z = FRONT_T, the room from z = 0 back to -DEPTH.
const ROOM_KIT := "res://assets/eclipse/kit/library_room.glb"
const DEPTH := 6.0
const WIDTH := 8.0
const FRONT_T := 0.4
## The arch's opening and the fascia's span (the corridor's tiles stop at the bookseller's front).
const FRONT_W := 3.0
const FRONT_REACH := 2.4
## The corridor outside: how far either way, and its far wall's tile face; its ceiling.
const RUN := 6.0
const FAR_WALL := 3.7
const CEILING := 4.0
const FLOOR_KIT := "res://assets/eclipse/kit/underground_floor.glb"
const WALL_KIT := "res://assets/eclipse/kit/underground_walls.glb"
const MODULE := 1.2
const EDGE_DEPTH := 0.9
const WALL_FACE := 0.067
## Where the player starts: in the corridor before the arch, facing in.
const SPAWN := Vector3(0.0, 1.05, 2.2)
const SODIUM := Color(1.0, 0.76, 0.5)
## His corner (tools/eclipse/library_corner.py), its frame's origin at the desk's middle on the floor, its
## front toward the shopfront; and where its lamp's bulb is (the kit's wicks, in the corner's frame).
const CORNER_KIT := "res://assets/eclipse/kit/library_corner.glb"
const CORNER_WICKS := "res://assets/eclipse/source/library_corner_wicks.json"
const CORNER_AT := Vector3(0.0, 0.0, -4.4)
## What of his corner is solid to the player.
const CORNER_SOLID := ["desk", "desk_chair", "coat_hook", "chained_book_rest", "quarantine_cage", "hunt_rack"]
## His chalk ward round the desk (its outer ring's radius, as the decal draws it at 0.91 of its half-width) and the
## salt across its open side toward the customers.
const WARD_RADIUS := 1.18
const SALT_SIZE := Vector3(1.3, 0.2, 0.9)
## His lamp: warm, low, under its green shade (where it stands when the corner's kit is missing).
const LAMP_AT := Vector3(-0.32, 1.39, -4.44)
const LAMP_COLOUR := Color(1.0, 0.78, 0.5)
## His shelves (tools/eclipse/library_shelves.py): each case's frame its front's middle on the floor, its front
## toward +z, its back DEPTH behind; where each stands (its origin, turned how far), the room's skirting allowed for.
const SHELF_KIT := "res://assets/eclipse/kit/library_shelves.glb"
const SHELF_BOARDS := "res://assets/eclipse/source/library_shelves_boards.json"
const SHELF_DEPTH := 0.42
const SKIRT_PROUD := 0.035
const WALL_IN := 4.0 - SKIRT_PROUD - SHELF_DEPTH
const BACK_IN := -6.0 + SKIRT_PROUD + SHELF_DEPTH
const SHELVES := {
	"chronology": [Vector3(-WALL_IN, 0.0, -1.7), 90.0], "necromancy": [Vector3(-WALL_IN, 0.0, -4.8), 90.0],
	"alchemy": [Vector3(WALL_IN, 0.0, -1.7), -90.0], "metaphysics": [Vector3(WALL_IN, 0.0, -4.3), -90.0],
	"hunting": [Vector3(2.65, 0.0, BACK_IN), 0.0]}
## The low cases either side of the runner, along the room: 1.4 m long, set back from the front wall and short of
## his desk so a body (the player's is a metre wide) crosses in front of them and behind them into the aisles.
const LOW_CASES := [Vector3(-1.15, 0.0, -2.0), Vector3(1.15, 0.0, -2.0)]
## The side aisles' middles (x), between the low cases and the wall cases.
const AISLE_X := 2.45

## His books (tools/eclipse/library_books.py): how far each case's boards are apart (a board's thickness, the
## underside of a case's top, of a low case's); the live book's hinge (the kit's, Blender axes) and how high it lies
## above what it lies on.
const BOOK_KIT := "res://assets/eclipse/kit/library_books.glb"
const BOOK_KINDS := 12
const BOOK_STACKS := 3
const BOARD_T := 0.035
const CASE_LID := 2.62
const LOW_LID := 1.33
const LIVE_HINGE := Vector3(-0.012, 0.0, 0.03)
const LIVE_LIFT := 0.002
## The live books. The studies lie open-able on a board of their section's case (which board, the hinge's x along
## it), a run either side kept clear of books for them to open into; the novels on the table by his door (scaled
## down: cheap octavos beside his folios) and one on the right low case; the spellbooks on lecterns, one in the
## front corner left of the arch, one in the right wall's gap between alchemy and metaphysics, each facing the floor.
## (All of them clear of the ways across the shop's front and into the aisles.)
const STUDIES := [["chronology", 2, -0.45], ["necromancy", 3, -0.57], ["necromancy", 2, 0.3], ["alchemy", 3, 0.2],
	["alchemy", 2, -0.45], ["metaphysics", 2, -0.2], ["hunting", 3, 0.35]]
const STUDY_KEEP := 0.285
const FRONT_TABLE_AT := Vector3(2.9, 0.0, -0.3)
const TABLE_TOP := 0.85
const NOVEL_SCALE := 0.8
const NOVELS := [Vector3(2.68, TABLE_TOP, -0.3), Vector3(3.12, TABLE_TOP, -0.3), Vector3(1.15, 1.4, -1.6)]
## Each lectern: where it stands, turned how far (degrees; its desk faces its own +z).
const LECTERNS := [[Vector3(-2.8, 0.0, -0.35), 180.0], [Vector3(3.7, 0.0, -3.0), -90.0]]
## The lectern's desk: its top's middle (Godot, the lectern's frame) and its slope toward the reader (+z).
const LECTERN_DESK := Vector3(0.0, 1.0791, 0.0051)
const LECTERN_SLOPE := 20.0

## The lamp's shade: emerald glass, lit through from inside.
const SHADE_GREEN := Color(0.12, 0.42, 0.22, 0.8)

var atlas_dir := "res://textures/painted/underground/"
var missing := PackedStringArray()
var player: Node3D
var world: WorldEnvironment
## The room's pieces by name, and his corner's.
var room := {}
var corner := {}
## The book he is working on, chained and straining; the books in the cage, stirring.
var chained: ChainedBook
var quarantine: Quarantine
var decals: Array[Decal] = []
## His sections' cases by name; every piece of shelving.
var sections := {}
var shelves: Array[MeshInstance3D] = []
var corridor: Array[MeshInstance3D] = []
## Every board's spot the books fill (BookFiller's), the books placed, their draws; the live books; the front table
## and lecterns.
var book_spots: Array = []
var book_layout: Array = []
var book_draws: Array[MultiMeshInstance3D] = []
var live_books: Array[LiveBook] = []
var book_stands: Array[MeshInstance3D] = []
var lamp_light: OmniLight3D
var work_lights: Array[Light3D] = []
var form_light: DirectionalLight3D
var form_material: StandardMaterial3D
var keys_label: Label
var _form := false


func _ready() -> void:
	reset_physics_interpolation.call_deferred()
	_environment()
	_room()
	_corner()
	_shelves()
	_books()
	_corridor()
	_lights()
	_keys()
	player = PLAYER.instantiate()
	player.debug_traversal = false
	add_child(player)
	player.global_position = SPAWN


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	match event.keycode:
		KEY_F1:
			set_work_lights(not work_lights[0].visible)
		KEY_F2:
			set_form(not _form)
		KEY_F3:
			set_decals(decals.is_empty() or not decals[0].visible)


func set_work_lights(on: bool) -> void:
	for light in work_lights:
		light.visible = on

	_name_keys()


## The form light: every mesh of the bay a neutral grey under one white light, the work lights and his lamp
## off; or everything as it was. (Effects keep their own look: they cast no shadow and draw with a shader.)
func set_form(on: bool) -> void:
	_form = on

	for mesh: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		if is_instance_valid(player) and player.is_ancestor_of(mesh):
			continue

		if mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and mesh.mesh != null \
				and (mesh.get_surface_override_material(0) is ShaderMaterial or mesh.mesh.surface_get_material(0) is ShaderMaterial):
			continue

		mesh.material_override = form_material if on else null

	# (The shelves' books keep their look on their draw.)
	for draw: MultiMeshInstance3D in book_draws:
		draw.material_override = form_material if on else draw.get_meta("look")

	form_light.visible = on
	lamp_light.visible = not on
	set_work_lights(not on)


# The room

func _room() -> void:
	if not ResourceLoader.exists(ROOM_KIT):
		missing.append(ROOM_KIT)
		return

	var meshes := _kit(ROOM_KIT)
	var look := Painterly.material(_painted(["library_room.png", "library_room_base.png"]), &"bespoke")

	for part in ["room_vault", "room_back", "room_front", "room_floor", "room_rug"]:
		if not meshes.has(part):
			missing.append("%s in %s" % [part, ROOM_KIT])
			continue
		# (The room's walls are walked against: solid to the shape, not its hull. Its floor is walked on flat at its
		# boards' tops, one box: hundreds of boards hairline apart cost the player's every step.)
		room[part] = _place(meshes[part], look, part, Vector3.ZERO, 0.0, part not in ["room_rug", "room_floor"], true)

	if room.has("room_floor"):
		var floor_body := StaticBody3D.new()
		floor_body.name = "floor_solid"
		for span: AABB in [AABB(Vector3(-WIDTH / 2.0, -0.2, -DEPTH), Vector3(WIDTH, 0.2, DEPTH)),
				AABB(Vector3(-FRONT_W / 2.0, -0.2, 0.0), Vector3(FRONT_W, 0.2, FRONT_T))]:
			var shape := CollisionShape3D.new()
			var solid := BoxShape3D.new()
			solid.size = span.size
			shape.shape = solid
			shape.position = span.get_center()
			floor_body.add_child(shape)
		room["room_floor"].add_child(floor_body)


# His corner

## His corner: the dealer's desk and its things (the rite, the hunt and the work in progress join it).
func _corner() -> void:
	if not ResourceLoader.exists(CORNER_KIT):
		missing.append(CORNER_KIT)
		return

	var meshes := _kit(CORNER_KIT)
	var look := Painterly.material(_painted(["library_corner.png", "library_corner_base.png"]), &"bespoke")

	for part: String in meshes:
		corner[part] = _place(meshes[part], look, part, CORNER_AT, 0.0, part in CORNER_SOLID)

	# The chained book: its cover lifts on the hinge along its spine (the kit's wicks).
	if corner.has("chained_book_cover"):
		chained = ChainedBook.new()
		chained.name = "chained_book"
		chained.cover = corner["chained_book_cover"]
		chained.block = corner.get("chained_book_block")
		var hinge := _wicks("chained_book_cover")
		if hinge.size() == 2:
			chained.hinge_a = hinge[0]
			chained.hinge_b = hinge[1]
		var ends := _wicks("chained_book_chain")
		if ends.size() == 2 and corner.has("chained_book_chain"):
			chained.chain = corner["chained_book_chain"]
			chained.chain_anchor = ends[0]
			chained.staple = ends[1]
		add_child(chained)

	quarantine = Quarantine.new()
	quarantine.name = "quarantine"
	for part: String in corner:
		if part.begins_with("quarantine_book_"):
			quarantine.books.append(corner[part])
	add_child(quarantine)

	# His ward: the chalk circle round the desk, open toward the customers, and the salt across its opening.
	var desk_at := CORNER_AT
	var ring := _decal("ward_circle", desk_at + Vector3(0.0, 0.05, 0.0), Vector3(2.0 * WARD_RADIUS / 0.91, 0.2, 2.0 * WARD_RADIUS / 0.91))
	ring.normal_fade = 0.5
	var salt := _decal("salt_line", desk_at + Vector3(0.0, 0.05, WARD_RADIUS), SALT_SIZE)
	salt.normal_fade = 0.5


## The points a kit's piece marks as wicks (world): a candle's, a lamp's bulb, a hinge's ends.
func _wicks(part: String) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if FileAccess.file_exists(CORNER_WICKS):
		var wicks: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CORNER_WICKS))
		for w in wicks.get(part, []):
			out.append(CORNER_AT + Vector3(w[0], w[1], w[2]))
	return out


func set_decals(on: bool) -> void:
	for d in decals:
		d.visible = on

	_name_keys()


func _decal(kind: String, at: Vector3, size: Vector3) -> Decal:
	var d := Decal.new()
	d.name = "decal_" + kind
	d.size = size
	d.texture_albedo = _painted(["decal_%s.png" % kind], true)
	d.upper_fade = 0.2
	d.lower_fade = 0.2
	add_child(d)
	d.position = at
	decals.append(d)
	return d


## Where his lamp's bulb is (world).
func lamp_bulb() -> Vector3:
	if FileAccess.file_exists(CORNER_WICKS):
		var wicks: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CORNER_WICKS))
		if wicks.has("lamp"):
			var w: Array = wicks["lamp"][0]
			return CORNER_AT + Vector3(w[0], w[1], w[2])

	return LAMP_AT


# His shelves

## His five sections' cases along the walls, the low cases either side of the runner, the ladder on its rail
## along the chronology case.
func _shelves() -> void:
	if not ResourceLoader.exists(SHELF_KIT):
		missing.append(SHELF_KIT)
		return

	var meshes := _kit(SHELF_KIT)
	var look := Painterly.material(_painted(["library_shelves.png", "library_shelves_base.png"]), &"bespoke")

	for section: String in SHELVES:
		var place: Array = SHELVES[section]
		var case: MeshInstance3D = _place(meshes["shelf_" + section], look, "shelf_" + section, place[0], deg_to_rad(place[1]), true, true)
		sections[section] = case
		shelves.append(case)

	for at: Vector3 in LOW_CASES:
		shelves.append(_place(meshes["shelf_middle"], look, "shelf_middle", at, PI / 2.0, true, true))

	var chrono: Array = SHELVES["chronology"]
	for part in ["ladder_rail", "ladder"]:
		shelves.append(_place(meshes[part], look, part, chrono[0], deg_to_rad(chrono[1]), part == "ladder"))


# His books

## Every board filled with books, the live books among them and on the front table and the lecterns.
func _books() -> void:
	if not ResourceLoader.exists(BOOK_KIT) or sections.is_empty():
		missing.append(BOOK_KIT)
		return

	var meshes := _kit(BOOK_KIT)
	var look := Painterly.material(_painted(["library_books.png", "library_books_base.png"]), &"bespoke")
	var boards: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SHELF_BOARDS))

	# The spots: each case's boards, each taking books as tall as the board above (or the case's top) allows.
	var cases: Array = []
	for section: String in sections:
		cases.append([sections[section], boards["shelf_" + section], CASE_LID, section])
	for case: MeshInstance3D in shelves:
		if case.get_meta("kind") == "shelf_middle":
			cases.append([case, boards["shelf_middle"], LOW_LID, ""])

	for c in cases:
		var spots: Array = c[1]
		var tops: Array = spots.map(func(b): return b[2])
		for i in spots.size():
			var b: Array = spots[i]
			var above: Array = tops.filter(func(t): return t > b[2] + 0.001)
			var head: float = (above.min() - BOARD_T if not above.is_empty() else c[2]) - b[2]
			var keep: Array = []
			for study in STUDIES:
				if study[0] == c[3] and _board_index(spots, i) == study[1]:
					keep.append(Vector2(study[2] - STUDY_KEEP, study[2] + STUDY_KEEP))
			book_spots.append({"case": c[0], "xform": (c[0] as Node3D).global_transform, "x0": b[0], "x1": b[1], "top": b[2],
				"z0": b[3], "z1": b[4], "facing": -1 if c[3] == "" and b[4] <= 0.0 else 1, "head": head, "keep": keep,
				"section": c[3]})

	var kinds: Array = []
	for k in BOOK_KINDS:
		kinds.append(meshes["book_%d" % k])
	for k in BOOK_STACKS:
		kinds.append(meshes["book_stack_%d" % k])
	var filler := BookFiller.new()
	book_draws = filler.fill(book_spots, kinds, look, 1888)
	book_layout = filler.layout
	for draw in book_draws:
		draw.set_meta("look", look)
		add_child(draw)

	# The studies on their boards, their spines along the board's depth.
	for study in STUDIES:
		var case: MeshInstance3D = sections[study[0]]
		var b: Array = boards["shelf_" + study[0]][study[1]]
		var at := Transform3D(Basis(), Vector3(study[2], b[2] + LIVE_HINGE.z + LIVE_LIFT, (b[3] + b[4]) / 2.0))
		_live_book(meshes, look, LiveBook.Kind.STUDY, StringName(study[0]), case.global_transform * at)

	# The table of novels by his door; the lecterns either side of the runner with a spellbook open-able on each.
	book_stands.append(_place(meshes["front_table"], look, "front_table", FRONT_TABLE_AT, 0.0, true))
	for at: Vector3 in NOVELS:
		var place := Transform3D(Basis().scaled(Vector3.ONE * NOVEL_SCALE), at + Vector3(0.0, (LIVE_HINGE.z + LIVE_LIFT) * NOVEL_SCALE, 0.0))
		_live_book(meshes, look, LiveBook.Kind.NOVEL, &"", place)

	var slope := Basis(Vector3.RIGHT, deg_to_rad(LECTERN_SLOPE))
	for stand: Array in LECTERNS:
		var yaw := deg_to_rad(stand[1])
		book_stands.append(_place(meshes["lectern"], look, "lectern", stand[0], yaw, true))
		var on := LECTERN_DESK + slope * Vector3(0.0, LIVE_HINGE.z + LIVE_LIFT, 0.0)
		_live_book(meshes, look, LiveBook.Kind.SPELL, &"", Transform3D(Basis(Vector3.UP, yaw), stand[0]) * Transform3D(slope, on))


## Which of its case's boards (counted from the floor) a spot is on.
func _board_index(spots: Array, i: int) -> int:
	var tops := {}
	for b in spots:
		tops[b[2]] = true
	var sorted: Array = tops.keys()
	sorted.sort()
	return sorted.find(spots[i][2])


func _live_book(meshes: Dictionary, look: Material, kind: LiveBook.Kind, section: StringName, place: Transform3D) -> LiveBook:
	var book := LiveBook.new()
	book.name = "live_%d" % live_books.size()
	book.kind = kind
	book.section = section
	add_child(book)
	book.global_transform = place
	book.build(meshes, look, LIVE_HINGE)
	live_books.append(book)
	return book


# The corridor outside: the Metro's tiled floor and walls either side of his front

func _corridor() -> void:
	# The floor walked on at the tiles' tops, and the corridor's ceiling and ends.
	var walked := StaticBody3D.new()
	walked.name = "corridor_walked"
	var top := CollisionShape3D.new()
	var slab := BoxShape3D.new()
	slab.size = Vector3(2.0 * RUN, 0.2, FAR_WALL - FRONT_T)
	top.shape = slab
	walked.add_child(top)
	add_child(walked)
	walked.position = Vector3(0.0, -0.1, (FAR_WALL + FRONT_T) / 2.0)
	var dark := _flat(Color(0.12, 0.11, 0.1))
	_box(Vector3(-RUN, CEILING, FRONT_T), Vector3(RUN, CEILING + 0.2, FAR_WALL + 0.3), dark, "corridor_ceiling")
	_box(Vector3(-RUN - 0.3, 0.0, FRONT_T), Vector3(-RUN, CEILING, FAR_WALL + 0.3), dark, "corridor_end_w")
	_box(Vector3(RUN, 0.0, FRONT_T), Vector3(RUN + 0.3, CEILING, FAR_WALL + 0.3), dark, "corridor_end_e")
	_box(Vector3(-RUN, 0.0, FAR_WALL + WALL_FACE), Vector3(RUN, CEILING, FAR_WALL + WALL_FACE + 0.3), dark, "corridor_far")

	if ResourceLoader.exists(FLOOR_KIT):
		var meshes := _kit(FLOOR_KIT)
		var look := Painterly.material(_painted(["underground_floor.png", "underground_floor_base.png"]), &"bespoke")
		var columns := int(round(2.0 * RUN / MODULE))

		for c in columns:
			var x := -RUN + MODULE * c
			for r in 2:
				var turned := fposmod(sin(c * 12.9898 + r * 78.233) * 43758.5453, 1.0) > 0.5
				var low := FRONT_T + MODULE * r
				var at := Vector3(x + MODULE, 0.0, low) if turned else Vector3(x, 0.0, low + MODULE)
				corridor.append(_place(meshes["floor_field"], look, "floor_field", at, PI if turned else 0.0, false))
			corridor.append(_place(meshes["floor_edge"], look, "floor_edge", Vector3(x + MODULE, 0.0, FAR_WALL - EDGE_DEPTH), PI, false))
	else:
		missing.append(FLOOR_KIT)

	if ResourceLoader.exists(WALL_KIT):
		var meshes := _kit(WALL_KIT)
		var look := Painterly.material(_painted(["underground_walls.png", "underground_walls_base.png"]), &"bespoke")
		var columns := int(round(2.0 * RUN / MODULE))

		for c in columns:
			var x := -RUN + MODULE * c
			# The far wall, turned to face back across the corridor.
			var kind := "wall_tiled_worn" if c in [2, 7] else "wall_tiled"
			corridor.append(_place(meshes[kind], look, kind, Vector3(x + MODULE, 0.0, FAR_WALL + WALL_FACE), PI, true))
			# The shop's side: tiles on its wall either side of the bookseller's front.
			if x + MODULE <= -FRONT_REACH + 0.001 or x >= FRONT_REACH - 0.001:
				kind = "wall_tiled_worn" if c == 1 else "wall_tiled"
				corridor.append(_place(meshes[kind], look, kind, Vector3(x, 0.0, FRONT_T), 0.0, true))
	else:
		missing.append(WALL_KIT)


# The light

func _environment() -> void:
	var environment := RetroScript.night_environment(Color(0.36, 0.44, 0.58), 0.22)
	environment.volumetric_fog_density = 0.02
	world = WorldEnvironment.new()
	world.environment = environment
	add_child(world)


func _lights() -> void:
	# Two sodium work lights under the vault, one in the corridor.
	for at in [Vector3(-2.2, 3.6, -2.6), Vector3(2.2, 3.6, -2.6), Vector3(0.0, 3.6, 2.0)]:
		var light := OmniLight3D.new()
		light.name = "work_%d" % work_lights.size()
		light.light_color = SODIUM
		light.light_energy = 1.4
		light.omni_range = 7.0
		light.shadow_enabled = true
		add_child(light)
		light.position = at
		work_lights.append(light)

	lamp_light = OmniLight3D.new()
	lamp_light.name = "lamp_light"
	lamp_light.light_color = LAMP_COLOUR
	lamp_light.light_energy = 1.2
	lamp_light.omni_range = 4.0
	lamp_light.shadow_enabled = true
	add_child(lamp_light)
	lamp_light.position = lamp_bulb()

	form_light = DirectionalLight3D.new()
	form_light.name = "form_light"
	form_light.light_energy = 1.2
	form_light.shadow_enabled = false
	form_light.visible = false
	add_child(form_light)
	form_light.rotation = Vector3(deg_to_rad(-40), deg_to_rad(30), 0)
	form_material = StandardMaterial3D.new()
	form_material.albedo_color = Color(0.6, 0.6, 0.6)
	form_material.roughness = 1.0


func _keys() -> void:
	var screen := CanvasLayer.new()
	add_child(screen)
	keys_label = Label.new()
	keys_label.position = Vector2(12, 8)
	keys_label.add_theme_font_size_override("font_size", 14)
	screen.add_child(keys_label)
	_name_keys()


func _name_keys() -> void:
	if keys_label == null or work_lights.is_empty():
		return

	keys_label.text = "F1 work lights %s  ·  F2 form light %s  ·  F3 decals %s" % ["on" if work_lights[0].visible else "off",
		"on" if _form else "off", "on" if decals.is_empty() or decals[0].visible else "off"]


# Kits, painting, placing

func _kit(path: String) -> Dictionary:
	var meshes := {}
	var kit: Node3D = (load(path) as PackedScene).instantiate()

	for mesh: MeshInstance3D in kit.find_children("*", "MeshInstance3D", true, false):
		meshes[String(mesh.name)] = mesh.mesh

	kit.free()
	return meshes


func _painted(names: Array, alpha := false) -> Texture2D:
	for file in names:
		var path: String = atlas_dir + file

		# The imported texture, as an exported game has it; a file Godot has not imported yet (just painted)
		# read straight from disk meanwhile.
		if ResourceLoader.exists(path):
			return load(path) as Texture2D

		if FileAccess.file_exists(path):
			var image := Image.load_from_file(path)
			image.convert(Image.FORMAT_RGBA8 if alpha else Image.FORMAT_RGB8)
			image.generate_mipmaps()
			return ImageTexture.create_from_image(image)

	missing.append(atlas_dir + String(names[-1]))
	return null


## Glass: clear, or of a tint (`tint`'s alpha 0 for clear), the tinted lit a little from within (a lamp's shade).
func _glass(tint := Color(0, 0, 0, 0)) -> StandardMaterial3D:
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass.albedo_color = Color(0.66, 0.78, 0.74, 0.32) if tint.a == 0.0 else tint
	glass.roughness = 0.1
	glass.metallic_specular = 0.8

	if tint.a > 0.0:
		glass.emission_enabled = true
		glass.emission = Color(tint.r, tint.g, tint.b)
		glass.emission_energy_multiplier = 0.6

	return glass


## A kit piece set at `at`, turned `yaw` about the vertical; solid if asked, to its shape (`exact`, for walls
## and floors walked against and on) or to its hull.
func _place(mesh: Mesh, material: Material, kind: String, at: Vector3, yaw: float, solid: bool, exact := false) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	piece.name = kind
	piece.mesh = mesh
	piece.set_meta("kind", kind)

	for i in piece.mesh.get_surface_count():
		var slot: Material = piece.mesh.surface_get_material(i)
		var glazed := slot != null and slot.resource_name.begins_with("glass")
		var tint := SHADE_GREEN if slot != null and slot.resource_name == "glass_green" else Color(0, 0, 0, 0)
		piece.set_surface_override_material(i, _glass(tint) if glazed else material)

	add_child(piece, true)
	piece.position = at
	piece.rotation.y = yaw

	if solid:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		shape.shape = piece.mesh.create_trimesh_shape() if exact else piece.mesh.create_convex_shape()
		body.add_child(shape)
		piece.add_child(body)

	return piece


func _flat(colour: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.roughness = 0.9
	return m


func _box(lo: Vector3, hi: Vector3, material: Material, node_name: String) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	var box := BoxMesh.new()
	box.size = hi - lo
	box.material = material
	mesh.mesh = box
	add_child(mesh)
	mesh.position = (lo + hi) / 2
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var solid := BoxShape3D.new()
	solid.size = hi - lo
	shape.shape = solid
	body.add_child(shape)
	mesh.add_child(body)
