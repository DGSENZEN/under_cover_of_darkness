extends Node3D
## Perception and search regressions with real players, guards and collision.

const PLAYER := preload("res://Player.tscn")
const GUARD := preload("res://Guard.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")
const SoundBus := preload("res://scripts/StimuliSystem/SoundBus.gd")
const TemperamentScript := preload("res://scripts/AISystem/Temperament.gd")

var player: CharacterBody3D
var results: Array[String] = []
var failed := false


func _ready() -> void:
	TemperamentScript.rolling = false
	Props.block(self, Vector3(0, -0.5, 0), Vector3(50, 1, 50))
	Props.block(self, Vector3(15, 1.5, -3), Vector3(6, 3, 0.4))
	var baker := NavigationRegion3D.new()
	baker.set_script(NavBakerScript)
	add_child(baker)
	player = _player_at(Vector3(0, 1.05, -6))
	await baker.baked
	await _frames(5)
	player.set_physics_process(false)
	await _perception_checks()
	await _investigation_check()
	await _engaged_check()
	print("\n==== RESULTS ====")
	for result in results:
		print(result)
	get_tree().quit(1 if failed else 0)


func _perception_checks() -> void:
	var guard := _guard_at(Vector3.ZERO)
	# Sample production vision directly, fixing bodies in place so movement
	# and idle head sweeps cannot obscure the light boundary under test.
	guard.set_physics_process(false)
	guard._target = player
	player.debug_light_level = 1.0
	player.velocity = Vector3(3, 0, 0)
	guard._sense_vision(1.0 / 60.0)
	player.velocity = Vector3.ZERO
	guard._sense_vision(1.0 / 60.0)
	player.debug_light_level = 0.0
	guard._sense_vision(1.0 / 60.0)
	var trail: Vector3 = guard._trail_point()
	_check("SP1 seeing the player stop clears a running trail", trail == Vector3.INF,
		"trail %s heading %s" % [trail, guard._seen_heading])

	player.debug_light_level = 1.0
	guard._sense_vision(1.0 / 60.0)
	var below := _light_for_visibility(guard, 0.019)
	var above := _light_for_visibility(guard, 0.021)
	var switches := 0
	var was_seen: bool = guard.can_see_target
	var before: float = guard.alert
	for i in 24:
		player.debug_light_level = below if i % 2 == 0 else above
		guard._sense_vision(1.0 / 60.0)
		if guard.can_see_target != was_seen:
			switches += 1
		was_seen = guard.can_see_target
	_check("SP2 a small light-boundary fluctuation keeps a visible silhouette stable",
		switches == 0 and guard.alert > before, "switches %d alert %.2f -> %.2f" % [switches, before, guard.alert])

	# Complete cover must still cut sight immediately: no sight grace timer
	# may disclose the player's movement behind this wall.
	player.debug_light_level = 1.0
	guard._sense_vision(1.0 / 60.0)
	var known: Vector3 = guard.last_known_position
	var wall := Props.block(self, Vector3(0, 1.5, -3), Vector3(6, 3, 0.4))
	await _frames(2)
	player.position.x = 1.0
	guard._sense_vision(1.0 / 60.0)
	_check("SP3 full cover immediately loses sight and preserves the last seen place",
		not guard.can_see_target and guard.last_known_position.distance_to(known) < 0.01,
		"seen %s last %s" % [guard.can_see_target, guard.last_known_position])
	wall.queue_free()
	await _frames(2)
	player.position.x = 0.0
	player.movement_state = 2 # Hanging: a visible airborne target allows follow-through.
	guard._sense_vision(1.0 / 60.0)
	known = guard.last_known_position
	var replacement := _player_at(Vector3(15, 1.05, -6))
	guard._target = replacement
	guard._sense_vision(1.0 / 60.0)
	_check("SP4 changing target cannot carry airborne tracking behind cover",
		not guard.can_see_target and guard.last_known_position.distance_to(known) < 0.01,
		"last %s previous %s replacement %s" % [guard.last_known_position, known, replacement.position])
	replacement.queue_free()
	player.movement_state = 0
	guard._target = player
	player.debug_light_level = below
	guard._sense_vision(1.0 / 60.0)
	_check("SP5 a new target needs clear enough sight to be acquired", not guard.can_see_target,
		"visibility %.4f seen %s" % [guard.visibility, guard.can_see_target])
	guard.queue_free()
	await _frames(3)


func _investigation_check() -> void:
	player.position = Vector3(20, 1.05, 20)
	player.debug_light_level = 0.0
	var guard := _guard_at(Vector3.ZERO)
	guard.look_around_time = 3.0
	SoundBus.emit_sound(Vector3(0, 0, -3), 70.0, player, &"footstep")
	for i in 600:
		await _frames(1)
		if guard.state == 2 and guard._look_timer > 0.5:
			break
	var looking: bool = guard.state == 2 and guard._look_timer > 0.5
	var started := guard.global_position
	SoundBus.emit_sound(Vector3(0, 0, -3), 70.0, player, &"footstep")
	await _frames(20)
	_check("SP7 a repeated nearby clue keeps the investigation's current look",
		looking and guard.state == 2 and guard._look_timer > 0.5 and guard.global_position.distance_to(started) < 0.2,
		"state %d timer %.2f drift %.3f" % [guard.state, guard._look_timer, guard.global_position.distance_to(started)])
	SoundBus.emit_sound(Vector3(8, 0, -3), 80.0, player, &"footstep")
	await _frames(35)
	_check("SP6 a fresh distant clue interrupts an investigation's look-around",
		looking and guard.state == 2 and guard._look_timer <= 0.0 and guard.global_position.x > started.x + 0.3,
		"looking %s state %d timer %.2f position %s -> %s" % [looking, guard.state, guard._look_timer, started, guard.global_position])
	guard.queue_free()
	await _frames(3)


func _light_for_visibility(guard: CharacterBody3D, wanted: float) -> float:
	# Find the real light level for this body's sight points and distance;
	# expectations concern stable perception, never this computed value.
	var low := 0.0
	var high := 1.0
	for i in 24:
		player.debug_light_level = (low + high) * 0.5
		if guard._visibility_of(player) < wanted:
			low = player.debug_light_level
		else:
			high = player.debug_light_level
	return (low + high) * 0.5


func _engaged_check() -> void:
	player.position = Vector3(0, 1.05, 2.4)
	player.debug_light_level = 0.0
	var guard := _guard_at(Vector3.ZERO)
	# Attacked from behind: engagement itself is a fresh reason to fight,
	# even before the first vision sample and before he turns to see us.
	guard._engage(player)
	await _frames(5)
	_check("SP8 engagement before the first vision sample retains its chase grace",
		guard.state == 4 and guard._fighter.squad != null,
		"state %d since seen %.2f squad %s" % [guard.state, guard._since_seen, guard._fighter.squad != null])
	guard.queue_free()
	await _frames(3)


func _player_at(at: Vector3) -> CharacterBody3D:
	var body: CharacterBody3D = PLAYER.instantiate()
	body.position = at
	add_child(body)
	body.invulnerable = true
	body.reload_on_death = false
	body.debug_traversal = false
	if body.has_node("LightGem"):
		body.get_node("LightGem").queue_free()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	return body


func _guard_at(at: Vector3) -> CharacterBody3D:
	var body: CharacterBody3D = GUARD.instantiate()
	body.position = at
	body.carries_lantern = false
	body.debug_ai = false
	add_child(body)
	return body


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(label: String, ok: bool, detail: String) -> void:
	failed = failed or not ok
	results.append("%s  %s [%s]" % ["PASS" if ok else "FAIL", label, detail])
