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


## The Company's pipe racks on the hall's long walls and the platforms' back walls (station_pipes: one piece each in the
## set's frame).
static func _racks(station, root: Node3D) -> void:
	if not ResourceLoader.exists(PIPES_KIT):
		return
	var kit := SetKit.kit(PIPES_KIT)
	var look := Painterly.material(SetKit.painted(["station_pipes.png", "station_pipes_base.png"]), &"bespoke")
	look.set_shader_parameter("painted_light", 0.0)
	look.set_shader_parameter("ramp_amount", 0.0)
	for kind: String in kit:
		if not kind.begins_with("rack_"):
			continue
		var rack := SetKit.place(root, kit[kind], look, kind, Vector3.ZERO, 0.0, false)
		rack.layers = Layers.STATION_HALL if kind.begins_with("rack_hall") else Layers.STATION_BELOW
		station.racks.append(rack)


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
	var look := Painterly.material(SetKit.painted(["station_neon.png", "station_neon_base.png"]), &"bespoke")
	look.set_shader_parameter("painted_light", 0.0)
	look.set_shader_parameter("ramp_amount", 0.0)
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
		var blade := SetKit.place(root, kit["blade_company"], look, "blade_company", on, bank.rotation.y, false)
		blade.layers = Layers.STATION_HALL
		for face in [1.0, -1.0]:
			var turn := Basis.IDENTITY if face > 0.0 else Basis(Vector3.UP, PI)
			var outline := Transform3D(blade.basis * turn, on + blade.basis * Vector3(0.0, 0.0, face * BLADE_TUBE_OUT))
			var sign := neon(station, root, kit["outline_blade"], blue, outline, seed, Layers.STATION_HALL, BLADE_LIGHT)
			sign.set_meta("symbol", "outline")
			sign.set_meta("on", String(bank.name))
			seed += 1
			var eye := Transform3D(blade.basis * turn, on + blade.basis * Vector3(0.0, BLADE_SYMBOL.y, face * BLADE_TUBE_OUT))
			sign = neon(station, root, kit["symbol_" + BLADE_SYMBOL_KIND], ACCENTS[BLADE_SYMBOL_KIND], eye, seed,
				Layers.STATION_HALL, BLADE_LIGHT, BLADE_SYMBOL.x)
			sign.set_meta("symbol", "blade_" + BLADE_SYMBOL_KIND)
			sign.set_meta("on", String(bank.name))
			seed += 1
