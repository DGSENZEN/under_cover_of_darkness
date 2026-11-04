extends Node3D
## The revenant (docs/superpowers/specs/2026-11-03-revenant-design.md). `-- --only-<group>` runs one group.

const PLAYER := preload("res://Player.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const BodyScript := preload("res://scripts/Monsters/RevenantBody.gd")
const CopalLine := preload("res://scripts/Hunt/CopalLine.gd")
const RevenantScript := preload("res://scripts/Monsters/Revenant.gd")
const Bestiary := preload("res://scripts/Monsters/Bestiary.gd")
const STATE: Dictionary = RevenantScript.State
const EyeScript := preload("res://scripts/Monsters/FloatingEye.gd")
const AnimaScript := preload("res://scripts/Monsters/Anima.gd")
const CombatScript := preload("res://scripts/Combat/PlayerCombat.gd")
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

	if only == "" or only == "looks":
		await _how_it_looks()

	if only == "" or only == "mouth":
		await _its_mouth()

	if only == "" or only == "saves":
		await _its_saves()

	if only == "" or only == "legs":
		await _its_legs()

	if only == "" or only == "water":
		await _in_water()

	if only == "" or only == "brazier":
		await _the_brazier()

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
	var worst_gap := 0.0
	var hand_steps := 0
	var worst_hand := 0.0
	var hand_was := [body.hand_planted(0), body.hand_planted(1)]
	var hand_at := [body.hand_on_floor(0), body.hand_on_floor(1)]
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

			# (Its first frames settle; and a stutter is meant to jump.)
			if (doing == &"walk" and i < 30 and steps == 0) or body.hitching():
				wrist_was = [body.wrist(0), body.wrist(1)]
				elbow_was = [body.elbow(0), body.elbow(1)]
				head_was = body.head_at()
				was_at = [body.foot(0), body.foot(1)]
				was_down = [body.foot_planted(0), body.foot_planted(1)]
				continue

			for side in 2:
				# (Galloping at 6 m/s, a hand swings at twice that and more: what's a pop is past that.)
				var allowed: float = 0.6 if doing == &"surge" else 1.0
				var wrist_speed: float = body.wrist(side).distance_to(wrist_was[side]) * 60.0 * allowed
				var elbow_speed: float = body.elbow(side).distance_to(elbow_was[side]) * 60.0 * allowed

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

			for side in 2:
				if body.hand_planted(side) and hand_was[side]:
					worst_hand = maxf(worst_hand, body.wrist(side).distance_to(body.hand_on_floor(side)) if false else body.hand_on_floor(side).distance_to(hand_at[side]))
				elif hand_was[side] and doing == &"walk":
					hand_steps += 1

				hand_was[side] = body.hand_planted(side)
				hand_at[side] = body.hand_on_floor(side)

			# What it stands on, it reaches: a foot's bone is where its foot is, not floating behind it.
			if doing == &"walk" or doing == &"surge":
				for side in 2:
					if body.foot_planted(side):
						# (At a gallop a foot can trail for a tick before it goes.)
						worst_gap = maxf(worst_gap, body.ankle_gap(side) * (0.5 if doing == &"surge" else 1.0))

			# (A bite is a strike: its head's what strikes.)
			var head_speed: float = body.head_at().distance_to(head_was) * 60.0 * (0.5 if doing == &"bite" else 1.0)

			if head_speed > worst_head:
				worst_head = head_speed
				at_head = doing

			head_was = body.head_at()

	_check("M0 it walks: it takes steps (%d)" % steps, steps > 8)
	_check("M1 a planted foot stays put (%.3f m)" % worst_slid, worst_slid < 0.03)
	_check("M6 its legs reach what they stand on (%.2f m)" % worst_gap, worst_gap < 0.06)
	_check("M7 and it goes on its hands, hauling itself (%d)" % hand_steps, hand_steps > 6)
	_check("M8 a hand on the floor stays put (%.3f m)" % worst_hand, worst_hand < 0.03)
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


## How it burns and dies, and what its touch and its blows do to your sight.
func _how_it_looks() -> void:
	await _clean()
	var deaths := {}

	for i in 12:
		var one := _revenant(Vector3(float(i) * 3.0 - 16.0, 0, -40))
		await _frames(2)
		one._surge_in = 99.0
		one._attack_in = 99.0
		one.health = 1.0
		one.take_hit(5.0, p, &"fire", one.global_position, Vector3.BACK)
		deaths[one.death_is()] = true

	_check("D1 three deaths, each its own (%s)" % str(deaths.keys()), deaths.size() == 3)
	await _clean()
	var burning := _revenant(Vector3(0, 0, -40))
	await _frames(2)
	burning._surge_in = 99.0
	burning._attack_in = 99.0
	burning.take_hit(5.0, p, &"fire", burning.global_position, Vector3.BACK)
	await _frames(30)
	_check("D0 on fire, you can see it: flames on it", burning.body.flames_lit() >= 4)
	burning.statuses.clear(&"burning")
	await _frames(70)
	_check("D0b put out, they go", burning.body.flames_lit() == 0)
	burning.health = 1.0
	burning.take_hit(5.0, p, &"fire", burning.global_position, Vector3.BACK)
	await _frames(2)
	_check("D2 dead, it does nothing and can't be struck", burning.dead and burning.get_child(0).disabled and burning.take_hit(5.0, p, &"fire", burning.global_position, Vector3.BACK) == &"none")
	await _frames(40)
	_check("D2b it burns as it goes", burning.visible and burning.body.flames_lit() >= 4)
	await _frames(int(3.4 * 60.0))
	_check("D3 its fire goes out, its body hides, nothing left burning", not burning.visible and burning.body.flames_lit() == 0)
	await _clean()
	var striker := _revenant(Vector3(0, 0, -2.0))
	await _frames(2)
	striker._surge_in = 99.0
	striker._attack_in = 99.0
	var calm: float = striker.body.wrath_now()
	striker._enter(STATE.SWIPE_WIND)
	await _until(func(): return striker.state == STATE.SWIPE, 1.6)
	_check("D8 winding up, the seep builds in it (%.2f, %.2f)" % [calm, striker.body.wrath_now()], striker.body.wrath_now() > calm + 0.6)
	await _frames(14)
	_check("D9 a blow leaves a smear in the air (%d)" % striker.body.smear_points(), striker.body.smear_points() >= 4)
	await _frames(70)
	_check("D9b and it goes", striker.body.smear_points() == 0)
	var was_lean: float = striker.body._flinch
	striker.take_hit(20.0, p, &"bullet", striker.global_position, Vector3.RIGHT)
	_check("D10 struck, it flinches and shows it", striker.body._flinch > was_lean and striker.body._hurt_now > 0.0)
	await _clean()
	var layer := _revenant(Vector3(0, 0, -40))
	var other := _revenant(Vector3(6, 0, -40))
	await _frames(2)

	for each in [layer, other]:
		each._surge_in = 99.0
		each._attack_in = 99.0

	p.touch.lay(layer, 0.0, 0.0)
	await _frames(25)
	_check("D4 the one that laid the touch has its eyes lit, the others not", layer.body.eyes_now() > 0.9 and other.body.eyes_now() < 0.1)
	await _clean()
	var hud: CanvasLayer = p.hud
	await _frames(40)
	_check("D5 nothing on your sight to begin with", not hud.soaked_shown() and not hud.touch_shown())
	p.statuses.apply(&"soaked", 0.5)
	await _frames(20)
	_check("D5b soaked, it shows", hud.soaked_shown())
	await _frames(70)
	_check("D5c and goes, lowkey (%.2f)" % hud.soaked_amount(), not hud.soaked_shown())
	var holder := _revenant(Vector3(0, 0, -40))
	await _frames(2)
	holder._surge_in = 99.0
	holder._attack_in = 99.0
	p.touch.lay(holder, 0.0, 0.0)
	await _frames(45)
	_check("D5d the touch shows, all the time", hud.touch_shown())
	_check("D6 neither is the curse's or the drain's look", not hud._curse_view.visible and not hud._drain_view.visible)
	_check("D7 they keep out of the middle third", hud.middle_kept_clear())
	p.touch.clear()
	await _frames(45)
	_check("D5e burnt, it goes", not hud.touch_shown())
	await _clean()


## Its mouth, and what drifts on it.
func _its_mouth() -> void:
	await _clean()
	p.invulnerable = false
	var one := _revenant(Vector3(0, 0, -2.3))
	await _frames(40)
	one._surge_in = 99.0
	one._attack_in = 99.0
	one._enter(STATE.WALK)
	await _frames(180)
	var resting_jaw: float = one.body.jaw_now()
	var flat := func(at: Vector3) -> float: return Vector2(at.x - p.global_position.x, at.z - p.global_position.z).length()
	var head_from: float = flat.call(one.body.head_at())
	one._enter(STATE.BITE_WIND)
	await _until(func(): return one._state_t > 0.75, 1.2)
	var drawn_back: float = flat.call(one.body.head_at())
	_check("O1 it gapes, winding up to bite (%.2f, %.2f)" % [resting_jaw, one.body.jaw_now()], one.body.jaw_now() > resting_jaw + 0.6)
	_check("O2 its head draws back on its neck (%.2f, %.2f)" % [head_from, drawn_back], drawn_back > head_from + 0.05)
	var health_was: float = p.health
	await _until(func(): return one.state == STATE.BITE, 0.4)
	var least := 99.0
	var jaw_least := 9.0

	for i in 14:
		await get_tree().physics_frame
		least = minf(least, flat.call(one.body.head_at()))
		jaw_least = minf(jaw_least, one.body.jaw_now())

	_check("O3 it dives at you (%.2f, %.2f)" % [drawn_back, least], least < drawn_back - 0.5)
	_check("O4 and its jaws snap shut on you (%.2f)" % jaw_least, jaw_least < 0.35)
	_check("O5 a bite lands 30, and soaks you (%.0f)" % (health_was - p.health), is_equal_approx(health_was - p.health, 30.0) and p.statuses.has(&"soaked"))
	await _clean()
	p.invulnerable = false
	var missed := _revenant(Vector3(0, 0, -2.3))
	await _frames(2)
	missed._surge_in = 99.0
	missed._attack_in = 99.0
	missed._enter(STATE.BITE_WIND)
	await _until(func(): return missed._state_t > 0.7, 1.0)
	p.teleport(Transform3D(Basis.IDENTITY, p.global_position + Vector3(0, 0, 8.0)))
	await _until(func(): return missed.state == STATE.BITE, 0.4)
	await _frames(2)
	_check("O6 out of its reach, it bites nothing", p.health == 100.0)
	await _clean()
	# It chooses its mouth, close to.
	var chooser := _revenant(Vector3(0, 0, -2.2))
	await _frames(2)
	chooser._surge_in = 99.0
	var bit := false

	for i in int(40.0 * 60.0):
		await get_tree().physics_frame
		bit = bit or chooser.state == STATE.BITE_WIND

		if bit:
			break

	_check("O7 close to, it uses its mouth", bit)
	await _clean()
	# Its jaw is never quite still.
	var works := _revenant(Vector3(0, 0, -30))
	await _frames(40)
	works._surge_in = 99.0
	var jaw_low := 9.0
	var jaw_high := -9.0

	for i in 150:
		await get_tree().physics_frame
		jaw_low = minf(jaw_low, works.body.jaw_now())
		jaw_high = maxf(jaw_high, works.body.jaw_now())

	_check("O8 its jaw works as it comes (%.2f..%.2f)" % [jaw_low, jaw_high], jaw_high - jaw_low > 0.1)
	await _clean()
	# What drifts on it drags behind what it does, and swings on when it stops.
	var body: Node3D = BodyScript.new()
	add_child(body)
	body.position = Vector3(40, 0, -30)
	await _frames(1)
	var still := func(frames: int) -> void:
		for i in frames:
			await get_tree().physics_frame
			body.tick(1.0 / 60.0, &"walk", Vector3.ZERO, Vector3(40, 1.6, -60), 0.0, 0.0, 0.0)

	await still.call(90)
	var at_rest: Vector3 = body.drift_now()

	for i in 90:
		await get_tree().physics_frame
		body.position += Vector3(0, 0, -6.0) / 60.0
		body.tick(1.0 / 60.0, &"surge", Vector3(0, 0, -6.0), Vector3(40, 1.6, -60), 0.0, 0.0, 0.0)

	var running: Vector3 = body.drift_now()
	_check("D11 running, what drifts on it streams behind it (%.2f, %.2f)" % [at_rest.z, running.z], running.z > at_rest.z + 0.25)
	var swung := running.z

	for i in 70:
		await get_tree().physics_frame
		body.tick(1.0 / 60.0, &"walk", Vector3.ZERO, Vector3(40, 1.6, -60), 0.0, 0.0, 0.0)
		swung = minf(swung, body.drift_now().z)

	_check("D12 stopping, it swings on past where it hangs (%.2f)" % swung, swung < at_rest.z - 0.02)
	body.queue_free()
	await _frames(2)
	p.invulnerable = true
	await _clean()


## Off a save, it is as it was.
func _its_saves() -> void:
	await _clean()
	var down := _revenant(Vector3(0, 0, -40))
	await _frames(2)
	down._surge_in = 99.0
	down._attack_in = 99.0

	while not down.is_down():
		down.take_hit(55.0, p, &"bullet", down.global_position, Vector3.BACK)

	await _frames(120)
	var kept: Dictionary = down.save_state()
	var had_time: float = down._state_t
	down.queue_free()
	await _frames(2)
	var back := _revenant(Vector3(0, 0, -40))
	await _frames(2)
	back.load_state(kept)
	await _frames(2)
	_check("S1 saved down, it comes back down, with the time it had left (%.2f, %.2f)" % [had_time, back._state_t], back.is_down() and absf(back._state_t - had_time) < 0.2 and back.health == 0.0)
	await _clean()
	var burning := _revenant(Vector3(0, 0, -40))
	await _frames(2)
	burning._surge_in = 99.0
	burning._attack_in = 99.0
	burning.take_hit(5.0, p, &"fire", burning.global_position, Vector3.BACK)
	var burnt: Dictionary = burning.save_state()
	burning.queue_free()
	await _frames(2)
	var still := _revenant(Vector3(0, 0, -40))
	await _frames(2)
	still.load_state(burnt)
	await _frames(2)
	_check("S2 saved burning, it burns on", still.statuses.has(&"burning"))
	await _clean()
	var dead_one := _revenant(Vector3(0, 0, -40))
	await _frames(2)
	dead_one.health = 1.0
	dead_one.take_hit(5.0, p, &"fire", dead_one.global_position, Vector3.BACK)
	var gone: Dictionary = dead_one.save_state()
	dead_one.queue_free()
	await _frames(2)
	var stays_gone := _revenant(Vector3(0, 0, -40))
	await _frames(2)
	stays_gone.load_state(gone)
	await _frames(2)
	_check("S2b dead for good stays dead, and hidden", stays_gone.dead and not stays_gone.visible)
	await _clean()
	var layer := _revenant(Vector3(0, 0, -40))
	layer.name = "TheOne"
	await _frames(2)
	layer._surge_in = 99.0
	layer._attack_in = 99.0
	p.touch.lay(layer, 0.0, 0.0)
	var whole: Dictionary = p.save_state()
	p.touch.clear()
	p.load_state(whole)
	await _frames(2)
	_check("S3 the touch and who laid it survive a save", p.touch.on_you() and p.touch.laid_by() == layer)
	await _clean()


## It goes as if it were under water: steady, slow in its limbs, what is on it floating; the water marks where it goes.
func _in_water() -> void:
	var body: Node3D = BodyScript.new()
	add_child(body)
	body.position = Vector3(-60, 0, -10)
	await _frames(1)
	var you := Vector3(-60, 1.6, -60)
	var going := Vector3(0, 0, -1.6)

	for i in 120:
		await get_tree().physics_frame
		body.position += going * body.lurch() / 60.0
		body.tick(1.0 / 60.0, &"walk", going, you, 0.0, 0.0, 0.0)

	var least := Vector3.INF
	var most := -Vector3.INF
	var pace_low := 9.0
	var pace_high := -9.0
	var longest := 0
	var going_for := [0, 0]
	var silt_most := 0

	for i in 300:
		await get_tree().physics_frame
		body.position += going * body.lurch() / 60.0
		body.tick(1.0 / 60.0, &"walk", going, you, 0.0, 0.0, 0.0)
		var chest: Vector3 = body.to_local(body.chest_at())
		least = Vector3(minf(least.x, chest.x), minf(least.y, chest.y), minf(least.z, chest.z))
		most = Vector3(maxf(most.x, chest.x), maxf(most.y, chest.y), maxf(most.z, chest.z))
		pace_low = minf(pace_low, body.lurch())
		pace_high = maxf(pace_high, body.lurch())
		silt_most = maxi(silt_most, body.silt_now())

		for side in 2:
			going_for[side] = going_for[side] + 1 if not body.foot_planted(side) else 0
			longest = maxi(longest, going_for[side])

	_check("W1 it doesn't wobble: its chest stays over itself (%.2f across, %.2f up)" % [most.x - least.x, most.y - least.y], most.x - least.x < 0.16 and most.y - least.y < 0.12)
	_check("W2 its pace is steady, not lurching (%.2f..%.2f)" % [pace_low, pace_high], pace_high - pace_low < 0.4)
	_check("W3 its steps are slow, through something (%.2f s)" % (float(longest) / 60.0), float(longest) / 60.0 >= 0.62)
	_check("W4 no rings where it steps, or in its pool", not body.has_method("rings_now") and not (load("res://scripts/Monsters/revenant_pool.gdshader") as Shader).code.contains("rings"))
	_check("W5 silt comes up where it treads (%d)" % silt_most, silt_most >= 2)
	_check("W6 no bubbles off it", body.find_children("*", "GPUParticles3D", true, false).is_empty())
	var mesh: MeshInstance3D = body._mesh
	var arrays: Array = mesh.mesh.surface_get_arrays(0)
	var far_along := 0

	for uv: Vector2 in arrays[Mesh.ARRAY_TEX_UV]:
		far_along += 1 if uv.x > 0.8 else 0

	_check("W7 seaweed: a lot of it (%d)" % far_along, far_along > 5000)
	var hangs := _how_it_hangs(body)
	_check("W8 its seaweed hangs: most tips below their roots as it walks (%.2f)" % hangs[0], hangs[0] >= 0.8)
	_check("W9 none of it stands up off it (%.2f of them over a hand above their root)" % hangs[1], hangs[1] <= 0.04)
	_check("W11 only what hangs sways: its teeth and its head don't (%d others)" % hangs[2], hangs[2] == 0)
	# (Reared up, what hangs off its trunk would point ahead of it: it swings back to hanging, slowly.)
	var still_drift: Vector3 = body.drift_now()

	for i in 80:
		await get_tree().physics_frame
		body.tick(1.0 / 60.0, &"swipe_wind", Vector3.ZERO, you, 0.0, 0.0, 0.0)

	var reared: Vector3 = body.drift_now()
	_check("W10 reared, its weed swings back to hanging (%.2f toward its back)" % (reared.z - still_drift.z), reared.z - still_drift.z > 0.12)
	body.queue_free()
	await _frames(2)


## Of what drifts on it, as posed now: the share whose tip hangs below its root by a quarter of how long it is, and the share whose tip stands more than 10 cm over its root.
func _how_it_hangs(body: Node3D) -> Array:
	var mesh: MeshInstance3D = body._mesh
	var skeleton: Skeleton3D = mesh.get_node(mesh.skeleton)
	var skin: Skin = mesh.skin
	var by_bone := {}

	for i in skin.get_bind_count():
		var bone := skeleton.find_bone(skin.get_bind_name(i)) if skin.get_bind_name(i) != &"" else skin.get_bind_bone(i)
		by_bone[i] = skeleton.global_transform * skeleton.get_bone_global_pose(bone) * skin.get_bind_pose(i)

	var arrays: Array = mesh.mesh.surface_get_arrays(0)
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var at: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var per := bones.size() / at.size()
	var strands := {}

	for i in at.size():
		if uvs[i].x < 0.001 and uvs[i].y < 0.001:
			continue

		var key := int(uvs[i].y * 100000.0)
		var one: Array = strands.get(key, [INF, Vector3.ZERO, -INF, Vector3.ZERO])
		var here := Vector3.ZERO

		for k in per:
			if weights[i * per + k] > 0.0:
				here += (by_bone[bones[i * per + k]] as Transform3D) * at[i] * weights[i * per + k]

		if uvs[i].x < one[0]:
			one[0] = uvs[i].x
			one[1] = here

		if uvs[i].x > one[2]:
			one[2] = uvs[i].x
			one[3] = here

		strands[key] = one

	var hanging := 0
	var standing := 0
	var counted := 0

	var strays := 0

	for one: Array in strands.values():
		# (What runs along nothing isn't a strand, and shouldn't be swaying as if it were.)
		if float(one[2]) - float(one[0]) < 0.5:
			strays += 1 if float(one[2]) > 0.001 else 0
			continue

		counted += 1
		var fall: float = (one[1] as Vector3).y - (one[3] as Vector3).y
		var long: float = maxf((one[1] as Vector3).distance_to(one[3]), 0.01)
		hanging += 1 if fall > long * 0.25 else 0
		standing += 1 if fall < -0.1 else 0

	return [float(hanging) / maxf(counted, 1.0), float(standing) / maxf(counted, 1.0), strays]


## Something to measure a blow's reach against: a thin wall that counts what lands on it.
class Struck extends StaticBody3D:
	var hits := 0

	func take_hit(_damage: float, _by: Node3D, _kind: StringName, _at: Vector3, _way: Vector3) -> StringName:
		hits += 1
		return &"hit"


func _struck_at(far: float) -> StaticBody3D:
	var thing := Struck.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, 1.6, 0.1)
	shape.shape = box
	thing.add_child(shape)
	# (Placed before it's in the world, or it's in you for a frame, and you're thrown off it.)
	thing.position = p.combat.aim().origin + Vector3(0.0, 0.0, -(far + 0.05))
	add_child(thing)
	return thing


func _until_idle() -> void:
	await _until(func(): return p.combat.phase == CombatScript.Phase.IDLE, 3.0)
	await _frames(2)


func _lash() -> void:
	await _press("throw")
	await _until_idle()


## Held: the close hit, on its own, as soon as it counts as held.
func _close_hit() -> void:
	Input.action_press("throw")
	await _until(func(): return p.combat.phase == CombatScript.Phase.STRIKE, 1.0)
	Input.action_release("throw")
	await _until_idle()


## The most it lost in one frame while `blow` was under way (what burns takes a frame's worth, not this).
func _worst_drop(one: Node3D, blow: Callable) -> float:
	var worst := [0.0]
	var was := [float(one.health)]
	var watching := [true]
	var watch := func():
		while watching[0] and is_instance_valid(one):
			await get_tree().physics_frame

			if is_instance_valid(one):
				worst[0] = maxf(worst[0], float(was[0]) - float(one.health))
				was[0] = float(one.health)

				# (Not winding up at you: caught in a grasp's wind-up, fire's blow is worth three.)
				if not one.dead and not one.is_down() and one.state != STATE.STAGGER and one.state != STATE.WALK:
					one._enter(STATE.WALK)
	watch.call()
	await blow.call()
	watching[0] = false
	return worst[0]


## Still, so what's being measured is only the blow.
func _held_still(at: Vector3) -> CharacterBody3D:
	var one := _revenant(at)
	await _frames(2)
	one._surge_in = 99.0
	one._attack_in = 99.0
	return one


## The brazier: reach you can trust, and everything it does to the drowned.
func _the_brazier() -> void:
	# (Whatever the groups before it did to you: a possession, a save. This one needs you able to swing.)
	await _clean()
	await _new_player()
	await _frames(30)
	p.combat.adrenaline = 0.0
	var packed: bool = p.loadout.pack_item(&"brazier")
	_check("Z0 it packs and comes to hand", packed and p.inventory.select_by_id(&"brazier"))
	await _frames(5)
	_check("Z0b it's the weapon in hand, the gun put away", p.combat.current_weapon() != null and p.combat.current_weapon().id == &"brazier" and not p.combat.gun_drawn())
	var near := _struck_at(4.9)
	await _lash()
	var hit_at_5: bool = near.hits == 1
	near.queue_free()
	await _frames(2)
	var far := _struck_at(5.4)
	await _lash()
	var missed_at_6: bool = far.hits == 0
	var whiffed: bool = far.hits == 0
	far.queue_free()
	await _frames(2)
	_check("Z1 a lash lands at 5 m, not past 5.3", hit_at_5 and missed_at_6)
	var close_near := _struck_at(2.2)
	await _close_hit()
	var close_hit: bool = close_near.hits == 1
	close_near.queue_free()
	await _frames(2)
	var close_far := _struck_at(2.8)
	await _close_hit()
	_check("Z1b the close hit reaches 2.4 m, not 2.8", close_hit and close_far.hits == 0)
	close_far.queue_free()
	await _frames(2)

	# It comes quicker than the lash does.
	var ticks := [0, 0]

	for which in 2:
		Input.action_press("throw")

		if which == 0:
			await _frames(2)
			Input.action_release("throw")

		while p.combat.phase != CombatScript.Phase.STRIKE and ticks[which] < 120:
			ticks[which] += 1
			await get_tree().physics_frame

		Input.action_release("throw")
		await _until_idle()

	_check("Z1c the close hit lands well before the lash does (%d, %d frames)" % ticks, ticks[1] < ticks[0] - 6 and ticks[0] >= 22)

	# A commitment if you miss.
	await _press("throw")
	await _until(func(): return p.combat.whiffed(), 1.5)
	var swung_at: int = p.combat._serial
	await _press("dodge")
	await _press("kick")
	await _frames(6)
	_check("Z11 a miss holds you till it's back: no dodge, no boot", p.combat.whiffed() and not p.combat.is_dodging())
	await _press("throw")
	await _frames(4)
	_check("Z11b nor another swing on the heels of it", p.combat._serial == swung_at and p.combat.whiffed())
	await _until_idle()
	await _frames(30)
	p.combat.stamina = p.combat.stamina_max

	# What it does to one of them.
	var one := await _held_still(Vector3(0, 0, -3.5))
	var lash_lost: float = await _worst_drop(one, _lash)
	var burns: bool = one.statuses.has(&"burning")
	var seared_after: bool = one.is_exposed()
	one.global_position = Vector3(0, 0, -3.5)
	var seared_lost: float = await _worst_drop(one, _lash)
	await _clean()
	p.combat.adrenaline = 0.0
	var other := await _held_still(Vector3(0, 0, -2.0))
	var close_lost: float = await _worst_drop(other, _close_hit)
	other.global_position = Vector3(0, 0, -2.0)
	p.combat.adrenaline = 0.0
	var seared_close_lost: float = await _worst_drop(other, _close_hit)
	_check("Z2 45 first, 90 seared; close 70, 140 seared (%.0f %.0f %.0f %.0f)" % [lash_lost, seared_lost, close_lost, seared_close_lost],
		absf(lash_lost - 45.0) < 0.5 and absf(seared_lost - 90.0) < 0.5 and absf(close_lost - 70.0) < 0.5 and (absf(seared_close_lost - 140.0) < 0.5 or not is_instance_valid(other) or other.dead))
	await _clean()
	p.combat.adrenaline = 0.0

	# Any wind-up, and walking too.
	var broke := 0
	var winds := [STATE.SWIPE_WIND, STATE.RAKE_WIND, STATE.BITE_WIND, STATE.GRASP_WIND, STATE.SURGE_TELL, STATE.SURGE, STATE.WALK]

	for wind in winds:
		var winding := await _held_still(Vector3(0, 0, -20))
		winding._enter(wind)
		winding.take_hit(1.0, p, &"brazier", winding.global_position, Vector3.FORWARD)
		broke += 1 if winding.state == STATE.STAGGER else 0
		winding.queue_free()
		await _frames(2)

	_check("Z3 any hit staggers it and breaks any wind-up (%d of %d)" % [broke, winds.size()], broke == winds.size())
	var searing := await _held_still(Vector3(0, 0, -20))
	searing.take_hit(1.0, p, &"brazier", searing.global_position, Vector3.FORWARD)
	await _frames(int(2.0 * 60.0))
	searing.take_hit(1.0, p, &"brazier", searing.global_position, Vector3.FORWARD)
	await _frames(int(2.9 * 60.0))
	var still_on: bool = searing.is_exposed()
	await _frames(int(0.3 * 60.0))
	_check("Z4 seared 3 s, a new hit starts it again", seared_after and still_on and not searing.is_exposed())
	await _frames(60)
	searing.take_hit(1.0, p, &"brazier", searing.global_position, Vector3.FORWARD)
	await _frames(1)
	var comes_up: float = searing.body.seared_now()
	await _frames(20)
	var is_up: float = searing.body.seared_now()
	_check("Z4b its marks come up on it, and don't just appear (%.2f, %.2f)" % [comes_up, is_up], comes_up < 0.5 and is_up > 0.95)
	searing.queue_free()
	await _frames(2)
	var downed := await _held_still(Vector3(0, 0, -20))

	while not downed.is_down():
		downed.take_hit(55.0, p, &"bullet", downed.global_position, Vector3.BACK)

	await _frames(50)
	downed.take_hit(45.0, p, &"brazier", downed.global_position, Vector3.BACK)
	_check("Z5 sets it burning; one on it down finishes it", burns and downed.dead)
	await _clean()
	p.combat.adrenaline = 0.0
	var holder := await _grasper(Vector3(0, 0, -2.5))
	await _grasp_lands(holder)
	await _frames(5)
	var was_held: bool = p.touch.holding()
	await _lash()
	_check("Z6 frees you from a hold", was_held and not p.touch.holding() and p.touch.on_you())
	await _clean()
	p.combat.adrenaline = 0.0
	var eye: CharacterBody3D = EyeScript.new()
	eye.seed_value = 7
	eye.position = Vector3(0, 2, -30)
	eye.start_turned = true
	add_child(eye)
	eye.next_swoop_in = 100.0
	var hand: CharacterBody3D = AnimaScript.new()
	hand.form = &"hands"
	hand.position = Vector3(6, 1, -30)
	add_child(hand)
	await _frames(2)
	var eye_was: float = eye.health
	var hand_was: float = hand.health
	var eye_result: StringName = eye.take_hit(10.0, p, &"brazier", eye.global_position, Vector3.FORWARD)
	var hand_result: StringName = hand.take_hit(10.0, p, &"brazier", hand.global_position, Vector3.FORWARD)
	_check("Z7 on an eye or a hand, an ordinary blow (%s, %s)" % [eye_result, hand_result], eye_result == &"hit" and hand_result == &"hit" and is_equal_approx(eye_was - eye.health, 10.0) and is_equal_approx(hand_was - hand.health, 10.0) and not eye.is_exposed() and not hand.is_exposed())
	await _clean()

	# With it out: the keys the blade has.
	await _press("block")
	Input.action_press("block")
	await _frames(4)
	var blocks: bool = p.combat.blocking
	Input.action_release("block")
	_check("Z10 it can't block", not blocks)
	await _frames(40)
	p.combat.stamina = p.combat.stamina_max
	await _press("dodge")
	var dodged: bool = p.combat.is_dodging() or p.combat.dodged_within(0.2)
	await _until_idle()
	await _frames(70)
	p.caster._press_key(&"burst")
	await _frames(2)
	var gun_out: bool = p.combat.gun_drawn()
	_check("Z9 a spell key takes the gun back out; a tapped Q dodges", gun_out and dodged)
	p.caster._held_key = &""
	p.inventory.select_by_id(&"brazier")
	await _frames(5)
	await _the_chain()
	await _how_it_lands()
	p.loadout.unpack_item(&"brazier")
	await _frames(2)
	var kept: Node3D = p.combat.chain()
	_check("C6 packed away, gone from sight", kept == null or not kept.visible)


## How a hit lands: something you feel go in, and see where it went.
func _how_it_lands() -> void:
	await _clean()
	p.combat.adrenaline = 0.0
	p.combat.stamina = p.combat.stamina_max
	await _frames(30)
	var chain: Node3D = p.combat.chain()
	var one := await _held_still(Vector3(0, 0, -3.5))
	var was_at: Vector3 = one.global_position
	var was_chest: Vector3 = one.to_local(one.body.chest_at())
	var head_near := 0
	var thrown_most := 0
	var steam := false
	var chest_went := 0.0
	var flare := 0.0
	var light_most := 0.0
	Input.action_press("throw")
	await _frames(2)
	Input.action_release("throw")
	await _until(func(): return one.statuses.has(&"burning"), 1.2)
	var landed_at: Vector3 = chain.head_at()
	var pushed_from: Vector3 = one.global_position
	var away: Vector3 = landed_at - p.combat.aim().origin
	var rebounded := false
	var furthest_back := 0.0

	for i in 30:
		await get_tree().physics_frame
		var off: float = chain.head_at().distance_to(one.global_position + (landed_at - pushed_from))
		head_near += 1 if off < 0.2 and not rebounded else 0
		rebounded = rebounded or off > 0.2
		thrown_most = maxi(thrown_most, chain.coals_flying())
		steam = steam or chain.steaming()
		chest_went = maxf(chest_went, (one.to_local(one.body.chest_at()) - was_chest).dot(one.to_local(one.global_position + away.normalized())))
		flare = maxf(flare, one.body.flare_now())
		light_most = maxf(light_most, chain.coal_light().light_energy)

	var shoved: float = one.global_position.distance_to(pushed_from)
	_check("Hb1 its head bites: it stays on what it hit for a moment (%d ticks)" % head_near, head_near >= 3)
	_check("Hb2 and then rebounds off it", rebounded)
	_check("Hb3 a lash shoves it back (%.2f m)" % shoved, shoved > 0.35 and one.global_position.distance_to(was_at) < 3.0)
	_check("Hb4 coals thrown out of it (%d)" % thrown_most, thrown_most >= 6)
	_check("Hb5 steam off its wet flesh", steam)
	_check("Hb6 a burn on the flesh where it struck (%.2f)" % flare, flare > 0.8)
	_check("Hb7 its coals' light jumps (%.1f)" % light_most, light_most > chain.COAL_LIGHT_FANNED + 1.0)
	_check("Hb8 its body gives the way it was hit (%.2f m)" % chest_went, chest_went > 0.06)
	await _frames(int(1.2 * 60.0))
	_check("Hb9 the burn fades (%.2f)" % one.body.flare_now(), one.body.flare_now() < 0.1)
	var least := INF

	for i in int(2.2 * 60.0):
		await get_tree().physics_frame

		if chain.coals_flying() > 0:
			least = minf(least, chain.lowest_coal())

	_check("Hb10 they land on the floor and go out (%.2f, %d left)" % [least, chain.coals_flying()], chain.coals_flying() == 0 and (least == INF or least >= 0.0))
	one.queue_free()
	await _clean()
	p.combat.adrenaline = 0.0
	p.combat.stamina = p.combat.stamina_max
	var other := await _held_still(Vector3(0, 0, -2.0))
	var from_at: Vector3 = other.global_position
	await _close_hit()
	_check("Hb11 a close hit shoves it harder (%.2f m)" % other.global_position.distance_to(from_at), other.global_position.distance_to(from_at) > 0.7)
	other.queue_free()
	await _clean()
	p.combat.adrenaline = 0.0
	var eye: CharacterBody3D = EyeScript.new()
	eye.seed_value = 7
	eye.position = p.combat.aim().origin + Vector3(0, -0.2, -3.0)
	eye.start_turned = true
	add_child(eye)
	eye.next_swoop_in = 100.0
	await _frames(3)
	var steamed := false
	var coals_off_eye := 0
	Input.action_press("throw")
	await _frames(2)
	Input.action_release("throw")

	for i in 70:
		await get_tree().physics_frame
		steamed = steamed or chain.steaming()
		coals_off_eye = maxi(coals_off_eye, chain.coals_flying())

	_check("Hb12 no steam off what isn't wet; the coals still fly (%d)" % coals_off_eye, not steamed and coals_off_eye >= 3)
	eye.queue_free()
	await _clean()
	# At nothing: pulled up short at the end of the chain, not sailing on.
	p.combat.stamina = p.combat.stamina_max
	await _frames(40)
	Input.action_press("throw")
	await _frames(2)
	Input.action_release("throw")
	await _until(func(): return p.combat.whiffed(), 1.5)
	var end_at: Vector3 = p.combat.aim().origin
	var out_most: float = chain.head_at().distance_to(end_at)
	var pulled_back := false

	for i in 14:
		await get_tree().physics_frame
		out_most = maxf(out_most, chain.head_at().distance_to(end_at))

	pulled_back = chain.head_at().distance_to(end_at) < out_most - 0.15
	_check("Hb13 a miss is pulled up short (%.2f out at most)" % out_most, pulled_back and out_most < 5.6)
	await _until_idle()


## The chain and its head: it lags your hand, flies where you aimed, and holds its length.
func _the_chain() -> void:
	await _clean()
	p.combat.adrenaline = 0.0
	p.combat.stamina = p.combat.stamina_max
	await _frames(90)
	var chain: Node3D = p.combat.chain()
	_check("C0 it hangs from your hand, under it, lit", chain != null and chain.visible and chain.head_at().y < chain.hand_now().y - 0.05 and chain.head_at().distance_to(chain.hand_now()) < 1.0 and chain.coal_light().light_energy > 0.0)
	var target := _struck_at(4.4)
	var landed_at: Vector3 = p.combat.aim().origin + Vector3(0.0, 0.0, -4.4)
	var fastest := 0.0
	var stretched := 0.0
	var head_off := INF
	var was: PackedVector3Array = chain.points_now()
	Input.action_press("throw")
	await _frames(2)
	Input.action_release("throw")

	for i in 110:
		await get_tree().physics_frame
		var now: PackedVector3Array = chain.points_now()

		for k in now.size():
			fastest = maxf(fastest, now[k].distance_to(was[k]) * 60.0)

		was = now
		stretched = maxf(stretched, chain.stretch())

		if target.hits > 0 and head_off == INF:
			head_off = chain.head_at().distance_to(landed_at)

	_check("C1 the head reaches where the lash lands (%.2f m off)" % head_off, head_off < 0.5)
	_check("C2 no link jumps (%.1f m/s)" % fastest, fastest < 30.0)
	_check("C3 the chain holds its length (%.2f)" % stretched, stretched < 1.1)
	var link_at: Transform3D = chain._links.multimesh.get_instance_transform(0)
	_check("C3b its links aren't drawn inside out (%.2f)" % link_at.basis.determinant(), link_at.basis.determinant() > 0.0)
	target.queue_free()
	await _until_idle()
	await _frames(60)
	_check("C4 it comes back and hangs again (%.2f m)" % chain.head_at().distance_to(chain.hand_now()), chain.head_at().distance_to(chain.hand_now()) < 1.0 and not chain.busy())
	var hand_was: Vector3 = chain.head_at()
	p.teleport(Transform3D(Basis.IDENTITY, HOME + Vector3(0, 0, 3)))
	await _frames(3)
	var one := await _held_still(Vector3(0, 0, 0.5))
	var bursts: int = chain.bursts
	await _lash()
	_check("C5 sparks and embers where it lands on one (%d)" % (chain.bursts - bursts), chain.bursts > bursts and hand_was != Vector3.ZERO)
	one.queue_free()
	await _clean()
	p.inventory.select_by_id(&"revolver")
	await _frames(3)
	_check("C7 the gun out, it's put away", not chain.visible and not chain.coal_light().visible)
	p.inventory.select_by_id(&"brazier")
	var never_at_your_face := true

	for i in 90:
		await get_tree().physics_frame
		never_at_your_face = never_at_your_face and (not chain.visible or chain.head_at().y < p.camera.global_position.y)

	_check("C8 taken out again, it's on your hand, not where it was, never up in your face", chain.visible and chain.head_at().distance_to(chain.hand_now()) < 1.2 and never_at_your_face)


## Its legs carry what it does: braced and bent under the weight, not stilts; its feet go when a blow says.
func _its_legs() -> void:
	var body: Node3D = BodyScript.new()
	add_child(body)
	body.position = Vector3(-40, 0, -30)
	await _frames(1)
	var you := Vector3(-40, 1.6, -27.5)

	var run := func(doing: StringName, seconds: float) -> Dictionary:
		var most := 0.0
		var steps := 0
		var down := [body.foot_planted(0), body.foot_planted(1)]
		var apart := 0.0

		for i in int(seconds * 60.0):
			await get_tree().physics_frame
			body.tick(1.0 / 60.0, doing, Vector3.ZERO, you, 0.0, 0.0, 0.0)
			most = maxf(most, maxf(body.leg_straight(0), body.leg_straight(1)))
			apart = maxf(apart, body.foot(0).distance_to(body.foot(1)))

			for side in 2:
				if down[side] and not body.foot_planted(side):
					steps += 1

				down[side] = body.foot_planted(side)

		return {"straight": most, "steps": steps, "apart": apart}

	await run.call(&"walk", 2.0)
	var rest: Dictionary = await run.call(&"walk", 1.0)
	_check("L0 standing, its feet are planted wide (%.2f m)" % rest["apart"], rest["apart"] > 0.75)

	for what in [[&"swipe_wind", 1.0, &"swipe", 0.45, 1], [&"rake_wind", 1.35, &"rake", 0.6, 1], [&"grasp_wind", 1.4, &"grasp", 0.5, 0], [&"bite_wind", 0.85, &"bite", 0.4, 0]]:
		var winding: Dictionary = await run.call(what[0], what[1])
		_check("L1 %s: its legs stay bent under it (%.2f of their length)" % [what[0], winding["straight"]], winding["straight"] < 0.9)
		_check("L2 %s: its feet go when the blow says, no shuffling (%d)" % [what[0], winding["steps"]], winding["steps"] <= int(what[4]))
		var striking: Dictionary = await run.call(what[2], what[3])
		_check("L3 %s: it stamps into it, one foot or two (%d), and braces (%.2f m apart)" % [what[2], striking["steps"], striking["apart"]], striking["steps"] >= 1 and striking["steps"] <= 2 and striking["apart"] > 0.8 and striking["apart"] < 1.95)
		await run.call(&"walk", 1.2)

	var hips_low: Vector3 = body.hips_at()
	await run.call(&"rake_wind", 0.5)
	var coiled: Vector3 = body.hips_at()
	_check("L4 gathering, its hips go down (%.2f, %.2f)" % [hips_low.y, coiled.y], coiled.y < hips_low.y - 0.12)
	await run.call(&"walk", 1.5)
	var balanced_low := body.to_local(body.hips_at()).z
	await run.call(&"rake_wind", 1.35)
	var balanced_up := body.to_local(body.hips_at()).z
	_check("L5 its hips counter its chest: back as it leans, under it as it rears (%.2f, %.2f)" % [balanced_low, balanced_up], balanced_low > balanced_up + 0.1)
	body.queue_free()
	await _frames(2)


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
	quick._state_t = 1.35
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
	await _until(func(): return cutter.state == STATE.RAKE, 1.9)
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
	await _until(func(): return missed._state_t > 1.25, 1.6)
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
	await _until(func(): return one.state != STATE.GRASP_WIND, 1.8)
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
	await _until(func(): return one.state == STATE.SWIPE, 1.6)
	await _frames(1)
	_check("H1 a swipe lands 25 (%.0f)" % (100.0 - p.health), is_equal_approx(p.health, 75.0))
	_check("H4 a hit soaks you for 8 s", p.statuses.has(&"soaked") and p.statuses.left(&"soaked") > 7.8)
	_check("H6 stamina comes back at 40%%", await _stamina_scale_is(0.4))
	p.health = 100.0
	await _frames(100)
	one._enter(STATE.RAKE_WIND)
	await _until(func(): return one.state == STATE.RAKE, 1.9)
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
	await _frames(40)
	Input.action_press("gun_dodge")
	await _frames(2)
	Input.action_release("gun_dodge")
	await _until(func(): return dodged.state == STATE.SWIPE, 1.4)
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
	var near := _revenant(Vector3(0, 0, -3.6))
	await _frames(2)
	near._surge_in = 99.0
	near._attack_in = 99.0
	near._enter(STATE.WALK)
	await _frames(180)
	var off_you: float = Vector2(near.global_position.x - p.global_position.x, near.global_position.z - p.global_position.z).length()
	_check("H9 it stops short of you, not through you (%.2f)" % off_you, off_you > 1.8 and off_you < 2.2)
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
