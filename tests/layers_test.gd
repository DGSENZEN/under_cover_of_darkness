extends Node3D
## The Underground's sound layers (docs/superpowers/specs/2026-10-24-underground-sound-layers-design.md), headless
## with --fixed-fps 60, sound on and Master muted: the focus director (F), the neon (N), the pipes (P), the books (B),
## and all of them in the bay, the lane and the shop (Y).

const Sfx := preload("res://scripts/Audio/Sfx.gd")
const Focus := preload("res://scripts/Audio/Focus.gd")

var results: Array[String] = []
var failures := 0
var eye: Camera3D


func _ready() -> void:
	Sfx.enabled = true
	AudioServer.set_bus_mute(0, true)
	eye = Camera3D.new()
	add_child(eye)
	eye.make_current()
	await _focus()
	# (Let the audio thread let go of what played before quitting.)
	Focus.reset()
	Sfx._bank.clear()
	await _frames(3)
	OS.delay_msec(300)
	await _frames(3)
	print("\n==== RESULTS ====")
	for result in results:
		print(result)
	get_tree().quit(1 if failures > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _player(at: Vector3) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.stream = load("res://audio/ambience/pipe_trickle.wav")
	player.max_distance = 30.0
	add_child(player)
	player.position = at
	player.play()
	return player


## F1-F5: the focus director.
func _focus() -> void:
	Focus.reset()
	var order := Focus.rank([{"at": Vector3(1, 0, 0), "priority": 1.0, "reach": 8.0},
		{"at": Vector3(4, 0, 0), "priority": 1.0, "reach": 8.0}, {"at": Vector3(2, 0, 0), "priority": 3.0, "reach": 8.0},
		{"at": Vector3(20, 0, 0), "priority": 1.0, "reach": 8.0}], Vector3.ZERO)
	_check("F1 rank orders by priority over distance and leaves out those past reach", order == [2, 0, 1], "%s" % [order])

	eye.global_position = Vector3.ZERO
	var loops: Array[AudioStreamPlayer3D] = []
	for d in [1.0, 2.0, 3.0, 6.0, 7.0]:
		var p := _player(Vector3(d, 0, 0))
		Focus.hold(self, p, &"loop", -20.0)
		loops.append(p)
	await _frames(10)
	var early := [Focus.duck_of(loops[3]), Focus.duck_of(loops[4])]
	await _frames(80)
	var ducks := loops.map(func(p): return Focus.duck_of(p))
	_check("F2 only the three nearest loops play at full, the rest sink to -12 eased",
		ducks.slice(0, 3).all(func(d): return d > -0.5) and ducks.slice(3).all(func(d): return d < -11.5)
		and early.all(func(d): return d < -1.0 and d > -11.5), "early %s, then %s" % [early, ducks])

	var allowed := 0
	for k in 10:
		allowed += 1 if Focus.allow(self, &"detail", Vector3(1, 0, 0)) else 0
	await _frames(126)
	var later := Focus.allow(self, &"detail", Vector3(1, 0, 0))
	_check("F3 one-shots: at most three details in any two seconds", allowed == 3 and later, "%d allowed, later %s" % [allowed, later])

	var held := loops[0]
	Focus.featured(self, Vector3(1, 0, 0), 1.0)
	await _frames(30)
	var mid := held.volume_db - (-20.0 + Focus.duck_of(held))
	await _frames(60)
	var after := held.volume_db - (-20.0 + Focus.duck_of(held))
	_check("F4 a featured sound near dips loops and details by 3 dB while it plays",
		absf(mid + 3.0) < 0.3 and absf(after) < 0.3, "mid %.2f, after %.2f" % [mid, after])

	var count := Focus.held_count()
	loops[4].stop()
	loops[4].stream = null
	loops[4].queue_free()
	await _frames(20)
	_check("F5 a freed player is let go without error", Focus.held_count() == count - 1, "%d -> %d" % [count, Focus.held_count()])
	for p in loops:
		if is_instance_valid(p):
			p.stop()
			p.stream = null
			p.queue_free()
	await _frames(2)


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		failures += 1
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", label, detail])
