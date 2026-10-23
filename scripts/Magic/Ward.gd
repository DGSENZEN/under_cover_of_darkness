extends Node3D
## Ward (Copal, a hand spell): a ring of ghostly copal smoke that rises round
## you and goes with you for a few seconds. It covers you from other spells
## and from shots (arrows today, guns and spells later), not from blades:
## blows and men pass through it as through smoke. Your own shots and spells
## go out through it. Spirits will not cross it (later).

const Fx := preload("res://scripts/Visual/Fx.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")

const RADIUS := 1.0
const LIFE := 4.0
## Its middle, above its owner's origin (the waist).
const HEIGHT := 0.0
## How many puffs make the ring, and how fast it turns (radians a second).
const PUFFS := 16
const TURN := 0.6

## Every ward standing, as weak references.
static var active: Array = []

var owner_body: Node3D = null

var _life := 0.0
var _puffs: Array[MeshInstance3D] = []


## A ward round `player`, going with them for LIFE seconds.
static func cast_on(player: Node3D) -> Node3D:
	var ward: Node3D = (load("res://scripts/Magic/Ward.gd") as GDScript).new()
	ward.owner_body = player
	player.get_parent().add_child(ward)
	ward.global_position = player.global_position + Vector3.UP * HEIGHT
	ward.reset_physics_interpolation()
	active.append(weakref(ward))
	return ward


## Where the segment `from` -> `to` first comes into a ward from outside it,
## for a shot or spell by `shooter` (not the ward's own owner); Vector3.INF
## if it meets none.
static func stops(from: Vector3, to: Vector3, shooter: Object) -> Vector3:
	var nearest := Vector3.INF
	var best := INF

	for ref in active.duplicate():
		var ward: Node3D = ref.get_ref()

		if ward == null or not is_instance_valid(ward) or ward.is_queued_for_deletion():
			active.erase(ref)
			continue

		if ward.owner_body == shooter:
			continue

		var middle: Vector3 = ward.global_position

		# From inside it, it does not stop (it covers what is in it from what
		# is out of it).
		if from.distance_to(middle) <= RADIUS:
			continue

		var hit: Variant = Geometry3D.segment_intersects_sphere(from, to, middle, RADIUS)

		if hit is PackedVector3Array and not (hit as PackedVector3Array).is_empty():
			var at: Vector3 = (hit as PackedVector3Array)[0]
			var along := from.distance_to(at)

			if along < best:
				best = along
				nearest = at

	return nearest


## Something stopped at `at` by a ward: a puff of its smoke, a soft sound.
static func turned_aside(context: Node, at: Vector3, direction: Vector3) -> void:
	Fx.dust(context, at, -direction, 0.6, "stone")
	Sfx.play(context, &"whoosh_light", at, -6.0, 0.6)


func _ready() -> void:
	var smoke := SphereMesh.new()
	smoke.radius = 0.18
	smoke.height = 0.3
	smoke.radial_segments = 8
	smoke.rings = 4
	var look := StandardMaterial3D.new()
	look.albedo_color = Color(0.74, 0.8, 0.72, 0.35)
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.cull_mode = BaseMaterial3D.CULL_DISABLED
	smoke.material = look

	for i in PUFFS:
		var puff := MeshInstance3D.new()
		puff.mesh = smoke
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(puff)
		_puffs.append(puff)

	Sfx.play(self, &"whoosh", global_position, -8.0, 0.55)


func _physics_process(delta: float) -> void:
	_life += delta

	if _life >= LIFE or owner_body == null or not is_instance_valid(owner_body):
		_end()
		return

	global_position = owner_body.global_position + Vector3.UP * HEIGHT


func _process(_delta: float) -> void:
	# Risen in a quarter second, sinking away in the last half.
	var rise := clampf(_life / 0.25, 0.0, 1.0) * clampf((LIFE - _life) / 0.5, 0.0, 1.0)

	for i in _puffs.size():
		var turn := TAU * float(i) / float(_puffs.size()) + _life * TURN
		var bob := sin(_life * 2.3 + float(i) * 1.7) * 0.06
		_puffs[i].position = Vector3(cos(turn) * RADIUS, bob - 0.3 * (1.0 - rise), sin(turn) * RADIUS)
		_puffs[i].scale = Vector3.ONE * (0.6 + 0.4 * rise) * (1.0 + 0.15 * sin(_life * 1.3 + float(i)))


func _end() -> void:
	for ref in active.duplicate():
		if ref.get_ref() == self:
			active.erase(ref)

	queue_free()
