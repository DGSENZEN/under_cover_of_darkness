extends Node3D
## The revenant's body as it comes out of Blender (docs/superpowers/specs/2026-11-03-revenant-design.md).

const MODEL := "res://assets/monsters/revenant.glb"
const SHADER := "res://scripts/Monsters/revenant_flesh.gdshader"
const SIDES := ["_l", "_r"]
const MIDDLE := ["root", "hips", "spine", "chest", "neck_1", "neck_2", "head", "jaw", "eye_l", "eye_r"]
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
	# (Its skin: what drifts off it goes where it goes.)
	var skin_arrays: Array = meshes[0].mesh.surface_get_arrays(0)
	var top := -INF
	var bottom := INF

	for i in skin_arrays[Mesh.ARRAY_VERTEX].size():
		if skin_arrays[Mesh.ARRAY_TEX_UV][i].x < 0.001:
			top = maxf(top, skin_arrays[Mesh.ARRAY_VERTEX][i].y)
			bottom = minf(bottom, skin_arrays[Mesh.ARRAY_VERTEX][i].y)

	_check("B1 about 2.6 m tall (%.2f)" % (top - bottom), top - bottom > 2.4 and top - bottom < 2.8)
	_check("B1b it stands on the floor (%.2f)" % bottom, absf(bottom) < 0.03)

	if missing.is_empty():
		var hand := minf(bones.get_bone_global_rest(bones.find_bone("finger_2_b_l")).origin.y, bones.get_bone_global_rest(bones.find_bone("finger_2_b_r")).origin.y)
		var knee := minf(bones.get_bone_global_rest(bones.find_bone("leg_2_l")).origin.y, bones.get_bone_global_rest(bones.find_bone("leg_2_r")).origin.y)
		_check("B3 hands hang below its knees (%.2f, %.2f)" % [hand, knee], hand < knee)
		var wrist := bones.get_bone_global_rest(bones.find_bone("hand_l")).origin
		var head := bones.get_bone_global_rest(bones.find_bone("head")).origin
		_check("B6 it faces the way the game's bodies do (head ahead of its hips)", head.z < bones.get_bone_global_rest(bones.find_bone("hips")).origin.z and wrist.y > 0.0)

	# It never left the lake: what drifts on it says how far along itself it is (UV x), and the seep and its eyes are in the colour's alpha.
	var arrays: Array = meshes[0].mesh.surface_get_arrays(0)
	var drifting := 0
	var seeped := 0
	var burning := 0

	if arrays[Mesh.ARRAY_TEX_UV] != null:
		for uv: Vector2 in arrays[Mesh.ARRAY_TEX_UV]:
			drifting += 1 if uv.x > 0.8 else 0

	if arrays[Mesh.ARRAY_COLOR] != null:
		for colour: Color in arrays[Mesh.ARRAY_COLOR]:
			seeped += 1 if colour.a > 0.2 and colour.a < 0.85 else 0
			burning += 1 if colour.a >= 0.9 else 0

	_check("B7 hair, roots and rags drift off it (%d)" % drifting, drifting > 100)
	_check("B8 the seep is in its skin (%d)" % seeped, seeped > 200)
	_check("B9 its eyes burn (%d)" % burning, burning > 20)
	# Both of them, each out where you can see it: ahead of what's between them.
	var eye_l := bones.get_bone_global_rest(bones.find_bone("eye_l")).origin
	var eye_r := bones.get_bone_global_rest(bones.find_bone("eye_r")).origin
	_check("B10 two eyes, level, about their distance apart (%.3f, %.3f)" % [absf(eye_l.y - eye_r.y), eye_l.distance_to(eye_r)], absf(eye_l.y - eye_r.y) < 0.03 and eye_l.distance_to(eye_r) > 0.07 and eye_l.distance_to(eye_r) < 0.17)
	_check("B11 neither sunk behind the other (%.3f)" % absf(eye_l.z - eye_r.z), absf(eye_l.z - eye_r.z) < 0.03)
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
