extends Node3D
## Lights and fire: the materials by slot, the flames, their flicker, the
## coronas, embers and smoke, lit and out, the shadow budget, every fixture
## the props pipeline builds, their sounds, and the levels switched over.
## Headless, so this checks settings and arithmetic, not pixels; the pixels
## are checked by eye with tests/visual/stage_lights.tscn.
##
##   Godot --headless --fixed-fps 60 --path . res://tests/lights_test.tscn

const Props := preload("res://scripts/Interaction/Props.gd")
const Furnishings := preload("res://scripts/Interaction/Furnishings.gd")
const FireScript := preload("res://scripts/Combat/Fire.gd")
const TorchScript := preload("res://scripts/Visual/Torch.gd")
const Materials := preload("res://scripts/Visual/Materials.gd")
const LightProbe := preload("res://scripts/StimuliSystem/LightProbe.gd")
const Flicker := preload("res://scripts/Visual/Lights/Flicker.gd")
const FlameFx := preload("res://scripts/Visual/Lights/FlameFx.gd")
const Layers := preload("res://scripts/Visual/Layers.gd")
const CoronaScript := preload("res://scripts/Visual/Lights/Corona.gd")
const PLAYER := preload("res://Player.tscn")
const GUARD := preload("res://Guard.tscn")
const FireParticles := preload("res://scripts/Visual/Lights/FireParticles.gd")
const AtmosphereScript := preload("res://scripts/Visual/Atmosphere.gd")
const LightBudget := preload("res://scripts/Visual/Lights/LightBudget.gd")
const Lights := preload("res://scripts/Visual/Lights/Lights.gd")
const LightFixture := preload("res://scripts/Visual/Lights/LightFixture.gd")

## LightProbe 2 m from a bare torch, the brazier and the campfire (each
## flame's flicker held still), read on main before any of this work: the
## gameplay's light must stay within 10% of these.
const PROBE_BASELINE := [0.6870, 0.5878, 0.8089, 0.7449, 0.6229, 0.6943]

var results: Array[String] = []


func _ready() -> void:
	Props.block(self, Vector3(0, -0.5, 0), Vector3(400, 1, 400))
	await _frames(5)
	await _run()

	print("\n==== RESULTS ====")
	for r in results:
		print(r)

	get_tree().quit()


func _run() -> void:
	await _materials()
	await _baselines()
	_flicker()
	await _flames()
	await _burner()
	await _coronas()
	await _particles()
	await _lit_and_out()
	await _budget()
	await _fixture()
	await _torches()
	await _lanterns()


# ---------------------------------------------------------------------------
# Materials
# ---------------------------------------------------------------------------

func _materials() -> void:
	# L1 no photo: the slot's flat colour, shaded by vertex colour
	var folder_before: String = Materials.folder
	Materials.folder = "res://nowhere/"
	Materials.clear_cache()
	var iron: StandardMaterial3D = Materials.surface(&"iron")
	_check("L1 with no photo a slot is its flat colour, shaded by vertex colour",
		iron != null and iron.albedo_texture == null and iron.albedo_color.is_equal_approx(Color("2A2826")) and iron.vertex_color_use_as_albedo,
		"texture %s colour %s vertex colour %s" % [iron.albedo_texture if iron else null, iron.albedo_color if iron else Color.BLACK, iron.vertex_color_use_as_albedo if iron else false])

	# L2 a photo where there is one
	Materials.folder = "res://textures/"
	var stone_before = Materials.photo_names.get(&"stone")
	Materials.photo_names[&"stone"] = "stone_brick_1"
	Materials.clear_cache()
	var stone: StandardMaterial3D = Materials.surface(&"stone")
	_check("L2 a slot whose photo exists is drawn with it, sampled nearest",
		stone != null and stone.albedo_texture != null and stone.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS,
		"texture %s filter %d" % [stone.albedo_texture if stone else null, stone.texture_filter if stone else -1])
	Materials.photo_names[&"stone"] = stone_before
	Materials.folder = folder_before
	Materials.clear_cache()


# ---------------------------------------------------------------------------
# The gameplay's light, before and after
# ---------------------------------------------------------------------------

func _baselines() -> void:
	# L3 LightProbe beside a torch, the brazier and the campfire
	var torch: Node3D = TorchScript.new()
	add_child(torch)
	torch.global_position = Vector3(100, 2, 100)
	var fire: Area3D = FireScript.brazier(self, Vector3(120, 0, 100))
	var camp: Node3D = Furnishings.campfire(self, Vector3(140, 0, 100))
	await _frames(5)
	var burners := [torch, _burner_in(fire.get_parent()), _burner_in(camp)]
	var readings: Array[float] = []

	for burner in burners:
		if burner == null:
			readings.append(-1.0)
			continue

		burner.flicker = 0.0

	await _frames(3)

	for burner in burners:
		if burner == null:
			continue

		var flame: Vector3 = burner.global_position
		# Two metres off, at chest height.
		readings.append(LightProbe.light_at(self, Vector3(flame.x + 2.0, 1.2, flame.z)))
		# And from the other side, lower.
		readings.append(LightProbe.light_at(self, Vector3(flame.x, 0.6, flame.z - 2.0)))

	print("L3 probe readings: %s" % [readings])
	var close := PROBE_BASELINE.size() == readings.size()

	for i in mini(PROBE_BASELINE.size(), readings.size()):
		close = close and absf(readings[i] - float(PROBE_BASELINE[i])) <= 0.1 * maxf(float(PROBE_BASELINE[i]), 0.01)

	_check("L3 the probe reads the torch, brazier and campfire as it did before (within 10%)", close,
		"now %s, before %s" % [readings, PROBE_BASELINE])

	for node in [torch, fire.get_parent(), camp]:
		node.queue_free()

	await _frames(3)


# ---------------------------------------------------------------------------
# Flicker
# ---------------------------------------------------------------------------

func _flicker() -> void:
	# L4 every kind stays within -1..1
	var widest := 0.0

	for kind in Flicker.KINDS:
		for salt in [1, 77, 90210]:
			for i in 600:
				widest = maxf(widest, absf(Flicker.value(kind, i / 60.0, salt)))

	_check("L4 every kind of flicker stays within its swing (-1..1)", widest <= 1.0, "widest %.3f" % widest)

	# L5 each puffs at its own rate: the strongest frequency over 8 s
	var off := []

	for kind in Flicker.KINDS:
		var rate: float = Flicker.KINDS[kind]

		if rate <= 0.0:
			continue

		var peak := _peak_frequency(kind, 5)

		if absf(peak - rate) > 0.2 * rate:
			off.append("%s %.2f Hz (rate %.2f)" % [kind, peak, rate])

	_check("L5 each flicker's strongest frequency is its puff rate (within 20%)", off.is_empty(), "off: %s" % [off])

	# L6 a candle is still until a draft, which shivers and settles in a second
	var still := true

	for i in 600:
		still = still and Flicker.value(&"candle", i / 60.0, 3) == 0.0

	var tail := 0.0
	var early := 0.0

	for i in 12:
		tail = maxf(tail, absf(Flicker.draft(0.8 + i / 60.0)))

	for i in 18:
		early = maxf(early, absf(Flicker.draft(i / 60.0)))

	_check("L6 a candle burns still, a draft makes it shiver and it settles within a second",
		still and early > 0.3 and Flicker.draft(1.0) == 0.0 and tail < 0.05,
		"still %s, strongest in the first 0.3 s %.3f, at 1 s %.3f, last fifth %.3f" % [still, early, Flicker.draft(1.0), tail])


# ---------------------------------------------------------------------------
# Flames
# ---------------------------------------------------------------------------

func _flames() -> void:
	# L7 sprites on the effects layer, sharing one material per sheet
	var a: Node3D = FlameFx.new()
	var b: Node3D = FlameFx.new()
	a.layers = 2
	a.core = true
	add_child(a)
	add_child(b)
	a.global_position = Vector3(0, 2, -60)
	b.global_position = Vector3(2, 2, -60)
	await _frames(2)
	var all_fx := true

	for sprite in a.sprites:
		all_fx = all_fx and sprite.layers == Layers.FX and sprite.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_check("L7 a flame is sprites on the effects layer, and flames of one sheet share a material",
		a.sprites.size() == 3 and all_fx and a.sprites[0].material_override == b.sprites[0].material_override and a.sprites[0].material_override is ShaderMaterial,
		"sprites %d all on FX %s shared %s" % [a.sprites.size(), all_fx, a.sprites[0].material_override == b.sprites[0].material_override])

	# L8 the flipbook runs at the sheet's rate, and slower in slow motion
	var changes := [0, 0]

	for pass_index in 2:
		Engine.time_scale = 1.0 if pass_index == 0 else 0.5
		var last: int = a.frame

		for i in 120:
			await get_tree().process_frame

			if a.frame != last:
				changes[pass_index] += 1
				last = a.frame

	Engine.time_scale = 1.0
	_check("L8 the flipbook runs at its rate (torch 12 a second), half that at half speed",
		changes[0] >= 20 and changes[1] <= 14 and changes[1] >= 8,
		"changes in 2 s: %d at full speed, %d at half" % [changes[0], changes[1]])

	# L9 the wind leans it and flattens it a little
	a.shape(0.0, 1.0, Vector3(1, 0, 0), 0.0, 0.0)
	_check("L9 the wind leans the flame its way and flattens it", a.sprites[0].position.x >= 0.05 and a.sprites[0].scale.y < 1.0,
		"moved %.3f m, height %.3f" % [a.sprites[0].position.x, a.sprites[0].scale.y])

	# L10 burning low it goes to its dying colours
	a.shape(0.0, 0.2, Vector3.ZERO, 0.0, 0.0)
	var low: float = a.sprites[0].get_instance_shader_parameter(&"low")
	a.shape(0.0, 1.0, Vector3.ZERO, 0.0, 0.0)
	var full: float = a.sprites[0].get_instance_shader_parameter(&"low")
	_check("L10 burning low a flame turns to its dying ramp; burning full it does not", low > 0.5 and full == 0.0,
		"low %.2f at strength 0.2, %.2f at 1" % [low, full])
	a.queue_free()
	b.queue_free()
	await _frames(2)


# ---------------------------------------------------------------------------
# The burner (Torch.gd)
# ---------------------------------------------------------------------------

func _burner() -> void:
	# L11 a bare torch keeps everything the game holds it by, and burns in its band
	var torch: Node3D = TorchScript.new()
	add_child(torch)
	torch.global_position = Vector3(0, 2, -80)
	await _frames(2)
	var kept: bool = torch.is_in_group(&"torches") and torch.has_method("lean") and torch.has_method("set_strength") and torch.has_method("flare")
	var drawn: bool = torch.flame is MeshInstance3D and torch.flame.layers == Layers.FX
	var marked: bool = torch.light.has_meta(&"casts_shadow") and torch.light.get_meta(&"casts_shadow") == true
	var frames_seen := {}

	for i in 60:
		await get_tree().process_frame
		frames_seen[torch.get("frame")] = true

	var low := INF
	var high := -INF

	for i in 300:
		await get_tree().process_frame
		low = minf(low, torch.light.light_energy)
		high = maxf(high, torch.light.light_energy)

	var band: bool = low >= torch.energy * (1.0 - torch.flicker) - 0.01 and high <= torch.energy * (1.0 + torch.flicker) + 0.01
	torch.set_strength(0.2)
	await _frames(2)
	var dim: bool = torch.light.light_energy < 0.6 * torch.energy
	torch.set_strength(1.0)
	torch.flare(1.0)
	var flared: float = torch._flare
	var faded := false

	for i in int((TorchScript.FLARE_TIME + 0.1) * 60.0):
		await get_tree().process_frame

		if torch._flare < 0.1:
			faded = true
			break

	_check("L11 a bare torch keeps its hold-points, draws its flame on FX, burns in its band, dims and flares",
		kept and drawn and marked and frames_seen.size() >= 3 and not frames_seen.has(null) and band and dim and flared == 1.0 and faded,
		"kept %s drawn %s marked %s frames %d energy %.2f..%.2f band %s dim %s flare %.2f faded %s" % [kept, drawn, marked, frames_seen.size(), low, high, band, dim, flared, faded])
	torch.queue_free()
	await _frames(2)


# ---------------------------------------------------------------------------
# Coronas
# ---------------------------------------------------------------------------

func _coronas() -> void:
	var camera := Camera3D.new()
	add_child(camera)
	camera.global_position = Vector3(0, 1.6, 200)
	camera.current = true
	var torch: Node3D = TorchScript.new()
	add_child(torch)
	torch.global_position = Vector3(0, 1.5, 194)
	await _frames(15)
	var open_before: float = torch.corona.visibility if torch.get("corona") != null else -1.0

	# L12 a wall hides it within a moment, and it comes back
	var wall: StaticBody3D = Props.block(self, Vector3(0, 1.6, 197), Vector3(4, 4, 0.3))
	await _frames(12)
	var walled: float = torch.corona.visibility if torch.get("corona") != null else -1.0
	wall.queue_free()
	await _frames(12)
	var back: float = torch.corona.visibility if torch.get("corona") != null else -1.0
	_check("L12 a corona shines in the open, a wall hides it within 0.2 s, and it comes back",
		open_before > 0.9 and walled >= 0.0 and walled < 0.05 and back > 0.9,
		"open %.2f walled %.2f back %.2f" % [open_before, walled, back])

	# L13 a man hides it; a thin post over one ray hides a part of it
	var guard: Node3D = GUARD.instantiate()
	add_child(guard)
	guard.global_position = Vector3(0, 0, 196)
	await _frames(12)
	var manned: float = torch.corona.visibility if torch.get("corona") != null else -1.0
	guard.queue_free()
	await _frames(15)
	var offset: float = torch.corona.world_radius(camera) * 0.25 if torch.get("corona") != null else 0.0
	var post: StaticBody3D = Props.block(self, Vector3(offset * 0.8, 1.55, 194.6), Vector3(0.04, 0.5, 0.04))
	await _frames(15)
	var partly: float = torch.corona.visibility if torch.get("corona") != null else -1.0
	post.queue_free()
	_check("L13 a man in the way hides the corona; a thin post over one of its rays hides a part",
		manned >= 0.0 and manned < 0.05 and partly > 0.2 and partly < 0.9,
		"behind a man %.2f, behind a post %.2f (ray offset %.3f m)" % [manned, partly, offset])

	# L14 it fades with distance, it is an effect, and the lightgem cannot see effects
	var fx_layer: bool = torch.get("corona") != null and torch.corona.quad.layers == Layers.FX
	var gem_clear := true
	var gems := 0
	var player: Node = PLAYER.instantiate()

	for cam in player.find_children("*", "Camera3D", true, false):
		if cam.cull_mask & Layers.GEM_PROBE:
			gems += 1
			gem_clear = gem_clear and (cam.cull_mask & Layers.FX) == 0

	player.free()
	_check("L14 a corona fades out between 1.5 and 3 times its light's reach, is drawn on FX, and the lightgem's cameras do not see FX",
		CoronaScript.distance_fade(7.0, 5.0) == 1.0 and CoronaScript.distance_fade(15.0, 5.0) == 0.0 and CoronaScript.distance_fade(11.5, 5.0) > 0.0 and CoronaScript.distance_fade(11.5, 5.0) < 1.0 and fx_layer and gems >= 1 and gem_clear,
		"fade at 7/11.5/15 m: %.2f/%.2f/%.2f, on FX %s, gem cameras %d clear %s" % [CoronaScript.distance_fade(7.0, 5.0), CoronaScript.distance_fade(11.5, 5.0), CoronaScript.distance_fade(15.0, 5.0), fx_layer, gems, gem_clear])
	torch.queue_free()
	camera.queue_free()
	await _frames(3)


# ---------------------------------------------------------------------------
# Embers and smoke
# ---------------------------------------------------------------------------

func _particles() -> void:
	var camera := Camera3D.new()
	add_child(camera)
	camera.global_position = Vector3(0, 1.6, 300)
	camera.current = true

	# L15 a torch near you sheds embers at its rate; far off it sheds none
	var torch: Node3D = TorchScript.new()
	torch.ember_rate = 6.0
	torch.smoke_rate = 0.0
	add_child(torch)
	torch.global_position = Vector3(0, 1.6, 297)
	FireParticles.clear()
	await _frames(120)
	var near: int = FireParticles.live(&"ember")
	torch.global_position = Vector3(0, 1.6, 260)
	await _frames(2)
	FireParticles.clear()
	await _frames(120)
	var far: int = FireParticles.live(&"ember")
	_check("L15 a torch near you sheds embers at its rate, a far one none", near >= 3 and near <= 12 and far == 0,
		"embers alive near %d, far %d" % [near, far])
	torch.queue_free()

	# L16 a puff of smoke grows and is gone within its life
	FireParticles.clear()
	FireParticles.emit(self, &"smoke", Vector3(0, 1, 295), 1, Vector3.ZERO, Color.WHITE, 0.2)
	await _frames(1)
	var pool = FireParticles.world_node()._pools[&"smoke"] if FireParticles.world_node() != null else null
	var start: float = pool.size[0] if pool != null and pool.count > 0 else 0.0
	var biggest := start

	for i in 185:
		await get_tree().process_frame

		if pool != null and pool.count > 0:
			biggest = maxf(biggest, pool.size[0])

	_check("L16 a puff of smoke grows to over twice its size and is gone by 3.1 s", start > 0.0 and biggest >= 2.0 * start and FireParticles.live(&"smoke") == 0,
		"size %.3f -> %.3f, alive after 3.1 s %d" % [start, biggest, FireParticles.live(&"smoke")])

	# L17 where the Atmosphere makes a fire's embers, the fire makes none
	var air: Node3D = AtmosphereScript.new()
	add_child(air)
	var fire: Node3D = TorchScript.new()
	fire.set("embers_by_atmosphere", true)
	fire.smoke_rate = 0.0
	add_child(fire)
	fire.global_position = Vector3(0, 1.6, 297)
	FireParticles.clear()
	await _frames(120)
	var doubled: int = FireParticles.live(&"ember")
	_check("L17 a fire the Atmosphere already sheds embers for sheds none of its own", doubled == 0, "embers %d" % doubled)
	fire.queue_free()
	air.queue_free()
	await _frames(2)

	# L18 drawn on FX, and slow motion slows them
	var on_fx := FireParticles.world_node() != null

	if on_fx:
		for draw in FireParticles.world_node().find_children("*", "MultiMeshInstance3D", true, false):
			on_fx = on_fx and draw.layers == Layers.FX

	var rises: Array[float] = []

	for scale in [1.0, 0.5]:
		FireParticles.clear()
		FireParticles.reseed(7)
		Engine.time_scale = scale
		FireParticles.emit(self, &"ember", Vector3(0, 1, 295), 1)
		await get_tree().process_frame
		var from: float = FireParticles.world_node()._pools[&"ember"].pos[0].y
		for i in 20:
			await get_tree().process_frame
		rises.append(FireParticles.world_node()._pools[&"ember"].pos[0].y - from)

	Engine.time_scale = 1.0
	var share := rises[1] / maxf(rises[0], 0.0001)
	_check("L18 embers and smoke are drawn on FX, and at half speed an ember rises about half as far",
		on_fx and share >= 0.4 and share <= 0.6, "on FX %s, rose %.3f then %.3f m (%.2f)" % [on_fx, rises[0], rises[1], share])
	FireParticles.clear()
	camera.queue_free()
	await _frames(2)


# ---------------------------------------------------------------------------
# Lit and out
# ---------------------------------------------------------------------------

func _lit_and_out() -> void:
	var camera := Camera3D.new()
	add_child(camera)
	camera.global_position = Vector3(0, 1.6, 400)
	camera.current = true
	var torch: Node3D = TorchScript.new()
	add_child(torch)
	torch.global_position = Vector3(0, 1.6, 396)
	await _frames(10)
	var told: Array = []
	torch.lit_changed.connect(func(on: bool) -> void: told.append(on))

	# L19 snuffed, relit, doused, on their timings, told once each
	var lit_probe := LightProbe.light_at(self, Vector3(2, 1.2, 396))
	FireParticles.clear()
	torch.put_out(&"snuff")
	var snuffed_in := -1

	for i in 8:
		await get_tree().process_frame

		if snuffed_in < 0 and torch.light.light_energy <= 0.01 or (snuffed_in < 0 and not torch.light.visible):
			snuffed_in = i + 1

	await _frames(20)
	var smoke_after: int = FireParticles.live(&"smoke")
	var out_probe := LightProbe.light_at(self, Vector3(2, 1.2, 396))
	var told_out := told.duplicate()
	torch.kindle()
	var relit_in := -1

	for i in 40:
		await get_tree().process_frame
		var e: float = torch.light.light_energy

		if relit_in < 0 and torch.light.visible and e >= torch.energy * (1.0 - torch.flicker) - 0.01:
			relit_in = i + 1

	var told_back := told.duplicate()
	torch.put_out(&"douse")
	await get_tree().process_frame
	var doused_dark: bool = not torch.light.visible or torch.light.light_energy <= 0.01
	var cool_start: float = torch._cool
	await _frames(int(3.2 * 60.0))
	var cool_end: float = torch._cool
	_check("L19 snuffed it goes out in a tenth of a second and smokes; relit in half a second; doused at once, cooling over 3 s; each change told once",
		snuffed_in > 0 and snuffed_in <= 8 and smoke_after > 0 and told_out == [false] and relit_in > 0 and relit_in <= 35 and told_back == [false, true] and doused_dark and cool_start > 0.95 and cool_end < 0.05,
		"snuffed in %d frames, smoke %d, told %s, relit in %d, told %s, doused dark %s, cool %.2f -> %.2f" % [snuffed_in, smoke_after, told_out, relit_in, told_back, doused_dark, cool_start, cool_end])

	# L20 out, it lights nobody up
	_check("L20 put out, the probe beside it drops by 80% or more, and comes back when lit",
		out_probe <= 0.2 * lit_probe, "lit %.3f, out %.3f" % [lit_probe, out_probe])

	# L21 lit, out and lit again in one frame: it stays lit and says nothing
	torch.kindle(true)
	await _frames(5)
	told.clear()
	torch.kindle()
	torch.put_out()
	torch.kindle()
	await _frames(40)
	var in_band: bool = torch.light.visible and torch.light.light_energy >= torch.energy * (1.0 - torch.flicker) - 0.01
	_check("L21 lit, put out and lit again in one frame, it burns on and tells nothing", in_band and told.is_empty() and torch.is_lit(),
		"burning %s, told %s" % [in_band, told])

	# L22 freed while it cools: nothing left behind, nothing broken
	torch.put_out(&"douse")
	await get_tree().process_frame
	torch.queue_free()
	await _frames(240)
	_check("L22 a doused flame freed the next frame leaves nothing behind", FireParticles.live(&"steam") == 0 and not is_instance_valid(torch),
		"steam %d, freed %s" % [FireParticles.live(&"steam"), not is_instance_valid(torch)])
	camera.queue_free()
	await _frames(2)


# ---------------------------------------------------------------------------
# The shadow budget
# ---------------------------------------------------------------------------

func _budget() -> void:
	var camera := Camera3D.new()
	add_child(camera)
	camera.global_position = Vector3(0, 1.6, 500)
	camera.current = true

	# L23 six shadows at most, and never switched close to you
	var line: Array = []

	for i in 10:
		var torch: Node3D = TorchScript.new()
		add_child(torch)
		torch.global_position = Vector3(0, 2, 486 - 2.0 * i)
		line.append(torch)

	await _frames(60)
	var at_most_six: int = LightBudget.shadowed()
	var popped_close := []
	var before := {}

	for torch in line:
		before[torch] = torch.light.shadow_enabled

	for step in 120:
		camera.global_position.z -= 0.25
		await get_tree().process_frame

		for torch in line:
			if torch.light.shadow_enabled != before[torch]:
				var d: float = camera.global_position.distance_to(torch.global_position)

				if d <= maxf(LightBudget.NEAR, torch.light_range + 1.0):
					popped_close.append("%.1f m" % d)

				before[torch] = torch.light.shadow_enabled

	_check("L23 at most six lights cast shadows, and none switches within max(12 m, its reach + 1) of you",
		at_most_six <= 6 and at_most_six > 0 and popped_close.is_empty(),
		"shadowed %d, switched close %s, shadowed at the end %d" % [at_most_six, popped_close, LightBudget.shadowed()])

	for torch in line:
		torch.queue_free()

	await _frames(3)

	# L24 a light the budget drew without shadows still casts them for the guards
	var lamp: Node3D = TorchScript.new()
	add_child(lamp)
	lamp.global_position = Vector3(10, 1.5, 520)
	Props.block(self, Vector3(10, 1.5, 518), Vector3(3, 3, 0.3))
	await _frames(3)
	lamp.flicker = 0.0
	await _frames(2)
	var behind := Vector3(10, 1.2, 516.5)
	var shadowed_read := LightProbe.light_at(self, behind)
	lamp.light.shadow_enabled = false
	LightProbe.invalidate()
	var budgeted_read := LightProbe.light_at(self, behind)
	lamp.light.shadow_enabled = true
	_check("L24 behind a wall, a light drawn without shadows still reads as shadowed to the guards",
		absf(budgeted_read - shadowed_read) <= 0.05 * maxf(shadowed_read, 0.02),
		"behind the wall: %.3f with shadows, %.3f drawn without" % [shadowed_read, budgeted_read])
	lamp.queue_free()

	# L25 too many shadows in one place: warned, once
	LightBudget.warned = false
	var crowd: Array = []

	for i in 8:
		var torch: Node3D = TorchScript.new()
		add_child(torch)
		torch.global_position = camera.global_position + Vector3(float(i) - 3.5, 0.5, -4.0)
		crowd.append(torch)

	await _frames(30)
	_check("L25 eight shadow lights within 12 m of you: the budget warns", LightBudget.warned, "warned %s" % LightBudget.warned)

	for torch in crowd:
		torch.queue_free()

	await _frames(3)

	# L26 a level freed and another built: the budget and particles start clean
	var level := Node3D.new()
	add_child(level)

	for i in 4:
		var torch: Node3D = TorchScript.new()
		level.add_child(torch)
		torch.global_position = camera.global_position + Vector3(float(i), 0.5, -30.0)

	await _frames(20)
	level.queue_free()
	await _frames(3)
	var fresh: Array = []

	for i in 3:
		var torch: Node3D = TorchScript.new()
		add_child(torch)
		torch.global_position = camera.global_position + Vector3(float(i) * 3.0 - 3.0, 0.5, -20.0)
		fresh.append(torch)

	FireParticles.clear()
	await _frames(90)
	_check("L26 after a level is freed the budget and embers work on the new lights alone",
		LightBudget.shadowed() == 3 and FireParticles.live(&"ember") > 0,
		"shadowed %d, embers %d" % [LightBudget.shadowed(), FireParticles.live(&"ember")])

	# L27 no camera at all: nothing breaks, nothing shows
	camera.current = false
	await get_tree().process_frame
	var no_camera := get_viewport().get_camera_3d() == null
	FireParticles.clear()
	var shadows_before: bool = fresh[0].light.shadow_enabled
	await _frames(60)
	_check("L27 with no camera the lights burn on: no halo, no embers, shadows left as they are",
		no_camera and fresh[0].corona.visibility == 0.0 and FireParticles.live(&"ember") == 0 and fresh[0].light.shadow_enabled == shadows_before,
		"no camera %s, halo %.2f, embers %d, shadows kept %s" % [no_camera, fresh[0].corona.visibility, FireParticles.live(&"ember"), fresh[0].light.shadow_enabled == shadows_before])

	for torch in fresh:
		torch.queue_free()

	camera.queue_free()
	await _frames(3)


# ---------------------------------------------------------------------------
# A fixture: the model on a burner
# ---------------------------------------------------------------------------

func _fixture() -> void:
	var camera := Camera3D.new()
	add_child(camera)
	camera.global_position = Vector3(0, 1.8, 604)
	camera.current = true
	# A wall facing +Z, its face at z = 596.15, a ceiling 1.2 m over the flame.
	Props.block(self, Vector3(0, 2, 596), Vector3(4, 4, 0.3))
	var spec: Dictionary = LightFixture.spec(&"wall_torch")
	var flame_local: Vector3 = _v(spec.get("sockets", {}).get("flame", [[0, 0, 0]])[0])
	var face_z := 596.15
	var flame_at := Vector3(0, 2.4, face_z + flame_local.z)

	# L28 against a wall: its flame where asked, its mount on the wall, one light above the flame
	var torch: Node3D = Lights.wall_torch(self, flame_at, Vector3(0, 0, 1))
	await _frames(5)
	# Where its light rests (a torch's light dances a couple of centimetres round it).
	var light_at: Vector3 = torch.global_transform * torch._light_base if torch.get("light") != null else Vector3.INF
	var mount_at: Vector3 = torch.global_transform * torch.socket(&"mount") if torch.has_method("socket") else Vector3.INF
	_check("L28 a wall torch stands on its wall: one flame, its light just above it, its mount on the wall face",
		torch.flames.size() == 1 and light_at.distance_to(flame_at + Vector3(0, 0.12, 0)) < 0.01 and absf(mount_at.z - face_z) < 0.03,
		"flames %d, light %s (flame %s), mount z %.3f (wall %.3f)" % [torch.flames.size(), light_at, flame_at, mount_at.z, face_z])

	# L29 its surfaces are the shared slot materials, and it keeps its baked colours
	var right := true
	var coloured := false

	for mesh in torch.find_children("*", "MeshInstance3D", true, false):
		if mesh.layers == Layers.FX:
			continue

		for i in mesh.mesh.get_surface_count():
			var look: Material = mesh.get_surface_override_material(i)
			var slot := String(mesh.mesh.surface_get_material(i).resource_name)
			right = right and (look is ShaderMaterial if slot.ends_with("_glow") else look == Materials.surface(StringName(slot)))
			var arrays: Array = mesh.mesh.surface_get_arrays(i)
			coloured = coloured or (arrays[Mesh.ARRAY_COLOR] != null and arrays[Mesh.ARRAY_COLOR].size() > 0)

	_check("L29 a fixture's surfaces are Materials' slot materials (or glowing), and its baked colours came through",
		right and coloured and torch.glow_meshes.size() >= 1, "slot materials %s, vertex colours %s, glowing %d" % [right, coloured, torch.glow_meshes.size()])

	# L30 soot on the wall above it
	var decals := torch.find_children("*", "Decal", true, false)
	var soot_ok: bool = decals.size() == 1 and decals[0].cull_mask == Layers.WORLD_ALL and decals[0].global_position.y > flame_at.y
	_check("L30 a wall fixture leaves one soot mark on the wall above its flame, on world surfaces only", soot_ok,
		"decals %d%s" % [decals.size(), (" at %s mask %d" % [decals[0].global_position, decals[0].cull_mask]) if decals.size() > 0 else ""])

	# L31 doused, its head cools to char
	torch.put_out(&"douse")
	await _frames(int(3.2 * 60.0))
	var charred: float = torch.glow_meshes[0].get_instance_shader_parameter(&"charred") if torch.glow_meshes.size() > 0 else -1.0
	var glow: float = torch.glow_meshes[0].get_instance_shader_parameter(&"glow") if torch.glow_meshes.size() > 0 else -1.0
	_check("L31 doused, its head's glow cools away and it is left charred", charred >= 0.95 and glow <= 0.05,
		"charred %.2f glow %.2f" % [charred, glow])
	torch.queue_free()

	# L32 a fixture with no model: still a light, as a bare flame
	var lost: Node3D = Lights.make(self, &"no_such_fixture", Vector3(3, 2, 600))
	await _frames(3)
	_check("L32 a fixture whose model is missing is still a bare flame with its light",
		lost.get("light") != null and lost.flames.size() == 1 and lost.flames[0].position == Vector3.ZERO,
		"light %s flames %d" % [lost.get("light") != null, lost.flames.size() if lost.get("flames") != null else -1])
	lost.queue_free()
	camera.queue_free()
	await _frames(3)


# ---------------------------------------------------------------------------
# The torch family and torch_at
# ---------------------------------------------------------------------------

func _torches() -> void:
	var camera := Camera3D.new()
	add_child(camera)
	camera.global_position = Vector3(0, 1.8, 710)
	camera.current = true
	Props.block(self, Vector3(40, -0.5, 705), Vector3(100, 1, 30))
	Props.block(self, Vector3(0, 2, 700), Vector3(6, 4, 0.3))

	# L33a beside a wall it becomes a wall torch on it
	var a: Node3D = Lights.torch_at(self, Vector3(0, 2.6, 700.45), 2.2, 9.0, true)
	var lit_every_frame := true

	for i in 4:
		await get_tree().physics_frame
		lit_every_frame = lit_every_frame and _lit_near(Vector3(0, 2.6, 700.45))

	var walled := _fixture_near(Vector3(0, 2.6, 700.6))
	_check("L33a a torch placed by a wall becomes a wall torch on it, lit throughout",
		walled != null and walled.fixture == &"wall_torch" and is_equal_approx(walled.energy, 2.2) and lit_every_frame,
		"became %s, energy %s, lit every frame %s" % [walled.fixture if walled else "nothing", walled.energy if walled else 0.0, lit_every_frame])

	# L33b in the open over a floor it becomes a pole cresset reaching its flame
	var b: Node3D = Lights.torch_at(self, Vector3(20, 2.6, 705), 2.4, 9.0, true)
	await _frames(3)
	var pole := _fixture_near(Vector3(20, 1.3, 705), 2.0)
	var reach := INF

	if pole != null:
		reach = (pole.global_transform * pole.flame_points[0]).distance_to(Vector3(20, 2.6, 705))

	_check("L33b a torch in the open over a floor becomes a pole cresset whose flame is where it was",
		pole != null and pole.fixture == &"cresset_pole" and reach < 0.03, "became %s, flame off by %.3f m" % [pole.fixture if pole else "nothing", reach])

	# L33c over nothing it stays a bare flame
	var c: Node3D = Lights.torch_at(self, Vector3(40, 30, 705), 2.4, 9.0, true)
	await _frames(1)
	await _frames(3)
	var bare := _burner_near(Vector3(40, 30, 705))
	_check("L33c a torch with nothing to stand on stays a bare flame", bare != null and bare.get("fixture") == null,
		"%s" % [bare])

	# L33d never mounted on a door, nor on a man
	var door: Node3D = Props.door(self, Vector3(60, 0, 705), 0.0)
	await _frames(2)
	Lights.torch_at(self, Vector3(60.5, 2.0, 705.3), 2.4, 9.0, true)
	var guard: Node3D = GUARD.instantiate()
	add_child(guard)
	guard.global_position = Vector3(70, 0, 705)
	await _frames(2)
	Lights.torch_at(self, Vector3(70, 1.2, 705.4), 2.4, 9.0, true)
	await _frames(3)
	var by_door := _fixture_near(Vector3(60.5, 1.0, 705.3), 2.0)
	var by_man := _fixture_near(Vector3(70, 0.6, 705.4), 2.0)
	_check("L33d a torch by a door or a man is never mounted on them",
		(by_door == null or by_door.fixture != &"wall_torch") and (by_man == null or by_man.fixture != &"wall_torch"),
		"by the door %s, by the man %s" % [by_door.fixture if by_door else "bare", by_man.fixture if by_man else "bare"])
	guard.queue_free()
	door.queue_free()

	# L34 the carried torch is held by its flame, the hand below
	var held: Node3D = Lights.carried_torch()
	add_child(held)
	await _frames(2)
	_check("L34 a carried torch's flame is its origin and its grip is 0.36 m below",
		held.socket(&"flame") == Vector3.ZERO and absf(held.socket(&"grip").y + 0.36) < 0.01,
		"flame %s grip %s" % [held.socket(&"flame"), held.socket(&"grip")])
	held.queue_free()

	for node in get_children():
		if node.is_in_group(&"torches"):
			node.queue_free()

	camera.queue_free()
	await _frames(3)


# ---------------------------------------------------------------------------
# Lanterns and lamps
# ---------------------------------------------------------------------------

func _lanterns() -> void:
	var camera := Camera3D.new()
	add_child(camera)
	camera.global_position = Vector3(0, 1.8, 810)
	camera.current = true

	# L35 a hung lantern throws its bars, casts shadows, and swings in the wind
	var hung: Node3D = Lights.hanging_lantern(self, Vector3(0, 3, 800), 0.6)
	await _frames(3)
	hung.lean(Vector3(1, 0, 0))
	await _frames(120)
	var tilt: float = hung.global_basis.y.angle_to(Vector3.UP)
	_check("L35 a hanging lantern throws its frame's bars, casts shadows, and swings in the wind",
		hung.light.light_projector != null and hung.light.shadow_enabled and tilt > 0.05,
		"projector %s shadows %s tilted %.3f rad" % [hung.light.light_projector != null, hung.light.shadow_enabled, tilt])
	hung.queue_free()

	# L36 a carried lantern throws none; a lamp post does, its flame at head height and more
	var carried: Node3D = Lights.carried_lantern()
	add_child(carried)
	var post: Node3D = Lights.lamp_post(self, Vector3(6, 0, 800))
	await _frames(3)
	var flame_height: float = (post.global_transform * post.flame_points[0]).y - post.global_position.y
	_check("L36 a carried lantern has no cookie and no shadows; a lamp post has its cookie, its flame 2.2-2.6 m up",
		carried.light.light_projector == null and not carried.light.shadow_enabled and post.light.light_projector != null and flame_height > 2.2 and flame_height < 2.6,
		"carried cookie %s shadows %s; post cookie %s flame at %.2f m" % [carried.light.light_projector != null, carried.light.shadow_enabled, post.light.light_projector != null, flame_height])
	carried.queue_free()
	post.queue_free()
	camera.queue_free()
	await _frames(3)


## The fixture (a LightFixture) nearest `at` within `reach`.
func _fixture_near(at: Vector3, reach := 1.0) -> Node3D:
	var best: Node3D = null

	for node in get_tree().get_nodes_in_group(&"torches"):
		if node.get("fixture") != null and String(node.fixture) != "" and node.global_position.distance_to(at) < reach:
			if best == null or node.global_position.distance_to(at) < best.global_position.distance_to(at):
				best = node

	return best


func _burner_near(at: Vector3, reach := 0.2) -> Node3D:
	for node in get_tree().get_nodes_in_group(&"torches"):
		if node.global_position.distance_to(at) < reach:
			return node

	return null


## Some burner's light near `at` is lit.
func _lit_near(at: Vector3) -> bool:
	for node in get_tree().get_nodes_in_group(&"torches"):
		if not node.is_queued_for_deletion() and node.light != null and node.light.visible and node.light.light_energy > 0.0 and node.light.global_position.distance_to(at) < 1.0:
			return true

	return false


func _v(a) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


## The frequency (Hz) with the most energy in 8 s of a flicker sampled at 60 Hz.
func _peak_frequency(kind: StringName, salt: int) -> float:
	var samples := PackedFloat64Array()

	for i in 480:
		samples.append(Flicker.value(kind, i / 60.0, salt))

	var best := 0.0
	var best_power := -1.0

	for k in range(1, 241):
		var frequency := k / 8.0
		var re := 0.0
		var im := 0.0

		for i in 480:
			var angle := TAU * frequency * i / 60.0
			re += samples[i] * cos(angle)
			im -= samples[i] * sin(angle)

		var power := re * re + im * im

		if power > best_power:
			best_power = power
			best = frequency

	return best


## The burner (anything in "torches") at or under `node`.
func _burner_in(node: Node) -> Node3D:
	if node == null:
		return null

	if node.is_in_group(&"torches"):
		return node

	for child in node.find_children("*", "", true, false):
		if child.is_in_group(&"torches"):
			return child

	return null


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
