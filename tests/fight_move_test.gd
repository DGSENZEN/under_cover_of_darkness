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
	Props.block(self, Vector3(0, -0.5, 0), Vector3(60, 1, 60))
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


func _settle() -> void:
	for action in ACTIONS:
		if InputMap.has_action(action):
			Input.action_release(action)

	p.teleport(Transform3D(Basis.IDENTITY, HOME))
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
