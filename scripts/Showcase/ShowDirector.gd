extends Node
## The director of the NPC showcase: plays the night (a story: ShowNight.gd)
## as acts, each a list of beats. A beat does something (the intruder's
## verbs, a nudge to someone's rounds), asks the camera for a shot, and waits
## until something true of the world says it is done (a man's alert, the
## squad's plan, a man down, begging, dead). If it never comes true (the
## guards decide for themselves), it is let go after its timeout, logged, and
## the show goes on: a run never stalls.
##
## An act: {"title", "enter" (run as it starts, always), "stage" (run only
## when the show starts at it: the world put in the state it needs), "beats"}.
## The title and the beats may be Callables, asked for as the act starts (the
## ending's act is only known then).
## A beat: {"name", "do", "until" (true when done), "min" (s at least; alone,
## the beat's length), "enough" (s: done by then whatever, not skipped),
## "timeout" (s: let go, logged), "scene" (for ShowCamera: whom to watch, and
## how)}.
##
## Keys: 1-5 start from that act, N the next beat, V Act V's ending (E is
## the camera's: fly up), R the start again, Space pause, [ ] slow motion
## (1/4, 1/2, 1). A beat's time is the world's: slowed, it waits longer. The command line (after
## --): --act=N --ending=overwhelmed|victor|escape --auto --quit-at-end.

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


func setup(p_map: Node3D, p_story: RefCounted) -> void:
	map = p_map
	story = p_story

	if not reload.is_valid():
		reload = _reload_scene


## What the command line asks for (the arguments after --).
func read_args(args: PackedStringArray) -> void:
	for arg in args:
		if arg.begins_with("--act="):
			start_act = clampi(int(arg.trim_prefix("--act=")), 1, 5)
		elif arg.begins_with("--ending="):
			var asked := StringName(arg.trim_prefix("--ending="))

			if asked in ENDINGS:
				ending = asked
		elif arg == "--auto":
			auto = true
		elif arg == "--quit-at-end":
			quit_at_end = true


## Plays the night from `start_act` to its end.
func run() -> void:
	if story == null or _running:
		return

	_running = true
	var acts: Array = story.acts()

	for i in range(clampi(start_act - 1, 0, maxi(acts.size() - 1, 0)), acts.size()):
		if not is_inside_tree():
			return

		await _play_act(i + 1, acts[i], i == start_act - 1)

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


# ---------------------------------------------------------------------------
# Keys
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return

	var key := (event as InputEventKey).physical_keycode

	match key:
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
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
	start_act = clampi(act, 1, 5)
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


# ---------------------------------------------------------------------------
# Acts and beats
# ---------------------------------------------------------------------------

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
