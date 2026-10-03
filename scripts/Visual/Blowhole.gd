extends Node3D
## Periodic cave spray and recorded roar (FilmCow sea; tools/prepare_sfx.py).
## During roar_time, a SoundBus box masks gameplay noise by roar_db; exit removes the zone.
## The radial spray texture is generated locally.

const SoundBus := preload("res://scripts/StimuliSystem/SoundBus.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")

## Between roars (s), how long each roars (s), how much it masks then (dB),
## how far round it (m: the zone's box, centred on it).
@export var period := 11.0
@export var roar_time := 3.2
@export var roar_db := 45.0
@export var reach := Vector3(18.0, 20.0, 18.0)
## Or the box it masks, given whole (a level's noise_zone marker: the cave
## below it and the headland round its mouth).
@export var zone_box := AABB()
## How high the spray is thrown (m); how loud the roar plays (dB).
@export var spray_height := 12.0
@export var volume := 6.0

var roaring := false
var zone := -1
var spray: GPUParticles3D = null
var _clock := 0.0


func _ready() -> void:
	zone = SoundBus.add_zone(zone_box if zone_box.has_volume() else AABB(global_position - reach * 0.5, reach), 0.0)
	spray = _make_spray()
	add_child(spray)
	# (Its first roar a little after the level begins, not on its first frame.)
	_clock = period * 0.4


func _exit_tree() -> void:
	if zone >= 0:
		SoundBus.remove_zone(zone)
		zone = -1


func _physics_process(delta: float) -> void:
	_clock += delta

	if roaring and _clock >= roar_time:
		roaring = false
		SoundBus.set_zone_db(zone, 0.0)

	if not roaring and _clock >= period:
		roar()


## The sea bursts out now.
func roar() -> void:
	_clock = 0.0
	roaring = true
	SoundBus.set_zone_db(zone, roar_db)
	Sfx.play(self, &"blowhole", global_position, volume, randf_range(0.94, 1.04))
	spray.restart()
	spray.emitting = true


func _make_spray() -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = "Spray"
	particles.one_shot = true
	particles.emitting = false
	particles.amount = 90
	particles.lifetime = 2.4
	particles.explosiveness = 0.55
	particles.visibility_aabb = AABB(Vector3(-6.0, -1.0, -6.0), Vector3(12.0, spray_height + 4.0, 12.0))
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 9.0
	var speed := sqrt(2.0 * 9.8 * spray_height)
	process.initial_velocity_min = speed * 0.7
	process.initial_velocity_max = speed
	process.gravity = Vector3(0.0, -9.8, 0.0)
	process.damping_min = 0.5
	process.damping_max = 1.5
	process.scale_min = 0.7
	process.scale_max = 1.6
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.4))
	grow.add_point(Vector2(1.0, 1.6))
	var grow_texture := CurveTexture.new()
	grow_texture.curve = grow
	process.scale_curve = grow_texture
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 1.0, 1.0, 0.75))
	fade.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var fade_texture := GradientTexture1D.new()
	fade_texture.gradient = fade
	process.color_ramp = fade_texture
	particles.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(1.2, 1.2)
	quad.material = _puff_material()
	particles.draw_pass_1 = quad
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return particles


## A soft round puff of sea-foam white: a radial gradient, faced to the
## camera, lit by the moon and the lamps like everything else.
static func _puff_material() -> StandardMaterial3D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.9, 0.94, 0.95, 1.0))
	gradient.set_color(1, Color(0.9, 0.94, 0.95, 0.0))
	gradient.add_point(0.55, Color(0.88, 0.92, 0.94, 0.55))
	var puff := GradientTexture2D.new()
	puff.gradient = gradient
	puff.fill = GradientTexture2D.FILL_RADIAL
	puff.fill_from = Vector2(0.5, 0.5)
	puff.fill_to = Vector2(1.0, 0.5)
	puff.width = 64
	puff.height = 64
	var material := StandardMaterial3D.new()
	material.albedo_texture = puff
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return material
