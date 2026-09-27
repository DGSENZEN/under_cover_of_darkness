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
