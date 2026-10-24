extends Node3D
## A shadow with no owner (docs/superpowers/refs/underground/supernatural_refs.md): now and then the
## tall shadow of a man in a sombrero crosses the tiled wall where no one stands (the procession's
## dead man, Mignola's black shape: textures/painted/underground/shadow_figure.png). It only crosses
## where the watcher sees it from the corner of their eye; the moment they look at it, it is gone.
## Its wall runs along X at `wall_z`; it crosses between `from_x` and `to_x`.

const IMAGE := "res://textures/painted/underground/shadow_figure.png"
## Its size on the wall (m: wide, tall, and how far the decal reaches into the wall), how fast it
## crosses (m/s), how long between crossings (s).
const SIZE := Vector3(1.25, 0.6, 2.5)
const PACE := 1.1
const EVERY := Vector2(40.0, 90.0)
## Where the watcher's eye must be from it: not within LOOKED (degrees) of where they look, within
## SEEN_FROM (the corner of the eye); how fast it goes when looked at, and comes in.
const LOOKED := 22.0
const SEEN_FROM := 85.0
const VANISH := 12.0
const ARRIVE := 3.0

@export var wall_z := 0.0
## Whether it is the far wall (its face toward -z) or the back wall (toward +z).
@export var far := true
@export var from_x := -6.0
@export var to_x := 6.0
@export var seed := 17
## Whose eye it keeps to (else whichever camera is drawing).
var watcher: Camera3D
var decal: Decal

var _rng := RandomNumberGenerator.new()
var _next := 0.0
var _x := 0.0
var _going := 0
var _seen := false


func _ready() -> void:
	_rng.seed = seed
	_next = _rng.randf_range(EVERY.x, EVERY.y)
	decal = Decal.new()
	decal.name = "shadow"
	decal.size = SIZE
	decal.texture_albedo = load(IMAGE)
	decal.modulate = Color(0.0, 0.0, 0.0, 0.0)
	decal.upper_fade = 0.05
	decal.lower_fade = 0.05
	decal.visible = false
	add_child(decal)
	# (Projected into the wall, its image upright.)
	decal.rotation_degrees = Vector3(90.0, 180.0, 0.0) if far else Vector3(-90.0, 0.0, 180.0)


## Where it crosses (the middle of its way, at its height on the wall).
func crossing_middle() -> Vector3:
	return Vector3((from_x + to_x) / 2.0, SIZE.z / 2.0, wall_z)


## It crosses now, from whichever end is farther from where the eye looks.
func cross_now() -> void:
	var height := SIZE.z / 2.0
	var from_left := _angle_to(Vector3(from_x, height, wall_z)) > _angle_to(Vector3(to_x, height, wall_z))
	_going = 1 if from_left else -1
	_x = from_x if from_left else to_x
	_seen = false
	decal.visible = true
	decal.global_position = Vector3(_x, SIZE.z / 2.0, wall_z + (-0.15 if far else 0.15))


func _process(delta: float) -> void:
	if _going == 0:
		_next -= delta
		if _next <= 0.0:
			_next = _rng.randf_range(EVERY.x, EVERY.y)
			if _corner_of_eye(crossing_middle()):
				cross_now()
		return

	_x += _going * PACE * delta
	decal.global_position.x = _x
	var looked := _looked_at(decal.global_position)
	_seen = _seen or looked
	var alpha := decal.modulate.a
	alpha = maxf(0.0, alpha - VANISH * delta) if _seen else minf(0.9, alpha + ARRIVE * delta)
	decal.modulate = Color(0.0, 0.0, 0.0, alpha)

	if (_seen and alpha <= 0.0) or _x < minf(from_x, to_x) - 0.5 or _x > maxf(from_x, to_x) + 0.5:
		_going = 0
		decal.visible = false
		decal.modulate = Color(0.0, 0.0, 0.0, 0.0)


func _eye() -> Camera3D:
	if watcher != null and is_instance_valid(watcher):
		return watcher
	return get_viewport().get_camera_3d()


func _angle_to(at: Vector3) -> float:
	var eye := _eye()
	if eye == null:
		return 180.0
	var look := -eye.global_transform.basis.z
	return rad_to_deg(look.angle_to((at - eye.global_position).normalized()))


func _looked_at(at: Vector3) -> bool:
	return _angle_to(at) < LOOKED


func _corner_of_eye(at: Vector3) -> bool:
	var a := _angle_to(at)
	return a >= LOOKED and a < SEEN_FROM
