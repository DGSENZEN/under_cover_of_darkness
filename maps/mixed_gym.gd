extends "res://maps/anima_gym.gd"
## The mixed gym: the ánima gym's room and yard, with the eyes back in it, so the two meet, each
## answered differently and both on you at once. Its last wave is the worst the screen has to answer.
## F5 starts it again, F6 calls the next wave.

## Each wave: ánimas by form, and eyes.
const MIXED_WAVES := [{&"hands": 3, &"eyes": 2}, {&"face": 2, &"hands": 3, &"eyes": 3}, {&"torso": 1, &"face": 2, &"hands": 3, &"eyes": 4}]
## How far out from the yard's middle the eyes wait, and how high.
const EYES_OUT := 8.0
const EYES_HIGH := 3.0
const EYES_MIDDLE := Vector3(0.0, 0.0, -24.0)


func _map_id() -> StringName:
	return &"mixed_gym"


func _kit() -> Array:
	return [
		[&"lead", &"round", Color(0.62, 0.66, 0.72)],
		[&"copal", &"round", Color(1.0, 0.58, 0.12)],
		[&"copal_line", &"item", Color(0.9, 0.55, 0.2)],
		[&"egg", &"item", Color(0.92, 0.88, 0.76)],
	]


func _clue() -> String:
	return "mixed_clue"


func _lay_out_waves() -> void:
	var spawns: Array = DRAINS + GRILLES
	var next := 0
	var seed_value := 1

	for number in MIXED_WAVES.size():
		var members: Array = []

		for what in MIXED_WAVES[number]:
			var many := int(MIXED_WAVES[number][what])

			for i in many:
				var one: Node3D

				if what == &"eyes":
					one = EyeScript.new()
					one.seed_value = seed_value
					one.name = "Eye%d" % seed_value
					var turn := float(i) / float(many) * TAU
					one.position = EYES_MIDDLE + Vector3(cos(turn) * EYES_OUT, EYES_HIGH, sin(turn) * EYES_OUT)
				else:
					one = AnimaScript.new()
					one.form = what
					one.rests = true
					one.leap_chance = LEAP_CHANCE
					one.name = "Anima%d" % seed_value
					var spot: Vector3 = spawns[next % spawns.size()]
					next += 1
					one.position = Vector3(spot.x, 0.5 if what != &"face" else 1.3, spot.z)

				seed_value += 1
				add_child(one)
				one.sleep()
				members.append(one)

		_waves.append(members)


func _wake_member(one: Node3D) -> void:
	if one.get("form") != null:
		super._wake_member(one)
	else:
		one.wake()
		one.state = one.State.CIRCLE
