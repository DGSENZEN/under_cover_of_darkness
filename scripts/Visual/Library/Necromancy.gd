extends Node3D
## Necromancy's projection (docs/superpowers/specs/2026-10-17-librarian-shop-design.md: "a skeletal hand, a skull
## rising in green spirit-fire, the dead's faces in smoke"), drawn as Graves' Deadheads are and as the ánimas already
## are (docs/superpowers/refs/underground/vfx_method.md): every shape Mignola's black, wrapped in a chartreuse rim
## and an outline of burning spirit-fire (anima_silhouette, anima_aura). Over an opened necromancy study: a skull
## rising out of a crown of spirit-fire at the gutter, its eyes, nose and teeth aglow, its jaw working; a skeletal
## hand reaching up out of the right-hand page, burning out of the paper at its forearm, its fingers curling and
## opening; and the dead's faces, small skulls, carried up out of the left-hand page on columns of smoke and eaten
## away as they go, then rising again. Upright in the room, scaled to the room above the pages.

const MeshVfx := preload("res://scripts/Visual/MeshVfx.gd")
const Layers := preload("res://scripts/Visual/Layers.gd")
const SILHOUETTE := preload("res://scripts/Visual/anima_silhouette.gdshader")
const AURA := preload("res://scripts/Visual/anima_aura.gdshader")

const CORE := Color("e6ff96")
const BODY := Color("b2ea3a")
const EDGE := Color("2a480b")
const RIM := Color("c8ff52")
## The room it is built for above the pages (m); where its pieces stand (from the right-hand page's middle: the gutter
## 0.13 m to its left, the left-hand page beyond).
const ROOM := 0.33
const GUTTER := Vector3(-0.13, 0.0, 0.0)
const SKULL_AT := Vector3(-0.13, 0.12, 0.0)
const HAND_AT := Vector3(0.05, 0.0, 0.01)
const FACES_FROM := [Vector3(-0.27, 0.0, -0.05), Vector3(-0.23, 0.0, 0.06), Vector3(-0.31, 0.0, 0.02)]
## The faces: how long one takes to climb, how high.
const FACE_CLIMB := 4.6
const FACE_RISE := 0.22
const FACE_SCALE := 0.55
## How long the hand takes to close and open; how far each finger joint bends closed (rad).
const GRASP := 3.4
const BENDS := [0.95, 1.2, 0.85]
## The hand at life size from the base body's left hand (metres): the forearm shown, the knuckles from the wrist
## (index to little finger, across from the thumb's side, up), each finger's phalanges, the thumb's three bones and
## their heading (toward the palm); drawn at HAND_SCALE.
const HAND_SCALE := 0.8
const FOREARM := 0.1
const KNUCKLES := [Vector3(-0.036, 0.088, 0.0), Vector3(-0.011, 0.087, 0.0), Vector3(0.0135, 0.08, 0.0),
	Vector3(0.0335, 0.069, 0.0)]
const PHALANGES := [[0.0317, 0.0271, 0.0235], [0.0364, 0.0293, 0.0296], [0.035, 0.0276, 0.0283], [0.0308, 0.0266, 0.0209]]
const THUMB := [0.0358, 0.0356, 0.0313]
const THUMB_TOWARD := Vector3(-0.0131, 0.0285, 0.0173)
## Below its own shapes: where a silhouette burns away (nothing of the skull or the bones does).
const NEVER := -1.0

var kind := &"necromancy"
var skull: Node3D
var jaw: MeshInstance3D
var fire: MeshInstance3D
var bones: Array[MeshInstance3D] = []
var faces: Array[Node3D] = []
var face_heights: Array[float] = []
## How closed the hand is (0 open, 1 a fist).
var curl := 0.0

var _seed := 0.0
var _hand: Node3D
var _fingers: Array = []
var _inks: Array[ShaderMaterial] = []
var _auras: Array[ShaderMaterial] = []
var _glows: Array[ShaderMaterial] = []
var _fire_look: ShaderMaterial
var _smokes: Array[ShaderMaterial] = []
var _face_inks: Array = []


func build(seed: float) -> void:
	_seed = seed
	name = "necromancy"
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	visible = false

	_fire_look = MeshVfx.look(CORE, BODY, EDGE, 3.4, 0.16, 1.7, seed + 9.0)
	fire = _geometry("fire", MeshVfx.tongues(11, 0.14, 0.017, 0.06, 0.45, int(seed * 10.0)), _fire_look, self)
	fire.position = GUTTER

	skull = Node3D.new()
	skull.name = "skull"
	add_child(skull)
	skull.position = SKULL_AT
	jaw = _skull(skull, _inks, _auras, _glows)

	_hand = Node3D.new()
	_hand.name = "hand"
	add_child(_hand)
	_hand.position = HAND_AT
	_build_hand()

	for k in FACES_FROM.size():
		var column := Node3D.new()
		column.name = "dead_%d" % k
		add_child(column)
		column.position = FACES_FROM[k]
		var smoke := MeshVfx.look(Color(0.78, 0.86, 0.7), Color(0.42, 0.52, 0.4), Color(0.1, 0.14, 0.1), 1.2, 0.3, 0.9,
			seed + 20.0 + k)
		smoke.set_shader_parameter("tail_eat", 0.7)
		_smokes.append(smoke)
		var path := PackedVector3Array()
		for j in 9:
			var t := float(j) / 8.0
			path.append(Vector3(sin(t * 4.0 + k) * 0.012, t * (FACE_RISE + 0.04), cos(t * 3.0 + k) * 0.01))
		_geometry("smoke", MeshVfx.plume(path, 0.004, 0.022, 8), smoke, column)
		var face := Node3D.new()
		face.name = "face"
		column.add_child(face)
		face.scale = Vector3.ONE * FACE_SCALE
		var inks: Array[ShaderMaterial] = []
		_skull(face, inks, inks, inks, true)
		_face_inks.append(inks)
		faces.append(face)
		face_heights.append(0.0)


## Where it stands (the pages' top middle, the book's heading), how present (0 gone to 1), the room above it.
func set_state(presence: float, clearance: float, time: float, at: Vector3, heading: float) -> void:
	visible = presence > 0.001
	if not visible:
		return
	var fit := clampf(clearance / ROOM, 0.4, 1.0) * lerpf(0.7, 1.0, presence)
	global_transform = Transform3D(Basis(Vector3.UP, heading).scaled(Vector3.ONE * fit), at)

	_fire_look.set_shader_parameter("opacity", presence)
	_fire_look.set_shader_parameter("erosion", lerpf(0.95, 0.16, presence))
	for look in _inks + _auras:
		look.set_shader_parameter("presence", presence)
	for look in _glows:
		look.set_shader_parameter("opacity", presence)
	for look in _smokes:
		look.set_shader_parameter("opacity", presence * 0.8)

	# The skull hangs in its fire, bobbing, looking about; its jaw chatters in bursts.
	skull.position = SKULL_AT + Vector3(0.0, 0.01 * sin(time * 1.3 + _seed), 0.0)
	skull.rotation = Vector3(0.12 * sin(time * 0.7), 0.6 * sin(time * 0.45 + _seed), 0.0)
	var chatter := smoothstep(0.2, 0.5, sin(time * 0.9 + _seed))
	jaw.rotation.x = 0.32 * chatter * maxf(0.0, sin(time * 11.0))

	# The hand reaches and grasps, each finger a little after the last.
	_hand.rotation = Vector3(0.18 * sin(time * 0.6 + _seed), 0.25 * sin(time * 0.4), 0.08 * sin(time * 0.9))
	curl = 0.5 - 0.5 * cos(time * TAU / GRASP + _seed)
	for f in _fingers.size():
		var late := 0.5 - 0.5 * cos((time - f * 0.12) * TAU / GRASP + _seed)
		var joints: Array = _fingers[f]
		for j in joints.size():
			(joints[j] as Node3D).rotation.x = late * BENDS[mini(j, BENDS.size() - 1)] * (0.6 if f == 4 else 1.0)

	# The dead climb their smoke, come into being at its foot and are eaten away near its top.
	for k in faces.size():
		var t := fposmod(time / FACE_CLIMB + float(k) / faces.size() + _seed * 0.13, 1.0)
		face_heights[k] = t * FACE_RISE
		faces[k].position = Vector3(0.0, 0.03 + face_heights[k], 0.0)
		faces[k].rotation = Vector3(0.0, 0.5 * sin(time * 0.6 + k), 0.15 * sin(time * 1.1 + k))
		var here := sin(t * PI) * presence
		for look: ShaderMaterial in _face_inks[k]:
			look.set_shader_parameter("presence", clampf(here * 1.4, 0.0, 1.0))
			look.set_shader_parameter("opacity", clampf(here * 1.4, 0.0, 1.0))


## Every piece it draws.
func parts() -> Array:
	return find_children("*", "GeometryInstance3D", true, false)


# The skull

## A skull under `parent`, its middle at the parent's origin, looking +z: CDmir's CC0 skull
## (tools/eclipse/library_spectres.py), its jaw hinged under it; black, rimmed and outlined in spirit-fire; its eyes
## two points of spirit-fire in their sockets. `lite` for the small faces in the smoke. Returns the jaw.
func _skull(parent: Node3D, inks: Array[ShaderMaterial], auras: Array[ShaderMaterial], glows: Array[ShaderMaterial],
		lite := false) -> MeshInstance3D:
	var kit := _spectres()
	var ink := _ink(NEVER, inks)
	var aura := _aura(NEVER, 0.0016 if lite else 0.0022, auras)
	var suffix := "_lite" if lite else ""
	_bone_part("cranium", kit["necro_skull" + suffix], ink, aura, parent)
	var hinge := Node3D.new()
	hinge.name = "hinge"
	parent.add_child(hinge)
	hinge.position = _points().get("jaw_hinge", Vector3.ZERO)
	var mandible := _bone_part("jaw", kit["necro_jaw" + suffix], ink, aura, hinge)

	var glow := MeshVfx.look(CORE, BODY, EDGE, 4.2, 0.0, 0.0, _seed + 3.0)
	glow.set_shader_parameter("tail_eat", 0.0)
	glows.append(glow)
	for at: Vector3 in _points().get("eyes", []):
		var eye := SphereMesh.new()
		eye.radius = 0.0042
		eye.height = 0.0072
		eye.radial_segments = 10
		eye.rings = 5
		_geometry("eye", eye, glow, parent).position = at
	return mandible


const SPECTRES := "res://assets/eclipse/kit/library_spectres.glb"
const SPECTRE_POINTS := "res://assets/eclipse/source/library_spectres.json"
static var _kit_meshes := {}
static var _kit_points := {}


## The spectres' meshes by name (loaded once).
static func _spectres() -> Dictionary:
	if _kit_meshes.is_empty() and ResourceLoader.exists(SPECTRES):
		var scene: Node = (load(SPECTRES) as PackedScene).instantiate()
		for mesh: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
			_kit_meshes[String(mesh.name)] = mesh.mesh
		scene.free()
	return _kit_meshes


## The jaw's hinge and the eye sockets, in the skull's frame (Godot's axes).
static func _points() -> Dictionary:
	if _kit_points.is_empty() and FileAccess.file_exists(SPECTRE_POINTS):
		var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SPECTRE_POINTS))
		var hinge: Array = raw["jaw_hinge"]
		_kit_points["jaw_hinge"] = Vector3(hinge[0], hinge[1], hinge[2])
		_kit_points["eyes"] = (raw["eyes"] as Array).map(func(e): return Vector3(e[0], e[1], e[2]))
	return _kit_points


# The hand

## The hand's bones on a real hand's proportions (Quaternius's CC0 base body, the left hand's armature, at HAND_SCALE),
## its forearm burning out of the page: radius and ulna; the wrist's small bones; four metacarpals from the wrist to
## the knuckles; three phalanges a finger; the thumb's metacarpal and two phalanges, from the wrist's side toward
## the palm. Up +y the fingers, across x from the thumb's side, its palm toward +z.
func _build_hand() -> void:
	var ink := _ink(NEVER, _inks)
	var aura := _aura(NEVER, 0.0018, _auras)
	var forearm_ink := _ink(0.0, _inks, 0.035)
	var forearm_aura := _aura(0.0, 0.0018, _auras, 0.035)
	var s := HAND_SCALE
	for x in [-0.009, 0.009]:
		var arm := _bone_part("forearm", _bone(FOREARM * s, 0.0042 * s, 0.0062 * s), forearm_ink, forearm_aura, _hand)
		arm.position = Vector3(x * s, 0.0, 0.0)
		arm.rotation.z = -x * 0.25
	var wrist := FOREARM * s
	for x in [-0.011, 0.0, 0.011]:
		var knob := SphereMesh.new()
		knob.radius = 0.0068 * s
		knob.height = 0.011 * s
		knob.radial_segments = 8
		knob.rings = 4
		_bone_part("carpal", knob, ink, aura, _hand).position = Vector3(x * s, wrist + 0.008 * s, 0.0)

	for f in 4:
		var knuckle: Vector3 = KNUCKLES[f] * s + Vector3(0.0, wrist, 0.0)
		var root := Vector3(knuckle.x * 0.35, wrist + 0.016 * s, 0.0)
		var metacarpal := _bone_part("metacarpal", _bone(root.distance_to(knuckle), 0.0046 * s, 0.0074 * s), ink, aura, _hand)
		metacarpal.position = root
		metacarpal.basis = _along(knuckle - root)
		var joints := []
		var parent: Node3D = _hand
		var at := knuckle
		for j in 3:
			var joint := Node3D.new()
			joint.name = "joint"
			parent.add_child(joint)
			joint.position = at
			# (The fingers splay a little from the middle.)
			joint.rotation.z = -KNUCKLES[f].x * 1.4 if j == 0 else 0.0
			var length: float = PHALANGES[f][j] * s
			_bone_part("phalanx", _bone(length, (0.0042 - j * 0.0005) * s, (0.0063 - j * 0.0008) * s), ink, aura, joint)
			joints.append(joint)
			parent = joint
			at = Vector3(0.0, length, 0.0)
		_fingers.append(joints)

	# The thumb, from the wrist's side, out and toward the palm.
	var thumb := Node3D.new()
	thumb.name = "thumb"
	_hand.add_child(thumb)
	thumb.position = Vector3(-0.016 * s, wrist + 0.004 * s, 0.004 * s)
	thumb.basis = _along(THUMB_TOWARD)
	var thumb_joints := []
	var parent: Node3D = thumb
	var at := Vector3.ZERO
	for j in 3:
		var length: float = THUMB[j] * s
		var joint := Node3D.new()
		joint.name = "joint"
		parent.add_child(joint)
		joint.position = at
		_bone_part("metacarpal" if j == 0 else "phalanx", _bone(length, (0.0046 - j * 0.0005) * s, (0.0068 - j * 0.0008) * s),
			ink, aura, joint)
		if j > 0:
			thumb_joints.append(joint)
		parent = joint
		at = Vector3(0.0, length, 0.0)
	_fingers.append(thumb_joints)


## A basis turning +y onto `direction`.
static func _along(direction: Vector3) -> Basis:
	var up := direction.normalized()
	var side := up.cross(Vector3.BACK)
	if side.length() < 0.01:
		side = up.cross(Vector3.RIGHT)
	side = side.normalized()
	return Basis(side, up, side.cross(up).normalized() * -1.0).orthonormalized()


## A bone lying up +y from its foot: knuckled at both ends, its shaft slimmer between; closed; v along it.
static func _bone(length: float, shaft: float, knuckle: float) -> ArrayMesh:
	var profile := [[0.0, 0.0], [0.02, 0.6], [0.08, 0.95], [0.16, 1.0], [0.28, 0.0], [0.72, 0.0], [0.86, 0.95],
		[0.94, 0.85], [0.99, 0.5], [1.0, 0.0]]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 8
	var rings := []
	for p: Array in profile:
		var r: float = float(p[1]) * knuckle if float(p[1]) > 0.0 or (float(p[0]) > 0.0 and float(p[0]) < 1.0) else 0.0
		if float(p[1]) == 0.0 and float(p[0]) > 0.0 and float(p[0]) < 1.0:
			r = shaft
		var ring := []
		for k in sides + 1:
			var a := TAU * k / sides
			ring.append(Vector3(cos(a) * r, float(p[0]) * length, sin(a) * r * 0.85))
		rings.append(ring)
	for i in rings.size() - 1:
		for k in sides:
			var v0 := float(profile[i][0])
			var v1 := float(profile[i + 1][0])
			MeshVfx._quad(st, [rings[i][k], rings[i + 1][k], rings[i + 1][k + 1], rings[i][k + 1]],
				[Vector2(float(k) / sides, v0), Vector2(float(k) / sides, v1), Vector2(float(k + 1) / sides, v1),
				Vector2(float(k + 1) / sides, v0)])
	st.generate_normals()
	return st.commit()


# Shapes and looks

func _ink(floor_y: float, into: Array[ShaderMaterial], wrist := 0.0001) -> ShaderMaterial:
	var ink := ShaderMaterial.new()
	ink.shader = SILHOUETTE
	ink.set_shader_parameter(&"glow", RIM)
	ink.set_shader_parameter(&"noise", MeshVfx.noise())
	ink.set_shader_parameter(&"seed", _seed + into.size())
	ink.set_shader_parameter(&"floor_y", floor_y)
	ink.set_shader_parameter(&"wrist", wrist)
	ink.set_shader_parameter(&"rim_power", 3.0)
	into.append(ink)
	return ink


func _aura(floor_y: float, thickness: float, into: Array[ShaderMaterial], wrist := 0.0001) -> ShaderMaterial:
	var aura := ShaderMaterial.new()
	aura.shader = AURA
	aura.set_shader_parameter(&"glow", RIM)
	aura.set_shader_parameter(&"noise", MeshVfx.noise())
	aura.set_shader_parameter(&"seed", _seed + into.size())
	aura.set_shader_parameter(&"floor_y", floor_y)
	aura.set_shader_parameter(&"wrist", wrist)
	aura.set_shader_parameter(&"thickness", thickness)
	into.append(aura)
	return aura


## A black piece with its burning outline (the same shape pushed out, drawn behind), counted among the bones.
func _bone_part(label: String, mesh: Mesh, ink: ShaderMaterial, aura: ShaderMaterial, parent: Node3D) -> MeshInstance3D:
	var part := _geometry(label, mesh, ink, parent)
	var outline := _geometry("outline", mesh, aura, part)
	outline.position = Vector3.ZERO
	if label != "cranium" and label != "face" and label != "jaw":
		bones.append(part)
	return part


func _geometry(label: String, mesh: Mesh, look: Material, parent: Node3D) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = label
	part.mesh = mesh
	part.set_surface_override_material(0, look)
	part.layers = Layers.FX
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(part)
	return part
