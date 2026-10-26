class_name MenuBand
extends Control
## A page's painting: the chosen illustration, large and at full colour,
## standing in the city behind the page's text, torn all round and melting
## longest to the left. It blooms in where the page sits; it never travels.
const SHADER := preload("res://scripts/UI/menu_page.gdshader")
const ATLAS := preload("res://assets/ui/main_menu/buttons.png")
const BOIL_FPS := 9.0
## Each illustration inside its painted tin rim, in buttons.png pixels.
const ART_REGIONS: Array[Rect2i] = [Rect2i(74, 93, 575, 248), Rect2i(790, 92, 579, 252), Rect2i(77, 486, 573, 510), Rect2i(784, 487, 583, 509)]
## The painting's size on a page (design px), framed on its face.
const ART := Vector2(820, 560)
## A page's left edge; its other edges are the screen's.
const PAGE_LEFT := 530.0

var showing := false
var page := false
## The visible screen in design px (wider or taller than 1600x900 off 16:9).
var screen := Rect2(0, 0, 1600, 900)
var _target := Rect2()
var _fade: Tween

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
	material = paint
	modulate.a = 0.0

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE)

static func boil_step(t: float) -> int:
	return floori(t * BOIL_FPS)

## The rect the painting's page covers, in design px.
func band_rect() -> Rect2:
	return _target

## Shows a page's painting: it blooms in where the page sits.
func open_page(index: int) -> void:
	showing = true
	page = true
	_frame(index)
	_place(_page_rect())
	_fade_to(1.0, MenuMotion.BLOOM)

func close_page() -> void:
	showing = false
	page = false
	_fade_to(0.0, MenuMotion.FADE)

## The visible screen in design px: a page reaches its top, right and bottom.
func set_screen(visible: Rect2) -> void:
	screen = visible
	if page:
		_place(_page_rect())

## Where the painting's left edge is, in design px.
func art_left() -> float:
	return position.x + _art_box().x * size.x

func _page_rect() -> Rect2:
	return Rect2(PAGE_LEFT, screen.position.y, screen.end.x - PAGE_LEFT, screen.size.y)

func _place(rect: Rect2) -> void:
	_target = rect
	position = rect.position
	size = rect.size
	material.set_shader_parameter("px", size)
	material.set_shader_parameter("box", _art_box())

func _fade_to(alpha: float, seconds: float) -> void:
	if _fade:
		_fade.kill()
	_fade = MenuMotion.tween(self)
	_fade.tween_property(self, "modulate:a", alpha, seconds)

## Covers ART with the painting, cropped around its face (as a word's wash is).
func _frame(index: int) -> void:
	var region := Rect2(ART_REGIONS[index])
	var scale := maxf(ART.x / region.size.x, ART.y / region.size.y)
	var window := ART / scale
	var face: Vector2 = region.position + region.size * MenuWash.FACE[index]
	var start := (face - window * 0.5).clamp(region.position, region.end - window)
	var atlas_size := Vector2(ATLAS.get_size())
	material.set_shader_parameter("rect", Vector4(start.x / atlas_size.x, start.y / atlas_size.y, window.x / atlas_size.x, window.y / atlas_size.y))

## The painting sits toward the right of the page, a little above centre.
func _art_box() -> Vector4:
	if size.x <= 0.0 or size.y <= 0.0:
		return Vector4(0, 0, 1, 1)
	var right := size.x - 40.0
	var top := (size.y - ART.y) * 0.5 - 30.0
	return Vector4((right - ART.x) / size.x, top / size.y, ART.x / size.x, ART.y / size.y)
