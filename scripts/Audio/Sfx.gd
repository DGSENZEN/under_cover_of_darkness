extends Node
## Sound effects, by name: "clang", "flesh", "whoosh", "twang"...
##
##   Sfx.play(self, &"clang", point)              at a place in the world
##   Sfx.play(self, &"whoosh", point, -6.0, 1.2)  quieter, higher
##   Sfx.play_flat(self, &"hurt")                 inside your own head
##
## Every sound is a recording: res://audio/sfx/<name>.wav, or <name>_1.wav,
## <name>_2.wav... for variations picked at random, cut and levelled from the
## sound packs by tools/prepare_sfx.py (their sources and licences are in
## CREDITS.md). A name with no recording plays nothing.
##
## Up close every sound is heard as if a little way off (NEAR), and the mix
## goes through a limiter: a blow at arm's length plays as loud as the table
## says, never clipped.
##
## Depth. Sounds in the world play on the World bus, in the room's acoustics
## (the level root's "acoustics" meta: "stone", the default, a keep's halls;
## "cave"; "wood"; "outdoors"): a reverb, and a sound behind a wall is heard
## through it, muffled and quieter; far off, duller. Your own body's sounds
## (feet, breath, gear) play on the Body bus, close and dry but for a touch
## of the same room. The score and the place duck under the fight (Music and
## Ambience, sidechained to World). A sound's variations never play the same
## one twice running, and each is played a hair differently (pitch and
## level), never the same way twice.
##
## The space shapes it as you move: the room around you is sounded out
## (probe_room: a dozen rays) and the reverb follows it, tight in a passage,
## long in a hall, all but gone in the open. Far off (FAR), a sound plays on
## WorldFar, wetter and duller. A sound round a corner (a way to it along the
## floor, not much longer than straight) comes through the doorway, less
## muffled than one through solid wall. And your body: cut badly, the world
## goes dull and your heart is loud in your chest (world_cutoff_for, the
## heartbeat); a heavy blow deadens your hearing for a moment (body_hit).
##
## Only audio. What guards hear is the SoundBus, which is separate.

const AmbienceScript := preload("res://scripts/Audio/Ambience.gd")
const MusicScript := preload("res://scripts/Audio/Music.gd")

const FOLDER := "res://audio/sfx/"
## A sound counts as loaded once this many of its variations are.
const VARIANTS := 1
## Nearer than this to the listener, a sound plays as if it were this far,
## in the same direction. Closer, the distance boost would drown out how loud
## each sound is meant to be.
const NEAR := 2.0

## The buses, made once (_ensure_buses).
const BUS_WORLD := &"World"
const BUS_FAR := &"WorldFar"
const BUS_BODY := &"Body"
const BUS_MUSIC := &"Music"
const BUS_AMBIENCE := &"Ambience"
## Played on the Music bus rather than your Body's.
const MUSICAL := [&"sting_suspicious", &"sting_combat", &"sting_escalate"]
## The room: [room size, damping, wet, spread, hi-pass] for each "acoustics".
const ACOUSTICS := {
	"stone": [0.62, 0.45, 0.2, 1.0, 0.1],
	"cave": [0.9, 0.25, 0.32, 1.0, 0.05],
	"wood": [0.42, 0.7, 0.12, 0.8, 0.15],
	"outdoors": [0.2, 0.85, 0.05, 0.6, 0.2],
}
## A sound heard through a wall: this much quieter, and cut above this; one
## heard round a corner, less so.
const OCCLUDED_DB := -8.0
const OCCLUDED_CUTOFF := 900.0
const AROUND_DB := -3.5
const AROUND_CUTOFF := 2600.0
## Further than this, a sound plays on WorldFar.
const FAR := 12.0
## How far the room is sounded out, and how often (seconds).
const PROBE_REACH := 28.0
const PROBE_EVERY := 0.5
## Cut badly (under this share of your health), the world goes dull toward
## HURT_CUTOFF; a heavy blow deadens it toward RING_CUTOFF for a moment.
const HURT_AT := 0.35
const HURT_CUTOFF := 1800.0
const RING_CUTOFF := 1100.0
const OPEN_CUTOFF := 20000.0
## Air: how dull a sound grows toward the edge of hearing.
const AIR_CUTOFF := 7500.0
const AIR_DB := -10.0

## Every sound, and how loud it plays by default (dB).
const GAIN := {
	# Blades and the bow (the TomMusic pack), levelled by loudness.
	&"whoosh": -6.0,
	&"flesh": -2.5,
	&"clang": -3.0,
	&"parry": -1.0,
	&"twang": -4.0,
	&"arrow_thunk": -2.0,
	&"arrow_flesh": 0.0,
	&"blade_draw": -5.0,
	&"sheath": -6.0,
	&"bow_draw": -1.0,
	&"bow_out": -2.0,
	&"bow_away": -6.0,
	# Laid under a recording for a heavier blow, or on their own: the rush of
	# a big swing, a quick swish, the wet weight of a heavy cut, bone going.
	&"whoosh_heavy": -9.4,
	&"whoosh_light": -6.9,
	&"flesh_heavy": -5.5,
	&"bone_crack": 1.2,
	&"clank": -2.0,
	&"thud": -6.7,
	&"thud_wood": 0.3,
	&"kick": -3.5,
	&"body_fall": -4.8,
	&"ting": -3.2,
	&"explosion": 4.0,
	&"ignite": -4.4,
	&"burning": 0.9,
	&"rope_snap": 4.0,
	&"guard_break": 3.0,
	# Voices: yours when you are cut; theirs cut, dying, roaring, grunting.
	&"hurt": -7.5,
	&"pain": -6.6,
	&"death": -4.0,
	&"roar": -9.1,
	&"grunt": -5.4,
	&"effort": -8.4,
	&"heartbeat": -9.6,
	&"gear": -11.4,
	# The duelist's own voice (a woman's).
	&"pain_f": -5.2,
	&"death_f": -10.1,
	&"grunt_f": -5.4,
	&"roar_f": -3.7,
	# Their talk and their breath (GuardVoice), levelled against the cries
	# above (about -25 LUFS as heard): the murmur of talk well under them
	# (-32; a shout's delivery brings it up to them), laughs and grunts a
	# little under (-28), sighs, "hm"s and breaths quieter still, a sleeper's
	# snore quietest (-34).
	&"murmur": -12.1,
	&"laugh": -7.9,
	&"sigh": -16.9,
	&"sigh_f": -15.4,
	&"cough": -6.4,
	&"spit": -16.0,
	&"grunt_effort": -6.2,
	&"hm": -15.2,
	&"breath_heavy": -16.6,
	&"breath_scared": -9.7,
	&"yawn": -13.4,
	&"snore": -12.1,
	&"gasp": -7.1,
	# The world: feet, hands, doors, what you pick up. Recordings are
	# levelled against a loudness each kind of sound is meant to have (their
	# measured LUFS, tools/prepare_sfx.py): your steps about 8 dB under a
	# sword's swing, a run 3 dB over a walk; a guard's mail heard clearly a
	# room away; a door as a door.
	&"step_stone": -5.8,
	&"step_stone_run": -2.7,
	&"step_wood": -7.0,
	&"step_wood_run": -9.6,
	&"step_dirt": -11.4,
	&"step_dirt_run": -7.1,
	&"step_water": -6.8,
	&"step_water_run": -2.9,
	&"step_stone_chain": -2.0,
	&"step_stone_chain_run": -1.9,
	&"step_wood_chain": -2.9,
	&"step_wood_chain_run": -7.8,
	&"step_dirt_chain": -7.6,
	&"step_dirt_chain_run": -5.4,
	&"step_water_chain": -2.1,
	&"step_water_chain_run": -2.2,
	&"jump_stone": -15.5,
	&"jump_wood": -13.3,
	&"jump_dirt": -10.4,
	&"jump_water": -9.2,
	&"land_stone": -6.1,
	&"land_wood": -8.9,
	&"land_dirt": -7.1,
	&"land_water": -5.6,
	&"land_stone_chain": -6.2,
	&"land_wood_chain": -7.7,
	&"land_dirt_chain": -6.7,
	&"land_water_chain": -7.0,
	&"step_metal": -8.7,
	&"step_carpet": -5.2,
	&"grab": -2.8,
	&"scuff": -6.9,
	&"cloth": -12.6,
	&"creak_rope": -14.6,
	&"rattle_chain": -13.1,
	&"door_open": -4.3,
	&"door_close": -5.8,
	&"door_rattle": 2.3,
	&"unlock": -6.6,
	&"chest_open": -5.4,
	&"chest_close": -7.2,
	&"gate_open": -7.0,
	&"gate_close": -7.8,
	&"coins": -0.5,
	&"keys": -10.2,
	&"pickup": -5.1,
	# Lights and fire: target LUFS less measured (crackle -30, coal pop -28,
	# log settling -26, lighting a torch -24, snuffing -32, dousing -24, a
	# lantern's creak and bail -30), capped at +4.
	&"crackle": 3.2,
	&"coal_pop": 2.4,
	&"log_settle": -5.0,
	&"ignite_torch": -6.3,
	&"snuff": -14.8,
	&"douse": -7.0,
	&"lantern_creak": -14.2,
	&"bail_rattle": -6.4,
	# Not in the world: the music of being noticed.
	&"sting_suspicious": -13.1,
	&"sting_combat": -5.1,
	&"sting_escalate": -6.9,
}


## Floors the footstep recordings know. Anything else is walked on as the
## nearest of them (grass and gravel as dirt); carpet and metal have steps
## of their own but no runs, jumps, landings or mail.
const FLOORS := ["stone", "wood", "dirt", "water"]


## The recording for a foot on `surface` ("stone", "grass"...): `what` is
## "step", "jump" or "land", at a run or not, in mail or not (a guard's).
static func step(surface: String, running := false, what := "step", mail := false) -> StringName:
	var floor_name := "stone"

	match surface:
		"wood":
			floor_name = "wood"
		"grass", "dirt", "gravel":
			floor_name = "dirt"
		"water":
			floor_name = "water"
		"carpet", "metal":
			floor_name = surface

	# Carpet and metal: only steps of their own.
	if not (floor_name in FLOORS):
		if what == "step" and not mail:
			return StringName("step_" + floor_name)

		floor_name = "stone"

	match what:
		"jump":
			return StringName("jump_" + floor_name)
		"land":
			return StringName("land_%s%s" % [floor_name, "_chain" if mail else ""])

	return StringName("step_%s%s%s" % [floor_name, "_chain" if mail else "", "_run" if running else ""])


## A gameplay noise level (dB, as the SoundBus uses) as a change in volume:
## what guards would hear loudly, you hear loudly. 50 dB is unchanged.
static func loudness(noise_db: float) -> float:
	return clampf((noise_db - 50.0) * 0.45, -14.0, 6.0)

## Off in headless runs (tests, servers): there is nothing to hear, and a
## sound still playing at exit is reported as a leak.
static var enabled := DisplayServer.get_name() != "headless"
static var volume_db := 0.0

static var _bank := {}
## The take each sound last played, so the next is another.
static var _last_pick := {}
static var _mutex := Mutex.new()
static var _node: Node = null

## Tests: while true, every sound asked for is written down here as
## [name, volume_db, positional], whether or not audio is on.
static var recording := false
static var recorded: Array = []

## The room as last sounded out, and as the reverb has it now: [size, how
## enclosed], each 0..1.
var room := Vector2(0.5, 1.0)
var _room_heard := Vector2(0.5, 1.0)
var _room_shaped := Vector2(0.5, 1.0)
var _probe_in := 0.0
## The level's stuff (ACOUSTICS): the room's size and walls come from probing.
static var _material := "stone"
## How deadened your hearing is by the last heavy blow (0..1, fading).
static var _ringing := 0.0
var _heart_in := 0.0
var _heart_beat := -1
var _players_3d: Array[AudioStreamPlayer3D] = []
var _players_flat: Array[AudioStreamPlayer] = []
var _cursor_3d := 0
var _cursor_flat := 0
var _task := -1


# ---------------------------------------------------------------------------
# Playing
# ---------------------------------------------------------------------------

static func play(context: Node, sound: StringName, at: Vector3, volume := 0.0, pitch := 1.0, jitter := 0.04) -> void:
	if recording:
		recorded.append([sound, volume, true])

	var node := _node_for(context)

	if node == null:
		return

	# A hair different each time: pitch, and a decibel either way.
	node._play_3d(sound, at, volume + float(GAIN.get(sound, 0.0)) + randf_range(-1.0, 1.0), pitch * (1.0 + randf_range(-jitter, jitter)))


static func play_flat(context: Node, sound: StringName, volume := 0.0, pitch := 1.0, jitter := 0.03) -> void:
	if recording:
		recorded.append([sound, volume, false])

	var node := _node_for(context)

	if node == null:
		return

	var level := volume + float(GAIN.get(sound, 0.0)) + (0.0 if sound in MUSICAL else randf_range(-0.8, 0.8))
	node._play_flat(sound, level, pitch * (1.0 + randf_range(-jitter, jitter)))


## Loads every recording in the background, so the first blow of a fight
## does not wait for its sound to be read off disk.
static func warm(context: Node) -> void:
	var node := _node_for(context)

	if node != null and node._task == -1:
		node._task = WorkerThreadPool.add_task(node._warm_all, false, "Sfx recordings")

	# The place itself, under everything; its acoustics; its score.
	if node != null:
		AmbienceScript.begin(context)
		set_acoustics(String(_level_of(context).get_meta(&"acoustics", "stone")))
		MusicScript.begin(context)


## A variation of a sound, picked at random; null if it has no recording.
static func stream(sound: StringName) -> AudioStream:
	_mutex.lock()
	var variants: Array = _bank.get(sound, [])
	_mutex.unlock()

	if variants.is_empty():
		variants = _load_files(sound)

		if variants.is_empty():
			return null

		_mutex.lock()

		if not _bank.has(sound):
			_bank[sound] = variants

		variants = _bank[sound]
		_mutex.unlock()

	# Never the same take twice running.
	var pick := randi() % variants.size()

	if variants.size() > 1:
		var last: int = _last_pick.get(sound, -1)

		if pick == last:
			pick = (pick + 1 + randi() % (variants.size() - 1)) % variants.size()

		_last_pick[sound] = pick

	return variants[pick]


## Stops everything at once.
static func silence() -> void:
	if _node == null or not is_instance_valid(_node):
		return

	for player in _node._players_3d:
		player.stop()

	for player in _node._players_flat:
		player.stop()

	# The place and the score too.
	var level: Node = _node.get_parent()

	if level != null:
		for name in ["Ambience", "Music"]:
			var other := level.get_node_or_null(name)

			if other != null and other.has_method("hush"):
				other.hush()


static func player_count() -> int:
	return 0 if _node == null or not is_instance_valid(_node) else _node._busy()


static func _node_for(context: Node) -> Node:
	if not enabled or context == null or not context.is_inside_tree():
		return null

	if _node != null and is_instance_valid(_node) and not _node.is_queued_for_deletion():
		return _node

	var tree := context.get_tree()
	var parent: Node = tree.current_scene if tree.current_scene != null else tree.root
	var node: Node = (load("res://scripts/Audio/Sfx.gd") as GDScript).new()
	node.name = "Sfx"

	if parent.is_node_ready():
		parent.add_child(node)
	else:
		parent.add_child.call_deferred(node)

	_node = node
	return node


## Built at once, so a sound asked for during a level's setup has a player
## waiting for it.
func _init() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF

	for i in range(16):
		var player := AudioStreamPlayer3D.new()
		player.unit_size = 4.0
		# The ceiling on the distance boost. At NEAR the boost is +6 dB, so a
		# sound whose GAIN plus its own volume is at most 0 dB is never cut
		# off: the table still decides how loud it is.
		player.max_db = 6.0
		player.max_distance = 45.0
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		player.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		player.bus = BUS_WORLD
		add_child(player)
		_players_3d.append(player)

	for i in range(6):
		var player := AudioStreamPlayer.new()
		player.bus = BUS_BODY
		add_child(player)
		_players_flat.append(player)

	_ensure_limiter()
	_ensure_buses()


## A hard limiter on the master bus, once: loud blows at arm's length, and
## several at once, are held just under full scale instead of clipping.
static func _ensure_limiter() -> void:
	var master := AudioServer.get_bus_index(&"Master")

	if master < 0:
		return

	for i in range(AudioServer.get_bus_effect_count(master)):
		if AudioServer.get_bus_effect(master, i) is AudioEffectHardLimiter:
			return

	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = -0.5
	limiter.release = 0.08
	AudioServer.add_bus_effect(master, limiter)


## The buses under Master, made once: World (the room's reverb), Body (you,
## close), Music and Ambience (each pressed down a little while the World is
## loud: the fight comes first).
static func _ensure_buses() -> void:
	for bus in [BUS_WORLD, BUS_FAR, BUS_BODY, BUS_MUSIC, BUS_AMBIENCE]:
		if AudioServer.get_bus_index(bus) >= 0:
			continue

		AudioServer.add_bus()
		var index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus)
		AudioServer.set_bus_send(index, &"Master")

		match bus:
			BUS_WORLD:
				AudioServer.add_bus_effect(index, AudioEffectReverb.new())
				AudioServer.add_bus_effect(index, _hurt_filter())
			BUS_FAR:
				AudioServer.add_bus_effect(index, AudioEffectReverb.new())
				var air := AudioEffectLowPassFilter.new()
				air.cutoff_hz = 3800.0
				AudioServer.add_bus_effect(index, air)
				AudioServer.add_bus_effect(index, _hurt_filter())
			BUS_BODY:
				var near := AudioEffectReverb.new()
				near.room_size = 0.25
				near.damping = 0.7
				near.wet = 0.05
				near.dry = 1.0
				AudioServer.add_bus_effect(index, near)
			BUS_MUSIC, BUS_AMBIENCE:
				var duck := AudioEffectCompressor.new()
				duck.sidechain = BUS_WORLD
				duck.threshold = -26.0 if bus == BUS_MUSIC else -28.0
				duck.ratio = 3.5 if bus == BUS_MUSIC else 2.5
				duck.attack_us = 4000.0
				duck.release_ms = 320.0
				AudioServer.add_bus_effect(index, duck)

				# The place outside you goes dull when you are hurt; the score
				# does not.
				if bus == BUS_AMBIENCE:
					AudioServer.add_bus_effect(index, _hurt_filter())

	set_acoustics("stone")


## A low-pass wide open until you are hurt (world_cutoff_for).
static func _hurt_filter() -> AudioEffectLowPassFilter:
	var filter := AudioEffectLowPassFilter.new()
	filter.cutoff_hz = OPEN_CUTOFF
	filter.set_meta(&"hurt", true)
	return filter


## How dull the world sounds (a low-pass cutoff, Hz) with `health` (0..1) and
## the ringing of a heavy blow (0..1).
static func world_cutoff_for(health: float, ringing: float) -> float:
	var hurt := clampf(health / HURT_AT, 0.0, 1.0)
	var cutoff := exp(lerpf(log(HURT_CUTOFF), log(OPEN_CUTOFF), hurt))
	return minf(cutoff, exp(lerpf(log(OPEN_CUTOFF), log(RING_CUTOFF), clampf(ringing, 0.0, 1.0))))


## A blow landed on you (PlayerCombat.on_hurt): a heavy one deadens your
## hearing for a moment.
static func body_hit(amount: float) -> void:
	_ringing = maxf(_ringing, clampf((amount - 10.0) / 30.0, 0.0, 1.0))


## Sounds out the room around `origin`: [size 0..1, enclosed 0..1], from a
## dozen rays (the walls, the ceiling) out to PROBE_REACH. Its size is how far
## off the walls it found are (a small room with its door open is still
## small); how enclosed, how many of the rays found one (the open sky, a
## doorway, a long hall let the sound away).
static func probe_room(space: PhysicsDirectSpaceState3D, origin: Vector3, exclude: Array[RID]) -> Vector2:
	var directions: Array[Vector3] = []

	for i in 8:
		directions.append(Vector3(cos(i * TAU / 8.0), 0.0, sin(i * TAU / 8.0)))

	for i in 3:
		var a := i * TAU / 3.0 + 0.5
		directions.append(Vector3(cos(a) * 0.7, 0.7, sin(a) * 0.7).normalized())

	directions.append(Vector3.UP)
	var hits := 0
	var total := 0.0

	for direction in directions:
		var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * PROBE_REACH, 1, exclude)
		query.collide_with_areas = false
		var hit := space.intersect_ray(query)

		if hit.is_empty():
			continue

		hits += 1
		total += origin.distance_to(hit["position"])

	if hits == 0:
		return Vector2(1.0, 0.0)

	var mean := total / float(hits)
	return Vector2(clampf((mean - 1.5) / 16.0, 0.0, 1.0), float(hits) / float(directions.size()))


## Which bus a sound this far off plays on.
static func bus_for_distance(distance: float) -> StringName:
	return BUS_FAR if distance > FAR else BUS_WORLD


## What the level is made of (ACOUSTICS): its walls' damping, how long a big
## room of it rings. The room itself (its size, how enclosed) is sounded out
## as you go (shape_room).
static func set_acoustics(kind: String) -> void:
	_material = kind if ACOUSTICS.has(kind) else "stone"
	shape_room(Vector2(0.5, 1.0))


## The reverb for a room of `shape` ([size, enclosed], probe_room) made of
## the level's stuff: bigger rooms ring longer, the open air barely at all;
## far off, everything is wetter.
static func shape_room(shape: Vector2) -> void:
	var stuff: Array = ACOUSTICS.get(_material, ACOUSTICS["stone"])

	for bus in [BUS_WORLD, BUS_FAR]:
		var index := AudioServer.get_bus_index(bus)

		if index < 0:
			continue

		for i in range(AudioServer.get_bus_effect_count(index)):
			var reverb := AudioServer.get_bus_effect(index, i) as AudioEffectReverb

			if reverb == null:
				continue

			var far := 1.0 if bus == BUS_FAR else 0.0
			reverb.room_size = clampf(lerpf(0.18, float(stuff[0]) + 0.2, shape.x) + 0.1 * far, 0.0, 1.0)
			reverb.damping = stuff[1]
			reverb.wet = clampf(lerpf(0.035, float(stuff[2]), shape.y) * (1.0 + 0.8 * far), 0.0, 0.6)
			reverb.spread = stuff[3]
			reverb.hipass = stuff[4]
			reverb.dry = 1.0 - 0.3 * far
			reverb.predelay_msec = lerpf(6.0, 40.0, shape.x)


static func _level_of(context: Node) -> Node:
	var tree := context.get_tree() if context != null and context.is_inside_tree() else null

	if tree == null:
		return context

	return tree.current_scene if tree.current_scene != null else tree.root


func _exit_tree() -> void:
	# Anything still sounding lets go of its stream now, not after exit.
	for player in _players_3d:
		player.stop()
		player.stream = null

	for player in _players_flat:
		player.stop()
		player.stream = null

	if _task != -1:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1

	# Leaving the level: the recordings are quick to load again.
	if _node == self:
		_node = null
		_mutex.lock()
		_bank.clear()
		_mutex.unlock()


func _play_3d(sound: StringName, at: Vector3, volume: float, pitch: float) -> void:
	# Asked for while the level is still being set up: nothing can play yet.
	if not is_inside_tree():
		return

	var chosen := stream(sound)

	if chosen == null:
		return

	var player := _free_player_3d()
	player.stream = chosen
	player.pitch_scale = clampf(pitch, 0.25, 4.0)
	var camera := get_viewport().get_camera_3d()
	player.bus = bus_for_distance(camera.global_position.distance_to(at)) if camera != null else BUS_WORLD

	# Through a wall: muffled and quieter; round a corner, a little. In the
	# open: only the air dulls it with distance.
	var hidden := _occlusion(at)

	if hidden >= 1.0:
		player.volume_db = volume + volume_db + OCCLUDED_DB
		player.attenuation_filter_cutoff_hz = OCCLUDED_CUTOFF
		player.attenuation_filter_db = -24.0
	elif hidden > 0.0:
		player.volume_db = volume + volume_db + AROUND_DB
		player.attenuation_filter_cutoff_hz = AROUND_CUTOFF
		player.attenuation_filter_db = -18.0
	else:
		player.volume_db = volume + volume_db
		player.attenuation_filter_cutoff_hz = AIR_CUTOFF
		player.attenuation_filter_db = AIR_DB

	at = _at_least_near(at)

	if player.is_inside_tree():
		player.global_position = at
	else:
		player.position = at

	player.play()


## How much stands between you and `at` (_occlusion): 0, 0.5 a corner, 1 a
## wall. 0 with sound off.
static func occlusion_at(context: Node, at: Vector3) -> float:
	var node := _node_for(context)
	return node._occlusion(at) if node != null else 0.0


## Whether something solid (the level, a closed door) stands between the
## listener and `at`.
func _occluded(at: Vector3) -> bool:
	return _occlusion(at) >= 1.0


## How much stands between the listener and `at`: 0 nothing; 0.5 a corner (a
## way round to it along the floor, not much longer than straight: it comes
## through the doorway); 1 solid wall.
func _occlusion(at: Vector3) -> float:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null

	if camera == null or camera.global_position.distance_to(at) < 1.5:
		return 0.0

	var query := PhysicsRayQueryParameters3D.create(camera.global_position, at, 1, _listener_exclude())
	query.collide_with_areas = false
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)

	# Nothing between us, or only the thing making the sound (a door
	# creaking open is heard from the door).
	if hit.is_empty() or (hit["position"] as Vector3).distance_to(at) <= 0.6:
		return 0.0

	var straight := camera.global_position.distance_to(at)

	if straight > PROBE_REACH:
		return 1.0

	var map := camera.get_world_3d().navigation_map

	if NavigationServer3D.map_get_iteration_id(map) == 0 or NavigationServer3D.map_get_regions(map).is_empty():
		return 1.0

	var from := NavigationServer3D.map_get_closest_point(map, camera.global_position)
	var to := NavigationServer3D.map_get_closest_point(map, at)

	if from.distance_to(camera.global_position) > 2.5 or to.distance_to(at) > 2.5:
		return 1.0

	var path := NavigationServer3D.map_get_path(map, from, to, true)

	if path.is_empty() or path[path.size() - 1].distance_to(to) > 0.5:
		return 1.0

	var along := 0.0

	for i in range(1, path.size()):
		along += path[i - 1].distance_to(path[i])

	return 0.5 if along <= straight * 1.7 + 1.0 else 1.0


func _listener_exclude() -> Array[RID]:
	var exclude: Array[RID] = []

	for body in get_tree().get_nodes_in_group(&"player"):
		if body is CollisionObject3D:
			exclude.append((body as CollisionObject3D).get_rid())

	return exclude


## How whole "you" are for what your hurt does to the sound (0 all but dead,
## 1 unhurt): your health; unhurt when dead, when nobody is there, or when
## the one they are after is not you (a puppet: the showcase's intruder).
## `dead_is_whole` false: a dead man's health counts as it is (Music).
static func health_of(you: Node, dead_is_whole := true) -> float:
	if you == null or you.get("puppet") == true or you.get("health") == null or you.get("max_health") == null:
		return 1.0

	if dead_is_whole and you.get("is_dead") == true:
		return 1.0

	return clampf(float(you.get("health")) / maxf(float(you.get("max_health")), 1.0), 0.0, 1.0)


## Every frame: the room sounded out now and then and the reverb eased
## toward it; how dull your hurt makes the world; your heart.
func _process(delta: float) -> void:
	var real := delta / maxf(Engine.time_scale, 0.05)
	var camera := get_viewport().get_camera_3d()

	if camera != null:
		_probe_in -= real

		if _probe_in <= 0.0:
			_probe_in = PROBE_EVERY
			room = probe_room(camera.get_world_3d().direct_space_state, camera.global_position, _listener_exclude())

		_room_heard = _room_heard.lerp(room, 1.0 - exp(-1.6 * real))

		if _room_heard.distance_to(_room_shaped) > 0.004:
			_room_shaped = _room_heard
			shape_room(_room_heard)

	var health := health_of(get_tree().get_first_node_in_group(&"player"))

	_ringing = maxf(_ringing - real / 0.8, 0.0)
	var cutoff := world_cutoff_for(health, _ringing)

	for bus in [BUS_WORLD, BUS_FAR, BUS_AMBIENCE]:
		var index := AudioServer.get_bus_index(bus)

		for i in range(AudioServer.get_bus_effect_count(index) if index >= 0 else 0):
			var filter := AudioServer.get_bus_effect(index, i) as AudioEffectLowPassFilter

			# (WorldFar's own air filter stays at 3.8 kHz; only the hurt one moves.)
			if filter != null and filter.has_meta(&"hurt") and not is_equal_approx(filter.cutoff_hz, cutoff):
				filter.cutoff_hz = cutoff

	# Near done: your heart, louder and quicker the worse it is. In a fight
	# it falls in with the score's beat (Music.beat_now: every other beat,
	# then every one) and the score's own pulse steps back for it; out of one
	# it keeps its own time.
	if health < HURT_AT:
		var worse := 1.0 - health / HURT_AT
		var level := lerpf(-12.0, 0.0, worse)
		var music := get_parent().get_node_or_null("Music") if get_parent() != null else null
		var beat: int = music.beat_now() if music != null and music.has_method("beat_now") else -1

		if beat >= 0:
			_heart_in = 0.0

			if beat != _heart_beat:
				_heart_beat = beat

				if worse > 0.5 or beat % 2 == 0:
					play_flat(self, &"heartbeat", level, 1.0, 0.01)
		else:
			_heart_beat = -1
			_heart_in -= real

			if _heart_in <= 0.0:
				_heart_in = 60.0 / lerpf(72.0, 118.0, worse)
				play_flat(self, &"heartbeat", level, 1.0, 0.01)
	else:
		_heart_in = 0.0
		_heart_beat = -1


## Where a sound at `at` is heard from: no nearer to the listener than NEAR.
func _at_least_near(at: Vector3) -> Vector3:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null

	if camera == null:
		return at

	var ears := camera.global_position
	var offset := at - ears

	if offset.length() >= NEAR:
		return at

	var direction := offset.normalized() if offset.length() > 0.01 else -camera.global_basis.z
	return ears + direction * NEAR


func _play_flat(sound: StringName, volume: float, pitch: float) -> void:
	if not is_inside_tree():
		return

	var chosen := stream(sound)

	if chosen == null:
		return

	var player := _players_flat[_cursor_flat]
	_cursor_flat = (_cursor_flat + 1) % _players_flat.size()
	player.stream = chosen
	player.bus = BUS_MUSIC if sound in MUSICAL else BUS_BODY
	player.volume_db = volume + volume_db
	player.pitch_scale = clampf(pitch, 0.25, 4.0)
	player.play()


## A player not in use, or failing that the one used longest ago.
func _free_player_3d() -> AudioStreamPlayer3D:
	for i in range(_players_3d.size()):
		var index := (_cursor_3d + i) % _players_3d.size()

		if not _players_3d[index].playing:
			_cursor_3d = (index + 1) % _players_3d.size()
			return _players_3d[index]

	var player := _players_3d[_cursor_3d]
	_cursor_3d = (_cursor_3d + 1) % _players_3d.size()
	return player


func _busy() -> int:
	var busy := 0

	for player in _players_3d:
		if player.playing:
			busy += 1

	for player in _players_flat:
		if player.playing:
			busy += 1

	return busy


func _warm_all() -> void:
	for sound in GAIN.keys():
		_mutex.lock()
		var known: bool = _bank.has(sound) and (_bank[sound] as Array).size() >= VARIANTS
		_mutex.unlock()

		if known:
			continue

		var variants := _load_files(sound)

		if variants.is_empty():
			continue

		_mutex.lock()
		_bank[sound] = variants
		_mutex.unlock()


static func _load_files(sound: StringName) -> Array:
	var found := []

	for extension in ["wav", "ogg"]:
		var single := "%s%s.%s" % [FOLDER, sound, extension]

		if ResourceLoader.exists(single):
			found.append(load(single))

		for i in range(1, 9):
			var numbered := "%s%s_%d.%s" % [FOLDER, sound, i, extension]

			if ResourceLoader.exists(numbered):
				found.append(load(numbered))

	return found
