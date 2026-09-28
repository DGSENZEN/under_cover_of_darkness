extends Node3D
## The rain round the camera: streaks falling through a box that follows it,
## slanted by the wind, stopped by roofs and overhangs (particle collision
## with a heightfield that follows the camera), a small splash where each
## lands. Night sets `amount` (0..1) and `wind` (m/s).

## The box the rain falls through round the camera (m), the most drops seen
## at once, how fast they fall (m/s) and how long each lives (s).
const BOX := Vector3(24.0, 12.0, 24.0)
const MOST := 7000
const FALL := 11.0
const LIFE := 1.3
## The wind leans the rain this much (per m/s).
const SLANT := 0.12
## How often the camera's shelter is looked for (s).
const SHELTER_EVERY := 0.25

var amount := 0.0
var wind := Vector3.ZERO
var _drops: GPUParticles3D
var _splashes: GPUParticles3D
var _field: GPUParticlesCollisionHeightField3D
var _falling: ParticleProcessMaterial
var _sheltered := false
var _shelter_in := 0.0


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_splashes = GPUParticles3D.new()
	_splashes.name = "Splashes"
	_splashes.amount = 600
	_splashes.lifetime = 0.25
	# (a sub-emitter is driven by the drops' collisions, but is only drawn
	# while emitting, and then throws a few of its own too: on only while it
	# rains, its own thrown far below the world)
	_splashes.emitting = false
	_splashes.local_coords = false
	# (a seed of its own: starting to emit would roll the world's dice)
	_splashes.use_fixed_seed = true
	_splashes.seed = 1901
	var splash := ParticleProcessMaterial.new()
	splash.direction = Vector3.UP
	splash.spread = 70.0
	splash.initial_velocity_min = 0.6
	splash.initial_velocity_max = 1.4
	splash.gravity = Vector3(0.0, -9.0, 0.0)
	splash.emission_shape_offset = Vector3(0.0, -1000.0, 0.0)
	_splashes.process_material = splash
	var dot := QuadMesh.new()
	dot.size = Vector2(0.05, 0.05)
	dot.material = _drop_material(Color(0.75, 0.8, 0.9, 0.5), true)
	_splashes.draw_pass_1 = dot
	add_child(_splashes)

	_drops = GPUParticles3D.new()
	_drops.name = "Drops"
	_drops.amount = MOST
	_drops.lifetime = LIFE
	_drops.local_coords = false
	_drops.emitting = false
	_drops.use_fixed_seed = true
	_drops.seed = 1902
	_drops.visibility_aabb = AABB(Vector3(-BOX.x, -BOX.y * 1.5, -BOX.z), Vector3(BOX.x * 2.0, BOX.y * 2.0, BOX.z * 2.0))
	_falling = ParticleProcessMaterial.new()
	_falling.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_falling.emission_box_extents = Vector3(BOX.x * 0.5, 0.3, BOX.z * 0.5)
	_falling.direction = Vector3.DOWN
	_falling.spread = 1.5
	_falling.initial_velocity_min = FALL
	_falling.initial_velocity_max = FALL * 1.15
	_falling.gravity = Vector3(0.0, -4.0, 0.0)
	_falling.particle_flag_align_y = true
	_falling.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT
	_falling.sub_emitter_mode = ParticleProcessMaterial.SUB_EMITTER_AT_COLLISION
	_falling.sub_emitter_amount_at_collision = 1
	_drops.process_material = _falling
	# Fine streaks, lit by what they fall past (a torch behind the rain turns
	# it to falling fire, the moon to silver), faint in the dark.
	var streak := BoxMesh.new()
	streak.size = Vector3(0.008, 0.7, 0.008)
	var streak_material := _drop_material(Color(0.8, 0.84, 0.92, 0.3), false)
	streak_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	streak_material.roughness = 0.25
	streak_material.backlight_enabled = true
	streak_material.backlight = Color(0.85, 0.88, 1.0)
	streak_material.emission_enabled = true
	streak_material.emission = Color(0.07, 0.08, 0.1)
	# Gone within a metre of the lens, whole from 3 m: no bars across a close
	# shot.
	streak_material.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	streak_material.distance_fade_min_distance = 1.0
	streak_material.distance_fade_max_distance = 3.0
	streak.material = streak_material
	_drops.draw_pass_1 = streak
	add_child(_drops)
	_drops.sub_emitter = _drops.get_path_to(_splashes)

	_field = GPUParticlesCollisionHeightField3D.new()
	_field.name = "Roofs"
	_field.size = Vector3(BOX.x + 4.0, 40.0, BOX.z + 4.0)
	_field.resolution = GPUParticlesCollisionHeightField3D.RESOLUTION_256
	_field.follow_camera_enabled = true
	_field.update_mode = GPUParticlesCollisionHeightField3D.UPDATE_MODE_WHEN_MOVED
	add_child(_field)


func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()

	if camera != null:
		global_position = camera.global_position + Vector3.UP * BOX.y * 0.5

	var raining := amount > 0.01
	_drops.emitting = raining
	_splashes.emitting = raining
	_drops.amount_ratio = clampf(amount, 0.0, 1.0)
	_field.visible = raining
	_falling.gravity = Vector3(wind.x * SLANT * FALL, -4.0, wind.z * SLANT * FALL)
	_shelter_in -= delta

	if _shelter_in <= 0.0 and camera != null:
		_shelter_in = SHELTER_EVERY
		var from := camera.global_position
		var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.UP * 30.0, 1)
		query.collide_with_areas = false
		_sheltered = not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## Whether the camera has a roof over it (the rain heard indoors).
func sheltered() -> bool:
	return _sheltered


static func _drop_material(colour: Color, billboard: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = colour
	material.vertex_color_use_as_albedo = true

	if billboard:
		material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES

	return material
