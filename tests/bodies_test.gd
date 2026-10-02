extends Node3D
## Bodies that fall as physics has them (Ragdoll.gd): the killing blow, the
## kick that takes a man off his feet and the getting up again, men flung into
## men, spikes, blasts, a body let fall off your shoulder; and the clean cut
## that takes a head, an arm or the legs (Humanoid.sever).

const PLAYER := preload("res://Player.tscn")
const GUARD := preload("res://Guard.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")
const BarrelScript := preload("res://scripts/Combat/Barrel.gd")

const COMBAT := 4
const TemperamentScript := preload("res://scripts/AISystem/Temperament.gd")
const GarrisonScript := preload("res://scripts/AISystem/Garrison.gd")
const SquadScript := preload("res://scripts/AISystem/Squad.gd")

var player: CharacterBody3D
var combat: Node
var results: Array[String] = []


func _ready() -> void:
	# Every guard at his class's own temperament: these checks are exact.
	TemperamentScript.rolling = false
	Props.block(self, Vector3(40, -0.5, 0), Vector3(160, 1, 60))
	# B6: a spiked wall.
	Props.block(self, Vector3(40, 1.5, -3.3), Vector3(4, 3, 0.3))
	Props.spikes(self, Vector3(40, 1.1, -3.1), 3.0, 1.6, Vector3.BACK)

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

	player.debug_light_level = 1.0
	player.global_position = Vector3(0, 1.05, 20)
	Props.give_weapons(player, 12)
	Props.give_blackjack(player)
	combat = player.combat

	await baker.baked
	await _frames(5)
	await _run()

	print("\n==== RESULTS ====")
	for r in results:
		print(r)
	get_tree().quit()


func _run() -> void:
	_wield(&"sword")

	# B1 a killing blow: limp, thrown away from you, at rest
	# Rash: alone and nearly dead he goes all in (a steady man would be careful
	# and keep his guard up), so the blow that kills him lands.
	var g1 := _fighter(Vector3(0, 0, -1.5), &"", &"rash")
	g1.health = 10.0
	_put_player(Vector3(0, 1.05, 0))
	await _frames(20)
	_aim(g1.global_position + Vector3.UP * 1.2)
	var id1 := g1.get_instance_id()
	await _tap("throw")
	await _until(func(): return not is_instance_id_valid(id1), 40)
	await _frames(2)
	var corpse := _last_body()
	var limp: bool = corpse != null and corpse.ragdoll() != null and corpse.ragdoll().is_limp()
	await _until(func(): return corpse == null or not corpse.is_falling(), 240)
	var hips: Vector3 = corpse.ragdoll().centre() if corpse != null else Vector3.ZERO
	_check("B1 a killing blow sends him limp, away from you, to lie still", limp and corpse != null and not corpse.is_falling() and hips.z < -1.5 and hips.y < 0.45,
		"limp %s at rest %s hips %s" % [limp, corpse != null and not corpse.is_falling(), hips])

	# B2 kicked mid-blow: off his feet, flying, and up again to fight
	var g2 := _fighter(Vector3(10, 0, -1.2))
	_put_player(Vector3(10, 1.05, 0))
	await _frames(20)
	g2._phase = &"windup"
	g2._attack = &"overhead"
	g2._phase_length = 0.6
	g2._phase_timer = 0.4
	var from2 := g2.global_position
	await _tap("kick")
	await _until(func(): return g2.is_downed(), 30)
	var downed2: bool = g2.is_downed()
	var furthest := 0.0

	for i in 60:
		await _frames(1)
		furthest = maxf(furthest, g2.global_position.distance_to(from2))

	await _until(func(): return not g2.is_downed() and g2._rising <= 0.0, 300)
	await _frames(10)
	var standing: bool = not g2.is_downed() and not g2._rig.man.is_limp() and g2.state == COMBAT
	_check("B2 kicked in the middle of his blow he flies off his feet, and gets up to fight", downed2 and furthest > 1.2 and standing,
		"downed %s flew %.2f m standing again %s" % [downed2, furthest, standing])
	g2.queue_free()
	await _frames(10)

	# B3 kicked while standing ready: he only stumbles back
	var g3 := _fighter(Vector3(20, 0, -1.2))
	_put_player(Vector3(20, 1.05, 0))
	await _frames(20)
	var ever_down := false
	await _tap("kick")

	for i in 40:
		await _frames(1)
		ever_down = ever_down or g3.is_downed()

	_check("B3 kicked standing ready he stumbles back but stays up", not ever_down and g3.global_position.z < -1.5,
		"went down %s z %.2f" % [ever_down, g3.global_position.z])
	g3.queue_free()
	await _frames(10)

	# B4 flung into another man: both go down
	var g4a := _fighter(Vector3(30, 0, -1.2))
	var g4b := _new_guard(&"", Vector3(30, 0, -2.5), PI)
	g4b._attack_timer = 999.0
	_put_player(Vector3(30, 1.05, 0))
	await _frames(20)
	g4a._stagger = 0.5
	await _tap("kick")
	await _until(func(): return g4b.is_downed(), 60)
	_check("B4 a man kicked into another takes him down too", g4a.is_downed() and g4b.is_downed(),
		"kicked down %s other down %s" % [g4a.is_downed(), g4b.is_downed()])
	g4a.queue_free()
	g4b.queue_free()
	await _frames(10)

	# B5 a brute keeps his feet against a standing kick, mid-swing or not; a
	#    running boot into a reeling brute takes him down
	var g5 := _fighter(Vector3(50, 0, -1.3), &"brute")
	_put_player(Vector3(50, 1.05, 0))
	await _frames(20)
	g5._phase = &"windup"
	g5._attack = &"heavy"
	g5._phase_length = 0.8
	g5._phase_timer = 0.6
	await _tap("kick")
	await _frames(20)
	var stood: bool = not g5.is_downed()
	g5._phase = &""
	await _frames(40)
	_put_player(Vector3(50, 1.05, 6))
	await _frames(5)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _until(func(): return player.global_position.z < g5.global_position.z + 1.9, 120)
	g5._stagger = 0.6
	await _tap("kick")
	_release_all()
	await _until(func(): return g5.is_downed(), 30)
	_check("B5 a brute stands a standing kick, but not a running one when reeling", stood and g5.is_downed(),
		"stood the first %s down after the second %s" % [stood, g5.is_downed()])
	g5.queue_free()
	await _frames(10)

	# B6 kicked onto spikes: he dies on them, and stays there
	var g6 := _fighter(Vector3(40, 0, -1.4))
	_put_player(Vector3(40, 1.05, 0))
	await _frames(20)
	g6._stagger = 0.5
	var id6 := g6.get_instance_id()
	await _tap("kick")
	await _until(func(): return not is_instance_id_valid(id6), 60)
	var impaled := _last_body()
	await _frames(120)
	var on_spikes: float = impaled.ragdoll().chest().z if impaled != null and impaled.ragdoll() != null else 99.0
	_check("B6 kicked onto spikes he dies on them and stays there", not is_instance_id_valid(id6) and impaled != null and on_spikes < -2.3,
		"dead %s chest z %.2f" % [not is_instance_id_valid(id6), on_spikes])

	# B7 a body let down off your shoulder falls and lies on the floor
	_wield(&"blackjack")
	var g7 := _new_guard(&"", Vector3(60, 0, -1.2), 0.0)
	player.debug_light_level = 0.0
	_put_player(Vector3(60, 1.05, 0.2))
	await _frames(10)
	_aim(g7.global_position + Vector3.UP * 1.4)
	await _frames(2)
	await _tap("throw")
	await _frames(40)
	var carried := _last_body()
	_aim(carried.ragdoll().centre() if carried != null else Vector3(60, 0, -1.2))
	await _frames(3)
	await _tap("frob")
	await _frames(20)
	var shouldered: bool = player.frob.is_shouldering()
	await _tap("frob")
	await _frames(10)
	var falling: bool = carried.is_falling()
	await _until(func(): return not carried.is_falling(), 200)
	var lying: float = carried.ragdoll().centre().y
	_check("B7 a body let down off your shoulder falls and lies on the floor", shouldered and falling and not carried.is_falling() and lying < 0.4,
		"shouldered %s fell %s lies at %.2f m" % [shouldered, falling, lying])
	player.debug_light_level = 1.0
	_wield(&"sword")

	# B8 a blast throws a man off his feet
	var barrel: RigidBody3D = BarrelScript.new()
	add_child(barrel)
	barrel.global_position = Vector3(70, 0.4, -1.0)
	var g8 := _new_guard(&"", Vector3(70, 0, -2.3), 0.0)
	g8.health = 1000.0
	g8.max_health = 1000.0
	_put_player(Vector3(70, 1.05, 12))
	await _frames(20)
	barrel.strike(&"arrow", barrel.global_position)
	# It burns a moment before it goes up.
	await _until(func(): return g8.is_downed(), 240)
	_check("B8 a blast throws him off his feet", is_instance_valid(g8) and g8.is_downed(), "downed %s" % [is_instance_valid(g8) and g8.is_downed()])
	g8.queue_free()
	await _frames(10)

	# B9 a clean killing cut high takes his head off
	# Rash, as in B1: nearly dead and all in, not guarding.
	var g9 := _fighter(Vector3(80, 0, -1.4), &"", &"rash")
	g9.health = 20.0
	_put_player(Vector3(80, 1.05, 0))
	await _frames(20)
	_aim(g9.global_position + Vector3.UP * 1.55)
	var id9 := g9.get_instance_id()
	var pieces_before := _pieces().size()
	await _tap("throw")
	await _until(func(): return not is_instance_id_valid(id9), 40)
	await _frames(5)
	var new_pieces := _pieces().slice(pieces_before)
	var headless := _last_body()
	var gone: bool = headless != null and headless.man() != null and headless.man().severed != null and &"neck_01" in headless.man().severed.bones
	_check("B9 a clean killing cut through the neck takes his head off", new_pieces.size() == 1 and new_pieces[0].part == &"neck_01" and gone,
		"pieces %s head gone from him %s" % [new_pieces.map(func(p): return p.part), gone])

	# B10 not weak enough, and not a heavy blow: it kills him, and he stays whole
	var g10 := _fighter(Vector3(90, 0, -1.4))
	# Half his health left: one cut kills him, but he is not weak (40%).
	g10.max_health = 60.0
	g10.health = 30.0
	_put_player(Vector3(90, 1.05, 0))
	await _frames(20)
	_aim(g10.global_position + Vector3.UP * 1.55)
	var id10 := g10.get_instance_id()
	pieces_before = _pieces().size()
	await _tap("throw")
	await _until(func(): return not is_instance_id_valid(id10), 40)
	await _frames(5)
	_check("B10 a quick cut on a man not yet weak kills him whole", not is_instance_id_valid(id10) and _pieces().size() == pieces_before,
		"dead %s pieces cut %d" % [not is_instance_id_valid(id10), _pieces().size() - pieces_before])

	# B11 where it meets him: a low sweep both legs, the arm it meets the arm;
	#     B12 a point cuts nothing off
	var g11 := _fighter(Vector3(100, 0, -1.4))
	await _frames(10)
	var man: Node3D = g11._rig.man
	var knee: Vector3 = man.bone_global(&"calf_l").origin
	var forearm: Vector3 = (man.bone_global(&"lowerarm_r").origin + man.bone_global(&"hand_r").origin) * 0.5
	combat._direction = &"left"
	var legs: Array = combat._sever_parts(g11, Vector3(g11.global_position.x, knee.y - 0.15, g11.global_position.z + 0.2), 100.0, 10.0, &"quick")
	var arm: Array = combat._sever_parts(g11, forearm, 100.0, 10.0, &"quick")
	combat._direction = &"thrust"
	var point_cut: Array = combat._sever_parts(g11, man.bone_global(&"neck_01").origin + Vector3.UP * 0.05, 100.0, 10.0, &"quick")
	combat._direction = &"left"
	_check("B11 a low sweep takes both legs, a cut on the arm takes the arm", legs == [&"calf_l", &"calf_r"] and arm == [&"lowerarm_r"],
		"low %s arm %s" % [legs, arm])
	_check("B12 a point goes in and cuts nothing off", point_cut.is_empty(), "thrust %s" % [point_cut])
	g11.queue_free()
	await _frames(10)

	# B13 a man on the floor cannot guard himself, and the blade finds him there
	var g13 := _fighter(Vector3(110, 0, -1.2))
	g13.block_chance = 1.0
	g13._fighter.parry_chance = 1.0
	_put_player(Vector3(110, 1.05, 0))
	await _frames(20)
	g13.knock_down(Vector3(0, 0.5, -1.0), player, g13.global_position + Vector3.UP)
	await _until(func(): return g13._down_still > 0.2, 120)
	var before13: float = g13.health
	_aim(g13._rig.man.ragdoll.chest())
	await _frames(2)
	await _tap("throw")
	await _frames(30)
	_check("B13 a man on the floor cannot guard, and the blade finds him there", g13.health < before13,
		"health %.0f -> %.0f downed %s" % [before13, g13.health, g13.is_downed()])
	g13.queue_free()
	await _frames(10)



func _pieces() -> Array:
	return get_tree().get_nodes_in_group(&"bodies").filter(func(b): return b.get("part") != null)


func _last_body() -> Node3D:
	var found: Node3D = null

	for body in get_tree().get_nodes_in_group(&"bodies"):
		if body.has_method("ragdoll"):
			found = body

	return found


func _fighter(at: Vector3, archetype: StringName = &"", preset: StringName = &"") -> CharacterBody3D:
	# A new fight: no dread carried over from the last one's dead, and no hunt
	# either (the men of earlier checks stay about, and a hunt outlives a lull).
	GarrisonScript.clear_all()
	SquadScript.clear_all()
	var g := _new_guard(archetype, at, 0.0, preset)
	g.block_chance = 0.0
	g._fighter.parry_chance = 0.0
	g._fighter.feint_chance = 0.0
	g._fighter.dodge_chance = 0.0
	g._fighter.counter_chance = 0.0
	g._fighter.kick_chance = 0.0
	g._fighter.backstep_chance = 0.0
	g._fighter.lunge_chance = 0.0
	g._fighter.timing_variance = 0.0
	g._fighter.read_skill = 0.0
	g.chase_speed = 0.0
	g._attack_timer = 999.0
	g.attack_cooldown = 999.0
	g._engage(player)
	return g


func _new_guard(archetype: StringName, at: Vector3, yaw: float, preset: StringName = &"") -> CharacterBody3D:
	var g: CharacterBody3D = GUARD.instantiate()
	g.archetype = archetype
	g.temperament = preset
	g.debug_ai = false
	g.position = at
	g.rotation.y = yaw
	add_child(g)
	return g


func _wield(weapon_id: StringName) -> void:
	player.inventory.select_by_id(weapon_id)


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
	player.combat.stamina = player.combat.stamina_max
	player.combat._kick_cooldown = 0.0
	player.reset_physics_interpolation()


func _aim(target: Vector3) -> void:
	var eye: Vector3 = player.get_node("Neck").global_position
	var d := target - eye
	player.rotation.y = atan2(-d.x, -d.z)
	player.get_node("Neck").rotation.x = atan2(d.y, Vector2(d.x, d.z).length())


func _release_all() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "jump", "sprint", "crouch", "frob", "throw", "block", "kick", "dodge"]:
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
