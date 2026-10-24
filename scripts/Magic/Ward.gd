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
## The ring: how many plumes of smoke rise round it, how fast it turns
## (radians a second), and its colours (the ward colour, a ghostly core, a
## cool edge).
const PLUMES := 12
const TURN := 0.6
const CORE := Color("#F2FAFC")
const BODY := Color("#CFE8F0")
## (Close to the body: wide apart, the noise reads as camouflage.)
const EDGE := Color("#A9C9D4")
## Seconds it takes to rise, and to sink away at the end.
const RISE := 0.25
const SINK := 0.5
## Eaten this far while it stands (1 is gone).
const STANDING := 0.4
## A stopped shot's bulge: its plumes, how long it lasts, how many at once,
## and how much the plumes beside it thin, for how long.
const BULGE_PLUMES := 3
const BULGE_LIFE := 0.45
const MOST_BULGES := 6
const THIN := 0.3
const THIN_FOR := 0.4

## Every ward standing, as weak references.
static var active: Array = []

var owner_body: Node3D = null

var _life := 0.0
var _plumes: Array[MeshInstance3D] = []
## Each plume's thinning left (seconds), from a bulge beside it.
var _thinning: Array[float] = []
## The bulges standing (weak references to their roots).
var _bulges: Array = []


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
## for a shot or spell by `shooter` (not the ward's own owner), and which
## ward: {at, ward}; {} if it meets none.
static func stopped_by(from: Vector3, to: Vector3, shooter: Object) -> Dictionary:
	var found := {}
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
				found = {"at": at, "ward": ward}

	return found


## Where a shot first comes into a ward (stopped_by); Vector3.INF if none.
static func stops(from: Vector3, to: Vector3, shooter: Object) -> Vector3:
	var found := stopped_by(from, to, shooter)
	return found["at"] if not found.is_empty() else Vector3.INF


## Something stopped at `at` by a ward: a puff of its smoke, a soft sound,
## and the ward's smoke bulging there.
static func turned_aside(context: Node, at: Vector3, direction: Vector3, ward: Node3D = null) -> void:
	Fx.dust(context, at, -direction, 0.6, "stone")
	Sfx.play(context, &"whoosh_light", at, -6.0, 0.6)

	if ward != null and is_instance_valid(ward) and ward.has_method("bulge"):
		ward.bulge(at)


func _ready() -> void:
	for i in PLUMES:
		var turn := TAU * float(i) / float(PLUMES)
		var plume := MeshInstance3D.new()
		plume.name = "WardPlume"
		# Tall enough to stand round your head as well as your feet, wide
		# enough that each runs into the next: one ring, not blades.
		plume.mesh = MeshVfx.plume(_plume_path(turn, 1.35 + 0.35 * float(i % 3) / 2.0), 0.12, 0.34, 12)
		plume.material_override = _smoke_look(float(i) * 1.7)
		plume.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		plume.add_to_group(&"ward_plume")
		add_child(plume)
		_plumes.append(plume)
		_thinning.append(0.0)

	Sfx.play(self, &"whoosh", global_position, -8.0, 0.55)


## A plume rising from about the feet at `turn` round the ring, curling on
## round it as it climbs `tall` metres. In the ward's own space.
static func _plume_path(turn: float, tall: float) -> PackedVector3Array:
	var path := PackedVector3Array()

	for k in 5:
		var t := float(k) / 4.0
		# Curling on round the ring, leaning in and out as it climbs.
		var round_by := turn + 0.7 * t
		var reach := RADIUS * (1.0 + 0.08 * sin(t * PI * 2.0 + turn * 3.0))
		path.append(Vector3(cos(round_by) * reach, -0.9 + tall * t, sin(round_by) * reach))

	return path


## Ghostly copal smoke: the ward colours, unshaded and low, a little
## see-through, big soft shapes (the shot's approved look).
static func _smoke_look(seed: float) -> ShaderMaterial:
	var look := MeshVfx.look(CORE, BODY, EDGE, 0.75, 1.0, 0.35, seed)
	# Feathered and see-through: against the night its bitten shapes read as
	# blotches if they are hard and thick.
	look.set_shader_parameter(&"opacity", 0.45)
	look.set_shader_parameter(&"tiling", Vector2(0.4, 0.6))
	look.set_shader_parameter(&"hardness", 0.16)
	look.set_shader_parameter(&"tail_eat", 0.45)
	look.set_shader_parameter(&"rim", 2.4)
	look.set_shader_parameter(&"core_reach", 0.5)
	# You see out through it from inside.
	look.set_shader_parameter(&"near_fade", 1.6)
	return look


## A shot stopped at `at`: the smoke there pushed out in short plumes that
## settle, the plumes beside it thinning for a moment.
func bulge(at: Vector3) -> void:
	_bulges = _bulges.filter(func(ref): return ref.get_ref() != null and is_instance_valid(ref.get_ref()))

	while _bulges.size() >= MOST_BULGES:
		var oldest: Node = _bulges.pop_front().get_ref()

		if oldest != null and is_instance_valid(oldest):
			oldest.queue_free()

	var local := to_local(at)
	var out := Vector3(local.x, 0.0, local.z).normalized() if Vector2(local.x, local.z).length() > 0.01 else Vector3.FORWARD
	var root := Node3D.new()
	root.name = "WardBulge"
	add_child(root)
	root.position = local

	for k in BULGE_PLUMES:
		var spread := (float(k) - 1.0) * 0.12
		var path := PackedVector3Array([Vector3.ZERO, out * 0.12 + Vector3(0, spread, 0), out * 0.24 + Vector3(0, spread * 1.6 + 0.04, 0)])
		var puff := MeshInstance3D.new()
		puff.mesh = MeshVfx.plume(path, 0.05, 0.12, 8)
		var look := _smoke_look(5.3 + float(k))
		puff.material_override = look
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		puff.add_to_group(&"ward_bulge")
		root.add_child(puff)
		var fade := puff.create_tween()
		fade.tween_method(func(e: float): look.set_shader_parameter(&"erosion", e), STANDING, 1.0, BULGE_LIFE)

	root.get_tree().create_timer(BULGE_LIFE, false, true).timeout.connect(root.queue_free)
	_bulges.append(weakref(root))

	# The two plumes either side of it round the ring thin (every plume
	# stands at the ward's middle: it is where each rises round it that
	# counts, in the ward's own turning space).
	var round_at := atan2(local.z, local.x)
	var order := range(_plumes.size())
	order.sort_custom(func(a, b): return absf(angle_difference(round_at, TAU * float(a) / float(PLUMES))) < absf(angle_difference(round_at, TAU * float(b) / float(PLUMES))))

	for i in order.slice(0, 2):
		_thinning[i] = THIN_FOR


func bulge_count() -> int:
	_bulges = _bulges.filter(func(ref): return ref.get_ref() != null and is_instance_valid(ref.get_ref()) and not (ref.get_ref() as Node).is_queued_for_deletion())
	return _bulges.size()


func _physics_process(delta: float) -> void:
	_life += delta

	if _life >= LIFE or owner_body == null or not is_instance_valid(owner_body):
		_end()
		return

	global_position = owner_body.global_position + Vector3.UP * HEIGHT


func _process(delta: float) -> void:
	# Rising out of nothing, standing, then eaten away as it sinks.
	var rise := clampf(_life / RISE, 0.0, 1.0)
	var sink := clampf((LIFE - _life) / SINK, 0.0, 1.0)
	var eaten := lerpf(1.0, STANDING, rise * sink)

	for i in _plumes.size():
		_thinning[i] = maxf(_thinning[i] - delta, 0.0)
		var thin := THIN if _thinning[i] > 0.0 else 0.0
		(_plumes[i].material_override as ShaderMaterial).set_shader_parameter(&"erosion", minf(eaten + thin, 1.0))

	rotation.y += TURN * delta


func _end() -> void:
	for ref in active.duplicate():
		if ref.get_ref() == self:
			active.erase(ref)

	queue_free()
