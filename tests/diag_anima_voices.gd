extends Node3D
## Records the ánimas' voices as the game plays them (their takes, each at a soul's pitch, from a hand before you, on
## the Souls bus into a tiled room's World reverb) to docs/superpowers/refs/underground/sound/anima_voices.wav,
## for listening outside the game. Run headless or windowed: Godot --path . tests/diag_anima_voices.tscn

const Sfx := preload("res://scripts/Audio/Sfx.gd")
const OUT := "res://docs/superpowers/refs/underground/sound/anima_voices.wav"
## What is said, in turn: the sound, its take, the soul's pitch, where (m before you, aside), dB, the pause after (s).
const LINES := [
	[&"anima_voice", 1, 1.03, Vector2(0.85, -0.2), 0.0, 0.6],
	[&"anima_voice", 5, 1.03, Vector2(0.85, -0.2), 0.0, 0.3],
	[&"anima_voice", 7, 1.03, Vector2(0.85, -0.2), 0.0, 1.4],
	[&"anima_voice", 2, 0.87, Vector2(0.9, 0.25), 0.0, 0.5],
	[&"anima_voice", 8, 0.87, Vector2(0.9, 0.25), 0.0, 1.6],
	[&"anima_voice", 3, 0.94, Vector2(2.5, 1.5), -6.0, 0.8],
	[&"anima_voice", 6, 1.1, Vector2(3.5, -2.0), -7.0, 1.2],
	[&"anima_voice", 4, 0.84, Vector2(0.85, 0.0), 0.0, 1.0],
	[&"anima_moan", 1, 0.95, Vector2(1.5, 0.3), 1.0, 0.4],
	[&"anima_moan", 2, 1.05, Vector2(2.0, -0.6), 1.0, 3.0],
]


func _ready() -> void:
	Sfx._ensure_buses()
	Sfx.set_acoustics("stone")
	Sfx.shape_room(Vector2(0.45, 1.0))
	var record := AudioEffectRecord.new()
	AudioServer.add_bus_effect(0, record)
	var ear := Camera3D.new()
	add_child(ear)
	ear.make_current()
	var voice := AudioStreamPlayer3D.new()
	voice.bus = Sfx.BUS_SOULS
	voice.unit_size = 1.2
	voice.max_distance = 14.0
	voice.attenuation_filter_cutoff_hz = Sfx.AIR_CUTOFF
	voice.attenuation_filter_db = Sfx.AIR_DB
	add_child(voice)
	record.set_recording_active(true)
	await get_tree().create_timer(0.3).timeout
	for line: Array in LINES:
		voice.stream = load("res://audio/sfx/%s_%d.wav" % [line[0], line[1]])
		voice.pitch_scale = line[2]
		voice.position = Vector3(line[3].y, -0.5, -line[3].x)
		voice.volume_db = float(Sfx.GAIN[line[0]]) + line[4] + 12.0
		voice.play()
		await get_tree().create_timer(voice.stream.get_length() / line[2] + line[5]).timeout
	record.set_recording_active(false)
	var wav := record.get_recording()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
	wav.save_to_wav(ProjectSettings.globalize_path(OUT))
	print("saved %s, %.1f s" % [OUT, wav.get_length()])
	get_tree().quit()
