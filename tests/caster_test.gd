extends Node3D
## Magic: spells as data, the power pool, the caster's loadouts and cast
## times, Blink, Shard, Ward, the tome and Empower.

const PLAYER := preload("res://Player.tscn")
const GUARD_SCRIPT := preload("res://scripts/AISystem/Guard.gd")
const GUARD := preload("res://Guard.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")
const SoundBus := preload("res://scripts/StimuliSystem/SoundBus.gd")
const Fx := preload("res://scripts/Visual/Fx.gd")
const TemperamentScript := preload("res://scripts/AISystem/Temperament.gd")
const GarrisonScript := preload("res://scripts/AISystem/Garrison.gd")
const ViewArmsScript := preload("res://scripts/Interaction/ViewArms.gd")
const Spells := preload("res://scripts/Magic/Spells.gd")


class Ear:
	var events: Array = []

	func hear_sound(event: Dictionary) -> void:
		events.append(event)


var player: CharacterBody3D
var baker: NavigationRegion3D
var results: Array[String] = []


func _ready() -> void:
	TemperamentScript.rolling = false
	GUARD_SCRIPT.bleeding_on = false
	ViewArmsScript.new_arms = true
	Props.block(self, Vector3(0, -0.5, 0), Vector3(160, 1, 90))              # floor

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
	player.debug_light_level = 1.0
	player.global_position = Vector3(60, 1.05, 40)
	Props.give_weapons(player)
	Props.give_revolver(player)

	await baker.baked
	await _frames(5)
	await _run()

	print("\n==== RESULTS ====")
	for r in results:
		print(r)
	get_tree().quit()


func _run() -> void:
	var power: Node = player.power

	# S1 the four spells, as data
	var empower: Dictionary = Spells.info(&"empower")
	_check("S1 the spells are data: Empower is a tome spell of 50 and 1.2 s",
		empower.get("tier") == Spells.Tier.TOME and _near(empower.get("cost", 0.0), 50.0, 0.001) and _near(empower.get("cast_time", 0.0), 1.2, 0.001)
			and Spells.all().size() == 4 and [&"blink", &"shard", &"ward", &"empower"].all(func(id): return id in Spells.all()),
		"empower %s all %s" % [empower, Spells.all()])

	# S2 the pool refills, but only after a rest
	power.power = power.MAX
	power.pay(40.0)
	await _frames(119)
	var rested: float = power.power
	await _frames(60)
	_check("S2 the pool refills 5 a second once 2 s have passed", _near(rested, 60.0, 0.01) and _near(power.power, 65.0, 0.2),
		"after 119 frames %.2f, 60 more %.2f" % [rested, power.power])

	# S3 its edges: no spending what is not there, no filling past full
	power.power = 10.0
	var paid: bool = power.pay(15.0)
	var kept: float = power.power
	await _frames(1000)
	_check("S3 the pool never goes under 0 or over 100", not paid and _near(kept, 10.0, 0.001) and power.power <= power.MAX,
		"paid %s kept %.1f later %.1f" % [paid, kept, power.power])

	var caster: Node = player.caster
	var done := []
	var broken := []
	caster.cast_done.connect(func(id): done.append(id))
	caster.cast_broken.connect(func(id): broken.append(id))

	# S4 a hand spell takes the circle's 0.4 s, then is paid for
	_wield(&"revolver")
	_put_player(Vector3(0, 1.05, 0))
	await _frames(30)
	power.power = power.MAX
	caster.select(&"shard")
	done.clear()
	Input.action_press("block")
	await _frames(22)
	var early := done.size()
	await _frames(4)
	Input.action_release("block")
	_check("S4 a hand spell is cast in 0.4 s and costs 15", early == 0 and done == [&"shard"] and _near(power.power, 85.0, 0.01),
		"at 22 %d then %s power %.1f" % [early, done, power.power])
	await _frames(10)

	# S5 a tome spell takes the pages' 1.2 s
	power.power = power.MAX
	caster.select(&"empower")
	await _frames(30)
	done.clear()
	Input.action_press("block")
	await _frames(70)
	var at_seventy := done.size()
	await _frames(4)
	Input.action_release("block")
	_check("S5 a tome spell is cast in 1.2 s and costs 50", at_seventy == 0 and done == [&"empower"] and _near(power.power, 50.0, 0.01),
		"at 70 %d then %s power %.1f" % [at_seventy, done, power.power])
	await _frames(10)

	# S6 a hard hit breaks a tome spell, for nothing
	power.power = power.MAX
	done.clear()
	broken.clear()
	Input.action_press("block")
	await _frames(30)
	player.take_damage(30.0, null)
	await _frames(2)
	var after_hit: StringName = caster.casting()
	await _frames(60)
	Input.action_release("block")
	_check("S6 a hard hit breaks a tome spell, and nothing is spent",
		broken == [&"empower"] and done.is_empty() and after_hit == &"" and _near(power.power, 100.0, 0.01),
		"broken %s done %s casting %s power %.1f" % [broken, done, after_hit, power.power])
	await _frames(10)

	# S7 let go early, or put the gun away: no spell, nothing spent
	power.power = power.MAX
	caster.select(&"shard")
	done.clear()
	Input.action_press("block")
	await _frames(10)
	Input.action_release("block")
	await _frames(30)
	var let_go := done.size()
	Input.action_press("block")
	await _frames(10)
	_wield(&"sword")
	await _frames(30)
	Input.action_release("block")
	_check("S7 letting go early or putting the gun away casts nothing and costs nothing",
		let_go == 0 and done.is_empty() and caster.casting() == &"" and _near(power.power, 100.0, 0.01),
		"let go %d done %s casting %s power %.1f" % [let_go, done, caster.casting(), power.power])

	# S8 what each grip allows
	await _frames(30)
	var sword_shard: bool = caster.can_cast(&"shard")
	var sword_blink: bool = caster.can_cast(&"blink")
	_wield(&"revolver")
	await _frames(30)
	caster.select(&"shard")
	caster.toggle_braced()
	await _frames(30)
	var braced_shard: bool = caster.can_cast(&"shard")
	caster.select(&"shard")
	Props.block(self, Vector3(20, 1.5, -5.0), Vector3(4, 3, 1))
	await _frames(2)
	var anchor: Vector3 = player.planner.hang_anchor(Vector3(20, 3.0, -4.5), Vector3.BACK, 3.0)
	player.teleport(Transform3D(Basis.IDENTITY, anchor))
	player._enter_hang(Vector3.BACK, 3.0, false)
	await _frames(10)
	var hung_shard: bool = caster.can_cast(&"shard")
	var hung_blink: bool = caster.can_cast(&"blink")
	player._drop_from_hang()
	await _frames(60)
	_check("S8 the sword or both hands on the gun allow only cantrips; hanging, only Blink",
		not sword_shard and sword_blink and not braced_shard and not hung_shard and hung_blink,
		"sword shard %s blink %s, braced shard %s, hanging shard %s blink %s" % [sword_shard, sword_blink, braced_shard, hung_shard, hung_blink])

	# S9 the tome in the left hand gives way to a pickup, and comes back
	_put_player(Vector3(0, 1.05, 0))
	caster.select(&"empower")
	await _frames(30)
	var holding: StringName = player.hand.left_mode()
	player.hand.receive("key", Props.belt_mesh(&"lockpick"), player.global_transform.translated(Vector3(0, 1, -1)))
	await _frames(5)
	var during: StringName = player.hand.left_mode()
	await _frames(60)
	_check("S9 the tome is in the left hand; a pickup takes it, then it is back",
		holding == &"tome" and during == &"" and player.hand.left_mode() == &"tome",
		"before %s during %s after %s" % [holding, during, player.hand.left_mode()])
	caster.select(&"shard")

	# S10 a tap of Q with the gun drawn: a 4 m step, paid for on arrival
	_wield(&"revolver")
	_put_player(Vector3(40, 1.05, 30))
	await _frames(30)
	power.power = power.MAX
	var from10: Vector3 = player.global_position
	await _tap("blink")
	await _frames(4)
	var moved10: Vector3 = player.global_position - from10
	_check("S10 a tap blinks 4 m ahead and costs 20", _near(-moved10.z, 4.0, 0.3) and absf(moved10.x) < 0.1 and _near(power.power, 80.0, 0.01),
		"moved %s power %.1f" % [moved10, power.power])

	# S11 never into anything: short of a wall, above a floor, before a man
	Props.block(self, Vector3(50, 1.5, 27.0), Vector3(6, 3, 0.4))           # a wall, its face at z = 27.2
	_put_player(Vector3(50, 1.05, 30.2))
	await _frames(20)
	power.power = power.MAX
	await _hold_blink(20)
	var wall_gap: float = player.global_position.z - 27.2
	var wall_clear: bool = not player.test_move(player.global_transform, Vector3.ZERO)
	_put_player(Vector3(56, 1.05, 30))
	player.get_node("Neck").rotation.x = -0.6
	await _frames(20)
	power.power = power.MAX
	await _hold_blink(20)
	var floor_y: float = player.global_position.y
	var floor_clear: bool = not player.test_move(player.global_transform, Vector3.ZERO)
	player.get_node("Neck").rotation.x = 0.0
	var g11 := _new_guard(Vector3(62, 0, 26), PI)
	g11.set_physics_process(false)
	_put_player(Vector3(62, 1.05, 30))
	await _frames(20)
	power.power = power.MAX
	await _hold_blink(20)
	var guard_gap: float = player.global_position.z - 26.0
	var guard_clear: bool = not player.test_move(player.global_transform, Vector3.ZERO)
	g11.queue_free()
	_check("S11 a blink stops short of a wall, above the floor, in front of a man",
		wall_gap >= 0.5 and wall_clear and floor_y >= 1.0 and floor_clear and guard_gap >= 0.8 and guard_clear,
		"wall gap %.2f clear %s, floor y %.2f clear %s, man gap %.2f clear %s" % [wall_gap, wall_clear, floor_y, floor_clear, guard_gap, guard_clear])

	# S12 from anywhere: hanging, falling, empty-handed; with a sword, a tap dodges
	Props.block(self, Vector3(70, 1.5, 25.0), Vector3(4, 3, 1))
	await _frames(2)
	_put_player(Vector3(70, 1.05, 30))
	await _frames(5)
	var hang_at: Vector3 = player.planner.hang_anchor(Vector3(70, 3.0, 25.5), Vector3.BACK, 3.0)
	player.teleport(Transform3D(Basis.IDENTITY, hang_at))
	player._enter_hang(Vector3.BACK, 3.0, false)
	await _frames(10)
	power.power = power.MAX
	player.rotation.y = PI
	var hung_from: Vector3 = player.global_position
	await _tap("blink")
	await _frames(4)
	var off_hang: bool = player.movement_state == player.MoveState.LOCOMOTION and player.global_position.distance_to(hung_from) > 2.0
	_put_player(Vector3(76, 6.0, 30))
	await _frames(20)
	var falling: float = player.velocity.y
	power.power = power.MAX
	await _tap("blink")
	await _frames(1)
	var kept_fall: bool = player.velocity.y < -2.0
	await _frames(120)
	player.inventory.holster()
	_put_player(Vector3(-50, 1.05, 30))
	await _frames(20)
	power.power = power.MAX
	var bare_from: Vector3 = player.global_position
	await _tap("blink")
	await _frames(4)
	var bare: bool = player.global_position.distance_to(bare_from) > 3.5
	_wield(&"sword")
	_put_player(Vector3(-60, 1.05, 30))
	await _frames(40)
	var dodges := []
	player.combat.dodged.connect(func(d): dodges.append(d), CONNECT_ONE_SHOT)
	power.power = power.MAX
	await _tap("blink")
	await _frames(30)
	var tapped_dodge: bool = dodges.size() == 1 and _near(power.power, 100.0, 0.01)
	_put_player(Vector3(-60, 1.05, 30))
	await _frames(40)
	var sword_from: Vector3 = player.global_position
	await _hold_blink(20)
	var held_blink: bool = player.global_position.distance_to(sword_from) > 3.0 and power.power < 100.0
	_check("S12 Blink from a hang, mid-fall, empty-handed; with a sword a tap is the dodge and a hold the blink",
		off_hang and kept_fall and bare and tapped_dodge and held_blink,
		"off hang %s kept fall %s (%.1f) bare %s sword tap dodged %s sword hold blinked %s" % [off_hang, kept_fall, falling, bare, tapped_dodge, held_blink])

	# S13 a blink out of an unblockable blow answers it, as a dodge does
	_wield(&"revolver")
	var answers := []
	player.combat.answered.connect(func(how): answers.append(how))
	# A wall at his back: the blink out of the blow stays near him (one far
	# away is a plain miss, not an answer; GuardFighter's own rule).
	Props.block(self, Vector3(-40, 1.5, 31.8), Vector3(4, 3, 0.4))
	var g13 := _caller(Vector3(-40, 0, 28.2))
	g13._fighter.attacks = {&"heavy": 1.0}
	g13.attack_cooldown = 5.0
	_put_player(Vector3(-40, 1.05, 30))
	await _frames(20)
	power.power = power.MAX
	g13._attack_timer = 0.0
	await _until(func(): return g13._phase == &"windup" and g13._phase_timer < 0.3, 240)
	Input.action_press("move_back")
	var before13: Vector3 = player.global_position
	await _tap("blink")
	await _frames(2)
	Input.action_release("move_back")
	await _until(func(): return g13._phase != &"windup", 60)
	await _frames(2)
	_check("S13 a blink out of an unblockable blow answers it", answers.has(&"dodged"), "answers %s" % [answers])
	g13.queue_free()

	# S14 aimed at a wall just under its top: the blink ends hanging from it
	# (tall enough to hang from with the feet off the ground)
	Props.block(self, Vector3(-30, 2.25, 10.0), Vector3(4, 4.5, 1))        # top at 4.5, face at z = 10.5
	_put_player(Vector3(-30, 1.05, 16.5))
	await _frames(20)
	_aim(Vector3(-30, 3.9, 10.5))
	power.power = power.MAX
	await _hold_blink(20)
	await _frames(1)
	var hanging: bool = player.movement_state == player.MoveState.HANGING
	_check("S14 a blink aimed just under a wall's top ends hanging from it",
		hanging and _near(player.hang_lip_y, 4.5, 0.05) and not player.test_move(player.global_transform, Vector3.ZERO),
		"state %d lip %.2f at %s" % [player.movement_state, player.hang_lip_y, player.global_position])
	player._drop_from_hang()
	await _frames(60)

	# S15 a shard from the bare hand's circle: 40 into a man 8 m off
	_wield(&"revolver")
	caster.select(&"shard")
	var g15 := _caller(Vector3(-20, 0, 22))
	g15.set_physics_process(false)
	_put_player(Vector3(-20, 1.05, 30))
	await _frames(20)
	_aim(g15.global_position + Vector3(0, 1.25, 0))
	power.power = power.MAX
	var ear := Ear.new()
	SoundBus.add_listener(ear)
	done.clear()
	Input.action_press("block")
	await _until(func(): return not done.is_empty(), 60)
	Input.action_release("block")
	await _frames(20)
	SoundBus.remove_listener(ear)
	_check("S15 a shard does 40 to a man 8 m off", _near(g15.health, 60.0, 0.1), "health %.1f" % g15.health)
	g15.queue_free()

	# S17 it is quiet beside the gun: a hiss, no gunshot
	var hiss: Array = ear.events.filter(func(e): return e["kind"] == &"shard")
	var bang: Array = ear.events.filter(func(e): return e["kind"] == &"gunshot")
	_check("S17 a shard is heard at 36 dB, and is no gunshot", not hiss.is_empty() and _near(hiss[0]["db"], 36.0, 0.01) and bang.is_empty(),
		"shard %s gunshot %d" % [hiss.map(func(e): return e["db"]), bang.size()])

	# S16 into the thigh of a man near done for: the leg comes off
	var parts_before := _severed_parts()
	var g16 := _caller(Vector3(-14, 0, 22))
	g16.set_physics_process(false)
	g16.health = 30.0
	_put_player(Vector3(-14, 1.05, 30))
	await _frames(20)
	_aim(g16.global_position + Vector3(0.12, 0.7, 0))
	power.power = power.MAX
	done.clear()
	Input.action_press("block")
	await _until(func(): return not done.is_empty(), 60)
	Input.action_release("block")
	await _frames(30)
	_check("S16 a killing shard in the thigh takes the leg off", not is_instance_valid(g16) and _severed_parts() > parts_before,
		"alive %s parts %d -> %d" % [is_instance_valid(g16), parts_before, _severed_parts()])


# Helpers

## Q held past a tap: aiming; let go, and the blink goes to the mark.
func _hold_blink(frames: int) -> void:
	Input.action_press("blink")
	await _frames(frames)
	Input.action_release("blink")
	await _frames(4)


## A guard who strikes when told, and does nothing else.
func _caller(at: Vector3) -> CharacterBody3D:
	GarrisonScript.clear_all()
	var g: CharacterBody3D = GUARD.instantiate()
	g.archetype = &""
	g.debug_ai = false
	g.position = at
	g.rotation.y = PI
	add_child(g)
	g.block_chance = 0.0
	g._fighter.parry_chance = 0.0
	g._fighter.feint_chance = 0.0
	g._fighter.dodge_chance = 0.0
	g._fighter.counter_chance = 0.0
	g._fighter.kick_chance = 0.0
	g._fighter.backstep_chance = 0.0
	g._fighter.lunge_chance = 0.0
	g._fighter.leap_chance = 0.0
	g._fighter.charge_chance = 0.0
	g._fighter.timing_variance = 0.0
	g._engage(player)
	return g

## A world point as the viewmodel draws it (pixels): the arms and what they
## hold are drawn with their own field of view (ViewArms.view_fov).
func _on_screen_point(p: Vector3) -> Vector2:
	var cam: Camera3D = player.camera
	var size: Vector2 = get_viewport().get_visible_rect().size
	var grow: float = tan(deg_to_rad(cam.fov) * 0.5) / tan(deg_to_rad(player.hand._arms.view_fov(cam.fov)) * 0.5)
	return size * 0.5 + (cam.unproject_position(p) - size * 0.5) * grow


## Limbs and heads cut off anyone, lying about (SeveredPart.gd).
func _severed_parts() -> int:
	var count := 0

	for b in get_tree().get_nodes_in_group(&"bodies"):
		if b.get("part") != null:
			count += 1

	return count


func _wield(weapon_id: StringName) -> void:
	player.inventory.select_by_id(weapon_id)


## A guard already fighting you, facing you, who will not strike first.
## Lit, so he can see who he is fighting.
func _fighter(at: Vector3) -> CharacterBody3D:
	# A new fight: no dread carried over from the last one's dead.
	GarrisonScript.clear_all()
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
	return g


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
	for a in ["move_forward", "move_back", "move_left", "move_right", "jump", "sprint", "crouch", "frob", "throw", "block", "kick", "reload", "barrel", "grip", "blink"]:
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
