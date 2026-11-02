extends Node3D
## The floating eye: packs that circle, tell and swoop, and a gaze that puts
## the evil eye on you. The real player.

const PLAYER := preload("res://Player.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const EyeScript := preload("res://scripts/Monsters/FloatingEye.gd")
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
	await _noticing()
	await _attacks()
	await _gaze()
	await _smoke()
	await _stagger()
	await _answers()
	await _deaths()
	await _limpia()
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
	p.set_meta(&"gaze", 0.0)
	var e := _eye(Vector3(0, 2, -7), 5)
	e.next_swoop_in = 100.0
	await _frames(100)
	_check("E7a not at once", not p.statuses.has(&"evil_eye"))
	await _until(func(): return p.statuses.has(&"evil_eye"), 2.0)
	_check("E7 2 s of gaze puts the evil eye on you", p.statuses.has(&"evil_eye"))
	await _frames(2)
	_check("E9 evil eye: refill halved", is_equal_approx(p.power.refill_scale, 0.5))
	_check("E9b view unsteady", p.juice.unsteady() > 0.0)
	p.revolver.aimed = true
	var straight: Basis = Basis.IDENTITY
	_check("E9c even aimed, the aim strays", p.revolver._stray(straight).dot(-straight.z) < 0.9999)
	p.revolver.aimed = false
	p.loadout.pack_item(&"egg")
	p.loadout.item_counts[&"egg"] = 1
	p.loadout.use_item()
	await _frames(55)
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
	p.set_meta(&"gaze", 0.0)
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
	_check("D3 and leaves a stain where it lands (%d, %d)" % [stains_was, Fx.stains_in_use()], Fx.stains_in_use() > stains_was)
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
	p.set_meta(&"gaze", 0.0)
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
	await _frames(30)
	_check("EG2 what can see you squeezes shut", seen.state == STATE.DAZED and also.state == STATE.DAZED and seen.is_exposed())
	_check("EG2b what can't see you or is too far doesn't", hidden.state != STATE.DAZED and distant.state != STATE.DAZED)
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
	await _frames(55)
	_check("EG7b and the egg lifts it", not p.statuses.has(&"evil_eye"))
	p.statuses.clear(&"cleansed")
	lo.unpack_item(&"egg")
	p.invulnerable = true
	_free(one)


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
