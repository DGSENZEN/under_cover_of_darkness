extends Node3D
## The Prosecutor's own first-person arms (assets/characters/fp_arms, built by
## tools/arms/build_fp_arms.py): shoulders to fingertips and no body, at a real
## arm's length, with the bones the arm solver uses (ArmReach.gd) and their
## own poses (Open, Fist, Hook). Offers the part of Humanoid's API ViewArms
## needs, facing -Z with the shoulders' middle at (0, 1.45, 0) as his are.

const SCENE := "res://assets/characters/fp_arms/fp_arms.glb"

var skeleton: Skeleton3D
var _library: AnimationLibrary


func build() -> void:
	var model := (load(SCENE) as PackedScene).instantiate() as Node3D
	model.name = "Model"
	add_child(model)
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_library = AnimationLibrary.new()

	for player in model.find_children("*", "AnimationPlayer", true, false):
		for name in (player as AnimationPlayer).get_animation_list():
			if not _library.has_animation(name):
				_library.add_animation(name, (player as AnimationPlayer).get_animation(name))

		# The poses are read, never played: the rest pose is the open hand.
		(player as AnimationPlayer).stop()


## The poses: what the solver learns its closed fist from.
func library() -> AnimationLibrary:
	return _library


func bone_global(bone: StringName) -> Transform3D:
	var index := skeleton.find_bone(bone)

	if index < 0:
		return global_transform

	return skeleton.global_transform * skeleton.get_bone_global_pose(index)


## Standing easy is the rest pose: only the arms move, by reaching.
func show_action(_animation: StringName, _time: float, _fade_in := 0.08, _weight := 1.0) -> void:
	pass


## No feet: the kick keeps the old body's leg (ViewArms).
func add_boots() -> void:
	pass
