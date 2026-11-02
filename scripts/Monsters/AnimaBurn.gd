extends Node3D
## What burns an ánima down: its own low fire comes up on it, the flesh goes to pale ash from
## the fire's edge inward (anima_flesh.gdshader's `charred`), the ash falls apart in flakes
## (`crumbled`), and a little heap is left on the floor, which sinks away. AnimaBody.gd says
## what there is to burn, and goes limp while this happens. Its child, so it goes with it.

const Layers := preload("res://scripts/Visual/Layers.gd")
const FleshShader := preload("res://scripts/Monsters/anima_flesh.gdshader")
const BRUSH := preload("res://textures/painted/eclipse/brush.png")

## When it happens (s): the fire catches; the charring; the crumbling; how long the heap lies.
const CATCHES := 0.2
const CHARS := 1.25
const CRUMBLES_AT := 1.45
const CRUMBLES := 0.85
const HEAP_LIES := 5.0
const HEAP_GOES := 1.4
## The fire: how big its flames get, and when it is highest.
const FLAME_HIGH := Vector2(0.26, 0.52)
const FLAME_WIDE := 0.034
## Its shell of fire stays broken up, licks and not an outline.
const SHELL_MOST := 0.46
const FLARES := 0.55
## The flakes: how many, how long each lasts.
const FLAKES := 46
const FLAKE_LIFE := 1.5
## The heap: how much of the body's size, how high.
const HEAP_WIDE := 0.165
const HEAP_HIGH := 0.085
## Its own fire, higher than it has ever been: lighter bands than its low burn, or it goes dark
## between them and reads as leaves.
const FIRE_CORE := Color("#A2B04E")
const FIRE_BODY := Color("#626E2C")
const FIRE_EDGE := Color("#333B18")
## How far its shell's licks stream up off it (m).
const SHELL_RISES := 0.14
const ASH_PALE := Color(0.2, 0.205, 0.22)
const ASH_DARK := Color(0.05, 0.05, 0.055)

var _burning: Array[Dictionary] = []
var _embers: Array[MeshInstance3D] = []
var _flames: Array[MeshInstance3D] = []
var _flame_at: Callable
var _flakes: CPUParticles3D
var _heap: MeshInstance3D
var _heap_look: ShaderMaterial
var _floor_y := 0.0
var _size := 1.0
var _t := 0.0
var _charred := 0.0
var _crumbled := 0.0
var _flare := 0.0
var _heap_high := 0.0
var _rng := RandomNumberGenerator.new()


## `meshes` to burn, each [mesh, how long after the rest it catches]; its `embers`; `flame_at`
## gives where its flames stand, this frame, in the world; `count` of them; the floor (world y).
func start(meshes: Array, embers: Array[MeshInstance3D], flame_at: Callable, count: int, floor_y: float, size: float, seed_value: int) -> void:
	_rng.seed = seed_value
	_flame_at = flame_at
	_embers = embers
	_floor_y = floor_y
	_size = size

	for item in meshes:
		_burning.append({"mesh": item[0], "late": item[1]})
		item[0].get_active_material(0).set_shader_parameter(&"burn_noise", MeshVfx.noise())

	var look := MeshVfx.look(FIRE_CORE, FIRE_BODY, FIRE_EDGE, 0.9, 0.22, 1.9)
	look.set_shader_parameter(&"tail_eat", 0.62)
	look.set_shader_parameter(&"core_reach", 0.3)
	look.set_shader_parameter(&"churn", 0.012)
	look.set_shader_parameter(&"tiling", Vector2(1.0, 0.9))

	for i in count:
		var flame := MeshInstance3D.new()
		flame.mesh = MeshVfx.flame(_rng.randf_range(FLAME_HIGH.x, FLAME_HIGH.y), FLAME_WIDE * _rng.randf_range(0.7, 1.15), 10, 8)
		flame.material_override = look
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flame.top_level = true
		flame.visible = false
		add_child(flame)
		_flames.append(flame)

	_build_flakes()
	_build_heap()


func charred() -> float:
	return _charred


func crumbled() -> float:
	return _crumbled


func flames_lit() -> int:
	var lit := 0

	for flame in _flames:
		if flame.visible:
			lit += 1

	return lit


func flakes_falling() -> bool:
	return _flakes.emitting


func heap_height() -> float:
	return _heap_high


func heap_floor() -> float:
	return _heap.global_position.y


## How far up its fire is, 0..1 and over at its height.
func flare() -> float:
	return _flare


func _physics_process(delta: float) -> void:
	_t += delta
	_charred = clampf((_t - CATCHES) / CHARS, 0.0, 1.0)
	_crumbled = clampf((_t - CRUMBLES_AT) / CRUMBLES, 0.0, 1.0)
	_flare = smoothstep(0.0, FLARES, _t) * (1.0 - smoothstep(CRUMBLES_AT, CRUMBLES_AT + CRUMBLES * 0.8, _t))

	for item in _burning:
		var mesh: MeshInstance3D = item["mesh"]
		var late: float = item["late"]
		var crumbled_here := clampf((_t - CRUMBLES_AT - late) / CRUMBLES, 0.0, 1.0)
		mesh.set_instance_shader_parameter(&"charred", clampf((_t - CATCHES - late) / CHARS, 0.0, 1.0))
		mesh.set_instance_shader_parameter(&"crumbled", crumbled_here)
		mesh.visible = crumbled_here < 1.0

	for ember in _embers:
		ember.set_instance_shader_parameter(&"flare", _flare * SHELL_MOST)
		ember.set_instance_shader_parameter(&"rise", _flare * SHELL_RISES)
		# (Gone before the flesh breaks: its inside would show through the holes.)
		ember.visible = _t < CRUMBLES_AT

	_work_flames()
	_flakes.emitting = _t >= CRUMBLES_AT * 0.85 and _t < CRUMBLES_AT + CRUMBLES
	_work_heap()


func _work_flames() -> void:
	var places: PackedVector3Array = _flame_at.call()

	for i in _flames.size():
		var flame := _flames[i]
		var size := _flare * (0.8 + 0.2 * sin(_t * 9.0 + float(i) * 2.1))
		flame.visible = _t > CATCHES and size > 0.03

		if flame.visible:
			flame.global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3(size, size * (0.75 + 0.25 * sin(_t * 13.0 + float(i))), size) * _size), places[i % places.size()])


func _work_heap() -> void:
	var grown := smoothstep(CRUMBLES_AT * 0.9, CRUMBLES_AT + CRUMBLES, _t)
	var going := clampf((_t - CRUMBLES_AT - CRUMBLES - HEAP_LIES) / HEAP_GOES, 0.0, 1.0)
	_heap_high = HEAP_HIGH * _size * grown * (1.0 - going * 0.6)
	_heap.scale = Vector3(_size * (0.55 + 0.45 * grown), maxf(_heap_high / HEAP_HIGH, 0.001), _size * (0.55 + 0.45 * grown))
	_heap.visible = grown > 0.01
	_heap.global_position = Vector3(global_position.x, _floor_y, global_position.z)
	_heap.set_instance_shader_parameter(&"charred", 1.0)
	_heap.set_instance_shader_parameter(&"crumbled", going)

	if going >= 1.0:
		get_parent().queue_free()


func _build_flakes() -> void:
	_flakes = CPUParticles3D.new()
	_flakes.amount = FLAKES
	_flakes.lifetime = FLAKE_LIFE
	_flakes.emitting = false
	_flakes.local_coords = false
	_flakes.mesh = _flake_mesh()
	_flakes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_flakes.emission_box_extents = Vector3(0.34, 0.12, 0.34) * _size
	_flakes.direction = Vector3.UP
	_flakes.spread = 50.0
	_flakes.gravity = Vector3(0.0, -0.75, 0.0)
	_flakes.initial_velocity_min = 0.25
	_flakes.initial_velocity_max = 1.0
	_flakes.damping_min = 0.6
	_flakes.damping_max = 1.4
	_flakes.angle_min = 0.0
	_flakes.angle_max = 360.0
	_flakes.angular_velocity_min = -180.0
	_flakes.angular_velocity_max = 180.0
	_flakes.scale_amount_min = 0.5
	_flakes.scale_amount_max = 1.5
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.14, 0.34, 0.8, 1.0])
	ramp.colors = PackedColorArray([FIRE_CORE, ASH_PALE, ASH_PALE, ASH_DARK, Color(ASH_DARK, 0.0)])
	_flakes.color_ramp = ramp
	var look := StandardMaterial3D.new()
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.vertex_color_use_as_albedo = true
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	look.cull_mode = BaseMaterial3D.CULL_DISABLED
	_flakes.material_override = look
	_flakes.layers = Layers.FX
	_flakes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_flakes)


## A torn bit of ash: a chunky shape, not a dot.
func _flake_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners := [Vector3(-0.007, -0.025, 0.0), Vector3(0.013, -0.011, 0.0), Vector3(0.005, 0.024, 0.0), Vector3(-0.013, 0.005, 0.0)]

	for index in [0, 1, 2, 0, 2, 3]:
		st.add_vertex(corners[index])

	return st.commit()


## A low mound, torn at its edge, closed underneath; painted, in the flesh's own hard light.
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
			# Lumps of it, and a torn edge running thin.
			var lumps := 1.0 + sin(turn * 3.0 + 1.1) * 0.16 + sin(turn * 5.0 + 2.6) * 0.1
			var torn := lumps + _rng.randf_range(-0.1, 0.1) * at
			var wide := HEAP_WIDE * at * torn
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
	_heap_look = ShaderMaterial.new()
	_heap_look.shader = FleshShader
	_heap_look.set_shader_parameter(&"stroke_sheet", BRUSH)
	_heap_look.set_shader_parameter(&"burn_noise", MeshVfx.noise())
	_heap_look.set_shader_parameter(&"wet", 0.0)
	_heap_look.set_shader_parameter(&"fill", 0.3)
	_heap_look.set_shader_parameter(&"rim", 0.1)
	_heap_look.set_shader_parameter(&"fill_sky", Color(0.42, 0.42, 0.38))
	_heap_look.set_shader_parameter(&"fill_ground", Color(0.4, 0.38, 0.33))
	_heap.material_override = _heap_look
	_heap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_heap.top_level = true
	_heap.visible = false
	add_child(_heap)


func _heap_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ca: Color, cb: Color, cc: Color, cd: Color) -> void:
	for pair in [[a, ca], [c, cc], [b, cb], [a, ca], [d, cd], [c, cc]]:
		st.set_color(pair[1])
		st.add_vertex(pair[0])
