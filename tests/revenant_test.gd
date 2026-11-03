extends Node3D
## The revenant (docs/superpowers/specs/2026-11-03-revenant-design.md). `-- --only-<group>` runs one group.

const PLAYER := preload("res://Player.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const BodyScript := preload("res://scripts/Monsters/RevenantBody.gd")
const CopalLine := preload("res://scripts/Hunt/CopalLine.gd")
const RevenantScript := preload("res://scripts/Monsters/Revenant.gd")
const Bestiary := preload("res://scripts/Monsters/Bestiary.gd")
const STATE: Dictionary = RevenantScript.State
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

	if only == "" or only == "brain":
		await _its_brain()

	if only == "" or only == "hits":
		await _its_blows()

	if only == "" or only == "touch":
		await _its_touch()

	if only == "" or only == "fire":
		await _fire()

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


## What it is: down isn't dead, and it gets back up.
func _its_brain() -> void:
	await _clean()
	var one := _revenant(Vector3(0, 0, -30))
	await _frames(2)
	one._surge_in = 99.0
	var balls := 0

	while not one.is_down() and balls < 30:
		one.take_hit(55.0, p, &"bullet", one.global_position, Vector3.FORWARD)
		balls += 1

	_check("R1 eleven balls of lead put it down, not ten (%d)" % balls, balls == 11)
	_check("R2 down, not dead", one.is_down() and not one.dead)
	var before: float = one.health
	one.take_hit(55.0, p, &"bullet", one.global_position, Vector3.FORWARD)
	one.take_hit(20.0, p, &"power", one.global_position, Vector3.FORWARD)
	one.kick(Vector3(2, 0, 0), p)
	_check("R3 hits do nothing while it's down", one.health == before and one.is_down())
	var rose: bool = await _until(func(): return one.state == STATE.WALK, 7.2)
	_check("R4 it gets up, after 5 s and 1.6 s, with 40%% (%.0f)" % one.health, rose and one._state_t < 0.5 and is_equal_approx(one.health, 72.0))
	var times := 0

	for i in 3:
		while not one.is_down():
			one.take_hit(55.0, p, &"bullet", one.global_position, Vector3.FORWARD)

		times += 1 if await _until(func(): return one.state == STATE.WALK, 7.2) else 0

	_check("R5 and does so again and again (%d)" % times, times == 3)
	await _clean()
	var walker := _revenant(Vector3(0, 0, -30))
	await _frames(20)
	walker._surge_in = 99.0
	var from: Vector3 = walker.global_position
	await _frames(120)
	var pace: float = walker.global_position.distance_to(from) / 2.0
	_check("R6 walks at 1.6 m/s (%.2f)" % pace, absf(pace - 1.6) < 0.2)
	walker.statuses.apply(&"smoked", 4.0)
	from = walker.global_position
	await _frames(120)
	var smoked_pace: float = walker.global_position.distance_to(from) / 2.0
	_check("R9 copal smoke doesn't slow it (%.2f)" % smoked_pace, absf(smoked_pace - pace) < 0.2)
	var line: Node3D = CopalLine.lay(p, walker.global_position + Vector3(0, 0, 1.2))
	var line_z: float = line.global_position.z
	var crossed: bool = await _until(func(): return walker.global_position.z > line_z + 0.3, 3.0)
	_check("R9b a copal line doesn't stop it", crossed)
	walker._surge_in = 0.0
	var told: bool = await _until(func(): return walker.state == STATE.SURGE_TELL, 0.5)
	var surged: bool = await _until(func(): return walker.state == STATE.SURGE, 1.0)
	from = walker.global_position
	await _frames(30)
	var surge_pace: float = walker.global_position.distance_to(from) / 0.5
	_check("R7 surges at about 6 m/s, with a tell (%.1f)" % surge_pace, told and surged and surge_pace > 5.0)
	await _clean()
	var hit := _revenant(Vector3(0, 0, -30))
	await _frames(20)
	hit._surge_in = 99.0

	for i in 8:
		hit.take_hit(55.0, p, &"bullet", hit.global_position, Vector3.RIGHT)
		await _frames(10)

	_check("R8 lead doesn't turn it aside (%.2f)" % absf(hit.global_position.x), absf(hit.global_position.x) < 0.3)
	await _clean()
	var booted := _revenant(Vector3(0, 0, -40))
	await _frames(20)
	booted._surge_in = 99.0
	var x: float = booted.global_position.x
	booted.kick(Vector3(10, 0, 0), p)
	await _frames(30)
	var shoved := absf(booted.global_position.x - x)
	x = booted.global_position.x
	booted.take_hit(20.0, p, &"burst", booted.global_position, Vector3.RIGHT)
	await _frames(30)
	var thrown := absf(booted.global_position.x - x)
	_check("R10 a boot barely moves it, Burst throws it (%.2f, %.2f)" % [shoved, thrown], shoved < 0.8 and thrown > 1.5)
	await _clean()
	# A ramp, and it falls on it.
	var ramp := StaticBody3D.new()
	var slope := CollisionShape3D.new()
	var plank := BoxShape3D.new()
	plank.size = Vector3(10, 0.4, 10)
	slope.shape = plank
	ramp.add_child(slope)
	add_child(ramp)
	ramp.position = Vector3(30, 0.9, -30)
	ramp.rotation.x = 0.2
	var fell := _revenant(Vector3(30, 3.0, -30))
	await _frames(60)
	fell._surge_in = 99.0

	while not fell.is_down():
		fell.take_hit(55.0, p, &"bullet", fell.global_position, Vector3.FORWARD)

	await _frames(150)
	var under: Vector3 = fell.global_position
	var lowest: float = minf(fell.body.wrist(0).y, fell.body.wrist(1).y)
	_check("M4 fallen on a slope, it stays on the floor, its hands above it (%.2f)" % (lowest - under.y), lowest > under.y - 0.6 and lowest < under.y + 0.9)
	ramp.queue_free()
	await _clean()
	Props.block(self, Vector3(-40, 2, -10), Vector3(10, 4, 1))
	var runner := _revenant(Vector3(-40, 0, -16))
	p.teleport(Transform3D(Basis.IDENTITY, Vector3(-40, 1.05, 2)))
	await _frames(20)
	runner._surge_in = 0.0
	await _until(func(): return runner.state == STATE.SURGE, 1.5)
	await _frames(70)
	_check("M5 a surge stops at a wall (%.2f)" % runner.global_position.z, runner.global_position.z < -10.4)
	await _clean()


## Only fire keeps it dead.
func _fire() -> void:
	await _clean()
	var one := _revenant(Vector3(0, 0, -40))
	await _frames(2)
	one._surge_in = 99.0
	one._attack_in = 99.0

	for i in 9:
		one.take_hit(5.0, p, &"fire", one.global_position, Vector3.BACK)

	_check("F1 a fire shell's worth, close: burning, not dead (%.0f)" % one.health, one.statuses.has(&"burning") and is_equal_approx(one.health, 135.0))
	var from: Vector3 = one.global_position
	await _frames(int(5.2 * 60.0))
	_check("F2 burns 8 a second for 5 s, and it keeps coming (%.0f)" % one.health, absf(one.health - 95.0) < 1.5 and one.global_position.distance_to(from) > 4.0 and not one.statuses.has(&"burning"))
	await _clean()
	var low := _revenant(Vector3(0, 0, -40))
	await _frames(2)
	low._surge_in = 99.0
	low._attack_in = 99.0
	low.health = 10.0
	low.take_hit(1.0, p, &"fire", low.global_position, Vector3.BACK)
	var never_fell := true

	for i in 120:
		never_fell = never_fell and not low.is_down()
		await get_tree().physics_frame

	_check("F3 run out while burning: finished, no fall", low.dead and never_fell)
	await _clean()
	var down := _revenant(Vector3(0, 0, -40))
	await _frames(2)
	down._surge_in = 99.0
	down._attack_in = 99.0

	while not down.is_down():
		down.take_hit(55.0, p, &"bullet", down.global_position, Vector3.BACK)

	await _frames(50)
	p.power.power = 0.0
	var paid_from: float = p.power.power
	down.take_hit(5.0, p, &"fire", down.global_position, Vector3.BACK)
	_check("F4 any pellet on one that's down finishes it, and pays power (%.1f)" % p.power.power, down.dead and p.power.power > paid_from)
	await _clean()
	var rising := _revenant(Vector3(0, 0, -40))
	await _frames(2)
	rising._surge_in = 99.0
	rising._attack_in = 99.0

	while not rising.is_down():
		rising.take_hit(55.0, p, &"bullet", rising.global_position, Vector3.BACK)

	await _until(func(): return rising.state == STATE.RISE, 6.0)
	rising.take_hit(5.0, p, &"fire", rising.global_position, Vector3.BACK)
	_check("F5 caught as it rises, the same", rising.dead)
	await _clean()
	# The gun itself.
	p.inventory.ammo[&"fire_shells"] = 4
	p.loadout.pack_round(&"fire")
	p.loadout.restock()
	_check("F6b with fire packed the barrel holds it (%s)" % p.revolver.shot_round, p.revolver.shot_round == &"fire" and int(p.revolver.loaded[&"shot"]) == 1)
	var shot := _revenant(Vector3(0, 0, -5.0))
	await _frames(2)
	shot._surge_in = 99.0
	shot._attack_in = 99.0
	shot._enter(STATE.STAGGER)
	shot._row = shot._row.duplicate()
	shot._row["stagger_time"] = 99.0
	var aim := shot.global_position + Vector3.UP * 1.2
	var way: Vector3 = (aim - p.camera.global_position).normalized()
	p.rotation.y = atan2(-way.x, -way.z)
	p.neck.rotation = Vector3(asin(way.y), 0.0, 0.0)
	await _frames(40)
	p.revolver.barrel = &"shot"
	var before: float = shot.health
	p.caster.empowered_until = p.caster._game_time + 5.0
	await _press("throw")
	await _frames(3)
	_check("F6 an empowered fire shell is still fire, and burns (%.0f)" % (before - shot.health), shot.statuses.has(&"burning") and before - shot.health <= 46.0 and before - shot.health > 0.0)
	await _frames(4)
	await _clean()
	var opening := _revenant(Vector3(0, 0, -2.6))
	await _frames(2)
	opening._surge_in = 99.0
	opening._attack_in = 99.0
	opening._enter(STATE.GRASP_WIND)
	await _frames(20)
	opening.take_hit(55.0, p, &"bullet", opening.global_position, Vector3.BACK)
	_check("F9 lead in a wind-up doesn't break it", opening.state == STATE.GRASP_WIND)
	opening.take_hit(5.0, p, &"fire", opening.global_position, Vector3.BACK)
	_check("F8 a hit from fire in a grasp's wind-up breaks it", opening.state == STATE.STAGGER and not p.touch.on_you())
	await _clean()
	var layer := _revenant(Vector3(0, 0, -40))
	var other := _revenant(Vector3(10, 0, -40))
	await _frames(2)

	for each in [layer, other]:
		each._surge_in = 99.0
		each._attack_in = 99.0

	p.touch.lay(layer, 0.0, 0.0)
	other.health = 1.0
	other.take_hit(5.0, p, &"fire", other.global_position, Vector3.BACK)
	await _frames(2)
	_check("F11 another's finishing doesn't clear it", other.dead and p.touch.on_you() and p.touch.laid_by() == layer)
	layer.health = 1.0
	layer.take_hit(5.0, p, &"fire", layer.global_position, Vector3.BACK)
	await _frames(2)
	_check("F10 the touch clears when the one that laid it is finished", layer.dead and not p.touch.on_you())
	await _clean()
	var eye: CharacterBody3D = load("res://scripts/Monsters/FloatingEye.gd").new()
	eye.position = Vector3(0, 2, -30)
	add_child(eye)
	await _frames(2)
	var eye_had: float = eye.health
	eye.take_hit(5.0, p, &"fire", eye.global_position, Vector3.BACK)
	_check("F12 fire on an eye is what the Bestiary says, no burn (%.0f)" % (eye_had - eye.health), is_equal_approx(eye_had - eye.health, 5.0 * Bestiary.scale_for(&"floating_eye", &"fire")) and not eye.statuses.has(&"burning"))
	await _clean()


func _press(action: String) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)


## Two touches: the first is a grasp, and the second is the end.
func _its_touch() -> void:
	await _clean()
	p.invulnerable = false
	var one := await _grasper(Vector3(0, 0, -2.5))
	await _grasp_lands(one)
	_check("T1 a first grasp lands 5, and the touch is on you (%.0f)" % (100.0 - p.health), is_equal_approx(p.health, 95.0) and p.touch.on_you() and p.touch.laid_by() == one)
	var was_held: bool = p.touch.holding() and one.state == STATE.HOLD
	var at: Vector3 = p.global_position
	await _frames(50)
	_check("T2 it holds you up to 1 s", was_held and p.touch.holding() and p.global_position.distance_to(at) < 0.1)
	await _until(func(): return not p.touch.holding(), 0.5)
	var got_away: bool = await _until(func(): return p.global_position.distance_to(at) > 0.6, 0.8)
	_check("T2b then shoves you away, the touch still on you", got_away and p.touch.on_you())
	await _clean()
	p.invulnerable = false
	var freed := await _grasper(Vector3(0, 0, -2.5))
	await _grasp_lands(freed)
	await _frames(10)
	freed.take_hit(20.0, p, &"power", freed.global_position, Vector3.FORWARD)
	await _frames(1)
	_check("T3 a whip frees you sooner, and the touch stays", not p.touch.holding() and p.touch.on_you())
	await _clean()
	p.invulnerable = false
	var twice := await _grasper(Vector3(0, 0, -2.5))
	p.touch.lay(twice, 0.0, 0.0)
	await _frames(2)
	await _grasp_lands(twice)
	_check("T4 a second grasp kills you there and then (%s)" % p.death.kind, p.is_dead and p.death.kind == &"possessed")
	await _new_player()
	await _clean()
	p.invulnerable = false
	var first := _revenant(Vector3(0, 0, -40))
	await _frames(2)
	first._surge_in = 99.0
	first._attack_in = 99.0
	p.touch.lay(first, 0.0, 0.0)
	await _frames(2)
	var other := await _grasper(Vector3(0, 0, -2.5))
	await _grasp_lands(other)
	_check("T5 another's grasp counts", p.is_dead and p.death.kind == &"possessed")
	await _new_player()
	await _clean()
	p.invulnerable = false
	var layer := _revenant(Vector3(0, 0, -40))
	await _frames(2)
	layer._surge_in = 99.0
	layer._attack_in = 99.0
	p.touch.lay(layer, 0.0, 1.5)
	await _frames(2)
	var quick := await _grasper(Vector3(0, 0, -2.5))
	quick._state_t = 1.05
	await _grasp_lands(quick)
	_check("T6 not in the grace after a hold", not p.is_dead)
	await _clean()
	p.invulnerable = false
	var layer_two := _revenant(Vector3(0, 0, -40))
	await _frames(2)
	layer_two._attack_in = 99.0
	layer_two._surge_in = 99.0
	p.touch.lay(layer_two, 0.0, 0.0)
	var cutter := _revenant(Vector3(0, 0, -1.9))
	await _frames(2)
	cutter._surge_in = 99.0
	cutter._attack_in = 99.0
	cutter._enter(STATE.RAKE_WIND)
	await _until(func(): return cutter.state == STATE.RAKE, 1.5)
	await _frames(1)
	_check("T7 swipes and rakes never do it", not p.is_dead and is_equal_approx(p.health, 65.0))
	await _clean()
	p.invulnerable = true
	var guarded := await _grasper(Vector3(0, 0, -2.5))
	p.touch.lay(guarded, 0.0, 0.0)
	await _frames(2)
	await _grasp_lands(guarded)
	_check("T8 invulnerable holds", not p.is_dead)
	await _clean()
	p.invulnerable = false
	var gone := _revenant(Vector3(0, 0, -40))
	await _frames(2)
	gone._attack_in = 99.0
	gone._surge_in = 99.0
	p.touch.lay(gone, 0.0, 0.0)
	await _frames(2)
	gone.sleep()
	await _frames(2)
	var went_asleep: bool = not p.touch.on_you()
	gone.wake()
	p.touch.lay(gone, 0.0, 0.0)
	await _frames(2)
	gone.queue_free()
	await _frames(3)
	_check("T9 the touch goes if the one that laid it is gone from play", went_asleep and not p.touch.on_you())
	await _clean()
	p.invulnerable = false
	var stays := _revenant(Vector3(0, 0, -40))
	await _frames(2)
	stays._attack_in = 99.0
	stays._surge_in = 99.0
	p.touch.lay(stays, 0.0, 0.0)

	while not stays.is_down():
		stays.take_hit(55.0, p, &"bullet", stays.global_position, Vector3.FORWARD)

	await _frames(5)
	var stayed: bool = p.touch.on_you()
	p.loadout.owned[&"egg"] = 2
	p.loadout.pack_item(&"egg")
	p.loadout.restock()
	p.loadout.use_item(0)
	await _frames(90)
	var egg_did_nothing: bool = p.touch.on_you()
	p.touch.clear()
	_check("T10 going down doesn't clear it, nor the egg", stayed and egg_did_nothing)
	await _clean()
	p.invulnerable = false
	var missed := await _grasper(Vector3(0, 0, -2.5))
	await _until(func(): return missed._state_t > 0.95, 1.2)
	p.teleport(Transform3D(Basis.IDENTITY, p.global_position + Vector3(0, 0, 8.0)))
	await _grasp_lands(missed)
	_check("T11 out of its reach, the grasp misses", not p.touch.on_you())
	p.invulnerable = true
	await _clean()


## One gathering to grasp you, its own clock running.
func _grasper(at: Vector3) -> CharacterBody3D:
	var one := _revenant(at)
	await _frames(2)
	one._surge_in = 99.0
	one._attack_in = 99.0
	one._enter(STATE.GRASP_WIND)
	return one


func _grasp_lands(one: CharacterBody3D) -> void:
	await _until(func(): return one.state != STATE.GRASP_WIND, 1.4)
	await _frames(1)


## Dead is dead: a new player for what's left to try.
func _new_player() -> void:
	for monster in get_tree().get_nodes_in_group(&"monsters"):
		monster.queue_free()

	p.free()
	await _frames(2)
	p = PLAYER.instantiate()
	add_child(p)
	p.debug_traversal = false
	p.invulnerable = true
	p.reload_on_death = false
	p.position = HOME
	Props.give_revolver(p, 200, 40)
	p.inventory.select_by_id(&"revolver")
	await _frames(30)


## A swipe hurts, a rake hurts more, and either leaves you soaked.
func _its_blows() -> void:
	await _clean()
	p.invulnerable = false
	var one := _revenant(Vector3(0, 0, -1.9))
	await _frames(2)
	one._surge_in = 99.0
	one._attack_in = 99.0
	one._enter(STATE.SWIPE_WIND)
	await _until(func(): return one.state == STATE.SWIPE, 1.2)
	await _frames(1)
	_check("H1 a swipe lands 25 (%.0f)" % (100.0 - p.health), is_equal_approx(p.health, 75.0))
	_check("H4 a hit soaks you for 8 s", p.statuses.has(&"soaked") and p.statuses.left(&"soaked") > 7.8)
	_check("H6 stamina comes back at 40%%", await _stamina_scale_is(0.4))
	p.health = 100.0
	await _frames(100)
	one._enter(STATE.RAKE_WIND)
	await _until(func(): return one.state == STATE.RAKE, 1.5)
	await _frames(1)
	_check("H2 a rake lands 35 (%.0f)" % (100.0 - p.health), is_equal_approx(p.health, 65.0))
	_check("H7 a new hit starts the 8 s again (%.1f)" % p.statuses.left(&"soaked"), p.statuses.left(&"soaked") > 7.8)
	one.global_position = Vector3(0, 0, -60)
	p.health = 62.0
	await _frames(int(7.0 * 60.0))
	_check("H5 your shield doesn't fill while it lasts (%.1f)" % p.health, p.health <= 62.0 and p.statuses.has(&"soaked"))
	var filled: bool = await _until(func(): return p.health > 63.0, 7.0)
	_check("H5b and does after", filled and not p.statuses.has(&"soaked"))
	await _clean()
	p.invulnerable = false
	var dodged := _revenant(Vector3(0, 0, -1.9))
	await _frames(2)
	dodged._surge_in = 99.0
	dodged._attack_in = 99.0
	dodged._enter(STATE.SWIPE_WIND)
	await _frames(20)
	Input.action_press("gun_dodge")
	await _frames(2)
	Input.action_release("gun_dodge")
	await _until(func(): return dodged.state == STATE.SWIPE, 1.0)
	await _frames(1)
	_check("H3 dodged, nothing (%.0f)" % p.health, p.health == 100.0)
	await _clean()
	p.invulnerable = false
	# Backing off as you aim doesn't beat it: it comes after you. Running does.
	var after_walk := await _backed_off_from(4.55)
	await _clean()
	p.invulnerable = false
	var after_run := await _backed_off_from(8.5)
	_check("H8 backing off at an aiming walk it catches you, at a sprint it doesn't (%.0f, %.0f)" % [after_walk, after_run], after_walk < 100.0 and after_run == 100.0)
	await _clean()
	p.invulnerable = false
	var near := _revenant(Vector3(0, 0, -3.0))
	await _frames(2)
	near._surge_in = 99.0
	near._attack_in = 99.0
	near._enter(STATE.WALK)
	await _frames(180)
	var off_you: float = Vector2(near.global_position.x - p.global_position.x, near.global_position.z - p.global_position.z).length()
	_check("H9 it stops short of you, not through you (%.2f)" % off_you, off_you > 1.3 and off_you < 1.7)
	p.invulnerable = true
	await _clean()


func _stamina_scale_is(scale: float) -> bool:
	await _frames(2)
	return is_equal_approx(p.combat.stamina_regen_scale, scale)


func _backed_off_from(speed: float) -> float:
	var one := _revenant(Vector3(0, 0, -2.2))
	await _frames(2)
	one._surge_in = 99.0
	one._attack_in = 99.0
	one._enter(STATE.SWIPE_WIND)

	while one.state == STATE.SWIPE_WIND:
		p.teleport(Transform3D(Basis.IDENTITY, p.global_position + Vector3(0, 0, speed / 60.0)))
		await get_tree().physics_frame

	await _frames(1)
	return p.health


func _clean() -> void:
	for monster in get_tree().get_nodes_in_group(&"monsters"):
		monster.queue_free()

	p.statuses.clear(&"soaked")

	if p.get("touch") != null:
		p.touch.clear()

	p.health = 100.0
	p.teleport(Transform3D(Basis.IDENTITY, HOME))
	await _frames(3)


func _revenant(at: Vector3) -> CharacterBody3D:
	var one: CharacterBody3D = RevenantScript.new()
	one.position = at
	add_child(one)
	return one


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
