extends Node3D
## Smoothness: physics interpolation. Physics runs 60 times a second; a
## faster screen draws between ticks, and anything moved on ticks must be
## drawn in between or it steps. These checks run the physics at 30 ticks a
## second against 60 frames, two frames to a tick, the way a 120 Hz screen
## sees a 60 Hz game, and look at where things are DRAWN.

const PLAYER := preload("res://Player.tscn")
const GUARD := preload("res://Guard.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")
const TorchScript := preload("res://scripts/Visual/Torch.gd")
const OFF := Node.PHYSICS_INTERPOLATION_MODE_OFF

var player: CharacterBody3D
var results: Array[String] = []


## Calls `read` after every node has done its _process this frame, and keeps
## what it returns: where things are drawn.
class Recorder:
	extends Node

	var read: Callable
	var seen: Array = []

	func _process(_delta: float) -> void:
		seen.append(read.call())


func _ready() -> void:
	Props.block(self, Vector3(0, -0.5, 0), Vector3(200, 1, 200))
	_staircase(Vector3(30, 0, 0), 10, 0.18, 0.32)

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

	player.global_position = Vector3(0, 1.05, 60)
	Props.give_weapons(player)

	await baker.baked
	await _frames(5)
	await _run()
	Engine.physics_ticks_per_second = 60

	print("\n==== RESULTS ====")
	for r in results:
		print(r)

	get_tree().quit()


func _run() -> void:
	# S1 on, and without the jitter fix, which fights interpolation
	_check("S1 physics interpolation is on and the jitter fix is off", get_tree().physics_interpolation and Engine.physics_jitter_fix == 0.0,
		"interpolation %s jitter fix %.2f" % [get_tree().physics_interpolation, Engine.physics_jitter_fix])

	# S2 what moves every frame is drawn as set: the camera (placed by hand),
	#    the neck, the HUD, the retro screen, effects, sounds, torches
	var torch: Node3D = TorchScript.new()
	add_child(torch)
	await _frames(2)
	var exempt := {
		"camera": player.camera,
		"neck": player.neck,
		"hud": player.hud,
		"retro": get_node_or_null("/root/Retro"),
		"torch": torch,
	}
	var fx: Node = get_node_or_null("Fx")
	var wrong := []

	for key in exempt:
		var node: Node = exempt[key]

		if node == null or node.physics_interpolation_mode != OFF:
			wrong.append(key)

	_check("S2 the camera, neck, HUD, retro screen and torches are drawn as set", wrong.is_empty() and player.camera.top_level,
		"not exempt %s camera top level %s effects node present %s" % [wrong, player.camera.top_level, fx != null])
	torch.queue_free()

	Engine.physics_ticks_per_second = 30

	# S3 a guard walking his round is drawn between his steps
	var route := Node3D.new()
	route.name = "Route"
	add_child(route)

	for at in [Vector3(-20, 0, 40), Vector3(-20, 0, 0)]:
		var point := Node3D.new()
		point.position = at
		route.add_child(point)

	var guard: CharacterBody3D = GUARD.instantiate()
	guard.position = Vector3(-20, 0, 40)
	guard.patrol_route = NodePath("../Route")
	guard.patrol_wait = 0.1
	add_child(guard)
	await _frames(40)
	var guard_steps := _steps(await _record(func(): return guard.get_global_transform_interpolated().origin, 24))
	_check("S3 a walking guard is drawn smoothly between physics ticks", _even(guard_steps),
		"per-frame steps %.4f..%.4f m" % [guard_steps.min(), guard_steps.max()])
	guard.queue_free()

	# S4 climbing stairs never dips the eye: each step is cancelled from the
	#    eye height at once, and the drawn body catches up over its tick. (The
	#    head bob is switched off: it dips on purpose.)
	_put_player(Vector3(30, 1.05, 3.0), 0.0)
	var feel: float = player.camera_feel
	player.camera_feel = 0.0
	await _frames(10)
	Input.action_press("move_forward")
	var heights: Array = await _record(func(): return player.camera.global_position.y, 70)
	Input.action_release("move_forward")
	player.camera_feel = feel
	var dip := 0.0

	for i in range(1, heights.size()):
		dip = maxf(dip, float(heights[i - 1]) - float(heights[i]))

	var climbed: float = float(heights[-1]) - float(heights[0])
	# The body itself settles a few millimetres onto a tread; a step drawn
	# without the fix would drop the eye by the whole step, 0.18 m.
	_check("S4 climbing stairs the eye rises without dipping", climbed > 0.8 and dip < 0.02,
		"climbed %.2f m, worst dip %.4f m" % [climbed, dip])

	# S5 mouse look is instant: turned between ticks, the view has turned in
	#    that same frame, not half of it
	_put_player(Vector3(0, 1.05, 60), 0.0)
	await _frames(10)
	var turned := [false]
	var recorder := Recorder.new()
	recorder.process_priority = 1000
	recorder.read = func():
		return -player.camera.global_basis.z
	add_child(recorder)
	await get_tree().process_frame
	# As the mouse does it: between ticks, before the player's _process.
	player.rotate_y(0.6)
	var wanted: Vector3 = -player.neck.global_basis.z
	await get_tree().process_frame
	recorder.queue_free()
	var shown: Vector3 = recorder.seen[-1]
	_check("S5 mouse look shows in the same frame", shown.angle_to(wanted) < 0.03,
		"view off the look direction by %.3f rad" % shown.angle_to(wanted))

	# S6 an arrow is drawn from the bow, not flown in from the world's origin
	_put_player(Vector3(60, 1.05, 60), 0.0)
	player.inventory.select_by_id(&"bow")
	await _frames(20)
	var fired := []
	player.combat.fired.connect(func(a): fired.append(a), CONNECT_ONE_SHOT)
	Input.action_press("throw")
	await _frames(30)
	Input.action_release("throw")
	await _until(func(): return not fired.is_empty(), 10)
	var arrow: Node3D = fired[0] if not fired.is_empty() else null
	var arrow_gap := INF

	if arrow != null and is_instance_valid(arrow):
		arrow_gap = arrow.get_global_transform_interpolated().origin.distance_to(player.global_position)

	_check("S6 a loosed arrow is drawn at the bow", arrow_gap < 3.0,
		"drawn %.2f m from you" % arrow_gap)

	# S7 a felled guard's body and sword are drawn where they land, not slid
	#    in from where they were made
	player.inventory.select_by_id(&"sword")
	player.debug_light_level = 1.0
	var victim: CharacterBody3D = GUARD.instantiate()
	victim.position = Vector3(75, 0, 58.5)
	victim.rotation.y = PI
	add_child(victim)
	victim.block_chance = 0.0
	victim._attack_timer = 999.0
	# One blow kills him, but he is not weak enough to be cut apart.
	victim.max_health = 1.0
	victim.health = 1.0
	victim._engage(player)
	_put_player(Vector3(75, 1.05, 60), 0.0)
	await _frames(20)
	var id := victim.get_instance_id()
	var bodies_before := get_tree().get_nodes_in_group(&"bodies").size()
	await _tap("throw")
	await _until(func(): return not is_instance_id_valid(id), 40)
	await get_tree().process_frame
	var body := _last_body()
	var sword: Node3D = null

	for child in get_children():
		if String(child.name).begins_with("DroppedSword"):
			sword = child

	var body_gap: float = body.get_global_transform_interpolated().origin.distance_to(body.global_position) if body != null else INF
	var sword_gap: float = sword.get_global_transform_interpolated().origin.distance_to(sword.global_position) if sword != null else INF
	_check("S7 a body and a dropped sword are drawn where they are",
		get_tree().get_nodes_in_group(&"bodies").size() == bodies_before + 1 and body_gap < 0.3 and sword_gap < 0.5,
		"body drawn %.3f m off, sword %.3f m off" % [body_gap, sword_gap])

	# S8 a kicked crate slides smoothly: drawn moving every frame
	var crate := Props.crate(self, Vector3(90, 0.3, 58.8), 0.5, 5.0)
	_put_player(Vector3(90, 1.05, 60), 0.0)
	await _frames(20)
	await _tap("kick")
	await _frames(8)
	var crate_steps := _steps(await _record(func(): return crate.get_global_transform_interpolated().origin, 16))
	_check("S8 a kicked crate is drawn moving every frame", crate_steps.min() > 0.0005,
		"per-frame steps %.4f..%.4f m" % [crate_steps.min(), crate_steps.max()])


# --------------------------------------------------------------------------

## Keeps what `read` gives after every frame's _process, for `frames` frames.
func _record(read: Callable, frames: int) -> Array:
	var recorder := Recorder.new()
	recorder.read = read
	recorder.process_priority = 1000
	add_child(recorder)

	for i in frames:
		await get_tree().process_frame

	recorder.queue_free()
	return recorder.seen


func _steps(points: Array) -> Array:
	var steps := []

	for i in range(1, points.size()):
		steps.append((points[i] as Vector3).distance_to(points[i - 1]))

	return steps


## Moving every frame, and no frame's step far from another's.
func _even(steps: Array) -> bool:
	return not steps.is_empty() and steps.min() > 0.0 and steps.max() < steps.min() * 1.6


func _staircase(foot: Vector3, count: int, rise: float, run: float) -> void:
	for i in count:
		var top := rise * (i + 1)
		Props.block(self, foot + Vector3(0, top * 0.5, -run * (i + 0.5)), Vector3(3.0, top, run))

	var landing := rise * count
	Props.block(self, foot + Vector3(0, landing * 0.5, -run * count - 2.0), Vector3(3.0, landing, 4.0))


func _put_player(at: Vector3, yaw: float) -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "throw", "block", "kick"]:
		Input.action_release(a)

	player.movement_state = 0
	player.velocity = Vector3.ZERO
	player.global_position = at
	player.rotation.y = yaw
	player.neck.rotation.x = 0.0
	player.combat._reset()
	player.combat.adrenaline = 0.0
	player.reset_physics_interpolation()


func _last_body() -> Node3D:
	var found: Node3D = null

	# A man's body, not a part cut off one (SeveredPart.gd).
	for b in get_tree().get_nodes_in_group(&"bodies"):
		if b.get("part") == null:
			found = b

	return found


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


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
