extends Node3D
## Eyes in the dark behind a grating (maps/candle_lane.gd's culvert): the nahual's (scripts/Visual/Nahual.gd), as it
## travels the works between its haunts. While it is away they open now and then, two embers in the black; they
## blink, drift a little after whoever is near, and close when that someone comes too close, or when it is back.
## The node stands where the eyes look out from, its -Z out through the grating.

## How far apart the eyes are, how big, their colour (the nahual's ember) and glow; their light.
const APART := 0.13
const SIZE := 0.022
const EMBER := Color(1.0, 0.36, 0.08)
const GLOW := 4.0
const LIGHT := 0.25
const REACH := 0.35
## How long they stay open, and closed between (s, while it is away); how often they blink, how long a blink is.
const OPEN_FOR := Vector2(6.0, 14.0)
const SHUT_FOR := Vector2(3.0, 9.0)
const BLINK_EVERY := Vector2(2.5, 6.0)
const BLINK := 0.14
## How near someone may come before they close (m), how far they drift after them (m), how fast they open and close.
const NEAR := 2.2
const DRIFT := 0.05
const RATE := 6.0

## The nahual whose eyes they are, and whoever they watch.
@export var nahual: Node3D
@export var watched: Node3D
@export var seed := 3

## How open they are now (0 shut, 1 open).
var open := 0.0
var eyes: Array[MeshInstance3D] = []
var light: OmniLight3D

var _rng := RandomNumberGenerator.new()
var _want := false
var _next := 0.0
var _blink_in := 0.0
var _blink := 0.0


func _ready() -> void:
	_rng.seed = seed
	_next = _rng.randf_range(SHUT_FOR.x, SHUT_FOR.y)
	_blink_in = _rng.randf_range(BLINK_EVERY.x, BLINK_EVERY.y)
	var ball := SphereMesh.new()
	ball.radius = SIZE
	ball.height = SIZE * 1.6
	ball.radial_segments = 10
	ball.rings = 6
	var ember := StandardMaterial3D.new()
	ember.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ember.albedo_color = EMBER
	ember.emission_enabled = true
	ember.emission = EMBER
	ember.emission_energy_multiplier = GLOW
	ball.material = ember
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		eye.name = "eye_%s" % ("l" if side < 0.0 else "r")
		eye.mesh = ball
		eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(eye)
		eye.position = Vector3(side * APART / 2.0, 0.0, 0.0)
		eyes.append(eye)
	light = OmniLight3D.new()
	light.name = "eye_light"
	light.light_color = EMBER
	light.omni_range = REACH
	light.shadow_enabled = false
	add_child(light)
	light.position = Vector3(0.0, 0.0, -0.05)
	_show()


## Opened at once (the stills; they open by themselves).
func open_now() -> void:
	_want = true
	_next = OPEN_FOR.y
	open = 1.0
	_show()


func _process(delta: float) -> void:
	var gone: bool = nahual != null and is_instance_valid(nahual) and nahual.get("away") == true
	var near := watched != null and is_instance_valid(watched) and watched.global_position.distance_to(global_position) < NEAR

	_next -= delta
	if _next <= 0.0:
		_want = not _want
		_next = _rng.randf_range(OPEN_FOR.x, OPEN_FOR.y) if _want else _rng.randf_range(SHUT_FOR.x, SHUT_FOR.y)

	var target := 1.0 if gone and _want and not near else 0.0
	open = move_toward(open, target, RATE * delta)

	# A blink now and then.
	_blink_in -= delta
	if _blink_in <= 0.0:
		_blink = BLINK
		_blink_in = _rng.randf_range(BLINK_EVERY.x, BLINK_EVERY.y)
	_blink = maxf(0.0, _blink - delta)

	# Drifting a little after whoever is near, in the dark behind the bars.
	if watched != null and is_instance_valid(watched) and open > 0.0:
		var to := to_local(watched.global_position)
		var drift := Vector3(clampf(to.x * 0.02, -DRIFT, DRIFT), clampf((to.y + 1.0) * 0.01, -DRIFT * 0.5, DRIFT * 0.5), 0.0)
		for k in eyes.size():
			eyes[k].position = eyes[k].position.lerp(Vector3((k * 2.0 - 1.0) * APART / 2.0, 0.0, 0.0) + drift, 1.0 - exp(-2.0 * delta))
	_show()


func _show() -> void:
	var lid := open * (0.08 if _blink > 0.0 else 1.0)
	for eye in eyes:
		eye.visible = lid > 0.02
		eye.scale = Vector3(1.0, maxf(lid, 0.02), 1.0)
	light.light_energy = LIGHT * open
