class_name ArchetypeTransition
extends ColorRect
## The chosen archetype's way into the game: its paint takes the whole
## screen from its card outward and ends in the dark (archetype_transition).
const SHADER := preload("res://scripts/UI/archetype_transition.gdshader")
const TIME := 1.3

signal finished

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
	hide()

## Plays archetype `kind`'s transition from `origin` (screen px); emits finished.
func play(kind: int, origin: Vector2) -> void:
	var screen := get_viewport_rect().size
	var paint := material as ShaderMaterial
	paint.set_shader_parameter("kind", kind)
	paint.set_shader_parameter("origin", origin / screen)
	paint.set_shader_parameter("aspect", screen.x / screen.y)
	progress = 0.0
	show()
	var run := create_tween()
	run.tween_property(self, "progress", 1.0, TIME)
	run.tween_callback(finished.emit)

func clear() -> void:
	hide()
	progress = 0.0
