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
	for z in [-15.0, -8.0, 10.0, 16.0]:
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
