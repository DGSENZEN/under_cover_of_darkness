extends Node3D
## The world answers you: what you do is heard, and your body shows it. Steps
## that sound like the floor and as loud as guards hear them, a landing that
## thuds and raises dust, hands that drag behind a turn and bob with a walk,
## guards you hear coming, doors, locks, loot, weapons drawn and put away, the
## bow raised to the eye, climbing, and a death that puts you on the floor.
##
## Sounds are checked by what is asked of the sound bank (Sfx.recording), so
## this runs without an audio device. Run with --fixed-fps 60: some checks
## look at what is drawn frame by frame (_paced says so if not).

const PLAYER := preload("res://Player.tscn")
const GUARD := preload("res://Guard.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")
const Fx := preload("res://scripts/Visual/Fx.gd")
const CLIMB := preload("res://scripts/PlayerUtils/ClimbVolume.gd")
const TemperamentScript := preload("res://scripts/AISystem/Temperament.gd")

var player: CharacterBody3D
var results: Array[String] = []
var _open_door: Node3D


func _ready() -> void:
	var paced: bool = await _paced()
	# Every guard at his class's own temperament: these checks are exact.
	TemperamentScript.rolling = false
	Props.block(self, Vector3(0, -0.5, 0), Vector3(200, 1, 200))
	Props.block(self, Vector3(30, 0.02, 0), Vector3(6, 0.04, 30), Color(0.5, 0.35, 0.2), "wood")   # a wooden floor
	Props.block(self, Vector3(-30, 1.5, 0), Vector3(4, 3, 4))                                        # a 3 m block to drop from
	Props.block(self, Vector3(60, 0.55, -2.0), Vector3(3, 1.1, 1.0))                                 # a ledge to mantle
	Props.block(self, Vector3(90, 2.5, -4.5), Vector3(3, 5, 3))                                      # a wall with a ladder

	var ladder := Area3D.new()
	ladder.set_script(CLIMB)
	var ladder_shape := CollisionShape3D.new()
	var ladder_box := BoxShape3D.new()
	ladder_box.size = Vector3(1.4, 5.0, 0.7)
	ladder_shape.shape = ladder_box
	ladder.add_child(ladder_shape)
	add_child(ladder)
	ladder.global_position = Vector3(90, 2.5, -2.65)

	# Doors in a wall: one open to anyone, one locked.
	Props.block(self, Vector3(-3.0, 1.25, 40), Vector3(5.0, 2.5, 0.3))
	Props.block(self, Vector3(3.5, 1.25, 40), Vector3(4.0, 2.5, 0.3))
	Props.block(self, Vector3(0.0, 2.3, 40), Vector3(1.0, 0.4, 0.3))
	_open_door = Props.door(self, Vector3(-0.5, 0, 40))
	Props.block(self, Vector3(12.0, 1.25, 40), Vector3(5.0, 2.5, 0.3))
	Props.block(self, Vector3(18.5, 1.25, 40), Vector3(4.0, 2.5, 0.3))
	Props.block(self, Vector3(15.0, 2.3, 40), Vector3(1.0, 0.4, 0.3))
	Props.door(self, Vector3(14.5, 0, 40), 0.0, 1.0, 2.1, true, &"vault_key")

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

	player.debug_light_level = 0.0
	player.global_position = Vector3(0, 1.05, 10)
	Props.give_weapons(player)

	await baker.baked
	await _frames(10)
	Sfx.recording = true
	await _run()
	Sfx.recording = false

	print("\n==== RESULTS ====")

	if not paced:
		print("NOTE  frames are not paced: run with --fixed-fps 60 (checks here look at what is drawn frame by frame)")
	for r in results:
		print(r)

	get_tree().quit()


func _run() -> void:
	var hand: Node3D = player.hand

	# L1 your steps sound like the floor
	_put_player(Vector3(0, 1.05, 10), 0.0)
	await _frames(10)
	Sfx.recorded.clear()
	Input.action_press("move_forward")
	await _frames(70)
	_release_all()
	var on_stone := _count(&"step_stone")
	_put_player(Vector3(30, 1.1, 12), 0.0)
	await _frames(10)
	Sfx.recorded.clear()
	Input.action_press("move_forward")
	await _frames(70)
	_release_all()
	var on_wood := _count(&"step_wood")
	_check("L1 steps sound like the floor", on_stone >= 3 and on_wood >= 3 and _count(&"step_stone") == 0,
		"stone steps %d, wood steps %d" % [on_stone, on_wood])

	# L2 sneaking is quieter, sprinting louder, as guards hear it
	var walk_volume := await _step_volume([])
	var sneak_volume := await _step_volume(["crouch"])
	var run_volume := await _step_volume(["sprint"])
	_check("L2 sneaking steps are quieter and running steps louder", sneak_volume < walk_volume - 3.0 and run_volume > walk_volume + 2.0,
		"sneak %.1f dB walk %.1f dB run %.1f dB" % [sneak_volume, walk_volume, run_volume])

	# L3 a hard landing thuds and raises dust: dropped from 4 m
	_put_player(Vector3(-50, 5.1, 0), 0.0)
	Sfx.recorded.clear()
	var dust := 0

	for i in 90:
		await _frames(1)
		dust = maxi(dust, Fx.live(Fx.Kind.DUST))

	# (The landing is the floor's own: land_stone here.)
	_check("L3 a hard landing thuds and raises dust", _count(&"land_stone") == 1 and dust > 0,
		"land sounds %d dust %d" % [_count(&"land_stone"), dust])

	# L4 the hands drag behind a turn and swing back
	_put_player(Vector3(0, 1.05, 10), 0.0)
	await _frames(20)
	await get_tree().process_frame
	player.rotate_y(0.5)
	var dragged := 0.0

	for i in 6:
		await get_tree().process_frame
		dragged = maxf(dragged, absf(hand.sway().x))

	await _frames(60)
	_check("L4 the hands drag behind a turn and settle", dragged > 0.05 and hand.sway().length() < 0.01,
		"dragged %.3f rad, after %.4f" % [dragged, hand.sway().length()])

	# L5 the hands bob in step with the walk
	await _frames(10)
	var heights := []
	Input.action_press("move_forward")
	await _frames(30)

	for i in 60:
		await get_tree().process_frame
		heights.append(hand.get_node("MainHand").position.y)

	_release_all()
	_check("L5 the hands bob with the walk", heights.max() - heights.min() > 0.006,
		"hand height range %.4f m" % (heights.max() - heights.min()))

	# L6 you hear a guard coming: mail and boots
	var route := Node3D.new()
	route.name = "Route"
	add_child(route)

	for at in [Vector3(-8, 0, 20), Vector3(-8, 0, 0)]:
		var point := Node3D.new()
		point.position = at
		route.add_child(point)

	var guard: CharacterBody3D = GUARD.instantiate()
	guard.position = Vector3(-8, 0, 20)
	guard.patrol_route = NodePath("../Route")
	guard.patrol_wait = 0.1
	add_child(guard)
	Sfx.recorded.clear()
	await _frames(150)
	# Mail and boots on the floor he walks (stone, unnamed).
	var armor := _count(&"step_stone_chain")
	_check("L6 a walking guard's steps are heard", armor >= 4, "armoured steps %d" % armor)
	guard.queue_free()

	# L7 doors creak open, thud shut, and rattle when locked
	_put_player(Vector3(0, 1.05, 41.8), PI)
	_aim(Vector3(0.0, 1.2, 40.0))
	await _frames(10)
	Sfx.recorded.clear()
	await _tap("frob")
	await _frames(70)
	var opened := _count(&"door_open")
	# Swung open, the panel is no longer where the doorway is: close it by hand.
	_open_door.frob(player)
	await _frames(90)
	var shut := _count(&"door_close")
	_put_player(Vector3(15, 1.05, 41.8), PI)
	_aim(Vector3(15.0, 1.2, 40.0))
	await _frames(10)
	await _tap("frob")
	await _frames(20)
	_check("L7 a door creaks open and thuds shut; a locked one rattles", opened == 1 and shut == 1 and _count(&"door_rattle") == 1,
		"open %d shut %d rattle %d" % [opened, shut, _count(&"door_rattle")])

	# L8 loot clinks into the purse, keys jingle onto the ring
	var loot := Props.loot(self, Vector3(40, 0.3, 58.8), 25)
	var key := Props.key(self, Vector3(41, 0.3, 58.8), &"cellar")
	await _frames(60)
	# A step away: something on the floor is at the edge of reach from 1.2 m.
	_put_player(Vector3(40, 1.05, 59.6), 0.0)
	_aim(loot.global_position)
	await _frames(10)
	Sfx.recorded.clear()
	await _tap("frob")
	await _frames(60)
	_put_player(Vector3(41, 1.05, 59.6), 0.0)
	_aim(key.global_position)
	await _frames(10)
	await _tap("frob")
	await _frames(60)
	_check("L8 loot clinks into the purse and a key jingles onto the ring", _count(&"coins") == 1 and _count(&"keys") == 1,
		"coins %d keys %d" % [_count(&"coins"), _count(&"keys")])

	# L9 a blade is drawn singing and put away with a slide
	_put_player(Vector3(0, 1.05, 10), 0.0)
	player.inventory.select_by_id(&"bow")
	await _frames(40)
	Sfx.recorded.clear()
	player.inventory.select_by_id(&"sword")
	await _frames(40)
	var drawn := _count(&"blade_draw")
	player.inventory.select_by_id(&"bow")
	await _frames(40)
	_check("L9 a sword is drawn with a ring and sheathed with a slide", drawn == 1 and _count(&"sheath") == 1,
		"drawn %d sheathed %d" % [drawn, _count(&"sheath")])

	# L10 the bow comes up to the eye as it is drawn
	await _frames(20)
	var rest: Vector3 = hand.weapon_frame().origin
	Sfx.recorded.clear()
	Input.action_press("throw")
	await _frames(60)
	var raised: Vector3 = hand.weapon_frame().origin
	# The arrow (the bow's -Z) along your line of sight.
	var along: float = hand.weapon_frame().basis.z.normalized().z
	Input.action_press("block")
	await _frames(2)
	_release_all()
	await _frames(10)
	_check("L10 the bow comes up into the middle of the view when drawn, the arrow along your sight, and creaks", raised.y > rest.y + 0.06 and absf(raised.x) < absf(rest.x) and along > 0.95 and _count(&"bow_draw") == 1,
		"rest %s drawn %s arrow along the view %.2f creak %d" % [rest, raised, along, _count(&"bow_draw")])
	player.inventory.select_by_id(&"sword")

	# L11 climbing is heard: hand over hand up a ladder
	_put_player(Vector3(90, 1.05, 0.0), 0.0)
	await _frames(10)
	Sfx.recorded.clear()
	Input.action_press("move_forward")
	await _until(func(): return player.movement_state == 3, 180)
	var contacts = hand._contacts
	var higher := -1
	var swaps := 0
	var both := 0

	for i in 90:
		await _frames(1)
		var up := 0 if contacts.hand(0).origin.y >= contacts.hand(1).origin.y else 1

		if higher >= 0 and up != higher:
			swaps += 1

		higher = up

		if contacts.weight(0) > 0.9 and contacts.weight(1) > 0.9:
			both += 1

	_release_all()
	var holds := _count(&"grab")
	_check("L11 climbing a ladder is heard hand over hand", holds >= 2, "hand holds %d" % holds)
	_check("L16 up a ladder the hands go over each other, both holding", swaps >= 2 and both > 45,
		"higher hand changed %d times, both holding %d/90 frames" % [swaps, both])
	await _frames(60)

	# L15 hanging from a ledge: two hands on the lip, the weapon put away
	Props.block(self, Vector3(-80, 1.8, -4.5), Vector3(4, 3.6, 3))
	_put_player(Vector3(-80, 1.05, -1.5), 0.0)
	player.inventory.select_by_id(&"sword")
	await _frames(30)
	Input.action_press("move_forward")
	await _frames(40)
	Input.action_press("jump")
	var early_grabs := 0

	for i in 150:
		await _frames(1)

		# The right hand only takes hold once the sword is out of sight.
		if hand._grip_weights[1] > 0.03 and hand.is_item_visible():
			early_grabs += 1

		if player.movement_state == 2 and i > 30:
			break

	_release_all()
	await _frames(30)
	var grips := 0

	for point in hand.grip_points():
		if player.camera.is_position_in_frustum(point):
			grips += 1

	_check("L15 hanging shows both hands on the lip and puts the weapon away", player.movement_state == 2 and grips == 2 and not hand.is_item_visible() and early_grabs == 0,
		"state %d hands in view %d weapon up %s, right hand held on with the sword in sight %d frames" % [player.movement_state, grips, hand.is_item_visible(), early_grabs])

	# L17 shuffling along the ledge: the hands stay where they hold and go on
	#     one at a time, never sliding along with the body.
	var lip: float = player.hang_lip_y
	var before := [contacts.hand(0).origin, contacts.hand(1).origin]
	var sliding := 0
	var moves := 0
	Input.action_press("move_right")

	for i in 60:
		await _frames(1)
		var now := [contacts.hand(0).origin, contacts.hand(1).origin]
		var moved := 0

		for side in 2:
			if (now[side] as Vector3).distance_to(before[side]) > 0.004:
				moved += 1

		if moved == 2:
			sliding += 1
		elif moved == 1:
			moves += 1

		before = now

	_release_all()
	await _frames(20)
	var on_lip: bool = absf(contacts.hand(0).origin.y - lip) < 0.05 and absf(contacts.hand(1).origin.y - lip) < 0.05
	_check("L17 shuffling along a ledge moves one hand at a time and both stay on the lip", sliding == 0 and moves > 5 and on_lip and player.movement_state == 2,
		"both moving %d frames, one moving %d, on the lip %s" % [sliding, moves, on_lip])
	player.movement_state = 0
	await _frames(20)

	# L12 a mantle scuffs
	_put_player(Vector3(60, 1.05, 0.0), 0.0)
	await _frames(10)
	Sfx.recorded.clear()
	Input.action_press("move_forward")
	await _frames(20)
	await _tap("jump")
	# L18 mantling with a sword in hand: the left hand goes down flat on the
	#     top and stays there, in sight, while the sword stays up in the right.
	var planted := Vector3.INF
	var drift := 0.0
	var seen := 0
	var right_held := 0.0
	var sword_down := 0

	for i in 80:
		await _frames(1)

		if hand._grip_weights[0] > 0.9:
			var at: Vector3 = contacts.hand(0).origin

			if planted == Vector3.INF:
				planted = at

			drift = maxf(drift, at.distance_to(planted))

			for point in hand.grip_points():
				if player.camera.is_position_in_frustum(point):
					seen += 1

		right_held = maxf(right_held, hand._grip_weights[1])

		if player.movement_state == 1 and not hand.is_item_visible():
			sword_down += 1

	_release_all()
	_check("L12 a mantle scuffs", _count(&"scuff") >= 1, "scuffs %d (sounds %s)" % [_count(&"scuff"), _names()])
	_check("L18 a mantle with a sword plants the left hand on the top, in sight, and keeps the sword up", planted != Vector3.INF and drift < 0.01 and seen >= 4 and right_held == 0.0 and sword_down == 0,
		"planted %s drift %.3f frames in sight %d right hand %.2f sword down %d" % [planted != Vector3.INF, drift, seen, right_held, sword_down])

	# L14 being noticed has a sound: a swell as he grows suspicious, a stab as
	#     he comes for you
	var watcher: CharacterBody3D = GUARD.instantiate()
	watcher.position = Vector3(-60, 0, 44)
	# Facing you.
	watcher.rotation.y = PI
	add_child(watcher)
	_put_player(Vector3(-60, 1.05, 50), 0.0)
	player.debug_light_level = 0.0
	# The HUD looks for guards to listen to once a second.
	await _frames(80)
	Sfx.recorded.clear()
	player.debug_light_level = 1.0
	await _until(func(): return watcher.state == 4, 400)
	await _frames(5)
	_check("L14 a guard noticing you swells, and coming for you stabs", _count(&"sting_suspicious") == 1 and _count(&"sting_combat") == 1,
		"state %d swells %d stabs %d" % [watcher.state, _count(&"sting_suspicious"), _count(&"sting_combat")])
	player.debug_light_level = 0.0
	watcher.queue_free()
	await _frames(10)

	# L13 death puts you on the floor
	_put_player(Vector3(0, 1.05, 10), 0.0)
	await _frames(10)
	Sfx.recorded.clear()
	player.invulnerable = false
	player.take_damage(1000.0, null)
	await _frames(80)
	var eye_drop: float = player.neck.global_position.y - player.camera.global_position.y
	_check("L13 dying drops the view to the floor", player.is_dead and eye_drop > 1.0 and _count(&"body_fall") == 1,
		"dead %s view %.2f m under the eye, thud %d" % [player.is_dead, eye_drop, _count(&"body_fall")])


# --------------------------------------------------------------------------

## The average loudness of your steps while walking with `held` pressed.
func _step_volume(held: Array) -> float:
	_put_player(Vector3(0, 1.05, 10), 0.0)
	await _frames(10)

	for action in held:
		Input.action_press(action)

	await _frames(20)
	Sfx.recorded.clear()
	Input.action_press("move_forward")
	await _frames(90)
	_release_all()
	await _frames(20)
	var total := 0.0
	var count := 0

	for entry in Sfx.recorded:
		if String(entry[0]).begins_with("step_"):
			total += float(entry[1])
			count += 1

	return total / maxf(count, 1)


func _count(sound: StringName) -> int:
	var n := 0

	for entry in Sfx.recorded:
		if entry[0] == sound:
			n += 1

	return n


func _names() -> Array:
	var names := []

	for entry in Sfx.recorded:
		if not names.has(entry[0]):
			names.append(entry[0])

	return names


func _put_player(at: Vector3, yaw: float) -> void:
	_release_all()
	player.movement_state = 0
	player.current_move = null
	player.current_climb = null
	player.velocity = Vector3.ZERO
	player.global_position = at
	player.rotation.y = yaw
	player.neck.rotation.x = 0.0
	player.combat._reset()
	player.reset_physics_interpolation()


func _aim(target: Vector3) -> void:
	var eye: Vector3 = player.neck.global_position
	var d := target - eye
	player.rotation.y = atan2(-d.x, -d.z)
	player.neck.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())


func _release_all() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "jump", "sprint", "crouch", "frob", "throw", "block", "kick"]:
		if InputMap.has_action(a):
			Input.action_release(a)


func _tap(action: String) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)


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


## Whether every frame is a fixed 60th of a second (run with --fixed-fps 60,
## as the suites are meant to be run). Some checks here look at what is drawn
## frame by frame; without it the machine's own frame rate decides how many
## physics ticks fall in a frame, and those checks do not hold.
func _paced() -> bool:
	for i in 3:
		await get_tree().process_frame

		if not is_equal_approx(get_process_delta_time(), 1.0 / 60.0):
			return false

	return true
