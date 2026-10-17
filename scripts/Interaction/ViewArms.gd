extends Node3D
## Humanoid arm/foot rig for the camera viewmodel, using ArmReach targets.
## The rig is scaled about the eye; targets use the parent’s small view space.
## Meshes share the viewmodel layer and squeezed depth; hidden body parts
## remain outside the view.

const HumanoidScript := preload("res://scripts/Visual/Humanoid.gd")
const ArmReachScript := preload("res://scripts/Visual/ArmReach.gd")

## How small the view's world is drawn: the scale the sword is held at.
const SCALE := 0.62
## Shoulder to wrist (m, full size): a real arm's length. The model's own
## are short (0.5 m), too short to reach a hold from a hang.
const ARM_LENGTH := 0.65
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
## The arms' own materials (not what they hold), for their depth.
var _materials: Array[BaseMaterial3D] = []
var _depth := Z_CLIP
var _held := 0.0
var _shoulders := Vector3.INF
## Held, his shoulders come this far toward the wall (m, the view's forward),
## and this far down: a hanging body's chest is at the wall, under the hands.
const CLIMB_FORWARD := 0.3
const CLIMB_DOWN := 0.05


## Builds/configures the arm rig and applies the supplied visual layer mask.
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
	reach.set("arm_length", ARM_LENGTH)
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


## Returns the current world hand position from the configured rig; setup() is required.
func hand_position(side: int) -> Vector3:
	if reach.weights[side] > 0.0:
		return reach.solved_hands[side]

	return man.bone_global(&"hand_l" if side == Side.LEFT else &"hand_r").origin


## Scales a full-size camera-space transform’s origin into the viewmodel space.
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
		_materials.append(instance.material_override)
		return

	if instance.mesh == null:
		return

	for i in range(instance.mesh.get_surface_count()):
		var source := instance.get_surface_override_material(i)

		if source == null:
			source = instance.mesh.surface_get_material(i)

		if source is BaseMaterial3D:
			var squeezed := _squeezed(source)
			instance.set_surface_override_material(i, squeezed)
			_materials.append(squeezed)


## Holding on to the world (amount 0..1): the rig grows to true size and the
## shoulders come forward to the wall, as a hanging chest is, and the arms are
## drawn at true depth, so real forearms rise in front of the stone and the
## fingers that curl over its lip are hidden by it. 0: the viewmodel, small and
## in front of everything.
func set_held(amount: float, chest := Vector3.INF) -> void:
	_held = clampf(amount, 0.0, 1.0)
	scale = Vector3.ONE * lerpf(SCALE, 1.0, _held)

	if man != null:
		var placed := -EYE + Vector3(0.0, -CLIMB_DOWN, -CLIMB_FORWARD)

		# The chest under the hands that hold: his shoulders' middle there.
		if chest != Vector3.INF:
			placed = chest - _shoulders_middle()

		man.position = (-EYE).lerp(placed, _held)

	set_depth_scale(1.0 if _held >= 0.5 else Z_CLIP)


## The middle of his shoulders at rest, in his own space (full size).
func _shoulders_middle() -> Vector3:
	if _shoulders == Vector3.INF and man != null and man.get("skeleton") != null:
		var skeleton: Skeleton3D = man.skeleton
		var left := skeleton.find_bone(&"upperarm_l")
		var right := skeleton.find_bone(&"upperarm_r")

		if left >= 0 and right >= 0:
			_shoulders = (skeleton.get_bone_global_rest(left).origin + skeleton.get_bone_global_rest(right).origin) * 0.5

	return _shoulders if _shoulders != Vector3.INF else Vector3(0.0, 1.45, 0.0)


## How far the rig is into its held, true-size form (0..1).
func held() -> float:
	return _held


## A camera-space transform (full size) into the rig's parent space at its
## present size: what shrink() is for the small viewmodel.
func to_rig(camera_space: Transform3D) -> Transform3D:
	return Transform3D(camera_space.basis, camera_space.origin * scale.x)


## Holding on to the world, the arms are drawn at their true depth (the rig is
## SCALE small about the eye; 1 / SCALE undoes it without moving them on
## screen), so the stone hides what curls over it: fingers over a lip. Free,
## squeezed in front of everything again, so they never sink into a wall.
func set_true_depth(on: bool) -> void:
	set_depth_scale(1.0 / SCALE if on else Z_CLIP)


## The arms drawn this much further than they are (about the eye): Z_CLIP in
## front of everything, more than 1 pushed back to where a held hand's grip
## really is (HandSlot), so the stone in front of the grip hides the fingers.
func set_depth_scale(wanted: float) -> void:
	if is_equal_approx(wanted, _depth):
		return

	_depth = wanted

	for material in _materials:
		material.z_clip_scale = wanted


## The arms' depth scale now (Z_CLIP squeezed in front, 1 / SCALE true).
func depth_scale() -> float:
	return _depth


static func _squeezed(source: Material) -> BaseMaterial3D:
	var material := (source as BaseMaterial3D).duplicate() as BaseMaterial3D
	# Keep the first-person representation out of water's reflection source;
	# late depth writes retain correct overlap with held items.
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	material.use_z_clip_scale = true
	material.z_clip_scale = Z_CLIP
	return material
