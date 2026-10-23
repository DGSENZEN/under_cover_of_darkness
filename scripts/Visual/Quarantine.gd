class_name Quarantine
extends Node3D
## The books in the librarian's quarantine cage (docs/superpowers/specs/2026-10-17-librarian-shop-design.md), still
## waiting to be exorcised: each stirs now and then, a small jolt on its shelf, each on its own clock, never in step.

## How often each twitches (s), how long a jolt lasts, how far it turns (degrees) and lifts (m).
const EVERY := Vector2(6.0, 20.0)
const JOLT := 0.9
const TURN_DEG := 6.5
const LIFT := 0.026

@export var books: Array[MeshInstance3D] = []
@export var seed := 67

## How many times each has twitched; how many frames saw two or more begin together.
var jolts: Array[int] = []
var together := 0

var _rng := RandomNumberGenerator.new()
var _rest: Array[Transform3D] = []
var _pivot: Array[Vector3] = []
var _next: Array[float] = []
var _clock: Array[float] = []
var _axis: Array[Vector3] = []
var _age := 0.0


func _ready() -> void:
	_rng.seed = seed

	for book in books:
		# (Moved every frame: drawn where it is, not interpolated between physics ticks.)
		book.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		_rest.append(book.global_transform)
		var box: AABB = book.global_transform * book.get_aabb()
		# (About the foot of its spine, as a book rocks on its shelf.)
		_pivot.append(Vector3(box.get_center().x, box.position.y, box.get_center().z))
		_next.append(_rng.randf_range(1.0, EVERY.y))
		_clock.append(-1.0)
		_axis.append(Vector3.FORWARD)
		jolts.append(0)


func _process(delta: float) -> void:
	_age += delta
	var began := 0

	for k in books.size():
		_next[k] -= delta
		if _next[k] <= 0.0 and _clock[k] < 0.0:
			_clock[k] = 0.0
			_next[k] = _rng.randf_range(EVERY.x, EVERY.y)
			var a := _rng.randf_range(0.0, TAU)
			_axis[k] = Vector3(cos(a), 0.0, sin(a))
			jolts[k] += 1
			began += 1

		var phase := _age * 2.3 + k * 1.73 + seed
		var breath_turn := deg_to_rad(0.7) * sin(phase)
		var breath_lift := 0.008 * (0.5 + 0.5 * sin(phase * 0.9))
		var turn := 0.0
		var lift := 0.0
		if _clock[k] >= 0.0:
			_clock[k] += delta
			var t := _clock[k] / JOLT
			var kick := sin(PI * clampf(t, 0.0, 1.0)) * (0.7 + 0.3 * pow(sin(t * TAU * 2.5), 2.0))
			turn = deg_to_rad(TURN_DEG) * kick
			lift = LIFT * kick
			if t >= 1.0:
				_clock[k] = -1.0
				turn = 0.0
				lift = 0.0

		var p := _pivot[k]
		var jolt := Transform3D(Basis(_axis[k], turn + breath_turn), Vector3(0.0, lift + breath_lift, 0.0))
		books[k].global_transform = Transform3D.IDENTITY.translated(p) * jolt * Transform3D.IDENTITY.translated(-p) * _rest[k]

	if began >= 2:
		together += 1
