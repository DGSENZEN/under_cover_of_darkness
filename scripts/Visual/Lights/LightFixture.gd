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
const LanternBody := preload("res://scripts/Visual/Lights/LanternBody.gd")
## A chain link's length along its chain.
const LINK_PITCH := 0.054
## A hung fixture's swing: gravity, damping, how hard the wind pushes it
## (rad/s^2 at full wind), and the most it swings.
const SWING_DAMPING := 1.5
const SWING_WIND := 0.8
const SWING_MOST := 0.5
## One solid lantern body, rather than simulating every chain link.
const LANTERN_MASS := 1.8
## A hung fixture creaks as it swings faster than this (rad/s, as it passes
## it), at most every CREAK_EVERY s.
const CREAK_SPEED := 0.15
const CREAK_EVERY := 0.8
## A hearth's chimney draw, under its fire's loop.
const CHIMNEY_DB := -20.0
## Candles feel a draft from a man moving faster than DRAFT_SPEED within
## DRAFT_REACH, or a door swinging within DRAFT_DOOR; they look DRAFT_EVERY.
const DRAFT_SPEED := 3.0
const DRAFT_REACH := 1.5
const DRAFT_DOOR := 3.0
const DRAFT_EVERY := 0.25
## Candles and oil lamps fade out between these distances (their light).
const SMALL_FADE_FROM := 20.0
const SMALL_FADE_OVER := 5.0
const HAZE_SHADER := preload("res://scripts/Visual/Lights/haze.gdshader")
## Heat haze only within this of the camera.
const HAZE_REACH := 15.0

## Which fixture (assets/props/lights/<fixture>.glb / .json).
@export var fixture := &""
## Burner settings laid over the fixture's own (export name -> value).
var overrides := {}
## Metres its stretching part grows (a pole cresset fitted to its place).
var stretch := 0.0
## A hung fixture: metres of chain between its hook (its origin) and it.
var hang_drop := 0.0
## A fixture made with a cookie throws its frame's bars; false (in its
## overrides) takes them off, its light then reaching all round.
var cookie := true

var model: Node3D
## socket name -> its points in the fixture's space.
var sockets := {}
var glow_meshes: Array[GeometryInstance3D] = []
## The glow its meshes were last told while lit (-1: tell them again).
var _sent_glow := -1.0
var soot: Decal
## A big fire's heat haze (null for other fixtures).
var haze: MeshInstance3D
## A hearth's chimney draw (null for other fixtures, or with sound off), and
## its loop's path (the recipe's "chimney", a name in audio/ambience/).
var chimney: AudioStreamPlayer3D
var chimney_path := ""
var spec_data := {}
var _tilt := Vector2.ZERO
var _spin := Vector2.ZERO
## Its turn as placed, found on its first swing (builders place it after
## adding it), in the world's frame: the wind tilts it about world axes.
var _rest_basis := Basis.IDENTITY
var _rest_known := false
## Physics ticks until its soot goes up (its walls may be built this frame,
## and are only in the physics space once it has stepped), -1 for none.
var _soot_in := -1
var _swinging := false
var _draft_clock := 0.0
var _door_angles := {}
var _creak_wait := 0.0
var _was_fast := false
## Physics owns the hanging lantern pose; the burner follows it as a whole.
var swing_body: RigidBody3D
var _swing_center := Vector3.ZERO

static var _specs := {}
static var _link_mesh: Mesh = null
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
		_soot_in = 2


## Burner settings from the recipe: exports by name; "color" as hex, "loop"
## and "chimney" as names in audio/ambience/ ("" for silence).
func _apply_settings(settings: Dictionary) -> void:
	for key in settings:
		var value = settings[key]

		match key:
			"color":
				color = Color(value) if value is String else value
			"loop":
				loop_path = _ambience(String(value))
			"chimney":
				chimney_path = _ambience(String(value))
			_:
				if key in self:
					var current = get(key)

					# JSON has lists where the burner has vectors.
					if value is Array and current is Vector2:
						value = Vector2(float(value[0]), float(value[1]))
					elif value is Array and current is Vector3:
						value = Vector3(float(value[0]), float(value[1]), float(value[2]))

					set(key, value)


## A loop by name in audio/ambience/ (a looping WAV or an OGG); "" for none.
static func _ambience(loop_name: String) -> String:
	if loop_name.is_empty():
		return ""

	for extension in ["wav", "ogg"]:
		var path := "res://audio/ambience/%s.%s" % [loop_name, extension]

		if ResourceLoader.exists(path):
			return path

	return ""


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
					_sent_glow = -1.0
					# Lit by its glow, not by its burner (Layers.GLOWING).
					drawn.layers = Layers.GLOWING
			else:
				drawn.set_surface_override_material(i, Materials.surface(StringName(slot)))

	for body in model.find_children("*", "CollisionObject3D", true, false):
		_bodies.append((body as CollisionObject3D).get_rid())


func _after_ready() -> void:
	if spec_data.get("cookie", false) and cookie and ResourceLoader.exists(COOKIE):
		# Its own frame's bars thrown round the walls.
		light.light_projector = load(COOKIE)

	_swinging = spec_data.get("mount", "") == "hang"
	if fixture == &"wall_lantern":
		_make_lantern_body(false)

	if spec_data.get("family", "") == "fires":
		_make_haze()

	_make_chimney()

	if spec_data.get("family", "") == "candles":
		light.distance_fade_enabled = true
		light.distance_fade_begin = SMALL_FADE_FROM
		light.distance_fade_length = SMALL_FADE_OVER


func _make_haze() -> void:
	haze = MeshInstance3D.new()
	haze.name = "Haze"
	var quad := QuadMesh.new()
	quad.size = Vector2(0.6, 0.9)
	haze.mesh = quad
	var look := ShaderMaterial.new()
	look.shader = HAZE_SHADER
	haze.material_override = look
	haze.layers = Layers.FX
	haze.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(haze)
	haze.position = flame_points[0] + Vector3(0.0, flame_size + 0.45, 0.0)
	haze.visible = false


## A hearth's chimney: the slow draw of air up it, heard from the top of its
## masonry whenever its fire's loop is.
func _make_chimney() -> void:
	if crackle == null or chimney_path.is_empty():
		return

	chimney = AudioStreamPlayer3D.new()
	chimney.name = "Chimney"
	chimney.stream = load(chimney_path)
	chimney.bus = crackle.bus
	chimney.unit_size = crackle.unit_size
	chimney.max_distance = loop_reach
	chimney.volume_db = CHIMNEY_DB
	chimney.max_db = 0.0
	chimney.attenuation_filter_db = Sfx.AIR_DB
	chimney.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
	var under := flame_points[0] if not flame_points.is_empty() else Vector3.ZERO
	chimney.position = Vector3(under.x, _model_top(), under.z)
	add_child(chimney)


## The top of its model, in its own space.
func _model_top() -> float:
	var top := 0.0

	if model == null:
		return top

	var to_self := global_transform.affine_inverse()

	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = (to_self * (mesh as MeshInstance3D).global_transform) * (mesh as MeshInstance3D).get_aabb()
		top = maxf(top, box.end.y)

	return top


## Its chimney plays with its fire's loop, as muffled.
func _draw_chimney() -> void:
	if crackle.playing and not chimney.playing:
		chimney.play(randf() * maxf(chimney.stream.get_length() - 1.0, 0.0))
	elif not crackle.playing and chimney.playing:
		chimney.stop()

	chimney.volume_db = CHIMNEY_DB + crackle.volume_db - loop_db
	chimney.attenuation_filter_cutoff_hz = crackle.attenuation_filter_cutoff_hz


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

	var link_mesh := _chain_link_mesh()

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


## The chain link's mesh, read once (its scene freed straight after).
static func _chain_link_mesh() -> Mesh:
	if _link_mesh == null and ResourceLoader.exists(CHAIN_LINK):
		var scene := (load(CHAIN_LINK) as PackedScene).instantiate()

		for mesh in scene.find_children("*", "MeshInstance3D", true, false):
			_link_mesh = (mesh as MeshInstance3D).mesh

		scene.free()

	return _link_mesh


## How fast a hung fixture swings (rad/s): its creak (LightFixture sounds).
func swing_speed() -> float:
	if swing_body != null:
		return 0.0 if swing_body.sleeping else swing_body.angular_velocity.length()
	return _spin.length()


## The enclosed lamp is solid; its chain and mounting hardware are not a
## giant collision box. These local bounds follow the actual exported model.
func _lantern_shape() -> CollisionShape3D:
	var bounds := AABB()
	var found := false
	var to_self := global_transform.affine_inverse()
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		if String(mesh.name) not in ["base", "panes", "roof"]:
			continue
		var part: AABB = (to_self * mesh.global_transform) * mesh.get_aabb()
		bounds = bounds.merge(part) if found else part
		found = true
	if not found:
		return null
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = bounds.size
	shape.shape = box
	shape.position = bounds.get_center()
	return shape


func _make_lantern_body(hanging: bool) -> void:
	if model == null:
		return
	var shape := _lantern_shape()
	if shape == null:
		return
	var body: PhysicsBody3D
	if hanging:
		swing_body = LanternBody.new()
		swing_body.mass = LANTERN_MASS
		swing_body.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
		swing_body.angular_damp = SWING_DAMPING
		swing_body.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
		swing_body.linear_damp = SWING_DAMPING
		# Keep the body origin at its weight, with the joint above it. This
		# gives the solver a centered hull and the correct pendulum lever arm.
		_swing_center = shape.position
		shape.position = Vector3.ZERO
		swing_body.continuous_cd = true
		# Moving the burner must never move the simulated body a second time.
		swing_body.top_level = true
		swing_body.transform = global_transform * Transform3D(Basis.IDENTITY, _swing_center)
		body = swing_body
	else:
		body = StaticBody3D.new()
	body.name = "LanternBody"
	body.collision_layer = 1
	body.collision_mask = 1
	body.set_meta(&"surface", "metal")
	body.add_child(shape)
	add_child(body)
	_bodies.append(body.get_rid())
	# The light is inside the solid lamp. Its own hull must never block the
	# guards' light calculation or its halo; unrelated walls still block it.
	light.set_meta(&"occlusion_exclude", _bodies.duplicate())
	_carriers_known = false
	if not hanging:
		return
	var joint := Generic6DOFJoint3D.new()
	joint.name = "LanternHook"
	joint.top_level = true
	joint.transform = global_transform
	# Empty node_a anchors this joint to the world. Translation is locked;
	# two axes swing, while yaw stays at the fixture's placed orientation.
	joint.node_b = body.get_path()
	for axis in ["x", "z"]:
		joint.set("angular_limit_%s/lower_angle" % axis, -SWING_MOST)
		joint.set("angular_limit_%s/upper_angle" % axis, SWING_MOST)
	add_child(joint)


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


func _physics_process(delta: float) -> void:
	# Builders place fixtures immediately after adding them. Make the joint
	# on the first physics tick, once its actual hook position is known.
	if fixture == &"hanging_lantern" and swing_body == null:
		_make_lantern_body(true)
	if swing_body != null:
		var wind := Vector3(_lean.x, 0.0, _lean.z).limit_length(3.0)
		if wind.length_squared() > 0.0001:
			swing_body.sleeping = false
			swing_body.apply_central_force(wind * LANTERN_MASS * SWING_WIND)
		global_transform = swing_body.global_transform * Transform3D(Basis.IDENTITY, -_swing_center)
		_creak(delta)
	super._physics_process(delta)

	if _soot_in > 0:
		_soot_in -= 1

		if _soot_in == 0:
			_place_soot()


func _process(delta: float) -> void:
	super._process(delta)

	if _swinging and fixture != &"hanging_lantern":
		_swing(delta)

	if flicker_kind == &"candle":
		_watch_drafts(delta)

	if chimney != null:
		_draw_chimney()

	if haze != null:
		var camera := get_viewport().get_camera_3d()
		haze.visible = lit and camera != null and camera.global_position.distance_to(global_position) < HAZE_REACH

	if lit and not glow_meshes.is_empty():
		var ratio := clampf(light.light_energy / _made_energy, 0.0, 1.5)

		# Told only when it has changed enough to see (every call is a trip
		# to the renderer, for every mesh of every fixture, every frame).
		if absf(ratio - _sent_glow) > 0.01:
			_sent_glow = ratio

			for mesh in glow_meshes:
				mesh.set_instance_shader_parameter(&"glow", ratio)


## A man hurrying past or a door swung near makes a candle shiver.
func _watch_drafts(delta: float) -> void:
	_draft_clock -= delta

	if _draft_clock > 0.0:
		return

	_draft_clock = DRAFT_EVERY
	var here := global_position

	for group in [&"player", &"guards"]:
		for body in get_tree().get_nodes_in_group(group):
			if body is CharacterBody3D:
				var off: Vector3 = body.global_position - here
				var speed := Vector2(body.velocity.x, body.velocity.z).length()

				if Vector2(off.x, off.z).length() < DRAFT_REACH and absf(off.y) < 2.0 and speed > DRAFT_SPEED:
					draft()
					return

	for door in get_tree().get_nodes_in_group(&"doors"):
		if door is Node3D and door.global_position.distance_to(here) < DRAFT_DOOR:
			var angle: float = door.rotation.y

			if _door_angles.has(door) and absf(angle - float(_door_angles[door])) > 0.02:
				draft()

			_door_angles[door] = angle


## A pendulum from its hook, pushed by the wind.
func _swing(delta: float) -> void:
	if not _rest_known:
		_rest_known = true
		_rest_basis = global_basis

	# The hook to the flame (its sockets already hang below by the chain).
	var length := maxf(absf(socket(&"flame").y), 0.2)
	var push := Vector2(_lean.x, _lean.z) * SWING_WIND
	var pull := -_tilt * (9.8 / length) + push - _spin * SWING_DAMPING
	_spin += pull * delta
	_tilt = (_tilt + _spin * delta).limit_length(SWING_MOST)
	# Its foot swings downwind (about Z for x, about X, against, for z),
	# whichever way it was turned.
	global_basis = Basis(Vector3.BACK, _tilt.x) * Basis(Vector3.RIGHT, -_tilt.y) * _rest_basis
	# A gust that sets it swinging: its chain creaks.
	_creak(delta)


func _creak(delta: float) -> void:
	_creak_wait = maxf(_creak_wait - delta, 0.0)
	var fast := swing_speed() > CREAK_SPEED

	if fast and not _was_fast and _creak_wait <= 0.0:
		_creak_wait = CREAK_EVERY
		Sfx.play(self, &"lantern_creak", global_position, 0.0)

	_was_fast = fast


func _show_lit(state: StringName) -> void:
	_sent_glow = -1.0

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
