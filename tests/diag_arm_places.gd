extends Node3D
## Diagnostic: where each arm's shoulder, elbow and hand are drawn (camera
## space) through station 17's reaches, old arms then new (FP_ARMS).
const GYM := preload("res://maps/traversal_gym.tscn")

func _ready() -> void:
	var gym = GYM.instantiate()
	add_child(gym)
	for i in 10: await get_tree().physics_frame
	var p = get_tree().get_first_node_in_group("player")
	p.inventory.select_by_id(&"")
	gym.select_station(16)
	for i in 20: await get_tree().physics_frame
	Input.action_press("sprint")
	Input.action_press("move_forward")
	var arms = p.hand._arms
	for i in 260:
		await get_tree().physics_frame
		var label: String = String(p.current_move.label) if p.current_move != null else "-"
		if i % 6 == 0 and label in ["wall run", "reach", "leap"]:
			var cam: Camera3D = p.camera
			var inv := cam.global_transform.affine_inverse()
			var line := "%3d %-8s held %.2f scale %.2f" % [i, label, arms.held(), arms.scale.x]
			for side in [0, 1]:
				if arms.reach.weights[side] > 0.5:
					line += " | %s S%s E%s H%s" % ["L" if side == 0 else "R", (inv * arms.reach.solved_shoulders[side]).snapped(Vector3.ONE * 0.01), (inv * arms.reach.solved_elbows[side]).snapped(Vector3.ONE * 0.01), (inv * arms.reach.solved_hands[side]).snapped(Vector3.ONE * 0.01)]
			print(line)
	get_tree().quit()
