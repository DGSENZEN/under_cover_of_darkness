extends Node
## Maintains a stripped copy of the level Environment for the lightgem cameras.
## Keeps ambient light and sky, disables atmospheric/post effects, and uses the linear curve the gem was tuned under.
## Resynchronizes when the level environment changes so fog and tonemapping cannot alter measured light.

## How often to look for a changed world environment, in seconds.
const CHECK_EVERY := 0.5

var cameras: Array[Camera3D] = []

var _source: Environment = null
var _source_version := -1
var _gem: Environment = null
var _timer := 0.0


## Sets the Camera3D Array to receive the stripped environment and immediately synchronizes it.
func setup(gem_cameras: Array[Camera3D]) -> void:
	cameras = gem_cameras
	sync()


func _process(delta: float) -> void:
	_timer -= delta

	if _timer <= 0.0:
		_timer = CHECK_EVERY
		sync()


## Copies changed level Environment state into the gem-safe resource and assigns it to the configured cameras.
## Missing source environments are tolerated; the source resource is not edited.
func sync() -> void:
	if cameras.is_empty() or not is_inside_tree():
		return

	var world := cameras[0].get_world_3d()
	var source: Environment = world.environment if world != null else null
	var version := _version_of(source)

	if source == _source and version == _source_version and _gem != null:
		return

	_source = source
	_source_version = version
	_gem = stripped(source)

	for camera in cameras:
		if is_instance_valid(camera):
			camera.environment = _gem


func environment() -> Environment:
	return _gem


## The same light, none of the atmosphere.
static func stripped(source: Environment) -> Environment:
	var gem: Environment = source.duplicate() if source != null else Environment.new()
	gem.volumetric_fog_enabled = false
	gem.fog_enabled = false
	gem.glow_enabled = false
	gem.ssao_enabled = false
	gem.ssil_enabled = false
	gem.ssr_enabled = false
	gem.sdfgi_enabled = false
	gem.adjustment_enabled = false
	gem.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	gem.tonemap_exposure = 1.0
	gem.tonemap_white = 1.0
	return gem


## A cheap fingerprint of the settings that change what the gem sees, so an
## environment edited in place (not replaced) is noticed too.
static func _version_of(source: Environment) -> int:
	if source == null:
		return 0

	return hash([
		source.ambient_light_source,
		source.ambient_light_color,
		source.ambient_light_energy,
		source.ambient_light_sky_contribution,
		source.background_mode,
		source.background_energy_multiplier,
		source.sky,
	])
