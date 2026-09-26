extends Node3D
## Your own arms, seen from inside your head: the base character in your
## colours (Humanoid.gd), made small about your eye just as the things you
## hold are, so that in the view they are full size. Each hand reaches for
## what HandSlot says it holds (ArmReach.gd): the grip of your sword, the
## purse, a ledge. Only the arms ever come into view: the head you are inside
## is folded away and the rest of you hangs below the frame.
##
## Drawn like everything in your hands, on the viewmodel layer and in front of
## the world (a squeezed depth, so the fingers still close over the grip).

const HumanoidScript := preload("res://scripts/Visual/Humanoid.gd")
const ArmReachScript := preload("res://scripts/Visual/ArmReach.gd")

## How small the view's world is drawn: the scale the sword is held at.
const SCALE := 0.62
## The point of him that sits at your eye, in his own space (full size). A
## little lower than his real eyes and behind them, over his shoulders: they
## come up just behind and below your view, where arms that hold a blade out
## in front would be.
const EYE := Vector3(0.0, 1.62, 0.1)
## The viewmodel's depth squeeze (BaseMaterial3D.z_clip_scale).
const Z_CLIP := 0.05

enum Side { LEFT, RIGHT }

var man: Node3D
var reach: SkeletonModifier3D


func setup(layer: int) -> void:
	name = "Arms"
	scale = Vector3.ONE * SCALE
	man = HumanoidScript.new()
	man.build(&"player")
	add_child(man)
	man.position = -EYE
	# Standing easy: only the arms move, by reaching.
	man.show_action(&"Idle", 0.4, 0.001)

	reach = ArmReachScript.new()
	reach.name = "Reach"
	reach.set("man", man)
	reach.set("folded", [&"neck_01"] as Array[StringName])
	man.skeleton.add_child(reach)

	man.add_boots()

	for mesh in man.find_children("*", "MeshInstance3D", true, false):
		var instance := mesh as MeshInstance3D
		instance.layers = layer
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.extra_cull_margin = 2.0
		_viewmodel(instance)


## A hand to `target` (a transform in the parent's space, the view's small
## world), by `weight`, the fingers closed by `curl`.
func set_hand(side: int, target: Transform3D, weight: float, curl: float) -> void:
	reach.targets[side] = _to_man(target)
	reach.weights[side] = clampf(weight, 0.0, 1.0)
	reach.curls[side] = clampf(curl, 0.0, 1.0)


## The right foot to `target` (parent's space), by `weight`.
func set_foot(target: Transform3D, weight: float) -> void:
	reach.foot_target = _to_man(target)
	reach.foot_weight = clampf(weight, 0.0, 1.0)


## Which way the forearm will run to a wrist at `wrist` (the parent's space,
## the view's small world): from where the elbow bends, the same way the arm
## will solve it (ArmReach.gd). A hand that holds its fingers along this has
## a straight wrist.
func forearm_to(side: int, wrist: Vector3) -> Vector3:
	var suffix := "l" if side == Side.LEFT else "r"
	var into := get_parent_node_3d().global_transform.affine_inverse() if get_parent_node_3d() != null else Transform3D.IDENTITY
	var shoulder: Vector3 = into * man.bone_global(StringName("upperarm_" + suffix)).origin
	var elbow_rest: Vector3 = into * man.bone_global(StringName("lowerarm_" + suffix)).origin
	var wrist_rest: Vector3 = into * man.bone_global(StringName("hand_" + suffix)).origin
	var a := shoulder.distance_to(elbow_rest)
	var b := elbow_rest.distance_to(wrist_rest)
	var to := wrist - shoulder

	# The shoulder slides out for a long reach, as the arm will.
	var short := to.length() - (a + b) * ArmReachScript.REACH

	if short > 0.0:
		shoulder += to.normalized() * minf(short, ArmReachScript.SHOULDER_GIVE * SCALE)
		to = wrist - shoulder

	var d := clampf(to.length(), absf(a - b) + 0.001, (a + b) * 0.999)
	var along := to.normalized()
	var hint: Vector3 = ArmReachScript.ELBOW_HINT[side]
	var out := (hint - along * hint.dot(along)).normalized()
	var cos_a := clampf((a * a + d * d - b * b) / (2.0 * a * d), -1.0, 1.0)
	var elbow := shoulder + along * (a * cos_a) + out * (a * sqrt(1.0 - cos_a * cos_a))
	return (shoulder + along * d - elbow).normalized()


## Where a hand is now (world space): the view's small world, so along the
## same line from the eye as the real thing.
func hand_position(side: int) -> Vector3:
	if reach.weights[side] > 0.0:
		return reach.solved_hands[side]

	return man.bone_global(&"hand_l" if side == Side.LEFT else &"hand_r").origin


## A point in the real world, as seen from the eye, in the view's small world.
static func shrink(camera_space: Transform3D) -> Transform3D:
	return Transform3D(camera_space.basis, camera_space.origin * SCALE)


func _to_man(target: Transform3D) -> Transform3D:
	# Parent space -> ours (scaled about the eye) -> his.
	var ours := transform.affine_inverse() * target
	return man.transform.affine_inverse() * Transform3D(ours.basis.orthonormalized(), ours.origin)


## Every surface drawn in front of the world, depth-sorted among themselves.
func _viewmodel(instance: MeshInstance3D) -> void:
	if instance.material_override is BaseMaterial3D:
		instance.material_override = _squeezed(instance.material_override)
		return

	if instance.mesh == null:
		return

	for i in range(instance.mesh.get_surface_count()):
		var source := instance.get_surface_override_material(i)

		if source == null:
			source = instance.mesh.surface_get_material(i)

		if source is BaseMaterial3D:
			instance.set_surface_override_material(i, _squeezed(source))


static func _squeezed(source: Material) -> BaseMaterial3D:
	var material := (source as BaseMaterial3D).duplicate() as BaseMaterial3D
	material.use_z_clip_scale = true
	material.z_clip_scale = Z_CLIP
	return material
