extends Node
## Do separate players stay in step? (the Metro score spec's first risk.)
## The fixture's bed plays; 2.5 bars in, its theme a starts on a second
## player from theme_offset(...) of the bed's position. Each plays on its own
## bus, both recorded from the same mix, for SECONDS. Every bar both click on
## the downbeat: the offset between the two clicks, bar by bar, is the drift.
## Prints `SEEK ok|failed first_offset_ms=<x>` (a set started mid-loop lands on
## its downbeats) and `DRIFT max_offset_ms=<x> after_s=<y>`.
##   Godot --headless --path . res://tests/diag_place_score_drift.tscn [-- --seconds=180]

const FIXTURE := "res://tests/fixtures/place_score/"
## The recording's own mix rate is used; this only if there is none.
const RATE := 48000
const BAR := 1.0
## A click's first sample over this (16-bit) is its onset.
const ONSET := 1500

var seconds := 180.0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seconds="):
			seconds = float(arg.get_slice("=", 1))
	var bed_rec := _recording_bus(&"DriftBed")
	var theme_rec := _recording_bus(&"DriftTheme")
	var bed := _player(FIXTURE + "bed.tres", &"pulse", &"DriftBed")
	var theme := _player(FIXTURE + "a.tres", &"lead", &"DriftTheme")
	var json: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE + "score.json"))
	var theme_loop := float(json.themes.a.loop_seconds)
	AudioServer.lock()
	bed_rec.set_recording_active(true)
	theme_rec.set_recording_active(true)
	bed.play()
	AudioServer.unlock()
	while bed.get_playback_position() < 2.5 * BAR:
		await get_tree().process_frame
	# The bed's position is where its next mixed chunk starts: the theme's
	# first chunk is mixed with it, from the same place in the music.
	AudioServer.lock()
	theme.play(PlaceClock.theme_offset(bed.get_playback_position(), theme_loop))
	AudioServer.unlock()
	await get_tree().create_timer(seconds, true, false, true).timeout
	AudioServer.lock()
	bed_rec.set_recording_active(false)
	theme_rec.set_recording_active(false)
	AudioServer.unlock()
	var bed_wav := bed_rec.get_recording()
	var rate := float(bed_wav.mix_rate) if bed_wav != null else float(RATE)
	var bed_onsets := _onsets(bed_wav)
	var theme_onsets := _onsets(theme_rec.get_recording())
	var worst := 0.0
	var first := INF
	var compared := 0
	for t in theme_onsets:
		var nearest := INF
		for b in bed_onsets:
			if absf(b - t) < absf(nearest):
				nearest = b - t
		if is_inf(nearest):
			continue
		var offset_ms := absf(nearest) / rate * 1000.0
		if is_inf(first):
			first = offset_ms
		worst = maxf(worst, offset_ms)
		compared += 1
	print("compared %d downbeats (bed %d, theme %d)" % [compared, bed_onsets.size(), theme_onsets.size()])
	print("SEEK %s first_offset_ms=%.2f" % ["ok" if first <= 5.0 else "failed", first])
	print("DRIFT max_offset_ms=%.2f after_s=%.1f" % [worst, seconds])
	get_tree().quit(0 if worst <= 5.0 and first <= 5.0 and compared > seconds * 0.8 else 1)


func _recording_bus(bus_name: StringName) -> AudioEffectRecord:
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	var record := AudioEffectRecord.new()
	record.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(index, record)
	return record


## A player of one set with only its one stem sounding.
func _player(path: String, stem: StringName, bus: StringName) -> AudioStreamPlayer:
	var stream := (load(path) as AudioStreamSynchronized).duplicate() as AudioStreamSynchronized
	for i in range(stream.stream_count):
		var file := stream.get_sync_stream(i).resource_path.get_file().get_basename()
		stream.set_sync_stream_volume(i, 0.0 if StringName(file) == stem else -80.0)
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = bus
	add_child(player)
	return player


## Sample frames of each downbeat click: the first sample over ONSET, then
## nothing for most of a bar.
func _onsets(wav: AudioStreamWAV) -> PackedInt64Array:
	var found := PackedInt64Array()
	if wav == null:
		return found
	var data := wav.data
	var frames := data.size() / 4
	var frame := 0
	while frame < frames:
		if absi(data.decode_s16(frame * 4)) > ONSET:
			found.append(frame)
			frame += int(wav.mix_rate * BAR * 0.8)
		else:
			frame += 1
	return found
