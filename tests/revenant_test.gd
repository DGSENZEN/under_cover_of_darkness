extends Node3D
## The revenant (docs/superpowers/specs/2026-11-03-revenant-design.md). `-- --only-<group>` runs one group.

const PLAYER := preload("res://Player.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const BodyScript := preload("res://scripts/Monsters/RevenantBody.gd")
const HOME := Vector3(0, 1.05, 0)

var p: CharacterBody3D
var failed := 0


func _ready() -> void:
	Props.block(self, Vector3(0, -0.5, 0), Vector3(200, 1, 200))
	p = PLAYER.instantiate()
	add_child(p)
	p.debug_traversal = false
	p.invulnerable = true
	p.reload_on_death = false
	p.position = HOME
	Props.give_revolver(p, 200, 40)
	p.inventory.select_by_id(&"revolver")
	p.inventory.ammo[&"copal_rounds"] = 60
	await _frames(60)
	var only := ""

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only-"):
			only = arg.trim_prefix("--only-")

	if only == "" or only == "moves":
		await _it_moves()

	print("revenant_test: %s" % ("FAILED %d" % failed if failed > 0 else "passed"))
	get_tree().quit(1 if failed > 0 else 0)


## On its own, with nothing driving it but a walk and each pose in turn.
func _it_moves() -> void:
	var body: Node3D = BodyScript.new()
	add_child(body)
	body.position = Vector3(0, 0, -12)
	await _frames(1)
	body.tick(1.0 / 60.0, &"walk", Vector3.ZERO, Vector3(0, 1.6, 0), 0.0, 0.0, 0.0)
	var you := Vector3(0, 1.6, 0)
	var going := Vector3(0, 0, 1.6)
	var worst_wrist := 0.0
	var worst_elbow := 0.0
	var worst_head := 0.0
	var worst_slid := 0.0
	var at_wrist := ""
	var at_elbow := ""
	var at_head := ""
	var steps := 0
	var was_down := [true, true]
	var was_at := [body.foot(0), body.foot(1)]
	var wrist_was: Array = [body.wrist(0), body.wrist(1)]
	var elbow_was: Array = [body.elbow(0), body.elbow(1)]
	var head_was: Vector3 = body.head_at()
	var order: Array = [&"walk", &"walk"]
	order.append_array(BodyScript.POSES.keys())
	order.append(&"walk")

	for doing: StringName in order:
		var moves: bool = doing == &"walk" or doing == &"surge" or doing == &"surge_tell"

		for i in 150:
			await get_tree().physics_frame
			var v := Vector3(0, 0, 6.0) if doing == &"surge" else (going if moves else Vector3.ZERO)
			body.position += v / 60.0
			body.tick(1.0 / 60.0, doing, v, you, 0.0, 0.0, 0.0)

			# (Its first frames settle.)
			if doing == &"walk" and i < 30 and steps == 0:
				wrist_was = [body.wrist(0), body.wrist(1)]
				elbow_was = [body.elbow(0), body.elbow(1)]
				head_was = body.head_at()
				was_at = [body.foot(0), body.foot(1)]
				was_down = [body.foot_planted(0), body.foot_planted(1)]
				continue

			for side in 2:
				var wrist_speed: float = body.wrist(side).distance_to(wrist_was[side]) * 60.0
				var elbow_speed: float = body.elbow(side).distance_to(elbow_was[side]) * 60.0

				if wrist_speed > worst_wrist:
					worst_wrist = wrist_speed
					at_wrist = doing

				if elbow_speed > worst_elbow:
					worst_elbow = elbow_speed
					at_elbow = doing

				wrist_was[side] = body.wrist(side)
				elbow_was[side] = body.elbow(side)
				var down: bool = body.foot_planted(side)

				if down and was_down[side]:
					worst_slid = maxf(worst_slid, body.foot(side).distance_to(was_at[side]))
				elif not down and was_down[side]:
					steps += 1

				was_down[side] = down
				was_at[side] = body.foot(side)

			var head_speed: float = body.head_at().distance_to(head_was) * 60.0

			if head_speed > worst_head:
				worst_head = head_speed
				at_head = doing

			head_was = body.head_at()

	_check("M0 it walks: it takes steps (%d)" % steps, steps > 8)
	_check("M1 a planted foot stays put (%.3f m)" % worst_slid, worst_slid < 0.03)
	_check("M2 no wrist pops (%.1f m/s, %s)" % [worst_wrist, at_wrist], worst_wrist < 14.0)
	_check("M2b no elbow pops (%.1f m/s, %s)" % [worst_elbow, at_elbow], worst_elbow < 14.0)
	# (Falling, it is a 2 m fall: that's quick, and it should be.)
	_check("M3 the head never jumps (%.1f m/s, %s)" % [worst_head, at_head], worst_head < 8.5)
	body.queue_free()
	await _frames(2)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _until(done: Callable, most: float) -> bool:
	var left := int(most * 60.0)

	while left > 0:
		if done.call():
			return true

		left -= 1
		await get_tree().physics_frame

	return done.call()


func _check(label: String, ok: bool) -> void:
	print("%s %s" % ["PASS" if ok else "FAIL", label])

	if not ok:
		failed += 1
