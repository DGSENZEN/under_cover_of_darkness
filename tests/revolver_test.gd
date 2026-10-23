extends Node3D
## The revolver: on the belt, its two barrels, the kick and the settle, the
## reload through the gate, held in view, the pistol-whip, and gibbing.

const PLAYER := preload("res://Player.tscn")
const GUARD_SCRIPT := preload("res://scripts/AISystem/Guard.gd")
const GUARD := preload("res://Guard.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")
const SoundBus := preload("res://scripts/StimuliSystem/SoundBus.gd")
const Fx := preload("res://scripts/Visual/Fx.gd")
const TemperamentScript := preload("res://scripts/AISystem/Temperament.gd")
const GarrisonScript := preload("res://scripts/AISystem/Garrison.gd")


class Ear:
	var events: Array = []

	func hear_sound(event: Dictionary) -> void:
		events.append(event)


var player: CharacterBody3D
var baker: NavigationRegion3D
var results: Array[String] = []


func _ready() -> void:
	# Every guard at his class's own temperament: these checks are exact.
	TemperamentScript.rolling = false
	# Exact damage is checked here: wounds do not go on bleeding.
	GUARD_SCRIPT.bleeding_on = false
	Props.block(self, Vector3(0, -0.5, 0), Vector3(140, 1, 90))              # floor

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

	await baker.baked
	await _frames(5)
	await _run()

	print("\n==== RESULTS ====")
	for r in results:
		print(r)
	get_tree().quit()


func _run() -> void:
	var combat: Node = player.combat

	# R1 the revolver on the belt: drawn, the sword's blows stand down
	Props.give_revolver(player)
	_wield(&"revolver")
	var g1 := _fighter(Vector3(0, 0, -1.5))
	_put_player(Vector3(0, 1.05, 0))
	await _frames(20)
	await _tap("throw")
	await _frames(40)
	_check("R1 the revolver is drawn, and the left mouse is no sword blow",
		combat.gun_drawn() and player.inventory.ammo[&"rounds"] == 24 and player.inventory.ammo[&"shells"] == 4
			and g1.health == g1.max_health and combat.phase == combat.Phase.IDLE,
		"drawn %s ammo %s health %.0f phase %d" % [combat.gun_drawn(), player.inventory.ammo, g1.health, combat.phase])
	g1.queue_free()

	# R2 the kick still works with the gun drawn
	var g2 := _fighter(Vector3(0, 0, -1.6))
	_put_player(Vector3(0, 1.05, 0))
	await _frames(20)
	var kicks := []
	combat.kicked.connect(func(t): kicks.append(t))
	await _tap("kick")
	await _frames(40)
	_check("R2 the kick still works with the gun drawn", kicks.size() == 1, "kicked %d" % kicks.size())
	g2.queue_free()

	# R3 rounds picked up go to the stock, not the belt
	var belt_before: int = player.inventory.belt.size()
	var box := Props.ammo(self, Vector3(3, 0.3, 3), &"rounds", 6)
	await _frames(2)
	box.frob(player)
	await _frames(2)
	_check("R3 rounds picked up go to the stock, not the belt",
		player.inventory.ammo[&"rounds"] == 30 and player.inventory.belt.size() == belt_before,
		"rounds %d belt %d -> %d" % [player.inventory.ammo[&"rounds"], belt_before, player.inventory.belt.size()])


# Helpers

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
