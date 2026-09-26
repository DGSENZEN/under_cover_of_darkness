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
## Only audio. What guards hear is the SoundBus, which is separate.

const AmbienceScript := preload("res://scripts/Audio/Ambience.gd")

const FOLDER := "res://audio/sfx/"
## A sound counts as loaded once this many of its variations are.
const VARIANTS := 1
## Nearer than this to the listener, a sound plays as if it were this far,
## in the same direction. Closer, the distance boost would drown out how loud
## each sound is meant to be.
const NEAR := 2.0

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
	&"grunt": -11.1,
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
	# Not in the world: the music of being noticed.
	&"sting_suspicious": -17.4,
	&"sting_combat": -10.8,
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
static var _mutex := Mutex.new()
static var _node: Node = null

## Tests: while true, every sound asked for is written down here as
## [name, volume_db, positional], whether or not audio is on.
static var recording := false
static var recorded: Array = []

var _players_3d: Array[AudioStreamPlayer3D] = []
var _players_flat: Array[AudioStreamPlayer] = []
var _cursor_3d := 0
var _cursor_flat := 0
var _task := -1


# ---------------------------------------------------------------------------
# Playing
# ---------------------------------------------------------------------------

static func play(context: Node, sound: StringName, at: Vector3, volume := 0.0, pitch := 1.0, jitter := 0.08) -> void:
	if recording:
		recorded.append([sound, volume, true])

	var node := _node_for(context)

	if node == null:
		return

	node._play_3d(sound, at, volume + float(GAIN.get(sound, 0.0)), pitch * (1.0 + randf_range(-jitter, jitter)))


static func play_flat(context: Node, sound: StringName, volume := 0.0, pitch := 1.0, jitter := 0.05) -> void:
	if recording:
		recorded.append([sound, volume, false])

	var node := _node_for(context)

	if node == null:
		return

	node._play_flat(sound, volume + float(GAIN.get(sound, 0.0)), pitch * (1.0 + randf_range(-jitter, jitter)))


## Loads every recording in the background, so the first blow of a fight
## does not wait for its sound to be read off disk.
static func warm(context: Node) -> void:
	var node := _node_for(context)

	if node != null and node._task == -1:
		node._task = WorkerThreadPool.add_task(node._warm_all, false, "Sfx recordings")

	# The place itself, under everything.
	if node != null:
		AmbienceScript.begin(context)


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

	return variants[randi() % variants.size()]


## Stops everything at once.
static func silence() -> void:
	if _node == null or not is_instance_valid(_node):
		return

	for player in _node._players_3d:
		player.stop()

	for player in _node._players_flat:
		player.stop()


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
		add_child(player)
		_players_3d.append(player)

	for i in range(6):
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players_flat.append(player)

	_ensure_limiter()


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
	player.volume_db = volume + volume_db
	player.pitch_scale = clampf(pitch, 0.25, 4.0)
	at = _at_least_near(at)

	if player.is_inside_tree():
		player.global_position = at
	else:
		player.position = at

	player.play()


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
