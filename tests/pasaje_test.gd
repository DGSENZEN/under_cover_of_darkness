extends Node3D
## The Pasaje set's middle stretch (docs/superpowers/plans/2026-10-26-pasaje-market.md): quick checks, headless with
## --fixed-fps 60.

const PASAJE := preload("res://maps/pasaje.tscn")

var results: Array[String] = []
var failures := 0
var pasaje: Node3D


func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	pasaje = PASAJE.instantiate()
	add_child(pasaje)
	await _frames(5)
	await _shell()
	_dressed()
	await _stalls()
	print("\n==== RESULTS ====")
	for result in results:
		print(result)
	get_tree().quit(1 if failures > 0 else 0)


## Task 2: the stretch's shell at the plan's measure, its openings open, walked end to end and out of both.
func _shell() -> void:
	var half_w: float = pasaje.HALF_W
	var half_l: float = pasaje.HALF_L
	var height: float = pasaje.HEIGHT
	# The floor under the whole street, the walls at ±HALF_W, the ceiling at HEIGHT.
	var floored := true
	for x in [-4.5, 0.0, 4.5]:
		for z in [-19.5, 0.0, 19.5]:
			floored = floored and absf(_ray(Vector3(x, 1.0, z), Vector3(x, -1.0, z)).y) < 0.02
	var walled := true
	# (In the alcoves between the stalls, where the walls stand bare.)
	for z in [-14.0, -7.0, 7.5, 19.0]:
		walled = walled and absf(absf(_ray(Vector3(0.0, 1.5, z), Vector3(-9.0, 1.5, z)).x) - half_w) < 0.35
		walled = walled and absf(absf(_ray(Vector3(0.0, 1.5, z), Vector3(9.0, 1.5, z)).x) - half_w) < 0.35
	var roofed := absf(_ray(Vector3(0.0, 2.0, 0.0), Vector3(0.0, 9.0, 0.0)).y - height) < 0.35
	# Each opening: a ray through its middle passes; 0.5 m beyond its ends, it meets wall.
	var open := true
	for name in pasaje.OPENINGS:
		var spec: Array = pasaje.OPENINGS[name]
		var side: float = spec[0]
		var middle: float = (spec[1] + spec[2]) / 2.0
		open = open and absf(_ray(Vector3(0.0, 1.5, middle), Vector3(side * 9.0, 1.5, middle)).x) > half_w + 0.5
		for z in [spec[1] - 0.5, spec[2] + 0.5]:
			open = open and absf(_ray(Vector3(0.0, 1.5, z), Vector3(side * 9.0, 1.5, z)).x) < half_w + 0.35
	_check("P1 the stretch's shell at the plan's measure, its openings open", floored and walled and roofed and open,
		"floored %s walled %s roofed %s openings %s" % [floored, walled, roofed, open])

	var street: Array[Vector3] = [Vector3(0.0, 1.05, 19.0)]
	var down := await _walk_path(Vector3(0.0, 1.05, -19.0), street, 2400)
	var herbs: Array[Vector3] = [Vector3(-3.0, 1.05, -1.0), Vector3(-5.6, 1.05, -1.0)]
	var to_herbs := await _walk_path(Vector3(0.0, 1.05, -6.0), herbs, 1200)
	var lane: Array[Vector3] = [Vector3(3.0, 1.05, 0.5), Vector3(5.6, 1.05, 0.5)]
	var to_lane := await _walk_path(Vector3(0.0, 1.05, -6.0), lane, 1200)
	_check("P2 the player walks the street end to end, and out into the herb market's mouth and the lane's",
		down["ok"] and to_herbs["ok"] and to_lane["ok"], "street %s herbs %s lane %s" % [down, to_herbs, to_lane])


## Task 3: the shell dressed in the Company's tile: no strip of either wall left bare from the floor to the ceiling
## (over an opening, from its head), and the mains along both walls, the east wall's turning into it either side of
## the lane's mouth.
func _dressed() -> void:
	var panels: Array = pasaje.get("wall_panels") if pasaje.get("wall_panels") != null else []
	var bare := []
	for side: int in [-1, 1]:
		var z := -19.95
		while z < 19.95:
			var low := 0.05
			for name in pasaje.OPENINGS:
				var spec: Array = pasaje.OPENINGS[name]
				if spec[0] == side and z > spec[1] and z < spec[2]:
					low = spec[3] + 0.05
			if not _covered(panels, side, z, low, pasaje.HEIGHT - 0.05):
				bare.append("%s %.2f" % ["west" if side < 0 else "east", z])
			z += 0.1
	_check("P3 the walls are tiled to the openings and the stretch's ends, no strip left bare",
		not panels.is_empty() and bare.is_empty(), "%d panels; bare %s" % [panels.size(), bare.slice(0, 6)])

	var services: Array = pasaje.get("services") if pasaje.get("services") != null else []
	var mouth: Array = pasaje.OPENINGS["candle_lane"]
	var runs := {"water": [[-19.9, 19.9]], "gas": [[-19.9, 19.9]], "tray": [[-19.9, 19.9]],
		"fire": [[-19.9, mouth[1] - 0.4], [mouth[2] + 0.4, 19.9]], "air": [[-19.9, mouth[1] - 0.4], [mouth[2] + 0.4, 19.9]]}
	var broken := []
	for main in runs:
		var spans := []
		for piece: MeshInstance3D in services:
			if piece.get_meta("main", "") == main:
				var box := _local_box(piece)
				spans.append([box.position.z, box.end.z])
		for run in runs[main]:
			var z: float = run[0]
			while z < run[1]:
				if not spans.any(func(s): return s[0] - 0.02 <= z and z <= s[1] + 0.02):
					broken.append("%s %.2f" % [main, z])
					break
				z += 0.1
		# (Nothing of the east's mains across the lane's mouth.)
		if main in ["fire", "air"] and spans.any(func(s): return s[1] > mouth[1] and s[0] < mouth[2]):
			broken.append("%s across the mouth" % main)
	_check("P3b the mains run both walls, the east's turning into the wall either side of the lane's mouth",
		not services.is_empty() and broken.is_empty(), "%d pieces; broken %s" % [services.size(), broken.slice(0, 6)])


## Task 4: the stalls by trade, against their walls clear of the walk and the openings, each front reached by the
## player, each under its own neon, every face for words blank, the floor open under every counter.
func _stalls() -> void:
	var stalls: Dictionary = pasaje.get("stalls") if pasaje.get("stalls") != null else {}
	var specs := {}
	for spec in (pasaje.get("STALLS") if pasaje.get("STALLS") != null else []):
		specs[spec[0]] = spec
	var wrong := []
	var walls := {}
	for name in stalls:
		var box := _stall_box(stalls[name])
		var side := 1 if box.get_center().x > 0.0 else -1
		walls[side] = true
		var near := box.position.x if side > 0 else -box.end.x
		var far := box.end.x if side > 0 else -box.position.x
		if near < 3.0 or far > 5.0:
			wrong.append("%s spans |x| %.2f-%.2f" % [name, near, far])
		for opening in pasaje.OPENINGS:
			var o: Array = pasaje.OPENINGS[opening]
			if o[0] == side and box.position.z < o[2] + 0.5 and box.end.z > o[1] - 0.5:
				wrong.append("%s by the %s" % [name, opening])
	_check("P4 the stalls stand against their walls, clear of the walk and the openings",
		stalls.size() >= 12 and stalls.size() <= 16 and walls.size() == 2 and wrong.is_empty(),
		"%d stalls on %d walls; %s" % [stalls.size(), walls.size(), wrong.slice(0, 4)])

	var unreached := []
	for name in stalls:
		var box := _stall_box(stalls[name])
		var side := 1 if box.get_center().x > 0.0 else -1
		var near := box.position.x if side > 0 else -box.end.x
		var middle := box.get_center().z
		var front: Array[Vector3] = [Vector3(side * (near - 0.6), 1.05, middle)]
		var walk := await _walk_path(Vector3(0.0, 1.05, middle), front, 300)
		if not walk["ok"]:
			unreached.append("%s %s" % [name, walk["end"]])
	_check("P4b the player reaches every stall's front", not stalls.is_empty() and unreached.is_empty(),
		"unreached %s" % [unreached.slice(0, 4)])

	var hues := {-1: [], 1: []}
	var off := []
	for name in stalls:
		var signs: Array = stalls[name].find_children("*", "NeonSign", true, false)
		if signs.is_empty():
			off.append("%s has no neon" % name)
			continue
		var hue: float = (signs[0].colour as Color).h * 360.0
		var box := _stall_box(stalls[name])
		var side := 1 if box.get_center().x > 0.0 else -1
		hues[side].append([box.get_center().z, hue, name])
		var mouth: bool = side > 0 and box.get_center().z > -6.5 and box.end.z < pasaje.OPENINGS["candle_lane"][1]
		for kept in [328.0, 2.0, 186.0]:
			var apart := _hue_apart(hue, kept)
			if mouth and kept == 186.0:
				if apart > 10.0:
					off.append("%s (the mouth's) %.0f off the teal" % [name, apart])
			elif apart < 15.0:
				off.append("%s at %.0f near %.0f" % [name, hue, kept])
	for side in hues:
		var row: Array = hues[side]
		row.sort_custom(func(a, b): return a[0] < b[0])
		for k in range(1, row.size()):
			if _hue_apart(row[k][1], row[k - 1][1]) < 25.0:
				off.append("%s beside %s" % [row[k][2], row[k - 1][2]])
	_check("P4c each stall under its own neon", not stalls.is_empty() and off.is_empty(), "%s" % [off.slice(0, 4)])

	var marked := []
	for name in stalls:
		if not stalls[name].find_children("*", "Label3D", true, false).is_empty() \
				or not stalls[name].find_children("*", "Decal", true, false).is_empty():
			marked.append(name)
	_check("P4d every face for words blank", not stalls.is_empty() and marked.is_empty(), "%s" % [marked])

	var shut := []
	var counters := 0
	for name in stalls:
		for counter: MeshInstance3D in stalls[name].find_children("counter*", "MeshInstance3D", true, false):
			counters += 1
			var box := _local_box(counter)
			var side := 1 if box.get_center().x > 0.0 else -1
			var near := box.position.x if side > 0 else -box.end.x
			var from := Vector3(side * (near - 0.05), 0.15, box.get_center().z)
			var hit := _ray(from, from + Vector3(side * 0.45, 0.0, 0.0))
			if hit.distance_to(from) < 0.449:
				shut.append("%s %.2f" % [name, hit.distance_to(from)])
		if specs.has(name) and not String(specs[name][5]) in ["cart", "barrow"] \
				and stalls[name].find_children("counter*", "MeshInstance3D", true, false).is_empty():
			shut.append("%s has no counter" % name)
	_check("P4e the floor under each counter is open, room for what will live there",
		counters > 0 and shut.is_empty(), "%d counters; %s" % [counters, shut.slice(0, 4)])


## The bounds of a stall's meshes in the set's frame.
func _stall_box(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var part := _local_box(mesh)
		box = part if first else box.merge(part)
		first = false
	return box


## How far apart two hues are round the wheel (degrees).
func _hue_apart(a: float, b: float) -> float:
	var d := fmod(absf(a - b), 360.0)
	return minf(d, 360.0 - d)


## Whether a panel on the `side` wall covers its face at `z` from `low` to `high`.
func _covered(panels: Array, side: int, z: float, low: float, high: float) -> bool:
	for panel: MeshInstance3D in panels:
		var box := _local_box(panel)
		var on_wall := absf(box.get_center().x - side * (pasaje.HALF_W - pasaje.WALL)) < 0.1
		if on_wall and box.position.z <= z and box.end.z >= z and box.position.y <= low and box.end.y >= high:
			return true
	return false


## A piece's bounds in the set's frame.
func _local_box(piece: MeshInstance3D) -> AABB:
	return pasaje.global_transform.affine_inverse() * piece.global_transform * piece.get_aabb()


func _ray(from: Vector3, to: Vector3) -> Vector3:
	var space := pasaje.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(pasaje.to_global(from), pasaje.to_global(to))
	var player: CharacterBody3D = pasaje.get("player")
	if player != null:
		q.exclude = [player.get_rid()]
	var hit := space.intersect_ray(q)
	return pasaje.to_local(hit.position) if not hit.is_empty() else to


## Walks the set's player from `start` along `way`, turning toward each point; arrived at each within 0.3 m.
func _walk_path(start: Vector3, way: Array[Vector3], frames: int) -> Dictionary:
	var player: CharacterBody3D = pasaje.player
	player.global_position = pasaje.to_global(start)
	player.velocity = Vector3.ZERO
	await _frames(10)
	var reached := 0
	var still := 0
	var last := player.global_position
	Input.action_press("move_forward")
	for i in frames:
		var to: Vector3 = pasaje.to_global(way[reached]) - player.global_position
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
	return {"ok": reached == way.size(), "reached": reached, "end": pasaje.to_local(player.global_position)}


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _check(label: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		failures += 1
