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


func _on_body_exited(body: Node3D) -> void:
	if body is RigidBody3D:
		_floating.erase(body as RigidBody3D)


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


## The surface, seen from above and below; the depth darkens toward the
## bottom as murk.
func _build_surface() -> void:
	var paint := StandardMaterial3D.new()
	paint.albedo_color = tint
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	paint.roughness = 0.08
	paint.metallic_specular = 0.9
	var plane := PlaneMesh.new()
	plane.size = Vector2(size.x, size.z)
	plane.material = paint
	_surface_mesh = MeshInstance3D.new()
	_surface_mesh.name = "Surface"
	_surface_mesh.mesh = plane
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
