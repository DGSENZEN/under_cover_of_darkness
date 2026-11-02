extends Node3D
## The ravenous ánimas: their forms, their rush, what they do on you, and what gets
## them off (docs/superpowers/specs/2026-11-01-ravenous-animas-design.md).

const PLAYER := preload("res://Player.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const AnimaScript := preload("res://scripts/Monsters/Anima.gd")
const STATE: Dictionary = AnimaScript.State
const SafePlace := preload("res://scripts/Hunt/SafePlace.gd")
const HOME := Vector3(0, 1.05, 0)

var p: CharacterBody3D
var failed := 0
var _lost := 0.0


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
	await _forms()
	await _rush()
	await _leeching()
	await _dying()
	print("==== RESULTS ====")
	get_tree().quit(1 if failed > 0 else 0)


func _forms() -> void:
	var hands := _anima(&"hands", Vector3(0, 0.3, -30))
	var face := _anima(&"face", Vector3(4, 1.3, -30))
	var torso := _anima(&"torso", Vector3(8, 0.4, -30))
	await _frames(2)
	_check("A1 three forms, their health", hands.health == 40.0 and face.health == 70.0 and torso.health == 130.0)
	_check("A2 lead passes through: resisted, little harm (%.1f)" % _lost, _hit(face, &"bullet", &"lead") == &"resisted" and is_equal_approx(_lost, 50.0 * 0.15))
	p.power.power = 50.0
	face.statuses.clear(&"exposed")
	await _frames(20)
	var result := _hit(face, &"bullet", &"copal")
	_check("A3 copal is weak, exposes, pays power back", result == &"weak" and face.is_exposed() and p.power.power > 50.0)
	_check("A4 a shell is a poor answer", _hit(torso, &"shot", &"lead") == &"resisted" and is_equal_approx(_lost, 25.0))
	_free([hands, face, torso])
	await _frames(5)
	for cloud in get_tree().get_nodes_in_group(&"copal_clouds"):
		cloud.queue_free()


func _rush() -> void:
	await _place_player(HOME)
	var hands := _anima(&"hands", Vector3(-3, 0.3, -24))
	var torso := _anima(&"torso", Vector3(3, 0.4, -24))
	await _until(func(): return hands.state == STATE.RUSH and torso.state == STATE.RUSH, 3.0)
	var hands_from := hands.global_position
	var torso_from := torso.global_position
	await _frames(60)
	var hands_covered := hands_from.distance_to(hands.global_position)
	var torso_covered := torso_from.distance_to(torso.global_position)
	_check("A5 from far off it rushes you (%.1f m)" % hands_covered, hands.global_position.distance_to(p.global_position) < hands_from.distance_to(p.global_position) - 4.0)
	_check("A5b hands are faster than a torso (%.1f, %.1f)" % [hands_covered, torso_covered], hands_covered > torso_covered * 2.0)
	_check("A8 hands and torso keep to the floor (%.2f, %.2f)" % [hands.global_position.y, torso.global_position.y], absf(hands.global_position.y - 0.25) < 0.2 and absf(torso.global_position.y - 0.35) < 0.2)
	_free([hands, torso])
	var face := _anima(&"face", Vector3(0, 1.3, -14))
	await _until(func(): return face.state == STATE.RUSH, 3.0)
	await _frames(20)
	_check("A8b the face floats (%.2f)" % face.global_position.y, absf(face.global_position.y - 1.3) < 0.3)
	var told := await _until(func(): return face.state == STATE.TELL, 6.0)
	var leapt := await _until(func(): return face.state == STATE.LEAP or face.state == STATE.ON, 2.0)
	_check("A6 close enough it tells, then leaps", told and leapt)
	_free([face])
	await _frames(3)
	var open := _anima(&"face", Vector3(0, 1.3, -6))
	await _until(func(): return open.state == STATE.TELL, 6.0)
	open.health = 1000.0
	var result := _hit(open, &"bullet", &"copal")
	_check("A7 in its tell, a copal hit breaks it: weak, triple (%.1f)" % _lost, result == &"weak" and open.state == STATE.THROWN and is_equal_approx(_lost, 150.0))
	_free([open])
	await _frames(3)
	var through := _anima(&"torso", Vector3(0, 0.4, -7))
	await _until(func(): return through.state == STATE.TELL, 8.0)
	var lead_result := _hit(through, &"bullet", &"lead")
	_check("A7b in its tell, lead still does nothing to it", through.state == STATE.TELL and lead_result == &"resisted")
	_free([through])
	await _frames(3)
	for cloud in get_tree().get_nodes_in_group(&"copal_clouds"):
		cloud.queue_free()


func _leeching() -> void:
	await _place_player(HOME)
	p.leech.free_all()
	_clear_all()
	await _frames(3)
	p.power.power = 100.0
	p.health = p.max_health
	# Leaps at you, standing still.
	var first := _anima(&"face", Vector3(0, 1.3, -7))
	var on := await _until(func(): return first.state == STATE.ON, 8.0)
	_check("A9 a leap that lands puts it on you", on and p.leech.count() == 1)
	p.invulnerable = false
	var power_from: float = p.power.power
	var life_from: float = p.health
	await _frames(60)
	var power_rate: float = power_from - p.power.power
	var life_rate: float = life_from - p.health
	_check("A11 it drains power (%.1f /s) and life (%.1f /s)" % [power_rate, life_rate], absf(power_rate - 8.0) < 0.5 and absf(life_rate - 2.5) < 0.3)
	var stood: float = p.health
	_check("A11b your power doesn't refill", p.power.refill_scale == 0.0)
	_check("A11c it is fed by what it drinks (%.1f)" % first.fed, first.fed > 7.0)
	_check("A13 one on you: pace 0.8", is_equal_approx(p.leech.speed(), 0.8))
	_check("A13b with the curse too, the costs multiply", _both_multiply())
	p.power.power = 0.0
	life_from = p.health
	await _frames(60)
	_check("A12 no power left, life goes twice as fast (%.1f)" % (life_from - p.health), absf(life_from - p.health - 5.0) < 0.4)
	_check("A11d your shield doesn't refill while it is on you", p.health < stood)
	p.power.power = 100.0

	# Back at the kit room, with one on you.
	p.invulnerable = true
	var safe: Node3D = SafePlace.build(self, HOME, Vector3(20, 6, 20))
	p.loadout.lock()
	await _frames(240)
	_check("A18 with one on you the kit room won't restock you", p.loadout.locked and p.leech.count() == 1)
	p.loadout.unlock()
	safe.queue_free()

	# Killed, half of what it drank comes back.
	p.power.power = 20.0
	await _frames(60)
	var drank: float = first.fed
	var before: float = p.power.power
	first.take_hit(1000.0, p, &"power", first.global_position, Vector3.FORWARD)
	_check("A15 what it drank, half comes back when it dies (%.1f, %.1f)" % [p.power.power - before, drank], absf(p.power.power - before - drank * 0.5) < 0.5)
	_check("A15b and it lets go", p.leech.count() == 0 and is_equal_approx(p.leech.speed(), 1.0))
	await _frames(3)

	# Four come: three on you, the rest wait.
	var pack: Array = []
	for i in 4:
		var turn := float(i) * TAU / 4.0
		pack.append(_anima(&"hands", Vector3(cos(turn) * 6.0, 0.3, sin(turn) * 6.0)))
	await _until(func(): return p.leech.count() == 3, 8.0)
	# (One still leaping when the last place went misses first.)
	await _frames(90)
	var waiting: Array = pack.filter(func(a): return a.state != STATE.ON)
	_check("A14 no more than three (%d); the rest wait, circling" % p.leech.count(), p.leech.count() == 3 and waiting.size() == 1 and waiting[0].state == STATE.CIRCLE)
	_check("A13c three on you: pace 0.5", is_equal_approx(p.leech.speed(), 0.5))
	_check("A10a the slots are all different", _slots_differ(pack.filter(func(a): return a.state == STATE.ON)))
	var gone: Node3D = pack.filter(func(a): return a.state == STATE.ON)[0]
	gone.queue_free()
	await _frames(3)
	_check("A17 freed while on you, the leech forgets it", p.leech.count() >= 2 and not p.leech.on_me().has(gone))
	_free(pack)
	await _frames(3)
	_check("A17b all gone, nothing is left on you", p.leech.count() == 0)

	# A dodge makes it miss.
	await _place_player(HOME)
	var missed := _anima(&"face", Vector3(0, 1.3, -7))
	await _until(func(): return missed.state == STATE.TELL, 8.0)
	Input.action_press("move_left")
	await _press("gun_dodge")
	await _until(func(): return missed.state == STATE.MISSED or missed.state == STATE.ON, 2.0)
	Input.action_release("move_left")
	_check("A10 a dodge at the right moment makes it miss", missed.state == STATE.MISSED and p.leech.count() == 0)
	_free([missed])
	await _frames(3)


func _both_multiply() -> bool:
	p.statuses.apply(&"evil_eye", 8.0)
	var both: float = p.fight_pace()
	var expected: float = p.curse.speed() * p.leech.speed()
	p.statuses.clear(&"evil_eye")
	return is_equal_approx(both, expected) and expected < p.leech.speed()


func _slots_differ(on: Array) -> bool:
	var seen := {}

	for a in on:
		seen[p.leech.slot_of(a)] = true

	return seen.size() == on.size() and on.size() == 3


## Left to the last: the player stays dead.
func _dying() -> void:
	await _place_player(HOME)
	p.power.power = 100.0
	var taker := _anima(&"hands", Vector3(0, 0.3, -4))
	await _until(func(): return taker.state == STATE.ON, 6.0)
	p.invulnerable = false
	p.health = 1.0
	await _until(func(): return p.is_dead, 4.0)
	await _frames(5)
	var after: float = p.power.power
	await _frames(30)
	_check("A16 dead, all let go and it stops", p.is_dead and p.leech.count() == 0 and taker.state != STATE.ON and is_equal_approx(p.power.power, after))


func _clear_all() -> void:
	for monster in get_tree().get_nodes_in_group(&"monsters"):
		monster.queue_free()


func _anima(form: StringName, at: Vector3) -> CharacterBody3D:
	var e: CharacterBody3D = AnimaScript.new()
	e.form = form
	e.position = at
	add_child(e)
	return e


func _hit(e: Node, kind: StringName, round_id: StringName) -> StringName:
	var was: float = e.health
	e.round_hint = round_id
	var result: StringName = e.take_hit(50.0, p, kind, e.global_position, Vector3.FORWARD)
	_lost = was - e.health
	return result


func _free(list: Array) -> void:
	for e in list:
		if is_instance_valid(e):
			e.queue_free()


func _place_player(at: Vector3) -> void:
	for action in ["move_left", "move_right", "move_forward", "move_back", "gun_dodge", "sprint", "throw"]:
		Input.action_release(action)

	p.teleport(Transform3D(Basis.IDENTITY, at))
	await _frames(20)


func _press(action: String) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)


func _until(done: Callable, most: float) -> bool:
	var left := int(most * 60.0)

	while left > 0:
		if done.call():
			return true

		left -= 1
		await get_tree().physics_frame

	return done.call()


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(label: String, ok: bool) -> void:
	print("%s %s" % ["PASS" if ok else "FAIL", label])

	if not ok:
		failed += 1
