class_name MenuPages
extends Control
## What a page says once its band has spread over the right two-thirds:
## Lore's text, the settings book (SettingsPage) painted like the band,
## Continue's line.
const Settings := preload("res://scripts/UI/Settings.gd")
const INK := Color("f4e6cc")
const GOLD := Color("d9b46a")
const AREA := Rect2(620, 270, 560, 560)
const CONTINUE_LINE := "No saved game yet. Choose New Game to begin."

var title_label: Label
var body_label: Label
## The settings book, and its master volume slider (the first row).
var settings: SettingsPage
var volume: HSlider
var back: MenuWord
var _scrim: TextureRect
## Under the settings book: a deeper, wider wash, so its rows read over the painting.
var _book_scrim: TextureRect
var _column: VBoxContainer
## The settings book starts higher than the other pages: it is taller.
const SETTINGS_TOP := 150.0
var _fade: Tween

func build(font: Font, lore: String) -> void:
	name = "Pages"
	size = Vector2(1600, 900)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_meta(&"lore", lore)
	# A feathered dark wash behind the words, so text reads over the painting.
	_scrim = TextureRect.new()
	var wash := Gradient.new()
	wash.colors = PackedColorArray([Color(0.01, 0.02, 0.03, 0.55), Color(0.01, 0.02, 0.03, 0.0)])
	var soft := GradientTexture2D.new()
	soft.gradient = wash
	soft.fill = GradientTexture2D.FILL_RADIAL
	soft.fill_from = Vector2(0.5, 0.5)
	soft.fill_to = Vector2(1.0, 0.5)
	_scrim.texture = soft
	_scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_scrim.position = AREA.position - Vector2(80, 60)
	_scrim.size = AREA.size + Vector2(160, 120)
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scrim)
	var deep := Gradient.new()
	deep.colors = PackedColorArray([Color(0.01, 0.02, 0.03, 0.86), Color(0.01, 0.02, 0.03, 0.7), Color(0.01, 0.02, 0.03, 0.0)])
	deep.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	var round_wash := GradientTexture2D.new()
	round_wash.gradient = deep
	round_wash.fill = GradientTexture2D.FILL_RADIAL
	round_wash.fill_from = Vector2(0.5, 0.5)
	round_wash.fill_to = Vector2(1.0, 0.5)
	_book_scrim = TextureRect.new()
	_book_scrim.texture = round_wash
	_book_scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_book_scrim.position = Vector2(560, 20)
	_book_scrim.size = Vector2(1000, 860)
	_book_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book_scrim.visible = false
	add_child(_book_scrim)
	var column := VBoxContainer.new()
	_column = column
	column.position = AREA.position
	column.size = AREA.size
	column.add_theme_constant_override("separation", 22)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	title_label = _label(MenuType.choice(), 52, INK)
	column.add_child(title_label)
	# A gold hairline under the heading, fading to nothing.
	var fade := Gradient.new()
	fade.colors = PackedColorArray([GOLD, Color(GOLD, 0.0)])
	var rule := GradientTexture2D.new()
	rule.gradient = fade
	rule.width = 256
	rule.height = 1
	var hairline := TextureRect.new()
	hairline.name = "Hairline"
	hairline.texture = rule
	hairline.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hairline.custom_minimum_size = Vector2(220, 1.5)
	hairline.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	hairline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(hairline)
	body_label = _label(MenuType.body(), 22, Color("e2d8c6"))
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.custom_minimum_size.x = AREA.size.x
	column.add_child(body_label)
	settings = SettingsPage.new()
	column.add_child(settings)
	settings.build()
	volume = settings.row_for("audio/master_volume").slider
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)
	back = MenuWord.new()
	back.configure("Back", -1, INK)
	back.custom_minimum_size = Vector2(240, 52)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.focus_entered.connect(func(): back.set_selected(true))
	back.focus_exited.connect(func(): back.set_selected(false))
	back.mouse_entered.connect(back.grab_focus)
	column.add_child(back)
	hide()

func show_page(index: int, title: String, colour: Color, message := "") -> void:
	title_label.text = title
	if not message.is_empty():
		body_label.text = message
	elif index == 1:
		body_label.text = CONTINUE_LINE
	elif index == 3:
		body_label.text = String(get_meta(&"lore"))
	else:
		body_label.text = ""
	body_label.visible = not body_label.text.is_empty()
	settings.visible = index == 2
	_column.position.y = SETTINGS_TOP if index == 2 else AREA.position.y
	_scrim.visible = index != 2
	_book_scrim.visible = index == 2
	if index == 2:
		settings.refresh_all()
		settings.paint(colour)
	back.colour = colour
	show()
	modulate.a = 0.0
	if _fade:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", 1.0, 0.25)
	if index == 2:
		settings.focus_first()
	else:
		back.grab_focus()

func hide_page() -> void:
	if _fade:
		_fade.kill()
	hide()

func _label(font: Font, point_size: int, colour: Color, words := "") -> Label:
	var label := Label.new()
	label.text = words
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", point_size)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label

## A slider's track is a dry brush stroke; the filled part and the handle
## are pigment in the page's colour.
static func paint_slider(slider: HSlider, colour: Color) -> void:
	var track := StyleBoxTexture.new()
	track.texture = _stroke_texture(INK * Color(1, 1, 1, 0.45))
	track.content_margin_top = 8
	track.content_margin_bottom = 8
	var lit := StyleBoxTexture.new()
	lit.texture = _stroke_texture(colour)
	lit.content_margin_top = 8
	lit.content_margin_bottom = 8
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", lit)
	slider.add_theme_stylebox_override("grabber_area_highlight", lit)
	slider.add_theme_icon_override("grabber", _dab_texture(colour, true))
	slider.add_theme_icon_override("grabber_highlight", _dab_texture(colour.lightened(0.25), true))

static func _stroke_texture(colour: Color) -> ImageTexture:
	var grain := FastNoiseLite.new()
	grain.seed = 31
	grain.frequency = 0.08
	var image := Image.create(256, 20, false, Image.FORMAT_RGBA8)
	for x in range(256):
		# Bristles: each row frays a little differently toward the ends.
		var taper := minf(float(x) / 24.0, float(255 - x) / 40.0)
		for y in range(20):
			var edge := 1.0 - absf(float(y) - 9.5) / 9.5
			var a := clampf(edge * 2.2 + grain.get_noise_2d(x * 0.6, y * 5.0) * 1.2 - 0.35, 0.0, 1.0) * clampf(taper, 0.0, 1.0)
			image.set_pixel(x, y, Color(colour.r, colour.g, colour.b, colour.a * a))
	return ImageTexture.create_from_image(image)

static func _dab_texture(colour: Color, solid: bool) -> ImageTexture:
	var grain := FastNoiseLite.new()
	grain.seed = 7
	grain.frequency = 0.25
	var image := Image.create(30, 30, false, Image.FORMAT_RGBA8)
	for x in range(30):
		for y in range(30):
			var r := Vector2(x - 14.5, y - 14.5).length() / 13.0 + grain.get_noise_2d(x, y) * 0.18
			var a := clampf((1.0 - r) * 6.0, 0.0, 1.0)
			if not solid:
				a *= clampf((r - 0.62) * 8.0, 0.0, 1.0)
			image.set_pixel(x, y, Color(colour.r, colour.g, colour.b, a))
	return ImageTexture.create_from_image(image)
