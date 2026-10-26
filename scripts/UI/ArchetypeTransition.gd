class_name ArchetypeTransition
extends ColorRect
## The chosen archetype's way into the game: its paint takes the whole
## screen from its card outward and ends in the dark (archetype_transition).
const SHADER := preload("res://scripts/UI/archetype_transition.gdshader")
const TIME := 1.3
## Factotum's marginalia, written in and wiped out over his study: his sums,
## the rites he keeps (in rubric red, as the old books print them), what he
## knows of the city's creatures, the old signs, and his diagrams of the body
## and the occult (FactotumSketch). The rites and creature notes are
## stand-ins drafted for the user to rewrite.
const EQUATIONS := ["v² = u² + 2as", "θ = 34°", "∫ F · ds", "√(x² + y²)", "Δt ≈ 0.31", "h = ½ g t²",
		"1 : 50", "∠ 112°", "Σ wᵢ xᵢ", "π r²", "F = m · a", "7 × 13 = 91", "x → ∞", "tan α = 5/12",
		"r = 2.4", "∴", "λ = c / f", "≈ 1923"]
const RITES := ["Exorcizo te, immundissime spiritus ✠", "Vade retro ✠", "Asperges me, hyssopo", "In nomine Patris ✠ et Filii ✠",
		"Ecce Crucem Domini", "sal · agua bendita · copal", "℟. Et cum spiritu tuo", "✠ ✠ ✠"]
const CREATURES := ["Nahual — sal en el umbral", "Ánima sola — vela de sebo, tres noches", "La Llorona: no responder",
		"Chaneque — hierro frío", "Tzitzimime ~ eclipse, 1923", "Nahual no cruza el hierro", "ánimas: copal al oriente"]
const SIGNS := ["☉ ☽ ☿ ♀ ♂ ♃ ♄", "△ ▽ ⊕", "IHS ✠", "♄ ∴ ☿", "Α ✠ Ω"]
## How many of each, and when (fractions of TIME) they may be written.
const NOTE_KINDS := {"sums": 6, "rites": 5, "creatures": 4, "signs": 3}
const SKETCHES := 6
const NOTES_FROM := 0.06
const NOTES_UNTIL := 0.62
const INK := Color(0.82, 0.88, 0.94, 0.9)
const RUBRIC := Color(0.8, 0.36, 0.3, 0.92)

signal finished

## Factotum's notes, over the painted transition.
var notes: Control

var progress := 0.0:
	set(value):
		progress = value
		(material as ShaderMaterial).set_shader_parameter("progress", value)

func _init() -> void:
	name = "ArchetypeTransition"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var paint := ShaderMaterial.new()
	paint.shader = SHADER
	var grain := FastNoiseLite.new()
	grain.frequency = 0.012
	grain.fractal_octaves = 4
	var noise := NoiseTexture2D.new()
	noise.width = 512
	noise.height = 512
	noise.seamless = true
	noise.noise = grain
	paint.set_shader_parameter("noise", noise)
	paint.set_shader_parameter("fps", MenuBand.BOIL_FPS)
	material = paint
	notes = Control.new()
	notes.name = "Notes"
	notes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notes.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(notes)
	hide()

## Plays archetype `kind`'s transition from `origin` (screen px); emits finished.
func play(kind: int, origin: Vector2) -> void:
	var screen := get_viewport_rect().size
	var paint := material as ShaderMaterial
	paint.set_shader_parameter("kind", kind)
	paint.set_shader_parameter("origin", origin / screen)
	paint.set_shader_parameter("aspect", screen.x / screen.y)
	progress = 0.0
	_clear_notes()
	show()
	if kind == 2:
		_write_notes(screen, origin)
	var run := create_tween()
	run.tween_property(self, "progress", 1.0, TIME)
	run.tween_callback(finished.emit)

func clear() -> void:
	hide()
	progress = 0.0
	_clear_notes()

func _clear_notes() -> void:
	for note in notes.get_children():
		note.queue_free()

## Each note is written in stroke by stroke (held steps), lingers, and is
## wiped out; they gather around his card and drift outward as it goes.
func _write_notes(screen: Vector2, origin: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var order: Array = []
	for pair in [["sums", EQUATIONS], ["rites", RITES], ["creatures", CREATURES], ["signs", SIGNS]]:
		var pool: Array = pair[1].duplicate()
		pool.shuffle()
		for k in range(NOTE_KINDS[pair[0]]):
			order.append([pair[0], pool[k % pool.size()]])
	order.shuffle()
	for i in range(order.size()):
		var kind: String = order[i][0]
		var note := Label.new()
		note.text = order[i][1]
		note.add_theme_font_override("font", MenuType.body_italic())
		var size := rng.randf_range(0.024, 0.042) if kind == "sums" else rng.randf_range(0.022, 0.03)
		note.add_theme_font_size_override("font_size", int(screen.y * size))
		note.add_theme_color_override("font_color", RUBRIC if kind == "rites" else INK)
		note.mouse_filter = Control.MOUSE_FILTER_IGNORE
		note.visible_ratio = 0.0
		var reach := rng.randf_range(0.12, 0.62) * screen.y
		var angle := rng.randf() * TAU
		note.position = (origin + Vector2(cos(angle) * 1.4, sin(angle)) * reach).clamp(Vector2(screen.x * 0.03, screen.y * 0.04), screen * Vector2(0.86, 0.92))
		note.rotation = rng.randf_range(-0.12, 0.12)
		notes.add_child(note)
		# Long notes stay inside the screen.
		note.position.x = minf(note.position.x, screen.x * 0.97 - note.get_minimum_size().x)
		var at := lerpf(NOTES_FROM, NOTES_UNTIL, float(i) / order.size()) * TIME + rng.randf_range(0.0, 0.06)
		# Every note is gone well before the dark.
		var life := minf(rng.randf_range(0.3, 0.5), 0.8 * TIME - at - 0.28)
		# Written in a few held strokes, however long the note.
		var strokes := clampi(note.text.length() / 3, 2, 8)
		var write := create_tween()
		write.tween_interval(at)
		for k in range(1, strokes + 1):
			write.tween_property(note, "visible_ratio", float(k) / strokes, 0.0)
			write.tween_interval(0.18 / strokes)
		write.tween_interval(life)
		write.tween_property(note, "modulate:a", 0.0, 0.1)
	# The diagrams, each drawn in a few held strokes, kept clear of his card.
	var kinds := FactotumSketch.KINDS.duplicate()
	kinds.shuffle()
	for i in range(SKETCHES):
		var sketch := FactotumSketch.new()
		var what: String = kinds[i % kinds.size()]
		var side := screen.y * rng.randf_range(0.15, 0.24)
		sketch.configure(what, side, RUBRIC if what in FactotumSketch.OCCULT else INK)
		var angle := (float(i) + rng.randf_range(-0.3, 0.3)) / SKETCHES * TAU
		var reach := rng.randf_range(0.3, 0.55) * screen.y
		var at_point := origin + Vector2(cos(angle) * 1.5, sin(angle)) * reach - sketch.size * 0.5
		sketch.position = at_point.clamp(Vector2(screen.x * 0.02, screen.y * 0.03), screen - sketch.size * 1.05)
		sketch.rotation = rng.randf_range(-0.15, 0.15)
		notes.add_child(sketch)
		var start := lerpf(NOTES_FROM, NOTES_UNTIL - 0.12, float(i) / SKETCHES) * TIME + rng.randf_range(0.0, 0.05)
		var draw_in := create_tween()
		draw_in.tween_interval(start)
		for k in range(1, 7):
			draw_in.tween_property(sketch, "drawn", k / 6.0, 0.0)
			draw_in.tween_interval(0.05)
		draw_in.tween_interval(minf(rng.randf_range(0.25, 0.4), 0.8 * TIME - start - 0.4))
		draw_in.tween_property(sketch, "modulate:a", 0.0, 0.1)
