extends Node3D
## The revenant's body as it comes out of Blender (docs/superpowers/specs/2026-11-03-revenant-design.md).

const MODEL := "res://assets/monsters/revenant.glb"
const SHADER := "res://scripts/Monsters/revenant_flesh.gdshader"
const SIDES := ["_l", "_r"]
const MIDDLE := ["root", "hips", "spine", "chest", "neck_1", "neck_2", "head", "jaw"]
const EACH_SIDE := ["clavicle", "arm_1", "arm_2", "hand", "thumb", "thumb_b", "finger_1", "finger_1_b", "finger_2", "finger_2_b", "finger_3", "finger_3_b", "finger_4", "finger_4_b", "leg_1", "leg_2", "foot"]

var failed := 0


func _ready() -> void:
	var made: PackedScene = load(MODEL) if ResourceLoader.exists(MODEL) else null
	_check("B0 it is there", made != null)

	if made == null:
		_end()
		return

	var body: Node3D = made.instantiate()
	add_child(body)
	var skeletons := body.find_children("*", "Skeleton3D", true, false)
	var meshes := body.find_children("*", "MeshInstance3D", true, false)
	_check("B4 one skin on one skeleton", skeletons.size() == 1 and meshes.size() == 1)
	var bones: Skeleton3D = skeletons[0]
	var missing: Array[String] = []

	for name in MIDDLE:
		if bones.find_bone(name) < 0:
			missing.append(name)

	for name in EACH_SIDE:
		for side in SIDES:
			if bones.find_bone(name + side) < 0:
				missing.append(name + side)

	_check("B2 every bone the body drives is there (" + str(missing) + ")", missing.is_empty())
	var box: AABB = meshes[0].mesh.get_aabb()
	_check("B1 about 2.6 m tall (%.2f)" % box.size.y, box.size.y > 2.4 and box.size.y < 2.8)
	_check("B1b it stands on the floor (%.2f)" % box.position.y, absf(box.position.y) < 0.03)

	if missing.is_empty():
		var hand := minf(bones.get_bone_global_rest(bones.find_bone("finger_2_b_l")).origin.y, bones.get_bone_global_rest(bones.find_bone("finger_2_b_r")).origin.y)
		var knee := minf(bones.get_bone_global_rest(bones.find_bone("leg_2_l")).origin.y, bones.get_bone_global_rest(bones.find_bone("leg_2_r")).origin.y)
		_check("B3 hands hang below its knees (%.2f, %.2f)" % [hand, knee], hand < knee)
		var wrist := bones.get_bone_global_rest(bones.find_bone("hand_l")).origin
		var head := bones.get_bone_global_rest(bones.find_bone("head")).origin
		_check("B6 it faces the way the game's bodies do (head ahead of its hips)", head.z < bones.get_bone_global_rest(bones.find_bone("hips")).origin.z and wrist.y > 0.0)

	var shader: Shader = load(SHADER) if ResourceLoader.exists(SHADER) else null
	var has := func(param: String) -> bool: return shader != null and shader.code.contains("instance uniform float %s" % param)
	_check("B5 it has eyes to light, flesh to burn and sear", has.call("eyes") and has.call("burn") and has.call("seared"))
	_end()


func _end() -> void:
	print("revenant_model_test: %s" % ("FAILED %d" % failed if failed > 0 else "passed"))
	get_tree().quit(1 if failed > 0 else 0)


func _check(what: String, ok: bool) -> void:
	print("%s %s" % ["PASS" if ok else "FAIL", what])

	if not ok:
		failed += 1
