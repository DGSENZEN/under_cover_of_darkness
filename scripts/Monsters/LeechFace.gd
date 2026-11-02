extends Node3D
## A face on your face: the skull itself, come round to you, its mouth at yours, and what it
## takes from you goes in there. Winding up to a gulp it rears, chin up, and gapes; on the
## gulp it lunges and clamps down, tongue up, and swallows, the light going down its throat;
## between gulps it worries at you and sucks, jaw working. Drawn as the viewmodel is, a child
## of LeechHands.gd. You can still see past it, under its jaw and to the sides.

const AnimaSkullScript := preload("res://scripts/Monsters/AnimaSkull.gd")

## How big, in the view's miniature; where its mouth is held, as you look (m).
const SIZE := 0.98
const HOLD := Vector3(0.0, 0.01, -0.62)
## Where its mouth is, on the model: between its jaws, at its teeth.
const MOUTH := Vector3(0.0, -0.13, -0.11)
## Winding up: how far it draws back; on the gulp: how far it comes at you. Its tilt.
const DRAWS_BACK := 0.13
const LUNGES := 0.17
## How near it comes for the last long gulp, as you die: all you can see.
const LAST_COMES := 0.52
const REARS := 0.26
const BITES_DOWN := 0.16
## The jaw: sucking between gulps, gaping winding up, clamped on the gulp. How much it works.
const JAW_SUCKS := 0.56
const JAW_WORKS := 0.09
const JAW_GAPES := 1.0
const JAW_CLAMPS := 0.2
## Worrying at you, side to side, this much, this fast.
const WORRY := 0.13
const WORRY_RATE := 4.1
## In from out of your sight, when it gets hold.
const COMES_FROM := Vector3(0.0, -0.32, -0.7)
const FleshShader := preload("res://scripts/Monsters/anima_flesh.gdshader")
const BRUSH := preload("res://textures/painted/eclipse/brush.png")
## This close you need to see into it: more light in its skin than the world's has.
const FILL := 0.72
const RIM := 0.14
## Bone should stay bone in it, not the red the painted fill gives things in the dark.
const FILL_SKY := Color(0.42, 0.42, 0.37)
const FILL_GROUND := Color(0.4, 0.35, 0.27)
const RIM_COLOUR := Color(0.42, 0.46, 0.34)

var _rig: Node3D
var _clock := 0.0
var _near := 0.0
var _near_speed := 0.0
var _jaw := 0.5
var _jaw_speed := 0.0
var _tongue := 0.0
var _flare := 0.0
var _at := HOLD
var _fov := 58.0


func _init(layer: int, z_clip: float, fov: float) -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var look := ShaderMaterial.new()
	look.shader = FleshShader
	look.set_shader_parameter(&"stroke_sheet", BRUSH)
	look.set_shader_parameter(&"wet", 0.0)
	look.set_shader_parameter(&"fill", FILL)
	look.set_shader_parameter(&"rim", RIM)
	look.set_shader_parameter(&"fill_sky", FILL_SKY)
	look.set_shader_parameter(&"fill_ground", FILL_GROUND)
	look.set_shader_parameter(&"rim_colour", RIM_COLOUR)
	look.set_shader_parameter(&"z_clip", z_clip)
	look.set_shader_parameter(&"fov_override", fov)
	_rig = AnimaSkullScript.new(look, layer, z_clip, fov)
	add_child(_rig)
	_fov = fov


func jaw() -> float:
	return _rig.jaw_open()


func near() -> float:
	return _near


func tongue() -> float:
	return _rig.tongue_up()


func throat() -> float:
	return _rig.throat()


## Where its mouth is on the screen, 0..1.
func mouth_on_screen(aspect: float) -> Vector2:
	var tall := tan(deg_to_rad(_fov) * 0.5) * maxf(-_at.z, 0.001)
	return Vector2(_at.x / (tall * aspect), -_at.y / tall) * 0.5 + Vector2(0.5, 0.5)


## It drinks. `gulp` is 1 as one lands and fades to 0; `coming`, how near the next is, 0..1;
## `arrived`, how far in from out of your sight it has come; `lag`, of the gulp, so two don't
## move as one.
func drink(delta: float, gulp: float, coming: float, arrived: float, fed: float, across: float, lag: float, last := 0.0) -> void:
	_clock += delta
	var wind := smoothstep(0.5, 1.0, coming + lag) if gulp <= 0.0 else 0.0
	var biting := gulp * gulp
	var worry := 1.0 - maxf(wind, biting)
	# Its jaw: snapped to where it should be, faster on the clamp.
	var sucking := JAW_SUCKS + sin(_clock * 9.0) * JAW_WORKS + sin(_clock * 15.7) * JAW_WORKS * 0.5
	var jaw_to := lerpf(lerpf(lerpf(sucking, JAW_GAPES, wind), JAW_CLAMPS, smoothstep(0.1, 0.55, gulp)), JAW_GAPES, last)
	var jaw_rate := minf(TAU * (15.0 if gulp > 0.4 else 7.0), 0.8 / delta)
	_jaw_speed += (jaw_rate * jaw_rate * (jaw_to - _jaw) - 2.0 * 0.8 * jaw_rate * _jaw_speed) * delta
	_jaw += _jaw_speed * delta
	# It comes at you on the gulp, and draws back to wind up: with the weight to overshoot.
	var near_to := lerpf(biting * LUNGES - wind * DRAWS_BACK, LAST_COMES, last)
	var near_rate := minf(TAU * 8.0, 0.8 / delta)
	_near_speed += (near_rate * near_rate * (near_to - _near) - 2.0 * 0.45 * near_rate * _near_speed) * delta
	_near += _near_speed * delta
	_tongue = lerpf(_tongue, 1.0 if gulp > 0.25 else 0.32 + sin(_clock * 7.3) * 0.28 * worry, 1.0 - exp(-18.0 * delta))
	_rig.open_to(clampf(_jaw, 0.0, 1.0), clampf(_tongue, 0.0, 1.0))
	# The light goes down it with each swallow, and stays a little higher the more it has had.
	_flare = lerpf(_flare, 0.1 + fed * 0.2 + maxf(gulp, last) * 0.8, 1.0 - exp(-14.0 * delta))
	_rig.throat_to(_flare)
	_rig.paint(fed, 0.0, 0.0)
	var tilt := Basis(Vector3.RIGHT, wind * REARS - biting * BITES_DOWN + sin(_clock * 2.1) * 0.02)
	var turn := Basis(Vector3.UP, sin(_clock * WORRY_RATE) * WORRY * worry + across * -0.5) * Basis(Vector3.BACK, sin(_clock * 2.9) * WORRY * 0.5 * worry + cos(_clock * 37.0) * 0.008 * (1.0 + fed))
	var facing := Basis(Vector3.UP, PI) * turn * tilt
	var gone := pow(1.0 - arrived, 2.0)
	_at = HOLD + Vector3(across, 0.0, 0.0)
	basis = facing.scaled(Vector3.ONE * SIZE)
	position = _at + COMES_FROM * gone + Vector3(0.0, 0.0, _near) - facing * (MOUTH * SIZE)
