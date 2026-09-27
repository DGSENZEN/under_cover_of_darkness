extends Node3D
## A flame's corona (Thief: Deadly Shadows): a halo that stays the same size
## on screen, drawn over the fog, breathing with the light's flicker and dying
## with it. Walls and men hide it: up to three rays a tick from the camera to
## its middle and to either side of it (the world and the guards' bodies),
## its visibility easing toward the share of them that get through over FADE
## seconds, so a man walking across a torch dims it rather than cutting it.
## Off screen it is gone at once, so turning round never shows a stale halo.
## It fades out between 1.5 and 3 times its light's reach.
##
## An effect: on its own layer, the lightgem never sees it.

const Layers := preload("res://scripts/Visual/Layers.gd")
const SHADER := preload("res://scripts/Visual/Lights/corona.gdshader")

## Its size on the 360-line screen.
@export var size_px := 48.0
@export var tint := Color.WHITE

## 0..1: how much of it shows.
var visibility := 0.0
var quad: MeshInstance3D

const FADE := 0.15
const RAYS := 3
## The world's and the guards' physics layers.
const MASK := 1 | 2

static var _material: ShaderMaterial
var _query := PhysicsRayQueryParameters3D.new()


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	quad = MeshInstance3D.new()
	quad.name = "Halo"
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE
	quad.mesh = mesh
	quad.material_override = _shared()
	quad.layers = Layers.FX
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# It sizes itself on screen: never culled for being small or far.
	quad.extra_cull_margin = 4.0
	add_child(quad)
	_show(0.0)


## Once a physics tick: `glow` is its light's energy over its energy as made
## (0 when out), `exclude` bodies its own fixture is made of.
func tick(camera: Camera3D, glow: float, light_range: float, exclude: Array[RID], delta: float) -> void:
	if camera == null or not is_inside_tree():
		visibility = 0.0
		_show(0.0)
		return

	var at := global_position
	var fade := distance_fade(camera.global_position.distance_to(at), light_range)

	if fade <= 0.0 or glow <= 0.0 or not camera.is_position_in_frustum(at):
		visibility = 0.0
		_show(0.0)
		return

	var clear := _clear_share(camera, exclude)
	visibility = move_toward(visibility, clear, delta / FADE)
	_show(visibility * fade * clampf(glow, 0.0, 1.5))


## 1 near, 0 far: full up to 1.5 times the light's reach, gone from 3 times.
static func distance_fade(distance: float, light_range: float) -> float:
	var reach := maxf(light_range, 0.01)
	return 1.0 - smoothstep(1.5 * reach, 3.0 * reach, distance)


## Its size in metres at the distance it stands from `camera` (its radius).
func world_radius(camera: Camera3D) -> float:
	if camera == null:
		return 0.0

	var distance := camera.global_position.distance_to(global_position)
	return distance * tan(deg_to_rad(camera.fov) * 0.5) * size_px / 360.0


func _clear_share(camera: Camera3D, exclude: Array[RID]) -> float:
	var space := get_world_3d().direct_space_state
	var from := camera.global_position
	var side := camera.global_basis.x * world_radius(camera) * 0.25
	var skip: Array[RID] = exclude.duplicate()
	var player := get_tree().get_first_node_in_group(&"player")

	if player is CollisionObject3D:
		skip.append((player as CollisionObject3D).get_rid())

	_query.from = from
	_query.collision_mask = MASK
	_query.collide_with_areas = false
	_query.exclude = skip
	var clear := 0

	for target in [global_position, global_position + side, global_position - side]:
		_query.to = target

		if space.intersect_ray(_query).is_empty():
			clear += 1

	return float(clear) / float(RAYS)


func _show(amount: float) -> void:
	if quad == null:
		return

	quad.visible = amount > 0.001
	quad.set_instance_shader_parameter(&"amount", amount)
	quad.set_instance_shader_parameter(&"size_px", size_px)
	quad.set_instance_shader_parameter(&"tint", tint)


static func _shared() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
		_material.set_shader_parameter(&"falloff", load("res://assets/vfx/corona.png"))

	return _material
