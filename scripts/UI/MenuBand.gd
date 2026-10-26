class_name MenuBand
extends Control
## The selection: a torn band of the chosen illustration brushed across the
## city behind its word. It glides between words, cross-fades its picture,
## and spreads over the right two-thirds to become a page.
const SHADER := preload("res://scripts/UI/menu_band.gdshader")
const ATLAS := preload("res://assets/ui/main_menu/buttons.png")
const BOIL_FPS := 9.0
## The picture's box in a choice band (design px). Each painting covers it,
## cropped around its subject; they exist only at ~575 px inside their rims,
## so the wide ones are enlarged most (1.45x here, ~1.75x at 1080p).
const ART_WIDTH := 640.0
const ART_MAX_SCALE := 1.5
## Each illustration inside its painted tin rim, in buttons.png pixels.
const ART_REGIONS: Array[Rect2i] = [Rect2i(74, 93, 575, 248), Rect2i(790, 92, 579, 252), Rect2i(77, 486, 573, 510), Rect2i(784, 487, 583, 509)]
## Where each picture's subject sits vertically, for cropping it into the band.
const ART_FOCUS := [0.28, 0.42, 0.38, 0.30]
const COLOURS := [Color("ef774c"), Color("67c9ed"), Color("929fdb"), Color("efa25e")]
const HEIGHT := 360.0
const PAGE_RECT := Rect2(530, 0, 1070, 900)
const GLIDE := 0.5
const FADE := 0.6

var showing := false
var page := false
## Left edge of the visible screen in design px (negative on wide screens).
var screen_left := 0.0
var _choice := -1
var _shown := -1
var _word_y := 0.0
var _target := Rect2()
var _move: Tween
var _fade: Tween
var _pulse: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grain := FastNoiseLite.new()
	grain.frequency = 0.012
	grain.fractal_octaves = 4
	var texture := NoiseTexture2D.new()
	texture.width = 512
	texture.height = 512
	texture.seamless = true
	texture.noise = grain
	var paint := ShaderMaterial.new()
	paint.shader = SHADER
	paint.set_shader_parameter("atlas", ATLAS)
	paint.set_shader_parameter("noise", texture)
	paint.set_shader_parameter("boil_fps", BOIL_FPS)
	paint.set_shader_parameter("glaze_amount", 0.28)
	material = paint
	modulate.a = 0.0

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE)

static func boil_step(t: float) -> int:
	return floori(t * BOIL_FPS)

## How much a painting is enlarged (design px per source px) to cover its box.
func art_scale(index: int) -> float:
	var region := ART_REGIONS[index]
	return maxf(ART_WIDTH / float(region.size.x), HEIGHT / float(region.size.y))

## The rect the band is heading for, in design px.
func band_rect() -> Rect2:
	return _target

func show_choice(index: int, word_centre_y: float) -> void:
	_word_y = word_centre_y
	var first := not showing
	showing = true
	if index != _choice:
		_choice = index
		var paint := material as ShaderMaterial
		if first:
			_set_art("a", index)
			_set_art("b", index)
			paint.set_shader_parameter("mix_ab", 1.0)
		else:
			# What is on screen becomes "a"; the new picture fades in as "b".
			_set_art("a", _shown)
			_set_art("b", index)
			paint.set_shader_parameter("mix_ab", 0.0)
			if _fade:
				_fade.kill()
			_fade = create_tween()
			_fade.tween_property(paint, "shader_parameter/mix_ab", 1.0, FADE)
		_shown = index
		paint.set_shader_parameter("glaze", COLOURS[index])
	if not page:
		_go(_choice_rect(), first)
	if first:
		create_tween().tween_property(self, "modulate:a", 1.0, 0.25)

func hide_band() -> void:
	showing = false
	_choice = -1
	create_tween().tween_property(self, "modulate:a", 0.0, 0.25)

func set_page(on: bool) -> void:
	page = on
	_go(PAGE_RECT if on else _choice_rect(), false)
	create_tween().tween_property(material, "shader_parameter/page", 1.0 if on else 0.0, GLIDE)

func pulse() -> void:
	if _pulse:
		_pulse.kill()
	material.set_shader_parameter("pulse", 1.0)
	_pulse = create_tween()
	_pulse.tween_property(material, "shader_parameter/pulse", 0.0, 0.35)

## Keeps the band reaching the screen's left edge when the window is wider than 16:9.
func set_screen_left(left: float) -> void:
	screen_left = minf(left, 0.0)
	if showing and not page:
		_go(_choice_rect(), true)

func _choice_rect() -> Rect2:
	return Rect2(screen_left, _word_y - HEIGHT * 0.5, 1440.0 - screen_left, HEIGHT)

func _go(rect: Rect2, at_once: bool) -> void:
	_target = rect
	if _move:
		_move.kill()
	if at_once:
		position = rect.position
		size = rect.size
		return
	_move = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_move.tween_property(self, "position", rect.position, GLIDE)
	_move.tween_property(self, "size", rect.size, GLIDE)

func _set_art(slot: String, index: int) -> void:
	var paint := material as ShaderMaterial
	var region := ART_REGIONS[index]
	var atlas_size := Vector2(ATLAS.get_size())
	# Cover the box: keep the part of the painting that fits, around its subject.
	var scale := art_scale(index)
	var keep := Vector2(ART_WIDTH, HEIGHT) / (Vector2(region.size) * scale)
	var start := Vector2(region.position) + Vector2(region.size) * (Vector2.ONE - keep) * Vector2(0.5, float(ART_FOCUS[index]))
	var window := Vector2(region.size) * keep
	paint.set_shader_parameter("rect_" + slot, Vector4(start.x / atlas_size.x, start.y / atlas_size.y, window.x / atlas_size.x, window.y / atlas_size.y))

func _process(_delta: float) -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var paint := material as ShaderMaterial
	paint.set_shader_parameter("band_px", size)
	# The picture keeps its size while the band glides or spreads; it sits in
	# the right half of a choice band and high in the middle of a page.
	var art := Vector2(ART_WIDTH, HEIGHT)
	var right := size.x * 0.86 if not page else size.x * 0.5 + art.x * 0.5
	var top := (size.y - art.y) * 0.5 if not page else 90.0
	var box := Vector4((right - art.x) / size.x, top / size.y, art.x / size.x, art.y / size.y)
	paint.set_shader_parameter("box_a", box)
	paint.set_shader_parameter("box_b", box)
