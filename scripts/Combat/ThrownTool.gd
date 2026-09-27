extends Node3D
## A tool thrown off your belt (PlayerFrob): it flies itself under gravity, a
## ray along each step of its path (as Arrow.gd, so it never passes through a
## thin wall), turning over as it goes, and bursts where it lands (or in the
## air, its fuse run out):
##
##   flashbomb   a flash of white fire and a bang. A guard who has it in his
##               eyes (in his view, nothing between, near enough) is blinded
##               a few seconds (Guard.dazzle: more the nearer, and the more
##               squarely he looked at it); everyone near hears it. Your own
##               eyes too, if you are looking at it (StealthHUD.dazzle).
##   waterflask  glass breaking and a splash. A torch on a wall in the splash
##               goes out (Torch.put_out, by you: the guards treat it as one
##               you put out by hand); the breaking glass is heard.

const SoundBus := preload("res://scripts/StimuliSystem/SoundBus.gd")
const Fx := preload("res://scripts/Visual/Fx.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")

## Thrown this fast along your aim (m/s), and up a little besides.
const THROW_SPEED := 15.0
const THROW_LIFT := 2.4
const GRAVITY := 9.8
## Bursting anyway after this long in the air (s).
const FUSE := 3.0
## The flash: this far it blinds a man looking at it (m), fully to FLASH_FULL;
## heard this loud (SoundBus, dB). A man it is not in the middle of the view
## of is blinded only as far as he had it in view (Guard._cone_factor); this
## near, it blinds him whichever way he faced.
const FLASH_REACH := 11.0
const FLASH_FULL := 4.0
const FLASH_DB := 72.0
const FLASH_CLOSE := 2.0
## The splash: a torch's flame this near where it broke goes out (m); heard
## this loud.
const SPLASH_REACH := 1.4
const SPLASH_DB := 44.0
## A torch hung out of reach of a splash below it: the flask can hit the
## flame itself (its reach, Torch.REACH_LAYER).
const TORCH_LAYER := 4

## Which tool it is (&"flashbomb", &"waterflask"), and who threw it.
var kind: StringName = &"flashbomb"
var thrower: Node3D = null
var velocity := Vector3.ZERO

var _life := 0.0
var _spin := Vector3.ZERO
var _visual: MeshInstance3D
var _burst := false


## Off it goes from `from` along `aim` (a direction), shown as `mesh`.
func launch(from: Vector3, aim: Vector3, mesh: Mesh, by: Node3D) -> void:
	thrower = by
	global_position = from
	velocity = aim.normalized() * THROW_SPEED + Vector3.UP * THROW_LIFT
	_spin = Vector3(randf_range(6.0, 11.0), randf_range(-3.0, 3.0), randf_range(-2.0, 2.0))

	if mesh != null:
		_visual = MeshInstance3D.new()
		_visual.mesh = mesh
		_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Its turning is for show: drawn as set.
		_visual.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		add_child(_visual)

	reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	if _burst:
		return

	_life += delta

	if _life >= FUSE:
		_go_off(global_position, Vector3.UP, null)
		return

	var next_velocity := velocity + Vector3.DOWN * GRAVITY * delta
	var travel := (velocity + next_velocity) * 0.5 * delta
	var from := global_position
	var to := from + travel
	var exclude: Array[RID] = []

	if thrower is CollisionObject3D and is_instance_valid(thrower):
		exclude.append((thrower as CollisionObject3D).get_rid())

	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to, 1 | 2 | 4, exclude)
	query.collide_with_areas = false
	query.hit_from_inside = true
	var hit := space.intersect_ray(query)

	# The flask can break on a torch's flame itself (nothing behind it).
	if kind == &"waterflask":
		var flame_query := PhysicsRayQueryParameters3D.create(from, to, TORCH_LAYER, exclude)
		flame_query.collide_with_areas = true
		flame_query.collide_with_bodies = false
		var flame := space.intersect_ray(flame_query)

		if not flame.is_empty() and (hit.is_empty() or from.distance_to(flame["position"]) < from.distance_to(hit["position"])):
			var torch: Node = (flame.get("collider") as Node).get_parent() if flame.get("collider") is Node else null

			if torch != null and torch.has_method("put_out"):
				hit = flame

	if not hit.is_empty():
		_go_off(hit["position"], hit.get("normal", Vector3.UP), hit.get("collider"))
		return

	global_position = to
	velocity = next_velocity

	if _visual != null:
		_visual.rotation += _spin * delta


func _go_off(at: Vector3, normal: Vector3, struck: Object) -> void:
	_burst = true

	match kind:
		&"flashbomb":
			flash(self, at + normal * 0.1, thrower)
		&"waterflask":
			splash(self, at, normal, thrower, struck)

	queue_free()


## A flash bomb going off at `at`: the flash and the bang; every guard who
## has it in his eyes blinded as far as he does; your own eyes too.
static func flash(context: Node, at: Vector3, by: Node3D) -> void:
	Fx.flash(context, at, Color(1.0, 0.97, 0.9), 14.0, 13.0, 0.4)
	Fx.sparks(context, at, Vector3.UP, 1.4, false)
	Sfx.play(context, &"explosion", at, -10.0, 1.9)
	Sfx.play(context, &"ting", at, -6.0, 0.7)
	SoundBus.emit_sound(at, FLASH_DB, by if by != null else context, &"flash")
	var space := _space_of(context)

	if space == null:
		return

	for node in context.get_tree().get_nodes_in_group(&"guards"):
		var guard := node as Node3D

		if guard == null or not guard.has_method("dazzle") or not guard.has_method("eye_position"):
			continue

		var eye: Vector3 = guard.eye_position()
		var far := eye.distance_to(at)

		if far > FLASH_REACH or not _clear(space, eye, at, guard):
			continue

		var looked: float = float(guard._cone_factor(at - eye)) if guard.has_method("_cone_factor") else 1.0

		if far <= FLASH_CLOSE:
			looked = maxf(looked, 0.6)

		var amount := looked * (1.0 - 0.7 * smoothstep(FLASH_FULL, FLASH_REACH, far))

		if amount > 0.05:
			guard.dazzle(at, amount)

	# Your own eyes: looking at it, nothing between.
	var camera := context.get_viewport().get_camera_3d()

	if camera != null and by != null and by.get("hud") != null:
		var to := at - camera.global_position
		var facing := -camera.global_basis.z
		var squarely := facing.dot(to.normalized()) if to.length() > 0.01 else 1.0

		if to.length() < FLASH_REACH and squarely > 0.3 and _clear(space, camera.global_position, at, by):
			var hud: Node = by.get("hud")

			if hud.has_method("dazzle"):
				hud.dazzle(smoothstep(0.3, 0.9, squarely) * (1.0 - 0.6 * smoothstep(FLASH_FULL, FLASH_REACH, to.length())))


## A water flask breaking at `at`: glass and a splash; a torch whose flame is
## in the splash goes out, put out by `by`.
static func splash(context: Node, at: Vector3, normal: Vector3, by: Node3D, struck: Object = null) -> void:
	Sfx.play(context, &"ting", at, -4.0, 1.6)
	Sfx.play(context, &"step_water_run", at, -2.0, 1.3)
	Fx.dust(context, at + normal * 0.05, normal, 1.2, "water")
	SoundBus.emit_sound(at, SPLASH_DB, by if by != null else context, &"glass")
	var space := _space_of(context)

	for node in context.get_tree().get_nodes_in_group(&"lights"):
		var torch := node as Node3D

		if torch == null or not torch.has_method("put_out") or not bool(torch.get("lit")):
			continue

		var hit_it: bool = struck != null and struck is Node and (struck as Node).get_parent() == torch

		if hit_it or (torch.global_position.distance_to(at) <= SPLASH_REACH and (space == null or _clear(space, at + normal * 0.1, torch.global_position, torch))):
			torch.put_out(by)


static func _space_of(context: Node) -> PhysicsDirectSpaceState3D:
	var world: World3D = (context as Node3D).get_world_3d() if context is Node3D else (context.get_viewport().find_world_3d() if context.get_viewport() != null else null)
	return world.direct_space_state if world != null else null


## Whether nothing solid (the world) stands between `from` and `to`.
static func _clear(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, skip: Object) -> bool:
	var exclude: Array[RID] = []

	if skip is CollisionObject3D:
		exclude.append((skip as CollisionObject3D).get_rid())

	var query := PhysicsRayQueryParameters3D.create(from, to, 1, exclude)
	query.collide_with_areas = false
	var hit := space.intersect_ray(query)
	return hit.is_empty() or (hit["position"] as Vector3).distance_to(to) < 0.3
