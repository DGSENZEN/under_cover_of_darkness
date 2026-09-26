extends Node3D
## Things that used to break, found by review and fixed: each check plays out
## the exact situation that went wrong, so it cannot quietly come back.

const PLAYER := preload("res://Player.tscn")
const GUARD := preload("res://Guard.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")
const WeaponScript := preload("res://scripts/Combat/Weapon.gd")
const CameraJuice := preload("res://scripts/PlayerUtils/CameraJuice.gd")
const Fx := preload("res://scripts/Visual/Fx.gd")

var player: CharacterBody3D
var results: Array[String] = []


## Asks for effects while the level is still being built, as a spawner or a
## level script might.
class EarlyEffects:
	extends Node3D

	func _ready() -> void:
		Fx.dust(self, Vector3(0, 1, 0), Vector3.UP, 1.0)
		Fx.sparks(self, Vector3(0, 1, 0), Vector3.UP, 1.0)


func _ready() -> void:
	Props.block(self, Vector3(0, -0.5, 0), Vector3(200, 1, 200))
	Props.block(self, Vector3(20, 1.5, -1.0), Vector3(4, 3, 0.3))        # a wall to shoot and kick against
	Props.spikes(self, Vector3(40, 1.0, -3.0), 6.0, 2.0, Vector3.BACK)     # a spiked wall, face at z = -3
	Props.block(self, Vector3(40, 1.0, -3.3), Vector3(6.2, 2.0, 0.6))

	var early_a := EarlyEffects.new()
	var early_b := EarlyEffects.new()
	add_child(early_a)
	add_child(early_b)

	var baker := NavigationRegion3D.new()
	baker.set_script(NavBakerScript)
	add_child(baker)

	player = PLAYER.instantiate()
	add_child(player)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.invulnerable = true
	player.reload_on_death = false

	if player.has_node("LightGem"):
		player.get_node("LightGem").queue_free()

	player.global_position = Vector3(0, 1.05, 10)
	Props.give_weapons(player)

	await baker.baked
	await _frames(10)
	await _run()

	print("\n==== RESULTS ====")
	for r in results:
		print(r)

	get_tree().quit()


func _run() -> void:
	var combat: Node = player.combat

	# U1 effects asked for during setup: one effects node, and it works
	var fx_nodes := 0

	for child in get_children():
		if String(child.name).begins_with("Fx"):
			fx_nodes += 1

	_check("U1 effects asked for while the level is built land in one node", fx_nodes == 1 and Fx.world_node() != null,
		"effects nodes %d" % fx_nodes)

	# U2 putting the weapon away mid-charge ends the charge cleanly
	player.inventory.select_by_id(&"sword")
	_put_player(Vector3(0, 1.05, 10), 0.0)
	await _frames(20)
	Input.action_press("throw")
	await _frames(30)
	var charging: bool = combat.phase == combat.Phase.CHARGING
	player.inventory.holster()
	await _frames(5)
	Input.action_release("throw")
	await _frames(20)
	_check("U2 putting the sword away mid-charge ends the attack", charging and combat.phase == combat.Phase.IDLE and combat.speed_scale() == 1.0 and player.juice._zoom == 0.0,
		"was charging %s phase %d speed x%.2f zoom %.1f" % [charging, combat.phase, combat.speed_scale(), player.juice._zoom])

	# U3 a charge does not carry into the bow, nor a drawn arrow into the dagger
	player.inventory.select_by_id(&"sword")
	await _frames(20)
	Input.action_press("throw")
	await _frames(40)
	player.inventory.select_by_id(&"bow")
	await _frames(3)
	var after_swap: int = combat.phase
	Input.action_release("throw")
	await _frames(20)
	player.inventory.select_by_id(&"bow")
	await _frames(20)
	var arrows_before: int = combat.arrow_count()
	Input.action_press("throw")
	await _frames(40)
	player.inventory.select_by_id(&"dagger")
	await _frames(3)
	Input.action_release("throw")
	await _frames(20)
	_check("U3 swapping weapons cancels the old weapon's attack", after_swap != combat.Phase.CHARGING and combat.arrow_count() == arrows_before and combat.phase == combat.Phase.IDLE,
		"phase after swap %d arrows %d -> %d" % [after_swap, arrows_before, combat.arrow_count()])

	# U4 an arrow loosed against a wall sticks in the wall, not in the guard
	#    behind it
	player.inventory.select_by_id(&"bow")
	var behind := _guard(Vector3(20, 0, -3.0))
	behind.health = 500.0
	_put_player(Vector3(20, 1.05, -0.35), 0.0)
	await _frames(20)
	Input.action_press("throw")
	await _frames(60)
	Input.action_release("throw")
	await _frames(30)
	_check("U4 an arrow loosed point-blank at a wall stays this side of it", behind.health == 500.0,
		"guard behind the wall %.0f / 500" % behind.health)

	# U5 a kick does not go through a wall either
	player.inventory.select_by_id(&"sword")
	behind.global_position = Vector3(20, 0, -1.7)
	await _frames(10)
	var before_kick: float = behind.health
	await _tap("kick")
	await _frames(30)
	_check("U5 a kick does not reach through a wall", behind.health == before_kick and behind._knock <= 0.0,
		"health %.0f -> %.0f knocked %s" % [before_kick, behind.health, behind._knock > 0.0])
	behind.queue_free()

	# U6 one arrow mesh, however long the bow is held
	var first := WeaponScript.arrow_mesh()
	_check("U6 the arrow is one shared mesh", WeaponScript.arrow_mesh() == first, "same %s" % (WeaponScript.arrow_mesh() == first))

	# U7 camera springs survive a long frame
	var juice := CameraJuice.new()
	var camera := Camera3D.new()
	add_child(camera)
	juice.setup(camera)
	juice.punch(3.0, 2.0, 1.0)

	for i in 12:
		juice.update(0.25, 0.0, 4.0, 0.0, true, false, false, 0, 0.0)

	_check("U7 a 250 ms frame does not throw the camera", absf(juice._pitch) < 0.2 and absf(juice._yaw) < 0.2,
		"pitch %.3f yaw %.3f" % [juice._pitch, juice._yaw])
	camera.queue_free()

	# U8 a blow from the right turns the head to the left
	var hit_juice := CameraJuice.new()
	hit_juice.hurt_from(Vector3(1, 0, 0), 1.0)
	_check("U8 a blow from the right snaps the head left", hit_juice._yaw_velocity > 0.0,
		"yaw velocity %.2f" % hit_juice._yaw_velocity)

	# U9 a guard under a moved, turned parent falls where he stood, and so
	#    does his sword
	var group := Node3D.new()
	add_child(group)
	group.global_transform = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(60, 0, 20))
	var grouped: CharacterBody3D = GUARD.instantiate()
	group.add_child(grouped)
	grouped.global_position = Vector3(60, 0, 25)
	grouped.reset_physics_interpolation()
	await _frames(10)
	var stood := grouped.global_position
	grouped.die(null)
	await _frames(3)
	var body := _last_body()
	var sword: Node3D = null

	for child in group.get_children():
		if String(child.name).begins_with("DroppedSword"):
			sword = child

	var body_gap: float = Vector2(body.global_position.x - stood.x, body.global_position.z - stood.z).length() if body != null else INF
	var sword_gap: float = Vector2(sword.global_position.x - stood.x, sword.global_position.z - stood.z).length() if sword != null else INF
	_check("U9 under a moved parent, the body and sword fall where he stood", body_gap < 1.2 and sword_gap < 1.5,
		"body %.2f m away, sword %.2f m away" % [body_gap, sword_gap])

	# U10 a guard chasing along a spiked wall brushes it and lives
	var runner := _guard(Vector3(37.5, 0, -2.4))
	runner._attack_timer = 999.0
	runner.velocity = Vector3(4.6, 0, 0)
	runner.hazard_hit(_spikes(), 2.5)
	await _frames(2)
	var survived: bool = is_instance_valid(runner) and not runner._knocked_out
	_check("U10 running along spikes is not running into them", survived, "alive %s" % survived)

	if is_instance_valid(runner):
		runner.queue_free()

	# U12 an arrow in a crate goes with the crate when it is kicked
	player.inventory.select_by_id(&"bow")
	var target := Props.crate(self, Vector3(100, 0.4, 4.0), 0.8, 20.0)
	_put_player(Vector3(100, 1.05, 10), 0.0)
	await _frames(20)
	_aim(target.global_position)
	await _frames(3)
	var fired := []
	combat.fired.connect(func(a): fired.append(a), CONNECT_ONE_SHOT)
	Input.action_press("throw")
	await _frames(40)
	Input.action_release("throw")
	await _frames(40)
	var arrow: Node3D = fired[0] if not fired.is_empty() and is_instance_valid(fired[0]) else null
	var in_crate: bool = arrow != null and arrow.get_parent() == target
	var offset_before := (arrow.global_position - target.global_position) if arrow != null else Vector3.INF
	target.apply_central_impulse(Vector3(0, 0, -150))
	await _frames(40)
	var offset_after := (arrow.global_position - target.global_position) if arrow != null else Vector3.ZERO
	_check("U12 an arrow stuck in a crate goes where the crate goes", in_crate and offset_before.distance_to(offset_after) < 0.6,
		"in the crate %s, its offset moved %.2f m" % [in_crate, offset_before.distance_to(offset_after)])

	# U13 a kick does not re-open the parry window for a guard already held up
	player.inventory.select_by_id(&"sword")
	_put_player(Vector3(0, 1.05, 30), 0.0)
	await _frames(10)
	Input.action_press("block")
	await _frames(60)
	var held_parry: bool = combat.is_parrying()
	await _tap("kick")
	await _frames(40)
	var after_kick: bool = combat.is_parrying()
	var still_blocking: bool = combat.blocking
	Input.action_release("block")
	_check("U13 a kick does not turn a held guard back into a parry", not held_parry and not after_kick and still_blocking,
		"parrying while held %s after the kick %s guard back up %s" % [held_parry, after_kick, still_blocking])

	# U14 a body shouldered mid-fall stops falling, and does not bleed a pool
	#     where it no longer lies
	var falling_guard := _guard(Vector3(0, 0, 38.8))
	_put_player(Vector3(0, 1.05, 40), 0.0)
	await _frames(10)
	falling_guard.die(null)
	await _frames(3)
	var corpse := _last_body()
	var was_falling: bool = corpse.is_falling()
	var stains_before := Fx.stains_in_use()
	_aim(corpse.global_position)
	await _frames(2)
	await _tap("frob")
	await _frames(90)
	var shouldered: bool = player.frob.is_shouldering()
	_check("U14 a body lifted mid-fall stops falling and leaves no pool behind", was_falling and shouldered and not corpse.is_falling() and Fx.stains_in_use() == stains_before,
		"was falling %s shouldered %s still falling %s stains %d -> %d" % [was_falling, shouldered, corpse.is_falling(), stains_before, Fx.stains_in_use()])
	await _tap("frob")
	await _frames(30)

	# U15 a swing drawn at two frames a tick moves the blade every frame
	Engine.physics_ticks_per_second = 30
	_put_player(Vector3(0, 1.05, 50), 0.0)
	await _frames(10)
	var main_hand: Node3D = player.hand.get_node("MainHand")
	var spots := []
	Input.action_press("throw")
	await get_tree().process_frame
	Input.action_release("throw")

	for i in 16:
		await get_tree().process_frame
		spots.append(main_hand.rotation)

	Engine.physics_ticks_per_second = 60
	var still_frames := 0

	for i in range(1, spots.size()):
		if (spots[i] as Vector3).is_equal_approx(spots[i - 1]):
			still_frames += 1

	_check("U15 at two frames a tick the weapon moves every frame of a swing", still_frames <= 1,
		"frames the blade did not move: %d of %d" % [still_frames, spots.size() - 1])

	# U16 a rope placed after it was added hangs from where it was put, not
	#     whipping across from the origin
	var rope := Area3D.new()
	rope.set_script(load("res://scripts/PlayerUtils/VerletRope.gd"))
	rope.length = 6.0
	add_child(rope)
	rope.global_position = Vector3(120, 7.0, -3.0)
	await _frames(30)
	var free_end: Vector3 = rope.points[rope.points.size() - 1]
	var hang := Vector2(free_end.x - 120.0, free_end.z + 3.0).length()
	_check("U16 a rope moved after it is added hangs from its new anchor", hang < 0.5 and free_end.y < 2.0,
		"free end %s, %.2f m off plumb" % [free_end, hang])
	rope.queue_free()

	# U11 dying with a crate in your hands keeps your hands down
	var crate := Props.crate(self, Vector3(80, 0.3, 8.9), 0.5, 5.0)
	player.inventory.select_by_id(&"sword")
	_put_player(Vector3(80, 1.05, 10), 0.0)
	_aim(crate.global_position)
	await _frames(10)
	await _tap("frob")
	await _frames(10)
	var carrying: bool = player.frob.held == crate
	player.invulnerable = false
	player.take_damage(1000.0, null)
	await _frames(40)
	var raised: bool = player.hand.is_item_visible()
	_check("U11 dying while carrying something leaves the weapon down", carrying and player.is_dead and not raised,
		"carrying %s dead %s weapon up %s" % [carrying, player.is_dead, raised])


# --------------------------------------------------------------------------

func _spikes() -> Node:
	for node in find_children("*", "Area3D", true, false):
		if node.has_method("into_speed"):
			return node

	return null


func _guard(at: Vector3) -> CharacterBody3D:
	var g: CharacterBody3D = GUARD.instantiate()
	g.position = at
	g.rotation.y = PI
	add_child(g)
	g.block_chance = 0.0
	g._attack_timer = 999.0
	g.attack_cooldown = 999.0
	return g


func _last_body() -> Node3D:
	var found: Node3D = null

	# A man's body, not a part cut off one (SeveredPart.gd).
	for b in get_tree().get_nodes_in_group(&"bodies"):
		if b.get("part") == null:
			found = b

	return found


func _put_player(at: Vector3, yaw: float) -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "throw", "block", "kick", "frob"]:
		Input.action_release(a)

	player.movement_state = 0
	player.velocity = Vector3.ZERO
	player.global_position = at
	player.rotation.y = yaw
	player.neck.rotation.x = 0.0
	player.combat._reset()
	player.combat.adrenaline = 0.0
	player.reset_physics_interpolation()


func _aim(target: Vector3) -> void:
	var eye: Vector3 = player.neck.global_position
	var d := target - eye
	player.rotation.y = atan2(-d.x, -d.z)
	player.neck.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())


func _tap(action: String) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
