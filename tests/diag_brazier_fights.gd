extends Node3D
## The brazier in real fights, for Movie Maker, first person: a stand-in player hunts each ánima form in turn, the elite mouth, then a revenant, then a mixed lot. Lashes at range, close hits up close.
##   Godot --path . --resolution 1280x720 --fixed-fps 60 --write-movie <file>.avi res://tests/diag_brazier_fights.tscn

const GYM := preload("res://maps/hunt_gym.tscn")
const AnimaScript := preload("res://scripts/Monsters/Anima.gd")
const RevenantScript := preload("res://scripts/Monsters/Revenant.gd")
const CombatScript := preload("res://scripts/Combat/PlayerCombat.gd")
const TURNS := 3.2
const LASHES_WITHIN := 5.2
const CLOSE_WITHIN := 2.5

var gym: Node3D
var p: CharacterBody3D
var _report: Array[String] = []


func _ready() -> void:
	# (Filming: a window losing focus mustn't stop it.)
	process_mode = Node.PROCESS_MODE_ALWAYS
	gym = GYM.instantiate()
	add_child(gym)
	await _frames(60)
	gym.set_physics_process(false)

	for other in get_tree().get_nodes_in_group(&"monsters"):
		other.queue_free()

	p = gym.player
	p.invulnerable = true
	p.hud.visible = true
	p.teleport(Transform3D(Basis.IDENTITY, Vector3(0, 1.05, -8)))
	# (Enough light to judge it by.)
	var lit := OmniLight3D.new()
	lit.light_color = Color(0.85, 0.82, 0.78)
	lit.light_energy = 1.6
	lit.omni_range = 22.0
	lit.position = Vector3(0, 6, -20)
	gym.add_child(lit)
	p.loadout.pack_item(&"brazier")
	await _frames(10)
	p.inventory.select_by_id(&"brazier")
	await _frames(70)
	await _fight("hands", [[&"hands", Vector3(-1.5, 1, -15)], [&"hands", Vector3(1.5, 1, -16)], [&"hands", Vector3(0, 1, -17)], [&"hands", Vector3(-2.5, 1, -17)], [&"hands", Vector3(2.5, 1, -17)]], 18.0)
	await _fight("face", [[&"face", Vector3(-1, 1, -16)], [&"face", Vector3(2, 1, -17)]], 16.0)
	await _fight("torso", [[&"torso", Vector3(0, 1, -17)]], 18.0)
	await _fight("elite mouth", [[&"elite", Vector3(0, 1, -18)]], 22.0)
	await _fight("revenant", [[&"revenant", Vector3(0, 0, -19)]], 24.0)
	await _fight("mixed", [[&"revenant", Vector3(-3, 0, -20)], [&"face", Vector3(3, 1, -18)], [&"hands", Vector3(0, 1, -17)], [&"hands", Vector3(2, 1, -16)]], 26.0)
	await _frames(90)

	for line in _report:
		print("FIGHT ", line)

	get_tree().quit()


func _fight(what: String, foes: Array, most: float) -> void:
	var these: Array[Node3D] = []

	for foe: Array in foes:
		var one: Node3D

		if foe[0] == &"revenant":
			one = RevenantScript.new()
		else:
			one = AnimaScript.new()
			one.form = &"torso" if foe[0] == &"elite" else foe[0]
			one.elite = foe[0] == &"elite"

		one.position = p.global_position + Vector3(0, -1.05, 0) + (foe[1] as Vector3) + Vector3(0, 0, 8)
		gym.add_child(one)
		these.append(one)

		if foe[0] != &"revenant":
			one.wake()
			one.rise()

	var left := most
	var swings := 0
	var hits := [0]
	var count_hit := func(_target, result, _dealt):
		if result != &"none":
			hits[0] += 1
	p.combat.landed.connect(count_hit)

	while left > 0.0:
		get_tree().paused = false
		p.health = 100.0
		p.combat.stamina = p.combat.stamina_max
		p.combat.adrenaline = 0.0

		if p.get("touch") != null:
			p.touch.clear()

		var near: Node3D = null
		var best := INF

		for one in these:
			if is_instance_valid(one) and not one.dead:
				var far: float = one.global_position.distance_to(p.global_position)

				if far < best:
					best = far
					near = one

		if near == null:
			break

		_look_at(near)

		# (Walks up on what's keeping off.)
		if best > LASHES_WITHIN - 0.6 and p.combat.phase == CombatScript.Phase.IDLE:
			Input.action_press("move_forward")
		else:
			Input.action_release("move_forward")

		if p.combat.phase == CombatScript.Phase.IDLE and best < LASHES_WITHIN and _on_it(near):
			swings += 1

			if best < CLOSE_WITHIN:
				Input.action_press("throw")

				for i in 16:
					await get_tree().physics_frame
					_look_at(near) if is_instance_valid(near) else null

				Input.action_release("throw")
			else:
				Input.action_press("throw")
				await _frames(2)
				Input.action_release("throw")

		await get_tree().physics_frame
		left -= 1.0 / 60.0

	p.combat.landed.disconnect(count_hit)
	Input.action_release("move_forward")
	_report.append("%s: %d swings, %d landed, %.1f s, %d left" % [what, swings, hits[0], most - left, these.filter(func(one): return is_instance_valid(one) and not one.dead).size()])

	for one in these:
		if is_instance_valid(one):
			one.queue_free()

	await _frames(50)


func _aim_at(one: Node3D) -> Vector3:
	var height: float = 1.3 if one is CharacterBody3D and one.get("kind") == &"revenant" else (0.5 if String(one.get("form")) == "hands" else 1.0)
	return one.global_position + Vector3.UP * height


func _look_at(one: Node3D) -> void:
	var neck: Node3D = p.get_node("Neck")
	var to: Vector3 = _aim_at(one) - neck.global_position
	var yaw := atan2(-to.x, -to.z)
	var turn := wrapf(yaw - p.global_rotation.y, -PI, PI)
	p.rotate_y(clampf(turn, -TURNS / 60.0, TURNS / 60.0))
	var pitch := atan2(to.y, Vector2(to.x, to.z).length())
	neck.rotation.x = move_toward(neck.rotation.x, clampf(pitch, -1.2, 1.2), TURNS / 60.0)


func _on_it(one: Node3D) -> bool:
	var at: Transform3D = p.combat.aim()
	var to: Vector3 = (_aim_at(one) - at.origin).normalized()
	return (-at.basis.z).dot(to) > 0.985


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
