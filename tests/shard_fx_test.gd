extends Node3D
## The Shard's effects, round two (docs/superpowers/specs/2026-10-23-shard-effects-design.md):
## the wind-up in the hand, the release, the flight and its trail, the
## impact's spikes and ring, the shard stuck in a man; none with effects
## off, and all of it gone after.

const PLAYER := preload("res://Player.tscn")
const GUARD_SCRIPT := preload("res://scripts/AISystem/Guard.gd")
const GUARD := preload("res://Guard.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")
const Fx := preload("res://scripts/Visual/Fx.gd")
const TemperamentScript := preload("res://scripts/AISystem/Temperament.gd")
const ViewArmsScript := preload("res://scripts/Interaction/ViewArms.gd")
const HandSlotScript := preload("res://scripts/Interaction/HandSlot.gd")
const MagicFx := preload("res://scripts/Visual/MagicFx.gd")
const ShardScript := preload("res://scripts/Magic/Shard.gd")

var player: CharacterBody3D
var baker: NavigationRegion3D
var results: Array[String] = []


func _ready() -> void:
	TemperamentScript.rolling = false
	GUARD_SCRIPT.bleeding_on = false
	ViewArmsScript.new_arms = true
	Props.block(self, Vector3(0, -0.5, 0), Vector3(160, 1, 90))              # floor
	Props.block(self, Vector3(-60, 1.5, -44), Vector3(6, 3, 0.4))           # a stone wall, its face at z = -43.8

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
	_put_player(Vector3(-60, 1.05, -24))
	await _frames(40)

	# W1 W2 W3 the wind-up: a spearhead grows in the circle, the splinters
	# draw in and turn to point at its middle, the hand trembles
	player.power.power = player.power.MAX
	Input.action_press("spell_1")
	var early_size := -1.0
	var late_size := -1.0
	var early_across := -1.0
	var late_across := -1.0
	var early_point := 0.0
	var late_point := 0.0
	var head_shown := false
	var head_on_view := false
	var shakes: Array[Vector3] = []

	for f in 23:
		await get_tree().physics_frame
		var head: MeshInstance3D = hand.spearhead()

		if head != null and head.is_visible_in_tree():
			head_shown = true
			head_on_view = head.layers == HandSlotScript.VIEWMODEL_LAYER

		if f == 11:
			early_size = head.scale.length() if head != null else -1.0
			early_across = hand.circle_across()
			early_point = _pointing_in(hand)
		if f == 22:
			late_size = head.scale.length() if head != null else -1.0
			late_across = hand.circle_across()
			late_point = _pointing_in(hand)
		if f >= 16:
			shakes.append(hand.tremble())

	var shook := 0.0

	for s in shakes:
		shook = maxf(shook, s.distance_to(shakes[0]))

	_check("W1 a spearhead grows in the circle as the cast builds, drawn in your view",
		head_shown and head_on_view and late_size > early_size * 1.6, "size %.3f -> %.3f, view %s" % [early_size, late_size, head_on_view])
	_check("W2 the splinters draw in toward 2.5 cm across and turn to point at the middle",
		late_across < early_across and late_across <= 0.035 and early_point < 0.2 and late_point > 0.8,
		"across %.3f -> %.3f, pointing in %.2f -> %.2f" % [early_across, late_across, early_point, late_point])
	_check("W3 the hand trembles near the end of the cast", shook > 0.0004 and shook < 0.004, "moved %.4f m" % shook)

	# R1 R2 R3 the release: the spearhead leaves the hand, a burst of flakes
	# and a refraction ring in your view, a brief cold light, gone quickly
	var released := 0
	var on_view := true
	var lit := false
	var head_gone := false
	var kicked := 0.0

	for f in 6:
		await get_tree().physics_frame
		kicked = maxf(kicked, absf(float(player.juice._pitch_velocity)))
		var burst := get_tree().get_nodes_in_group(&"shard_release")
		released = maxi(released, burst.size())

		for piece in burst:
			if piece is VisualInstance3D:
				on_view = on_view and (piece as VisualInstance3D).layers == HandSlotScript.VIEWMODEL_LAYER

		lit = lit or not get_tree().get_nodes_in_group(&"shard_light").is_empty()

		if not get_tree().get_nodes_in_group(&"shards").is_empty():
			var head: MeshInstance3D = hand.spearhead()
			head_gone = head == null or not head.is_visible_in_tree()

	Input.action_release("spell_1")
	_check("R1 on release, the spearhead leaves the hand as the shard flies", head_gone, "gone %s" % head_gone)
	_check("R2 a burst of flakes and a ring in your view at the release", released >= 7 and on_view, "pieces %d, view %s" % [released, on_view])
	_check("R3 a brief cold light at the release", lit, "lit %s" % lit)
	_check("R4 a small kick to the view at the release", kicked > 0.3 and kicked < 2.0, "pitch speed %.2f" % kicked)

	# F1 F2 the flight: a spearhead some 32 cm long, and a trail from the hand
	var shard: Node = get_tree().get_nodes_in_group(&"shards")[0] if not get_tree().get_nodes_in_group(&"shards").is_empty() else null
	var length := -1.0
	var trail_ok := false
	var trail_detail := "no shard"

	if shard != null:
		var visual: MeshInstance3D = shard.get_node("MeshInstance3D")
		length = visual.mesh.get_aabb().size[visual.mesh.get_aabb().get_longest_axis_index()]
		await get_tree().physics_frame
		await get_tree().physics_frame
		var trails := get_tree().get_nodes_in_group(&"shard_trail")

		if not trails.is_empty() and is_instance_valid(shard):
			var span: Array = trails[0].span()
			var tail: Vector3 = span[0]
			var head: Vector3 = span[1]
			trail_ok = head.distance_to(shard.global_position) < 1.5 and tail.distance_to(player.global_position) < 4.0 and head.distance_to(tail) > 2.0
			trail_detail = "head %.2f from shard, tail %.2f from you, %.1f m long" % [head.distance_to(shard.global_position), tail.distance_to(player.global_position), head.distance_to(tail)]

	_check("F1 the flying shard is a spearhead about 32 cm long", length >= 0.28 and length <= 0.36, "%.3f m" % length)
	_check("F2 a trail runs from your hand to the shard as it flies", trail_ok, trail_detail)

	# I1 I2 I3 I4 on stone: a star of spikes out of the wall, a ring of glass
	# dust, the trail fading after; the spikes stay ~3 s, then crumble
	await _until(func(): return not get_tree().get_nodes_in_group(&"shard_spike").is_empty(), 60)
	await _frames(4)
	var spikes := get_tree().get_nodes_in_group(&"shard_spike")
	var out_of_wall := true
	var lengths := []

	for spike in spikes:
		var s := spike as Node3D
		var along: Vector3 = s.global_basis.y
		out_of_wall = out_of_wall and along.normalized().dot(Vector3.BACK) > 0.2 and s.global_position.z > -43.85
		lengths.append(snappedf(along.length() * float(s.get_meta(&"length", 0.0)), 0.01))

	var lengths_ok: bool = not lengths.is_empty() and lengths.min() >= 0.2 and lengths.max() <= 0.6
	var ring := get_tree().get_nodes_in_group(&"shard_ring")
	var trail_left := get_tree().get_nodes_in_group(&"shard_trail").size()
	_check("I1 a star of 6-8 glass spikes bursts out of the wall, 20-60 cm long",
		spikes.size() >= 6 and spikes.size() <= 8 and out_of_wall and lengths_ok, "spikes %d, out %s, lengths %s" % [spikes.size(), out_of_wall, lengths])
	_check("I2 a ring of glass dust spreads on the wall",
		not ring.is_empty() and absf((ring[0] as Node3D).global_position.z + 43.8) < 0.1, "rings %d" % ring.size())
	await _frames(15)
	_check("I3 the trail fades out soon after the hit", trail_left >= 0 and get_tree().get_nodes_in_group(&"shard_trail").is_empty(),
		"trails %d" % get_tree().get_nodes_in_group(&"shard_trail").size())
	await _frames(int(2.3 * 60.0))
	var still_there := get_tree().get_nodes_in_group(&"shard_spike").size()
	var crumbled := 0

	for f in 60:
		crumbled = maxi(crumbled, get_tree().get_nodes_in_group(&"shard_crumble").size())
		await get_tree().physics_frame

	await _frames(60)
	_check("I4 the spikes stay about 3 s, then crumble into flakes and are gone",
		still_there == spikes.size() and crumbled > 0 and get_tree().get_nodes_in_group(&"shard_spike").is_empty() and get_tree().get_nodes_in_group(&"shard_crumble").is_empty(),
		"at 2.5 s %d, flakes %d, after %d" % [still_there, crumbled, get_tree().get_nodes_in_group(&"shard_spike").size()])

	# M1 into a man: it sticks in where it struck and goes where he goes
	var man := _new_guard(Vector3(-60, 0, -32), PI)
	await _frames(20)
	man.set_physics_process(false)
	_aim(man.global_position + Vector3.UP * 1.2)
	await _frames(5)
	player.power.power = player.power.MAX
	Input.action_press("spell_1")
	await _until(func(): return not get_tree().get_nodes_in_group(&"shard_stuck").is_empty(), 60)
	Input.action_release("spell_1")
	var stuck := get_tree().get_nodes_in_group(&"shard_stuck")
	var in_him := not stuck.is_empty() and man.is_ancestor_of(stuck[0])
	var follows := false

	if in_him:
		var before: Vector3 = (stuck[0] as Node3D).global_position
		man.global_position += Vector3(1.0, 0, 0)
		await _frames(2)
		follows = _near((stuck[0] as Node3D).global_position.x - before.x, 1.0, 0.05)

	_check("M1 a shard into a man sticks in him and goes where he goes", in_him and follows,
		"stuck %d, in him %s, follows %s" % [stuck.size(), in_him, follows])
	await _frames(int(6.2 * 60.0))
	_check("M2 the stuck shard is gone after about 6 s", get_tree().get_nodes_in_group(&"shard_stuck").is_empty(),
		"stuck %d" % get_tree().get_nodes_in_group(&"shard_stuck").size())
	man.queue_free()
	await _frames(30)

	# E1 with effects off: the shard still flies and strikes, and leaves none
	_put_player(Vector3(-60, 1.05, -24))
	await _frames(20)
	Fx.enabled = false
	player.power.power = player.power.MAX
	Input.action_press("spell_1")
	var any := 0

	for f in 60:
		any = maxi(any, _count_all())
		await get_tree().physics_frame

	Input.action_release("spell_1")
	Fx.enabled = true
	_check("E1 with effects off, a shard leaves no spikes, ring, trail, burst or light", any == 0, "effects %d" % any)

	# E2 all gone after
	await _frames(30)
	_check("E2 nothing of the shard's effects is left over", MagicFx.live_count() == 0 and _count_all() == 0,
		"magic %d, shard effects %d" % [MagicFx.live_count(), _count_all()])


## How much the circle's splinters point at its middle: 1 all in, -1 all out.
func _pointing_in(hand: Node) -> float:
	var pieces: Array = hand._circle_pieces
	var sum := 0.0

	for piece in pieces:
		var p := piece as Node3D
		sum += p.transform.basis.y.normalized().dot(-p.transform.origin.normalized())

	return sum / maxf(pieces.size(), 1.0)


func _count_all() -> int:
	var n := 0

	for group in [&"shard_spike", &"shard_ring", &"shard_trail", &"shard_release", &"shard_light", &"shard_crumble", &"shard_stuck"]:
		n += get_tree().get_nodes_in_group(group).size()

	return n


func _new_guard(at: Vector3, yaw: float) -> CharacterBody3D:
	var g: CharacterBody3D = GUARD.instantiate()
	g.debug_ai = false
	g.position = at
	g.rotation.y = yaw
	add_child(g)
	return g


func _put_player(at: Vector3) -> void:
	for a in ["aim", "blink", "spell_1", "spell_2", "spell_3"]:
		Input.action_release(a)
	player.velocity = Vector3.ZERO
	player.global_position = at
	player.rotation.y = 0.0
	player.get_node("Neck").rotation.x = 0.0


func _aim(target: Vector3) -> void:
	var eye: Vector3 = player.get_node("Neck").global_position
	var d := target - eye
	player.rotation.y = atan2(-d.x, -d.z)
	player.get_node("Neck").rotation.x = atan2(d.y, Vector2(d.x, d.z).length())


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _until(cond: Callable, max_frames: int) -> void:
	for i in max_frames:
		if cond.call():
			return
		await get_tree().physics_frame


func _near(a: float, b: float, tol: float) -> bool:
	return absf(a - b) <= tol


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
