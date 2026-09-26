## Listening check, not a test: the mix as it plays, logged, in the NPC gym
## (windowed, so sound is on; quiet). Every half second: the room as sounded
## out and the reverb it gives, what is playing on which bus, the torches
## crackling, the score and the place, how dull your hurt makes the world.
##   Godot --fixed-fps 60 --resolution 960x540 --path . res://tests/visual/stage_sound.tscn
extends Node3D

const GYM := preload("res://maps/npc_gym.tscn")
const Sfx := preload("res://scripts/Audio/Sfx.gd")
const TorchScript := preload("res://scripts/Visual/Torch.gd")

var gym: Node3D


func _ready() -> void:
	Sfx.volume_db = -60.0
	gym = GYM.instantiate()
	add_child(gym)
	await gym._baker.baked
	gym.player.invulnerable = true
	await _frames(30)
	print("-- in the hub")
	await _log_for(2.0)
	print("-- in a bay (the swordsman's, empty)")
	gym.player.global_position = Vector3(-17, 1.05, -26)
	await _log_for(2.5)

	# At the mouth of the squad's bay, facing in, as they come.
	gym.player.global_position = Vector3(8, 1.05, -26)
	gym.player.rotation.y = -PI * 0.5
	gym._start_bay(5)
	print("-- the squad")
	await _log_for(8.0)

	print("-- cut badly")
	gym.player.recover_delay = 1000.0
	gym.player.health = gym.player.max_health * 0.1
	await _log_for(3.0)
	Sfx.body_hit(35.0)
	print("-- a heavy blow")
	await _log_for(1.0)
	gym.player.health = gym.player.max_health
	print("-- healed")
	await _log_for(1.5)
	get_tree().quit()


func _log_for(seconds: float) -> void:
	for i in int(seconds * 2.0):
		await _frames(30)
		_log()


func _log() -> void:
	var node: Node = Sfx._node

	if node == null or not is_instance_valid(node):
		print("no Sfx node")
		return

	var world := AudioServer.get_bus_index(Sfx.BUS_WORLD)
	var reverb: AudioEffectReverb = null
	var hurt := -1.0

	for i in range(AudioServer.get_bus_effect_count(world)):
		var effect := AudioServer.get_bus_effect(world, i)

		if effect is AudioEffectReverb:
			reverb = effect
		elif effect is AudioEffectLowPassFilter and effect.has_meta(&"hurt"):
			hurt = (effect as AudioEffectLowPassFilter).cutoff_hz

	var buses := {}

	for player in node._players_3d:
		if player.playing:
			buses[player.bus] = int(buses.get(player.bus, 0)) + 1

	var torches := 0
	var crackling := 0

	for torch in gym.find_children("*", "Node3D", true, false):
		if torch.get_script() == TorchScript:
			torches += 1

			if torch.crackle != null and torch.crackle.playing:
				crackling += 1

	# (Sfx.warm starts them on the scene being played: here, this stager.)
	var level := get_tree().current_scene
	var music := level.get_node_or_null("Music")
	var ambience := level.get_node_or_null("Ambience")
	var camera := get_viewport().get_camera_3d()
	var place_db: float = ambience._player.volume_db if ambience != null and ambience._player != null else -99.0
	print("at %s | room %s heard %s | reverb wet %.2f size %.2f pre %.0f ms | playing %s | torches %d/%d | score %.2f place %.1f dB | hurt cutoff %.0f Hz" % [
		camera.global_position.snapped(Vector3.ONE * 0.1) if camera != null else Vector3.INF, node.room, node._room_heard, reverb.wet, reverb.room_size, reverb.predelay_msec, buses, crackling, torches,
		float(music.intensity) if music != null else -1.0, place_db, hurt])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
