extends Node3D
## Combat transitions on a real player, floor and hanging shelf.

const PLAYER := preload("res://Player.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")

var player: CharacterBody3D
var combat: Node
var results: Array[String] = []
var failed := false
var dodges: Array[float] = []


func _ready() -> void:
	Props.block(self, Vector3(0, -0.5, 0), Vector3(80, 1, 60))
	Props.block(self, Vector3(10, 1.8, -4.5), Vector3(6, 3.6, 3))
	player = PLAYER.instantiate()
	add_child(player)
	combat = player.combat
	player.debug_traversal = false
	player.invulnerable = true
	player.reload_on_death = false
	if player.has_node("LightGem"):
		player.get_node("LightGem").queue_free()
	Props.give_weapons(player)
	player.inventory.select_by_id(&"sword")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	combat.dodged.connect(func(_direction): dodges.append(combat._game_time))
	await _frames(5)
	await _run()
	_release_all()
	print("\n==== RESULTS ====")
	for result in results:
		print(result)
	get_tree().quit(1 if failed else 0)


func _run() -> void:
	await _strike()
	await _until(func(): return combat.phase == combat.Phase.STRIKE and combat._t >= 0.16, 30)
	var before := player.global_position
	await _tap("dodge")
	var committed: bool = combat.phase == combat.Phase.STRIKE
	await _frames(20)
	_check("CP1 late-strike dodge waits for recovery and moves once", committed and dodges.size() == 1 and player.global_position.z - before.z > 0.6,
		"committed %s dodges %d travel %.3f" % [committed, dodges.size(), player.global_position.z - before.z])

	await _strike()
	await _until(func(): return combat.phase == combat.Phase.RECOVER, 30)
	var recovery_start: float = combat._game_time - combat._t
	await _tap("dodge")
	var early_recovery: bool = combat.phase == combat.Phase.RECOVER
	await _frames(8)
	var delay: float = dodges[0] - recovery_start if not dodges.is_empty() else -1.0
	_check("CP2 early-recovery dodge starts at the first allowed frame", early_recovery and dodges.size() == 1 and delay >= 0.06 and delay <= 0.10,
		"committed %s dodges %d delay %.3f" % [early_recovery, dodges.size(), delay])

	await _strike()
	await _tap("dodge")
	await _frames(45)
	_check("CP3 an early-strike dodge expires rather than firing later", dodges.is_empty(), "dodges %d" % dodges.size())

	await _place()
	Input.action_press("block")
	await _frames(2)
	await _tap("throw")
	await _hang()
	_return_to_floor()
	Input.action_release("block")
	await _frames(25)
	_check("CP4 traversal cancels a pending attack", combat.threat_serial() == _serial_before and combat.phase == combat.Phase.IDLE,
		"serial %d -> %d phase %d" % [_serial_before, combat.threat_serial(), combat.phase])

	await _place()
	await _hang()
	Input.action_press("block")
	await _frames(2)
	_return_to_floor()
	await _frames(2)
	var held_guard: bool = combat.blocking and not combat.is_parrying()
	Input.action_release("block")
	await _frames(2)
	Input.action_press("block")
	await _frames(2)
	_check("CP5 traversal block resumes as a held guard; a fresh press parries", held_guard and combat.is_parrying(),
		"held guard %s fresh parry %s" % [held_guard, combat.is_parrying()])

	await _place()
	Input.action_press("throw")
	await _frames(2)
	Input.action_release("throw")
	await _frames(2)
	await _tap("throw")
	Input.action_press("block")
	await _frames(2)
	Input.action_release("block")
	var feint_serial: int = combat.threat_serial()
	await _frames(30)
	_check("CP6 feint cancels the clicked follow-up", combat.threat_serial() == feint_serial and combat.phase == combat.Phase.IDLE,
		"serial %d -> %d phase %d" % [feint_serial, combat.threat_serial(), combat.phase])

	await _place()
	combat._stagger(0.1, &"flinch")
	await _tap("throw")
	await _frames(30)
	_check("CP7 attacks pressed while staggered do not replay", combat.threat_serial() == _serial_before,
		"serial %d -> %d" % [_serial_before, combat.threat_serial()])

	await _strike()
	await _tap("throw")
	Input.action_press("block")
	await _frames(45)
	var covered_serial: int = combat.threat_serial()
	Input.action_release("block")
	await _frames(35)
	_check("CP8 guarding after a swing cancels its queued follow-up", combat.threat_serial() == covered_serial,
		"serial %d -> %d" % [covered_serial, combat.threat_serial()])

	await _place()
	Input.action_press("block")
	await _frames(2)
	Input.action_press("throw")
	await _frames(2)
	player.spend_attack_press()
	Input.action_release("block")
	await _frames(20)
	_check("CP9 item-owned input cancels a pending sword attack", combat.threat_serial() == _serial_before,
		"serial %d -> %d" % [_serial_before, combat.threat_serial()])

	await _place()
	Input.action_press("block")
	await _frames(2)
	await _tap("throw")
	player.inventory.select_by_id(&"dagger")
	Input.action_release("block")
	await _frames(30)
	_check("CP10 a pending attack does not carry into another weapon", combat.threat_serial() == _serial_before,
		"serial %d -> %d" % [_serial_before, combat.threat_serial()])
	player.inventory.select_by_id(&"sword")

	await _place()
	combat._dodge_cooldown = 0.10
	Input.action_press("dodge")
	await _frames(50)
	_check("CP11 a cooldown buffers one dodge; holding never repeats it", dodges.size() == 1 and player.global_position.z > 3.6,
		"dodges %d position %s" % [dodges.size(), player.global_position])

	await _place()
	combat._dodge_cooldown = 0.30
	await _tap("dodge")
	await _frames(25)
	var expired: bool = dodges.is_empty()
	await _tap("dodge")
	await _frames(15)
	_check("CP12 a cooldown press expires, and a fresh press works", expired and dodges.size() == 1,
		"expired %s dodges %d" % [expired, dodges.size()])

	await _strike()
	await _until(func(): return combat.phase == combat.Phase.STRIKE and combat._t >= 0.16, 30)
	await _tap("dodge")
	combat._stagger(0.08, &"flinch")
	await _tap("dodge")
	await _frames(25)
	_check("CP13 stagger cancels a pending dodge and refuses presses", dodges.is_empty(), "dodges %d" % dodges.size())

	await _place()
	combat.stamina = 0.0
	await _tap("dodge")
	combat.stamina = 100.0
	await _frames(15)
	var empty_stamina: bool = dodges.is_empty()
	player.global_position.y = 5.0
	await _frames(3)
	await _tap("dodge")
	await _frames(60)
	_check("CP14 empty stamina and airborne presses do not become later dodges", empty_stamina and dodges.is_empty(),
		"empty stamina %s dodges %d" % [empty_stamina, dodges.size()])


var _serial_before := 0


func _place() -> void:
	_release_all()
	_return_to_floor()
	combat._reset()
	combat.stamina = 100.0
	combat._stamina_rest = combat._game_time + 10.0
	combat._dodge_cooldown = 0.0
	combat._parry_ready_at = 0.0
	combat._block_held = false
	dodges.clear()
	await _frames(3)
	_serial_before = combat.threat_serial()


func _return_to_floor() -> void:
	player.movement_state = player.MoveState.LOCOMOTION
	player.current_move = null
	player.global_position = Vector3(0, 1.05, 3)
	player.velocity = Vector3.ZERO
	player.shove(Vector3.ZERO, 0.0)
	player.rotation = Vector3.ZERO
	player.neck.rotation = Vector3.ZERO


func _hang() -> void:
	player.global_position = Vector3(10, 2.55, -2.48)
	player.velocity = Vector3.ZERO
	player._enter_hang(Vector3.BACK, 3.6, false)
	await _frames(2)
	_check("CP fixture real shelf supports a hang", player.movement_state == player.MoveState.HANGING,
		"state %d" % player.movement_state)


func _strike() -> void:
	await _place()
	await _tap("throw")
	await _until(func(): return combat.phase == combat.Phase.STRIKE, 30)


func _tap(action: String) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)


func _release_all() -> void:
	for action in ["throw", "block", "dodge", "kick", "move_forward", "move_back", "move_left", "move_right", "jump", "crouch", "sprint"]:
		Input.action_release(action)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _until(condition: Callable, frames: int) -> void:
	for i in frames:
		if condition.call():
			return
		await get_tree().physics_frame


func _check(label: String, ok: bool, detail: String) -> void:
	failed = failed or not ok
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", label, detail])
