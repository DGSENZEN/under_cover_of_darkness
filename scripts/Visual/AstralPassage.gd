extends Node3D
## An astral passage (docs/superpowers/specs/2026-10-26-astral-passages-design.md): a dark stretch beyond the market's
## wards, where nothing built holds back the Metro's thin dark (the same the north circle's rite opened), walked as
## through the astral plane toward the market. The stretch's box is gone: its greybox unseen (still solid), windows
## where its walls, ceiling and floor were (astral_window.gdshader), and behind them, seen only through them, the void
## with real depth: its painted sky (astral_sky.gdshader), the city's fragments and the presences drifting in it
## (astral_ink.gdshader). Veils of pale light across the way part round the walker (astral_veil.gdshader); motes
## drift toward the market. Our own effects: no lights.
## Set up by `make` (maps/metro.gd), in the map's frame.

const Layers := preload("res://scripts/Visual/Layers.gd")
const WINDOW := preload("res://scripts/Visual/astral_window.gdshader")
const SKY := preload("res://scripts/Visual/astral_sky.gdshader")
const VEIL := preload("res://scripts/Visual/astral_veil.gdshader")
## How far below the floor the floor's window lies (the way's stones over it hide it), and the walls' windows reach.
const BELOW := 0.6
## The sky's sphere round the passage's middle (m).
const SKY_RADIUS := 45.0
## Where along the passage (its share from the market's mouth) the veils hang.
const VEILS_AT := [0.25, 0.5, 0.75]
## The motes drifting toward the market: how many, how long each lives (s), their pace (m/s).
const MOTES := 180
const MOTE_LIFE := 14.0
const MOTE_PACE := Vector2(0.12, 0.35)

## Its box (the map's frame: the corridor's floor to its ceiling), the market's mouth (the box's end nearest the
## Pasaje: -1 its low z end, 1 its high), and the corridor's gaps ([{a, b: Vector2 (x, z) ends, y0, y1}]).
var bounds: AABB
var mouth_end := 1
var gaps: Array = []
## Who walks through; the stretch's greybox (unseen, its collider kept); the way (polylines, the main first).
var walker: Node3D
var greybox: MeshInstance3D
var way: Array = []
## Its pieces.
var windows: Array[MeshInstance3D] = []
var sky: MeshInstance3D
var stones: Array[MeshInstance3D] = []
var fragments: Array[Node3D] = []
var presences: Array[Node3D] = []
var thresholds: Array[MeshInstance3D] = []
var veils: Array[MeshInstance3D] = []
var motes: GPUParticles3D
## Its crossings (each time the walker passes a threshold) and whether the walker is inside.
var crossings := 0
var inside := false

var _mouth: Vector3
var _away: Vector3
var _span: float


## An astral passage over the corridor `box`, its market's mouth at its `end` (1: its high z end), its windows cut
## round `holes` ([{a, b, y0, y1}]), parting round `who`; `grey` the stretch's greybox mesh; `paths` its way.
static func make(box: AABB, end: int, holes: Array, who: Node3D, grey: MeshInstance3D = null, paths: Array = []) -> Node3D:
	var passage: Node3D = load("res://scripts/Visual/AstralPassage.gd").new()
	passage.bounds = box
	passage.mouth_end = end
	passage.gaps = holes
	passage.walker = who
	passage.greybox = grey
	passage.way = paths
	return passage


func _ready() -> void:
	var middle := bounds.get_center()
	_span = bounds.size.z
	_mouth = Vector3(middle.x, bounds.position.y, bounds.end.z if mouth_end > 0 else bounds.position.z)
	_away = Vector3(0.0, 0.0, -float(mouth_end))
	if greybox != null:
		greybox.visible = false
	_windows()
	_sky()
	_veils()
	_motes()


## How strongly it shows `t` (share from the market's mouth) along.
func grown(t: float) -> float:
	return smoothstep(1.0, 0.55, t) * (0.45 + 0.55 * smoothstep(0.0, 0.18, t))


func _process(_delta: float) -> void:
	if walker == null or not is_instance_valid(walker):
		return
	var at := walker.global_position
	for veil in veils:
		(veil.get_surface_override_material(0) as ShaderMaterial).set_shader_parameter(&"walker", at)


## The windows where its walls, ceiling and floor were: each wall cut round its gaps (a run either side, a lintel over),
## the wall at the market's mouth left open, the floor's window BELOW the floor.
func _windows() -> void:
	var look := ShaderMaterial.new()
	look.shader = WINDOW
	var low := bounds.position.y - BELOW
	var high := bounds.end.y
	var x0 := bounds.position.x
	var x1 := bounds.end.x
	var z0 := bounds.position.z
	var z1 := bounds.end.z
	# [its line (from, to in x-z), its inward normal]; the market's end left out.
	var walls := [[Vector2(x0, z0), Vector2(x0, z1), Vector3(1, 0, 0)], [Vector2(x1, z0), Vector2(x1, z1), Vector3(-1, 0, 0)]]
	var far_z := z0 if mouth_end > 0 else z1
	walls.append([Vector2(x0, far_z), Vector2(x1, far_z), Vector3(0, 0, 1 if mouth_end > 0 else -1)])
	for wall: Array in walls:
		var a: Vector2 = wall[0]
		var b: Vector2 = wall[1]
		var length := a.distance_to(b)
		var along := (b - a) / length
		# (Its gaps, as runs along it.)
		var holes := []
		for gap: Dictionary in gaps:
			var ga: Vector2 = gap["a"]
			var gb: Vector2 = gap["b"]
			var off_a := absf((ga - a).cross(along))
			var off_b := absf((gb - a).cross(along))
			if off_a < 0.05 and off_b < 0.05:
				var s0 := (ga - a).dot(along)
				var s1 := (gb - a).dot(along)
				holes.append([minf(s0, s1), maxf(s0, s1), float(gap["y1"])])
		holes.sort_custom(func(p, q): return p[0] < q[0])
		var from := 0.0
		for hole: Array in holes + [[length, length, high]]:
			if hole[0] - from > 0.01:
				_window(look, a + along * (from + hole[0]) / 2.0, along, hole[0] - from, low, high, wall[2])
			if hole[1] - hole[0] > 0.01 and high - hole[2] > 0.01:
				_window(look, a + along * (hole[0] + hole[1]) / 2.0, along, hole[1] - hole[0], hole[2], high, wall[2])
			from = maxf(from, hole[1])
	# The ceiling and, below the floor, the floor.
	for spec in [[high, Vector3.DOWN], [low, Vector3.UP]]:
		var flat := _plain(look, Vector2(bounds.size.x, bounds.size.z))
		flat.position = Vector3(bounds.get_center().x, spec[0], bounds.get_center().z)
		flat.rotation.x = PI / 2.0 if spec[1] == Vector3.DOWN else -PI / 2.0


## A window upright on a wall: `width` along `along` round `middle` (x, z), from `y0` to `y1`, facing `normal`.
func _window(look: Material, middle: Vector2, along: Vector2, width: float, y0: float, y1: float, normal: Vector3) -> void:
	var piece := _plain(look, Vector2(width, y1 - y0))
	piece.position = Vector3(middle.x, (y0 + y1) / 2.0, middle.y)
	piece.rotation.y = atan2(normal.x, normal.z)


func _plain(look: Material, size: Vector2) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = size
	var piece := MeshInstance3D.new()
	piece.name = "window"
	piece.mesh = quad
	piece.set_surface_override_material(0, look)
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(piece)
	windows.append(piece)
	return piece


## The void's sky: a sphere round the passage, painted inside, drawn first of the void.
func _sky() -> void:
	var look := ShaderMaterial.new()
	look.shader = SKY
	look.render_priority = -10
	look.set_shader_parameter(&"noise", Vfx.noise_3d())
	look.set_shader_parameter(&"centre", bounds.get_center())
	var sphere := SphereMesh.new()
	sphere.radius = SKY_RADIUS
	sphere.height = SKY_RADIUS * 2.0
	sphere.radial_segments = 48
	sphere.rings = 24
	sky = MeshInstance3D.new()
	sky.name = "sky"
	sky.mesh = sphere
	sky.set_surface_override_material(0, look)
	sky.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sky.extra_cull_margin = SKY_RADIUS
	add_child(sky)
	sky.position = bounds.get_center()


## The veils across the way.
func _veils() -> void:
	for t: float in VEILS_AT:
		var look := ShaderMaterial.new()
		look.shader = VEIL
		look.set_shader_parameter(&"noise", Vfx.noise_3d())
		look.set_shader_parameter(&"strength", grown(t))
		var quad := QuadMesh.new()
		quad.size = Vector2(bounds.size.x - 0.3, bounds.size.y - 0.1)
		var veil := MeshInstance3D.new()
		veil.name = "veil"
		veil.mesh = quad
		veil.set_surface_override_material(0, look)
		veil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(veil)
		veil.position = _mouth + _away * t * _span + Vector3(0.0, (bounds.size.y - 0.1) / 2.0, 0.0)
		veils.append(veil)


## The motes, drifting toward the market.
func _motes() -> void:
	motes = GPUParticles3D.new()
	motes.name = "motes"
	motes.amount = MOTES
	motes.lifetime = MOTE_LIFE
	motes.preprocess = MOTE_LIFE
	motes.layers = Layers.FX
	motes.visibility_aabb = AABB(-bounds.size / 2.0 - Vector3.ONE, bounds.size + Vector3.ONE * 2.0)
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(bounds.size.x / 2.0 - 0.4, bounds.size.y / 2.0 - 0.4, _span / 2.0)
	process.direction = -_away
	process.spread = 25.0
	process.initial_velocity_min = MOTE_PACE.x
	process.initial_velocity_max = MOTE_PACE.y
	process.gravity = Vector3.ZERO
	process.scale_min = 0.5
	process.scale_max = 1.4
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 1.0, 1.0, 0.0))
	fade.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	fade.add_point(0.2, Color(0.8, 0.88, 1.0, 1.0))
	fade.add_point(0.8, Color(0.8, 0.88, 1.0, 1.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	process.color_ramp = ramp
	motes.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(0.045, 0.045)
	var look := StandardMaterial3D.new()
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	look.vertex_color_use_as_albedo = true
	var glow := GradientTexture2D.new()
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(0.5, 0.5)
	glow.fill_to = Vector2(1.0, 0.5)
	var soft := Gradient.new()
	soft.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	soft.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	glow.gradient = soft
	look.albedo_texture = glow
	quad.material = look
	motes.draw_pass_1 = quad
	add_child(motes)
	motes.position = bounds.get_center()
