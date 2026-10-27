extends Node3D
## An astral passage (the user's word, Oct 26 2026: "as if we were walking through the astral plane towards the
## pasaje"): the dark stretches either side of the Pasaje, beyond the market's wards, where nothing built holds back
## the Metro's thin dark (the same the north circle's rite opened) and the walker goes as through the astral plane
## toward the market. Its walls and ceiling give way to deep space (astral_skin.gdshader), motes drift past the walker
## toward the market, veils of pale light hang across the way and part round whoever goes through
## (astral_veil.gdshader), and ward rings glow on the floor, brighter as the walker nears. Strongest in its middle,
## easing at the market's mouth, gone toward its far end. Our own effects: no lights, nothing to walk into.
## Set up by `make` (maps/metro.gd), in the map's frame.

const Layers := preload("res://scripts/Visual/Layers.gd")
const SKIN := preload("res://scripts/Visual/astral_skin.gdshader")
const VEIL := preload("res://scripts/Visual/astral_veil.gdshader")
## The ward rings' sheet (the Pasaje's chalk circle, glowing here) and its cell.
const RINGS_SHEET := "pasaje_wards.png"
## How far the skin stands off the greybox's walls and ceiling (m).
const OFF := 0.04
## Where along the passage (its share from the market's mouth) the veils hang and the rings lie; a ring's size (m).
const VEILS_AT := [0.25, 0.5, 0.75]
const RINGS_AT := [0.15, 0.38, 0.62]
const RING_SIZE := 2.6
## The rings' glow: at rest, and as the walker comes within RING_NEAR of one.
const RING_GLOW := Vector2(0.35, 2.4)
const RING_NEAR := 3.5
const RING_COLOUR := Color(0.45, 0.75, 1.0)
## The motes drifting toward the market: how many, how long each lives (s), their pace (m/s).
const MOTES := 180
const MOTE_LIFE := 14.0
const MOTE_PACE := Vector2(0.12, 0.35)

## Its box (the map's frame: the corridor's floor to its ceiling), the market's mouth (the box's end nearest the
## Pasaje: -1 its low z end, 1 its high), and the corridor's openings on its long walls ([at (x, z), width]).
var bounds: AABB
var mouth_end := 1
var openings: Array = []
## Who walks through.
var walker: Node3D
## Its pieces.
var skins: Array[MeshInstance3D] = []
var veils: Array[MeshInstance3D] = []
var rings: Array[Decal] = []
var motes: GPUParticles3D

var _mouth: Vector3
var _away: Vector3
var _span: float


## An astral passage over the corridor `bounds`, its market's mouth at its `mouth_end` (1: its high z end), cut round
## `openings` ([[x, z], width] on its long walls), parting round `who`.
static func make(box: AABB, end: int, gaps: Array, who: Node3D) -> Node3D:
	var passage: Node3D = load("res://scripts/Visual/AstralPassage.gd").new()
	passage.bounds = box
	passage.mouth_end = end
	passage.openings = gaps
	passage.walker = who
	return passage


func _ready() -> void:
	var middle := bounds.get_center()
	_span = bounds.size.z
	_mouth = Vector3(middle.x, bounds.position.y, bounds.end.z if mouth_end > 0 else bounds.position.z)
	_away = Vector3(0.0, 0.0, -float(mouth_end))
	_skin()
	_veils()
	_rings()
	_motes()


## How strongly it shows `t` (share from the market's mouth) along: as its skin's shader does.
func grown(t: float) -> float:
	return smoothstep(1.0, 0.55, t) * (0.45 + 0.55 * smoothstep(0.0, 0.18, t))


func _process(_delta: float) -> void:
	if walker == null or not is_instance_valid(walker):
		return
	var at := walker.global_position
	for veil in veils:
		(veil.get_surface_override_material(0) as ShaderMaterial).set_shader_parameter(&"walker", at)
	for ring in rings:
		var t: float = ring.get_meta("t")
		var near := 1.0 - clampf(Vector2(at.x - ring.global_position.x, at.z - ring.global_position.z).length() / RING_NEAR, 0.0, 1.0)
		ring.emission_energy = (RING_GLOW.x + (RING_GLOW.y - RING_GLOW.x) * near * near) * grown(t)


## Its walls (cut round their openings) and its ceiling, each a quad of deep space.
func _skin() -> void:
	var look := ShaderMaterial.new()
	look.shader = SKIN
	look.set_shader_parameter(&"noise", Vfx.noise_3d())
	look.set_shader_parameter(&"mouth", _mouth)
	look.set_shader_parameter(&"away", _away)
	look.set_shader_parameter(&"span", _span)
	var height := bounds.size.y
	for side in [-1, 1]:
		var x := bounds.position.x + OFF if side < 0 else bounds.end.x - OFF
		# (The wall's runs between its openings.)
		var cuts := []
		for gap: Array in openings:
			if absf(float(gap[0][0]) - (bounds.position.x if side < 0 else bounds.end.x)) < 0.2:
				cuts.append(Vector2(float(gap[0][1]) - float(gap[1]) / 2.0 - 0.1, float(gap[0][1]) + float(gap[1]) / 2.0 + 0.1))
		cuts.sort_custom(func(a, b): return a.x < b.x)
		var from := bounds.position.z
		for cut: Vector2 in cuts + [Vector2(bounds.end.z, bounds.end.z)]:
			var to := minf(cut.x, bounds.end.z)
			if to - from > 0.3:
				var wall := _quad("skin_wall", Vector2(to - from, height - OFF), look)
				wall.position = Vector3(x, bounds.position.y + (height - OFF) / 2.0, (from + to) / 2.0)
				wall.rotation.y = -side * PI / 2.0
			from = maxf(from, cut.y)
	var ceiling := _quad("skin_ceiling", Vector2(bounds.size.x - 2.0 * OFF, _span), look)
	ceiling.position = Vector3(bounds.get_center().x, bounds.end.y - OFF, bounds.get_center().z)
	ceiling.rotation.x = PI / 2.0


func _quad(name: String, size: Vector2, look: Material) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = size
	var piece := MeshInstance3D.new()
	piece.name = name
	piece.mesh = quad
	piece.set_surface_override_material(0, look)
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(piece)
	skins.append(piece)
	return piece


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


## The ward rings on the floor, glowing.
func _rings() -> void:
	var cell := _ring_cell()
	if cell == null:
		return
	for t: float in RINGS_AT:
		var ring := Decal.new()
		ring.name = "ring"
		ring.texture_albedo = cell
		ring.texture_emission = cell
		ring.albedo_mix = 0.0
		ring.modulate = RING_COLOUR
		ring.size = Vector3(RING_SIZE, 0.4, RING_SIZE)
		ring.cull_mask = Layers.WORLD
		ring.set_meta("t", t)
		add_child(ring)
		ring.position = _mouth + _away * t * _span
		ring.rotation.y = t * 7.0
		ring.emission_energy = RING_GLOW.x * grown(t)
		rings.append(ring)


func _ring_cell() -> Texture2D:
	var sheet := SetKit.painted([RINGS_SHEET], SetKit.ATLAS_DIR, true)
	if sheet == null:
		return null
	var image := sheet.get_image()
	if image.is_compressed():
		image.decompress()
	var size := image.get_width() / 2
	var cell := image.get_region(Rect2i(0, 0, size, size))
	cell.generate_mipmaps()
	return ImageTexture.create_from_image(cell)


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
