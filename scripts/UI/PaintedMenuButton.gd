extends Button
## One painting, with independent pigment flow, focus, border and music response.
const PAINT := preload("res://scripts/UI/painted_button.gdshader")
const FLOW := preload("res://scripts/UI/paint_flow.tres")
var caption := ""
var paint: TextureRect
var music_energy := 0.0
var _hover := 0.0
var _target := 0.0
var _press := 0.0
var _mouse_over := false
var _focus_over := false

func configure(atlas: Texture2D, region: Rect2, title: String, index: int, colour: Color, font: Font) -> void:
	caption = title
	name = title.replace(" ", "")
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	paint = TextureRect.new()
	paint.name = "Paint"
	paint.texture = atlas
	paint.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader := ShaderMaterial.new()
	shader.shader = PAINT
	shader.set_shader_parameter("flow_map", FLOW)
	shader.set_shader_parameter("paint_atlas", atlas)
	shader.set_shader_parameter("atlas_rect", Vector4(region.position.x, region.position.y, region.size.x, region.size.y))
	shader.set_shader_parameter("pigment", colour)
	shader.set_shader_parameter("style", float(index))
	paint.material = shader
	add_child(paint)
	var label := Label.new()
	label.text = title
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color("f5e9d5"))
	label.add_theme_color_override("font_shadow_color", Color(0.02, 0.02, 0.03, 0.95))
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	label.offset_left = 22
	label.offset_top = -52
	label.offset_bottom = -12
	paint.add_child(label)
	mouse_entered.connect(func(): _mouse_over = true; _refresh_highlight())
	mouse_exited.connect(func(): _mouse_over = false; _refresh_highlight())
	focus_entered.connect(func(): _focus_over = true; _refresh_highlight())
	focus_exited.connect(func(): _focus_over = false; _refresh_highlight())
	button_down.connect(func(): _press = 1.0)

func _refresh_highlight() -> void:
	set_highlighted(_mouse_over or _focus_over)

func set_highlighted(on: bool) -> void:
	_target = 1.0 if on else 0.0
	z_index = 2 if on else 0

func _process(delta: float) -> void:
	if paint == null:
		return
	_hover = move_toward(_hover, _target, delta * 5.5)
	_press = move_toward(_press, 0.0, delta * 2.4)
	music_energy = move_toward(music_energy, 0.0, delta * 0.6)
	paint.pivot_offset = size * 0.5
	paint.scale = Vector2.ONE * (1.0 + _hover * 0.065 + _press * 0.025)
	paint.material.set_shader_parameter("hover", _hover)
	paint.material.set_shader_parameter("press", _press)
	paint.material.set_shader_parameter("music", music_energy)
	paint.material.set_shader_parameter("canvas_size", size)
	paint.material.set_shader_parameter("pointer", get_local_mouse_position() / size)
