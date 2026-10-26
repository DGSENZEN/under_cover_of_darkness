class_name MenuWord
extends Button
## One menu choice as a word: dim until chosen, then white, nudged forward,
## with a thin tick in its colour. Mouse and focus both choose it.
signal chosen(index: int)

const DIM := 0.6
const NUDGE := 8.0
const LIT := Color(1, 1, 1)
const INK := Color("f4e6cc")
var index := -1
var colour := Color.WHITE
var selected := false
var _tick: ColorRect
var _glow: ColorRect
var _style: StyleBoxEmpty

func configure(caption: String, at_index: int, tint: Color, font: Font) -> void:
	index = at_index
	colour = tint
	text = caption.to_upper()
	name = caption.replace(" ", "")
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var spaced := FontVariation.new()
	spaced.base_font = font
	spaced.spacing_glyph = 4
	add_theme_font_override("font", spaced)
	add_theme_font_size_override("font_size", 34)
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		add_theme_color_override(state, INK)
	add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	add_theme_constant_override("shadow_offset_y", 2)
	_style = StyleBoxEmpty.new()
	_style.content_margin_left = 18
	for state in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		add_theme_stylebox_override(state, _style)
	_glow = ColorRect.new()
	_glow.color = Color(tint, 0.22)
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_glow)
	_tick = ColorRect.new()
	_tick.color = tint
	_tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tick)
	mouse_entered.connect(func(): chosen.emit(index))
	focus_entered.connect(func(): chosen.emit(index))
	resized.connect(_place_tick)
	set_selected(false)

func set_selected(on: bool) -> void:
	selected = on
	modulate.a = 1.0 if on else DIM
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		add_theme_color_override(state, LIT if on else INK)
	_style.content_margin_left = 18 + (NUDGE if on else 0.0)
	_tick.visible = on
	_glow.visible = on
	_place_tick()

func _place_tick() -> void:
	if _tick == null:
		return
	_tick.size = Vector2(4, size.y * 0.64)
	_tick.position = Vector2(0, size.y * 0.18)
	_glow.size = Vector2(12, size.y * 0.76)
	_glow.position = Vector2(-4, size.y * 0.12)
