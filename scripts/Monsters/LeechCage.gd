extends Node3D
## The mouth has you: you are in its chest, looking out between its ribs. They come from behind you, past your face,
## their points stopping short of the middle of your view; they beat with its gulps, and open wide winding up. What
## it is made of is under you and over you, and those it has had stare in at you from every side. What it takes from
## you goes down into its throat, under you. Drawn as the viewmodel is, a child of LeechHands.gd. Only your death
## shuts it. The first whip breaks them, and they stay broken while it has you.

const MODEL := "res://assets/monsters/anima_mouth.glb"
const BROKEN_MODEL := "res://assets/monsters/anima_mouth_ribs_broken.glb"
const SHEATH_MODEL := "res://assets/monsters/mouth_sheath.glb"
const FleshShader := preload("res://scripts/Monsters/anima_flesh.gdshader")
const LightShader := preload("res://scripts/Monsters/mouth_light.gdshader")
const BRUSH := preload("res://textures/painted/eclipse/brush.png")

## Where the ribs swing from, behind your head, as you look (m). How far they stand swung: at rest, winding up, on a
## gulp, broken, as you die (rad); how far off they start, in from out of your sight.
const HINGE := Vector3(0.0, 0.02, 0.36)
## (Packed closer and further off than it stands in the world, so they read as a cage, not as stakes.)
const RIBS_SIZE := Vector3(1.3, 0.72, 1.3)
## Each side stands this far off the middle of you, or their points would meet there; as you die it comes in.
const RIBS_APART := 0.38
const REST := 0.05
const WIND := 0.13
const TIGHT := 0.0
const BROKEN_WIDER := 0.04
const SHUT := -0.06
const COMES_FROM := 1.0
## How it comes at you with a gulp, and draws back (m).
const COMES_AT := 0.05
const DRAWS_BACK := 0.04
## What it is made of: under you, tipped up so you look down its throat; over you, hanging. Where its throat is on that.
const UNDER_AT := Vector3(0.0, -0.44, -1.08)
const UNDER_TILT := 1.95
const UNDER_SIZE := 0.8
const OVER_AT := Vector3(0.05, 0.98, -1.05)
const OVER_TILT := -1.9
const THROAT_ON_MASS := Vector3(0.0, 0.55, -0.1)
## (It is under you: what goes down it goes off the bottom of your view.)
const THROAT_LOWEST := 0.92
## Those staring in at you: where, which way up. The hands gripping on over your head.
const FACES: Array[Vector4] = [
	Vector4(-0.6, 0.05, -0.74, 0.3), Vector4(0.62, 0.15, -0.78, -0.45),
	Vector4(0.22, 0.47, -0.84, 2.9), Vector4(-0.44, 0.47, -0.82, 0.6),
]
## And those the elite has taken, in the room there is.
const MORE_FACES: Array[Vector4] = [Vector4(-0.72, -0.26, -0.88, -0.4), Vector4(0.74, -0.3, -0.9, 0.5), Vector4(0.64, 0.54, -0.98, 0.2)]
const FACE_SIZE := 1.0
const HANDS: Array[Vector3] = [Vector3(-0.72, 0.34, -0.82), Vector3(0.8, 0.3, -0.86)]
const HAND_SIZE := 0.62
const FACE_HINGE := Vector3(0.0, -0.043, -0.042)
const FACE_EYE := Vector3(0.044, 0.005, -0.088)
const JAW_DROPS := 0.85

## How many of those it took are looking at you.
var more_faces := 0
var _ribs_left: MeshInstance3D
var _ribs_right: MeshInstance3D
var _whole: Array[Mesh] = []
var _broken: Array[Mesh] = []
var _under: MeshInstance3D
var _gullet: MeshInstance3D
var _over: MeshInstance3D
var _faces: Array[Node3D] = []
var _jaws: Array[MeshInstance3D] = []
var _hands: Array[MeshInstance3D] = []
var _body := Node3D.new()
var _fov := 58.0
var _layer := 1
var _swing := COMES_FROM
var _swing_speed := 0.0
var _closed := 0.0
var _cracked := false
var _breaks := 0.0
var _clock := 0.0
var _points: Dictionary = {}


func _init(layer: int, z_clip: float, fov: float) -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_layer = layer
	_fov = fov
	add_child(_body)
	var flesh := _look(z_clip, fov, 1.0)
	var bone := _look(z_clip, fov, 0.6)
	var made: Node3D = (load(MODEL) as PackedScene).instantiate()
	var left_mesh: Mesh = (made.find_child("RibsLeft", true, false) as MeshInstance3D).mesh
	var right_mesh: Mesh = (made.find_child("RibsRight", true, false) as MeshInstance3D).mesh
	var mass_mesh: Mesh = (made.find_child("Mass", true, false) as MeshInstance3D).mesh
	var gullet_mesh: Mesh = (made.find_child("Gullet", true, false) as MeshInstance3D).mesh
	made.free()
	var broke: Node3D = (load(BROKEN_MODEL) as PackedScene).instantiate()
	_whole = [left_mesh, right_mesh]
	_broken = [(broke.find_child("RibsLeft", true, false) as MeshInstance3D).mesh, (broke.find_child("RibsRight", true, false) as MeshInstance3D).mesh]
	broke.free()
	_ribs_left = _piece(left_mesh, bone)
	_ribs_right = _piece(right_mesh, bone)
	_under = _piece(mass_mesh, flesh)
	_gullet = _piece(gullet_mesh, flesh)
	_over = _piece(mass_mesh, flesh)
	var sheath: Node3D = (load(SHEATH_MODEL) as PackedScene).instantiate()
	var skull_mesh: Mesh = (sheath.find_child("SkinSkull", true, false) as MeshInstance3D).mesh
	var jaw_mesh: Mesh = (sheath.find_child("SkinJaw", true, false) as MeshInstance3D).mesh
	var hand_mesh: Mesh = (sheath.find_child("SkinHand", true, false) as MeshInstance3D).mesh
	sheath.free()
	var light := ShaderMaterial.new()
	light.shader = LightShader
	light.set_shader_parameter(&"z_clip", z_clip)
	light.set_shader_parameter(&"fov_override", fov)

	for at in FACES + MORE_FACES:
		var root := Node3D.new()
		_body.add_child(root)
		_piece(skull_mesh, flesh, root)
		var jaw := _piece(jaw_mesh, flesh, root)
		jaw.position = FACE_HINGE

		for side in [-1.0, 1.0]:
			var eye := MeshInstance3D.new()
			var ball := SphereMesh.new()
			ball.radial_segments = 12
			ball.rings = 8
			ball.radius = 0.016
			ball.height = 0.032
			eye.mesh = ball
			eye.material_override = light
			eye.layers = _layer
			eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			eye.position = FACE_EYE * Vector3(side, 1.0, 1.0)
			root.add_child(eye)

		_faces.append(root)
		_jaws.append(jaw)

	for at in HANDS:
		_hands.append(_piece(hand_mesh, flesh))


func _look(z_clip: float, fov: float, spectral: float) -> ShaderMaterial:
	var look := ShaderMaterial.new()
	look.shader = FleshShader
	look.set_shader_parameter(&"stroke_sheet", BRUSH)
	look.set_shader_parameter(&"burn_noise", MeshVfx.noise())
	look.set_shader_parameter(&"wet", 0.0)
	# This close you need to see into it.
	look.set_shader_parameter(&"fill", 0.72)
	look.set_shader_parameter(&"rim", 0.14)
	look.set_shader_parameter(&"fill_sky", Color(0.42, 0.42, 0.37))
	look.set_shader_parameter(&"fill_ground", Color(0.42, 0.34, 0.26))
	look.set_shader_parameter(&"rim_colour", Color(0.42, 0.46, 0.34))
	look.set_shader_parameter(&"z_clip", z_clip)
	look.set_shader_parameter(&"fov_override", fov)
	look.set_shader_parameter(&"spectral", spectral)
	return look


func _piece(mesh: Mesh, look: ShaderMaterial, parent: Node3D = null) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	piece.mesh = mesh
	piece.material_override = look
	piece.layers = _layer
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent != null else _body).add_child(piece)
	return piece


## How far they have shut, 0 at their widest, 1 at the worst a living man sees; past that, as he dies.
func closed() -> float:
	return _closed


## How many are staring at you.
func faces_shown() -> int:
	return FACES.size() + more_faces if visible else 0


func cracked_shown() -> bool:
	return visible and _cracked


## How far along it is coming off you: it has let go.
func let_go() -> void:
	visible = false
	_swing = COMES_FROM
	_swing_speed = 0.0
	_cracked = false
	_set_ribs(false)


## Where its throat is on the screen, 0..1.
func mouth_on_screen(aspect: float) -> Vector2:
	var at: Vector3 = _body.transform * (_under.transform * THROAT_ON_MASS)
	var tall := tan(deg_to_rad(_fov) * 0.5) * maxf(-at.z, 0.001)
	var on := Vector2(at.x / (tall * aspect), -at.y / tall) * 0.5 + Vector2(0.5, 0.5)
	return Vector2(on.x, minf(on.y, THROAT_LOWEST))


## Whether all of it, as it stands now, is out of the middle third of your view.
func keeps_clear_of_middle(aspect: float) -> bool:
	return in_the_middle(aspect) == ""


## What of it is in the middle third of your view, if anything.
func in_the_middle(aspect: float) -> String:
	var tall := tan(deg_to_rad(_fov) * 0.5)
	var into := global_transform.affine_inverse()

	for piece in find_children("*", "MeshInstance3D", true, false):
		if not piece.is_visible_in_tree():
			continue

		var points: PackedVector3Array = _points_of(piece.mesh)
		var there: Transform3D = into * piece.global_transform

		for k in range(0, points.size(), 3):
			var at: Vector3 = there * points[k]

			if at.z < -0.03 and absf(at.x / (-at.z * tall * aspect)) < 1.0 / 3.0 and absf(at.y / (-at.z * tall)) < 1.0 / 3.0:
				return "%s %s" % [piece.get_parent().name, piece.name]

	return ""


func _points_of(mesh: Mesh) -> PackedVector3Array:
	if not _points.has(mesh):
		_points[mesh] = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]

	return _points[mesh]


func _set_ribs(broken: bool) -> void:
	_ribs_left.mesh = _broken[0] if broken else _whole[0]
	_ribs_right.mesh = _broken[1] if broken else _whole[1]


## It drinks. `gulp` is 1 as one lands, fading to 0; `coming`, how near the next is; `arrived`, how far in it has come;
## `last`, its last long gulp, as you die: it shuts on you. `cracked`: the first whip has broken its ribs.
func close_in(delta: float, gulp: float, coming: float, arrived: float, last: float, cracked: bool) -> void:
	visible = true
	_clock += delta

	if cracked != _cracked:
		_cracked = cracked
		_set_ribs(cracked)
		_breaks = 1.0 if cracked else 0.0

	_breaks = move_toward(_breaks, 0.0, delta * 2.2)
	var wind := smoothstep(0.5, 1.0, coming) if gulp <= 0.0 else 0.0
	var biting := gulp * gulp
	var wider := BROKEN_WIDER if cracked else 0.0
	var wanted := lerpf(lerpf(REST, WIND, wind), TIGHT, smoothstep(0.1, 0.6, gulp)) + wider
	wanted = lerpf(wanted, SHUT, last) + pow(1.0 - arrived, 2.0) * COMES_FROM + _breaks * 0.14
	var rate := minf(TAU * (6.0 if gulp > 0.3 else 3.2), 0.8 / delta)
	_swing_speed += (rate * rate * (wanted - _swing) - 2.0 * 0.55 * rate * _swing_speed) * delta
	_swing += _swing_speed * delta

	# (However hard it goes, only your death brings them over the middle of your view.)
	if last <= 0.0:
		_swing = maxf(_swing, TIGHT + wider)

	_closed = clampf(1.0 - (_swing - TIGHT) / (WIND - TIGHT), 0.0, 1.0) + maxf(TIGHT - _swing, 0.0) * 4.0
	var shake := sin(_clock * 41.0) * _breaks * 0.03
	_ribs_left.basis = Basis.from_euler(Vector3(0.0, _swing + shake, sin(_clock * 3.1) * 0.012 + (0.05 if cracked else 0.0))).scaled(RIBS_SIZE)
	_ribs_right.basis = Basis.from_euler(Vector3(0.0, -_swing - shake * 0.7, -sin(_clock * 2.7) * 0.012 - (0.09 if cracked else 0.0))).scaled(RIBS_SIZE)
	var apart := RIBS_APART * (1.0 - last)
	_ribs_left.position = HINGE + Vector3(-apart, 0.0, 0.0)
	_ribs_right.position = HINGE + Vector3(apart, 0.0, 0.0)
	var hunger := 0.12 + biting * 0.6 + last * 0.5
	# Your view is no wider or narrower to it than to anything else.
	var view := get_viewport().get_visible_rect().size
	_body.scale = Vector3(view.x / maxf(view.y, 1.0) / (16.0 / 9.0), 1.0, 1.0)
	_body.position = Vector3(sin(_clock * 2.3) * 0.006, sin(_clock * 1.7) * 0.006, biting * COMES_AT - wind * DRAWS_BACK + last * 0.1)
	var rises := biting * 0.05 - wind * 0.03 + last * 0.22 + pow(1.0 - arrived, 2.0) * -0.5
	var low := Basis(Vector3.RIGHT, UNDER_TILT + wind * 0.08).scaled(Vector3.ONE * UNDER_SIZE)
	_under.transform = Transform3D(low, UNDER_AT + Vector3(0.0, rises, 0.0))
	_gullet.transform = _under.transform
	_over.transform = Transform3D(Basis(Vector3.RIGHT, OVER_TILT), OVER_AT + Vector3(0.0, -rises - last * 0.3, 0.0))

	for i in _faces.size():
		_faces[i].visible = i < FACES.size() + more_faces

		if not _faces[i].visible:
			continue

		var spot: Vector4 = FACES[i] if i < FACES.size() else MORE_FACES[i - FACES.size()]
		var seed := float(i) * 2.3
		var at := Vector3(spot.x, spot.y, spot.z)
		# Each a beat behind the last, pressing in as it swallows, its jaw going wide before.
		var own_wind := smoothstep(0.5 - float(i) * 0.05, 1.0, coming) if gulp <= 0.0 else 0.0
		var pressing := biting * 0.07 - own_wind * 0.05 + sin(_clock * (1.6 + float(i) * 0.4) + seed) * 0.012
		var toward := -(at.normalized())
		var there := at + toward * (pressing + last * 0.35) - at.normalized() * -pow(1.0 - arrived, 2.0) * 0.7
		_faces[i].transform = Transform3D(Basis.looking_at(toward, Vector3.UP).rotated(toward, spot.w + sin(_clock * 1.1 + seed) * 0.08).scaled(Vector3.ONE * FACE_SIZE), there)
		_jaws[i].rotation.x = -JAW_DROPS * clampf(0.3 + own_wind * 0.7 + sin(_clock * (5.0 + float(i)) + seed) * 0.12 - biting * 0.5 + last, 0.0, 1.0)

	for i in _hands.size():
		var at: Vector3 = HANDS[i]
		var side := signf(at.x)
		var flat := Basis(Vector3.UP, -side * 2.1) * Basis(Vector3.RIGHT, 0.8)
		_hands[i].transform = Transform3D(flat.scaled(Vector3.ONE * HAND_SIZE), at + Vector3(side * pow(1.0 - arrived, 2.0) * 0.5, sin(_clock * 2.0 + float(i)) * 0.01 - biting * 0.03, 0.0))

	for piece in find_children("*", "MeshInstance3D", true, false):
		if piece.material_override is ShaderMaterial and piece.material_override.shader == FleshShader:
			piece.set_instance_shader_parameter(&"hunger", hunger)
