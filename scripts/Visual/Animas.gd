extends Node3D
## Ánimas from a drain (docs/superpowers/refs/underground/supernatural_refs.md): the souls of the
## old city's drowned, come up the drain from its cistern, drawn by the living's candles. Small
## flames (anima.gdshader), each in a soft glow (its halo) trailing wisps of itself, its light
## pooling on the floor under it. Some wander in the sump under the grate, its bars black against
## their glow; most of the time a few are out: each rises through a gap between the bars, drifts
## round the drain up to chest height, leaning toward the candles (`toward`), and in a while sinks
## home. From anyone near (`flee_from`) they keep their distance and dim, but stay; from what they
## fear passing (`hush`, the dark train) they all sink and go dark. Placed at the drain's middle
## at the floor, its axes the grate's (the gaps between its bars at `lanes` along Z).

const SHADER := preload("res://scripts/Visual/anima.gdshader")
const HALO_CODE := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, shadows_disabled;
uniform vec4 colour : source_color;
uniform float presence = 1.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float soft = pow(clamp(1.0 - r, 0.0, 1.0), 2.2);
	ALBEDO = colour.rgb * soft * presence * 1.3;
}
"""
const WISP_CODE := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, shadows_disabled;
uniform vec4 colour : source_color;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0, 0, 0), vec4(0, length(MODEL_MATRIX[1].xyz), 0, 0),
		vec4(0, 0, length(MODEL_MATRIX[2].xyz), 0), vec4(0, 0, 0, 1));
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float soft = clamp(1.0 - length(p), 0.0, 1.0);
	ALBEDO = colour.rgb * soft * soft * COLOR.a;
}
"""
## Where they wander under the grate (local m): the sump's middle and how far either way.
const HOME := Vector3(0.0, -0.12, 0.0)
const REACH := Vector3(0.2, 0.05, 0.2)
## Out of the drain: how far round it they drift, how high (over the floor), and how strongly
## they lean toward the candles; how fast they move (m/s).
const ROAM := 3.0
const HEIGHT := Vector2(0.35, 1.5)
const LEAN := 0.25
const SPEED := 0.45
## How many are out at once (most of the time), how long each stays out, how soon another rises (s).
const WANT_OUT := 5
const OUT_FOR := Vector2(10.0, 20.0)
const RISE_GAP := Vector2(1.5, 4.0)
## How near the living must come before they keep off, and how far they keep (m); how dim they go.
const SHY := 1.6
const KEEP := 1.15
const SHY_DIM := 0.55
const FLAME_SIZE := Vector2(0.13, 0.2)
const HALO_SIZE := 0.9
## The light each casts at full, and how far.
const LAMP_ENERGY := 0.55
const LAMP_RANGE := 1.8
## The glow under the grate: a sheet of light just under its bars, and a light deep in the sump.
const SHEET := Vector2(0.54, 0.54)
const SHEET_Y := -0.045
const GLOW_Y := -0.19
const GLOW_ENERGY := 0.3
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

@export var count := 9
@export var seed := 7
@export var colour := Color("a8eba0")
@export var flee_from: Node3D
@export var toward: Node3D
## The gaps between the grate's bars, along local Z.
@export var lanes := PackedFloat32Array()

## Each ánima's flame (it carries its halo, its wisps and its light).
var lights: Array[Node3D] = []
var halos: Array[MeshInstance3D] = []
var trails: Array[GPUParticles3D] = []
var lamps: Array[OmniLight3D] = []
var glow: OmniLight3D
## 1 when they are here; 0 when they have hidden from what passes.
var presence := 1.0
## Something passing they fear (the dark train, 0-1): they all sink and go dark.
var hush := 0.0

var _time := 0.0
var _rng := RandomNumberGenerator.new()
var _souls := []
var _next_rise := 0.0
var _flames: Array[ShaderMaterial] = []
var _halo_looks: Array[ShaderMaterial] = []
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
		look.set_shader_parameter(&"colour", Color(colour.r * 1.6, colour.g * 1.6, colour.b * 1.6))
		look.set_shader_parameter(&"seed", float(i) * 1.37 + seed)
		quad.material = look
		flame.mesh = quad
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(flame)
		lights.append(flame)
		_flames.append(look)

		var halo := MeshInstance3D.new()
		halo.name = "halo"
		var disc := QuadMesh.new()
		disc.size = Vector2.ONE * HALO_SIZE
		var soft := ShaderMaterial.new()
		soft.shader = Shader.new()
		soft.shader.code = HALO_CODE
		soft.set_shader_parameter(&"colour", colour)
		disc.material = soft
		halo.mesh = disc
		halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flame.add_child(halo)
		halos.append(halo)
		_halo_looks.append(soft)

		var wisps := _wisps()
		flame.add_child(wisps)
		trails.append(wisps)

		var lamp := OmniLight3D.new()
		lamp.name = "lamp"
		lamp.light_color = colour
		lamp.omni_range = LAMP_RANGE
		lamp.shadow_enabled = false
		lamp.light_energy = 0.0
		flame.add_child(lamp)
		lamps.append(lamp)

		var phase := Vector3(_rng.randf_range(0.0, TAU), _rng.randf_range(0.0, TAU), _rng.randf_range(0.0, TAU))
		_souls.append({"state": "home", "phase": phase, "t": 0.0, "until": 0.0, "lane": 0.0, "goal": Vector3.ZERO,
			"fade": 1.0})
		flame.position = _home(i)

	_build_glow()
	_next_rise = _rng.randf_range(0.2, 1.0)


## One ánima sent up now (the stills; they rise by themselves); returns it.
func rise_now() -> Node3D:
	for i in count:
		if _souls[i]["state"] == "home":
			_rise(i)
			return lights[i]

	return lights[0]


func _process(delta: float) -> void:
	_time += delta
	var hidden := hush > 0.3
	presence = maxf(0.0, presence - 3.0 * delta) if hidden else minf(1.0, presence + 0.8 * delta)
	var out := 0

	for soul in _souls:
		out += 1 if soul["state"] != "home" else 0

	if not hidden:
		_next_rise -= delta
		if out < WANT_OUT and _next_rise <= 0.0:
			for i in count:
				if _souls[i]["state"] == "home":
					_rise(i)
					break
			_next_rise = _rng.randf_range(RISE_GAP.x, RISE_GAP.y)

	for i in count:
		_move(i, delta, hidden)

	_sheet.set_shader_parameter(&"presence", presence)
	glow.light_energy = GLOW_ENERGY * presence


func _rise(i: int) -> void:
	var soul: Dictionary = _souls[i]
	soul["state"] = "rising"
	soul["t"] = 0.0
	soul["lane"] = _nearest_lane(lights[i].position.z)
	soul["until"] = _rng.randf_range(OUT_FOR.x, OUT_FOR.y)
	soul["goal"] = _goal()


## Somewhere round the drain to drift to, a little toward the candles, at a spirit's height.
func _goal() -> Vector3:
	var a := _rng.randf_range(0.0, TAU)
	var r := _rng.randf_range(0.3, ROAM)
	var at := Vector3(cos(a) * r, _rng.randf_range(HEIGHT.x, HEIGHT.y), sin(a) * r)

	if toward != null and is_instance_valid(toward):
		var to := to_local(toward.global_position)
		at += Vector3(to.x, 0.0, to.z).normalized() * LEAN * r

	return at


func _move(i: int, delta: float, hidden: bool) -> void:
	var soul: Dictionary = _souls[i]
	var flame := lights[i]
	var at := flame.position
	var state: String = soul["state"]
	soul["t"] += delta

	if hidden and state != "home":
		state = "sinking"
		soul["state"] = state

	match state:
		"home":
			at = at.lerp(_home(i), 1.0 - exp(-3.0 * delta))
		"rising":
			# To its gap, then straight up through it.
			if at.y < 0.05:
				at = at.move_toward(Vector3(at.x, 0.1, soul["lane"]), SPEED * 1.5 * delta)
			else:
				soul["state"] = "out"
		"out":
			var goal: Vector3 = soul["goal"]
			if at.distance_to(goal) < 0.15:
				soul["goal"] = _goal()
			var phase: Vector3 = soul["phase"]
			var bob := Vector3(sin(_time * 1.3 + phase.x), sin(_time * 0.9 + phase.y) * 0.6, sin(_time * 1.1 + phase.z)) * 0.08
			at = at.move_toward(goal + bob, SPEED * delta)
			at = _keep_off(at, delta)
			if soul["t"] > soul["until"]:
				soul["state"] = "sinking"
		"sinking":
			# Back over a gap, then down through it home.
			# (Its gap's mouth well inside the grate's frame: aimed at exactly, a float never lands on it.)
			var lane := _nearest_lane(at.z)
			var mouth := Vector3(clampf(at.x, -0.17, 0.17), maxf(at.y, 0.12), lane)
			if Vector2(at.x - mouth.x, at.z - mouth.z).length() > 0.03:
				at = at.move_toward(mouth, SPEED * 1.6 * delta)
			else:
				at = at.move_toward(Vector3(at.x, HOME.y, lane), SPEED * 1.6 * delta)
				if at.y <= HOME.y + 0.02:
					soul["state"] = "home"

	flame.position = at
	# Shy of the near: dimmer while near them.
	var near := _near_living(at)
	soul["fade"] = lerpf(soul["fade"], SHY_DIM if near else 1.0, 1.0 - exp(-4.0 * delta))
	var shown: float = soul["fade"] * presence
	_flames[i].set_shader_parameter(&"presence", shown)
	_halo_looks[i].set_shader_parameter(&"presence", shown * (1.0 if at.y > 0.0 else 0.4))
	var risen := clampf(at.y / 0.4, 0.0, 1.0)
	lamps[i].light_energy = LAMP_ENERGY * risen * shown
	trails[i].emitting = shown > 0.05
	trails[i].amount_ratio = 0.35 + 0.65 * risen


## Pushed away from the living, so they keep their distance.
func _keep_off(at: Vector3, delta: float) -> Vector3:
	if flee_from == null or not is_instance_valid(flee_from):
		return at

	var them := to_local(flee_from.global_position)
	var off := Vector2(at.x - them.x, at.z - them.z)

	if off.length() < KEEP:
		var away := off.normalized() if off.length() > 0.01 else Vector2(1.0, 0.0)
		var to := Vector2(them.x, them.z) + away * KEEP
		at.x = lerpf(at.x, to.x, 1.0 - exp(-6.0 * delta))
		at.z = lerpf(at.z, to.y, 1.0 - exp(-6.0 * delta))

	return at


func _near_living(at: Vector3) -> bool:
	if flee_from == null or not is_instance_valid(flee_from):
		return false

	var them := to_local(flee_from.global_position)
	return Vector2(at.x - them.x, at.z - them.z).length() < SHY


func _home(i: int) -> Vector3:
	var p: Vector3 = _souls[i]["phase"]
	return HOME + Vector3(sin(_time * 0.53 + p.x) * REACH.x, sin(_time * 0.81 + p.y) * REACH.y,
		sin(_time * 0.37 + p.z) * REACH.z)


func _nearest_lane(z: float) -> float:
	if lanes.is_empty():
		return z

	var best: float = lanes[0]

	for lane in lanes:
		if absf(lane - z) < absf(best - z):
			best = lane

	return best


## Wisps trailing off a flame: small soft specks of its light left behind it as it moves, rising
## a little and fading.
func _wisps() -> GPUParticles3D:
	var wisps := GPUParticles3D.new()
	wisps.name = "wisps"
	wisps.amount = 28
	wisps.lifetime = 1.4
	wisps.local_coords = false
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.03
	process.gravity = Vector3(0.0, 0.08, 0.0)
	process.initial_velocity_min = 0.01
	process.initial_velocity_max = 0.05
	process.spread = 180.0
	process.scale_min = 0.5
	process.scale_max = 1.0
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(1.0, 0.0))
	var curve := CurveTexture.new()
	curve.curve = shrink
	process.scale_curve = curve
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.8))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	process.color_ramp = ramp
	wisps.process_material = process
	var speck := QuadMesh.new()
	speck.size = Vector2(0.06, 0.06)
	var look := ShaderMaterial.new()
	look.shader = Shader.new()
	look.shader.code = WISP_CODE
	look.set_shader_parameter(&"colour", colour)
	speck.material = look
	wisps.draw_pass_1 = speck
	wisps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return wisps


func _build_glow() -> void:
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
