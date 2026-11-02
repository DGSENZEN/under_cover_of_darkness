extends Node3D
## The obsidian burst: key 4, for when you are crowded. Everything near, hurt and
## thrown out, everything on you thrown off, and a wall stops it.

const PLAYER := preload("res://Player.tscn")
const GUARD := preload("res://Guard.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const AnimaScript := preload("res://scripts/Monsters/Anima.gd")
const EyeScript := preload("res://scripts/Monsters/FloatingEye.gd")
const STATE: Dictionary = AnimaScript.State
const HOME := Vector3(0, 1.05, 0)

var p: CharacterBody3D
var failed := 0


func _ready() -> void:
	Props.block(self, Vector3(0, -0.5, 0), Vector3(200, 1, 200))
	Props.block(self, Vector3(0, 2, 4), Vector3(8, 4, 0.4))
	p = PLAYER.instantiate()
	add_child(p)
	p.debug_traversal = false
	p.invulnerable = true
	p.reload_on_death = false
	p.position = HOME
	Props.give_revolver(p, 200, 40)
	p.inventory.select_by_id(&"revolver")
	await _frames(60)
	_glass()
	await _reach()
	await _on_you()
	await _refused()
	print("==== RESULTS ====")
	get_tree().quit(1 if failed > 0 else 0)


## The glass it is made of: real shapes, wearing the Shard's look.
func _glass() -> void:
	var scene: PackedScene = load("res://assets/magic/burst_glass.glb")
	_check("G0 the glass is there", scene != null)

	if scene == null:
		return

	var glass: Node3D = scene.instantiate()
	var meshes := glass.find_children("*", "MeshInstance3D", true, false)
	_check("G1 five spikes, six chunks", meshes.filter(func(m): return m.name.begins_with("Spike")).size() == 5 and meshes.filter(func(m): return m.name.begins_with("Chunk")).size() == 6)
	var colours: PackedColorArray = meshes[0].mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	_check("G1b corners in its colours, for the glass's edges", colours.size() > 0)
	var tall: AABB = glass.find_child("Spike_1", true, false).get_aabb()
	_check("G1c a spike grows from its root, up, about a metre (%.2f)" % tall.end.y, absf(tall.end.y - 1.0) < 0.1 and tall.position.y < 0.0)
	glass.free()


func _reach() -> void:
	var near_a := _anima(&"torso", Vector3(3, 0.4, -2))
	var near_b := _anima(&"torso", Vector3(-3, 0.4, -2))
	var far := _anima(&"torso", Vector3(0, 0.4, -7))
	var behind := _anima(&"torso", Vector3(0, 0.4, 5))
	var eye: CharacterBody3D = EyeScript.new()
	eye.seed_value = 4
	eye.position = Vector3(0, 2.2, -3)
	add_child(eye)
	eye.next_swoop_in = 100.0
	await _frames(2)

	for e in [near_a, near_b, far, behind]:
		e.asleep = false
		e.state = STATE.THROWN

	var man: CharacterBody3D = GUARD.instantiate()
	# Set first: spawned on you, a man carries you off like a lift.
	man.position = Vector3(3, 0.1, 1)
	add_child(man)
	await _frames(10)
	var man_was: float = man.health
	var eye_was: float = eye.health
	var near_from := near_a.global_position
	p.power.power = 100.0
	Input.action_press("spell_4")
	await _frames(12)
	_check("B1 not before its time", is_equal_approx(p.power.power, 100.0) and near_a.health == 130.0)
	await _frames(10)
	Input.action_release("spell_4")
	# (Less the 8 the eye pays back, being weak to obsidian.)
	_check("B1b key 4, 40 power, 0.3 s (%.0f)" % p.power.power, absf(p.power.power - 68.0) < 0.6)
	_check("B2 hurts everything within 5.5 m (%.0f, %.0f)" % [near_a.health, near_b.health], near_a.health == 95.0 and near_b.health == 95.0)
	_check("B2b nothing farther", far.health == 130.0)
	_check("B3 eyes take it at 1.5 (%.1f)" % (eye_was - eye.health), is_equal_approx(eye_was - eye.health, 52.5))
	_check("B4 a wall stops it", behind.health == 130.0)
	_check("B10 a man takes it as a blast", man.health < man_was)
	_check("B9 a ring goes out", not get_tree().get_nodes_in_group(&"burst_ring").is_empty())
	await _frames(30)
	_check("B6 thrown outward, hard (%.1f m)" % near_from.distance_to(near_a.global_position), near_from.distance_to(near_a.global_position) > 1.5)
	_check("B9b splinters stay in the floor", not get_tree().get_nodes_in_group(&"burst_splinters").is_empty())
	await _frames(300)
	_check("B9c and are gone in a few seconds", get_tree().get_nodes_in_group(&"burst_splinters").is_empty() and get_tree().get_nodes_in_group(&"burst_ring").is_empty())

	for e in [near_a, near_b, far, behind, eye, man]:
		e.queue_free()

	await _frames(3)


func _on_you() -> void:
	p.power.power = 100.0
	var a := _anima(&"face", p.global_position + Vector3(1, 0.5, 0))
	var b := _anima(&"face", p.global_position + Vector3(-1, 0.5, 0))
	await _frames(1)
	a.put_on_you()
	b.put_on_you()
	await _frames(2)
	_check("B7 two on you", p.leech.count() == 2)
	await _until(func(): return p.revolver.ready_to_fire(), 3.0)
	Input.action_press("spell_4")
	await _frames(22)
	Input.action_release("spell_4")
	_check("B5 cast with them on you: all thrown off", p.leech.count() == 0 and a.state == STATE.THROWN and b.state == STATE.THROWN)
	a.queue_free()
	b.queue_free()
	await _frames(3)


func _refused() -> void:
	p.power.power = 30.0
	await _frames(1)
	var a := _anima(&"torso", Vector3(2, 0.4, -2))
	a.state = STATE.THROWN
	await _frames(2)
	var was: float = a.health
	Input.action_press("spell_4")
	await _frames(22)
	Input.action_release("spell_4")
	_check("B8 refused without the power, nothing spent", a.health == was and absf(p.power.power - 30.0) < 3.0)
	a.queue_free()
	await _frames(3)


func _anima(form: StringName, at: Vector3) -> CharacterBody3D:
	var e: CharacterBody3D = AnimaScript.new()
	e.form = form
	e.position = at
	add_child(e)
	return e


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
