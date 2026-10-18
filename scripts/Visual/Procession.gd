extends Node3D
## The procession (docs/superpowers/refs/underground/supernatural_refs.md: the dead in white, men,
## women and children, each carrying a lit candle): now and then her dead walk the marigold trail she
## lays them, from her ofrenda across the floor and into the old city's stone behind the wall. Pale
## shapes (spectre.gdshader, its ink near white), each with its own candle's flame and light, gliding
## in file at a walking pace, facing their way; at the old stone each is eaten away into it. The ánimas
## gather to them as they pass (`animas`).

const SHADE := preload("res://scripts/Visual/shade.gdshader")
## How far apart they walk (along the trail, m), how fast (m/s), how high their candles' flames
## stand over their hands, how bright the candles.
const SPACING := 1.1
const PACE := 0.38
const FLAME := Vector2(0.09, 0.028)
const CANDLE_LIGHT := 0.5
const CANDLE_REACH := 2.2
## How near the trail's end each begins to be eaten into the stone, and how fast it goes (per s).
const INTO_STONE := 0.9
const GONE_RATE := 1.2
## How often they walk on their own (s).
const EVERY := Vector2(240.0, 480.0)
## Their shrouds' pale (shade.gdshader).
const PALE := Color(0.8, 0.86, 0.9)

## The trail they walk: a function of t (0 at its start, 1 at its end) to a point on the floor.
var trail: Callable
## Its length (m, along it).
var length := 1.0
var animas: Node3D
var figures: Array[MeshInstance3D] = []
var walking := false
@export var seed := 3

var _looks: Array[ShaderMaterial] = []
var _held: Array[Vector3] = []
var _along := 0.0
var _gone: Array[bool] = []
var _next := 0.0
var _rng := RandomNumberGenerator.new()


## The walkers from the uncanny kit's meshes: `cast` [(mesh, where its sleeves hold its candle)].
func build(cast: Array) -> void:
	_rng.seed = seed
	_next = _rng.randf_range(EVERY.x, EVERY.y)
	var flame_mesh := MeshVfx.flame(FLAME.x, FLAME.y, 8, 10)

	for i in cast.size():
		var figure := MeshInstance3D.new()
		figure.name = "dead_%d" % i
		figure.mesh = cast[i][0]
		# Its shroud and its face's hollow, each surface by its slot; the hollow's oval measured from it.
		var look := ShaderMaterial.new()
		look.shader = SHADE
		look.set_shader_parameter(&"noise", Vfx.noise_3d())
		look.set_shader_parameter(&"pale", PALE)
		var face := _hollow_oval(figure.mesh)
		look.set_shader_parameter(&"face_middle", face.position + face.size / 2.0)
		look.set_shader_parameter(&"face_half", Vector2(face.size.z / 2.0, face.size.y / 2.0) * 1.15)

		for k in figure.mesh.get_surface_count():
			var slot: Material = figure.mesh.surface_get_material(k)
			if slot != null and slot.resource_name == "hollow":
				var dark := look.duplicate() as ShaderMaterial
				dark.set_shader_parameter(&"hollow", 1.0)
				figure.set_surface_override_material(k, dark)
			else:
				figure.set_surface_override_material(k, look)
		figure.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		figure.visible = false
		add_child(figure)
		figures.append(figure)
		_looks.append(look)
		_held.append(cast[i][1])

		# Their candle: a warm flame standing in their hands, its light on them and the floor.
		var flame := MeshInstance3D.new()
		flame.name = "candle"
		flame.mesh = flame_mesh
		var fire := MeshVfx.look(Color("fff2c8"), Color("ffb347"), Color("c2410c"), 2.6, 0.04, 1.2, float(i) * 3.3)
		fire.set_shader_parameter(&"tail_eat", 0.55)
		flame.set_surface_override_material(0, fire)
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		figure.add_child(flame)
		flame.position = cast[i][1] + Vector3(0.0, 0.03, 0.0)
		var light := OmniLight3D.new()
		light.name = "candle_light"
		light.light_color = Color("ffb35c")
		light.light_energy = CANDLE_LIGHT
		light.omni_range = CANDLE_REACH
		light.shadow_enabled = false
		flame.add_child(light)
		light.position = Vector3(0.0, 0.08, 0.0)


## Its face's hollow, its bounds in the shade's own axes.
func _hollow_oval(mesh: Mesh) -> AABB:
	for k in mesh.get_surface_count():
		var slot: Material = mesh.surface_get_material(k)
		if slot != null and slot.resource_name == "hollow":
			var points: PackedVector3Array = mesh.surface_get_arrays(k)[Mesh.ARRAY_VERTEX]
			var box := AABB(points[0], Vector3.ZERO)
			for p in points:
				box = box.expand(p)
			return box
	return AABB(Vector3(0.1, 1.4, -0.1), Vector3(0.05, 0.25, 0.2))


func _set_all(i: int, param: StringName, value: Variant) -> void:
	for k in figures[i].mesh.get_surface_count():
		var look := figures[i].get_surface_override_material(k) as ShaderMaterial
		if look != null:
			look.set_shader_parameter(param, value)


## They set out now (they do on their own, rarely).
func start() -> void:
	walking = true
	_along = 0.0
	_gone.clear()

	for i in figures.size():
		_gone.append(false)
		figures[i].visible = false
		_set_all(i, &"presence", 1.0)


func _process(delta: float) -> void:
	if not walking:
		_next -= delta
		if _next <= 0.0:
			_next = _rng.randf_range(EVERY.x, EVERY.y)
			start()
		return

	_along += PACE * delta
	var still := false

	for i in figures.size():
		if _gone[i]:
			continue

		var figure := figures[i]
		# Each walks its place in the file: the first ahead, the rest behind it, none before the start.
		var behind := _along - SPACING * i
		still = true

		if behind < 0.0:
			figure.visible = false
			continue

		figure.visible = true
		var t := clampf(behind / length, 0.0, 1.0)
		var at: Vector3 = trail.call(t)
		var ahead: Vector3 = trail.call(minf(t + 0.02, 1.0)) - trail.call(maxf(t - 0.02, 0.0))
		# A glide, not a step: the dead do not walk as the living; they float, swaying a little.
		at.y = 0.03 * sin(_along * 2.2 + i * 1.3)
		figure.position = at

		if ahead.length() > 0.001:
			figure.rotation.y = atan2(-ahead.z, ahead.x)

		# Its candle's warmth on its shroud, its hem's mist where it floats.
		_set_all(i, &"candle_at", figure.global_transform * (_held[i] + Vector3(0.0, 0.06, 0.0)))
		_set_all(i, &"hem", figure.global_position.y + 0.1)

		# At the old stone, eaten away into it.
		if (1.0 - t) * length < INTO_STONE:
			var presence: float = _looks[i].get_shader_parameter(&"presence")
			presence = maxf(0.0, presence - GONE_RATE * delta)
			_set_all(i, &"presence", presence)
			if presence <= 0.0:
				_gone[i] = true
				figure.visible = false

	walking = still

	# The ánimas gather to the file while it walks.
	if animas != null and is_instance_valid(animas):
		animas.gather = figures[mini(figures.size() - 1, 2)] if walking else null
