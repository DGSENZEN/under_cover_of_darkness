extends Node3D
## A burner: a warm light that breathes and gutters, and the flames that make
## it, drawn from our own heat sheets (FlameFx.gd). Its shadows are on, so in
## a foggy room it throws shafts past pillars and through doorways. On its
## own it is a bare flame (a torch as the game has always had one); every
## light fixture (LightFixture.gd) is one of these with a model round it.
##
## A real light: guards see you by it (and see you flicker with it), and the
## lightgem reads it. Its flames, like every effect, are on their own layer,
## so they light nothing and the lightgem never sees them. Put the node where
## the flame is (for several flames, `flame_points` round it).
##
## It flickers at the rate its kind of flame puffs (Flicker.gd), never
## outside energy × (1 ± flicker), however it is stoked or blown.
##
## Heard as well: it crackles (audio/ambience/torch_loop.ogg unless told
## otherwise), close by only, muffled through a wall, a little different from
## every other torch. It only plays while you are near enough to hear it.
##
## A log pushed into it (flare) and it flares up a moment, brighter and
## taller.
##
##   var torch := Torch.new(); torch.position = Vector3(0, 2.2, 0); add_child(torch)

const Fx := preload("res://scripts/Visual/Fx.gd")
const Layers := preload("res://scripts/Visual/Layers.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")
const Flicker := preload("res://scripts/Visual/Lights/Flicker.gd")
const FlameFxScript := preload("res://scripts/Visual/Lights/FlameFx.gd")
const CoronaScript := preload("res://scripts/Visual/Lights/Corona.gd")
const FireParticles := preload("res://scripts/Visual/Lights/FireParticles.gd")
const LightProbe := preload("res://scripts/StimuliSystem/LightProbe.gd")
const LightBudget := preload("res://scripts/Visual/Lights/LightBudget.gd")

const CRACKLE := "res://audio/ambience/torch_loop.ogg"
## How loud its crackle is (dB at a metre or so), and how far it carries.
const CRACKLE_DB := -13.0
const CRACKLE_REACH := 11.0
## A flare: this much brighter and this much taller at its height, gone over
## FLARE_TIME.
const FLARE_LIGHT := 0.6
const FLARE_SIZE := 0.45
const FLARE_TIME := 0.9
## How far the top of the flame goes with a full wind (m, at its made size).
const LEAN_REACH := 0.07
## The light sits this far above its flames, so they never shadow it.
const LIGHT_ABOVE := 0.12
## Embers and smoke only within this of the camera.
const PARTICLE_REACH := 30.0
## Lit, a flame grows over LIGHT_TIME; snuffed, it pinches out over
## SNUFF_TIME and smokes a thread for SMOKE_THREAD; doused, its head (or its
## coals) cools over COOL_TIME.
const LIGHT_TIME := 0.5
const SNUFF_TIME := 0.1
const SMOKE_THREAD := 2.5
const COOL_TIME := 3.0

## Lit or put out (told at the end of the frame, once per real change).
signal lit_changed(lit: bool)

@export var color := Color("FF9829")
@export var energy := 2.4
@export var light_range := 9.0
## How much the light wavers, as a fraction of its energy.
@export_range(0.0, 0.6, 0.01) var flicker := 0.16
@export var shadows := true
## Flame frames per second; 0 is the sheet's own.
@export var frame_rate := 0.0
## The flame's height (m).
@export var flame_size := 0.34

## Which way it flickers (Flicker.KINDS): torch, cresset, brazier, fire,
## lamp or candle.
@export var flicker_kind := &"torch"
## Its heat sheet and colour ramps (FlameFx.gd).
@export var sheet := &"torch"
@export var ramp := &"torch"
@export var low_ramp := &"dying"
## Where its flames are, in its own space. One light serves them all.
@export var flame_points: PackedVector3Array = PackedVector3Array([Vector3.ZERO])
@export var flame_layers := 2
@export var core := true
## Its halo's size on the 360-line screen; 0 for none.
@export var corona_px := 48.0
## Its loop ("" for silence), how loud and how far.
@export var loop_path := CRACKLE
@export var loop_db := CRACKLE_DB
@export var loop_reach := CRACKLE_REACH
## Lit as made.
@export var lit := true
## Embers and smoke a second from each flame.
@export var ember_rate := 6.0
@export var smoke_rate := 3.0
## A fire's events (surges, settling logs) every x..y seconds; zero for none.
@export var event_every := Vector2.ZERO

var light: OmniLight3D
## The main flame sprite.
var flame: MeshInstance3D
## Its crackle (null with sound off).
var crackle: AudioStreamPlayer3D
var flames: Array = []
## Its own dice: drawn from where it stands, so every run is the same.
var rng := RandomNumberGenerator.new()
## Its halo (null with corona_px 0), and where it is in its own space (INF:
## just over its flames).
var corona: Node3D
var corona_point := Vector3.INF
## The Atmosphere makes this fire's embers already (Fire.brazier): none of
## its own while there is one.
var embers_by_atmosphere := false
## The main flame's flipbook frame.
var frame: int:
	get:
		return flames[0].frame if not flames.is_empty() else 0

var _time := 0.0
var _salt := 0
var _seeded := false
var _listen_in := 0.0
var _crackle_db := CRACKLE_DB
## How brightly it burns (a brazier burning down: Fire.gd); 1 as made.
var _strength := 1.0
## The wind on it (Atmosphere): the flame leans its way.
var _lean := Vector3.ZERO
var _flare := 0.0
## A fire's surge or settling log, 0..1: the flames only, never the light.
var _jump := 0.0
var _light_base := Vector3.ZERO
var _ember_due := 0.0
var _smoke_due := 0.0
## 0..1: how far lit it is (the light and flames follow it).
var _lit_level := 1.0
var _lit_target := 1.0
var _lit_rate := 1.0 / LIGHT_TIME
## 1 just doused, cooling to 0 over COOL_TIME.
var _cool := 0.0
var _smoke_left := 0.0
var _thread_due := 0.0
var _told := true
## Seconds since a draft reached it (a candle shivers for Flicker.DRAFT_TIME).
var _draft_since := INF


func _ready() -> void:
	_before_ready()
	add_to_group(&"torches")
	# Its clock starts somewhere of its own. (One draw from the global dice,
	# as torches always made: seeded suites roll the same numbers after it.)
	_time = randf() * 100.0
	# The light wavers and the flame changes every drawn frame: drawn as set.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF

	if flame_points.is_empty():
		flame_points = PackedVector3Array([Vector3.ZERO])

	var middle := Vector3.ZERO

	for point in flame_points:
		middle += point

	middle /= float(flame_points.size())
	_light_base = middle + Vector3(0.0, LIGHT_ABOVE, 0.0)

	light = OmniLight3D.new()
	light.name = "Light"
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.omni_attenuation = 1.15
	light.shadow_enabled = shadows
	light.shadow_blur = 1.5
	light.light_volumetric_fog_energy = 1.4
	# What the guards' light arithmetic takes it to be, whatever the shadow
	# budget does to what is drawn (LightProbe, LightBudget).
	light.set_meta(&"casts_shadow", shadows)
	# A fixture's glowing parts shine by themselves; this light, right over
	# them, would only blow them out.
	light.light_cull_mask = 0xFFFFF & ~Layers.GLOWING
	light.position = _light_base
	add_child(light)

	for point in flame_points:
		var fx: Node3D = FlameFxScript.new()
		fx.name = "Flame"
		fx.sheet = sheet
		fx.ramp = ramp
		fx.low_ramp = low_ramp
		fx.size = flame_size
		fx.frame_rate = frame_rate
		fx.layers = flame_layers
		fx.core = core
		add_child(fx)
		fx.position = point
		flames.append(fx)

	flame = flames[0].sprites[0]
	_lit_level = 1.0 if lit else 0.0
	_lit_target = _lit_level
	_told = lit

	if corona_px > 0.0:
		corona = CoronaScript.new()
		corona.name = "Corona"
		corona.size_px = corona_px
		corona.tint = color
		add_child(corona)
		corona.position = corona_point if corona_point != Vector3.INF else _light_base - Vector3(0.0, LIGHT_ABOVE - 0.06, 0.0)

	_make_loop()
	_show_lit(&"lit" if lit else &"out")
	_apply_lit()

	if shadows:
		LightBudget.register(self)

	_after_ready()


func _exit_tree() -> void:
	LightBudget.unregister(self)


## For what is built on a burner (LightFixture.gd): set the exports before
## the burner builds itself from them, and finish once it has.
func _before_ready() -> void:
	pass


func _after_ready() -> void:
	pass


func _make_loop() -> void:
	if not Sfx.enabled or loop_path.is_empty() or not ResourceLoader.exists(loop_path):
		return

	var loop := load(loop_path) as AudioStream

	if loop == null:
		return

	if loop is AudioStreamOggVorbis:
		loop.loop = true

	crackle = AudioStreamPlayer3D.new()
	crackle.name = "Crackle"
	crackle.stream = loop
	crackle.bus = Sfx.BUS_WORLD
	crackle.unit_size = 1.4
	crackle.max_distance = loop_reach
	crackle.volume_db = loop_db
	crackle.max_db = 0.0
	crackle.attenuation_filter_cutoff_hz = Sfx.AIR_CUTOFF
	crackle.attenuation_filter_db = Sfx.AIR_DB
	crackle.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
	crackle.position = _light_base - Vector3(0.0, LIGHT_ABOVE, 0.0)
	# No two torches burn alike.
	crackle.pitch_scale = randf_range(0.9, 1.1)
	_crackle_db = loop_db
	add_child(crackle)


func _process(delta: float) -> void:
	if not _seeded:
		# Seeded once it stands where it will burn (it is often placed just
		# after it is added).
		_seeded = true
		_salt = Flicker.seed_of(global_position)
		rng.seed = _salt

	_time += delta
	_flare = move_toward(_flare, 0.0, delta / FLARE_TIME)
	var flared := _flare * _flare
	var waver := Flicker.value(flicker_kind, _time, _salt)

	if flicker_kind == &"candle":
		# Still, but for a draft.
		_draft_since += delta
		waver = Flicker.draft(_draft_since)

	_step_lit(delta)
	# Eased as it lights: fast at first, settling into its flame.
	var shown := 1.0 - (1.0 - _lit_level) * (1.0 - _lit_level)
	light.light_color = color
	light.light_energy = energy * _strength * (1.0 + flicker * waver) * (1.0 + FLARE_LIGHT * flared) * shown
	light.omni_range = light_range * lerpf(0.55, 1.0, clampf(_strength, 0.0, 1.0))
	light.position = _light_base

	if flicker_kind == &"torch" or flicker_kind == &"cresset":
		# A torch's light dances a little, so its shadows shimmer.
		light.position += Vector3(sin(_time * 3.1) * 0.02, sin(_time * 4.7) * 0.015, cos(_time * 2.9) * 0.02)

	for fx in flames:
		fx.shape(waver, _strength, _lean, _flare, _jump)

	_shed(delta)
	_listen(delta)


## Embers and smoke off its flames, at their rates, while you are near (and a
## snuffed flame's smoke thread).
func _shed(delta: float) -> void:
	if _smoke_left > 0.0:
		_smoke_left -= delta

		if _near_camera():
			_thread_due += 3.0 * float(flame_points.size()) * delta

			while _thread_due >= 1.0:
				_thread_due -= 1.0
				FireParticles.emit(self, &"smoke", _flame_top(0.3), 1, _lean, Color.BLACK, flame_size * 0.3)

	if _lit_level < 0.5 or not _near_camera():
		_ember_due = 0.0
		_smoke_due = 0.0
		return

	var flames_count := float(flame_points.size())

	if ember_rate > 0.0 and not _atmosphere_embers():
		_ember_due += ember_rate * flames_count * delta

	if smoke_rate > 0.0:
		_smoke_due += smoke_rate * flames_count * delta

	while _ember_due >= 1.0:
		_ember_due -= 1.0
		FireParticles.emit(self, &"ember", _flame_top(0.6), 1, _lean, color)

	while _smoke_due >= 1.0:
		_smoke_due -= 1.0
		FireParticles.emit(self, &"smoke", _flame_top(1.0), 1, _lean, color, flame_size * 0.6)


func _near_camera() -> bool:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	return camera != null and camera.global_position.distance_to(global_position) <= PARTICLE_REACH


func _atmosphere_embers() -> bool:
	return embers_by_atmosphere and get_tree().get_first_node_in_group(&"atmosphere") != null


## A point up one of its flames (`up` of its height), picked by its dice.
func _flame_top(up: float) -> Vector3:
	var point := flame_points[rng.randi_range(0, flame_points.size() - 1)]
	var jitter := Vector3(rng.randf_range(-0.3, 0.3), 0.0, rng.randf_range(-0.3, 0.3)) * flame_size * 0.3
	return global_transform * (point + jitter + Vector3.UP * flame_size * up)


func _physics_process(delta: float) -> void:
	if corona != null:
		var glow := light.light_energy / maxf(energy, 0.001) if light.visible else 0.0
		corona.tick(get_viewport().get_camera_3d(), glow, light_range, _corona_exclude(), delta)


## Bodies of its own that must not hide its halo (a fixture's).
func _corona_exclude() -> Array[RID]:
	return []


## Lights it: the flame grows from nothing over LIGHT_TIME with a spray of
## sparks (`instant`: lit at once, silently).
func kindle(instant := false) -> void:
	var was_out := _lit_target < 1.0 or _lit_level < 1.0
	lit = true
	_lit_target = 1.0
	_lit_rate = 1.0 / LIGHT_TIME
	_cool = 0.0
	_smoke_left = 0.0

	if instant:
		_lit_level = 1.0
	elif was_out and _lit_level < 0.5 and is_inside_tree():
		for point in flame_points:
			FireParticles.emit(self, &"spark", global_transform * point, 8, _lean, color)

		var big := sheet == &"torch" or sheet == &"brazier" or sheet == &"fire"
		Sfx.play(self, &"ignite_torch" if big else &"ignite", global_position, -6.0)

	_show_lit(&"lit")
	_apply_lit()


## Puts it out: `how` "snuff" (pinched out, a thread of smoke) or "douse"
## (out at once, a burst of steam, the head cooling). `instant`: out, silently.
func put_out(how := &"snuff", instant := false) -> void:
	var was_lit := _lit_target > 0.0
	lit = false
	_lit_target = 0.0

	if instant:
		_lit_level = 0.0
		_cool = 0.0
		_show_lit(&"out")
	elif how == &"douse":
		_lit_level = 0.0
		_cool = 1.0 if was_lit else _cool

		if was_lit and is_inside_tree():
			for point in flame_points:
				FireParticles.emit(self, &"steam", global_transform * (point + Vector3.UP * flame_size * 0.4), 6, _lean, Color.WHITE, flame_size * 0.5)

			Sfx.play(self, &"douse", global_position, -4.0)

		_show_lit(&"cooling")
	else:
		_lit_rate = 1.0 / SNUFF_TIME

		if was_lit:
			_smoke_left = SMOKE_THREAD

			if is_inside_tree():
				Sfx.play(self, &"snuff", global_position, -8.0)

		_show_lit(&"out")

	_apply_lit()


func is_lit() -> bool:
	return lit


## A draft reaches it (a door, a man running past): a candle shivers a while.
func draft() -> void:
	_draft_since = 0.0


## What is built on a burner shows its lit, cooling and out states here
## (LightFixture: glowing heads and coals, charred when cold).
func _show_lit(_state: StringName) -> void:
	pass


func _step_lit(delta: float) -> void:
	var before := _lit_level
	_lit_level = move_toward(_lit_level, _lit_target, _lit_rate * delta)

	if _cool > 0.0:
		_cool = move_toward(_cool, 0.0, delta / COOL_TIME)
		_show_lit(&"cooling" if _cool > 0.0 else &"out")

	if _lit_level != before:
		_apply_lit()

	if lit != _told:
		_told = lit
		LightProbe.invalidate()
		lit_changed.emit(lit)


func _apply_lit() -> void:
	if light == null:
		return

	light.visible = _lit_level > 0.0

	for fx in flames:
		fx.set_shown(_lit_level)


## The wind on it (Atmosphere.wind): which way and how hard.
func lean(v: Vector3) -> void:
	_lean = v


## How brightly it burns: its light, its reach and its flame (1 as made;
## less burning down, more flaring).
func set_strength(k: float) -> void:
	_strength = maxf(k, 0.0)


## Flares up a moment (a log pushed into a fire): brighter and taller, then
## back as it was over FLARE_TIME.
func flare(amount := 1.0) -> void:
	_flare = maxf(_flare, clampf(amount, 0.0, 1.0))

	if is_inside_tree() and ember_rate > 0.0 and _near_camera() and not _atmosphere_embers():
		for i in int(12.0 + 8.0 * clampf(amount, 0.0, 1.0)):
			FireParticles.emit(self, &"ember", _flame_top(0.5), 1, _lean, color)


## Its crackle: started when you come near enough to hear it (somewhere in
## the loop, never in step with another torch), stopped when you leave;
## dulled and dropped through a wall, eased there so it never jumps.
func _listen(delta: float) -> void:
	if crackle == null:
		return

	var real := delta / maxf(Engine.time_scale, 0.05)
	_listen_in -= real

	if _listen_in <= 0.0:
		_listen_in = 0.4 + randf() * 0.2
		var camera := get_viewport().get_camera_3d()
		var near := camera != null and camera.global_position.distance_to(global_position) < loop_reach + 1.0

		if near and not crackle.playing:
			crackle.volume_db = -40.0
			crackle.play(randf() * maxf(crackle.stream.get_length() - 1.0, 0.0))
		elif not near and crackle.playing:
			crackle.stop()

		if crackle.playing:
			var hidden := Sfx.occlusion_at(self, global_position)
			_crackle_db = loop_db + (Sfx.OCCLUDED_DB if hidden >= 1.0 else (Sfx.AROUND_DB if hidden > 0.0 else 0.0))
			crackle.attenuation_filter_cutoff_hz = Sfx.OCCLUDED_CUTOFF if hidden >= 1.0 else (Sfx.AROUND_CUTOFF if hidden > 0.0 else Sfx.AIR_CUTOFF)

	if crackle.playing:
		crackle.volume_db = lerpf(crackle.volume_db, _crackle_db, 1.0 - exp(-4.0 * real))
