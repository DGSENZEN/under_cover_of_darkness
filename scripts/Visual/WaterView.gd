extends Node3D
## One camera-dependent water pass per viewport. Lives beyond a level so replacing
## a volume or scene cannot strand a tint on the next camera.
const Water := preload("res://scripts/Interaction/WaterVolume.gd")
const OPTICS := preload("res://scripts/Visual/underwater.gdshader")
const Fx := preload("res://scripts/Visual/Fx.gd")
var active_water: Area3D
var ray_strength := 0.0
var visible_effect := false
var _quad: MeshInstance3D
var _material: ShaderMaterial
## What hangs in the water round the eye when under (specks drifting, faint,
## fading a few metres off): MOTES of them in a cube MOTE_SPAN m a side that
## wraps round the camera.
const MOTES := 160
const MOTE_SPAN := 10.0
const MOTE_SIZE := 0.022
var _motes: MultiMeshInstance3D
var _mote_seeds: Array[Vector3] = []
var _mote_drift: Array[Vector3] = []
var _clock := 0.0

## Schedules one WaterView child for viewport, guarded by a pending metadata flag.
## The view survives level replacement and tracks the active camera/water; null viewport is not supported.
static func ensure(viewport: Viewport) -> void:
	if viewport.get_node_or_null("WaterView") != null or viewport.has_meta("water_view_pending"):
		return
	var view: Node3D = (load("res://scripts/Visual/WaterView.gd") as GDScript).new()
	view.name = "WaterView"
	viewport.set_meta("water_view_pending", true)
	viewport.add_child.call_deferred(view)

func _ready() -> void:
	get_viewport().remove_meta("water_view_pending")
	_material = ShaderMaterial.new()
	_material.shader = OPTICS
	# Draw before particles and hands; the screen copy contains opaque geometry.
	_material.render_priority = -127
	_material.set_shader_parameter("caustics", Water._noise(128, 0.055, 821, false))
	_quad = MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(2, 2)
	_quad.mesh = mesh
	_quad.material_override = _material
	_quad.layers = 1 << 18 # Main camera only; lightgem probes exclude this layer.
	_quad.extra_cull_margin = 16384.0
	_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_quad.visible = false
	add_child(_quad)
	_make_motes()


func _make_motes() -> void:
	var look := StandardMaterial3D.new()
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	look.billboard_keep_scale = true
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.albedo_color = Color(0.55, 0.62, 0.58, 0.32)
	look.albedo_texture = Fx.texture(&"puff")
	look.disable_fog = true
	# (Fading out as they get further: min past max reverses the fade.)
	look.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	look.distance_fade_min_distance = MOTE_SPAN * 0.5
	look.distance_fade_max_distance = 0.6
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * MOTE_SIZE
	quad.material = look
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = quad
	multi.instance_count = MOTES
	_motes = MultiMeshInstance3D.new()
	_motes.name = "Motes"
	_motes.multimesh = multi
	_motes.layers = 1 << 18
	_motes.top_level = true
	_motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_motes.extra_cull_margin = 16384.0
	_motes.visible = false
	add_child(_motes)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711

	for i in MOTES:
		_mote_seeds.append(Vector3(rng.randf(), rng.randf(), rng.randf()) * MOTE_SPAN)
		_mote_drift.append(Vector3(rng.randf_range(-0.06, 0.06), rng.randf_range(-0.02, 0.03), rng.randf_range(-0.06, 0.06)))


## The specks round the eye (each wrapped into the cube about it), drifting;
## none over the surface (`surface`).
func _drift_motes(eye: Vector3, delta: float, surface: float) -> void:
	_clock += delta

	for i in MOTES:
		var p := _mote_seeds[i] + _mote_drift[i] * _clock + Vector3(sin(_clock * 0.4 + i), 0.0, cos(_clock * 0.3 + i * 1.7)) * 0.05
		var wrapped := Vector3(fposmod(p.x - eye.x, MOTE_SPAN), fposmod(p.y - eye.y, MOTE_SPAN), fposmod(p.z - eye.z, MOTE_SPAN)) - Vector3.ONE * MOTE_SPAN * 0.5
		var at := eye + wrapped
		_motes.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY if at.y < surface - 0.05 else Basis.from_scale(Vector3.ZERO), at))

func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	active_water = null
	if camera != null:
		for water in get_tree().get_nodes_in_group("water"):
			if water is Area3D and water.get_world_3d() == camera.get_world_3d() and water.has_method("holds") and water.holds(camera.global_position):
				active_water = water
				break
	visible_effect = active_water != null
	_quad.visible = visible_effect
	_motes.visible = visible_effect
	ray_strength = 0.0
	if not visible_effect:
		return
	global_transform = camera.global_transform
	var eye := camera.global_position
	_drift_motes(eye, _delta, active_water.surface_y())
	var direction: Vector3 = active_water.moon_direction()
	var inside := -Vector3(-direction.x / 1.333, -sqrt(maxf(0.0, 1.0 - (direction.x * direction.x + direction.z * direction.z) / (1.333 * 1.333))), -direction.z / 1.333)
	var surface: float = active_water.surface_y()
	var entry := eye + inside * ((surface - eye.y) / maxf(inside.y, 0.01))
	var access := 0.0
	if direction.y > 0.02 and active_water.over(entry):
		var query := PhysicsRayQueryParameters3D.create(entry + direction * 0.08, entry + direction * 80.0, 1)
		query.collide_with_areas = false
		if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			access = active_water.moon_visibility()
	var toward := clampf((-camera.global_basis.z).dot(inside), 0.0, 1.0)
	ray_strength = access * smoothstep(0.1, 0.95, toward)
	_material.set_shader_parameter("ray_strength", ray_strength)
	_material.set_shader_parameter("moon_inside", inside)
	_material.set_shader_parameter("surface_y", surface)
	_material.set_shader_parameter("water_bottom", active_water.bottom_y())
	_material.set_shader_parameter("water_center", Vector2(active_water.global_position.x, active_water.global_position.z))
	_material.set_shader_parameter("half_size", Vector2(active_water.size.x, active_water.size.z) * 0.5)
	_material.set_shader_parameter("clarity", active_water.clarity)
	_material.set_shader_parameter("water_tint", Color(active_water.tint.r, active_water.tint.g, active_water.tint.b))
	_material.set_shader_parameter("moon_colour", active_water.moon_colour())
	_material.set_shader_parameter("water_clock", active_water.render_clock)
