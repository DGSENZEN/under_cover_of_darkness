## Visual check for the movement feel: the same walk, sprint, stop, jump,
## drop, creep, stand and lean on the old feel and on the new, with what the
## view and the hands did on every tick written out for tools/plot_motion.py.
## Headless is fine: nothing here needs the screen.
##   Godot --headless --fixed-fps 60 --path . res://tests/visual/stage_motion.tscn -- --out=<folder>
##   python3 tools/plot_motion.py <folder>
extends Node3D

const PLAYER := preload("res://Player.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const ViewArmsScript := preload("res://scripts/Interaction/ViewArms.gd")

## [name, seconds, actions held]; "platform" first puts you on the 3 m block.
const SCRIPT := [
	["stand", 0.5, []],
	["walk", 1.5, ["move_forward"]],
	["sprint", 1.5, ["move_forward", "sprint"]],
	["stop", 1.0, []],
	["jump", 1.2, ["move_forward", "jump@0.3-0.9"]],
	["drop", 2.2, ["platform", "move_forward"]],
	["creep", 1.5, ["crouch", "move_forward"]],
	["rise", 0.8, []],
	["lean", 0.8, ["lean_right"]],
	["back", 0.5, []],
]

var out_dir := "user://motion/"
var player: CharacterBody3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6).trim_suffix("/") + "/"

	DirAccess.make_dir_recursive_absolute(out_dir)
	Props.block(self, Vector3(0, -0.5, 0), Vector3(200, 1, 200))
	Props.block(self, Vector3(-40, 1.5, 0), Vector3(6, 3, 6))

	player = PLAYER.instantiate()
	add_child(player)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.invulnerable = true
	player.reload_on_death = false

	if player.has_node("LightGem"):
		player.get_node("LightGem").queue_free()

	Props.give_weapons(player)
	player.inventory.select_by_id(&"sword")
	await _frames(30)

	for legacy in [true, false]:
		player.set_legacy_feel(legacy)
		var rows := await _perform()
		_write(out_dir + ("motion_old.csv" if legacy else "motion_new.csv"), rows)

	print("wrote %smotion_old.csv and %smotion_new.csv" % [out_dir, out_dir])
	get_tree().quit()


func _perform() -> Array:
	_put(Vector3(0, 1.05, 60))
	await _frames(40)
	var rows := []
	var t := 0.0
	var last_steps: int = player._steps
	var hand_rest: float = player.hand._main.position.y

	for part in SCRIPT:
		var name: String = part[0]
		var seconds: float = part[1]
		var held: Array = part[2]
		_release()

		if held.has("platform"):
			_put(Vector3(-40, 4.05, 2.5))

		for action in held:
			if action != "platform" and not String(action).contains("@"):
				Input.action_press(action)

		var ticks := int(round(seconds * 60.0))

		for i in ticks:
			# "jump@a-b": held from a to b seconds into the part.
			for action in held:
				if String(action).contains("@"):
					var span := String(action).get_slice("@", 1).split_floats("-")
					var at := i / 60.0

					if at >= span[0] and at < span[1]:
						Input.action_press(String(action).get_slice("@", 0))
					else:
						Input.action_release(String(action).get_slice("@", 0))

			await _frames(1)
			t += 1.0 / 60.0
			var view: Vector3 = player.juice.view_position
			var turn: Vector3 = player.juice.view_rotation
			var stepped: bool = player._steps != last_steps
			last_steps = player._steps
			rows.append([
				"%.4f" % t, name,
				"%.3f" % Vector2(player.velocity.x, player.velocity.z).length(),
				"%.5f" % view.x, "%.5f" % view.y, "%.5f" % view.z,
				"%.4f" % rad_to_deg(turn.x), "%.4f" % rad_to_deg(turn.z),
				"%.3f" % player.camera.fov,
				# The hands are drawn in the view's miniature: grown back to
				# the size of the motion they show.
				"%.5f" % ((player.hand._main.position.y - hand_rest) / ViewArmsScript.SCALE),
				"1" if stepped else "0",
			])

	_release()
	return rows


func _write(path: String, rows: Array) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_line("t,phase,speed,view_x,view_y,view_z,pitch_deg,roll_deg,fov,hand_y,step")

	for row in rows:
		file.store_line(",".join(PackedStringArray(row)))

	file.close()


func _put(at: Vector3) -> void:
	_release()
	player.movement_state = 0
	player.velocity = Vector3.ZERO
	player.global_position = at
	player.rotation.y = 0.0
	player.neck.rotation.x = 0.0
	player.reset_physics_interpolation()


func _release() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "sprint", "crouch", "jump", "lean_left", "lean_right"]:
		Input.action_release(a)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
