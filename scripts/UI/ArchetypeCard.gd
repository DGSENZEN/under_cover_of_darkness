class_name ArchetypeCard
extends Control
## One archetype in the triptych: its portrait cut from the sheet, its painted
## effects behind it (on the screen's shared layer, so they never cross a
## portrait), a stepped gold frame, and its emblem, name and line below.
const SHEET := preload("res://assets/ui/archetypes/archetypes_sheet.webp")
const CARD_SHADER := preload("res://scripts/UI/archetype_card.gdshader")
const FX_SHADER := preload("res://scripts/UI/archetype_fx.gdshader")
const EMBLEMS := [
	preload("res://assets/ui/archetypes/emblem_derive.svg"),
	preload("res://assets/ui/archetypes/emblem_thaumaturge.svg"),
	preload("res://assets/ui/archetypes/emblem_factotum.svg"),
]
## The three panels' columns in the sheet (px), inset from its gutters.
const PANELS := [Vector2i(4, 649), Vector2i(664, 1330), Vector2i(1345, 1996)]
const SIZE := Vector2(281, 480)
## How far the effects spill past the portrait, as fractions of its size:
## each side, above, below.
const SPILL_SIDE := 0.8
const SPILL_TOP := 0.32
const SPILL_FOOT := 0.34
const GOLD := Color("d9b46a")
const INK := Color("f4e6cc")
## A card not chosen steps back to this size.
const ASLEEP_SCALE := 0.84
const LINE_WIDTH := 370.0
## Factotum's construction lines take this long to ink in (s).
const DRAW_TIME := 1.4

signal hovered(index: int)
signal clicked(index: int)

static var _noise: NoiseTexture2D

var index := 0
var chosen := false
## Behind the portrait, on the screen's effects layer.
var fx: ColorRect
var portrait: ColorRect
var frame: Control
var emblem: TextureRect
var title: Label
var ornament: Control
var line: Label
## 0 asleep .. 1 chosen (eased).
var wake := 0.0:
	set(value):
		wake = value
		_apply()
## 0..1: the confirm's surge.
var surge := 0.0
## 0..1: Factotum's lines inked in.
var drawn := 0.0
var _motion: Tween
var _accent: Tween

func _init() -> void:
	size = SIZE
	pivot_offset = SIZE * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	scale = Vector2.ONE * ASLEEP_SCALE
	if _noise == null:
		var grain := FastNoiseLite.new()
		grain.frequency = 0.012
		grain.fractal_octaves = 4
		_noise = NoiseTexture2D.new()
		_noise.width = 512
		_noise.height = 512
		_noise.seamless = true
		_noise.noise = grain

func configure(at_index: int, caption: String, words: String) -> void:
	index = at_index
	name = "Card%d" % index
	# The effects, sized past the portrait by the spill.
	fx = ColorRect.new()
	fx.name = "Fx%d" % index
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.size = Vector2(SIZE.x * (1.0 + 2.0 * SPILL_SIDE), SIZE.y * (1.0 + SPILL_TOP + SPILL_FOOT))
	fx.pivot_offset = pivot_offset + Vector2(SIZE.x * SPILL_SIDE, SIZE.y * SPILL_TOP)
	var effects := ShaderMaterial.new()
	effects.shader = FX_SHADER
	effects.set_shader_parameter("noise", _noise)
	effects.set_shader_parameter("kind", index)
	effects.set_shader_parameter("fps", MenuBand.BOIL_FPS)
	effects.set_shader_parameter("px", fx.size)
	effects.set_shader_parameter("card", Vector4(SPILL_SIDE * SIZE.x / fx.size.x, SPILL_TOP * SIZE.y / fx.size.y, SIZE.x / fx.size.x, SIZE.y / fx.size.y))
	fx.material = effects
	# The portrait: the panel, cropped from its top to the card's shape.
	portrait = ColorRect.new()
	portrait.name = "Portrait"
	portrait.size = SIZE
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var paint := ShaderMaterial.new()
	paint.shader = CARD_SHADER
	paint.set_shader_parameter("sheet", SHEET)
	paint.set_shader_parameter("noise", _noise)
	paint.set_shader_parameter("fps", MenuBand.BOIL_FPS)
	paint.set_shader_parameter("px", SIZE)
	var sheet_size := Vector2(SHEET.get_size())
	var columns: Vector2i = PANELS[index]
	var width := float(columns.y - columns.x)
	var height := minf(width * SIZE.y / SIZE.x, sheet_size.y)
	paint.set_shader_parameter("rect", Vector4(columns.x / sheet_size.x, 0.0, width / sheet_size.x, height / sheet_size.y))
	portrait.material = paint
	add_child(portrait)
	frame = Control.new()
	frame.name = "Frame"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.size = SIZE
	frame.draw.connect(_draw_frame)
	add_child(frame)
	emblem = TextureRect.new()
	emblem.name = "Emblem"
	emblem.texture = EMBLEMS[index]
	emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	emblem.size = Vector2(46, 46)
	emblem.position = Vector2(SIZE.x * 0.5 - 23.0, SIZE.y + 18.0)
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(emblem)
	title = _label(caption, MenuType.choice(), 40, Vector2(SIZE.x * 0.5 - LINE_WIDTH * 0.5, SIZE.y + 64.0))
	title.add_theme_constant_override("outline_size", 0)
	ornament = Control.new()
	ornament.name = "Ornament"
	ornament.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ornament.size = Vector2(200, 12)
	ornament.position = Vector2(SIZE.x * 0.5 - 100.0, SIZE.y + 118.0)
	ornament.draw.connect(_draw_ornament)
	add_child(ornament)
	line = _label(words, MenuType.body_italic(), 23, Vector2(SIZE.x * 0.5 - LINE_WIDTH * 0.5, SIZE.y + 136.0))
	mouse_entered.connect(func(): hovered.emit(index))
	_apply()

func _label(words: String, font: Font, font_size: int, at: Vector2) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(LINE_WIDTH, 0)
	label.text = words
	label.position = at
	label.size = Vector2(LINE_WIDTH, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", INK)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("shadow_outline_size", 10)
	add_child(label)
	return label

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(index)
		accept_event()

## Chosen: the painting wakes into full colour and its effects come in;
## not chosen: it dims and steps back.
func set_chosen(on: bool) -> void:
	if on == chosen:
		return
	chosen = on
	if _motion:
		_motion.kill()
	_motion = MenuMotion.tween(self)
	_motion.tween_property(self, "wake", 1.0 if on else 0.0, MenuMotion.BLOOM if on else MenuMotion.FADE)
	if index != 0 or not on:
		_motion.tween_property(self, "scale", Vector2.ONE * (1.0 if on else ASLEEP_SCALE), MenuMotion.BLOOM)
	if on:
		_arrive()

## Each one arrives in its own way: Derivé throws a punch (a jolt held for a
## frame, then settles), Thaumaturge draws a slow breath, Factotum inks his lines.
func _arrive() -> void:
	if _accent:
		_accent.kill()
	_accent = create_tween()
	match index:
		0:
			_accent.tween_property(self, "scale", Vector2.ONE * 1.05, 0.06)
			_accent.tween_interval(0.08)
			_accent.tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		1:
			_accent.tween_property(portrait, "position:y", -6.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			_accent.tween_property(portrait, "position:y", 0.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		2:
			drawn = 0.0
			_accent.tween_property(self, "drawn", 1.0, DRAW_TIME).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)

## Confirmed: the effects surge for a beat and hold.
func surge_out() -> void:
	MenuMotion.tween(self).tween_property(self, "surge", 1.0, 0.25)

## Another was confirmed: this one falls away into the dark.
func fall_away() -> void:
	var fall := MenuMotion.tween(self)
	fall.tween_property(self, "modulate:a", 0.0, MenuMotion.FADE)
	fall.tween_property(self, "position:y", position.y + 30.0, MenuMotion.FADE)

func _apply() -> void:
	if portrait == null:
		return
	(portrait.material as ShaderMaterial).set_shader_parameter("wake", wake)
	frame.modulate.a = lerpf(0.25, 1.0, wake)
	emblem.modulate.a = lerpf(0.45, 1.0, wake)
	title.modulate.a = lerpf(0.6, 1.0, wake)
	ornament.modulate.a = wake
	line.modulate.a = wake * wake

func _process(_delta: float) -> void:
	if fx == null:
		return
	# The effects follow the card's place, size and fade from their own layer.
	fx.position = position - Vector2(SIZE.x * SPILL_SIDE, SIZE.y * SPILL_TOP)
	fx.scale = scale
	fx.modulate.a = modulate.a
	fx.visible = visible
	var effects := fx.material as ShaderMaterial
	effects.set_shader_parameter("level", wake)
	effects.set_shader_parameter("surge", surge)
	effects.set_shader_parameter("drawn", drawn)

## Stepped gold brackets at each corner: two nested angles and a stud.
func _draw_frame() -> void:
	var arm := 34.0
	var inset := 7.0
	for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		# Out points away from the card's middle; the arms run back along the edges.
		var out := Vector2(corner.x * 2.0 - 1.0, corner.y * 2.0 - 1.0)
		var at: Vector2 = corner * SIZE + out * 8.0
		for step in [0.0, inset]:
			var o: Vector2 = at - out * step
			var length: float = arm - step
			frame.draw_polyline(PackedVector2Array([o - Vector2(0, out.y) * length, o, o - Vector2(out.x, 0) * length]), GOLD, 1.5, true)
		frame.draw_rect(Rect2(at - out * (inset * 2.0) - Vector2(1.5, 1.5), Vector2(3, 3)), GOLD)

## A rule with a lozenge at its heart, under the name.
func _draw_ornament() -> void:
	var mid := ornament.size * 0.5
	ornament.draw_line(Vector2(0, mid.y), Vector2(mid.x - 18, mid.y), GOLD, 1.0, true)
	ornament.draw_line(Vector2(mid.x + 18, mid.y), Vector2(ornament.size.x, mid.y), GOLD, 1.0, true)
	ornament.draw_colored_polygon(PackedVector2Array([mid + Vector2(-8, 0), mid + Vector2(0, -5), mid + Vector2(8, 0), mid + Vector2(0, 5)]), GOLD)
	for side in [-1.0, 1.0]:
		ornament.draw_circle(mid + Vector2(side * 13.0, 0), 1.5, GOLD)
