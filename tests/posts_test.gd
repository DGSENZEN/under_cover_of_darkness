extends Node3D
## Posts and places: a man set to watch keeps his post and watches from it
## (Guard._holds_post), sends a friend down to look at what he sees and
## covers him, calls them all out if the friend goes quiet; he comes down
## when he is needed, fetched, or no use up there, and says so
## (Squad._keeps_post). Things are picked up and thrown when it helps
## (GuardFighter._throw_worth); a man waiting his turn goes round to his
## place; a man cut down in a fight is no news to the men fighting, and the
## parts of one man are one find (Guard._discover).

const PLAYER := preload("res://Player.tscn")
const GUARD := preload("res://Guard.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")
const SquadScript := preload("res://scripts/AISystem/Squad.gd")
const GarrisonScript := preload("res://scripts/AISystem/Garrison.gd")
const TemperamentScript := preload("res://scripts/AISystem/Temperament.gd")
const GuardScript := preload("res://scripts/AISystem/Guard.gd")
const Comms := preload("res://scripts/AISystem/Comms.gd")
const AlarmBellScript := preload("res://scripts/Interaction/AlarmBell.gd")
const LightProbe := preload("res://scripts/StimuliSystem/LightProbe.gd")

const RELAXED := 0
const SUSPICIOUS := 1
const INVESTIGATING := 2
const SEARCHING := 3
const COMBAT := 4

## Where you stand while they are not to see you: far off, in the dark.
const AWAY := Vector3(700, 1.05, 35)

var player: CharacterBody3D
var results: Array[String] = []
var _barks := {}


func _ready() -> void:
	# Every man at his class's own temperament, and exact cuts.
	TemperamentScript.rolling = false
	GuardScript.bleeding_on = false
	Props.block(self, Vector3(340, -0.5, 0), Vector3(760, 1, 80))

	# A lookout's platform for each check that needs one, stairs down its
	# east side.
	for x in [0.0, 60.0, 120.0, 180.0, 240.0, 300.0, 640.0]:
		_platform(Vector3(x, 0, 0))

	var baker := NavigationRegion3D.new()
	baker.set_script(NavBakerScript)
	add_child(baker)

	player = PLAYER.instantiate()
	add_child(player)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.debug_traversal = false
	player.invulnerable = true
	player.reload_on_death = false

	if player.has_node("LightGem"):
		player.get_node("LightGem").queue_free()

	player.global_position = AWAY
	Props.give_weapons(player, 12)
	player.inventory.select_by_id(&"sword")

	await baker.baked
	await _frames(5)
	await _run()

	print("\n==== RESULTS ====")
	for r in results:
		print(r)
	get_tree().quit()


func _run() -> void:
	# A man set to watch

	# P1 word of you comes up to him: he watches it from his post
	await _fresh()
	player.debug_light_level = 0.0
	var watch1 := _lookout(Vector3(0, 0, 0))
	var caller1 := _guard(&"swordsman", Vector3(6, 0, 8), 0.0, &"steady", false)
	await _frames(20)
	var where1 := Vector3(-6, 0, 14)
	Comms.call_out(caller1, &"spotted", where1, {"heading": Vector3.ZERO})
	var off1 := [0.0]
	for i in 240:
		await _frames(1)
		off1[0] = maxf(off1[0], _off_post(watch1))
	var eyes1 := _eyes_off(watch1, where1)
	_check("P1 told where you are, a man set to watch looks from his post, and does not come down to it",
		watch1.state >= INVESTIGATING and off1[0] < 1.0 and eyes1 < 40.0,
		"state %d, at most %.2f m off his post, looking %.0f deg off the place" % [watch1.state, off1[0], eyes1])

	# P2 they fight you below where he cannot see: he comes down to them
	await _fresh()
	player.debug_light_level = 0.0
	var watch2 := _lookout(Vector3(60, 0, 0))
	var fighter2 := _guard(&"swordsman", Vector3(66, 0, 8), 0.0)
	fighter2.lose_time = 999.0
	await _frames(20)
	var where2 := Vector3(54, 0, 16)
	Comms.call_out(fighter2, &"spotted", where2, {"heading": Vector3.ZERO})
	await _frames(120)
	var held2 := _off_post(watch2) < 1.0
	await _frames(360)
	var down2: bool = _barks_of(watch2).any(func(t): return _is_line(t, &"descend"))
	_check("P2 his friends fighting below where he cannot see it: he watches a moment, then comes down to them, and says so",
		held2 and watch2._left_post and _off_post(watch2) > 3.0 and down2,
		"on his post at first %s, came down %s (%.1f m off it), said %s" % [held2, watch2._left_post, _off_post(watch2), _barks_of(watch2)])

	# P3 he sees something: he sends a friend to look, by name, and covers him
	await _fresh()
	player.debug_light_level = 0.0
	var watch3 := _lookout(Vector3(120, 0, 0))
	var friend3 := _guard(&"", Vector3(125, 0, 6), 0.0, &"steady", false)
	friend3.look_around_time = 0.4
	friend3.search_points = 1
	await _frames(20)
	var where3 := Vector3(115, 0, 12)
	_glimpse(watch3, where3)
	await _frames(10)
	var named3: bool = _barks_of(watch3).any(func(t): return String(t).begins_with(friend3.given_name + "!"))
	var went3: bool = friend3.state == INVESTIGATING and friend3._agent.target_position.distance_to(where3) < 2.0
	var covered3: bool = watch3.state == SUSPICIOUS and watch3._life.covering()
	var off3 := [0.0]
	await _until(func():
		off3[0] = maxf(off3[0], _off_post(watch3))
		return friend3.state == RELAXED, 2400)
	await _frames(20)
	var clear3: bool = _barks_of(friend3).any(func(t): return _is_line(t, &"clear"))
	_check("P3 something seen from his post: he calls a friend by name to go and look, covers him from up there, and stands easy when he calls it clear",
		named3 and went3 and covered3 and clear3 and off3[0] < 1.0 and not watch3._life.covering(),
		"named %s went %s covered %s clear %s, at most %.2f m off his post, said %s" % [named3, went3, covered3, clear3, off3[0], _barks_of(watch3)])

	# P4 the friend he sent goes quiet: he calls them all out, and watches
	await _fresh()
	player.debug_light_level = 0.0
	var watch4 := _lookout(Vector3(180, 0, 0))
	var friend4 := _guard(&"", Vector3(185, 0, 6), 0.0, &"steady", false)
	var other4 := _guard(&"", Vector3(196, 0, -6), PI * 0.5, &"steady", false)
	await _frames(20)
	_glimpse(watch4, Vector3(175, 0, 12))
	await _frames(10)
	var went4: bool = friend4.state == INVESTIGATING
	var name4: String = friend4.given_name
	friend4.knock_out(player, true)
	await _frames(40)
	var quiet4: bool = _barks_of(watch4).any(func(t): return String(t).contains(name4) and not String(t).begins_with(name4 + "!"))
	_check("P4 the friend he sent goes quiet: he calls it, by name, and the others come; he keeps his post",
		went4 and quiet4 and other4.state >= INVESTIGATING and GarrisonScript.of(player).alarm >= 0.35 and _off_post(watch4) < 1.0,
		"went %s called it %s (%s), the other %d, alarm %.2f, %.2f m off his post" % [went4, quiet4, _barks_of(watch4), other4.state, GarrisonScript.of(player).alarm, _off_post(watch4)])

	# P5 two of them have you in hand: he keeps his post; one cut down, he
	#    comes down to help, and says so
	await _fresh()
	player.debug_light_level = 1.0
	_put_player(Vector3(240, 1.05, 9))
	var watch5 := _lookout(Vector3(240, 0, 0))
	watch5.fov_vertical = 179.0
	var a5 := _guard(&"swordsman", Vector3(238.5, 0, 7), PI)
	var b5 := _guard(&"swordsman", Vector3(241.5, 0, 7), PI)
	await _until(func(): return watch5.state == COMBAT, 300)
	await _frames(150)
	var squad5 = SquadScript.of(player)
	var kept5: bool = squad5.role_of(watch5) == &"lookout" and _off_post(watch5) < 1.0
	a5.die(player)
	await _frames(40)
	var role5: StringName = squad5.role_of(watch5)
	var down5: bool = _barks_of(watch5).any(func(t): return _is_line(t, &"descend"))
	await _frames(240)
	_check("P5 he keeps his post while two of them are at you; one cut down, he comes down to help, and says so",
		kept5 and role5 != &"lookout" and down5 and _off_post(watch5) > 2.0,
		"kept it %s, then %s, said so %s, %.1f m off his post" % [kept5, role5, down5, _off_post(watch5)])
	b5.queue_free()

	# P6 they fight below him, a bell near: he rings it, and they all come
	await _fresh()
	player.debug_light_level = 0.0
	var watch6 := _lookout(Vector3(640, 0, 0))
	var bell6: StaticBody3D = AlarmBellScript.build(self, Vector3(646, 0, 3), 0.0)
	var rang6 := [false]
	bell6.rung.connect(func(_by): rang6[0] = true)
	var fighter6 := _guard(&"swordsman", Vector3(646, 0, 10), 0.0)
	fighter6.lose_time = 999.0
	var far6 := _guard(&"", Vector3(690, 0, -25), 0.0, &"steady", false)
	far6.hearing_acuity = 0.1
	await _frames(20)
	Comms.call_out(fighter6, &"spotted", Vector3(636, 0, 16), {"heading": Vector3.ZERO})
	await _frames(5)
	var far_heard6: int = far6.state
	await _until(func(): return rang6[0], 600)
	await _frames(20)
	var bell_line6: bool = _barks_of(watch6).any(func(t): return _is_line(t, &"bell"))
	_check("P6 they fight below him and a bell is near: he rings it, and the far men come",
		rang6[0] and bell_line6 and far_heard6 < INVESTIGATING and far6.state >= INVESTIGATING and far6.last_known_position.distance_to(Vector3(636, 0, 16)) < 4.0,
		"rang %s said so %s, far man %d before the bell, %d after (%.1f m off the place), said %s" % [rang6[0], bell_line6, far_heard6, far6.state, far6.last_known_position.distance_to(Vector3(636, 0, 16)), _barks_of(watch6)])
	bell6.queue_free()

	# P7 fetched by one of his own, he comes down
	await _fresh()
	player.debug_light_level = 0.0
	var watch7 := _lookout(Vector3(300, 0, 0))
	_guard(&"", Vector3(306, 0, 8), 0.0, &"steady", false)
	await _frames(20)
	watch7.join_hunt(Vector3(296, 0, 16))
	await _frames(300)
	_check("P7 fetched to the hunt by one of his own, a man set to watch comes down to it",
		watch7._left_post and _off_post(watch7) > 3.0,
		"came down %s, %.1f m off his post" % [watch7._left_post, _off_post(watch7)])

	# Things thrown when it helps

	# P8 waiting his turn while another is at you: he throws what is near
	await _fresh()
	player.debug_light_level = 1.0
	player.invulnerable = false
	player.health = player.max_health
	_put_player(Vector3(360, 1.05, 0))
	var front8 := _guard(&"swordsman", Vector3(360, 0, -2.0), 0.0)
	var waiter8 := _guard(&"", Vector3(363.5, 0, -1.5), 0.0, &"sly")
	var crate8 := Props.crate(self, Vector3(362.5, 0.3, 1.5), 0.45, 2.5)
	await _frames(5)
	front8._fighter._take_token(player)
	waiter8._attack_timer = 0.0
	waiter8.attack_cooldown = 1.5
	var threw8 := await _watch_throw(waiter8, crate8, 900)
	_check("P8 waiting his turn while another is at you, he takes up something near and throws it",
		threw8[0] and threw8[1],
		"held %s, it reached you %s (%.2f m), your health %.0f" % [threw8[0], threw8[1], threw8[2], player.health])
	player.invulnerable = true

	# P9 you keep out of his reach: he throws what is near
	await _fresh()
	player.debug_light_level = 1.0
	player.invulnerable = false
	player.health = player.max_health
	_put_player(Vector3(420, 1.05, 0))
	var slow9 := _guard(&"", Vector3(420, 0, -8.5), 0.0)
	slow9.chase_speed = 0.4
	var crate9 := Props.crate(self, Vector3(420.9, 0.3, -7.6), 0.45, 2.5)
	await _frames(5)
	slow9._attack_timer = 0.0
	slow9.attack_cooldown = 1.5
	var threw9 := await _watch_throw(slow9, crate9, 900)
	_check("P9 you keeping out of his reach, he takes up something near and throws it",
		threw9[0] and threw9[1],
		"held %s, it reached you %s (%.2f m), your health %.0f" % [threw9[0], threw9[1], threw9[2], player.health])
	player.invulnerable = true

	# Places, and the dead

	# P10 a plain watchman waiting his turn goes round to his place
	await _fresh()
	player.debug_light_level = 1.0
	_put_player(Vector3(480, 1.05, 0))
	var first10 := _guard(&"", Vector3(480, 0, -2.0), 0.0)
	var second10 := _guard(&"", Vector3(480.4, 0, -3.4), 0.0)
	await _frames(5)
	first10._fighter._take_token(player)
	var start10: Vector3 = second10.global_position
	await _frames(240)
	var squad10 = SquadScript.of(player)
	var role10: StringName = squad10.role_of(second10) if squad10 != null else &""
	var apart10 := _angle_round_you(first10, second10)
	_check("P10 a plain watchman waiting his turn goes round you to his place",
		second10.global_position.distance_to(start10) > 1.5 and apart10 > 50.0,
		"%s, moved %.1f m, %.0f deg round you from the man in front" % [role10, second10.global_position.distance_to(start10), apart10])

	# P11 a man cut down in front of his friends: no news to them
	await _fresh()
	player.debug_light_level = 1.0
	_light(Vector3(540, 3, -2))
	_put_player(Vector3(540, 1.05, 0))
	var m11 := _guard(&"swordsman", Vector3(540, 0, -2.2), 0.0)
	var others11: Array = [_guard(&"swordsman", Vector3(542.2, 0, -1.8), 0.0), _guard(&"swordsman", Vector3(537.8, 0, -1.8), 0.0)]
	await _frames(30)
	m11.die(player)
	await _frames(240)
	var shouted11: bool = others11.any(func(g): return _barks_of(g).any(func(t): return String(t).begins_with("He's dead") or String(t).begins_with("A body")))
	var knew11: bool = others11.all(func(g): return not g._known_bodies.is_empty())
	_check("P11 a man cut down in front of his friends is no news to them: no cry of murder mid-fight",
		not shouted11 and knew11 and others11.all(func(g): return g.state == COMBAT),
		"shouted %s knew of him %s states %s" % [shouted11, knew11, others11.map(func(g): return g.state)])

	# P12 the parts of one man lie together: one find, one cry
	await _fresh()
	var g12 := _guard(&"", Vector3(600, 0, 0), 0.0, &"steady", false)
	var body12 := Node3D.new()
	add_child(body12)
	body12.global_position = Vector3(600, 0, -3)
	var head12 := Node3D.new()
	add_child(head12)
	head12.global_position = Vector3(600.9, 0, -3.6)
	g12._discover(body12)
	g12._search_left = 1
	g12._discover(head12)
	var cries12: int = _barks_of(g12).filter(func(t): return String(t).begins_with("He's dead") or String(t).begins_with("A body")).size()
	_check("P12 the parts of one man are one find: one cry, and the search is not begun again",
		cries12 == 1 and g12._search_left == 1 and g12.state == SEARCHING,
		"cries %d, search points left %d, state %d" % [cries12, g12._search_left, g12.state])
	body12.queue_free()
	head12.queue_free()



## A 3 m platform (its top 3 m up) at `at`, stairs up its east side.
func _platform(at: Vector3) -> void:
	Props.block(self, at + Vector3(0, 1.5, 0), Vector3(3, 3, 3))
	var start := at + Vector3(4.5, 0, 0)

	for i in 10:
		var top := 0.3 * (i + 1)
		Props.block(self, start + Vector3.LEFT * (0.3 * (i + 0.5)) + Vector3.UP * (top * 0.5), Vector3(0.3, top, 1.4))


## A man set to watch on the platform at `at`, facing south (+Z).
func _lookout(at: Vector3) -> CharacterBody3D:
	var g := _guard(&"", at + Vector3(0, 3.0, 0), PI, &"steady", false)
	g.lookout = true
	return g


## How far `g` is from his post.
func _off_post(g: Node3D) -> float:
	return g.global_position.distance_to(g._home.origin)


## How far (deg) from `point` `g` is looking.
func _eyes_off(g: Node3D, point: Vector3) -> float:
	var facing: Vector3 = -g.global_basis.z
	var to := point - g.global_position
	return rad_to_deg(absf(Vector2(facing.x, facing.z).angle_to(Vector2(to.x, to.z))))


## How far round you (deg) `b` stands from `a`.
func _angle_round_you(a: Node3D, b: Node3D) -> float:
	var to_a := a.global_position - player.global_position
	var to_b := b.global_position - player.global_position
	return rad_to_deg(absf(Vector2(to_a.x, to_a.z).angle_to(Vector2(to_b.x, to_b.z))))


## `g` glimpses something at `where`: enough to look into.
func _glimpse(g: Node3D, where: Vector3) -> void:
	g.last_known_position = where
	g.has_last_known = true
	g._stimulus = &"sight"
	g._since_stimulus = 0.0
	g.alert = g.investigate_at + 5.0


## Up to `max_frames`: whether `g` took up `thing`, whether it reached you
## (you hurt, or it came within 1.5 m of you), and how near it came.
func _watch_throw(g: Node3D, thing: Node3D, max_frames: int) -> Array:
	var held := false
	var nearest := 99.0

	for i in max_frames:
		await _frames(1)

		if g._hands.held != null:
			held = true

		if held and is_instance_valid(thing):
			nearest = minf(nearest, thing.global_position.distance_to(player.global_position))

		if player.health < player.max_health or nearest < 1.5:
			break

	return [held, player.health < player.max_health or nearest < 1.5, nearest]


## A guard of `archetype` at `at`, facing `yaw`. Engaged: fighting you, not
## striking until told.
func _guard(archetype: StringName, at: Vector3, yaw := 0.0, preset: StringName = &"steady", engage := true) -> CharacterBody3D:
	var g: CharacterBody3D = GUARD.instantiate()
	g.archetype = archetype
	g.temperament = preset
	g.debug_ai = false
	g.position = at
	g.rotation.y = yaw
	add_child(g)
	g._attack_timer = 999.0
	g.attack_cooldown = 999.0
	_barks[g] = []
	g.barked.connect(func(t): _barks[g].append(t))

	if engage:
		g._engage(player)

	return g


func _light(at: Vector3) -> void:
	var lamp := OmniLight3D.new()
	lamp.omni_range = 9.0
	lamp.light_energy = 2.0
	lamp.add_to_group(&"posts_lights")
	add_child(lamp)
	lamp.global_position = at
	LightProbe.invalidate()


## A clean start: nobody left, nothing lying about, nothing remembered, and
## you far off in the dark.
func _fresh() -> void:
	_release_all()

	for g in get_tree().get_nodes_in_group(&"guards"):
		g.remove_from_group(&"guards")
		g.set_physics_process(false)
		g.queue_free()

	for group in [&"bodies", &"dropped_weapons", &"dropped_lights", &"posts_lights", &"stray_arrows"]:
		for thing in get_tree().get_nodes_in_group(group):
			thing.queue_free()

	SquadScript.clear_all()
	GarrisonScript.clear_all()
	_put_player(AWAY)
	player.debug_light_level = 0.0
	player.invulnerable = true
	player.health = player.max_health
	await _frames(5)
	LightProbe.invalidate()


func _barks_of(g: Node) -> Array:
	return _barks.get(g, [])


## One of the lines any temperament has for `situation`.
func _is_line(text: String, situation: StringName) -> bool:
	for tag in TemperamentScript.MORE_LINES:
		if text in (TemperamentScript.MORE_LINES[tag] as Dictionary).get(situation, []):
			return true

	return false


func _put_player(at: Vector3) -> void:
	_release_all()
	player.movement_state = 0
	player.current_move = null
	player.velocity = Vector3.ZERO
	player.global_position = at
	player.rotation.y = 0.0
	player.get_node("Neck").rotation.x = 0.0
	player.combat._reset()
	player.reset_physics_interpolation()


func _release_all() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "jump", "sprint", "crouch", "frob", "throw", "block", "kick", "dodge"]:
		if InputMap.has_action(a):
			Input.action_release(a)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _until(cond: Callable, max_frames: int) -> void:
	for i in max_frames:
		if cond.call():
			return
		await get_tree().physics_frame


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
