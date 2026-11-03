extends "res://maps/hunt_gym.gd"
## The ánima gym: the hunt gym's room and dark yard, with drains and grilles for them
## to come up out of, a doorway and a pinch to lay a line in, and room to be crowded.
## No eyes, so they are judged alone. F5 starts it again, F6 calls the next wave.

const AnimaScript := preload("res://scripts/Monsters/Anima.gd")
## How often one that could leap does: the rest come on and cut you.
const LEAP_CHANCE := 0.45

## Each wave, by form.
## How many start round an elite, and how far from it.
const ELITE_KEEPS := 6
const ELITE_KEEPS_AT := 2.4
const ANIMA_WAVES := [{&"hands": 5}, {&"face": 2, &"hands": 4}, {&"torso": 1, &"face": 2, &"hands": 4}, {&"elite": 1, &"face": 2, &"hands": 4}]
## Where they come up: drains in the floor, grilles low in the walls.
const DRAINS := [Vector3(-8, 0, -14), Vector3(8, 0, -18), Vector3(0, 0, -26), Vector3(-10, 0, -30), Vector3(10, 0, -32)]
const GRILLES := [Vector3(-14.6, 0, -24), Vector3(14.6, 0, -12), Vector3(-4, 0, -35.6)]
const DRAIN_SIZE := Vector3(1.2, 0.04, 1.2)
## A wall across the yard with a gap to hold: where it is, the gap in it.
const PINCH_Z := -11.0
const PINCH_GAP := Vector2(-2.6, 2.6)


func _map_id() -> StringName:
	return &"anima_gym"


func _kit() -> Array:
	return [
		[&"lead", &"round", Color(0.62, 0.66, 0.72)],
		[&"copal", &"round", Color(1.0, 0.58, 0.12)],
		[&"copal_line", &"item", Color(0.9, 0.55, 0.2)],
	]


func _clue() -> String:
	return "anima_clue"


func _yard() -> void:
	super._yard()
	Props.block(self, Vector3((YARD.position.x + PINCH_GAP.x) * 0.5, 2.0, PINCH_Z), Vector3(PINCH_GAP.x - YARD.position.x, 4.0, 0.6), DARK)
	Props.block(self, Vector3((YARD.end.x + PINCH_GAP.y) * 0.5, 2.0, PINCH_Z), Vector3(YARD.end.x - PINCH_GAP.y, 4.0, 0.6), DARK)

	for at in DRAINS:
		_dark_slot(at, DRAIN_SIZE)

	for at in GRILLES:
		_dark_slot(at + Vector3.UP * 0.35, Vector3(1.0, 0.7, 1.0))


func _dark_slot(at: Vector3, size: Vector3) -> void:
	var slot := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	var look := StandardMaterial3D.new()
	look.albedo_color = Color(0.02, 0.02, 0.025)
	box.material = look
	slot.mesh = box
	add_child(slot)
	slot.global_position = at


func _lay_out_waves() -> void:
	var spawns: Array = DRAINS + GRILLES
	var next := 0
	var seed_value := 1

	for number in ANIMA_WAVES.size():
		var members: Array = []
		var elite_at := Vector3.INF

		for form in ANIMA_WAVES[number]:
			for i in int(ANIMA_WAVES[number][form]):
				var anima: Node3D = AnimaScript.new()
				anima.form = &"torso" if form == &"elite" else form
				anima.elite = form == &"elite"
				anima.rests = true
				anima.leap_chance = LEAP_CHANCE
				anima.name = "Anima%d" % seed_value
				seed_value += 1
				var spot: Vector3 = spawns[next % spawns.size()]
				next += 1

				# What is drawn to an elite starts by it.
				if form == &"elite":
					elite_at = spot
				elif elite_at != Vector3.INF:
					var round_it := float(members.size()) / float(ELITE_KEEPS) * TAU
					spot = elite_at + Vector3(cos(round_it), 0.0, sin(round_it)) * ELITE_KEEPS_AT

				anima.position = Vector3(spot.x, 0.5 if form != &"face" else 1.3, spot.z)
				add_child(anima)
				anima.sleep()
				members.append(anima)

		_waves.append(members)


func _wake_member(anima: Node3D) -> void:
	anima.wake()
	anima.rise()


func _guard_in_wave(_number: int) -> bool:
	return false


