class_name MenuBand
extends Control
## A page's painting: the chosen illustration spread over the right of the
## screen behind a page's text, torn on its left and melting into the city.
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
## A page's left edge; its other edges are the screen's.
const PAGE_LEFT := 530.0
const GLIDE := 0.5
const FADE := 0.6

var showing := false
var page := false
## The visible screen in design px (wider or taller than 1600x900 off 16:9).
var screen := Rect2(0, 0, 1600, 900)
## The two pictures being cross-faded: "a" fading out, "b" fading in.
var art_a := -1
var art_b := -1
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
	# Values that are tweened must exist on the material first.
	paint.set_shader_parameter("page", 0.0)
	paint.set_shader_parameter("pulse", 0.0)
	paint.set_shader_parameter("mix_ab", 1.0)
	paint.set_shader_parameter("glaze_a", COLOURS[0])
	paint.set_shader_parameter("glaze_b", COLOURS[0])
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

## Shows a page's painting: it blooms in where the page sits, never travelling.
func open_page(index: int) -> void:
	showing = true
	page = true
	_set_art("a", index)
	_set_art("b", index)
	material.set_shader_parameter("mix_ab", 1.0)
	material.set_shader_parameter("page", 1.0)
	_go(_page_rect(), true)
	_fade_to(1.0, MenuMotion.BLOOM)

func close_page() -> void:
	showing = false
	page = false
	_fade_to(0.0, MenuMotion.FADE)

func _fade_to(alpha: float, seconds: float) -> void:
	if _fade:
		_fade.kill()
	_fade = MenuMotion.tween(self)
	_fade.tween_property(self, "modulate:a", alpha, seconds)

func pulse() -> void:
	if _pulse:
		_pulse.kill()
	material.set_shader_parameter("pulse", 1.0)
	_pulse = create_tween()
	_pulse.tween_property(material, "shader_parameter/pulse", 0.0, 0.35)

## The visible screen in design px: a choice band reaches its left edge, a
## page its top, right and bottom, whatever the window's shape.
func set_screen(visible: Rect2) -> void:
	screen = visible
	if page:
		_go(_page_rect(), true)

func _page_rect() -> Rect2:
	return Rect2(PAGE_LEFT, screen.position.y, screen.end.x - PAGE_LEFT, screen.size.y)

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
	paint.set_shader_parameter("glaze_" + slot, COLOURS[index])
	if slot == "a":
		art_a = index
	else:
		art_b = index

## Where the picture's left edge is now, in design px.
func art_left() -> float:
	return position.x + _art_box().x * size.x

func _process(_delta: float) -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var paint := material as ShaderMaterial
	paint.set_shader_parameter("band_px", size)
	# The picture keeps its size while the band glides or spreads; it sits in
	# the right half of a choice band and high in the middle of a page.
	var box := _art_box()
	paint.set_shader_parameter("box_a", box)
	paint.set_shader_parameter("box_b", box)

## The picture's box in band UV. On a page it sits to the right, clear of most
## of the text; it travels there with the page's own spread, never jumping.
func _art_box() -> Vector4:
	var art := Vector2(ART_WIDTH, HEIGHT)
	var t := float(material.get_shader_parameter("page"))
	var right := lerpf(size.x * 0.86, size.x - 30.0, t)
	var top := (size.y - art.y) * 0.5 - 70.0 * t
	return Vector4((right - art.x) / size.x, top / size.y, art.x / size.x, art.y / size.y)
