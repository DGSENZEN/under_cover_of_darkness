class_name LivingCity
extends TextureRect
## The menu's painted city, kept still; its sky, lights, haze, water and moon
## live (city_life.gdshader), stirred by the score's four layers.
const CITY := preload("res://assets/ui/main_menu/city.png")
const MASKS := preload("res://assets/ui/main_menu/city_masks.png")
const SHADER := preload("res://scripts/UI/city_life.gdshader")

## Brightness, 1 normally; the menu dims it behind a band.
var dim := 1.0:
	set(value):
		dim = value
		if material:
			material.set_shader_parameter("dim", value)

func _init() -> void:
	texture = CITY
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grain := FastNoiseLite.new()
	grain.frequency = 0.008
	grain.fractal_octaves = 4
	var noise := NoiseTexture2D.new()
	noise.width = 512
	noise.height = 512
	noise.seamless = true
	noise.noise = grain
	var life := ShaderMaterial.new()
	life.shader = SHADER
	life.set_shader_parameter("masks", MASKS)
	life.set_shader_parameter("noise", noise)
	material = life

## Each 0..1: how present the score's base, low, high and fx layers are.
func set_energy(base: float, low: float, high: float, fx: float) -> void:
	material.set_shader_parameter("base", base)
	material.set_shader_parameter("low", low)
	material.set_shader_parameter("high", high)
	material.set_shader_parameter("fx", fx)
