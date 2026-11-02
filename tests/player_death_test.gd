extends Node3D
## The Exsecrator's deaths: which one plays, how long it takes, and what it does to the fight
## around it.

const PLAYER := preload("res://Player.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")
const AnimaScript := preload("res://scripts/Monsters/Anima.gd")
const EyeScript := preload("res://scripts/Monsters/FloatingEye.gd")
const EyeGobScript := preload("res://scripts/Monsters/EyeGob.gd")
const HOME := Vector3(0, 1.05, 0)

var failed := 0
var p: CharacterBody3D


func _ready() -> void:
	Props.block(self, Vector3(0, -0.5, 0), Vector3(200, 1, 200))
	await _which()
	await _how_long()
	await _the_words()
	await _skipping()
	await _paused()
	await _freed()
	print("==== RESULTS ====")
	get_tree().quit(1 if failed > 0 else 0)


## A fresh player, nothing else in the map.
func _fresh(reload := false) -> void:
	_clear()

	if is_instance_valid(p):
		p.free()

	await _frames(2)
	p = PLAYER.instantiate()
	add_child(p)
	p.debug_traversal = false
	p.reload_on_death = reload
	p.position = HOME
	await _frames(30)
	p.invulnerable = false


func _clear() -> void:
	for m in get_tree().get_nodes_in_group(&"monsters"):
		m.free()

	for g in get_tree().get_nodes_in_group(&"eye_gobs"):
		g.free()


## Dies with that on you, by that blow, or by the drain with none. What death does it choose?
func _dying_by(cursed: bool, feeding: bool, blow: StringName) -> void:
	await _fresh()

	if cursed:
		p.statuses.apply(&"evil_eye", 60.0)

	if feeding:
		var one: CharacterBody3D = AnimaScript.new()
		one.form = &"hands"
		one.position = HOME + Vector3(0.8, 0.3, 0)
		add_child(one)
		await _frames(1)
		one.put_on_you()
		await _frames(2)

	p.health = 0.01

	match blow:
		&"eye":
			var eye: CharacterBody3D = EyeScript.new()
			eye.position = HOME + Vector3(0, 2, -40)
			add_child(eye)
			eye.sleep()
			p.take_damage(50.0, eye)
		&"gob":
			var gob: Node3D = EyeGobScript.spat_at(self, HOME + Vector3(0, 2, -40), HOME + Vector3(0, 2, -60), null)
			p.take_damage(50.0, gob)
		&"anima":
			var cutter: CharacterBody3D = AnimaScript.new()
			cutter.form = &"hands"
			cutter.position = HOME + Vector3(0, 0, -40)
			add_child(cutter)
			cutter.sleep()
			p.take_damage(50.0, cutter)
		&"guard":
			var man := Node3D.new()
			add_child(man)
			p.take_damage(50.0, man)
			man.queue_free()
		_:
			p.drain_life(50.0)


func _which() -> void:
	await _fresh()
	_check("P0 alive, no death", p.death.kind == &"" and not p.death.playing())
	await _dying_by(true, true, &"")
	_check("P1 curse and something feeding, the drain's blow: both (%s)" % p.death.kind, p.death.kind == &"both")
	await _dying_by(true, true, &"guard")
	_check("P1b even a guard's blow", p.death.kind == &"both")
	await _dying_by(false, true, &"guard")
	_check("P2 something feeding, no curse: the ánimas (%s)" % p.death.kind, p.death.kind == &"animas")
	await _dying_by(false, false, &"eye")
	_check("P3 nothing feeding, an eye's bite: the eyes (%s)" % p.death.kind, p.death.kind == &"eyes")
	await _dying_by(true, false, &"gob")
	_check("P3b a gob: the eyes (%s)" % p.death.kind, p.death.kind == &"eyes")
	await _dying_by(false, false, &"anima")
	_check("P4 nothing feeding, an ánima's swipe: the swipe (%s)" % p.death.kind, p.death.kind == &"swipe")
	await _dying_by(true, false, &"guard")
	_check("P5 cursed, killed by a guard, nothing feeding: today's fall (%s)" % p.death.kind, p.death.kind == &"fall" and not p.death.playing())


## Seconds till it finishes, or till the page opens.
func _time_till(done: Callable, most: float) -> float:
	var t := 0.0

	while t < most and not done.call():
		await get_tree().physics_frame
		t += 1.0 / 60.0

	return t


func _how_long() -> void:
	await _dying_by(false, false, &"eye")
	# (A blow's hit-stop slows the first few frames of it: within a tenth.)
	var eyes_took: float = await _time_till(func(): return not p.death.playing(), 8.0)
	await _dying_by(true, true, &"")
	var both_took: float = await _time_till(func(): return not p.death.playing(), 8.0)
	_check("P6 each takes its length (%.2f, %.2f)" % [eyes_took, both_took], absf(eyes_took - 3.0) < 0.1 and absf(both_took - 4.0) < 0.1)
	# The page.
	await _fresh(true)
	p.statuses.apply(&"evil_eye", 60.0)
	var eye: CharacterBody3D = EyeScript.new()
	eye.position = HOME + Vector3(0, 2, -40)
	add_child(eye)
	eye.sleep()
	p.health = 0.01
	p.take_damage(50.0, eye)
	await _frames(int(2.9 * 60.0))
	var shut: bool = not p.hud.death_page.visible
	await _frames(20)
	_check("P7 the page waits for the end", shut and p.hud.death_page.visible)
	p.hud.death_page.hide()
	await _fresh(true)
	var man := Node3D.new()
	add_child(man)
	p.health = 0.01
	p.take_damage(50.0, man)
	var fall_page: float = await _time_till(func(): return p.hud.death_page.visible, 4.0)
	_check("P7b the fall's page still comes at 2 s (%.2f)" % fall_page, absf(fall_page - 2.0) < 0.1)
	man.queue_free()
	p.hud.death_page.hide()


func _the_words() -> void:
	await _dying_by(false, false, &"eye")
	await _frames(int(2.4 * 60.0))
	var before: float = p.hud._death.modulate.a
	await _until(func(): return not p.death.playing(), 2.0)
	var after: float = p.hud._death.modulate.a
	_check("P8 the words start half a second from the end (%.2f, %.2f)" % [before, after], before == 0.0 and after > 0.9)
	await _dying_by(false, false, &"guard")
	await _frames(30)
	_check("P8b the fall's fade and words start at once (%.2f)" % p.hud._fade.color.a, p.hud._fade.color.a > 0.2)


func _skipping() -> void:
	await _dying_by(false, false, &"eye")
	await _frames(30)
	await _press("throw")
	await _frames(20)
	_check("P9 an attack press before 1 s does nothing (%.2f)" % p.death.at(), p.death.playing() and p.death.at() < 1.0)
	await _frames(20)
	var pressed_at: float = p.death.at()
	await _press("throw")
	var left: float = await _time_till(func(): return not p.death.playing(), 3.0)
	_check("P9b after it, half a second to the end (pressed at %.2f, %.2f more)" % [pressed_at, left], left < 0.6)


func _paused() -> void:
	await _dying_by(false, false, &"eye")
	await _frames(70)
	var was: float = p.death.share()
	get_tree().paused = true
	Input.action_press("throw")

	for i in 20:
		await get_tree().physics_frame

	var still: float = p.death.share()
	Input.action_release("throw")

	for i in 3:
		await get_tree().physics_frame

	get_tree().paused = false
	_check("P10 paused, the clock waits and a press is ignored (%.3f, %.3f)" % [was, still], absf(was - still) < 0.02)
	await _frames(3)
	_check("P10b and it goes on after", p.death.playing() and p.death.share() < 0.6)


func _freed() -> void:
	await _dying_by(true, true, &"")
	await _frames(30)
	await _fresh()
	await _frames(10)
	_check("P11 freed mid-death, the next starts clean", Sfx.drain_muffle == 0.0 and p.death.kind == &"")


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
