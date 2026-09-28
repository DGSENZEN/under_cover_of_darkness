extends Node
## The weather, heard: the rain (a calm and a strong loop crossfaded by how
## hard it rains, lower under a roof), the wind (by its speed), dripping
## (while it is wet), and thunder after each flash, quieter the longer the
## delay. The loops are cut by tools/prepare_sfx.py --weather into
## audio/weather/ (WAVs that loop on import); whatever is not there is not
## heard. Only audio: guards hear none of it
## (the noise floor is SoundBus.masking_db).

const FOLDER := "res://audio/weather/"
const LOOPS := ["rain_calm", "rain_strong", "wind", "drip"]
## Loudest (dB) of each, and how fast a level eases (dB/s).
const LOUDEST := {"rain_calm": -12.0, "rain_strong": -9.0, "wind": -14.0, "drip": -20.0}
const SILENT := -60.0
const EASE := 18.0
## A roof over you takes this off the rain (dB).
const INDOORS := -8.0
## Thunder: its loudest (dB), less this much a second of delay.
const THUNDER_DB := -4.0
const THUNDER_PER_SECOND := -3.0

var _players := {}
var _wanted := {}
var _thunders: Array[AudioStream] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 1917
	var bus := "Ambience" if AudioServer.get_bus_index("Ambience") >= 0 else "Master"

	for name in LOOPS:
		var path: String = FOLDER + name + ".wav"

		if not ResourceLoader.exists(path):
			continue

		var stream := load(path) as AudioStream

		if stream == null:
			continue

		var player := AudioStreamPlayer.new()
		player.stream = stream
		player.bus = bus
		player.volume_db = SILENT
		add_child(player)
		_players[name] = player
		_wanted[name] = SILENT

	for i in range(1, 9):
		for kind in ["wav", "ogg"]:
			var path := "%sthunder_%d.%s" % [FOLDER, i, kind]

			if ResourceLoader.exists(path):
				_thunders.append(load(path))


## The weather now: how hard it rains (0..1), the wind (m/s), how wet it is,
## whether you are under a roof.
func set_weather(rain: float, wind_speed: float, wetness: float, indoors: bool) -> void:
	var roof := INDOORS if indoors else 0.0
	_want("rain_calm", clampf(rain * 2.5, 0.0, 1.0) * (1.0 - smoothstep(0.5, 1.0, rain) * 0.6), roof)
	_want("rain_strong", smoothstep(0.35, 1.0, rain), roof)
	_want("wind", clampf(wind_speed / 8.0, 0.0, 1.0), 0.0)
	_want("drip", smoothstep(0.2, 0.6, wetness), 0.0)


## Thunder, `delay` s after its flash.
func thunder(delay: float) -> void:
	if _thunders.is_empty():
		return

	var player := AudioStreamPlayer.new()
	player.stream = _thunders[_rng.randi() % _thunders.size()]
	player.bus = "Ambience" if AudioServer.get_bus_index("Ambience") >= 0 else "Master"
	player.volume_db = THUNDER_DB + THUNDER_PER_SECOND * maxf(delay - 1.0, 0.0)
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _want(name: String, level: float, offset_db: float) -> void:
	if _players.has(name):
		_wanted[name] = SILENT if level <= 0.001 else float(LOUDEST[name]) + linear_to_db(level) + offset_db


func _process(delta: float) -> void:
	for name in _players:
		var player: AudioStreamPlayer = _players[name]
		player.volume_db = move_toward(player.volume_db, float(_wanted[name]), EASE * delta)
		var audible := player.volume_db > SILENT + 1.0

		if audible and not player.playing:
			player.play()
		elif not audible and player.playing:
			player.stop()
