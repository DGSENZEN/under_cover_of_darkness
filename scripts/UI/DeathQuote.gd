extends Control
## The end of a death. Dark, and nothing, a moment. Then someone lights a candle, and a few words
## from someone who knew (DeathQuotes.gd) are brushed in, in the paint the menu and the teaser use,
## over a torn wash, embers coming off them, and last whose they were. The HUD sets where it is.

const VeilShader := preload("res://scripts/UI/death_veil.gdshader")
const WordsShader := preload("res://scripts/UI/painted_words.gdshader")
const Sfx := preload("res://scripts/Audio/Sfx.gd")
const INK := Color(0.95, 0.9, 0.8)
const BY_INK := Color(0.74, 0.65, 0.53)
## The words' place, of the screen; their size, and the name's, of its height.
const FROM_X := 0.36
const TO_X := 0.93
const QUOTE_SIZE := 0.05
const BY_SIZE := 0.03
const NAME_GAP := 0.012
const TOP_OF_ALL := 0.44
## After the death is over (s): the moment of nothing, the candle catching, the words brushed in,
## the name after them.
const DARK_FOR := 0.5
const CATCHES := 0.9
const WORDS_FROM := 1.2
const WORDS_TAKE := 1.5
const NAME_FROM := 2.4
const NAME_TAKES := 0.9
## All landed by then: the page's words may come.
const TAKES := 3.4
## The grain the paint is boiled from.
const GRAIN_FREQUENCY := 0.012

var font: Font

var _veil: ColorRect
var _words: TextureRect
var _by: TextureRect
var _words_page: SubViewport
var _by_page: SubViewport
var _words_line: Label
var _by_line: Label
var _lit_sound := false
var _shown := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var grain := FastNoiseLite.new()
	grain.frequency = GRAIN_FREQUENCY
	grain.fractal_octaves = 4
	var noise := NoiseTexture2D.new()
	noise.width = 512
	noise.height = 512
	noise.seamless = true
	noise.noise = grain
	_veil = ColorRect.new()
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var look := ShaderMaterial.new()
	look.shader = VeilShader
	look.set_shader_parameter(&"noise", noise)
	_veil.material = look
	_veil.visible = false
	add_child(_veil)
	var words := _painted(INK, noise)
	_words = words[0]
	_words_page = words[1]
	_words_line = words[2]
	var by := _painted(BY_INK, noise)
	_by = by[0]
	_by_page = by[1]
	_by_line = by[2]
	(_by.material as ShaderMaterial).set_shader_parameter(&"wash", 0.0)
	get_viewport().size_changed.connect(_lay_out)
	_lay_out()


## [the rect, its page, its label]
func _painted(ink: Color, noise: Texture2D) -> Array:
	var page := SubViewport.new()
	page.transparent_bg = true
	page.disable_3d = true
	page.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(page)
	var line := Label.new()
	line.add_theme_font_override("font", font)
	line.add_theme_color_override("font_color", ink)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(line)
	var rect := TextureRect.new()
	rect.texture = page.get_texture()
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var look := ShaderMaterial.new()
	look.shader = WordsShader
	look.set_shader_parameter(&"noise", noise)
	look.set_shader_parameter(&"wash", 0.62)
	look.set_shader_parameter(&"wash_col", Vector3(0.012, 0.012, 0.022))
	rect.material = look
	rect.visible = false
	add_child(rect)
	return [rect, page, line]


func set_quote(one: Dictionary) -> void:
	_words_line.text = one["text"]
	_by_line.text = one["by"]
	_lay_out()


func quote() -> String:
	return _words_line.text


## How far up the gentle ground has come, 0..1.
func shown() -> float:
	return _shown


## Where the last of the words ends, down the screen (px).
func bottom_of_words() -> float:
	return _by.position.y + _by.size.y


## `t` seconds after the death is over. Nothing here depends on any clock but this.
func after(t: float) -> void:
	var catching := clampf((t - DARK_FOR) / CATCHES, 0.0, 1.0)
	_shown = smoothstep(0.0, 1.0, catching)
	_veil.visible = _shown > 0.0
	var veil_look := _veil.material as ShaderMaterial
	veil_look.set_shader_parameter(&"lit", _shown)
	veil_look.set_shader_parameter(&"aspect", _aspect())
	veil_look.set_shader_parameter(&"flame_at", Vector2((FROM_X + TO_X) * 0.5, 0.74))
	_veil.modulate.a = _shown

	if catching > 0.0 and not _lit_sound:
		_lit_sound = true
		Sfx.play_flat(self, &"ignite", -16.0, 1.3)

	_paint(_words, clampf((t - WORDS_FROM) / WORDS_TAKE, 0.0, 1.0), t - WORDS_FROM)
	_paint(_by, clampf((t - NAME_FROM) / NAME_TAKES, 0.0, 1.0), t - NAME_FROM)


func _paint(rect: TextureRect, level: float, since: float) -> void:
	rect.visible = level > 0.0
	var look := rect.material as ShaderMaterial
	look.set_shader_parameter(&"level", level)
	look.set_shader_parameter(&"spread", 0.35 + 0.65 * (1.0 - pow(1.0 - level, 3.0)))
	# They catch as they are brushed in, and a few go on coming off them.
	look.set_shader_parameter(&"embers", 0.08 + 0.5 * exp(-maxf(since - 0.8, 0.0) * 1.1))


func _aspect() -> float:
	var view := get_viewport().get_visible_rect().size
	return view.x / maxf(view.y, 1.0)


func _lay_out() -> void:
	var view := get_viewport().get_visible_rect().size
	var wide := view.x * (TO_X - FROM_X)
	var pad := view.y * 0.05
	var words_tall := _fit(_words_line, _words_page, _words, int(view.y * QUOTE_SIZE), wide, pad)
	var by_tall := _fit(_by_line, _by_page, _by, int(view.y * BY_SIZE), wide, view.y * 0.012)
	var top := view.y * TOP_OF_ALL - (words_tall + by_tall) * 0.5
	_words.position = Vector2(view.x * FROM_X - pad, top)
	_by.position = Vector2(view.x * FROM_X - view.y * 0.012, top + words_tall + view.y * NAME_GAP - pad * 0.5)


## Lays the label out on its page, the page's picture on the rect; returns the rect's height.
func _fit(line: Label, page: SubViewport, rect: TextureRect, font_size: int, wide: float, pad: float) -> float:
	line.add_theme_font_size_override("font_size", font_size)
	line.position = Vector2(pad, pad)
	line.size = Vector2(wide, 0.0)
	var tall := line.get_minimum_size().y + pad * 2.0
	var size_now := Vector2(wide + pad * 2.0, tall)
	page.size = Vector2i(size_now)
	page.render_target_update_mode = SubViewport.UPDATE_ONCE
	rect.size = size_now
	var look := rect.material as ShaderMaterial
	var aspect := size_now.x / maxf(size_now.y, 1.0)
	look.set_shader_parameter(&"aspect", aspect)
	look.set_shader_parameter(&"half_size", Vector2(aspect * 0.5 * 0.96, 0.46))
	return tall
