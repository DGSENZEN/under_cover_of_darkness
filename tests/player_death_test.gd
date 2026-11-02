extends Node3D
## The Exsecrator's deaths: which one plays, how long it takes, and what it does to the fight
## around it.

const PLAYER := preload("res://Player.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")
const AnimaScript := preload("res://scripts/Monsters/Anima.gd")
const EyeScript := preload("res://scripts/Monsters/FloatingEye.gd")
const EyeGobScript := preload("res://scripts/Monsters/EyeGob.gd")
const DeathQuotes := preload("res://scripts/UI/DeathQuotes.gd")
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
	await _staying()
	await _going_down()
	await _the_eyes()
	await _the_rest()
	await _heard()
	await _marked_dead()
	await _quotes()
	await _review_of_the_deaths()
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
	await _frames(int(5.9 * 60.0))
	var shut: bool = not p.hud.death_page.visible
	await _frames(45)
	_check("P7 the page waits for the end, and for the words", shut and p.hud.death_page.visible)
	p.hud.death_page.hide()
	await _fresh(true)
	var man := Node3D.new()
	add_child(man)
	p.health = 0.01
	p.take_damage(50.0, man)
	var fall_page: float = await _time_till(func(): return p.hud.death_page.visible, 8.0)
	_check("P7b the fall's page comes after its words (%.2f)" % fall_page, absf(fall_page - (p.death.FALL_TAKES + p.death.QUOTE_TAKES)) < 0.1)
	man.queue_free()
	p.hud.death_page.hide()


func _the_words() -> void:
	await _dying_by(false, false, &"eye")
	await _frames(int(2.4 * 60.0))
	var before: float = p.hud._fade.color.a
	await _until(func(): return not p.death.playing(), 2.0)
	await _frames(2)
	var after: float = p.hud._fade.color.a
	_check("P8 the dark waits for the very end (%.2f, %.2f)" % [before, after], before == 0.0 and after > 0.85)
	_check("P8c at the end there is a moment of nothing", p.hud._death.shown() == 0.0)
	await _frames(int(p.hud._death.DARK_FOR * 60.0 + p.hud._death.CATCHES * 60.0) + 2)
	_check("P8d then a candle", p.hud._death.shown() > 0.95)
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


func _camera_above_floor() -> float:
	return p.camera.global_position.y


func _going_down() -> void:
	await _dying_by(false, false, &"guard")
	await _frames(30)
	_check("C1 the fall's camera is as it was", p.juice.death_fall.is_empty() and p.juice.death > 0.0)
	# A face on you, to your right.
	await _fresh()
	var face: CharacterBody3D = AnimaScript.new()
	face.form = &"face"
	face.position = HOME + Vector3(0.9, 0.3, -0.2)
	add_child(face)
	await _frames(1)
	face.put_on_you()
	await _frames(40)
	var slot: int = p.leech.slot_of(face)
	var hands: Node3D = p.leech_hands
	var near_before: float = hands.face_near(slot)
	p.health = 0.01
	p.drain_life(50.0)
	await _frames(30)
	_check("C2 dying with it on you, the hands stay shown", p.is_dead and hands.shown(slot))
	_check("C3 you go down toward its side", signf(p.juice.death_fall["side"]) == signf((p.global_basis.inverse() * p.leech.slot_side(slot)).x) and p.juice.death_fall["down"] > 0.0)
	await _until(func(): return p.leech.last_gulp() > 0.9, 3.0)
	await _frames(4)
	_check("C2b the face too, and it comes in for the last (%.2f, %.2f)" % [near_before, hands.face_near(slot)], hands.face_shown(slot) and hands.face_near(slot) > near_before + 0.2)
	await _until(func(): return p.leech.count() == 0, 2.0)
	await _frames(int(0.8 * 60.0))
	_check("C5 after it lets go, the hands go", not hands.shown(slot) and not hands.face_shown(slot))
	var pose_then: Dictionary = p.juice.death_fall.duplicate()
	await _frames(20)
	_check("C6 the view holds still after it lets go", p.juice.death_fall == pose_then)
	await _until(func(): return not p.death.playing(), 3.0)
	await _frames(20)
	var above: float = _camera_above_floor()
	_check("C4 you end low on the floor, not through it (%.2f)" % above, above > 0.08 and above < 0.5)
	# Only hands on you.
	await _dying_by(false, true, &"guard")
	var holder: CharacterBody3D = _on_you_now()
	var held_slot: int = p.leech.slot_of(holder)
	await _until(func(): return p.leech.last_gulp() > 0.9, 3.0)
	_check("C2c only hands: one long squeeze (%.2f)" % p.leech_hands.squeeze(held_slot), p.leech_hands.squeeze(held_slot) > 0.7)
	# In mid-air, you come down first.
	await _fresh()
	p.global_position = HOME + Vector3(0, 3, 0)
	p.health = 0.01
	var eye: CharacterBody3D = EyeScript.new()
	eye.position = HOME + Vector3(0, 2, -40)
	add_child(eye)
	eye.sleep()
	p.take_damage(50.0, eye)
	await _until(func(): return not p.death.playing(), 5.0)
	await _frames(20)
	above = _camera_above_floor()
	_check("C4b dying in mid-air, you come down first (%.2f)" % above, above > 0.08 and above < 0.5)
	# On a ledge.
	await _fresh()
	p.movement_state = p.MoveState.HANGING
	p.health = 0.01
	var man := Node3D.new()
	add_child(man)
	var cutter: CharacterBody3D = AnimaScript.new()
	cutter.form = &"hands"
	cutter.position = HOME + Vector3(0, 0, -40)
	add_child(cutter)
	cutter.sleep()
	p.take_damage(50.0, cutter)
	man.queue_free()
	await _until(func(): return not p.death.playing(), 5.0)
	await _frames(20)
	above = _camera_above_floor()
	_check("C4c dying on a ledge: you land, no error (%.2f)" % above, above > 0.08 and above < 0.5)
	# Crouched: not through the floor.
	await _fresh()
	Input.action_press("crouch")
	await _frames(30)
	p.health = 0.01
	var eye2: CharacterBody3D = EyeScript.new()
	eye2.position = HOME + Vector3(0, 2, -40)
	add_child(eye2)
	eye2.sleep()
	p.take_damage(50.0, eye2)
	await _until(func(): return not p.death.playing(), 5.0)
	await _frames(20)
	Input.action_release("crouch")
	above = _camera_above_floor()
	_check("C4d dying crouched, not through the floor (%.2f)" % above, above > 0.08)


func _the_eyes() -> void:
	await _dying_by(false, false, &"guard")
	await _frames(60)
	_check("E5 the fall: none of it", p.hud.curse_state()["dying"] == 0.0)
	# Killed by an eye, no curse on you.
	await _dying_by(false, false, &"eye")
	await _frames(45)
	var hud: Node = p.hud
	var early: Dictionary = hud.curse_state()
	_check("E1 killed by an eye with no curse on you: the flesh still comes (%.2f)" % early["dying"], early["dying"] > 0.0 and hud.curse_view_shown())
	await _frames(45)
	var half: Dictionary = hud.curse_state()
	await _until(func(): return p.death.share() > 0.9, 2.0)
	var late: Dictionary = hud.curse_state()
	_check("E2 it closes all the way (%.2f)" % late["dying"], late["dying"] > 0.95)
	_check("E8 nothing of the HUD's left over it", not hud._crosshair.visible and not hud._gem.visible and not hud._shields.visible and not hud._ammo.visible)
	_check("E3 every eye opens, and more than the curse ever had (%d, %.2f)" % [late["ring_open"], late["extra_eyes"]], late["ring_open"] == 6 and late["extra_eyes"] > 0.9)
	_check("E4 the last eye opens in the middle, late (%.2f, %.2f)" % [half["last_eye"], late["last_eye"]], half["last_eye"] == 0.0 and late["last_eye"] > 0.9)
	_check("E4b the heart is failing by the end (%.2f)" % late["failing"], late["failing"] > 0.5 and half["failing"] == 0.0)
	await _until(func(): return not p.death.playing(), 2.0)
	await _frames(60)
	_check("E7 and it stays, under the page: nothing comes back", hud.curse_state()["dying"] > 0.95 and hud.curse_view_shown())
	# Using the egg as you die.
	await _fresh()
	hud = p.hud
	hud.egg_broke()
	await _frames(2)
	var eye: CharacterBody3D = EyeScript.new()
	eye.position = HOME + Vector3(0, 2, -40)
	add_child(eye)
	eye.sleep()
	p.health = 0.01
	p.take_damage(50.0, eye)
	await _frames(5)
	_check("E6 the egg going as you die: it stops", hud.curse_state()["dispel"] == 0.0 and hud.curse_state()["gather"] == 0.0)
	await _until(func(): return not p.death.playing(), 4.0)
	_check("E6b and the death finishes", not p.death.playing())


func _the_rest() -> void:
	# The ánimas'.
	await _dying_by(false, true, &"guard")
	var hud: Node = p.hud
	await _frames(6)
	var start: float = hud.drain_state()["no_colour"]
	var least_rise := 1.0
	var was: float = start

	for i in 90:
		await get_tree().physics_frame
		var now: float = hud.drain_state()["no_colour"]
		least_rise = minf(least_rise, now - was)
		was = now

	await _until(func(): return p.leech.last_gulp() > 0.95, 3.0)
	await _frames(15)
	_check("A1 the ánimas' death: colour goes with the gulps (%.2f to %.2f)" % [start, hud.drain_state()["no_colour"]], start < 0.5 and least_rise >= 0.0 and hud.drain_state()["no_colour"] > 0.95)
	_check("A0 the drain stays on your sight as you go", hud.drain_view_shown() and hud.drain_state()["drain"] > 0.2)
	await _until(func(): return p.leech.count() == 0, 2.0)
	await _frames(4)
	_check("A2 you still see them leave, grey (%.2f)" % hud.drain_state()["sight_fails"], hud.drain_state()["sight_fails"] < 0.5)
	await _until(func(): return not p.death.playing(), 2.0)
	_check("A3 then your sight fails (%.2f)" % hud.drain_state()["sight_fails"], hud.drain_state()["sight_fails"] > 0.95)
	await _frames(30)
	_check("A4 no colour floods back: you aren't free", hud.drain_state()["release"] == 0.0 and hud.drain_view_shown())
	# Both.
	await _dying_by(true, true, &"")
	hud = p.hud
	var look: ShaderMaterial = hud._curse_view.material
	await _frames(60)
	var watching: bool = look.get_shader_parameter(&"feeders")[0].z > 0.5
	var open_yet: float = hud.curse_state()["shut"]
	var shut_at := -1.0
	var slack_at := -1.0

	while p.death.playing():
		await get_tree().physics_frame

		if shut_at < 0.0 and hud.curse_state()["shut"] > 0.9:
			shut_at = p.death.at()

		if slack_at < 0.0 and hud.curse_state()["slack"] > 0.9:
			slack_at = p.death.at()

	var both: Dictionary = hud.curse_state()
	_check("B1 both: the eyes watch them, open", watching and open_yet == 0.0)
	_check("B2 on the last gulp all shut and the flesh goes slack, together (%.2f, %.2f)" % [shut_at, slack_at], shut_at > 0.0 and absf(shut_at - slack_at) < 0.05 and shut_at <= p.death.LETS_GO[&"both"] + 0.05)
	_check("B3 no eye in the middle", both["last_eye"] == 0.0 and both["extra_eyes"] == 0.0)
	_check("B3b a gap left to see them through (%.2f)" % both["dying"], both["dying"] > 0.3 and both["dying"] < 0.8)
	_check("B4 the heart stops", both["failing"] == 1.0)
	# The swipe.
	await _dying_by(false, false, &"anima")
	hud = p.hud
	hud.claw_at(1.0)
	await _frames(90)
	var clawed: float = hud.drain_state()["claws"]
	_check("S1 the swipe: its marks stay open (%.2f)" % clawed, clawed > 0.5 and hud.drain_view_shown())
	await _until(func(): return not p.death.playing(), 2.0)
	_check("S1b and your sight fails", hud.drain_state()["sight_fails"] > 0.95)
	await _dying_by(true, false, &"anima")
	hud = p.hud
	await _frames(70)
	var swipe_cursed: Dictionary = hud.curse_state()
	_check("S2 cursed, its flesh falls slack, with no ending of its own (%.2f)" % swipe_cursed["slack"], swipe_cursed["slack"] > 0.9 and swipe_cursed["last_eye"] == 0.0 and swipe_cursed["dying"] == 0.0)
	await _fresh()
	await _frames(10)
	_check("R1 the next life starts clean: nothing stuck", p.hud.curse_state()["slack"] == 0.0 and p.hud.drain_state()["no_colour"] == 0.0 and not p.hud.drain_view_shown())


## Set dead by something else, with no death chosen: no pose asked of nothing.
func _marked_dead() -> void:
	await _fresh()
	p.is_dead = true
	await _frames(5)
	_check("Z1 marked dead with no death chosen: the old fall", p.juice.death_fall.is_empty() and p.juice.death > 0.0)
	p.is_dead = false


func _quotes() -> void:
	_check("Q1 all eight of the user's quotes", DeathQuotes.ALL.size() == 8 and DeathQuotes.ALL[1]["text"] == "“Cada suspiro es como un sorbo de vida del que uno se deshace.”" and DeathQuotes.ALL[1]["by"] == "Juan Rulfo, Pedro Paramo")
	var used := {}

	for how in [&"eyes", &"animas", &"both", &"swipe", &"fall"]:
		_check("Q2 %s has a few of its own" % how, DeathQuotes.FOR[how].size() >= 3)

		for id in DeathQuotes.FOR[how]:
			used[id] = true

	_check("Q2b every quote can come up", used.size() == DeathQuotes.ALL.size())
	_check("Q2c a sip of life is for what drinks you", DeathQuotes.FOR[&"animas"].has(1) and not DeathQuotes.FOR[&"eyes"].has(1))
	var repeats := 0
	var was: Dictionary = {}

	for i in 30:
		var now: Dictionary = DeathQuotes.choose(&"animas")

		if now == was:
			repeats += 1

		was = now

	_check("Q3 never the same one twice running", repeats == 0)
	# In the game.
	await _dying_by(false, true, &"guard")
	var hud: Node = p.hud
	var text: String = hud._death.quote()
	_check("Q4 the ánimas' death takes one of theirs", DeathQuotes.FOR[&"animas"].any(func(id): return DeathQuotes.ALL[id]["text"] == text))
	_check("Q5 there is nothing of the old words", not text.contains("caught"))
	await _until(func(): return not p.death.playing(), 5.0)
	await _frames(120)
	_check("Q6 it is up under the page, on its background (%.2f)" % hud._death.shown(), hud._death.shown() > 0.95 and hud._death.visible)
	await _dying_by(false, false, &"guard")
	hud = p.hud
	await _frames(200)
	_check("Q7 a guard's kill has one too", DeathQuotes.FOR[&"fall"].any(func(id): return DeathQuotes.ALL[id]["text"] == hud._death.quote()) and hud._death.shown() > 0.9)
	# Every one fits, at the size it is played.
	var fits := true

	for one in DeathQuotes.ALL:
		hud._death.set_quote(one)
		await _frames(2)
		fits = fits and hud._death.bottom_of_words() < get_viewport().get_visible_rect().size.y

	_check("Q8 the longest fits on the screen", fits)
	await _fresh()
	_check("Q9 a fresh life shows none of it", p.hud._death.shown() == 0.0 and not p.hud._death.visible)
	# A press in the words brings the page.
	await _fresh(true)
	var man := Node3D.new()
	add_child(man)
	p.health = 0.01
	p.take_damage(50.0, man)
	man.queue_free()
	await _frames(int(p.death.FALL_TAKES * 60.0) + 10)
	await _press("throw")
	await _frames(3)
	_check("Q10 a press in the words brings the page", p.hud.death_page.visible)
	p.hud.death_page.hide()


## What the deaths' review found.
func _review_of_the_deaths() -> void:
	# A copal line under way as you die: it never goes off, so what has you keeps you.
	await _fresh()
	p.loadout.locked = false
	p.loadout.items = [&"copal_line"] as Array[StringName]
	p.loadout.item_counts = {&"copal_line": 2}
	var one: CharacterBody3D = AnimaScript.new()
	one.form = &"hands"
	one.position = HOME + Vector3(0.8, 0.3, 0)
	add_child(one)
	await _frames(1)
	one.put_on_you()
	await _frames(2)
	p.loadout.use_item(0)
	_check("V0 the line is under way", p.loadout.is_using())
	p.health = 0.01
	p.drain_life(50.0)
	await _frames(60)
	_check("V1 an item in use as you die never goes off", not p.loadout.is_using() and p.loadout.item_counts[&"copal_line"] == 2 and p.leech.count() == 1)
	# Looking far up or down, you still go straight down, in the same place.
	await _fresh()
	p.neck.rotation.x = -1.0
	await _frames(2)
	var flat_at := Vector2(p.camera.global_position.x, p.camera.global_position.z)
	var eye: CharacterBody3D = EyeScript.new()
	eye.position = HOME + Vector3(0, 2, -40)
	add_child(eye)
	eye.sleep()
	p.health = 0.01
	p.take_damage(50.0, eye)
	await _until(func(): return not p.death.playing(), 5.0)
	await _frames(10)
	var moved: float = flat_at.distance_to(Vector2(p.camera.global_position.x, p.camera.global_position.z))
	_check("V2 looking far down as you die, you go straight down (%.2f m aside, %.2f up)" % [moved, p.camera.global_position.y], moved < 0.35 and p.camera.global_position.y < 0.5)
	# A face's second hand stays on you as you go.
	await _fresh()
	var face: CharacterBody3D = AnimaScript.new()
	face.form = &"face"
	face.position = HOME + Vector3(0.9, 0.3, -0.2)
	add_child(face)
	await _frames(1)
	face.put_on_you()
	await _frames(60)
	var second_was: bool = p.leech_hands.other_hand_shown()
	p.health = 0.01
	p.drain_life(50.0)
	await _frames(20)
	_check("V3 a face's second hand stays on you as you go", second_was and p.leech_hands.other_hand_shown())
	# Fed on, shaken off, then an eye: it isn't the drain that took you.
	await _dying_by(false, false, &"eye")
	p.hud._drain_magic = 0.1
	await _frames(40)
	_check("V4 killed by an eye, the flesh keeps its blood (%.2f)" % p.hud.curse_state()["drained"], p.hud.curse_state()["drained"] == 0.0)


func _heard() -> void:
	await _dying_by(false, false, &"eye")
	await _until(func(): return p.death.share() > 0.6, 3.0)
	var by_then: int = p.death.heartbeats
	await _until(func(): return p.hud.curse_state()["failing"] > 0.5, 2.0)
	var at_failing: int = p.death.heartbeats
	await _until(func(): return not p.death.playing(), 2.0)
	_check("H1 the heart races, and then it stops: no beat after it fails (%d, %d, %d)" % [by_then, at_failing, p.death.heartbeats], by_then >= 3 and p.death.heartbeats == at_failing)


func _on_you_now() -> CharacterBody3D:
	return p.leech.on_me()[0] if p.leech.count() > 0 else null


func _staying() -> void:
	const STATE: Dictionary = AnimaScript.State
	await _dying_by(false, true, &"guard")
	var taker: CharacterBody3D = _on_you_now()
	var power_was: float = p.power.power
	var gulps := [0]
	p.leech.gulped.connect(func(): gulps[0] += 1)
	await _frames(60)
	_check("L1 dead with one on you, it stays on you", p.leech.count() == 1 and taker.state == STATE.ON)
	await _frames(30)
	var slowing: float = p.death.gulps_slow()
	var rose: bool = await _until(func(): return p.leech.last_gulp() > 0.5, 2.0)
	_check("L2 it goes on gulping, slower as it goes (%d gulps, %.2f)" % [gulps[0], slowing], gulps[0] >= 2 and slowing > 1.5)
	_check("L3 a last long gulp before it lets go", rose and p.leech.count() == 1)
	await _until(func(): return p.leech.count() == 0, 2.0)
	_check("L4 at its moment it lets go and crawls off (%.2f s)" % p.death.at(), absf(p.death.at() - p.death.LETS_GO[&"animas"]) < 0.1 and taker.state == STATE.LEAVE)
	var from_you: float = taker.global_position.distance_to(p.global_position)
	await _frames(40)
	_check("L4b away from you, and not fast (%.2f)" % taker.velocity.length(), taker.global_position.distance_to(p.global_position) > from_you + 0.3 and taker.velocity.length() <= taker.LEAVE_SPEED + 0.01)
	_check("L6 it takes no power once you are dead", p.power.power == power_was)
	await _until(func(): return taker.state == STATE.REST, taker.LEAVE_TIME + 1.0)
	await _frames(int(taker.REST_LONGEST * 60.0) + 30)
	_check("L5 after a while it rests, and stays", taker.state == STATE.REST)
	# Awake and not on you.
	await _fresh()
	var circling: Array = []
	var swung := [0]

	for i in 2:
		var one: CharacterBody3D = AnimaScript.new()
		one.form = &"hands"
		one.position = HOME + Vector3(i * 2.0 - 1.0, 0.0, -1.0)
		one.swiped.connect(func(_hit): swung[0] += 1)
		add_child(one)
		circling.append(one)

	await _frames(2)
	circling[0].state = STATE.WIND_UP
	p.health = 0.01
	var man := Node3D.new()
	add_child(man)
	p.take_damage(50.0, man)
	man.queue_free()
	await _frames(3)
	_check("L7b the fall too: they crawl off", p.death.kind == &"fall" and circling.all(func(m): return m.state == STATE.LEAVE))
	await _frames(60)
	_check("L7 and no swing lands after", swung[0] == 0)
	# The last one killed while it finishes you.
	await _dying_by(false, true, &"guard")
	taker = _on_you_now()
	await _frames(30)
	taker.take_hit(9999.0, p, &"power", taker.global_position, Vector3.FORWARD)
	await _frames(10)
	_check("L8 the last feeder killed mid-death: it goes on without it", p.leech.count() == 0 and p.death.playing())
	await _until(func(): return not p.death.playing(), 4.0)
	_check("L8b and ends", not p.death.playing() and Sfx.drain_muffle == 0.0)


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
