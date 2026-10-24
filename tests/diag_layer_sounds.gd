extends Node3D
## Records one of the Underground's layers (docs/superpowers/specs/2026-10-24-underground-sound-layers-design.md) as
## the game would play it, to docs/superpowers/refs/underground/sound/<layer>.wav, for the user to judge before it
## is wired in: its loops and takes from Sfx, through the World bus and a room's reverb, at their tiers' levels
## (all raised by LISTEN dB so they can be heard clearly), you walking past.
##   Godot --headless --path . tests/diag_layer_sounds.tscn -- --layer=neon|pipes|books|all
## (all: the candle lane with the shop in its wall, maps/candle_lane.tscn, everything wired in and under Focus and the
## bay's judged-bad sounds hushed as the lane hushes them, walked from the Pasaje's mouth by the drain's ánimas, past
## her sign under the mains, in through the librarian's arch and under his vault.)

const Sfx := preload("res://scripts/Audio/Sfx.gd")
const LISTEN := 12.0
const OUT := "res://docs/superpowers/refs/underground/sound/%s.wav"
const LANE := "res://maps/candle_lane.tscn"

var layer := "neon"
var ear: Camera3D
var clock := 0.0
var _rng := RandomNumberGenerator.new()
var _loops: Array = []
var _events: Array = []
var _walk := [Vector3.ZERO, Vector3.ZERO, 1.0]
var _length := 20.0
var _signs: Array = []
var _last_tick := -10.0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--layer="):
			layer = arg.split("=")[1]
	_rng.seed = 24
	if layer == "all":
		await _all()
		return
	Sfx._ensure_buses()
	Sfx.set_acoustics("wood" if layer == "books" else "stone")
	Sfx.shape_room(Vector2(0.3, 1.0) if layer == "books" else Vector2(0.45, 1.0))
	ear = Camera3D.new()
	add_child(ear)
	ear.make_current()
	call("_" + layer)
	var record := AudioEffectRecord.new()
	AudioServer.add_bus_effect(0, record)
	record.set_recording_active(true)
	var start := Time.get_ticks_msec()
	while clock < _length:
		await get_tree().process_frame
		var delta := (Time.get_ticks_msec() - start) / 1000.0 - clock
		clock += delta
		_step(delta)
	for loop: Array in _loops:
		loop[0].stop()
	await get_tree().create_timer(2.5).timeout
	record.set_recording_active(false)
	var wav := record.get_recording()
	wav.save_to_wav(ProjectSettings.globalize_path(OUT % layer))
	print("saved %s, %.1f s" % [OUT % layer, wav.get_length()])
	get_tree().quit()


## The bay and the shop as they play: walked through on a path of its own, at the game's levels raised by LISTEN.
func _all() -> void:
	Sfx.enabled = true
	var map: Node3D = (load(LANE) as PackedScene).instantiate()
	add_child(map)
	ear = Camera3D.new()
	add_child(ear)
	await get_tree().process_frame
	ear.make_current()
	var drain: Vector3 = map.animas.global_position if map.get("animas") != null else Vector3.ZERO
	var arch: Vector3 = map.SHOP_AT
	# Up the lane (standing by the drain a while, past her sign under the mains), in at the arch, under the vault.
	var path := [[0.0, Vector3(-14.0, 1.6, 0.9), -PI / 2.0], [8.0, Vector3(drain.x - 0.5, 1.6, 0.9), -PI / 2.0],
		[16.0, Vector3(drain.x, 1.6, 0.9), -PI / 2.0], [24.0, Vector3(0.5, 1.6, 0.6), -PI / 2.0],
		[31.0, Vector3(arch.x, 1.6, arch.z - 1.4), PI], [36.0, Vector3(arch.x, 1.6, arch.z + 1.2), PI],
		[45.0, Vector3(arch.x, 1.6, arch.z + 2.9), PI + 0.5]]
	# (Raised a little less than the layers' files: all of it at once peaks higher.)
	AudioServer.set_bus_volume_db(0, LISTEN - 2.0)
	var record := AudioEffectRecord.new()
	AudioServer.add_bus_effect(0, record)
	record.set_recording_active(true)
	var start := Time.get_ticks_msec()
	clock = 0.0
	while clock < 45.0:
		await get_tree().process_frame
		clock = (Time.get_ticks_msec() - start) / 1000.0
		var k := 0
		while k < path.size() - 2 and clock > path[k + 1][0]:
			k += 1
		var u := clampf((clock - path[k][0]) / (path[k + 1][0] - path[k][0]), 0.0, 1.0)
		ear.global_position = (path[k][1] as Vector3).lerp(path[k + 1][1], u)
		ear.rotation.y = lerpf(path[k][2], path[k + 1][2], u)
	record.set_recording_active(false)
	var wav := record.get_recording()
	wav.save_to_wav(ProjectSettings.globalize_path(OUT % layer))
	var pipes: Node = map.get("pipe_sounds")
	var books: Node = map.shop.get("book_sounds") if map.get("shop") != null else null
	print("pipes played %s" % [pipes.played if pipes != null else {}])
	print("books played %s" % [books.played if books != null else {}])
	print("ánimas spoke %d" % [map.animas.spoken if map.get("animas") != null else -1])
	print("saved %s, %.1f s" % [OUT % layer, wav.get_length()])
	Sfx.silence()
	get_tree().quit()


## A loop at `at` (or sliding along a run: from, to), at its level.
func _loop(sound: StringName, at: Vector3, reach := 8.0, run := []) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.stream = load("res://audio/ambience/%s.wav" % sound)
	player.bus = Sfx.BUS_WORLD
	player.unit_size = 1.2
	player.max_distance = reach
	player.attenuation_filter_cutoff_hz = Sfx.AIR_CUTOFF
	player.attenuation_filter_db = Sfx.AIR_DB
	player.volume_db = float(Sfx.LOOP_GAIN[sound]) + LISTEN
	add_child(player)
	player.position = at
	player.play(_rng.randf_range(0.0, player.stream.get_length()))
	_loops.append([player, run, player.volume_db])
	return player


## A one-shot at `when` (s), `at`, `db` over its gain.
func _shot(when: float, sound: StringName, at: Vector3, db := 0.0) -> void:
	_events.append([when, sound, at, db])


func _play(sound: StringName, at: Vector3, db: float) -> void:
	var player := AudioStreamPlayer3D.new()
	player.stream = Sfx.stream(sound)
	player.bus = Sfx.BUS_WORLD
	player.unit_size = 1.2
	player.max_distance = 14.0
	player.attenuation_filter_cutoff_hz = Sfx.AIR_CUTOFF
	player.attenuation_filter_db = Sfx.AIR_DB
	player.volume_db = float(Sfx.GAIN.get(sound, 0.0)) + db + LISTEN + _rng.randf_range(-1.0, 1.0)
	player.pitch_scale = 1.0 + _rng.randf_range(-0.04, 0.04)
	add_child(player)
	player.position = at
	player.play()
	player.finished.connect(player.queue_free)


func _step(delta: float) -> void:
	var t := clampf(clock / _length, 0.0, 1.0)
	ear.position = _walk[0].lerp(_walk[1], t)
	ear.rotation.y = _walk[2]
	while not _events.is_empty() and _events[0][0] <= clock:
		var e: Array = _events.pop_front()
		_play(e[1], e[2], e[3])
	# A run's emitter slides to the point on it nearest you.
	for loop: Array in _loops:
		if not loop[1].is_empty():
			var a: Vector3 = loop[1][0]
			var b: Vector3 = loop[1][1]
			var along := clampf((ear.position - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
			loop[0].position = a.lerp(b, along)
	# The signs: the hum follows the tube; some stutters tick off and zap back.
	for sign: Array in _signs:
		var neon: NeonSign = sign[0]
		var level := neon.level()
		sign[1].volume_db = sign[2] + linear_to_db(maxf(level, 0.02))
		if sign[3] > 0.5 and level < 0.5 and clock - _last_tick > 5.0 and _rng.randf() < 0.35:
			_play(&"neon_tick", neon.position, 0.0)
			print("%.1f s: the sign at %s ticks off" % [clock, neon.position])
			_shot(clock + 0.12 + _rng.randf_range(0.0, 0.2), &"neon_zap", neon.position)
			_events.sort_custom(func(x, y): return x[0] < y[0])
			_last_tick = clock
		sign[3] = level


func _sign(at: Vector3, buzz: StringName, pattern: String, seed: int) -> void:
	var neon := NeonSign.new()
	neon.pattern = pattern
	neon.seed = seed
	add_child(neon)
	neon.position = at
	var hum := _loop(buzz, at, 4.5)
	_signs.append([neon, hum, hum.volume_db, 1.0])


## Past her stall's sign (its own pattern), a stuttering one across the corridor, a steady one down it.
func _neon() -> void:
	_length = 22.0
	_walk = [Vector3(-3.0, 1.6, 0.0), Vector3(4.0, 1.6, 0.0), 0.0]
	_sign(Vector3(-1.5, 2.2, -1.6), &"neon_buzz_1", "mmmmmmmmmmmmmmmammmmmmmmmzmmmmmmmmmmmmmmmmmaam", 11)
	_sign(Vector3(2.0, 2.4, 1.8), &"neon_buzz_2", "mmmmmmmmmmmmmmmmmmmmmmmamammmmmmmmmmmmmmmmmzmmm", 5)
	_sign(Vector3(5.5, 2.4, -1.8), &"neon_buzz_3", "m", 3)


## Along the corridor's mains: the water main trickling over your head (its weeping joint dripping), knocks
## travelling down the fire main across from it, a gulp, its valve breathing, the air line faint below.
func _pipes() -> void:
	_length = 26.0
	_walk = [Vector3(-7.0, 1.6, 0.0), Vector3(7.0, 1.6, 0.0), 0.0]
	_loop(&"pipe_trickle", Vector3.ZERO, 8.0, [Vector3(-12.0, 3.25, -2.2), Vector3(12.0, 3.25, -2.2)])
	_loop(&"pipe_air", Vector3.ZERO, 6.0, [Vector3(-12.0, 2.75, 2.2), Vector3(12.0, 2.75, 2.2)])
	var drip := Vector3(-2.3, 3.15, -2.17)
	var when := 0.8
	while when < _length:
		_shot(when, &"pipe_drip", Vector3(drip.x, 0.05, drip.z), _rng.randf_range(-3.0, 0.0))
		when += _rng.randf_range(1.4, 3.4)
	for knock: Array in [[5.0, -6.0, 1.0], [17.5, 4.0, -1.0]]:
		var x: float = knock[1]
		var at: float = knock[0]
		for k in 3:
			_shot(at, &"pipe_knock", Vector3(x, 3.1, 2.2), -4.0 * k)
			at += _rng.randf_range(0.16, 0.38)
			x += knock[2] * _rng.randf_range(2.5, 4.0)
	_shot(9.0, &"pipe_gurgle", Vector3(0.0, 3.25, -2.2))
	_shot(21.0, &"pipe_gurgle", Vector3(5.0, 3.25, -2.2))
	_shot(12.5, &"pipe_hiss", Vector3(9.0, 3.1, 2.2))
	_events.sort_custom(func(a, b): return a[0] < b[0])


## In the shop: a book drifting overhead, its pages stirring; a shelf behind you rearranged; a live book opening
## before you and shutting; a book lifting off its board and another coming down onto one.
func _books() -> void:
	_length = 22.0
	_walk = [Vector3(0.0, 1.6, 0.0), Vector3(0.0, 1.6, -0.5), 0.0]
	var flutter := _loop(&"book_flutter", Vector3(0.0, 2.9, -1.5), 6.0)
	_loops[-1][1] = []
	_signs = []
	_shot(2.5, &"shelf_shuffle", Vector3(-1.2, 1.2, 3.0))
	_shot(6.0, &"book_open", Vector3(0.3, 1.1, -0.8))
	_shot(6.45, &"book_riffle", Vector3(0.3, 1.1, -0.8))
	_shot(10.0, &"book_shut", Vector3(0.3, 1.1, -0.8))
	_shot(13.0, &"shelf_slide", Vector3(2.2, 1.6, 2.4))
	_shot(13.7, &"shelf_tock", Vector3(2.2, 1.6, 2.4))
	_shot(16.0, &"book_lift", Vector3(-2.5, 1.8, -2.0))
	_shot(19.5, &"book_land", Vector3(2.5, 1.5, -2.2))
	_events.sort_custom(func(a, b): return a[0] < b[0])
	var orbit := create_tween().set_loops()
	orbit.tween_method(func(a: float) -> void: flutter.position = Vector3(cos(a) * 2.0, 2.9, -1.5 + sin(a) * 1.6),
		0.0, TAU, 14.0)
