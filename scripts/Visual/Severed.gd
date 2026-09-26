extends SkeletonModifier3D
## What has been cut away from him (Humanoid.sever): each bone listed, and
## everything hanging off it, is drawn shrunk to nothing where it joined him.
## The last word on his pose, after physics (Ragdoll.gd).

var bones: Array[StringName] = []
var _index := {}


func _process_modification() -> void:
	var skeleton := get_skeleton()

	if skeleton == null:
		return

	for bone in bones:
		if not _index.has(bone):
			_index[bone] = skeleton.find_bone(bone)

		var index: int = _index[bone]

		if index >= 0:
			skeleton.set_bone_pose_scale(index, Vector3.ONE * 0.001)
