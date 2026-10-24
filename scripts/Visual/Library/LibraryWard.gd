extends Node3D
## The chained book against its ward (docs/superpowers/specs/2026-10-17-librarian-shop-design.md: "Now and then it
## strains against its chain and its words try to crawl out, and a ward flares to push them back ... Five candle stubs
## on the chalk circle. Their flames lean away from the chained book, harder the more it strains, and settle when it
## rests"). As the book strains, its words seep out from under its cover's fore-edge, cross the desk, pour down its
## front and crawl over the boards toward the salt; short of the inner ring they rear and are thrown back, gone. The
## ward pushes as hard as the book strains, and holds while the words are at its chalk: each candle's flame (the
## corridor's, Vfx "candles") leans straight away from the book and burns taller, the chalk's rings glow, and the
## ward's own script burns up in the band between them (the invented script until the user's words are set), all of
## it gone again when the book is still.

const Glyphs := preload("res://scripts/Visual/Library/LibraryGlyphs.gd")
const WordChain := preload("res://scripts/Visual/Library/WordChain.gd")

## How hard a flame is pushed at the ward's full strength (m/s, the candle shader's draught); how much taller and
## wider it burns, and how much brighter its light.
const PUSH := 1.8
const TALLER := 0.35
const WIDER := 0.15
const BRIGHTER := 0.8
## A candle's light: how far it reaches (m; the corridor's cluster reaches 4).
const CANDLE_REACH := 1.4
## How fast the ward comes up and lets go (of its full strength, per s).
const RISE := 6.0
const FALL := 0.9
## The book's words: the unexorcised's colour (the cage's, LibraryLight's necromancy chartreuse), their size (m),
## how fast they crawl (m/s), how many glyphs each chain carries.
const WORDS_COLOUR := Color("b2ea3a")
const WORD_SIZE := 0.055
const WORD_SPEED := 1.3
const WORD_COUNT := 26
## The ward's own script in the band between its rings: its colour, its size (m), and the arcs it runs along
## (degrees round from the customers' side toward +x, clear of the opening and of his chair's foot on the band).
const WARD_COLOUR := Color("fff0c8")
const BAND_SIZE := 0.075
const BAND_ARCS := [Vector2(30.0, 163.0), Vector2(179.0, 330.0)]
## The chalk's glow at full strength (its emission: decals.py's ward_glow, the chalk's lines over black), warmed toward
## the ward's colour as it flares.
const GLOW := 1.15
const GLOW_TEXTURE := "res://textures/painted/underground/decal_ward_glow.png"
## The inner ring's radius (m; decals.py draws the rings at 0.7 and 0.91 of the decal's half-width, the outer one at
## the ward's radius).
const INNER_OF_OUTER := 0.7 / 0.91
## The words' ways in the corner's frame (the desk's middle on the floor, the customers' side +z): out from under the
## cover's fore-edge, over the desk between his things (the rituale, the reliquary, the oil phial), over its front
## edge and down its front, onto the boards toward the salt, turned back short of the inner ring, rearing up as they
## back toward the desk as they go, beside their own fall. Smoothed through these points.
const WAYS := [
	[Vector3(-0.925, 1.098, 0.08), Vector3(-0.86, 1.15, 0.12), Vector3(-0.74, 1.2, 0.24), Vector3(-0.63, 1.2, 0.36),
		Vector3(-0.61, 1.14, 0.445), Vector3(-0.6, 0.85, 0.45), Vector3(-0.59, 0.3, 0.45), Vector3(-0.58, 0.06, 0.47),
		Vector3(-0.56, 0.025, 0.54), Vector3(-0.5, 0.02, 0.64), Vector3(-0.48, 0.12, 0.57), Vector3(-0.46, 0.3, 0.47)],
	[Vector3(-0.925, 1.098, 0.0), Vector3(-0.85, 1.17, 0.03), Vector3(-0.6, 1.22, 0.06), Vector3(-0.42, 1.22, 0.16),
		Vector3(-0.35, 1.2, 0.32), Vector3(-0.34, 1.14, 0.445), Vector3(-0.33, 0.8, 0.45), Vector3(-0.32, 0.3, 0.45),
		Vector3(-0.31, 0.06, 0.47), Vector3(-0.29, 0.025, 0.56), Vector3(-0.22, 0.02, 0.76), Vector3(-0.21, 0.12, 0.66),
		Vector3(-0.2, 0.3, 0.52)],
	[Vector3(-0.925, 1.098, -0.08), Vector3(-0.84, 1.17, -0.07), Vector3(-0.55, 1.23, 0.0), Vector3(-0.15, 1.23, 0.06),
		Vector3(0.15, 1.22, 0.04), Vector3(0.34, 1.2, 0.2), Vector3(0.41, 1.15, 0.4), Vector3(0.42, 1.1, 0.445),
		Vector3(0.43, 0.8, 0.45), Vector3(0.44, 0.3, 0.45), Vector3(0.44, 0.06, 0.47), Vector3(0.43, 0.025, 0.55),
		Vector3(0.38, 0.02, 0.71), Vector3(0.35, 0.12, 0.62), Vector3(0.32, 0.3, 0.5)],
]

## The candles round the ward (each a Vfx "candles" of one flame, on its wick); how hard the ward pushes now (0-1).
var candles: Array[Node3D] = []
var strength := 0.0
## The book's words (WordChains), the ward's script in its band (one chain per arc; `band` the first, for its
## presence), its chalk (the ring decal, flaring).
var words: Array[Node3D] = []
var bands: Array[Node3D] = []
var band: Node3D
var ring: Decal
## Whether its words and script are drawn (the effects off, or the form light on, hide them).
var shown := true

var _chained: ChainedBook
var _frame := Transform3D.IDENTITY
var _radius := 1.0
## Since the book's words came out (s), or -1; the book's strain last frame.
var _crawl := -1.0
var _was := 0.0
## While each chain's words are at the chalk, from and to (s into the crawl); how long its words take to pass.
var _at_chalk: Array[Vector2] = []
var _through := 0.0
## Each candle's flame and halo (grown about its wick by their node's scale: a MultiMesh's instance does not read
## back), its light's energy.
var _flames: Array = []
var _energy := PackedFloat32Array()
## Each candle's way straight out from the book (world, level); the strength last drawn, and whether shown then (a
## still ward draws nothing again).
var _away: Array[Vector3] = []
var _drawn := -1.0
var _drawn_shown := true


func build(chained: ChainedBook, frame: Transform3D, radius: float, wicks: Array[Vector3], chalk: Decal) -> void:
	name = "LibraryWard"
	_chained = chained
	_frame = frame
	_radius = radius
	ring = chalk
	if ring != null and ResourceLoader.exists(GLOW_TEXTURE):
		ring.texture_emission = load(GLOW_TEXTURE)
		ring.emission_energy = 0.0

	for wick in wicks:
		var candle := Vfx.system("candles")
		candle.name = "ward_candle_%d" % candles.size()
		add_child(candle)
		Vfx.place(candle, wick, {"wicks": [wick]})
		Vfx.emit(candle, true)
		for light: OmniLight3D in candle.find_children("*", "OmniLight3D", false, false):
			light.omni_range = CANDLE_REACH
		var grown: Array[Node3D] = []
		for part in ["candles", "candle_halos"]:
			var draw := candle.find_child(part, false, false) as Node3D
			if draw != null:
				grown.append(draw)
		_flames.append(grown)
		_energy.append(candle.get("energy") if "energy" in candle else 0.0)
		var out: Vector3 = wick - _book()
		out.y = 0.0
		_away.append(out.normalized() if out.length() > 0.01 else Vector3.ZERO)
		candles.append(candle)

	var atlas := Glyphs.atlas("script")
	for k in WAYS.size():
		var chain := WordChain.new()
		chain.name = "words_%d" % k
		chain.size = WORD_SIZE
		chain.speed = WORD_SPEED
		add_child(chain)
		# (Facing up and toward the customers as far as the way lets them: flat on the desk and the boards, out from
		# the desk's front as they pour down it, never edge on to whoever stands before it.)
		chain.face = _frame.basis * Vector3(0.0, 0.6, 0.8).normalized()
		chain.build(_smoothed(WAYS[k]), Glyphs.script(500 + k, WORD_COUNT), atlas, WORDS_COLOUR)
		chain.set_presence(0.0)
		words.append(chain)
		# (Its words reach the chalk where its way comes farthest out over the boards.)
		var turn := 0.0
		var farthest := 0.0
		var along := 0.0
		var path: PackedVector3Array = chain.path
		for i in range(1, path.size()):
			along += path[i].distance_to(path[i - 1])
			var here := _frame.affine_inverse() * path[i]
			if here.y < 0.3 and Vector2(here.x, here.z).length() > farthest:
				farthest = Vector2(here.x, here.z).length()
				turn = along
		var lead := chain.text_length()
		_at_chalk.append(Vector2(turn, turn + lead) / WORD_SPEED)
		_through = maxf(_through, (chain.length + lead + chain.fade) / WORD_SPEED)

	var middle := (INNER_OF_OUTER + 1.0) * 0.5 * radius
	for k in BAND_ARCS.size():
		var arc: Vector2 = BAND_ARCS[k]
		var points := PackedVector3Array()
		var steps := int(ceil((arc.y - arc.x) / 3.0))
		for i in steps + 1:
			var a := deg_to_rad(lerpf(arc.x, arc.y, float(i) / steps))
			points.append(_frame * Vector3(middle * sin(a), 0.004, middle * cos(a)))
		var script := WordChain.new()
		script.name = "band_%d" % k
		script.size = BAND_SIZE
		script.speed = 0.0
		script.face = Vector3.UP
		add_child(script)
		script.build(points, Glyphs.script(600 + k, 4), atlas, WARD_COLOUR)
		_fill(script, 600 + k, atlas)
		script.set_presence(0.0)
		bands.append(script)
	band = bands[0]


## The user's words for the book's chains and the ward's script, in `atlas`.
func set_words(text: String, atlas: Dictionary) -> void:
	for chain: Node3D in words + bands:
		chain.set_text(text, atlas)


## A band's chain filled with as much script as lies along it, still, its middle at its arc's.
func _fill(chain: Node3D, seed: int, atlas: Dictionary) -> void:
	var room: float = chain.length - 2.0 * chain.fade - 0.04
	var count := 40
	for attempt in 6:
		chain.set_text(Glyphs.script(seed, count), atlas)
		var long: float = chain.text_length()
		if long <= room and long > room - 0.15:
			break
		count = maxi(4, int(count * room / maxf(long, 0.01)) - (1 if long > room else 0))
	chain.set_text(Glyphs.script(seed, count), atlas)
	# (An open chain's glyph i lies `flow - offset` along it: the text's middle laid at the arc's.)
	chain.run_from((chain.length + chain.text_length()) * 0.5 / chain.length)


func _process(delta: float) -> void:
	if _chained == null:
		return
	var strain := _chained.strain
	# The words come out as the book begins to strain.
	if strain > 0.0 and _was <= 0.0 and _crawl < 0.0:
		_crawl = 0.0
		for chain: Node3D in words:
			chain.run_from(0.0)
	_was = strain

	var at_chalk := 0.0
	if _crawl >= 0.0:
		_crawl += delta
		for window: Vector2 in _at_chalk:
			if _crawl >= window.x and _crawl <= window.y:
				at_chalk = 1.0
		if _crawl > _through:
			_crawl = -1.0
	var wanted := maxf(strain, at_chalk)
	strength = move_toward(strength, wanted, (RISE if wanted > strength else FALL) * delta)

	for chain: Node3D in words:
		var on := shown and _crawl >= 0.0
		if chain.visible != on:
			chain.set_presence(1.0 if on else 0.0)
	if strength == _drawn and shown == _drawn_shown:
		return
	_drawn = strength
	_drawn_shown = shown
	for script: Node3D in bands:
		script.set_presence(strength if shown else 0.0)
	if ring != null:
		ring.emission_energy = GLOW * strength
		ring.modulate = Color.WHITE.lerp(WARD_COLOUR, strength)

	for i in candles.size():
		var candle := candles[i]
		Vfx.blow(candle, _away[i] * PUSH * strength)
		for draw: Node3D in _flames[i]:
			draw.scale = Vector3(1.0 + WIDER * strength, 1.0 + TALLER * strength, 1.0 + WIDER * strength)
		if "energy" in candle:
			candle.set("energy", _energy[i] * (1.0 + BRIGHTER * strength))


## Where the book is (world): its cover's middle shut.
func _book() -> Vector3:
	if _chained.cover == null:
		return _frame.origin
	return (_chained.cover_rest * _chained.cover.get_aabb()).get_center()


## Points every 2 cm along a Catmull-Rom curve through `controls` (the corner's frame), in the world.
func _smoothed(controls: Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	for k in controls.size() - 1:
		var p0: Vector3 = controls[maxi(k - 1, 0)]
		var p1: Vector3 = controls[k]
		var p2: Vector3 = controls[k + 1]
		var p3: Vector3 = controls[mini(k + 2, controls.size() - 1)]
		var steps := maxi(2, int(ceil(p1.distance_to(p2) / 0.02)))
		for i in steps:
			out.append(_frame * p1.cubic_interpolate(p2, p0, p3, float(i) / steps))
	out.append(_frame * (controls[controls.size() - 1] as Vector3))
	return out
