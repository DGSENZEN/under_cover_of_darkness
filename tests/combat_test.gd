extends Node3D
## Combat, Dark Messiah style: swings, blocks, parries, the kick, the bow,
## adrenaline, and guards who fight back and die.

const PLAYER := preload("res://Player.tscn")
const GUARD_SCRIPT := preload("res://scripts/AISystem/Guard.gd")
const GUARD := preload("res://Guard.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")
const SoundBus := preload("res://scripts/StimuliSystem/SoundBus.gd")
const LightProbe := preload("res://scripts/StimuliSystem/LightProbe.gd")

const RELAXED := 0
const INVESTIGATING := 2
const COMBAT := 4
const TemperamentScript := preload("res://scripts/AISystem/Temperament.gd")
const GarrisonScript := preload("res://scripts/AISystem/Garrison.gd")


class Ear:
	var events: Array = []

	func hear_sound(event: Dictionary) -> void:
		events.append(event)


var player: CharacterBody3D
var baker: NavigationRegion3D
var results: Array[String] = []
var _barks := {}


func _ready() -> void:
	# Every guard at his class's own temperament: these checks are exact.
	TemperamentScript.rolling = false
	# Exact damage is checked here: cuts do not go on bleeding.
	GUARD_SCRIPT.bleeding_on = false
	Props.block(self, Vector3(0, -0.5, 0), Vector3(140, 1, 90))              # floor
	Props.block(self, Vector3(-20, 1.5, -1.0), Vector3(4, 3, 0.3))          # C3 wall
	Props.spikes(self, Vector3(20, 1.0, -3.0), 3.0, 2.0, Vector3.BACK)       # C9b spikes, face at z = -3
	Props.block(self, Vector3(20, 1.0, -3.3), Vector3(3.2, 2.0, 0.6))        # the wall behind them
	Props.block(self, Vector3(40, 3.0, 0), Vector3(4, 6, 4))                 # C9c platform, top at 6
	Props.block(self, Vector3(-3.0, 1.25, 20), Vector3(5.0, 2.5, 0.3))       # door wall
	Props.block(self, Vector3(3.0, 1.25, 20), Vector3(5.0, 2.5, 0.3))
	Props.block(self, Vector3(0.0, 2.3, 20), Vector3(1.0, 0.4, 0.3))
	Props.block(self, Vector3(-40, 1.5, -10), Vector3(6, 3, 0.3))            # C12 target wall

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
	get_tree().quit()


func _run() -> void:
	var combat: Node = player.combat

	# C1 a quick sword blow
	_wield(&"sword")
	var g1 := _fighter(Vector3(0, 0, -1.5))
	_put_player(Vector3(0, 1.05, 0))
	await _frames(20)
	var landed := []
	combat.landed.connect(func(t, r, d): landed.append([r, d]))
	await _tap("throw")
	await _frames(40)
	_check("C1 a quick blow lands for the sword's damage", _near(g1.health, 66.0, 0.1) and landed.size() == 1 and landed[0][0] == &"hit",
		"health %.1f landed %s" % [g1.health, landed])
	g1.queue_free()

	# C2 hold to charge: a power attack
	var g2 := _fighter(Vector3(0, 0, -1.5))
	_put_player(Vector3(0, 1.05, 0))
	await _frames(20)
	Input.action_press("throw")
	await _frames(50)
	var charged: bool = combat.phase == combat.Phase.CHARGING and combat._charge >= 1.0
	var slowed: float = combat.speed_scale()
	Input.action_release("throw")
	await _frames(40)
	_check("C2 holding charges a power blow, and slows you", charged and slowed < 1.0 and _near(g2.health, 30.0, 0.1),
		"charged %s speed x%.2f health %.1f" % [charged, slowed, g2.health])
	g2.queue_free()

	# C3 a swing into a wall bounces off it
	var g3 := _fighter(Vector3(-20, 0, -2.0))
	var bounced := []
	combat.deflected.connect(func(p): bounced.append(p))
	_put_player(Vector3(-20, 1.05, 0.0))
	await _frames(20)
	await _tap("throw")
	await _frames(40)
	_check("C3 a swing into a wall bounces off", bounced.size() == 1 and g3.health == g3.max_health,
		"deflected %d guard health %.0f" % [bounced.size(), g3.health])
	g3.queue_free()

	# C4 the dagger, from behind, on the unaware: death
	player.debug_light_level = 0.0
	_wield(&"dagger")
	var g4 := _new_guard(Vector3(10, 0, -1.2), 0.0)
	_put_player(Vector3(10, 1.05, 0.2))
	await _frames(20)
	await _tap("throw")
	await _frames(30)
	var corpse := _last_body()
	_check("C4 a dagger in the back kills an unaware guard", not is_instance_valid(g4) and corpse != null and corpse.dead,
		"alive %s corpse %s" % [is_instance_valid(g4), corpse != null and corpse.dead])

	# C5 the sword, from behind, on the unaware: double damage
	_wield(&"sword")
	var g5 := _new_guard(Vector3(14, 0, -1.4), 0.0)
	_put_player(Vector3(14, 1.05, 0.0))
	await _frames(20)
	await _tap("throw")
	await _frames(40)
	_check("C5 a sneak attack does double damage", _near(g5.health, 32.0, 0.1), "health %.1f" % g5.health)
	g5.queue_free()

	# C6 his blow is telegraphed: the blade goes up well before it lands
	player.invulnerable = false
	player.health = player.max_health
	var g6 := _fighter(Vector3(0, 0, -1.3))
	g6._attack_timer = 0.0
	g6.attack_cooldown = 1.1
	_put_player(Vector3(0, 1.05, 0))
	var windup_at := -1
	var hurt_at := -1
	for i in 240:
		await _frames(1)
		if windup_at < 0 and g6._phase == &"windup":
			windup_at = i
		if hurt_at < 0 and player.health < player.max_health:
			hurt_at = i
			break
	_check("C6 his blow is telegraphed by half a second", windup_at >= 0 and hurt_at - windup_at >= 30 and _near(player.health, 66.0, 0.1),
		"wind-up at frame %d, hit at frame %d, health %.0f" % [windup_at, hurt_at, player.health])

	# C7 a raised guard takes most of it; raised just in time, all of it
	player.health = player.max_health
	Input.action_press("block")
	g6._phase = &""
	g6._attack_timer = 0.0
	await _until(func(): return player.health < player.max_health or g6._phase == &"recover", 240)
	var blocked_health: float = player.health
	Input.action_release("block")
	await _frames(60)
	player.health = player.max_health
	g6._stagger = 0.0
	g6._phase = &""
	g6._attack_timer = 0.0
	await _until(func(): return g6._phase == &"windup" and g6._phase_timer < 0.12, 240)
	Input.action_press("block")
	await _until(func(): return g6._phase != &"windup", 60)
	await _frames(3)
	var parried_stagger: float = g6._stagger
	Input.action_release("block")
	_check("C7 block takes a fifth; a parry takes nothing and staggers him", _near(blocked_health, 93.2, 0.1) and player.health == player.max_health and parried_stagger > 1.0,
		"blocked: health %.1f  parried: health %.1f, his stagger %.2f s" % [blocked_health, player.health, parried_stagger])
	g6.queue_free()
	player.invulnerable = true
	await _frames(40)

	# C8 fighting you, he catches quick blows; a power blow gets through.
	# (Quick to see it coming: a plain watchman's 0.12 s against a quick cut
	# is a race to the frame, and this is about what he does, not how fast.)
	var g8 := _fighter(Vector3(0, 0, -1.5))
	g8.block_chance = 1.0
	g8._fighter.reaction = 0.05
	_put_player(Vector3(0, 1.05, 0))
	await _frames(20)
	landed.clear()
	await _tap("throw")
	await _frames(40)
	var quick_result: StringName = landed[0][0] if landed.size() > 0 else &""
	var after_quick: float = g8.health
	g8._stagger = 0.0
	await _until(func(): return combat.phase == combat.Phase.IDLE, 90)
	Input.action_press("throw")
	await _frames(_charge_frames())
	Input.action_release("throw")
	await _frames(40)
	_check("C8 quick blows are blocked; power blows are not", quick_result == &"blocked" and after_quick == g8.max_health and _near(g8.health, 30.0, 0.1),
		"quick %s health after %.0f, after power %.0f" % [quick_result, after_quick, g8.health])
	g8.queue_free()

	# C9 the kick sends him sliding back
	var g9 := _fighter(Vector3(0, 0, -1.2))
	_put_player(Vector3(0, 1.05, 0))
	await _frames(20)
	var start_z: float = g9.global_position.z
	await _tap("kick")
	var flew := false
	for i in 90:
		await _frames(1)
		if g9._knock > 0.0:
			flew = true
	_check("C9 the kick sends him back", flew and start_z - g9.global_position.z > 2.0,
		"knocked %s pushed back %.2f m" % [flew, start_z - g9.global_position.z])
	g9.queue_free()

	# C9b kicked into spikes
	var bodies_before := get_tree().get_nodes_in_group(&"bodies").size()
	var g9b := _fighter(Vector3(20, 0, -1.8))
	_put_player(Vector3(20, 1.05, -0.6))
	await _frames(20)
	await _tap("kick")
	await _frames(60)
	var spiked := _last_body()
	var new_bodies := get_tree().get_nodes_in_group(&"bodies").size() - bodies_before
	_check("C9b kicked onto spikes, he dies", not is_instance_valid(g9b) and new_bodies == 1 and spiked.dead,
		"alive %s new corpses %d" % [is_instance_valid(g9b), new_bodies])

	# C9c kicked off a 6 m platform, he dies of the fall
	bodies_before = get_tree().get_nodes_in_group(&"bodies").size()
	var g9c := _fighter(Vector3(40, 6, -1.4))
	_put_player(Vector3(40, 7.05, -0.2))
	await _frames(20)
	await _tap("kick")
	await _frames(150)
	var fallen := _last_body()
	new_bodies = get_tree().get_nodes_in_group(&"bodies").size() - bodies_before
	_check("C9c kicked off a height, the fall kills him", not is_instance_valid(g9c) and new_bodies == 1 and fallen.dead,
		"alive %s new corpses %d health %.0f" % [is_instance_valid(g9c), new_bodies, g9c.health if is_instance_valid(g9c) else 0.0])

	# C10 the kick sends a crate flying and bursts a door open
	var crate := Props.crate(self, Vector3(30, 0.3, 18.8), 0.5, 5.0)
	_put_player(Vector3(30, 1.05, 20))
	await _frames(20)
	await _tap("kick")
	await _frames(12)
	var crate_speed: float = crate.linear_velocity.length()
	await _frames(60)
	var door := Props.door(self, Vector3(-0.5, 0, 20))
	_put_player(Vector3(0, 1.05, 21.0))
	await _frames(20)
	await _tap("kick")
	await _frames(60)
	_check("C10 kicks move crates and burst doors", crate_speed > 3.0 and door.is_open,
		"crate speed %.1f door open %s" % [crate_speed, door.is_open])

	# C11 the bow: a full draw hurts, and draws him to you
	player.debug_light_level = 0.0
	_wield(&"bow")
	var g11 := _new_guard(Vector3(-10, 0, -15), 0.0)
	_put_player(Vector3(-10, 1.05, 0))
	await _frames(20)
	_aim(Vector3(-10, 1.3, -15))
	await _frames(3)
	var arrows_before: int = combat.arrow_count()
	Input.action_press("throw")
	await _frames(60)
	var full: float = combat.draw
	Input.action_release("throw")
	await _frames(60)
	_check("C11 a full draw hurts, uses an arrow, and gives you away", full >= 1.0 and _near(g11.health, 30.0, 0.5) and combat.arrow_count() == arrows_before - 1 and g11.state == COMBAT,
		"draw %.2f health %.1f arrows %d -> %d state %d" % [full, g11.health, arrows_before, combat.arrow_count(), g11.state])
	g11.queue_free()

	# C11b a headshot kills
	var g11b := _new_guard(Vector3(-10, 0, -15), 0.0)
	_put_player(Vector3(-10, 1.05, 0))
	await _frames(20)
	_aim(Vector3(-10, 2.1, -15))
	await _frames(3)
	Input.action_press("throw")
	await _frames(60)
	Input.action_release("throw")
	await _frames(60)
	_check("C11b a headshot at full draw kills", not is_instance_valid(g11b), "alive %s" % is_instance_valid(g11b))

	# C12 a miss sticks in the wall, is heard there, and can be taken back
	var ear := Ear.new()
	SoundBus.add_listener(ear)
	var g12 := _new_guard(Vector3(-36, 0, -7), PI * 0.5)
	_put_player(Vector3(-40, 1.05, 0))
	await _frames(20)
	_aim(Vector3(-40, 1.3, -10))
	await _frames(3)
	Input.action_press("throw")
	await _frames(30)
	Input.action_release("throw")
	await _frames(40)
	var stuck: Node3D = null
	for child in get_children():
		if child.get("stuck") == true:
			stuck = child
	var heard_at := Vector3.INF
	for e in ear.events:
		if e["kind"] == &"arrow":
			heard_at = e["position"]
	SoundBus.remove_listener(ear)
	var guard_goes: bool = g12.has_last_known and g12.last_known_position.distance_to(heard_at) < 2.5
	var was_stuck: bool = stuck != null
	var count_before: int = combat.arrow_count()
	if stuck != null:
		_put_player(Vector3(stuck.global_position.x, 1.05, stuck.global_position.z + 1.3))
		await _frames(10)
	_aim(stuck.global_position if stuck else Vector3.ZERO)
	await _frames(4)
	await _tap("frob")
	await _frames(5)
	_check("C12 a missed arrow sticks, is heard, and can be taken back", was_stuck and heard_at.z < -9.5 and guard_goes and combat.arrow_count() == count_before + 1,
		"stuck %s heard at %s guard heading there %s arrows %d -> %d" % [was_stuck, heard_at, guard_goes, count_before, combat.arrow_count()])
	g12.queue_free()

	# C13 no arrows: nothing to draw
	for entry in player.inventory.belt:
		if entry["id"] == &"arrows":
			entry["count"] = 0
	await _tap("throw")
	await _frames(5)
	_check("C13 no arrows, no draw", combat.phase != combat.Phase.DRAWING, "phase %d" % combat.phase)
	for entry in player.inventory.belt:
		if entry["id"] == &"arrows":
			entry["count"] = 12

	# C14 full adrenaline: the next power blow is a slow-motion finisher
	_wield(&"sword")
	var g14 := _fighter(Vector3(0, 0, -1.5))
	_put_player(Vector3(0, 1.05, 0))
	await _frames(20)
	combat.adrenaline = combat.adrenaline_max
	var slowed_time := [false]
	combat.finisher_started.connect(func(): slowed_time[0] = Engine.time_scale < 1.0, CONNECT_ONE_SHOT)
	await _until(func(): return combat.phase == combat.Phase.IDLE, 90)
	Input.action_press("throw")
	await _frames(_charge_frames())
	Input.action_release("throw")
	await _frames(40)
	await get_tree().create_timer(1.0, true, false, true).timeout
	_check("C14 full adrenaline makes a slow-motion finisher", not is_instance_valid(g14) and slowed_time[0] and Engine.time_scale == 1.0 and combat.adrenaline < 30.0,
		"alive %s slowed %s time scale now %.2f adrenaline %.0f" % [is_instance_valid(g14), slowed_time[0], Engine.time_scale, combat.adrenaline])

	# C15 a raised guard slows you
	_put_player(Vector3(0, 1.05, 30))
	Input.action_press("block")
	Input.action_press("move_forward")
	await _frames(60)
	var blocking_speed: float = Vector2(player.velocity.x, player.velocity.z).length()
	_release_all()
	await _frames(10)
	_check("C15 blocking slows you down", combat.blocking == false and blocking_speed < player.walk_speed * 0.6 and blocking_speed > 1.0,
		"speed with guard up %.2f" % blocking_speed)

	# C16 a death scream brings the others
	player.debug_light_level = 0.0
	_wield(&"dagger")
	var victim := _new_guard(Vector3(25, 0, 30), 0.0)
	var listener := _new_guard(Vector3(25, 0, 40), 0.0)
	_put_player(Vector3(25, 1.05, 31.2))
	await _frames(20)
	await _tap("throw")
	await _frames(10)
	_check("C16 a dying scream brings the others", not is_instance_valid(victim) and listener.state >= INVESTIGATING,
		"victim alive %s listener state %d" % [is_instance_valid(victim), listener.state])
	listener.queue_free()

	# C17 a corpse in the light: "He's dead!"
	var lamp := OmniLight3D.new()
	lamp.omni_range = 8.0
	lamp.light_energy = 2.0
	add_child(lamp)
	var dead_body := _last_body()
	lamp.global_position = dead_body.global_position + Vector3.UP * 2.5
	LightProbe.invalidate()
	player.global_position = Vector3(60, 1.05, 40)
	var finder := _new_guard(dead_body.global_position + Vector3(0, -0.4, 4.0), 0.0)
	finder.global_position.y = 0.0
	await _until(func(): return dead_body.discovered, 240)
	_check("C17 a corpse found in the light is called murder", dead_body.discovered and _barks_of(finder).has("He's dead! Murder!"),
		"found %s barks %s" % [dead_body.discovered, _barks_of(finder)])
	finder.queue_free()
	lamp.queue_free()

	# C18 the hands show the weapon, and the bow shows its arrow when drawn
	_wield(&"bow")
	_put_player(Vector3(0, 1.05, 30))
	await _frames(30)
	var hand: Node3D = player.hand
	var showing_bow: bool = hand.current_item_mesh() != null and hand.current_item_mesh() == combat.current_weapon().mesh
	Input.action_press("throw")
	await _frames(20)
	var nocked: bool = hand._nocked.visible
	Input.action_press("block")
	await _frames(2)
	Input.action_release("block")
	Input.action_release("throw")
	await _frames(5)
	_check("C18 the bow is in your hand, with an arrow on the string when drawn", showing_bow and nocked and combat.phase == combat.Phase.IDLE,
		"bow in hand %s arrow shown %s phase %d" % [showing_bow, nocked, combat.phase])


# --------------------------------------------------------------------------
func _wield(weapon_id: StringName) -> void:
	player.inventory.select_by_id(weapon_id)


## Frames to hold the attack for a full power blow with the weapon in hand:
## its windup and its charge, and a little more.
func _charge_frames() -> int:
	var weapon: Resource = player.combat.current_weapon()
	return int(ceil((weapon.windup + weapon.charge_time + 0.12) * 60.0))


## A guard already fighting you, facing you, who will not strike first.
## Lit, so he can see who he is fighting.
func _fighter(at: Vector3) -> CharacterBody3D:
	# A new fight: no dread carried over from the last one's dead.
	GarrisonScript.clear_all()
	player.debug_light_level = 1.0
	var g := _new_guard(at, 0.0)
	g.block_chance = 0.0
	g._attack_timer = 999.0
	g.attack_cooldown = 999.0
	g.rotation.y = PI
	g._engage(player)
	return g


func _new_guard(at: Vector3, yaw: float) -> CharacterBody3D:
	var g: CharacterBody3D = GUARD.instantiate()
	g.debug_ai = false
	g.position = at
	g.rotation.y = yaw
	add_child(g)
	_barks[g] = []
	g.barked.connect(func(t): _barks[g].append(t))
	return g


func _barks_of(g: Node) -> Array:
	return _barks.get(g, [])


func _last_body() -> Node3D:
	var found: Node3D = null
	# A man's body, not a part cut off one (SeveredPart.gd).
	for b in get_tree().get_nodes_in_group(&"bodies"):
		if b.get("part") == null:
			found = b
	return found


func _put_player(at: Vector3) -> void:
	_release_all()
	player.movement_state = 0
	player.current_move = null
	player.velocity = Vector3.ZERO
	player.global_position = at
	player.rotation.y = 0.0
	player.get_node("Neck").rotation.x = 0.0
	player.combat._reset()
	# Each test starts calm: adrenaline carried over would turn a power blow
	# into a finisher.
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


func _near(a: float, b: float, tol: float) -> bool:
	return absf(a - b) <= tol


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
