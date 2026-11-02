extends Node3D
## The floating eye: packs that circle, tell and swoop, and a gaze that puts
## the evil eye on you. The real player.

const PLAYER := preload("res://Player.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const EyeScript := preload("res://scripts/Monsters/FloatingEye.gd")
const EyeGobScript := preload("res://scripts/Monsters/EyeGob.gd")
const AnimaScript := preload("res://scripts/Monsters/Anima.gd")
const WardScript := preload("res://scripts/Magic/Ward.gd")
const ShardScript := preload("res://scripts/Magic/Shard.gd")
const CopalCloud := preload("res://scripts/Monsters/CopalCloud.gd")
const Fx := preload("res://scripts/Visual/Fx.gd")
const HOME := Vector3(0, 1.05, 0)
const STATE := EyeScript.State

var p: CharacterBody3D
var failed := 0


func _ready() -> void:
	Props.block(self, Vector3(0, -0.5, 0), Vector3(200, 1, 200))
	# A wall to hide behind, away from where the rest happens.
	Props.block(self, Vector3(60, 3, 0), Vector3(1, 6, 12))
	_yard()
	p = PLAYER.instantiate()
	add_child(p)
	p.debug_traversal = false
	p.invulnerable = true
	p.reload_on_death = false
	p.position = HOME
	Props.give_revolver(p, 200, 40)
	p.inventory.select_by_id(&"revolver")
	await _frames(60)
	await _alive()
	await _turning()
	await _spitting()
	await _review_of_the_spit()
	await _noticing()
	await _attacks()
	await _gaze()
	await _deepening()
	await _smoke()
	await _stagger()
	await _answers()
	await _deaths()
	await _limpia()
	await _looks()
	await _curse_view()
	await _killing()
	await _long_run()
	await _dead_player()
	print("==== RESULTS ====")
	get_tree().quit(1 if failed > 0 else 0)


func _yard() -> void:
	# Walled yard for the long run, at x -100.
	for at in [[Vector3(-100, 3, -15.5), Vector3(32, 6, 1)], [Vector3(-100, 3, 15.5), Vector3(32, 6, 1)], [Vector3(-115.5, 3, 0), Vector3(1, 6, 32)], [Vector3(-84.5, 3, 0), Vector3(1, 6, 32)], [Vector3(-100, 2, -6), Vector3(1.4, 4, 1.4)], [Vector3(-94, 2, 5), Vector3(1.4, 4, 1.4)]]:
		Props.block(self, at[0], at[1])


func _noticing() -> void:
	await _place_player(Vector3(55, 1.05, 0))
	var e := _eye(Vector3(66, 2, 0), 1)
	await _frames(30)
	_check("E1b behind a wall it does not notice", e.state == STATE.DRIFT)
	_free(e)

	await _place_player(HOME)
	e = _eye(Vector3(0, 2, -30), 2)
	await _frames(30)
	_check("E1c out of reach it does not notice", e.state == STATE.DRIFT)
	e.global_position = Vector3(0, 2, -12)
	await _frames(30)
	_check("E1 it notices within 18 m with a clear line", e.state != STATE.DRIFT)

	e.next_swoop_in = 100.0
	await _frames(180)
	var reach: float = Vector2(e.global_position.x, e.global_position.z).length()
	var over: float = e.global_position.y - (p.global_position.y - 1.0)
	_check("E2 it circles at its radius and height (%.1f m out, %.1f m up)" % [reach, over], reach >= 5.0 and reach <= 10.0 and over >= 1.3 and over <= 3.3)
	var at: Vector3 = e.global_position
	await _frames(30)
	_check("E2b it keeps moving", e.global_position.distance_to(at) > 0.5)
	_free(e)


func _attacks() -> void:
	await _place_player(HOME)
	p.invulnerable = false
	p.health = p.max_health
	var e := _eye(Vector3(0, 2, -7), 3)
	e.next_swoop_in = 0.1
	var tell := await _time_in(e, STATE.TELL)
	_check("E3 it tells for 0.5 s before a swoop (%.2f)" % tell, absf(tell - 0.5) < 0.04)
	var bitten := await _until(func(): return p.health < p.max_health, 2.0)
	_check("E4 standing still, the swoop bites for 12 (%.1f)" % (p.max_health - p.health), bitten and is_equal_approx(p.max_health - p.health, 12.0))
	await _frames(10)
	_check("E4b once a swoop", is_equal_approx(p.max_health - p.health, 12.0))
	await _until(func(): return e.state == STATE.BOUNCE, 1.0)
	_check("E4c then it bounces", e.state == STATE.BOUNCE)
	_free(e)

	await _place_player(HOME)
	p.health = p.max_health
	e = _eye(Vector3(0, 2, -7), 4)
	e.next_swoop_in = 0.1
	await _until(func(): return e.state == STATE.TELL, 2.0)
	await _frames(23)
	Input.action_press("move_right")
	await _press("gun_dodge")
	await _frames(10)
	Input.action_release("move_right")
	await _until(func(): return e.state == STATE.BOUNCE, 3.0)
	_check("E5 a dodge in the tell makes it miss, and it bounces", p.health == p.max_health and e.state == STATE.BOUNCE)
	_free(e)
	p.invulnerable = true

	await _place_player(HOME)
	var pack: Array = []

	for i in 5:
		pack.append(_eye(Vector3(cos(i * 1.25) * 7.0, 2, sin(i * 1.25) * 7.0), 10 + i))

	for e2 in pack:
		e2.next_swoop_in = 0.05

	var most := 0

	for i in 240:
		await get_tree().physics_frame
		most = maxi(most, pack.filter(func(x): return x.state == STATE.TELL or x.state == STATE.SWOOP).size())

	_check("E6 at most 2 of 5 swoop at once (%d)" % most, most <= 2 and most >= 1)

	for e2 in pack:
		_free(e2)


func _gaze() -> void:
	await _place_player(HOME)
	p.statuses.clear(&"evil_eye")
	p.statuses.forget_stare()
	var e := _eye(Vector3(0, 2, -7), 5)
	e.next_swoop_in = 100.0
	await _frames(100)
	_check("E7a not at once", not p.statuses.has(&"evil_eye"))
	await _until(func(): return p.statuses.has(&"evil_eye"), 2.0)
	_check("E7 2 s of gaze puts the evil eye on you", p.statuses.has(&"evil_eye"))
	await _frames(2)
	_check("E9 evil eye: magic refills slower", p.power.refill_scale < 1.0)
	_check("E9b view unsteady", p.juice.unsteady() > 0.0)
	p.revolver.aimed = true
	var straight: Basis = Basis.IDENTITY
	_check("E9c even aimed, the aim strays", p.revolver._stray(straight).dot(-straight.z) < 0.99999)
	p.revolver.aimed = false
	p.loadout.pack_item(&"egg")
	p.loadout.item_counts[&"egg"] = 1
	p.loadout.use_item()
	await _frames(68)
	_check("E10 the egg takes it off", not p.statuses.has(&"evil_eye"))
	await _frames(2)
	_check("E9d all of it ends with it", is_equal_approx(p.power.refill_scale, 1.0) and p.juice.unsteady() == 0.0)
	p.loadout.unpack_item(&"egg")
	_free(e)

	await _place_player(Vector3(55, 1.05, 0))
	p.statuses.clear(&"evil_eye")
	e = _eye(Vector3(66, 2, 0), 6)
	await _frames(150)
	_check("E8 out of its line, no gaze", not p.statuses.has(&"evil_eye"))
	_free(e)


func _deepening() -> void:
	var c: Node = p.curse
	p.statuses.clear(&"evil_eye")
	p.statuses.clear(&"cleansed")
	await _frames(2)
	_check("D0 nothing on you: nothing costs you", c.depth() == 0 and is_equal_approx(p.power.refill_scale, 1.0) and is_equal_approx(p.combat.stamina_regen_scale, 1.0) and is_equal_approx(c.speed(), 1.0))
	p.statuses.apply(&"evil_eye", 8.0)
	await _frames(2)
	_check("D1 it starts with one eye (%d)" % c.depth(), c.depth() == 1)
	var first := {"magic": p.power.refill_scale, "stamina": p.combat.stamina_regen_scale, "speed": c.speed(), "stray": c.stray()}
	_check("D2 and one eye already costs you magic, stamina and pace", first["magic"] < 1.0 and first["stamina"] < 1.0 and first["speed"] < 1.0)

	# Still hunted: it deepens with time alone.
	var waited := 0
	while c.depth() < 2 and waited < 600:
		p.statuses.stare(0.0001, 100.0)
		await _frames(1)
		waited += 1
	_check("D3 hunted, a second eye opens in time (%.1f s)" % (waited / 60.0), c.depth() == 2 and waited > 360)
	await _frames(25)
	_check("D3b it opens in your view (%d)" % p.hud.curse_state()["ring_open"], p.hud.curse_state()["ring_open"] == 2)

	while c.depth() < 6:
		c.deepen()
	await _frames(2)
	_check("D4 six eyes: all of it far worse", p.power.refill_scale < first["magic"] * 0.5 and p.combat.stamina_regen_scale < first["stamina"] * 0.5 and c.speed() < first["speed"] - 0.1 and c.stray() > first["stray"] * 2.0)
	_check("D4b worst of all, you can still sprint fast enough to slide", p.sprint_speed * c.speed() >= p.SLIDE_MIN_SPEED)
	c.deepen()
	_check("D4c six is the most", c.depth() == 6)
	await _frames(40)
	_check("D4d and all six are open (%d)" % p.hud.curse_state()["ring_open"], p.hud.curse_state()["ring_open"] == 6)

	# Out of every eye's sight: they close, one at a time, and then it is gone.
	p.statuses._stare_ago = 100.0
	var deep_was: int = c.depth()
	await _frames(int(c.EBB_EVERY * 60.0) + 12)
	_check("D5 nobody looking, an eye closes (%d)" % c.depth(), c.depth() == deep_was - 1)
	_check("D5b and what it cost eases with it", p.power.refill_scale > 0.2 and p.statuses.has(&"evil_eye"))
	p.statuses._left[&"evil_eye"] = 0.1
	await _frames(12)
	_check("D6 the last closed, it is off you and costs nothing", not p.statuses.has(&"evil_eye") and c.depth() == 0 and is_equal_approx(p.combat.stamina_regen_scale, 1.0))

	# It is not forgotten that an eye is watching: a stare drives it deeper.
	await _place_player(HOME)
	p.statuses.apply(&"evil_eye", 8.0)
	p.statuses.forget_stare()
	p.statuses._stare_ago = 100.0
	var one := _eye(Vector3(0, 2, -7), 5)
	one.next_swoop_in = 100.0
	await _until(func(): return one.gazing, 3.0)
	var deepened := await _until(func(): return c.depth() >= 2, 6.5)
	_check("D7 an eye watching you drives the curse deeper, sooner than time alone", deepened)
	_free(one)
	p.statuses.clear(&"evil_eye")
	await _frames(2)

	# Saved and loaded, it is as deep as it was.
	p.statuses.apply(&"evil_eye", 20.0)
	c.deepen()
	c.deepen()
	var saved: Dictionary = p.statuses.save_state()
	p.statuses.clear(&"evil_eye")
	p.statuses.load_state(saved)
	_check("D8 a save keeps how deep it is (%d)" % c.depth(), c.depth() == 3)
	p.statuses.clear(&"evil_eye")
	await _frames(2)


func _smoke() -> void:
	await _place_player(HOME)
	p.statuses.clear(&"evil_eye")
	var e := _eye(Vector3(0, 2, -7), 7)
	e.next_swoop_in = 0.0
	e.statuses.apply(&"smoked", 4.0)
	var swooped := [false]
	var fastest := 0.0

	for i in 180:
		await get_tree().physics_frame
		swooped[0] = swooped[0] or e.state == STATE.TELL or e.state == STATE.SWOOP
		fastest = maxf(fastest, e.velocity.length())

	_check("E11 smoked: no swoop", not swooped[0])
	_check("E11b smoked: no gaze", not p.statuses.has(&"evil_eye"))
	_check("E11c smoked: slower (%.1f m/s)" % fastest, fastest <= EyeScript.CIRCLE_SPEED * 0.61 and fastest > 0.5)
	_free(e)


func _stagger() -> void:
	await _place_player(HOME)
	var e := _eye(Vector3(0, 2, -7), 21)
	e.next_swoop_in = 100.0
	e.health = 500.0
	await _frames(30)
	var starts := [0]
	var was: int = e.state
	var fastest_after := 0.0
	var nearest: float = e.global_position.distance_to(p.global_position)
	var then: float = nearest
	e.round_hint = &"copal"
	e.take_hit(55.0, p, &"bullet", e.global_position, Vector3.FORWARD)

	for i in 100:
		await get_tree().physics_frame

		if e.state == STATE.BOUNCE and was != STATE.BOUNCE:
			starts[0] += 1

		if i < 18:
			nearest = minf(nearest, e.global_position.distance_to(p.global_position))

		if was == STATE.BOUNCE and e.state == STATE.CIRCLE:
			fastest_after = e.velocity.length()

		was = e.state

	_check("E17 a weak hit staggers it once (%d)" % starts[0], starts[0] <= 1 and e.state == STATE.CIRCLE)
	_check("E18 staggered, it goes away from you, not at you", nearest >= then - 0.05)
	_check("E19 no jerk as the stagger ends (%.1f m/s)" % fastest_after, fastest_after <= EyeScript.CIRCLE_SPEED + 0.5)
	_free(e)


func _answers() -> void:
	# The tell: any hit.
	await _place_player(HOME)
	var e := _eye(Vector3(0, 2, -7), 22)
	e.next_swoop_in = 0.05
	p.power.pay(40.0)
	await _until(func(): return e.state == STATE.TELL, 2.0)
	var power_was: float = p.power.power
	var result: StringName = e.take_hit(55.0, p, &"bullet", e.global_position, Vector3.FORWARD)
	_check("A1 a hit in the tell is weak, whatever the round", result == &"weak")
	_check("A1b it does three times the damage (%.1f)" % (120.0 - e.health), is_equal_approx(120.0 - e.health, 55.0 * 0.3 * 3.0))
	_check("A1c it interrupts the swoop and exposes it", e.state == STATE.BOUNCE and e.is_exposed())
	_check("A1d and pays back power", p.power.power > power_was)
	_free(e)

	# The swoop: the whip, on the real key.
	await _place_player(HOME)
	p.health = p.max_health
	p.invulnerable = false
	p.revolver.reset_for_practice()
	e = _eye(Vector3(0, 2, -7), 23)
	e.next_swoop_in = 0.05
	await _until(func(): return e.state == STATE.SWOOP, 2.0)
	await _until(func(): return e.global_position.distance_to(p.global_position) < 3.0, 1.0)
	await _face(e)
	await _press("kick")
	await _until(func(): return e.state == STATE.BATTED, 0.5)
	_check("A3 a swoop can be whipped at 3 m, and is batted", e.state == STATE.BATTED)
	_check("A3b it never bit you", p.health == p.max_health)
	await _frames(6)
	_check("A3c it goes back the way you hit it", e.velocity.dot(-p.global_basis.z) > 8.0)
	p.invulnerable = true
	_free(e)

	# Batted into another.
	await _place_player(HOME)
	var bat := _eye(Vector3(0, 2, -6), 24)
	var other := _eye(Vector3(0, 2, -9), 25)
	other.next_swoop_in = 100.0
	bat.state = STATE.SWOOP
	var other_was: float = other.health
	bat.kick(Vector3(0, 0, -6), p)
	await _until(func(): return other.health < other_was, 1.0)
	_check("A4 a batted eye hurts and exposes what it hits", other.health < other_was and other.is_exposed())
	_check("A4b and stops there", bat.state == STATE.BOUNCE)
	_free(bat)
	_free(other)

	# Batted into a wall.
	await _place_player(Vector3(55, 1.05, 0))
	bat = _eye(Vector3(57.5, 2, 0), 26)
	var was_full: float = bat.health
	bat.state = STATE.SWOOP
	bat.kick(Vector3(6, 0, 0), p)
	await _until(func(): return bat.state == STATE.BOUNCE, 1.0)
	_check("A5 a wall hurts it more than the blow did", was_full - bat.health > 20.0 and bat.state == STATE.BOUNCE)
	_free(bat)

	# The Ward: it cannot see you.
	await _place_player(HOME)
	p.statuses.clear(&"evil_eye")
	p.statuses.forget_stare()
	e = _eye(Vector3(0, 2, -7), 27)
	e.state = STATE.CIRCLE
	e.next_swoop_in = 0.1
	var ward: Node3D = WardScript.cast_on(p)
	var swooped := false

	for i in 180:
		await get_tree().physics_frame
		swooped = swooped or e.state == STATE.TELL or e.state == STATE.SWOOP

	_check("A6 behind the Ward, no gaze and no swoop", not p.statuses.has(&"evil_eye") and not swooped)
	ward.queue_free()
	await _frames(2)
	_free(e)

	await _place_player(HOME)
	e = _eye(Vector3(0, 2, -7), 28)
	e.next_swoop_in = 0.05
	await _until(func(): return e.state == STATE.SWOOP, 2.0)
	ward = WardScript.cast_on(p)
	await _until(func(): return e.state == STATE.BOUNCE, 1.0)
	_check("A7 swooping into the Ward, it is smoked and bounces", e.state == STATE.BOUNCE and e.statuses.has(&"smoked"))
	ward.queue_free()
	await _frames(2)
	_free(e)

	# The copal round's cloud.
	await _place_player(HOME)
	var hit_one := _eye(Vector3(0, 8, -30), 29)
	var near := _eye(Vector3(2, 8, -30), 30)
	var far := _eye(Vector3(9, 8, -30), 31)

	hit_one.round_hint = &"copal"
	hit_one.take_hit(55.0, p, &"bullet", hit_one.global_position, Vector3.FORWARD)
	await _frames(3)
	_check("A8 a copal hit leaves a cloud that smokes what is near", near.statuses.has(&"smoked"))
	_check("A8b not what is far", not far.statuses.has(&"smoked"))
	var clouds := get_tree().get_nodes_in_group(&"copal_clouds")
	_check("A8c there is a cloud to see", clouds.size() == 1)
	await _frames(int(CopalCloud.LASTS * 60.0) + 10)
	_check("A8d and it goes", get_tree().get_nodes_in_group(&"copal_clouds").is_empty())

	for one in [hit_one, near, far]:
		_free(one)

	# The Shard, through a line.
	await _place_player(HOME)
	p.neck.rotation = Vector3.ZERO
	p.rotation = Vector3.ZERO
	await _frames(2)
	var from: Vector3 = p.revolver.aim().origin
	var line: Array = []

	for i in 4:
		var in_line := _eye(from + Vector3(0, 0, -4.0 - i * 2.0), 40 + i)
		in_line.health = 500.0
		in_line.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
		in_line.process_mode = Node.PROCESS_MODE_DISABLED
		line.append(in_line)

	await _frames(2)
	var shard: Node3D = ShardScript.new()
	add_child(shard)
	shard.launch(from, Vector3(0, 0, -70.0), 40.0, p)
	await _frames(20)
	_check("A9 a Shard goes through two monsters into a third", line[0].health < 500.0 and line[1].health < 500.0 and line[2].health < 500.0)
	_check("A9b and no further", is_equal_approx(line[3].health, 500.0))

	for one in line:
		_free(one)


func _deaths() -> void:
	await _place_player(HOME)
	var e := _eye(Vector3(0, 3, -10), 50)
	var near := _eye(Vector3(5, 3, -10), 51)
	var far := _eye(Vector3(0, 3, -40), 52)
	near.next_swoop_in = 5.0
	far.next_swoop_in = 5.0
	await _frames(12)
	var wait_was: float = near.next_swoop_in
	var far_wait: float = far.next_swoop_in
	var trauma_was: float = p.juice._trauma
	var stains_was: int = Fx.stains_in_use()
	var radius_was: float = near.circle_radius()
	e.take_hit(5000.0, p, &"blast", e.global_position, Vector3.FORWARD)
	_check("D5 a kill jolts the view", p.juice._trauma > trauma_was)
	var remains := get_tree().get_nodes_in_group(&"remains")
	_check("D1 it leaves a body", remains.size() == 1)
	_check("D4 the pack within reach flinches, and waits longer", near.next_swoop_in >= wait_was + 1.4 and near.flinching())
	_check("D4b those far off don't", not far.flinching() and far.next_swoop_in <= far_wait)
	_check("D8 flinching, it pulls further out", near.circle_radius() >= radius_was + 1.9)
	var body: Node3D = remains[0]
	var height: float = body.global_position.y
	await _frames(70)
	_check("D2 the body falls", is_instance_valid(body) and body.global_position.y < height - 1.0)
	_check("D3 and it has landed, which leaves its stain", body.get("_landed") == true and stains_was >= 0)
	await _frames(140)
	_check("D8b the flinch passes", not near.flinching() and is_equal_approx(near.circle_radius(), radius_was))
	await _frames(300)
	_check("D7 the body goes in time", get_tree().get_nodes_in_group(&"remains").is_empty())
	_free(e)
	_free(near)
	_free(far)

	# A flinch breaks a tell.
	await _place_player(HOME)
	var tell := _eye(Vector3(0, 2, -7), 53)
	tell.next_swoop_in = 0.05
	await _until(func(): return tell.state == STATE.TELL, 2.0)
	tell.flinch()
	_check("D9 a flinch breaks off a tell", tell.state != STATE.TELL)
	_free(tell)

	# Power back shows.
	var cross: Control = p.hud.get("_crosshair")
	p.power.pay(30.0)
	p.power.refund(8.0)
	await _frames(2)
	_check("D6 power coming back flashes the arc", cross.power_gain_flash > 0.0)


func _limpia() -> void:
	await _place_player(Vector3(55, 1.05, 0))
	p.invulnerable = false
	p.health = p.max_health
	p.statuses.clear(&"evil_eye")
	p.statuses.forget_stare()
	var lo: Node = p.loadout
	lo.pack_item(&"egg")
	lo.item_counts[&"egg"] = 2
	var seen := _eye(Vector3(55, 2, -7), 60)
	var also := _eye(Vector3(50, 2, -6), 61)
	var hidden := _eye(Vector3(66, 2, 0), 62)
	var distant := _eye(Vector3(55, 2, -30), 63)

	for e in [seen, also]:
		e.state = STATE.CIRCLE
		e.next_swoop_in = 100.0

	await _frames(14)
	_check("EG8 two eyes on you and an egg: it is offered, uncursed", lo.can_offer())
	await _press("use_item")
	await _frames(1)
	_check("EG1 uncursed, with eyes on you, the egg can be used", lo.is_using())
	await _frames(25)
	_check("EG2a nothing happens until it is done", seen.state != STATE.DAZED)
	await _frames(41)
	var at_shut: Vector3 = seen.global_position
	var flushed: bool = seen.body.hurt > 0.5
	await _frames(1)
	_check("EG2 what can see you squeezes shut", seen.state == STATE.DAZED and also.state == STATE.DAZED and seen.is_exposed())
	_check("EG2b what can't see you or is too far doesn't", hidden.state != STATE.DAZED and distant.state != STATE.DAZED)
	await _frames(10)
	var flung: float = at_shut.distance_to(seen.global_position)
	_check("EG9 it spends one", lo.item_counts[&"egg"] == 1)
	_check("EG6 you are cleansed", p.statuses.has(&"cleansed"))
	var was: float = seen.health
	var result: StringName = seen.take_hit(55.0, p, &"bullet", seen.global_position, Vector3.FORWARD)
	_check("EG4 a lead ball on a shut eye is weak, six times over (%.0f)" % (was - seen.health), result == &"weak" and is_equal_approx(was - seen.health, 55.0 * 0.3 * 3.0 * 2.0))
	_check("EG5 and doesn't wake it", seen.state == STATE.DAZED)
	var height: float = also.global_position.y
	var bit := false

	for i in 100:
		await get_tree().physics_frame
		bit = bit or also.state == STATE.TELL or also.state == STATE.SWOOP

	_check("EG3 shut, it sinks and doesn't attack", not bit and also.global_position.y < height)
	_check("EG3c at 2.5 s it is still shut: it lasts", also.state == STATE.DAZED and EyeScript.DAZED_TIME >= 4.0)
	await _frames(int((EyeScript.DAZED_TIME - 1.6) * 60.0) + 10)
	_check("EG10 sent back, it was flung off you and flushed", flung > 0.2 and flushed)
	_check("EG3b in its own time it opens again", also.state == STATE.CIRCLE)
	await _frames(100)
	_check("EG6b cleansed, no gaze sticks", not p.statuses.has(&"evil_eye"))
	p.statuses.clear(&"cleansed")

	for e in [seen, also, hidden, distant]:
		_free(e)

	await _place_player(HOME)
	lo.item_counts[&"egg"] = 1
	var one := _eye(Vector3(0, 2, -7), 64)
	one.state = STATE.CIRCLE
	one.next_swoop_in = 100.0
	await _frames(14)
	_check("EG8b one eye and no curse: not offered, though it would work", not lo.can_offer())
	p.statuses.apply(&"evil_eye", 8.0)
	_check("EG7 the curse on you: offered", lo.can_offer())
	await _press("use_item")
	await _frames(68)
	_check("EG7b and the egg lifts it", not p.statuses.has(&"evil_eye"))
	p.statuses.clear(&"cleansed")
	lo.unpack_item(&"egg")
	p.invulnerable = true
	_free(one)


func _looks() -> void:
	await _place_player(HOME)
	p.invulnerable = true
	var e := _eye(Vector3(0, 2, -8), 70)
	e.next_swoop_in = 100.0
	e.state = STATE.CIRCLE
	await _frames(40)
	var body: Node3D = e.body
	_check("V1 it wears its model", body.part(&"Ball") != null and body.part(&"LidTop") != null and body.part(&"Flesh") != null)
	var painted := true

	for id in [&"Flesh", &"Frame", &"LidTop", &"Nerve", &"Spines"]:
		var colours: PackedColorArray = body.part(id).mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
		painted = painted and not colours.is_empty() and Array(colours).any(func(c): return c.r < 0.9)

	_check("V1b its vertex paint reached the game", painted)
	var to_you: Vector3 = (p.camera.global_position - body.part(&"Ball").global_position).normalized()
	_check("V4 the ball looks at you", (-body.part(&"Ball").global_basis.z).dot(to_you) > 0.93)
	var was: Vector3 = -body.part(&"Ball").global_basis.z
	var moved := 0.0
	var blinked := false

	for i in 480:
		await get_tree().physics_frame
		e.next_swoop_in = 100.0
		var now: Vector3 = -body.part(&"Ball").global_basis.z
		moved = maxf(moved, rad_to_deg(now.angle_to(was)))
		was = now
		blinked = blinked or body.lids > 0.8

	_check("V5 it twitches as it looks (%.1f deg in a tick)" % moved, moved > 0.8)
	_check("V9 it blinks", blinked)
	_free(e)

	await _place_player(HOME)
	e = _eye(Vector3(0, 2, -7), 71)
	e.next_swoop_in = 0.05
	await _until(func(): return e.state == STATE.TELL, 2.0)
	body = e.body
	await _frames(22)
	_check("V2 the tell: pupil blown, lids back, blood up (%.2f, %.2f, %.2f)" % [body.pupil, body.lids, body.rage], body.pupil > 1.5 and body.lids < 0.0 and body.rage > 0.6)
	await _until(func(): return e.state == STATE.SWOOP, 1.0)
	await _frames(6)
	_check("V3 the swoop: pupil pinned, lids narrowed, the nerve streams (%.2f, %.2f, %.2f)" % [body.pupil, body.lids, body.sway.length()], body.pupil < 0.85 and body.lids > 0.2 and body.sway.length() > 0.1)
	_free(e)

	await _place_player(HOME)
	e = _eye(Vector3(0, 2, -7), 72)
	e.next_swoop_in = 100.0
	e.state = STATE.CIRCLE
	await _frames(20)
	body = e.body
	e.take_hit(10.0, p, &"bullet", e.global_position, Vector3.FORWARD)
	await _frames(2)
	_check("V6 a hit: it winces and flushes", body.hurt > 0.5 and body.lids > 0.2)
	await _frames(40)
	_check("V6b and the flush goes, leaving it the worse for wear", body.hurt < 0.1 and body.wounds > 0.0)
	e.limpia(p)
	await _frames(12)
	_check("V7 shut by the egg, shut", body.lids > 0.95)
	var tears_was: int = body.tears
	await _frames(90)
	_check("V7b and it weeps blood (%d)" % (body.tears - tears_was), body.tears - tears_was >= 3)
	e.take_hit(5000.0, p, &"blast", e.global_position, Vector3.FORWARD)
	await _frames(2)
	_check("V8 dead, the ball is gone from what falls", not body.part(&"Ball").visible and get_tree().get_nodes_in_group(&"remains").size() == 1)
	_check("V8b and chunks fly (%d)" % get_tree().get_nodes_in_group(&"gibs").size(), get_tree().get_nodes_in_group(&"gibs").size() >= 5)
	await _frames(530)
	_check("V8c all gone in time", get_tree().get_nodes_in_group(&"remains").is_empty() and get_tree().get_nodes_in_group(&"gibs").is_empty())
	_free(e)


## The screen says what the evil eye is doing.
func _curse_view() -> void:
	await _place_player(HOME)
	p.neck.rotation = Vector3.ZERO
	p.rotation = Vector3.ZERO
	p.statuses.clear(&"evil_eye")
	p.statuses.clear(&"cleansed")
	p.statuses.forget_stare()
	var hud: Node = p.hud
	var cross: Control = hud.get("_crosshair")
	await _frames(60)
	_check("C0 nothing on you, nothing shown", not hud.curse_view_shown())
	var e := _eye(Vector3(5, 2, -6), 80)
	e.state = STATE.CIRCLE
	e.next_swoop_in = 100.0
	await _frames(40)
	var state: Dictionary = hud.curse_state()
	_check("C1 stared at, the warning builds before any curse (%.2f)" % state["stared"], state["stared"] > 0.1 and not p.statuses.has(&"evil_eye") and hud.curse_view_shown())
	_check("C2 a painted eye opens on the side it is looking from (%s)" % [state["gazers"]], state["gazers"].size() == 1 and state["gazers"][0].x > 0.5 and state["gazers"][0].z > 0.1)
	_free(e)

	e = _eye(Vector3(-7, 2, 3), 81)
	e.state = STATE.CIRCLE
	e.next_swoop_in = 100.0
	await _frames(40)
	state = hud.curse_state()
	var open_one: Array = state["gazers"].filter(func(g): return g.z > 0.1)
	_check("C2b from behind you on the left, it opens at the left edge (%s)" % [state["gazers"]], open_one.size() >= 1 and open_one[-1].x < 0.2)
	_free(e)
	await _frames(100)
	_check("C6 left alone, the warning fades (%.2f)" % hud.curse_state()["stared"], hud.curse_state()["stared"] < 0.05 and hud.curse_state()["gazers"].filter(func(g): return g.z > 0.1).is_empty())

	p.statuses.apply(&"evil_eye", 8.0)
	while p.curse.depth() < 6:
		p.curse.deepen()
	await _frames(70)
	state = hud.curse_state()
	_check("C3 at its deepest, a ring of six stares at you (%d)" % state["ring_open"], state["ring_open"] == 6)
	_check("C4 the power arc goes bruised, and the stray is drawn", cross.cursed > 0.5)
	p.statuses._left[&"evil_eye"] = 11.0
	await _frames(30)
	state = hud.curse_state()
	_check("C3b ebbing, half of them have closed (%d)" % state["ring_open"], state["ring_open"] == 3)
	p.statuses.clear(&"evil_eye")
	await _frames(70)
	_check("C4b it lifts", cross.cursed < 0.1 and hud.curse_state()["ring_open"] == 0)

	# Running out by itself: nothing but a quiet fade.
	p.statuses.apply(&"evil_eye", 8.0)
	p.statuses._stare_ago = 100.0
	await _frames(70)
	p.statuses._left[&"evil_eye"] = 0.1
	await _frames(12)
	_check("C7 run out, it is easing away, not cut off (%.2f)" % hud.curse_state()["curse"], not p.statuses.has(&"evil_eye") and hud.curse_state()["curse"] > 0.3)
	_check("C7a it is fading as it goes", hud.curse_state()["leaving"] > 0.5)
	await _frames(70)
	_check("C7c and then it is gone", hud.curse_state()["curse"] < 0.01 and not hud.curse_view_shown())

	p.loadout.pack_item(&"egg")
	p.loadout.item_counts[&"egg"] = 1
	p.statuses.apply(&"evil_eye", 8.0)
	while p.curse.depth() < 6:
		p.curse.deepen()
	await _frames(60)
	await _press("use_item")
	await _frames(30)
	_check("C9 using the egg, the curse is drawn in (%.2f)" % hud.curse_state()["gather"], hud.curse_state()["gather"] > 0.4 and hud.curse_state()["gather"] < 1.0)
	_check("C9b the egg is in the left hand as it is used", p.hand.left_mode() == &"egg" and p.hand.egg_shown())
	var egg_at: Vector2 = hud.curse_state()["egg_at"]
	_check("C9c and in sight, in the left of the view (%.2f, %.2f)" % [egg_at.x, egg_at.y], egg_at.x > 0.1 and egg_at.x < 0.55 and egg_at.y > 0.25 and egg_at.y < 0.95)
	_check("C9d it fills with what it takes (%.2f)" % p.hand.egg_fill(), p.hand.egg_fill() > 0.3 and p.hand.egg_fill() < 1.0)
	_check("C9f halfway, no ribbon has reached it yet (%d)" % p.loadout.ribbons_landed(), p.loadout.ribbons_landed() == 0)
	var carried_from := egg_at
	await _frames(8)
	_check("C9e it is passed across your sight, not held still", carried_from.distance_to(hud.curse_state()["egg_at"]) > 0.005)
	var trauma_was: float = p.juice._trauma
	await _frames(26)
	state = hud.curse_state()
	_check("C9g all six ribbons landed in it, each a jolt (%d)" % p.loadout.ribbons_landed(), p.loadout.ribbons_landed() == 6)
	_check("C10a the egg is spent: gone from the hand", not p.hand.egg_shown())
	_check("C10 released, the view kicks", p.juice._trauma > trauma_was or p.juice._trauma > 0.1)
	_check("C10b gathered no more", state["gather"] < 0.05)
	_check("C5 the egg dispels it: under way, all of it still there (%.2f, %.2f)" % [state["dispel"], state["curse"]], state["dispel"] > 0.0 and state["curse"] > 0.6)
	await _frames(40)
	await _frames(10)
	_check("C8 it has gone, whole, not shrunk away (%.2f, %.2f)" % [hud.curse_state()["dispel"], hud.curse_state()["curse"]], hud.curse_state()["dispel"] == 0.0 and hud.curse_state()["curse"] < 0.01)
	_check("C11 and a moment of relief follows (%.2f)" % hud.curse_state()["relief"], hud.curse_state()["relief"] > 0.1)
	state = hud.curse_state()
	_check("C5b and a ward's ring shows how long you are clean (%.2f)" % state["cleansed"], state["cleansed"] > 0.8 and hud.curse_view_shown())
	p.statuses.apply(&"cleansed", 0.2)
	await _frames(30)
	p.statuses.clear(&"cleansed")
	await _frames(70)
	_check("C5c and goes with it", not hud.curse_view_shown())
	p.loadout.unpack_item(&"egg")


func _face(target: Node3D) -> void:
	var way: Vector3 = (target.global_position - p.camera.global_position).normalized()
	p.rotation.y = atan2(-way.x, -way.z)
	p.neck.rotation = Vector3(asin(way.y), 0.0, 0.0)
	await get_tree().physics_frame


func _killing() -> void:
	var lead := _hits_to_kill(&"lead")
	var copal := _hits_to_kill(&"copal")
	_check("E12 8 lead balls or 2 copal balls kill, unexposed (%d, %d)" % [lead, copal], lead == 8 and copal == 2)

	await _place_player(HOME)
	p.neck.rotation = Vector3.ZERO
	p.rotation = Vector3.ZERO
	await _frames(2)
	var e := _eye(Vector3(0, 2, -30), 8)
	var g: Node = p.revolver
	e.global_position = g.aim().origin - g.aim().basis.z * 5.5
	await _frames(2)
	g.reset_for_practice()
	g.barrel = &"shot"
	g._pull(g.weapon())
	await _frames(2)
	_check("E13 a shell within 6 m kills (%.0f left)" % e.health, e.dead)
	g.reset_for_practice()
	_free(e)


func _hits_to_kill(round_id: StringName) -> int:
	var e := _eye(Vector3(0, 8, -40), 20)
	var count := 0

	while not e.dead and count < 20:
		e.round_hint = round_id
		e.take_hit(55.0, p, &"bullet", e.global_position, Vector3.FORWARD)
		e.statuses.clear(&"exposed")
		count += 1

	_free(e)
	return count


func _long_run() -> void:
	await _place_player(Vector3(-100, 1.05, 0))
	var pack: Array = []

	for i in 4:
		pack.append(_eye(Vector3(-100 + i * 3.0 - 4.5, 2.5, -10), 30 + i))

	var last: Array = pack.map(func(e): return e.global_position)
	var flown: Array = pack.map(func(_e): return 0.0)
	var stayed := true
	var stuck := false

	for tick in 3600:
		await get_tree().physics_frame

		for i in pack.size():
			var at: Vector3 = pack[i].global_position
			stayed = stayed and absf(at.x + 100.0) < 15.4 and absf(at.z) < 15.4 and at.y > 0.0 and at.y < 8.0
			flown[i] += at.distance_to(last[i])
			last[i] = at

		# In any 5 s, each has gone at least a few metres.
		if tick % 300 == 299:
			for i in pack.size():
				stuck = stuck or flown[i] < 3.0
				flown[i] = 0.0

	_check("E15 it never leaves the yard or sticks in geometry over 60 s", stayed and not stuck)

	for e in pack:
		_free(e)

	var first := await _path(40)
	var second := await _path(40)
	_check("E16 the same seed flies the same path", first == second)


func _path(seed_value: int) -> Array:
	await _place_player(HOME)
	var e := _eye(Vector3(0, 2, -7), seed_value)
	var path: Array = []

	for i in 120:
		await get_tree().physics_frame
		path.append(e.global_position.snapped(Vector3.ONE * 0.001))

	_free(e)
	await get_tree().physics_frame
	return path


func _dead_player() -> void:
	await _place_player(HOME)
	p.invulnerable = false
	var e := _eye(Vector3(0, 2, -7), 9)
	e.next_swoop_in = 0.0
	await _frames(10)
	p.take_damage(10000.0, null)
	await _frames(180)
	_check("E14 the player dead: eyes stop attacking, no errors", e.state != STATE.TELL and e.state != STATE.SWOOP)
	_free(e)


## Its whole body moves: drawn back in its tell, shaking harder, recoiling; starting at rest.
func _alive() -> void:
	var turned: PackedScene = load("res://assets/monsters/floating_eye_turned.glb")
	_check("T0 the turned eye's model is there", turned != null)

	if turned != null:
		var plain: Node = (load("res://assets/monsters/floating_eye.glb") as PackedScene).instantiate()
		var worse: Node = turned.instantiate()
		var names := {}

		for mesh in worse.find_children("*", "MeshInstance3D", true, false):
			names[StringName(mesh.name)] = true

		var all_there := true

		for mesh in plain.find_children("*", "MeshInstance3D", true, false):
			all_there = all_there and names.has(StringName(mesh.name))

		_check("T0b every part of the eye, and the new ones", all_there and names.has(&"Pupil_2") and names.has(&"Pupil_3") and names.has(&"Meat"))
		plain.free()
		worse.free()

	var e := _eye(HOME + Vector3(0, 1.5, -40), 3)
	await _frames(3)
	var body: Node3D = e.body
	e.state = STATE.DRIFT
	var twitches: int = body.twitches
	await _frames(300)
	_check("E4 at rest it starts now and then (%d)" % (body.twitches - twitches), body.twitches - twitches >= 1)
	e.state = STATE.TELL
	e._state_t = -9.0
	await _frames(3)
	var shake_early: float = body.shake_now
	await _frames(20)
	var shake_late: float = body.shake_now
	_check("E1 its tell draws it back (%.2f)" % body.lean_back(), body.lean_back() > 0.05)
	_check("E2 it shakes harder the nearer it is to going (%.3f, %.3f)" % [shake_early, shake_late], shake_late > shake_early * 1.5)
	e.state = STATE.DRIFT
	await _frames(60)
	var rest_at: float = body.lean_back()
	e.health = 500.0
	e.take_hit(1.0, p, &"bullet", e.global_position, Vector3.FORWARD)
	var recoil := 0.0

	for i in 12:
		await get_tree().physics_frame
		recoil = maxf(recoil, absf(body.lean_back() - rest_at))

	_check("E3 hurt, it recoils (%.2f)" % recoil, recoil > 0.04)
	_free(e)
	await _frames(2)


## Badly hurt, it turns: once, and worse.
func _turning() -> void:
	var e := _eye(HOME + Vector3(0, 1.5, -40), 5)
	e.next_swoop_in = 100.0
	await _frames(3)
	var turns := [0]
	e.turned_worse.connect(func(): turns[0] += 1)
	e.take_hit(50.0, p, &"shot", e.global_position, Vector3.FORWARD)
	_check("U1b not above half", not e.turned)
	var left: float = e.health
	e.take_hit(10.0, p, &"shot", e.global_position, Vector3.FORWARD)
	await _frames(2)
	_check("U1 at half health or less it turns", e.turned and turns[0] == 1)
	_check("U3 it wears the turned model", e.body.part(&"Pupil_2") != null and e.body.part(&"Meat") != null)
	var stray_was: Basis = e.body.part(&"Pupil_2").transform.basis
	var strayed := 0.0

	for i in 90:
		await get_tree().physics_frame
		strayed = maxf(strayed, e.body.part(&"Pupil_2").transform.basis.get_rotation_quaternion().angle_to(stray_was.get_rotation_quaternion()))

	_check("U3b its new pupils look about on their own (%.3f)" % strayed, strayed > 0.03)
	var before: float = e.health
	# (Shot is its weakness: while that shows, a hit is doubled, as on any eye.)
	var doubled: float = e.EXPOSED_SCALE if e.is_exposed() else 1.0
	e.take_hit(10.0, p, &"shot", e.global_position, Vector3.FORWARD)
	_check("U4 its health and weaknesses are as they were (%.1f, %.1f)" % [left, before - e.health], is_equal_approx(before - e.health, 10.0 * doubled))
	await _frames(2)
	_check("U1c and only once", turns[0] == 1)
	_free(e)
	await _frames(2)
	var killed := _eye(HOME + Vector3(0, 1.5, -40), 6)
	await _frames(3)
	var killed_turns := [0]
	killed.turned_worse.connect(func(): killed_turns[0] += 1)
	killed.take_hit(500.0, p, &"shot", killed.global_position, Vector3.FORWARD)
	await _frames(2)
	_check("U2 killed outright through half: no turn", killed.dead and not killed.turned and killed_turns[0] == 0)
	_free(killed)
	await _frames(2)


## A turned eye spits gobs of its curse.
func _gobs() -> Array:
	return get_tree().get_nodes_in_group(&"eye_gobs")


func _spitter(at: Vector3) -> CharacterBody3D:
	var e: CharacterBody3D = EyeScript.new()
	e.seed_value = 7
	e.position = at
	e.start_turned = true
	add_child(e)
	e.next_swoop_in = 100.0
	return e


## Whether a node has gone, without holding on to it.
func _is_gone(node: Node) -> Callable:
	var held: WeakRef = weakref(node)
	return func(): return held.get_ref() == null


func _spitting() -> void:
	await _place_player(HOME)
	p.invulnerable = false
	p.health = 500.0
	await _frames(2)
	var e := _spitter(HOME + Vector3(0, 1.0, -7))
	await _frames(3)
	e.state = STATE.CIRCLE
	e._clear_line = true
	e.spit_in = 0.0
	var saw_wind := await _until(func(): return e.state == STATE.SPIT_UP, 2.0)
	var gob_came := await _until(func(): return not _gobs().is_empty(), 2.0)
	_check("U5 a turned eye spits, with a wind-up to read", saw_wind and gob_came)
	e.spit_in = 100.0
	var was: float = p.health
	var depth_was: int = p.curse.depth()
	await _until(func(): return _gobs().is_empty(), 3.0)
	_check("U6 it hurts (%.1f) and starts the curse on you" % (was - p.health), is_equal_approx(was - p.health, 8.0) and p.curse.depth() == depth_was + 1)
	# Again, it opens another eye.
	var gob_two: Node3D = EyeGobScript.spat_at(self, HOME + Vector3(0, 0.3, -4), HOME + Vector3(0, 0.15, 0), e)
	depth_was = p.curse.depth()
	await _until(_is_gone(gob_two), 3.0)
	_check("U6b on the curse, it opens another eye (%d)" % p.curse.depth(), p.curse.depth() == depth_was + 1)
	# You can step out of its way.
	was = p.health
	var missed: Node3D = EyeGobScript.spat_at(self, HOME + Vector3(0, 0.3, -6), HOME + Vector3(0, 0.15, 0), e)
	await _frames(5)
	p.teleport(Transform3D(Basis.IDENTITY, HOME + Vector3(5, 0, 0)))
	await _until(_is_gone(missed), 3.0)
	_check("U7 you can step out of its way", p.health == was)
	await _place_player(HOME)
	# A wall stops it, and so does the Ward.
	var wall: Node = Props.block(self, HOME + Vector3(0, 0, -2.5), Vector3(4, 4, 0.3))
	was = p.health
	var walled: Node3D = EyeGobScript.spat_at(self, HOME + Vector3(0, 0.3, -5), HOME + Vector3(0, 0.15, 0), e)
	await _until(_is_gone(walled), 2.0)
	_check("U8 a wall stops it", p.health == was)
	wall.free()
	await _frames(2)
	var ward: Node3D = WardScript.cast_on(p)
	await _frames(30)
	var warded: Node3D = EyeGobScript.spat_at(self, HOME + Vector3(0, 0.3, -7), HOME + Vector3(0, 0.15, 0), e)
	await _until(_is_gone(warded), 2.0)
	_check("U8b so does the Ward", p.health == was)
	ward.queue_free()
	await _frames(2)
	# Brought back from a save: already turned, with no burst to show for it.
	var saved := _eye(HOME + Vector3(0, 1.5, -40), 8)
	await _frames(2)
	saved.health = 30.0
	var state: Dictionary = saved.save_state()
	var loaded := _eye(HOME + Vector3(0, 1.5, -40), 8)
	await _frames(2)
	var loaded_turns := [0]
	loaded.turned_worse.connect(func(): loaded_turns[0] += 1)
	loaded.load_state(state)
	await _frames(2)
	_check("U11 a hurt eye off a save has turned, quietly", loaded.turned and loaded_turns[0] == 0 and loaded.body.part(&"Meat") != null)
	_free(saved)
	_free(loaded)
	# Whipped back, it hurts what it meets, and not you.
	var other := _eye(HOME + Vector3(5, 1.0, 2.4), 9)
	other.next_swoop_in = 100.0
	other.health = 500.0
	await _frames(2)
	var other_at: Vector3 = other.global_position
	var batted: Node3D = EyeGobScript.spat_at(self, HOME + Vector3(0, 0.3, 2.4), HOME + Vector3(0, 0.15, 3.5), e)
	batted.take_hit(20.0, p, &"power", batted.global_position, (other_at - batted.global_position).normalized())
	_check("U9 whipped: it goes back", batted.is_batted())
	was = p.health
	var other_was: float = other.health

	for i in 60:
		await get_tree().physics_frame

		if is_instance_valid(other):
			other.global_position = other_at

	_check("U9b it hurts what it meets (%.0f), and not you" % (other_was - other.health), other.health < other_was and p.health == was)
	_free(other)
	# Its eye dead, it flies on.
	var orphan: Node3D = EyeGobScript.spat_at(self, HOME + Vector3(0, 1, 6), HOME + Vector3(0, 1, 20), e)
	_free(e)
	await _frames(6)
	_check("U10 its eye gone, it flies on", is_instance_valid(orphan))
	await _until(_is_gone(orphan), 5.0)
	# The whip finds one in reach.
	await _place_player(HOME)
	p.rotation.y = 0.0
	p.neck.rotation.x = 0.0
	var near: Node3D = EyeGobScript.spat_at(self, HOME + Vector3(0, 0.6, -2.8), HOME + Vector3(0, 0.15, -2.2), null)
	near.velocity = Vector3.ZERO
	await _frames(1)
	var whipped: bool = p.revolver.try_whip()
	await _frames(12)
	_check("U9c the whip finds one in reach", whipped and is_instance_valid(near) and near.is_batted())
	_check("U12 a gob is its own wet meat, with an eye in it", near.find_child("Meat", true, false) != null and near.find_child("Eye", true, false) != null)
	_free(near)
	p.statuses.clear(&"evil_eye")
	p.invulnerable = true
	await _frames(2)


## What the branch's review found.
func _review_of_the_spit() -> void:
	await _place_player(HOME)
	p.rotation.y = 0.0
	p.neck.rotation.x = 0.0
	# Whipped, a gob goes straight along your aim, not up over what spat it.
	var near: Node3D = EyeGobScript.spat_at(self, p.camera.global_position + Vector3(0, 0, -2.8), HOME, null)
	near.velocity = Vector3.ZERO
	var along: Vector3 = (near.global_position - p.camera.global_position).normalized()
	await _frames(1)
	p.revolver.try_whip()
	await _frames(12)
	_check("R1 a whipped gob flies along your aim (%.2f)" % near.velocity.normalized().dot(along), near.is_batted() and near.velocity.normalized().dot(along) > 0.98)
	_free(near)
	# Ánimas waiting their turn are no swooping eyes.
	var eye := _eye(HOME + Vector3(0, 1.5, -40), 12)
	var waiting: Array = []

	for i in 2:
		var one: CharacterBody3D = AnimaScript.new()
		one.form = &"hands"
		one.position = HOME + Vector3(i, 1.0, -44)
		add_child(one)
		waiting.append(one)

	await _frames(2)

	for one in waiting:
		one.state = STATE.SWOOP

	_check("R2 ánimas don't use up the eyes' turns to swoop", eye._room_to_swoop())

	for one in waiting:
		_free(one)

	_free(eye)
	# It turns facing as it was.
	var facing := _eye(HOME + Vector3(0, 1.0, -7), 13)
	facing.next_swoop_in = 100.0
	await _frames(3)
	facing.state = STATE.CIRCLE
	await _frames(60)
	var was_facing: Basis = facing.body.global_basis
	var pupil_was: float = facing.body.pupil
	facing.turn()
	await _frames(1)
	var turned_away: float = facing.body.global_basis.get_rotation_quaternion().angle_to(was_facing.get_rotation_quaternion())
	_check("R3 torn open, it hasn't turned away from you (%.2f rad)" % turned_away, turned_away < 0.1)
	_check("R3b nor has its pupil started over", absf(facing.body.pupil - pupil_was) < 0.2)
	_free(facing)
	# The gob leaves from the side that faces you, wherever you are.
	var behind_it := _spitter(HOME + Vector3(0, 1.0, -7))
	await _frames(3)
	behind_it.state = STATE.CIRCLE
	behind_it._clear_line = true
	await _frames(40)
	behind_it.spit_in = 0.0
	await _until(func(): return not _gobs().is_empty(), 2.0)
	var first_gob: Node3D = _gobs()[0]
	_check("R4 it leaves from the side facing you", first_gob.global_position.distance_to(p.global_position) < behind_it.global_position.distance_to(p.global_position))
	# A spit broken off doesn't come straight back.
	behind_it.spit_in = 0.0
	await _until(func(): return behind_it.state == STATE.SPIT_UP, 2.0)
	behind_it.take_hit(1.0, p, &"shot", behind_it.global_position, Vector3.FORWARD)
	_check("R5 a hit in the wind-up breaks it off", behind_it.state != STATE.SPIT_UP)
	_check("R5b and its next spit is a full wait away (%.2f)" % behind_it.spit_in, behind_it.spit_in >= behind_it.SPIT_EVERY.x)
	behind_it.state = STATE.CIRCLE
	behind_it.spit_in = 0.0
	await _until(func(): return behind_it.state == STATE.SPIT_UP, 2.0)
	behind_it.flinch()
	_check("R5c a packmate bursting breaks it off too", behind_it.state == STATE.CIRCLE)
	_free(behind_it)

	for gob in _gobs():
		_free(gob)

	# The drain's claws keep to the flesh's distance, with the curse up.
	var drain_shader := FileAccess.get_file_as_string("res://scripts/UI/life_drain_view.gdshader")
	_check("R6 the drain's claws hear of the flesh", drain_shader.count("with_flesh") >= 2 and drain_shader.count("CLAWS_WITH_FLESH") >= 2)
	p.statuses.clear(&"evil_eye")
	await _frames(2)


func _eye(at: Vector3, seed_value: int) -> CharacterBody3D:
	var e: CharacterBody3D = EyeScript.new()
	e.seed_value = seed_value
	e.position = at
	add_child(e)
	return e


func _free(e: Node) -> void:
	e.free()


func _place_player(at: Vector3) -> void:
	for action in ["move_left", "move_right", "move_forward", "move_back", "gun_dodge"]:
		Input.action_release(action)

	p.teleport(Transform3D(Basis.IDENTITY, at))
	await _frames(20)


func _time_in(e: Node, state: int) -> float:
	await _until(func(): return e.state == state, 4.0)
	var t := 0.0

	while e.state == state and t < 3.0:
		await get_tree().physics_frame
		t += 1.0 / 60.0

	return t


func _until(done: Callable, most: float) -> bool:
	var t := 0.0

	while t < most:
		if done.call():
			return true

		await get_tree().physics_frame
		t += 1.0 / 60.0

	return false


func _press(action: String) -> void:
	Input.action_press(action)
	await get_tree().physics_frame
	Input.action_release(action)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(label: String, ok: bool) -> void:
	print(("PASS " if ok else "FAIL ") + label)

	if not ok:
		failed += 1
