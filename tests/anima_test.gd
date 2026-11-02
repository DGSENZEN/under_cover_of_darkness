extends Node3D
## The ravenous ánimas: their forms, their rush, what they do on you, and what gets
## them off (docs/superpowers/specs/2026-11-01-ravenous-animas-design.md).

const PLAYER := preload("res://Player.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const AnimaScript := preload("res://scripts/Monsters/Anima.gd")
const STATE: Dictionary = AnimaScript.State
const SafePlace := preload("res://scripts/Hunt/SafePlace.gd")
const WardScript := preload("res://scripts/Magic/Ward.gd")
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
	await _getting_off()
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


## Those on you, from these forms, put there directly.
func _on_you(forms: Array) -> Array:
	var list: Array = []

	for i in forms.size():
		var turn := float(i) * TAU / 3.0 + 0.4
		var e := _anima(forms[i], p.global_position + Vector3(cos(turn) * 0.8, 0.5, sin(turn) * 0.8))
		await _frames(1)
		e.put_on_you()
		list.append(e)

	await _frames(2)
	return list


func _whip() -> bool:
	var went: bool = p.revolver.try_whip()
	await _frames(int(p.revolver.WHIP_TIME * 60.0) + 4)
	return went


func _getting_off() -> void:
	await _place_player(HOME)
	p.invulnerable = true
	p.power.power = 100.0
	_clear_all()
	await _frames(3)
	var two: Array = await _on_you([&"face", &"face"])
	_check("W0 what is on you can be aimed at: it stays where it came from", _stays_put(two[0]))
	_face(two[0])
	await _frames(2)
	var whipped: bool = await _whip()
	_check("W1 a whip throws off the one you aim at, only that one", whipped and two[0].state == STATE.THROWN and two[1].state == STATE.ON)
	_check("W1a from anywhere you stand: it needs no cone", p.leech.count() == 1)
	await _frames(25)
	_check("W1b thrown clear, stunned and exposed (%.1f m)" % two[0].global_position.distance_to(p.global_position), two[0].global_position.distance_to(p.global_position) > 1.5 and two[0].is_exposed() and two[0].state == STATE.THROWN)
	_free(two)
	await _frames(3)

	var torso: Array = await _on_you([&"torso"])
	_face(torso[0])
	await _whip()
	_check("W2 a torso needs two whips (%d left)" % torso[0].grip_left, torso[0].state == STATE.ON and torso[0].grip_left == 1)
	await _whip()
	_check("W2b and the second throws it off", torso[0].state == STATE.THROWN)
	_free(torso)
	await _frames(3)

	var pair: Array = await _on_you([&"torso", &"torso"])
	p.power.power = 50.0
	_hit(pair[0], &"bullet", &"copal")
	_check("W3 a copal round throws off the one it hits, and pays you", pair[0].state == STATE.THROWN and pair[1].state == STATE.ON and p.power.power > 50.0)
	await _frames(30)
	p.power.power = 80.0
	p.invulnerable = false
	var was_power: float = p.power.power
	await _frames(60)
	p.invulnerable = true
	_check("W3b its cloud doesn't: the other holds on, draining at half (%.1f)" % (was_power - p.power.power), pair[1].state == STATE.ON and absf(was_power - p.power.power - 6.0) < 0.6)
	var smoked := _anima(&"hands", p.global_position + Vector3(0, 0, -3.0))
	await _frames(150)
	_check("W3c nothing can latch inside the cloud", smoked.state != STATE.ON and p.leech.slot_of(smoked) < 0)
	_free(pair + [smoked])
	_clear_clouds()
	await _frames(3)

	var kept: Array = await _on_you([&"torso"])
	var was: float = kept[0].health
	_hit(kept[0], &"bullet", &"lead")
	_check("W4 lead doesn't free you", kept[0].state == STATE.ON and kept[0].health < was)
	was = kept[0].health
	_hit(kept[0], &"shot", &"lead")
	var after_shell: float = kept[0].health
	_hit(kept[0], &"shard", &"lead")
	_check("W4b nor a shell, nor a shard, though both hurt", kept[0].state == STATE.ON and after_shell < was and kept[0].health < after_shell)
	_face(kept[0])
	await _until(func(): return p.revolver.ready_to_fire(), 4.0)
	var read := await _fired_read()
	_check("W4c a lead ball is seen to pass through (%s)" % str(read), read == &"through")
	_free(kept)
	await _frames(3)

	# The Ward.
	await _until(func(): return p.revolver.ready_to_fire(), 4.0)
	p.power.power = 100.0
	var warded: Array = await _on_you([&"hands", &"face"])
	Input.action_press("spell_2")
	await _frames(40)
	Input.action_release("spell_2")
	await _frames(2)
	_check("W5 the Ward throws off everything", p.leech.count() == 0 and warded[0].state == STATE.THROWN and warded[1].state == STATE.THROWN)
	var outsider := _anima(&"hands", p.global_position + Vector3(0, 0, -3.0))
	await _frames(100)
	_check("W5b and they can't enter it (%.2f m)" % outsider.global_position.distance_to(p.global_position), p.leech.slot_of(outsider) < 0 and outsider.state != STATE.ON and not WardScript.covers(outsider.global_position))
	_free(warded + [outsider])
	await _until(func(): return not WardScript.covers(p.global_position + Vector3.UP), 6.0)
	await _frames(3)

	# A blink.
	p.power.power = 100.0
	var blinked: Array = await _on_you([&"face"])
	p.caster._blink_to(p.global_position + Vector3(0, 0, -3.0))
	await _frames(1)
	_check("W6 a blink tears you free, but they aren't thrown or hurt", p.leech.count() == 0 and blinked[0].state != STATE.ON and blinked[0].state != STATE.THROWN and not blinked[0].is_exposed() and is_equal_approx(blinked[0].health, 70.0))
	_free(blinked)
	await _place_player(HOME)

	# No power.
	var bound: Array = await _on_you([&"face"])
	p.power.power = 0.0
	await _until(func(): return p.revolver.ready_to_fire(), 4.0)
	Input.action_press("spell_2")
	await _frames(40)
	Input.action_release("spell_2")
	_check("W7 no power: the Ward refuses", not WardScript.covers(p.global_position + Vector3.UP) and bound[0].state == STATE.ON)
	_face(bound[0])
	await _whip()
	_check("W7b the whip still works", bound[0].state == STATE.THROWN)
	_free(bound)
	await _frames(3)

	# Over a ledge with one on you.
	Props.block(self, Vector3(30, 0.6, -2), Vector3(4, 1.2, 2))
	await _place_player(Vector3(30, 1.05, 0.2))
	p.rotation.y = 0.0
	p.neck.rotation = Vector3.ZERO
	var alone: float = await _over_the_ledge()
	_check("W8a with nothing on you it mantles (%.2f)" % alone, alone > 1.6)
	await _place_player(Vector3(30, 1.05, 0.2))
	var rider: Array = await _on_you([&"hands"])
	var ridden: float = await _over_the_ledge()
	_check("W8 mantling with one on you: it holds on (%.2f)" % ridden, ridden > 1.6 and p.leech.count() == 1 and rider[0].state == STATE.ON)
	_free(rider)
	await _frames(3)
	p.power.power = 100.0


## Walks at the ledge and over: the highest you got.
func _over_the_ledge() -> float:
	var peak := 0.0
	Input.action_press("move_forward")
	await _until(func(): return p.global_position.z < -0.35, 3.0)
	Input.action_press("jump")

	for i in 120:
		await get_tree().physics_frame
		peak = maxf(peak, p.global_position.y)

	Input.action_release("move_forward")
	Input.action_release("jump")
	return peak


func _stays_put(e: Node3D) -> bool:
	var was := e.global_position
	var yaw_was: float = p.rotation.y
	p.rotation.y += 1.2
	var same := e.global_position.distance_to(was) < 0.01
	p.rotation.y = yaw_was
	return same


func _face(target: Node3D) -> void:
	var way: Vector3 = (target.global_position - p.camera.global_position).normalized()
	p.rotation.y = atan2(-way.x, -way.z)
	p.neck.rotation = Vector3(asin(way.y), 0.0, 0.0)


## One shot, and the mark it left.
func _fired_read() -> StringName:
	var seen := &""
	Input.action_press("throw")

	for i in 5:
		await get_tree().physics_frame

		for mark in get_tree().get_nodes_in_group(&"round_fx_impact"):
			seen = mark.get_meta(&"read", &"")

	Input.action_release("throw")
	return seen


func _clear_clouds() -> void:
	for cloud in get_tree().get_nodes_in_group(&"copal_clouds"):
		cloud.queue_free()


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
