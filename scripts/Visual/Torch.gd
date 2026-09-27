extends Node3D
## A torch: a warm light that breathes and gutters, and a flame drawn as a
## four-frame pixel flipbook that always faces you. Its shadows are on, so in
## a foggy room it throws shafts past pillars and through doorways.
##
## A real light: guards see you by it (and see you flicker with it), and the
## lightgem reads it. Put the node where the flame is.
##
## Heard as well: it crackles (audio/ambience/torch_loop.ogg), close by only,
## muffled through a wall, a little different from every other torch. It only
## plays while you are near enough to hear it.
##
## A log pushed into it (flare) and it flares up a moment, brighter and
## taller.
##
## A level's own torch on a wall (`can_douse`) can be put out: by you, up close
## (use it: pinched out with a hiss and a wisp of smoke), and that place is
## dark. It was burning when the level began, so a guard who sees it dark
## knows someone has been at it (left_out: GuardLife), and lights it again
## (relight: GuardHands).
##
##   var torch := Torch.new(); torch.position = Vector3(0, 2.2, 0); add_child(torch)

const Fx := preload("res://scripts/Visual/Fx.gd")
const Layers := preload("res://scripts/Visual/Layers.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")
const SoundBus := preload("res://scripts/StimuliSystem/SoundBus.gd")

const CRACKLE := "res://audio/ambience/torch_loop.ogg"
## Put out: heard this loud (SoundBus, dB), close by only. The ray you use
## things with finds it on this physics layer (PlayerFrob.frob_mask), within
## REACH_RADIUS (m) of the flame.
const HISS_DB := 30.0
const REACH_LAYER := 4
const REACH_RADIUS := 0.3
## How loud its crackle is (dB at a metre or so), and how far it carries.
const CRACKLE_DB := -13.0
const CRACKLE_REACH := 11.0
## Flaring up: this much brighter and taller at first, gone in this long (s).
const FLARE_LIGHT := 0.6
const FLARE_SIZE := 0.45
const FLARE_TIME := 0.9

@export var color := Color(1.0, 0.64, 0.32)
@export var energy := 2.4
@export var light_range := 9.0
## How much the light wavers, as a fraction of its energy.
@export_range(0.0, 0.6, 0.01) var flicker := 0.16
@export var shadows := true
## Flame frames per second.
@export var frame_rate := 9.0
@export var flame_size := 0.34
## A level's own torch, that you can put out (see the header); and what it is
## called ("Put out the torch").
@export var can_douse := false
@export var light_name := "torch"

var light: OmniLight3D
var flame: MeshInstance3D
## Its crackle (null with sound off).
var crackle: AudioStreamPlayer3D

var _flame_material: StandardMaterial3D
var _time := 0.0
var _phase := 0.0
var _listen_in := 0.0
var _crackle_db := CRACKLE_DB
## How brightly it burns (a brazier burning down: Fire.gd); 1 as made.
var _strength := 1.0
## The wind on it (Atmosphere): the flame leans its way.
var _lean := Vector3.ZERO
## How far the top of the flame goes with a full wind (m, at its made size).
const LEAN_REACH := 0.07
## Flaring up (a log pushed in): 1 at once, fading.
var _flare := 0.0
## Burning; and whether it was when the level began (a light they expect).
var lit := true
var was_lit := true
var _put_out_by: WeakRef = null
var _reach: Area3D


func _ready() -> void:
	add_to_group(&"torches")
	# The light wavers and the flame changes every drawn frame: drawn as set.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_phase = randf() * 100.0
	_time = _phase

	light = OmniLight3D.new()
	light.name = "Light"
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.omni_attenuation = 1.15
	light.shadow_enabled = shadows
	light.shadow_blur = 1.5
	light.light_volumetric_fog_energy = 1.4
	# Just above the flame, so the flame does not shadow its own light.
	light.position = Vector3(0.0, 0.12, 0.0)
	add_child(light)

	flame = MeshInstance3D.new()
	flame.name = "Flame"
	var quad := QuadMesh.new()
	quad.size = Vector2(flame_size * 0.75, flame_size)
	flame.mesh = quad
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flame.layers = Layers.FX

	_flame_material = StandardMaterial3D.new()
	_flame_material.albedo_texture = Fx.texture(&"flame")
	_flame_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_flame_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flame_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	_flame_material.alpha_scissor_threshold = 0.5
	_flame_material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	_flame_material.albedo_color = Color(1.6, 1.3, 1.0)
	_flame_material.disable_fog = true
	_flame_material.uv1_scale = Vector3(0.25, 1.0, 1.0)
	flame.material_override = _flame_material
	add_child(flame)

	if Sfx.enabled and ResourceLoader.exists(CRACKLE):
		var loop := load(CRACKLE) as AudioStreamOggVorbis

		if loop != null:
			loop.loop = true
			crackle = AudioStreamPlayer3D.new()
			crackle.name = "Crackle"
			crackle.stream = loop
			crackle.bus = Sfx.BUS_WORLD
			crackle.unit_size = 1.4
			crackle.max_distance = CRACKLE_REACH
			crackle.volume_db = CRACKLE_DB
			crackle.max_db = 0.0
			crackle.attenuation_filter_cutoff_hz = Sfx.AIR_CUTOFF
			crackle.attenuation_filter_db = Sfx.AIR_DB
			crackle.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
			# No two torches burn alike.
			crackle.pitch_scale = randf_range(0.9, 1.1)
			add_child(crackle)

	# A level's own torch: found by the ray you use things with, and known to
	# the guards.
	if can_douse:
		was_lit = lit
		add_to_group(&"lights")
		flame.set_meta(&"no_highlight", true)
		_reach = Area3D.new()
		_reach.name = "Reach"
		_reach.collision_layer = REACH_LAYER
		_reach.collision_mask = 0
		_reach.monitoring = false
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = REACH_RADIUS
		shape.shape = sphere
		_reach.add_child(shape)
		add_child(_reach)


func _process(delta: float) -> void:
	if not lit:
		return

	_time += delta

	# A slow breath, a quicker waver and a nervous flutter.
	var n := (
		sin(_time * 1.7) * 0.45
		+ sin(_time * 5.3 + 1.1) * 0.35
		+ sin(_time * 13.1 + 2.3) * 0.2
	)
	_flare = move_toward(_flare, 0.0, delta / FLARE_TIME)
	var flared := _flare * _flare
	light.light_energy = energy * _strength * (1.0 + flicker * n) * (1.0 + FLARE_LIGHT * flared)
	light.omni_range = light_range * lerpf(0.55, 1.0, clampf(_strength, 0.0, 1.0))
	light.position = Vector3(sin(_time * 3.1) * 0.02, 0.12 + sin(_time * 4.7) * 0.015, cos(_time * 2.9) * 0.02)

	var frame := int(floor(_time * frame_rate)) % 4
	_flame_material.uv1_offset = Vector3(0.25 * frame, 0.0, 0.0)
	flame.scale = Vector3.ONE * lerpf(0.35, 1.0, clampf(_strength, 0.0, 1.5)) * (1.0 + 0.08 * n) * (1.0 + FLARE_SIZE * flared)
	# Leaning with the wind: the flame goes its way and flattens a little.
	var gust := Vector3(_lean.x, 0.0, _lean.z)
	flame.position = gust * LEAN_REACH * (flame_size / 0.34)
	flame.scale.y *= 1.0 - 0.15 * clampf(gust.length(), 0.0, 1.0)
	_listen(delta)


## The wind on it (Atmosphere.wind): which way and how hard.
func lean(v: Vector3) -> void:
	_lean = v


## How brightly it burns: its light, its reach and its flame (1 as made;
## less burning down, more flaring).
func set_strength(k: float) -> void:
	_strength = maxf(k, 0.0)


## What using it does (PlayerFrob): put it out, while it burns.
func get_prompt(_by: Node) -> String:
	return "Put out the %s" % light_name if lit and can_douse else ""


func frob(by: Node) -> void:
	if lit and can_douse:
		put_out(by)


## Out: dark and quiet, with a hiss and a wisp of smoke; who put it out is
## remembered (left_out).
func put_out(by: Node = null) -> void:
	if not lit:
		return

	lit = false
	_put_out_by = weakref(by) if by != null else null
	light.visible = false
	flame.visible = false

	if crackle != null:
		crackle.stop()

	if _reach != null:
		_reach.collision_layer = 0

	Sfx.play(self, &"cloth", global_position, -6.0, 0.75)
	Fx.dust(self, global_position + Vector3.UP * 0.12, Vector3.UP, 0.5)
	SoundBus.emit_sound(global_position, HISS_DB, by if by != null else self, &"hiss")


## Lit again (a guard with his tinder): burning, flaring up a moment.
func relight(_by: Node = null) -> void:
	if lit:
		return

	lit = true
	_put_out_by = null
	light.visible = true
	flame.visible = true

	if _reach != null:
		_reach.collision_layer = REACH_LAYER

	if has_meta(&"noticed"):
		remove_meta(&"noticed")

	_listen_in = 0.0
	Sfx.play(self, &"ignite", global_position, -4.0)
	flare(0.8)


## Out when it should be burning, and not by one of the guards: someone has
## been at it.
func left_out() -> bool:
	if lit or not was_lit:
		return false

	var who: Object = _put_out_by.get_ref() if _put_out_by != null else null
	return who == null or not (who as Node).is_in_group(&"guards")


## Flares up a moment (a log pushed into a fire): brighter and taller, then
## back as it was over FLARE_TIME.
func flare(amount := 1.0) -> void:
	_flare = maxf(_flare, clampf(amount, 0.0, 1.0))


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
		var near := camera != null and camera.global_position.distance_to(global_position) < CRACKLE_REACH + 1.0

		if near and not crackle.playing:
			crackle.volume_db = -40.0
			crackle.play(randf() * maxf(crackle.stream.get_length() - 1.0, 0.0))
		elif not near and crackle.playing:
			crackle.stop()

		if crackle.playing:
			var hidden := Sfx.occlusion_at(self, global_position)
			_crackle_db = CRACKLE_DB + (Sfx.OCCLUDED_DB if hidden >= 1.0 else (Sfx.AROUND_DB if hidden > 0.0 else 0.0))
			crackle.attenuation_filter_cutoff_hz = Sfx.OCCLUDED_CUTOFF if hidden >= 1.0 else (Sfx.AROUND_CUTOFF if hidden > 0.0 else Sfx.AIR_CUTOFF)

	if crackle.playing:
		crackle.volume_db = lerpf(crackle.volume_db, _crackle_db, 1.0 - exp(-4.0 * real))
