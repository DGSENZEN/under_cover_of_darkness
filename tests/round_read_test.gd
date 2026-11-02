extends Node3D
## You can tell which round you fired, whether it told, and what it did, at a glance:
## each round its own colour, its own shot, its own mark on what it hits.

const PLAYER := preload("res://Player.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const EyeScript := preload("res://scripts/Monsters/FloatingEye.gd")
const Rounds := preload("res://scripts/Combat/Rounds.gd")
const CopalCloud := preload("res://scripts/Monsters/CopalCloud.gd")

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
	p.revolver.take_up([&"lead", &"copal"] as Array[StringName])
	await _colours()
	await _lead()
	await _switching()
	await _copal()
	await _smoke()
	print("==== RESULTS ====")
	get_tree().quit(1 if failed > 0 else 0)


func _colours() -> void:
	var lead: Color = Rounds.info(&"lead")["colour"]
	var copal: Color = Rounds.info(&"copal")["colour"]
	var apart := Vector3(lead.r - copal.r, lead.g - copal.g, lead.b - copal.b).length()
	_check("R1 lead and copal are plainly different colours (%.2f)" % apart, apart > 0.45)
	await _until(func(): return p.revolver.ready_to_fire(), 4.0)
	await _frames(4)
	var cross: Control = p.hud.get("_crosshair")
	_check("R2 the aim wears the loaded round's colour", cross.round_ink.is_equal_approx(lead))


func _lead() -> void:
	var e := _eye()
	await _frames(20)
	_face(e)
	var seen := await _fire()
	_check("R3 a lead tracer: thin, its round's (%s)" % str(seen["round"]), seen["round"] == &"lead")
	_check("R4 on an eye lead glances off, plainly (%s)" % str(seen["read"]), seen["read"] == &"glance")
	_check("R4b and leaves no lingering thread", seen["trails"] == 0)
	lead_width = seen["width"]
	lead_life = seen["life"]
	_free(e)
	await _frames(40)


var lead_width := 0.0
var lead_life := 0.0


func _switching() -> void:
	var readout: Control = p.hud.get("_ammo")
	await _until(func(): return p.revolver.ready_to_fire(), 4.0)
	_check("R5 before a switch the readout is still", float(readout.snapshot()["switched"]) < 0.01)
	await _press("switch_round")
	await _frames(3)
	_check("R5b switching round the readout calls it out", float(readout.snapshot()["switched"]) > 0.5)
	await _until(func(): return p.revolver.ready_to_fire() and p.revolver.cylinder_round == &"copal", 8.0)
	await _frames(6)
	var cross: Control = p.hud.get("_crosshair")
	_check("R5c and the aim changes colour", cross.round_ink.is_equal_approx(Rounds.info(&"copal")["colour"]))


func _copal() -> void:
	var e := _eye()
	await _frames(20)
	_face(e)
	var seen := await _fire()
	_check("R6 a copal tracer: its round's (%s)" % str(seen["round"]), seen["round"] == &"copal")
	_check("R6b far wider than lead's (%.3f, %.3f)" % [seen["width"], lead_width], seen["width"] > lead_width * 2.5)
	_check("R6c and lasts longer (%.3f, %.3f)" % [seen["life"], lead_life], seen["life"] > lead_life * 1.8)
	_check("R7 on an eye copal bursts (%s)" % str(seen["read"]), seen["read"] == &"burst")
	_check("R7b and leaves a thread of resin in the air", seen["trails"] == 1)
	await _frames(20)
	_check("R7c which outlasts the tracer", get_tree().get_nodes_in_group(&"round_fx_trail").size() == 1 and get_tree().get_nodes_in_group(&"gunfx_tracer").is_empty())
	_check("R8 a smoked eye shows it (%.2f)" % e.body.smoulder, e.body.smoulder > 0.5)
	e.statuses.clear(&"smoked")
	await _frames(60)
	for cloud in get_tree().get_nodes_in_group(&"copal_clouds"):
		cloud.queue_free()
	await _frames(80)
	_check("R8b out of the smoke it stops (%.2f)" % e.body.smoulder, e.body.smoulder < 0.1)
	_free(e)
	await _frames(40)


func _smoke() -> void:
	_check("R9 copal's cloud is thin enough to see the eye through it", CopalCloud.OPACITY <= 0.15)
	await _frames(1)


## One shot, and what it drew.
func _fire() -> Dictionary:
	await _until(func(): return p.revolver.ready_to_fire(), 4.0)
	var seen := {"round": &"", "width": 0.0, "life": 0.0, "read": &"", "trails": 0}
	Input.action_press("throw")

	for i in 4:
		await get_tree().physics_frame

		for line in get_tree().get_nodes_in_group(&"gunfx_tracer"):
			seen["round"] = line.get_meta(&"round", &"")
			seen["width"] = line.get_meta(&"width", 0.0)
			seen["life"] = line.get_meta(&"life", 0.0)

		for mark in get_tree().get_nodes_in_group(&"round_fx_impact"):
			seen["read"] = mark.get_meta(&"read", &"")

		seen["trails"] = maxi(seen["trails"], get_tree().get_nodes_in_group(&"round_fx_trail").size())

	Input.action_release("throw")
	return seen


func _eye() -> CharacterBody3D:
	var e: CharacterBody3D = EyeScript.new()
	e.seed_value = 3
	e.position = Vector3(0, 2.2, -6)
	add_child(e)
	e.next_swoop_in = 100.0
	return e


func _face(target: Node3D) -> void:
	var way: Vector3 = (target.global_position - p.camera.global_position).normalized()
	p.rotation.y = atan2(-way.x, -way.z)
	p.neck.rotation = Vector3(asin(way.y), 0.0, 0.0)


func _free(e: Node) -> void:
	if is_instance_valid(e):
		e.queue_free()


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
