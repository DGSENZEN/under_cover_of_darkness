extends Node3D
## The hunts' tables: what each blow counts as, what each kind makes of it,
## and statuses that run out in game time.

const Bestiary := preload("res://scripts/Monsters/Bestiary.gd")
const Rounds := preload("res://scripts/Combat/Rounds.gd")
const StatusesScript := preload("res://scripts/Monsters/Statuses.gd")

var failed := 0


func _ready() -> void:
	_check("B1 a bullet counts as its round", Bestiary.source_of(&"bullet", &"lead") == &"lead" and Bestiary.source_of(&"bullet", &"copal") == &"copal")
	_check("B2 shot, blast, shard and fire count as themselves", Bestiary.source_of(&"shot", &"lead") == &"shot" and Bestiary.source_of(&"blast", &"lead") == &"blast" and Bestiary.source_of(&"shard", &"lead") == &"obsidian" and Bestiary.source_of(&"fire", &"lead") == &"fire")
	var drowned: Dictionary = Bestiary.info(&"revenant")
	_check("B4 lead and copal hardly touch a revenant, a shell does half", is_equal_approx(Bestiary.scale_for(&"revenant", &"lead"), 0.3) and is_equal_approx(Bestiary.scale_for(&"revenant", &"copal"), 0.3) and is_equal_approx(Bestiary.scale_for(&"revenant", &"shot"), 0.5))
	_check("B5 fire is neither its weakness nor resisted: what fire does to it is its own", not Bestiary.is_weak(&"revenant", &"fire") and not Bestiary.is_resisted(&"revenant", &"fire") and is_equal_approx(Bestiary.scale_for(&"revenant", &"fire"), 1.0))
	_check("B6 540 health, 40%% back when it rises", float(drowned.get("health", 0.0)) == 540.0 and float(drowned.get("rises_with", 0.0)) == 0.4)
	_check("B3 anything else is a blow", Bestiary.source_of(&"whip", &"lead") == &"blow" and Bestiary.source_of(&"quick", &"copal") == &"blow")
	_check("B4 an eye takes 0.3 from lead", is_equal_approx(Bestiary.scale_for(&"floating_eye", &"lead"), 0.3))
	_check("B5 a source it has no word on is 1.0", is_equal_approx(Bestiary.scale_for(&"floating_eye", &"blow"), 1.0))
	_check("B6 weak and resisted are told apart", Bestiary.is_weak(&"floating_eye", &"copal") and not Bestiary.is_weak(&"floating_eye", &"lead") and Bestiary.is_resisted(&"floating_eye", &"lead") and not Bestiary.is_resisted(&"floating_eye", &"shot"))
	_check("B6b rounds are data", Rounds.info(&"copal")["stock"] == &"copal_rounds" and Rounds.info(&"lead")["source"] == &"lead" and Rounds.info(&"nothing").is_empty())

	var statuses: Node = StatusesScript.new()
	add_child(statuses)
	var started: Array = []
	var ended: Array = []
	statuses.started.connect(func(id): started.append(id))
	statuses.ended.connect(func(id): ended.append(id))
	statuses.apply(&"evil_eye", 0.5)
	_check("B7 applied, it holds and started fired once", statuses.has(&"evil_eye") and started == [&"evil_eye"])
	statuses.apply(&"evil_eye", 0.2)
	_check("B8 a shorter one does not cut it short", statuses.left(&"evil_eye") > 0.4 and started.size() == 1)
	var saved: Dictionary = statuses.save_state()
	await _frames(40)
	_check("B9 it runs out in its seconds, and ended fires once", not statuses.has(&"evil_eye") and ended == [&"evil_eye"])
	statuses.load_state(saved)
	_check("B10 a save keeps the time left", statuses.has(&"evil_eye") and statuses.left(&"evil_eye") > 0.4)
	statuses.clear(&"evil_eye")
	_check("B10b clear ends it", not statuses.has(&"evil_eye") and ended.size() == 2)

	print("==== RESULTS ====")
	get_tree().quit(1 if failed > 0 else 0)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(label: String, ok: bool) -> void:
	print(("PASS " if ok else "FAIL ") + label)

	if not ok:
		failed += 1
