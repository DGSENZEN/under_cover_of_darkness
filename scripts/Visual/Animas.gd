extends Node3D
## Ánimas in a drain (docs/superpowers/refs/underground/supernatural_refs.md): the souls of the
## old city's drowned, come up the drain from its cistern, drawn by the living's candles. Small
## flat flames (anima.gdshader) wander in the sump under the grate, lighting its bars from
## below; now and then one rises through a gap between the bars, leans toward the candles
## (`toward`) a while, and sinks again; from anyone near (`flee_from`) they all slip to the
## bottom and dim, and come back once the near have gone. Placed at the drain's middle, at the
## floor; its axes the grate's (its bars run along X, the gaps between them at `lanes` along Z).

const SHADER := preload("res://scripts/Visual/anima.gdshader")
## Where they wander (local m): the sump's middle and how far either way.
const HOME := Vector3(0.0, -0.12, 0.0)
const REACH := Vector3(0.2, 0.06, 0.2)
## How deep they slip when they flee, how near the living must come for it, how fast they go
## and come back (per second).
const BOTTOM := -0.18
const FLEE := 1.4
const DIM_RATE := 3.0
const RETURN_RATE := 1.0
## A rise: how high over the floor, how far it leans toward the candles, and how long each
## part takes (s): to its gap, up, the lean held, back over its gap, down.
const RISE_Y := 0.3
const LEAN := 0.3
const RISE_PARTS := [0.3, 1.2, 2.0, 1.0, 1.0]
## How long between rises (s), at random from the seed.
const RISE_EVERY := Vector2(25.0, 60.0)
const FLAME_SIZE := Vector2(0.07, 0.11)
## Their glow seen only through the grate: a sheet of cold light just under its bars (so the
## bars stand black against it, the image Mignola would draw), its size and depth (local m);
## and a small light deep in the sump for its walls (a light any higher would tint the floor
## round the drain, the painterly ramp wrapping it over the tiles' tops).
const SHEET := Vector2(0.54, 0.54)
const SHEET_Y := -0.045
const GLOW_Y := -0.19
const GLOW_ENERGY := 0.25
const SHEET_CODE := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, shadows_disabled;
uniform vec4 colour : source_color;
uniform float presence = 1.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float fall = clamp(1.0 - dot(p, p) * 0.7, 0.0, 1.0);
	float stir = 0.85 + 0.15 * sin(TIME * 1.7 + p.x * 4.0) * sin(TIME * 1.1 + p.y * 3.0);
	ALBEDO = colour.rgb * fall * stir * presence * 1.2;
}
"""

@export var count := 4
@export var seed := 7
@export var colour := Color("a8eba0")
@export var flee_from: Node3D
@export var toward: Node3D
## The gaps between the grate's bars, along local Z.
@export var lanes := PackedFloat32Array()

var lights: Array[Node3D] = []
var glow: OmniLight3D
## 1 when they are here; 0 when they have fled.
var presence := 1.0

var _time := 0.0
var _rng := RandomNumberGenerator.new()
var _phases := []
var _riser := -1
var _rise_t := 0.0
var _rise_from := Vector3.ZERO
var _rise_lane := 0.0
var _rise_lean := Vector3.ZERO
var _next_rise := 0.0
var _materials: Array[ShaderMaterial] = []
var _sheet: ShaderMaterial


func _ready() -> void:
	_rng.seed = seed

	for i in count:
		var flame := MeshInstance3D.new()
		flame.name = "anima_%d" % i
		var quad := QuadMesh.new()
		quad.size = FLAME_SIZE
		var look := ShaderMaterial.new()
		look.shader = SHADER
		look.set_shader_parameter(&"colour", colour)
		look.set_shader_parameter(&"seed", float(i) * 1.37 + seed)
		quad.material = look
		flame.mesh = quad
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(flame)
		lights.append(flame)
		_materials.append(look)
		_phases.append(Vector3(_rng.randf_range(0.0, TAU), _rng.randf_range(0.0, TAU), _rng.randf_range(0.0, TAU)))
		flame.position = _wander(i)

	var sheet := MeshInstance3D.new()
	sheet.name = "anima_sheet"
	var plane := PlaneMesh.new()
	plane.size = SHEET
	_sheet = ShaderMaterial.new()
	_sheet.shader = Shader.new()
	_sheet.shader.code = SHEET_CODE
	_sheet.set_shader_parameter(&"colour", colour)
	plane.material = _sheet
	sheet.mesh = plane
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sheet)
	sheet.position = Vector3(0.0, SHEET_Y, 0.0)

	glow = OmniLight3D.new()
	glow.name = "anima_glow"
	glow.light_color = colour
	glow.omni_range = 0.35
	glow.shadow_enabled = false
	glow.light_energy = GLOW_ENERGY
	add_child(glow)
	glow.position = Vector3(0.0, GLOW_Y, 0.0)
	_next_rise = _rng.randf_range(RISE_EVERY.x, RISE_EVERY.y)


## One ánima sent up now (tests; the drain sends them up itself at random); returns it.
func rise_now() -> Node3D:
	_riser = _rng.randi_range(0, count - 1)
	_rise_t = 0.0
	_rise_from = lights[_riser].position
	_rise_lane = _nearest_lane(_rise_from.z)
	var lean := Vector3.ZERO

	if toward != null:
		var to := to_local(toward.global_position)
		lean = Vector3(to.x, 0.0, to.z).normalized() * LEAN

	_rise_lean = lean
	return lights[_riser]


func _process(delta: float) -> void:
	_time += delta
	var near := flee_from != null and Vector2(flee_from.global_position.x - global_position.x,
		flee_from.global_position.z - global_position.z).length() < FLEE

	if near:
		presence = maxf(0.0, presence - DIM_RATE * delta * maxf(presence, 0.1))
		_riser = -1
	else:
		presence = minf(1.0, presence + RETURN_RATE * delta)

	if not near and _riser < 0:
		_next_rise -= delta
		if _next_rise <= 0.0:
			rise_now()
			_next_rise = _rng.randf_range(RISE_EVERY.x, RISE_EVERY.y)

	var ease := 1.0 - exp(-4.0 * delta)

	for i in count:
		var want := _wander(i)

		if near:
			want.y = BOTTOM
		elif i == _riser:
			want = _rising(delta)
			lights[i].position = want
			continue

		lights[i].position = lights[i].position.lerp(want, ease)

	for look in _materials:
		look.set_shader_parameter(&"presence", presence)

	_sheet.set_shader_parameter(&"presence", presence)
	glow.light_energy = GLOW_ENERGY * presence


func _wander(i: int) -> Vector3:
	var p: Vector3 = _phases[i]
	return HOME + Vector3(sin(_time * 0.53 + p.x) * REACH.x, sin(_time * 0.81 + p.y) * REACH.y,
		sin(_time * 0.37 + p.z) * REACH.z)


## Where the rising one is now: to its gap, up through it, leaning toward the candles, back
## over its gap, down again; done, it wanders again.
func _rising(delta: float) -> Vector3:
	_rise_t += delta
	var t := _rise_t
	var at_gap := Vector3(_rise_from.x, _rise_from.y, _rise_lane)
	var above := Vector3(_rise_from.x, RISE_Y, _rise_lane)
	var leaned := above + _rise_lean
	var parts: Array = RISE_PARTS

	if t < parts[0]:
		return _rise_from.lerp(at_gap, _smooth(t / parts[0]))
	t -= parts[0]
	if t < parts[1]:
		return at_gap.lerp(above, _smooth(t / parts[1]))
	t -= parts[1]
	if t < parts[2]:
		return above.lerp(leaned, _smooth(minf(1.0, t / (parts[2] * 0.6))))
	t -= parts[2]
	if t < parts[3]:
		return leaned.lerp(above, _smooth(t / parts[3]))
	t -= parts[3]
	if t < parts[4]:
		return above.lerp(Vector3(above.x, HOME.y, above.z), _smooth(t / parts[4]))

	_riser = -1
	return Vector3(above.x, HOME.y, above.z)


func _nearest_lane(z: float) -> float:
	if lanes.is_empty():
		return z

	var best: float = lanes[0]

	for lane in lanes:
		if absf(lane - z) < absf(best - z):
			best = lane

	return best


static func _smooth(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
