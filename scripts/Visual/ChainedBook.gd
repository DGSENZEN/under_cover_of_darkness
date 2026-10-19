class_name ChainedBook
extends Node3D
## The book the librarian is working on (docs/superpowers/specs/2026-10-17-librarian-shop-design.md): chained to
## his desk and nailed shut, it is not yet exorcised. Now and then it strains: its cover lifts against the chain on
## its hinge in jerks, and drops shut. (The words that try to crawl out of it, and the ward that pushes them back,
## come with Part 2.)

## How often it strains (s), for how long, how far its cover lifts at most (degrees).
const STRAIN_EVERY := Vector2(14.0, 30.0)
const STRAIN_FOR := 1.6
const LIFT_DEG := 12.0

## Its cover, and the ends of the hinge along its spine (world) the cover lifts about.
@export var cover: MeshInstance3D
@export var block: MeshInstance3D
@export var hinge_a := Vector3.ZERO
@export var hinge_b := Vector3(0, 0, 1)
@export var seed := 41
## Its chain, swung about the desk's ring (`chain_anchor`) so its end stays on the cover's staple (`staple`, shut).
@export var chain: MeshInstance3D
@export var chain_anchor := Vector3.ZERO
@export var staple := Vector3.ZERO

## How hard it strains now (0-1), and how far its cover is lifted (degrees).
var strain := 0.0
var angle := 0.0
## The cover's transform shut.
var cover_rest := Transform3D.IDENTITY

var _rng := RandomNumberGenerator.new()
var _next := 0.0
var _clock := -1.0
var _axis := Vector3.FORWARD
var _chain_rest := Transform3D.IDENTITY


func _ready() -> void:
	_rng.seed = seed
	_next = _rng.randf_range(STRAIN_EVERY.x, STRAIN_EVERY.y)
	if cover == null:
		return
	# (Moved every frame: drawn where they are, not interpolated between physics ticks.)
	for part: Node3D in [cover, chain]:
		if part != null:
			part.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF

	cover_rest = cover.global_transform
	if chain != null:
		_chain_rest = chain.global_transform
	_axis = (hinge_b - hinge_a).normalized()
	# (The way round that lifts the fore-edge: a point of the cover beyond the hinge must rise.)
	var middle := (cover.global_transform * cover.get_aabb()).get_center()
	if (Basis(_axis, 0.1) * (middle - hinge_a)).y < (middle - hinge_a).y:
		_axis = -_axis


## It strains now (the stills; it strains by itself).
func strain_now() -> void:
	_clock = 0.0


func _process(delta: float) -> void:
	if cover == null:
		return

	_next -= delta
	if _next <= 0.0 and _clock < 0.0:
		strain_now()
		_next = _rng.randf_range(STRAIN_EVERY.x, STRAIN_EVERY.y)

	if _clock >= 0.0:
		_clock += delta
		var t := _clock / STRAIN_FOR
		# Swelling and falling over the strain, in jerks against the chain.
		var swell := sin(PI * clampf(t, 0.0, 1.0))
		var jerk := 0.55 + 0.45 * (1.0 if sin(_clock * 21.0) > 0.0 else 0.0)
		strain = swell
		angle = LIFT_DEG * swell * jerk
		if t >= 1.0:
			_clock = -1.0
			strain = 0.0
			angle = 0.0

	var turn := Transform3D(Basis(_axis, deg_to_rad(angle)), Vector3.ZERO)
	cover.global_transform = Transform3D.IDENTITY.translated(hinge_a) * turn * Transform3D.IDENTITY.translated(-hinge_a) * cover_rest

	# The chain pulled after the staple: swung about its ring on the desk.
	if chain != null:
		var swing := _swing()
		chain.global_transform = Transform3D.IDENTITY.translated(chain_anchor) * Transform3D(swing, Vector3.ZERO) \
			* Transform3D.IDENTITY.translated(-chain_anchor) * _chain_rest


## Where the cover's staple is now (world).
func staple_now() -> Vector3:
	return hinge_a + Basis(_axis, deg_to_rad(angle)) * (staple - hinge_a)


## How far the chain's end is from the staple it is locked to (m): nothing, unless something is wrong.
func staple_gap() -> float:
	if chain == null:
		return 0.0
	return (chain_anchor + _swing() * (staple - chain_anchor)).distance_to(staple_now())


## The chain's swing about its ring after the staple, and its straightening as it is pulled taut (a stretch along
## its line by as much as the staple has gone from the ring).
func _swing() -> Basis:
	var was := staple - chain_anchor
	var now := staple_now() - chain_anchor
	var turn := Basis(Quaternion(was.normalized(), now.normalized())) if was.normalized().dot(now.normalized()) < 0.999999 \
		else Basis.IDENTITY
	var d := now.normalized()
	var k := now.length() / maxf(was.length(), 1e-6) - 1.0
	var taut := Basis(Vector3(1, 0, 0) + d * d.x * k, Vector3(0, 1, 0) + d * d.y * k, Vector3(0, 0, 1) + d * d.z * k)
	return taut * turn
