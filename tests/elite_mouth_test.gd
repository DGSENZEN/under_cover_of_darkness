extends Node3D
## The elite mouth: hurt, it takes in the small ones, and each it takes makes it harder to kill and worse;
## at three its lunge kills you (docs/superpowers/specs/2026-11-03-elite-mouth-design.md).

const PLAYER := preload("res://Player.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const AnimaScript := preload("res://scripts/Monsters/Anima.gd")
const Bestiary := preload("res://scripts/Monsters/Bestiary.gd")
const CopalLine := preload("res://scripts/Hunt/CopalLine.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")
const STATE: Dictionary = AnimaScript.State
const HOME := Vector3(0, 1.05, 0)

var p: CharacterBody3D
var failed := 0
var _lost := 0.0


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
	await _it_grows()
	await _they_stay_near()
	await _it_feeds()
	await _at_three()
	await _in_the_world()
	await _heard_it()
	print("elite_mouth_test: %s" % ("all passed" if failed == 0 else "%d FAILED" % failed))
	get_tree().quit(1 if failed > 0 else 0)


## The elite, and what each it takes does to it.
func _it_grows() -> void:
	await _clean()
	var plain := _anima(&"torso", HOME + Vector3(5.0, -0.5, -12.0))
	var one := _elite(HOME + Vector3(-5.0, -0.5, -12.0))
	plain.leap_chance = 0.0
	one.leap_chance = 0.0
	await _frames(5)
	_check("E1 a plain torso is as it was", plain.hit_radius() == 0.95 and not plain.body.candles_lit() and plain.health == 130.0)
	_check("E1b you can tell one: lit, and bigger", one.body.candles_lit() and one.hit_radius() > plain.hit_radius() and one.body.mouth_size().x > plain.body.mouth_size().x)
	_check("E1b2 its own health", one.health == 240.0)
	one.health = 100.0
	var size_was: float = one.body.mouth_size().x
	var swipe_was: float = one.form_number("swipe_damage")
	var drain_was: float = one.drain_life()
	var speed_was: float = one.form_number("speed")
	var swipe_reach_was: float = one.form_number("swipe_reach")
	var leap_reach_was: float = one.form_number("leap_reach")
	var radius_was: float = one.hit_radius()
	one.take_in(&"face")
	_check("E1c it wins back 30%% of its most (%.0f)" % one.health, is_equal_approx(one.health, 100.0 + 240.0 * 0.3))
	await _frames(20)
	_check("E1d each one bigger (%.2f, %.2f), and it still stands on the floor (%.2f)" % [size_was, one.body.mouth_size().x, one.global_position.y], one.body.mouth_size().x > size_was * 1.08 and absf(one.global_position.y - 0.5) < 0.15)
	_check("E1d2 harder to miss", one.hit_radius() > radius_was)
	_check("E1f harder, slower, further", one.form_number("swipe_damage") > swipe_was and one.drain_life() > drain_was and one.form_number("speed") < speed_was and is_equal_approx(one.form_number("swipe_reach"), swipe_reach_was + 0.2) and is_equal_approx(one.form_number("leap_reach"), leap_reach_was + 0.3))
	one.health = 239.0
	one.take_in(&"hands")
	one.take_in(&"hands")
	one.take_in(&"face")
	await _frames(40)
	_check("E1g never above its most, never over three (%.0f, %d)" % [one.health, one.taken_count()], one.health <= 240.0 and one.taken_count() == 3)
	_check("E1h what it took stays, a face for a face, a hand for a hand", one.body.taken_shown(&"face") == 1 and one.body.taken_shown(&"hands") == 2)
	_check("E1i all three are up out of its skin", one.body.taken_up() == 3)
	await _until(func(): return one.body.arm_dug_in(0), 5.0)
	_check("E1e its hands still reach the ground (%.2f)" % one.body.fingertip_y(0), one.body.arm_dug_in(0) and one.body.fingertip_y(0) < 0.03)
	_check("E1j its arm still reaches back into it (%.3f)" % one.body.arm_end_gap(0), one.body.arm_end_gap(0) < 0.05)
	_check("E1k at three its lunge has room to happen", one.form_number("leap_reach") > one.form_number("swipe_reach") + 0.3)
	_free([plain, one])
	await _frames(3)


## The small ones stay near an elite, until you are near.
func _they_stay_near() -> void:
	await _clean()
	var one := _elite(HOME + Vector3(0.0, -0.5, -22.0))
	one.leap_chance = 0.0
	var small := _anima(&"hands", HOME + Vector3(5.0, -0.5, -22.0))
	await _frames(300)
	var off: float = small.global_position.distance_to(one.global_position)
	_check("E2 small ones wait round it, you far off (%.1f m)" % off, off < 4.0)
	_check("E2a and stay off you", small.global_position.distance_to(p.global_position) > 15.0)
	p.teleport(Transform3D(Basis.IDENTITY, small.global_position + Vector3(0.0, 0.55, 3.2)))
	var came := await _until(func(): return small.state in [STATE.TELL, STATE.WIND_UP, STATE.LEAP, STATE.ON], 6.0)
	_check("E2b you near, they come for you as ever", came)
	p.leech.free_all()
	p.teleport(Transform3D(Basis.IDENTITY, HOME))
	await _frames(60)
	var before: float = small.global_position.distance_to(one.global_position)
	await _frames(300)
	var after: float = small.global_position.distance_to(one.global_position)
	_check("E2c with nothing on you, they drift back (%.1f, %.1f)" % [before, after], after < 4.0)
	_free([one, small])
	await _frames(3)
	var alone := _anima(&"hands", HOME + Vector3(5.0, -0.5, -22.0))
	alone.leap_chance = 0.0
	await _until(func(): return alone.state == STATE.RUSH, 3.0)
	var was: float = alone.global_position.distance_to(p.global_position)
	await _frames(120)
	_check("E2d with no elite, nothing has changed", alone.global_position.distance_to(p.global_position) < was - 2.0)
	_free([alone])
	await _frames(3)


## What you hear of it, at the moment it happens: the mouth's, and the elite's.
func _heard_it() -> void:
	await _clean()
	var one := _elite(HOME + Vector3(0.0, -0.5, -6.0))
	one.leap_chance = 0.0
	await _frames(5)
	Sfx.recording = true
	var heard := func(what: Callable, sound: StringName) -> bool:
		Sfx.recorded.clear()
		what.call()
		return Sfx.recorded.any(func(entry): return entry[0] == sound)
	_check("E6 its ribs opening, for a lunge", heard.call(func(): one._enter(STATE.TELL), &"bone_crack"))
	_check("E6b or a rake", heard.call(func(): one._enter(STATE.WIND_UP), &"bone_crack"))
	_check("E6c snapping shut", heard.call(func(): one._enter(STATE.SWIPE), &"flesh"))
	_check("E6d closing on you", heard.call(func(): one.put_on_you(), &"flesh_heavy"))
	_check("E6e its ribs breaking", heard.call(func(): _hit(one, &"blow", &"blow"), &"bone_crack"))
	p.leech.free_all()
	_check("E6f seizing", heard.call(func(): one._enter(STATE.DRAG), &"whoosh_light"))
	_check("E6g taking one in", heard.call(func(): one.take_in(&"face"), &"flesh_heavy"))
	one.take_in(&"hands")
	_check("E6h full: you hear it", heard.call(func(): one.take_in(&"face"), &"anima_moan"))
	Sfx.recorded.clear()
	var dying: Node3D = one.body
	one.death_kind = 0
	one.health = 1.0
	_hit(one, &"bullet", &"copal")
	await _frames(60)
	_check("E6i its ribs bursting", Sfx.recorded.any(func(entry): return entry[0] == &"bone_crack"))
	Sfx.recording = false
	_free([one])
	if is_instance_valid(dying):
		dying.queue_free()
	await _frames(3)


## Left alone it reaches three; tended, it doesn't. It keeps what it took through a save, shows it in its cage, and gives it up as it dies.
func _in_the_world() -> void:
	var left: Array = await _hungry_at(120.0, [[&"hands", Vector3(2.0, 0.0, 0.0)], [&"face", Vector3(-2.0, 0.8, 0.0)], [&"hands", Vector3(0.0, 0.0, 2.2)]])
	var neglected: CharacterBody3D = left[0]

	for i in 1800:
		await get_tree().physics_frame
		neglected.health = minf(neglected.health, 120.0)

		if neglected.taken_count() >= 3:
			break

	_check("E5 left alone and hurt, it reaches three (%d)" % neglected.taken_count(), neglected.taken_count() == 3)
	_free(left)
	var kept: Array = await _hungry_at(120.0, [[&"hands", Vector3(2.0, 0.0, 0.0)], [&"face", Vector3(-2.0, 0.8, 0.0)]])
	var tended: CharacterBody3D = kept[0]

	for i in 1200:
		await get_tree().physics_frame

		if tended.state == STATE.DRAG:
			tended.health = 220.0
			_hit(tended, &"bullet", &"copal")

		tended.health = minf(tended.health, 120.0)

	_check("E5b stopped each time, it doesn't (%d)" % tended.taken_count(), tended.taken_count() == 0)
	_free(kept)
	# A save, mid-drag.
	var saving: Array = await _hungry_at(150.0, [[&"hands", Vector3(2.0, 0.0, 0.0)], [&"face", Vector3(-2.0, 0.8, 0.0)]])
	var saved_one: CharacterBody3D = saving[0]
	saved_one.take_in(&"face")
	saved_one.health = 150.0
	await _until(func(): return saved_one.state == STATE.DRAG, 8.0)
	var mouth_saved: Dictionary = saved_one.save_state()
	var small_saved: Dictionary = saved_one.prey().save_state()
	var loaded := _elite(HOME + Vector3(6.0, -0.5, -14.0))
	var small_loaded := _anima(&"hands", HOME + Vector3(8.0, -0.5, -14.0))
	await _frames(3)
	loaded.load_state(mouth_saved)
	small_loaded.load_state(small_saved)
	await _frames(5)
	_check("E5c saved mid-drag, loaded: no drag, the small one back, what it took stays", loaded.state != STATE.DRAG and not small_loaded.is_seized() and not small_loaded.dead and loaded.taken_count() == 1 and loaded.body.taken_shown(&"face") == 1)
	_check("E5c2 as big as it was", is_equal_approx(loaded.hit_radius(), saved_one.hit_radius()))
	_free(saving)
	_free([loaded, small_loaded])
	# In its cage.
	await _clean()
	var caged := _elite(HOME + Vector3(0.8, -0.5, -0.8))
	await _frames(2)
	caged.take_in(&"face")
	caged.take_in(&"face")
	caged.put_on_you()
	await _frames(40)
	var cage: Node3D = p.leech_hands.cage()
	var size: Vector2 = get_viewport().get_visible_rect().size
	var clear := true

	for i in 90:
		await get_tree().physics_frame
		clear = clear and cage.in_the_middle(size.x / size.y) == ""

	_check("E5d in its cage, a face for each it took (%d), and the middle clear" % cage.faces_shown(), cage.faces_shown() == 6 and clear)
	p.leech.free_all()
	_free([caged])
	await _frames(3)
	# Dying.
	await _clean()
	var dies := _elite(HOME + Vector3(0.0, -0.5, -6.0))
	dies.leap_chance = 0.0
	dies.death_kind = 0
	await _frames(5)
	dies.take_in(&"face")
	dies.take_in(&"hands")
	dies.take_in(&"face")
	await _frames(5)
	var dead_body: Node3D = dies.body
	_check("E5f its candles are lit till it dies", dead_body.candles_lit())
	dies.health = 1.0
	_hit(dies, &"bullet", &"copal")
	await _frames(100)
	_check("E5e dying, what it took comes out too (%d)" % dead_body.souls_apart(), dead_body.souls_apart() >= 11)
	await _until(func(): return not is_instance_valid(dead_body), 22.0)
	_check("E5g and all of it burns away", not is_instance_valid(dead_body))
	_free([dies])
	await _frames(3)


## At three you can see it, and it looks for no more.
func _at_three() -> void:
	await _clean()
	var full := _elite(HOME + Vector3(0.0, -0.5, -3.0))
	full.leap_chance = 0.0
	var small := _anima(&"hands", HOME + Vector3(2.0, -0.5, -3.0))
	small.leap_chance = 0.0
	small.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(2)

	for kind in [&"face", &"hands", &"hands"]:
		full.take_in(kind)

	_check("E4a it knows it is full", full.is_full())
	full.health = 40.0
	await _frames(240)
	var up := 0

	for n in full.body.presses_held():
		up += 1 if full.body.press_strength(n) > 0.4 else 0

	_check("E4 you can see it: all of them straining (%d of %d), hunger high (%.2f)" % [up, full.body.presses_held(), full.body.hunger()], up >= full.body.presses_held() - 1 and full.body.hunger() >= 0.6)
	_check("E4b full, it looks for no more", full.state != STATE.REACH and full.state != STATE.DRAG and full.prey() == null)
	full.global_position = HOME + Vector3(0.0, -0.5, -3.6)
	full.state = STATE.RUSH
	full.leap_chance = 1.0
	full._leap_in = 0.0
	await _until(func(): return full.state == STATE.TELL, 2.0)
	var told := 0

	while full.state == STATE.TELL and told < 100:
		await get_tree().physics_frame
		told += 1

	full.health = 240.0
	full.state = STATE.TELL
	full._state_t = 0.0
	_hit(full, &"bullet", &"copal")
	_check("E4c its tell is as long as ever (%d frames), and you can break it (state %d)" % [told, full.state], told >= 100 and full.state == STATE.THROWN)
	_free([full, small])
	await _frames(3)


## An elite, hurt enough to feed, and small ones by it, you far off.
func _hungry_at(health: float, smalls: Array) -> Array:
	await _clean()
	var one := _elite(HOME + Vector3(0.0, -0.5, -14.0))
	one.leap_chance = 0.0
	var made: Array = [one]

	for spot in smalls:
		var small := _anima(spot[0], one.position + spot[1])
		small.leap_chance = 0.0
		made.append(small)

	await _frames(3)
	one.health = health
	return made


func _it_feeds() -> void:
	# Whole, it fights on.
	var whole: Array = await _hungry_at(240.0, [[&"hands", Vector3(3.0, 0.0, 0.0)]])
	await _frames(120)
	_check("E3 whole, it doesn't look for one", whole[0].state != STATE.REACH and whole[0].prey() == null)
	_free(whole)
	# The nearest.
	var two: Array = await _hungry_at(150.0, [[&"hands", Vector3(4.6, 0.0, 0.0)], [&"face", Vector3(0.0, 0.8, 3.2)]])
	var one: CharacterBody3D = two[0]
	await _until(func(): return one.prey() != null, 3.0)
	_check("E3a below two-thirds it goes for the nearest", one.prey() != null and one.prey().global_position.distance_to(one.global_position) <= two[2].global_position.distance_to(one.global_position) + 0.01)
	var small: CharacterBody3D = one.prey()
	await _until(func(): return one.state == STATE.DRAG, 8.0)
	_check("E3j seized, the small one stops and thrashes", one.state == STATE.DRAG and small.is_seized())
	var at_start: float = small.global_position.distance_to(one.global_position)
	await _frames(35)
	_check("E3j2 and is dragged in (%.2f from %.2f)" % [small.global_position.distance_to(one.global_position), at_start], small.global_position.distance_to(one.global_position) < at_start - 0.4)
	var power_was: float = p.power.power
	var health_was: float = one.health
	await _until(func(): return one.state != STATE.DRAG, 3.0)
	_check("E3k taken in: gone as the dead are, no burn, no reward", small.dead and not small.visible and p.power.power == power_was and one.taken_count() == 1)
	_check("E3k2 and it gets its health (%.0f)" % one.health, one.health > health_was + 60.0 and one.prey() == null)
	_free(two)
	# Lead does nothing; anything else stops it, and pays.
	var stopped: Array = await _hungry_at(150.0, [[&"hands", Vector3(2.0, 0.0, 0.0)]])
	one = stopped[0]
	small = stopped[1]
	await _until(func(): return one.state == STATE.DRAG, 8.0)
	_hit(one, &"bullet", &"lead")
	_check("E3m lead changes nothing", one.state == STATE.DRAG and small.is_seized())
	p.power.power = 10.0
	one.health = 220.0
	var result: StringName = _hit(one, &"bullet", &"copal")
	_check("E3l another round: triple (%.0f), power back, stunned, and it lets go" % _lost, result == &"weak" and one.state == STATE.THROWN and _lost > 140.0 and p.power.power > 10.0)
	await _frames(2)
	_check("E3l2 the small one drops, alive", not small.is_seized() and not small.dead and one.taken_count() == 0)
	await _frames(40)
	_check("E3l3 and fights on", small.visible and small.state != STATE.THROWN or small.state == STATE.RUSH)
	_free(stopped)
	# Kill the small one.
	var killed: Array = await _hungry_at(150.0, [[&"hands", Vector3(2.0, 0.0, 0.0)]])
	one = killed[0]
	small = killed[1]
	await _until(func(): return one.state == STATE.DRAG, 8.0)
	small.health = 1.0
	_hit(small, &"bullet", &"copal")
	await _frames(3)
	_check("E3n kill the small one: it gets nothing", one.taken_count() == 0 and one.state != STATE.DRAG and one.prey() == null)
	_free(killed)
	# On the very tick it would have gone in.
	var just: Array = await _hungry_at(150.0, [[&"hands", Vector3(2.0, 0.0, 0.0)]])
	one = just[0]
	small = just[1]
	await _until(func(): return one.state == STATE.DRAG, 8.0)
	one._state_t = 99.0
	small.health = 1.0
	_hit(small, &"bullet", &"copal")
	await _frames(2)
	_check("E3b dying as it is taken: no heal, no growth, no error", one.taken_count() == 0 and one.health <= 150.0)
	_free(just)
	# The mouth dies, or sleeps, mid-drag.
	var dies: Array = await _hungry_at(150.0, [[&"hands", Vector3(2.0, 0.0, 0.0)]])
	one = dies[0]
	small = dies[1]
	await _until(func(): return one.state == STATE.DRAG, 8.0)
	one.health = 1.0
	_hit(one, &"bullet", &"copal")
	await _frames(3)
	_check("E3c the mouth dies mid-drag: the small one drops alive", not small.is_seized() and not small.dead)
	if is_instance_valid(one) and one.body != null:
		pass
	_free(dies)
	var sleeps: Array = await _hungry_at(150.0, [[&"hands", Vector3(2.0, 0.0, 0.0)]])
	one = sleeps[0]
	small = sleeps[1]
	await _until(func(): return one.state == STATE.DRAG, 8.0)
	one.sleep()
	await _frames(3)
	_check("E3c2 or sleeps: the same", not small.is_seized() and not small.dead)
	_free(sleeps)
	# Only from crawling, circling, backing off.
	var holding: Array = await _hungry_at(240.0, [[&"hands", Vector3(2.0, 0.0, 0.0)]])
	one = holding[0]
	one.global_position = HOME + Vector3(0.0, -0.5, -1.2)
	holding[1].global_position = HOME + Vector3(2.0, -0.5, -1.2)
	await _frames(1)
	one.put_on_you()
	one.health = 100.0
	await _frames(120)
	_check("E3g it never lets go of you to feed", one.state == STATE.ON and one.prey() == null)
	p.leech.free_all()
	_free(holding)
	var telling: Array = await _hungry_at(240.0, [[&"hands", Vector3(2.0, 0.0, 0.0)]])
	one = telling[0]
	one.state = STATE.TELL
	one._state_t = -9.0
	one.health = 100.0
	await _frames(120)
	_check("E3g2 nor from a lunge it is gathering", one.state == STATE.TELL and one.prey() == null)
	_free(telling)
	# Walled off, smoked.
	var walled: Array = await _hungry_at(150.0, [[&"hands", Vector3(3.2, 0.0, 0.0)]])
	one = walled[0]
	walled[1].process_mode = Node.PROCESS_MODE_DISABLED
	var wall: Node = Props.block(self, one.global_position + Vector3(1.6, 0.0, 0.0), Vector3(0.5, 3.0, 8.0))
	await _frames(120)
	_check("E3h a wall between: no", one.prey() == null and one.state != STATE.REACH)
	wall.free()
	_free(walled)
	var lined: Array = await _hungry_at(150.0, [[&"hands", Vector3(3.2, 0.0, 0.0)]])
	one = lined[0]
	lined[1].process_mode = Node.PROCESS_MODE_DISABLED
	var line: Node3D = CopalLine.lay(p, one.global_position + Vector3(1.6, -0.5, 0.0))
	await _frames(100)
	_check("E3h2 a copal line between: no", one.prey() == null and one.state != STATE.DRAG)
	line.queue_free()
	_free(lined)
	var smoked: Array = await _hungry_at(150.0, [[&"hands", Vector3(2.0, 0.0, 0.0)]])
	one = smoked[0]
	smoked[1].process_mode = Node.PROCESS_MODE_DISABLED
	one.statuses.apply(&"smoked", 20.0)
	await _frames(200)
	_check("E3i smoked, it can't seize", one.state != STATE.DRAG and one.taken_count() == 0)
	_free(smoked)
	# Gives up; and waits before trying again.
	var far_off: Array = await _hungry_at(150.0, [[&"hands", Vector3(5.2, 0.0, 0.0)]])
	one = far_off[0]
	far_off[1].process_mode = Node.PROCESS_MODE_DISABLED
	var pin: Vector3 = one.global_position
	var began := -1
	var ended := -1
	var again := -1

	for i in 1000:
		await get_tree().physics_frame
		one.global_position = pin

		if began < 0 and one.state == STATE.REACH:
			began = i
		elif began >= 0 and ended < 0 and one.state != STATE.REACH:
			ended = i
		elif ended >= 0 and again < 0 and one.state == STATE.REACH:
			again = i

	_check("E3p it gives up after 6 s if it can't get there (%d frames)" % (ended - began), began >= 0 and absi(ended - began - 360) < 8)
	_check("E3o and 6 s from one try to the next (%d frames)" % (again - began), again < 0 or again - began >= 354)
	_free(far_off)
	# Two elites; one on you.
	await _clean()
	var a := _elite(HOME + Vector3(-1.2, -0.5, -14.0))
	var b := _elite(HOME + Vector3(1.2, -0.5, -14.0))
	a.leap_chance = 0.0
	b.leap_chance = 0.0
	var between := _anima(&"hands", HOME + Vector3(0.0, -0.5, -12.0))
	between.leap_chance = 0.0
	await _frames(3)
	a.health = 100.0
	b.health = 100.0
	var shared := false

	for i in 60:
		await get_tree().physics_frame
		shared = shared or (a.prey() != null and a.prey() == b.prey())

	_check("E3e two elites: never one prey between them", not shared)
	_free([a, b, between])
	await _clean()
	var feeding := _elite(HOME + Vector3(0.0, -0.5, -3.0))
	feeding.leap_chance = 0.0
	var on_you := _anima(&"hands", HOME + Vector3(0.8, -0.5, -0.5))
	await _frames(1)
	on_you.put_on_you()
	feeding.health = 100.0
	await _frames(120)
	_check("E3f one on you is never taken off you", on_you.state == STATE.ON and feeding.prey() != on_you)
	p.leech.free_all()
	_free([feeding, on_you])
	await _frames(3)


func _clean() -> void:
	for action in ["move_left", "move_right", "move_forward", "move_back", "gun_dodge", "sprint"]:
		Input.action_release(action)

	for monster in get_tree().get_nodes_in_group(&"monsters"):
		monster.queue_free()

	p.health = 100.0
	p.teleport(Transform3D(Basis.IDENTITY, HOME))
	await _frames(20)


func _elite(at: Vector3) -> CharacterBody3D:
	var e: CharacterBody3D = AnimaScript.new()
	e.form = &"torso"
	e.elite = true
	e.position = at
	add_child(e)
	return e


func _anima(form: StringName, at: Vector3) -> CharacterBody3D:
	var e: CharacterBody3D = AnimaScript.new()
	e.form = form
	e.position = at
	add_child(e)
	return e


func _hit(e: Node, kind: StringName, round_id: StringName) -> StringName:
	var was: float = e.health
	e.round_hint = round_id
	var result: StringName = e.take_hit(50.0, p, kind, e.global_position, Vector3.FORWARD)
	_lost = was - e.health
	return result


func _free(list: Array) -> void:
	for e in list:
		if is_instance_valid(e):
			e.queue_free()


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
