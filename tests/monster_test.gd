extends Node3D
## The monster base: what each kind of hit does to it, and how the right
## answer pays you back. The real player and real shots.

const PLAYER := preload("res://Player.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const MonsterScript := preload("res://scripts/Monsters/Monster.gd")
const ShardScript := preload("res://scripts/Magic/Shard.gd")
const DummyScript := preload("res://scripts/Combat/TrainingDummy.gd")

var p: CharacterBody3D
var g: Node
var failed := 0
var last := &""
var confirmed := &""


func _ready() -> void:
	Props.block(self, Vector3(0, -0.5, 0), Vector3(120, 1, 120))
	p = PLAYER.instantiate()
	add_child(p)
	p.debug_traversal = false
	p.invulnerable = true
	p.reload_on_death = false
	p.position = Vector3(0, 1.05, 0)
	Props.give_revolver(p, 200, 40)
	p.inventory.select_by_id(&"revolver")
	await _frames(60)
	g = p.revolver
	g.hit_confirmed.connect(func(kind): confirmed = kind)
	await _hits()
	await _rounds()
	await _blows()
	await _forgiving()
	print("==== RESULTS ====")
	get_tree().quit(1 if failed > 0 else 0)


func _hits() -> void:
	# Spawned where the player stands and moved away: no ride on it.
	var under: CharacterBody3D = MonsterScript.new()
	under.kind = &"floating_eye"
	add_child(under)
	under.global_position = p.global_position
	await _frames(2)
	under.global_position = Vector3(0, 2, -5)
	await _frames(3)
	_check("M0 a monster spawned on the player doesn't lift or launch them (%.1f m/s)" % p.velocity.length(), p.velocity.length() < 1.0 and absf(p.global_position.y - 1.0) < 0.05)
	_free(under)

	var m := _monster()
	await _ball(m)
	_check("M1 a lead ball does 0.3 of its damage (%.1f)" % m.health, is_equal_approx(m.health, 120.0 - 55.0 * 0.3))
	_check("M2 a lead hit confirms resisted", confirmed == &"resisted" and last == &"resisted")

	m.health = 500.0
	p.power.pay(50.0)
	var before: float = p.power.power
	g.cylinder_round = &"copal"
	await _ball(m)
	_check("M3 a copal ball is weak: confirms weak, exposes", confirmed == &"weak" and m.is_exposed())
	_check("M4 a weak hit refunds 8 power", is_equal_approx(p.power.power, before + 8.0))
	_check("M3b a copal ball smokes it", m.statuses.has(&"smoked"))

	var was: float = m.health
	g.cylinder_round = &"lead"
	await _ball(m)
	_check("M6 a hit while exposed is doubled (%.1f)" % (was - m.health), is_equal_approx(was - m.health, 55.0 * 0.3 * 2.0))
	_free(m)

	m = _monster()
	m.health = 500.0
	await _frames(20)
	before = p.power.power
	await _shell(m)
	_check("M5 a whole shell refunds once", is_equal_approx(p.power.power, before + 8.0))
	_check("M5b a shell confirms weak", confirmed == &"weak")
	_free(m)

	m = _monster()
	m.health = 500.0
	var shard: Node3D = ShardScript.new()
	add_child(shard)
	var at: Transform3D = g.aim()
	shard.launch(at.origin, -at.basis.z * 70.0, 40.0, p)
	await _frames(12)
	_check("M7 a shard hit is weak (obsidian)", last == &"weak" and is_equal_approx(m.health, 500.0 - 60.0))
	_free(m)

	m = _monster()
	var deaths := [0]
	m.died.connect(func(_by): deaths[0] += 1)
	m.health = 1.0
	await _frames(20)
	before = p.power.power
	p.power.pay(30.0)
	before = p.power.power
	await _shell(m)
	_check("M9 pellets after the killing one return none: one death, one refund", deaths[0] == 1 and is_equal_approx(p.power.power, before + 8.0))
	_check("M4b a weak blow that kills refunds too", p.power.power > before)
	_check("M8 killed: it hides and its collider is off", not m.visible and m.dead and m.get_child(0).get("disabled") != false)
	_check("M8b hit again, dead, it returns none", m.take_hit(10.0, p, &"bullet", m.global_position, Vector3.FORWARD) == &"none")
	_free(m)

	m = _monster()
	m.health = 500.0
	var from: Vector3 = m.global_position
	g.cylinder_round = &"lead"
	await _ball(m, 20)
	var ball_push: float = from.distance_to(m.global_position)
	_free(m)
	m = _monster()
	m.health = 500.0
	from = m.global_position
	await _shell(m, 20)
	var shell_push: float = from.distance_to(m.global_position)
	_check("M11 a hit pushes it, a shell further than a ball (%.2f, %.2f)" % [ball_push, shell_push], ball_push > 0.05 and shell_push > ball_push)
	_free(m)

	m = _monster()
	m.health = 37.0
	m.statuses.apply(&"smoked", 3.0)
	var state: Dictionary = m.save_state()
	m.health = 60.0
	m.statuses.clear(&"smoked")
	m.load_state(state)
	_check("M12 save and load keep health and statuses", is_equal_approx(m.health, 37.0) and m.statuses.has(&"smoked"))
	m.take_hit(500.0, p, &"blast", m.global_position, Vector3.FORWARD)
	state = m.save_state()
	_free(m)
	m = _monster()
	m.load_state(state)
	_check("M12b a saved death comes back dead and hidden", m.dead and not m.visible)
	_free(m)

	m = _monster(Vector3(0, 1.0, -3.0))
	await _frames(2)
	p.teleport(Transform3D(Basis.IDENTITY, Vector3(0, 1.05, 0)))
	await _frames(5)
	Input.action_press("move_forward")
	await _frames(70)
	Input.action_release("move_forward")
	_check("M13 the player walks through it unblocked", p.global_position.z < -4.0)
	_free(m)

	p.statuses.apply(&"evil_eye", 5.0)
	var saved: Dictionary = p.save_state()
	p.statuses.clear(&"evil_eye")
	p.load_state(saved)
	_check("M14 the player's statuses are saved with them", p.statuses.has(&"evil_eye"))
	p.statuses.clear(&"evil_eye")


## A shot need not be exact: near enough to a monster counts.
func _forgiving() -> void:
	g.cylinder_round = &"lead"
	_face()
	await _frames(40)
	var at: Transform3D = g.aim()
	var ahead: Vector3 = at.origin - at.basis.z * 5.0
	var side: Vector3 = at.basis.x
	var m := _monster(ahead + side * 0.5)
	m.health = 500.0
	await _frames(2)
	await _shot_straight()
	_check("G1 a ball 0.2 m past its edge at 5 m still hits (%.0f)" % m.health, m.health < 500.0)
	_free(m)

	m = _monster(ahead + side * 0.75)
	m.health = 500.0
	await _frames(2)
	await _shot_straight()
	_check("G2 a ball well wide misses", is_equal_approx(m.health, 500.0))
	_free(m)

	# A wall between: it doesn't reach round it.
	var wall := Props.block(self, at.origin - at.basis.z * 3.0 + side * 0.5, Vector3(0.6, 3, 0.2))
	m = _monster(ahead + side * 0.5)
	m.health = 500.0
	await _frames(2)
	var through: Dictionary = g._trace(g.aim().origin, -g.aim().basis.z)
	_check("G3 near enough doesn't reach through a wall that is on the line", through["target"] == null or m.global_position.distance_to(through["point"]) > 1.0 or is_equal_approx(m.health, 500.0))
	wall.free()
	_free(m)

	m = _monster(ahead + side * 0.5)
	m.health = 500.0
	await _frames(2)
	var pellet: Dictionary = g._trace(g.aim().origin, -g.aim().basis.z, true)
	_check("G4 a pellet is forgiven less than a ball", pellet["target"] == null)
	m.sleep()
	await _frames(2)
	var asleep: Dictionary = g._trace(g.aim().origin, -g.aim().basis.z)
	_check("G6 nothing asleep is found", asleep["target"] == null)
	_free(m)

	var dummy: StaticBody3D = DummyScript.new()
	add_child(dummy)
	dummy.global_position = ahead + side * 0.55 - Vector3(0, 1.1, 0)
	await _frames(2)
	var man: Dictionary = g._trace(g.aim().origin, -g.aim().basis.z)
	_check("G5 what is no monster takes only an exact hit", man["target"] == null)
	dummy.queue_free()
	await _frames(1)

	# The Shard, near enough.
	m = _monster(ahead + side * 0.55)
	m.health = 500.0
	await _frames(2)
	var shard: Node3D = ShardScript.new()
	add_child(shard)
	shard.launch(at.origin, -at.basis.z * 70.0, 40.0, p)
	await _frames(12)
	_check("G7 a Shard near enough finds it (%.0f)" % m.health, m.health < 500.0)
	_free(m)


func _shot_straight() -> void:
	_face()
	await _frames(1)
	g.reset_for_practice()
	g._pull(g.weapon())
	await _frames(2)


func _blows() -> void:
	# At arm's length, with the gun: the butt.
	_face()
	await _frames(30)
	g.reset_for_practice()
	var m := _monster(Vector3.INF, 1.0)
	m.health = 500.0
	await _frames(2)
	Input.action_press("kick")
	await _frames(1)
	Input.action_release("kick")
	await _frames(25)
	_check("M15 the pistol-whip finds a monster at arm's length (%.0f)" % m.health, m.health < 500.0)
	_free(m)
	await _frames(40)

	m = _monster()
	m.health = 500.0
	var from: Vector3 = m.global_position
	m.kick(Vector3(0, 0, -6), p)
	await _frames(15)
	_check("M16 a boot hurts it and sends it off", m.health < 500.0 and m.global_position.distance_to(from) > 0.3)
	_check("M16b a boot counts as a blow", last == &"hit")
	_free(m)


## Task 7 adds to this.
func _rounds() -> void:
	var dummy: StaticBody3D = DummyScript.new()
	add_child(dummy)
	var kinds: Array = []
	dummy.struck.connect(func(_result, kind, _damage): kinds.append(kind))
	# (The load above put the gun away and brought it back.)
	_face()
	await _frames(60)
	var at: Transform3D = g.aim()
	dummy.global_position = at.origin - at.basis.z * 5.0 - Vector3(0, 1.1, 0)
	await _frames(2)
	g.reset_for_practice()
	g.cylinder_round = &"copal"
	g._pull(g.weapon())
	await _frames(2)
	_check("M10 a target that is no monster takes a copal round as a bullet (%s)" % [kinds], kinds == [&"bullet"])
	g.cylinder_round = &"lead"
	dummy.queue_free()
	await _switching()


func _switching() -> void:
	var inv: Node = p.inventory
	g.reset_for_practice()
	g.packed_rounds = [&"lead"] as Array[StringName]
	_check("R6 with only lead packed, T does nothing", not g.switch_round())
	g.packed_rounds = [&"lead", &"copal"] as Array[StringName]
	inv.ammo[&"copal_rounds"] = 12
	var lead_was: int = inv.ammo[&"rounds"]
	g.loaded[&"cylinder"] = 4
	Input.action_press("switch_round")
	await _frames(2)
	Input.action_release("switch_round")
	_check("R1 T switches to copal and starts a reload", g.cylinder_round == &"copal" and g.is_reloading())
	_check("R2 unfired lead goes back to its pouch", inv.ammo[&"rounds"] == lead_was + 4 and int(g.loaded[&"cylinder"]) == 0)
	await _frames(240)
	_check("R3 a reload takes from the round's own pouch", inv.ammo[&"copal_rounds"] == 6 and int(g.loaded[&"cylinder"]) == 6 and inv.ammo[&"rounds"] == lead_was + 4)
	_check("R3b stock_id follows the round", g.stock_id() == &"copal_rounds")

	# Mid-reload, back to lead: nothing lost in the count.
	g.loaded[&"cylinder"] = 2
	inv.ammo[&"copal_rounds"] = 10
	g._start_loading(g.weapon())
	await _frames(40)
	var total_before: int = int(inv.ammo[&"copal_rounds"]) + int(g.loaded[&"cylinder"])
	g.switch_round()
	_check("R5 switching mid-reload keeps what is loaded counted", int(inv.ammo[&"copal_rounds"]) == total_before and g.cylinder_round == &"lead")
	g._stop_loading()

	inv.ammo[&"copal_rounds"] = 0
	g.loaded[&"cylinder"] = 3
	var switched: bool = g.switch_round()
	_check("R4 an empty next pouch refuses, nothing moves", not switched and g.cylinder_round == &"lead" and int(g.loaded[&"cylinder"]) == 3)

	g.load_state({"loaded": {&"cylinder": 2, &"shot": 1}, "barrel": &"cylinder"})
	_check("R7 a save with no cylinder_round loads as lead", g.cylinder_round == &"lead")
	inv.ammo[&"copal_rounds"] = 6
	var kept: Dictionary = inv.save_state()
	inv.load_state(kept)
	_check("R9 stocks of every kind survive save and load", inv.ammo[&"copal_rounds"] == 6)
	kept["ammo"] = {"rounds": 3, "shells": 1}
	inv.load_state(kept)
	_check("R8 a save with no new stocks loads them empty", int(inv.ammo.get(&"copal_rounds", 0)) == 0 and inv.ammo[&"rounds"] == 3)
	g.cylinder_round = &"copal"
	var roundtrip: Dictionary = g.save_state()
	g.cylinder_round = &"lead"
	g.load_state(roundtrip)
	_check("R10 a save keeps the round", g.cylinder_round == &"copal")
	g.cylinder_round = &"lead"
	g.packed_rounds = [&"lead"] as Array[StringName]
	await _frames(40)


## A monster straight down the sights, `reach` metres off.
func _monster(at := Vector3.INF, reach := 5.0) -> CharacterBody3D:
	var m: CharacterBody3D = MonsterScript.new()
	m.kind = &"floating_eye"
	add_child(m)
	m.struck.connect(func(result, _source): last = result)
	_face()
	var aim_at: Transform3D = g.aim()
	m.global_position = at if at != Vector3.INF else aim_at.origin - aim_at.basis.z * reach
	return m


func _face() -> void:
	p.neck.rotation = Vector3.ZERO
	p.rotation = Vector3.ZERO


func _ball(m: CharacterBody3D, after := 2) -> void:
	_face()
	await _frames(1)
	m.global_position = g.aim().origin - g.aim().basis.z * 5.0
	g.reset_for_practice()
	g._pull(g.weapon())
	await _frames(after)


func _shell(m: CharacterBody3D, after := 2) -> void:
	_face()
	await _frames(1)
	m.global_position = g.aim().origin - g.aim().basis.z * 2.5
	g.reset_for_practice()
	g.barrel = &"shot"
	g._pull(g.weapon())
	await _frames(after)
	g.reset_for_practice()


func _free(m: Node) -> void:
	m.queue_free()
	await get_tree().process_frame


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(label: String, ok: bool) -> void:
	print(("PASS " if ok else "FAIL ") + label)

	if not ok:
		failed += 1
