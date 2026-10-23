extends Node3D
## The shop's living words (docs/superpowers/specs/2026-10-17-librarian-shop-design.md: "some books pour out chains of
## text ... waves of words fly from one bookstand to another"): a stream out of every novel and spellbook while it is
## open, curling up from its pages in its colour; and two slow waves always running between the stands, from the
## table of novels to the spellbook in the front corner, and from the spellbook in the right wall's gap across the
## shop to the same corner. All in the invented script until the user's words replace it (`set_words`).

const Glyphs := preload("res://scripts/Visual/Library/LibraryGlyphs.gd")
const WordChain := preload("res://scripts/Visual/Library/WordChain.gd")
const LibraryLight := preload("res://scripts/Visual/Library/LibraryLight.gd")

## A stream: how high it curls from the pages, how wide its turns, how many turns; its glyphs' size.
const STREAM_RISE := 0.5
const STREAM_TURN := 0.09
const STREAM_TURNS := 1.6
const STREAM_SIZE := 0.05
## The waves: their glyphs' size, how fast they go, the gold they burn.
const WAVE_SIZE := 0.075
const WAVE_SPEED := 0.22
const WAVE_COLOUR := Color("f0c67a")

var streams := {}
var waves: Array[Node3D] = []
var _projections := {}
var _atlas := {}


func build(lab: Node3D, projections: Array) -> void:
	name = "LibraryWords"
	_atlas = Glyphs.atlas("script")
	var novel := 0
	for i in lab.live_books.size():
		var book: LiveBook = lab.live_books[i]
		if book.kind == LiveBook.Kind.STUDY:
			continue
		var colour: Color = LibraryLight.COLOURS.get(book.section, Color.WHITE)
		if book.kind == LiveBook.Kind.NOVEL:
			colour = LibraryLight.NOVEL_COLOURS[novel % LibraryLight.NOVEL_COLOURS.size()]
			novel += 1
		var chain := WordChain.new()
		chain.name = "stream_%d" % i
		chain.size = STREAM_SIZE
		chain.speed = 0.16
		add_child(chain)
		chain.build(_stream(projections[i].origin_world(), float(i)), Glyphs.script(100 + i, 34), _atlas, colour)
		chain.set_presence(0.0)
		streams[book] = chain
		_projections[book] = projections[i]

	# The waves, between the stands' books (the lab's frame), arching over the shop's floor.
	var table: Vector3 = lab.FRONT_TABLE_AT + Vector3(0.0, lab.TABLE_TOP + 0.08, 0.0)
	var corner: Vector3 = lab.LECTERNS[0][0] + Vector3(0.0, 1.2, 0.0)
	var gap: Vector3 = lab.LECTERNS[1][0] + Vector3(0.0, 1.2, 0.0)
	# (Each curve climbs halfway to its middle point: these put both well over the head, under the vault.)
	var routes := [[table, Vector3(0.1, 3.6, -0.9), corner], [gap, Vector3(0.6, 4.0, -2.4), corner]]
	for k in routes.size():
		var r: Array = routes[k]
		var points := PackedVector3Array()
		for j in 41:
			var t := float(j) / 40.0
			var p: Vector3 = (r[0] as Vector3).lerp(r[1], t).lerp((r[1] as Vector3).lerp(r[2], t), t)
			# (A slow sway sideways along it, so it reads as a wave, not a wire.)
			p += Vector3(0.0, 0.0, 0.12 * sin(t * TAU * 1.5 + k)) * sin(t * PI)
			points.append(lab.to_global(p))
		var wave := WordChain.new()
		wave.name = "wave_%d" % k
		wave.size = WAVE_SIZE
		wave.speed = WAVE_SPEED
		add_child(wave)
		wave.build(points, Glyphs.script(300 + k, 54), _atlas, WAVE_COLOUR)
		wave.set_presence(1.0)
		# (Already running when the player walks in.)
		wave.run_from(0.7 + 0.2 * k)
		waves.append(wave)


## The user's words for every chain, in `atlas` (one text, laid in turn along each).
func set_words(text: String, atlas: Dictionary) -> void:
	for chain: Node3D in streams.values() + waves:
		chain.set_text(text, atlas)


func _process(_delta: float) -> void:
	for book: LiveBook in streams:
		var projection: Node3D = _projections[book]
		var presence: float = projection.presence if is_instance_valid(projection) else 0.0
		var chain: Node3D = streams[book]
		# (Exactly: a few millionths left over would keep a shut book's stream counted as there.)
		if chain.presence != presence:
			chain.set_presence(presence)


## A stream's path (world): out of the pages at `at`, curling up and outward.
static func _stream(at: Vector3, seed: float) -> PackedVector3Array:
	var points := PackedVector3Array()
	for j in 31:
		var t := float(j) / 30.0
		var a := t * TAU * STREAM_TURNS + seed
		var r := STREAM_TURN * smoothstep(0.0, 0.3, t) * (1.0 + t)
		points.append(at + Vector3(cos(a) * r, 0.01 + t * STREAM_RISE, sin(a) * r))
	return points
