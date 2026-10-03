extends Area3D
## Axis-aligned water Area3D; origin is box centre, size is full XYZ extent.
## Its top is the surface; terrain below determines standable depth. Water
## registers movement contacts, floats loose bodies, emits splashes, and
## provides shoreline/light data to shaders. Bake navigation after placement.

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
const SHORE_SHADER := preload("res://scripts/Visual/water_shore.gdshader")
## Terrain survey resolution, bounded for the large harbour. Work is spread
## over physics ticks and never follows moving actors or the camera.
const SHORE_CELL := 0.4
const SHORE_TEXELS := 768
const SHORE_RAYS_PER_TICK := 4096
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
var _shore_paint: ShaderMaterial
var _night: Node = null
var render_clock := 0.0
var _moon: DirectionalLight3D


## Attaches an axis-aligned water box centred at world centre with full XYZ box_size.
static func build(parent: Node, centre: Vector3, box_size: Vector3) -> Area3D:
	var water: Area3D = (load("res://scripts/Interaction/WaterVolume.gd") as GDScript).new()
	water.name = "Water"
	water.size = box_size
	parent.add_child(water)
	water.global_position = centre
	return water


## Returns the first grouped water volume containing world point, or null.
## above extends only the upper boundary in metres.
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
	refresh_shoreline()
	(load("res://scripts/Visual/WaterView.gd") as GDScript).ensure(get_viewport())
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


## Raycasts down from the surface on terrain layer 1; returns world floor Y
## or bottom_y() on miss. exclude contains body RIDs.
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


## Emits noise/spray at surface-projected world at, scaled by speed; body may be null.
## This method has no minimum-speed guard; body-entry callers apply SPLASH_SPEED.
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

	_surface_parameter(&"tile", tile)
	_surface_parameter(&"stretch", stretch)
	_surface_parameter(&"flow", (Vector2(1.0, 0.0) if size.x >= size.z else Vector2(0.0, 1.0)) * drift)


## The night on the water: rain rings it; the sky in it as bright as the moon
## lets.
func _process(delta: float) -> void:
	render_clock += delta
	if _paint == null:
		return

	_show_columns()
	_surface_parameter("water_clock", render_clock)
	_surface_parameter("moon_direction", moon_direction())
	_surface_parameter("moon_visibility", moon_visibility())
	_surface_parameter("moon_colour", moon_colour())

	if _night == null or not is_instance_valid(_night):
		_night = null
		for night in get_tree().get_nodes_in_group(&"night"):
			if night is Node3D and night.get_world_3d() == get_world_3d():
				_night = night
				break

		if _night == null:
			return

	if _night.has_method(&"rain"):
		_surface_parameter(&"rain", clampf(float(_night.rain()), 0.0, 1.0))

	if _night.has_method(&"moon_share"):
		_surface_parameter(&"sky_light", clampf(0.45 + 0.55 * float(_night.moon_share()), 0.0, 2.0))


## Shared source data for surface glitter and the submerged view. Standalone
## levels without Night still follow their actual directional light.
func _find_moon() -> DirectionalLight3D:
	if is_instance_valid(_moon):
		return _moon
	for node in get_tree().root.find_children("*", "DirectionalLight3D", true, false):
		if node.get_world_3d() == get_world_3d() and (_moon == null or node.name == "Moon"):
			_moon = node as DirectionalLight3D
	return _moon

func moon_direction() -> Vector3:
	if is_instance_valid(_night) and _night.has_method("moon_direction"):
		return _night.moon_direction()
	var source := _find_moon()
	return source.global_basis.z.normalized() if source != null else Vector3.UP

func moon_visibility() -> float:
	if is_instance_valid(_night) and _night.has_method("moon_visibility"):
		return _night.moon_visibility()
	var source := _find_moon()
	return clampf(source.light_energy / 0.4, 0.0, 1.0) if source != null and source.visible else 0.0

func moon_colour() -> Color:
	var source := _find_moon()
	return source.light_color if source != null else Color(0.6, 0.7, 0.9)


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

	_surface_parameter(&"lights", places)
	_surface_parameter(&"light_colours", colours)
	_surface_parameter(&"light_count", n)


## The surface, seen from above and below; the depth darkens toward the
## bottom as murk.
func _build_surface() -> void:
	_paint = ShaderMaterial.new()
	_paint.shader = SHADER
	_surface_parameter(&"ripples", _noise(RIPPLE_TEXELS, 0.02, 71, true))
	_surface_parameter(&"patches", _noise(64, 0.05, 29, false))
	_surface_parameter(&"deep", Color(tint.r * 0.14, tint.g * 0.12, tint.b * 0.1))
	_surface_parameter(&"half_size", Vector2(size.x, size.z) * 0.5)
	# Still water, rippled every way alike (a canal's streaks: ripple()), the
	# night sky in it.
	_surface_parameter(&"tile", RIPPLE_TILE)
	_surface_parameter(&"stretch", 1.0)
	_surface_parameter(&"flow", Vector2(0.02, 0.0))
	_surface_parameter(&"sky_zenith", SKY_ZENITH)
	_surface_parameter(&"sky_horizon", SKY_HORIZON)
	_surface_parameter(&"sky_light", 1.0)
	_surface_parameter(&"rain", 0.0)
	_shore_paint = _paint.duplicate() as ShaderMaterial
	_shore_paint.shader = SHORE_SHADER
	_shore_paint.render_priority = -126
	_paint.next_pass = _shore_paint
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
	murk.cull_mode = BaseMaterial3D.CULL_BACK
	murk.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var box := BoxMesh.new()
	box.size = Vector3(size.x - 0.02, size.y - 0.06, size.z - 0.02)
	# Leave its lid open: the underwater optical path supplies absorption.
	# A flat translucent lid would obscure the newly visible shallow bed.
	var arrays := box.get_mesh_arrays()
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var sides := PackedInt32Array()
	for i in range(0, indices.size(), 3):
		if normals[indices[i]].y < 0.5:
			sides.append_array(indices.slice(i, i + 3))
	arrays[Mesh.ARRAY_INDEX] = sides
	var open_box := ArrayMesh.new()
	open_box.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	open_box.surface_set_material(0, murk)
	var depth := MeshInstance3D.new()
	depth.name = "Murk"
	depth.mesh = open_box
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


## Keep both parts of the surface on the same clock, wind and light source.
func _surface_parameter(parameter: StringName, value: Variant) -> void:
	_paint.set_shader_parameter(parameter, value)
	if _shore_paint != null:
		_shore_paint.set_shader_parameter(parameter, value)


## Restarts the terrain-only shoreline survey after static bank geometry changes.
## Rays start above the water to avoid overhead bridges; work spans physics ticks.
func refresh_shoreline() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame

	if not is_inside_tree():
		return

	var width := clampi(int(ceil(size.x / SHORE_CELL)), 8, SHORE_TEXELS)
	var height := clampi(int(ceil(size.z / SHORE_CELL)), 8, SHORE_TEXELS)
	var image := Image.create(width, height, false, Image.FORMAT_RF)
	var land: PackedByteArray = await _concave_land(width, height)

	# (Its level gone meanwhile, at a district's gate: no more.)
	if not is_inside_tree() or land.size() < width * height:
		return

	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.new()
	query.collision_mask = 1
	query.collide_with_areas = false
	query.hit_from_inside = true
	var rays := 0
	for z in height:
		for x in width:
			var at := global_position + Vector3(
				((float(x) + 0.5) / width - 0.5) * size.x, 0.0,
				((float(z) + 0.5) / height - 0.5) * size.z)
			query.from = Vector3(at.x, surface_y() + 0.03, at.z)
			query.to = Vector3(at.x, bottom_y() - 0.5, at.z)
			var hit := space.intersect_ray(query)
			var bed := bottom_y()
			if land[z * width + x] != 0:
				bed = surface_y()
			elif not hit.is_empty():
				bed = (hit["position"] as Vector3).y
			image.set_pixel(x, z, Color(maxf(surface_y() - 0.02 - bed, 0.0), 0.0, 0.0))
			rays += 1
			if rays % SHORE_RAYS_PER_TICK == 0:
				await get_tree().physics_frame

				if not is_inside_tree():
					return
	_surface_parameter("shore_depth", ImageTexture.create_from_image(image))
	_surface_parameter("shore_texel", Vector2(1.0 / width, 1.0 / height))
	_surface_parameter("shore_ready", true)


## Rays starting inside a concave mesh cannot detect its interior. Recover
## that case from the closest triangle above the surface: an upward-facing
## exit means land, a downward-facing entrance means an overhead deck. This
## uses original winding because Godot flips the normals of backface hits.
func _concave_land(width: int, height: int) -> PackedByteArray:
	var land := PackedByteArray()
	land.resize(width * height)
	var closest := PackedFloat32Array()
	closest.resize(width * height)
	closest.fill(INF)
	var contained := PackedByteArray()
	contained.resize(width * height)
	var low := Vector2(global_position.x - size.x * 0.5, global_position.z - size.z * 0.5)
	var cell := Vector2(size.x / width, size.z / height)
	var surface := surface_y() + 0.03
	var work := 0
	for node in get_tree().root.find_children("*", "CollisionShape3D", true, false):
		# (The work spans frames: a level freed meanwhile, at a district's
		# gate, takes its shapes with it.)
		if not is_instance_valid(node):
			continue

		var shape := node as CollisionShape3D
		var body := shape.get_parent() as CollisionObject3D
		if shape.disabled or not shape.shape is ConcavePolygonShape3D or body == null or (body.collision_layer & 1) == 0 or body.get_world_3d() != get_world_3d():
			continue
		var faces := (shape.shape as ConcavePolygonShape3D).get_faces()
		if faces.is_empty():
			continue
		var bounds := AABB(faces[0], Vector3.ZERO)
		for point in faces:
			bounds = bounds.expand(point)
		var transform := shape.global_transform
		bounds = transform * bounds
		if bounds.position.y > surface or bounds.end.y < surface or bounds.end.x < low.x or bounds.position.x > low.x + size.x or bounds.end.z < low.y or bounds.position.z > low.y + size.z:
			continue
		# Classify each solid independently. A nearer underside belonging to
		# another bridge must not clear land inside an overlapping pier.
		closest.fill(INF)
		contained.fill(0)
		var touched := PackedInt32Array()
		for i in range(0, faces.size(), 3):
			var a := transform * faces[i]
			var b := transform * faces[i + 1]
			var c := transform * faces[i + 2]
			var denominator := (b.x - a.x) * (c.z - a.z) - (b.z - a.z) * (c.x - a.x)
			if absf(denominator) < 0.00001 or maxf(a.y, maxf(b.y, c.y)) < surface:
				continue
			var first_x := clampi(int(floor((minf(a.x, minf(b.x, c.x)) - low.x) / cell.x)), 0, width - 1)
			var last_x := clampi(int(ceil((maxf(a.x, maxf(b.x, c.x)) - low.x) / cell.x)), 0, width - 1)
			var first_z := clampi(int(floor((minf(a.z, minf(b.z, c.z)) - low.y) / cell.y)), 0, height - 1)
			var last_z := clampi(int(ceil((maxf(a.z, maxf(b.z, c.z)) - low.y) / cell.y)), 0, height - 1)
			for z in range(first_z, last_z + 1):
				for x in range(first_x, last_x + 1):
					var dx := low.x + (x + 0.5) * cell.x - a.x
					var dz := low.y + (z + 0.5) * cell.y - a.z
					var u := (dx * (c.z - a.z) - dz * (c.x - a.x)) / denominator
					var v := ((b.x - a.x) * dz - (b.z - a.z) * dx) / denominator
					if u >= 0.0 and v >= 0.0 and u + v <= 1.0:
						var y := a.y + u * (b.y - a.y) + v * (c.y - a.y)
						var index := z * width + x
						if y >= surface and y < closest[index]:
							if is_inf(closest[index]):
								touched.append(index)
							closest[index] = y
							# Clockwise faces: negative cross is the outward normal.
							contained[index] = 1 if denominator > 0.0 else 0
					work += 1
					if work % SHORE_RAYS_PER_TICK == 0:
						await get_tree().physics_frame

						if not is_inside_tree():
							return PackedByteArray()
		for index in touched:
			if contained[index] != 0:
				land[index] = 1
	return land
