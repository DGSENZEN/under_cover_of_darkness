extends CanvasLayer
## Screen transitions above Retro and below the showcase overlay: 2.39:1 letterbox, wipe, dissolve, and fade through black.
## Captured frames already contain the Retro grid. Envelopes use TimeFx real time; subtitle_band() exposes safe text placement.

const TimeFx := preload("res://scripts/Visual/TimeFx.gd")

## The width over the height of what the bars leave.
const RATIO := 2.39
## The bars ease in or out over this long (real s).
const EASE := 1.5
## A wipe crosses the screen in this long (real s).
const WIPE := 0.6
## A dissolve fades its frame out over this long; a fade goes down to black
## and comes up again over this long each way (real s).
const DISSOLVE := 1.2
const FADE := 0.5
const WIPE_SHADER := """
shader_type canvas_item;
uniform float edge = 0.0;

void fragment() {
	if (UV.x < edge) {
		discard;
	}
}
"""

var _top: ColorRect
var _bottom: ColorRect
var _wipe: TextureRect
var _wipe_material: ShaderMaterial
var _dissolve: TextureRect
var _black: ColorRect
var _dissolve_t := -1.0
## Through black: how long in (-1 with none), and how long held there.
var _fade_t := -1.0
var _fade_hold := 0.0
var _on := false
var _shown := 0.0
var _wipe_t := -1.0
var _last := -1.0


func _init() -> void:
	layer = 6
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_wipe = TextureRect.new()
	_wipe.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wipe.stretch_mode = TextureRect.STRETCH_SCALE
	_wipe.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_wipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wipe.visible = false
	_wipe_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = WIPE_SHADER
	_wipe_material.shader = shader
	_wipe.material = _wipe_material
	add_child(_wipe)
	_dissolve = TextureRect.new()
	_dissolve.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dissolve.stretch_mode = TextureRect.STRETCH_SCALE
	_dissolve.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_dissolve.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dissolve.visible = false
	add_child(_dissolve)

	for i in 2:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bar)

		if i == 0:
			_top = bar
		else:
			_bottom = bar

	_black = ColorRect.new()
	_black.color = Color(0.0, 0.0, 0.0, 0.0)
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_black.visible = false
	add_child(_black)
	_lay_out()


## How tall each bar is on a screen of `size` for the band between to be
## 2.39:1 (none on a screen wider than that).
static func bar_for(size: Vector2) -> float:
	return maxf((size.y - size.x / RATIO) * 0.5, 0.0)


## The bars in (or out), eased over EASE.
func letterbox(on: bool) -> void:
	_on = on


## How tall each bar is now (px).
func bar_height() -> float:
	return bar_for(_screen_size()) * smoothstep(0.0, 1.0, _shown)


## Where the subtitles go while the bars show: the lower bar; else nothing.
func subtitle_band() -> Rect2:
	var bar := bar_height()

	if bar < 1.0:
		return Rect2()

	var size := _screen_size()
	return Rect2(0.0, size.y - bar, size.x, bar)


## The frame just shown, wiped away over WIPE.
func wipe(texture: Texture2D) -> void:
	if texture == null:
		return

	_wipe.texture = texture
	_wipe.visible = true
	_wipe_t = 0.0
	_wipe_material.set_shader_parameter("edge", 0.0)


func wiping() -> bool:
	return _wipe_t >= 0.0


## How far across the edge is (0..1), -1 with no wipe.
func wipe_edge() -> float:
	return clampf(_wipe_t / WIPE, 0.0, 1.0) if wiping() else -1.0


## The frame being wiped away (null when none).
func wipe_texture() -> Texture2D:
	return _wipe.texture if _wipe != null else null


## The frame just shown, fading out over DISSOLVE above the next.
func dissolve(texture: Texture2D) -> void:
	if texture == null or _dissolve == null:
		return

	_dissolve.texture = texture
	_dissolve.modulate.a = 1.0
	_dissolve.visible = true
	_dissolve_t = 0.0


func dissolving() -> bool:
	return _dissolve_t >= 0.0


## How much of the dissolving frame still shows (1..0; 0 with none).
func dissolve_alpha() -> float:
	return 1.0 - clampf(_dissolve_t / DISSOLVE, 0.0, 1.0) if dissolving() else 0.0


## The frame dissolving away (null when none).
func dissolve_texture() -> Texture2D:
	return _dissolve.texture if _dissolve != null else null


## Down to black over FADE, held there `hold` s, then up again over FADE.
func fade_through(hold: float) -> void:
	_fade_t = 0.0
	_fade_hold = maxf(hold, 0.0)
	_lay_black()


func fading() -> bool:
	return _fade_t >= 0.0


## How black the screen is (0..1).
func black() -> float:
	if not fading():
		return 0.0

	if _fade_t < FADE:
		return _fade_t / FADE

	if _fade_t < FADE + _fade_hold:
		return 1.0

	return clampf(1.0 - (_fade_t - FADE - _fade_hold) / FADE, 0.0, 1.0)


## Clears wipe/dissolve/fade state and captured textures; letterbox state is unchanged.
func clear() -> void:
	_wipe_t = -1.0
	_dissolve_t = -1.0
	_fade_t = -1.0

	if _wipe != null:
		_wipe.visible = false
		_wipe.texture = null

	if _dissolve != null:
		_dissolve.visible = false
		_dissolve.texture = null

	_lay_black()


func _process(_delta: float) -> void:
	var dt := TimeFx.real_since(_last) if _last >= 0.0 else 0.0
	_last = TimeFx.real_time()
	_shown = move_toward(_shown, 1.0 if _on else 0.0, dt / EASE)

	if wiping():
		_wipe_t += dt
		_wipe_material.set_shader_parameter("edge", wipe_edge())

		if _wipe_t >= WIPE:
			_wipe_t = -1.0
			_wipe.visible = false
			_wipe.texture = null

	if dissolving():
		_dissolve_t += dt
		_dissolve.modulate.a = dissolve_alpha()

		if _dissolve_t >= DISSOLVE:
			_dissolve_t = -1.0
			_dissolve.visible = false
			_dissolve.texture = null

	if fading():
		_fade_t += dt

		if _fade_t >= FADE * 2.0 + _fade_hold:
			_fade_t = -1.0

	_lay_black()
	_lay_out()


func _lay_black() -> void:
	if _black == null:
		return

	var amount := black()
	_black.color.a = amount
	_black.visible = amount > 0.0


func _lay_out() -> void:
	if _top == null:
		return

	var size := _screen_size()
	var bar := bar_height()
	_top.position = Vector2.ZERO
	_top.size = Vector2(size.x, bar)
	_bottom.position = Vector2(0.0, size.y - bar)
	_bottom.size = Vector2(size.x, bar)
	_top.visible = bar > 0.0
	_bottom.visible = bar > 0.0


func _screen_size() -> Vector2:
	return get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1920, 1080)
