extends Node3D
## The ravenous ánimas: their forms, their rush, what they do on you, and what gets
## them off (docs/superpowers/specs/2026-11-01-ravenous-animas-design.md).

const PLAYER := preload("res://Player.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const AnimaScript := preload("res://scripts/Monsters/Anima.gd")
const STATE: Dictionary = AnimaScript.State
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
