extends Node3D
## One camera-dependent water pass per viewport. Lives beyond a level so replacing
## a volume or scene cannot strand a tint on the next camera.
const Water := preload("res://scripts/Interaction/WaterVolume.gd")
const OPTICS := preload("res://scripts/Visual/underwater.gdshader")
var active_water: Area3D
var ray_strength := 0.0
var visible_effect := false
var _quad: MeshInstance3D
var _material: ShaderMaterial

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
	ray_strength = 0.0
	if not visible_effect:
		return
	global_transform = camera.global_transform
	var eye := camera.global_position
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
