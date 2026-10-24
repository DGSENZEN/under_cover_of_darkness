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
	player.revolver._start_loading(player.revolver.weapon())
	_check("reload indicator follows actual reload", readout.snapshot().get("reloading", false))
	player.revolver._stop_loading()
	player.revolver.flip_barrel()
	state = readout.snapshot()
	_check("lower barrel shows its own shell and reserve", state.get("loaded") == 1 and state.get("reserve") == 4 and state.get("capacity") == 1)
	player.inventory.holster()
	_check("holstering hides ammo readout", readout.snapshot().is_empty())
	print("==== RESULTS ====")
	get_tree().quit(1 if failed > 0 else 0)


func _check(label: String, ok: bool) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failed += 1
