extends Node3D
## A novel's characters (docs/superpowers/specs/2026-10-17-librarian-shop-design.md: "spectres of its characters, in
## different colours"; stand-ins until a figure passes review: "a Mignola-black silhouette with a coloured rim, or
## their emblem (a mask, a hat, a sword, a rose)"): over an opened novel, its character's emblem rising out of the
## pages, black and rimmed in the novel's own colour, turning slowly as it hangs there, a thread of that colour
## climbing past it. The emblem is the novel's by its place among the novels (a hat, a sword, a rose).

const MeshVfx := preload("res://scripts/Visual/MeshVfx.gd")
const Layers := preload("res://scripts/Visual/Layers.gd")
const SILHOUETTE := preload("res://scripts/Visual/anima_silhouette.gdshader")
const AURA := preload("res://scripts/Visual/anima_aura.gdshader")

const EMBLEMS := [&"hat", &"sword", &"rose"]
## How high the emblem hangs over the pages (m), how far it rises as the book opens.
const HANG := 0.15
## How large the emblem is drawn (its shapes are laid out at a hand's breadth).
const EMBLEM_SCALE := 1.45
const RISE := 0.05
## The room it is built for above the pages.
const ROOM := 0.3

var kind := &"novel"
var emblem := &"hat"
var colour := Color.WHITE
var emblem_node: Node3D

var _seed := 0.0
var _inks: Array[ShaderMaterial] = []
var _thread_look: ShaderMaterial


func build(seed: float, which: int, tint: Color) -> void:
	_seed = seed
	emblem = EMBLEMS[which % EMBLEMS.size()]
	colour = tint
	name = "novel"
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	visible = false

	emblem_node = Node3D.new()
	emblem_node.name = String(emblem)
	add_child(emblem_node)
	match emblem:
		&"hat":
			_shape("hat", _lathe([Vector2(0.0, 0.0), Vector2(0.052, 0.0), Vector2(0.054, 0.004), Vector2(0.03, 0.006),
				Vector2(0.03, 0.012), Vector2(0.028, 0.05), Vector2(0.031, 0.056), Vector2(0.0, 0.058)], 24), emblem_node)
			# (Cocked at an angle, as worn.)
			emblem_node.get_child(0).rotation = Vector3(0.0, 0.0, 0.25)
			emblem_node.get_child(0).position = Vector3(0.0, -0.025, 0.0)
		&"sword":
			var sword := Node3D.new()
			emblem_node.add_child(sword)
			sword.rotation = Vector3(0.0, 0.0, 0.35)
			sword.position = Vector3(0.0, -0.06, 0.0)
			_shape("blade", _blade(0.12, 0.015), sword).position = Vector3(0.0, 0.045, 0.0)
			_shape("cup", _lathe([Vector2(0.0, -0.004), Vector2(0.018, 0.0), Vector2(0.02, 0.008), Vector2(0.0, 0.006)], 16), sword) \
				.position = Vector3(0.0, 0.036, 0.0)
			var guard := BoxMesh.new()
			guard.size = Vector3(0.05, 0.004, 0.006)
			_shape("guard", guard, sword).position = Vector3(0.0, 0.036, 0.0)
			_shape("grip", _lathe([Vector2(0.0, 0.0), Vector2(0.0045, 0.0), Vector2(0.0055, 0.016), Vector2(0.0045, 0.032),
				Vector2(0.0, 0.032)], 10), sword).position = Vector3(0.0, 0.0, 0.0)
			_shape("pommel", _lathe([Vector2(0.0, -0.008), Vector2(0.007, -0.004), Vector2(0.007, 0.002), Vector2(0.0, 0.004)], 12),
				sword).position = Vector3(0.0, -0.004, 0.0)
		_:
			var rose := Node3D.new()
			emblem_node.add_child(rose)
			rose.position = Vector3(0.0, -0.06, 0.0)
			rose.rotation = Vector3(0.0, 0.0, -0.2)
			var stem := PackedVector3Array()
			for i in 9:
				var t := float(i) / 8.0
				stem.append(Vector3(0.006 * sin(t * 3.0), t * 0.09, 0.004 * cos(t * 2.0)))
			_shape("stem", MeshVfx.tendril(stem, 0.0026, 6), rose)
			for side in [-1.0, 1.0]:
				var leaf := _shape("leaf", _leaf(0.026, 0.011), rose)
				leaf.position = Vector3(0.0, 0.035 + side * 0.008, 0.0)
				leaf.rotation = Vector3(0.0, 0.0, side * 0.9)
			# The bloom: three rings of petals, each a cup, opening outward from the bud.
			var bloom := Node3D.new()
			bloom.name = "bloom"
			rose.add_child(bloom)
			bloom.position = Vector3(0.0, 0.09, 0.0)
			bloom.scale = Vector3.ONE * 1.7
			for ring in 3:
				var count := 3 + ring * 2
				for k in count:
					var petal := _shape("petal", _petal(0.012 + ring * 0.004), bloom)
					petal.rotation = Vector3(0.0, TAU * float(k) / count + ring * 0.6, -0.25 - ring * 0.32)

	_thread_look = MeshVfx.look(colour.lerp(Color.WHITE, 0.6), colour, colour.darkened(0.7), 2.0, 0.2, 0.9, seed + 3.0)
	_thread_look.set_shader_parameter("tail_eat", 0.7)
	var path := PackedVector3Array()
	for i in 12:
		var t := float(i) / 11.0
		path.append(Vector3(0.03 * sin(t * 5.0 + seed), t * (HANG + 0.06), 0.03 * cos(t * 4.0 + seed)))
	var thread := MeshInstance3D.new()
	thread.name = "thread"
	thread.mesh = MeshVfx.tendril(path, 0.003, 6)
	thread.set_surface_override_material(0, _thread_look)
	thread.layers = Layers.FX
	thread.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(thread)


## Where it stands (the pages' top middle, the book's heading), how present (0 gone to 1), the room above it.
func set_state(presence: float, clearance: float, time: float, at: Vector3, heading: float) -> void:
	visible = presence > 0.001
	if not visible:
		return
	var fit := clampf(clearance / ROOM, 0.4, 1.0)
	global_transform = Transform3D(Basis(Vector3.UP, heading).scaled(Vector3.ONE * fit), at)
	for look in _inks:
		look.set_shader_parameter("presence", presence)
	_thread_look.set_shader_parameter("opacity", presence * 0.8)
	_thread_look.set_shader_parameter("erosion", lerpf(0.95, 0.2, presence))
	emblem_node.position = Vector3(0.0, HANG - RISE * (1.0 - presence) + 0.008 * sin(time * 1.1 + _seed), 0.0)
	emblem_node.rotation = Vector3(0.12 * sin(time * 0.7), time * 0.5 + _seed, 0.0)
	emblem_node.scale = Vector3.ONE * EMBLEM_SCALE


## Every piece it draws.
func parts() -> Array:
	return find_children("*", "GeometryInstance3D", true, false)


## A black piece rimmed and outlined in the novel's colour.
func _shape(label: String, mesh: Mesh, parent: Node3D) -> MeshInstance3D:
	var ink := ShaderMaterial.new()
	ink.shader = SILHOUETTE
	ink.set_shader_parameter(&"glow", colour.lerp(Color.WHITE, 0.25))
	ink.set_shader_parameter(&"noise", MeshVfx.noise())
	ink.set_shader_parameter(&"seed", _seed + _inks.size())
	ink.set_shader_parameter(&"floor_y", -10.0)
	ink.set_shader_parameter(&"wrist", 0.0001)
	# (A tight rim: on its smooth turned shapes a wide one covered them and they read pale, not black.)
	ink.set_shader_parameter(&"rim_power", 4.5)
	_inks.append(ink)
	var aura := ShaderMaterial.new()
	aura.shader = AURA
	aura.set_shader_parameter(&"glow", colour)
	aura.set_shader_parameter(&"noise", MeshVfx.noise())
	aura.set_shader_parameter(&"seed", _seed + _inks.size())
	aura.set_shader_parameter(&"floor_y", -10.0)
	aura.set_shader_parameter(&"wrist", 0.0001)
	aura.set_shader_parameter(&"thickness", 0.0018)
	_inks.append(aura)
	var part := MeshInstance3D.new()
	part.name = label
	part.mesh = mesh
	part.set_surface_override_material(0, ink)
	part.layers = Layers.FX
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(part)
	var outline := MeshInstance3D.new()
	outline.name = "outline"
	outline.mesh = mesh
	outline.set_surface_override_material(0, aura)
	outline.layers = Layers.FX
	outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	part.add_child(outline)
	return part


## A solid turned about y from `profile` (radius, height), its first and last points on the axis.
static func _lathe(profile: Array, sides: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in profile.size() - 1:
		var a: Vector2 = profile[i]
		var b: Vector2 = profile[i + 1]
		for k in sides:
			var t0 := TAU * float(k) / sides
			var t1 := TAU * float(k + 1) / sides
			MeshVfx._quad(st, [Vector3(cos(t0) * a.x, a.y, sin(t0) * a.x), Vector3(cos(t1) * a.x, a.y, sin(t1) * a.x),
				Vector3(cos(t1) * b.x, b.y, sin(t1) * b.x), Vector3(cos(t0) * b.x, b.y, sin(t0) * b.x)],
				[Vector2(float(k) / sides, float(i) / profile.size()), Vector2(float(k + 1) / sides, float(i) / profile.size()),
				Vector2(float(k + 1) / sides, float(i + 1) / profile.size()), Vector2(float(k) / sides, float(i + 1) / profile.size())])
	st.generate_normals()
	return st.commit()


## A blade up +y from its foot, `length` long, `width` at its foot, diamond in section, narrowing to its point.
static func _blade(length: float, width: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# (Thick through its middle: flat, it turned edge-on to the eye and vanished to a hairline.)
	var foot := [Vector3(width * 0.5, 0.0, 0.0), Vector3(0.0, 0.0, width * 0.42), Vector3(-width * 0.5, 0.0, 0.0),
		Vector3(0.0, 0.0, -width * 0.42)]
	var tip := Vector3(0.0, length, 0.0)
	for k in 4:
		var j := (k + 1) % 4
		MeshVfx._quad(st, [foot[k], tip, tip, foot[j]], [Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0)])
		st.set_uv(Vector2(0.5, 0.0))
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(foot[j])
		st.add_vertex(foot[k])
	st.generate_normals()
	return st.commit()


## A leaf lying in its own plane (facing +z) from its stalk at the origin out along +x, `length` long, `width` wide,
## a little cupped.
static func _leaf(length: float, width: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 8
	for i in steps:
		var rows := []
		for t in [float(i) / steps, float(i + 1) / steps]:
			var half: float = sin(t * PI) * width * 0.5
			rows.append([Vector3(t * length, half, 0.002), Vector3(t * length, 0.0, -0.001), Vector3(t * length, -half, 0.002)])
		for side in 2:
			MeshVfx._quad(st, [rows[0][side], rows[1][side], rows[1][side + 1], rows[0][side + 1]],
				[Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0)])
	st.generate_normals()
	return st.commit()


## A petal: a cup leaning out from the bloom's middle along +x, `size` long.
static func _petal(size: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := 5
	var cols := 4
	var at := func(i: int, k: int) -> Vector3:
		var u := float(i) / rows
		var v := float(k) / cols - 0.5
		var half := sin(minf(u * 1.3, 1.0) * PI * 0.5) * size * 0.55
		return Vector3(u * size, 0.25 * size * v * v * 4.0 * u + u * u * size * 0.25, v * 2.0 * half)
	for i in rows:
		for k in cols:
			MeshVfx._quad(st, [at.call(i, k), at.call(i + 1, k), at.call(i + 1, k + 1), at.call(i, k + 1)],
				[Vector2(float(k) / cols, float(i) / rows), Vector2(float(k) / cols, float(i + 1) / rows),
				Vector2(float(k + 1) / cols, float(i + 1) / rows), Vector2(float(k + 1) / cols, float(i) / rows)])
	st.generate_normals()
	return st.commit()
