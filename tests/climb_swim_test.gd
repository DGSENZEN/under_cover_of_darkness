extends Node3D
## Climbing and swimming: the ways across the navmesh cannot walk (NavLinks),
## guards crossing them after you (GuardClimb), water (WaterVolume): you
## swimming and wading, guards swimming after you and climbing out
## (GuardWater), and loose things afloat.

const PLAYER := preload("res://Player.tscn")
const GUARD := preload("res://Guard.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")
const SquadScript := preload("res://scripts/AISystem/Squad.gd")
const GarrisonScript := preload("res://scripts/AISystem/Garrison.gd")
const TemperamentScript := preload("res://scripts/AISystem/Temperament.gd")
const GuardScript := preload("res://scripts/AISystem/Guard.gd")
const WaterScript := preload("res://scripts/Interaction/WaterVolume.gd")
const CLIMB := preload("res://scripts/PlayerUtils/ClimbVolume.gd")

const RELAXED := 0
const COMBAT := 4
## Where you stand while out of it: far off, in the dark.
const AWAY := Vector3(250, 1.05, 30)
## The pool: a pit (x 330..338, z -4..4) 2.6 m deep, its water 0.5 m under the
## bank.
const POOL := Vector3(334, 0, 0)
const POOL_SURFACE := -0.5
## How long a guard goes on after you unseen before he starts to search
## (Guard.lose_time, as it comes).
const GUARD_LOSE_TIME := 4.0

var player: CharacterBody3D
var baker: NavigationRegion3D
var results: Array[String] = []
var pool: Area3D
var shallows: Area3D


func _ready() -> void:
	TemperamentScript.rolling = false
	GuardScript.bleeding_on = false
	# The floor, with a pit for the pool in it.
	Props.block(self, Vector3(155, -0.5, 0), Vector3(350, 1, 80))
	Props.block(self, Vector3(349, -0.5, 0), Vector3(22, 1, 80))
	Props.block(self, Vector3(334, -0.5, 22), Vector3(8, 1, 36))
	Props.block(self, Vector3(334, -0.5, -22), Vector3(8, 1, 36))
	Props.block(self, Vector3(334, -3.1, 0), Vector3(8, 1, 8))
	# A: a 1.5 m block. B: a 3.5 m tower with a ladder up its south face.
	# C: two 1.5 m platforms with a 1.4 m gap. D: a 3 m wall, no way up.
	# E: a 3.5 m tower, no ladder.
	Props.block(self, Vector3(0, 0.75, -6), Vector3(3, 1.5, 3))
	Props.block(self, Vector3(40, 1.75, -6), Vector3(3, 3.5, 3))
	_ladder(Vector3(40, 1.7, -4.15), 3.4)
	Props.block(self, Vector3(77.5, 0.75, -6), Vector3(3, 1.5, 4))
	Props.block(self, Vector3(82.4, 0.75, -6), Vector3(3, 1.5, 4))
	Props.block(self, Vector3(120, 1.5, -6), Vector3(3, 3.0, 3))
	Props.block(self, Vector3(160, 1.75, -6), Vector3(3, 3.5, 3))
	pool = WaterScript.build(self, Vector3(334, -1.55, 0), Vector3(8, 2.1, 8))
	# Shallows: 0.8 m of water standing on the floor.
	shallows = WaterScript.build(self, Vector3(280, 0.4, 0), Vector3(8, 0.8, 8))

	baker = NavigationRegion3D.new()
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
	# ------------------------------------------------------------------
	# The ways across
	# ------------------------------------------------------------------

	# L1 found: onto the block and down again, off the tower, up the ladder,
	#    across the gap, into the water and out; not up the bare wall
	var kinds := _links_near(Vector3(0, 0, -6), 4.0)
	var ladder := _links_near(Vector3(40, 0, -5), 3.0)
	var off_tower := _links_near(Vector3(160, 0, -6), 4.0)
	var gap := _links_near(Vector3(80, 0, -6), 3.0)
	var water := _links_near(POOL, 6.0)
	var wall := _links_near(Vector3(120, 0, -6), 4.0)
	var onto: PackedVector3Array = NavigationServer3D.map_get_path(get_world_3d().navigation_map, Vector3(0, 0, -2), Vector3(0, 1.5, -6), true)
	_check("L1 the ways across are found: onto a block and down, off a tower, up a ladder, across a gap, into water and out; none up a bare 3 m wall (only off it)",
		kinds.has(&"climb") and ladder.has(&"ladder") and off_tower.has(&"drop") and gap.has(&"leap") and water.has(&"water") and not wall.has(&"climb") and not wall.has(&"ladder") and onto.size() > 0 and onto[onto.size() - 1].y > 1.3,
		"block %s ladder %s tower %s gap %s pool %s wall %s, the path onto the block ends %s (%d links)" % [kinds.keys(), ladder.keys(), off_tower.keys(), gap.keys(), water.keys(), wall.keys(), onto[onto.size() - 1] if onto.size() > 0 else "nowhere", baker.link_count])

	# L2 deep water is swum at its surface: no path along its bottom, and a
	#    swim is dearer than the long way round
	var bottom := NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, Vector3(334, -2.6, 0))
	var round_path: PackedVector3Array = NavigationServer3D.map_get_path(get_world_3d().navigation_map, Vector3(326, 0, 0), Vector3(342, 0, 0), true)
	var swims := Array(round_path).any(func(p): return pool.over(p, 0.2) and p.y < 0.0)
	_check("L2 deep water is swum at its surface, never walked along its bottom; the way round is taken when it is not far",
		bottom.y > POOL_SURFACE - 0.2 and not swims and round_path.size() > 0,
		"nearest navmesh to the bottom at %.2f (surface %.2f); across the pool swims %s" % [bottom.y, POOL_SURFACE, swims])

	# ------------------------------------------------------------------
	# Guards after you
	# ------------------------------------------------------------------

	# G1 you up on the block: he climbs up after you
	await _fresh()
	_put_player(Vector3(0, 2.55, -6))
	var g1 := _guard(&"swordsman", Vector3(0, 0, 1.5), PI)
	var did1 := await _watch(g1, func(): return g1.global_position.y > 1.3, 720)
	_check("G1 you up on a block: he climbs up after you", g1.global_position.y > 1.3 and did1.has(&"climb"),
		"at %s, did %s" % [g1.global_position, did1])

	# G2 you below: he hops down after you
	await _fresh()
	_put_player(Vector3(0, 1.05, 1.5))
	var g2 := _guard(&"swordsman", Vector3(0, 1.5, -6), 0.0)
	var did2 := await _watch(g2, func(): return g2.global_position.y < 0.2, 600)
	_check("G2 you below: he hops down after you", g2.global_position.y < 0.2 and did2.has(&"fall") and did2.has(&"land"),
		"at %s, did %s" % [g2.global_position, did2])

	# G3 you on the tower: he goes up the ladder after you
	await _fresh()
	_put_player(Vector3(40, 4.55, -6.5))
	var g3 := _guard(&"swordsman", Vector3(40, 0, 2.0), PI)
	var did3 := await _watch(g3, func(): return g3.global_position.y > 3.3, 1200)
	_check("G3 you up a tower with a ladder: he climbs the ladder after you", g3.global_position.y > 3.3 and did3.has(&"ladder"),
		"at %s, did %s" % [g3.global_position, did3])

	# G4 you below a tower he stands on: he lowers himself off and drops,
	#    unhurt
	await _fresh()
	_put_player(Vector3(160, 1.05, 1.5))
	var g4 := _guard(&"swordsman", Vector3(160, 3.5, -6.5), 0.0)
	var did4 := await _watch(g4, func(): return g4.global_position.y < 0.2, 900)
	_check("G4 you below a tower: he lowers himself off the edge and drops, unhurt", g4.global_position.y < 0.2 and did4.has(&"hang") and g4.health == g4.max_health,
		"at %s, did %s, health %.0f/%.0f" % [g4.global_position, did4, g4.health, g4.max_health])

	# G5 you across the gap: he leaps it
	await _fresh()
	_put_player(Vector3(82.4, 2.55, -6))
	var g5 := _guard(&"swordsman", Vector3(77, 1.5, -6), -PI * 0.5)
	var did5 := await _watch(g5, func(): return g5.global_position.x > 80.6 and g5.global_position.y > 1.3, 720)
	_check("G5 you across a gap: he leaps it", g5.global_position.x > 80.6 and g5.global_position.y > 1.3 and did5.has(&"leap"),
		"at %s, did %s" % [g5.global_position, did5])

	# G6 struck on the ladder: he loses his hold and falls
	await _fresh()
	_put_player(Vector3(40, 4.55, -6.5))
	var g6 := _guard(&"swordsman", Vector3(40, 0, 2.0), PI)
	await _until(func(): return g6.activity() == &"ladder" and g6.global_position.y > 1.6, 900)
	var hit_at: float = g6.global_position.y
	g6.take_hit(4.0, player, &"quick", Vector3.ZERO, Vector3(0, 0, -1))
	await _until(func(): return g6.global_position.y < 0.3, 120)
	_check("G6 struck on a ladder, he loses his hold and falls", hit_at > 1.6 and g6.global_position.y < 0.3 and not g6._climb.active(),
		"struck %.1f m up, now at %.2f, climbing %s" % [hit_at, g6.global_position.y, g6._climb.active()])

	# G7 you up a wall with no way up: he cannot get to you
	await _fresh()
	_put_player(Vector3(120, 4.05, -6))
	var g7 := _guard(&"swordsman", Vector3(120, 0, 1.0), PI)
	await _frames(240)
	_check("G7 you up a bare 3 m wall: he cannot get to you, and does not try to climb it", g7._fighter.is_unreachable() and g7.global_position.y < 0.5 and not g7._climb.active(),
		"unreachable %s, at %s" % [g7._fighter.is_unreachable(), g7.global_position])

	# G8 you on the tower at its edge, him close under it: in a fight he
	#    looks up at you (steeper than his eyes see looking ahead), sees you,
	#    and comes up after you
	await _fresh()
	_put_player(Vector3(40, 4.55, -4.9))
	# Facing the tower, 2 m short of it: you are 54 degrees up. Held where he
	# is a second, to see whether he sees you.
	var looker := _guard(&"swordsman", Vector3(40, 0, -2.8), 0.0)
	looker.lose_time = GUARD_LOSE_TIME
	looker._fighter.stays_put = true
	var saw_up := 0.0

	for i in 60:
		await _frames(1)
		saw_up = maxf(saw_up, float(looker.visibility))

	looker._fighter.stays_put = false
	var did_look := await _watch(looker, func(): return looker.global_position.y > 3.3, 900)
	_check("G8 you up on a tower at its edge, him close under it: he looks up, sees you, and comes up after you",
		looker.global_position.y > 3.3 and did_look.has(&"ladder") and saw_up > 0.1,
		"at %s, did %s, saw you from below %.2f, state %d" % [looker.global_position, did_look, saw_up, int(looker.state)])

	# G9 the same in the dark, and he hears nothing of it: he saw you start
	#    up the ladder, so he knows where you went, and comes up after you
	await _fresh()
	_put_player(Vector3(40, 1.05, -2.2))
	# Well back, so it is dark before he is near enough to see you by touch.
	var follower := _guard(&"swordsman", Vector3(40, 0, 9.0), PI)
	follower.lose_time = GUARD_LOSE_TIME
	follower.hearing_acuity = 0.0
	await _climb_the_ladder(true)
	var did_follow := await _watch(follower, func(): return follower.global_position.y > 3.3, 900)
	_check("G9 up the ladder with him after you, the light goes and he hears nothing: he saw you go up, and comes up after you",
		follower.global_position.y > 3.3 and did_follow.has(&"ladder"),
		"at %s, did %s, state %d, last had you at %s" % [follower.global_position, did_follow, int(follower.state), follower.last_known_position])

	# G10 you stop partway up the ladder, him after you: he waits his turn
	#     (no climbing into you, no shoving you up it); you go on up, and he
	#     comes up behind you
	await _fresh()
	_put_player(Vector3(40, 1.05, -2.2))
	var waiter := _guard(&"swordsman", Vector3(40, 0, 3.5), PI)
	waiter.lose_time = GUARD_LOSE_TIME
	await _frames(20)
	Input.action_press("move_forward")
	await _until(func(): return player.movement_state == player.MoveState.CLIMBING and player.global_position.y > 2.6, 300)
	_release_all()
	var held_at: float = player.global_position.y
	var closest := INF

	for i in 240:
		await _frames(1)

		if waiter._climb.active():
			closest = minf(closest, player.get_feet_position().y - waiter.global_position.y)

	var stayed: bool = player.movement_state == player.MoveState.CLIMBING and absf(player.global_position.y - held_at) < 0.3
	var waited_at: Vector3 = waiter.global_position
	var waited: bool = waited_at.distance_to(Vector3(40, 0, -3.4)) < 1.6 and (closest == INF or closest > 1.7)
	Input.action_press("move_forward")
	await _until(func(): return player.movement_state == player.MoveState.LOCOMOTION and player.global_position.y > 4.3, 600)
	await _until(func(): return player.global_position.z < -6.3, 60)
	_release_all()
	var did_wait := await _watch(waiter, func(): return waiter.global_position.y > 3.3, 900)
	_check("G10 you stop partway up the ladder: he waits his turn at its foot, not into you; you go on up and he comes up behind you",
		stayed and waited and waiter.global_position.y > 3.3 and did_wait.has(&"ladder"),
		"you stayed %s, he waited %s (at %s, nearest below you %.2f), then at %s, did %s" % [stayed, waited, waited_at, closest, waiter.global_position, did_wait])

	# ------------------------------------------------------------------
	# Water
	# ------------------------------------------------------------------

	# W1 you in deep water: afloat with your eyes out, swimming; under at
	#    crouch; out onto the bank with a jump at it
	await _fresh()
	_put_player(Vector3(334, 0.8, 0))
	await _frames(150)
	var swam: bool = player.movement_state == player.MoveState.SWIMMING
	var eyes: float = player.neck.global_position.y
	Input.action_press("crouch")
	await _frames(40)
	Input.action_release("crouch")
	var under: bool = player.is_underwater()
	await _frames(120)
	# To the east wall, and up it.
	player.rotation.y = -PI * 0.5
	Input.action_press("move_forward")
	await _until(func(): return player.global_position.x > 336.6, 240)
	var out := [false]
	for i in 90:
		if i % 10 == 0:
			Input.action_press("jump")
		elif i % 10 == 2:
			Input.action_release("jump")
		await _frames(1)
		if player.movement_state != player.MoveState.SWIMMING:
			out[0] = true
	Input.action_release("move_forward")
	Input.action_release("jump")
	await _frames(90)
	_check("W1 you in deep water: afloat with your eyes over it, under it at crouch, and out onto the bank with a jump at it",
		swam and absf(eyes - (POOL_SURFACE + 0.12)) < 0.25 and under and out[0] and player.get_feet_position().y > -0.1 and player.global_position.x > 337.5,
		"swimming %s eyes %.2f (surface %.2f) under %s out %s at %s" % [swam, eyes, POOL_SURFACE, under, out[0], player.global_position])

	# W2 wading: slower in the shallows than on land
	await _fresh()
	player.rotation.y = -PI * 0.5
	_put_player(Vector3(270, 1.05, 0))
	player.rotation.y = -PI * 0.5
	Input.action_press("move_forward")
	await _frames(40)
	var dry: float = Vector2(player.velocity.x, player.velocity.z).length()
	await _until(func(): return player.global_position.x > 279.0, 240)
	await _frames(20)
	var wet: float = Vector2(player.velocity.x, player.velocity.z).length()
	var wading: String = player._surface_name()
	Input.action_release("move_forward")
	_check("W2 wading the shallows is slower, and it is water underfoot", wet < dry * 0.8 and wading == "water" and player.movement_state == player.MoveState.LOCOMOTION,
		"on land %.1f m/s, wading %.1f m/s, underfoot %s" % [dry, wet, wading])

	# W3 you in the water: he goes in after you and swims; no blows afloat
	await _fresh()
	_put_player(Vector3(335, 0.8, 0))
	var g8 := _guard(&"swordsman", Vector3(325, 0, 0), -PI * 0.5)
	g8._attack_timer = 0.0
	g8.attack_cooldown = 0.5
	var swung_afloat := [false]
	var did8 := await _watch(g8, func():
		swung_afloat[0] = swung_afloat[0] or (g8._water.swimming and g8._phase != &"")
		return g8._water.swimming and g8.global_position.distance_to(player.global_position) < 3.2, 900)
	_check("W3 you in the water: he goes in after you and swims, and swings no blow afloat",
		g8._water.swimming and did8.has(&"swim") and not swung_afloat[0],
		"swimming %s, %.1f m from you, did %s, swung afloat %s" % [g8._water.swimming, g8.global_position.distance_to(player.global_position), did8, swung_afloat[0]])

	# W4 you out on the far bank: he swims to it and climbs out after you
	await _fresh()
	_put_player(Vector3(343, 1.05, 0))
	var g9 := _guard(&"swordsman", Vector3(333, -1.6, 0), -PI * 0.5)
	var did9 := await _watch(g9, func(): return g9.global_position.y > -0.1 and g9.global_position.x > 338.0, 900)
	_check("W4 you on the far bank: he swims to it and climbs out after you", g9.global_position.x > 338.0 and g9.global_position.y > -0.1 and did9.has(&"climb"),
		"at %s, did %s" % [g9.global_position, did9])

	# W5 a crate in the water floats
	await _fresh()
	var crate := Props.crate(self, Vector3(334, 1.5, 1.5), 0.45, 2.5)
	await _frames(240)
	_check("W5 a crate thrown in the water floats", absf(crate.global_position.y - POOL_SURFACE) < 0.45,
		"crate at %.2f (surface %.2f, bottom -2.6)" % [crate.global_position.y, POOL_SURFACE])
	crate.queue_free()


# --------------------------------------------------------------------------

## A ladder up a south face: a ClimbVolume `height` tall centred at `at`.
func _ladder(at: Vector3, height: float) -> void:
	var volume := Area3D.new()
	volume.set_script(CLIMB)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.2, height, 0.7)
	shape.shape = box
	volume.add_child(shape)
	add_child(volume)
	volume.global_position = at


## The kinds of link (NavLinks) starting or ending within `reach` of `point`
## (flat), counted.
func _links_near(point: Vector3, reach: float) -> Dictionary:
	var kinds := {}

	for link in baker.get_node("TraversalLinks").get_children():
		var a: Vector3 = link.global_transform * (link as NavigationLink3D).start_position
		var b: Vector3 = link.global_transform * (link as NavigationLink3D).end_position

		for end in [a, b]:
			if Vector2(end.x - point.x, end.z - point.z).length() < reach:
				var kind: StringName = link.get_meta(&"kind")
				kinds[kind] = int(kinds.get(kind, 0)) + 1
				break

	return kinds


## Up to `max_frames`, until `done` (and half a second more, to see him
## land): what `g` did meanwhile (his activities).
func _watch(g: Node, done: Callable, max_frames: int) -> Dictionary:
	var did := {}
	var after := -1

	for i in max_frames:
		await _frames(1)

		if not is_instance_valid(g):
			break

		var doing: StringName = g.activity()

		if doing != &"":
			did[doing] = int(did.get(doing, 0)) + 1

		if after < 0 and done.call():
			after = 30

		if after >= 0:
			after -= 1

			if after <= 0:
				break

	return did


## A guard of `archetype` at `at`, facing `yaw`, fighting you, not striking
## until told.
func _guard(archetype: StringName, at: Vector3, yaw := 0.0) -> CharacterBody3D:
	var g: CharacterBody3D = GUARD.instantiate()
	g.archetype = archetype
	g.temperament = &"steady"
	g.debug_ai = false
	g.position = at
	g.rotation.y = yaw
	add_child(g)
	g._attack_timer = 999.0
	g.attack_cooldown = 999.0
	g.lose_time = 999.0
	g._engage(player)
	return g


## You, at the ladder's foot facing it: up it and onto the tower, and a step
## back from the edge (out of the sight of anyone at its foot but for his
## looking up). `dark`: the light goes once you are on the ladder.
func _climb_the_ladder(dark := false) -> void:
	await _frames(20)
	Input.action_press("move_forward")
	await _until(func(): return player.movement_state == player.MoveState.CLIMBING, 240)

	if dark:
		player.debug_light_level = 0.0

	await _until(func(): return player.movement_state == player.MoveState.LOCOMOTION and player.global_position.y > 4.3, 600)
	await _until(func(): return player.global_position.z < -6.3, 60)
	_release_all()


## A clean start: nobody left, nothing remembered, you away in the dark.
func _fresh() -> void:
	_release_all()

	for g in get_tree().get_nodes_in_group(&"guards"):
		g.remove_from_group(&"guards")
		g.set_physics_process(false)
		g.queue_free()

	for group in [&"bodies", &"dropped_weapons", &"dropped_lights"]:
		for thing in get_tree().get_nodes_in_group(group):
			thing.queue_free()

	SquadScript.clear_all()
	GarrisonScript.clear_all()
	_put_player(AWAY)
	player.debug_light_level = 1.0
	await _frames(5)


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
