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
const WardScript := preload("res://scripts/Magic/Ward.gd")
const ArrowScript := preload("res://scripts/Combat/Arrow.gd")
const MagicFx := preload("res://scripts/Visual/MagicFx.gd")
const MagicView := preload("res://scripts/Visual/MagicView.gd")


## A source that says what it is, as Barrel and Arrow do (attack_info).
class Blaster:
	extends Node

	func attack_info() -> Dictionary:
		return {"type": &"blast", "unblockable": true}


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
	Input.action_press("spell_1")
	await _frames(22)
	var early := done.size()
	await _frames(4)
	Input.action_release("spell_1")
	_check("S4 a hand spell is cast in 0.4 s and costs 15", early == 0 and done == [&"shard"] and _near(power.power, 85.0, 0.01),
		"at 22 %d then %s power %.1f" % [early, done, power.power])
	await _frames(10)

	# S5 a tome spell takes the pages' 1.2 s
	power.power = power.MAX
	caster.select(&"empower")
	await _frames(30)
	done.clear()
	Input.action_press("spell_3")
	await _frames(70)
	var at_seventy := done.size()
	await _frames(4)
	Input.action_release("spell_3")
	_check("S5 a tome spell is cast in 1.2 s and costs 50", at_seventy == 0 and done == [&"empower"] and _near(power.power, 50.0, 0.01),
		"at 70 %d then %s power %.1f" % [at_seventy, done, power.power])
	await _frames(10)

	# S6 a hard hit breaks a tome spell, for nothing
	power.power = power.MAX
	done.clear()
	broken.clear()
	Input.action_press("spell_3")
	await _frames(30)
	player.take_damage(30.0, null)
	await _frames(2)
	var after_hit: StringName = caster.casting()
	await _frames(60)
	Input.action_release("spell_3")
	_check("S6 a hard hit breaks a tome spell, and nothing is spent",
		broken == [&"empower"] and done.is_empty() and after_hit == &"" and _near(power.power, 100.0, 0.01),
		"broken %s done %s casting %s power %.1f" % [broken, done, after_hit, power.power])
	await _frames(10)

	# S6b a light blast still breaks it: the kind of blow, not only its weight
	power.power = power.MAX
	broken.clear()
	var blaster := Blaster.new()
	add_child(blaster)
	Input.action_press("spell_3")
	await _frames(30)
	player.take_damage(10.0, blaster)
	await _frames(2)
	Input.action_release("spell_3")
	blaster.queue_free()
	_check("S6b a blast breaks a tome spell however light", broken == [&"empower"], "broken %s" % [broken])
	await _frames(10)

	# S7 let go early, or put the gun away: no spell, nothing spent
	power.power = power.MAX
	caster.select(&"shard")
	done.clear()
	Input.action_press("spell_1")
	await _frames(10)
	Input.action_release("spell_1")
	await _frames(30)
	var let_go := done.size()
	Input.action_press("spell_1")
	await _frames(10)
	_wield(&"sword")
	await _frames(30)
	Input.action_release("spell_1")
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
	Input.action_press("aim")
	await _frames(30)
	var braced_shard: bool = caster.can_cast(&"shard")
	Input.action_release("aim")
	await _frames(15)
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
	Input.action_press("spell_1")
	await _until(func(): return not done.is_empty(), 60)
	Input.action_release("spell_1")
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
	Input.action_press("spell_1")
	await _until(func(): return not done.is_empty(), 60)
	Input.action_release("spell_1")
	await _frames(30)
	_check("S16 a killing shard in the thigh takes the leg off", not is_instance_valid(g16) and _severed_parts() > parts_before,
		"alive %s parts %d -> %d" % [is_instance_valid(g16), parts_before, _severed_parts()])

	# S18 the ward stops an arrow a metre out
	player.invulnerable = false
	player.health = player.max_health
	_wield(&"revolver")
	_put_player(Vector3(-10, 1.05, 0))
	await _frames(20)
	await _cast_ward()
	var archer := _caller(Vector3(-10, 0, -10))
	archer.set_physics_process(false)
	var stopped_at := [Vector3.INF]
	var arrow := _arrow_at_player(archer)
	arrow.tree_exiting.connect(func(): stopped_at[0] = arrow.global_position)
	await _frames(30)
	var gap: float = stopped_at[0].distance_to(player.global_position + Vector3.UP * WardScript.HEIGHT) if stopped_at[0] != Vector3.INF else -1.0
	_check("S18 a ward stops an arrow a metre out", _near(player.health, player.max_health, 0.01) and _near(gap, 1.0, 0.15),
		"health %.1f stopped %.2f from the middle" % [player.health, gap])

	# S20 your own shot goes out through it
	var g20 := _caller(Vector3(-10, 0, -6))
	g20.set_physics_process(false)
	await _frames(2)
	_aim(g20.global_position + Vector3(0, 1.25, 0))
	player.revolver.reset_for_practice()
	await _tap("throw")
	await _frames(4)
	_check("S20 your own shot goes out through your ward", _near(g20.health, 45.0, 0.1), "health %.1f" % g20.health)
	g20.queue_free()

	# S19 a blade is not stopped by it
	player.health = player.max_health
	var g19 := _caller(Vector3(-10, 0, -1.6))
	g19._fighter.attacks = {&"overhead": 1.0}
	g19.attack_cooldown = 5.0
	await _cast_ward()
	g19._attack_timer = 0.0
	await _until(func(): return player.health < player.max_health, 240)
	_check("S19 a blade comes through a ward", player.health < player.max_health and not WardScript.active.is_empty(),
		"health %.1f wards %d" % [player.health, WardScript.active.size()])
	g19.queue_free()

	# S21 after its four seconds it is gone, and arrows land again
	await _frames(int(WardScript.LIFE * 60.0) + 5)
	var gone := WardScript.active.is_empty()
	player.health = player.max_health
	var late := _arrow_at_player(archer)
	await _frames(30)
	_check("S21 a ward lasts four seconds; then arrows land again", gone and player.health < player.max_health,
		"wards %d health %.1f" % [WardScript.active.size(), player.health])
	archer.queue_free()
	player.invulnerable = true
	player.health = player.max_health

	# S22 empowered, a kick is three times the blow, and throws him
	_wield(&"revolver")
	_put_player(Vector3(0, 1.05, -20))
	await _frames(20)
	await _cast(&"empower")
	var g22 := _caller(Vector3(0, 0, -21.6))
	g22.set_physics_process(false)
	await _frames(2)
	await _tap("kick")
	await _frames(30)
	# (60 as a blast, and the boot's own 6 if it throws him off his feet.)
	_check("S22 empowered, a kick lands three times a whip's blow, once", g22.health >= 33.9 and g22.health <= 40.1 and not caster.empowered(),
		"health %.1f still empowered %s" % [g22.health, caster.empowered()])
	g22.queue_free()

	# S23 a tapped jump keeps it; a held jump spends it, and goes twice as high
	_put_player(Vector3(6, 1.05, -20))
	await _frames(20)
	var plain := await _jump_apex(40)
	await _cast(&"empower")
	var tapped := await _jump_apex(6)
	var kept23: bool = caster.empowered()
	var held := await _jump_apex(40)
	_check("S23 empowered: a tapped jump keeps the charge, a held one spends it on twice the height",
		kept23 and not caster.empowered() and absf(held / plain - 2.0) <= 0.2 and tapped < plain,
		"plain %.2f tapped %.2f held %.2f (x%.2f) kept %s" % [plain, tapped, held, held / plain, kept23])

	# S24 empowered, a blink goes twice as far
	_put_player(Vector3(12, 1.05, -10))
	await _frames(20)
	await _cast(&"empower")
	var from24: Vector3 = player.global_position
	await _tap("blink")
	await _frames(4)
	_check("S24 empowered, a tapped blink goes 8 m", _near(from24.z - player.global_position.z, 8.0, 0.3),
		"moved %.2f" % (from24.z - player.global_position.z))

	# S25 unused, it fades after eight seconds
	await _cast(&"empower")
	await _frames(8 * 60 + 5)
	_check("S25 an unused charge fades after 8 s", not caster.empowered(), "empowered %s" % caster.empowered())

	# S26 empowered, a ball from the cylinder throws a man as a blast does
	_put_player(Vector3(18, 1.05, -10))
	await _frames(20)
	await _cast(&"empower")
	var g26 := _caller(Vector3(18, 0, -16))
	g26.set_physics_process(false)
	g26.health = 50.0
	var thrown := [0.0]
	g26.tree_exiting.connect(func(): thrown[0] = g26._last_push.length())
	_aim(g26.global_position + Vector3(0, 1.25, 0))
	player.revolver.reset_for_practice()
	await _frames(2)
	await _tap("throw")
	await _frames(10)
	_check("S26 empowered, a ball throws the man it kills, as a blast", not is_instance_valid(g26) and thrown[0] > 5.0,
		"alive %s thrown %.1f" % [is_instance_valid(g26), thrown[0]])

	# S27 a spell key with the sword drawn: the revolver comes, then the spell
	_wield(&"sword")
	_put_player(Vector3(24, 1.05, -10))
	await _frames(30)
	power.power = power.MAX
	done.clear()
	Input.action_press("spell_1")
	await _until(func(): return not done.is_empty(), 60)
	Input.action_release("spell_1")
	_check("S27 holding 1 with the sword drawn draws the revolver and casts Shard",
		done == [&"shard"] and player.combat.gun_drawn(), "done %s gun %s" % [done, player.combat.gun_drawn()])
	await _frames(20)

	# S28 aimed, a spell key lowers the sights and casts
	Input.action_press("aim")
	await _frames(20)
	power.power = power.MAX
	done.clear()
	Input.action_press("spell_2")
	await _frames(15)
	var lowered: float = player.revolver.aim_amount()
	await _until(func(): return not done.is_empty(), 60)
	Input.action_release("spell_2")
	Input.action_release("aim")
	_check("S28 aimed, holding 2 lowers the sights and casts Ward", lowered == 0.0 and done == [&"ward"],
		"aim at 15 frames %.2f done %s" % [lowered, done])
	await _frames(WardScript.LIFE * 60.0 + 10)

	# S29 put away mid-cast, or a key tapped as the gun comes up: nothing
	power.power = power.MAX
	done.clear()
	Input.action_press("spell_1")
	await _frames(10)
	_wield(&"sword")
	await _frames(40)
	Input.action_release("spell_1")
	await _frames(20)
	var switched := done.size()
	await _tap("spell_1")
	await _frames(60)
	_check("S29 a spell put away mid-cast, or tapped as the gun comes up, casts nothing and costs nothing",
		switched == 0 and done.is_empty() and _near(power.power, 100.0, 0.01),
		"after the switch %d, tapped %s power %.1f" % [switched, done, power.power])

	# M1 Shard's circle: twelve black-glass splinters, not boxes
	_wield(&"revolver")
	_put_player(Vector3(-50, 1.05, -20))
	await _frames(40)
	power.power = power.MAX
	Input.action_press("spell_1")
	await _frames(12)
	var pieces1: Array = player.hand._circle_pieces.filter(func(p): return p.visible and player.hand._circle.visible)
	var glassy: bool = pieces1.size() == 12 and pieces1.all(func(p): return not (p.mesh is BoxMesh) and p.material_override is BaseMaterial3D and (p.material_override as BaseMaterial3D).metallic >= 0.8)
	Input.action_release("spell_1")
	await _frames(30)
	_check("M1 Shard's circle is twelve splinters of black glass", glassy, "visible %d" % pieces1.size())

	# M2 Ward's circle: tendrils of ward smoke, not balls
	power.power = power.MAX
	Input.action_press("spell_2")
	await _frames(12)
	var pieces2: Array = player.hand._circle_pieces
	var smoky: bool = player.hand._circle.visible and pieces2.all(func(p): return not (p.mesh is SphereMesh) and p.material_override is ShaderMaterial and (p.material_override as ShaderMaterial).get_shader_parameter(&"core").is_equal_approx(Color("#F2FAFC")))
	Input.action_release("spell_2")
	await _frames(30)
	_check("M2 Ward's circle is tendrils of ward smoke", smoky, "pieces %d" % pieces2.size())

	# M3 let go half way: the circle goes at once
	power.power = power.MAX
	Input.action_press("spell_1")
	await _frames(10)
	Input.action_release("spell_1")
	await _frames(2)
	_check("M3 a cast let go of half way takes its circle with it", not player.hand._circle.visible, "visible %s" % player.hand._circle.visible)
	await _frames(20)

	# M4 with the world's effects off, the spells still cast and leave none
	Fx.enabled = false
	power.power = power.MAX
	await _tap("blink")
	await _frames(10)
	power.power = power.MAX
	Input.action_press("spell_1")
	await _frames(30)
	Input.action_release("spell_1")
	await _frames(30)
	power.power = power.MAX
	Input.action_press("spell_2")
	await _frames(30)
	Input.action_release("spell_2")
	await _frames(5)
	var left_over: int = MagicFx.live_count()
	Fx.enabled = true
	await _frames(WardScript.LIFE * 60.0)
	_check("M4 with effects off, spells cast and leave no effects", left_over == 0, "magic effects %d" % left_over)

	# M5 the shard spins about its length as it flies
	Props.block(self, Vector3(-60, 1.5, -44), Vector3(6, 3, 0.4))           # a stone wall, its face at z = -43.8
	_wield(&"revolver")
	_put_player(Vector3(-60, 1.05, -24))
	await _frames(40)
	power.power = power.MAX
	Input.action_press("spell_1")
	await _until(func(): return not get_tree().get_nodes_in_group(&"shards").is_empty(), 60)
	Input.action_release("spell_1")
	var shard: Node = get_tree().get_nodes_in_group(&"shards")[0] if not get_tree().get_nodes_in_group(&"shards").is_empty() else null
	var spun := -1.0

	if shard != null:
		var spin_before: float = shard.spin
		await get_tree().physics_frame
		spun = shard.spin - spin_before if is_instance_valid(shard) else -1.0

	_check("M5 the shard spins about its length as it flies", _near(spun, 14.0 / 60.0, 0.05), "per frame %.3f rad" % spun)

	# M6 on stone it shatters into black glass, gone in a moment
	await _until(func(): return not get_tree().get_nodes_in_group(&"shatter").is_empty(), 60)
	await _frames(1)
	var shards_out: int = get_tree().get_nodes_in_group(&"shatter").size()
	await _frames(int(1.5 * 60.0) + 5)
	_check("M6 a shard shatters on stone into eight splinters, gone after 1.5 s",
		shards_out == 8 and get_tree().get_nodes_in_group(&"shatter").is_empty(),
		"splinters %d after %d" % [shards_out, get_tree().get_nodes_in_group(&"shatter").size()])

	# B1 B2 B3 a blink: a mirror-crack where you stood, a ripple where you
	# land, a cold flash at the edges of the view
	_put_player(Vector3(-40, 1.05, 20))
	await _frames(40)
	power.power = power.MAX
	Input.action_press("blink")
	await _frames(2)
	Input.action_release("blink")
	var mirrors := 0
	var rippled := false
	var cold := 0.0

	for i in 3:
		await get_tree().physics_frame
		mirrors = maxi(mirrors, get_tree().get_nodes_in_group(&"mirror").size())
		cold = maxf(cold, MagicView.of(get_tree()).cold_amount())

		for r in get_tree().get_nodes_in_group(&"ripple"):
			rippled = rippled or (r as Node3D).global_position.distance_to(player.global_position + Vector3.UP * MagicFx.RIPPLE_HEIGHT) <= 0.5

	await _frames(10)
	var cold_after: float = MagicView.of(get_tree()).cold_amount()
	await _frames(int(MagicFx.MIRROR_LIFE * 60.0))
	_check("B1 a blink leaves ten mirror shards where you stood, gone in 0.6 s",
		mirrors == 10 and get_tree().get_nodes_in_group(&"mirror").is_empty(), "shards %d after %d" % [mirrors, get_tree().get_nodes_in_group(&"mirror").size()])
	_check("B2 you arrive in a ripple, gone in 0.3 s", rippled and get_tree().get_nodes_in_group(&"ripple").is_empty(),
		"rippled %s after %d" % [rippled, get_tree().get_nodes_in_group(&"ripple").size()])
	_check("B3 a cold flash at the edges of the view, gone in 0.1 s", cold > 0.0 and cold_after == 0.0, "flash %.2f after %.2f" % [cold, cold_after])

	# B4 ten blinks in a row: the effects stay bounded and clear
	var most_magic := 0

	for i in 10:
		power.power = power.MAX
		await _tap("blink")

		for k in 12:
			await get_tree().physics_frame
			most_magic = maxi(most_magic, MagicFx.live_count())

	await _frames(60)
	_check("B4 ten blinks: never more than 40 effects, none left after a second",
		most_magic <= 40 and MagicFx.live_count() == 0, "most %d after %d" % [most_magic, MagicFx.live_count()])

	# W1 the ward rises as twelve plumes of ward smoke
	_wield(&"revolver")
	_put_player(Vector3(-30, 1.05, 40))
	await _frames(40)
	await _cast_ward()
	var ward: Node3D = WardScript.active[0].get_ref() if not WardScript.active.is_empty() else null
	var plumes: Array = ward.get_children().filter(func(c): return c.is_in_group(&"ward_plume")) if ward != null else []
	var coloured: bool = not plumes.is_empty() and plumes.all(func(p): return (p.material_override as ShaderMaterial).get_shader_parameter(&"core").is_equal_approx(Color("#F2FAFC")))
	var rising: float = (plumes[0].material_override as ShaderMaterial).get_shader_parameter(&"erosion") if not plumes.is_empty() else -1.0
	await _frames(25)
	var risen: float = (plumes[0].material_override as ShaderMaterial).get_shader_parameter(&"erosion") if not plumes.is_empty() and is_instance_valid(plumes[0]) else -1.0
	_check("W1 the ward rises as twelve plumes of ward smoke", plumes.size() == 12 and coloured and rising > 0.5 and _near(risen, WardScript.STANDING, 0.05),
		"plumes %d coloured %s erosion %.2f then %.2f" % [plumes.size(), coloured, rising, risen])

	# W2 a stopped arrow bulges the smoke where it struck
	var archer2 := _caller(Vector3(-30, 0, 30))
	archer2.set_physics_process(false)
	var bulges_before: int = ward.bulge_count() if is_instance_valid(ward) else -1
	_arrow_at_player(archer2)
	await _frames(20)
	var bulged: int = (ward.bulge_count() if is_instance_valid(ward) else -1) - bulges_before
	var puffs: int = get_tree().get_nodes_in_group(&"ward_bulge").size()
	await _frames(int(0.45 * 60.0) + 5)
	_check("W2 a stopped arrow bulges the smoke there, and it settles", bulged == 1 and puffs == 3 and get_tree().get_nodes_in_group(&"ward_bulge").is_empty(),
		"bulges +%d puffs %d after %d" % [bulged, puffs, get_tree().get_nodes_in_group(&"ward_bulge").size()])

	# W4 a volley of eight: at most six bulges, all gone with the ward
	var most_bulges := 0
	for i in 8:
		_arrow_at_player(archer2)
	for i in 30:
		await get_tree().physics_frame
		most_bulges = maxi(most_bulges, ward.bulge_count() if is_instance_valid(ward) else 0)

	# W3 when its time is up nothing of it is left
	await _frames(int(WardScript.LIFE * 60.0))
	_check("W4 a volley bulges the ward at most six times", most_bulges <= 6 and most_bulges >= 1, "most %d" % most_bulges)
	_check("W3 when the ward ends, none of its smoke is left",
		get_tree().get_nodes_in_group(&"ward_plume").is_empty() and get_tree().get_nodes_in_group(&"ward_bulge").is_empty(),
		"plumes %d bulges %d" % [get_tree().get_nodes_in_group(&"ward_plume").size(), get_tree().get_nodes_in_group(&"ward_bulge").size()])
	archer2.queue_free()

	# S30 aiming a blink, a fresh right mouse lets it go, and raises no sights
	_wield(&"revolver")
	_put_player(Vector3(30, 1.05, -10))
	await _frames(30)
	power.power = power.MAX
	var from30: Vector3 = player.global_position
	Input.action_press("blink")
	await _frames(20)
	Input.action_press("aim")
	await _frames(10)
	var sights: float = player.revolver.aim_amount()
	Input.action_release("blink")
	await _frames(6)
	Input.action_release("aim")
	_check("S30 right mouse lets an aimed blink go without raising the sights",
		player.global_position.distance_to(from30) < 0.3 and sights == 0.0 and _near(power.power, 100.0, 0.01),
		"moved %.2f sights %.2f power %.1f" % [player.global_position.distance_to(from30), sights, power.power])


# Helpers

## The key a spell is cast from (1 Shard, 2 Ward, 3 Empower).
func _key_of(id: StringName) -> String:
	return "spell_%d" % ([&"shard", &"ward", &"empower"].find(id) + 1)


## A spell cast with the gun drawn: its key held until it is done.
func _cast(id: StringName) -> void:
	player.caster.select(id)
	player.power.power = player.power.MAX
	await _frames(20)
	var cast := [false]
	var on_done := func(done_id): cast[0] = cast[0] or done_id == id
	player.caster.cast_done.connect(on_done)
	Input.action_press(_key_of(id))
	await _until(func(): return cast[0], 120)
	Input.action_release(_key_of(id))
	player.caster.cast_done.disconnect(on_done)
	await _frames(2)


## A jump with the key held `held` frames: how high it rose (metres).
func _jump_apex(held: int) -> float:
	var start: float = player.global_position.y
	var top := start
	Input.action_press("jump")

	for i in 90:
		if i == held:
			Input.action_release("jump")

		await get_tree().physics_frame
		top = maxf(top, player.global_position.y)

	Input.action_release("jump")
	await _frames(30)
	return top - start


## The Ward, cast: the copal circle closed.
func _cast_ward() -> void:
	player.caster.select(&"ward")
	player.power.power = player.power.MAX
	var cast := [false]
	var on_done := func(id): cast[0] = cast[0] or id == &"ward"
	player.caster.cast_done.connect(on_done)
	Input.action_press("spell_2")
	await _until(func(): return cast[0], 60)
	Input.action_release("spell_2")
	player.caster.cast_done.disconnect(on_done)
	await _frames(2)


## An arrow loosed at the player's chest by `archer`, at 40 m/s.
func _arrow_at_player(archer: Node3D) -> Node3D:
	var arrow: StaticBody3D = ArrowScript.new()
	add_child(arrow)
	var from: Vector3 = archer.global_position + Vector3.UP * 1.5
	var chest: Vector3 = player.global_position + Vector3.UP * 0.4
	arrow.launch(from, (chest - from).normalized() * 40.0, 20.0, archer, 2.5)
	arrow.gravity = 0.0
	return arrow


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
	for a in ["move_forward", "move_back", "move_left", "move_right", "jump", "sprint", "crouch", "frob", "throw", "block", "kick", "reload", "barrel", "aim", "blink", "spell_1", "spell_2", "spell_3"]:
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
