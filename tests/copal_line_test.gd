extends Node3D
## The copal line: drawn on the floor, ánimas can't cross it, and laying it throws off
## whatever is on you. In the open they go round; in a doorway they can't.

const PLAYER := preload("res://Player.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const AnimaScript := preload("res://scripts/Monsters/Anima.gd")
const EyeScript := preload("res://scripts/Monsters/FloatingEye.gd")
const CopalLine := preload("res://scripts/Hunt/CopalLine.gd")
const STATE: Dictionary = AnimaScript.State
const HOME := Vector3(0, 1.05, 0)

var p: CharacterBody3D
var failed := 0


func _ready() -> void:
	Props.block(self, Vector3(0, -0.5, 0), Vector3(300, 1, 300))
	# A wall with a door in it, at x 60, z -3.
	Props.block(self, Vector3(60 - 4.0, 2, -3), Vector3(6, 4, 0.4))
	Props.block(self, Vector3(60 + 4.0, 2, -3), Vector3(6, 4, 0.4))
	p = PLAYER.instantiate()
	add_child(p)
	p.debug_traversal = false
	p.invulnerable = true
	p.reload_on_death = false
	p.position = HOME
	Props.give_revolver(p, 200, 40)
	p.inventory.select_by_id(&"revolver")
	await _frames(60)
	p.loadout.pack_item(&"egg")
	p.loadout.pack_item(&"copal_line")
	p.loadout.item_counts[&"egg"] = 2
	p.loadout.item_counts[&"copal_line"] = 2
	await _laying()
	await _open_ground()
	await _doorway()
	await _keys()
	print("==== RESULTS ====")
	get_tree().quit(1 if failed > 0 else 0)


func _laying() -> void:
	_check("L8 nothing on you, it can still be laid, unlike the egg", p.loadout.use_item(1))
	_check("L2 it takes up the hand", p.loadout.is_using() and p.loadout.using() == &"copal_line")
	_check("L10 and the egg's hold is the egg's alone", p.hand.left_mode() != &"egg")
	await _frames(30)
	_check("L2b not yet", get_tree().get_nodes_in_group(&"copal_lines").is_empty())
	await _frames(10)
	var lines := get_tree().get_nodes_in_group(&"copal_lines")
	_check("L2c laid in 0.6 s, one gone from the pack", lines.size() == 1 and p.loadout.item_counts[&"copal_line"] == 1)
	var line: Node3D = lines[0]
	var ends: Array = line.ends()
	var across: Vector3 = ends[1] - ends[0]
	_check("L1 5 m long (%.1f)" % across.length(), absf(across.length() - 5.0) < 0.05)
	_check("L1b square to your look, ahead of you", absf(across.normalized().dot(-p.global_basis.z)) < 0.05 and (line.global_position - p.global_position).dot(-p.global_basis.z) > 1.0)
	_check("L1c on the floor (%.2f)" % line.global_position.y, absf(line.global_position.y) < 0.1)
	_check("L1d the egg's business stays the egg's: no dispel, no curse cleared", p.hud.curse_state()["dispel"] == 0.0 and p.loadout.ribbons_landed() == 0)
	await _frames(int((CopalLine.LASTS - 0.6) * 60.0) + 40)
	_check("L7 gone after 20 s", get_tree().get_nodes_in_group(&"copal_lines").is_empty())


func _open_ground() -> void:
	await _place_player(HOME)
	var line: Node3D = CopalLine.lay(p)
	var e := _anima(&"hands", p.global_position + Vector3(0, -0.7, -7))
	var reached := await _until(func(): return p.leech.slot_of(e) >= 0, 14.0)
	_check("L4 in the open they go round it", reached)
	# Thrown off by laying another.
	p.loadout.item_counts[&"copal_line"] = 2
	_check("L5a one is on you", e.state == STATE.ON)
	p.loadout.use_item(1)
	await _frames(40)
	_check("L5 laying it throws off any on you", p.leech.count() == 0 and e.state == STATE.THROWN)
	_free([e, line])
	_clear_lines()
	await _frames(3)
	# Offered when it would help.
	var was: Array[StringName] = p.loadout.items.duplicate()
	p.loadout.items = [&"copal_line"] as Array[StringName]
	p.loadout.item_counts[&"copal_line"] = 1
	_check("L5b not offered with nothing on you", not p.loadout.can_offer())
	var held := _anima(&"hands", p.global_position + Vector3(1, -0.5, 0))
	await _frames(1)
	held.put_on_you()
	await _frames(1)
	_check("L5c offered with one on you", p.loadout.can_offer())
	held.queue_free()
	p.loadout.items = was
	await _frames(3)


func _doorway() -> void:
	await _place_player(Vector3(60, 1.05, 2))
	p.rotation.y = 0.0
	# Facing the door: laid across it.
	await _frames(2)
	var line: Node3D = CopalLine.lay(p, Vector3(60, 0, -3))
	var e := _anima(&"hands", Vector3(60, 0.3, -9))
	var f := _anima(&"face", Vector3(61, 1.3, -9))
	var got := await _until(func(): return p.leech.count() > 0 or e.global_position.z > -2.5 or f.global_position.z > -2.5, 10.0)
	_check("L3 no ánima crosses it (%.1f, %.1f)" % [e.global_position.z, f.global_position.z], not got)
	_check("L4b in a doorway they can't get round", p.leech.count() == 0)
	var eye: CharacterBody3D = EyeScript.new()
	eye.seed_value = 7
	eye.position = Vector3(60, 2.2, -5)
	add_child(eye)
	eye.next_swoop_in = 100.0
	var eye_from_z: float = eye.position.z
	await _frames(2)
	eye.state = eye.State.CIRCLE
	var eye_over := await _until(func(): return eye.global_position.z > -2.0, 8.0)
	_check("L6 eyes ignore it", eye_over or eye_from_z < -2.0)
	_free([e, f, eye, line])
	await _frames(3)


func _keys() -> void:
	await _place_player(HOME)
	p.loadout.item_counts[&"copal_line"] = 2
	p.statuses.apply(&"evil_eye", 8.0)
	await _press("use_item_2")
	_check("L9 packed second, B uses it", p.loadout.using() == &"copal_line")
	await _frames(45)
	_clear_lines()
	await _press("use_item")
	_check("L9b V still the first", p.loadout.using() == &"egg")
	await _frames(80)
	_check("L10b the egg still works as it did", not p.statuses.has(&"evil_eye") and p.hud.curse_state()["relief"] >= 0.0)
	p.statuses.clear(&"cleansed")


func _clear_lines() -> void:
	for line in get_tree().get_nodes_in_group(&"copal_lines"):
		line.queue_free()


func _anima(form: StringName, at: Vector3) -> CharacterBody3D:
	var e: CharacterBody3D = AnimaScript.new()
	e.form = form
	e.position = at
	add_child(e)
	return e


func _free(list: Array) -> void:
	for e in list:
		if is_instance_valid(e):
			e.queue_free()


func _place_player(at: Vector3) -> void:
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
