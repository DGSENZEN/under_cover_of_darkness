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
