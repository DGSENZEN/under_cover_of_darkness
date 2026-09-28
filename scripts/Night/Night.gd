extends Node3D
## The night over a level: the moon and its clouds, and the weather (clear,
## cloudy, drizzle, shower, storm, fog). It draws the sky (NightSky), lets
## the rain fall (Rain), wets the ground, sets how hard the wind blows
## (Atmosphere), throws lightning, thickens the fog and raises the noise
## floor (SoundBus.masking_db), easing from one state to the next.
##
## The clouds the sky draws are this node's cloud field, and the moon's light
## reads it here with the sky shader's own projection at the moon: a cloud
## seen crossing the moon is the cloud that dims its light (to CLOUDED of it,
## the ambient to AMBIENT_CLOUDED). The weather rolls its own dice, so it
## never shifts the world's.
##
## A level adds one beside its moon light and its environment:
##   night.moon = moon; night.environment = environment; add_child(night)
##   night.to(&"storm", 30.0)        # a storm, eased in over 30 s
##   night.cover_moon(20.0)          # a cloud over the moon, held 20 s

const SoundBus := preload("res://scripts/StimuliSystem/SoundBus.gd")
const Materials := preload("res://scripts/Visual/Materials.gd")
const NightSkyScript := preload("res://scripts/Night/NightSky.gd")
const RainScript := preload("res://scripts/Night/Rain.gd")
const NightSoundScript := preload("res://scripts/Night/NightSound.gd")

## Each state: cloud cover (0..1), rain (0..1), wind (m/s), fog (times the
## level's own), the noise floor (dB), whether clouds cross the moon now and
## then, whether lightning strikes.
const STATES := {
	&"clear": {"cover": 0.15, "rain": 0.0, "wind": 1.0, "fog": 1.0, "mask": 0.0, "crossings": true, "lightning": false},
	&"cloudy": {"cover": 0.5, "rain": 0.0, "wind": 2.0, "fog": 1.0, "mask": 0.0, "crossings": true, "lightning": false},
	&"drizzle": {"cover": 0.65, "rain": 0.25, "wind": 2.0, "fog": 1.0, "mask": 3.0, "crossings": false, "lightning": false},
	&"shower": {"cover": 0.8, "rain": 0.6, "wind": 4.0, "fog": 1.0, "mask": 6.0, "crossings": false, "lightning": false},
	&"rain": {"cover": 0.9, "rain": 0.8, "wind": 5.5, "fog": 1.1, "mask": 8.0, "crossings": false, "lightning": false},
	&"storm": {"cover": 0.95, "rain": 1.0, "wind": 8.0, "fog": 1.0, "mask": 10.0, "crossings": false, "lightning": true},
	&"fog": {"cover": 0.4, "rain": 0.0, "wind": 0.5, "fog": 4.0, "mask": 0.0, "crossings": false, "lightning": false},
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
## The sky shader holds the same constants (night_test N3).
const FIELD := 256
const CLOUD_CURVE := 0.25
const CLOUD_SCALE := 0.35
const CLOUD_SOFT := 0.12
const CLOUD_DRIFT := 0.0025

## A veil (cover_moon): a cloud this big, its edge this soft, coming from
## this far off along the wind, over VEIL_IN seconds each way.
const VEIL_RADIUS := 0.22
const VEIL_EDGE := 0.18
const VEIL_TRAVEL := 0.9
const VEIL_IN := 4.0
## In clear and cloudy weather a cloud crosses the moon this often (s, from
## one crossing to the next), held over it this long (the moon dark about
## 2.3 s longer than the hold: 15-25 s).
const CROSSING_EVERY := Vector2(60.0, 90.0)
const CROSSING_HOLD := Vector2(12.7, 22.7)

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
const WET_ROUGH := 0.35
## Puddles show from this wetness, and splash underfoot from PUDDLE_SPLASH.
const PUDDLE_FROM := 0.1
const PUDDLE_SPLASH := 0.3
const PUDDLE_SIZE := 2.4

## The mist banks' density in thick fog.
const MIST := 0.2
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
var _field: Image
var _field_texture: ImageTexture
var _offset := Vector2.ZERO
var _veil := {}
var _crossing_in := INF
var _lightning_in := INF
var _flash_t := INF
var _thunder_in := INF
var _thunder_delay := 0.0
var _moon_base := 1.0
var _ambient_base := 1.0
var _fog_base := 0.01
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

	if environment != null:
		_ambient_base = environment.ambient_light_energy
		_fog_base = environment.volumetric_fog_density
		_sky = NightSkyScript.new(environment, _field_texture)

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


## To `to_state` over `seconds` (0: at once), `after` s from now (a change
## asked for now drops any still waiting).
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


## A cloud over the moon: in over VEIL_IN s, held `hold` s, off over VEIL_IN
## s. 0 while one holds sends it on its way now.
func cover_moon(hold: float) -> void:
	if not _veil.is_empty():
		var t := float(_veil["t"])

		if hold <= 0.0 and t < VEIL_IN + float(_veil["hold"]):
			_veil["hold"] = maxf(t - VEIL_IN, 0.0)
		elif hold > 0.0:
			_veil["hold"] = maxf(float(_veil["hold"]), t - VEIL_IN + hold)

		return

	if hold > 0.0:
		_veil = {"t": 0.0, "hold": hold, "along": _wind_flat()}


## A lightning flash, now; its thunder follows.
func flash() -> void:
	_flash_t = 0.0
	_thunder_delay = _rng.randf_range(THUNDER_AFTER.x, THUNDER_AFTER.y)
	_thunder_in = _thunder_delay
	flashed.emit()


## How clouded the moon is (0..1), a veil over it included.
func cloud_cover() -> float:
	return density_at(_moon_dir())


## The clouds' density toward `dir`, as the sky draws it.
func density_at(dir: Vector3) -> float:
	if dir.y <= 0.0:
		return 0.0

	var uv := sky_uv(dir)
	var cover := float(_now.get("cover", 0.0))
	var field := smoothstep(1.0 - cover - CLOUD_SOFT, 1.0 - cover + CLOUD_SOFT, field_at(uv))
	return maxf(field, _veil_at(uv))


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


## `material` darkens and shines as the ground gets wet. Its dry look is
## kept on it (a shared surface outlives a level, and the next night must not
## take it wet as dry).
func register_wet(material: BaseMaterial3D) -> void:
	if material == null or _wet.has(material):
		return

	if not material.has_meta(&"night_dry"):
		material.set_meta(&"night_dry", [material.albedo_color, material.roughness])

	_wet[material] = material.get_meta(&"night_dry")
	_wet_shown = -1.0


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
	_step_veil(delta)
	_step_crossings(delta)
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
	_crossing_in = _rng.randf_range(CROSSING_EVERY.x, CROSSING_EVERY.y) if values["crossings"] else INF
	_lightning_in = _rng.randf_range(LIGHTNING_EVERY.x, LIGHTNING_EVERY.y) if values["lightning"] else INF

	if was != to_state:
		state_changed.emit(to_state)


func _values(of_state: StringName) -> Dictionary:
	var values := {}

	for key in EASED:
		values[key] = float(STATES[of_state][key])

	return values


func _step_veil(delta: float) -> void:
	if _veil.is_empty():
		return

	_veil["t"] = float(_veil["t"]) + delta

	if float(_veil["t"]) >= VEIL_IN * 2.0 + float(_veil["hold"]):
		_veil = {}


func _step_crossings(delta: float) -> void:
	if not bool(STATES[state]["crossings"]):
		return

	# (counted from one crossing's start to the next; one due while a veil is
	# still over the moon waits for it to go)
	_crossing_in -= delta

	if _crossing_in <= 0.0 and _veil.is_empty():
		_crossing_in = _rng.randf_range(CROSSING_EVERY.x, CROSSING_EVERY.y)
		cover_moon(_rng.randf_range(CROSSING_HOLD.x, CROSSING_HOLD.y))


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
	if moon != null:
		moon.light_energy = _moon_base * (lerpf(1.0, CLOUDED, cover) + flash_level - 1.0)

	if environment != null:
		environment.ambient_light_energy = _ambient_base * lerpf(1.0, AMBIENT_CLOUDED, cover)
		environment.volumetric_fog_density = _fog_base * float(_now.get("fog", 1.0)) * zone_fog

		if zone_fog_color.a > 0.0:
			environment.volumetric_fog_albedo = zone_fog_color

	SoundBus.masking_db = masking_db()
	var atmosphere := get_tree().get_first_node_in_group(&"atmosphere") if is_inside_tree() else null

	if atmosphere != null and &"strength" in atmosphere:
		atmosphere.strength = float(_now.get("wind", 0.0)) * WIND_STRENGTH

	if _sky != null:
		var veil_on := 1.0 if not _veil.is_empty() else 0.0
		_sky.show_night(float(_now.get("cover", 0.0)), _offset, _veil_centre(), veil_on,
			clampf((flash_level - 1.0) / 5.0, 0.0, 1.0), clampf((float(_now.get("fog", 1.0)) - 1.0) / 3.0, 0.0, 1.0), _clock)

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


func _veil_at(uv: Vector2) -> float:
	if _veil.is_empty():
		return 0.0

	return 1.0 - smoothstep(VEIL_RADIUS, VEIL_RADIUS + VEIL_EDGE, uv.distance_to(_veil_centre()))


## Where the veil is on the field now: coming along the wind, over the moon,
## going on.
func _veil_centre() -> Vector2:
	var moon_uv := sky_uv(_moon_dir())

	if _veil.is_empty():
		return moon_uv + Vector2(10.0, 10.0)

	var t := float(_veil["t"])
	var hold := float(_veil["hold"])
	var x := 0.0

	if t < VEIL_IN:
		x = -VEIL_TRAVEL * (1.0 - t / VEIL_IN)
	elif t > VEIL_IN + hold:
		x = VEIL_TRAVEL * (t - VEIL_IN - hold) / VEIL_IN

	return moon_uv + (_veil["along"] as Vector2) * x


func _wind_flat() -> Vector2:
	var air := wind()
	var flat := Vector2(air.x, air.z)
	return flat.normalized() if flat.length() > 0.01 else Vector2(0.7, 0.7).normalized()


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
