extends Node
## Level score driven by nearby hunting/fighting guards, health, wounds, pressure, and squad plans.
## Four synchronized loops fade by smoothed intensity; absent recordings are skipped. Sfx.warm() starts it.
## Real-time envelopes/sting cooldowns survive time scaling. Playback emits no gameplay sound stimulus.

const Sfx := preload("res://scripts/Audio/Sfx.gd")
const TimeFx := preload("res://scripts/Visual/TimeFx.gd")

const FOLDER := "res://audio/music/"
## [layer, where it starts coming in, where it is all there, its level (dB)].
## Levels set against each loop's loudness (tools/prepare_sfx.py): the drone
## low under everything, the drums the loudest, the whole of it under the
## fight's own sounds.
const LAYERS := [
	[&"music_drone", 0.02, 0.2, -17.0],
	[&"music_pulse", 0.28, 0.45, -9.3],
	[&"music_drums", 0.45, 0.62, -10.7],
	[&"music_severe", 0.7, 0.88, -14.3],
]
## Intensity rising (per second) and falling.
const RISE := 1.2
const FALL := 0.12
## Above this it has turned severe: the escalation hit, now and then.
const SEVERE := 0.72
const ESCALATE_EVERY := 14.0
## Not within this long (real seconds) of another of the score's hits (the
## HUD's stab as the fight opens): the two would pile up.
const STING_GAP := 3.0
## Guards this near count toward the fight.
const NEAR := 14.0
const CLOSE := 5.0
## A beat of the drums (130 bpm; music_pulse is one bar of four).
const BEAT := 60.0 / 130.0
## How far the score's own heartbeat (music_pulse) steps back when you are
## badly hurt (dB): your heart, in time with it, takes its place (Sfx).
const PULSE_YIELD := -10.0

var intensity := 0.0
var target := 0.0
var _layers := {}
var _playing := false
var _think := 0.0
var _escalated_at := -100.0
var _clock := 0.0
var _last_real := -1.0
var _last_health := -1.0
var _hurt_at := -100.0


## Adds one Music node to the current scene/tree root; detached contexts or an existing Music node are ignored.
## Called by Sfx.warm(); missing individual loop recordings are skipped during setup.
static func begin(context: Node) -> void:
	var tree := context.get_tree() if context != null and context.is_inside_tree() else null

	if tree == null:
		return

	var level: Node = tree.current_scene if tree.current_scene != null else tree.root

	if level.has_node("Music"):
		return

	var node: Node = (load("res://scripts/Audio/Music.gd") as GDScript).new()
	node.name = "Music"

	if level.is_node_ready():
		level.add_child(node)
	else:
		level.add_child.call_deferred(node)


## How bad the fight is, 0..1, from what is known about it:
##   hunting   guards near looking for you (investigating, searching)
##   fighting  guards near in a fight with you; close: those within reach
##   health    yours, 0..1; hurt: cut within the last moment
##   pressing  one of them on top of you (pressing, desperate, enraged)
##   plan      the squad pressing you hard
static func intensity_of(hunting: int, fighting: int, close: int, health: float, hurt: bool, pressing: bool, plan: bool) -> float:
	var x := 0.0

	if hunting > 0:
		x = 0.12

	if fighting > 0:
		# One man at you is a fight; each more makes it worse, the near ones
		# most. Numbers alone bring the drums in; it takes things going wrong
		# (below) to tip it over into the severe.
		x = 0.34 + 0.08 * float(mini(fighting, 5) - 1) + 0.04 * float(mini(close, 3))

	if fighting > 0 or hunting > 0:
		if health < 0.5:
			x += 0.12
		if health < 0.25:
			x += 0.12
		if hurt:
			x += 0.05
		if pressing:
			x += 0.08
		if plan:
			x += 0.1

	return clampf(x, 0.0, 1.0)


func _ready() -> void:
	for spec in LAYERS:
		var stream := _load_loop(spec[0])

		if stream == null:
			continue

		var player := AudioStreamPlayer.new()
		player.stream = stream
		player.volume_db = -80.0
		player.bus = Sfx.BUS_MUSIC if AudioServer.get_bus_index(Sfx.BUS_MUSIC) >= 0 else &"Master"
		add_child(player)
		_layers[spec[0]] = player


func _load_loop(layer: StringName) -> AudioStream:
	for extension in ["ogg", "wav"]:
		var path := "%s%s.%s" % [FOLDER, layer, extension]

		if ResourceLoader.exists(path):
			var stream: AudioStream = load(path)

			if stream is AudioStreamOggVorbis:
				(stream as AudioStreamOggVorbis).loop = true
			elif stream is AudioStreamWAV:
				# Imported to loop (audio/music/*.import); if not, looped here
				# over its whole length.
				var wav := stream as AudioStreamWAV

				if wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
					wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
					wav.loop_begin = 0
					wav.loop_end = int(round(wav.get_length() * wav.mix_rate))

			return stream

	return null


func _process(_delta: float) -> void:
	# Real time: slow motion and hit-stops do not hold the score back.
	var real := TimeFx.real_since(_last_real) if _last_real >= 0.0 else 0.0
	_last_real = TimeFx.real_time()
	_clock += real
	_think -= real

	if _think <= 0.0:
		_think = 0.25
		target = _judge()

	intensity = move_toward(intensity, target, real * (RISE if target > intensity else FALL))

	# The fight turning: once in a while, the hit as it goes over the edge.
	if intensity >= SEVERE and target >= SEVERE and _clock - _escalated_at > ESCALATE_EVERY:
		_escalated_at = _clock

		if TimeFx.real_time() - Sfx.sting_at >= STING_GAP:
			Sfx.play_flat(self, &"sting_escalate")

	if _layers.is_empty():
		return

	# All together from the start of a fight, so they stay in step; stopped
	# once it has faded right out, to start in step again next time.
	if intensity > 0.01 and not _playing:
		_playing = true

		for player in _layers.values():
			player.play()
	elif intensity <= 0.0 and _playing:
		_playing = false

		for player in _layers.values():
			player.stop()

	for spec in LAYERS:
		var player: AudioStreamPlayer = _layers.get(spec[0])

		if player == null:
			continue

		var amount := smoothstep(float(spec[1]), float(spec[2]), intensity)
		player.volume_db = lerpf(-60.0, float(spec[3]), sqrt(amount)) if amount > 0.001 else -80.0

		if spec[0] == &"music_pulse" and amount > 0.001:
			player.volume_db += PULSE_YIELD * _hurt_badly()


## Returns the pulse beat index (0..3), or -1 when its loop is absent, stopped, or below -45 dB.
func beat_now() -> int:
	var pulse: AudioStreamPlayer = _layers.get(&"music_pulse")

	if pulse == null or not pulse.playing or pulse.volume_db < -45.0:
		return -1

	return int(pulse.get_playback_position() / BEAT) % 4


## How badly hurt you are, 0 (not: over Sfx.HURT_AT) to 1 (all but dead).
func _hurt_badly() -> float:
	return clampf(1.0 - _last_health / Sfx.HURT_AT, 0.0, 1.0) if _last_health >= 0.0 else 0.0


func _judge() -> float:
	var tree := get_tree()
	var you := tree.get_first_node_in_group(&"player") as Node3D

	if you == null:
		return 0.0

	var hunting := 0
	var fighting := 0
	var close := 0
	var pressing := false
	var plan := false

	for node in tree.get_nodes_in_group(&"guards"):
		var guard := node as Node3D

		if guard == null or guard.get("state") == null:
			continue

		var d := guard.global_position.distance_to(you.global_position)

		if d > NEAR:
			continue

		var state := int(guard.get("state"))

		if state == 4:
			fighting += 1

			if d < CLOSE:
				close += 1

			var fighter: Variant = guard.get("_fighter")

			if fighter != null:
				if fighter.get("mood") in [&"pressing", &"desperate", &"enraged"]:
					pressing = true

				var squad: Variant = fighter.get("squad")

				if squad != null and squad.get("tactic") == &"press":
					plan = true
		elif state == 2 or state == 3:
			hunting += 1

	var health := Sfx.health_of(you, false)

	if _last_health >= 0.0 and health < _last_health - 0.001:
		_hurt_at = _clock

	_last_health = health
	return intensity_of(hunting, fighting, close, health, _clock - _hurt_at < 2.5, pressing, plan)


## Stops it for good: every layer let go of (leaving the level, tests).
func hush() -> void:
	for player in _layers.values():
		player.stop()
		player.stream = null

	_layers.clear()
	_playing = false


func _exit_tree() -> void:
	hush()
