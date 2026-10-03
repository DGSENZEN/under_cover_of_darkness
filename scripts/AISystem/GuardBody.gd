class_name GuardBody
extends RigidBody3D
## Carryable remains of a killed or unconscious guard, registered in "bodies".
## Normal bodies use physics layer 3; players and guard sight pass over them.
## With a humanoid ragdoll, this collision-free proxy follows the hips; limbs collide.
## Without one, a capsule supports an animated fall. Landing makes sound/dust;
## corpses form a blood pool after settling. Detection is handled by Guard.

const Fx := preload("res://scripts/Visual/Fx.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")
const Layers := preload("res://scripts/Visual/Layers.gd")

const LAYER := 4
## Hacking at a corpse: how likely a quick cut is to take a part off, how
## near the cut must pass it, and where each part runs to.
const HACK_CHANCE := 0.45
const HACK_REACH := 0.26
const LIMB_ENDS := {
	&"neck_01": &"Head",
	&"upperarm_l": &"lowerarm_l", &"upperarm_r": &"lowerarm_r",
	&"lowerarm_l": &"hand_l", &"lowerarm_r": &"hand_r",
	&"thigh_l": &"calf_l", &"thigh_r": &"calf_r",
	&"calf_l": &"foot_l", &"calf_r": &"foot_r",
}

var discovered := false
## Whose body it is (his given name): a friend who finds it calls it.
var called := ""
## Killed, rather than knocked out. Found either way; spoken of differently.
var dead := false
## A stand-in for a man who has gone limp (see above).
var limp := false

var _visual: Node3D
var _fall_t := -1.0
var _fall_time := 0.55
var _start := Transform3D.IDENTITY
var _end := Transform3D.IDENTITY
var _foot := Vector3.ZERO
var _landed := false
var _pool_at := -1.0
# Limp: the hardest his hips have come down since they last stopped (a man
# crumpling slows as his legs give, so the thud is when the fall ends, as
# hard as it was at its worst), thuds so far, how long he has lain still, and
# whether he has bled his pool.
var _fall_peak := 0.0
var _thuds := 0
var _since_thud := 1.0
var _still := 0.0
var _pooled := false
var _limp_time := 0.0
var _settled := false
## Where it last put itself (on his hips): moved from there by anything else,
## he is taken along.
var _followed := Vector3.INF
## Lain still this long (seconds), he stops being worked out every tick:
## only watched, until something moves him (a blade, a boot, another body
## falling on him, a script) or he is laid down again.
const SLEEP_AFTER := 2.0
var _asleep := false


func _ready() -> void:
	add_to_group(&"bodies")
	mass = 70.0
	linear_damp = 1.5
	angular_damp = 4.0

	if limp:
		# Where his hips are, and nothing else: his limbs are the body.
		freeze = true
		freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		collision_layer = 0
		collision_mask = 0
		return

	collision_layer = LAYER
	collision_mask = 1 | LAYER


func get_prompt(_player: Node) -> String:
	return "Shoulder the body"


## Returns false for arm-length carrying; frob() uses shoulder carrying instead.
func can_carry() -> bool:
	return false


## Requests player.frob.shoulder(self) when the player exposes a frob component.
func frob(player: Node) -> void:
	if player.get("frob") != null:
		player.frob.shoulder(self)


func is_falling() -> bool:
	if limp:
		var rag := ragdoll()
		return rag != null and rag.is_limp() and not _settled

	return _fall_t >= 0.0


## Lifted mid-fall (shouldered): lying as it will, and nothing left to land.
## A pool that has not started yet does not start: he was carried off.
func finish_fall() -> void:
	if _visual != null and _fall_t >= 0.0:
		_visual.transform = _end

	_fall_t = -1.0
	_landed = true
	_pool_at = -1.0

	# Over a shoulder, out of sight: nothing to work out, and no pool where
	# he no longer lies.
	var rag := ragdoll()
	_pooled = true

	if rag != null and rag.is_limp():
		rag.recover(0.0)


## Returns the owned humanoid visual, or null when this body has none.
func man() -> Node3D:
	for child in get_children():
		if child.get("ragdoll") != null:
			return child as Node3D

	return null


func ragdoll() -> Node:
	var who := man()
	return who.ragdoll if who != null else null


## Put down off a shoulder at `rest` (where the body goes, lying along its
## -Z): let fall from a little above the floor, flat on his back, and left
## to physics.
## Whose body, killed or not, where it lies and whether it has been found:
## the district's memory (Guard.restore_downed puts it back).
func save_state() -> Dictionary:
	return {"guard": called, "dead": dead, "transform": global_transform, "discovered": discovered}


func lay_down(rest: Transform3D) -> bool:
	var who := man()
	var rag := ragdoll()

	if who == null or rag == null:
		return false

	# Flat on his back (the first frame of getting up), his head toward the
	# body's -Z end, his feet toward +Z.
	who.show_pose(&"LayToIdle", 0.0)
	var size: Vector3 = who.global_transform.basis.get_scale()
	var yaw := rest.basis.get_euler().y + PI
	var ground := rest.origin + Vector3.DOWN * (RADIUS - 0.03)
	var placed := Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(size), Vector3.ZERO)
	# The pose's hips lie a little behind its feet: centre the hips on the spot.
	placed.origin = ground + Vector3.UP * 0.5 - placed.basis * Vector3(0.0, 0.0, 0.24)
	who.global_transform = placed
	# Put down in one step: his cloth starts afresh where he lies.
	who.restart_cloth()
	rag.go_limp(Vector3.DOWN * 0.4)
	_fall_peak = 0.0
	_thuds = 0
	_still = 0.0
	_limp_time = 0.0
	_settled = false
	_followed = Vector3.INF
	_asleep = false
	return true


## A blade in a man already dead: it bleeds and moves him, and does no more.
func struck(point: Vector3, direction: Vector3, heavy := false, cuts := false) -> void:
	Fx.blood(self, point, direction, 0.8 if heavy else 0.5)
	var rag := ragdoll()

	if rag != null and rag.is_limp():
		rag.shove(direction.normalized() * (2.4 if heavy else 1.4), point, 0.5)
		_asleep = false

	# A cutting edge can take him apart: a heavy cut always takes what it
	# met (a neck, a limb), a quick one now and then.
	if cuts and dead and (heavy or randf() < HACK_CHANCE):
		_hack(point, direction, heavy)


## Takes off whatever part of him the cut met, if it met one.
func _hack(point: Vector3, direction: Vector3, heavy: bool) -> void:
	var who := man()

	if who == null or who.get("skeleton") == null:
		return

	var bone := limb_at(who, point)

	if bone == &"":
		return

	var piece: Node = who.sever(bone, direction.normalized() * (2.2 if heavy else 1.3) + Vector3.UP)

	if piece != null:
		Sfx.play(self, &"flesh_heavy", point, 0.0, 0.85)
		Sfx.play(self, &"bone_crack", point, -2.0, randf_range(0.95, 1.1))
		Fx.blood(self, point, direction, 1.2)


## The part of `who` (a Humanoid) nearest `point` that a blade can take off,
## if one is near enough; else "".
static func limb_at(who: Node3D, point: Vector3) -> StringName:
	var skeleton: Skeleton3D = who.get("skeleton")
	var severable: Dictionary = who.get_script().get_script_constant_map().get("SEVERABLE", {})
	var best: StringName = &""
	var nearest := HACK_REACH

	for bone in severable:
		# Gone, or hung from a part that is (a calf off a thigh cut away).
		if who.is_severed(bone) or not LIMB_ENDS.has(bone):
			continue

		var from := skeleton.find_bone(bone)
		var to := skeleton.find_bone(LIMB_ENDS[bone])

		if from < 0 or to < 0:
			continue

		var a: Vector3 = skeleton.global_transform * (who.pose_now(from) as Transform3D).origin
		var b: Vector3 = skeleton.global_transform * (who.pose_now(to) as Transform3D).origin
		var d := point.distance_to(Geometry3D.get_closest_point_to_segment(point, a, b))

		if d < nearest:
			nearest = d
			best = bone

	return best


func _physics_process(delta: float) -> void:
	if not limp or not visible:
		return

	var rag := ragdoll()

	if rag == null or not rag.is_limp():
		return

	# Asleep: nothing to do while neither he nor it has been moved.
	if _asleep:
		if global_position.distance_to(_followed) < 0.01 and rag.centre().distance_to(_followed) < 0.02:
			return

		_asleep = false

	# Only ever where he is: nothing of its own to fall with.
	freeze = true

	# Moved by something other than his fall (a script, a test): he goes too.
	if _followed != Vector3.INF and global_position.distance_to(_followed) > 0.3:
		rag.move_by(global_position - _followed)

	# Where his hips are, the -Z end toward his head.
	var hips: Vector3 = rag.centre()
	var head: Vector3 = rag.head()
	var along := Vector3(head.x - hips.x, 0.0, head.z - hips.z)
	var yaw := global_rotation.y

	if along.length() > 0.1:
		yaw = atan2(-along.x, -along.z)

	global_transform = Transform3D(Basis(Vector3.UP, yaw), hips)
	_followed = hips
	_limp_time += delta

	# Coming down hard: a thud and dust where he met the floor.
	var fall: float = -rag.velocity().y
	_since_thud += delta

	_fall_peak = maxf(_fall_peak, fall)

	if fall < 0.5:
		var came_down := _fall_peak
		_fall_peak = 0.0

		if came_down > 1.8 and _thuds < 3 and _since_thud > 0.25:
			_thud(hips, came_down)

	# Once he lies still, a corpse bleeds his pool.
	if rag.speed() < 0.2:
		_still += delta
	else:
		_still = 0.0

	_settled = _still > 0.4 and _limp_time > 0.5

	if dead and not _pooled and _still > 0.6:
		_pooled = true
		Fx.pool(self, hips, 1.15, 6.0)

	_asleep = _settled and _still > SLEEP_AFTER and (_pooled or not dead)


## Coming down hard (`speed`, m/s): a thud, his gear with him the first time,
## and dust where he met the floor.
func _thud(hips: Vector3, speed: float) -> void:
	_thuds += 1
	_since_thud = 0.0
	var floor_kind := _floor_under(hips)
	Fx.dust(self, hips + Vector3.DOWN * 0.1, Vector3.UP, 0.9, floor_kind if floor_kind != "" else "stone")
	var hard := clampf((speed - 1.8) / 3.0, 0.0, 1.0)
	Sfx.play(self, &"body_fall", hips, lerpf(-4.0, 1.0, hard) if _thuds == 1 else -6.0, randf_range(0.9, 1.05))

	# His mail and his gear hitting the floor with him: the floor he actually
	# came down on (planks, flagstones, earth, a puddle).
	if _thuds == 1:
		Sfx.play(self, Sfx.step(floor_kind, false, "land", true), hips, lerpf(-6.0, -2.0, hard), randf_range(0.9, 1.0))


# The fall

## Animates the look of the body from `stood` (the standing body's world
## transform, capsule centre) to where it lies. `foot` is half the capsule's
## length: the fall pivots about its lower end.
func play_fall(stood: Transform3D, seconds: float) -> void:
	if _visual == null:
		return

	_start = global_transform.affine_inverse() * stood.orthonormalized()
	_end = _visual.transform
	_foot = Vector3(0.0, -_visual_half_length(), 0.0)
	_fall_time = maxf(seconds, 0.05)
	_fall_t = 0.0
	_landed = false
	_visual.transform = _start


func _process(delta: float) -> void:
	if _pool_at >= 0.0:
		_pool_at -= delta

		if _pool_at < 0.0:
			Fx.pool(self, global_position, 1.15, 6.0)

	if _fall_t < 0.0 or _visual == null:
		return

	_fall_t += delta / _fall_time
	var t := _fall_t
	var eased := 1.0

	if t < 1.0:
		# Gravity: slow to start, fast at the end.
		eased = t * t
	elif t < 1.22:
		# A small rebound off the floor.
		eased = 1.0 - 0.07 * sin(PI * (t - 1.0) / 0.22)

		if not _landed:
			_land()
	else:
		_visual.transform = _end
		_fall_t = -1.0
		return

	var turn := _start.basis.get_rotation_quaternion().slerp(_end.basis.get_rotation_quaternion(), eased)
	var basis := Basis(turn)
	var foot := (_start * _foot).lerp(_end * _foot, eased)
	_visual.transform = Transform3D(basis, foot - basis * _foot)


func _land() -> void:
	_landed = true
	var head_end := global_transform * (_end * -_foot)
	var floor_kind := _floor_under(global_position)
	var dust_kind := floor_kind if floor_kind != "" else "stone"
	Fx.dust(self, head_end + Vector3.DOWN * 0.2, Vector3.UP, 1.1, dust_kind)
	Fx.dust(self, global_position + Vector3.DOWN * 0.2, Vector3.UP, 0.6, dust_kind)
	Sfx.play(self, &"body_fall", global_position, 0.0)
	Sfx.play(self, Sfx.step(floor_kind, false, "land", true), global_position, -5.0, randf_range(0.9, 1.0))

	if dead:
		_pool_at = 0.35


## What the floor under `at` is made of (its "surface" meta: "stone",
## "wood"...), or "" when it does not say.
func _floor_under(at: Vector3) -> String:
	if not is_inside_tree():
		return ""

	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.3, at + Vector3.DOWN * 1.2, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var floor_body: Object = hit.get("collider") if not hit.is_empty() else null
	return String(floor_body.get_meta(&"surface")) if floor_body != null and floor_body.has_meta(&"surface") else ""


func _visual_half_length() -> float:
	if _visual is MeshInstance3D and (_visual as MeshInstance3D).mesh is CapsuleMesh:
		return ((_visual as MeshInstance3D).mesh as CapsuleMesh).height * 0.5

	return LENGTH * 0.5


const RADIUS := 0.28
const LENGTH := 1.7
## How far behind his feet a man who fell on his back lies, centre to feet.
const MAN_LIES_BEHIND := 0.46


## Finds a world-space lying transform near center, testing yaw rotations and offsets
## against world/actors/bodies while excluding RIDs. If none is free, returns the
## requested transform and lets physics resolve overlap; there is no failure sentinel.
static func find_rest_transform(space: PhysicsDirectSpaceState3D, center: Vector3, yaw: float, exclude: Array[RID]) -> Transform3D:
	var capsule := CapsuleShape3D.new()
	capsule.radius = RADIUS
	capsule.height = LENGTH

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = 1 | 2 | LAYER
	query.exclude = exclude
	query.collide_with_areas = false

	for turn in [0.0, PI * 0.5, -PI * 0.5, PI * 0.25, -PI * 0.25]:
		var basis := Basis(Vector3.UP, yaw + turn)

		for shift in [0.0, 0.45, -0.45, 0.9, -0.9]:
			for side in [0.0, 0.35, -0.35]:
				var at: Vector3 = center + basis.z * shift + basis.x * side
				query.transform = Transform3D(basis * Basis(Vector3.RIGHT, PI * 0.5), at)

				if space.intersect_shape(query, 1).is_empty():
					return Transform3D(basis, at)

	# Nowhere is free: lie where asked and let physics sort it out.
	return Transform3D(Basis(Vector3.UP, yaw), center)


## Creates remains under guard's parent. killed marks a corpse; fall is a world-space
## blow direction (ZERO defaults backwards). Returns RigidBody3D; rig transfer is
## the caller's responsibility. Uses a ragdoll proxy when the rig already has one.
static func spawn(guard: Node3D, killed := false, fall := Vector3.ZERO) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.set_script(load("res://scripts/AISystem/GuardBody.gd"))
	body.name = "Body"
	body.set("called", String(guard.get("given_name")) if guard.get("given_name") != null else "")

	# A bigger man leaves a bigger body, in his own colours.
	var rig: Node = guard.get_node_or_null("Rig")
	var falling_man := rig.get("man") as Node3D if rig != null else null

	if falling_man != null and falling_man.get("ragdoll") != null:
		# He falls as physics has him: the body only follows him.
		var shape := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = RADIUS
		capsule.height = LENGTH
		shape.shape = capsule
		shape.rotation.x = deg_to_rad(90.0)
		shape.disabled = true
		body.add_child(shape)
		body.set("limp", true)
		body.set("dead", killed)
		body.set("_landed", true)
		var home := guard.get_parent()
		# On his hips from the first frame, and drawn nowhere (it is only a
		# stand-in): nothing to slide in from.
		var hips: Vector3 = falling_man.bone_global(&"pelvis").origin
		var at := Transform3D(Basis(Vector3.UP, guard.global_rotation.y + PI), hips)
		body.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		body.transform = (home as Node3D).global_transform.affine_inverse() * at if home is Node3D else at
		home.add_child(body)
		body.reset_physics_interpolation()
		return body
	var size: float = float(rig.get("size")) if rig != null and rig.get("size") != null else 1.0
	var colour := Color(0.32, 0.22, 0.2)
	var worn := rig.get("body_mesh") as MeshInstance3D if rig != null else null

	if worn != null and worn.mesh is PrimitiveMesh and (worn.mesh as PrimitiveMesh).material is StandardMaterial3D:
		colour = ((worn.mesh as PrimitiveMesh).material as StandardMaterial3D).albedo_color

	# A capsule lying along the body's -Z.
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = RADIUS * size
	capsule.height = LENGTH * size
	shape.shape = capsule
	shape.rotation.x = deg_to_rad(90.0)
	body.add_child(shape)

	# A man with a body of his own falls as his death animation does: onto his
	# back, to lie behind where he stood (GuardRig.gd).
	var man := rig.get("man") as Node3D if rig != null else null
	var flat := Vector3(fall.x, 0.0, fall.z)
	var yaw := guard.global_rotation.y + PI

	if flat.length() > 0.05 and man == null:
		# The body's -Z, the end his head is at, points the way he fell.
		yaw = atan2(-flat.x, -flat.z)

	var exclude: Array[RID] = []

	if guard is CollisionObject3D:
		exclude.append((guard as CollisionObject3D).get_rid())

	var centre := guard.global_position + Vector3.UP * (RADIUS * size + 0.03)

	if man != null:
		centre += Basis(Vector3.UP, guard.global_rotation.y).z * MAN_LIES_BEHIND * size

	var rest := find_rest_transform(guard.get_world_3d().direct_space_state, centre, yaw, exclude)

	# How he stood: his own body mesh if he has one, else upright.
	var stood := Transform3D(Basis(Vector3.UP, guard.global_rotation.y), guard.global_position + Vector3.UP * 0.9)
	var standing_mesh := guard.get_node_or_null("Rig/Body") as Node3D

	if standing_mesh != null:
		stood = standing_mesh.global_transform.orthonormalized()

	var visual := MeshInstance3D.new()
	visual.name = "Visual"
	var mesh := CapsuleMesh.new()
	mesh.radius = RADIUS * size
	mesh.height = LENGTH * size
	var material := StandardMaterial3D.new()
	material.albedo_color = colour.lerp(Color(0.3, 0.04, 0.03), 0.45) if killed else colour
	material.roughness = 0.9
	mesh.material = material
	visual.mesh = mesh
	visual.layers = Layers.ACTORS

	# Lying, he is his standing self tipped over: face down if he fell
	# forward, face up if he fell back.
	var head_end := -rest.basis.z
	var tip_axis := Vector3.UP.cross(head_end)
	var lying := stood.basis

	if tip_axis.length() > 0.001:
		lying = Basis(tip_axis.normalized(), PI * 0.5) * Basis(Vector3.UP, guard.global_rotation.y)

	visual.transform = Transform3D(rest.basis.inverse() * lying, Vector3.ZERO)
	# The fall is animated every frame: drawn as set, riding the body's own
	# interpolated transform.
	visual.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	body.add_child(visual)
	body.set("_visual", visual)

	# Placed before entering the tree, so physics starts it where it belongs,
	# in its parent's space: the parent may itself be moved or turned.
	var parent := guard.get_parent()
	body.transform = (parent as Node3D).global_transform.affine_inverse() * rest if parent is Node3D else rest
	body.set("dead", killed)

	if man != null:
		# Where the man stands to fall: where he stood, unless the body had to
		# lie somewhere else, and then along with it.
		var meant := Transform3D(Basis(Vector3.UP, yaw), centre)
		var stood_at := Transform3D(Basis(Vector3.UP, guard.global_rotation.y), guard.global_position)
		body.set_meta(&"man_at", rest * meant.affine_inverse() * stood_at)

	parent.add_child(body)
	body.reset_physics_interpolation()
	var falls_for: float = 0.5 if killed else 0.62

	if man != null and rig.has_method("fall_time"):
		falls_for = rig.fall_time(killed)

	body.call("play_fall", stood, falls_for)
	return body
