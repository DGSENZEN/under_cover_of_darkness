extends CanvasLayer
## The edge of the view coloured by magic: Blink's cold flash as you pass
## through the glass, and Empower's slow beast pulse while its charge waits.
## One per tree, made on first use (of()).

const SHADER := preload("res://scripts/Visual/magic_view.gdshader")

## Blink's cold flash, and Empower's umber pulse (70 a minute).
const COLD := Color("#DDE6F2")
const BEAST := Color("#4A3423")
const BEAST_BPM := 70.0
const BEAST_MOST := 0.55

var _rect: ColorRect
var _material: ShaderMaterial
var _cold_t := -1.0
var _cold_for := 0.1
var _cold := 0.0
var _beast := 0.0
var _clock := 0.0


## The tree's view, made on first use.
static func of(tree: SceneTree) -> CanvasLayer:
	# (Remembered on the root, so a second ask before it has joined the
	# tree finds the same one.)
	if tree.root.has_meta(&"magic_view"):
		var known: Variant = tree.root.get_meta(&"magic_view")

		if known is CanvasLayer and is_instance_valid(known):
			return known

	var view: CanvasLayer = (load("res://scripts/Visual/MagicView.gd") as GDScript).new()
	view.name = "MagicView"
	tree.root.add_child.call_deferred(view)
	tree.root.set_meta(&"magic_view", view)
	# (Usable at once, before it joins the tree.)
	return view


## Blink's cold flash, rising and falling over `seconds`.
static func cold(tree: SceneTree, seconds := 0.1) -> void:
	var view := of(tree)
	view._cold_t = 0.0
	view._cold_for = maxf(seconds, 0.01)
	view._cold = 0.0001


func _init() -> void:
	layer = 9
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_rect.material = _material
	add_child(_rect)


func cold_amount() -> float:
	return _cold


## Empower's charge waiting (0..1, eased by the caller): the pulse.
func set_beast(amount: float) -> void:
	_beast = clampf(amount, 0.0, 1.0)


func beast_amount() -> float:
	return _beast


func _physics_process(delta: float) -> void:
	_clock += delta

	if _cold_t >= 0.0:
		_cold_t += delta
		_cold = sin(PI * clampf(_cold_t / _cold_for, 0.0, 1.0))

		if _cold_t >= _cold_for:
			_cold_t = -1.0
			_cold = 0.0

	var pulse := _beast * BEAST_MOST * (0.6 + 0.4 * sin(_clock * TAU * BEAST_BPM / 60.0))

	if _cold > pulse:
		_material.set_shader_parameter(&"tint", COLD)
		_material.set_shader_parameter(&"amount", _cold)
	else:
		_material.set_shader_parameter(&"tint", BEAST)
		_material.set_shader_parameter(&"amount", pulse)
