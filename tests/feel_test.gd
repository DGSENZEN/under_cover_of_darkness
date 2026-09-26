extends Node3D
## Combat feel: what a blow looks, sounds and feels like. Blood and where it
## lands, sparks and their light, hit-stop, the guard's reactions and fall,
## arrows that stay in, blade trails, and the rule that none of it touches
## gameplay (the lightgem, the guards' eyes, where a blow goes).

const PLAYER := preload("res://Player.tscn")
const GUARD_SCRIPT := preload("res://scripts/AISystem/Guard.gd")
const GUARD := preload("res://Guard.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")
const LightProbe := preload("res://scripts/StimuliSystem/LightProbe.gd")
const Fx := preload("res://scripts/Visual/Fx.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")
const TimeFx := preload("res://scripts/Visual/TimeFx.gd")
const Layers := preload("res://scripts/Visual/Layers.gd")

var player: CharacterBody3D
var baker: NavigationRegion3D
var results: Array[String] = []


func _ready() -> void:
	# Exact damage is checked here: cuts do not go on bleeding.
	GUARD_SCRIPT.bleeding_on = false
	Sfx.enabled = true
	Props.block(self, Vector3(0, -0.5, 0), Vector3(160, 1, 100))            # floor
	Props.block(self, Vector3(0, 1.5, -3.6), Vector3(4, 3, 0.3))             # F2 wall behind the guard
	Props.block(self, Vector3(-20, 1.5, -1.0), Vector3(4, 3, 0.3))           # F16 wall to swing at

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

	player.debug_light_level = 0.0
	player.global_position = Vector3(60, 1.05, 40)
	Props.give_weapons(player)

	await baker.baked
	await _frames(5)
	await _run()

	print("\n==== RESULTS ====")
	for r in results:
		print(r)

	# Let every sound stop before leaving, or the audio server reports them.
	# Headless frames run far faster than real time: give the audio thread a
	# real moment to let go of what it was playing.
	Sfx.silence()
	TimeFx.clear()
	await _frames(3)
	OS.delay_msec(300)
	await _frames(3)
	get_tree().quit()


func _run() -> void:
	var combat: Node = player.combat
	var hand: Node3D = player.hand
	_wield(&"sword")

	# F1 a blow that lands: blood, a wound, a freeze, a jolt, a bloody blade
	var g1 := _fighter(Vector3(0, 0, -1.5))
	_put_player(Vector3(0, 1.05, 0))
	await _frames(20)
	var stains_before := Fx.stains_in_use()
	var lowest := [1.0]
	var trauma := [0.0]
	Input.action_press("throw")
	await _frames(2)
	Input.action_release("throw")

	for i in 40:
		await _frames(1)
		lowest[0] = minf(lowest[0], Engine.time_scale)
		trauma[0] = maxf(trauma[0], player.juice.trauma())

	var blood_flew := Fx.live(Fx.Kind.BLOOD) > 0 or Fx.stains_in_use() > stains_before
	_check("F1 a landed blow bleeds, marks him, freezes time, jolts the view, bloodies the blade",
		g1.health < g1.max_health and blood_flew and g1._rig.wound_count() == 1 and lowest[0] < 0.2 and Engine.time_scale == 1.0 and trauma[0] > 0.05 and hand.blood_on_blade() > 0.1,
		"health %.0f blood %s wounds %d lowest time scale %.2f now %.2f trauma %.2f blade blood %.2f" % [g1.health, blood_flew, g1._rig.wound_count(), lowest[0], Engine.time_scale, trauma[0], hand.blood_on_blade()])

	# F2 the spray lands: a splat on the wall behind him, drops on the floor
	await _frames(90)
	var stains_after := Fx.stains_in_use()
	_check("F2 blood splats the wall behind him and spots the floor", stains_after - stains_before >= 3,
		"stains %d -> %d" % [stains_before, stains_after])
	g1.queue_free()

	# F3 a blocked blow throws sparks and a flash that lights nobody up
	var g3 := _fighter(Vector3(0, 0, -1.5))
	g3.block_chance = 1.0
	_put_player(Vector3(0, 1.05, 0))
	await _frames(20)
	var landed := []
	combat.landed.connect(func(t, r, d): landed.append(r), CONNECT_ONE_SHOT)
	var light_before := LightProbe.light_at(self, Vector3(0, 1.3, -1.0))
	Input.action_press("throw")
	await _frames(2)
	Input.action_release("throw")
	var saw_sparks := false
	var lit := false
	var light_during := -1.0
	var fx_light_ok := true

	for i in 30:
		await _frames(1)

		if Fx.live(Fx.Kind.SPARK) > 0:
			saw_sparks = true

		if Fx.lights_lit() > 0 and not lit:
			lit = true
			LightProbe.invalidate()
			light_during = LightProbe.light_at(self, Vector3(0, 1.3, -1.0))

			for light in get_tree().get_nodes_in_group(&"fx_light"):
				if ((light as Light3D).light_cull_mask & Layers.GEM_PROBE) != 0:
					fx_light_ok = false

	_check("F3 a blocked blow sparks and flashes, and the flash lights no one for the guards or the gem",
		landed.size() > 0 and landed[0] == &"blocked" and saw_sparks and lit and fx_light_ok and absf(light_during - light_before) < 0.001,
		"result %s sparks %s flash %s gem-safe %s probe %.3f -> %.3f" % [landed, saw_sparks, lit, fx_light_ok, light_before, light_during])
	g3.queue_free()

	# F4 he reels away from the blow: a slash to the right tips him right
	var g4 := _fighter(Vector3(0, 0, -1.5))
	_put_player(Vector3(0, 1.05, 0))
	await _frames(20)
	# A flick of the view to the right as the blow starts: a slash to the right.
	combat.add_look_motion(Vector2(-0.2, 0.0))
	Input.action_press("throw")
	await _frames(2)
	Input.action_release("throw")
	await _frames(8)
	var tipped := 0.0

	for i in 30:
		await _frames(1)
		var rig: Node3D = g4._rig
		# The top of him in world space, relative to his feet.
		var lean: Vector3 = rig.global_transform.basis.y
		tipped = maxf(tipped, lean.x)

	_check("F4 a slash to the right tips him to the right", g4.health < g4.max_health and tipped > 0.05,
		"health %.0f lean toward the cut %.3f" % [g4.health, tipped])
	g4.queue_free()
	await _frames(20)

	# F5 his blow is telegraphed: the blade goes up, glints, then smears down
	player.invulnerable = true
	var g5 := _fighter(Vector3(0, 0, -1.3))
	g5._attack_timer = 0.0
	g5.attack_cooldown = 5.0
	_put_player(Vector3(0, 1.05, 0))
	var highest := 0.0
	var glinted := false
	var smeared := 0

	for i in 120:
		await _frames(1)

		if g5._phase == &"windup":
			# The tip of his blade, over his head.
			var blade: Transform3D = g5._rig.weapon.global_transform
			highest = maxf(highest, (blade * g5._rig.weapon.mesh.get_meta(&"blade_tip", Vector3.UP)).y - g5.global_position.y)

			if Fx.live(Fx.Kind.GLINT) > 0:
				glinted = true

		smeared = maxi(smeared, g5._rig.trail.sample_count())

		if g5._phase == &"recover":
			break

	_check("F5 his sword rises and glints before it falls, and leaves a smear", highest > 1.9 and glinted and smeared >= 3,
		"highest tip %.2f glint %s trail samples %d" % [highest, glinted, smeared])
	g5.queue_free()
	await _frames(10)

	# F6 a killing blow: he topples the way it went, keeps his wounds, drops
	#    his sword, and bleeds a pool
	var g6 := _fighter(Vector3(0, 0, -1.5))
	# Hurt, but not so weak that the blow takes him apart (Humanoid.sever).
	g6.max_health = 40.0
	g6.health = 20.0
	_put_player(Vector3(0, 1.05, 0))
	await _frames(20)
	var stains_pre := Fx.stains_in_use()
	await _tap("throw")
	var g6_id := g6.get_instance_id()
	await _until(func(): return not is_instance_id_valid(g6_id), 40)
	await _frames(2)
	var corpse := _last_body()
	var falling: bool = corpse != null and corpse.is_falling()
	var wounds_moved := 0

	if corpse != null:
		for child in corpse.find_children("*", "", true, false):
			if child.has_meta(&"wound"):
				wounds_moved += 1

	var sword := _find_named("DroppedSword")
	# He falls as physics has him (Ragdoll.gd): given the time a body takes.
	await _until(func(): return corpse == null or not corpse.is_falling(), 180)
	await _frames(40)
	var settled: bool = corpse != null and not corpse.is_falling()
	var pooled := Fx.stains_in_use() > stains_pre
	# Struck from the south, he goes down to the north: his head end, -Z.
	var head_end: Vector3 = -corpse.global_basis.z if corpse != null else Vector3.ZERO
	_check("F6 he topples away from the killing blow, keeps his wounds, drops his sword, and bleeds",
		not is_instance_valid(g6) and falling and settled and wounds_moved >= 1 and sword != null and pooled and head_end.z < -0.5,
		"falling %s settled %s wounds on the body %d sword %s pooled %s head toward %s" % [falling, settled, wounds_moved, sword != null, pooled, head_end])

	# F7 an arrow that hits him stays in him, and in his body after
	_wield(&"bow")
	var g7 := _fighter(Vector3(10, 0, -8))
	g7.health = 200.0
	g7.chase_speed = 0.0
	_put_player(Vector3(10, 1.05, 0))
	await _frames(20)
	_aim(Vector3(10, 1.2, -8))
	await _frames(3)
	Input.action_press("throw")
	await _frames(30)
	Input.action_release("throw")
	await _frames(40)
	var in_him: int = g7._rig.arrow_count()
	var health_after_one: float = g7.health
	var arrows_left: int = combat.arrow_count()
	g7.health = 1.0
	_aim(Vector3(10, 1.0, -8))
	await _frames(3)
	Input.action_press("throw")
	await _frames(30)
	Input.action_release("throw")
	await _frames(40)
	var body7 := _last_body()
	var in_body := 0

	if body7 != null and body7 != corpse:
		for child in body7.find_children("*", "", true, false):
			if child.has_meta(&"embedded_arrow"):
				in_body += 1

	_check("F7 arrows stay in him, and go down with him", in_him == 1 and not is_instance_valid(g7) and in_body == 2,
		"in him %d (health %.0f, quiver %d) dead %s in the body %d" % [in_him, health_after_one, arrows_left, not is_instance_valid(g7), in_body])

	# F8 your blade smears the air while it cuts, and not at rest
	_wield(&"sword")
	_put_player(Vector3(0, 1.05, 20))
	await _frames(30)
	var most := 0
	Input.action_press("throw")
	await _frames(2)
	Input.action_release("throw")

	for i in 20:
		await _frames(1)
		most = maxi(most, hand.trail_samples())

	await _frames(40)
	_check("F8 your blade leaves a trail while cutting, none at rest", most >= 3 and hand.trail_samples() == 0 and not hand.is_trail_on(),
		"samples while cutting %d at rest %d" % [most, hand.trail_samples()])

	# F9 a finisher's slow motion survives the hit-stop inside it. (Made a
	#    second long here, so there is room to see it resume.)
	var g9 := _fighter(Vector3(0, 0, -1.5))
	_put_player(Vector3(0, 1.05, 0))
	await _frames(20)
	combat.adrenaline = combat.adrenaline_max
	var finisher_time: float = combat.finisher_time
	combat.finisher_time = 1.0
	Input.action_press("throw")
	await _frames(50)
	Input.action_release("throw")
	var scales := []

	for i in 90:
		await _frames(1)
		scales.append(Engine.time_scale)

	combat.finisher_time = finisher_time
	var lowest_scale: float = scales.min()
	var froze_at: int = scales.find(lowest_scale)
	var resumed := false

	for i in range(froze_at, 55):
		resumed = resumed or is_equal_approx(scales[i], combat.finisher_time_scale)

	_check("F9 the finisher's slow motion holds through its hit-stop, then time returns", not is_instance_valid(g9) and lowest_scale < 0.1 and resumed and Engine.time_scale == 1.0,
		"alive %s lowest %.2f at frame %d, slow again after %s, now %.2f" % [is_instance_valid(g9), lowest_scale, froze_at, resumed, Engine.time_scale])

	# F10 the view shakes; the blow does not
	var g10 := _fighter(Vector3(0, 0, -1.5))
	_put_player(Vector3(0, 1.05, 0))
	await _frames(20)
	player.juice.add_trauma(1.0)
	var camera_off := 0.0
	var aim_true := true

	# The shake is a sum of sines: take its largest swing over a few frames,
	# not one instant that may fall where they cancel.
	for i in 12:
		await _frames(1)
		camera_off = maxf(camera_off, player.camera.global_basis.z.angle_to(player.neck.global_basis.z))
		aim_true = aim_true and combat.aim().basis.z.is_equal_approx(player.neck.global_basis.orthonormalized().z)
	player.juice.add_trauma(1.0)
	await _tap("throw")
	await _frames(30)
	_check("F10 camera shake moves the view, not the blow", camera_off > 0.01 and aim_true and g10.health < g10.max_health,
		"camera off the aim by %.4f rad, aim from the head %s, hit %s" % [camera_off, aim_true, g10.health < g10.max_health])
	g10.queue_free()

	# F11 effects are bounded and go away
	for i in 60:
		Fx.blood(self, Vector3(randf_range(-3, 3), 1.2, randf_range(-3, 3)), Vector3.FORWARD, 2.0)
		Fx.sparks(self, Vector3(0, 1.0, 5), Vector3.UP, 2.0)

	var peak_blood := Fx.live(Fx.Kind.BLOOD)
	var peak_stains := Fx.stains_in_use()
	# (A part cut off earlier may still be dripping for a few seconds.)
	await _frames(200)
	await _until(func(): return Fx.live(Fx.Kind.BLOOD) == 0 and Fx.live(Fx.Kind.SPARK) == 0 and Fx.live(Fx.Kind.MIST) == 0, 300)
	_check("F11 effects stay within their pools and die away", peak_blood <= 320 and peak_stains <= Fx.DECAL_POOL and Fx.live(Fx.Kind.BLOOD) == 0 and Fx.live(Fx.Kind.SPARK) == 0 and Fx.live(Fx.Kind.MIST) == 0,
		"blood peak %d stains %d, after: blood %d sparks %d mist %d" % [peak_blood, peak_stains, Fx.live(Fx.Kind.BLOOD), Fx.live(Fx.Kind.SPARK), Fx.live(Fx.Kind.MIST)])

	# F12 with gore off, blows draw no blood
	Fx.gore = 0.0
	var g12 := _fighter(Vector3(0, 0, -1.5))
	_put_player(Vector3(0, 1.05, 0))
	await _frames(20)
	await _tap("throw")
	await _frames(40)
	_check("F12 gore off: no blood, no wounds", g12.health < g12.max_health and Fx.live(Fx.Kind.BLOOD) == 0 and g12._rig.wound_count() == 0,
		"health %.0f blood %d wounds %d" % [g12.health, Fx.live(Fx.Kind.BLOOD), g12._rig.wound_count()])
	Fx.gore = 1.0
	g12.queue_free()

	# F13 his blow lands on you: a freeze, your head snapped away, a mark on
	#     the side it came from
	player.invulnerable = false
	player.health = player.max_health
	var g13 := _fighter(Vector3(1.0, 0, -1.0))
	g13._attack_timer = 0.0
	g13.attack_cooldown = 5.0
	_put_player(Vector3(0, 1.05, 0))
	var froze := false
	var marked := 0
	var shaken := 0.0

	for i in 150:
		await _frames(1)

		if player.health < player.max_health:
			froze = froze or Engine.time_scale < 0.2
			marked = maxi(marked, player.hud.hurt_mark_count())
			shaken = maxf(shaken, player.juice.trauma())

			if i > 0 and marked > 0 and shaken > 0.0:
				break

	_check("F13 a blow that lands on you freezes, jolts, and marks where it came from", player.health < player.max_health and froze and marked >= 1 and shaken > 0.1,
		"health %.0f froze %s marks %d trauma %.2f" % [player.health, froze, marked, shaken])
	player.invulnerable = true
	g13.queue_free()
	await _frames(30)

	# F14 steel and flesh are heard
	var g14 := _fighter(Vector3(0, 0, -1.5))
	_put_player(Vector3(0, 1.05, 0))
	await _frames(20)
	await _tap("throw")
	var sounding := 0

	for i in 30:
		await _frames(1)
		sounding = maxi(sounding, Sfx.player_count())
	_check("F14 blows make sound", sounding >= 2, "players sounding %d" % sounding)
	g14.queue_free()

	# F15 the kick: he folds with it and his feet skid, throwing up dust
	var g15 := _fighter(Vector3(0, 0, -1.2))
	_put_player(Vector3(0, 1.05, 0))
	await _frames(20)
	await _tap("kick")
	var dust := 0
	var folded := 0.0

	for i in 40:
		await _frames(1)
		dust = maxi(dust, Fx.live(Fx.Kind.DUST))
		folded = maxf(folded, -g15._rig.global_transform.basis.y.z)

	_check("F15 a kicked guard folds back and skids in a cloud of dust", folded > 0.1 and dust > 0,
		"lean back %.3f dust %d" % [folded, dust])
	g15.queue_free()

	# F16 a swing into a wall: sparks, a scratch, and the blade thrown back
	_put_player(Vector3(-20, 1.05, 0.0))
	await _frames(30)
	Fx.clear()
	var scratches_before := Fx.stains_in_use()
	var bounced := []
	combat.deflected.connect(func(p): bounced.append(p), CONNECT_ONE_SHOT)
	await _tap("throw")
	var threw_sparks := false
	var recoiled := 0.0

	for i in 20:
		await _frames(1)
		threw_sparks = threw_sparks or Fx.live(Fx.Kind.SPARK) > 0
		recoiled = maxf(recoiled, hand._recoil.length())

	_check("F16 a blade turned by a wall sparks, scratches it, and kicks back", bounced.size() == 1 and threw_sparks and Fx.stains_in_use() > scratches_before and recoiled > 0.01,
		"deflected %d sparks %s stains %d -> %d recoil %.3f" % [bounced.size(), threw_sparks, scratches_before, Fx.stains_in_use(), recoiled])


# --------------------------------------------------------------------------
func _wield(weapon_id: StringName) -> void:
	player.inventory.select_by_id(weapon_id)


## A guard already fighting you, facing you, who will not strike first.
## Lit, so he can see who he is fighting.
func _fighter(at: Vector3) -> CharacterBody3D:
	player.debug_light_level = 1.0
	var g: CharacterBody3D = GUARD.instantiate()
	g.debug_ai = false
	g.position = at
	add_child(g)
	g.block_chance = 0.0
	g._attack_timer = 999.0
	g.attack_cooldown = 999.0
	g.rotation.y = PI
	g._engage(player)
	return g


func _last_body() -> Node3D:
	var found: Node3D = null

	# A man's body, not a part cut off one (SeveredPart.gd).
	for b in get_tree().get_nodes_in_group(&"bodies"):
		if b.get("part") == null:
			found = b

	return found


func _find_named(prefix: String) -> Node:
	for child in get_children():
		if String(child.name).begins_with(prefix):
			return child

	return null


func _put_player(at: Vector3) -> void:
	_release_all()
	player.movement_state = 0
	player.current_move = null
	player.velocity = Vector3.ZERO
	player.global_position = at
	player.rotation.y = 0.0
	player.get_node("Neck").rotation.x = 0.0
	player.combat._reset()
	player.combat.adrenaline = 0.0


func _aim(target: Vector3) -> void:
	var eye: Vector3 = player.get_node("Neck").global_position
	var d := target - eye
	player.rotation.y = atan2(-d.x, -d.z)
	player.get_node("Neck").rotation.x = atan2(d.y, Vector2(d.x, d.z).length())


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
