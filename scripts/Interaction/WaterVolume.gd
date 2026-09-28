extends Area3D
## A body of water: a box, its top the surface (the node's origin is the
## middle of the box, `size` its extent, not turned). What it does:
##   deep       deeper than a man can stand in (SWIM_DEPTH): he swims. The
##              player floats with his eyes above the surface, dives and comes
##              up; a guard swims after you along its own navmesh (NavBaker
##              bakes one per body of water, dearer to cross than land) and
##              climbs out where the bank is low enough (NavLinks).
##   shallow    up to the thigh: slow going, and every step splashes.
##   splash     anything coming into it fast is heard (SoundBus) and seen.
##   afloat     loose things (a crate, a stool) float, and are slowed.
##   murk       under the surface you are hard to see.
## Levels place them with build() or as nodes with a BoxShape3D child; the
## navmesh must be baked after (NavBaker does it on load).
##
##   WaterVolume.build(parent, centre, size)
##   WaterVolume.at(tree, point)   the water `point` is in, or null

const Sfx := preload("res://scripts/Audio/Sfx.gd")
const Fx := preload("res://scripts/Visual/Fx.gd")
const SoundBus := preload("res://scripts/StimuliSystem/SoundBus.gd")

## Deeper than this (m, surface to bottom) a man swims: his feet no longer
## keep him where he wants to be.
const SWIM_DEPTH := 1.3
## Slower than this (m/s) into the water is no splash.
const SPLASH_SPEED := 2.0
## A floating thing rides this far into the water, and water slows it.
const FLOAT_SINK := 0.6
const WATER_DRAG := 2.5

## The box: width, depth (top to bottom), length.
@export var size := Vector3(6.0, 2.0, 6.0)
## How much of what is under the surface can be seen (0 none, 1 clear).
@export_range(0.0, 1.0, 0.05) var clarity := 0.25
@export var tint := Color(0.1, 0.2, 0.22, 0.72)

var _floating: Array[RigidBody3D] = []
var _surface_mesh: MeshInstance3D
## Ripples (ripple()): a ripple this many metres along, drawn out this many
## times the other way; a canal's flow (m/s); the normal map's size and
## strength.
const RIPPLE_TILE := 3.0
const RIPPLE_STRETCH := 6.0
const CANAL_FLOW := 0.08
const RIPPLE_TEXELS := 128
const RIPPLE_STRENGTH := 6.0
const SHADER := preload("res://scripts/Visual/water.gdshader")
## The night sky seen in it at a glancing look: overhead, and low.
const SKY_ZENITH := Color(0.03, 0.04, 0.075)
const SKY_HORIZON := Color(0.09, 0.1, 0.13)
## The lights that stand in it as columns: at most this many, this near its
## sides (m) and not this far over its surface (m); a column carries about
## this far (m) for each unit of the light's energy, at most COLUMN_FAR.
const COLUMNS := 16
const COLUMN_REACH := 14.0
const COLUMN_HIGH := 12.0
const COLUMN_CARRY := 6.0
const COLUMN_FAR := 18.0
var _columns: Array[Light3D] = []
var _paint: ShaderMaterial
var _night: Node = null


## Water filling a `size` box centred on `centre`, its top the surface.
static func build(parent: Node, centre: Vector3, box_size: Vector3) -> Area3D:
	var water: Area3D = (load("res://scripts/Interaction/WaterVolume.gd") as GDScript).new()
	water.name = "Water"
	water.size = box_size
	parent.add_child(water)
	water.global_position = centre
	return water


## The water `point` is in (below its surface, above its bottom, inside it),
## or null. `above`: count this far over the surface as in it (a man's feet
## just clear of it).
static func at(tree: SceneTree, point: Vector3, above := 0.0) -> Area3D:
	for water in tree.get_nodes_in_group(&"water"):
		if water.has_method("holds") and water.holds(point, above):
			return water

	return null


func _ready() -> void:
	add_to_group(&"water")
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 1 | 2 | 4

	if get_node_or_null("Shape") == null:
		var shape := CollisionShape3D.new()
		shape.name = "Shape"
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		add_child(shape)

	_build_surface()
	# The level's lights are made after the water: gathered once they are.
	get_tree().create_timer(0.5).timeout.connect(gather_lights)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


## The height of the surface.
func surface_y() -> float:
	return global_position.y + size.y * 0.5


## The height of the bottom of the box (the water's floor is whatever level
## geometry is under the surface: floor_under).
func bottom_y() -> float:
	return global_position.y - size.y * 0.5


## The box seen from above: its corners, in the world.
func footprint() -> PackedVector3Array:
	var half := Vector3(size.x * 0.5, 0.0, size.z * 0.5)
	var c := Vector3(global_position.x, surface_y(), global_position.z)
	return PackedVector3Array([c + Vector3(-half.x, 0, -half.z), c + Vector3(half.x, 0, -half.z), c + Vector3(half.x, 0, half.z), c + Vector3(-half.x, 0, half.z)])


## `point` is over the box (seen from above), `margin` in from its sides.
func over(point: Vector3, margin := 0.0) -> bool:
	return absf(point.x - global_position.x) <= size.x * 0.5 - margin and absf(point.z - global_position.z) <= size.z * 0.5 - margin


## `point` is in the water: over it, below its surface (or at most `above`
## over it), and above the bottom of the box.
func holds(point: Vector3, above := 0.0) -> bool:
	return over(point) and point.y <= surface_y() + above and point.y >= bottom_y() - 0.05


## How far below the surface `point` is (negative: above it).
func depth_of(point: Vector3) -> float:
	return surface_y() - point.y


## The floor under the water at `point` (a ray down from the surface), or
## the bottom of the box if nothing is there.
func floor_under(point: Vector3, exclude: Array[RID] = []) -> float:
	var from := Vector3(point.x, surface_y() + 0.05, point.z)
	var to := Vector3(point.x, bottom_y() - 0.5, point.z)
	var query := PhysicsRayQueryParameters3D.create(from, to, 1, exclude)
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return (hit["position"] as Vector3).y if not hit.is_empty() else bottom_y()


## Too deep there to stand in (SWIM_DEPTH).
func deep_at(point: Vector3) -> bool:
	return surface_y() - floor_under(point) > SWIM_DEPTH


## Something went in at `at`, this fast: a splash, heard as far as it was
## hard (`db` over the base), and a spray.
func splash(at: Vector3, speed: float, body: Node = null) -> void:
	var on_top := Vector3(at.x, surface_y(), at.z)
	var hard := clampf((speed - SPLASH_SPEED) / 8.0, 0.0, 1.0)
	var db := 48.0 + 22.0 * hard
	Sfx.play(self, &"land_water" if speed > 5.0 else &"jump_water", on_top, Sfx.loudness(db))
	Fx.dust(self, on_top, Vector3.UP, 0.5 + 1.2 * hard, "water")
	SoundBus.emit_sound(on_top, db, body if body != null else self, &"splash")


func _on_body_entered(body: Node3D) -> void:
	if body is RigidBody3D and not (body as RigidBody3D).freeze:
		if not _floating.has(body):
			_floating.append(body)

	var going: Variant = body.get("velocity") if not (body is RigidBody3D) else (body as RigidBody3D).linear_velocity

	if going is Vector3 and (going as Vector3).y < -SPLASH_SPEED:
		splash(body.global_position, -(going as Vector3).y, body)

	# The player keeps the waters he is in, rather than asking every tick.
	if body.has_method("add_water_volume"):
		body.add_water_volume(self)


func _on_body_exited(body: Node3D) -> void:
	if body is RigidBody3D:
		_floating.erase(body as RigidBody3D)

	if body.has_method("remove_water_volume"):
		body.remove_water_volume(self)


## Loose things float: pushed up by as much of them as is under, and
## slowed by the water.
func _physics_process(delta: float) -> void:
	for i in range(_floating.size() - 1, -1, -1):
		var thing: RigidBody3D = _floating[i]

		if not is_instance_valid(thing) or thing.freeze or not thing.is_inside_tree():
			_floating.remove_at(i)
			continue

		var under := clampf((surface_y() - thing.global_position.y) / FLOAT_SINK + 0.5, 0.0, 1.0)

		if under <= 0.0:
			continue

		var gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)) * thing.gravity_scale
		thing.apply_central_force(Vector3.UP * gravity * thing.mass * 1.6 * under)
		thing.linear_velocity = thing.linear_velocity.move_toward(Vector3.ZERO, WATER_DRAG * under * delta)
		thing.angular_velocity = thing.angular_velocity.move_toward(Vector3.ZERO, WATER_DRAG * under * delta)


## Ripples on the surface drawn out into streaks (a canal at night): packed
## `stretch` times closer across it than along it, so lights on it draw out
## toward the eye; `tile` metres a ripple along it; it flows along its length
## at `drift` m/s.
func ripple(tile := RIPPLE_TILE, stretch := RIPPLE_STRETCH, drift := CANAL_FLOW) -> void:
	if _paint == null:
		return

	_paint.set_shader_parameter(&"tile", tile)
	_paint.set_shader_parameter(&"stretch", stretch)
	_paint.set_shader_parameter(&"flow", (Vector2(1.0, 0.0) if size.x >= size.z else Vector2(0.0, 1.0)) * drift)


## The night on the water: rain rings it; the sky in it as bright as the moon
## lets.
func _process(_delta: float) -> void:
	if _paint == null:
		return

	_show_columns()

	if _night == null or not is_instance_valid(_night):
		_night = get_tree().get_first_node_in_group(&"night")

		if _night == null:
			return

	if _night.has_method(&"rain"):
		_paint.set_shader_parameter(&"rain", clampf(float(_night.rain()), 0.0, 1.0))

	if _night.has_method(&"moon_share"):
		_paint.set_shader_parameter(&"sky_light", clampf(0.45 + 0.55 * float(_night.moon_share()), 0.0, 2.0))


## The lamps and torches by it (Light3D within COLUMN_REACH of its sides, not
## effects), nearest first, found once the level has lit them.
func gather_lights() -> void:
	_columns.clear()
	var found := []

	for node in get_tree().root.find_children("*", "Light3D", true, false):
		var light := node as Light3D

		if light is DirectionalLight3D or light.is_in_group(&"fx_light"):
			continue

		var at := light.global_position
		var outside := Vector2(maxf(absf(at.x - global_position.x) - size.x * 0.5, 0.0), maxf(absf(at.z - global_position.z) - size.z * 0.5, 0.0)).length()
		var over := at.y - surface_y()

		if outside <= COLUMN_REACH and over > 0.0 and over <= COLUMN_HIGH:
			found.append([outside, light])

	found.sort_custom(func(a, b): return a[0] < b[0])

	for pair in found.slice(0, COLUMNS):
		_columns.append(pair[1])

	_show_columns()


## Each light's column as it is lit now (a torch flickers, a lamp douses).
func _show_columns() -> void:
	var places := PackedVector4Array()
	var colours := PackedVector4Array()
	places.resize(COLUMNS)
	colours.resize(COLUMNS)
	var n := 0

	for light in _columns:
		if not is_instance_valid(light) or not light.is_visible_in_tree() or light.light_energy <= 0.0:
			continue

		var c := light.light_color * light.light_energy
		places[n] = Vector4(light.global_position.x, light.global_position.y, light.global_position.z, 0.0)
		colours[n] = Vector4(c.r, c.g, c.b, minf(COLUMN_CARRY * light.light_energy, COLUMN_FAR))
		n += 1

	_paint.set_shader_parameter(&"lights", places)
	_paint.set_shader_parameter(&"light_colours", colours)
	_paint.set_shader_parameter(&"light_count", n)


## The surface, seen from above and below; the depth darkens toward the
## bottom as murk.
func _build_surface() -> void:
	_paint = ShaderMaterial.new()
	_paint.shader = SHADER
	_paint.set_shader_parameter(&"ripples", _noise(RIPPLE_TEXELS, 0.02, 71, true))
	_paint.set_shader_parameter(&"patches", _noise(64, 0.05, 29, false))
	_paint.set_shader_parameter(&"deep", Color(tint.r * 0.14, tint.g * 0.12, tint.b * 0.1))
	_paint.set_shader_parameter(&"half_size", Vector2(size.x, size.z) * 0.5)
	# Still water, rippled every way alike (a canal's streaks: ripple()), the
	# night sky in it.
	_paint.set_shader_parameter(&"tile", RIPPLE_TILE)
	_paint.set_shader_parameter(&"stretch", 1.0)
	_paint.set_shader_parameter(&"flow", Vector2(0.02, 0.0))
	_paint.set_shader_parameter(&"sky_zenith", SKY_ZENITH)
	_paint.set_shader_parameter(&"sky_horizon", SKY_HORIZON)
	_paint.set_shader_parameter(&"sky_light", 1.0)
	_paint.set_shader_parameter(&"rain", 0.0)
	var plane := PlaneMesh.new()
	plane.size = Vector2(size.x, size.z)
	_surface_mesh = MeshInstance3D.new()
	_surface_mesh.name = "Surface"
	_surface_mesh.mesh = plane
	_surface_mesh.material_override = _paint
	_surface_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_surface_mesh.position = Vector3(0.0, size.y * 0.5 - 0.02, 0.0)
	add_child(_surface_mesh)

	# The murk: a box of darker water under the surface.
	var murk := StandardMaterial3D.new()
	murk.albedo_color = Color(tint.r * 0.6, tint.g * 0.6, tint.b * 0.6, 1.0 - clarity)
	murk.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	murk.cull_mode = BaseMaterial3D.CULL_DISABLED
	murk.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var box := BoxMesh.new()
	box.size = Vector3(size.x - 0.02, size.y - 0.06, size.z - 0.02)
	box.material = murk
	var depth := MeshInstance3D.new()
	depth.name = "Murk"
	depth.mesh = box
	depth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	depth.position = Vector3(0.0, -0.02, 0.0)
	add_child(depth)


## Seamless noise: a normal map (the ripples) or plain (the duckweed's
## patches).
static func _noise(texels: int, frequency: float, seed: int, normal: bool) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency
	noise.seed = seed
	var texture := NoiseTexture2D.new()
	texture.width = texels
	texture.height = texels
	texture.seamless = true
	texture.generate_mipmaps = true
	texture.noise = noise

	if normal:
		texture.as_normal_map = true
		texture.bump_strength = RIPPLE_STRENGTH

	return texture
