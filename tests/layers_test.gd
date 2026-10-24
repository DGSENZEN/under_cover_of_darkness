extends Node3D
## The Underground's sound layers (docs/superpowers/specs/2026-10-24-underground-sound-layers-design.md), headless
## with --fixed-fps 60, sound on and Master muted: the focus director (F), the neon (N), the pipes (P), the books (B),
## and all of them in the bay, the lane and the shop (Y).

const Sfx := preload("res://scripts/Audio/Sfx.gd")
const Focus := preload("res://scripts/Audio/Focus.gd")
const PipeSoundsScript := preload("res://scripts/Audio/PipeSounds.gd")

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
	await _neon()
	await _pipes()
	# (Let the audio thread let go of what played before quitting.)
	Focus.reset()
	Sfx._bank.clear()
	if Sfx._node != null and is_instance_valid(Sfx._node):
		Sfx._node.queue_free()
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


## N1-N3: her sign's hum and its stutters.
func _neon() -> void:
	Focus.reset()
	var sign := NeonSign.new()
	sign.pattern = "mmmmmmmmmmmmmmmammmmmmmmmzmmmmmmmmmmmmmmmmmaam"
	sign.seed = 11
	sign.set("buzz", &"neon_buzz_1")
	add_child(sign)
	sign.position = Vector3(0.0, 2.2, -1.5)
	eye.global_position = Vector3(0.0, 1.6, 0.0)
	await _frames(30)
	var hum: AudioStreamPlayer3D = sign.get("hum")
	var gain: float = Sfx.LOOP_GAIN[&"neon_buzz_1"]
	var worst := 0.0
	for f in 300:
		await get_tree().process_frame
		if hum != null:
			worst = maxf(worst, absf(Focus.base_of(hum) - NeonSign.hum_db(gain, sign.level() * sign.dim)))
	_check("N1 her sign hums from its tube, its loudness following the flicker",
		hum != null and hum.playing and hum.max_distance <= 4.5 and worst < 0.1, "hum %s, worst %.2f dB" % [hum, worst])

	var times: Array[float] = []
	var was: int = sign.get("ticks") if sign.get("ticks") != null else 0
	for f in 3600:
		await get_tree().process_frame
		if sign.get("ticks") != null and int(sign.get("ticks")) > was:
			was = sign.get("ticks")
			times.append(sign._time)
	var apart := INF
	for k in range(1, times.size()):
		apart = minf(apart, times[k] - times[k - 1])
	_check("N2 its stutters tick only now and then, never closer than five seconds",
		times.size() >= 2 and times.size() <= 7 and apart >= 5.0, "%d ticks at %s" % [times.size(), times])

	var last := INF
	var fell := true
	var steepest := 0.0
	for f in 60:
		sign.dim = lerpf(1.0, 0.3, float(f + 1) / 60.0)
		sign.pattern = "m"
		await get_tree().process_frame
		var now := Focus.base_of(hum) if hum != null else 0.0
		if last != INF:
			fell = fell and now <= last + 0.001
			steepest = maxf(steepest, last - now)
		last = now
	_check("N3 a brownout sags the hum with the light", hum != null and fell and steepest <= 1.5,
		"fell %s, steepest %.2f dB a frame" % [fell, steepest])
	sign.queue_free()
	await _frames(2)


## P1-P4: the pipes.
func _pipes() -> void:
	Focus.reset()
	var pipes: Node3D = PipeSoundsScript.new()
	add_child(pipes)
	pipes.run(&"pipe_trickle", Vector3(-12.0, 3.25, -2.2), Vector3(12.0, 3.25, -2.2))
	var along := []
	for x in [-5.0, 0.0, 7.0]:
		eye.global_position = Vector3(x, 1.6, 0.0)
		await _frames(2)
		along.append(pipes.emitter_of(0).global_position.x if pipes.emitter_of(0) != null else INF)
	_check("P1 the main is heard where you are along it", along.size() == 3 and absf(along[0] + 5.0) < 0.05
		and absf(along[1]) < 0.05 and absf(along[2] - 7.0) < 0.05, "%s" % [along])
	eye.global_position = Vector3(20.0, 1.6, 0.0)
	await _frames(2)
	var end: float = pipes.emitter_of(0).global_position.x if pipes.emitter_of(0) != null else INF
	_check("P2 past a run's end the sound stays at its end", absf(end - 12.0) < 0.05, "%.2f" % end)

	eye.global_position = Vector3(0.0, 1.6, 0.0)
	pipes.knocks(Vector3(-12.0, 3.1, 2.2), Vector3(12.0, 3.1, 2.2), Vector2(1.0, 1.0))
	await _frames(180)
	var strikes: Array = pipes.heard.filter(func(h): return h[1] == &"pipe_knock")
	var travels := strikes.size() >= 3
	if travels:
		var step1: float = strikes[1][2].x - strikes[0][2].x
		var step2: float = strikes[2][2].x - strikes[1][2].x
		travels = signf(step1) == signf(step2) and absf(step1) >= 2.49 and absf(step1) <= 4.01 \
			and absf(step2) >= 2.49 and absf(step2) <= 4.01 and strikes[1][0] > strikes[0][0] and strikes[2][0] > strikes[1][0]
	_check("P3 a knock travels: three strikes, each further along", travels,
		"%s" % [strikes.slice(0, 3).map(func(h): return [snappedf(h[0], 0.01), snappedf(h[2].x, 0.01)])])
	pipes.queue_free()
	await _frames(2)

	Focus.reset()
	var joint: Node3D = PipeSoundsScript.new()
	add_child(joint)
	joint.events(&"pipe_drip", Vector3(-2.3, 0.05, -2.17), Vector2(1.4, 3.4))
	await _frames(1200)
	var drops: Array = joint.heard.map(func(h): return h[0])
	var closest := INF
	for k in range(1, drops.size()):
		closest = minf(closest, drops[k] - drops[k - 1])
	_check("P4 the weeping joint drips, never two drops at once", drops.size() >= 5 and drops.size() <= 15
		and closest >= 1.39, "%d drops, closest %.2f s" % [drops.size(), closest])
	joint.queue_free()
	await _frames(2)


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		failures += 1
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", label, detail])
