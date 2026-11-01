extends Node
## The world's 3D voices by the Company's engine as a train passes, in real time (the audio's own): how busy Sfx's pool
## gets, what holds it, what is taken from it. Run WITHOUT --fixed-fps (that turns real-time sync off: the game then
## outruns its own audio and every sound looks unfinished):
##   Godot --headless --path . res://tests/diag_metro_voices.tscn
## Prints HOGS {sound: voice-frames}, REAL <s>, PROBE <busiest> <frames all busy> <taken> <the engine's sounds>.
const Sfx := preload("res://scripts/Audio/Sfx.gd")

func _ready() -> void:
	Engine.max_fps = 60
	Sfx.enabled = true
	var metro: Node3D = preload("res://maps/metro.tscn").instantiate()
	add_child(metro)
	for i in 5:
		await get_tree().process_frame
	var player: Node3D = metro.get("player")
	var engine: Node3D = metro.get_node("metro_station").engine
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.global_position = engine.global_position + Vector3(6.0, 1.05, 0.0)
	# (Its camera is top level, following the player only in the player's own update, stopped here: the ear is carried.)
	var eye := get_viewport().get_camera_3d()
	eye.global_position = player.global_position + Vector3(0.0, 0.6, 0.0)
	eye.look_at(engine.global_position + Vector3(0.0, 1.5, 0.0))
	var s: PlaceSound = metro.get_node("PlaceSound")
	await get_tree().process_frame
	s.train.start_pass()
	var busy_max := 0
	var hogs := {}
	var levels := {&"World": [], &"Machine": [], &"Ambience": [], &"Music": []}
	var t0 := Time.get_ticks_msec()
	var full_frames := 0
	var stolen := {}
	var last := {}
	var frames := 15 * 60
	for f in frames:
		await get_tree().process_frame
		var node: Node = Sfx._node
		if node == null:
			continue
		var busy := 0
		for v: AudioStreamPlayer3D in node._players_3d:
			if v.playing:
				busy += 1
			var was: Array = last.get(v, [])
			# A voice whose stream changed while the old one still had time left was taken.
			if not was.is_empty() and was[0] != v.stream and was[1] and float(was[2]) < float(was[3]) - 0.05:
				var key := String(was[0].resource_path.get_file().get_slice("_", 0) + "_" + was[0].resource_path.get_file().get_slice("_", 1)) if was[0] != null else "?"
				stolen[key] = int(stolen.get(key, 0)) + 1
			last[v] = [v.stream, v.playing, v.get_playback_position() if v.playing else 0.0, v.stream.get_length() if v.stream != null else 0.0]
		busy_max = maxi(busy_max, busy)
		for bus: StringName in levels:
			var b := AudioServer.get_bus_index(bus)
			levels[bus].append(AudioServer.get_bus_peak_volume_left_db(b, 0))
		for v: AudioStreamPlayer3D in node._players_3d:
			if v.playing and v.stream != null:
				var n := v.stream.resource_path.get_file().rsplit("_", true, 1)[0]
				hogs[n] = int(hogs.get(n, 0)) + 1
		if busy >= node._players_3d.size():
			full_frames += 1
	print("HOGS ", hogs)
	# How much each bus swings frame to frame (a bed ducked by every stroke swings with them).
	for bus: StringName in levels:
		var v: Array = levels[bus]
		var swing := 0.0
		for i in range(1, v.size()):
			swing += absf(float(v[i]) - float(v[i - 1]))
		var sorted := v.duplicate()
		sorted.sort()
		print("BUS %s median %.1f dB, 10-90 spread %.1f dB, mean swing %.2f dB a frame" % [bus, sorted[sorted.size() / 2],
			sorted[sorted.size() * 9 / 10] - sorted[sorted.size() / 10], swing / maxf(v.size() - 1, 1)])
	var by_name := {}
	for entry: Array in s.engine_heard():
		by_name[entry[0]] = int(by_name.get(entry[0], 0)) + 1
	print("REAL %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	print("PROBE voices busy max %d of %d, frames all busy %d of %d; stolen %s; engine heard %s" % [busy_max,
		Sfx._node._players_3d.size(), full_frames, frames, stolen, by_name])
	get_tree().quit()
