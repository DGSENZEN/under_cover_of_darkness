extends Node3D
## Occult metaphysics' projection (docs/superpowers/specs/2026-10-17-librarian-shop-design.md: "nested geometric
## sigils, an eye opening, planes folding"), in violet: over an opened metaphysics study, three sigils nested one
## within another (a hexagram in its circle, a square, a triangle), each at its own depth, turning against each
## other; at their heart an eye in a black almond that opens slowly, looks about with its slit pupil and closes again;
## and over the left-hand page five black planes edged in violet fire folding up from a flat cross into an open box
## and lying flat again, the front of each carrying a grid of light a little apart from it, its back bare.
## Glowing lines on our own meshes (vfx_mesh.gdshader); the shapes black with a burning rim (anima_silhouette,
## anima_aura), as the other families are. Upright in the room, scaled to the room above the pages.

const MeshVfx := preload("res://scripts/Visual/MeshVfx.gd")
const Layers := preload("res://scripts/Visual/Layers.gd")
const Alchemy := preload("res://scripts/Visual/Library/Alchemy.gd")
const SILHOUETTE := preload("res://scripts/Visual/anima_silhouette.gdshader")
const AURA := preload("res://scripts/Visual/anima_aura.gdshader")

const CORE := Color(0.96, 0.92, 1.0)
const VIOLET := Color("a486ed")
const EDGE := Color(0.14, 0.05, 0.3)
## The room it is built for above the pages (m); where its pieces stand (from the right-hand page's middle: the gutter
## 0.13 m to its left, the left-hand page beyond).
const ROOM := 0.33
const HEART := Vector3(0.0, 0.17, 0.0)
## The sigils: each its radius, its depth (back to front) and how fast it turns (rad/s).
const SIGIL_RADII := [0.085, 0.06, 0.04]
const SIGIL_DEPTHS := [-0.014, 0.0, 0.014]
const SIGIL_TURNS := [0.22, -0.38, 0.6]
## The eye: half its width and height, how long it takes to open, look about and shut.
const EYE := Vector2(0.042, 0.02)
const EYE_CYCLE := 6.5
## The planes: where they lie (over the left-hand page), each plane's side, how long they take to fold and unfold.
## (Lifted clear of the left-hand page's fanning leaves.)
const PLANES_AT := Vector3(-0.26, 0.06, 0.0)
const PLANE := 0.075
const FOLD_CYCLE := 7.5

var kind := &"metaphysics"
var sigils: Array[MeshInstance3D] = []
var eye: Node3D
## How open the eye is (0 shut, 1 wide).
var eye_open := 0.0
## The planes' hinges; how far they have folded (0 a flat cross, 1 an open box).
var folds: Array[Node3D] = []
var fold := 0.0

var _seed := 0.0
var _looks: Array[ShaderMaterial] = []
var _inks: Array[ShaderMaterial] = []
var _lens: Node3D
var _iris: Node3D
var _planes: Node3D


func build(seed: float) -> void:
	_seed = seed
	name = "metaphysics"
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	visible = false

	var line := _look(seed)
	for k in SIGIL_RADII.size():
		var sigil := _geometry("sigil_%d" % k, _sigil(k, SIGIL_RADII[k]), line if k != 1 else _look(seed + 1.0), self)
		sigil.position = HEART + Vector3(0.0, 0.0, SIGIL_DEPTHS[k])
		sigils.append(sigil)

	# The eye: a black almond, and in it the white, the iris and the pupil, all of them closing to a line together.
	eye = Node3D.new()
	eye.name = "eye"
	add_child(eye)
	# (In front of every sigil, so their light is behind it and it stands dark against them.)
	eye.position = HEART + Vector3(0.0, 0.0, SIGIL_DEPTHS[2] + 0.02)
	_lens = Node3D.new()
	_lens.name = "lids"
	eye.add_child(_lens)
	var socket := _geometry("almond", _almond(EYE * 1.35, 0.0), _ink(), _lens)
	_geometry("outline", socket.mesh, _aura(), socket).position = Vector3.ZERO
	# (Its white a dim pearl, so the iris and the slit read against it.)
	var white := MeshVfx.look(Color(0.62, 0.56, 0.72), Color(0.42, 0.36, 0.55), EDGE, 0.9, 0.0, 0.2, seed + 2.0)
	white.set_shader_parameter("tail_eat", 0.0)
	_looks.append(white)
	_geometry("white", _almond(EYE, 0.0015), white, _lens)
	_iris = Node3D.new()
	_iris.name = "iris"
	_lens.add_child(_iris)
	var iris := MeshVfx.look(VIOLET.lerp(CORE, 0.6), VIOLET, EDGE, 3.0, 0.0, 0.6, seed + 3.0)
	iris.set_shader_parameter("tail_eat", 0.0)
	_looks.append(iris)
	_geometry("iris", _disc(0.015, 0.003), iris, _iris)
	var pupil := StandardMaterial3D.new()
	pupil.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pupil.albedo_color = Color(0.01, 0.0, 0.02)
	_geometry("pupil", _almond(Vector2(0.0038, 0.0125), 0.0042), pupil, _iris)

	# The planes: one lying flat, four hinged at its edges.
	_planes = Node3D.new()
	_planes.name = "planes"
	add_child(_planes)
	_planes.position = PLANES_AT
	_plane(_planes, Transform3D.IDENTITY)
	for side in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
		var hinge := Node3D.new()
		hinge.name = "hinge"
		_planes.add_child(hinge)
		hinge.position = side * PLANE * 0.5
		hinge.set_meta("side", side)
		_plane(hinge, Transform3D(Basis(), side * PLANE * 0.5))
		folds.append(hinge)


## Where it stands (the pages' top middle, the book's heading), how present (0 gone to 1), the room above it.
func set_state(presence: float, clearance: float, time: float, at: Vector3, heading: float) -> void:
	visible = presence > 0.001
	if not visible:
		return
	var fit := clampf(clearance / ROOM, 0.4, 1.0) * lerpf(0.7, 1.0, presence)
	global_transform = Transform3D(Basis(Vector3.UP, heading).scaled(Vector3.ONE * fit), at)
	for look in _looks:
		look.set_shader_parameter("opacity", presence)
		look.set_shader_parameter("erosion", lerpf(0.95, float(look.get_meta("erosion", 0.0)), presence))
	for look in _inks:
		look.set_shader_parameter("presence", presence)

	for k in sigils.size():
		sigils[k].rotation = Vector3(0.0, 0.0, time * SIGIL_TURNS[k] + _seed * (k + 1))

	# The eye: shut a while, opening slowly, wide and looking about, shutting quickly.
	var t := fposmod(time / EYE_CYCLE + _seed * 0.1, 1.0)
	eye_open = smoothstep(0.18, 0.4, t) * (1.0 - smoothstep(0.86, 0.94, t))
	_lens.scale = Vector3(1.0, maxf(0.04, eye_open), 1.0)
	_iris.position = Vector3(0.016 * sin(time * 1.3 + _seed), 0.005 * sin(time * 0.9), 0.0) * eye_open

	# The planes fold up into a box and lie flat again, the whole turning slowly so their depth shows.
	fold = 0.5 - 0.5 * cos(time * TAU / FOLD_CYCLE + _seed)
	_planes.rotation = Vector3(0.0, time * 0.25 + _seed, 0.0)
	for hinge in folds:
		var side: Vector3 = hinge.get_meta("side")
		var up := PI / 2.0 * fold
		if side.x != 0.0:
			hinge.rotation = Vector3(0.0, 0.0, up * side.x)
		else:
			hinge.rotation = Vector3(-up * side.z, 0.0, 0.0)


## Every piece it draws.
func parts() -> Array:
	return find_children("*", "GeometryInstance3D", true, false)


## A plane under `parent` at `where` (its middle): a black slab edged in violet fire, its front (up while it lies
## flat) carrying a grid of light 2 mm apart from it, its back bare.
func _plane(parent: Node3D, where: Transform3D) -> void:
	var slab := BoxMesh.new()
	slab.size = Vector3(PLANE * 0.96, 0.002, PLANE * 0.96)
	var body := _geometry("plane", slab, _ink(), parent)
	body.transform = where
	_geometry("outline", slab, _aura(), body).position = Vector3.ZERO
	var grid := _geometry("grid", _grid(PLANE * 0.84), _looks[0], body)
	grid.position = Vector3(0.0, 0.003, 0.0)


func _look(seed: float) -> ShaderMaterial:
	# (Violet to their core and not too bright: brighter, with the page's light, they bloomed into a white ball.)
	var look := MeshVfx.look(VIOLET.lerp(CORE, 0.35), VIOLET, EDGE, 1.25, 0.0, 0.5, seed)
	look.set_shader_parameter("tail_eat", 0.0)
	look.set_meta("erosion", 0.0)
	_looks.append(look)
	return look


func _ink() -> ShaderMaterial:
	var ink := ShaderMaterial.new()
	ink.shader = SILHOUETTE
	ink.set_shader_parameter(&"glow", VIOLET.lerp(CORE, 0.3))
	ink.set_shader_parameter(&"noise", MeshVfx.noise())
	ink.set_shader_parameter(&"seed", _seed + _inks.size())
	ink.set_shader_parameter(&"floor_y", -1.0)
	ink.set_shader_parameter(&"wrist", 0.0001)
	ink.set_shader_parameter(&"rim_power", 2.6)
	_inks.append(ink)
	return ink


func _aura() -> ShaderMaterial:
	var aura := ShaderMaterial.new()
	aura.shader = AURA
	aura.set_shader_parameter(&"glow", VIOLET)
	aura.set_shader_parameter(&"noise", MeshVfx.noise())
	aura.set_shader_parameter(&"seed", _seed + _inks.size())
	aura.set_shader_parameter(&"floor_y", -1.0)
	aura.set_shader_parameter(&"wrist", 0.0001)
	aura.set_shader_parameter(&"thickness", 0.0014)
	_inks.append(aura)
	return aura


## One of the nested sigils, standing in its own plane (facing +z), `radius` across: the outer a hexagram in its
## circle, the middle a square in its circle, the inner a triangle.
static func _sigil(k: int, radius: float) -> ArrayMesh:
	var strokes := []
	match k:
		0:
			strokes = [Alchemy._ring(radius), _polygon(3, radius * 0.94, PI / 2.0), _polygon(3, radius * 0.94, -PI / 2.0)]
		1:
			strokes = [Alchemy._ring(radius), _polygon(4, radius * 0.97, PI / 4.0)]
		_:
			strokes = [_polygon(3, radius, PI / 2.0), Alchemy._ring(radius * 0.5)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for path: PackedVector3Array in strokes:
		st.append_from(Alchemy._bar(path, 0.0026), 0, Transform3D.IDENTITY)
	return st.commit()


## A plane's grid of light, lying flat (facing +y), `size` across: three by three, a circle within.
static func _grid(size: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var flat := Basis(Vector3.RIGHT, -PI / 2.0)
	var strokes := [Alchemy._ring(size * 0.32)]
	for i in 4:
		var x := lerpf(-0.5, 0.5, float(i) / 3.0) * size
		strokes.append(Alchemy._line(Vector2(x, -size * 0.5), Vector2(x, size * 0.5)))
		strokes.append(Alchemy._line(Vector2(-size * 0.5, x), Vector2(size * 0.5, x)))
	for path: PackedVector3Array in strokes:
		st.append_from(Alchemy._bar(path, 0.0013), 0, Transform3D(flat, Vector3.ZERO))
	return st.commit()


## A regular polygon's outline, `sides`, `radius` to its corners, its first corner at angle `turn`.
static func _polygon(sides: int, radius: float, turn: float) -> PackedVector3Array:
	var path := PackedVector3Array()
	for i in sides + 1:
		var a := turn + TAU * float(i) / sides
		path.append(Vector3(cos(a), sin(a), 0.0) * radius)
	return path


## An almond (an eye's opening) facing +z, `half` its half-width and half-height, `z` its depth, how `pointed` its
## corners (0 an ellipse); a flat fan.
static func _almond(half: Vector2, z: float, pointed := 0.35) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rim := []
	var steps := 24
	for i in steps:
		var a := TAU * float(i) / steps
		# (Pointed at its corners: the height shaped by a power of the cosine across it.)
		var x := cos(a) * half.x
		var y := sin(a) * half.y * pow(1.0 - absf(cos(a)), pointed)
		rim.append(Vector3(x, y, z))
	for i in steps:
		var j := (i + 1) % steps
		st.set_uv(Vector2(0.5, 0.0))
		st.add_vertex(Vector3(0.0, 0.0, z))
		st.set_uv(Vector2(float(i) / steps, 1.0))
		st.add_vertex(rim[i])
		st.set_uv(Vector2(float(j) / steps, 1.0))
		st.add_vertex(rim[j])
	st.generate_normals()
	return st.commit()


## A disc facing +z, `radius` across, at depth `z`.
static func _disc(radius: float, z: float) -> ArrayMesh:
	return _almond(Vector2(radius, radius), z, 0.0)


func _geometry(label: String, mesh: Mesh, look: Material, parent: Node3D) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = label
	part.mesh = mesh
	part.set_surface_override_material(0, look)
	part.layers = Layers.FX
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(part)
	return part
