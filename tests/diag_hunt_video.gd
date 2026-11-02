extends Node3D
## A scripted run of the hunt gym to record, played with real keys: pack, walk out,
## lead against an eye, copal, the curse deepening, the egg, the kills; then a bigger
## pack, a spell, the curse at its deepest, the egg again. To record:
##   Godot --path . --resolution 1280x720 --write-movie <file>.avi res://tests/diag_hunt_video.tscn

const GYM := preload("res://maps/hunt_gym.tscn")
## How fast the view swings to what it is after, and how far off it wanders (rad).
const AIM_RATE := 9.0
const AIM_WANDER := 0.012
## The whole run stops here, whatever has happened (s).
const LONGEST := 130.0

var gym: Node3D
var p: CharacterBody3D
var target: Node3D
var look_point := Vector3.ZERO
var strafing := false
var _time := 0.0


func _ready() -> void:
	gym = GYM.instantiate()
	add_child(gym)
	await _frames(100)
	p = gym.player
	p.invulnerable = true
	CityState.job.read_slot("eye_clue")
	_strafe_loop()
	await _pack_and_walk_out()
	await _first_wave()
	await _second_wave()
	await _beat("the end", 150)
	get_tree().quit()


func _physics_process(delta: float) -> void:
	_time += delta

	if _time > LONGEST:
		print("VIDEO cut at the longest")
		get_tree().quit()

	if p == null:
		return

	var at: Vector3 = target.global_position if is_instance_valid(target) else look_point

	if at == Vector3.ZERO:
		return

	var way: Vector3 = (at - p.camera.global_position).normalized()
	var turn := 1.0 - exp(-AIM_RATE * delta)
	var wander := Vector2(sin(_time * 1.3), cos(_time * 0.9)) * AIM_WANDER
	p.rotation.y = lerp_angle(p.rotation.y, atan2(-way.x, -way.z) + wander.x, turn)
	p.neck.rotation.x = lerp_angle(p.neck.rotation.x, asin(way.y) + wander.y, turn)


func _pack_and_walk_out() -> void:
	_say("the kit room")
	look_point = gym.kit_table.piece(&"copal").global_position
	await _frames(70)
	gym.kit_table.piece(&"copal").frob(p)
	await _frames(45)
	look_point = gym.kit_table.piece(&"egg").global_position
	await _frames(35)
	gym.kit_table.piece(&"egg").frob(p)
	await _frames(45)
	look_point = Vector3(0.0, 1.8, -20.0)
	await _frames(45)
	Input.action_press("move_forward")
	await _until(func(): return p.global_position.z < gym.YARD_START - 4.0, 6.0)
	Input.action_release("move_forward")


func _first_wave() -> void:
	_say("wave one: lead, then copal")
	strafing = true
	# Lead does little to an eye.
	await _shots(4)
	await _press("switch_round")
	await _until(func(): return not p.revolver.is_reloading(), 6.0)
	# Copal smokes it: one dead.
	var first := _nearest()
	await _shoot_until(func(): return not is_instance_valid(first) or first.dead, 9.0)
	await _beat("stop shooting: let the curse land and deepen", 10)
	target = _nearest()
	await _until(func(): return p.curse.depth() >= 3, 22.0)
	_say("curse at %d eyes: its stray, its pace" % p.curse.depth())
	await _shots(3)
	await _slide()
	await _egg()
	# Flung back and exposed: finish them.
	await _shoot_until(func(): return _awake().is_empty(), 20.0)
	strafing = false
	target = null
	look_point = Vector3(0.0, 2.0, -24.0)
	await _beat("wave one down", 90)


func _second_wave() -> void:
	await _until(func(): return not _awake().is_empty(), 8.0)
	_say("wave two: a pack")
	strafing = true
	target = _nearest()
	await _frames(90)
	await _spell()
	await _gun_dodge()
	await _shots(3)
	await _until(func(): return p.curse.depth() >= 6, 24.0)
	_say("curse at %d eyes" % p.curse.depth())
	await _frames(100)
	await _egg()
	await _shoot_until(func(): return _awake().is_empty(), 26.0)
	strafing = false
	target = null


## A shot as soon as the gun will, at whichever is nearest.
func _shots(count: int) -> void:
	var fired := 0

	while fired < count:
		target = _nearest()

		if int(p.revolver.loaded[&"cylinder"]) == 0 and not p.revolver.is_reloading():
			await _press("reload")
		elif p.revolver.ready_to_fire() and _on_target():
			await _press("throw")
			fired += 1
			await _frames(16)
		else:
			await _frames(1)


func _shoot_until(done: Callable, most: float) -> void:
	var left := int(most * 60.0)

	while left > 0 and not done.call():
		target = _nearest()

		if int(p.revolver.loaded[&"cylinder"]) == 0 and not p.revolver.is_reloading():
			await _press("reload")
		elif p.revolver.ready_to_fire() and _on_target():
			await _press("throw")
			await _frames(14)
			left -= 14
		else:
			await _frames(1)

		left -= 1


func _egg() -> void:
	_say("the egg, at %d eyes" % p.curse.depth())
	await _press("use_item")
	await _frames(62)
	await _frames(26)


func _slide() -> void:
	_say("a slide")
	var was := strafing
	strafing = false
	await _frames(2)
	Input.action_press("sprint")
	Input.action_press("move_forward")
	await _frames(55)
	await _press("crouch")
	await _frames(40)
	Input.action_release("sprint")
	Input.action_release("move_forward")
	strafing = was


func _gun_dodge() -> void:
	_say("a dodge")
	var was := strafing
	strafing = false
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_press("move_left")
	await _press("gun_dodge")
	await _frames(24)
	Input.action_release("move_left")
	strafing = was


func _spell() -> void:
	_say("a shard")
	target = _nearest()
	Input.action_press("spell_1")
	await _frames(48)
	Input.action_release("spell_1")
	await _frames(30)


## Side to side while it is wanted, on its own clock, as a player would.
func _strafe_loop() -> void:
	var side := "move_left"

	while true:
		if not strafing:
			await _frames(5)
			continue

		Input.action_press(side)
		await _frames(68)
		Input.action_release(side)
		side = "move_right" if side == "move_left" else "move_left"


func _on_target() -> bool:
	if not is_instance_valid(target):
		return false

	var way: Vector3 = (target.global_position - p.camera.global_position).normalized()
	return way.dot(-p.camera.global_basis.z) > 0.985


func _awake() -> Array:
	return gym.get_tree().get_nodes_in_group(&"monsters").filter(func(m): return not m.dead and not m.asleep)


func _nearest() -> Node3D:
	var eyes := _awake()

	if eyes.is_empty():
		return null

	return eyes.reduce(func(a, b): return a if a.global_position.distance_to(p.global_position) < b.global_position.distance_to(p.global_position) else b)


func _beat(words: String, frames: int) -> void:
	_say(words)
	await _frames(frames)


func _say(words: String) -> void:
	print("VIDEO %6.1f s  %s" % [_time, words])


func _press(action: String) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)


func _until(done: Callable, most: float) -> bool:
	var left := int(most * 60.0)

	while left > 0:
		if done.call():
			return true

		left -= 1
		await get_tree().physics_frame

	return done.call()


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
