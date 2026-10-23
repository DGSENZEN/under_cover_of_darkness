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


# Helpers

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
