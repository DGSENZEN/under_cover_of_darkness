extends CanvasLayer
## What a fight does to your sight (adrenaline.gdshader), in one pass under
## the retro screen (layer 4) and the HUD (layer 5):
##  - full adrenaline: the edges of the view warm and darken with a slow
##    heartbeat, stronger while you wind up the power blow that would spend it;
##  - a blow landing, yours or his: the view jolts for an instant;
##  - cut: red floods in from the side it came from;
##  - near death: the colour drains out of everything.
##
##   var view := AdrenalineView.new()
##   add_child(view)
##   view.show_state(fraction, primed, delta)   # every frame
##   view.set_health(fraction)                  # every frame
##   AdrenalineView.jolt(get_tree(), 1.0)       # a heavy blow landed
##   AdrenalineView.cut(get_tree(), 0.8, -1.0)  # hurt, from the left

const SHADER := preload("res://scripts/Visual/adrenaline.gdshader")
## Beats a minute: a heart working hard.
const BPM := 84.0
## Below this much health the colour starts to go.
const WOUNDED_BELOW := 0.4
## How long a jolt and a cut take to die away, seconds (real time).
const JOLT_TIME := 0.16
const CUT_TIME := 0.55

var _rect: ColorRect
var _material: ShaderMaterial
var _ready_shown := 0.0
var _primed_shown := 0.0
var _clock := 0.0
var _impact := 0.0
var _hurt := 0.0
var _hurt_side := 0.0
var _wounded := 0.0
var _wounded_shown := 0.0


## A blow landed: every view in the tree jolts. 1 is a heavy one.
static func jolt(tree: SceneTree, strength: float) -> void:
	if tree == null:
		return

	for view in tree.get_nodes_in_group(&"combat_view"):
		view.impact(strength)


## You were cut: every view in the tree floods red from `side` (-1 left,
## 0 ahead, 1 right).
static func cut(tree: SceneTree, strength: float, side: float) -> void:
	if tree == null:
		return

	for view in tree.get_nodes_in_group(&"combat_view"):
		view.hurt(strength, side)


func _ready() -> void:
	layer = 3
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"combat_view")
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_rect = ColorRect.new()
	_rect.name = "Adrenaline"
	_rect.material = _material
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.visible = false
	add_child(_rect)


func impact(strength: float) -> void:
	_impact = maxf(_impact, clampf(strength, 0.0, 1.5))


func hurt(strength: float, side: float) -> void:
	_hurt = maxf(_hurt, clampf(strength, 0.0, 1.0))
	_hurt_side = clampf(side, -1.0, 1.0)


## `fraction` of your health left (1 whole). Call every frame.
func set_health(fraction: float) -> void:
	_wounded = clampf(1.0 - fraction / WOUNDED_BELOW, 0.0, 1.0) if fraction > 0.0 else 0.0


## `fraction` of adrenaline (1 is full: a finisher is ready), `primed` while a
## power blow is being wound up. Call every frame.
func show_state(fraction: float, primed: bool, delta: float) -> void:
	# Real time: slow motion slows the world, not your heart or your eyes.
	var real := delta / maxf(Engine.time_scale, 0.05)
	var full := fraction >= 1.0
	_ready_shown = move_toward(_ready_shown, 1.0 if full else 0.0, delta / (0.6 if full else 0.25))
	_primed_shown = move_toward(_primed_shown, 1.0 if full and primed else 0.0, delta / 0.15)
	_impact = move_toward(_impact, 0.0, real * 1.5 / JOLT_TIME)
	_hurt = move_toward(_hurt, 0.0, real / CUT_TIME)
	_wounded_shown = move_toward(_wounded_shown, _wounded, real / 0.8)
	_rect.visible = _ready_shown > 0.001 or _impact > 0.001 or _hurt > 0.001 or _wounded_shown > 0.001

	if not _rect.visible:
		_clock = 0.0
		return

	_clock += real
	var phase := fmod(_clock * BPM / 60.0, 1.0)
	# Lub, dub.
	var thump := exp(-pow(phase / 0.06, 2.0)) + 0.6 * exp(-pow((phase - 0.17) / 0.06, 2.0))
	_material.set_shader_parameter("ready", _ready_shown)
	_material.set_shader_parameter("beat", clampf(thump, 0.0, 1.0))
	_material.set_shader_parameter("primed", _primed_shown)
	_material.set_shader_parameter("impact", _impact)
	_material.set_shader_parameter("hurt", _hurt * _hurt)
	_material.set_shader_parameter("hurt_side", _hurt_side)
	_material.set_shader_parameter("wounded", _wounded_shown)


## How strongly the adrenaline shows (tests).
func strength() -> float:
	return _ready_shown if _rect.visible else 0.0


## How hard the view is jolted and how red it runs right now (tests).
func jolted() -> float:
	return _impact


func flooded() -> float:
	return _hurt
