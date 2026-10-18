class_name MeshVfx
extends RefCounted
## The shapes the Underground's mesh effects are drawn on, the Deadlock way
## (docs/superpowers/refs/underground/vfx_method.md), and their look (vfx_mesh.gdshader). Every
## shape's v runs along it (0 at its root, 1 at its far end), u round it, so the noise scrolls along.

const SHADER := preload("res://scripts/Visual/vfx_mesh.gdshader")

static var _noise: NoiseTexture2D


## The shared look: its bands, its brightness, how eaten it is, how fast its noise slides.
static func look(core: Color, body: Color, edge: Color, energy := 1.6, erosion := 0.25, scroll := 0.6,
		seed := 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter(&"core", core)
	m.set_shader_parameter(&"body", body)
	m.set_shader_parameter(&"edge", edge)
	m.set_shader_parameter(&"energy", energy)
	m.set_shader_parameter(&"erosion", erosion)
	m.set_shader_parameter(&"scroll", scroll)
	m.set_shader_parameter(&"seed", seed)
	m.set_shader_parameter(&"noise", noise())
	return m


## A tiling noise of our own, shared.
static func noise() -> NoiseTexture2D:
	if _noise == null:
		_noise = NoiseTexture2D.new()
		_noise.width = 256
		_noise.height = 256
		_noise.seamless = true
		_noise.generate_mipmaps = true
		var n := FastNoiseLite.new()
		# (Smooth, layered: big tongues with a little fine fray, never cells or facets.)
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.frequency = 0.012
		n.fractal_type = FastNoiseLite.FRACTAL_FBM
		n.fractal_octaves = 3
		n.fractal_gain = 0.45
		_noise.noise = n
	return _noise


## A flame turned about its upright axis: a round belly drawn up to a point (`height` tall,
## `radius` at its widest), `rings` up it and `sides` round, closed at both ends. Its root at y 0.
static func flame(height: float, radius: float, rings := 12, sides := 14) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var profile := []

	for i in rings + 1:
		var t := float(i) / rings
		# A teardrop: round below, drawn out to its tip.
		var r := radius * sin(PI * pow(t, 0.62)) * (1.0 - 0.15 * t)
		profile.append(Vector2(maxf(r, 0.0005), t * height))

	for i in rings:
		for k in sides:
			var a0 := TAU * k / sides
			var a1 := TAU * (k + 1) / sides
			var p00 := _round(profile[i], a0)
			var p01 := _round(profile[i], a1)
			var p10 := _round(profile[i + 1], a0)
			var p11 := _round(profile[i + 1], a1)
			var v0 := float(i) / rings
			var v1 := float(i + 1) / rings
			_quad(st, [p00, p10, p11, p01], [Vector2(float(k) / sides, v0), Vector2(float(k) / sides, v1),
				Vector2(float(k + 1) / sides, v1), Vector2(float(k + 1) / sides, v0)])

	# (Corners welded so the normals round off: smooth, never faceted like crumpled paper.)
	st.index()
	st.generate_normals()
	return st.commit()


## A crown of `count` flame tongues standing round a ring `spread` across (one mesh, one draw): each a slim
## flame (`radius` at its widest) of its own height (`height` the tallest, down to `shortest` of it), leaning
## out a little and twisted; u splits among them so the noise eats each differently. Their roots at y 0.
static func tongues(count: int, height: float, radius: float, spread: float, shortest := 0.55, seed := 0,
		rings := 10, sides := 8) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	for t in count:
		var a := TAU * t / count + rng.randf_range(-0.3, 0.3)
		var root := Vector3(cos(a), 0.0, sin(a)) * spread * 0.5
		var tall := height * rng.randf_range(shortest, 1.0)
		# (The tallest in the middle of the ring: the last stands at its centre.)
		if t == count - 1:
			root = Vector3.ZERO
			tall = height
		var lean := Vector3(cos(a), 0.0, sin(a)) * tall * rng.randf_range(0.08, 0.22)
		var twist := rng.randf_range(-0.6, 0.6)
		var wide := radius * rng.randf_range(0.75, 1.0)

		for i in rings:
			for k in sides:
				var corners := []
				var uvs := []
				for c in [[i, k], [i + 1, k], [i + 1, k + 1], [i, k + 1]]:
					var v := float(c[0]) / rings
					var r := wide * sin(PI * pow(v, 0.62)) * (1.0 - 0.15 * v)
					var turn: float = TAU * float(c[1]) / sides + twist * v
					# Leaning out as it climbs, the lean growing toward the tip.
					corners.append(root + Vector3(cos(turn) * maxf(r, 0.0005), v * tall, sin(turn) * maxf(r, 0.0005)) + lean * v * v)
					uvs.append(Vector2((t + float(c[1]) / sides) / count, v))
				_quad(st, corners, uvs)

	# (Corners welded so the normals round off: smooth, never faceted like crumpled paper.)
	st.index()
	st.generate_normals()
	return st.commit()


## A tendril: a tube rising along `path` (local points, its root first), `radius` at its root
## narrowing to a point, `sides` round it.
static func tendril(path: PackedVector3Array, radius: float, sides := 8) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := path.size()
	var rings := []

	for i in n:
		var ahead := (path[mini(i + 1, n - 1)] - path[maxi(i - 1, 0)]).normalized()
		var side := ahead.cross(Vector3.FORWARD if absf(ahead.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
		var up := side.cross(ahead).normalized()
		var r := radius * (1.0 - float(i) / (n - 1)) * (0.7 + 0.3 * sin(float(i) * 1.7))
		var ring := []
		for k in sides + 1:
			var a := TAU * k / sides
			ring.append(path[i] + (side * cos(a) + up * sin(a)) * maxf(r, 0.002))
		rings.append(ring)

	for i in n - 1:
		for k in sides:
			_quad(st, [rings[i][k], rings[i + 1][k], rings[i + 1][k + 1], rings[i][k + 1]],
				[Vector2(float(k) / sides, float(i) / (n - 1)), Vector2(float(k) / sides, float(i + 1) / (n - 1)),
				Vector2(float(k + 1) / sides, float(i + 1) / (n - 1)), Vector2(float(k + 1) / sides, float(i) / (n - 1))])

	st.generate_normals()
	return st.commit()


## A plume: a tube along `path` (local points, its root first) widening from `root` to `crown` across
## (radii, m) as smoke spreads, `sides` round it, open at both ends; v runs up it, u round it.
static func plume(path: PackedVector3Array, root: float, crown: float, sides := 10) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := path.size()
	var rings := []

	for i in n:
		var ahead := (path[mini(i + 1, n - 1)] - path[maxi(i - 1, 0)]).normalized()
		var side := ahead.cross(Vector3.FORWARD if absf(ahead.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
		var up := side.cross(ahead).normalized()
		var t := float(i) / (n - 1)
		# (Spreading fast off the vent, then slower: smoke widens as it slows.)
		var r := lerpf(root, crown, sqrt(t))
		var ring := []
		for k in sides + 1:
			var a := TAU * k / sides
			ring.append(path[i] + (side * cos(a) + up * sin(a)) * r)
		rings.append(ring)

	for i in n - 1:
		for k in sides:
			_quad(st, [rings[i][k], rings[i + 1][k], rings[i + 1][k + 1], rings[i][k + 1]],
				[Vector2(float(k) / sides, float(i) / (n - 1)), Vector2(float(k) / sides, float(i + 1) / (n - 1)),
				Vector2(float(k + 1) / sides, float(i + 1) / (n - 1)), Vector2(float(k + 1) / sides, float(i) / (n - 1))])

	# (Corners welded so the normals round off: smooth, never faceted.)
	st.index()
	st.generate_normals()
	return st.commit()


## A ribbon drawn along `points` (world, the newest first), `width` across at its head narrowing
## to nothing at its tail, turned to face `eye`; v runs from its head (0) to its tail (1).
static func ribbon(points: PackedVector3Array, width: float, eye: Vector3) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var n := points.size()

	if n < 2:
		return mesh

	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var normals := PackedVector3Array()

	for i in n:
		var ahead := (points[mini(i + 1, n - 1)] - points[maxi(i - 1, 0)])
		ahead = ahead.normalized() if ahead.length() > 1e-5 else Vector3.UP
		var to_eye := (eye - points[i]).normalized()
		var across := ahead.cross(to_eye).normalized() * width * 0.5 * (1.0 - float(i) / (n - 1))
		var v := float(i) / (n - 1)
		verts.append(points[i] - across)
		verts.append(points[i] + across)
		uvs.append(Vector2(0.0, v))
		uvs.append(Vector2(1.0, v))
		normals.append(to_eye)
		normals.append(to_eye)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_NORMAL] = normals
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, arrays)
	return mesh


static func _round(p: Vector2, a: float) -> Vector3:
	return Vector3(cos(a) * p.x, p.y, sin(a) * p.x)


static func _quad(st: SurfaceTool, corners: Array, uvs: Array) -> void:
	for i in [0, 1, 2, 0, 2, 3]:
		st.set_uv(uvs[i])
		st.add_vertex(corners[i])
