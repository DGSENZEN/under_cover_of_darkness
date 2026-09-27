extends CanvasLayer
## What lies over the picture: the letterbox (black bars easing in until
## what is left between them is 2.39:1) and the wipe (the last frame held,
## and a hard edge drawn across it, uncovering the next shot beneath, as
## Kurosawa cut between scenes). Above the retro filter (whose grid the
## captured frame already has) and below the showcase's overlay.

const TimeFx := preload("res://scripts/Visual/TimeFx.gd")

## The width over the height of what the bars leave.
const RATIO := 2.39
## The bars ease in or out over this long (real s).
const EASE := 1.5
## A wipe crosses the screen in this long (real s).
const WIPE := 0.6
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

	for i in 2:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bar)

		if i == 0:
			_top = bar
		else:
			_bottom = bar

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


## Any wipe over at once, its frame let go.
func clear() -> void:
	_wipe_t = -1.0

	if _wipe != null:
		_wipe.visible = false
		_wipe.texture = null


func _process(_delta: float) -> void:
	var dt := TimeFx.real_since(_last) if _last >= 0.0 else 0.0
	_last = TimeFx.real_time()
	_shown = move_toward(_shown, 1.0 if _on else 0.0, dt / EASE)

	if wiping():
		_wipe_t += dt
		_wipe_material.set_shader_parameter("edge", wipe_edge())

		if _wipe_t >= WIPE:
			clear()

	_lay_out()


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
