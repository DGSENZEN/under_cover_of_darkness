class_name MenuWord
extends Button
## One menu choice as a word in book small capitals: dim until chosen, then
## white and a step forward, with a soft shadow so it reads over any painting.
## Mouse and focus both choose it.
signal chosen(index: int)

const DIM := 0.5
## Dimmer still while a page is open.
const PAGE_DIM := 0.35
const STEP := 10.0
const SIZE := 38
const LIT := Color(1, 1, 1)
const INK := Color("f4e6cc")
var index := -1
var colour := Color.WHITE
var selected := false
## How far the word has stepped forward (design px), eased.
var step_x := 0.0:
	set(value):
		step_x = value
		if _style:
			_style.content_margin_left = value
## This word's painting (none for Quit and Back).
var wash: MenuWash
var _style: StyleBoxEmpty
var _motion: Tween

func configure(caption: String, at_index: int, tint: Color) -> void:
	index = at_index
	colour = tint
	text = caption
	name = caption.replace(" ", "")
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_theme_font_override("font", MenuType.choice())
	add_theme_font_size_override("font_size", SIZE)
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		add_theme_color_override(state, LIT)
	add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	add_theme_constant_override("shadow_offset_x", 0)
	add_theme_constant_override("shadow_offset_y", 1)
	add_theme_constant_override("shadow_outline_size", 10)
	_style = StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		add_theme_stylebox_override(state, _style)
	if index >= 0 and index < MenuWash.FACE.size():
		# The menu puts the wash on a layer behind every word (place_wash).
		wash = MenuWash.new()
		wash.name = "Wash%d" % index
		wash.configure(index)
	mouse_entered.connect(func(): chosen.emit(index))
	focus_entered.connect(func(): chosen.emit(index))
	modulate = Color(INK, DIM)

func set_selected(on: bool) -> void:
	selected = on
	if _motion:
		_motion.kill()
	_motion = MenuMotion.tween(self)
	_motion.tween_property(self, "modulate", LIT if on else Color(INK, DIM), MenuMotion.ANSWER)
	_motion.tween_property(self, "step_x", STEP if on else 0.0, MenuMotion.ANSWER)
	if wash:
		if on:
			wash.bloom()
		else:
			wash.fade()

## The painting starts a little left of the word and is centred on it (in the
## coordinates of the layer the menu put it on, the word's own parent's).
func place_wash() -> void:
	if wash:
		wash.home = position + Vector2(-40.0, (size.y - MenuWash.SIZE.y) * 0.5)

## A page is open over the menu: the other words step back further.
func set_page_dim(on: bool) -> void:
	if _motion:
		_motion.kill()
	_motion = MenuMotion.tween(self)
	var alpha := PAGE_DIM if on else (1.0 if selected else DIM)
	_motion.tween_property(self, "modulate:a", alpha, MenuMotion.ANSWER)

## Pressed: the word dips in and springs back, before its action.
func press_in() -> void:
	var letters := get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE).x
	pivot_offset = Vector2(step_x + letters * 0.5, size.y * 0.5)
	var press := create_tween().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	press.tween_property(self, "scale", Vector2.ONE * 0.97, MenuMotion.PRESS * 0.5)
	press.tween_property(self, "scale", Vector2.ONE, MenuMotion.PRESS * 0.5)
