extends Node3D
## The Ward's effects, round two (docs/superpowers/specs/2026-10-23-ward-effects-design.md): the
## smoke and embers in the palm, the pour from the hand round the floor into
## the ring, the embers in the wall, a stopped shot's puncture, ripple and
## what falls, the drain at the end; none with effects off, all gone after.

const PLAYER := preload("res://Player.tscn")
const GUARD_SCRIPT := preload("res://scripts/AISystem/Guard.gd")
const Props := preload("res://scripts/Interaction/Props.gd")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")
const Fx := preload("res://scripts/Visual/Fx.gd")
const TemperamentScript := preload("res://scripts/AISystem/Temperament.gd")
const ViewArmsScript := preload("res://scripts/Interaction/ViewArms.gd")
const MagicFx := preload("res://scripts/Visual/MagicFx.gd")
const WardScript := preload("res://scripts/Magic/Ward.gd")
const ArrowScript := preload("res://scripts/Combat/Arrow.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")

const GROUPS := [&"ward_pour", &"ward_skirt", &"ward_ember", &"ward_puncture", &"ward_drop", &"ward_drain",
	&"ward_shell", &"ward_sigil", &"ward_streak", &"ward_ash", &"ward_glyph"]

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
	_put_player(Vector3(-30, 1.05, 40))
	await _frames(40)
	await _until(func(): return player.revolver.is_up(), 60)

	# H1 the wind-up: ward smoke curling up from the palm, growing; embers of
	# copal in it, glowing brighter
	player.power.power = player.power.MAX
	Input.action_press("spell_2")
	var early_tall := -1.0
	var late_tall := -1.0
	var early_glow := -1.0
	var late_glow := -1.0
	var on_view := false
	var hand_glyphs := 0

	for f in 23:
		await get_tree().physics_frame
		var smoke: Node3D = hand.palm_smoke()

		if f == 11:
			early_tall = smoke.scale.y if smoke != null and smoke.is_visible_in_tree() else -1.0
			early_glow = hand.palm_glow()
		if f == 22:
			late_tall = smoke.scale.y if smoke != null and smoke.is_visible_in_tree() else -1.0
			late_glow = hand.palm_glow()
			on_view = smoke != null and smoke.get_children().all(func(c): return not (c is VisualInstance3D) or (c as VisualInstance3D).layers == 1 << 18)
			hand_glyphs = get_tree().get_nodes_in_group(&"ward_hand_glyph").filter(func(g): return (g as Node3D).is_visible_in_tree() and (g as VisualInstance3D).layers == 1 << 18).size()

	_check("H1 casting the Ward, smoke curls up from the palm, growing, drawn in your view",
		early_tall > 0.0 and late_tall > early_tall * 1.5 and on_view, "height %.2f -> %.2f, view %s" % [early_tall, late_tall, on_view])
	_check("H2 embers of copal glow brighter in the palm as it builds", early_glow > 0.0 and late_glow > early_glow * 1.5,
		"glow %.2f -> %.2f" % [early_glow, late_glow])
	_check("H3 a ring of the invented script turns round the circle in your hand", hand_glyphs >= 8, "glyphs %d" % hand_glyphs)

	# P1 P2 P3 the pour: a stream from the hand to the floor; the plumes rise
	# front first; a skirt of smoke at the foot of the wall
	await _until(func(): return not WardScript.active.is_empty(), 20)
	Input.action_release("spell_2")
	var ward: Node3D = WardScript.active[0].get_ref() if not WardScript.active.is_empty() else null
	var poured := false
	var pour_ok := false

	for f in 3:
		await get_tree().physics_frame
		var pour := get_tree().get_nodes_in_group(&"ward_pour")
		if not pour.is_empty():
			poured = true
			var span: Array = pour[0].get_meta(&"span", [Vector3.ZERO, Vector3.ZERO])
			pour_ok = (span[0] as Vector3).y > 0.8 and absf((span[1] as Vector3).y) < 0.15

	await _frames(4)
	var fill_early: float = ward.shell_fill() if ward != null else -1.0
	var written_early: Array = ward.glyph_presence() if ward != null else []
	var front_eaten := -1.0
	var back_eaten := -1.0

	if ward != null:
		var front: int = ward.front_plume()
		var back: int = (front + WardScript.PLUMES / 2) % WardScript.PLUMES
		front_eaten = (ward._plumes[front].material_override as ShaderMaterial).get_shader_parameter(&"erosion")
		back_eaten = (ward._plumes[back].material_override as ShaderMaterial).get_shader_parameter(&"erosion")

	_check("P1 smoke pours from your hand down to the floor", poured and pour_ok, "poured %s, hand to floor %s" % [poured, pour_ok])
	_check("P2 the wall rises front first: the front plume up while the back one has not come",
		front_eaten >= 0.0 and front_eaten < 0.9 and back_eaten > 0.97, "front eaten %.2f back %.2f" % [front_eaten, back_eaten])
	await _frames(40)
	var risen := true

	if ward != null:
		for p in ward._plumes:
			risen = risen and absf(float((p.material_override as ShaderMaterial).get_shader_parameter(&"erosion")) - WardScript.STANDING) < 0.06

	var skirt := get_tree().get_nodes_in_group(&"ward_skirt")
	_check("P3 by 0.75 s the whole wall stands on a skirt of smoke at its foot", risen and not skirt.is_empty() and ward != null and ward.is_ancestor_of(skirt[0]),
		"risen %s skirts %d" % [risen, skirt.size()])

	var tallest_before: float = ward._plumes[0].scale.y

	# D1 D2 a shell of smoke the size of what it stops, filling up from the
	# floor as the pour runs round
	var shells := get_tree().get_nodes_in_group(&"ward_shell")
	var shell_size: float = (shells[0] as MeshInstance3D).mesh.get_aabb().size.x * 0.5 if not shells.is_empty() else -1.0
	_check("D1 a shell of smoke round you exactly the size of what the ward stops", shells.size() == 1 and ward.is_ancestor_of(shells[0]) and absf(shell_size - WardScript.RADIUS) < 0.03,
		"shells %d radius %.2f" % [shells.size(), shell_size])
	_check("D2 the shell fills up from the floor with the pour", fill_early >= 0.0 and fill_early < 0.5 and absf(ward.shell_fill() - 1.0) < 0.01,
		"fill %.2f then %.2f" % [fill_early, ward.shell_fill()])

	# D3 a burning line of copal on the floor at the wall's foot
	var sigil := get_tree().get_nodes_in_group(&"ward_sigil")
	var sigil_ok: bool = not sigil.is_empty()
	for arc in sigil:
		sigil_ok = sigil_ok and absf((arc as Node3D).global_position.y) < 0.06
	_check("D3 a burning line of copal runs round the floor at the wall's foot", sigil_ok, "arcs %d" % sigil.size())

	# D4 bands of brighter smoke circling the shell
	var streaks := get_tree().get_nodes_in_group(&"ward_streak")
	var turned_by := -1.0
	if not streaks.is_empty():
		var s0 := (streaks[0] as Node3D).global_position - ward.global_position
		await _frames(10)
		var s1 := (streaks[0] as Node3D).global_position - ward.global_position
		turned_by = absf(angle_difference(atan2(s0.z, s0.x), atan2(s1.z, s1.x)))
	_check("D4 three bands of brighter smoke circle the shell", streaks.size() == 3 and turned_by > 0.15, "bands %d turned %.2f rad in 10 frames" % [streaks.size(), turned_by])

	# G1 G2 a circle written in the invented script on the floor inside the
	# copal ring, written in round from the front
	var glyphs := get_tree().get_nodes_in_group(&"ward_glyph")
	var placed := not glyphs.is_empty()
	var scripted := not glyphs.is_empty()
	for g in glyphs:
		var p := (g as Node3D).global_position - ward.global_position
		var round_r := Vector2(p.x, p.z).length()
		placed = placed and absf((g as Node3D).global_position.y) < 0.06 and round_r > 0.6 and round_r < 0.9
		var code := String(g.get_meta(&"char", " ")).unicode_at(0)
		scripted = scripted and code >= 0xE000 and code < 0xE000 + 40
	_check("G1 a circle of the invented script lies on the floor inside the copal ring (most of its 26 places)", glyphs.size() >= 18 and glyphs.size() < WardScript.GLYPH_SLOTS and placed and scripted,
		"glyphs %d placed %s scripted %s" % [glyphs.size(), placed, scripted])
	var front_g: int = ward.glyph_nearest(ward.front_angle())
	var back_g: int = ward.glyph_nearest(ward.front_angle() + PI)
	_check("G2 it is written in round from the front with the pour", written_early.size() > maxi(front_g, back_g) and float(written_early[front_g]) > 0.3 and float(written_early[back_g]) < 0.05 \
		and ward.glyph_presence().all(func(v): return float(v) > 0.95), "front %.2f back %.2f early" % [float(written_early[front_g]) if written_early.size() > front_g else -1.0, float(written_early[back_g]) if written_early.size() > back_g else -1.0])

	# I1 from inside, the shell and the bands are faint
	var inside_v: Variant = ward._shell.material_override.get_shader_parameter(&"inside")
	var inside_at: float = float(inside_v) if inside_v != null else -1.0
	_check("I1 seen from inside, the shell is faint and the bands are hidden", inside_at > 0.99 and streaks.all(func(b): return not (b as Node3D).is_visible_in_tree()),
		"inside %.2f" % inside_at)

	# D5 inside it, the world's sounds go dull
	_check("D5 inside the ward the world is muffled (about 2.5 kHz)", Sfx.ward_muffle > 0.95 and absf(Sfx.world_cutoff_for(1.0, 0.0, 1.0) - Sfx.WARD_CUTOFF) < 1.0 and Sfx.WARD_CUTOFF <= 3000.0,
		"muffle %.2f, cutoff %.0f Hz" % [Sfx.ward_muffle, Sfx.world_cutoff_for(1.0, 0.0, Sfx.ward_muffle)])

	# S1 embers of copal drift up inside the smoke
	var embers := get_tree().get_nodes_in_group(&"ward_ember")
	var inside := not embers.is_empty()
	var before := {}

	for e in embers:
		var at := (e as Node3D).global_position
		inside = inside and Vector2(at.x - ward.global_position.x, at.z - ward.global_position.z).length() <= WardScript.RADIUS + 0.15
		before[(e as Node).get_instance_id()] = at.y

	await _frames(3)
	var rising := 0

	for e in embers:
		if is_instance_valid(e) and (e as Node3D).global_position.y > float(before[(e as Node).get_instance_id()]):
			rising += 1

	_check("S1 a dozen embers of copal drift up inside the smoke", embers.size() >= 10 and inside and rising >= embers.size() * 0.7,
		"embers %d inside %s rising %d" % [embers.size(), inside, rising])

	# B1 B2 B3 a ball stopped: a puncture of ward-white where it struck, a
	# ripple out through the wall, the ball flattened and dropped to the floor
	var at := ward.global_position + Vector3(0.0, 0.2, -WardScript.RADIUS)
	WardScript.turned_aside(player, at, Vector3.BACK, ward, &"ball")
	await get_tree().physics_frame
	var punctures := get_tree().get_nodes_in_group(&"ward_puncture")
	var punctured: bool = not punctures.is_empty() and (punctures[0] as Node3D).global_position.distance_to(at) < 0.15
	var hits: Array = ward.shell_hits()
	var hit_where: bool = hits.size() == 1 and (hits[0][0] as Vector3).angle_to(ward.to_local(at).normalized()) < 0.1
	var flare_at_hit: float = ward.shell_flare()
	var glyph_glow: float = ward.glyph_glow()
	await _frames(8)
	var spread_to: float = ward.shell_hits()[0][1] if ward.shell_hits().size() == 1 else -1.0
	var puncture_left := get_tree().get_nodes_in_group(&"ward_puncture").size()
	_check("B1 a stopped ball flashes a puncture where it struck, gone in a moment", punctured and puncture_left == 0,
		"punctured %s, left after 0.15 s %d" % [punctured, puncture_left])
	_check("B2 the shell flares where it struck and a ripple runs out over it", hit_where and flare_at_hit > 0.5 and spread_to > 0.1,
		"hit there %s, flare %.2f, ripple %.2f s on" % [hit_where, flare_at_hit, spread_to])
	await _frames(32)
	_check("B5 the ripple is gone from the shell in 0.6 s", ward.shell_hits().is_empty(), "hits %d" % ward.shell_hits().size())
	_check("G3 the written circle brightens when a shot is stopped", glyph_glow > ward.glyph_glow() * 1.3, "glow %.2f then %.2f" % [glyph_glow, ward.glyph_glow()])
	var drops := get_tree().get_nodes_in_group(&"ward_drop")
	var ball_down: bool = drops.size() == 1 and (drops[0] as Node3D).global_position.y < 0.1 and String(drops[0].get_meta(&"kind", "")) == "ball"
	_check("B3 the ball falls flattened to the floor", ball_down, "drops %d" % drops.size())

	# B4 an arrow stopped falls dead to the floor
	var archer := Node3D.new()
	add_child(archer)
	archer.global_position = player.global_position + Vector3(1.5, -1.05, -8.0)
	var arrow: StaticBody3D = ArrowScript.new()
	add_child(arrow)
	var from := archer.global_position + Vector3.UP * 1.5
	var chest := player.global_position + Vector3.UP * 0.4
	arrow.launch(from, (chest - from).normalized() * 30.0, 10.0, archer, 2.5)
	arrow.gravity = 0.0
	await _until(func(): return get_tree().get_nodes_in_group(&"ward_drop").any(func(d): return String(d.get_meta(&"kind", "")) == "arrow"), 40)
	var arrow_drop: Array = get_tree().get_nodes_in_group(&"ward_drop").filter(func(d): return String(d.get_meta(&"kind", "")) == "arrow")
	await _until(func(): return not arrow_drop.is_empty() and is_instance_valid(arrow_drop[0]) and (arrow_drop[0] as Node3D).global_position.y < 0.2, 60)
	var arrow_down: bool = not arrow_drop.is_empty() and is_instance_valid(arrow_drop[0]) and (arrow_drop[0] as Node3D).global_position.y < 0.2
	_check("B4 an arrow the ward stops falls dead to the floor", arrow_down, "dropped %d" % arrow_drop.size())
	archer.queue_free()

	# E1 E2 the end: the plumes sink, the smoke drains off across the floor in
	# a widening ring left where you stood, and it all goes
	var stood: Vector3 = player.global_position
	var held := [ward]
	await _until(func(): return is_instance_valid(held[0]) and held[0]._life >= WardScript.LIFE - 0.2, 300)
	var sinking: float = ward._plumes[0].scale.y if is_instance_valid(ward) else -1.0
	await _until(func(): return not is_instance_valid(held[0]), 30)
	await _frames(2)
	var drains := get_tree().get_nodes_in_group(&"ward_drain")
	var drain_ok: bool = not drains.is_empty() and absf((drains[0] as Node3D).global_position.y) < 0.15 \
		and Vector2((drains[0] as Node3D).global_position.x - stood.x, (drains[0] as Node3D).global_position.z - stood.z).length() < 0.5
	var drain_from := (drains[0] as Node3D).scale.x if not drains.is_empty() else -1.0
	await _frames(20)
	var drain_to := (drains[0] as Node3D).scale.x if not drains.is_empty() and is_instance_valid(drains[0]) else -1.0
	_check("E1 at the end the plumes sink toward the floor", sinking >= 0.0 and sinking < tallest_before * 0.8, "height %.2f -> %.2f" % [tallest_before, sinking])
	_check("E2 the smoke drains off across the floor in a widening ring where you stood", drain_ok and drain_to > drain_from,
		"drains %d on the floor %s, %.2f -> %.2f" % [drains.size(), drain_ok, drain_from, drain_to])
	await _frames(90)
	var left := _count_all() - get_tree().get_nodes_in_group(&"ward_drop").size()
	var ash := get_tree().get_nodes_in_group(&"ward_ash")
	var ash_down: bool = not ash.is_empty() and absf((ash[0] as Node3D).global_position.y) < 0.06
	left -= ash.size()
	_check("E4 the copal ring is left as dim ash on the floor, and the muffle eases off", ash_down and Sfx.ward_muffle < 0.01,
		"ash %d on the floor %s, muffle %.2f" % [ash.size(), ash_down, Sfx.ward_muffle])
	_check("E3 nothing of the ward is left a second and a half after (what it stopped and the ash still lie there)", left == 0 and get_tree().get_nodes_in_group(&"ward_plume").is_empty(),
		"effects %d plumes %d" % [left, get_tree().get_nodes_in_group(&"ward_plume").size()])
	await _frames(int(4.5 * 60.0))

	# X1 with effects off: the ward stands (its plumes), and nothing else
	Fx.enabled = false
	player.power.power = player.power.MAX
	Input.action_press("spell_2")
	var any := 0
	var stood_up := false

	for f in 80:
		any = maxi(any, _count_all())
		stood_up = stood_up or not get_tree().get_nodes_in_group(&"ward_plume").is_empty()
		await get_tree().physics_frame

	Input.action_release("spell_2")
	await _until(func(): return WardScript.active.is_empty(), 300)

	for f in 60:
		any = maxi(any, _count_all())
		await get_tree().physics_frame

	Fx.enabled = true
	_check("X1 with effects off, the ward stands and leaves none of its decorations", stood_up and any == 0, "stood %s effects %d" % [stood_up, any])
	_check("X2 nothing left over", MagicFx.live_count() == 0 and _count_all() == 0, "magic %d ward effects %d" % [MagicFx.live_count(), _count_all()])


func _count_all() -> int:
	var n := 0

	for group in GROUPS:
		n += get_tree().get_nodes_in_group(group).size()

	return n


func _put_player(at: Vector3) -> void:
	for a in ["aim", "blink", "spell_1", "spell_2", "spell_3"]:
		Input.action_release(a)
	player.velocity = Vector3.ZERO
	player.global_position = at
	player.rotation.y = 0.0
	player.get_node("Neck").rotation.x = 0.0


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
