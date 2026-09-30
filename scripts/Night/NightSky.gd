extends RefCounted
## The night's sky on an environment: night_sky.gdshader, the cloud field
## Night gives it, and the skyline (assets/sky/skyline.png, or the map's own:
## rendered by tools/skyline in Blender; a plain noise ridge until it is
## there). Night feeds it every frame (show_night).

const SHADER := preload("res://scripts/Night/night_sky.gdshader")
const SKYLINE := "res://assets/sky/skyline.png"
## The moon's face (tools/textures/paint.py: ours, committed).
const MOON_FACE := "res://textures/painted/moon.png"

var material: ShaderMaterial


func _init(environment: Environment, field: Texture2D, skyline := "") -> void:
	material = ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("cloud_field", field)
	material.set_shader_parameter("skyline", _skyline(skyline if skyline != "" else SKYLINE))
	material.set_shader_parameter("moon_face", _moon_face())
	var sky := Sky.new()
	sky.sky_material = material
	# (nothing reads its radiance: reflections are off and the ambient is a
	# flat colour; incremental keeps its updates cheap)
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	environment.sky = sky
	environment.background_mode = Environment.BG_SKY


## The sky as the night is now.
func show_night(cover: float, offset: Vector2, veil_center: Vector2, veil_on: float, flash: float, fog: float, clock: float) -> void:
	material.set_shader_parameter("clock", clock)
	material.set_shader_parameter("cloud_cover", cover)
	material.set_shader_parameter("cloud_offset", offset)
	material.set_shader_parameter("veil_center", veil_center)
	material.set_shader_parameter("veil_on", veil_on)
	material.set_shader_parameter("flash", flash)
	material.set_shader_parameter("fog", fog)


## Lightning: where the flash is in the sky, its bolt (0 or 1), which bolt.
func show_lightning(direction: Vector3, bolt: float, seed: float) -> void:
	material.set_shader_parameter("flash_dir", direction)
	material.set_shader_parameter("bolt", bolt)
	material.set_shader_parameter("bolt_seed", seed)


## High thin cloud (0..1).
func show_cirrus(amount: float) -> void:
	material.set_shader_parameter("cirrus", amount)


## The painted moon, or a plain pale disc to stand in.
static func _moon_face() -> Texture2D:
	if ResourceLoader.exists(MOON_FACE):
		return load(MOON_FACE)

	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)

	for y in 32:
		for x in 32:
			var inside := Vector2(x - 15.5, y - 15.5).length() < 15.5
			image.set_pixel(x, y, Color(0.85, 0.87, 0.9, 1.0 if inside else 0.0))

	return ImageTexture.create_from_image(image)


## The Blender skyline at `path`, or a plain ridge of hills and roofs to
## stand in.
static func _skyline(path := SKYLINE) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)

	var width := 1024
	var height := 128
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 11
	noise.frequency = 0.01

	for x in width:
		var ridge := 0.62 + 0.18 * noise.get_noise_1d(x) + 0.08 * noise.get_noise_1d(x * 4.0)

		for y in height:
			var v := float(y) / float(height)
			image.set_pixel(x, y, Color(0.012, 0.014, 0.02, 1.0 if v > ridge else 0.0))

	return ImageTexture.create_from_image(image)
