extends RefCounted
## The Light Company's machinery in the Zócalo station (docs/superpowers/specs/2026-10-31-station-machinery-design.md;
## plan docs/superpowers/plans/2026-10-31-station-machinery.md): its neon, and (later tasks) its cable runs and arcs,
## its engine and its astral lamps. Static, given the set, as the dressing is; StationDressing.dress calls it after
## the station's light.

const SetKit := preload("res://scripts/Level/SetKit.gd")
const Painterly := preload("res://scripts/Visual/Painterly.gd")
const Layers := preload("res://scripts/Visual/Layers.gd")

const NEON_KIT := "res://assets/eclipse/kit/station_neon.glb"
const RUNS_KIT := "res://assets/eclipse/kit/station_runs.glb"
const RUNS_JSON := "res://assets/eclipse/kit/station_runs.json"
const PIPES_KIT := "res://assets/eclipse/kit/station_pipes.glb"
const DUCTS_KIT := "res://assets/eclipse/kit/station_ducts.glb"
const PIPES_JSON := "res://assets/eclipse/kit/station_pipes.json"
const ENGINE_KIT := "res://assets/eclipse/kit/station_engine.glb"
const ENGINE_WORKS_KIT := "res://assets/eclipse/kit/station_engine_works.glb"
const ENGINE_JSON := "res://assets/eclipse/kit/station_engine.json"
const Clockwork := preload("res://scripts/Visual/Clockwork.gd")
const EngineCrank := preload("res://scripts/Visual/EngineCrank.gd")
const ENGINE_CORE := preload("res://scripts/Visual/engine_core.gdshader")
const ENGINE_DIAL := preload("res://scripts/Visual/engine_dial.gdshader")
const ENGINE_LAMP := preload("res://scripts/Visual/engine_lamp.gdshader")
## The Company's engine (station_engine: the stone and the works, each placed at its frame's origin): where it stands,
## its footprint's reach round it (its brass ring), its core's light (energy, reach) and its height over the hall's
## floor.
const ENGINE_AT := Vector3(0.0, 6.0, 0.0)
const ENGINE_REACH := 4.78
const CORE_LIGHT := Vector2(2.4, 9.0)
const CORE_LIGHT_HIGH := 2.8
## Its blade signs' tubes' light: low, standing on its pale deck (full, they washed the plinth pink).
const ENGINE_BLADE_LIGHT := Vector2(0.22, 3.0)
## The floor's pipe mouths (station_pipes' mouth), venting the Company's fuel fumes: where each stands (the set's frame,
## on its floor), the fumes' height over its foot (the kit's FUME_AT), how they look (the fuel's sour amber-green).
const MOUTHS := [Vector3(-25.0, 6.0, -11.6), Vector3(25.0, 6.0, 11.6), Vector3(-3.0, 6.0, 11.6), Vector3(11.0, 6.0, -11.6),
	Vector3(-44.0, 0.0, -11.6), Vector3(28.0, 0.0, -11.6), Vector3(-28.0, 0.0, 11.6), Vector3(44.0, 0.0, 11.6)]
## Each mouth fed from its wall's floor main (the kit's feed: FEED_LENGTH long, from the main toward the mouth), the
## floor mains' line out from the plaster; how many cables a tray carries (the kit's TRAY_CABLES).
const FEED_LENGTH := 1.32
const FLOOR_MAIN_Z := 14.0 - 0.3 - 0.032 - 0.75
const TRAY_CABLES := 6
const FUME_AT := 0.95
## Where its smoke rises from: down in its throat, under its lip (the kit's mouth: 0.9 high).
const FUME_FROM := 0.7
## The smoke: its mouth's width, how high its plumes climb, its colours lit and in shade (grey, the copal column's), the
## haze it gathers in over the mouth.
const SMOKE_WIDTH := 1.8
const SMOKE_RISE := 3.6
const SMOKE_LIT := Color(0.8, 0.79, 0.76)
const SMOKE_SHADE := Color(0.34, 0.35, 0.41)
const SMOKE_POOL := Vector3(4.0, 1.6, 4.0)
const SMOKE_BILLOW := Vector3(2.4, 1.2, 2.4)

## The neon's own hanging board (station_neon's neon_board, in place of the shell's sign_board where neon hangs: the
## user, Oct 31, "enlarge the symbols" and "make sure they fit on the board"): its face's middle under the ceiling and
## its half-width (m); the arrow and the symbol at its ends, half again their drawn size, their whole tube inside the
## face (a margin from its edge), the middle left for the user's words; the tubes this far in front of the board's
## middle (clear of the brass frame).
const BOARD_MIDDLE := 0.91
const BOARD_FACE_HALF := 1.15
const BOARD_MARGIN := 0.02
const BOARD_TUBE_OUT := 0.125
const BOARD_SYMBOL_SIZE := 1.5
## Where each board's gap leads → its symbol: the platforms' stairs from the hall the serpent (to the trains), the
## corridors the eye, the market stairs the marigold, the way up from a platform the hand.
const LEADS := {"stairs_n": "serpent", "stairs_s": "serpent", "corridor_w": "eye", "corridor_e": "eye",
	"market_stairs": "marigold"}
const LEAD_ELSE := "hand"
## Each symbol's warm accent (the arrows burn the Company's blue).
const ACCENTS := {"serpent": Color("#FFB040"), "eye": Color("#FF4F7A"), "marigold": Color("#FF8A2A"),
	"hand": Color("#FF4A3A"), "skull": Color("#E8E0D0")}
## A tube steady but for a rare stutter; its glow, its light and reach.
const PATTERN := "mmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmlmmmmmmmmmmmmmmmmkm"
const TUBE_ENERGY := 4.0
const SIGN_LIGHT := Vector2(0.5, 3.5)
## The Company's blade signs: on each turnstile bank's pylon at the kit's +x end (station_turnstiles: the outer
## cabinet's middle, its pylon's top), its face's tubes this far in front of the board's middle, the symbol scaled up
## to the blade's face and where on it; the Company's eye on them.
const BLADE_ON := Vector3(3.72, 0.0, 2.16)
const BLADE_TUBE_OUT := 0.14
const BLADE_SYMBOL := Vector2(1.6, 1.15)
const BLADE_LIGHT := Vector2(0.9, 4.5)
const BLADE_SYMBOL_KIND := "eye"


static func dress(station, root: Node3D) -> void:
	_neon(station, root)
	_runs(station, root)
	_racks(station, root)
	_engine(station, root)


## The Company's engine at the hall's middle: its stone and its works (solid), its glowing core and its gauges' dials
## and lamps, its core's light; its gears and governor turning (Clockwork) and its flywheels driving their pistons
## (EngineCrank), stood from station_engine.json; the Company's blade signs on its deck.
static func _engine(station, root: Node3D) -> void:
	if not (ResourceLoader.exists(ENGINE_KIT) and ResourceLoader.exists(ENGINE_WORKS_KIT)
			and FileAccess.file_exists(ENGINE_JSON)):
		return
	var stone_kit := SetKit.kit(ENGINE_KIT)
	var works_kit := SetKit.kit(ENGINE_WORKS_KIT)
	var stone_look := Painterly.material(SetKit.painted(["station_engine.png", "station_engine_base.png"]), &"bespoke")
	var works_look := Painterly.material(SetKit.painted(["station_engine_works.png", "station_engine_works_base.png"]),
		&"bespoke")
	var level := Layers.STATION_HALL
	var engine := Node3D.new()
	engine.name = "engine"
	root.add_child(engine)
	engine.position = ENGINE_AT
	engine.set_meta("footprint", Rect2(-ENGINE_REACH, -ENGINE_REACH, 2.0 * ENGINE_REACH, 2.0 * ENGINE_REACH))
	station.engine = engine
	var stone := SetKit.place(engine, stone_kit["engine"], stone_look, "engine", Vector3.ZERO, 0.0, true, true)
	stone.layers = level
	var works := SetKit.place(engine, works_kit["engine_works"], works_look, "engine_works", Vector3.ZERO, 0.0, true,
		true)
	works.layers = level
	_glaze(works)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ENGINE_JSON))
	var spinners: Array[Node3D] = []
	for gear: Dictionary in data["gears"]:
		var out := _out(float(gear["heading"]))
		var turner := _turner(engine, works_kit, works_look, String(gear["piece"]), _spot(gear),
			Basis(out.cross(Vector3.UP), out, Vector3.UP), float(gear["turns"]), level)
		spinners.append(turner)
	var governor: Dictionary = data["governor"]
	spinners.append(_turner(engine, works_kit, works_look, "governor", _spot(governor), Basis.IDENTITY,
		float(governor["turns"]), level))
	var cranks: Array[Node3D] = []
	var linkage: Dictionary = data["linkage"]
	for spot: Dictionary in data["cranks"]:
		var out := _out(float(spot["heading"]))
		var crank := EngineCrank.new()
		crank.name = "crank"
		crank.turns = float(spot["turns"])
		crank.start = float(spot["start"])
		crank.throw = float(linkage["throw"])
		crank.conrod = float(linkage["conrod"])
		crank.out = float(linkage["out"])
		for part in ["flywheel", "conrod", "crosshead"]:
			var piece := MeshInstance3D.new()
			piece.name = part
			piece.mesh = works_kit[part]
			piece.material_override = works_look
			piece.layers = level
			crank.add_child(piece)
		engine.add_child(crank, true)
		crank.transform = Transform3D(Basis(Vector3.UP.cross(out), out, Vector3.DOWN), _spot(spot))
		cranks.append(crank)
	engine.set_meta("spinners", spinners)
	engine.set_meta("cranks", cranks)
	var StationDressing = load("res://maps/metro_station_dressing.gd")
	var core := OmniLight3D.new()
	core.name = "core_light"
	core.light_color = StationDressing.COMPANY_BLUE
	core.light_energy = CORE_LIGHT.x
	core.omni_range = CORE_LIGHT.y
	core.light_cull_mask = level | Layers.WORLD | Layers.ACTORS | Layers.VIEWMODEL | Layers.FX | Layers.GEM_PROBE
	engine.add_child(core)
	core.position = Vector3(0.0, CORE_LIGHT_HIGH, 0.0)
	station.lights.append(core)
	# The Company's blade signs standing on its deck.
	if ResourceLoader.exists(NEON_KIT):
		var neon_kit := SetKit.kit(NEON_KIT)
		var look := _neon_look()
		var seed := 400
		for blade: Dictionary in data["blades"]:
			_blade(station, root, neon_kit, look, Vector3(float(blade["x"]), float(blade["y"]), float(blade["z"])),
				-deg_to_rad(float(blade["heading"])), "engine", seed, ENGINE_BLADE_LIGHT)
			seed += 4


## Out from the engine's middle along the set frame's heading (degrees).
static func _out(heading: float) -> Vector3:
	return Vector3(cos(deg_to_rad(heading)), 0.0, sin(deg_to_rad(heading)))


## A spot of station_engine.json (the set frame), in the engine's own.
static func _spot(spot: Dictionary) -> Vector3:
	return Vector3(float(spot["x"]), float(spot["y"]), float(spot["z"])) - ENGINE_AT


## A Clockwork at `at` turned to `basis`, the kit's `piece` its one child.
static func _turner(engine: Node3D, kit: Dictionary, look: Material, piece: String, at: Vector3, basis: Basis,
		turns: float, level: int) -> Node3D:
	var turner := Clockwork.new()
	turner.name = piece + "_turner"
	turner.turns = turns
	var part := MeshInstance3D.new()
	part.name = piece
	part.mesh = kit[piece]
	part.material_override = look
	part.layers = level
	turner.add_child(part)
	engine.add_child(turner, true)
	turner.transform = Transform3D(basis, at)
	return turner


## The engine's lit glass: its core, its gauges' dials, its indicator lamps (its lenses stay clear glass).
static func _glaze(piece: MeshInstance3D) -> void:
	for i in piece.mesh.get_surface_count():
		var slot: Material = piece.mesh.surface_get_material(i)
		var name := slot.resource_name if slot != null else ""
		var shader: Shader = {"glass_core": ENGINE_CORE, "glass_dial": ENGINE_DIAL, "glass_lamp": ENGINE_LAMP}.get(name)
		if shader != null:
			var lit := ShaderMaterial.new()
			lit.shader = shader
			piece.set_surface_override_material(i, lit)


## The Company's pipework (station_pipes: one piece each in the set's frame): the racks on the hall's long walls and
## the platforms' back walls, the ceiling's mains, the walls' risers (solid), and the floor's mouths venting fumes.
static func _racks(station, root: Node3D) -> void:
	if not ResourceLoader.exists(PIPES_KIT) or not ResourceLoader.exists(DUCTS_KIT):
		return
	var kit := SetKit.kit(PIPES_KIT)
	var look := Painterly.material(SetKit.painted(["station_pipes.png", "station_pipes_base.png"]), &"bespoke")
	look.set_shader_parameter("painted_light", 0.0)
	look.set_shader_parameter("ramp_amount", 0.0)
	var ducts := SetKit.kit(DUCTS_KIT)
	var duct_look := Painterly.material(SetKit.painted(["station_ducts.png", "station_ducts_base.png"]), &"bespoke")
	duct_look.set_shader_parameter("painted_light", 0.0)
	duct_look.set_shader_parameter("ramp_amount", 0.0)
	for kind: String in ducts:
		if kind.begins_with("floor_"):
			var floor_main := SetKit.place(root, ducts[kind], duct_look, kind, Vector3.ZERO, 0.0, true, true)
			floor_main.layers = Layers.STATION_HALL if kind.begins_with("floor_hall") else Layers.STATION_BELOW
			station.floor_mains.append(floor_main)
		elif kind.begins_with("tray_"):
			var tray := SetKit.place(root, ducts[kind], duct_look, kind, Vector3.ZERO, 0.0, false)
			tray.layers = Layers.STATION_HALL
			tray.set_meta("cables", TRAY_CABLES)
			station.trays.append(tray)
	for kind: String in kit:
		var hall := kind.begins_with("rack_hall") or kind.begins_with("main_") or kind.begins_with("riser_h")
		var level := Layers.STATION_HALL if hall else Layers.STATION_BELOW
		if kind.begins_with("rack_"):
			var rack := SetKit.place(root, kit[kind], look, kind, Vector3.ZERO, 0.0, false)
			rack.layers = level
			station.racks.append(rack)
		elif kind.begins_with("main_"):
			var main := SetKit.place(root, kit[kind], look, kind, Vector3.ZERO, 0.0, false)
			main.layers = level
			station.mains.append(main)


	# (The risers: one built for the hall and one for the platforms, each stood where the kit's json says, turned to its
	# wall.)
	if FileAccess.file_exists(PIPES_JSON):
		for spot: Dictionary in JSON.parse_string(FileAccess.get_file_as_string(PIPES_JSON)):
			var piece := String(spot["piece"])
			if not kit.has(piece):
				continue
			var at := Vector3(float(spot["x"]), float(spot["floor"]), float(spot["z"]))
			var riser := SetKit.place(root, kit[piece], look, piece, at, 0.0 if float(spot["side"]) < 0.0 else PI, true,
				true)
			riser.layers = Layers.STATION_HALL if piece == "riser_hall" else Layers.STATION_BELOW
			station.risers.append(riser)
	if not ducts.has("mouth"):
		return
	for k in MOUTHS.size():
		var at: Vector3 = MOUTHS[k]
		var mouth := SetKit.place(root, ducts["mouth"], duct_look, "mouth", at, k * 0.7, true)
		mouth.layers = Layers.STATION_HALL if at.y > 3.0 else Layers.STATION_BELOW
		# (Its feed from the floor's main at its wall: the kit's feed runs from the main toward the mouth.)
		if ducts.has("feed"):
			var side := signf(at.z)
			var feed := SetKit.place(root, ducts["feed"], duct_look, "feed", Vector3(at.x, at.y, side * FLOOR_MAIN_Z),
				0.0 if side < 0.0 else PI, true)
			feed.layers = mouth.layers
			mouth.set_meta("feed", feed)
		# (Smoke, its ribbons big: the user, Oct 31: "it's not more effects, it's making the ribbons and the general vibe
		# of the smoke bigger". The copal column's way: a wide mouth, few fat plumes climbing high, few puffs, grey.)
		var fumes := Fumes.new()
		fumes.name = "fumes"
		fumes.width = SMOKE_WIDTH
		fumes.rise = SMOKE_RISE
		fumes.plumes = 3
		fumes.root = 0.14
		fumes.crown = 0.42
		fumes.lit = SMOKE_LIT
		fumes.shade = SMOKE_SHADE
		fumes.warmth = 0.03
		fumes.glow = 0.08
		fumes.opacity = 0.75
		fumes.puffs = 0.0
		fumes.churn = 0.05
		# (Deadlock's ribbons (the user's reference, Mirage's tornado, docs/superpowers/refs/underground/
		# deadlock_smoke_mirage_tornado.jpg): narrow smooth bands winding round each other up a slender helix, streaked
		# with the flow, their edges fading soft, never eaten into holes; its foot a soft billow of haze.)
		fumes.twirl = 3.6
		# (Out of the mouth itself, the user, Oct 31: "they should be coming OUT of the mouth, not around it": their feet
		# close round its middle, down in its throat, the helix widening as it climbs.)
		fumes.ring = 0.08
		fumes.widen = 5.0
		fumes.erosion = 0.15
		fumes.grain = 0.7
		fumes.streak = 4.0
		fumes.softness = 0.3
		# (Dissipating as it climbs: smooth out of the mouth, thinning, breaking up and fading into the haze by its top,
		# the user, Oct 31: "it should dissipate more".)
		fumes.dissipate = 2.4
		fumes.fade_from = 0.4
		fumes.seed = 900 + k
		# (A soft billow of haze at its foot, out of the mouth.)
		var billow := FogVolume.new()
		billow.name = "smoke_billow"
		billow.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
		billow.size = SMOKE_BILLOW
		var cloud := FogMaterial.new()
		cloud.albedo = SMOKE_LIT
		cloud.density = 1.4
		cloud.edge_fade = 0.6
		billow.material = cloud
		mouth.add_child(billow)
		billow.position = Vector3(0.0, FUME_AT + 0.4, 0.0)
		# (Its smoke gathering in a haze over it, under the ceiling.)
		var pool := FogVolume.new()
		pool.name = "smoke_pool"
		pool.size = SMOKE_POOL
		var haze := FogMaterial.new()
		haze.albedo = SMOKE_LIT
		haze.density = 1.6
		haze.edge_fade = 0.5
		pool.material = haze
		mouth.add_child(pool)
		pool.position = Vector3(0.0, FUME_AT + SMOKE_RISE, 0.0)
		mouth.add_child(fumes)
		fumes.position = Vector3(0.0, FUME_FROM, 0.0)
		station.mouths.append(mouth)


## The Company's cable runs from the engine's crown (station_runs: one piece each in the set's frame, a bundle of
## cables; the user dropped the tesla arcs, Oct 31).
static func _runs(station, root: Node3D) -> void:
	if not ResourceLoader.exists(RUNS_KIT) or not FileAccess.file_exists(RUNS_JSON):
		return
	var kit := SetKit.kit(RUNS_KIT)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RUNS_JSON))
	var look := Painterly.material(SetKit.painted(["station_runs.png", "station_runs_base.png"]), &"bespoke")
	look.set_shader_parameter("painted_light", 0.0)
	look.set_shader_parameter("ramp_amount", 0.0)
	for name: String in data:
		var kind := "run_" + name
		if not kit.has(kind):
			continue
		var run := SetKit.place(root, kit[kind], look, kind, Vector3.ZERO, 0.0, false)
		run.layers = Layers.STATION_HALL | Layers.STATION_STAIRS | Layers.STATION_BELOW
		var points := PackedVector3Array()
		for p: Array in data[name]["points"]:
			points.append(Vector3(p[0], p[1], p[2]))
		run.set_meta("points", points)
		run.set_meta("to", String(data[name]["to"]))
		run.set_meta("cables", int(data[name].get("cables", 1)))
		station.runs.append(run)


## A silent neon sign of `mesh` in `colour` at `place` (the set's frame), its light on `level` and the movers; listed
## in station.neon and its light in station.lights.
static func neon(station, root: Node3D, mesh: Mesh, colour: Color, place: Transform3D, seed: int, level: int,
		light := SIGN_LIGHT, size := 1.0) -> NeonSign:
	var sign := NeonSign.new()
	sign.name = "neon"
	sign.colour = colour
	sign.pattern = PATTERN
	sign.seed = seed
	sign.energy = TUBE_ENERGY
	sign.light_energy = light.x
	sign.light_range = light.y
	sign.buzz = &""
	var tube := MeshInstance3D.new()
	tube.name = "tube"
	tube.mesh = mesh
	tube.layers = level
	# (Scaled on the tube, never the sign: its light's reach stays its own.)
	tube.scale = Vector3.ONE * size
	sign.add_child(tube)
	root.add_child(sign, true)
	sign.transform = place
	sign.light.light_cull_mask = level | Layers.WORLD | Layers.ACTORS | Layers.VIEWMODEL | Layers.FX | Layers.GEM_PROBE
	station.neon.append(sign)
	station.lights.append(sign.light)
	return sign


static func _neon(station, root: Node3D) -> void:
	if not ResourceLoader.exists(NEON_KIT):
		return
	var kit := SetKit.kit(NEON_KIT)
	var StationDressing = load("res://maps/metro_station_dressing.gd")
	var blue: Color = StationDressing.COMPANY_BLUE
	var seed := 100
	var look := _neon_look()
	# The hanging boards: the neon's own board at each, an arrow and the symbol for where it leads on each face.
	for k in station.sign_boards.size():
		var board: Transform3D = station.sign_boards[k]
		var symbol := String(LEADS.get(station.sign_leads[k], LEAD_ELSE))
		var level: int = StationDressing.level_of(station.sign_spaces[k])
		var hung := SetKit.place(root, kit["neon_board"], look, "neon_board", board.origin, 0.0, false)
		hung.basis = board.basis
		hung.layers = level
		for face in [1.0, -1.0]:
			var turn := Basis.IDENTITY if face > 0.0 else Basis(Vector3.UP, PI)
			# (Seen from this face, the arrow at its left end and the symbol at its right.)
			for part in [["arrow", -1.0, blue], [symbol, 1.0, ACCENTS[symbol]]]:
				var mesh: Mesh = kit["symbol_" + part[0]]
				var box := mesh.get_aabb()
				var half := maxf(box.size.x, box.size.y) * BOARD_SYMBOL_SIZE / 2.0
				var x: float = part[1] * face * (BOARD_FACE_HALF - BOARD_MARGIN - half)
				# (Its tube's middle on its spot, wherever the drawing's own middle lies.)
				var middle := turn * (box.get_center() * BOARD_SYMBOL_SIZE)
				var at := Vector3(x, -BOARD_MIDDLE, face * BOARD_TUBE_OUT) - Vector3(middle.x, middle.y, 0.0)
				var sign := neon(station, root, mesh, part[2], board * Transform3D(turn, at), seed, level, SIGN_LIGHT,
					BOARD_SYMBOL_SIZE)
				sign.set_meta("symbol", part[0])
				seed += 1
	# The Company's blade signs on the banks' pylons.
	if not kit.has("blade_company"):
		return
	for bank: Node3D in station.turnstiles:
		var on := bank.transform * Vector3(BLADE_ON.x, BLADE_ON.z, -BLADE_ON.y)
		_blade(station, root, kit, look, on, bank.rotation.y, String(bank.name), seed)
		seed += 4


## The neon's painted look (its boards and blades lit by their own tubes, not the painted light).
static func _neon_look() -> ShaderMaterial:
	var look := Painterly.material(SetKit.painted(["station_neon.png", "station_neon_base.png"]), &"bespoke")
	look.set_shader_parameter("painted_light", 0.0)
	look.set_shader_parameter("ramp_amount", 0.0)
	return look


## A Company blade sign standing at `on`, turned `yaw`: the Company's blue outline and its eye in neon on both faces,
## each sign's meta "on" naming what it stands on.
static func _blade(station, root: Node3D, kit: Dictionary, look: Material, on: Vector3, yaw: float, on_name: String,
		seed: int, light := BLADE_LIGHT) -> void:
	var StationDressing = load("res://maps/metro_station_dressing.gd")
	var blue: Color = StationDressing.COMPANY_BLUE
	var blade := SetKit.place(root, kit["blade_company"], look, "blade_company", on, yaw, false)
	blade.layers = Layers.STATION_HALL
	for face in [1.0, -1.0]:
		var turn := Basis.IDENTITY if face > 0.0 else Basis(Vector3.UP, PI)
		var outline := Transform3D(blade.basis * turn, on + blade.basis * Vector3(0.0, 0.0, face * BLADE_TUBE_OUT))
		var sign := neon(station, root, kit["outline_blade"], blue, outline, seed, Layers.STATION_HALL, light)
		sign.set_meta("symbol", "outline")
		sign.set_meta("on", on_name)
		seed += 1
		var eye := Transform3D(blade.basis * turn, on + blade.basis * Vector3(0.0, BLADE_SYMBOL.y, face * BLADE_TUBE_OUT))
		sign = neon(station, root, kit["symbol_" + BLADE_SYMBOL_KIND], ACCENTS[BLADE_SYMBOL_KIND], eye, seed,
			Layers.STATION_HALL, light, BLADE_SYMBOL.x)
		sign.set_meta("symbol", "blade_" + BLADE_SYMBOL_KIND)
		sign.set_meta("on", on_name)
		seed += 1
