extends RefCounted
## The night's sky on an environment: night_sky.gdshader, the cloud field
## Night gives it, and the skyline (assets/sky/skyline.png, rendered by
## tools/skyline in Blender; a plain noise ridge until it is there). Night
## feeds it every frame (show_night).

const SHADER := preload("res://scripts/Night/night_sky.gdshader")
const SKYLINE := "res://assets/sky/skyline.png"

var material: ShaderMaterial


func _init(environment: Environment, field: Texture2D) -> void:
	material = ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("cloud_field", field)
	material.set_shader_parameter("skyline", _skyline())
	var sky := Sky.new()
	sky.sky_material = material
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	environment.sky = sky
	environment.background_mode = Environment.BG_SKY


## The sky as the night is now.
func show_night(cover: float, offset: Vector2, veil_center: Vector2, veil_on: float, flash: float, fog: float) -> void:
	material.set_shader_parameter("cloud_cover", cover)
	material.set_shader_parameter("cloud_offset", offset)
	material.set_shader_parameter("veil_center", veil_center)
	material.set_shader_parameter("veil_on", veil_on)
	material.set_shader_parameter("flash", flash)
	material.set_shader_parameter("fog", fog)


## The Blender skyline, or a plain ridge of hills and roofs to stand in.
static func _skyline() -> Texture2D:
	if ResourceLoader.exists(SKYLINE):
		return load(SKYLINE)

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
