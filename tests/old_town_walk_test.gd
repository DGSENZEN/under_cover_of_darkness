extends Node3D
## The old town walked by the real player (plan B1a, Task 16b): every
## route_check route of the level, from its first point to its last, played
## through the controller as a player would: doors frobbed open, steered
## point to point, jump pressed where he is held up (a mantle, a hang, a
## climb over), ladders looked up or down; each must arrive.
##   Godot --headless --fixed-fps 60 --path . res://tests/old_town_walk_test.tscn [-- --only=<prefix>]
## Each route a check: W1 <route>.

var MAP := "res://maps/old_town.tscn"
var LEVEL := "res://assets/level/old_town/old_town.json"
## How near a point counts as reached (m, flat), and its finish's height.
const REACH := 0.6
const ARRIVE := 1.2
const ARRIVE_Y := 0.4
## Held up this long (s) with no headway: jump is pressed.
const STUCK := 0.5
## Hanging, the hands over the feet (m).
const HANDS := 1.9
## Jumped for, a ledge's lip this far ahead (m).
const GRAB_STANDOFF := 0.7

var map: Node3D
var player: CharacterBody3D
var results: Array[String] = []
var _loose := {}


func _ready() -> void:
	var only := ""

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
		elif arg.begins_with("--map="):
			MAP = arg.trim_prefix("--map=")
		elif arg.begins_with("--level="):
			LEVEL = arg.trim_prefix("--level=")

	map = (load(MAP) as PackedScene).instantiate()
	add_child(map)
	await map.ready_to_play
	player = map.player
	# (A fall in one route must not reload the town under the next.)
	player.invulnerable = true
	player.reload_on_death = false

	for name in map.guards:
		map.guards[name].set_physics_process(false)
		map.guards[name].set_process(false)

	for door in get_tree().get_nodes_in_group(&"doors"):
		if not bool(door.get("is_open")) and not bool(door.get("locked")):
			door.call(&"frob", player)

	await _frames(120)
	var routes := _routes()

	# (Loose things knocked about by one route are put back for the next.)
	for body in find_children("*", "RigidBody3D", true, false):
		_loose[body] = (body as RigidBody3D).global_transform

	for name in routes:
		if only != "" and not String(name).begins_with(only):
			continue

		await _walk(name, routes[name])

	print("\n==== RESULTS ====")

	for r in results:
		print(r)

	get_tree().quit()


## The level's routes: name → [[position, move]] in order.
func _routes() -> Dictionary:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LEVEL))
	var out := {}

	for m in data["markers"]:
		if m["ucd"] != "route_check":
			continue

		var props: Dictionary = m["props"]
		var p: Array = m["position"]
		out.get_or_add(props["route"], []).append([int(props["order"]), Vector3(p[0], p[1], p[2]), String(props["move"])])

	var names := out.keys()
	names.sort()
	var sorted := {}

	for name in names:
		var points: Array = out[name]
		points.sort_custom(func(a, b): return a[0] < b[0])
		sorted[name] = points.map(func(e): return [e[1], e[2]])

	return sorted


func _walk(name: String, points: Array) -> void:
	var start: Vector3 = points[0][0]
	var finish: Vector3 = points[-1][0]
	_put(start, points[1][0] if points.size() > 1 else finish)
	await _frames(20)
	var next := mini(1, points.size() - 1)
	var limit := 900 + 160 * points.size()
	var still: Vector3 = player.get_feet_position()
	var held := 0.0
	var arrived := false

	Input.action_press("move_forward")

	for i in limit:
		var feet: Vector3 = player.get_feet_position()

		if player.is_on_floor() and player.movement_state == player.MoveState.LOCOMOTION and next == points.size() - 1 \
				and Vector2(feet.x - finish.x, feet.z - finish.z).length() <= ARRIVE and absf(feet.y - finish.y) <= ARRIVE_Y:
			arrived = true
			break

		var target: Vector3 = points[next][0]

		# (Hanging, a point on the ledge is reached by the hands; a grab, by
		# hanging at all.)
		var hanging_now: bool = player.movement_state == player.MoveState.HANGING
		var hands := feet.y + (HANDS if hanging_now else 0.0)
		var grabbed: bool = hanging_now and points[next][1] == "grab"
		# (On a ladder, its foot or its head: the climber is held off its
		# wall and stops short of the floor.)
		var laddered: bool = player.movement_state == player.MoveState.CLIMBING and Vector2(target.x - feet.x, target.z - feet.z).length() < 1.0 \
			and absf(target.y - feet.y) < 0.6

		# (Hanging, the body hangs out from the ledge's lip.)
		var reach := REACH + (0.3 if hanging_now else 0.0)

		if (grabbed or laddered or Vector2(target.x - feet.x, target.z - feet.z).length() < reach and absf(target.y - hands) < 1.5) \
				and next < points.size() - 1:
			next += 1
			target = points[next][0]

		# (A ledge out of reach standing is jumped for from in front of its
		# lip, not from under it: stood off toward where he came from.)
		var aim := target

		if points[next][1] == "grab" and next > 0:
			var back: Vector3 = points[next - 1][0] - target
			back.y = 0.0
			aim = target + back.normalized() * GRAB_STANDOFF

		var flat := Vector2(aim.x - feet.x, aim.z - feet.z)

		# (There: jumped for straight up, facing it, and pushed into it near
		# the top, jump held, as a man reaches for a ledge over him.)
		if points[next][1] == "grab" and flat.length() < 0.3 and player.movement_state == player.MoveState.LOCOMOTION:
			flat = Vector2(target.x - feet.x, target.z - feet.z)
			player.rotation.y = atan2(-flat.x, -flat.y)
			Input.action_release("move_forward")
			Input.action_press("jump")

			for f in 40:
				if f == 12:
					Input.action_press("move_forward")

				await get_tree().physics_frame

			Input.action_release("jump")
			continue

		# (A gap: run at it, jump from its edge, where the way's last point
		# before it is.)
		var leaping: bool = points[next][1] in ["jump", "sprint_jump", "assist_jump"]
		_hold("sprint", leaping)

		var off: Vector2 = Vector2(feet.x - points[next - 1][0].x, feet.z - points[next - 1][0].z) if next > 0 else Vector2.ZERO
		var across: Vector2 = Vector2(target.x - points[next - 1][0].x, target.z - points[next - 1][0].z).normalized() if next > 0 else Vector2.ZERO

		if leaping and next > 0 and player.is_on_floor() and player.movement_state == player.MoveState.LOCOMOTION and off.length() < 1.0 \
				and off.dot(across) > -0.15:
			Input.action_press("jump")

			for f in 20:
				await get_tree().physics_frame

			Input.action_release("jump")
			continue

		if flat.length() > 0.05 and player.movement_state in [player.MoveState.LOCOMOTION, player.MoveState.SWIMMING]:
			player.rotation.y = atan2(-flat.x, -flat.y)

		# (On a ladder: facing it, as a man climbs; looking up to climb up,
		# down to climb down.)
		if player.movement_state == player.MoveState.CLIMBING and player.current_climb != null and not bool(player.current_climb.get("rope")):
			var n: Vector3 = player.climb_normal()
			player.rotation.y = atan2(n.x, n.z)

		var neck: Node3D = player.get_node("Neck")
		neck.rotation.x = deg_to_rad(-55.0 if target.y < feet.y - 0.3 else 30.0) if player.movement_state == player.MoveState.CLIMBING else 0.0

		# (Hanging: along the ledge hand over hand to a shimmy's point, sideways;
		# let go over a point below; else pulled up, forward.)
		var hanging: bool = player.movement_state == player.MoveState.HANGING
		var move: String = points[next][1]
		var side := 0.0

		if hanging and move == "shimmy":
			side = signf((target - feet).dot(player.global_transform.basis.x))

		_hold("move_forward", not hanging or (move != "shimmy" and move != "grab"))
		_hold("move_right", side > 0.0)
		_hold("move_left", side < 0.0)

		# (Let go: hanging over a point below; on a ladder at a walk's level.)
		var climbing: bool = player.movement_state == player.MoveState.CLIMBING
		var off_ladder: bool = climbing and move == "walk" and target.y < feet.y + 0.05 and absf(target.y - feet.y) < 0.6

		if hanging and move != "shimmy" and move != "grab" and target.y < feet.y - 0.3 or off_ladder:
			Input.action_press("crouch")
			await get_tree().physics_frame
			Input.action_release("crouch")

		if OS.has_environment("WALK_TRACE") and i % 30 == 0:
			var climb: Node = player.current_climb
			print("TRACE %s %d feet %s vel %s state %d neck %.2f climb %s" % [name, i, feet.snapped(Vector3.ONE * 0.01), player.velocity.snapped(Vector3.ONE * 0.01),
				player.movement_state, neck.rotation.x, "-" if climb == null else "%s top %.2f" % [climb.name, climb.top_y()]])

		held += 1.0 / 60.0

		if feet.distance_to(still) > 0.2:
			still = feet
			held = 0.0

		if held > STUCK and player.movement_state == player.MoveState.LOCOMOTION:
			# (Jumped for a ledge out of reach standing: held, to catch it.)
			var hold := 30 if points[next][1] in ["grab", "hang"] else 1
			Input.action_press("jump")

			for f in hold:
				await get_tree().physics_frame

			Input.action_release("jump")
			held = 0.0
		else:
			await get_tree().physics_frame

	for a in ["move_forward", "move_left", "move_right", "jump", "crouch", "sprint"]:
		Input.action_release(a)

	var end: Vector3 = player.get_feet_position()
	results.append("%s  W1 %s%s" % ["PASS" if arrived else "FAIL", name, "" if arrived else "   [ends %s %s, at point %d of %d]" % [end.snapped(Vector3.ONE * 0.1),
		["LOCOMOTION", "MOVING", "HANGING", "CLIMBING", "SWIMMING"][player.movement_state], next + 1, points.size()]])
	player.movement_state = player.MoveState.LOCOMOTION
	player.current_move = null
	await _frames(10)


func _hold(action: String, on: bool) -> void:
	if on and not Input.is_action_pressed(action):
		Input.action_press(action)
	elif not on and Input.is_action_pressed(action):
		Input.action_release(action)


func _put(feet: Vector3, toward: Vector3) -> void:
	for body in _loose:
		if is_instance_valid(body):
			(body as RigidBody3D).global_transform = _loose[body]
			(body as RigidBody3D).linear_velocity = Vector3.ZERO
			(body as RigidBody3D).angular_velocity = Vector3.ZERO

	for a in ["move_forward", "move_back", "move_left", "move_right", "jump", "sprint", "crouch"]:
		Input.action_release(a)

	player.movement_state = player.MoveState.LOCOMOTION
	player.current_move = null
	player.current_climb = null
	player.velocity = Vector3.ZERO

	# (A route that ended crouched, let go off a ladder, leaves no trace on
	# the next.)
	if bool(player.get("is_crouched")):
		player.call(&"_set_crouched", false)
	var middle: Vector3 = player.global_position - player.get_feet_position()
	player.global_position = feet + middle + Vector3.UP * 0.05
	player.rotation.y = atan2(-(toward.x - feet.x), -(toward.z - feet.z))
	player.get_node("Neck").rotation.x = 0.0
	player.reset_physics_interpolation()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
