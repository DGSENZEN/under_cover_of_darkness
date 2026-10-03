extends Node3D
## Level weather: shared cloud field/sky, moon and ambient light, rain, wet surfaces, wind, fog, lightning, and noise masking.
## Transitions use scaled game time and a private weather RNG; moon dimming samples the same cloud projection as the sky.
## Set moon/environment before adding to the tree. Exit dries registered shared materials and resets SoundBus masking.
## Zones supplies zone_fog/zone_fog_color; weather multiplies that local atmosphere.

const SoundBus := preload("res://scripts/StimuliSystem/SoundBus.gd")
const Materials := preload("res://scripts/Visual/Materials.gd")
const NightSkyScript := preload("res://scripts/Night/NightSky.gd")
const RainScript := preload("res://scripts/Night/Rain.gd")
const NightSoundScript := preload("res://scripts/Night/NightSound.gd")

## Each state: cloud cover (0..1), rain (0..1), wind (m/s), fog (times the
## level's own), the noise floor (dB), whether lightning strikes.
const STATES := {
	&"clear": {"cover": 0.15, "rain": 0.0, "wind": 1.0, "fog": 1.0, "mask": 0.0, "lightning": false},
	&"cloudy": {"cover": 0.5, "rain": 0.0, "wind": 2.0, "fog": 1.0, "mask": 0.0, "lightning": false},
	&"drizzle": {"cover": 0.65, "rain": 0.25, "wind": 2.0, "fog": 1.0, "mask": 3.0, "lightning": false},
	&"shower": {"cover": 0.8, "rain": 0.6, "wind": 4.0, "fog": 1.25, "mask": 6.0, "lightning": false},
	&"rain": {"cover": 0.9, "rain": 0.8, "wind": 5.5, "fog": 1.3, "mask": 8.0, "lightning": false},
	&"storm": {"cover": 0.95, "rain": 1.0, "wind": 8.0, "fog": 1.6, "mask": 10.0, "lightning": true},
	&"fog": {"cover": 0.4, "rain": 0.0, "wind": 0.5, "fog": 4.0, "mask": 0.0, "lightning": false},
}
const ORDER := [&"clear", &"cloudy", &"drizzle", &"shower", &"rain", &"storm", &"fog"]
const EASED := ["cover", "rain", "wind", "fog", "mask"]

## Under full cloud the moon gives this much of its light, the sky's ambient
## this much of its own.
const CLOUDED := 0.15
const AMBIENT_CLOUDED := 0.9

## The cloud field: a seamless noise image, projected on a plane overhead
## (the view's xz over its height plus CLOUD_CURVE, times CLOUD_SCALE), its
## edges CLOUD_SOFT wide; the wind carries it CLOUD_DRIFT a second per m/s.
## The sky shader holds the same projection and filtered density images.
const FIELD := 256
const CLOUD_CURVE := 0.25
const CLOUD_SCALE := 0.35
const CLOUD_SOFT := 0.12
const CLOUD_DRIFT := 0.0025
## Sparse cloud bellies may be opaque even on a clear night.
const CLOUD_CONTRAST := 2.0
const MOON_RADIUS := 0.0244

## Lightning in a storm this often (s); a flash's light, as [until s, times
## the unclouded moon's light, added to it]; its thunder this long after (s).
const LIGHTNING_EVERY := Vector2(20.0, 40.0)
const FLASH := [[0.06, 6.0], [0.1, 1.5], [0.14, 6.0]]
const THUNDER_AFTER := Vector2(1.0, 4.0)

## Wet: rising to the rain over WET_RISE s, drying over WET_DRY s; a wet
## surface darkens to WET_DARKEN of its colour, its roughness to WET_ROUGH.
const WET_RISE := 30.0
const WET_DRY := 120.0
const WET_DARKEN := 0.7
const WET_ROUGH := 0.15
## Puddles show from this wetness, and splash underfoot from PUDDLE_SPLASH.
const PUDDLE_FROM := 0.1
const PUDDLE_SPLASH := 0.3
const PUDDLE_SIZE := 2.4

## How far a map's haze (its depth fog) still reaches in thick fog, as a
## share of its clear night's.
const HAZE_CLOSED := 0.3
## The mist banks' density in thick fog.
const MIST := 0.2
## Thick fog greys the level's fog colour toward moonlit silver (this much
## at its thickest) and the moon scatters this much less in it.
const FOG_SILVER := Color(0.74, 0.76, 0.79)
const FOG_GREYED := 0.85
const FOG_SCATTER := 0.45
## High thin cloud on a clear night: this much of it at no cover, none from
## CIRRUS_GONE.
const CIRRUS := 0.4
const CIRRUS_GONE := 0.6
## A flash's place: anywhere round the sky, this high (rad); its bolt drawn
## while the flash is at least this bright (times the moon).
const FLASH_ELEVATION := Vector2(0.12, 0.38)
const BOLT_FROM := 3.0
## In a flash the rain-thick air lights this many times over at most (the
## ground takes the whole flash; the air would white the sky out).
const FLASH_AIR := 1.5
## The eye opens in the rain: the picture's exposure this many times over
## under a full storm (a look only; the lights stay as they are).
const WET_EYE := 1.35
## The roof test: a ray this far up.
const INDOORS_REACH := 30.0
## The wind's m/s to Atmosphere's strength (1 as it was made: a shower).
const WIND_STRENGTH := 0.25

signal state_changed(state: StringName)
signal flashed
## Thunder, `delay` s after its flash.
signal thundered(delay: float)

@export var moon: DirectionalLight3D
@export var environment: Environment
## Its dice (0: one roll from the world's).
@export var seed := 0
@export var start: StringName = &"clear"
## Low spots where puddles gather; boxes where mist lies in fog.
@export var puddles: Array[Vector3] = []
@export var mist_boxes: Array[AABB] = []
## The map's own skyline (tools/skyline: a picture round the horizon); ""
## the showcase's.
@export var skyline := ""
## The comet across this map's sky (night_sky.gdshader; 0 none): an omen.
@export var comet := 0.0
## The aurora low in this map's north (night_sky.gdshader; 0 none).
@export var aurora := 0.0

var state: StringName = &"clear"
var wetness := 0.0
## The atmosphere zone the camera is in (scripts/Level/Zones.gd): its fog,
## times the level's and the weather's, and its colour.
var zone_fog := 1.0
var zone_fog_color := Color(0, 0, 0, 0)

var _now := {}
var _from := {}
var _to := {}
var _t := 0.0
var _over := 0.0
var _pending: Array = []
var _clock := 0.0
var _rng := RandomNumberGenerator.new()
## (The flash's place from dice of its own: the weather's run of rolls stays
## as it was.)
var _sky_rng := RandomNumberGenerator.new()
var _flash_dir := Vector3(0.0, 0.3, -1.0).normalized()
var _bolt_seed := 0.0
var _fog_albedo_base := Color(1, 1, 1)
var _exposure_base := 1.0
var _moon_scatter_base := 1.0
var _field: Image
var _field_texture: ImageTexture
var _offset := Vector2.ZERO
var _lightning_in := INF
var _flash_t := INF
var _thunder_in := INF
var _thunder_delay := 0.0
var _moon_base := 1.0
var _ambient_base := 1.0
var _fog_base := 0.01
var _haze_end_base := 0.0
var _wet := {}
var _wet_shown := -1.0
var _registered_in := 0.0
var _sky: RefCounted
var _rain: Node3D
var _sound: Node
var _mist: Array[FogVolume] = []
var _decals: Array[Decal] = []


func _ready() -> void:
	_rng.seed = seed if seed != 0 else randi()
	_sky_rng.seed = _rng.seed ^ 0x5eed
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.012
	noise.fractal_octaves = 4
	_field = noise.get_seamless_image(FIELD, FIELD, false, false, 0.1, true)
	_field.convert(Image.FORMAT_L8)
	_field_texture = ImageTexture.create_from_image(_field)

	if moon != null:
		_moon_base = moon.light_energy
		_moon_scatter_base = moon.light_volumetric_fog_energy

	if environment != null:
		_ambient_base = environment.ambient_light_energy
		_fog_base = environment.volumetric_fog_density
		_fog_albedo_base = environment.volumetric_fog_albedo
		_exposure_base = environment.tonemap_exposure
		_haze_end_base = environment.fog_depth_end if environment.fog_enabled and environment.fog_mode == Environment.FOG_MODE_DEPTH else 0.0
		_sky = NightSkyScript.new(environment, _field_texture, skyline)
		_sky.material.set_shader_parameter("moon_radius", MOON_RADIUS)
		_sky.material.set_shader_parameter("comet", comet)
		_sky.material.set_shader_parameter("aurora", aurora)

	_rain = RainScript.new()
	_rain.name = "Rain"
	add_child(_rain)
	_sound = NightSoundScript.new()
	_sound.name = "Sound"
	add_child(_sound)
	_make_puddles()
	_make_mist()
	_jump(start)
	_register_shared()


func _exit_tree() -> void:
	SoundBus.masking_db = 0.0

	# What it wetted, dry again (the shared surfaces outlive the level).
	for material in _wet:
		if is_instance_valid(material):
			var dry: Array = _wet[material]
			material.albedo_color = dry[0]
			material.roughness = float(dry[1])


## Transitions to a STATES key over seconds (game time); nonpositive duration jumps immediately.
## after > 0 queues a delayed change; an immediate request clears pending changes. Unknown keys warn and leave state unchanged.
## Updates state/emits state_changed when the transition starts, before its eased values finish.
func to(to_state: StringName, seconds: float, after := 0.0) -> void:
	if not STATES.has(to_state):
		push_warning("Night: no weather '%s'" % to_state)
		return

	if after > 0.0:
		_pending.append([_clock + after, to_state, seconds])
		_pending.sort_custom(func(a, b): return a[0] < b[0])
		return

	_pending.clear()

	if seconds <= 0.0:
		_jump(to_state)
		return

	_from = _now.duplicate()
	_to = _values(to_state)
	_t = 0.0
	_over = seconds
	_set_state(to_state)


## The next state in ORDER, over 2 s (the showcase's F4).
func cycle() -> void:
	to(ORDER[(ORDER.find(state) + 1) % ORDER.size()], 2.0)


## Deprecated compatibility for old story/city scripts. Clouds now exist
## continuously and travel only with the wind; a cue cannot spawn, hold or
## teleport a cloud onto the moon. Weather changes remain available via to().
func cover_moon(_hold: float) -> void:
	pass


## A lightning flash, now, somewhere in the sky; its thunder follows.
func flash() -> void:
	_flash_t = 0.0
	var round := _sky_rng.randf_range(0.0, TAU)
	var high := _sky_rng.randf_range(FLASH_ELEVATION.x, FLASH_ELEVATION.y)
	_flash_dir = Vector3(sin(round) * cos(high), sin(high), cos(round) * cos(high)).normalized()
	_bolt_seed = _sky_rng.randf_range(0.0, 97.0)
	_thunder_delay = _rng.randf_range(THUNDER_AFTER.x, THUNDER_AFTER.y)
	_thunder_in = _thunder_delay
	flashed.emit()


## How clouded the moon's disc is (0..1), averaged over equal-area samples.
func cloud_cover() -> float:
	var dir := moon_direction()
	var right := dir.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.1:
		right = Vector3.RIGHT
	var up := right.cross(dir).normalized()
	var total := 0.0
	# Four rings, eight directions each; radial midpoints cover equal areas.
	for ring in 4:
		var radius := MOON_RADIUS * sqrt((float(ring) + 0.5) / 4.0)
		for sector in 8:
			var angle := (float(sector) + float(ring % 2) * 0.5) * TAU / 8.0
			total += density_at((dir + (right * cos(angle) + up * sin(angle)) * radius).normalized())
	return total / 32.0


## The source direction and unobscured fraction, independent of lightning.
func moon_direction() -> Vector3:
	return _moon_dir()


func moon_visibility() -> float:
	return clampf(1.0 - cloud_cover(), 0.0, 1.0)


## The clouds' density toward `dir`, as the sky draws it.
func density_at(dir: Vector3) -> float:
	if dir.y <= 0.0:
		return 0.0

	var uv := sky_uv(dir)
	var cover := float(_now.get("cover", 0.0))
	var n := clampf((field_at(uv) - 0.5) * CLOUD_CONTRAST + 0.5, 0.0, 1.0)
	var field := smoothstep(1.0 - cover - CLOUD_SOFT, 1.0 - cover + CLOUD_SOFT, n)
	var edge := field * (1.0 - field) * 4.0
	var grain := field_at(uv * 3.3 + Vector2(0.31, 0.77))
	field *= lerpf(1.0, smoothstep(0.2, 0.75, grain), 0.55 * edge)
	return field * smoothstep(0.0, 0.1, dir.normalized().y)


## Where `dir` falls on the cloud field (the sky shader's sky_uv).
func sky_uv(dir: Vector3) -> Vector2:
	var d := dir.normalized()
	var h := maxf(d.y, 0.02) + CLOUD_CURVE
	return Vector2(d.x, d.z) / h * CLOUD_SCALE + _offset


## The field at `uv` (wrapping, filtered as the sky's texture is).
func field_at(uv: Vector2) -> float:
	if _field == null:
		return 0.0

	var x := fposmod(uv.x, 1.0) * FIELD - 0.5
	var y := fposmod(uv.y, 1.0) * FIELD - 0.5
	var x0 := floori(x)
	var y0 := floori(y)
	var fx := x - x0
	var fy := y - y0
	var a := _texel(x0, y0)
	var b := _texel(x0 + 1, y0)
	var c := _texel(x0, y0 + 1)
	var d := _texel(x0 + 1, y0 + 1)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)


## How hard it rains (0..1).
func rain() -> float:
	return float(_now.get("rain", 0.0))


## The wind (m/s), gusts and all.
func wind() -> Vector3:
	var atmosphere := get_tree().get_first_node_in_group(&"atmosphere") if is_inside_tree() else null
	var speed := float(_now.get("wind", 0.0))

	if atmosphere != null and atmosphere.has_method("wind"):
		var strength := maxf(float(atmosphere.get("strength")), 0.001)
		return (atmosphere.wind() as Vector3) / strength * speed

	return Vector3(0.7, 0.0, 0.7).normalized() * speed * 0.6


func masking_db() -> float:
	return float(_now.get("mask", 0.0))


## How thick the mist banks are now.
func mist_density() -> float:
	return MIST * clampf((float(_now.get("fog", 1.0)) - 1.0) / 3.0, 0.0, 1.0)


## Whether `point` has a roof over it.
func indoors(point: Vector3) -> bool:
	if not is_inside_tree():
		return false

	var query := PhysicsRayQueryParameters3D.create(point, point + Vector3.UP * INDOORS_REACH, 1)
	query.collide_with_areas = false
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## Whether a foot at `point` stands in a puddle deep enough to splash.
func splashes_at(point: Vector3) -> bool:
	if wetness < PUDDLE_SPLASH:
		return false

	for spot in puddles:
		if Vector2(point.x - spot.x, point.z - spot.z).length() < PUDDLE_SIZE * 0.4 and absf(point.y - spot.y) < 0.5:
			return true

	return false


## Registers a shared BaseMaterial3D for wetness edits, storing its dry colour/roughness in night_dry metadata.
## Null/already-registered resources are ignored; exit restores dry values so later levels do not inherit wet materials.
func register_wet(material: BaseMaterial3D) -> void:
	if material == null or _wet.has(material):
		return

	if not material.has_meta(&"night_dry"):
		material.set_meta(&"night_dry", [material.albedo_color, material.roughness])

	_wet[material] = material.get_meta(&"night_dry")
	_wet_shown = -1.0


## How much of the unclouded moon's light falls now: 1 in the clear, down to
## CLOUDED under cloud, more in a lightning flash (its light added).
func moon_share() -> float:
	if moon == null or _moon_base <= 0.0:
		return 1.0

	return moon.light_energy / _moon_base


## The night of `node`'s level; null if it has none.
static func of(node: Node) -> Node:
	if node == null or not node.is_inside_tree():
		return null

	return node.get_tree().get_first_node_in_group(&"night")


func _enter_tree() -> void:
	add_to_group(&"night")


func _process(delta: float) -> void:
	_clock += delta

	while not _pending.is_empty() and float(_pending[0][0]) <= _clock:
		var due: Array = _pending.pop_front()
		var rest := _pending.duplicate()
		to(due[1], float(due[2]))
		_pending = rest

	if _t < _over:
		_t = minf(_t + delta, _over)
		var k := smoothstep(0.0, 1.0, _t / _over)

		for key in EASED:
			_now[key] = lerpf(float(_from[key]), float(_to[key]), k)

	# (the field slides against the wind, so the clouds on it go with it)
	var air := wind()
	_offset -= Vector2(air.x, air.z) * CLOUD_DRIFT * delta
	_step_lightning(delta)
	_step_wet(delta)
	_registered_in -= delta

	if _registered_in <= 0.0:
		_registered_in = 2.0
		_register_shared()

	_apply(air)


func _jump(to_state: StringName) -> void:
	_now = _values(to_state)
	_from = _now.duplicate()
	_to = _now.duplicate()
	_t = 0.0
	_over = 0.0
	_set_state(to_state)
	_apply(wind())


func _set_state(to_state: StringName) -> void:
	var was := state
	state = to_state
	var values: Dictionary = STATES[to_state]
	_lightning_in = _rng.randf_range(LIGHTNING_EVERY.x, LIGHTNING_EVERY.y) if values["lightning"] else INF

	if was != to_state:
		state_changed.emit(to_state)


func _values(of_state: StringName) -> Dictionary:
	var values := {}

	for key in EASED:
		values[key] = float(STATES[of_state][key])

	return values


func _step_lightning(delta: float) -> void:
	if bool(STATES[state]["lightning"]) and rain() >= 0.8:
		_lightning_in -= delta

		if _lightning_in <= 0.0:
			_lightning_in = _rng.randf_range(LIGHTNING_EVERY.x, LIGHTNING_EVERY.y)
			flash()

	if _flash_t < INF:
		_flash_t += delta

		if _flash_t > float(FLASH[FLASH.size() - 1][0]):
			_flash_t = INF

	if _thunder_in < INF:
		_thunder_in -= delta

		if _thunder_in <= 0.0:
			_thunder_in = INF
			thundered.emit(_thunder_delay)

			if _sound != null:
				_sound.thunder(_thunder_delay)


func _step_wet(delta: float) -> void:
	var wanted := rain()

	if wanted > wetness:
		wetness = minf(wetness + delta / WET_RISE, wanted)
	else:
		wetness = maxf(wetness - delta / WET_DRY, wanted)


## The flash's light now (times the moon's).
func _flash_level() -> float:
	if _flash_t == INF:
		return 1.0

	for step in FLASH:
		if _flash_t <= float(step[0]):
			return float(step[1])

	return 1.0


func _apply(air: Vector3) -> void:
	var cover := cloud_cover()
	var flash_level := _flash_level()

	# (lightning is its own light: it adds to the moon's whatever the cloud)
	var thick := clampf((float(_now.get("fog", 1.0)) - 1.0) / 3.0, 0.0, 1.0)

	if moon != null:
		moon.light_energy = _moon_base * (lerpf(1.0, CLOUDED, cover) + flash_level - 1.0)
		moon.light_volumetric_fog_energy = _moon_scatter_base * lerpf(1.0, FOG_SCATTER, thick) / maxf(flash_level / FLASH_AIR, 1.0)

	if environment != null:
		environment.ambient_light_energy = _ambient_base * lerpf(1.0, AMBIENT_CLOUDED, cover)
		environment.volumetric_fog_density = _fog_base * float(_now.get("fog", 1.0)) * zone_fog
		# Thick fog in moonlight is silver-grey, whatever the place's own.
		var own := zone_fog_color if zone_fog_color.a > 0.0 else _fog_albedo_base
		environment.volumetric_fog_albedo = own.lerp(FOG_SILVER, FOG_GREYED * thick)

		# A map's haze over the distance (a depth fog) closes in as the fog
		# thickens: in thick fog the far shore is gone.
		if _haze_end_base > 0.0:
			environment.fog_depth_end = _haze_end_base * lerpf(1.0, HAZE_CLOSED, thick)
		environment.tonemap_exposure = _exposure_base * lerpf(1.0, WET_EYE, rain())

	SoundBus.masking_db = masking_db()
	var atmosphere := get_tree().get_first_node_in_group(&"atmosphere") if is_inside_tree() else null

	if atmosphere != null and &"strength" in atmosphere:
		atmosphere.strength = float(_now.get("wind", 0.0)) * WIND_STRENGTH

	if _sky != null:
		var cover_now := float(_now.get("cover", 0.0))
		_sky.show_night(cover_now, _offset, clampf((flash_level - 1.0) / 5.0, 0.0, 1.0), thick, _clock)
		_sky.show_lightning(_flash_dir, 1.0 if flash_level >= BOLT_FROM else 0.0, _bolt_seed)
		_sky.show_cirrus(CIRRUS * clampf(1.0 - cover_now / CIRRUS_GONE, 0.0, 1.0))

	if _rain != null:
		_rain.amount = rain()
		_rain.wind = air

	if _sound != null:
		_sound.set_weather(rain(), air.length(), wetness, _rain != null and _rain.sheltered())

	if absf(wetness - _wet_shown) > 0.002:
		_wet_shown = wetness

		for material in _wet:
			if not is_instance_valid(material):
				continue

			var base: Array = _wet[material]
			var dry: Color = base[0]
			var k := lerpf(1.0, WET_DARKEN, wetness)
			material.albedo_color = Color(dry.r * k, dry.g * k, dry.b * k, dry.a)
			material.roughness = lerpf(float(base[1]), WET_ROUGH, wetness)

		for decal in _decals:
			decal.modulate.a = smoothstep(PUDDLE_FROM, 0.6, wetness)
			decal.visible = wetness > PUDDLE_FROM

	for fog in _mist:
		(fog.material as FogMaterial).density = mist_density()
		fog.visible = mist_density() > 0.001


func _moon_dir() -> Vector3:
	return moon.global_basis.z.normalized() if moon != null and moon.is_inside_tree() else Vector3(-0.6, 0.5, -0.6).normalized()


func _texel(x: int, y: int) -> float:
	return _field.get_pixel(posmod(x, FIELD), posmod(y, FIELD)).r


func _register_shared() -> void:
	for material in Materials.surfaces():
		register_wet(material)


func _make_puddles() -> void:
	if puddles.is_empty():
		return

	var albedo := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var orm := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 31
	noise.frequency = 0.08

	for y in 64:
		for x in 64:
			var r := Vector2(x - 31.5, y - 31.5).length() / 32.0
			var edge := clampf((1.0 - r) * 2.2 + noise.get_noise_2d(x, y) * 0.9, 0.0, 1.0)
			albedo.set_pixel(x, y, Color(0.03, 0.035, 0.05, edge * 0.85))
			orm.set_pixel(x, y, Color(1.0, 0.08, 0.0, 1.0))

	var albedo_texture := ImageTexture.create_from_image(albedo)
	var orm_texture := ImageTexture.create_from_image(orm)

	for spot in puddles:
		var decal := Decal.new()
		decal.size = Vector3(PUDDLE_SIZE, 0.6, PUDDLE_SIZE)
		decal.texture_albedo = albedo_texture
		decal.texture_orm = orm_texture
		decal.cull_mask = 1
		decal.visible = false
		add_child(decal)
		decal.global_position = spot
		decal.rotation.y = float(_decals.size()) * 1.7
		_decals.append(decal)


func _make_mist() -> void:
	for box in mist_boxes:
		var fog := FogVolume.new()
		fog.size = box.size
		var material := FogMaterial.new()
		material.density = 0.0
		material.albedo = Color(0.75, 0.78, 0.85)
		material.height_falloff = 1.2
		material.edge_fade = 0.4
		fog.material = material
		fog.visible = false
		add_child(fog)
		fog.global_position = box.get_center()
		_mist.append(fog)
