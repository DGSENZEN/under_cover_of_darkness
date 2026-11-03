extends Node3D
## The elite mouth: hurt, it takes in the small ones, and each it takes makes it harder to kill and worse;
## at three its lunge kills you (docs/superpowers/specs/2026-11-03-elite-mouth-design.md).

const PLAYER := preload("res://Player.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const AnimaScript := preload("res://scripts/Monsters/Anima.gd")
const Bestiary := preload("res://scripts/Monsters/Bestiary.gd")
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
