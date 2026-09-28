extends Node3D
## The night and its weather (scripts/Night): the moon and its clouds, the
## states and their easing, the scripted veil, crossings, lightning, the
## noise floor, wetness, fog, the roof test, the wind, its own dice.
##   Godot --headless --fixed-fps 60 --path . res://tests/night_test.tscn

const NightScript := preload("res://scripts/Night/Night.gd")
const SoundBus := preload("res://scripts/StimuliSystem/SoundBus.gd")
const LightProbe := preload("res://scripts/StimuliSystem/LightProbe.gd")
const Props := preload("res://scripts/Interaction/Props.gd")
const AtmosphereScript := preload("res://scripts/Visual/Atmosphere.gd")
const TimeFx := preload("res://scripts/Visual/TimeFx.gd")
const GuardScript := preload("res://scripts/AISystem/Guard.gd")
const GUARD := preload("res://Guard.tscn")

## Hears every sound event (the noise floor).
class Ear:
	var heard: Array = []

	func hear_sound(event: Dictionary) -> void:
		heard.append(event)


var results: Array[String] = []
var moon: DirectionalLight3D
var environment: Environment
var atmosphere: Node3D


func _ready() -> void:
	_stage()
	await _frames(3)
	await _moon_and_clouds()
	await _states()
	await _lightning()
	await _ground()
	await _dice()
	print("\n==== RESULTS ====")

	for r in results:
		print(r)

	get_tree().quit()


func _stage() -> void:
	Props.block(self, Vector3(0, -0.5, 0), Vector3(80, 1, 80))
	# A shelter: four posts and a roof over (10, 0, 0).
	Props.block(self, Vector3(10, 3.1, 0), Vector3(4, 0.2, 4))

	for corner in [Vector3(8.2, 1.5, -1.8), Vector3(11.8, 1.5, -1.8), Vector3(8.2, 1.5, 1.8), Vector3(11.8, 1.5, 1.8)]:
		Props.block(self, corner, Vector3(0.3, 3.0, 0.3))

	environment = Environment.new()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.3, 0.32, 0.4)
	environment.ambient_light_energy = 0.1
	environment.volumetric_fog_density = 0.01
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	moon = DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.65, 0.95)
	moon.light_energy = 0.4
	moon.shadow_enabled = true
	add_child(moon)
	moon.global_basis = Basis.looking_at(Vector3(0.62, -0.5, 0.6).normalized(), Vector3.UP)
	atmosphere = AtmosphereScript.new()
	add_child(atmosphere)


func _night(start: StringName = &"clear", seed := 5) -> Node:
	var night: Node = NightScript.new()
	night.moon = moon
	night.environment = environment
	night.seed = seed
	night.start = start
	add_child(night)
	return night


# ---------------------------------------------------------------------------
# N: the moon and its clouds
# ---------------------------------------------------------------------------

func _moon_and_clouds() -> void:
	var night := _night(&"clear")
	await _frames(2)

	# N1 clear: the moon unclouded, at its full light
	var clear_cover: float = night.cloud_cover()
	_check("N1 clear, the moon is unclouded and at its full light",
		clear_cover < 0.2 and absf(moon.light_energy - 0.4) < 0.02, "cover %.2f, energy %.3f" % [clear_cover, moon.light_energy])

	# N2 a veil: drifts over in about 4 s, holds, drifts off; the light 15%
	night.cover_moon(3.0)
	await _seconds(1.0)
	var coming: float = night.cloud_cover()
	await _seconds(3.5)
	var covered: float = night.cloud_cover()
	var dimmed: float = moon.light_energy
	var ambient_dimmed: float = environment.ambient_light_energy
	await _seconds(2.0)
	var still: float = night.cloud_cover()
	await _seconds(6.0)
	var after: float = night.cloud_cover()
	_check("N2 a veil drifts over the moon in about 4 s, holds it covered, and drifts off; covered, the moon is 15% and the ambient 90%",
		coming < 0.9 and covered > 0.99 and still > 0.99 and after < 0.2 and absf(dimmed - 0.4 * 0.15) < 0.01 and absf(ambient_dimmed - 0.09) < 0.005,
		"at 1 s %.2f, 4.5 s %.2f, 6.5 s %.2f, 12.5 s %.2f; energy %.3f, ambient %.3f" % [coming, covered, still, after, dimmed, ambient_dimmed])

	# N3 the sky draws the clouds the light reads: one projection, the same
	# constants in the shader
	var code := (load("res://scripts/Night/night_sky.gdshader") as Shader).code
	var same := true

	var constants := {"CLOUD_CURVE": NightScript.CLOUD_CURVE, "CLOUD_SCALE": NightScript.CLOUD_SCALE, "CLOUD_SOFT": NightScript.CLOUD_SOFT,
		"VEIL_RADIUS": NightScript.VEIL_RADIUS, "VEIL_EDGE": NightScript.VEIL_EDGE}

	for name in constants:
		var found := RegEx.create_from_string("const float %s = ([0-9.]+);" % name).search(code)
		same = same and found != null and absf(float(found.get_string(1)) - float(constants[name])) < 0.0001

	var up_uv: Vector2 = night.sky_uv(Vector3.UP)
	var wrapped: float = night.field_at(up_uv + Vector2(3.0, -2.0))
	_check("N3 the sky shader and the moon's light share one cloud projection (its constants match, the field wraps)",
		same and absf(wrapped - night.field_at(up_uv)) < 0.001, "constants match %s" % same)

	# N4 in clear, now and then a cloud crosses the moon: dark 15 to 25 s,
	# every 60 to 90 s
	var dark := 0.0
	var darks := []
	var starts := []
	var t := 0.0

	while t < 300.0:
		await get_tree().process_frame
		t += 1.0 / 60.0

		if night.cloud_cover() > 0.9:
			if dark == 0.0:
				starts.append(t)
			dark += 1.0 / 60.0
		elif dark > 0.0:
			darks.append(snappedf(dark, 0.1))
			dark = 0.0

	var gaps4 := []

	for i in range(1, starts.size()):
		gaps4.append(snappedf(starts[i] - starts[i - 1], 0.1))

	_check("N4 in clear a cloud crosses the moon every 60-90 s, dark for 15-25 s",
		darks.size() >= 3 and darks.all(func(d): return d >= 14.9 and d <= 25.1) and gaps4.all(func(g): return g >= 59.9 and g <= 90.1),
		"dark spells %s, a crossing every %s s" % [darks, gaps4])

	# N5 the sky wastes nothing: no TIME in it (a sky using TIME re-filters a
	# 256 radiance map every frame) and a small radiance map nothing reads
	var sky: Sky = environment.sky
	var sky_code := (load("res://scripts/Night/night_sky.gdshader") as Shader).code
	_check("N5 the sky neither re-filters a big radiance map every frame nor reads TIME",
		sky != null and sky.radiance_size == Sky.RADIANCE_SIZE_32 and sky.process_mode != Sky.PROCESS_MODE_REALTIME and not sky_code.contains("TIME"),
		"radiance %s, mode %s, TIME %s" % [sky.radiance_size if sky else -1, sky.process_mode if sky else -1, sky_code.contains("TIME")])
	night.queue_free()
	await _frames(2)


# ---------------------------------------------------------------------------
# W: the states
# ---------------------------------------------------------------------------

func _states() -> void:
	var night := _night(&"clear")
	await _frames(2)

	# W1 to(state, seconds) eases, never a jump; 0 s jumps
	night.to(&"storm", 2.0)
	var biggest := 0.0
	var was: float = night.rain()

	for f in 150:
		await get_tree().process_frame
		biggest = maxf(biggest, absf(night.rain() - was))
		was = night.rain()

	var reached: bool = absf(night.rain() - 1.0) < 0.001 and night.state == &"storm"
	night.to(&"clear", 0.0)
	await _frames(1)
	_check("W1 a change of weather eases over its seconds (no step over 3% a frame); 0 s jumps",
		reached and biggest <= 0.03 and night.rain() == 0.0, "reached %s, biggest step %.3f, after the jump %.2f" % [reached, biggest, night.rain()])

	# W2 the noise floor: a storm leaves a sound 0.37 of its reach
	var ear := Ear.new()
	SoundBus.add_listener(ear)
	SoundBus.emit_sound(Vector3.ZERO, 60.0, self, &"test")
	night.to(&"storm", 0.0)
	await _frames(1)
	SoundBus.emit_sound(Vector3.ZERO, 60.0, self, &"test")
	night.to(&"drizzle", 0.0)
	await _frames(1)
	SoundBus.emit_sound(Vector3.ZERO, 60.0, self, &"test")
	SoundBus.remove_listener(ear)
	var reaches := ear.heard.map(func(e): return float(e["range"]))
	_check("W2 rain masks sound: under a storm (+10 dB) a sound carries 0.37 of its reach, under drizzle (+3 dB) 0.74",
		reaches.size() == 3 and absf(reaches[1] / reaches[0] - 0.371) < 0.02 and absf(reaches[2] / reaches[0] - 0.743) < 0.02,
		"%s" % [reaches.map(func(r): return snappedf(r, 0.01))])

	# W3 the wind: a storm blows far harder than a clear night
	night.to(&"clear", 0.0)
	var calm := await _wind_over(2.0)
	night.to(&"storm", 0.0)
	var storm := await _wind_over(2.0)
	_check("W3 a storm's wind leans the flames far harder than a clear night's (the wind's strength 4x or more)",
		storm >= 4.0 * calm and calm > 0.0, "clear %.2f, storm %.2f" % [calm, storm])

	# W4 fog: four times the level's fog, and mist banks over the ground
	night.to(&"fog", 0.0)
	await _frames(2)
	var mist: float = night.mist_density()
	_check("W4 fog: the level's fog four times over, mist banks lying on the ground",
		absf(environment.volumetric_fog_density - 0.04) < 0.001 and mist > 0.0, "fog %.3f, mist %.2f" % [environment.volumetric_fog_density, mist])

	# W5 F4's cycle: clear, cloudy, drizzle, shower, storm, fog, clear
	night.to(&"clear", 0.0)
	var cycled := []

	for i in 6:
		night.cycle()
		cycled.append(night.state)

	_check("W5 the cycle goes clear, cloudy, drizzle, shower, storm, fog and round",
		cycled == [&"cloudy", &"drizzle", &"shower", &"storm", &"fog", &"clear"], "%s" % [cycled])

	# W7 the clouds drift with the wind: a cloud seen now toward d is seen a
	# moment later a little downwind of d
	atmosphere.force_wind(Vector3(1.0, 0.0, 0.0))
	night.to(&"shower", 0.0)
	await _frames(2)
	var d7 := Vector3(0.0, 0.8, -0.6).normalized()
	var seen7: Vector2 = night.sky_uv(d7)
	await _seconds(2.0)
	var downwind7 := Vector3(0.05, 0.8, -0.6).normalized()
	var upwind7 := Vector3(-0.05, 0.8, -0.6).normalized()
	atmosphere.force_wind(null)
	_check("W7 the clouds drift with the wind (the way the rain slants and the flames lean)",
		night.sky_uv(downwind7).distance_to(seen7) < night.sky_uv(upwind7).distance_to(seen7), "downwind %.4f, upwind %.4f" % [night.sky_uv(downwind7).distance_to(seen7), night.sky_uv(upwind7).distance_to(seen7)])

	# R1 the rain fades near the lens (no bars across a close shot)
	var drop: StandardMaterial3D = (night.get_node("Rain/Drops") as GPUParticles3D).draw_pass_1.surface_get_material(0)
	_check("R1 raindrops fade out within a metre of the camera, fully seen from 3 m",
		drop.distance_fade_mode != BaseMaterial3D.DISTANCE_FADE_DISABLED and drop.distance_fade_min_distance >= 1.0 and drop.distance_fade_max_distance <= 3.5,
		"fade %s from %.1f to %.1f m" % [drop.distance_fade_mode, drop.distance_fade_min_distance, drop.distance_fade_max_distance])

	# W6 a change asked for later waits for its time
	night.to(&"clear", 0.0)
	night.to(&"shower", 0.0, 1.0)
	await _seconds(0.5)
	var waited: StringName = night.state
	await _seconds(0.7)
	_check("W6 a change asked for in a second waits its second", waited == &"clear" and night.state == &"shower", "%s then %s" % [waited, night.state])
	night.to(&"clear", 0.0)
	night.queue_free()
	await _frames(2)


func _wind_over(seconds: float) -> float:
	var total := 0.0
	var n := 0

	for f in int(seconds * 60.0):
		await get_tree().process_frame
		total += (atmosphere.wind() as Vector3).length()
		n += 1

	return total / float(maxi(n, 1))


# ---------------------------------------------------------------------------
# L: lightning
# ---------------------------------------------------------------------------

func _lightning() -> void:
	var night := _night(&"storm")
	await _frames(2)
	var flashes := []
	var thunders := []
	night.flashed.connect(func() -> void: flashes.append(TimeFx.real_time()))
	night.thundered.connect(func(delay: float) -> void: thunders.append(delay))

	# L1 a flash: the moon's light six times over, twice, gone in 0.2 s; a
	# man in the open reads it
	var open := Vector3(0, 1.2, 0)
	var before := LightProbe.light_at(self, open)
	var base: float = moon.light_energy
	night.flash()
	await _frames(1)
	var peak: float = moon.light_energy
	var lit := LightProbe.light_at(self, open)
	await _seconds(0.3)
	var after: float = moon.light_energy
	_check("L1 a flash adds five times the unclouded moon's light (clouds or none) and is gone within 0.2 s; a man in the open is lit by it",
		absf(peak - (base + 0.4 * 5.0)) < 0.05 and absf(after - base) < 0.01 and lit > before + 0.2, "base %.2f, peak %.2f, after %.2f; light %.2f -> %.2f" % [base, peak, after, before, lit])

	# L2 over a minute of storm: flashes 20 to 40 s apart, thunder 1 to 4 s
	# after each
	flashes.clear()
	thunders.clear()
	await _seconds(95.0)
	var gaps := []

	for i in range(1, flashes.size()):
		gaps.append(snappedf(flashes[i] - flashes[i - 1], 0.1))

	_check("L2 in a storm lightning comes every 20-40 s, its thunder 1-4 s after",
		flashes.size() >= 2 and gaps.all(func(g): return g >= 19.9 and g <= 40.1) and thunders.size() >= flashes.size() - 1 and thunders.all(func(d): return d >= 1.0 and d <= 4.0),
		"flashes %d, gaps %s, thunder after %s" % [flashes.size(), gaps, thunders.map(func(d): return snappedf(d, 0.1))])
	night.queue_free()
	await _frames(2)


# ---------------------------------------------------------------------------
# G: the ground: wetness, the roof
# ---------------------------------------------------------------------------

func _ground() -> void:
	var night := _night(&"clear")
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.5, 0.5, 0.5)
	stone.roughness = 0.85
	night.register_wet(stone)
	await _frames(2)

	# G1 wet: it rises toward the rain over about 30 s, and dries slowly
	night.to(&"storm", 0.0)
	await _seconds(10.0)
	var rising: float = night.wetness
	await _seconds(22.0)
	var soaked: float = night.wetness
	var dark_stone: float = stone.albedo_color.r
	var sheen: float = stone.roughness
	night.to(&"clear", 0.0)
	await _seconds(12.0)
	var drying: float = night.wetness
	_check("G1 the rain wets the ground over about 30 s (stone darkens to 0.7, its sheen to roughness 0.35) and it dries slowly",
		rising > 0.25 and rising < 0.45 and soaked > 0.99 and absf(dark_stone - 0.35) < 0.01 and absf(sheen - 0.35) < 0.01 and drying > 0.85 and drying < 0.95,
		"10 s %.2f, 32 s %.2f (stone %.2f, roughness %.2f), 12 s dry %.2f" % [rising, soaked, dark_stone, sheen, drying])

	# G3 a puddle: a foot in it splashes once the ground is wet (0.3), not
	# before, and not beside it
	var puddled := _night(&"clear")
	puddled.puddles = [Vector3(-10, 0.02, 10)] as Array[Vector3]
	await _frames(2)
	puddled.wetness = 0.2
	var damp: bool = puddled.splashes_at(Vector3(-10, 0.0, 10))
	puddled.wetness = 0.5
	var wet: bool = puddled.splashes_at(Vector3(-10.4, 0.0, 10.3))
	var beside: bool = puddled.splashes_at(Vector3(-12.5, 0.0, 10))
	_check("G3 a foot in a puddle splashes once the ground is wet, not before and not beside it",
		not damp and wet and not beside, "damp %s, wet %s, beside %s" % [damp, wet, beside])
	puddled.queue_free()

	# G4 a level made again (watch it again): what a night wetted is dry once
	# it goes, and the next night takes it as dry
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.4, 0.4, 0.4)
	iron.roughness = 0.9
	var first := _night(&"storm")
	first.register_wet(iron)
	first.wetness = 1.0
	await _frames(2)
	var soaked4: float = iron.albedo_color.r
	first.queue_free()
	await _frames(2)
	var after_free: float = iron.albedo_color.r
	var second := _night(&"clear")
	second.register_wet(iron)
	second.wetness = 1.0
	await _frames(2)
	var soaked_again: float = iron.albedo_color.r
	second.queue_free()
	await _frames(2)
	_check("G4 a night gone leaves the ground dry, and the next wets it from dry (no darker every time)",
		absf(soaked4 - 0.28) < 0.01 and absf(after_free - 0.4) < 0.001 and absf(soaked_again - 0.28) < 0.01 and absf(iron.roughness - 0.9) < 0.001,
		"wet %.3f, gone %.3f, wet again %.3f" % [soaked4, after_free, soaked_again])

	# G5 a guard's foot in a puddle after rain is in water (the level's night:
	# the one this part of the suite made)
	var guard_night := night
	guard_night.puddles = [Vector3(-14, 0.02, -14)] as Array[Vector3]
	GuardScript.randomize_on = false
	var guard: CharacterBody3D = GUARD.instantiate()
	add_child(guard)
	guard.global_position = Vector3(-14, 0.0, -14)
	await _frames(3)
	guard_night.wetness = 0.0
	guard.set("_floor_checked_at", -100.0)
	var dry5: String = guard.floor_surface()
	guard_night.wetness = 0.8
	var wet5: String = guard.floor_surface()
	guard.queue_free()
	guard_night.wetness = 0.0
	guard_night.puddles = [] as Array[Vector3]
	GuardScript.randomize_on = true
	await _frames(2)
	_check("G5 a guard's foot in a puddle after rain steps in water", dry5 != "water" and wet5 == "water", "dry %s, wet %s" % [dry5, wet5])

	# G2 the roof: under the shelter is indoors, the open is not
	_check("G2 under a roof is indoors, the open yard is not",
		night.indoors(Vector3(10, 1.0, 0)) and not night.indoors(Vector3(0, 1.0, 0)), "under %s, open %s" % [night.indoors(Vector3(10, 1.0, 0)), night.indoors(Vector3(0, 1.0, 0))])
	night.queue_free()
	await _frames(2)


# ---------------------------------------------------------------------------
# D: its own dice
# ---------------------------------------------------------------------------

func _dice() -> void:
	# (made with the level, before the world's dice are seeded: a particle
	# system takes one roll of them as it is made, as every level's do)
	var night := _night(&"clear", 9)
	await _frames(2)
	seed(4242)
	var expected := randi()
	seed(4242)
	night.to(&"storm", 5.0)
	await _seconds(45.0)
	night.to(&"clear", 0.0)
	await _frames(2)
	var kept := randi() == expected
	night.queue_free()
	await _frames(2)
	_check("D1 the weather rolls its own dice: rain starting, a stormy minute's lightning and clearing leave the world's where they were", kept, "")


# ---------------------------------------------------------------------------

func _seconds(seconds: float) -> void:
	for f in int(round(seconds * 60.0)):
		await get_tree().process_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
