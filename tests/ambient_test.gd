extends Node3D
## The street's ambient effects and the plaza's pigeons (the scenes plan,
## Task 4), from a made-up dressing. Headless:
##   Godot --headless --fixed-fps 60 --path . res://tests/ambient_test.tscn

const FireParticles := preload("res://scripts/Visual/Lights/FireParticles.gd")

var results: Array[String] = []
var eye: Camera3D


func _ready() -> void:
	eye = Camera3D.new()
	add_child(eye)
	eye.make_current()
	eye.global_position = Vector3(0, 1.7, 0)
	await _run()

	print("\n==== RESULTS ====")
	for r in results:
		print(r)

	get_tree().quit()


func _run() -> void:
	# A1 near runs, far does not.
	var ambient := Ambient.build([{"effect": "steam", "at": [10, 0, 0]}, {"effect": "steam", "at": [80, 0, 0]}])
	add_child(ambient)
	ambient.step(0.3)
	_check("A1 an emitter 10 m off runs, one 80 m off does not", ambient.running() == [0], "%s" % [ambient.running()])
	ambient.free()

	# A2 a hundred near: the nearest forty run.
	var many := []

	for k in 100:
		many.append({"effect": "copal", "at": [cos(k * 0.7) * (5.0 + k * 0.25), 0, sin(k * 0.7) * (5.0 + k * 0.25)]})

	ambient = Ambient.build(many)
	add_child(ambient)
	ambient.step(0.3)
	var on := ambient.running()
	var far_on := 0.0
	var near_off := INF

	for k in 100:
		var d := Vector3(many[k]["at"][0], 0, many[k]["at"][2]).distance_to(Vector3(0, 0, 0))

		if k in on:
			far_on = maxf(far_on, d)
		else:
			near_off = minf(near_off, d)

	_check("A2 at most forty run, the nearest", on.size() == Ambient.ACTIVE and far_on <= near_off,
		"%d running, farthest on %.1f, nearest off %.1f" % [on.size(), far_on, near_off])
	ambient.free()

	# A3 a night emitter is still by day.
	ambient = Ambient.build([{"effect": "embers", "at": [5, 0, 0], "when": "night"}])
	add_child(ambient)
	ambient.set_day(true)
	ambient.step(0.3)
	var by_day := ambient.running().size()
	ambient.set_day(false)
	ambient.step(0.3)
	_check("A3 a night emitter is still by day and runs at night", by_day == 0 and ambient.running() == [0],
		"day %d, night %s" % [by_day, ambient.running()])
	ambient.free()

	# A4 copal is pale smoke; mist creeps low.
	FireParticles.clear()
	ambient = Ambient.build([{"effect": "copal", "at": [3, 0, 0]}, {"effect": "mist", "at": [-3, 0, 0]}])
	add_child(ambient)
	await _frames(2)

	for k in 30:
		ambient.step(1.0 / 30.0)

	await _frames(1)
	var world := FireParticles.world_node()
	var smoke = world._pools[&"smoke"] if world else null
	var mist = world._pools[&"mist"] if world and world._pools.has(&"mist") else null
	var pale: bool = smoke != null and smoke.count > 0 and smoke.tint[0].is_equal_approx(Color("ECE6DA"))
	var low: bool = mist != null and mist.count > 0

	if low:
		for i in mist.count:
			if mist.pos[i].y > 0.3 + mist.age[i] * 0.2:
				low = false

	_check("A4 copal smokes pale, mist creeps low", pale and low,
		"smoke %s, mist %s" % [smoke.count if smoke else -1, mist.count if mist else -1])
	ambient.free()

	# A5 the pigeons lift when someone comes close, and settle after.
	var watcher := Node3D.new()
	add_child(watcher)
	watcher.global_position = Vector3(30, 0, 0)
	var pigeons := Pigeons.build([{"at": [0, 0, 0], "count": 12, "radius": 2.5}], QuadMesh.new())
	pigeons.watcher = watcher
	add_child(pigeons)

	for k in 30:
		pigeons.step(0.1)

	var settled := not pigeons.flying(0)
	watcher.global_position = Vector3(3, 0, 0)

	for k in 10:
		pigeons.step(0.1)

	var lifted := pigeons.flying(0)
	watcher.global_position = Vector3(30, 0, 0)

	for k in 90:
		pigeons.step(0.1)

	_check("A5 a flock lifts when someone comes 3 m off and settles 8 s after", settled and lifted and not pigeons.flying(0),
		"settled %s, lifted %s, after %s" % [settled, lifted, pigeons.flying(0)])
	pigeons.free()

	# A6 petals, leaves and dust draw their own.
	FireParticles.clear()
	ambient = Ambient.build([{"effect": "petals", "at": [2, 0, 2]}, {"effect": "leaves", "at": [-2, 6, 2], "floor": 0.0},
		{"effect": "dust", "at": [0, 0, 3]}])
	add_child(ambient)
	await _frames(2)

	for k in 60:
		ambient.step(1.0 / 30.0)

	await _frames(1)
	world = FireParticles.world_node()
	var drawn := {}

	for kind in [&"petal", &"leaf", &"dust"]:
		var pool = world._pools.get(kind) if world else null
		drawn[kind] = pool != null and pool.count > 0 and pool.draw.material_override != null

	_check("A6 petals, leaves and dust are emitted and drawn", drawn.values().all(func(v): return v), "%s" % [drawn])
	ambient.free()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
