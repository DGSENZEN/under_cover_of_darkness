extends Node3D
## Guards and the gun: they read it from shots fired at them, take cover at
## range, rush you as you reload, flinch at near misses, and hear a gunshot
## from a block away.

const PLAYER := preload("res://Player.tscn")
const GUARD_SCRIPT := preload("res://scripts/AISystem/Guard.gd")
const GUARD := preload("res://Guard.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")
const SoundBus := preload("res://scripts/StimuliSystem/SoundBus.gd")
const TemperamentScript := preload("res://scripts/AISystem/Temperament.gd")
const GarrisonScript := preload("res://scripts/AISystem/Garrison.gd")
const SquadScript := preload("res://scripts/AISystem/Squad.gd")
const ViewArmsScript := preload("res://scripts/Interaction/ViewArms.gd")

var player: CharacterBody3D
var baker: NavigationRegion3D
var results: Array[String] = []


func _ready() -> void:
	TemperamentScript.rolling = false
	GUARD_SCRIPT.bleeding_on = false
	Props.block(self, Vector3(0, -0.5, 0), Vector3(460, 1, 140))             # floor, x -230..230
	# GF1/GF2: pillars to either side of the way two men 20 m off will come
	# at you (and one behind them): cover is there to be got to, and none of
	# it hides them before the first shot.
	for at in [Vector3(-4, 1.5, -12), Vector3(6, 1.5, -12), Vector3(-4, 1.5, -6), Vector3(6, 1.5, -6), Vector3(1, 1.5, -26)]:
		Props.block(self, at, Vector3(1.2, 3, 1.2))
	# GF4: a wall between the near listener and the shot, to go round.
	Props.block(self, Vector3(-120, 2.0, 40.0), Vector3(1, 4, 30))

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
	player.global_position = Vector3(0, 1.05, 40)
	Props.give_revolver(player)
	player.inventory.select_by_id(&"revolver")

	await baker.baked
	await _frames(5)
	await _run()

	print("\n==== RESULTS ====")
	for r in results:
		print(r)
	get_tree().quit()


func _run() -> void:
	var revolver: Node = player.revolver

	# GF5 the gun drawn but never fired: nothing to read
	SquadScript.clear_all()
	var a5 := _fighter(Vector3(60, 0, -10))
	var b5 := _fighter(Vector3(63, 0, -10))
	_put_player(Vector3(61, 1.05, 0))
	await _frames(600)
	var squad5: RefCounted = SquadScript.of(player)
	_check("GF5 a gun drawn and not fired is not read", squad5 != null and float(squad5.read.get(&"gun", -1.0)) == 0.0,
		"read %s" % [squad5.read if squad5 != null else {}])
	a5.queue_free()
	b5.queue_free()
	await _frames(10)

	# GF1 shots past them at range: they read the gun, and take cover
	SquadScript.clear_all()
	GarrisonScript.clear_all()
	revolver.reset_for_practice()
	# At their ease until the first shot past them.
	var a := _new_guard(Vector3(0, 0, -20), PI)
	var b := _new_guard(Vector3(2, 0, -20), PI)
	_put_player(Vector3(1, 1.05, 0))
	await _frames(20)
	for i in 2:
		_aim(Vector3(1, 1.3, -20))
		await _tap("throw")
		await _frames(40)
	var squad: RefCounted = SquadScript.of(player)
	var read: float = float(squad.read.get(&"gun", 0.0))
	await _until(func(): return squad.tactic == &"cover", 60)
	var covering: StringName = squad.tactic
	await _until(func(): return _hidden(a) and _hidden(b), 300)
	_check("GF1 shots past them at range: they read the gun and get behind cover",
		read >= 0.5 and covering == &"cover" and _hidden(a) and _hidden(b),
		"read %.2f tactic %s hidden %s %s" % [read, covering, _hidden(a), _hidden(b)])

	# GF2 the reload: they come at you
	var far_a: float = a.global_position.distance_to(player.global_position)
	var far_b: float = b.global_position.distance_to(player.global_position)
	await _tap("reload")
	await _until(func(): return squad.tactic == &"rush", 30)
	var rushing: StringName = squad.tactic
	await _frames(120)
	var closed_a: float = far_a - a.global_position.distance_to(player.global_position)
	var closed_b: float = far_b - b.global_position.distance_to(player.global_position)
	_check("GF2 at the reload they rush you", rushing == &"rush" and closed_a >= 3.0 and closed_b >= 3.0,
		"tactic %s closed %.1f %.1f" % [rushing, closed_a, closed_b])
	a.queue_free()
	b.queue_free()
	await _frames(10)

	# GF3 a near miss on a man at his ease: he starts, and knows
	SquadScript.clear_all()
	revolver.reset_for_practice()
	var c := _new_guard(Vector3(40, 0, -15), 0.0)
	_put_player(Vector3(40, 1.05, 0))
	await _frames(30)
	var calm: float = c.alert
	_aim(Vector3(41.0, 1.3, -15))
	await _tap("throw")
	await _frames(5)
	_check("GF3 a near miss startles a man at his ease", c.alert > calm and c._last_blow != Vector3.ZERO and c.health == c.max_health,
		"alert %.1f -> %.1f blow %s health %.0f" % [calm, c.alert, c._last_blow, c.health])
	c.queue_free()
	await _frames(10)

	# GF4 a gunshot is heard 60 m off round a corner, not 200 m off
	revolver.reset_for_practice()
	var near := _new_guard(Vector3(-90, 0, 40), 0.0)
	var distant := _new_guard(Vector3(50, 0, 40), 0.0)
	_put_player(Vector3(-150, 1.05, 40))
	await _frames(30)
	var near_before: float = near.alert
	var far_before: float = distant.alert
	player.get_node("Neck").rotation.x = -1.2
	await _tap("throw")
	await _frames(10)
	player.get_node("Neck").rotation.x = 0.0
	_check("GF4 a gunshot carries 60 m round a corner, not 200 m",
		near.alert > near_before and near.has_last_known and _near(distant.alert, far_before, 0.01),
		"near %.1f -> %.1f knows %s, far %.1f -> %.1f" % [near_before, near.alert, near.has_last_known, far_before, distant.alert])
	near.queue_free()
	distant.queue_free()


## Out of the player's sight: the world between his eye and the man's chest.
func _hidden(g: Node3D) -> bool:
	if not is_instance_valid(g):
		return false

	var eye: Vector3 = player.get_node("Neck").global_position
	var chest: Vector3 = g.global_position + Vector3.UP * 1.2
	var query := PhysicsRayQueryParameters3D.create(eye, chest, 1, [player.get_rid()])
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


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
