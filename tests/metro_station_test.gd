extends Node3D
## The Zócalo station set (docs/superpowers/plans/2026-10-30-metro-station.md): quick checks, headless with
## --fixed-fps 60:
##   Godot --headless --fixed-fps 60 --path . res://tests/metro_station_test.tscn

const STATION := preload("res://maps/metro_station.tscn")
const Layers := preload("res://scripts/Visual/Layers.gd")
const StationDressing := preload("res://maps/metro_station_dressing.gd")
const TeslaArcScript := preload("res://scripts/Visual/TeslaArc.gd")
const EngineFx := preload("res://maps/metro_station_engine_fx.gd")
## The MP-68's running pads, centred this far either side of a track's centre (m).
const PAD_FROM_CENTRE := 1.0

var results: Array[String] = []
var failures := 0
var station: Node3D


func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	station = STATION.instantiate()
	add_child(station)
	await _frames(5)
	_shell()
	await _walked()
	_mouths()
	_track()
	_dressed()
	await _lit()
	_taquillas()
	await _turnstiles()
	_neon()
	await _runs()
	await _engine()
	await _engine_fx()
	print("\n==== RESULTS ====")
	for result in results:
		print(result)
	get_tree().quit(1 if failures > 0 else 0)


## Task 5: the track laid for the MP-68.
## S5: two tracks laid end to end: for each track, both its running pads' tops at PAD_TOP (± 1 cm) at every metre of x
## from -50 to 50, found by a ray down onto them (what a foot or a tyre stands on).
func _track() -> void:
	var wrong := []
	for z: float in station.TRACKS_Z:
		for side in [-1.0, 1.0]:
			var pad_z: float = z + side * PAD_FROM_CENTRE
			for x in range(-50, 51):
				var at := Vector3(float(x), float(station.PAD_TOP) + 2.0, pad_z)
				var top := _ray(at, at + Vector3(0.0, -3.0, 0.0)).y
				if absf(top - float(station.PAD_TOP)) > 0.01:
					wrong.append("pad at x %d, z %.1f: %.2f" % [x, pad_z, top])
	_check("S5 two tracks laid end to end", wrong.is_empty(), "%d: %s" % [wrong.size(), wrong.slice(0, 6)])


## Task 7: the taquillas.
## The booths' places (the plan's): the east against the hall's north wall at x 16…24 (the plan's ticket booth), the
## west against its south wall at x −24…−16; the windows each has.
const TAQUILLAS := {"east": [16.0, 24.0, -1.0, 3], "west": [-24.0, -16.0, 1.0, 2]}
## How far in front of a window the queue stands clear, and how wide (m).
const QUEUE := Vector2(2.0, 1.0)


## S7: each booth stands against its wall (its back on the wall's tiles), within its x range, its windows facing into
## the hall. S7b: 2 m of clear floor in front of each window, nothing solid in it and no dressing drawn in it.
func _taquillas() -> void:
	var booths = station.get("taquillas")
	var wrong := []
	var crowded := []
	var tiles := 14.0 - float(station.WALL) - 0.067
	var hall_floor: float = station.spaces()["hall"]["floor"]
	var drawn := _drawn()
	if booths == null or (booths as Array).size() != TAQUILLAS.size():
		wrong.append("booths: %s" % [booths])
		booths = []
	for booth: Node3D in booths:
		var place: Array = TAQUILLAS.get(booth.get_meta("side", ""), [])
		if place.is_empty():
			wrong.append("%s: no side" % booth.name)
			continue
		var box := _box_of(booth)
		var back := box.position.z if place[2] < 0.0 else box.end.z
		if absf(absf(back) - tiles) > 0.02 or signf(back) != place[2]:
			wrong.append("%s: back at z %.3f, the tiles at %.3f" % [booth.name, back, place[2] * tiles])
		if box.position.x < place[0] - 0.01 or box.end.x > place[1] + 0.01:
			wrong.append("%s: x %.2f…%.2f" % [booth.name, box.position.x, box.end.x])
		var windows: Array = booth.get_meta("windows", [])
		if windows.size() != place[3]:
			wrong.append("%s: %d windows" % [booth.name, windows.size()])
		if not _footprint_fits(booth, box):
			wrong.append("%s: no footprint over its box %s" % [booth.name, box])
		var facing: Vector3 = booth.get_meta("facing", Vector3.ZERO)
		if facing.distance_to(Vector3(0.0, 0.0, -place[2])) > 0.01:
			wrong.append("%s: facing %s" % [booth.name, facing])
		for w: Vector3 in windows:
			# (The queue's room: from the counter's edge out, a window wide, a head tall.)
			var room := AABB(Vector3(w.x - QUEUE.y / 2.0, hall_floor + 0.1, minf(w.z, w.z + facing.z * QUEUE.x)),
				Vector3(QUEUE.y, 1.9, QUEUE.x))
			var shape := BoxShape3D.new()
			shape.size = room.size
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = shape
			q.transform = station.global_transform * Transform3D(Basis.IDENTITY, room.get_center())
			var player: CharacterBody3D = station.get("player")
			if player != null:
				q.exclude = [player.get_rid()]
			if not station.get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty():
				crowded.append("%s at x %.1f: solid" % [booth.name, w.x])
			for b: Dictionary in drawn["boxes"]:
				if (b["aabb"] as AABB).intersects(room):
					crowded.append("%s at x %.1f: %s" % [booth.name, w.x, b["kind"]])
	_check("S7 the taquillas against their walls, their windows facing the hall", wrong.is_empty(), "%s" % [wrong])
	_check("S7b a queue's room in front of every window", crowded.is_empty() and not (booths as Array).is_empty(),
		"%s" % [crowded.slice(0, 6)])


## Task 4: the Company's cable runs.
## S10: six runs, each from the engine's crown junction to the piece it powers (its last point within 1 m of that
## piece), an arc riding it in the Company's blue, its light among the station's lights. S10b: every point of every run,
## and every 0.25 m between, at least 2.4 m over the floor under it (the booths' roofs looked through).
const ENGINE_TERMINAL := Vector3(0.0, 9.45, 0.0)


func _runs() -> void:
	var runs = station.get("runs")
	var wrong := []
	var low := []
	if runs == null or (runs as Array).size() != 6:
		_check("S10 the Company's six cable runs from the engine", false, "runs %s" % [runs])
		return
	# (A booth's roof and a turnstile pylon are no walks: looked through to the floor.)
	var roofs := []
	# (The engine takes the runs in at its crown: its works are no floor under them.)
	var engine_parts: Array = [station.engine] if station.get("engine") != null else []
	for piece: Node3D in station.taquillas + station.turnstiles + engine_parts:
		for body: StaticBody3D in piece.find_children("*", "StaticBody3D", true, false):
			roofs.append(body.get_rid())
	for run: Node3D in runs:
		var points: PackedVector3Array = run.get_meta("points", PackedVector3Array())
		var to := String(run.get_meta("to", ""))
		var arc = run.get_meta("arc") if run.has_meta("arc") else null
		if points.is_empty() or points[0].distance_to(ENGINE_TERMINAL) > 0.05:
			wrong.append("%s starts at %s" % [run.name, points[0] if not points.is_empty() else null])
			continue
		var end := points[points.size() - 1]
		var near := station.find_children(to + "*", "Node3D", true, false).filter(func(n):
			if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
				var box: AABB = station.global_transform.affine_inverse() * (n as Node3D).global_transform * (n as MeshInstance3D).mesh.get_aabb()
				return box.grow(1.0).has_point(end)
			return (n as Node3D).position.distance_to(end) < 1.0)
		if near.is_empty():
			wrong.append("%s ends at %s, no %s there" % [run.name, end, to])
		# (The user, Oct 31: "remove the tesla arcs, add more cables": a bundle of cables, no arc.)
		if arc != null or int(run.get_meta("cables", 0)) < 3:
			wrong.append("%s: arc %s, %d cables" % [run.name, arc, int(run.get_meta("cables", 0))])
		for k in points.size() - 1:
			var a := points[k]
			var b := points[k + 1]
			var steps := maxi(1, int(ceil(a.distance_to(b) / 0.25)))
			for j in steps + 1:
				var p := a.lerp(b, float(j) / steps)
				var under := _floor_under(p, roofs)
				if under != -INF and p.y - under < 2.4:
					low.append("%s at %s: %.2f over the floor" % [run.name, p, p.y - under])
	# S10c: no run through a hanging board (its cable's tube clear of every neon board's box by 3 cm).
	var boards := station.find_children("*", "MeshInstance3D", true, false).filter(func(m):
		return m.get_meta("kind", "") == "neon_board")
	var through := []
	for run: Node3D in runs:
		var points: PackedVector3Array = run.get_meta("points", PackedVector3Array())
		for k in points.size() - 1:
			for j in 9:
				var p := points[k].lerp(points[k + 1], j / 8.0)
				for board: MeshInstance3D in boards:
					var box: AABB = station.global_transform.affine_inverse() * board.global_transform * board.mesh.get_aabb()
					if box.grow(0.032 + 0.03).has_point(p):
						through.append("%s at %s by %s" % [run.name, p, board.name])
	_check("S10c no run through a hanging board", through.is_empty(), "%d: %s" % [through.size(), through.slice(0, 4)])
	_check("S10 the Company's six cable runs from the engine", wrong.is_empty(), "%s" % [wrong.slice(0, 6)])
	_check("S10b every run 2.4 m over the walks", low.is_empty(), "%d: %s" % [low.size(), low.slice(0, 5)])
	var arcs := station.find_children("*", "Node3D", true, false).filter(func(n): return n.get_script() == TeslaArcScript)
	_check("S10d no tesla arc in the station", arcs.is_empty(), "%d" % arcs.size())

	# S10e: the Company's pipe racks along the hall's long walls and the platforms' back walls: on their wall's face
	# (within 0.6 m), 2.4 m over the floor at least, clear of every run and every hanging board.
	var racks = station.get("racks")
	var bad := []
	if racks == null or (racks as Array).size() < 6:
		bad.append("racks %s" % [racks])
		racks = []
	for rack: MeshInstance3D in racks:
		var box: AABB = station.global_transform.affine_inverse() * rack.global_transform * rack.mesh.get_aabb()
		var face := 14.0 - float(station.WALL) - 0.032
		var wall_z := box.end.z if box.get_center().z > 0.0 else box.position.z
		if absf(absf(wall_z) - face) > 0.6:
			bad.append("%s off its wall: z %.2f" % [rack.name, wall_z])
		var under := _floor_under(Vector3(box.get_center().x, box.position.y - 0.01, box.get_center().z), roofs)
		if under != -INF and box.position.y - under < 2.4:
			bad.append("%s %.2f over the floor" % [rack.name, box.position.y - under])
		for run: Node3D in runs:
			for p: Vector3 in run.get_meta("points", PackedVector3Array()):
				if box.grow(0.05).has_point(p):
					bad.append("%s crosses %s at %s" % [rack.name, run.name, p])
					break
		for board: MeshInstance3D in boards:
			var other: AABB = station.global_transform.affine_inverse() * board.global_transform * board.mesh.get_aabb()
			if other.intersects(box):
				bad.append("%s through %s" % [rack.name, board.name])
	_check("S10e the Company's pipe racks on the walls", bad.is_empty(), "%s" % [bad.slice(0, 6)])
	await _machine(runs, boards, roofs)


## The user, Oct 31: "it needs more, on the ceiling, on the walls, bigger, the feel of a large machine being operated;
## some big pipe mouths in the floor spewing fuel or fumes".
## S10f: the ceiling's mains (2 at least): under the coffers' beams, 3.2 m over the hall's floor, clear of every run,
## hanging board, blade sign and Company lamp. S10g: the risers (8 at least): each from its floor into its ceiling,
## within 1.2 m of its wall, clear of the doors, the booths, the maps and tablets, the lamps and the racks. S10h: the
## floor's pipe mouths (6 at least): solid, standing on their floor, fuming (a Fumes at their mouth, uninterpolated),
## 1.5 m clear of the stair heads, the corridors' and market's mouths, the lanes' approaches and the booths' queues, and
## on a platform 1.5 m back from its edge.
func _machine(runs: Array, boards: Array, roofs: Array) -> void:
	var hall_floor: float = station.spaces()["hall"]["floor"]
	var hall_top := hall_floor + float(station.spaces()["hall"]["height"])
	var avoid := station.find_children("*", "MeshInstance3D", true, false).filter(func(m):
		var kind := String(m.get_meta("kind", ""))
		return kind in ["neon_board", "blade_company", "ward_bracket", "taquilla_east", "taquilla_west", "bank_east",
			"bank_west"] or kind.begins_with("rack_"))
	var drawn := _drawn()
	var mains = station.get("mains")
	var risers = station.get("risers")
	var mouths = station.get("mouths")
	var wrong := []
	if mains == null or (mains as Array).size() < 6:
		wrong.append("mains %s" % [mains])
		mains = []
	for main: MeshInstance3D in mains:
		var box := _set_box(main)
		var low := hall_floor if box.position.y > hall_floor else 0.0
		var high := hall_top if box.position.y > hall_floor else float(station.spaces()["platform_n"]["height"])
		# (Its pipe under the coffers' beams the kit checks; its hanging rods reach the ceiling.)
		if box.position.y < low + 2.4 or box.end.y > high + 0.001:
			wrong.append("%s spans y %.2f…%.2f" % [main.name, box.position.y, box.end.y])
		# (A main's box spans its branches: what counts is any of its own points inside another piece.)
		wrong += _crossing(main.name, box, runs, [])
		wrong += _points_in(main, avoid.filter(func(m): return not String(m.get_meta("kind", "")).begins_with("rack_")))
	_check("S10f the ceiling's mains", wrong.is_empty(), "%s" % [wrong.slice(0, 6)])

	wrong = []
	if risers == null or (risers as Array).size() < 8:
		wrong.append("risers %s" % [risers])
		risers = []
	var face := 14.0 - float(station.WALL) - 0.032
	for riser: MeshInstance3D in risers:
		var box := _set_box(riser)
		var space := "hall" if box.position.y > hall_floor - 1.0 else "platform"
		var floor_y := hall_floor if space == "hall" else 0.0
		var top := hall_top if space == "hall" else floor_y + float(station.spaces()["platform_n"]["height"])
		if absf(box.position.y - floor_y) > 0.05 or box.end.y < top - 0.05:
			wrong.append("%s spans y %.2f…%.2f" % [riser.name, box.position.y, box.end.y])
		var near := absf(absf(box.get_center().z) - face)
		if near > 1.2:
			wrong.append("%s %.2f off its wall" % [riser.name, near])
		# (Its body, the pipe itself: its straps reach back to the wall over and under the racks, which pass behind it.)
		var side := signf(box.get_center().z)
		var body := AABB(Vector3(box.get_center().x - RISER.x, box.position.y, side * (face - RISER.y) - RISER.x),
			Vector3(2.0 * RISER.x, box.size.y, 2.0 * RISER.x))
		wrong += _crossing(riser.name, body, runs, avoid)
		for b: Dictionary in drawn["boxes"]:
			if String(b["kind"]) in ["line_map", "name_tablet"] and (b["aabb"] as AABB).intersects(box):
				wrong.append("%s over a %s" % [riser.name, b["kind"]])
		for record in station.spaces().values():
			for gap: Dictionary in record.get("gaps", []):
				var a := Vector2(gap["a"][0], gap["a"][1])
				var c := Vector2(gap["b"][0], gap["b"][1])
				var door := AABB(Vector3(minf(a.x, c.x), float(gap["y0"]) + 14.0, minf(a.y, c.y)) - Vector3(0.0, 0.0, 0.0),
					Vector3(absf(a.x - c.x), float(gap["y1"]) - float(gap["y0"]), absf(a.y - c.y))).grow(0.6)
				if door.intersects(box):
					wrong.append("%s in the door to %s" % [riser.name, gap["to"]])
	_check("S10g the walls' risers", wrong.is_empty(), "%s" % [wrong.slice(0, 6)])

	wrong = []
	if mouths == null or (mouths as Array).size() < 6:
		wrong.append("mouths %s" % [mouths])
		mouths = []
	var keep_clear := [Vector2(-6.0, -12.5), Vector2(6.0, 12.5), Vector2(-29.0, 0.0), Vector2(29.0, 0.0),
		Vector2(-10.0, 12.5)]
	for mouth: MeshInstance3D in mouths:
		var box := _set_box(mouth)
		# (Probed beside it along the wall, away from its feed.)
		var on := _floor_under(Vector3(box.position.x - 0.3, box.position.y + 0.3, box.get_center().z))
		if absf(box.position.y - on) > 0.03:
			wrong.append("%s stands at %.2f over a floor at %.2f" % [mouth.name, box.position.y, on])
		if mouth.find_children("*", "StaticBody3D", true, false).is_empty():
			wrong.append("%s not solid" % mouth.name)
		var fumes := mouth.find_children("*", "Node3D", true, false).filter(func(n): return n is Fumes)
		if fumes.is_empty():
			wrong.append("%s does not fume" % mouth.name)
		var foot := Rect2(box.position.x, box.position.z, box.size.x, box.size.z).grow(1.5)
		for at: Vector2 in keep_clear:
			if box.position.y > hall_floor - 1.0 and foot.has_point(at):
				wrong.append("%s within 1.5 m of %s" % [mouth.name, at])
		for bank_x in [-14.0, 14.0]:
			if box.position.y > hall_floor - 1.0 and foot.intersects(Rect2(bank_x - 2.0, -4.0, 4.0, 8.0)):
				wrong.append("%s in a lane's approach" % mouth.name)
		for booth: Node3D in station.taquillas:
			for w: Vector3 in booth.get_meta("windows", []):
				var queue := Rect2(w.x - 0.5, minf(w.z, w.z + (booth.get_meta("facing") as Vector3).z * 2.0), 1.0, 2.0)
				if foot.intersects(queue):
					wrong.append("%s in %s's queue" % [mouth.name, booth.name])
		if box.position.y < hall_floor - 1.0 and minf(absf(box.position.z), absf(box.end.z)) < float(station.EDGE_Z) + 1.5:
			wrong.append("%s within 1.5 m of the platform's edge" % mouth.name)
	_check("S10h the floor's pipe mouths fuming", wrong.is_empty(), "%s" % [wrong.slice(0, 6)])

	# The user, Oct 31: "more engrained towards the terrain, same with the cables, a bit more".
	# S10i: the floor's mains along the walls' feet: half sunk (diving under the floor), never more than 0.3 m over it
	# (a step), no point of them over the floor in a door, in a booth or under a bank's railing; every fume mouth fed by
	# a pipe of its own (meta "feed").
	wrong = []
	var floor_mains = station.get("floor_mains")
	if floor_mains == null or (floor_mains as Array).size() < 4:
		wrong.append("floor mains %s" % [floor_mains])
		floor_mains = []
	var blocked := []
	for record in station.spaces().values():
		for gap: Dictionary in record.get("gaps", []):
			var a := Vector2(gap["a"][0], gap["a"][1])
			var c := Vector2(gap["b"][0], gap["b"][1])
			blocked.append(AABB(Vector3(minf(a.x, c.x), float(gap["y0"]) + 14.0 + 0.02, minf(a.y, c.y)),
				Vector3(absf(a.x - c.x), 3.0, absf(a.y - c.y))).grow(0.25))
	for piece: Node3D in station.taquillas:
		blocked.append(_set_box(piece as MeshInstance3D).grow(-0.01))
	# (A bank meets the walls only with its railing's curb and newels, 0.22 m wide.)
	for bank: Node3D in station.turnstiles:
		var b := _set_box(bank as MeshInstance3D)
		blocked.append(AABB(Vector3(b.get_center().x - 0.15, b.position.y + 0.02, b.position.z), Vector3(0.3, b.size.y, b.size.z)))
	for main: MeshInstance3D in floor_mains:
		var box := _set_box(main)
		var floor_y := hall_floor if box.end.y > hall_floor - 1.0 else 0.0
		if box.position.y > floor_y - 0.1 or box.end.y > floor_y + 0.3:
			wrong.append("%s spans y %.2f…%.2f over a floor at %.1f" % [main.name, box.position.y, box.end.y, floor_y])
		var to_set := station.global_transform.affine_inverse() * main.global_transform
		var seen := {}
		for v: Vector3 in main.mesh.get_faces():
			var p := to_set * v
			if p.y < floor_y + 0.02:
				continue
			for k in blocked.size():
				if not seen.has(k) and (blocked[k] as AABB).has_point(p):
					seen[k] = true
					wrong.append("%s over the floor in %s" % [main.name, blocked[k]])
	for mouth: MeshInstance3D in mouths:
		if not mouth.has_meta("feed"):
			wrong.append("%s unfed" % mouth.name)
	_check("S10i the floor's mains, half sunk, feeding the mouths", wrong.is_empty(), "%s" % [wrong.slice(0, 6)])

	# S10j: the cable trays under the coffers, from the engine's place to the hall's end walls, each carrying 5 cables
	# at least, 2.4 m over the floor.
	wrong = []
	var trays = station.get("trays")
	if trays == null or (trays as Array).size() < 2:
		wrong.append("trays %s" % [trays])
		trays = []
	for tray: MeshInstance3D in trays:
		var box := _set_box(tray)
		if box.position.y < hall_floor + 2.4 or box.end.y > hall_top + 0.001:
			wrong.append("%s spans y %.2f…%.2f" % [tray.name, box.position.y, box.end.y])
		if minf(absf(box.position.x), absf(box.end.x)) > 3.6 or maxf(absf(box.position.x), absf(box.end.x)) < 29.4:
			wrong.append("%s spans x %.1f…%.1f" % [tray.name, box.position.x, box.end.x])
		if int(tray.get_meta("cables", 0)) < 5:
			wrong.append("%s carries %d" % [tray.name, int(tray.get_meta("cables", 0))])
		wrong += _crossing(tray.name, box, runs, avoid)
	_check("S10j the cable trays", wrong.is_empty(), "%s" % [wrong.slice(0, 6)])


## A piece's mesh box in the set's frame.
func _set_box(piece: MeshInstance3D) -> AABB:
	return station.global_transform.affine_inverse() * piece.global_transform * piece.mesh.get_aabb()


## The points of `piece` inside any of `others`' boxes (a long piece checked by its own geometry).
func _points_in(piece: MeshInstance3D, others: Array) -> Array:
	var out := []
	var to_set := station.global_transform.affine_inverse() * piece.global_transform
	var faces := piece.mesh.get_faces()
	for other: MeshInstance3D in others:
		var box := _set_box(other).grow(-0.01)
		if not box.intersects(_set_box(piece)):
			continue
		for v: Vector3 in faces:
			if box.has_point(to_set * v):
				out.append("%s through %s" % [piece.name, other.name])
				break
	return out


## What `box` (named `name`) crosses: a run's path, or another piece's box.
func _crossing(name: String, box: AABB, runs: Array, pieces: Array) -> Array:
	var out := []
	for run: Node3D in runs:
		for p: Vector3 in run.get_meta("points", PackedVector3Array()):
			if box.grow(0.05).has_point(p):
				out.append("%s crosses %s at %s" % [name, run.name, p])
				break
	# (A long piece's box spans its whole wall: what counts is any of its own points inside this box.)
	var inside := box.grow(-0.01)
	for piece: MeshInstance3D in pieces:
		if not _set_box(piece).intersects(box):
			continue
		var to_set := station.global_transform.affine_inverse() * piece.global_transform
		for v: Vector3 in piece.mesh.get_faces():
			if inside.has_point(to_set * v):
				out.append("%s through %s" % [name, piece.name])
				break
	return out


## A riser's radius and its middle out from its wall's plaster (tools/eclipse/station_pipes.py's RISER).
const RISER := Vector2(0.3, 0.75)
## The neon boards' faces (tools/eclipse/station_neon.py's NEON_FACE, and its middle under the ceiling).
const NEON_FACE := Vector2(2.3, 0.54)
const NEON_FACE_MIDDLE := 0.91


## Task 2 (docs/superpowers/plans/2026-10-31-station-machinery.md): the station's signs in neon.
## S9: every hanging direction sign carries, within 0.5 m of its board, an arrow and one symbol on each face; a Company
## blade sign stands on each turnstile bank's pylon; every sign is silent, lights with at least 3 m of reach, its light
## among the station's lights.
func _neon() -> void:
	var signs = station.get("neon")
	var boards = station.get("sign_boards")
	var wrong := []
	if signs == null or boards == null or (boards as Array).is_empty():
		_check("S9 the station's signs in neon", false, "neon %s, boards %s" % [signs, boards])
		return
	for board: Transform3D in boards:
		var near := (signs as Array).filter(func(n): return (n as Node3D).global_transform.origin.distance_to(
			station.global_transform * board.origin) < 1.6)
		var arrows := near.filter(func(n): return String(n.get_meta("symbol", "")) == "arrow")
		var symbols := near.filter(func(n): return not String(n.get_meta("symbol", "")) in ["", "arrow"])
		if arrows.size() != 2 or symbols.size() != 2:
			wrong.append("board at %s: %d arrows, %d symbols" % [board.origin, arrows.size(), symbols.size()])
		# (Read from across the hall at half again their drawn size, the user, Oct 31: "enlarge the symbols", and "make
		# sure they fit on the board": on a board of their own, each one's whole tube inside the board's face.)
		var on := station.find_children("*", "MeshInstance3D", true, false).filter(func(m):
			return m.get_meta("kind", "") == "neon_board" and (m as Node3D).transform.origin.distance_to(board.origin) < 0.01)
		if on.is_empty():
			wrong.append("board at %s: no neon board" % board.origin)
		for sign in arrows + symbols:
			var tube := (sign as Node3D).get_node_or_null("tube") as MeshInstance3D
			var box: AABB = board.affine_inverse() * (sign as Node3D).transform * tube.transform * tube.mesh.get_aabb()
			if maxf(box.size.x, box.size.y) < 0.45:
				wrong.append("board at %s: %s too small" % [board.origin, sign.get_meta("symbol", "")])
			if box.position.x < -NEON_FACE.x / 2.0 or box.end.x > NEON_FACE.x / 2.0 \
					or box.position.y < -NEON_FACE_MIDDLE - NEON_FACE.y / 2.0 or box.end.y > -NEON_FACE_MIDDLE + NEON_FACE.y / 2.0:
				wrong.append("board at %s: %s off its face %s" % [board.origin, sign.get_meta("symbol", ""), box])
	for bank: Node3D in station.turnstiles:
		var bladed := (signs as Array).any(func(n): return String(n.get_meta("on", "")) == bank.name)
		if not bladed:
			wrong.append("%s: no blade sign" % bank.name)
	for sign in signs:
		if not sign is NeonSign:
			wrong.append("%s is no NeonSign" % sign)
			continue
		var neon := sign as NeonSign
		if neon.buzz != &"" or neon.light_energy <= 0.0 or neon.light_range < 3.0 or not station.lights.has(neon.light):
			wrong.append("%s: buzz %s, light %.1f / %.1f, listed %s" % [neon.name, neon.buzz, neon.light_energy,
				neon.light_range, station.lights.has(neon.light)])
	_check("S9 the station's signs in neon", wrong.is_empty(), "%d signs; %s" % [(signs as Array).size(),
		wrong.slice(0, 6)])


## A piece's "footprint" (Rect2 in the set's x-z, for the crowd's routes) is its meshes' box seen from above.
func _footprint_fits(piece: Node3D, box: AABB) -> bool:
	if not piece.has_meta("footprint") or not piece.get_meta("footprint") is Rect2:
		return false
	var footprint: Rect2 = piece.get_meta("footprint")
	var want := Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
	return footprint.position.distance_to(want.position) < 0.02 and footprint.size.distance_to(want.size) < 0.02


## Task 8: the turnstile banks.
## The banks' places (the plan's): across the hall at x -14 (the west, its north half fused open) and x 14 (the east);
## the lanes each has, and those of the west's fused (the hall's z -4…0).
const BANKS := {"west": -14.0, "east": 14.0}
const LANES := 4
## Every lane clear at least this wide (m): the player's capsule and a hand.
const LANE_CLEAR := 1.1


## S8: each bank stands across the hall at its x, from wall to wall, closed beside its lanes (a ray across its railings
## meets it), its four lanes each at least 1.1 m clear from the floor to 2 m (rays across the bank every centimetre).
## S8b: the player walks through every lane, both ways. S8c: a working lane's arms turn a third as the player passes,
## seen turned (interpolation off: they turn between ticks); the fused lanes (the west's north half) have no arms that
## turn.
func _turnstiles() -> void:
	var banks = station.get("turnstiles")
	var wrong := []
	var narrow := []
	var stuck := []
	var turns := []
	var walls := 14.0 - float(station.WALL) - 0.067
	var hall_floor: float = station.spaces()["hall"]["floor"]
	if banks == null or (banks as Array).size() != BANKS.size():
		wrong.append("banks: %s" % [banks])
		banks = []
	for bank: Node3D in banks:
		var side: String = bank.get_meta("side", "")
		if not BANKS.has(side):
			wrong.append("%s: no side" % bank.name)
			continue
		var x: float = BANKS[side]
		var box := _box_of(bank)
		if absf(box.get_center().x - x) > 0.3 or absf(box.position.z + walls) > 0.02 or absf(box.end.z - walls) > 0.02:
			wrong.append("%s: x %.2f…%.2f z %.3f…%.3f" % [bank.name, box.position.x, box.end.x, box.position.z,
				box.end.z])
		if not _footprint_fits(bank, box):
			wrong.append("%s: no footprint over its box %s" % [bank.name, box])
		# (Its railings' fret is open to see through; their curb and top bar close them, the staff gate's too.)
		for z in [-13.0, -10.0, -7.0, -5.0, 5.0, 7.0, 10.0, 13.0]:
			for h in [0.06, 0.94]:
				var hit := _ray(Vector3(x - 2.0, hall_floor + h, z), Vector3(x + 2.0, hall_floor + h, z))
				if absf(hit.x - x) > 1.0:
					wrong.append("%s: open at z %.1f, %.2f m up" % [bank.name, z, h])
		var lanes: Array = bank.get_meta("lanes", [])
		var arms: Array = bank.get_meta("arms", [])
		if lanes.size() != LANES or arms.size() != LANES:
			wrong.append("%s: %d lanes, %d arms" % [bank.name, lanes.size(), arms.size()])
			continue
		for k in LANES:
			var lane: Vector3 = lanes[k]
			var best := 0.0
			var run := 0.0
			for i in 151:
				var z := lane.z - 0.75 + i * 0.01
				var open := true
				for h in [0.1, 0.4, 0.7, 1.0, 1.3, 1.6, 1.9]:
					var from := Vector3(x - 2.0, hall_floor + h, z)
					var to := Vector3(x + 2.0, hall_floor + h, z)
					if _ray(from, to) != to:
						open = false
						break
				run = run + 0.01 if open else 0.0
				best = maxf(best, run)
			if best < LANE_CLEAR:
				narrow.append("%s lane %d: %.2f m" % [bank.name, k, best])
			# (Fused: the west bank's lanes north of the hall's middle, its z under 0.)
			var fused: bool = side == "west" and lane.z < 0.0
			var turner = arms[k]
			if fused != (turner == null):
				turns.append("%s lane %d: fused %s, arms %s" % [bank.name, k, fused, turner])
				continue
			for way in [1.0, -1.0]:
				var before: Basis = turner.global_transform.basis if turner != null else Basis.IDENTITY
				var walked := await _walk_path(Vector3(x - way * 2.5, hall_floor + 1.05, lane.z),
					[Vector3(x + way * 2.5, hall_floor + 1.05, lane.z)], 600)
				if not walked["ok"]:
					stuck.append("%s lane %d going %s: %s" % [bank.name, k, "east" if way > 0 else "west", walked])
				if turner == null:
					continue
				await _frames(60)
				var after: Basis = turner.global_transform.basis
				# (Either way round: a third back reads as two thirds forward.)
				var turned := (before.inverse() * after).get_rotation_quaternion().get_angle()
				turned = minf(turned, TAU - turned)
				if absf(turned - TAU / 3.0) > 0.05:
					turns.append("%s lane %d going %s: turned %.2f" % [bank.name, k, way, turned])
				if turner.physics_interpolation_mode != Node.PHYSICS_INTERPOLATION_MODE_OFF:
					turns.append("%s lane %d: arms interpolated" % [bank.name, k])
	_check("S8 the turnstile banks across the hall, every lane at least 1.1 m clear", wrong.is_empty() \
		and narrow.is_empty() and not (banks as Array).is_empty(), "%s %s" % [wrong.slice(0, 6), narrow])
	_check("S8b walked through every lane both ways", stuck.is_empty() and not (banks as Array).is_empty(),
		"%s" % [stuck.slice(0, 6)])
	_check("S8c the working arms turn a third as the player passes, the fused never", turns.is_empty() \
		and not (banks as Array).is_empty(), "%s" % [turns.slice(0, 6)])


## A node's meshes' box in the set's frame.
func _box_of(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for m in node.find_children("*", "MeshInstance3D", true, false) + ([node] if node is MeshInstance3D else []):
		var mesh := (m as MeshInstance3D).mesh
		if mesh == null:
			continue
		var aabb: AABB = station.global_transform.affine_inverse() * (m as Node3D).global_transform * mesh.get_aabb()
		box = aabb if first else box.merge(aabb)
		first = false
	return box


## S1: the shell at the plan's measure: its floors, its ceilings, and every gap of its spaces open (a ray through its
## middle passes), the wall beside it closed (0.5 m along from either end, where the gap does not run the wall's
## whole length).
func _shell() -> void:
	var wrong := []
	# Its floors: the platforms and the stairwells' feet at 0, the hall at 6, the bed at -1.2.
	for spot in [[Vector3(0.0, 2.0, -10.0), 0.0], [Vector3(-20.0, 2.0, 10.0), 0.0], [Vector3(-2.0, 2.0, -20.0), 0.0],
			[Vector3(-20.0, 8.0, -5.0), 6.0], [Vector3(-20.0, 0.5, -2.5), -1.2]]:
		var at: Vector3 = spot[0]
		var floor_y := _ray(at, at + Vector3(0.0, -4.0, 0.0)).y
		if absf(floor_y - float(spot[1])) > 0.02:
			wrong.append("floor at %s: %.2f" % [at, floor_y])
	# Its ceilings: the platforms' and the track's at 5.5, the hall's at 11.
	for spot in [[Vector3(-40.0, 2.0, -10.0), 5.5], [Vector3(-20.0, 1.0, -2.5), 5.5], [Vector3(-20.0, 8.0, -5.0), 11.0]]:
		var at: Vector3 = spot[0]
		var top := _ray(at, at + Vector3(0.0, 9.0, 0.0)).y
		if absf(top - float(spot[1])) > 0.02:
			wrong.append("ceiling over %s: %.2f" % [at, top])
	var spaces: Dictionary = station.spaces()
	for name: String in spaces:
		var record: Dictionary = spaces[name]
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for q in record["polygon"]:
			lo = Vector2(minf(lo.x, q[0]), minf(lo.y, q[1]))
			hi = Vector2(maxf(hi.x, q[0]), maxf(hi.y, q[1]))
		var middle_of := (lo + hi) / 2.0
		for gap: Dictionary in record["gaps"]:
			var a := Vector2(gap["a"][0], gap["a"][1])
			var b := Vector2(gap["b"][0], gap["b"][1])
			var along := (b - a).normalized()
			var out := Vector2(-along.y, along.x)
			if out.dot((a + b) / 2.0 - middle_of) < 0.0:
				out = -out
			var y := float(gap["y0"]) + 1.5
			var mid := (a + b) / 2.0
			var from := Vector3(mid.x - out.x, y, mid.y - out.y)
			var to := Vector3(mid.x + out.x * 1.5, y, mid.y + out.y * 1.5)
			if _ray(from, to).distance_to(to) > 0.01:
				wrong.append("%s's gap to %s shut" % [name, gap["to"]])
			# (Beside it, where its own run of wall goes on past it: a point on the outline's same edge.)
			var run: Array = _edge_of(record["polygon"], a, b)
			for side in [a - along * 0.5, b + along * 0.5]:
				var s: Vector2 = side
				# (Unless another of its gaps goes on there at that height: two gaps meeting end to end.)
				var in_next: bool = (record["gaps"] as Array).any(func(g): return g != gap \
					and Geometry2D.get_closest_point_to_segment(s, Vector2(g["a"][0], g["a"][1]),
						Vector2(g["b"][0], g["b"][1])).distance_to(s) < 0.01 and y >= float(g["y0"]) and y <= float(g["y1"]))
				if not in_next and not run.is_empty() and Geometry2D.get_closest_point_to_segment(s, run[0], run[1]).distance_to(s) < 0.01:
					var hit := _ray(Vector3(s.x - out.x, y, s.y - out.y), Vector3(s.x + out.x * 1.5, y, s.y + out.y * 1.5))
					if Vector2(hit.x, hit.z).distance_to(s) > 0.35:
						wrong.append("%s beside its gap to %s open" % [name, gap["to"]])
	_check("S1 the shell at the plan's measure, every gap of its spaces open", wrong.is_empty(),
		"%d: %s" % [wrong.size(), wrong.slice(0, 6)])


## S2: walked: along the arrival's platform both ways; up the north stairwell into the hall; across it and down the
## south stairwell onto the south platform.
func _walked() -> void:
	var east := await _walk_path(Vector3(0.0, 1.05, -9.0), [Vector3(40.0, 1.05, -9.0)], 2400)
	var west := await _walk_path(Vector3(0.0, 1.05, -9.0), [Vector3(-45.0, 1.05, -9.0)], 2400)
	var up_way: Array[Vector3] = [Vector3(-2.0, 1.05, -13.0), Vector3(-2.0, 1.05, -29.2), Vector3(-6.0, 1.05, -29.2),
		Vector3(-6.0, 1.05, -14.5), Vector3(-6.0, 1.05, -12.5)]
	var up := await _walk_path(Vector3(0.0, 1.05, -9.0), up_way, 3600)
	# (Round the engine at the hall's middle.)
	var down_way: Array[Vector3] = [Vector3(-6.5, 1.05, 6.5), Vector3(6.0, 1.05, 6.5), Vector3(6.0, 1.05, 12.5), Vector3(6.0, 1.05, 14.5), Vector3(6.0, 1.05, 29.2),
		Vector3(2.0, 1.05, 29.2), Vector3(2.0, 1.05, 13.0), Vector3(2.0, 1.05, 10.0)]
	var down := await _walk_path(Vector3(-6.0, 7.05, -12.5), down_way, 3600)
	var in_hall: bool = up["ok"] and absf(float(up["end"].y) - 7.05) < 0.15
	var on_south: bool = down["ok"] and absf(float(down["end"].y) - 1.05) < 0.15
	_check("S2 walked along the platform, up into the hall, across it and down onto the south platform",
		east["ok"] and west["ok"] and in_hall and on_south, "east %s west %s up %s down %s" % [east, west, up, down])
	# S2b: no lip where a flight arrives in the hall: along each flight's top into the hall, no step over 5 cm.
	var steps := []
	for flight in [[-6.0, -1.0], [6.0, 1.0]]:
		var x: float = flight[0]
		var sz: float = flight[1]
		var last := INF
		for k in 41:
			# (Off the exact planes two touching boxes share, where a ray slips between them.)
			var z := sz * (15.5125 - k * 0.05)
			# (From under the door's lintel, at 9.)
			var y := _ray(Vector3(x, 8.5, z), Vector3(x, 3.0, z)).y
			if last != INF and absf(y - last) > 0.05:
				steps.append("x %.0f z %.2f: %.2f -> %.2f" % [x, z, last, y])
			last = y
	_check("S2b no lip where either flight arrives in the hall", steps.is_empty(), "%s" % [steps])


## S3: each track's tunnel mouth at either end runs on into the dark: a ray along the track from inside the station
## passes its end and meets the black cap 10-13 m beyond it.
func _mouths() -> void:
	var wrong := []
	for track_z: float in station.TRACKS_Z:
		for end in [-1.0, 1.0]:
			var hit := _ray(Vector3(end * 45.0, 1.0, track_z), Vector3(end * 70.0, 1.0, track_z))
			if absf(hit.x) < 60.0 or absf(hit.x) > 63.0:
				wrong.append("track at z %.1f, end %d: met at x %.2f" % [track_z, end, hit.x])
	_check("S3 the tunnel mouths run on into the dark", wrong.is_empty(), "%s" % [wrong])


## Task 4: the shell dressed.
## S4: every run of wall the shell stands in its spaces dressed, tiled or plastered, every 1.2 m along it from a metre
## up to near its top (a run under 0.25 m, a jamb its reveal covers, excepted): sampled just in front of its face
## against where the dressing is drawn.
## S4b: no word on it: no Label3D or Decal under the set (its signs' faces are the kit's blank `sign` slot).
## S4c: nothing hung over a walk lower than 2.4 m over its floor.
func _dressed() -> void:
	var drawn := _drawn()
	var bare := []
	var faces: Array = station.get("faces") if station.get("faces") != null else []
	for face: Dictionary in faces:
		var a: Vector2 = face["a"]
		var b: Vector2 = face["b"]
		var length := a.distance_to(b)
		if length < 0.25:
			continue
		var along := (b - a) / length
		var inward: Vector2 = face["inward"]
		var s := minf(0.6, length / 2.0)
		while s < length:
			for y in [float(face["y0"]) + 1.0, float(face["y1"]) - 0.3]:
				var p := a + along * s + inward * 0.03
				var at := Vector3(p.x, y, p.y)
				if not _covered(drawn, at):
					bare.append("%s %s" % [face["space"], at.snapped(Vector3.ONE * 0.1)])
			s += 1.2
	_check("S4 tiled to every gap and corner, no run of wall left bare", not faces.is_empty() and bare.is_empty(),
		"%d faces; %d bare: %s" % [faces.size(), bare.size(), bare.slice(0, 6)])

	# (The player's own, standing in it when it stands alone, are not the set's.)
	var words: Array = (station.find_children("*", "Label3D", true, false) + station.find_children("*", "Decal", true, false)) \
		.filter(func(n): return not station.player.is_ancestor_of(n))
	_check("S4b no word on it", words.is_empty(), "%s" % [words.slice(0, 4)])

	var low := []
	# (A booth's roof, a riser's top and the engine's works are no walks: their bodies are looked through to the
	# floor.)
	var roofs := []
	var tops: Array = (station.get("taquillas") if station.get("taquillas") != null else []) \
		+ (station.get("risers") if station.get("risers") != null else []) \
		+ ([station.engine] if station.get("engine") != null else [])
	for piece: Node3D in tops:
		for body: StaticBody3D in piece.find_children("*", "StaticBody3D", true, false):
			roofs.append(body.get_rid())
	var floors := {}
	for name: String in station.spaces():
		floors[name] = station.spaces()[name]
	for box: Dictionary in drawn["boxes"]:
		if not box["kind"] in ["sign_board", "strip_fitting", "coffer", "ceiling_panel", "line_map"]:
			continue
		var aabb: AABB = box["aabb"]
		if box["kind"] == "line_map":
			continue
		var under := _floor_under(Vector3(aabb.get_center().x, aabb.position.y, aabb.get_center().z), roofs)
		if aabb.position.y - under < 2.4:
			low.append("%s at %s, %.2f over its floor" % [box["kind"], aabb.get_center().snapped(Vector3.ONE * 0.1),
				aabb.position.y - under])
	_check("S4c over the walks, nothing lower than 2.4 m", low.is_empty(), "%s" % [low.slice(0, 5)])

	# S4d: no bare end of wall or lintel's underside: each lined, or inside a door's reveal (sampled at its middle, a
	# hair in front of it).
	var reveals := (drawn["boxes"] as Array).filter(func(b): return String(b["kind"]).begins_with("reveal_"))
	var bare_ends := []
	for end: Dictionary in station.ends:
		var at: Vector2 = end["at"]
		var out: Vector2 = end["out"]
		var inward: Vector2 = end["inward"]
		var mid := at + inward * float(station.WALL) / 2.0 + out * 0.02
		var p := Vector3(mid.x, (float(end["y0"]) + float(end["y1"])) / 2.0, mid.y)
		if not _covered(drawn, p):
			bare_ends.append("end %s" % p.snapped(Vector3.ONE * 0.1))
	for head: Dictionary in station.heads:
		var a: Vector2 = head["from"]
		var b: Vector2 = head["to"]
		var inward: Vector2 = head["inward"]
		var mid := (a + b) / 2.0 + inward * float(station.WALL) / 2.0
		var p := Vector3(mid.x, float(head["y"]) - 0.02, mid.y)
		if not _covered(drawn, p):
			bare_ends.append("head %s" % p.snapped(Vector3.ONE * 0.1))
	_check("S4d no bare end of wall or lintel's underside", bare_ends.is_empty() and not station.ends.is_empty(),
		"%d ends, %d heads; bare %s" % [station.ends.size(), station.heads.size(), bare_ends.slice(0, 6)])

	# S4e: each ramp clad: its sides and its underside covered at every metre along it.
	var bare_ramps := []
	for ramp: MeshInstance3D in station.ramp_boxes:
		var size: Vector3 = (ramp.mesh as BoxMesh).size
		var t: Transform3D = ramp.transform
		var k := 0.5
		while k < size.z:
			var at: Vector3 = t.origin + t.basis.z * (k - size.z / 2.0)
			for p in [at + t.basis.x * (size.x / 2.0 + 0.02), at - t.basis.x * (size.x / 2.0 + 0.02),
					at - t.basis.y * (size.y / 2.0 + 0.02)]:
				if not _covered(drawn, p):
					bare_ramps.append("%s %s" % [ramp.name, (p as Vector3).snapped(Vector3.ONE * 0.1)])
			k += 1.0
	_check("S4e every ramp clad, its sides and underside", bare_ramps.is_empty() and not station.ramp_boxes.is_empty(),
		"%s" % [bare_ramps.slice(0, 6)])

	# S4f: each revealed door has its threshold.
	var sills := (drawn["boxes"] as Array).filter(func(b): return b["kind"] == "sill")
	var unsilled := []
	for reveal: Dictionary in reveals:
		var r: AABB = reveal["aabb"]
		var foot := Vector3(r.get_center().x, r.position.y + 0.005, r.get_center().z)
		if not sills.any(func(b): return (b["aabb"] as AABB).grow(0.02).has_point(foot)):
			unsilled.append(foot.snapped(Vector3.ONE * 0.1))
	_check("S4f every door has its threshold", unsilled.is_empty() and not reveals.is_empty(), "%s" % [unsilled])

	# S4g: the track steps' walls are the platform's where they stand over it: tiled a metre over the platform's floor,
	# plastered near their top, the pit's concrete only under the platform's floor.
	var platform: float = station.spaces()["platform_n"]["floor"]
	var wrong_notch := []
	var notch_faces := 0
	for face: Dictionary in faces:
		if not String(face["space"]).begins_with("track_notch") or float(face["y1"]) < platform + 2.0:
			continue
		notch_faces += 1
		var a: Vector2 = face["a"]
		var b: Vector2 = face["b"]
		var p: Vector2 = (a + b) / 2.0 + (face["inward"] as Vector2) * 0.03
		for want: Array in [[platform - 1.0, "pit_face"], [platform + 1.0, "wall_low"], [float(face["y1"]) - 0.3, "plaster_sheet"]]:
			var at := Vector3(p.x, want[0], p.y)
			var kinds := _kinds_at(drawn, at)
			if not kinds.any(func(k): return String(k).begins_with(want[1])):
				wrong_notch.append("%s %s: %s, wanted %s" % [face["space"], at.snapped(Vector3.ONE * 0.1), kinds, want[1]])
	_check("S4g the track steps' walls the platform's over its floor", notch_faces > 0 and wrong_notch.is_empty(),
		"%d faces; %s" % [notch_faces, wrong_notch.slice(0, 6)])

	# S4h: each cut the track steps go down is guarded where it lies open over its drop: a guard rail along its rim on
	# the platform and along its parapet, every metre of them; the parapet capped; the rim coped (the yellow line round
	# the drop).
	# S4i: nothing stands over the parapet but its rail (no wall's end lined up to the ceiling there).
	var unguarded := []
	var over_parapet := []
	for notch: String in ["track_notch_n", "track_notch_s"]:
		var sz := -1.0 if notch == "track_notch_n" else 1.0
		var xs := []
		for q in station.spaces()[notch]["polygon"]:
			xs.append(float(q[0]))
		var x0: float = xs.min()
		var x1: float = xs.max()
		var rim_z: float = sz * (float(station.EDGE_Z) + float(station.CUT_DEEP))
		var parapet_z: float = sz * (float(station.EDGE_Z) + float(station.WALL) / 2.0)
		# (The parapet runs from the head to the steps' foot, the last 2 m open onto the bed.)
		var p0 := x0 if sz < 0.0 else x0 + float(station.FOOT)
		var p1 := x1 - float(station.FOOT) if sz < 0.0 else x1
		var x := x0 + 0.5
		while x < x1:
			var rim := Vector3(x, platform + 1.0, rim_z + sz * 0.1)
			if not _kinds_at(drawn, rim).has("guard_rail"):
				unguarded.append("%s rail on the rim %s" % [notch, rim.snapped(Vector3.ONE * 0.1)])
			var coped := Vector3(x, platform + 0.005, rim_z + sz * 0.3)
			if not _kinds_at(drawn, coped).has("coping"):
				unguarded.append("%s rim uncoped %s" % [notch, coped.snapped(Vector3.ONE * 0.1)])
			if x > p0 + 0.2 and x < p1 - 0.2:
				var rail := Vector3(x, platform + 1.0, parapet_z)
				if not _kinds_at(drawn, rail).has("guard_rail"):
					unguarded.append("%s rail on the parapet %s" % [notch, rail.snapped(Vector3.ONE * 0.1)])
				var cap := Vector3(x, platform + 0.005, parapet_z)
				if not _kinds_at(drawn, cap).has("parapet_cap"):
					unguarded.append("%s parapet uncapped %s" % [notch, cap.snapped(Vector3.ONE * 0.1)])
				for y in [platform + 1.6, platform + 3.0]:
					var above := Vector3(x, y, parapet_z)
					if not _kinds_at(drawn, above).is_empty():
						over_parapet.append("%s %s: %s" % [notch, above.snapped(Vector3.ONE * 0.1), _kinds_at(drawn, above)])
			x += 1.0
		# (Its end at the steps' foot: lined only as high as it stands.)
		var end_x := p1 + 0.02 if sz < 0.0 else p0 - 0.02
		for y in [platform + 1.6, platform + 3.0]:
			var above_end := Vector3(end_x, y, parapet_z)
			if not _kinds_at(drawn, above_end).is_empty():
				over_parapet.append("%s end %s: %s" % [notch, above_end.snapped(Vector3.ONE * 0.1), _kinds_at(drawn, above_end)])
	# S4j: the track steps stand clear of their cut's walls (the parapet's face toward them, the pit's face under the
	# rim), their handrails clear of the guard rails over them.
	var crowded := []
	for ramp: MeshInstance3D in station.ramp_boxes:
		if not String(ramp.name).begins_with("track_steps"):
			continue
		var sz := -1.0 if ramp.name == "track_steps_n" else 1.0
		var half: float = (ramp.mesh as BoxMesh).size.x / 2.0
		var across := absf(ramp.transform.origin.z)
		var inner := across - half
		var outer := across + half
		var parapet_face: float = float(station.EDGE_Z) + float(station.WALL) + 0.04
		var rim_face: float = float(station.EDGE_Z) + float(station.CUT_DEEP) - 0.04
		if inner < parapet_face + 0.1 or outer > rim_face - 0.1:
			crowded.append("%s spans |z| %.2f..%.2f, the cut's clear %.2f..%.2f" % [ramp.name, inner, outer, parapet_face,
				rim_face])
		for box: Dictionary in drawn["boxes"]:
			if box["kind"] != "handrail" or absf((box["aabb"] as AABB).get_center().x - ramp.transform.origin.x) > 3.0:
				continue
			var z := absf((box["aabb"] as AABB).get_center().z)
			if absf(z - across) < 2.0 and (absf(z - float(station.EDGE_Z) - float(station.WALL) / 2.0) < 0.3 \
					or absf(z - float(station.EDGE_Z) - float(station.CUT_DEEP) - 0.1) < 0.3):
				crowded.append("%s handrail at |z| %.2f on a guard rail's line" % [ramp.name, z])
				break
	_check("S4j the track steps clear of their cut's walls and rails", crowded.is_empty(), "%s" % [crowded])
	_check("S4h the track steps' cut railed, its parapet capped, its rim coped", unguarded.is_empty(),
		"%s" % [unguarded.slice(0, 6)])
	_check("S4i nothing over the parapet but its rail", over_parapet.is_empty(), "%s" % [over_parapet.slice(0, 6)])


## Task 6: the station's light.
## S6: every walk lit: each of S2's waypoints, a metre over its floor, within 70 % of some station light's reach, that
## light's own level (none lit from another floor through a slab).
## S6b: the tunnel mouths dark: no light within 6 m of a mouth's far half.
## S6c: the light in budget: at most 40 shadowless lights and at most 2 with shadows.
## S6d: no light through a floor: each light lights its own level's layer (and the world's movers: the player, actors,
## hands, effects, the lightgem's probe) and never another level's; every dressing piece is on its level's layer.
## S6e: the fittings glow: every fluorescent tube's surface emits.
func _lit() -> void:
	var lights: Array = station.get("lights") if station.get("lights") != null else []
	var hall: int = Layers.STATION_HALL
	var stairs: int = Layers.STATION_STAIRS
	var below: int = Layers.STATION_BELOW
	var levels := hall | stairs | below
	var dark := []
	var walks := [[Vector3(0.0, 1.0, -9.0), below], [Vector3(40.0, 1.0, -9.0), below], [Vector3(-45.0, 1.0, -9.0), below],
		[Vector3(-2.0, 1.0, -20.0), stairs], [Vector3(-2.0, 1.0, -29.0), stairs], [Vector3(-6.0, 4.0, -21.0), stairs],
		[Vector3(-6.0, 7.0, -12.5), hall], [Vector3(6.0, 7.0, 12.5), hall], [Vector3(-25.0, 7.0, 0.0), hall],
		[Vector3(25.0, 7.0, 0.0), hall], [Vector3(0.0, 7.0, 0.0), hall], [Vector3(2.0, 1.0, 29.0), stairs],
		[Vector3(2.0, 1.0, 10.0), below], [Vector3(-40.0, 1.0, 10.0), below], [Vector3(40.0, 1.0, 10.0), below]]
	for walk in walks:
		var at: Vector3 = walk[0]
		var lit := lights.any(func(l): return (l as Light3D).light_cull_mask & int(walk[1]) != 0 \
			and (l as Node3D).position.distance_to(at) < 0.7 * _reach(l))
		if not lit:
			dark.append(at)
	_check("S6 every walk lit by its own level's light", not lights.is_empty() and dark.is_empty(), "%d lights; dark %s" % [
		lights.size(), dark])

	var near_mouth := []
	for light: Light3D in lights:
		for end in [-1.0, 1.0]:
			for z: float in station.TRACKS_Z:
				var far_half := Vector3(end * (50.0 + station.DARK_RUN * 0.75), 1.0, z)
				if light.position.distance_to(far_half) < 6.0:
					near_mouth.append(light.name)
	_check("S6b the tunnel mouths dark", near_mouth.is_empty(), "%s" % [near_mouth])

	var plain := lights.filter(func(l): return not (l as Light3D).shadow_enabled).size()
	var shadowed := lights.size() - plain
	# (The budget is suspended, the user, Oct 31: "I don't mind cost, we can optimize rendering later": a report.)
	_check("S6c the light counted", true, "%d shadowless, %d shadowed" % [plain, shadowed])

	var leaks := []
	for light: Light3D in lights:
		var own: int = light.light_cull_mask & levels
		if own != hall and own != stairs and own != below:
			leaks.append("%s lights levels %d" % [light.name, own])
		if light.light_cull_mask & (Layers.WORLD | Layers.ACTORS | Layers.VIEWMODEL | Layers.GEM_PROBE) \
				!= (Layers.WORLD | Layers.ACTORS | Layers.VIEWMODEL | Layers.GEM_PROBE):
			leaks.append("%s misses the movers" % light.name)
	for node in station.find_children("*", "MultiMeshInstance3D", true, false):
		var on: int = (node as VisualInstance3D).layers
		if on & levels == 0 or on & Layers.WORLD != 0:
			leaks.append("%s on layers %d" % [node.name, on])
	_check("S6d no light through a floor", leaks.is_empty(), "%s" % [leaks.slice(0, 6)])

	var unlit := []
	for node in station.find_children("*", "MultiMeshInstance3D", true, false):
		if not node.get_meta("kind", "") in ["strip_fitting", "coffer"]:
			continue
		var mesh := (node as MultiMeshInstance3D).multimesh.mesh
		var glows := false
		for i in mesh.get_surface_count():
			var m := mesh.surface_get_material(i) as BaseMaterial3D
			glows = glows or (m != null and m.emission_enabled and m.emission_energy_multiplier > 0.5)
		if not glows:
			unlit.append(node.name)
	_check("S6e the fittings glow", unlit.is_empty(), "%s" % [unlit])

	# S6f: Deadlock's key (docs/superpowers/specs/2026-10-31-station-machinery-design.md): every station space hazed
	# warm (a FogVolume over its middle and its corners, its albedo warm); the hall and each platform lit by at least
	# four warm fittings and four of the Company's blue lamps; no light left the old cool fluorescent.
	var key := []
	var fogs: Array = station.find_children("*", "FogVolume", true, false).filter(func(f):
		var albedo: Color = ((f as FogVolume).material as FogMaterial).albedo if (f as FogVolume).material is FogMaterial \
			else Color.BLACK
		return albedo.r - albedo.b >= 0.15)
	for space: String in ["hall", "stairs_n", "stairs_s", "platform_n", "platform_s", "track"]:
		var record: Dictionary = station.spaces()[space]
		var outline: Array = record["polygon"]
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for q in outline:
			lo = Vector2(minf(lo.x, q[0]), minf(lo.y, q[1]))
			hi = Vector2(maxf(hi.x, q[0]), maxf(hi.y, q[1]))
		var y := float(record["floor"]) + 1.5
		for p: Vector2 in [(lo + hi) / 2.0, lo + Vector2(0.5, 0.5), hi - Vector2(0.5, 0.5)]:
			var at := Vector3(p.x, y, p.y)
			if not fogs.any(func(f): return AABB((f as FogVolume).position - (f as FogVolume).size / 2.0,
					(f as FogVolume).size).has_point(at)):
				key.append("%s unhazed at %s" % [space, at])
	for level in [[hall, "hall"], [below, "the platforms"]]:
		var own := lights.filter(func(l): return (l as Light3D).light_cull_mask & int(level[0]) != 0)
		var warm := own.filter(func(l): return (l as Light3D).light_color.r - (l as Light3D).light_color.b >= 0.2)
		var blue := own.filter(func(l): return (l as Light3D).light_color.b - (l as Light3D).light_color.r >= 0.2)
		var need := 4 if level[1] == "hall" else 8
		if warm.size() < need or blue.size() < need:
			key.append("%s: %d warm, %d blue" % [level[1], warm.size(), blue.size()])
	for light: Light3D in lights:
		if light.light_color.is_equal_approx(Color(0.86, 0.97, 0.92)):
			key.append("%s still fluorescent" % light.name)
			break
	_check("S6f warm haze against the Company's blue", key.is_empty(), "%s" % [key.slice(0, 6)])
	await _lamps_breathe()


## S6g: the Company's lamps atmospheric (the user, Oct 31: "a shader to the lamp itself to make it feel more
## atmospheric"): each of the 20 drawn by the ward glass's shader behind its glass, a halo round it, a pocket of haze at
## it; its light breathing with its glass (the same level, 0.6…1.2 of its energy, moving over 2 s), no two lamps in step.
func _lamps_breathe() -> void:
	var lamps = station.get("company_lamps")
	var wrong := []
	if lamps == null or (lamps as Array).size() != 20:
		wrong.append("lamps: %s" % [lamps.size() if lamps != null else null])
		lamps = []
	var levels := {}
	for lamp: Node3D in lamps:
		var glass: ShaderMaterial = lamp.get("glass")
		if glass == null or glass.shader.resource_path != "res://scripts/Visual/ward_glass.gdshader":
			wrong.append("%s: glass %s" % [lamp.name, glass])
		var halo: MeshInstance3D = lamp.get("halo")
		if halo == null or not halo.material_override is ShaderMaterial \
				or (halo.material_override as ShaderMaterial).shader.resource_path != "res://scripts/Visual/ward_halo.gdshader":
			wrong.append("%s: no halo" % lamp.name)
		elif not (halo.material_override as ShaderMaterial).shader.code.contains("fog_disabled"):
			# (The user, Oct 31: "I can still see the light quad": fog added over a blend_add quad draws its square.)
			wrong.append("%s: its halo takes the fog (its square shows)" % lamp.name)
		var light: OmniLight3D = lamp.get("light")
		var haze: FogVolume = lamp.get("haze")
		if light == null or not station.lights.has(light):
			wrong.append("%s: light" % lamp.name)
			continue
		if haze == null or haze.global_position.distance_to(light.global_position) > 0.6:
			wrong.append("%s: no haze at it" % lamp.name)
		levels[lamp] = []
	for i in 120:
		await get_tree().process_frame
		for lamp: Node3D in levels:
			var light: OmniLight3D = lamp.get("light")
			var level: float = light.light_energy / float(lamp.get("energy"))
			var glass: ShaderMaterial = lamp.get("glass")
			if absf(float(glass.get_shader_parameter("pulse")) - level) > 0.01:
				wrong.append("%s: glass %.2f, light %.2f" % [lamp.name, glass.get_shader_parameter("pulse"), level])
			levels[lamp].append(level)
	var seen := []
	for lamp: Node3D in levels:
		var run: Array = levels[lamp]
		if run.min() < 0.6 or run.max() > 1.2 or run.max() - run.min() < 0.05:
			wrong.append("%s breathes %.2f…%.2f" % [lamp.name, run.min(), run.max()])
		if seen.has(run):
			wrong.append("%s in step with another" % lamp.name)
		seen.append(run)
	_check("S6g the Company's lamps breathe in their haze", wrong.is_empty() and not (lamps as Array).is_empty(),
		"%s" % [wrong.slice(0, 6)])


func _reach(light: Light3D) -> float:
	return (light as OmniLight3D).omni_range if light is OmniLight3D else (light as SpotLight3D).spot_range


## Where the set's dressing is drawn: {"boxes": [{kind, aabb}] in its frame, "grid": {cell: [box indices]}}, its
## MultiMeshes' instances each its own box.
func _drawn() -> Dictionary:
	var boxes := []
	var grid := {}
	for node in station.find_children("*", "MultiMeshInstance3D", true, false):
		var many := (node as MultiMeshInstance3D).multimesh
		if many == null or many.mesh == null:
			continue
		var local := many.mesh.get_aabb()
		var to_set := station.global_transform.affine_inverse() * (node as Node3D).global_transform
		# (Its instances' transforms as the dressing laid them: a headless run's renderer keeps none.)
		var laid: Array = node.get_meta("transforms", [])
		for i in laid.size():
			var aabb: AABB = to_set * (laid[i] as Transform3D) * local
			boxes.append({"kind": node.get_meta("kind", String(node.name)), "aabb": aabb})
			var lo := (aabb.position / 2.0).floor()
			var hi := (aabb.end / 2.0).floor()
			for x in range(lo.x, hi.x + 1):
				for y in range(lo.y, hi.y + 1):
					for z in range(lo.z, hi.z + 1):
						var key := Vector3i(x, y, z)
						if not grid.has(key):
							grid[key] = []
						grid[key].append(boxes.size() - 1)
	return {"boxes": boxes, "grid": grid}


## The kinds of dressing drawn over `at`.
func _kinds_at(drawn: Dictionary, at: Vector3) -> Array:
	var kinds := []
	for i in drawn["grid"].get(Vector3i((at / 2.0).floor()), []):
		if (drawn["boxes"][i]["aabb"] as AABB).grow(0.01).has_point(at):
			kinds.append(drawn["boxes"][i]["kind"])
	return kinds


func _covered(drawn: Dictionary, at: Vector3) -> bool:
	for i in drawn["grid"].get(Vector3i((at / 2.0).floor()), []):
		if (drawn["boxes"][i]["aabb"] as AABB).grow(0.01).has_point(at):
			return true
	return false


## The floor under `at` (the shell's), its height; -INF if none.
func _floor_under(at: Vector3, skip: Array = []) -> float:
	var hit := _ray(at, at - Vector3(0.0, 20.0, 0.0), skip)
	return hit.y if hit != at - Vector3(0.0, 20.0, 0.0) else -INF


## The edge of `outline` that the run `a`-`b` lies on ([its two ends]; empty if none).
func _edge_of(outline: Array, a: Vector2, b: Vector2) -> Array:
	for i in outline.size():
		var p := Vector2(outline[i][0], outline[i][1])
		var q := Vector2(outline[(i + 1) % outline.size()][0], outline[(i + 1) % outline.size()][1])
		if Geometry2D.get_closest_point_to_segment(a, p, q).distance_to(a) < 0.02 \
				and Geometry2D.get_closest_point_to_segment(b, p, q).distance_to(b) < 0.02:
			return [p, q]
	return []


func _ray(from: Vector3, to: Vector3, skip: Array = []) -> Vector3:
	var space := station.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(station.to_global(from), station.to_global(to))
	var player: CharacterBody3D = station.get("player")
	q.exclude = skip + ([player.get_rid()] if player != null else [])
	var hit := space.intersect_ray(q)
	return station.to_local(hit.position) if not hit.is_empty() else to


## Task 5: the Company's engine (the user, Oct 31: "a gigantic engine ... more things going on at the same time").
## Where it stands, and what its foot keeps clear by ENGINE_CLEAR: the stair heads, the market stairs' mouth, each
## lane's approach (x, z boxes on the hall's floor).
const ENGINE_AT := Vector3(0.0, 6.0, 0.0)
const ENGINE_CLEAR := 1.5
const ENGINE_KEEP_CLEAR := [Vector2(-6.0, -12.5), Vector2(6.0, 12.5), Vector2(-10.0, 14.0)]
const ENGINE_LANES := [Rect2(-16.0, -4.0, 4.0, 8.0), Rect2(12.0, -4.0, 4.0, 8.0)]
## The corridors' mouths on the hall, walked between.
const CORRIDOR_W := Vector3(-29.0, 7.05, 0.0)
const CORRIDOR_E := Vector3(29.0, 7.05, 0.0)

## S11: the engine stands at the hall's middle, its footprint clear of the stairs, the market stairs and the lanes'
## approaches; the Company's blade signs stand on it, neon on both their faces.
## S11b: the player walks from corridor_w's mouth to corridor_e's, through the banks' lanes and round the engine, and
## climbs its plinth to its walk.
## S11c: it runs: every gear and the governor turn, each flywheel turns its crank, its conrod joins its crank's pin to
## its crosshead's at every frame, its crosshead rises and falls; all of it uninterpolated (moved between ticks).
func _engine() -> void:
	var engine = station.get("engine")
	if engine == null:
		_check("S11 the engine stands at the hall's middle", false, "no engine")
		_check("S11b walked round the engine", false, "no engine")
		_check("S11c the engine runs", false, "no engine")
		return
	var wrong := []
	if (engine as Node3D).position.distance_to(ENGINE_AT) > 0.01:
		wrong.append("at %s" % [engine.position])
	var foot: Rect2 = engine.get_meta("footprint", Rect2())
	if foot.size.x < 8.0:
		wrong.append("footprint %s" % [foot])
	for point: Vector2 in ENGINE_KEEP_CLEAR:
		var near := Vector2(clampf(point.x, foot.position.x, foot.end.x), clampf(point.y, foot.position.y, foot.end.y))
		if near.distance_to(point) < ENGINE_CLEAR:
			wrong.append("%.2f m from %s" % [near.distance_to(point), point])
	for lane: Rect2 in ENGINE_LANES:
		if lane.grow(ENGINE_CLEAR).intersects(foot):
			wrong.append("within %.1f m of the lane %s" % [ENGINE_CLEAR, lane])
	var blades := 0
	for sign: Node3D in station.neon:
		if sign.get_meta("on", "") == "engine":
			blades += 1
	if blades < 8:
		wrong.append("%d neon on its blade signs" % blades)
	_check("S11 the engine stands at the hall's middle", wrong.is_empty(), "%s" % [wrong])
	# S11b: across the hall by the lanes and round the engine's south side; up its steps onto its walk.
	var hall_floor: float = station.spaces()["hall"]["floor"]
	var lane_w := Vector3(-14.0, hall_floor + 1.05, 6.0)
	var lane_e := Vector3(14.0, hall_floor + 1.05, 6.0)
	for bank: Node3D in station.turnstiles:
		var lanes: Array = bank.get_meta("lanes", [])
		if not lanes.is_empty():
			var lane: Vector3 = lanes[lanes.size() - 1]
			if bank.get_meta("side", "") == "west":
				lane_w = Vector3(lane.x, hall_floor + 1.05, lane.z)
			else:
				lane_e = Vector3(lane.x, hall_floor + 1.05, lane.z)
	var round := [lane_w + Vector3(-2.5, 0.0, 0.0), lane_w + Vector3(2.5, 0.0, 0.0),
		Vector3(-6.5, hall_floor + 1.05, 6.5), Vector3(6.5, hall_floor + 1.05, 6.5), lane_e + Vector3(-2.5, 0.0, 0.0),
		lane_e + Vector3(2.5, 0.0, 0.0), CORRIDOR_E]
	var across := await _walk_path(CORRIDOR_W, round, 3600)
	# (Through the gate toward the window at 135°.)
	var up := await _walk_path(Vector3(-4.6, hall_floor + 1.05, 4.6), [Vector3(-2.12, hall_floor + 1.05, 2.12)], 900)
	var deck: float = (up["end"] as Vector3).y - (hall_floor + 1.05)
	_check("S11b walked round the engine", across["ok"] and up["ok"] and deck > 0.45,
		"across %s, up %s, on its deck %.2f m up" % [across, up, deck])
	# S11c: it runs.
	var spinners: Array = engine.get_meta("spinners", [])
	var cranks: Array = engine.get_meta("cranks", [])
	var faults := []
	if spinners.size() < 13 or cranks.size() < 4:
		faults.append("%d spinners, %d cranks" % [spinners.size(), cranks.size()])
	var before := []
	for spinner: Node3D in spinners:
		before.append(spinner.get_child(0).global_transform.basis)
	var heights := []
	for crank: Node3D in cranks:
		heights.append([INF, -INF])
	for frame in 40:
		await get_tree().process_frame
		for k in cranks.size():
			var crank: Node3D = cranks[k]
			var wheel: Node3D = crank.get_node("flywheel")
			var rod: Node3D = crank.get_node("conrod")
			var head: Node3D = crank.get_node("crosshead")
			var pin: Vector3 = wheel.global_transform * Vector3(float(crank.throw), float(crank.out), 0.0)
			var far: Vector3 = rod.global_transform * Vector3(0.0, float(crank.conrod), 0.0)
			if rod.global_position.distance_to(pin) > 0.01 or far.distance_to(head.global_position) > 0.01:
				faults.append("crank %d frame %d: pin %.3f, head %.3f" % [k, frame, rod.global_position.distance_to(pin),
					far.distance_to(head.global_position)])
			heights[k] = [minf(heights[k][0], head.global_position.y), maxf(heights[k][1], head.global_position.y)]
	for k in cranks.size():
		if heights[k][1] - heights[k][0] < 0.1:
			faults.append("crank %d's crosshead moved %.3f m" % [k, heights[k][1] - heights[k][0]])
	for k in spinners.size():
		var after: Basis = spinners[k].get_child(0).global_transform.basis
		if (before[k].inverse() * after).get_rotation_quaternion().get_angle() < 0.01:
			faults.append("%s did not turn" % spinners[k].name)
	for node: Node3D in spinners + cranks:
		for part: Node in [node] + node.get_children():
			if part is Node3D and (part as Node3D).physics_interpolation_mode != Node.PHYSICS_INTERPOLATION_MODE_OFF:
				faults.append("%s interpolated" % part.name)
	_check("S11c the engine runs", faults.is_empty(), "%s" % [faults.slice(0, 6)])

## The engine's presence (docs/superpowers/plans/2026-11-01-engine-presence.md).
## S12: one beat: a stroke for each crank as its crosshead tops its travel, a second apart; the core's light and its
## shader breathe on it (low between strokes, high just after one); paused, the beat holds.
func _engine_fx() -> void:
	var engine = station.get("engine")
	var beat = engine.get_node_or_null("beat") if engine != null else null
	if beat == null:
		_check("S12 the engine keeps one beat", false, "no beat")
		return
	var fx: Dictionary = engine.get_meta("fx", {})
	var cranks: Array = engine.get_meta("cranks", [])
	var wrong := []
	var strokes := []
	var on_stroke := func(index: int) -> void:
		strokes.append([index, float(beat.time)])
		var crank: Node3D = cranks[index]
		var top := float(crank.throw) + float(crank.conrod)
		var height := float(crank.head_height(beat.angle(index)))
		if absf(height - top) > 0.001:
			wrong.append("crank %d stroked at %.4f of %.4f" % [index, height, top])
	beat.stroke.connect(on_stroke)
	var core: OmniLight3D = fx.get("core")
	var look: ShaderMaterial = fx.get("core_look")
	var base := float(fx.get("core_energy", 0.0))
	var samples := []
	for frame in 240:
		await get_tree().process_frame
		var swell := float(beat.swell())
		samples.append([swell, float(beat.since_stroke())])
		if core == null or absf(core.light_energy - base * (EngineFx.CORE_LOW + (1.0 - EngineFx.CORE_LOW) * swell)) > 0.01:
			wrong.append("core light %.3f at swell %.2f" % [core.light_energy if core != null else -1.0, swell])
		if look == null or absf(float(look.get_shader_parameter("swell")) - swell) > 0.001:
			wrong.append("core shader's swell %s at %.2f" % [look.get_shader_parameter("swell") if look != null else null, swell])
	beat.stroke.disconnect(on_stroke)
	var indices := {}
	for k in strokes.size():
		indices[strokes[k][0]] = true
		if k > 0 and absf(strokes[k][1] - strokes[k - 1][1] - 1.0) > 0.02:
			wrong.append("strokes %.3f s apart" % (strokes[k][1] - strokes[k - 1][1]))
	if strokes.size() < 4 or strokes.size() > 5 or indices.size() != 4:
		wrong.append("strokes %s" % [strokes])
	var lowest := 1.0
	var highest := [0.0, 0.0]
	for sample: Array in samples:
		lowest = minf(lowest, sample[0])
		if sample[0] > highest[0]:
			highest = sample
	if lowest > 0.2 or highest[0] < 0.8 or highest[1] > 0.15:
		wrong.append("swell from %.2f to %.2f, its height %.2f s after a stroke" % [lowest, highest[0], highest[1]])
	get_tree().paused = true
	var held := float(beat.time)
	await _frames(30)
	if float(beat.time) != held:
		wrong.append("paused, the beat ran on %.3f s" % (float(beat.time) - held))
	get_tree().paused = false
	if beat.physics_interpolation_mode != Node.PHYSICS_INTERPOLATION_MODE_OFF:
		wrong.append("the beat interpolated")
	_check("S12 the engine keeps one beat; its core breathes on it", wrong.is_empty(), "%s" % [wrong.slice(0, 6)])


## Walks the set's player from `start` along `way`, turning toward each point; arrived at each within 0.3 m.
func _walk_path(start: Vector3, way: Array, frames: int) -> Dictionary:
	var player: CharacterBody3D = station.player
	player.global_position = station.to_global(start)
	player.velocity = Vector3.ZERO
	await _frames(10)
	var reached := 0
	var still := 0
	var last := player.global_position
	Input.action_press("move_forward")
	for i in frames:
		var to: Vector3 = station.to_global(way[reached]) - player.global_position
		to.y = 0.0
		if to.length() < 0.3:
			reached += 1
			if reached == way.size():
				break
			continue
		player.rotation.y = atan2(-to.x, -to.z)
		await get_tree().physics_frame
		still = still + 1 if player.global_position.distance_to(last) < 0.003 else 0
		last = player.global_position
		if still > 30:
			break
	Input.action_release("move_forward")
	await _frames(10)
	return {"ok": reached == way.size(), "reached": reached, "end": station.to_local(player.global_position)}


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _check(label: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		failures += 1
