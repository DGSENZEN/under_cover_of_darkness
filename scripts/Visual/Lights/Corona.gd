extends Node3D
## Screen-sized flame halo on Layers.FX, drawn above fog without depth testing.
## Three camera rays against world/bodies determine visibility; it eases over FADE and disappears immediately off screen.
## Distance fading spans 1.5 to 3 times the light reach. Caller supplies carrier RIDs to exclude.

const Layers := preload("res://scripts/Visual/Layers.gd")
const SHADER := preload("res://scripts/Visual/Lights/corona.gdshader")
const SightRay := preload("res://scripts/StimuliSystem/SightRay.gd")

## Its size on the 360-line screen.
@export var size_px := 48.0:
	set(value):
		size_px = value
		_sent_look = false
@export var tint := Color.WHITE:
	set(value):
		tint = value
		_sent_look = false

## 0..1: how much of it shows.
var visibility := 0.0
var quad: MeshInstance3D

const FADE := 0.15
const RAYS := 3
## The world's and the guards' physics layers.
const MASK := 1 | 2

static var _material: ShaderMaterial
var _query := PhysicsRayQueryParameters3D.new()
## What the shader and the rays were last given.
var _sent_amount := -1.0
var _sent_look := false
var _skipping: Array[RID] = []
var _skip_player := RID()
var _player: Node = null


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
	if _player == null or not is_instance_valid(_player) or not _player.is_inside_tree():
		_player = get_tree().get_first_node_in_group(&"player")

	var player_rid := (_player as CollisionObject3D).get_rid() if _player is CollisionObject3D else RID()

	# Told again only when what it skips changes (not built afresh each tick).
	if exclude != _skipping or player_rid != _skip_player:
		_skipping = exclude.duplicate()
		_skip_player = player_rid
		var skip: Array[RID] = exclude.duplicate()

		if player_rid.is_valid():
			skip.append(player_rid)

		_query.exclude = skip

	_query.from = from
	_query.collision_mask = MASK
	_query.collide_with_areas = false
	var clear := 0

	for target in [global_position, global_position + side, global_position - side]:
		_query.to = target

		# (Seen through a window's glass too.)
		if SightRay.first_solid(space, _query).is_empty():
			clear += 1

	return float(clear) / float(RAYS)


func _show(amount: float) -> void:
	if quad == null:
		return

	quad.visible = amount > 0.001

	if not _sent_look:
		_sent_look = true
		quad.set_instance_shader_parameter(&"size_px", size_px)
		quad.set_instance_shader_parameter(&"tint", tint)

	if amount != _sent_amount:
		_sent_amount = amount
		quad.set_instance_shader_parameter(&"amount", amount)


static func _shared() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
		_material.set_shader_parameter(&"falloff", load("res://assets/vfx/corona.png"))

	return _material
