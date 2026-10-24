extends Node3D
## Blink's effects, round two (docs/superpowers/specs/2026-10-23-blink-effects-design.md): the
## landing mark and the reaching hand, the rush (the view widening and
## smearing, flakes whipping past), the crack where you stood, the dust where
## you land; none with effects off, and all of it gone after.

const PLAYER := preload("res://Player.tscn")
const GUARD_SCRIPT := preload("res://scripts/AISystem/Guard.gd")
const Props := preload("res://scripts/Interaction/Props.gd")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")
const Fx := preload("res://scripts/Visual/Fx.gd")
const TemperamentScript := preload("res://scripts/AISystem/Temperament.gd")
const ViewArmsScript := preload("res://scripts/Interaction/ViewArms.gd")
const MagicFx := preload("res://scripts/Visual/MagicFx.gd")
const MagicView := preload("res://scripts/Visual/MagicView.gd")

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
	var caster: Node = player.caster
	_put_player(Vector3(-40, 1.05, 20))
	await _frames(40)
	await _until(func(): return player.revolver.is_up(), 60)

	# K1 K2 holding Q: a ring of eight glass flakes where you will land,
	# following the aim; the left hand reaches toward it
	player.power.power = player.power.MAX
	Input.action_press("blink")
	await _frames(20)
	var mark: Node3D = caster.blink_mark()
	var flakes := mark.get_children().filter(func(c): return c is MeshInstance3D and c.name != "MarkRing").size() if mark != null else 0
	var ring: Node3D = mark.get_node_or_null("MarkRing") if mark != null else null
	var ring_down: bool = ring != null and absf(ring.global_position.y) < 0.1
	var on_spot: bool = mark != null and mark.global_position.distance_to(caster._aim_at) < 0.3
	var reaching: bool = player.hand.left_mode() == &"cast" and not player.hand._circle.visible
	player.rotation.y += 0.4
	await _frames(3)
	var followed: bool = mark != null and is_instance_valid(mark) and mark.global_position.distance_to(caster._aim_at) < 0.3
	_check("K1 holding Q, eight glass flakes and a ring on the ground mark where you will land, and follow the aim",
		flakes == 8 and ring_down and on_spot and followed, "flakes %d ring on the floor %s on the spot %s followed %s" % [flakes, ring_down, on_spot, followed])
	_check("K2 holding Q with the gun out, the left hand reaches out (no circle)", reaching, "left %s" % player.hand.left_mode())

	# R1 R2 R3 letting go: the view widens and comes back, the picture smears
	# in to the middle and clears, glass flakes whip past from ahead
	var base_fov: float = player.camera.fov
	var from: Vector3 = player.global_position
	var forward: Vector3 = -player.global_basis.z
	Input.action_release("blink")
	var widest := 0.0
	var smear := 0.0
	var streaks := 0
	var passing := true
	var seen: Dictionary = {}

	for f in 6:
		await get_tree().physics_frame
		widest = maxf(widest, player.camera.fov - base_fov)
		smear = maxf(smear, MagicView.of(get_tree()).rush_amount())
		var now := get_tree().get_nodes_in_group(&"blink_streak")
		streaks = maxi(streaks, now.size())

		for s in now:
			var id := (s as Node).get_instance_id()
			if seen.has(id):
				passing = passing and ((s as Node3D).global_position - seen[id]).dot(forward) < 0.0
			seen[id] = (s as Node3D).global_position

	var crack_at_go: Array = get_tree().get_nodes_in_group(&"blink_crack").map(func(f): return (f as Node3D).global_position)
	await _frames(24)
	var fov_back: float = absf(player.camera.fov - base_fov)
	var smear_after: float = MagicView.of(get_tree()).rush_amount()
	_check("R1 blinking, the view widens for an instant and comes back", widest >= 5.0 and fov_back < 1.0,
		"widened %.1f, then off by %.1f" % [widest, fov_back])
	_check("R2 the picture smears in to the middle and clears", smear > 0.5 and smear_after == 0.0, "smear %.2f then %.2f" % [smear, smear_after])
	_check("R3 glass flakes whip past you from ahead", streaks >= 8 and passing, "flakes %d passing %s" % [streaks, passing])
	await _frames(1)
	var gone_mark: bool = caster.blink_mark() == null

	# C1 C2 the crack where you stood: a pane of glass facets, upright, at the
	# place you left; it hangs, then falls apart, and is gone
	var facets := crack_at_go
	var middle := Vector3.ZERO
	var low := INF
	var high := -INF
	var start_y := {}

	for p in facets:
		middle += p
		low = minf(low, p.y)
		high = maxf(high, p.y)

	middle /= maxf(facets.size(), 1.0)
	var near_from := Vector2(middle.x - from.x, middle.z - from.z).length() < 1.0
	_check("C1 a pane of cracked glass hangs where you stood, upright, a man's height",
		facets.size() >= 12 and near_from and high - low >= 1.0 and gone_mark,
		"facets %d, %.2f m from where you stood, %.2f m tall, mark gone %s" % [facets.size(), Vector2(middle.x - from.x, middle.z - from.z).length(), high - low, gone_mark])

	# A fresh one to time: blink back and watch it from the start.
	_put_player(Vector3(-40, 1.05, 20))
	await _frames(30)
	player.power.power = player.power.MAX
	await _tap("blink")
	await _until(func(): return not get_tree().get_nodes_in_group(&"blink_crack").is_empty(), 10)
	var pieces := get_tree().get_nodes_in_group(&"blink_crack")
	for p in pieces:
		start_y[(p as Node).get_instance_id()] = (p as Node3D).global_position.y
	await _frames(9)
	var hung_drop := _mean_drop(start_y)
	await _frames(24)
	var fell_drop := _mean_drop(start_y)
	await _frames(15)
	var left_after := get_tree().get_nodes_in_group(&"blink_crack").size()
	_check("C2 the crack hangs a moment, then falls apart and is gone by 0.8 s",
		hung_drop < 0.03 and fell_drop > 0.1 and left_after == 0, "drop at 0.15 s %.3f, at 0.55 s %.2f, left at 0.8 s %d" % [hung_drop, fell_drop, left_after])

	# A1 the dust where you land: a ring kicked out across the floor
	var dust := get_tree().get_nodes_in_group(&"blink_dust")
	_put_player(Vector3(-40, 1.05, 20))
	await _frames(30)
	player.power.power = player.power.MAX
	await _tap("blink")
	await _frames(2)
	dust = get_tree().get_nodes_in_group(&"blink_dust")
	var on_floor: bool = not dust.is_empty() and absf((dust[0] as Node3D).global_position.y) < 0.1 \
		and Vector2((dust[0] as Node3D).global_position.x - player.global_position.x, (dust[0] as Node3D).global_position.z - player.global_position.z).length() < 0.5
	_check("A1 you land in a ring of dust kicked across the floor", on_floor, "rings %d" % dust.size())
	await _frames(60)

	# L1 three blinks in quick succession: never more than two cracks
	var most_panes := 0
	for i in 3:
		_put_player(Vector3(-40, 1.05, 20))
		await get_tree().physics_frame
		player.power.power = player.power.MAX
		await _tap("blink")
		for k in 4:
			await get_tree().physics_frame
			most_panes = maxi(most_panes, get_tree().get_nodes_in_group(&"blink_crack_pane").size())
	_check("L1 no more than two cracks hang at once", most_panes >= 1 and most_panes <= 2, "most %d" % most_panes)
	await _frames(90)

	# E1 with effects off: the blink still goes, and leaves none
	_put_player(Vector3(-40, 1.05, 20))
	await _frames(20)
	Fx.enabled = false
	player.power.power = player.power.MAX
	Input.action_press("blink")
	var any := 0
	for f in 40:
		if f == 20:
			Input.action_release("blink")
		any = maxi(any, _count_all())
		await get_tree().physics_frame
	Input.action_release("blink")
	var moved: bool = player.global_position.distance_to(Vector3(-40, 1.05, 20)) > 2.0
	Fx.enabled = true
	_check("E1 with effects off, a blink goes and leaves no mark, crack, flakes or dust", moved and any == 0, "moved %s effects %d" % [moved, any])

	# E2 all gone after
	await _frames(60)
	_check("E2 nothing of Blink's effects is left over", MagicFx.live_count() == 0 and _count_all() == 0 and MagicView.of(get_tree()).rush_amount() == 0.0,
		"magic %d, blink effects %d" % [MagicFx.live_count(), _count_all()])


func _mean_drop(start_y: Dictionary) -> float:
	var sum := 0.0
	var n := 0

	for id in start_y:
		var node := instance_from_id(id) as Node3D

		if node != null and is_instance_valid(node):
			sum += float(start_y[id]) - node.global_position.y
			n += 1

	return sum / n if n > 0 else 999.0


func _count_all() -> int:
	var n := 0

	for group in [&"blink_mark", &"blink_streak", &"blink_crack", &"blink_crack_pane", &"blink_dust"]:
		n += get_tree().get_nodes_in_group(group).size()

	return n


func _put_player(at: Vector3) -> void:
	for a in ["aim", "blink", "spell_1", "spell_2", "spell_3"]:
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
