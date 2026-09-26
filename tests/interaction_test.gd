extends Node3D

const PLAYER := preload("res://Player.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const GUARD := preload("res://Guard.tscn")
const TemperamentScript := preload("res://scripts/AISystem/Temperament.gd")

var player: CharacterBody3D
var results: Array[String] = []
var labels: Array[String] = []
var _last_move = null

var door_a: Node3D
var door_b: Node3D
var chest_a: Node3D
var loot_1: RigidBody3D
var loot_2: RigidBody3D
var key_a: RigidBody3D
var crate_a: RigidBody3D
var heavy: RigidBody3D


func _ready() -> void:
	# Every guard at his class's own temperament: these checks are exact.
	TemperamentScript.rolling = false
	Props.block(self, Vector3(8, -0.5, -4), Vector3(40, 1, 30))         # floor, top at 0

	door_a = Props.door(self, Vector3(-0.5, 0, -4.0))
	door_b = Props.door(self, Vector3(3.5, 0, -4.0), 0.0, 1.0, 2.1, true, &"cellar", "cellar door")
	key_a = Props.key(self, Vector3(4.0, 0.62, -1.0), &"cellar", "cellar key")
	Props.block(self, Vector3(4.0, 0.3, -1.0), Vector3(0.4, 0.6, 0.4))  # pedestal under the key

	chest_a = Props.chest(self, Vector3(8.0, 0.0, -4.0))
	loot_1 = Props.loot(self, Vector3(7.8, 0.15, -4.0), 50, "goblet")
	loot_2 = Props.loot(self, Vector3(8.2, 0.15, -4.0), 120, "necklace")

	crate_a = Props.crate(self, Vector3(12.0, 0.3, -3.0))
	heavy = Props.crate(self, Vector3(14.0, 0.4, -3.0), 0.8, 60.0, Color(0.3, 0.3, 0.35))
	Props.block(self, Vector3(12.0, 0.6, -8.0), Vector3(3, 1.2, 2))      # ledge 1.2 for the carry test

	player = PLAYER.instantiate()
	add_child(player)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.debug_traversal = false
	player.reload_on_death = false
	if player.has_node("LightGem"):
		player.get_node("LightGem").queue_free()

	await _frames(10)
	await _run()

	print("\n==== RESULTS ====")
	for r in results:
		print(r)
	get_tree().quit()


func _physics_process(_d: float) -> void:
	if player == null:
		return
	if player.current_move != _last_move:
		_last_move = player.current_move
		if _last_move != null:
			labels.append(String(_last_move.label))


func _run() -> void:
	# I1 open and close a door
	await _place(Vector3(0.0, 1.05, -2.2), 0.0)
	_aim(Vector3(0.0, 1.0, -4.0))
	await _frames(3)
	var prompt_open: String = player.frob.current_prompt()
	await _tap("frob")
	await _frames(70)
	var angle_open: float = absf(wrapf(door_a.rotation.y, -PI, PI))
	# The door swung away; aim at where its panel is now.
	_aim(door_a.to_global(Vector3(0.5, 1.05, 0.0)))
	await _frames(3)
	await _tap("frob")
	await _frames(70)
	var angle_closed: float = absf(wrapf(door_a.rotation.y, -PI, PI))
	_check("I1 door opens and closes", prompt_open.begins_with("Open") and angle_open > 1.2 and angle_closed < 0.05,
		"prompt '%s' open %.2f closed %.2f" % [prompt_open, angle_open, angle_closed])

	# I2 the door swings away from the frobber: from the other side it opens the other way
	await _place(Vector3(0.0, 1.05, -5.8), PI)
	_aim(Vector3(0.0, 1.0, -4.0))
	await _frames(3)
	await _tap("frob")
	await _frames(70)
	var angle_other: float = wrapf(door_a.rotation.y, -PI, PI)
	_aim(door_a.to_global(Vector3(0.5, 1.05, 0.0)))
	await _frames(3)
	await _tap("frob")
	await _frames(70)
	_check("I2 door swings away from the player", angle_other < -1.2, "angle %.2f" % angle_other)

	# I3 locked door needs the key
	await _place(Vector3(4.0, 1.05, -2.2), 0.0)
	_aim(Vector3(4.0, 1.0, -4.0))
	await _frames(3)
	var prompt_locked: String = player.frob.current_prompt()
	await _tap("frob")
	await _frames(40)
	var stayed_shut: bool = absf(wrapf(door_b.rotation.y, -PI, PI)) < 0.05
	await _place(Vector3(4.0, 1.05, 0.2), 0.0)
	_aim(Vector3(4.0, 0.62, -1.0))
	await _frames(3)
	await _tap("frob")
	await _frames(5)
	var has_key: bool = player.inventory.has_key(&"cellar")
	var belt_item: Dictionary = player.inventory.selected_item()
	await _place(Vector3(4.0, 1.05, -2.2), 0.0)
	_aim(Vector3(4.0, 1.0, -4.0))
	await _frames(3)
	var prompt_unlock: String = player.frob.current_prompt()
	await _tap("frob")
	await _frames(12)
	var turning: bool = door_b.locked and player.frob._unlocking and player.hand.is_busy()
	await _frames(110)
	var opened_with_key: bool = absf(wrapf(door_b.rotation.y, -PI, PI)) > 1.2
	_check("I3 locked door and key", prompt_locked == "Locked" and stayed_shut and has_key and belt_item.get("name", "") == "cellar key" and opened_with_key and not door_b.locked,
		"prompt '%s' shut %s key %s belt %s opened %s" % [prompt_locked, stayed_shut, has_key, belt_item.get("name", ""), opened_with_key])
	_check("U2 the key goes to the lock and turns before it opens", prompt_unlock == "Unlock the cellar door" and turning and not player.frob._unlocking,
		"prompt '%s' still locked while turning %s" % [prompt_unlock, turning])

	# I4 chest: open the lid, take the loot inside
	await _place(Vector3(8.0, 1.05, -2.4), 0.0)
	_aim(Vector3(8.0, 0.56, -3.75))
	await _frames(3)
	var prompt_chest: String = player.frob.current_prompt()
	await _tap("frob")
	await _frames(50)
	var lid_open: bool = chest_a.is_open and absf(chest_a.get_node("Lid").rotation.x) > 1.5
	player.global_position = Vector3(8.0, 1.05, -3.05)
	await _frames(5)
	# Aim at the top of the loot so the ray clears the chest's front wall.
	_aim(Vector3(7.8, 0.2, -4.0))
	await _frames(3)
	var prompt_loot: String = player.frob.current_prompt()
	await _tap("frob")
	await _frames(5)
	var purse_1: int = player.inventory.purse
	_aim(Vector3(8.2, 0.2, -4.0))
	await _frames(3)
	await _tap("frob")
	await _frames(5)
	var purse_2: int = player.inventory.purse
	_check("I4 chest and loot", prompt_chest.begins_with("Open") and lid_open and prompt_loot.begins_with("Take") and purse_1 == 50 and purse_2 == 170,
		"prompt '%s' lid %s loot prompt '%s' purse %d then %d" % [prompt_chest, lid_open, prompt_loot, purse_1, purse_2])

	# I5 carry a crate, walk backwards with it, set it down
	await _place(Vector3(12.0, 1.05, -1.6), 0.0)
	_aim(Vector3(12.0, 0.3, -3.0))
	await _frames(3)
	await _tap("frob")
	await _frames(5)
	var picked: bool = player.frob.held == crate_a
	Input.action_press("move_back")
	await _frames(45)
	Input.action_release("move_back")
	await _frames(10)
	var hold_point: Vector3 = player.frob._hold_point()
	var follow_distance: float = crate_a.global_position.distance_to(hold_point)
	await _tap("frob")
	await _frames(30)
	var set_down: bool = player.frob.held == null
	var near: float = Vector3(crate_a.global_position.x - player.global_position.x, 0, crate_a.global_position.z - player.global_position.z).length()
	_check("I5 carry and set down", picked and follow_distance < 0.6 and set_down and near < 1.8 and crate_a.global_position.y < 0.6,
		"picked %s follow %.2f set down %s near %.2f y %.2f" % [picked, follow_distance, set_down, near, crate_a.global_position.y])

	# I6 throw it
	await _place(Vector3(crate_a.global_position.x, 1.05, crate_a.global_position.z + 1.5), 0.0)
	_aim(crate_a.global_position)
	await _frames(3)
	await _tap("frob")
	await _frames(20)
	var held_again: bool = player.frob.held == crate_a
	player.get_node("Neck").rotation.x = 0.15
	await _tap("throw")
	await _frames(2)
	var thrown_velocity: Vector3 = crate_a.linear_velocity
	_check("I6 throw", held_again and player.frob.held == null and thrown_velocity.z < -5.0,
		"held %s velocity %s" % [held_again, thrown_velocity])

	# I7 too heavy to lift
	await _place(Vector3(14.0, 1.05, -1.6), 0.0)
	_aim(Vector3(14.0, 0.4, -3.0))
	await _frames(3)
	var prompt_heavy: String = player.frob.current_prompt()
	await _tap("frob")
	await _frames(5)
	_check("I7 too heavy", prompt_heavy == "Too heavy" and player.frob.held == null, "prompt '%s' held %s" % [prompt_heavy, player.frob.held])

	# I8 carrying blocks climbing
	await _frames(60)
	await _place(Vector3(crate_a.global_position.x, 1.05, crate_a.global_position.z + 1.5), 0.0)
	_aim(crate_a.global_position)
	await _frames(3)
	await _tap("frob")
	await _frames(10)
	var carrying: bool = player.frob.held == crate_a
	player.global_position = Vector3(12.0, 1.05, -6.2)
	player.get_node("Neck").rotation.x = 0.0
	crate_a.global_position = player.frob._hold_point()
	await _frames(5)
	labels.clear()
	Input.action_press("move_forward")
	await _frames(20)
	await _tap("jump")
	await _frames(40)
	_release_all()
	_check("I8 carrying blocks climbing", carrying and labels.is_empty(), "carrying %s labels %s" % [carrying, labels])

	# I12 both hands on a crate: the item in hand goes out of sight, then comes back
	var hand: Node3D = player.get_node("Neck/Camera3D/Hand")
	var hidden_while_carrying: bool = not hand.is_item_visible()
	player.frob.drop_held()
	await _frames(30)
	_check("I12 hand item hides while carrying", hidden_while_carrying and hand.is_item_visible(),
		"hidden %s visible after %s" % [hidden_while_carrying, hand.is_item_visible()])

	# I14 a tool picked up in the world joins what you carry, and shows in your hand
	await _place(Vector3(-6.0, 1.05, 4.0), 0.0)
	var pick := Props.tool(self, Vector3(-6.0, 0.65, 2.6), &"lockpick", "lockpick", Color(0.6, 0.6, 0.65), "rod")
	Props.block(self, Vector3(-6.0, 0.3, 2.6), Vector3(0.4, 0.6, 0.4))
	await _frames(20)
	_aim(pick.global_position)
	await _frames(4)
	var prompt_tool: String = player.frob.current_prompt()
	await _tap("frob")
	await _frames(5)
	var carried: bool = player.inventory.select_by_id(&"lockpick")
	await _frames(20)
	var hand_node: Node3D = player.get_node("Neck/Camera3D/Hand")
	var shown: bool = hand_node.current_item_mesh() != null and hand_node.is_item_visible()
	_check("I14 tool pickup", prompt_tool == "Take lockpick" and carried and shown and not is_instance_valid(pick),
		"prompt '%s' carried %s shown in hand %s" % [prompt_tool, carried, shown])
	player.get_node("Neck").rotation.x = 0.0

	# I11 the wheel cycles through every item and through empty hands
	player.inventory.select_by_id(&"cellar key")
	player.inventory.belt_index = 0
	var seen: Array[String] = []
	for i in 3:
		player.inventory.select_next(1)
		seen.append(String(player.inventory.selected_item().get("name", "empty")))
	await _ui_checks()

	_check("I11 wheel includes empty hands", seen == ["lockpick", "empty", "cellar key"], "seen %s" % [seen])


# --------------------------------------------------------------------------
func _place(pos: Vector3, yaw: float) -> void:
	_release_all()
	await _frames(2)
	player.movement_state = 0
	player.current_move = null
	player.velocity = Vector3.ZERO
	player.global_position = pos
	player.rotation.y = yaw
	player.get_node("Neck").rotation.x = 0.0
	await _frames(15)
	labels.clear()
	_last_move = null


func _aim(target: Vector3) -> void:
	var eye: Vector3 = player.get_node("Neck").global_position
	var d := target - eye
	player.rotation.y = atan2(-d.x, -d.z)
	player.get_node("Neck").rotation.x = atan2(d.y, Vector2(d.x, d.z).length())


func _ui_checks() -> void:
	var hud: CanvasLayer = player.hud
	var hand: Node3D = player.get_node("Neck/Camera3D/Hand")
	var chest_b := Props.chest(self, Vector3(-3.0, 0.0, 6.0))
	var loot_3 := Props.loot(self, Vector3(-3.2, 0.15, 6.0), 75, "silver cup")
	var door_c := Props.door(self, Vector3(-6.5, 0, 3.0))
	await _frames(10)

	# U1 prompts name the key: [E] Open door
	await _place(Vector3(-6.0, 1.05, 4.8), 0.0)
	_aim(door_c.to_global(Vector3(0.5, 1.05, 0.0)))
	await _frames(12)
	var actions: Array = player.frob.current_actions()
	var shown: PackedStringArray = hud.prompt_texts()
	_check("U1 prompts show the key and the verb", actions == [[&"frob", "Open door"]] and shown == PackedStringArray(["[E] Open door"]),
		"actions %s shown %s" % [actions, shown])

	# U3 loot flies into the off hand and into the purse; its tag tallies it
	await _place(Vector3(-3.0, 1.05, 7.4), 0.0)
	_aim(Vector3(-3.0, 0.56, 5.75))
	await _frames(3)
	await _tap("frob")
	await _frames(50)
	player.global_position = Vector3(-3.0, 1.05, 6.8)
	_aim(loot_3.global_position + Vector3.UP * 0.05)
	await _frames(4)
	var purse_before: int = player.inventory.purse
	await _tap("frob")
	var purse_at_once: int = player.inventory.purse
	var saw_purse := false
	var tally := ""
	for i in 40:
		await _frames(1)
		if hand.is_purse_visible():
			saw_purse = true
			tally = hand.tally_text()
	await _frames(60)
	_check("U3 loot is pocketed in the purse, and its tag tallies it", purse_at_once == purse_before + 75 and saw_purse and tally == str(purse_at_once) and not hand.is_busy() and not hand.is_purse_visible(),
		"purse %d -> %d, purse seen %s tag '%s', busy after %s" % [purse_before, purse_at_once, saw_purse, tally, hand.is_busy()])

	# U4 switching lowers one item out of view and raises the next
	var bomb := SphereMesh.new()
	bomb.radius = 0.05
	bomb.height = 0.1
	player.inventory.add_belt_item(&"flashbomb", "flash bomb", bomb)
	player.inventory.select_by_id(&"cellar key")
	await _frames(30)
	var before_mesh: Mesh = hand.current_item_mesh()
	player.inventory.select_by_id(&"flashbomb")
	await _frames(4)
	var lowered: bool = not hand.is_item_visible()
	await _frames(30)
	_check("U4 switching lowers, swaps, raises", before_mesh != null and lowered and hand.current_item_mesh() == bomb and hand.is_item_visible(),
		"lowered %s now holding the new item %s visible %s" % [lowered, hand.current_item_mesh() == bomb, hand.is_item_visible()])

	# U12 the new item's name is shown briefly
	_check("U12 a caption names what came into your hand", hud._caption.text == "flash bomb" and hud._caption.modulate.a > 0.5,
		"caption '%s' alpha %.2f" % [hud._caption.text, hud._caption.modulate.a])

	# U5 hands stay inside the body, so they never reach into a wall
	var reach := maxf(hand.get_node("MainHand").position.length(), hand.get_node("OffHand").position.length() if hand.get_node("OffHand").visible else 0.0)
	_check("U5 resting hands stay within reach of the eye", reach <= hand.MAX_REACH, "farthest hand %.2f m (limit %.2f)" % [reach, hand.MAX_REACH])

	# U8 the hands are drawn on their own layer, which the lightgem never sees
	var layer: int = hand.VIEWMODEL_LAYER
	var eye_mask: int = player.get_node("Neck/Camera3D").cull_mask
	var gem_top: int = player.get_node("SubViewport/Camera3D").cull_mask
	var gem_bottom: int = player.get_node("SubViewport2/Camera3D").cull_mask
	var main_layers: int = hand.get_node("MainHand").get_child(0).layers
	_check("U8 hands are on a layer the lightgem cameras do not see", main_layers == layer and eye_mask & layer != 0 and gem_top & layer == 0 and gem_bottom & layer == 0,
		"layers %d eye sees %s gem sees %s/%s" % [main_layers, eye_mask & layer != 0, gem_top & layer != 0, gem_bottom & layer != 0])

	# U6 holding Tab raises the purse to look at
	Input.action_press("inventory")
	await _frames(15)
	var checking: bool = hand.is_purse_visible()
	var check_tally: String = hand.tally_text()
	Input.action_release("inventory")
	await _frames(20)
	_check("U6 Tab holds up the purse", checking and check_tally == str(player.inventory.purse) and not hand.is_purse_visible(),
		"up %s tag '%s' down after %s" % [checking, check_tally, not hand.is_purse_visible()])

	# U11 what a guard says is subtitled with who said it
	var g := GUARD.instantiate()
	g.debug_ai = false
	add_child(g)
	g.global_position = player.global_position + Vector3(3, -1.05, 0)
	await _frames(70)
	g.bark("Who's there?")
	await _frames(3)
	var subtitle: String = hud._subtitle.get_parsed_text()
	_check("U11 subtitles name the speaker", subtitle.contains("Guard") and subtitle.contains("Who's there?") and hud._subtitle_panel.modulate.a > 0.5,
		"'%s' alpha %.2f" % [subtitle, hud._subtitle_panel.modulate.a])
	g.queue_free()

	# U10 health shields only show when you are hurt
	await _frames(10)
	var hidden_full: bool = hud._shields.modulate.a < 0.05
	player.invulnerable = false
	player.take_damage(20.0, null)
	await _frames(40)
	_check("U10 health shows only when hurt", hidden_full and hud._shields.modulate.a > 0.9 and hud._vignette.modulate.a > 0.1,
		"hidden at full %s shields %.2f vignette %.2f" % [hidden_full, hud._shields.modulate.a, hud._vignette.modulate.a])

	# U7 Esc pauses, a click resumes. The handlers are called directly:
	# injected input can arrive twice in a headless run, and Esc toggles.
	var esc := InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	player._unhandled_input(esc)
	await get_tree().process_frame
	await get_tree().process_frame
	var paused: bool = get_tree().paused and hud._pause.visible
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	hud._unhandled_input(click)
	await get_tree().process_frame
	await _frames(3)
	_check("U7 Esc pauses and shows the pause screen; a click resumes", paused and not get_tree().paused and not hud._pause.visible,
		"paused with screen %s now paused %s screen %s" % [paused, get_tree().paused, hud._pause.visible])

	# U9 caught: the screen fades to black
	player.take_damage(1000.0, null)
	await _frames(90)
	_check("U9 death fades out", player.is_dead and hud._fade.color.a > 0.5 and hud._death.text == "You were caught.",
		"fade %.2f text '%s'" % [hud._fade.color.a, hud._death.text])
	player.is_dead = false
	player.health = player.max_health
	player.invulnerable = true
	hud._fade.color.a = 0.0
	player.hand.set_suppressed(false)
	chest_b.queue_free()


func _release_all() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "jump", "sprint", "crouch", "frob", "throw"]:
		if InputMap.has_action(a):
			Input.action_release(a)


func _tap(action: String) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
