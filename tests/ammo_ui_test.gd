extends Node3D
const PLAYER := preload("res://Player.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
var failed := 0


func _ready() -> void:
	Props.block(self, Vector3(0, -0.5, 0), Vector3(20, 1, 20))
	var player: CharacterBody3D = PLAYER.instantiate()
	add_child(player)
	player.debug_traversal = false
	player.invulnerable = true
	player.position = Vector3(0, 1.05, 0)
	Props.give_revolver(player)
	player.inventory.select_by_id(&"revolver")
	for i in 40:
		await get_tree().physics_frame
	var hud: Node = player.hud
	var readout: Control = hud.get("_ammo")
	var state: Dictionary = readout.snapshot()
	_check("drawn revolver shows six rounds and 24 reserve", state.get("loaded") == 6 and state.get("reserve") == 24)
	player.revolver._pull(player.revolver.weapon())
	state = readout.snapshot()
	_check("firing updates loaded ammo immediately", state.get("loaded") == 5 and state.get("reserve") == 24)
	_check("the readout names the round", state.get("round") == &"lead")
	player.inventory.ammo[&"copal_rounds"] = 12
	player.revolver.cylinder_round = &"copal"
	_check("the reserve is the round's own pouch", readout.snapshot().get("reserve") == 12)
	player.revolver.cylinder_round = &"lead"
	player.revolver._start_loading(player.revolver.weapon())
	_check("reload indicator follows actual reload", readout.snapshot().get("reloading", false))
	player.revolver._stop_loading()
	player.revolver.flip_barrel()
	state = readout.snapshot()
	_check("lower barrel shows its own shell and reserve", state.get("loaded") == 1 and state.get("reserve") == 4 and state.get("capacity") == 1)
	await _marks(player, hud, readout)
	player.inventory.select_by_id(&"revolver")
	await _frames(40)
	player.inventory.holster()
	_check("U7 holstering hides ammo readout", readout.snapshot().is_empty())
	print("==== RESULTS ====")
	get_tree().quit(1 if failed > 0 else 0)


func _marks(player: CharacterBody3D, hud: Node, readout: Control) -> void:
	const Rounds := preload("res://scripts/Combat/Rounds.gd")
	var g: Node = player.revolver
	g.barrel = &"cylinder"
	g.reset_for_practice()
	var snap: Dictionary = readout.snapshot()
	_check("U1 six chambers shown, coloured by round", snap["chambers"].size() == 6 and snap["chambers"][0] == Rounds.info(&"lead")["colour"])
	g.reset_for_practice()
	g.loaded[&"cylinder"] = 5
	snap = readout.snapshot()
	_check("U2 firing empties a chamber", snap["loaded"] == 5 and snap["chambers"][5] == readout.SPENT and snap["chambers"][4] != readout.SPENT)
	g.cylinder_round = &"copal"
	snap = readout.snapshot()
	_check("U3 copal chambers take copal's colour", snap["chambers"][0] == Rounds.info(&"copal")["colour"])
	g.cylinder_round = &"lead"
	player.loadout.pack_item(&"egg")
	player.loadout.item_counts[&"egg"] = 2
	snap = readout.snapshot()
	_check("U4 a packed egg shows its count", snap["items"].get(&"egg", 0) == 2)
	_check("U5a no evil eye, no view of it", not hud.curse_view_shown())
	player.statuses.apply(&"evil_eye", 2.0)
	await _frames(40)
	_check("U5 the evil eye view shows under the status", hud.curse_view_shown() and readout.snapshot()["evil_eye"])
	player.statuses.clear(&"evil_eye")
	await _frames(90)
	_check("U5b and goes with it", not hud.curse_view_shown())
	var cross: Control = hud.get("_crosshair")
	_check("U6 weak and resisted marks differ", cross.mark_ink(&"weak") != cross.mark_ink(&"resisted"))
	player.loadout.unpack_item(&"egg")


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(label: String, ok: bool) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failed += 1
