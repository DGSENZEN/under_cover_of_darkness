extends Node3D
## Alchemy's projection (docs/superpowers/specs/2026-10-17-librarian-shop-design.md: "a turning ouroboros, a
## homunculus in a glass flask, alchemical symbols burning gold"), in copper and gold, drawn the Deadlock way on our
## own meshes (vfx_mesh.gdshader) and, for the serpent and the little man, as the ánimas and the dead are
## (anima_silhouette, anima_aura): over an opened alchemy study, a black serpent outlined in copper fire, coiled a full
## turn over the right-hand page,
## its head at its own tail, turning as it swallows itself; over the left-hand page a round flask of glass, its bulb
## half full of glowing water, the homunculus curled in it (Quaternius's CC0 base body, tools/eclipse/library_spectres
## .py), drifting and turning; and round the serpent the old signs (sun, moon, mercury, sulphur, salt, fire) rising,
## flaring gold and burning out near the top, then rising again. Upright in the room, scaled to the room above.

const MeshVfx := preload("res://scripts/Visual/MeshVfx.gd")
const Layers := preload("res://scripts/Visual/Layers.gd")
const Necromancy := preload("res://scripts/Visual/Library/Necromancy.gd")
const SILHOUETTE := preload("res://scripts/Visual/anima_silhouette.gdshader")
const AURA := preload("res://scripts/Visual/anima_aura.gdshader")

const CORE := Color(1.0, 0.92, 0.7)
const COPPER := Color("ef8b40")
const GOLD := Color("f2c14e")
const EDGE := Color(0.32, 0.12, 0.03)
## The room it is built for above the pages (m); where its pieces stand (from the right-hand page's middle: the gutter
## 0.13 m to its left, the left-hand page beyond).
const ROOM := 0.33
const SERPENT_AT := Vector3(0.0, 0.17, 0.0)
const COIL := 0.072
## (Hovering over the left-hand page, clear of its fanning leaves.)
const FLASK_AT := Vector3(-0.26, 0.06, 0.0)
const BULB := 0.042
## The signs: how far round the serpent they circle, how long one takes to rise, from where to where.
const ORBIT := 0.1
const RISE := 5.2
const RISE_FROM := 0.05
const RISE_TO := 0.27
const SIGNS := ["sun", "moon", "mercury", "sulphur", "salt", "fire"]
## How much larger the signs are drawn than they are laid out.
const SIGN_SIZE := 1.5

var kind := &"alchemy"
var ouroboros: MeshInstance3D
var flask: MeshInstance3D
var homunculus: MeshInstance3D
var symbols: Array[MeshInstance3D] = []
var symbol_heights: Array[float] = []
## How far each sign has burnt (0 whole, 1 gone).
var symbol_burns: Array[float] = []

var _seed := 0.0
var _water_look: ShaderMaterial
var _sign_looks: Array[ShaderMaterial] = []
var _inks: Array[ShaderMaterial] = []
var _glass: StandardMaterial3D


func build(seed: float) -> void:
	_seed = seed
	name = "alchemy"
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	visible = false

	# The serpent black, outlined in copper fire, as the little man and the dead are (a glowing coil against the lit
	# pages bloomed into a ring with no head).
	ouroboros = _geometry("ouroboros", _serpent(COIL), _ink(_inks), self)
	ouroboros.position = SERPENT_AT
	_geometry("outline", ouroboros.mesh, _aura(_inks), ouroboros).position = Vector3.ZERO

	# The flask: its glass drawn after what is in it (both are see-through), its water glowing, the little man inside.
	_glass = StandardMaterial3D.new()
	_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# (Both faces: its far side seen through its near one, as glass is.)
	_glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	_glass.albedo_color = Color(0.95, 0.82, 0.62, 0.16)
	_glass.roughness = 0.04
	_glass.metallic_specular = 0.9
	_glass.rim_enabled = true
	_glass.rim = 0.6
	_glass.rim_tint = 0.4
	_glass.render_priority = 1
	flask = _geometry("flask", _flask(), _glass, self)
	flask.position = FLASK_AT
	_water_look = MeshVfx.look(CORE, COPPER.lerp(GOLD, 0.4), EDGE, 1.6, 0.0, 0.25, seed + 4.0)
	_water_look.set_shader_parameter("tail_eat", 0.0)
	var water := SphereMesh.new()
	water.radius = BULB - 0.004
	water.height = (BULB - 0.004) * 1.25
	water.radial_segments = 16
	water.rings = 8
	_geometry("water", water, _water_look, flask).position = Vector3(0.0, BULB * 0.82, 0.0)
	var ink := _ink(_inks)
	homunculus = _geometry("homunculus", Necromancy._spectres().get("alch_homunculus", SphereMesh.new()), ink, flask)
	homunculus.position = Vector3(0.0, BULB, 0.0)
	var outline := _geometry("outline", homunculus.mesh, _aura(_inks), homunculus)
	outline.position = Vector3.ZERO

	for k in SIGNS.size():
		var look := MeshVfx.look(Color(1.0, 0.97, 0.82), GOLD, EDGE, 3.4, 0.0, 0.5, seed + 10.0 + k)
		look.set_shader_parameter("tail_eat", 0.0)
		_sign_looks.append(look)
		symbols.append(_geometry("sign_" + SIGNS[k], _sign(SIGNS[k]), look, self))
		symbol_heights.append(0.0)
		symbol_burns.append(0.0)


## Where it stands (the pages' top middle, the book's heading), how present (0 gone to 1), the room above it.
func set_state(presence: float, clearance: float, time: float, at: Vector3, heading: float) -> void:
	visible = presence > 0.001
	if not visible:
		return
	var fit := clampf(clearance / ROOM, 0.4, 1.0) * lerpf(0.7, 1.0, presence)
	global_transform = Transform3D(Basis(Vector3.UP, heading).scaled(Vector3.ONE * fit), at)

	_water_look.set_shader_parameter("opacity", presence * 0.6)
	_glass.albedo_color.a = 0.16 * presence
	for look in _inks:
		look.set_shader_parameter("presence", presence)

	# The serpent turns round its coil as it swallows itself, its coil leaning a little this way and that.
	ouroboros.quaternion = Quaternion(Vector3.UP, 0.35 * sin(time * 0.4 + _seed)) * Quaternion(Vector3.BACK, -time * 0.55)

	# The little man drifts in his water, turning slowly, breathing.
	homunculus.position = Vector3(0.0, BULB + 0.006 * sin(time * 0.9 + _seed), 0.0)
	homunculus.rotation = Vector3(0.25 * sin(time * 0.5), time * 0.35 + _seed, 0.18 * sin(time * 0.7))
	homunculus.scale = Vector3.ONE * (1.0 + 0.03 * sin(time * 1.6))

	# The signs circle the serpent as they rise, flare at the height of their climb and burn out at its top.
	for k in symbols.size():
		var t := fposmod(time / RISE + float(k) / symbols.size() + _seed * 0.11, 1.0)
		symbol_heights[k] = lerpf(RISE_FROM, RISE_TO, t)
		symbol_burns[k] = smoothstep(0.6, 1.0, t)
		var round_at := TAU * float(k) / symbols.size() + time * 0.3
		symbols[k].position = Vector3(SERPENT_AT.x + cos(round_at) * ORBIT, symbol_heights[k], sin(round_at) * ORBIT * 0.8)
		symbols[k].rotation = Vector3(0.0, 0.4 * sin(time * 0.6 + k), 0.0)
		var look := _sign_looks[k]
		look.set_shader_parameter("opacity", presence * smoothstep(0.0, 0.12, t))
		look.set_shader_parameter("erosion", lerpf(0.02, 0.98, symbol_burns[k]))
		look.set_shader_parameter("energy", 3.4 + 3.0 * sin(t * PI))


## Every piece it draws.
func parts() -> Array:
	return find_children("*", "GeometryInstance3D", true, false)


## The serpent: a body coiled one full turn (round z) and a little more, `coil` across its middle, thick at its head
## and thinning to its tail, its head (a wedge, its jaws open) closing on the tail; v along it from the tail.
static func _serpent(coil: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 72
	var sides := 8
	var sweep := TAU * 1.04
	var rings := []
	for i in steps + 1:
		var t := float(i) / steps
		var a := t * sweep
		var middle := Vector3(cos(a), sin(a), 0.0) * coil
		var out := Vector3(cos(a), sin(a), 0.0)
		var thick := lerpf(0.003, 0.0135, smoothstep(0.0, 0.85, t))
		var ring := []
		for k in sides + 1:
			var b := TAU * k / sides
			ring.append(middle + (out * cos(b) + Vector3.BACK * sin(b)) * thick)
		rings.append(ring)
	for i in steps:
		for k in sides:
			MeshVfx._quad(st, [rings[i][k], rings[i + 1][k], rings[i + 1][k + 1], rings[i][k + 1]],
				[Vector2(float(k) / sides, float(i) / steps), Vector2(float(k) / sides, float(i + 1) / steps),
				Vector2(float(k + 1) / sides, float(i + 1) / steps), Vector2(float(k + 1) / sides, float(i) / steps)])
	# The head: a wedge from the body's end, along it, its upper and lower jaw parted round the tail.
	var a_end := sweep
	var at := Vector3(cos(a_end), sin(a_end), 0.0) * coil
	var ahead := Vector3(-sin(a_end), cos(a_end), 0.0)
	var out_end := Vector3(cos(a_end), sin(a_end), 0.0)
	for jaw in [1.0, -1.0]:
		var base := [at + out_end * 0.013 * jaw + Vector3.BACK * 0.011, at + out_end * 0.013 * jaw - Vector3.BACK * 0.011,
			at - out_end * 0.002 * jaw - Vector3.BACK * 0.008, at - out_end * 0.002 * jaw + Vector3.BACK * 0.008]
		var tip: Vector3 = at + ahead * 0.034 + out_end * 0.009 * jaw
		for k in 4:
			var j := (k + 1) % 4
			MeshVfx._quad(st, [base[k], tip, tip, base[j]], [Vector2(0, 1), Vector2(0, 1), Vector2(1, 1), Vector2(1, 1)])
	st.generate_normals()
	return st.commit()


## A round-bottomed flask turned about y: its bulb BULB across its middle, sitting on its foot at y 0, a narrow neck
## and a lip; closed, its outside only.
static func _flask() -> ArrayMesh:
	var profile := []
	for i in 13:
		var a := -PI / 2.0 + PI * 0.84 * float(i) / 12.0
		profile.append(Vector2(cos(a) * BULB, BULB + sin(a) * BULB))
	profile.append(Vector2(0.012, BULB * 1.95))
	profile.append(Vector2(0.011, 0.14))
	profile.append(Vector2(0.016, 0.145))
	profile.append(Vector2(0.015, 0.152))
	profile.append(Vector2(0.0, 0.152))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 20
	for i in profile.size() - 1:
		for k in sides:
			var corners := []
			for c in [[i, k], [i + 1, k], [i + 1, k + 1], [i, k + 1]]:
				var p: Vector2 = profile[c[0]]
				var b := TAU * float(c[1]) / sides
				corners.append(Vector3(cos(b) * p.x, p.y, sin(b) * p.x))
			MeshVfx._quad(st, [corners[0], corners[3], corners[2], corners[1]],
				[Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	st.generate_normals()
	return st.commit()


## One of the old signs, standing in its own plane (facing +z), about 0.048 tall, drawn as thin bars of fire.
static func _sign(which: String) -> ArrayMesh:
	var r := 0.011
	var strokes := []
	match which:
		"sun":
			strokes = [_ring(r), _ring(0.0025)]
		"moon":
			strokes = [_arc(r, -PI * 0.65, PI * 0.65, Vector2.ZERO), _arc(r * 0.8, -PI * 0.55, PI * 0.55, Vector2(0.0045, 0.0))]
		"mercury":
			strokes = [_ring(r * 0.8), _arc(r * 0.7, PI * 0.15, PI * 0.85, Vector2(0.0, 0.016)),
				_line(Vector2(0.0, -r * 0.8), Vector2(0.0, -0.022)), _line(Vector2(-0.006, -0.016), Vector2(0.006, -0.016))]
		"sulphur":
			strokes = [_line(Vector2(-0.011, 0.002), Vector2(0.0, 0.018)), _line(Vector2(0.0, 0.018), Vector2(0.011, 0.002)),
				_line(Vector2(0.011, 0.002), Vector2(-0.011, 0.002)), _line(Vector2(0.0, 0.002), Vector2(0.0, -0.016)),
				_line(Vector2(-0.007, -0.008), Vector2(0.007, -0.008))]
		"salt":
			strokes = [_ring(r), _line(Vector2(-r, 0.0), Vector2(r, 0.0))]
		_:
			strokes = [_line(Vector2(-0.012, -0.009), Vector2(0.0, 0.013)), _line(Vector2(0.0, 0.013), Vector2(0.012, -0.009)),
				_line(Vector2(0.012, -0.009), Vector2(-0.012, -0.009))]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for path: PackedVector3Array in strokes:
		st.append_from(_bar(path, 0.0014 / SIGN_SIZE), 0, Transform3D.IDENTITY.scaled(Vector3.ONE * SIGN_SIZE))
	return st.commit()


static func _ring(radius: float) -> PackedVector3Array:
	return _arc(radius, 0.0, TAU, Vector2.ZERO)


static func _arc(radius: float, from: float, to: float, centre: Vector2) -> PackedVector3Array:
	var path := PackedVector3Array()
	var steps := maxi(6, int(absf(to - from) / TAU * 28.0))
	for i in steps + 1:
		var a := lerpf(from, to, float(i) / steps)
		path.append(Vector3(centre.x + cos(a) * radius, centre.y + sin(a) * radius, 0.0))
	return path


static func _line(a: Vector2, b: Vector2) -> PackedVector3Array:
	var path := PackedVector3Array()
	for i in 5:
		var p := a.lerp(b, float(i) / 4.0)
		path.append(Vector3(p.x, p.y, 0.0))
	return path


## A thin round bar along `path`; v along it.
static func _bar(path: PackedVector3Array, radius := 0.0013, sides := 6) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := path.size()
	var rings := []
	for i in n:
		var ahead := (path[mini(i + 1, n - 1)] - path[maxi(i - 1, 0)]).normalized()
		var side := ahead.cross(Vector3.BACK).normalized()
		var ring := []
		for k in sides + 1:
			var b := TAU * k / sides
			ring.append(path[i] + (side * cos(b) + Vector3.BACK * sin(b)) * radius)
		rings.append(ring)
	for i in n - 1:
		for k in sides:
			MeshVfx._quad(st, [rings[i][k], rings[i + 1][k], rings[i + 1][k + 1], rings[i][k + 1]],
				[Vector2(float(k) / sides, float(i) / (n - 1)), Vector2(float(k) / sides, float(i + 1) / (n - 1)),
				Vector2(float(k + 1) / sides, float(i + 1) / (n - 1)), Vector2(float(k + 1) / sides, float(i) / (n - 1))])
	st.generate_normals()
	return st.commit()


func _ink(into: Array[ShaderMaterial]) -> ShaderMaterial:
	var ink := ShaderMaterial.new()
	ink.shader = SILHOUETTE
	ink.set_shader_parameter(&"glow", COPPER.lerp(GOLD, 0.5))
	ink.set_shader_parameter(&"noise", MeshVfx.noise())
	ink.set_shader_parameter(&"seed", _seed)
	ink.set_shader_parameter(&"floor_y", -1.0)
	ink.set_shader_parameter(&"wrist", 0.0001)
	ink.set_shader_parameter(&"rim_power", 2.6)
	into.append(ink)
	return ink


func _aura(into: Array[ShaderMaterial]) -> ShaderMaterial:
	var aura := ShaderMaterial.new()
	aura.shader = AURA
	aura.set_shader_parameter(&"glow", COPPER)
	aura.set_shader_parameter(&"noise", MeshVfx.noise())
	aura.set_shader_parameter(&"seed", _seed)
	aura.set_shader_parameter(&"floor_y", -1.0)
	aura.set_shader_parameter(&"wrist", 0.0001)
	aura.set_shader_parameter(&"thickness", 0.0016)
	into.append(aura)
	return aura


func _geometry(label: String, mesh: Mesh, look: Material, parent: Node3D) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = label
	part.mesh = mesh
	part.set_surface_override_material(0, look)
	part.layers = Layers.FX
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(part)
	return part
