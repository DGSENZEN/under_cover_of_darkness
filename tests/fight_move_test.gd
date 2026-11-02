extends Node3D
## Fight movement (the hunts plan, part zero): strafing, the dodge with the
## gun, the slide. Real player, real input, revolver drawn.

const PLAYER := preload("res://Player.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const ACTIONS := ["move_left", "move_right", "move_forward", "move_back", "sprint", "crouch", "aim", "throw", "reload", "blink", "dodge", "gun_dodge", "jump", "spell_1", "spell_2", "spell_3"]
const HOME := Vector3(0, 1.05, 0)

var p: CharacterBody3D
var failed := 0


func _ready() -> void:
	Props.block(self, Vector3(0, -0.5, 0), Vector3(120, 1, 120))
	# A beam to go under, a wall to run into, a platform with a drop.
	Props.block(self, Vector3(0, 2.3, 12), Vector3(8, 2, 3))
	Props.block(self, Vector3(-20, 1.5, 0), Vector3(6, 3, 1))
	Props.block(self, Vector3(20, 1.5, 0), Vector3(10, 3, 20))
	Props.block(self, Vector3(40, 1.5, 0), Vector3(10, 3, 20))
	p = PLAYER.instantiate()
	add_child(p)
	p.debug_traversal = false
	p.invulnerable = true
	p.reload_on_death = false
	p.position = HOME
	Props.give_revolver(p, 200, 20)
	p.inventory.select_by_id(&"revolver")
	await _frames(60)
	await _strafing()
	await _gun_dodge()
	await _slide()
	await _slide_feel()
	print("==== RESULTS ====")
	print("%d failed" % failed)
	get_tree().quit(1 if failed > 0 else 0)


func _strafing() -> void:
	await _settle()
	Input.action_press("move_right")
	var start := await _time_until(func(): return _side() >= p.walk_speed * 0.9, 2.0)
	_check("FM1 strafe reaches 90%% of walk within 0.2 s (%.3f)" % start, start >= 0.0 and start <= 0.2)
	await _frames(30)
	Input.action_release("move_right")
	var stop := await _time_until(func(): return _flat() < 0.2, 2.0)
	_check("FM2 strafe stops within 0.2 s (%.3f)" % stop, stop >= 0.0 and stop <= 0.2)

	await _settle()
	Input.action_press("move_left")
	await _frames(40)
	Input.action_release("move_left")
	Input.action_press("move_right")
	var reverse := await _time_until(func(): return _side() >= p.walk_speed * 0.9, 2.0)
	_check("FM3 reversing reaches 90%% the other way within 0.35 s (%.3f)" % reverse, reverse >= 0.0 and reverse <= 0.35)

	await _settle()
	Input.action_press("sprint")
	Input.action_press("move_right")
	await _frames(30)
	var top := 0.0
	var ready_every_tick := true

	for i in 60:
		await get_tree().physics_frame
		top = maxf(top, absf(_side()))
		ready_every_tick = ready_every_tick and p.revolver.ready_to_fire()

	_check("FM4 sprint held while strafing stays at walk speed (%.2f)" % top, absf(top - p.walk_speed) < 0.3)
	_check("FM5 the gun stays ready through a sprint-held strafe", ready_every_tick)

	await _settle()
	Input.action_press("sprint")
	Input.action_press("move_forward")
	await _frames(40)
	_check("FM6 sprinting forward still lowers the gun", not p.revolver.ready_to_fire() and _flat() > p.walk_speed + 1.0)


func _press(action: String) -> void:
	Input.action_press(action)
	await get_tree().physics_frame
	Input.action_release(action)


func _gun_dodge() -> void:
	const Spells := preload("res://scripts/Magic/Spells.gd")

	await _settle()
	p.revolver.reset_for_practice()
	await _frames(10)
	var from: Vector3 = p.global_position
	var stamina_was: float = p.combat.stamina
	var power_was: float = p.power.power
	await _press("gun_dodge")
	await _frames(1)
	_check("FM7 Alt with the gun dodges", p.combat.phase == p.combat.Phase.DODGE)
	var early: bool = p.revolver.ready_to_fire()
	await _frames(8)
	var still_early: bool = p.revolver.ready_to_fire()
	await _frames(14)
	var late: bool = p.revolver.ready_to_fire()
	_check("FM10 no shot in the first 60%, a shot after", not early and not still_early and late)
	await _frames(30)
	var moved: Vector3 = p.global_position - from
	_check("FM8 a gun dodge carries at least 2.4 m (%.2f)" % moved.length(), moved.length() >= 2.4)
	_check("FM9 with no key held it goes straight back", moved.normalized().dot(p.global_basis.z) >= 0.9)
	_check("FM14 it costs stamina and no power", p.combat.stamina < stamina_was and is_equal_approx(power_was, p.power.power))

	await _settle()
	from = p.global_position
	Input.action_press("move_left")
	await _press("gun_dodge")
	await _frames(20)
	Input.action_release("move_left")
	_check("FM9b it goes the way you are moving", (p.global_position - from).normalized().dot(-p.global_basis.x) >= 0.9)

	await _settle()
	p.revolver.reset_for_practice()
	p.revolver.loaded[&"cylinder"] = 2
	await _press("reload")
	await _frames(40)
	var loaded_was: int = p.revolver.loaded[&"cylinder"]
	await _press("gun_dodge")
	await _frames(45)
	_check("FM11 the reload carries on through a dodge", p.revolver.is_reloading() and int(p.revolver.loaded[&"cylinder"]) > loaded_was)

	await _settle()
	p.revolver.reset_for_practice()
	Input.action_press("spell_3")
	await _frames(20)
	_check("FM12a a tome spell is under way", Spells.info(p.caster.casting()).get("tier", -1) == Spells.Tier.TOME)
	await _press("gun_dodge")
	await _frames(1)
	_check("FM12 no dodge during a tome cast", p.combat.phase != p.combat.Phase.DODGE)

	await _settle()
	p.combat._spend(p.combat.stamina)
	from = p.global_position
	await _press("gun_dodge")
	await _frames(1)
	_check("FM13 out of stamina: no dodge and no shove", p.combat.phase != p.combat.Phase.DODGE and p.global_position.distance_to(from) < 0.05)

	await _settle()
	from = p.global_position
	power_was = p.power.power
	await _press("blink")
	await _frames(30)
	_check("FM15 Q with the gun is still Blink", p.power.power < power_was and p.global_position.distance_to(from) > 3.0)


func _sprint_for(frames: int, from := HOME, yaw := 0.0) -> void:
	await _settle(from, yaw)
	Input.action_press("sprint")
	Input.action_press("move_forward")
	await _frames(frames)


func _slide() -> void:
	await _sprint_for(40)
	var from: Vector3 = p.global_position
	Input.action_press("crouch")
	await _frames(2)
	_check("FM16 crouch at a sprint on open floor slides", p.is_sliding() and p.is_crouched)
	var ready_at := await _time_until(func(): return p.revolver.ready_to_fire(), 1.0)
	_check("FM19 the gun is ready within 0.2 s of starting (%.3f)" % ready_at, ready_at >= 0.0 and ready_at <= 0.2)
	await _time_until(func(): return not p.is_sliding(), 2.0)
	_check("FM17 it carries at least 4 m (%.2f)" % from.distance_to(p.global_position), from.distance_to(p.global_position) >= 4.0)
	_check("FM17b it ends in a crouch while crouch is held", p.is_crouched and not p.is_sliding())

	await _settle()
	Input.action_press("move_forward")
	await _frames(40)
	Input.action_press("crouch")
	await _frames(3)
	_check("FM18 crouch from a walk is only a crouch", not p.is_sliding() and p.is_crouched)

	await _sprint_for(40)
	Input.action_release("sprint")
	Input.action_press("crouch")
	await _frames(2)
	_check("FM18b crouch just after letting go of sprint is only a crouch", not p.is_sliding())

	await _sprint_for(40)
	Input.action_press("crouch")
	await _frames(10)
	Input.action_press("jump")
	await _frames(3)
	Input.action_release("jump")
	_check("FM20 jump ends it in a hop, keeping speed (%.2f)" % _flat(), not p.is_sliding() and not p.is_on_floor() and _flat() >= 6.0)

	await _sprint_for(40)
	Input.action_press("crouch")
	await _frames(10)
	Input.action_release("crouch")
	await _frames(2)
	_check("FM21 letting go of crouch ends it standing", not p.is_sliding() and not p.is_crouched)

	# Under a beam 1.3 m clear: crouch let go beneath it.
	await _sprint_for(20, Vector3(0, 1.05, 20))
	Input.action_press("crouch")
	await _time_until(func(): return p.global_position.z < 13.5, 2.0)
	var sliding_under: bool = p.is_sliding() or p.is_crouched
	Input.action_release("crouch")
	await _frames(2)
	var kept_low: bool = p.is_crouched
	Input.action_release("sprint")
	await _time_until(func(): return p.global_position.z < 9.0, 3.0)
	await _frames(5)
	_check("FM22 it goes under a 1.3 m beam and stays crouched until there is room", sliding_under and kept_low and p.global_position.z < 9.0 and not p.is_crouched)

	# Into a wall.
	await _sprint_for(30, Vector3(-20, 1.05, 12))
	Input.action_press("crouch")
	await _time_until(func(): return p.is_on_wall(), 2.0)
	await _frames(3)
	_check("FM23 into a wall it ends at once, no jitter (%.2f m/s)" % _flat(), not p.is_sliding() and _flat() < 0.5)

	# Off a drop.
	await _sprint_for(36, Vector3(20, 3.05, -1))
	Input.action_press("crouch")
	var fell := await _time_until(func(): return p.global_position.y < 2.5, 3.0)
	_check("FM24 off a drop it ends and you fall", fell >= 0.0 and not p.is_sliding() and p.movement_state == p.MoveState.LOCOMOTION)

	# At a ledge: sprint and crouch climb down, as they did.
	await _settle(Vector3(40, 3.03, -9.3))
	Input.action_press("sprint")
	Input.action_press("crouch")
	await _frames(20)
	_check("FM25 at a ledge, sprint + crouch still climbs down", p.movement_state != p.MoveState.LOCOMOTION)


func _slide_feel() -> void:
	await _sprint_for(40)
	var eye_was: float = p.camera.global_position.y
	var scrapes := [0]
	var on_scrape := func(): scrapes[0] += 1
	p.slide_scraped.connect(on_scrape)
	Input.action_press("crouch")
	await _frames(2)
	var start: float = _flat()
	_check("FM26a it kicks the view wide", p.juice.slide_amount() > 0.0)
	await _frames(5)
	_check("FM27 the view drops sharply: over half way in 0.12 s (%.2f m)" % (eye_was - p.camera.global_position.y), eye_was - p.camera.global_position.y >= (p._standing_height - p.crouch_height) * 0.5)
	await _frames(14)
	_check("FM26 it holds its speed for the first 40%% (%.1f of %.1f)" % [_flat(), start], _flat() >= start * 0.95)
	await _time_until(func(): return not p.is_sliding(), 2.0)
	_check("FM28 scraping as it goes, with dust (%d)" % scrapes[0], scrapes[0] >= 4)
	p.slide_scraped.disconnect(on_scrape)
	await _frames(20)
	_check("FM26b the view comes back", p.juice.slide_amount() < 0.05)

	await _sprint_for(40)
	Input.action_press("crouch")
	Input.action_press("move_right")
	await _frames(12)
	var right: float = p.juice.slide_roll()
	await _sprint_for(40)
	Input.action_press("crouch")
	Input.action_press("move_left")
	await _frames(12)
	var left: float = p.juice.slide_roll()
	_check("FM29 it leans the way you steer (%.2f, %.2f)" % [right, left], right * left < 0.0)

	await _sprint_for(40)
	Input.action_press("crouch")
	await _frames(20)
	var low: float = p.camera.global_position.y
	Input.action_release("crouch")
	await _frames(10)
	_check("FM30 up quick out of it: most of the way in 0.17 s (%.2f m)" % (p.camera.global_position.y - low), p.camera.global_position.y - low >= (p._standing_height - p.crouch_height) * 0.6)


func _settle(at := HOME, yaw := 0.0) -> void:
	for action in ACTIONS:
		if InputMap.has_action(action):
			Input.action_release(action)

	p.teleport(Transform3D(Basis(Vector3.UP, yaw), at))
	p.power.power = p.power.MAX
	p.combat.stamina = p.combat.stamina_max
	await _frames(45)


func _side() -> float:
	return p.velocity.dot(p.global_basis.x)


func _flat() -> float:
	return Vector2(p.velocity.x, p.velocity.z).length()


func _time_until(done: Callable, most: float) -> float:
	var t := 0.0

	while t < most:
		if done.call():
			return t

		await get_tree().physics_frame
		t += 1.0 / 60.0

	return -1.0


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(label: String, ok: bool) -> void:
	print(("PASS " if ok else "FAIL ") + label)

	if not ok:
		failed += 1
