extends Node3D
## Ánimas from a drain (docs/superpowers/refs/underground/supernatural_refs.md): the souls of the
## old city's drowned, come up the drain from its cistern, drawn by the living's candles. Each is
## drawn the Deadlock way (vfx_method.md: meshes, not cards): a 3D flame, its bright core inside a
## larger shell the noise eats away as it climbs, a ribbon of itself trailing where it has been,
## its light pooling on the floor under it. Some wander in the sump under the grate, its bars black against
## their glow; most of the time a few are out: each rises through a gap between the bars, drifts
## round the drain up to chest height, leaning toward the candles (`toward`), and in a while sinks
## home. From anyone near (`flee_from`) they keep their distance and dim, but stay; from what they
## fear passing (`hush`, the dark train) they all sink and go dark. Placed at the drain's middle
## at the floor, its axes the grate's (the gaps between its bars at `lanes` along Z).

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
## A soul's flame: its core's height and width, its shell's, its trail's length (points) and width.
const CORE := Vector2(0.26, 0.075)
const SHELL := Vector2(0.46, 0.16)
const TRAIL_POINTS := 22
const TRAIL_EVERY := 0.035
const TRAIL_WIDTH := 0.16
## Its bands: a near-white core, the seeped green body, a deep cold edge.
const CORE_COLOUR := Color("eafff0")
const BODY_COLOUR := Color("8fe39a")
const EDGE_COLOUR := Color("1d5446")
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

## Each ánima's flame (its core; it carries its shell and its light), and its trail.
var lights: Array[MeshInstance3D] = []
var shells: Array[MeshInstance3D] = []
var ribbons: Array[MeshInstance3D] = []
var lamps: Array[OmniLight3D] = []
var glow: OmniLight3D
## 1 when they are here; 0 when they have hidden from what passes.
var presence := 1.0
## Something passing they fear (the dark train, 0-1): they all sink and go dark.
var hush := 0.0
## Something they gather to (the procession walking): those out drift round it instead.
var gather: Node3D

var _time := 0.0
var _rng := RandomNumberGenerator.new()
var _souls := []
var _next_rise := 0.0
var _cores: Array[ShaderMaterial] = []
var _shell_looks: Array[ShaderMaterial] = []
var _trail_looks: Array[ShaderMaterial] = []
var _paths := []
var _trail_clock := 0.0
var _sheet: ShaderMaterial


func _ready() -> void:
	_rng.seed = seed

	var core_mesh := MeshVfx.flame(CORE.x, CORE.y)
	var shell_mesh := MeshVfx.flame(SHELL.x, SHELL.y, 14, 16)

	for i in count:
		var flame := MeshInstance3D.new()
		flame.name = "anima_%d" % i
		flame.mesh = core_mesh
		var core := MeshVfx.look(CORE_COLOUR, BODY_COLOUR, EDGE_COLOUR, 3.2, 0.02, 0.9, float(i) * 3.1)
		core.set_shader_parameter(&"tail_eat", 0.5)
		core.set_shader_parameter(&"churn", 0.004)
		flame.set_surface_override_material(0, core)
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(flame)
		lights.append(flame)
		_cores.append(core)

		# Its shell, larger, rooted a little below the core, eaten away in tongues as it climbs.
		var shell := MeshInstance3D.new()
		shell.name = "shell"
		shell.mesh = shell_mesh
		var outer := MeshVfx.look(BODY_COLOUR, BODY_COLOUR.darkened(0.25), EDGE_COLOUR, 2.0, 0.28, 1.4, float(i) * 1.7 + 9.0)
		outer.set_shader_parameter(&"tail_eat", 0.75)
		outer.set_shader_parameter(&"churn", 0.012)
		outer.set_shader_parameter(&"tiling", Vector2(1.2, 0.8))
		outer.set_shader_parameter(&"opacity", 0.7)
		shell.set_surface_override_material(0, outer)
		shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flame.add_child(shell)
		shell.position = Vector3(0.0, -0.04, 0.0)
		shells.append(shell)
		_shell_looks.append(outer)

		# Its trail: a ribbon of itself left where it has been (drawn in the world, not carried).
		var ribbon := MeshInstance3D.new()
		ribbon.name = "ribbon_%d" % i
		ribbon.top_level = true
		var trail := MeshVfx.look(BODY_COLOUR, BODY_COLOUR.darkened(0.2), EDGE_COLOUR, 2.0, 0.15, 1.8, float(i) * 2.3 + 4.0)
		trail.set_shader_parameter(&"tail_eat", 0.85)
		trail.set_shader_parameter(&"tiling", Vector2(1.0, 3.0))
		trail.set_shader_parameter(&"churn", 0.0)
		ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ribbon)
		ribbon.global_transform = Transform3D.IDENTITY
		ribbons.append(ribbon)
		_trail_looks.append(trail)
		_paths.append(PackedVector3Array())

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

	_trail(delta)

	_sheet.set_shader_parameter(&"presence", presence)
	glow.light_energy = GLOW_ENERGY * presence


func _rise(i: int) -> void:
	var soul: Dictionary = _souls[i]
	soul["state"] = "rising"
	soul["t"] = 0.0
	soul["lane"] = _nearest_lane(lights[i].position.z)
	soul["until"] = _rng.randf_range(OUT_FOR.x, OUT_FOR.y)
	soul["goal"] = _goal()


## Somewhere round the drain to drift to, a little toward the candles, at a spirit's height; or,
## while something passes they gather to, somewhere round it.
func _goal() -> Vector3:
	if gather != null and is_instance_valid(gather) and gather.is_visible_in_tree():
		var round_it := to_local(gather.global_position)
		var a := _rng.randf_range(0.0, TAU)
		return Vector3(round_it.x + cos(a) * 0.8, _rng.randf_range(0.6, 1.6), round_it.z + sin(a) * 0.8)

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
			# (Gathering, they keep up with what they gather to.)
			var gathering := gather != null and is_instance_valid(gather) and gather.is_visible_in_tree()
			if at.distance_to(goal) < 0.15 or (gathering and Vector2(goal.x, goal.z).distance_to(
					Vector2(to_local(gather.global_position).x, to_local(gather.global_position).z)) > 1.2):
				soul["goal"] = _goal()
			var phase: Vector3 = soul["phase"]
			var bob := Vector3(sin(_time * 1.3 + phase.x), sin(_time * 0.9 + phase.y) * 0.6, sin(_time * 1.1 + phase.z)) * 0.08
			at = at.move_toward(goal + bob, SPEED * (2.0 if gathering else 1.0) * delta)
			at = _keep_off(at, delta)
			if soul["t"] > soul["until"] and not gathering:
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
	# Fading is eating: a soul going dim is eaten away, never made see-through.
	_cores[i].set_shader_parameter(&"erosion", lerpf(0.75, 0.02, shown))
	_shell_looks[i].set_shader_parameter(&"erosion", lerpf(0.9, 0.28, shown))
	_trail_looks[i].set_shader_parameter(&"erosion", lerpf(0.95, 0.15, shown))
	var risen := clampf(at.y / 0.4, 0.0, 1.0)
	lamps[i].light_energy = LAMP_ENERGY * risen * shown


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


## Each soul's trail: where it has been, a point every TRAIL_EVERY s, drawn as a ribbon turned to
## the eye; none while it is home under the grate.
func _trail(delta: float) -> void:
	_trail_clock += delta
	var step := _trail_clock >= TRAIL_EVERY
	if step:
		_trail_clock = 0.0
	var camera := get_viewport().get_camera_3d()
	var eye := camera.global_position if camera != null else global_position + Vector3(0, 1.6, 3)

	for i in count:
		var path: PackedVector3Array = _paths[i]
		var head := lights[i].global_position + Vector3(0.0, CORE.x * 0.35, 0.0)

		if _souls[i]["state"] == "home":
			path.clear()
		elif step:
			path.insert(0, head)
			if path.size() > TRAIL_POINTS:
				path.resize(TRAIL_POINTS)
		elif path.size() > 0:
			path[0] = head

		_paths[i] = path
		if path.size() >= 2:
			# (Its look on the mesh itself: a mesh made anew each frame drops a node's override.)
			var strip := MeshVfx.ribbon(path, TRAIL_WIDTH, eye)
			strip.surface_set_material(0, _trail_looks[i])
			ribbons[i].mesh = strip
		else:
			ribbons[i].mesh = null


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
