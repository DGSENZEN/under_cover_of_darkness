extends "res://scripts/Visual/Torch.gd"
## A light fixture: a burner (Torch.gd) with a model round it, built by the
## props pipeline (tools/props): assets/props/lights/<fixture>.glb and its
## .json (sockets, slots, the burner's settings). Its flames stand at the
## model's flame sockets, its halo at the corona socket; its surfaces are the
## shared slot materials (Materials.gd: the user's photos or flat colours)
## shaded by the model's baked colours; parts that glow from inside (a pitch
## head, coals, horn panes) glow with the flame and char once it is cold.
## A wall fixture leaves soot on the wall above it.
##
## Everything that holds a torch holds a fixture the same way: it is one.
##
##   Lights.wall_torch(parent, flame_at, wall_normal)   (Lights.gd builds them)

const Materials := preload("res://scripts/Visual/Materials.gd")
const FOLDER := "res://assets/props/lights/"
const SOOT := preload("res://assets/vfx/soot.png")
const COOKIE := "res://assets/vfx/cookie_lantern.png"
const CHAIN_LINK := "res://assets/props/lights/chain_link.glb"
## A chain link's length along its chain.
const LINK_PITCH := 0.054
## A hung fixture's swing: gravity, damping, how hard the wind pushes it
## (rad/s^2 at full wind), and the most it swings.
const SWING_DAMPING := 1.5
const SWING_WIND := 0.8
const SWING_MOST := 0.5

## Which fixture (assets/props/lights/<fixture>.glb / .json).
@export var fixture := &""
## Burner settings laid over the fixture's own (export name -> value).
var overrides := {}
## Metres its stretching part grows (a pole cresset fitted to its place).
var stretch := 0.0
## A hung fixture: metres of chain between its hook (its origin) and it.
var hang_drop := 0.0

var model: Node3D
## socket name -> its points in the fixture's space.
var sockets := {}
var glow_meshes: Array[GeometryInstance3D] = []
var soot: Decal
var spec_data := {}
var _tilt := Vector2.ZERO
var _spin := Vector2.ZERO
var _rest_basis := Basis.IDENTITY
var _swinging := false

static var _specs := {}
var _bodies: Array[RID] = []


## A fixture's .json, read once ({} when there is none).
static func spec(fixture_name: StringName) -> Dictionary:
	if _specs.has(fixture_name):
		return _specs[fixture_name]

	var data := {}
	var path := FOLDER + String(fixture_name) + ".json"

	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))

		if parsed is Dictionary:
			data = parsed

	_specs[fixture_name] = data
	return data


## A socket's point in the fixture's space (the origin if it has none).
func socket(socket_name: StringName, index := 0) -> Vector3:
	var points: Array = sockets.get(socket_name, [])
	return points[index] if index < points.size() else Vector3.ZERO


func _before_ready() -> void:
	spec_data = spec(fixture)

	if spec_data.is_empty():
		push_error("LightFixture: no fixture called '%s' (%s%s.json): a bare flame instead" % [fixture, FOLDER, fixture])
		_apply_settings(overrides)
		return

	for socket_name in spec_data.get("sockets", {}):
		var points: Array = []

		for p in spec_data["sockets"][socket_name]:
			points.append(Vector3(float(p[0]), float(p[1]), float(p[2])))

		sockets[StringName(socket_name)] = points

	_apply_settings(spec_data.get("burner", {}))
	_apply_settings(overrides)
	_build_model()
	_stretch()
	_hang()

	if sockets.has(&"flame"):
		flame_points = PackedVector3Array(sockets[&"flame"])

	if sockets.has(&"corona"):
		corona_point = socket(&"corona")

	if spec_data.get("soot", false) and spec_data.get("mount", "") == "wall":
		_place_soot.call_deferred()


## Burner settings from the recipe: exports by name; "color" as hex, "loop"
## as a name in audio/ambience/ ("" for silence).
func _apply_settings(settings: Dictionary) -> void:
	for key in settings:
		var value = settings[key]

		match key:
			"color":
				color = Color(value) if value is String else value
			"loop":
				loop_path = "" if String(value).is_empty() else "res://audio/ambience/%s.ogg" % value
			_:
				if key in self:
					set(key, value)


func _build_model() -> void:
	var path := FOLDER + String(fixture) + ".glb"

	if not ResourceLoader.exists(path):
		push_error("LightFixture: no model %s" % path)
		return

	model = (load(path) as PackedScene).instantiate()
	model.name = "Model"
	add_child(model)

	var shadowing: Array = spec_data.get("shadow_parts", [])

	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		var drawn := mesh as MeshInstance3D
		# Right under its own light, a part would throw a wedge of shadow over
		# everything below: only the parts the recipe names cast shadows.
		drawn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadowing.has(String(drawn.name)) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		for i in drawn.mesh.get_surface_count():
			var original := drawn.mesh.surface_get_material(i)
			var slot := String(original.resource_name) if original != null else ""

			if slot.ends_with("_glow"):
				drawn.set_surface_override_material(i, Materials.glowing(StringName(slot.trim_suffix("_glow"))))

				if not glow_meshes.has(drawn):
					glow_meshes.append(drawn)
					# Lit by its glow, not by its burner (Layers.GLOWING).
					drawn.layers = Layers.GLOWING
			else:
				drawn.set_surface_override_material(i, Materials.surface(StringName(slot)))

	for body in model.find_children("*", "CollisionObject3D", true, false):
		_bodies.append((body as CollisionObject3D).get_rid())


func _after_ready() -> void:
	if spec_data.get("cookie", false) and ResourceLoader.exists(COOKIE):
		# Its own frame's bars thrown round the walls.
		light.light_projector = load(COOKIE)

	_swinging = spec_data.get("mount", "") == "hang"
	_rest_basis = transform.basis


## A hung fixture hangs `hang_drop` below its hook on links of chain; it
## swings about the hook.
func _hang() -> void:
	if spec_data.get("mount", "") != "hang" or model == null or hang_drop <= 0.0:
		return

	model.position.y -= hang_drop

	for socket_name in [&"flame", &"corona"]:
		if sockets.has(socket_name):
			var lowered: Array = []

			for point in sockets[socket_name]:
				lowered.append(point - Vector3(0.0, hang_drop, 0.0))

			sockets[socket_name] = lowered

	if not ResourceLoader.exists(CHAIN_LINK):
		return

	var link_mesh: Mesh = null

	for mesh in (load(CHAIN_LINK) as PackedScene).instantiate().find_children("*", "MeshInstance3D", true, false):
		link_mesh = mesh.mesh

	if link_mesh == null:
		return

	for i in int(hang_drop / LINK_PITCH):
		var link := MeshInstance3D.new()
		link.name = "Link%d" % i
		link.mesh = link_mesh
		link.material_override = Materials.surface(&"chain")
		link.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(link)
		link.position = Vector3(0.0, -LINK_PITCH * i, 0.0)
		link.rotation.y = PI * 0.5 * (i % 2)


## How fast a hung fixture swings (rad/s): its creak (LightFixture sounds).
func swing_speed() -> float:
	return _spin.length()


## A stretching part (a cresset's pole) grows by `stretch`; everything above
## it, flames and halo too, rises with it; what stays on the floor stays.
func _stretch() -> void:
	var rule: Dictionary = spec_data.get("stretch", {})

	if is_zero_approx(stretch) or rule.is_empty() or model == null:
		return

	var length := float(rule.get("length", 1.0))
	var keep: Array = rule.get("keep", [])

	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		if String(mesh.name) == String(rule.get("part", "")):
			mesh.scale.y *= (length + stretch) / length
		elif not keep.has(String(mesh.name)):
			mesh.position.y += stretch

	for socket_name in [&"flame", &"corona"]:
		if sockets.has(socket_name):
			var raised: Array = []

			for point in sockets[socket_name]:
				raised.append(point + Vector3(0.0, stretch, 0.0))

			sockets[socket_name] = raised


## Soot up the wall above the flame (Arx Fatalis did this and it grounds a
## torch like nothing else), reaching the ceiling when it is near.
func _place_soot() -> void:
	if not is_inside_tree() or flame_points.is_empty():
		return

	var out := global_basis.z.normalized()
	var flame_world := global_transform * flame_points[0]
	var height := 0.9
	var space := get_world_3d().direct_space_state
	var up := PhysicsRayQueryParameters3D.create(flame_world, flame_world + Vector3.UP * 1.2, 1)
	var ceiling := space.intersect_ray(up)

	if not ceiling.is_empty():
		height = maxf(height, (ceiling["position"].y - flame_world.y) * 1.2)

	soot = Decal.new()
	soot.name = "Soot"
	soot.texture_albedo = SOOT
	soot.size = Vector3(0.5, 0.3, height)
	soot.cull_mask = Layers.WORLD_ALL
	# On the effects layer: the lightgem's cameras never see it.
	soot.layers = Layers.FX
	soot.upper_fade = 0.2
	soot.lower_fade = 0.2
	add_child(soot)
	# Its projection (-Y) into the wall, the image's top (-Z) up the wall.
	var z := Vector3.DOWN
	var y := out
	soot.global_basis = Basis(y.cross(z).normalized(), y, z)
	var wall := global_transform * socket(&"mount")
	soot.global_position = Vector3(wall.x, flame_world.y + height * 0.5 - 0.05, wall.z)


func _process(delta: float) -> void:
	super._process(delta)

	if _swinging:
		_swing(delta)

	if lit and not glow_meshes.is_empty():
		var ratio := clampf(light.light_energy / maxf(energy, 0.001), 0.0, 1.5)

		for mesh in glow_meshes:
			mesh.set_instance_shader_parameter(&"glow", ratio)


## A pendulum from its hook, pushed by the wind.
func _swing(delta: float) -> void:
	# The hook to the flame (its sockets already hang below by the chain).
	var length := maxf(absf(socket(&"flame").y), 0.2)
	var push := Vector2(_lean.x, _lean.z) * SWING_WIND
	var pull := -_tilt * (9.8 / length) + push - _spin * SWING_DAMPING
	_spin += pull * delta
	_tilt = (_tilt + _spin * delta).limit_length(SWING_MOST)
	# Its foot swings downwind: about Z for x, about X (against) for z.
	transform.basis = _rest_basis * Basis(Vector3.BACK, _tilt.x) * Basis(Vector3.RIGHT, -_tilt.y)


func _show_lit(state: StringName) -> void:
	for mesh in glow_meshes:
		mesh.set_instance_shader_parameter(&"heat_tint", color)

		match state:
			&"lit":
				mesh.set_instance_shader_parameter(&"glow", 1.0)
				mesh.set_instance_shader_parameter(&"charred", 0.0)
			&"cooling":
				mesh.set_instance_shader_parameter(&"glow", _cool)
				mesh.set_instance_shader_parameter(&"charred", 1.0 - _cool)
			_:
				mesh.set_instance_shader_parameter(&"glow", 0.0)
				mesh.set_instance_shader_parameter(&"charred", 1.0)


func _corona_exclude() -> Array[RID]:
	return _bodies
