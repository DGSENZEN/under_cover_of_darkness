extends Node3D
## Empower's effects, round two (docs/superpowers/specs/2026-10-23-empower-effects-design.md):
## the written pages lighting as the tome is read and their words flying into
## the gun hand; the charge in the hand (darkened skin, fur, veins pulsing
## with the beat, a twitch); spending it (the hand back to itself, claws on a
## blow and on a shot, a hit-stop); none with effects off, all gone after.

const PLAYER := preload("res://Player.tscn")
const GUARD_SCRIPT := preload("res://scripts/AISystem/Guard.gd")
const GUARD := preload("res://Guard.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")
const Fx := preload("res://scripts/Visual/Fx.gd")
const TemperamentScript := preload("res://scripts/AISystem/Temperament.gd")
const GarrisonScript := preload("res://scripts/AISystem/Garrison.gd")
const ViewArmsScript := preload("res://scripts/Interaction/ViewArms.gd")
const MagicFx := preload("res://scripts/Visual/MagicFx.gd")
const TimeFx := preload("res://scripts/Visual/TimeFx.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")

const GROUPS := [&"empower_word", &"empower_claw"]

var player: CharacterBody3D
var baker: NavigationRegion3D
var results: Array[String] = []


func _ready() -> void:
	TemperamentScript.rolling = false
	GUARD_SCRIPT.bleeding_on = false
	ViewArmsScript.new_arms = true
	Props.block(self, Vector3(0, -0.5, 0), Vector3(160, 1, 90))              # floor, its top at y = 0

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
	var hand: Node = player.hand
	var caster: Node = player.caster
	_put_player(Vector3(-20, 1.05, 30))
	await _frames(40)
	await _until(func(): return player.revolver.is_up(), 60)

	# R1 R2 reading: the pages' lines of script light as it is read; their
	# words fly off the page into the gun hand
	player.power.power = player.power.MAX
	Sfx.recording = true
	Sfx.recorded.clear()
	Input.action_press("spell_3")
	var lit_early := -1
	var lit_late := -1
	var on_page := 0
	var words_most := 0
	var word: Node3D = null
	var word_from := -1.0
	var word_to := -1.0
	var word_view := true
	var growled := false

	for f in 75:
		await get_tree().physics_frame
		if f == 6:
			growled = Sfx.recorded.any(func(e): return String(e[0]) == "roar")
			Sfx.recording = false
		if f == 20:
			lit_early = hand.tome_lit()
			on_page = hand.tome_glyphs().size()
		if f == 66:
			lit_late = hand.tome_lit()
		var words := get_tree().get_nodes_in_group(&"empower_word")
		words_most = maxi(words_most, words.size())
		for w in words:
			word_view = word_view and (w as VisualInstance3D).layers == 1 << 18
		if word == null and not words.is_empty():
			word = words[0]
			word_from = word.global_position.distance_to(hand.gun_hand_view_position())
		elif word != null and is_instance_valid(word):
			word_to = word.global_position.distance_to(hand.gun_hand_view_position())
		if caster.empowered():
			break

	Input.action_release("spell_3")
	_check("R1 the tome's pages carry lines of script that light as it is read", on_page >= 12 and lit_early >= 1 and lit_late > lit_early,
		"glyphs %d lit %d then %d" % [on_page, lit_early, lit_late])
	_check("R2 the words fly off the page into the gun hand, in your view", words_most >= 4 and word_view and word_from > 0.0 and word_to >= 0.0 and word_to < word_from * 0.6,
		"words at most %d, one went %.3f -> %.3f from the hand" % [words_most, word_from, word_to])
	_check("R4 a low growl rises as the tome is read", growled, "growled %s" % growled)
	await _frames(30)
	_check("R3 the words are gone once it is read", get_tree().get_nodes_in_group(&"empower_word").is_empty(), "left %d" % get_tree().get_nodes_in_group(&"empower_word").size())

	# C1 C2 C3 charged: the skin darkened, fur standing out of it, veins that
	# pulse with the beat, a twitch of the hand on the beat
	var passes: int = hand.fur_passes()
	var low := INF
	var high := -INF
	var twitched := 0.0

	for f in 60:
		await get_tree().physics_frame
		low = minf(low, hand.vein_glow())
		high = maxf(high, hand.vein_glow())
		twitched = maxf(twitched, hand.beat_kick())

	_check("C1 charged, fur stands out of the gun hand's skin, its skin darkened", passes >= 3 and hand.pelt_amount() > 0.9, "fur passes %d pelt %.2f" % [passes, hand.pelt_amount()])
	_check("C2 the veins glow and pulse with the heartbeat", low >= 0.0 and high - low > 0.3, "glow %.2f to %.2f" % [low, high])
	_check("C3 the gun hand twitches on the beat", twitched > 0.002 and twitched < 0.02, "twitch %.4f m" % twitched)

	# S1 S2 spent on a kick: claw rakes across where it landed, a hit-stop,
	# the hand back to itself
	GarrisonScript.clear_all()
	var man: CharacterBody3D = GUARD.instantiate()
	man.debug_ai = false
	man.position = Vector3(-20, 0, 28.4)
	man.rotation.y = PI
	add_child(man)
	await _frames(10)
	man.set_physics_process(false)
	await _tap("kick")
	var claws := 0
	var claw_near := false
	var stopped := false

	for f in 25:
		await get_tree().physics_frame
		var now := get_tree().get_nodes_in_group(&"empower_claw")
		claws = maxi(claws, now.size())
		for c in now:
			claw_near = claw_near or (c as Node3D).global_position.distance_to(man.global_position + Vector3.UP * 1.1) < 0.9
		stopped = stopped or TimeFx.is_active(&"empower")
		if not caster.empowered() and f > 12:
			break

	await _frames(20)
	_check("S1 spent on a kick: three claw rakes tear across where it landed, with a hit-stop", claws == 3 and claw_near and stopped,
		"claws %d near %s hit-stop %s" % [claws, claw_near, stopped])
	_check("S2 the hand goes back to itself", hand.fur_passes() == 0 and hand.pelt_amount() == 0.0 and get_tree().get_nodes_in_group(&"empower_claw").is_empty(),
		"fur passes %d pelt %.2f claws left %d" % [hand.fur_passes(), hand.pelt_amount(), get_tree().get_nodes_in_group(&"empower_claw").size()])
	man.queue_free()
	await _frames(30)

	# S3 spent on a shot: the claws fly out along the shot
	player.revolver.reset_for_practice()
	player.power.power = player.power.MAX
	Input.action_press("spell_3")
	await _until(func(): return caster.empowered(), 100)
	Input.action_release("spell_3")
	await _frames(20)
	var muzzle: Vector3 = player.global_position
	var ahead: Vector3 = -player.camera.global_basis.z
	await _tap("throw")
	var out_along := false
	var shot_claws := 0

	for f in 10:
		await get_tree().physics_frame
		var now := get_tree().get_nodes_in_group(&"empower_claw")
		shot_claws = maxi(shot_claws, now.size())
		for c in now:
			out_along = out_along or ((c as Node3D).global_position - muzzle).dot(ahead) > 1.0

	_check("S3 spent on a shot: three claw rakes fly out along it", shot_claws == 3 and out_along, "claws %d out along %s" % [shot_claws, out_along])
	await _frames(40)

	# X1 with effects off: it still reads and spends, and makes no words or claws
	Fx.enabled = false
	player.revolver.reset_for_practice()
	player.power.power = player.power.MAX
	Input.action_press("spell_3")
	var any := 0
	for f in 100:
		any = maxi(any, _count_all())
		if caster.empowered():
			break
		await get_tree().physics_frame
	Input.action_release("spell_3")
	var charged: bool = caster.empowered()
	await _frames(10)
	await _tap("throw")
	for f in 20:
		any = maxi(any, _count_all())
		await get_tree().physics_frame
	Fx.enabled = true
	_check("X1 with effects off, it reads and spends and makes no words or claws", charged and not caster.empowered() and any == 0, "charged %s effects %d" % [charged, any])
	await _frames(30)
	_check("X2 nothing left over", _count_all() == 0 and hand.fur_passes() == 0, "effects %d fur %d" % [_count_all(), hand.fur_passes()])


func _count_all() -> int:
	var n := 0

	for group in GROUPS:
		n += get_tree().get_nodes_in_group(group).size()

	return n


func _put_player(at: Vector3) -> void:
	for a in ["aim", "blink", "spell_1", "spell_2", "spell_3", "kick", "throw"]:
		Input.action_release(a)
	player.velocity = Vector3.ZERO
	player.global_position = at
	player.rotation.y = 0.0
	player.get_node("Neck").rotation.x = 0.0


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
