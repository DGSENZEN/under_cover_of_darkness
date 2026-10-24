extends Node
## The librarian's books heard (docs/superpowers/specs/2026-10-24-underground-sound-layers-design.md): a shelf that
## rearranges itself while no one looks, by how it changed (heard behind you, never seen); each floating book's pages
## stirring as it drifts (silent while it rests on its board), its landing on the board and its lift off it; a live
## book's cover creaking and its leaves riffling as it starts to open, its clap shut. Every one-shot asks Focus first;
## what was played is counted with sound off too.

const Sfx := preload("res://scripts/Audio/Sfx.gd")
const Focus := preload("res://scripts/Audio/Focus.gd")

## A shelf's change, by kind: its sounds, each [sound, how long after (s), dB].
const STIRS := {
	&"by_height": [[&"shelf_shuffle", 0.0, 0.0]],
	&"push_home": [[&"shelf_slide", 0.0, 0.0], [&"shelf_tock", 0.35, 0.0]],
	&"close_gap": [[&"shelf_slide", 0.0, 0.0]],
	&"stand_up": [[&"shelf_tock", 0.0, 0.0]],
	&"square_stack": [[&"shelf_shuffle", 0.0, -3.0]],
}
## A live book opening: its creak, then its leaves this long after (s).
const RIFFLE_AFTER := 0.45
## A floating book's pages: heard this far (m); while it rests on its board (dB).
const FLUTTER_REACH := 6.0
const RESTING_DB := -60.0
## How fast its pages fade as it settles on the board, and come back as it lifts (dB/s).
const FADE_DB := 90.0

## What has played, by sound (and "refused"); the last of them, [time, sound, where]. Each floating book's pages.
var played := {}
var heard: Array = []
var flutters: Array[AudioStreamPlayer3D] = []

var _floating: Node3D
var _levels := PackedFloat32Array()
var _pending: Array = []
## Each happening's sounds are one to Focus: its first asks, the rest ride on that (by happening, while some wait).
var _happenings := 0
var _let := {}
var _clock := 0.0
var _rng := RandomNumberGenerator.new()


## Listens to the shelves (`stir`), the floating books and the live books.
func listen(stir: Node, floating: Node3D, live_books: Array) -> void:
	name = "book_sounds"
	_rng.seed = 33
	_floating = floating
	stir.stirred.connect(_on_stirred)
	floating.moved.connect(_on_moved)

	for book: LiveBook in live_books:
		book.opening.connect(_on_opening)
		book.closed.connect(_on_closed)


func _process(delta: float) -> void:
	_clock += delta

	# (Built here, not as the shop is set up: a level that hushes its players as it is set up must not reach them.)
	if flutters.is_empty() and _floating != null and Sfx.enabled:
		_flutter()

	for k in flutters.size():
		var resting: bool = _floating.state_of(k) == &"resting"
		var target := RESTING_DB if resting else float(Sfx.LOOP_GAIN[&"book_flutter"])
		_levels[k] = move_toward(_levels[k], target, FADE_DB * delta)
		Focus.base(flutters[k], _levels[k])

	while not _pending.is_empty() and _pending[0][0] <= _clock:
		var due: Array = _pending.pop_front()
		var happening: int = due[4]

		if not _let.has(happening):
			_let[happening] = _play(due[1], due[2], due[3])
		elif _let[happening]:
			_play(due[1], due[2], due[3], false)

		if not _pending.any(func(p: Array) -> bool: return p[4] == happening):
			_let.erase(happening)


func _exit_tree() -> void:
	for flutter in flutters:
		if is_instance_valid(flutter):
			flutter.stop()
			flutter.stream = null


## Each floating book's pages, carried in it.
func _flutter() -> void:
	var stream: AudioStream = load("res://audio/ambience/book_flutter.wav")

	for book: Node3D in _floating.books:
		var flutter := AudioStreamPlayer3D.new()
		flutter.name = "flutter"
		flutter.stream = stream
		flutter.bus = Sfx.BUS_WORLD
		flutter.unit_size = 1.0
		flutter.max_distance = FLUTTER_REACH
		flutter.attenuation_filter_cutoff_hz = Sfx.AIR_CUTOFF
		flutter.attenuation_filter_db = Sfx.AIR_DB
		flutter.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		book.add_child(flutter)
		Focus.hold(self, flutter, &"loop", float(Sfx.LOOP_GAIN[&"book_flutter"]))
		flutter.play(_rng.randf_range(0.0, stream.get_length()))
		flutters.append(flutter)
		_levels.append(float(Sfx.LOOP_GAIN[&"book_flutter"]))


func _on_stirred(_board: int, kind: StringName, at: Vector3) -> void:
	_happenings += 1

	for sound: Array in STIRS.get(kind, []):
		_later(sound[1], sound[0], at, sound[2])


func _on_moved(_k: int, what: StringName, at: Vector3) -> void:
	_happenings += 1

	if what == &"resting":
		_later(0.0, &"book_land", at, 0.0)
	elif what == &"rising":
		_later(0.0, &"book_lift", at, 0.0)


func _on_opening(book: LiveBook) -> void:
	_happenings += 1
	_later(0.0, &"book_open", book._middle(), 0.0)
	_later(RIFFLE_AFTER, &"book_riffle", book._middle(), 0.0)


func _on_closed(book: LiveBook) -> void:
	_happenings += 1
	_later(0.0, &"book_shut", book._middle(), 0.0)


## `sound` `after` s from now, as part of the happening last begun.
func _later(after: float, sound: StringName, at: Vector3, db: float) -> void:
	_pending.append([_clock + after, sound, at, db, _happenings])
	_pending.sort_custom(func(p: Array, q: Array) -> bool: return p[0] < q[0])


## Plays `sound` if Focus lets it (unless `ask` is false: the rest of a happening); whether it played.
func _play(sound: StringName, at: Vector3, db: float, ask := true) -> bool:
	if ask and not Focus.allow(self, &"detail", at):
		played[&"refused"] = int(played.get(&"refused", 0)) + 1
		return false

	Sfx.play(self, sound, at, db)
	played[sound] = int(played.get(sound, 0)) + 1
	heard.append([_clock, sound, at])

	if heard.size() > 32:
		heard.pop_front()

	return true
