extends "res://maps/hunt_gym.gd"
## The revenant gym: the hunt gym's room and dark yard, and the drowned, alone, so they can be judged alone. One, then two, then three. F5 starts it again, F6 calls the next wave.

const RevenantScript := preload("res://scripts/Monsters/Revenant.gd")
const REVENANT_WAVES := [1, 2, 3]
## Where they start, far down the yard.
const COMES_FROM := [Vector3(-2, 0, -30), Vector3(8, 0, -28), Vector3(-9, 0, -27)]


func _map_id() -> StringName:
	return &"revenant_gym"


func _kit() -> Array:
	return [
		[&"lead", &"round", Color(0.62, 0.66, 0.72)],
		[&"copal", &"round", Color(1.0, 0.58, 0.12)],
		[&"fire", &"round", Color(1.0, 0.36, 0.08)],
		[&"egg", &"item", Color(0.9, 0.86, 0.76)],
	]


func _clue() -> String:
	return ""


func _lay_out_waves() -> void:
	var seed_value := 1

	for number in REVENANT_WAVES.size():
		var members: Array = []

		for i in int(REVENANT_WAVES[number]):
			var one: Node3D = RevenantScript.new()
			one.name = "Revenant%d" % seed_value
			seed_value += 1
			one.position = COMES_FROM[i]
			add_child(one)
			one.sleep()
			members.append(one)

		_waves.append(members)


func _wake_member(one: Node3D) -> void:
	one.wake()


func _guard_in_wave(_number: int) -> bool:
	return false
