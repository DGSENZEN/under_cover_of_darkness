extends Node3D
## The hunt gym: you can read the clue, pack, and walk out to the yard, on foot
## from where you start.

const GYM := preload("res://maps/hunt_gym.tscn")
const JobBook := preload("res://scripts/Level/JobBook.gd")
const SaveFiles := preload("res://scripts/Save/SaveFiles.gd")

var failed := 0


func _ready() -> void:
	JobBook.reload()
	var gym: Node3D = GYM.instantiate()
	add_child(gym)
	await _frames(60)
	var p: CharacterBody3D = get_tree().get_first_node_in_group(&"player")
	_check("H1 the map loads and the player is in the kit room", gym.safe_place.overlaps_body(p))
	_check("H6 the job file parses", JobBook.library()["readables"].has("eye_clue") and JobBook.library()["notes"].has("eye_weakness"))
	CityState.job.read_slot("eye_clue")
	_check("H3 reading the clue adds the pencil note", CityState.job.notes.has("eye_weakness"))
	gym.kit_table.piece(&"copal").frob(p)
	gym.kit_table.piece(&"egg").frob(p)
	_check("H7 the table packs for you", p.loadout.rounds.has(&"copal") and p.loadout.items.has(&"egg"))

	# Turn to the door and walk out.
	p.rotation.y = 0.0
	Input.action_press("move_forward")
	var t := 0.0

	while p.global_position.z > gym.YARD_START and t < 6.0:
		await get_tree().physics_frame
		t += 1.0 / 60.0

	Input.action_release("move_forward")
	_check("H2 the player reaches the yard on foot from spawn (%.1f s)" % t, p.global_position.z <= gym.YARD_START)
	_check("H4 walking out locks and restocks", p.loadout.locked and p.inventory.ammo[&"copal_rounds"] == 12)

	await _frames(2)
	_check("H9 stepping into the yard, the first wave comes", gym.wave_now == 1 and gym.get_node("Eye1").visible and not gym.get_node("Eye1").asleep)
	_check("H9b the next waves wait", gym.get_node("Eye4").asleep)

	var scanner = p.scanner
	var under: Vector3 = gym.BEAM_AT + Vector3(0, 1.0, 0)
	_check("H5 the slide beam is only for a crouch", not scanner.fits(under, false) and scanner.fits(under, true))
	var side: Vector3 = gym.BEAM_AT + Vector3(gym.BEAM_WIDTH * 0.5 + 0.2, 1.0, 0)
	_check("H5b there is no way past it on your feet", not scanner.fits(side, false))

	_check("H8 the lit room and the dark yard are both lit at all", gym.find_children("*", "Light3D", true, false).size() >= 3)
	var run: String = CityState.run_id
	gym.queue_free()
	await get_tree().process_frame
	SaveFiles.delete_run(run)
	print("==== RESULTS ====")
	get_tree().quit(1 if failed > 0 else 0)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(label: String, ok: bool) -> void:
	print(("PASS " if ok else "FAIL ") + label)

	if not ok:
		failed += 1
