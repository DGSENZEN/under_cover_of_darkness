extends PhysicalBoneSimulator3D
## Going limp: a body of bones laid over the skeleton (PhysicalBone3D), which
## takes over from the animation when he falls and lets physics have him:
## killed, knocked out, kicked off his feet, flung by a blast. Until then the
## bones touch nothing and cost next to nothing.
##
## Built with the person (Humanoid.add_ragdoll), while he still stands in his
## rest pose: arms out, legs straight. Each joint's limits are measured from
## that pose and about the bone's own axes, so a knee bends about its +X by up
## to 140 degrees and never the other way.
##
##   man.ragdoll.go_limp(velocity)             # falls as he was moving
##   man.ragdoll.shove(push, at)               # the struck part the most
##   man.ragdoll.recover(0.35)                 # back under the animation
##   man.ragdoll.centre()                      # his hips (world)
##
## Bodies are on the bodies' physics layer (GuardBody.LAYER): they rest on the
## world and on each other, the player walks through them, and whatever finds
## one of them (a blade, a hazard, the frob ray) asks `owner_node` what it
## belongs to: the guard while he lives, his body once he is dead.

const LAYER := 4
const MASK := 1 | 4

## [bone, shape, a, b, size, mass, limits x, y, z (lower, upper degrees)].
## capsule: from bone a's rest position to bone b's, `size` [radius, extra
##   length past b]. sphere: at bone a + `b` (an offset), radius `size`. box:
##   at bone a + `b`, `size` its extent, square to the body (x across,
##   y up, z forward).
## Limits are about the bone's own axes: x bends (a knee, an elbow +), y turns
## about the bone's length, z swings sideways. The first body has no joint.
const BODIES := [
	[&"pelvis", &"box", &"pelvis", Vector3(0.0, 0.04, 0.0), Vector3(0.3, 0.2, 0.2), 11.0, [], [], []],
	[&"spine_02", &"box", &"spine_02", Vector3(0.0, 0.02, 0.0), Vector3(0.28, 0.2, 0.18), 9.0, [-30.0, 30.0], [-20.0, 20.0], [-18.0, 18.0]],
	[&"spine_03", &"box", &"spine_03", Vector3(0.0, 0.12, 0.0), Vector3(0.34, 0.26, 0.21), 13.0, [-25.0, 25.0], [-20.0, 20.0], [-15.0, 15.0]],
	[&"neck_01", &"sphere", &"Head", Vector3(0.0, 0.09, 0.02), 0.115, 5.0, [-45.0, 50.0], [-50.0, 50.0], [-35.0, 35.0]],
	[&"upperarm_l", &"capsule", &"upperarm_l", &"lowerarm_l", [0.055, 0.0], 2.5, [-80.0, 80.0], [-45.0, 45.0], [-80.0, 80.0]],
	[&"lowerarm_l", &"capsule", &"lowerarm_l", &"hand_l", [0.045, 0.09], 1.8, [0.0, 140.0], [-15.0, 15.0], [-5.0, 5.0]],
	[&"upperarm_r", &"capsule", &"upperarm_r", &"lowerarm_r", [0.055, 0.0], 2.5, [-80.0, 80.0], [-45.0, 45.0], [-80.0, 80.0]],
	[&"lowerarm_r", &"capsule", &"lowerarm_r", &"hand_r", [0.045, 0.09], 1.8, [0.0, 140.0], [-15.0, 15.0], [-5.0, 5.0]],
	[&"thigh_l", &"capsule", &"thigh_l", &"calf_l", [0.075, 0.0], 8.0, [-110.0, 25.0], [-25.0, 25.0], [-45.0, 45.0]],
	[&"calf_l", &"capsule", &"calf_l", &"foot_l", [0.05, 0.0], 5.0, [0.0, 140.0], [-5.0, 5.0], [-5.0, 5.0]],
	[&"thigh_r", &"capsule", &"thigh_r", &"calf_r", [0.075, 0.0], 8.0, [-110.0, 25.0], [-25.0, 25.0], [-45.0, 45.0]],
	[&"calf_r", &"capsule", &"calf_r", &"foot_r", [0.05, 0.0], 5.0, [0.0, 140.0], [-5.0, 5.0], [-5.0, 5.0]],
]

## What a part of him that is found belongs to (a Guard, a GuardBody).
var owner_node: Node3D
## The person this is part of (Humanoid.gd).
var man: Node3D

var _bodies := {}
var _limp := false
## How long since he last went limp or was shoved: a body gives up its
## motion quickly once it is down (flesh, cloth, the floor), so the damping
## rises from loose to heavy over the first second or so.
var _loose_for := 0.0
var _recover_left := 0.0
var _recover_time := 0.0


## Every body for the skeleton, in its rest pose. `mass_scale`: a bigger man
## is a heavier one.
func build(p_man: Node3D, mass_scale := 1.0) -> void:
	man = p_man
	name = "Ragdoll"
	active = false
	var skeleton: Skeleton3D = man.skeleton

	for spec in BODIES:
		var bone := skeleton.find_bone(spec[0])

		if bone < 0:
			continue

		var rest := skeleton.get_bone_global_rest(bone)
		var shape := CollisionShape3D.new()
		shape.name = "Shape"
		# Where the body's middle is, and how it lies, in the skeleton's space.
		var middle := Transform3D.IDENTITY

		match spec[1]:
			&"capsule":
				var from := skeleton.get_bone_global_rest(skeleton.find_bone(spec[2])).origin
				var to := skeleton.get_bone_global_rest(skeleton.find_bone(spec[3])).origin
				var along := (to - from).normalized()
				to += along * float(spec[4][1])
				var radius: float = spec[4][0]
				var capsule := CapsuleShape3D.new()
				capsule.radius = radius
				capsule.height = maxf(from.distance_to(to) + radius * 2.0, radius * 2.0 + 0.01)
				shape.shape = capsule
				middle = Transform3D(_basis_along(along), (from + to) * 0.5)
			&"sphere":
				var sphere := SphereShape3D.new()
				sphere.radius = spec[4]
				shape.shape = sphere
				middle = Transform3D(Basis.IDENTITY, skeleton.get_bone_global_rest(skeleton.find_bone(spec[2])).origin + spec[3])
			&"box":
				var box := BoxShape3D.new()
				box.size = spec[4]
				shape.shape = box
				middle = Transform3D(Basis.IDENTITY, skeleton.get_bone_global_rest(skeleton.find_bone(spec[2])).origin + spec[3])

		var body := PhysicalBone3D.new()
		body.name = String(spec[0])
		body.bone_name = spec[0]
		# The body's frame is the bone's, moved to the middle of its shape.
		body.body_offset = Transform3D(Basis.IDENTITY, rest.affine_inverse() * middle.origin)
		shape.transform = Transform3D(rest.basis.inverse() * middle.basis, Vector3.ZERO)
		body.add_child(shape)
		body.mass = float(spec[5]) * mass_scale
		body.friction = 0.85
		body.bounce = 0.0
		body.linear_damp = 0.15
		body.angular_damp = 3.0
		body.can_sleep = true
		# Nothing to touch until he falls: standing, the bones are left where
		# they were made and would be obstacles nobody can see.
		body.collision_layer = 0
		body.collision_mask = 0
		body.set_meta(&"ragdoll", self)

		var limits: Array = [spec[6], spec[7], spec[8]]

		if not (limits[0] as Array).is_empty():
			body.joint_type = PhysicalBone3D.JOINT_TYPE_6DOF
			# At the bone's own origin, square to it.
			body.joint_offset = body.body_offset.affine_inverse()

			for i in range(3):
				var axis: String = ["x", "y", "z"][i]
				var span: Array = limits[i]
				# The joint measures the parent's turn from the child's
				# (B inverse A), the other way from the bone's own: mirrored.
				body.set("joint_constraints/%s/angular_limit_enabled" % axis, true)
				body.set("joint_constraints/%s/angular_limit_lower" % axis, -float(span[1]))
				body.set("joint_constraints/%s/angular_limit_upper" % axis, -float(span[0]))

		add_child(body)
		_bodies[spec[0]] = body

	# His parts overlap at every joint (a thigh starts inside the hips): left
	# to collide with each other, they shove apart against the joints and
	# never lie still.
	var parts := _bodies.values()

	for i in range(parts.size()):
		for j in range(i + 1, parts.size()):
			(parts[i] as PhysicalBone3D).add_collision_exception_with(parts[j])


## A basis whose +Y runs along `along` (a capsule lies along its Y).
static func _basis_along(along: Vector3) -> Basis:
	var y := along.normalized()
	var ref := Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x := y.cross(ref).normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)


# ---------------------------------------------------------------------------
# Falling and getting up
# ---------------------------------------------------------------------------

## Lets physics have him from the pose he is in, every part moving at
## `velocity` (how he was moving).
func go_limp(velocity := Vector3.ZERO) -> void:
	var rising := _recover_left > 0.0
	_recover_left = 0.0
	influence = 1.0

	if _limp:
		# Down again on his way up: the rise stops where it is, hands and
		# feet with it.
		if rising and man != null and man.has_method("hold_still"):
			man.hold_still()

		return

	_limp = true
	_loose_for = 0.0
	active = true
	set_physics_process(true)

	if man != null and man.has_method("hold_still"):
		man.hold_still()

	for part in _bodies.values():
		(part as PhysicalBone3D).collision_layer = LAYER
		(part as PhysicalBone3D).collision_mask = MASK

	physical_bones_start_simulation()
	_clear_of_world()

	# You walk over a body; it is not shoved about by your legs.
	for walker in get_tree().get_nodes_in_group(&"player"):
		if walker is PhysicsBody3D:
			for part in _bodies.values():
				(part as PhysicalBone3D).add_collision_exception_with(walker)

	for body in _bodies.values():
		(body as PhysicalBone3D).linear_velocity = velocity


## A hand or a blade that was in a wall as he fell would be flung out of it
## hard, and him with it: all of him is eased out of the wall first.
func _clear_of_world() -> void:
	var space := get_world_3d().direct_space_state

	for attempt in range(6):
		var away := Vector3.ZERO

		for part in _bodies.values():
			for child in (part as Node).get_children():
				if not (child is CollisionShape3D):
					continue

				var query := PhysicsShapeQueryParameters3D.new()
				query.shape = (child as CollisionShape3D).shape
				query.transform = (child as CollisionShape3D).global_transform
				query.collision_mask = 1
				query.margin = -0.01
				var info := space.get_rest_info(query)

				if info.is_empty():
					continue

				# The floor under him is where he is meant to be; only walls.
				var normal: Vector3 = info["normal"]
				normal.y = 0.0

				if normal.length() > 0.3:
					away = normal.normalized()
					break

			if away != Vector3.ZERO:
				break

		if away == Vector3.ZERO:
			return

		move_by(away * 0.08)


## A blow or a boot: the part at `at` moves at `push` the most, the rest of
## him less the further it is. `at` INF: all of him alike.
func shove(push: Vector3, at := Vector3.INF, reach := 0.6) -> void:
	if not _limp:
		return

	# Moving again: loose again.
	_loose_for = 0.0
	set_physics_process(true)

	for body in _bodies.values():
		var part := body as PhysicalBone3D
		var share := 1.0

		if at != Vector3.INF:
			share = lerpf(0.45, 1.0, clampf(1.0 - part.global_position.distance_to(at) / reach, 0.0, 1.0))

		part.linear_velocity += push * share


## Back under the animation's control over `seconds`: the pose he lies in
## gives way to the one he is animated in (getting up).
func recover(seconds := 0.35) -> void:
	if not _limp:
		return

	_recover_time = maxf(seconds, 0.01)
	_recover_left = _recover_time

	if seconds <= 0.0:
		_stop()


func _physics_process(delta: float) -> void:
	if not _limp:
		return

	_loose_for += delta
	var heavy := smoothstep(0.6, 1.6, _loose_for)

	for part in _bodies.values():
		var body := part as PhysicalBone3D
		body.linear_damp = lerpf(0.15, 0.9, heavy)
		body.angular_damp = lerpf(3.0, 9.0, heavy)

	# As heavy as he gets: nothing to change until he is moved again.
	if heavy >= 1.0:
		set_physics_process(false)


func _process(delta: float) -> void:
	if _recover_left <= 0.0:
		return

	_recover_left -= delta
	influence = clampf(_recover_left / _recover_time, 0.0, 1.0)

	if _recover_left <= 0.0:
		_stop()


func _stop() -> void:
	physical_bones_stop_simulation()

	for part in _bodies.values():
		(part as PhysicalBone3D).collision_layer = 0
		(part as PhysicalBone3D).collision_mask = 0

	_limp = false
	_recover_left = 0.0
	influence = 1.0
	active = false


func is_limp() -> bool:
	return _limp


## Getting up: limp still, but on the way back to the animation.
func is_recovering() -> bool:
	return _limp and _recover_left > 0.0


# ---------------------------------------------------------------------------
# Where he is
# ---------------------------------------------------------------------------

func body(bone: StringName) -> PhysicalBone3D:
	return _bodies.get(bone) as PhysicalBone3D


func bodies() -> Array:
	return _bodies.values()


## His hips, his head, the middle of his chest (world).
func centre() -> Vector3:
	var hips := body(&"pelvis")
	return hips.global_position if hips != null else global_position


func head() -> Vector3:
	var part := body(&"neck_01")
	return part.global_position if part != null else centre() + Vector3.UP * 0.6


func chest() -> Vector3:
	var part := body(&"spine_03")
	return part.global_position if part != null else centre()


## Lying on his back: his chest's front (the bone's +Z) is to the sky.
func face_up() -> bool:
	var part := body(&"spine_03")
	return part == null or part.global_basis.z.y > 0.0


func velocity() -> Vector3:
	var hips := body(&"pelvis")
	return hips.linear_velocity if hips != null else Vector3.ZERO


## The fastest any of his heavy parts is moving.
func speed() -> float:
	var fastest := 0.0

	for bone in [&"pelvis", &"spine_03", &"neck_01"]:
		var part := body(bone)

		if part != null:
			fastest = maxf(fastest, part.linear_velocity.length())

	return fastest


func total_mass() -> float:
	var sum := 0.0

	for part in _bodies.values():
		sum += (part as PhysicalBone3D).mass

	return sum


func rids() -> Array[RID]:
	var found: Array[RID] = []

	for part in _bodies.values():
		found.append((part as PhysicalBone3D).get_rid())

	return found


## All of him, moved by `shift` and brought to a stop (put somewhere).
func move_by(shift: Vector3) -> void:
	for part in _bodies.values():
		var body := part as PhysicalBone3D
		body.global_position += shift
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO


## A part of him cut away (Humanoid.sever): its bodies go with it.
func drop_bodies(bones: Array) -> void:
	for bone in bones:
		if _bodies.has(bone):
			var part: PhysicalBone3D = _bodies[bone]
			_bodies.erase(bone)
			part.queue_free()


## What the part `node` (a PhysicalBone3D) belongs to, if it is one of these.
static func owner_of(node: Object) -> Node3D:
	if not is_instance_valid(node):
		return null

	if node is Node and (node as Node).has_meta(&"ragdoll"):
		var ragdoll = (node as Node).get_meta(&"ragdoll")

		if is_instance_valid(ragdoll):
			return ragdoll.owner_node

	return null


## The ragdoll `node` (a PhysicalBone3D) is part of.
static func of(node: Object) -> Node:
	if not is_instance_valid(node):
		return null

	if node is Node and (node as Node).has_meta(&"ragdoll"):
		var ragdoll = (node as Node).get_meta(&"ragdoll")

		if is_instance_valid(ragdoll):
			return ragdoll

	return null
