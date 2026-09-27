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
const Sfx := preload("res://scripts/Audio/Sfx.gd")
const HangingScript := preload("res://scripts/Visual/Hanging.gd")
const ThrownTool := preload("res://scripts/Combat/ThrownTool.gd")
const LightFixture := preload("res://scripts/Visual/Lights/LightFixture.gd")

## LightProbe 2 m from a bare torch, the brazier and the campfire (each
## flame's flicker held still), read on main before any of this work: the
## gameplay's light must stay within 10% of these.
const PROBE_BASELINE := [0.6870, 0.5878, 0.8089, 0.7449, 0.6229, 0.6943]

var results: Array[String] = []
## The suite's own floor (L47 takes it away while a map stands on it).
var _ground: StaticBody3D


func _ready() -> void:
	_ground = Props.block(self, Vector3(0, -0.5, 0), Vector3(400, 1, 400))
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
	await _candles()
	await _fires()
	await _sounds()
	await _switched()
	await _maps()
	await _gallery()
	await _reviewed()
	await _minors()
	await _douseable()


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

	# L3b whatever its colour, a burner's light is as bright as today's torch:
	#     a warmer colour is a hue, not a dimmer light
	var luma := func(c: Color) -> float: return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
	var today: float = luma.call(Color(1.0, 0.64, 0.32))
	var hues_kept := true
	var lumas: Array[float] = []

	for colour in [Color("FF9829"), Color("FFA645")]:
		var burner: Node3D = TorchScript.new()
		burner.color = colour
		add_child(burner)
		burner.global_position = Vector3(160, 2, 100)
		await _frames(2)
		var shone: Color = burner.light.light_color
		lumas.append(luma.call(shone))
		hues_kept = hues_kept and is_equal_approx(shone.g / shone.r, colour.g / colour.r) and is_equal_approx(shone.b / shone.r, colour.b / colour.r)
		burner.queue_free()

	_check("L3b a torch's or a lantern's light is as bright as today's torch light, in its own hue",
		hues_kept and absf(lumas[0] - today) < 0.005 and absf(lumas[1] - today) < 0.005,
		"luminance %s (today %.4f), hues kept %s" % [lumas, today, hues_kept])
	await _frames(2)


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
	var counted: bool = LightBudget._world != null and LightBudget._world._burners.has(torch)
	torch.queue_free()
	# The next frame, before the budget has looked again: it was told.
	await get_tree().process_frame
	var forgotten: bool = LightBudget._world != null and LightBudget._world._burners.all(func(b): return is_instance_valid(b))
	await _frames(240)
	_check("L22 a doused flame freed the next frame leaves nothing behind: no steam, and the budget forgets it at once",
		FireParticles.live(&"steam") == 0 and not is_instance_valid(torch) and counted and forgotten,
		"steam %d, freed %s, counted %s then forgotten %s" % [FireParticles.live(&"steam"), not is_instance_valid(torch), counted, forgotten])
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

	# L26 a level freed and another built: its budget and particles go with
	#     it, and start clean in the next
	var level := Node3D.new()
	get_tree().root.add_child(level)
	var own_scene := get_tree().current_scene
	get_tree().current_scene = level

	for manager in [FireParticles.world_node(), LightBudget._world]:
		if manager != null and is_instance_valid(manager):
			manager.free()

	for i in 4:
		var torch: Node3D = TorchScript.new()
		level.add_child(torch)
		torch.global_position = camera.global_position + Vector3(float(i), 0.5, -30.0)

	FireParticles.emit(level, &"ember", camera.global_position + Vector3(0, 0, -5), 1)
	await _frames(20)
	var old_budget: Node = LightBudget._world
	var old_particles: Node = FireParticles.world_node()
	var made_there: bool = old_budget != null and old_budget.get_parent() == level and old_particles != null and old_particles.get_parent() == level
	get_tree().current_scene = own_scene
	level.queue_free()
	await _frames(3)
	var went_with_it: bool = not is_instance_valid(old_budget) and not is_instance_valid(old_particles)
	var fresh: Array = []

	for i in 3:
		var torch: Node3D = TorchScript.new()
		add_child(torch)
		torch.global_position = camera.global_position + Vector3(float(i) * 3.0 - 3.0, 0.5, -20.0)
		fresh.append(torch)

	FireParticles.clear()
	await _frames(90)
	var rebuilt: bool = LightBudget._world != null and LightBudget._world.get_parent() == own_scene and FireParticles.world_node() != null and FireParticles.world_node().get_parent() == own_scene
	_check("L26 a level's budget and particles are made in it, go with it, and start clean in the next, on the new lights alone",
		made_there and went_with_it and rebuilt and LightBudget.shadowed() == 3 and FireParticles.live(&"ember") > 0,
		"made in the level %s, went with it %s, rebuilt %s, shadowed %d, embers %d" % [made_there, went_with_it, rebuilt, LightBudget.shadowed(), FireParticles.live(&"ember")])

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


# ---------------------------------------------------------------------------
# Candles, oil lamps and the draft
# ---------------------------------------------------------------------------

func _candles() -> void:
	var camera := Camera3D.new()
	add_child(camera)
	camera.global_position = Vector3(0, 1.8, 910)
	camera.current = true

	# L37 a candelabra: one light for its five candles, one halo, plain flames
	var five: Node3D = Lights.candelabra(self, Vector3(0, 1.0, 900), 5)
	var lone: Node3D = Lights.candle(self, Vector3(3, 1.0, 900), 10)
	await _frames(5)
	var lights: int = five.find_children("*", "OmniLight3D", true, false).size()
	var plain: bool = five.flames.size() == 5

	for fx in five.flames:
		plain = plain and fx.sprites.size() == 1 and not fx.core

	var halos: int = five.find_children("*", "", true, false).filter(func(n): return n.get_script() == CoronaScript).size()
	var low := INF
	var high := -INF

	for i in 120:
		await get_tree().process_frame
		low = minf(low, lone.light.light_energy)
		high = maxf(high, lone.light.light_energy)

	_check("L37 a candelabra of five has one light, five plain flames and one halo; a lone candle burns still",
		lights == 1 and plain and halos == 1 and high - low <= 0.001,
		"lights %d, flames %d plain %s, halos %d, lone candle %.4f..%.4f" % [lights, five.flames.size(), plain, halos, low, high])

	# L38 a door opening beside a candle makes it shiver, and it settles; so does a man running past
	var door: Node3D = Props.door(self, Vector3(4.5, 0, 900), 0.0)
	await _frames(20)
	door.rotation.y += 0.6
	var shivered := false
	var base: float = lone.energy

	for i in 30:
		await get_tree().process_frame
		shivered = shivered or absf(lone.light.light_energy - base) > 0.01 * base

	await _frames(90)
	var settled_door: bool = absf(lone.light.light_energy - base) <= 0.001
	var runner := CharacterBody3D.new()
	runner.add_to_group(&"guards")
	add_child(runner)
	runner.global_position = Vector3(1.0, 1.0, 900.6)
	runner.velocity = Vector3(4, 0, 0)
	var run_shiver := false

	for i in 30:
		runner.global_position += Vector3(4.0 / 60.0, 0, 0)
		await get_tree().process_frame
		run_shiver = run_shiver or absf(lone.light.light_energy - base) > 0.01 * base

	runner.queue_free()
	_check("L38 a door swung beside a candle makes it shiver and it settles; a man running past does the same",
		shivered and settled_door and run_shiver, "door shiver %s, settled %s, runner shiver %s" % [shivered, settled_door, run_shiver])
	door.queue_free()
	five.queue_free()
	lone.queue_free()
	camera.queue_free()
	await _frames(3)


# ---------------------------------------------------------------------------
# Open fires
# ---------------------------------------------------------------------------

func _fires() -> void:
	var camera := Camera3D.new()
	add_child(camera)
	camera.global_position = Vector3(0, 1.8, 1005)
	camera.current = true
	Props.block(self, Vector3(0, -0.5, 1000), Vector3(80, 1, 40))

	# L39 heat haze over a campfire near you, none far off
	var camp: Node3D = Lights.campfire(self, Vector3(0, 0, 1000))
	await _frames(5)
	var haze_near: bool = camp.get("haze") != null and camp.haze.visible
	camera.global_position = Vector3(0, 1.8, 1020)
	await _frames(3)
	var haze_far: bool = camp.get("haze") != null and camp.haze.visible
	_check("L39 a campfire's heat haze shows near you and not 20 m off", haze_near and not haze_far,
		"near %s far %s" % [haze_near, haze_far])
	camera.global_position = Vector3(0, 1.8, 1005)

	# L40 settling logs make the flames jump, never the light
	var from_recipe: Vector2 = camp.event_every
	camp.event_every = Vector2(0.5, 0.6)
	var low := INF
	var high := -INF
	var jumps := 0
	var was_high := false

	for i in 20 * 60:
		await get_tree().process_frame
		var e: float = camp.light.light_energy
		low = minf(low, e)
		high = maxf(high, e)
		var up: bool = camp._jump > 0.9

		if up and not was_high:
			jumps += 1

		was_high = up

	_check("L40 settling logs make a campfire's flames jump, and its light stays in its band",
		from_recipe == Vector2(20, 40) and low >= camp.energy * (1.0 - camp.flicker) - 0.01 and high <= camp.energy * (1.0 + camp.flicker) + 0.01 and jumps >= 10,
		"its recipe's events %s, light %.2f..%.2f (band %.2f..%.2f), jumps %d" % [from_recipe, low, high, camp.energy * (1.0 - camp.flicker), camp.energy * (1.0 + camp.flicker), jumps])
	camp.queue_free()

	# L40b a doused brazier's coals wink out: a few embers over 20 s, then none
	var brazier: Node3D = Lights.brazier(self, Vector3(6, 0, 1000))
	await _frames(10)
	brazier.put_out(&"douse")
	var before: int = FireParticles.emitted(&"ember")
	await _frames(20 * 60)
	var winks: int = FireParticles.emitted(&"ember") - before
	await _frames(10 * 60)
	var after: int = FireParticles.emitted(&"ember") - before - winks
	_check("L40b doused, a brazier's coals wink out: 3 to 5 embers over 20 s, then none",
		winks >= 3 and winks <= 5 and after == 0, "winks %d, after %d" % [winks, after])
	brazier.queue_free()

	# L41 a hearth is solid masonry
	var hearth: Node3D = Lights.hearth(self, Vector3(20, 0, 999), 0.0)
	await _frames(5)
	var bodies: int = hearth.find_children("*", "StaticBody3D", true, false).size()
	var hood_hit := {}

	if bodies > 0:
		var space := get_world_3d().direct_space_state
		var query := PhysicsRayQueryParameters3D.create(Vector3(20, 1.25, 1002), Vector3(20, 1.25, 998), 1)
		hood_hit = space.intersect_ray(query)

	_check("L41 a hearth has its masonry as static bodies, and its hood stops a ray", bodies >= 4 and not hood_hit.is_empty(),
		"bodies %d, hood hit %s" % [bodies, not hood_hit.is_empty()])
	hearth.queue_free()
	camera.queue_free()
	await _frames(3)


# ---------------------------------------------------------------------------
# Their sounds
# ---------------------------------------------------------------------------

func _sounds() -> void:
	Sfx.enabled = true
	var camera := Camera3D.new()
	add_child(camera)
	camera.global_position = Vector3(0, 1.6, 1103)
	camera.current = true

	# L42 a campfire's bed near you, gone far off, silent once out, muffled through a wall
	var camp: Node3D = Lights.campfire(self, Vector3(0, 0, 1100))
	await _frames(60)
	var bed: AudioStreamPlayer3D = camp.crackle
	var bed_file: String = bed.stream.resource_path.get_file() if bed != null else "none"
	var near_playing: bool = bed != null and bed.playing and bed.bus == Sfx.BUS_WORLD and bed_file.get_basename() == "fire_medium"
	camera.global_position = Vector3(0, 1.6, 1120)
	await _frames(60)
	var far_stopped: bool = bed != null and not bed.playing
	camera.global_position = Vector3(0, 1.6, 1103)
	await _frames(60)
	var back: bool = bed != null and bed.playing
	camp.put_out(&"douse")
	await _frames(60)
	var out_stopped: bool = bed != null and not bed.playing
	camp.queue_free()
	var room := Vector3(20, 0, 1100)
	Props.block(self, room + Vector3(0, 1.6, -2.2), Vector3(4.8, 3.2, 0.4))
	Props.block(self, room + Vector3(0, 1.6, 2.2), Vector3(4.8, 3.2, 0.4))
	Props.block(self, room + Vector3(-2.2, 1.6, 0), Vector3(0.4, 3.2, 4.8))
	Props.block(self, room + Vector3(2.2, 1.6, 0), Vector3(0.4, 3.2, 4.8))
	Props.block(self, room + Vector3(0, 3.4, 0), Vector3(4.8, 0.4, 4.8))
	var boxed: Node3D = Lights.campfire(self, room)
	camera.global_position = room + Vector3(0, 1.6, 8)
	await _frames(60)
	var muffled: bool = boxed.crackle != null and boxed.crackle.playing and boxed.crackle.attenuation_filter_cutoff_hz == Sfx.OCCLUDED_CUTOFF
	_check("L42 a campfire's fire bed plays near you on the World bus, stops 20 m off and once doused, and is muffled through a wall",
		near_playing and far_stopped and back and out_stopped and muffled,
		"near %s (%s), far stopped %s, back %s, doused stopped %s, boxed muffled %s" % [near_playing, bed_file, far_stopped, back, out_stopped, muffled])
	boxed.queue_free()

	# L42b a hearth's chimney draws with its fire, from the top of its masonry
	var hearth: Node3D = Lights.hearth(self, Vector3(30, 0, 1100), 0.0)
	camera.global_position = Vector3(30, 1.6, 1104)
	await _frames(60)
	var draw: AudioStreamPlayer3D = hearth.get("chimney")
	var drawing: bool = draw != null and draw.playing and hearth.crackle.playing and draw.position.y > 1.5 and draw.stream.resource_path.get_file().get_basename() == "chimney"
	var under_bed: bool = draw != null and absf(draw.volume_db - (LightFixture.CHIMNEY_DB + hearth.crackle.volume_db - hearth.loop_db)) < 0.01
	hearth.put_out(&"douse")
	await _frames(60)
	var draw_stopped: bool = draw != null and not draw.playing
	_check("L42b a hearth's chimney draws from the top of its masonry, 20 dB under its fire, and stops with it; it crackles half as often",
		drawing and under_bed and draw_stopped and is_equal_approx(hearth.crackle_rate, 0.5),
		"drawing %s at %.2f m, under the bed %s, stopped %s, crackles %.2f/s" % [drawing, draw.position.y if draw != null else -1.0, under_bed, draw_stopped, hearth.crackle_rate])
	hearth.queue_free()

	# L43 a brazier crackles at random over its bed: never on a grid
	var brazier: Node3D = Lights.brazier(self, Vector3(40, 0, 1100))
	camera.global_position = Vector3(40, 1.6, 1104)
	await _frames(60)
	Sfx.recording = true
	Sfx.recorded.clear()
	var times: Array[float] = []
	var seen := 0

	for i in 60 * 60:
		await _frames(1)

		while seen < Sfx.recorded.size():
			if Sfx.recorded[seen][0] in [&"crackle", &"coal_pop"]:
				times.append(i / 60.0)

			seen += 1

	Sfx.recording = false
	var gaps: Array[float] = []

	for i in range(1, times.size()):
		gaps.append(times[i] - times[i - 1])

	var mean := 0.0

	for gap in gaps:
		mean += gap

	mean /= maxf(gaps.size(), 1)
	var spread := 0.0

	for gap in gaps:
		spread += (gap - mean) * (gap - mean)

	var cv := sqrt(spread / maxf(gaps.size(), 1)) / maxf(mean, 0.0001)
	_check("L43 a brazier crackles and pops 40-80 times a minute over its bed, at irregular times",
		times.size() >= 40 and times.size() <= 80 and cv > 0.6, "%d in 60 s, variation of the gaps %.2f" % [times.size(), cv])
	brazier.queue_free()

	# L44 a hung lantern creaks as the wind swings it; a guard's lantern rattles every other step
	var hung: Node3D = Lights.hanging_lantern(self, Vector3(60, 3, 1100), 0.6)
	camera.global_position = Vector3(60, 1.6, 1104)
	await _frames(3)
	Sfx.recording = true
	Sfx.recorded.clear()
	hung.lean(Vector3(3, 0, 0))
	await _frames(180)
	var creaks := Sfx.recorded.filter(func(entry): return entry[0] == &"lantern_creak").size()
	hung.queue_free()
	var guard: CharacterBody3D = GUARD.instantiate()
	add_child(guard)
	guard.global_position = Vector3(80, 0, 1100)
	await _frames(10)
	guard._hands.carry_light(&"lantern")
	guard.set_physics_process(false)
	guard.velocity = Vector3(0, 0, 1.4)
	Sfx.recorded.clear()
	var steps := 0

	while steps < 10:
		guard.global_position += guard.velocity / 60.0
		guard._update_weapon(1.0 / 60.0)
		await _frames(1)
		steps = Sfx.recorded.filter(func(entry): return String(entry[0]).begins_with("step_")).size()

	var rattles := Sfx.recorded.filter(func(entry): return entry[0] == &"bail_rattle").size()
	Sfx.recording = false
	_check("L44 a hanging lantern creaks as the wind swings it; a guard's lantern rattles on every other step",
		creaks >= 1 and rattles >= 4 and rattles <= 6, "creaks %d, rattles %d in %d steps" % [creaks, rattles, steps])
	guard.queue_free()
	camera.queue_free()
	Sfx.silence()
	Sfx.enabled = false
	await _frames(3)


# ---------------------------------------------------------------------------
# The guards' lights, the brazier and the campfire, switched over
# ---------------------------------------------------------------------------

func _switched() -> void:
	Props.block(self, Vector3(0, -0.5, 1200), Vector3(80, 1, 40))
	var camera := Camera3D.new()
	add_child(camera)
	camera.global_position = Vector3(0, 1.8, 1206)
	camera.current = true

	# L45 a guard's lantern and torch are the new fixtures; a dropped one burns on, then dims out
	var man: CharacterBody3D = GUARD.instantiate()
	add_child(man)
	man.global_position = Vector3(0, 0, 1200)
	await _frames(10)
	man._hands.carry_light(&"lantern")
	await _frames(3)
	var lantern: Node3D = man._hands.lantern
	var lantern_name: String = str(lantern.get("fixture")) if lantern != null else "none"
	var hung: bool = lantern != null and lantern.get("fixture") == &"carried_lantern" and _hung_from(lantern) and is_equal_approx(lantern.energy, man._hands.LANTERN_ENERGY)
	man._hands.drop_lantern()
	await _frames(2)
	var dropped: Node3D = null

	for body in get_tree().get_nodes_in_group(&"dropped_lights"):
		if body is Node3D and body.global_position.distance_to(man.global_position) < 3.0:
			dropped = body

	var found := dropped != null
	var burning_on := false
	var dimmed := false

	if found:
		await _frames(int((man._hands.DROPPED_LIGHT_TIME - 1.0) * 60.0))
		burning_on = is_instance_valid(lantern) and lantern.light.light_energy > 0.1
		await _frames(int(4.1 * 60.0))
		dimmed = not is_instance_valid(dropped) or not is_instance_valid(lantern) or lantern.light.light_energy <= 0.001

	man._hands.carry_light(&"torch")
	await _frames(3)
	var torch: Node3D = man._hands.lantern
	var held_torch: bool = torch != null and torch.get("fixture") == &"carried_torch" and is_equal_approx(torch.energy, man._hands.TORCH_ENERGY)
	_check("L45 a guard's lantern is the carried lantern under its Hanging and his torch the carried torch; dropped, it burns on and dims out",
		hung and found and burning_on and dimmed and held_torch,
		"lantern %s hung %s, dropped %s burning on %s dimmed %s, torch %s" % [lantern_name, hung, found, burning_on, dimmed, torch.get("fixture") if torch != null else "none", ])
	man.queue_free()

	# L46 the brazier and the campfire are the new fixtures; a guard kicked into the brazier catches fire
	var fire: Area3D = FireScript.brazier(self, Vector3(20, 0, 1200))
	var camp: Node3D = Furnishings.campfire(self, Vector3(40, 0, 1200))
	var victim: CharacterBody3D = GUARD.instantiate()
	add_child(victim)
	victim.global_position = Vector3(20, 0, 1201.4)
	await _frames(20)
	var bowl: Node3D = fire.torch
	var brazier_ok: bool = bowl != null and bowl.get("fixture") == &"brazier" and bowl.embers_by_atmosphere
	var flame: Node3D = _burner_in(camp)
	var pointed := 0

	for spot in get_children():
		if spot.has_meta(&"fire") and spot.get_meta(&"fire") == flame:
			pointed += 1

	var camp_ok: bool = flame != null and flame.get("fixture") == &"campfire" and not flame.shadows and pointed == 3
	victim.kick(Vector3(0, 0, -5), null)
	var caught := false

	for i in 120:
		await _frames(1)

		if not is_instance_valid(victim) or victim.is_burning():
			caught = true
			break

	_check("L46 Fire.brazier is the brazier fixture (the Atmosphere's embers) and a guard kicked into it catches fire; the campfire is its fixture, unshadowed, its spots pointing at it",
		brazier_ok and camp_ok and caught,
		"brazier %s, campfire %s (%d spots on it), caught %s" % [bowl.get("fixture") if bowl != null else "none", flame.get("fixture") if flame != null else "none", pointed, caught])

	if is_instance_valid(victim):
		victim.queue_free()

	fire.get_parent().queue_free()
	camp.queue_free()
	camera.queue_free()
	await _frames(3)


## L47 every map's torches are fixtures: none left a bare flame.
func _maps() -> void:
	# The maps stand on their own floors, not the suite's.
	_ground.collision_layer = 0
	await _frames(2)
	var bare_in := {}
	var fixtures := 0
	var ring_cookies: Array = []

	for map_name in ["retro_showcase", "stealth_gym", "combat_gym", "combat_arena", "npc_gym", "npc_showcase"]:
		var map: Node = load("res://maps/%s.tscn" % map_name).instantiate()
		add_child(map)
		await _frames(120)
		var bare: Array[String] = []

		for burner in map.find_children("*", "", true, false):
			if not burner.is_in_group(&"torches"):
				continue

			if burner.get("fixture") == null or burner.fixture == &"":
				bare.append("%.1f,%.1f,%.1f" % [burner.global_position.x, burner.global_position.y, burner.global_position.z])
			else:
				fixtures += 1

		if not bare.is_empty():
			bare_in[map_name] = bare

		if map_name == "combat_arena":
			for burner in map.find_children("*", "", true, false):
				if burner.get("fixture") == &"hanging_lantern":
					ring_cookies.append(burner.light.light_projector != null)

		map.queue_free()
		await _frames(10)

	_ground.collision_layer = 1
	_check("L47 every torch in the six maps is a fixture (sconce, cresset, brazier, campfire...), none a bare flame",
		bare_in.is_empty() and fixtures > 0, "fixtures %d, bare %s" % [fixtures, bare_in])

	# L49 a fixture's bars can be taken off; the arena ring's lantern throws none
	var plain: Node3D = Lights.hanging_lantern(self, Vector3(0, 3, 1300), 0.6, {"cookie": false})
	var barred: Node3D = Lights.hanging_lantern(self, Vector3(3, 3, 1300), 0.6)
	await _frames(3)
	_check("L49 overrides can take a lantern's bars off, and combat_arena's ring lantern throws none (its light reaches the ring)",
		plain.light.light_projector == null and barred.light.light_projector != null and ring_cookies == [false],
		"plain barred %s, barred %s, ring lantern barred %s" % [plain.light.light_projector != null, barred.light.light_projector != null, ring_cookies])
	plain.queue_free()
	barred.queue_free()
	await _frames(2)


## L48 the gallery shows every fixture lit; its L key's cycle puts them all
## out, and three more bring them all back.
func _gallery() -> void:
	_ground.collision_layer = 0
	await _frames(2)
	var gallery: Node = load("res://maps/lights_gallery.tscn").instantiate()
	add_child(gallery)
	await _frames(180)
	var wanted: Array[String] = []

	for file in DirAccess.get_files_at("res://assets/props/lights/"):
		if file.ends_with(".json") and file != "chain_link.json":
			wanted.append(file.get_basename())

	var found := {}
	var fixtures: Array = []

	for node in gallery.find_children("*", "", true, false):
		if node.is_in_group(&"torches") and node.get("fixture") != null and node.fixture != &"":
			fixtures.append(node)
			found[String(node.fixture)] = true

	var missing := wanted.filter(func(n): return not found.has(n))
	var all_lit := not fixtures.is_empty() and fixtures.all(func(f): return f.is_lit())
	var all_out := false
	var lit_again := false

	if gallery.has_method("cycle_lights"):
		gallery.cycle_lights()
		await _frames(30)
		all_out = fixtures.all(func(f): return not is_instance_valid(f) or not f.is_lit())

		for i in 3:
			gallery.cycle_lights()
			await _frames(30)

		lit_again = fixtures.all(func(f): return not is_instance_valid(f) or f.is_lit())

	_check("L48 the lights gallery has every fixture, all lit; one turn of its L key puts them out, three more light them again",
		missing.is_empty() and all_lit and all_out and lit_again,
		"%d fixtures, missing %s, lit %s, out %s, lit again %s" % [fixtures.size(), missing, all_lit, all_out, lit_again])
	gallery.queue_free()
	await _frames(10)
	_ground.collision_layer = 1


## L50-L52: what the final review found.
func _reviewed() -> void:
	var camera := Camera3D.new()
	add_child(camera)
	camera.global_position = Vector3(0, 1.8, 1316)
	camera.current = true

	# L50 flames built in the same frame do not burn in step
	var a: Node3D = TorchScript.new()
	add_child(a)
	a.global_position = Vector3(0, 2, 1310)
	var b: Node3D = TorchScript.new()
	add_child(b)
	b.global_position = Vector3(4, 2, 1310)
	var hoop: Node3D = Lights.chandelier(self, Vector3(10, 4, 1310), 6, 1.0)
	await _frames(5)
	var torches_apart := 0
	var candles_apart := 0

	for i in 60:
		await get_tree().process_frame

		if a.frame != b.frame:
			torches_apart += 1

		var shown := {}

		for fx in hoop.flames:
			shown[fx.frame] = true

		if shown.size() > 1:
			candles_apart += 1

	_check("L50 two torches built together, and a chandelier's candles, burn out of step",
		torches_apart > 30 and candles_apart > 30, "torches apart %d of 60 frames, candles %d" % [torches_apart, candles_apart])
	a.queue_free()
	b.queue_free()
	hoop.queue_free()

	# L51 Godot leaves the props' Blender sources alone
	var imports := Array(DirAccess.get_files_at("res://assets/props/source/")).filter(func(f): return String(f).ends_with(".import"))
	var ignored := FileAccess.file_exists("res://assets/props/source/.gdignore")
	_check("L51 the props' Blender sources are not imported by Godot", ignored and imports.is_empty(),
		".gdignore %s, imports %d" % [ignored, imports.size()])

	# L52 a carried lantern's halo is not hidden by the man carrying it
	var man := CharacterBody3D.new()
	man.collision_layer = 2
	var body := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	body.shape = capsule
	body.position.y = 0.9
	man.add_child(body)
	add_child(man)
	man.global_position = Vector3(0, 0, 1320)
	var lamp: Node3D = Lights.carried_lantern()
	man.add_child(lamp)
	# Held close, in his shape; you on the far side of him.
	lamp.position = Vector3(0.2, 1.0, 0.0)
	camera.global_position = Vector3(-3.0, 1.0, 1320)
	camera.look_at(lamp.global_position)
	await _frames(30)
	var seen: float = lamp.corona.visibility if lamp.corona != null else -1.0
	_check("L52 a carried lantern's halo is not hidden by the man carrying it", seen > 0.5, "halo %.2f" % seen)
	man.queue_free()

	camera.queue_free()
	await _frames(3)


## L54-L64: the final review's minor findings.
func _minors() -> void:
	Props.block(self, Vector3(0, -0.5, 1400), Vector3(120, 1, 60))
	var camera := Camera3D.new()
	add_child(camera)
	camera.global_position = Vector3(0, 1.6, 1406)
	camera.current = true

	# L54 a lantern whose light is let down (a dropped one guttering) dims its halo and horn with it
	var dimmed: Node3D = Lights.carried_lantern()
	add_child(dimmed)
	dimmed.global_position = Vector3(0, 1.6, 1403)
	await _frames(20)
	dimmed.energy = dimmed.energy * 0.2
	await _frames(20)
	var horn: float = dimmed.glow_meshes[0].get_instance_shader_parameter(&"glow") if not dimmed.glow_meshes.is_empty() else -1.0
	var halo: float = dimmed.corona.quad.get_instance_shader_parameter(&"amount")
	_check("L54 a lantern let down to a fifth of its light dims its horn panes and its halo with it",
		horn > 0.1 and horn < 0.3 and halo < 0.35 and dimmed.corona.visibility > 0.9, "horn %.2f, halo %.2f (seen %.2f)" % [horn, halo, dimmed.corona.visibility])
	dimmed.queue_free()

	# L55 a hung fixture keeps the way it was turned, and swings downwind whichever way it faces
	var lamp: Node3D = Lights.oil_lamp(self, Vector3(4, 3, 1400), &"hanging", PI * 0.5, 0.5)
	await _frames(10)
	var facing: Vector3 = lamp.global_basis.z
	lamp.lean(Vector3(1, 0, 0))
	await _frames(90)
	var flame: Vector3 = lamp.global_transform * lamp.flame_points[0]
	_check("L55 a hung lamp turned a quarter keeps its turn and swings downwind",
		facing.distance_to(Vector3(1, 0, 0)) < 0.05 and flame.x - 4.0 > 0.02, "facing %s, flame %.3f m downwind" % [facing, flame.x - 4.0])
	lamp.queue_free()
	await _frames(2)

	# L56 a hung fixture leaves no nodes behind when freed
	var orphans_before := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var hung: Node3D = Lights.hanging_lantern(self, Vector3(8, 3, 1400), 0.6)
	await _frames(3)
	hung.queue_free()
	await _frames(3)
	var orphans_after := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	_check("L56 a hanging lantern leaves no stray nodes once freed", orphans_after <= orphans_before,
		"orphan nodes %d -> %d" % [orphans_before, orphans_after])

	# L57 the budget and the particles, started just as their level goes, start again in the next with every light kept
	for manager in [FireParticles.world_node(), LightBudget._world]:
		if manager != null and is_instance_valid(manager):
			manager.free()

	var doomed := Node3D.new()
	get_tree().root.add_child(doomed)
	# Built before the switch (nothing may be added to the tree while the
	# doomed level is the scene: the Retro pass would sweep it once freed).
	var early: Node3D = TorchScript.new()
	early.shadows = false
	add_child(early)
	early.global_position = Vector3(12, 2, 1400)
	await _frames(2)
	var own_scene := get_tree().current_scene
	get_tree().current_scene = doomed
	LightBudget.register(early)
	FireParticles.emit(self, &"ember", Vector3(12, 2, 1400), 1)
	doomed.free()
	get_tree().current_scene = own_scene
	var late: Node3D = TorchScript.new()
	add_child(late)
	late.global_position = Vector3(14, 2, 1400)
	FireParticles.emit(self, &"ember", Vector3(14, 2, 1400), 1)
	await _frames(5)
	var particles_world := FireParticles.world_node()
	var budget_world: Node = LightBudget._world
	var budget_ok: bool = budget_world != null and is_instance_valid(budget_world) and budget_world.is_inside_tree() and budget_world._burners.has(early) and budget_world._burners.has(late)
	_check("L57 managers begun as their level is freed begin again in the next, every light still counted",
		particles_world != null and particles_world.is_inside_tree() and budget_ok,
		"particles in the tree %s, budget in the tree %s" % [particles_world != null and particles_world.is_inside_tree(), budget_ok])

	# L58 a shadowed light taken out of the tree and put back is still in the budget
	remove_child(late)
	add_child(late)
	await _frames(2)
	_check("L58 a shadowed light taken out and put back is still counted by the budget",
		LightBudget._world != null and LightBudget._world._burners.has(late), "counted %s" % [LightBudget._world != null and LightBudget._world._burners.has(late)])
	early.queue_free()
	late.queue_free()

	# L59 a torch just past 3.2 m over a floor still finds it
	Lights.torch_at(self, Vector3(20, 3.21, 1400), 2.4, 9.0, false)
	await _frames(5)
	var stand := _fixture_near(Vector3(20, 1.5, 1400), 2.5)
	_check("L59 a torch 3.21 m over a floor stands on a cresset, not in the air",
		stand != null and stand.fixture == &"cresset_pole", "became %s" % [stand.fixture if stand != null else "a bare flame"])

	if stand != null:
		stand.queue_free()
	else:
		var left := _burner_near(Vector3(20, 3.21, 1400), 0.3)

		if left != null:
			left.queue_free()

	# L60 its snuff and douse sounds only when it really goes out
	var quiet: Node3D = TorchScript.new()
	add_child(quiet)
	quiet.global_position = Vector3(24, 2, 1400)
	await _frames(5)
	Sfx.recording = true
	Sfx.recorded.clear()
	quiet.kindle()
	quiet.put_out(&"snuff")
	quiet.kindle()
	quiet.put_out(&"douse")
	quiet.kindle()
	await _frames(5)
	var heard_early := Sfx.recorded.filter(func(e): return e[0] == &"snuff" or e[0] == &"douse").size()
	quiet.put_out(&"snuff")
	await _frames(5)
	var heard_snuff := Sfx.recorded.filter(func(e): return e[0] == &"snuff").size()
	Sfx.recording = false
	_check("L60 lit, put out and lit again in one frame makes no snuff or douse sound; put out for good, one snuff",
		heard_early == 0 and heard_snuff == 1, "sounds for a flame that never went out %d, snuffs %d" % [heard_early, heard_snuff])
	quiet.queue_free()

	# L61 put out at once, it leaves no smoke thread or winking coals behind
	var coals: Node3D = Lights.brazier(self, Vector3(28, 0, 1402))
	camera.global_position = Vector3(28, 1.6, 1406)
	await _frames(10)
	coals.put_out(&"douse")
	coals.put_out(&"snuff", true)
	var embers_before := FireParticles.emitted(&"ember")
	var smoke_before := FireParticles.emitted(&"smoke")
	await _frames(22 * 60)
	_check("L61 doused then put out at once, a brazier winks no embers and trails no smoke",
		FireParticles.emitted(&"ember") == embers_before and FireParticles.emitted(&"smoke") == smoke_before,
		"embers %d, smoke %d after" % [FireParticles.emitted(&"ember") - embers_before, FireParticles.emitted(&"smoke") - smoke_before])
	coals.queue_free()
	camera.global_position = Vector3(0, 1.6, 1406)

	# L62 a wall fixture built in the same frame as its walls finds the ceiling for its soot
	Props.block(self, Vector3(40, 2, 1399.8), Vector3(4, 4, 0.4))
	Props.block(self, Vector3(40, 3.6, 1400.5), Vector3(4, 0.4, 2))
	var reach := float(LightFixture.spec(&"wall_torch")["sockets"]["flame"][0][2])
	var sooty: Node3D = Lights.wall_torch(self, Vector3(40, 2.4, 1400 + reach), Vector3.BACK)
	await _frames(10)
	var soot_height: float = sooty.soot.size.z if sooty.soot != null else -1.0
	_check("L62 a sconce built with its walls reaches its soot up to the ceiling a metre above its flame", soot_height > 1.0,
		"soot %.2f m high" % soot_height)
	sooty.queue_free()

	# L63 torch_at rolls the global dice no more than a bare torch does
	seed(12345)
	randf()
	var second := randf()
	seed(12345)
	Lights.torch_at(self, Vector3(50, 2.2, 1400), 2.4, 9.0, false)
	await _frames(5)
	var next := randf()
	_check("L63 a torch fitted by torch_at draws from the global dice only as a bare torch did", is_equal_approx(next, second),
		"next draw %.5f (a bare torch's %.5f)" % [next, second])
	var fitted := _fixture_near(Vector3(50, 1.5, 1400), 2.5)

	if fitted != null:
		fitted.queue_free()

	# L64 every fixture's .json carries every key
	var keys := ["burner", "sockets", "stretch", "shadow_parts", "soot", "cookie", "family", "mount"]
	var lacking: Array[String] = []

	for file in DirAccess.get_files_at("res://assets/props/lights/"):
		if file.ends_with(".json"):
			var data := LightFixture.spec(StringName(file.get_basename()))

			for key in keys:
				if not data.has(key):
					lacking.append("%s:%s" % [file.get_basename(), key])

	_check("L64 every fixture's .json carries every key the game reads", lacking.is_empty(), "lacking %s" % [lacking])
	camera.queue_free()
	await _frames(3)


## L65 a level's own torch (you may put it out; the guards light it again),
## fitted to its wall as a sconce.
func _douseable() -> void:
	Props.block(self, Vector3(0, -0.5, 1500), Vector3(40, 1, 20))
	Props.block(self, Vector3(0, 2, 1499.7), Vector3(4, 4, 0.4))
	var camera := Camera3D.new()
	add_child(camera)
	camera.global_position = Vector3(0, 1.6, 1506)
	camera.current = true
	var flame_at := Vector3(0, 2.2, 1500.0)
	Lights.torch_at(self, flame_at, 2.4, 9.0, false, {"can_douse": true})
	await _frames(5)
	var sconce := _fixture_near(flame_at, 1.0)

	if sconce == null:
		_check("L65 a level's own torch as a sconce: reached at its flame, left out when you put it out, relit, doused by a flask", false, "no sconce")
		camera.queue_free()
		return

	var own: bool = sconce.fixture == &"wall_torch" and sconce.can_douse and sconce.is_in_group(&"lights")
	var reached: bool = sconce._reach != null and sconce._reach.global_position.distance_to(sconce.flame_position()) < 0.01
	var someone := Node3D.new()
	add_child(someone)
	sconce.put_out(someone)
	await _frames(10)
	var left: bool = not sconce.lit and sconce.left_out() and sconce._reach.collision_layer == 0
	sconce.relight(null)
	await _frames(40)
	var relit: bool = sconce.lit and not sconce.left_out() and sconce._reach.collision_layer == TorchScript.REACH_LAYER
	ThrownTool.splash(self, sconce.flame_position() + Vector3(0, 0, 0.1), Vector3.BACK, null)
	await _frames(3)
	var doused: bool = not sconce.lit and sconce._cool > 0.5
	_check("L65 a level's own torch as a sconce: reached at its flame, left out when you put it out, relit, doused by a flask",
		own and reached and left and relit and doused, "its own %s, reached at the flame %s, left out %s, relit %s, doused %s" % [own, reached, left, relit, doused])
	someone.queue_free()
	sconce.queue_free()
	camera.queue_free()
	await _frames(3)


## Whether `node` hangs from a Hanging (a lantern swinging from a fist).
func _hung_from(node: Node) -> bool:
	var up := node.get_parent()

	while up != null:
		if up.get_script() == HangingScript:
			return true

		up = up.get_parent()

	return false


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
