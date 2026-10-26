class_name MenuWash
extends Control
## A word's own painting, washed in around it at full colour. It blooms in
## when its word is chosen and fades out when another is; it never travels.
const SHADER := preload("res://scripts/UI/menu_wash.gdshader")
const ATLAS := preload("res://assets/ui/main_menu/buttons.png")
const SIZE := Vector2(440, 170)
## Each painting's subject (its face), in its region's UV, to frame the wash on.
const FACE := [Vector2(0.55, 0.45), Vector2(0.4, 0.5), Vector2(0.5, 0.45), Vector2(0.62, 0.35)]
## Blooms in from a little smaller and a little to the left.
const FROM_SCALE := 0.94
const FROM_X := -10.0

static var _noise: NoiseTexture2D

## 0..1: how far the painting has bloomed in (eased).
var level := 0.0:
	set(value):
		level = value
		_apply()
## Where the wash sits relative to its word when fully shown.
var home := Vector2.ZERO:
	set(value):
		home = value
		_apply()
var _tween: Tween

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = SIZE
	pivot_offset = SIZE * 0.5
	if _noise == null:
		var grain := FastNoiseLite.new()
		grain.frequency = 0.012
		grain.fractal_octaves = 4
		_noise = NoiseTexture2D.new()
		_noise.width = 512
		_noise.height = 512
		_noise.seamless = true
		_noise.noise = grain

func configure(art: int) -> void:
	var paint := ShaderMaterial.new()
	paint.shader = SHADER
	paint.set_shader_parameter("atlas", ATLAS)
	paint.set_shader_parameter("noise", _noise)
	paint.set_shader_parameter("boil_fps", MenuBand.BOIL_FPS)
	paint.set_shader_parameter("px", SIZE)
	# Cover the wash with the painting, cropped around its face.
	var region := Rect2(MenuBand.ART_REGIONS[art])
	var scale := maxf(SIZE.x / region.size.x, SIZE.y / region.size.y)
	var window := SIZE / scale
	var face: Vector2 = region.position + region.size * FACE[art]
	var start := (face - window * 0.5).clamp(region.position, region.end - window)
	var atlas_size := Vector2(ATLAS.get_size())
	paint.set_shader_parameter("rect", Vector4(start.x / atlas_size.x, start.y / atlas_size.y, window.x / atlas_size.x, window.y / atlas_size.y))
	material = paint
	_apply()

func bloom() -> void:
	_go(1.0, MenuMotion.BLOOM)

func fade() -> void:
	_go(0.0, MenuMotion.FADE)

## Gone at once, almost: a third painting never stacks under two others.
func clear() -> void:
	if level <= 0.0:
		return
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "level", 0.0, 0.03)

func _go(to: float, seconds: float) -> void:
	if _tween:
		_tween.kill()
	_tween = MenuMotion.tween(self)
	_tween.tween_property(self, "level", to, seconds)

func _apply() -> void:
	if material:
		material.set_shader_parameter("alpha", level)
	scale = Vector2.ONE * lerpf(FROM_SCALE, 1.0, level)
	position = home + Vector2(FROM_X * (1.0 - level), 0.0)
	visible = level > 0.001

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE)
