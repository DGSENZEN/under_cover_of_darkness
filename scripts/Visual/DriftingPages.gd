class_name DriftingPages
extends Node3D
## Loose pages lifted out of the librarian's arch on the corridor's draught (docs/superpowers/specs/
## 2026-10-24-lane-landmarks-design.md): now and then one to three lift out of the arch's foot, tumble out into the
## walk, then skate along the floor with the draught, slowing, settle flat and fade. Blank (no letters), pale paper
## that reads against the dark floor. In its parent's frame (the lane's); they ride `wind` (the lane's draught_now),
## harder as it gusts, and never past `end_x`.

## How often they come (s), how many at once, how long each lasts (s), how far out of the arch they tumble into the
## walk (its near and far edges, z), how much of the wind they take, the most there may be at once.
const COUNT := Vector2i(1, 3)
const LIFE := Vector2(4.0, 7.0)
const WALK := Vector2(0.5, 3.0)
## The line down the walk's middle they make for (z), where the cart and the nahual do not hide them from the mouth.
const PATH := Vector2(0.8, 1.6)
const CARRY := 2.8
const MOST := 6
## A page's size (m), how fast it lifts out (up, out into the walk), how fast it falls, how it slows on the floor.
const SIZE := Vector2(0.24, 0.32)
const LIFT := Vector2(1.3, 1.9)
const OUT := Vector2(0.9, 1.5)
const FALL := 1.6
const SKID := 1.2
const PAPER := Color(0.93, 0.9, 0.82)

## Where they lift (the arch's foot), how often, where the lane ends.
@export var from := Vector3.ZERO
@export var every := Vector2(8.0, 20.0)
@export var end_x := 16.8
@export var seed := 23
## The wind they ride (returns m/s, the parent's frame).
var wind: Callable = func(): return Vector3.ZERO
## The pages aloft or lying, and how many have come.
var pages: Array[MeshInstance3D] = []
var released := 0

var _rng := RandomNumberGenerator.new()
var _next := 0.0
var _state := {}
var _mesh: BoxMesh


func _ready() -> void:
	_rng.seed = seed
	_next = _rng.randf_range(every.x, every.y)
	_mesh = BoxMesh.new()
	_mesh.size = Vector3(SIZE.x, 0.003, SIZE.y)


## One to three pages lift out now; returns how many.
func release_now() -> int:
	var n := _rng.randi_range(COUNT.x, COUNT.y)
	for i in n:
		if pages.size() >= MOST:
			_retire(pages[0])
		var page := MeshInstance3D.new()
		page.name = "page"
		page.mesh = _mesh
		page.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		page.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		var look := StandardMaterial3D.new()
		look.albedo_color = PAPER
		look.emission_enabled = true
		look.emission = PAPER
		look.emission_energy_multiplier = 0.9
		look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		look.cull_mode = BaseMaterial3D.CULL_DISABLED
		page.material_override = look
		add_child(page)
		page.position = from + Vector3(_rng.randf_range(-0.6, 0.6), _rng.randf_range(0.0, 0.3), 0.0)
		page.rotation = Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(0.0, TAU), _rng.randf_range(-1.0, 1.0))
		_state[page] = {
			"vel": Vector3(_rng.randf_range(-0.2, 0.4), _rng.randf_range(LIFT.x, LIFT.y), -_rng.randf_range(OUT.x, OUT.y)),
			"spin": Vector3(_rng.randf_range(-4.0, 4.0), _rng.randf_range(-2.0, 2.0), _rng.randf_range(-4.0, 4.0)),
			"age": 0.0, "life": _rng.randf_range(LIFE.x, LIFE.y), "lane": _rng.randf_range(PATH.x, PATH.y),
			"down": false, "look": look,
		}
		pages.append(page)
	released += n
	return n


func _process(delta: float) -> void:
	_next -= delta
	if _next <= 0.0:
		_next = _rng.randf_range(every.x, every.y)
		release_now()

	var blow: Vector3 = wind.call()
	for page: MeshInstance3D in pages.duplicate():
		var s: Dictionary = _state[page]
		s["age"] += delta
		var vel: Vector3 = s["vel"]
		var at := page.position
		if not s["down"]:
			# Aloft: carried on the draught, out into the walk to its own line across it, falling, tumbling.
			var carry := Vector3(blow.x * CARRY, 0.0, (s["lane"] - at.z) * 0.9)
			vel.x = lerpf(vel.x, carry.x, 1.0 - exp(-1.5 * delta))
			vel.z = lerpf(vel.z, carry.z, 1.0 - exp(-1.2 * delta))
			vel.y = maxf(vel.y - 4.0 * delta, -FALL)
			page.rotation += (s["spin"] as Vector3) * delta
			at += vel * delta
			if at.y <= 0.004 and vel.y < 0.0:
				# On the floor: it lies flat where it fell, turned as it was.
				at.y = 0.004
				s["down"] = true
				page.rotation = Vector3(0.0, page.rotation.y, 0.0)
		else:
			# Lying: it skates on with the draught, slowing, and lies still.
			vel.y = 0.0
			vel.z = 0.0
			vel.x = lerpf(vel.x, blow.x * CARRY * 0.6, 1.0 - exp(-SKID * delta))
			at += vel * delta
		at.z = clampf(at.z, WALK.x, from.z) if s["age"] > 0.5 else at.z
		page.position = at
		s["vel"] = vel
		# Its last second it fades.
		var left: float = s["life"] - s["age"]
		(s["look"] as StandardMaterial3D).albedo_color.a = clampf(left, 0.0, 1.0)
		if left <= 0.0 or at.x > end_x:
			_retire(page)


func _retire(page: MeshInstance3D) -> void:
	pages.erase(page)
	_state.erase(page)
	page.queue_free()
