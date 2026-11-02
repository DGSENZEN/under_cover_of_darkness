extends Node3D
## The hunts so far, played with real keys in the mixed gym, to record: packing and choosing items,
## swipes and the whip, the spells, the turned eye and its spit, the egg and the line, the curse and
## the drain as one body; then each way of dying. No words of ours. To record:
##   Godot --path . --resolution 1920x1080 --write-movie <file>.avi res://tests/diag_showcase_video.tscn

const GYM := preload("res://maps/mixed_gym.tscn")
const AnimaScript := preload("res://scripts/Monsters/Anima.gd")
const EyeScript := preload("res://scripts/Monsters/FloatingEye.gd")
const SaveFiles := preload("res://scripts/Save/SaveFiles.gd")
const DeathQuotes := preload("res://scripts/UI/DeathQuotes.gd")
## How fast the view swings to what it is after, and how far off it wanders (rad).
const AIM_RATE := 7.0
const AIM_WANDER := 0.012
const LONGEST := 420.0

var gym: Node3D
var p: CharacterBody3D
var target: Node3D
var look_point := Vector3.ZERO
var strafing := false
var _time := 0.0


func _ready() -> void:
	await _new_gym()

	# (A long take can stall the recording: --fights and --deaths take a half each.)
	if not OS.get_cmdline_user_args().has("--deaths"):
		await _packing()
		await _swipes_and_whip()
		await _spells()
		await _the_turned_eye()
		await _one_body()

	if not OS.get_cmdline_user_args().has("--fights"):
		await _death_by_the_eyes()
		await _death_by_the_animas()
		await _death_by_a_swipe()
		await _death_by_both()
	_chapter("the end")
	SaveFiles.delete_run(CityState.run_id)
	get_tree().quit()


func _new_gym() -> void:
	target = null
	look_point = Vector3.ZERO
	strafing = false

	for action in ["move_left", "move_right", "move_forward", "move_back", "throw"]:
		Input.action_release(action)

	if gym != null:
		gym.free()
		await _frames(2)

	gym = GYM.instantiate()
	add_child(gym)
	await _frames(70)
	p = gym.player
	p.invulnerable = true
	p.reload_on_death = true
	CityState.job.read_slot("mixed_clue")
	_light_the_yard()


## For the camera, this recording only: the yard is meant to be dark, and film goes darker.
func _light_the_yard() -> void:
	for at in [Vector3(-8, 4, -12), Vector3(8, 4, -14), Vector3(0, 4.5, -22), Vector3(-9, 4, -28), Vector3(9, 4, -30), Vector3(0, 4, -8)]:
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.8, 0.58)
		lamp.light_energy = 1.5
		lamp.omni_range = 15.0
		lamp.omni_attenuation = 0.8
		gym.add_child(lamp)
		lamp.global_position = at


## The eyes wait their turn, so what is being shown can be seen.
func _eyes_wait() -> void:
	for one in _awake():
		if one.get("form") == null:
			one.sleep()


func _physics_process(delta: float) -> void:
	_time += delta

	if _time > LONGEST:
		print("VIDEO cut at the longest")
		get_tree().quit()

	if p == null or not is_instance_valid(p) or p.is_dead:
		return

	var at: Vector3 = target.global_position if is_instance_valid(target) else look_point

	if at == Vector3.ZERO:
		return

	var way: Vector3 = (at - p.camera.global_position).normalized()
	var turn := 1.0 - exp(-AIM_RATE * delta)
	var wander := Vector2(sin(_time * 1.3), cos(_time * 0.9)) * AIM_WANDER
	p.rotation.y = lerp_angle(p.rotation.y, atan2(-way.x, -way.z) + wander.x, turn)
	p.neck.rotation.x = lerp_angle(p.neck.rotation.x, asin(clampf(way.y, -1.0, 1.0)) + wander.y, turn)


func _packing() -> void:
	_chapter("packing")
	for what in [&"copal", &"copal_line", &"egg"]:
		look_point = gym.kit_table.piece(what).global_position
		await _frames(55)
		gym.kit_table.piece(what).frob(p)
		await _frames(30)

	look_point = Vector3(0.0, 1.8, -20.0)
	await _frames(30)
	Input.action_press("move_forward")
	await _until(func(): return p.global_position.z < gym.YARD_START + 1.5, 6.0)
	Input.action_release("move_forward")
	# Choosing between what you packed.
	await _press("next_item")
	await _frames(50)
	await _press("next_item")
	await _frames(50)
	await _press("switch_round")
	await _until(func(): return not p.revolver.is_reloading(), 6.0)


func _walk_out() -> void:
	look_point = Vector3(0.0, 1.8, -24.0)
	Input.action_press("move_forward")
	await _until(func(): return p.global_position.z < gym.YARD_START - 4.0, 6.0)
	Input.action_release("move_forward")


func _swipes_and_whip() -> void:
	_chapter("swipes")
	await _walk_out()
	_eyes_wait()
	strafing = false
	await _let_them_come(5.0)
	await _fight(func(): return _awake_animas().is_empty(), 11.0)
	_clear(_awake_animas())
	await _frames(70)


func _spells() -> void:
	_chapter("spells")
	gym.wave(2)
	_eyes_wait()
	await _let_them_come(3.0)
	await _spell("spell_1", 42)
	await _fight(func(): return false, 1.5)
	await _spell("spell_1", 42)
	await _let_them_come(2.0)
	await _spell("spell_4", 36)
	await _frames(70)
	await _spell("spell_2", 36)
	await _frames(70)
	await _spell("spell_3", 90)
	target = _nearest()
	await _frames(20)
	p.revolver.try_whip()
	await _frames(50)
	await _blink()
	await _fight(func(): return _awake_animas().is_empty(), 4.0)
	_clear(_awake_animas())
	await _frames(70)


func _the_turned_eye() -> void:
	_chapter("the turned eye")
	var eye: CharacterBody3D = EyeScript.new()
	eye.position = p.global_position + Vector3(2.0, 1.4, -8.0)
	gym.add_child(eye)
	await _frames(2)
	eye.state = eye.State.CIRCLE
	eye.next_swoop_in = 60.0
	eye.spit_in = 60.0
	# Near, for the camera: its radius is meant to keep it out of reach.
	eye._radius = 3.4
	eye._height = 2.4
	target = eye
	# Shot down past half: it tears open.
	var left := 300

	while not eye.dead and not eye.turned and left > 0:
		left -= 1

		if int(p.revolver.loaded[&"cylinder"]) == 0 and not p.revolver.is_reloading():
			await _press("reload")
		elif p.revolver.ready_to_fire() and _on_target():
			await _press("throw")
			await _frames(12)
		else:
			await _frames(1)

	await _frames(100)

	if eye.dead:
		return

	# It spits. One whipped back, one let through, and it opens the curse.
	eye.spit_in = 0.0
	await _until(func(): return not get_tree().get_nodes_in_group(&"eye_gobs").is_empty(), 3.0)
	var gob: Node3D = get_tree().get_nodes_in_group(&"eye_gobs")[0] if not get_tree().get_nodes_in_group(&"eye_gobs").is_empty() else null

	if gob != null:
		target = gob
		await _until(func(): return not is_instance_valid(gob) or gob.global_position.distance_to(p.global_position) < 2.8, 3.0)
		p.revolver.try_whip()
		await _frames(70)

	target = eye
	eye.spit_in = 0.0
	await _frames(190)
	# The egg sent back at it.
	p.statuses.apply(&"evil_eye", 20.0)
	await _frames(90)
	p.loadout.selected = p.loadout.items.find(&"egg")
	await _frames(20)
	await _press("use_item")
	await _frames(110)
	await _fight(func(): return eye.dead, 7.0)
	_clear(_awake())
	await _frames(70)


func _one_body() -> void:
	_chapter("one body")
	await _frames(10)
	gym.wave(3)

	for one in _awake():
		if one.get("form") == null:
			one.next_swoop_in = 60.0
		elif one.get("form") == &"torso":
			one.leap_chance = 0.0

	p.statuses.apply(&"evil_eye", 60.0)

	for i in 5:
		p.curse.deepen()

	await _let_them_come(3.0)
	var put := 0

	for one in _awake_animas():
		if put < 3 and one.form != &"torso":
			one.global_position = p.global_position + Vector3(0.6, 0.0, 0.2)
			one.put_on_you()
			put += 1
			await _frames(70)

	target = null
	look_point = p.global_position + Vector3(0.0, 1.8, -10.0)
	await _frames(240)
	# Laying the line throws them off.
	p.statuses.clear(&"evil_eye")
	p.loadout.item_counts[&"copal_line"] = 2
	p.loadout.selected = p.loadout.items.find(&"copal_line")
	await _frames(30)
	await _press("use_item")
	await _frames(120)


## Dies, and holds on the words and the page a moment.
func _hold_on_the_words(quote: int) -> void:
	await _until(func(): return p.is_dead, 25.0)
	# (One of each, for the film; in play a death draws among its own.)
	p.hud._death.set_quote(DeathQuotes.ALL[quote])
	await _until(func(): return p.hud.death_page.visible, 12.0)
	await _frames(170)


func _feeder(form: StringName, at: Vector3, put_on := true) -> CharacterBody3D:
	var one: CharacterBody3D = AnimaScript.new()
	one.form = form
	one.position = at
	gym.add_child(one)
	await _frames(1)

	if put_on:
		one.put_on_you()

	return one


func _in_the_room() -> void:
	# Out of the door, where there is room to go down.
	p.teleport(Transform3D(Basis.IDENTITY, Vector3(0.0, 1.05, -16.0)))
	gym.wave_now = 3
	look_point = Vector3(0.0, 1.6, -26.0)
	await _frames(30)


func _death_by_the_eyes() -> void:
	_chapter("the eyes")
	await _new_gym()
	await _in_the_room()
	p.statuses.apply(&"evil_eye", 60.0)
	p.curse.deepen()
	var eye: CharacterBody3D = EyeScript.new()
	eye.position = p.global_position + Vector3(0.0, 1.2, -7.0)
	gym.add_child(eye)
	target = eye
	await _frames(60)
	eye.state = eye.State.CIRCLE
	eye.next_swoop_in = 0.0
	p.invulnerable = false
	p.health = 1.0
	await _hold_on_the_words(3)


func _death_by_the_animas() -> void:
	_chapter("the animas")
	await _new_gym()
	await _in_the_room()
	var face := await _feeder(&"face", p.global_position + Vector3(0.9, 0.3, -0.3))
	var hands := await _feeder(&"hands", p.global_position + Vector3(-0.9, 0.3, -0.3))

	for i in 3:
		await _feeder(&"hands" if i < 2 else &"face", p.global_position + Vector3(float(i) * 3.0 - 3.0, 0.0, -8.0), false)

	target = null
	await _frames(100)
	p.invulnerable = false
	p.max_health = maxf(p.max_health, 1.0)
	p.health = 4.0
	await _hold_on_the_words(1)
	assert(face != null and hands != null)


func _death_by_a_swipe() -> void:
	_chapter("a swipe")
	await _new_gym()
	await _in_the_room()
	var one := await _feeder(&"hands", p.global_position + Vector3(1.0, 0.0, -6.0), false)
	one.leap_chance = 0.0
	target = one
	p.invulnerable = false
	p.health = 1.0
	await _hold_on_the_words(4)


func _death_by_both() -> void:
	_chapter("both")
	await _new_gym()
	await _in_the_room()
	p.statuses.apply(&"evil_eye", 60.0)

	for i in 4:
		p.curse.deepen()

	await _frames(90)
	await _feeder(&"face", p.global_position + Vector3(0.9, 0.3, -0.3))
	await _feeder(&"hands", p.global_position + Vector3(-0.9, 0.3, -0.3))
	target = null
	await _frames(120)
	p.invulnerable = false
	p.health = 4.0
	await _hold_on_the_words(2)


func _spell(action: String, frames: int) -> void:
	p.power.power = p.power.MAX
	target = _nearest()
	Input.action_press(action)
	await _frames(frames)
	Input.action_release(action)
	await _frames(14)


func _blink() -> void:
	p.power.power = p.power.MAX
	target = null
	look_point = p.global_position + Vector3(4.0, 1.2, -8.0)
	await _frames(30)
	Input.action_press("blink")
	await _frames(24)
	Input.action_release("blink")
	await _frames(40)


## Shoots what is nearest, whipping off what gets on you, till it's done or the time is up.
func _fight(done: Callable, most: float) -> void:
	var left := int(most * 60.0)
	var held := 0

	while left > 0 and not done.call():
		left -= 1
		p.power.power = maxf(p.power.power, p.power.MAX * 0.5)
		target = _nearest()

		if p.leech.count() > 0:
			held += 1

			# Let it get its teeth in first.
			if held > 110:
				held = 0
				p.revolver.try_whip()
				await _frames(14)
				continue
		else:
			held = 0

		if int(p.revolver.loaded[&"cylinder"]) == 0 and not p.revolver.is_reloading():
			await _press("reload")
		elif p.revolver.ready_to_fire() and _on_target():
			await _press("throw")
			await _frames(14)
		else:
			await _frames(1)


func _clear(list: Array) -> void:
	for m in list:
		m.take_hit(9999.0, p, &"power", m.global_position, Vector3.FORWARD)


func _let_them_come(seconds: float) -> void:
	var left := int(seconds * 60.0)

	while left > 0:
		left -= 1
		target = _nearest()
		await _frames(1)


func _on_target() -> bool:
	if not is_instance_valid(target):
		return false

	var way: Vector3 = (target.global_position - p.camera.global_position).normalized()
	return way.dot(-p.camera.global_basis.z) > 0.985


func _awake() -> Array:
	return get_tree().get_nodes_in_group(&"monsters").filter(func(m): return not m.dead and not m.asleep)


func _awake_animas() -> Array:
	return _awake().filter(func(m): return m.get("form") != null)


func _nearest() -> Node3D:
	var best: Node3D = null

	for m in _awake():
		if best == null or m.global_position.distance_to(p.global_position) < best.global_position.distance_to(p.global_position):
			best = m

	return best


func _chapter(name_of: String) -> void:
	print("VIDEO %.1f s: %s" % [_time, name_of])


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
