extends Node3D
## The combat gym (maps/combat_gym.tscn) builds, with its range bay: the
## revolver and its stocks on the belt, the dummies, the men, the table.

const GYM := preload("res://maps/combat_gym.tscn")

var results: Array[String] = []


func _ready() -> void:
	var gym: Node3D = GYM.instantiate()
	add_child(gym)
	await _frames(120)
	var player: Node = get_tree().get_first_node_in_group(&"player")
	var bay := AABB(Vector3(30, -1, -48), Vector3(30, 6, 40))
	var dummies := 0
	var men := 0

	for node in gym.get_children():
		if node is Node3D and bay.has_point((node as Node3D).global_position):
			if node.has_method("take_hit") and node.get_script() == preload("res://scripts/Combat/TrainingDummy.gd"):
				dummies += 1
			elif node.is_in_group(&"guards"):
				men += 1

	var armed: bool = player != null and player.inventory.count_of(&"revolver") == 1 and int(player.inventory.ammo[&"rounds"]) > 0
	_check("CG1 the range bay builds: three dummies, three men, the revolver and its rounds on the belt",
		dummies == 3 and men == 3 and armed, "dummies %d men %d armed %s" % [dummies, men, armed])

	print("\n==== RESULTS ====")
	for r in results:
		print(r)
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
