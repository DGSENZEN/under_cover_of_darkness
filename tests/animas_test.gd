extends Node3D
## The ánimas on their own (scripts/Visual/Animas.gd), headless with --fixed-fps 60: never crowded into one, those
## begging side by side, up out of a wall's grille, a lurker drawn back, a shy one out of the gaze, their sizes.

const AnimasScript := preload("res://scripts/Visual/Animas.gd")

var results: Array[String] = []
var failures := 0
var living: Node3D
var eye: Camera3D


func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	living = Node3D.new()
	living.name = "living"
	add_child(living)
	eye = Camera3D.new()
	add_child(eye)
	eye.make_current()
	await _crowd()
	await _wall()
	await _lurker()
	await _shy()
	print("\n==== RESULTS ====")
	for result in results:
		print(result)
	get_tree().quit(1 if failures > 0 else 0)


func _souls(tempers: Dictionary, mouth := "grate", n := 6, sizes := Vector2(1.0, 1.0)) -> Node3D:
	var animas: Node3D = AnimasScript.new()
	animas.count = n
	animas.want_out = n
	animas.seed = 5
	animas.tempers = tempers
	animas.mouth = mouth
	animas.sizes = sizes
	animas.flee_from = living
	if mouth == "wall":
		animas.lanes = PackedFloat32Array([0.2, 0.3])
	else:
		animas.lanes = PackedFloat32Array([-0.12, 0.0, 0.12])
	add_child(animas)
	return animas


func _look(from: Vector3, at: Vector3) -> void:
	eye.global_transform = Transform3D(Basis.IDENTITY, from).looking_at(at, Vector3.UP)


func _out(animas: Node3D) -> Array:
	var out := []
	for i in animas.count:
		if animas.state_of(i) not in ["below", "climbing", "dragged"]:
			out.append(i)
	return out


## A6-A2: beggars round a drain, someone standing still before it a while.
func _crowd() -> void:
	var animas := _souls({"beggar": 1.0}, "grate", 6, Vector2(0.6, 1.4))
	living.global_position = Vector3(1.6, 0.0, 0.0)
	_look(living.global_position + Vector3(0, 1.6, 0), Vector3(0, 1.0, 0))
	var closest := INF
	var pleaders_apart := INF
	for f in 1800:
		await get_tree().process_frame
		if f < 240:
			continue
		var out := _out(animas)
		var pleading := out.filter(func(i): return animas.state_of(i) == "pleading")
		for a in out:
			for b in out:
				if a < b:
					var d: float = animas.lights[a].position.distance_to(animas.lights[b].position)
					closest = minf(closest, d)
					if a in pleading and b in pleading:
						pleaders_apart = minf(pleaders_apart, d)
	var sizes: Array = animas._souls.map(func(s): return s["size"])
	var scaled: bool = range(animas.count).all(func(i): return absf(animas.lights[i].scale.x - animas._souls[i]["size"]) < 0.01)
	_check("A1 no two ever crowd into one: every pair out keeps apart, those begging side by side",
		closest > 0.15 and pleaders_apart > 0.3 and pleaders_apart < INF,
		"closest %.2f m, begging apart %.2f m" % [closest, pleaders_apart])
	_check("A2 each its own size, drawn from its range, its hand that size",
		sizes.max() - sizes.min() > 0.3 and scaled, "sizes %s scaled %s" % [sizes, scaled])
	animas.queue_free()
	await get_tree().process_frame


## A3: from a wall's grille, out through its slots and free.
func _wall() -> void:
	var animas := _souls({"beggar": 1.0}, "wall", 3)
	living.global_position = Vector3(30.0, 0.0, 0.0)
	var behind := true
	var through := false
	var free := false
	for f in 900:
		await get_tree().process_frame
		for i in animas.count:
			var at: Vector3 = animas.lights[i].position
			if animas.state_of(i) == "below":
				behind = behind and at.z < -0.15
			if animas.state_of(i) == "climbing" and at.z > 0.0:
				through = true
			if animas.state_of(i) in ["seeking", "warming", "straining"] and at.z > 0.3:
				free = true
	_check("A3 from a wall's grille: waiting behind it, out through its slots, then free into the room",
		behind and through and free, "behind %s through %s free %s" % [behind, through, free])
	animas.queue_free()
	await get_tree().process_frame


## A4: a lurker hooked at its grille draws back in when someone comes close.
func _lurker() -> void:
	var animas := _souls({"lurker": 1.0}, "wall", 2)
	living.global_position = Vector3(10.0, 0.0, 6.0)
	var lurked := -1
	for f in 900:
		await get_tree().process_frame
		for i in animas.count:
			if animas.state_of(i) == "lurking":
				lurked = i
		if lurked >= 0:
			break
	var held_out: bool = lurked >= 0 and animas.lights[lurked].position.z > 0.0 and animas.lights[lurked].position.z < 0.3
	living.global_position = animas.to_global(Vector3(0.0, 0.0, 1.0))
	var drawn := false
	for f in 90:
		await get_tree().process_frame
		if lurked >= 0 and animas.state_of(lurked) in ["dragged", "below"]:
			drawn = true
	_check("A4 a lurker stays hooked at its grille, never free, and draws back in when someone comes close",
		held_out and drawn, "lurked %d held out %s drawn back %s" % [lurked, held_out, drawn])
	animas.queue_free()
	await get_tree().process_frame


## A5: a shy one at its candle, looked at, darts out of the gaze.
func _shy() -> void:
	var animas := _souls({"shy": 1.0}, "grate", 2)
	animas.candles = PackedVector3Array([Vector3(1.4, 1.0, 0.0)])
	living.global_position = Vector3(-30.0, 0.0, 0.0)
	_look(Vector3(-20.0, 1.6, 0.0), Vector3(-30.0, 1.6, 0.0))
	var warm := -1
	for f in 1200:
		await get_tree().process_frame
		for i in animas.count:
			if animas.state_of(i) == "warming":
				warm = i
		if warm >= 0:
			break
	var fled := false
	var out_of_sight := false
	if warm >= 0:
		var at: Vector3 = animas.lights[warm].global_position
		_look(at + Vector3(-2.5, 0.4, 0.3), at)
		for f in 120:
			await get_tree().process_frame
			if animas.state_of(warm) == "hiding":
				fled = true
		var d: Vector3 = animas.lights[warm].global_position - eye.global_position
		out_of_sight = (-eye.global_basis.z).dot(d.normalized()) < cos(deg_to_rad(16.0))
	_check("A5 a shy one, looked at, darts out of the gaze", warm >= 0 and fled and out_of_sight,
		"warming %d fled %s out of sight %s" % [warm, fled, out_of_sight])
	animas.queue_free()
	await get_tree().process_frame


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		failures += 1
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", label, detail])
