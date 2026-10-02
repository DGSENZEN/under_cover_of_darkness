extends Node
## Runs story acts and beats, emitting camera/overlay cues while predicates observe live world state.
## Beat timers use scaled physics time and pause with the tree; timeouts log/emit a skip so shows can continue.
## Controls: 1-6 acts, N next beat, V ending, R restart, Space pause, [/] speed.
## User arguments: --act=N --ending=overwhelmed|victor|escape --auto --quit-at-end.
## Act/beat schemas and lifecycle are documented in docs/systems/cinematics.md.

const SquadScript := preload("res://scripts/AISystem/Squad.gd")
const GarrisonScript := preload("res://scripts/AISystem/Garrison.gd")
const TimeFx := preload("res://scripts/Visual/TimeFx.gd")
const LightProbe := preload("res://scripts/StimuliSystem/LightProbe.gd")

signal act_started(index: int, title: String)
signal beat_started(beat_name: StringName, scene: Dictionary)
signal beat_skipped(beat_name: StringName)
signal show_ended
## The ending changed (E), or the show speed ([ ]): for the overlay.
signal ending_chosen(ending: StringName)
signal speed_changed(scale: float)
signal paused_changed(paused: bool)

## The show speeds [ and ] step through.
const SPEEDS := [0.25, 0.5, 1.0]
const ENDINGS := [&"random", &"overwhelmed", &"victor", &"escape"]
## Quit this long after the end (--quit-at-end), real seconds.
const QUIT_AFTER := 3.0
## A beat with no timeout of its own.
const DEFAULT_TIMEOUT := 30.0
## The most acts a night has (the garrison's six; the yard's has five).
const MAX_ACTS := 6

## Which act the show starts at, and which ending: kept across a reload.
static var start_act := 1
static var ending: StringName = &"random"

var map: Node3D = null
var story: RefCounted = null
## No hands on it: the camera left to the director (--auto).
var auto := false
var quit_at_end := false
## Where the show is: the act (1-based) and the beat under way.
var act_index := 0
var beat_name: StringName = &""
## Every beat skipped, as printed.
var log_lines: Array[String] = []
## How a jump reloads the showcase (a test swaps its own in).
var reload: Callable

var _speed_index := 2
var _skip := false
var _resolved: StringName = &""
var _running := false


func _init() -> void:
	name = "Director"
	process_mode = Node.PROCESS_MODE_ALWAYS


## Binds a map and dynamic story object exposing acts(); installs the default scene reload Callable when absent.
func setup(p_map: Node3D, p_story: RefCounted) -> void:
	map = p_map
	story = p_story

	if not reload.is_valid():
		reload = _reload_scene


## What the command line asks for (the arguments after --).
func read_args(args: PackedStringArray) -> void:
	for arg in args:
		if arg.begins_with("--act="):
			start_act = clampi(int(arg.trim_prefix("--act=")), 1, MAX_ACTS)
		elif arg.begins_with("--ending="):
			var asked := StringName(arg.trim_prefix("--ending="))

			if asked in ENDINGS:
				ending = asked
		elif arg == "--auto":
			auto = true
		elif arg == "--quit-at-end":
			quit_at_end = true


## Runs acts asynchronously from the clamped start_act; emits show_ended and optionally quits after a real-time delay.
## Null story or an already-running show is ignored; leaving the tree aborts the run.
func run() -> void:
	if story == null or _running:
		return

	_running = true
	var acts: Array = story.acts()
	# A night of fewer acts than asked for starts at its last, staged as a
	# start there is.
	var first := clampi(start_act - 1, 0, maxi(acts.size() - 1, 0))

	for i in range(first, acts.size()):
		if not is_inside_tree():
			return

		await _play_act(i + 1, acts[i], i == first)

	_running = false
	show_ended.emit()

	if quit_at_end and is_inside_tree():
		await get_tree().create_timer(QUIT_AFTER, true, false, true).timeout
		get_tree().quit()


## The ending this run plays: the chosen one, or (random) one of the three,
## settled once per run.
func chosen_ending() -> StringName:
	if ending != &"random":
		return ending

	if _resolved == &"":
		_resolved = [&"overwhelmed", &"victor", &"escape"][randi() % 3]

	return _resolved


# Keys

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return

	var key := (event as InputEventKey).physical_keycode

	match key:
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
			jump_to(key - KEY_0)
		KEY_N:
			next_beat()
		KEY_V:
			cycle_ending()
		KEY_R:
			jump_to(1)
		KEY_SPACE:
			toggle_pause()
		KEY_BRACKETLEFT:
			set_speed(_speed_index - 1)
		KEY_BRACKETRIGHT:
			set_speed(_speed_index + 1)
		_:
			return

	get_viewport().set_input_as_handled()


## Starts the show again at `act`: everything the level remembers is
## forgotten (hunts, the garrison's memory, slowed time, the light cache),
## and the showcase is loaded afresh.
func jump_to(act: int) -> void:
	start_act = clampi(act, 1, MAX_ACTS)
	get_tree().paused = false
	SquadScript.clear_all()
	GarrisonScript.clear_all()
	TimeFx.clear()
	TimeFx.set_base(1.0)
	LightProbe.invalidate()
	_speed_index = SPEEDS.size() - 1

	if reload.is_valid():
		await reload.call()


## Gone (the showcase closed or reloaded): time back to normal for what
## comes after, unless another director has set the speed since.
func _exit_tree() -> void:
	if is_equal_approx(TimeFx.base, SPEEDS[_speed_index]):
		TimeFx.clear()
		TimeFx.set_base(1.0)


func next_beat() -> void:
	_skip = true


func cycle_ending() -> void:
	ending = ENDINGS[(ENDINGS.find(ending) + 1) % ENDINGS.size()]
	_resolved = &""
	ending_chosen.emit(ending)


func toggle_pause() -> void:
	get_tree().paused = not get_tree().paused
	paused_changed.emit(get_tree().paused)


## The show speed, by index into SPEEDS.
func set_speed(index: int) -> void:
	_speed_index = clampi(index, 0, SPEEDS.size() - 1)
	TimeFx.set_base(SPEEDS[_speed_index])
	speed_changed.emit(SPEEDS[_speed_index])


func speed() -> float:
	return SPEEDS[_speed_index]


# Acts and beats

func _play_act(index: int, act: Dictionary, first: bool) -> void:
	act_index = index

	if first and index > 1 and act.has("stage"):
		(act["stage"] as Callable).call()

	if act.has("enter"):
		(act["enter"] as Callable).call()

	var title: Variant = act.get("title", "")
	var beats: Variant = act.get("beats", [])
	act_started.emit(index, String((title as Callable).call() if title is Callable else title))

	for beat in ((beats as Callable).call() if beats is Callable else beats):
		if not is_inside_tree():
			return

		await _play_beat(beat)


func _play_beat(beat: Dictionary) -> void:
	beat_name = StringName(beat.get("name", &""))
	beat_started.emit(beat_name, beat.get("scene", {}))

	if beat.has("do"):
		(beat["do"] as Callable).call()

	var until: Callable = beat.get("until", Callable())
	var least := float(beat.get("min", 0.0))
	var timeout := float(beat.get("timeout", DEFAULT_TIMEOUT))
	var enough := float(beat.get("enough", INF))
	var elapsed := 0.0
	_skip = false

	while is_inside_tree():
		await get_tree().physics_frame

		# Paused, the night waits.
		if get_tree().paused:
			continue

		# The world's time, not the wall's: in slow motion (or a hit-stop) a
		# beat waits as long as the world takes.
		elapsed += Engine.time_scale / float(Engine.physics_ticks_per_second)

		if _skip:
			_skip = false
			return

		if elapsed >= least and (not until.is_valid() or bool(until.call()) or elapsed >= enough):
			return

		if elapsed >= timeout:
			var line := "[show] skipped %s (act %d, %.0f s)" % [beat_name, act_index, timeout]
			print(line)
			log_lines.append(line)
			beat_skipped.emit(beat_name)
			return


func _reload_scene() -> void:
	get_tree().reload_current_scene()
