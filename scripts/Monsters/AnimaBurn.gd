extends Node3D
## What burns an ánima down. A soul no one lit a candle for, it goes up at last: the game's own
## simulated fire (anima_fire.gdshader) in its sick green, catching where it caught and running
## along the body, with a glow, threads of smoke, sparks and a light that moves. The flesh burns black (anima_flesh.gdshader's `charred`),
## its hot edge ahead of the flames, goes to pale ash and falls apart in flakes (`crumbled`). A
## little heap is left, with a last flame on it, then a thread of smoke, and it sinks away.
## AnimaBody.gd says what there is to burn and acts its last moments meanwhile. Its child, so it
## goes with it.

const Layers := preload("res://scripts/Visual/Layers.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")
const FleshShader := preload("res://scripts/Monsters/anima_flesh.gdshader")
const FireShader := preload("res://scripts/Monsters/anima_fire.gdshader")
const HALO := preload("res://scripts/Visual/vfx_halo.gdshader")
const WISP := preload("res://scripts/Visual/vfx_wisp.gdshader")
const BRUSH := preload("res://textures/painted/eclipse/brush.png")

## How long the fire takes to run the length of it; how far that is (m); how quickly a flame
## comes up, and how long after the ash starts to fall a flame can last.
const RUNS := 0.7
const REACHES := 1.15
const FLAME_GROWS := 0.28
const FLAMES_LAST := 0.5
## A sheet of fire against the flame it stands for: how tall, how wide, so they run together;
## and how far their heights differ. A flame's smoke and glow go by FLAME_WIDE.
const SHEET_TALL := 1.7
const SHEET_WIDE := 1.25
const FLAME_WIDE := 0.42
const FLAME_VARIES := Vector2(0.7, 1.4)
const FIRE_SHEET := "res://assets/vfx/fire.png"
## How much it lifts, and how big the last flame on the heap.
const LAST_FLAME := 0.2
const LAST_FLAME_FOR := 0.95
## What it casts round it.
const GLOW := Color("#A8C840")
## Each how manyth flame has a glow, and a thread of smoke; how long the last thread lasts.
const HALO_EVERY := 3
const WISP_EVERY := 3
const SMOKE_LASTS := 3.2
## Its shell of fire: how broken up, how far its licks stream up off it (m).
const SHELL_MOST := 0.8
const SHELL_RISES := 0.08
## Its light; how many burning at once can throw one.
## (High, and low in strength: it should light the floor round it, not turn its flesh to plastic.)
const LIGHT_MOST := 0.85
const LIGHT_UP := 0.75
const LIGHT_RANGE := 3.4
const LIGHTS_MOST := 4
## The heap: how long it lies, how long it takes to go.
const CRUMBLES := 0.85
const HEAP_LIES := 5.0
const HEAP_GOES := 1.4
const HEAP_WIDE := 0.165
const HEAP_HIGH := 0.085
const FLAKES := 46
const FLAKE_LIFE := 1.5
const SPARKS := 26
const SPARK_HOT := Color("#E4EDA0")
const SPARK_COOL := Color("#34441A")
const ASH_PALE := Color(0.2, 0.205, 0.22)
const ASH_DARK := Color(0.05, 0.05, 0.055)

var _burning: Array[Dictionary] = []
var _embers: Array[MeshInstance3D] = []
var _spots: Array[Dictionary] = []
var _place: Callable
var _flames: MultiMeshInstance3D
var _halos: MultiMeshInstance3D
var _wisps: MultiMeshInstance3D
var _flakes: CPUParticles3D
var _sparks: CPUParticles3D
var _light: OmniLight3D
var _heap: MeshInstance3D
var _floor_y := 0.0
var _size := 1.0
var _ignites := 0.3
var _crumbles := 2.0
var _t := 0.0
var _charred := 0.0
var _crumbled := 0.0
var _flare := 0.0
var _heap_high := 0.0
var _lit := 0
var _smoking := 0
var _caught := false
var _broke := false
var _light_now := 0.0
var _rng := RandomNumberGenerator.new()


## What there is to burn: `meshes` ([mesh, how long after the rest it goes]), `embers`, `spots`
## where flames stand and `place` to say where a spot is now, the `floor`, its `size`, `seed`;
## when it `ignites` and when it `crumbles`; `from` where the fire runs, in the world.
func start(what: Dictionary) -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_rng.seed = what["seed"]
	_place = what["place"]
	_embers = what["embers"]
	_floor_y = what["floor"]
	_size = what["size"]
	_ignites = what["ignites"]
	_crumbles = what["crumbles"]
	var from: Vector3 = what["from"]

	for item in what["meshes"]:
		var mesh: MeshInstance3D = item[0]
		_burning.append({"mesh": mesh, "late": item[1]})
		mesh.get_active_material(0).set_shader_parameter(&"burn_noise", MeshVfx.noise())
		mesh.set_instance_shader_parameter(&"burn_from", from)
		mesh.set_instance_shader_parameter(&"burn_reach", REACHES * _size)

	for spot in what["spots"]:
		var at: Vector3 = _place.call(spot)
		_spots.append({
			"spot": spot, "tall": float(spot[spot.size() - 1]) * _rng.randf_range(FLAME_VARIES.x, FLAME_VARIES.y),
			"born": clampf(at.distance_to(from) / (REACHES * _size), 0.0, 1.0) * RUNS + _rng.randf_range(0.0, 0.1),
			"last": _rng.randf_range(0.0, FLAMES_LAST), "phase": _rng.randf(),
		})

	# A last flame on what is left.
	_spots.append({"spot": [], "tall": LAST_FLAME, "born": 0.0, "last": 0.0, "phase": _rng.randf()})
	_build_flames()
	_flakes = _new_bits(FLAKES, FLAKE_LIFE, _flake_mesh(), Vector3(0.0, -0.75, 0.0), 0.25, 1.0, [GLOW, ASH_PALE, ASH_PALE, ASH_DARK, Color(ASH_DARK, 0.0)])
	_sparks = _new_bits(SPARKS, 0.8, _spark_mesh(), Vector3(0.0, 0.9, 0.0), 0.8, 2.0, [SPARK_HOT, GLOW, SPARK_COOL, SPARK_COOL, Color(SPARK_COOL, 0.0)])
	_build_light()
	_build_heap()


func charred() -> float:
	return _charred


func crumbled() -> float:
	return _crumbled


func flames_lit() -> int:
	return _lit


func wisps_rising() -> int:
	return _smoking


func light_energy() -> float:
	return _light_now


func flakes_falling() -> bool:
	return _flakes.emitting


func heap_height() -> float:
	return _heap_high


func heap_floor() -> float:
	return _heap.global_position.y


## How far up its fire is, 0..1.
func flare() -> float:
	return _flare


func _physics_process(delta: float) -> void:
	_t += delta
	_charred = clampf((_t - _ignites) / maxf(_crumbles - _ignites - 0.1, 0.1), 0.0, 1.0)
	_crumbled = clampf((_t - _crumbles) / CRUMBLES, 0.0, 1.0)
	_flare = smoothstep(_ignites, _ignites + 0.5, _t) * (1.0 - smoothstep(_crumbles, _crumbles + CRUMBLES * 0.8, _t))

	if not _caught and _t >= _ignites:
		_caught = true
		Sfx.play(self, &"ignite", _centre(), -8.0, 0.72)
		Sfx.play(self, &"burning", _centre(), -10.0, 0.9)

	if not _broke and _t >= _crumbles:
		_broke = true
		Sfx.play(self, &"whoosh_light", _centre(), -15.0, 0.55)

	for item in _burning:
		var mesh: MeshInstance3D = item["mesh"]
		var late: float = item["late"]
		var gone := clampf((_t - _crumbles - late) / CRUMBLES, 0.0, 1.0)
		mesh.set_instance_shader_parameter(&"charred", clampf((_t - _ignites - late) / maxf(_crumbles - _ignites - 0.1, 0.1), 0.0, 1.0))
		mesh.set_instance_shader_parameter(&"crumbled", gone)
		mesh.visible = gone < 1.0

	for ember in _embers:
		ember.set_instance_shader_parameter(&"flare", _flare * SHELL_MOST)
		ember.set_instance_shader_parameter(&"rise", _flare * SHELL_RISES)
		# (Gone before the flesh breaks: its inside would show through the holes.)
		ember.visible = _t < _crumbles

	_work_flames()
	var centre := _centre()
	_flakes.global_position = centre
	_sparks.global_position = centre
	_flakes.emitting = _t >= _crumbles - 0.2 and _t < _crumbles + CRUMBLES
	_sparks.emitting = _t >= _ignites and _t < _crumbles + 0.3
	_work_light(centre)
	_work_heap()


## The middle of what is burning, and where its bits fly from.
func _centre() -> Vector3:
	return get_parent().global_position + Vector3.UP * 0.08


func _work_flames() -> void:
	_lit = 0
	_smoking = 0
	var heap_at := Vector3(get_parent().global_position.x, _floor_y + HEAP_HIGH * 0.6 * _size, get_parent().global_position.z)

	for i in _spots.size():
		var flame: Dictionary = _spots[i]
		var spot: Array = flame["spot"]
		var tall: float
		var at: Vector3

		if spot.is_empty():
			at = heap_at
			tall = float(flame["tall"]) * _size * smoothstep(_crumbles + 0.2, _crumbles + 0.5, _t) * (1.0 - smoothstep(_crumbles + LAST_FLAME_FOR * 0.6, _crumbles + LAST_FLAME_FOR, _t))
		else:
			at = _place.call(spot)
			var grown := smoothstep(_ignites + float(flame["born"]), _ignites + float(flame["born"]) + FLAME_GROWS, _t)
			var out := 1.0 - smoothstep(_crumbles - 0.1 + float(flame["last"]), _crumbles + 0.25 + float(flame["last"]), _t)
			tall = float(flame["tall"]) * _size * grown * out

		var shape := Transform3D(Basis.from_scale(Vector3(FLAME_WIDE, 1.0, FLAME_WIDE) * maxf(tall, 0.0005)), at)

		if tall > 0.03:
			_lit += 1

		_flames.multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(SHEET_WIDE, SHEET_TALL, 1.0) * maxf(tall, 0.0005)), at))

		if i % HALO_EVERY == 0:
			_halos.multimesh.set_instance_transform(i / HALO_EVERY, shape)

		if i % WISP_EVERY == 0:
			if tall > 0.03:
				_smoking += 1

			_wisps.multimesh.set_instance_transform(i / WISP_EVERY, shape)

	# The last thread of smoke, off the heap, when the fire is out.
	var smoke_left := (1.0 - smoothstep(_crumbles + CRUMBLES + SMOKE_LASTS * 0.7, _crumbles + CRUMBLES + SMOKE_LASTS, _t)) * smoothstep(_crumbles + 0.6, _crumbles + 1.2, _t)
	_wisps.multimesh.set_instance_transform(_wisps.multimesh.instance_count - 1, Transform3D(Basis.from_scale(Vector3.ONE * maxf(0.2 * smoke_left, 0.0005)), heap_at))


func _build_flames() -> void:
	var count := _spots.size()
	var flame := QuadMesh.new()
	var look := ShaderMaterial.new()
	look.shader = FireShader
	look.set_shader_parameter(&"sheet", load(FIRE_SHEET))
	look.set_shader_parameter(&"noise", MeshVfx.noise())
	flame.material = look
	_flames = _new_draw(flame, count)
	var quad := QuadMesh.new()
	var glow := ShaderMaterial.new()
	glow.shader = HALO
	glow.set_shader_parameter(&"colour", GLOW)
	glow.set_shader_parameter(&"size", 0.06)
	glow.set_shader_parameter(&"lift", 0.03)
	glow.set_shader_parameter(&"strength", 0.32)
	quad.material = glow
	_halos = _new_draw(quad, ceili(float(count) / float(HALO_EVERY)))
	var thread := QuadMesh.new()
	thread.subdivide_depth = 20
	var smoke := ShaderMaterial.new()
	smoke.shader = WISP
	smoke.set_shader_parameter(&"noise", MeshVfx.noise())
	smoke.set_shader_parameter(&"colour", Color(0.3, 0.32, 0.27))
	smoke.set_shader_parameter(&"thin", Color(0.16, 0.17, 0.15))
	smoke.set_shader_parameter(&"gutter", 1.0)
	smoke.set_shader_parameter(&"height", 0.17)
	smoke.set_shader_parameter(&"width", 0.012)
	smoke.set_shader_parameter(&"start", 0.03)
	smoke.set_shader_parameter(&"opacity", 0.55)
	thread.material = smoke
	# (One more thread than it has flames for: the last, off the heap.)
	_wisps = _new_draw(thread, ceili(float(count) / float(WISP_EVERY)) + 1)


func _new_draw(mesh: Mesh, count: int) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_custom_data = true
	multi.mesh = mesh
	multi.instance_count = count

	for i in count:
		multi.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * 0.0005), Vector3.ZERO))
		multi.set_instance_custom_data(i, Color(_rng.randf(), 0, 0, 0))

	var draw := MultiMeshInstance3D.new()
	draw.multimesh = multi
	draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# (Spots move, and a MultiMesh keeps the bounds it was made with: never cull it.)
	draw.custom_aabb = AABB(Vector3(-2000.0, -2000.0, -2000.0), Vector3(4000.0, 4000.0, 4000.0))
	add_child(draw)
	return draw


func _build_light() -> void:
	var lights_going := 0

	for other in get_tree().get_nodes_in_group(&"anima_ash_lights"):
		if other != self:
			lights_going += 1

	if lights_going >= LIGHTS_MOST:
		return

	add_to_group(&"anima_ash_lights")
	_light = OmniLight3D.new()
	_light.light_color = GLOW
	_light.omni_range = LIGHT_RANGE
	_light.light_cull_mask = Layers.ALL_BUT_PROBE
	_light.shadow_enabled = false
	_light.light_energy = 0.0
	add_child(_light)


func _work_light(centre: Vector3) -> void:
	if _light == null:
		return

	var flicker := 0.78 + 0.22 * sin(_t * 17.0) * sin(_t * 7.3) + 0.1 * sin(_t * 31.0)
	_light_now = LIGHT_MOST * _flare * flicker
	_light.light_energy = _light_now
	_light.global_position = centre + Vector3.UP * LIGHT_UP


func _new_bits(amount: int, life: float, mesh: Mesh, pull: Vector3, slowest: float, fastest: float, colours: Array) -> CPUParticles3D:
	var bits := CPUParticles3D.new()
	bits.amount = amount
	bits.lifetime = life
	bits.emitting = false
	bits.local_coords = false
	bits.mesh = mesh
	bits.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	bits.emission_box_extents = Vector3(0.36, 0.14, 0.36) * _size
	bits.direction = Vector3.UP
	bits.spread = 45.0
	bits.gravity = pull
	bits.initial_velocity_min = slowest
	bits.initial_velocity_max = fastest
	bits.damping_min = 0.6
	bits.damping_max = 1.4
	bits.angle_min = 0.0
	bits.angle_max = 360.0
	bits.angular_velocity_min = -180.0
	bits.angular_velocity_max = 180.0
	bits.scale_amount_min = 0.5
	bits.scale_amount_max = 1.5
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.14, 0.34, 0.8, 1.0])
	ramp.colors = PackedColorArray(colours)
	bits.color_ramp = ramp
	var look := StandardMaterial3D.new()
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.vertex_color_use_as_albedo = true
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	look.cull_mode = BaseMaterial3D.CULL_DISABLED
	bits.material_override = look
	bits.layers = Layers.FX
	bits.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bits)
	return bits


## A torn bit of ash: a chunky shape, not a dot.
func _flake_mesh() -> ArrayMesh:
	return _quad_mesh([Vector3(-0.007, -0.025, 0.0), Vector3(0.013, -0.011, 0.0), Vector3(0.005, 0.024, 0.0), Vector3(-0.013, 0.005, 0.0)])


## A spark: a sliver.
func _spark_mesh() -> ArrayMesh:
	return _quad_mesh([Vector3(-0.003, -0.012, 0.0), Vector3(0.004, -0.006, 0.0), Vector3(0.003, 0.014, 0.0), Vector3(-0.004, 0.004, 0.0)])


func _quad_mesh(corners: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for index in [0, 1, 2, 0, 2, 3]:
		st.add_vertex(corners[index])

	return st.commit()


func _work_heap() -> void:
	var grown := smoothstep(_crumbles * 0.98, _crumbles + CRUMBLES, _t)
	var going := clampf((_t - _crumbles - CRUMBLES - HEAP_LIES) / HEAP_GOES, 0.0, 1.0)
	_heap_high = HEAP_HIGH * _size * grown * (1.0 - going * 0.6)
	_heap.scale = Vector3(_size * (0.55 + 0.45 * grown), maxf(_heap_high / HEAP_HIGH, 0.001), _size * (0.55 + 0.45 * grown))
	_heap.visible = grown > 0.01
	var over: Vector3 = get_parent().global_position
	_heap.global_position = Vector3(over.x, _floor_y, over.z)
	_heap.set_instance_shader_parameter(&"charred", 1.0)
	_heap.set_instance_shader_parameter(&"crumbled", going)

	if going >= 1.0:
		get_parent().queue_free()


## A low mound, lumped and torn at its edge, closed underneath, in the flesh's own hard light.
func _build_heap() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var around := 16
	var rings := 5
	var points: Array[PackedVector3Array] = []
	var colours: Array[PackedColorArray] = []

	for r in rings:
		var at := float(r) / float(rings - 1)
		var ring := PackedVector3Array()
		var paint := PackedColorArray()

		for j in around:
			var turn := TAU * float(j) / float(around)
			var lumps := 1.0 + sin(turn * 3.0 + 1.1) * 0.16 + sin(turn * 5.0 + 2.6) * 0.1
			var wide := HEAP_WIDE * at * (lumps + _rng.randf_range(-0.1, 0.1) * at)
			var high := HEAP_HIGH * pow(maxf(1.0 - at, 0.0), 0.75) * _rng.randf_range(0.82, 1.14)
			ring.append(Vector3(cos(turn) * wide, high, sin(turn) * wide))
			paint.append(ASH_PALE.lerp(ASH_DARK, _rng.randf_range(0.0, 0.85) * (0.4 + at * 0.6)))

		points.append(ring)
		colours.append(paint)

	for r in rings - 1:
		for j in around:
			var n := (j + 1) % around
			_heap_quad(st, points[r][j], points[r][n], points[r + 1][n], points[r + 1][j], colours[r][j], colours[r][n], colours[r + 1][n], colours[r + 1][j])

	# Underneath, closed.
	var under := Vector3(0.0, -0.002, 0.0)

	for j in around:
		var n := (j + 1) % around
		var rim: PackedVector3Array = points[rings - 1]
		st.set_color(ASH_DARK)
		st.add_vertex(under)
		st.add_vertex(rim[j])
		st.add_vertex(rim[n])

	st.generate_normals()
	_heap = MeshInstance3D.new()
	_heap.mesh = st.commit()
	var look := ShaderMaterial.new()
	look.shader = FleshShader
	look.set_shader_parameter(&"stroke_sheet", BRUSH)
	look.set_shader_parameter(&"burn_noise", MeshVfx.noise())
	look.set_shader_parameter(&"wet", 0.0)
	look.set_shader_parameter(&"fill", 0.3)
	look.set_shader_parameter(&"rim", 0.1)
	look.set_shader_parameter(&"fill_sky", Color(0.42, 0.42, 0.38))
	look.set_shader_parameter(&"fill_ground", Color(0.4, 0.38, 0.33))
	_heap.material_override = look
	_heap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_heap.top_level = true
	_heap.visible = false
	add_child(_heap)


func _heap_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ca: Color, cb: Color, cc: Color, cd: Color) -> void:
	for pair in [[a, ca], [c, cc], [b, cb], [a, ca], [d, cd], [c, cc]]:
		st.set_color(pair[1])
		st.add_vertex(pair[0])
