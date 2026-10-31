extends Node3D
## A Light Company lamp's breath (the station's Company lamps, maps/metro_station_dressing.gd): its light, the ward
## glass behind its lantern's panes, the halo it throws and the pocket of haze round it, all at one level that rises
## and falls slowly with a faint stutter, on game time. The seed sets its place in the breath, so a row of lamps never
## pulses as one. Nothing of it moves: only its light's energy and its shaders' `pulse` change.

const GLASS := preload("res://scripts/Visual/ward_glass.gdshader")
const HALO := preload("res://scripts/Visual/ward_halo.gdshader")

## The breath: its slow swell (of the level), how fast (radians a second); the stutter's depth and pace.
const SWELL := 0.1
const SWELL_RATE := 1.1
const STUTTER := 0.05
const STUTTER_RATE := 7.0
## The halo's size (m) and the haze's reach round the globe (m), its density, how much it glows.
const HALO_SIZE := 1.3
const HAZE_SIZE := Vector3(1.4, 1.2, 1.4)
const HAZE_DENSITY := 0.35
const HAZE_GLOW := 0.12

@export var colour := Color("#5AB4FF")
@export var energy := 1.6
@export var reach := 8.0
@export var seed := 0
## Its level's layers (the light's cull mask and the halo's layer).
@export var mask := 1
@export var layer := 1

var light: OmniLight3D
var glass: ShaderMaterial
var halo: MeshInstance3D
var haze: FogVolume
var _time := 0.0
var _phase := 0.0


func _init() -> void:
	glass = ShaderMaterial.new()
	glass.shader = GLASS


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	_phase = rng.randf() * TAU
	glass.set_shader_parameter("colour", colour)
	glass.set_shader_parameter("phase", rng.randf())
	light = OmniLight3D.new()
	light.name = "light"
	light.light_color = colour
	light.light_energy = energy
	light.omni_range = reach
	light.shadow_enabled = false
	light.light_cull_mask = mask
	add_child(light)
	halo = MeshInstance3D.new()
	halo.name = "halo"
	var quad := QuadMesh.new()
	quad.size = Vector2(HALO_SIZE, HALO_SIZE)
	halo.mesh = quad
	var look := ShaderMaterial.new()
	look.shader = HALO
	look.set_shader_parameter("colour", colour)
	halo.material_override = look
	halo.layers = layer
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(halo)
	haze = FogVolume.new()
	haze.name = "haze"
	haze.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
	haze.size = HAZE_SIZE
	var fog := FogMaterial.new()
	fog.albedo = colour
	fog.density = HAZE_DENSITY
	fog.emission = colour * HAZE_GLOW
	fog.edge_fade = 0.6
	haze.material = fog
	add_child(haze)
	_apply()


## Its level at game time `t` (1 its full energy).
func level_at(t: float) -> float:
	return 1.0 - SWELL + SWELL * sin(t * SWELL_RATE + _phase) \
		- STUTTER * maxf(0.0, sin(t * STUTTER_RATE + _phase * 3.0) * sin(t * STUTTER_RATE * 0.37 + _phase))


func _process(delta: float) -> void:
	_time += delta
	_apply()


func _apply() -> void:
	var level := level_at(_time)
	light.light_energy = energy * level
	glass.set_shader_parameter("pulse", level)
	(halo.material_override as ShaderMaterial).set_shader_parameter("pulse", level)
