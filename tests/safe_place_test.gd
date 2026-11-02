extends Node3D
## The safe place: leaving locks your pack and saves, dying goes back to that
## save, and walking back restores you.

const PLAYER := preload("res://Player.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const SafePlace := preload("res://scripts/Hunt/SafePlace.gd")
const MonsterScript := preload("res://scripts/Monsters/Monster.gd")
const SaveFiles := preload("res://scripts/Save/SaveFiles.gd")

const IN := Vector3(0, 1.05, 0)
const OUT := Vector3(30, 1.05, 0)

var p: CharacterBody3D
var failed := 0


func _ready() -> void:
	Props.block(self, Vector3(0, -0.5, 0), Vector3(100, 1, 100))
	p = PLAYER.instantiate()
	add_child(p)
	p.debug_traversal = false
	p.reload_on_death = false
	p.position = IN
	Props.give_revolver(p, 24, 4)
	p.inventory.select_by_id(&"revolver")
	var place: Node3D = SafePlace.build(self, Vector3(0, 2, 0), Vector3(12, 6, 12))
	var left := [0]
	var returned := [0]
	place.left.connect(func(): left[0] += 1)
	place.returned.connect(func(): returned[0] += 1)
	var run_id: String = SaveGame.begin_run(&"hunt_test")
	await _frames(60)
	var lo: Node = p.loadout
	var inv: Node = p.inventory
	lo.pack_round(&"copal")
	lo.pack_item(&"egg")
	var owned_rounds: int = lo.owned[&"rounds"]
	_check("S0 starting inside neither locks nor restocks", not lo.locked and lo.owned[&"rounds"] == owned_rounds and returned[0] == 0)
	var monster: CharacterBody3D = MonsterScript.new()
	monster.kind = &"floating_eye"
	monster.name = "Eye"
	add_child(monster)
	monster.global_position = OUT + Vector3(0, 1, -10)

	var saved_kinds: Array = []
	SaveGame.saved.connect(func(_run, slot, error): saved_kinds.append([slot, error]))
	p.teleport(Transform3D(Basis.IDENTITY, OUT))
	await _frames(4)
	_check("S1 leaving locks the pack and restocks", left[0] == 1 and lo.locked and inv.ammo[&"copal_rounds"] == 12 and lo.item_counts[&"egg"] == 2)
	for i in 180:
		if not saved_kinds.is_empty():
			break
		await get_tree().process_frame
	_check("S2 leaving makes an auto save, whole", not saved_kinds.is_empty() and saved_kinds[0][1] == OK)
	_check("S2b that is now the newest save of the run", not SaveFiles.saves(run_id).is_empty() and SaveFiles.saves(run_id)[0]["kind"] == &"auto")

	var body: Dictionary = SaveGame.gather()
	_check("S3 the saved game holds the pack and the pouches", not body.is_empty() and JSON.stringify(body).contains("copal_rounds"))

	# The run: things used.
	inv.take_ammo(&"copal_rounds", 5)
	lo.item_counts[&"egg"] = 1
	monster.take_hit(500.0, p, &"blast", monster.global_position, Vector3.FORWARD)
	_check("S8 in a run, used stays used", inv.ammo[&"copal_rounds"] == 7 and lo.owned[&"copal_rounds"] == 12)
	var run_body: Dictionary = SaveGame.gather()

	# Death: that save. Everything used comes back, the eye lives.
	SaveGame.apply(body)
	await _frames(2)
	var eye: Node = get_node_or_null("Eye")
	_check("S4 applying that save restores what was used in the run", inv.ammo[&"copal_rounds"] == 12 and lo.item_counts[&"egg"] == 2 and eye != null and not eye.dead)
	SaveGame.apply(run_body)
	await _frames(2)

	# A step in and straight out again, at the door, is not the walk.
	p.health = 40.0
	p.teleport(Transform3D(Basis.IDENTITY, IN))
	await _frames(4)
	_check("S9 back within moments, no shields and no pouch", p.health == 40.0 and lo.locked and returned[0] == 0)
	var saves_now: int = SaveFiles.saves(run_id).size()
	p.teleport(Transform3D(Basis.IDENTITY, OUT))
	await _frames(4)
	await get_tree().process_frame
	_check("S9b and leaving again writes no save", left[0] == 1 and SaveFiles.saves(run_id).size() == saves_now)

	# Something awake close by: no rest until it is dealt with.
	await _frames(int(place.MIN_OUT * 60.0) + 2)
	var hunter: CharacterBody3D = MonsterScript.new()
	hunter.kind = &"floating_eye"
	hunter.name = "Hunter"
	add_child(hunter)
	hunter.global_position = IN + Vector3(3, 1, 0)
	p.teleport(Transform3D(Basis.IDENTITY, IN))
	await _frames(4)
	_check("S10 hunted, the room gives nothing", p.health == 40.0 and lo.locked and returned[0] == 0)
	var owned_before: int = lo.owned[&"copal_rounds"]
	hunter.take_hit(500.0, p, &"blast", hunter.global_position, Vector3.FORWARD)
	await _frames(4)

	_check("S5 back inside: lost shields return and it unlocks", returned[0] == 1 and p.health == p.max_health and not lo.locked)
	_check("S6 walking back restocks from what's left owned", inv.ammo[&"copal_rounds"] == 12 and lo.owned[&"copal_rounds"] == owned_before - 5)
	_check("S7 a monster killed stays dead after walking back", get_node("Eye").dead)
	p.teleport(Transform3D(Basis.IDENTITY, OUT))
	await _frames(4)
	_check("S1b leaving again locks again", left[0] == 2 and lo.locked)
	p.is_dead = true
	await _frames(int(place.MIN_OUT * 60.0) + 2)
	p.health = 1.0
	p.teleport(Transform3D(Basis.IDENTITY, IN))
	await _frames(4)
	_check("S11 the dead get nothing crossing the line", p.health == 1.0 and lo.locked)
	p.is_dead = false
	SaveFiles.delete_run(run_id)
	print("==== RESULTS ====")
	get_tree().quit(1 if failed > 0 else 0)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(label: String, ok: bool) -> void:
	print(("PASS " if ok else "FAIL ") + label)

	if not ok:
		failed += 1
