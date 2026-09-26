extends Node3D
## Sound woven into the game: every name a recording; takes never repeating
## back to back; the room's acoustics on the World bus, the score and the place
## ducking under the fight; a sound behind a wall heard through it; slow
## motion heard as well as seen; the score's intensity following the fight.
## And the second pass: the room sounded out as you go, far sounds wetter and
## duller, a corner heard round, your hurt dulling the world under a
## heartbeat, steps landing with the head bob, torches crackling, iron ringing
## on iron, bodies falling on the floor they hit, the place receding under
## the fight, the guard coming up in its leather.

const PLAYER := preload("res://Player.tscn")
const GUARD := preload("res://Guard.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")
const SfxScript := preload("res://scripts/Audio/Sfx.gd")
const MusicScript := preload("res://scripts/Audio/Music.gd")
const TimeFx := preload("res://scripts/Visual/TimeFx.gd")
const TorchScript := preload("res://scripts/Visual/Torch.gd")
const AmbienceScript := preload("res://scripts/Audio/Ambience.gd")

## A sealed stone room (M3, M9, M13): walls and a roof around a 4 x 4 floor.
const BOX := Vector3(-20, 0, 20)
const TemperamentScript := preload("res://scripts/AISystem/Temperament.gd")

var player: CharacterBody3D
var results: Array[String] = []


func _ready() -> void:
	# Every guard at his class's own temperament: these checks are exact.
	TemperamentScript.rolling = false
	Props.block(self, Vector3(0, -0.5, 0), Vector3(80, 1, 80))
	# A wall to hear round (M3).
	Props.block(self, Vector3(20, 1.5, -5), Vector3(6, 3, 0.4))
	# A sealed room to hear through (M3, M9, M13).
	Props.block(self, BOX + Vector3(0, 1.6, -2.2), Vector3(4.8, 3.2, 0.4))
	Props.block(self, BOX + Vector3(0, 1.6, 2.2), Vector3(4.8, 3.2, 0.4))
	Props.block(self, BOX + Vector3(-2.2, 1.6, 0), Vector3(0.4, 3.2, 4.8))
	Props.block(self, BOX + Vector3(2.2, 1.6, 0), Vector3(0.4, 3.2, 4.8))
	Props.block(self, BOX + Vector3(0, 3.4, 0), Vector3(4.8, 0.4, 4.8))
	# Planks to fall on (M15).
	Props.block(self, Vector3(10, 0.05, 20), Vector3(6, 0.1, 6), Color(0.45, 0.32, 0.2), "wood")

	var baker := NavigationRegion3D.new()
	baker.set_script(NavBakerScript)
	add_child(baker)

	player = PLAYER.instantiate()
	add_child(player)
	player.invulnerable = true
	player.reload_on_death = false

	if player.has_node("LightGem"):
		player.get_node("LightGem").queue_free()

	player.global_position = Vector3(0, 1.05, 0)
	await baker.baked
	await _frames(5)
	await _run()

	print("\n==== RESULTS ====")
	for r in results:
		print(r)

	# The score's layers were playing: give the audio thread a real moment to
	# let go of them, or it reports them at exit.
	SfxScript._bank.clear()
	await _frames(3)
	OS.delay_msec(300)
	await _frames(3)
	get_tree().quit()


func _run() -> void:
	# M1 takes never repeat back to back
	var repeats := 0
	var last: Object = null
	for i in 60:
		var take := SfxScript.stream(&"step_stone")
		if take == last:
			repeats += 1
		last = take
	_check("M1 a sound's takes never play the same one twice running", repeats == 0 and SfxScript._load_files(&"step_stone").size() >= 2, "repeats %d" % repeats)

	# M2 the buses: the room's reverb on World, the score and the place ducked by it
	SfxScript._ensure_buses()
	var world := AudioServer.get_bus_index(SfxScript.BUS_WORLD)
	var reverb: AudioEffectReverb = null
	for i in range(AudioServer.get_bus_effect_count(world)):
		if AudioServer.get_bus_effect(world, i) is AudioEffectReverb:
			reverb = AudioServer.get_bus_effect(world, i)
	var ducked := 0
	for bus in [SfxScript.BUS_MUSIC, SfxScript.BUS_AMBIENCE]:
		var index := AudioServer.get_bus_index(bus)
		for i in range(AudioServer.get_bus_effect_count(index)):
			var compressor := AudioServer.get_bus_effect(index, i) as AudioEffectCompressor
			if compressor != null and compressor.sidechain == SfxScript.BUS_WORLD:
				ducked += 1
	var stone_room: float = reverb.room_size if reverb != null else -1.0
	SfxScript.set_acoustics("cave")
	var cave_room: float = reverb.room_size if reverb != null else -1.0
	SfxScript.set_acoustics("stone")
	_check("M2 the world plays in the room's acoustics; the score and the place duck under it", reverb != null and ducked == 2 and cave_room > stone_room,
		"reverb %s ducking buses %d room stone %.2f cave %.2f" % [reverb != null, ducked, stone_room, cave_room])

	# M3 a sound behind a wall with a way round it is heard round it; one in
	#    a sealed room through the wall; one in the open, plainly
	var sfx: Node = SfxScript.new()
	add_child(sfx)
	var camera := Camera3D.new()
	add_child(camera)
	camera.global_position = Vector3(20, 1.6, 0)
	camera.current = true
	await _frames(3)
	var round_it: float = sfx._occlusion(Vector3(20, 1.4, -10))
	var in_the_open: float = sfx._occlusion(Vector3(28, 1.4, 0))
	camera.global_position = BOX + Vector3(0, 1.6, -8)
	await _frames(2)
	var sealed: float = sfx._occlusion(BOX + Vector3(0, 1.4, 0))
	_check("M3 a sound round a wall comes round it, one in a sealed room through it, one in the open plainly", round_it == 0.5 and sealed == 1.0 and in_the_open == 0.0 and sfx._occluded(BOX + Vector3(0, 1.4, 0)),
		"round the wall %.1f sealed in %.1f in the open %.1f" % [round_it, sealed, in_the_open])

	# M9 the room is sounded out, and the reverb follows it: a tight stone
	#    box rings short and close, the open air hardly at all
	var space := get_world_3d().direct_space_state
	var boxed: Vector2 = SfxScript.probe_room(space, BOX + Vector3(0, 1.6, 0), [])
	var open_air: Vector2 = SfxScript.probe_room(space, Vector3(-10, 1.6, -25), [])
	var reverb_of := func(bus: StringName) -> AudioEffectReverb:
		var index := AudioServer.get_bus_index(bus)
		for i in range(AudioServer.get_bus_effect_count(index)):
			if AudioServer.get_bus_effect(index, i) is AudioEffectReverb:
				return AudioServer.get_bus_effect(index, i)
		return null
	var room_reverb: AudioEffectReverb = reverb_of.call(SfxScript.BUS_WORLD)
	SfxScript.shape_room(boxed)
	var boxed_wet := room_reverb.wet
	var boxed_size := room_reverb.room_size
	SfxScript.shape_room(open_air)
	var open_wet := room_reverb.wet
	SfxScript.set_acoustics("stone")
	# And as you go: the listener in the box, the reverb eases to it.
	camera.global_position = BOX + Vector3(0, 1.6, 0)
	await _frames(150)
	var eased: Vector2 = sfx._room_heard
	_check("M9 the room is sounded out and the reverb follows it", boxed.y == 1.0 and boxed.x < 0.15 and open_air.y < 0.3 and open_air.x > 0.7 and open_wet < boxed_wet * 0.5 and boxed_size < 0.4 and eased.distance_to(boxed) < 0.12,
		"box %s (wet %.2f size %.2f) open %s (wet %.2f); heard in the box %s" % [boxed, boxed_wet, boxed_size, open_air, open_wet, eased])

	# M10 far off, a sound plays on WorldFar: wetter, and dulled by the air
	var far_reverb: AudioEffectReverb = reverb_of.call(SfxScript.BUS_FAR)
	var far_index := AudioServer.get_bus_index(SfxScript.BUS_FAR)
	var far_air := 0.0
	for i in range(AudioServer.get_bus_effect_count(far_index)):
		var filter := AudioServer.get_bus_effect(far_index, i) as AudioEffectLowPassFilter
		if filter != null and not filter.has_meta(&"hurt"):
			far_air = filter.cutoff_hz
	camera.global_position = Vector3(20, 1.6, 0)
	await _frames(2)
	sfx._play_3d(&"clang", Vector3(20, 1.4, 25), 0.0, 1.0)
	sfx._play_3d(&"clang", Vector3(22, 1.4, 1), 0.0, 1.0)
	var buses := []
	for player_3d in sfx._players_3d:
		if player_3d.playing:
			buses.append(player_3d.bus)
	_check("M10 a far sound plays wetter and duller than a near one", SfxScript.bus_for_distance(20.0) == SfxScript.BUS_FAR and SfxScript.bus_for_distance(4.0) == SfxScript.BUS_WORLD and far_reverb != null and far_reverb.wet > room_reverb.wet and far_air > 0.0 and far_air < 5000.0 and buses.has(SfxScript.BUS_FAR) and buses.has(SfxScript.BUS_WORLD),
		"far wet %.2f near wet %.2f far air %.0f Hz playing on %s" % [far_reverb.wet if far_reverb != null else -1.0, room_reverb.wet, far_air, buses])

	# M11 hurt badly, the world goes dull and your heart pounds; a heavy blow
	#    deadens your hearing for a moment
	var hurt_cutoff := func() -> float:
		var index := AudioServer.get_bus_index(SfxScript.BUS_WORLD)
		for i in range(AudioServer.get_bus_effect_count(index)):
			var filter := AudioServer.get_bus_effect(index, i) as AudioEffectLowPassFilter
			if filter != null and filter.has_meta(&"hurt"):
				return filter.cutoff_hz
		return -1.0
	var unhurt: float = hurt_cutoff.call()
	SfxScript.recording = true
	SfxScript.recorded.clear()
	# (Held there: no catching your breath meanwhile.)
	var breath: float = player.recover_delay
	player.recover_delay = 1000.0
	player.health = player.max_health * 0.06
	await _frames(90)
	var dulled: float = hurt_cutoff.call()
	var beats := SfxScript.recorded.filter(func(entry): return entry[0] == &"heartbeat").size()
	player.health = player.max_health
	player.recover_delay = breath
	await _frames(5)
	var healed: float = hurt_cutoff.call()
	SfxScript.body_hit(40.0)
	await _frames(2)
	var struck: float = hurt_cutoff.call()
	await _frames(70)
	var cleared: float = hurt_cutoff.call()
	SfxScript.recording = false
	_check("M11 cut badly the world dulls under a heartbeat; a heavy blow deadens it a moment", unhurt == SfxScript.OPEN_CUTOFF and dulled < 3200.0 and beats >= 2 and healed == SfxScript.OPEN_CUTOFF and struck < 2000.0 and cleared == SfxScript.OPEN_CUTOFF and SfxScript.world_cutoff_for(0.2, 0.0) > SfxScript.world_cutoff_for(0.05, 0.0),
		"unhurt %.0f Hz, near dead %.0f Hz with %d beats, healed %.0f Hz, struck %.0f Hz, after %.0f Hz" % [unhurt, dulled, beats, healed, struck, cleared])
	sfx.queue_free()
	camera.queue_free()
	await _frames(2)

	# M12 each footstep lands as the head comes down, walking or running; at
	#    a run the gear knocks on one hip, every other step
	player.global_position = Vector3(0, 1.05, 0)
	player.rotation.y = 0.0
	player.velocity = Vector3.ZERO
	await _frames(10)
	var lows := []
	var walked := await _steps_with_bob(false, lows)
	var run_lows := []
	SfxScript.recording = true
	SfxScript.recorded.clear()
	var ran := await _steps_with_bob(true, run_lows)
	var gear := SfxScript.recorded.filter(func(entry): return entry[0] == &"gear").size()
	var run_steps := SfxScript.recorded.filter(func(entry): return String(entry[0]).begins_with("step_")).size()
	SfxScript.recording = false
	var all_low := func(values: Array) -> bool:
		for value in values:
			if value > -0.85:
				return false
		return true
	_check("M12 footsteps land as the head comes down; at a run the gear knocks on one hip", walked >= 3 and ran >= 4 and all_low.call(lows) and all_low.call(run_lows) and gear >= 1 and gear <= (run_steps + 1) / 2,
		"walk steps %d bob at them %s; run steps %d bob %s; gear %d of %d steps" % [walked, _rounded(lows), ran, _rounded(run_lows), gear, run_steps])
	player.global_position = Vector3(0, 1.05, 0)
	player.velocity = Vector3.ZERO
	await _frames(5)

	# M13 a torch crackles near you (never in step with another), through a
	#    wall muffled, and not at all out of earshot
	SfxScript.enabled = true
	var boxed_torch: Node3D = TorchScript.new()
	boxed_torch.position = BOX + Vector3(0, 2.2, 0)
	add_child(boxed_torch)
	var open_torch: Node3D = TorchScript.new()
	open_torch.position = Vector3(0, 2.2, -20)
	add_child(open_torch)
	var ear := Camera3D.new()
	add_child(ear)
	ear.current = true
	ear.global_position = Vector3(0, 1.6, -16)
	await _frames(50)
	var open_playing: bool = open_torch.crackle != null and open_torch.crackle.playing
	var open_cutoff: float = open_torch.crackle.attenuation_filter_cutoff_hz if open_torch.crackle != null else -1.0
	var boxed_idle: bool = boxed_torch.crackle != null and not boxed_torch.crackle.playing
	ear.global_position = BOX + Vector3(0, 1.6, -4.5)
	await _frames(50)
	var boxed_playing: bool = boxed_torch.crackle.playing
	var boxed_muffled: bool = boxed_torch.crackle.attenuation_filter_cutoff_hz == SfxScript.OCCLUDED_CUTOFF and boxed_torch._crackle_db < TorchScript.CRACKLE_DB - 5.0
	var open_gone: bool = not open_torch.crackle.playing
	var unlike: bool = not is_equal_approx(open_torch.crackle.pitch_scale, boxed_torch.crackle.pitch_scale)
	_check("M13 a torch crackles near you, muffled through a wall, silent out of earshot", open_playing and open_cutoff == SfxScript.AIR_CUTOFF and boxed_idle and boxed_playing and boxed_muffled and open_gone and unlike,
		"open torch playing %s (%.0f Hz), boxed idle while far %s, boxed playing %s muffled %s, open stopped when far %s, unalike %s" % [open_playing, open_cutoff, boxed_idle, boxed_playing, boxed_muffled, open_gone, unlike])
	boxed_torch.queue_free()
	open_torch.queue_free()
	ear.queue_free()
	SfxScript.silence()
	if SfxScript._node != null and is_instance_valid(SfxScript._node):
		SfxScript._node.queue_free()
	SfxScript._node = null
	SfxScript.enabled = false
	await _frames(3)

	# M14 steel on a helmet or a shoulder plate rings; on a hood, on cloth,
	#    only flesh
	var mailed: CharacterBody3D = GUARD.instantiate()
	mailed.archetype = &"swordsman"
	mailed.position = Vector3(-8, 0, 8)
	add_child(mailed)
	var hooded: CharacterBody3D = GUARD.instantiate()
	hooded.archetype = &"archer"
	hooded.position = Vector3(-4, 0, 8)
	add_child(hooded)
	await _frames(5)
	var man_of := func(g: Node) -> Node:
		return g.get("_rig").get("man")
	var helm_at: Vector3 = man_of.call(mailed).bone_global(&"Head").origin + Vector3.UP * 0.12
	var plate_at: Vector3 = man_of.call(mailed).bone_global(&"upperarm_r").origin
	# A cloth belly: the archer's (the wardrobe's swordsman wears a mail
	# hauberk, so his belly rings; the wardrobe suite's K9 pins where).
	var belly_at: Vector3 = hooded.global_position + Vector3.UP * 1.0 + hooded.global_basis.z * -0.2
	var hood_at: Vector3 = man_of.call(hooded).bone_global(&"Head").origin + Vector3.UP * 0.12
	_check("M14 steel rings on a helmet or a shoulder plate, not on a hood or a belly", mailed.armoured_at(helm_at) and mailed.armoured_at(plate_at) and not hooded.armoured_at(belly_at) and not hooded.armoured_at(hood_at),
		"helmet %s plate %s belly %s hood %s" % [mailed.armoured_at(helm_at), mailed.armoured_at(plate_at), hooded.armoured_at(belly_at), hooded.armoured_at(hood_at)])
	mailed.queue_free()
	hooded.queue_free()
	await _frames(3)

	# M15 a body falls on the floor it hits: planks sound of planks
	var falling: CharacterBody3D = GUARD.instantiate()
	falling.archetype = &"swordsman"
	falling.position = Vector3(10, 0.1, 20)
	add_child(falling)
	await _frames(10)
	SfxScript.recording = true
	SfxScript.recorded.clear()
	falling.take_hit(500.0, null, &"backstab", falling.global_position + Vector3.UP * 1.2, Vector3.FORWARD)
	var fell := []
	for i in 300:
		await _frames(1)
		fell = SfxScript.recorded.map(func(entry): return entry[0]).filter(func(n): return String(n).begins_with("land_"))
		if not fell.is_empty():
			break
	var all_heard := SfxScript.recorded.map(func(entry): return entry[0])
	SfxScript.recording = false
	_check("M15 a body falls on the floor it hits", fell.has(&"land_wood_chain") and not fell.has(&"land_stone_chain"), "heard %s (of %s)" % [fell, all_heard.slice(0, 10)])
	for body in get_tree().get_nodes_in_group(&"bodies"):
		body.queue_free()
	if is_instance_valid(falling):
		falling.queue_free()
	await _frames(3)

	# M18 in a fight, your failing heart falls in with the score's beat, and
	#    the score's own pulse steps back for it
	var score: Node = MusicScript.new()
	score.name = "Music"
	add_child(score)
	var beater: Node = SfxScript.new()
	add_child(beater)
	var foe: CharacterBody3D = GUARD.instantiate()
	foe.archetype = &"swordsman"
	foe.position = player.global_position + Vector3(0, -1.05, -2.0)
	foe.rotation.y = PI
	add_child(foe)
	foe._attack_timer = 999.0
	foe._engage(player)
	var breath2: float = player.recover_delay
	player.recover_delay = 1000.0
	player.health = player.max_health * 0.06
	await _until(func(): return score.beat_now() >= 0, 240)
	SfxScript.recording = true
	SfxScript.recorded.clear()
	var beat_times: Array[float] = []
	var seen := 0
	var start := Time.get_ticks_usec()
	while Time.get_ticks_usec() - start < 3000000:
		await get_tree().process_frame
		var hearts := SfxScript.recorded.filter(func(entry): return entry[0] == &"heartbeat").size()
		if hearts > seen:
			seen = hearts
			beat_times.append((Time.get_ticks_usec() - start) / 1000000.0)
	SfxScript.recording = false
	# By now the pulse is all the way in, but for what it yields.
	var pulse_db: float = score._layers[&"music_pulse"].volume_db if score._layers.has(&"music_pulse") else 0.0
	var yielded: float = MusicScript.LAYERS[1][3] + MusicScript.PULSE_YIELD * (1.0 - 0.06 / SfxScript.HURT_AT)
	var off_grid := 0.0
	for i in range(1, beat_times.size()):
		var gap := beat_times[i] - beat_times[i - 1]
		off_grid = maxf(off_grid, absf(gap - MusicScript.BEAT * round(gap / MusicScript.BEAT)))
	var full_pulse: float = MusicScript.LAYERS[1][3]
	_check("M18 in a fight your failing heart falls in with the score's beat, its own pulse stepping back", beat_times.size() >= 4 and off_grid < 0.06 and absf(pulse_db - yielded) < 0.5,
		"%d beats, furthest off the beat %.3f s, the score's pulse %.1f dB (whole %.1f, yielding to %.1f)" % [beat_times.size(), off_grid, pulse_db, full_pulse, yielded])
	player.health = player.max_health
	player.recover_delay = breath2
	foe.queue_free()
	score.queue_free()
	beater.queue_free()
	await _frames(5)

	# M16 the place recedes as the fight's score rises
	var quiet := AmbienceScript.dip_for(0.0)
	var some := AmbienceScript.dip_for(0.3)
	var full := AmbienceScript.dip_for(0.9)
	_check("M16 the place recedes as the fight rises", quiet == 0.0 and some < 0.0 and some > full and is_equal_approx(full, AmbienceScript.FIGHT_DIP),
		"calm %.1f dB, some fight %.1f dB, a hard one %.1f dB" % [quiet, some, full])

	# M17 your guard comes up in its leather, the blade brought across
	Props.give_weapons(player)
	player.inventory.select_by_id(&"sword")
	await _frames(40)
	SfxScript.recording = true
	SfxScript.recorded.clear()
	Input.action_press("block")
	await _frames(6)
	Input.action_release("block")
	await _frames(20)
	Input.action_press("block")
	await _frames(1)
	Input.action_release("block")
	var raised := SfxScript.recorded.map(func(entry): return entry[0])
	SfxScript.recording = false
	var grabs := raised.filter(func(n): return n == &"grab").size()
	_check("M17 raising your guard creaks its leather and brings the blade across", player.combat.current_weapon() != null and grabs == 2 and raised.has(&"blade_draw"),
		"weapon %s heard %s" % [player.combat.current_weapon() != null, raised])

	# M4 slow motion is heard: the mix slows with it (a hit-stop does not)
	TimeFx.hitstop(get_tree(), 0.2)
	var during_stop := AudioServer.playback_speed_scale
	TimeFx.request(get_tree(), &"finisher", 0.3, 0.3)
	var during_slow := AudioServer.playback_speed_scale
	await get_tree().create_timer(0.5, true, false, true).timeout
	var after := AudioServer.playback_speed_scale
	_check("M4 slow motion slows the sound too; a hit-stop does not warble it", _near(during_stop, 1.0, 0.01) and during_slow < 0.7 and _near(after, 1.0, 0.01),
		"hit-stop %.2f slow motion %.2f after %.2f" % [during_stop, during_slow, after])

	# M5 the score follows the fight: layer by layer as it worsens
	var calm := MusicScript.intensity_of(0, 0, 0, 1.0, false, false, false)
	var hunted := MusicScript.intensity_of(2, 0, 0, 1.0, false, false, false)
	var one := MusicScript.intensity_of(0, 1, 1, 1.0, false, false, false)
	var three := MusicScript.intensity_of(0, 3, 2, 1.0, false, false, false)
	var dire := MusicScript.intensity_of(0, 3, 3, 0.2, true, true, true)
	var layers_at := func(x: float) -> Array:
		var on := []
		for spec in MusicScript.LAYERS:
			if x > float(spec[1]):
				on.append(String(spec[0]).trim_prefix("music_"))
		return on
	_check("M5 the score comes in layer by layer as the fight worsens", calm == 0.0 and hunted < one and one < three and three < dire and dire >= MusicScript.SEVERE and layers_at.call(hunted) == ["drone"] and "drums" in layers_at.call(three) and "severe" in layers_at.call(dire),
		"calm %.2f hunted %.2f %s, one %.2f %s, three %.2f %s, dire %.2f %s" % [calm, hunted, layers_at.call(hunted), one, layers_at.call(one), three, layers_at.call(three), dire, layers_at.call(dire)])

	# M6 a guard on you raises it; with him gone it falls away again
	var music: Node = MusicScript.new()
	add_child(music)
	var g: CharacterBody3D = GUARD.instantiate()
	g.archetype = &"swordsman"
	g.position = Vector3(0, 0, -2.0)
	g.rotation.y = PI
	add_child(g)
	g._attack_timer = 999.0
	g._engage(player)
	await _frames(30)
	var fighting: float = music.target
	g.queue_free()
	await _frames(60)
	var gone: float = music.target
	_check("M6 a guard at you raises the score; with him gone it falls away", fighting > 0.3 and gone == 0.0, "with him %.2f without %.2f" % [fighting, gone])
	music.queue_free()
	await _frames(5)

	# M7 the score's loops loop, and all but the drone are whole bars of the
	#    drums (130 bpm), so they stay in step
	var bar := 4.0 * 60.0 / 130.0
	var loops := []
	var all_ok := true
	for spec in MusicScript.LAYERS:
		var wav := load("res://audio/music/%s.wav" % spec[0]) as AudioStreamWAV
		var bars: float = wav.get_length() / bar if wav != null else 0.0
		var whole: bool = spec[0] == &"music_drone" or absf(bars - round(bars)) < 0.002
		all_ok = all_ok and wav != null and wav.loop_mode != AudioStreamWAV.LOOP_DISABLED and whole
		loops.append("%s %.3f bars" % [String(spec[0]).trim_prefix("music_"), bars])
	_check("M7 the score's layers loop, the rhythmic ones in whole bars of the drums", all_ok, ", ".join(loops))

	# M8 the duelist cries out in her own voice; a man in his
	SfxScript.recording = true
	SfxScript.recorded.clear()
	var duelist: CharacterBody3D = GUARD.instantiate()
	duelist.archetype = &"duelist"
	duelist.position = Vector3(-6, 0, -3)
	add_child(duelist)
	var swordsman: CharacterBody3D = GUARD.instantiate()
	swordsman.archetype = &"swordsman"
	swordsman.position = Vector3(6, 0, -3)
	add_child(swordsman)
	await _frames(5)
	duelist.voice(&"pain")
	swordsman.voice(&"pain")
	var spoken := SfxScript.recorded.map(func(entry): return entry[0])
	SfxScript.recording = false
	_check("M8 the duelist cries out in a woman's voice, a man in his", spoken.has(&"pain_f") and spoken.has(&"pain") and SfxScript._load_files(&"pain_f").size() >= 3 and SfxScript._load_files(&"death_f").size() >= 3,
		"heard %s" % [spoken])
	duelist.queue_free()
	swordsman.queue_free()


## Walks (or runs) the player forward and, at every footstep, how low the
## head bob is then (sin 2φ: -1 at the bottom) into `lows`. The steps taken.
func _steps_with_bob(running: bool, lows: Array) -> int:
	var taken := 0
	var last: int = player._steps
	Input.action_press("move_forward")
	if running:
		Input.action_press("sprint")
	for i in 110:
		await _frames(1)
		if player._steps != last:
			last = player._steps
			taken += 1
			# (The first steps come as the bob is still finding its weight.)
			lows.append(sin(player.juice.bob_phase() * 2.0))
	Input.action_release("move_forward")
	Input.action_release("sprint")
	await _frames(20)
	return taken


func _until(done: Callable, limit: int) -> void:
	for i in limit:
		if done.call():
			return
		await _frames(1)


func _rounded(values: Array) -> String:
	return ", ".join(values.map(func(v): return "%.2f" % v))


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _near(a: float, b: float, tol: float) -> bool:
	return absf(a - b) <= tol


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
