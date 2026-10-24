extends Node3D
## Ward (Copal, a hand spell): a ring of ghostly copal smoke that rises round
## you and goes with you for a few seconds. It covers you from other spells
## and from shots (arrows today, guns and spells later), not from blades:
## blows and men pass through it as through smoke. Your own shots and spells
## go out through it. Spirits will not cross it (later).
## Seen (docs/superpowers/specs/2026-10-23-ward-effects-design.md): it pours from your hand to the
## floor and runs round it, the wall rising front first on a skirt of smoke,
## embers of the burning copal drifting up in it; what it stops flashes,
## ripples the wall and falls; at its end it sinks and drains off across the
## floor.

const Fx := preload("res://scripts/Visual/Fx.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")
const MagicFx := preload("res://scripts/Visual/MagicFx.gd")
const GunFx := preload("res://scripts/Visual/GunFx.gd")

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
## Seconds each plume takes to rise, and the wall to sink away at the end.
const RISE := 0.25
const SINK := 0.5
## The pour: seconds for the smoke to reach the floor from your hand, then
## to run round the floor from the front to the back; how long the stream
## shows. The base of the wall below its middle (m).
const POUR_DOWN := 0.06
## How far a standing plume's top is eaten (the smoke look's tail_eat).
const TAIL_EAT := 0.45
const POUR_SWEEP := 0.35
const POUR_LIFE := 0.3
const BASE := -0.9
## Burning copal: its embers drifting up in the smoke (how many, how long
## one takes to rise), deep ember red-orange (marigold is the dead's).
const EMBERS := 12
const EMBER_RISE := 1.6
const EMBER := Color("#D9541E")
## A stopped shot: the puncture's flash, the ripple through the wall (how
## long, how wide), what fell lying on the floor.
const PUNCTURE_LIFE := 0.1
const RIPPLE_LIFE := 0.3
const RIPPLE_TO := 0.6
const DROP_LIFE := 4.0
## The end: the ring of smoke draining off across the floor (how long, how
## wide it spreads).
const DRAIN_LIFE := 0.8
const DRAIN_TO := 2.2
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
## Where it was cast toward, round the ring in its own space (radians).
var _front := 0.0
var _skirts: Array[MeshInstance3D] = []
var _embers: Array[MeshInstance3D] = []


## A ward round `player`, going with them for LIFE seconds.
static func cast_on(player: Node3D) -> Node3D:
	var ward: Node3D = (load("res://scripts/Magic/Ward.gd") as GDScript).new()
	ward.owner_body = player
	player.get_parent().add_child(ward)
	ward.global_position = player.global_position + Vector3.UP * HEIGHT
	ward.reset_physics_interpolation()
	ward._begin()
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
## `kind` says what it was ("ball", "arrow", "shard"): it falls to the floor.
static func turned_aside(context: Node, at: Vector3, direction: Vector3, ward: Node3D = null, kind: StringName = &"") -> void:
	Fx.dust(context, at, -direction, 0.6, "stone")
	Sfx.play(context, &"whoosh_light", at, -6.0, 0.6)

	if ward != null and is_instance_valid(ward) and ward.has_method("bulge"):
		ward.bulge(at)
		ward.struck(at, direction, kind, context)


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


## Placed round its owner (cast_on): its front the way they look, the pour
## from their hand, the skirt and the embers.
func _begin() -> void:
	if owner_body != null and is_instance_valid(owner_body):
		var ahead := -owner_body.global_basis.z
		_front = atan2(ahead.z, ahead.x) - rotation.y

	if MagicFx.allowed(self):
		_pour()
		_make_skirts()
		_make_embers()

	Sfx.play(self, &"whoosh", global_position, -8.0, 0.55)


## Seconds after the cast plume `i` begins to rise: once the smoke has
## run round the floor to it from the front.
func _rise_delay(i: int) -> float:
	var away := absf(angle_difference(_front, TAU * float(i) / float(PLUMES)))
	return POUR_DOWN + away / PI * POUR_SWEEP


## The stream of smoke from its owner's casting hand down to the floor at
## the front of the ring, eaten away over POUR_LIFE.
func _pour() -> void:
	var hand: Node = owner_body.get("hand") if owner_body != null else null
	var from: Vector3 = hand.circle_world_position() if hand != null and hand.has_method("circle_world_position") else global_position + Vector3.UP * 0.4
	var front := to_global(Vector3(cos(_front), BASE, sin(_front)) * Vector3(RADIUS, 1.0, RADIUS))
	var floor_hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(front + Vector3.UP * 0.5, front - Vector3.UP * 1.0, 1))
	var to: Vector3 = floor_hit["position"] if not floor_hit.is_empty() else front
	var stream := MeshInstance3D.new()
	stream.name = "WardPour"
	var drop := to - from
	stream.mesh = MeshVfx.plume(PackedVector3Array([Vector3.ZERO, drop * Vector3(0.3, 0.2, 0.3), drop * Vector3(0.75, 0.65, 0.75), drop]), 0.02, 0.2, 10)
	var look := _smoke_look(9.1)
	# Thin by your own eye (it leaves your hand), spilling wide where it meets
	# the floor; dim, see-through and broken up: from just above it a smooth
	# bright tube read as a blade of light, not smoke falling.
	look.set_shader_parameter(&"near_fade", 1.4)
	look.set_shader_parameter(&"tail_eat", 0.0)
	look.set_shader_parameter(&"energy", 0.45)
	look.set_shader_parameter(&"opacity", 0.22)
	look.set_shader_parameter(&"hardness", 0.25)
	look.set_shader_parameter(&"tiling", Vector2(0.8, 1.2))
	look.set_shader_parameter(&"churn", 0.05)
	stream.material_override = look
	stream.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stream.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	stream.set_meta(&"span", [from, to])
	stream.add_to_group(&"ward_pour")
	get_parent().add_child(stream)
	stream.global_position = from
	stream.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).tween_method(func(e: float): look.set_shader_parameter(&"erosion", e), 0.5, 1.0, POUR_LIFE).set_ease(Tween.EASE_IN)
	MagicFx._keep(stream, POUR_LIFE)


## The skirt of smoke at the foot of the wall: two halves running round the
## floor from the front, each eaten from its far end until the pour reaches
## it.
func _make_skirts() -> void:
	for side in [1.0, -1.0]:
		var path := PackedVector3Array()

		for k in 9:
			var turn: float = _front + side * PI * float(k) / 8.0
			path.append(Vector3(cos(turn) * RADIUS, BASE + 0.06, sin(turn) * RADIUS))

		var skirt := MeshInstance3D.new()
		skirt.name = "WardSkirt"
		skirt.mesh = MeshVfx.tendril(path, 0.14, 8)
		var look := _smoke_look(3.3 + side)
		look.set_shader_parameter(&"erosion", STANDING)
		look.set_shader_parameter(&"tail_eat", 3.0)
		skirt.material_override = look
		skirt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		skirt.add_to_group(&"ward_skirt")
		add_child(skirt)
		_skirts.append(skirt)


## Embers of the burning copal, inside the smoke, each rising on its own
## turn round the ring and coming round again.
func _make_embers() -> void:
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = EMBER
	glow.emission_enabled = true
	glow.emission = EMBER
	# Bright enough to bloom through the smoke in front of it.
	glow.emission_energy_multiplier = 8.0
	var mote := SphereMesh.new()
	mote.radius = 0.02
	mote.height = 0.04
	mote.radial_segments = 6
	mote.rings = 3

	for i in EMBERS:
		var ember := MeshInstance3D.new()
		ember.name = "WardEmber"
		ember.mesh = mote
		ember.material_override = glow
		ember.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ember.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		ember.add_to_group(&"ward_ember")
		add_child(ember)
		_embers.append(ember)

	_move_embers()


## Each ember's place now: round the ring just inside the smoke, rising
## from the floor to head height over EMBER_RISE, flickering in size; going
## out as the wall sinks.
func _move_embers() -> void:
	var sink := clampf((LIFE - _life) / SINK, 0.0, 1.0)

	for i in _embers.size():
		var t := fposmod(_life / EMBER_RISE + float(i) * 0.37, 1.0)
		var turn := TAU * float(i) / float(EMBERS) + 0.6 * t
		var reach := RADIUS * (0.95 + 0.06 * float(i % 3))
		_embers[i].position = Vector3(cos(turn) * reach, BASE + 0.1 + 1.25 * t, sin(turn) * reach)
		var flicker := 0.7 + 0.3 * sin(_life * (17.0 + float(i)) + float(i))
		_embers[i].scale = Vector3.ONE * flicker * sin(PI * t) * sink


## A shot or spell stopped at `at` going `direction` (turned_aside): a
## puncture of ward-white there, a ripple out through the wall, and what it
## was (`kind`, `thing` the stopped node) falling to the floor.
func struck(at: Vector3, direction: Vector3, kind: StringName, thing: Node) -> void:
	if not MagicFx.allowed(self):
		return

	var out := (at - global_position)
	out.y = 0.0
	out = out.normalized() if out.length() > 0.01 else -direction.normalized()
	var world := get_parent()
	var facing := Basis.looking_at(-out, Vector3.UP)
	var star := MeshInstance3D.new()
	star.name = "WardPuncture"
	star.mesh = GunFx._star(6, 0.16, 0.4)
	star.material_override = MeshVfx.look(CORE, BODY, EDGE, 3.0, 0.1, 1.0, 2.2)
	star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	star.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	star.add_to_group(&"ward_puncture")
	world.add_child(star)
	star.global_transform = Transform3D(facing, at)
	MagicFx._keep(star, PUNCTURE_LIFE)
	MagicFx.glint_light(self, at + out * 0.2, 1.4, 2.5, BODY)

	var ripple := MeshInstance3D.new()
	ripple.name = "WardRipple"
	ripple.mesh = MagicFx._ring_mesh(0.5, 0.2, 32)
	var look := MeshVfx.look(CORE, BODY, EDGE, 1.4, 0.15, 0.6, 6.1)
	look.set_shader_parameter(&"tail_eat", 0.0)
	look.set_shader_parameter(&"opacity", 0.7)
	ripple.material_override = look
	ripple.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ripple.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	ripple.add_to_group(&"ward_ripple")
	world.add_child(ripple)
	# Flat on the wall there: its plane square to `out`.
	ripple.global_transform = Transform3D(Basis(out.cross(Vector3.UP).normalized(), out, Vector3.UP), at)
	ripple.scale = Vector3.ONE * 0.05
	var grow := ripple.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).set_parallel(true)
	grow.tween_property(ripple, "scale", Vector3.ONE * RIPPLE_TO, RIPPLE_LIFE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	grow.tween_method(func(e: float): look.set_shader_parameter(&"erosion", e), 0.15, 1.0, RIPPLE_LIFE).set_ease(Tween.EASE_IN)
	MagicFx._keep(ripple, RIPPLE_LIFE)

	_drop(at + out * 0.05, out, kind, thing)


## What the ward stopped, falling dead to the floor from `at` (bounced a
## little back out along `out`): a ball flattened, the arrow, the shard's
## glass in flakes; lying DROP_LIFE.
func _drop(at: Vector3, out: Vector3, kind: StringName, thing: Node) -> void:
	var pieces := []

	match kind:
		&"ball":
			var lead := SphereMesh.new()
			lead.radius = 0.008
			lead.height = 0.016
			var grey := StandardMaterial3D.new()
			grey.albedo_color = Color("#5A5C60")
			grey.metallic = 0.7
			grey.roughness = 0.45
			lead.material = grey
			# Flattened where it struck.
			pieces.append([lead, Vector3(1.7, 0.55, 1.7), Vector3(0.02, 0.01, 0.02)])
		&"arrow":
			var visual: Variant = thing.get("_visual") if thing != null and is_instance_valid(thing) else null

			if visual is MeshInstance3D and (visual as MeshInstance3D).mesh != null:
				pieces.append([(visual as MeshInstance3D).mesh, (visual as MeshInstance3D).scale, Vector3(0.03, 0.03, 0.7)])
		&"shard":
			for i in 3:
				var flake := MagicFx.spearhead_mesh(0.02, 0.05 + 0.02 * float(i), 0.008)
				flake.surface_set_material(0, MagicFx.obsidian_look())
				pieces.append([flake, Vector3.ONE, Vector3(0.02, 0.05, 0.01)])

	for i in pieces.size():
		var piece := RigidBody3D.new()
		piece.name = "WardDrop"
		piece.collision_layer = 0
		piece.collision_mask = 1
		piece.mass = 0.02
		piece.set_meta(&"kind", String(kind))
		piece.add_to_group(&"ward_drop")
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = pieces[i][2]
		shape.shape = box
		piece.add_child(shape)
		var visual := MeshInstance3D.new()
		visual.mesh = pieces[i][0]
		visual.scale = pieces[i][1]
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		piece.add_child(visual)
		get_parent().add_child(piece)
		piece.global_position = at + Vector3.UP * 0.03 * float(i)
		piece.reset_physics_interpolation()
		piece.linear_velocity = out * 0.8 + Vector3.UP * 0.3
		piece.angular_velocity = Vector3(3.0, 2.0 * float(i), 1.0)
		MagicFx._keep(piece, DROP_LIFE)


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
	look.set_shader_parameter(&"tail_eat", TAIL_EAT)
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


## The plume nearest where the ward was cast toward (its front).
func front_plume() -> int:
	return posmod(roundi(_front / TAU * float(PLUMES)), PLUMES)


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
	# Each plume rising once the pour has run round to it, standing, then
	# sinking toward the floor as it is eaten away.
	var sink := clampf((LIFE - _life) / SINK, 0.0, 1.0)

	for i in _plumes.size():
		var rise := clampf((_life - _rise_delay(i)) / RISE, 0.0, 1.0)
		var eaten := lerpf(1.0, STANDING, rise * sink)
		_thinning[i] = maxf(_thinning[i] - delta, 0.0)
		var thin := THIN if _thinning[i] > 0.0 else 0.0
		var look := _plumes[i].material_override as ShaderMaterial
		look.set_shader_parameter(&"erosion", minf(eaten + thin, 1.0))
		# Up out of the floor with a ragged top (its top eaten away less and
		# less: squashed short, its noise read as a solid blade)...
		look.set_shader_parameter(&"tail_eat", lerpf(2.5, TAIL_EAT, smoothstep(0.0, 1.0, rise)))
		# ...and back down into it at the end (its foot stays put).
		var tall := lerpf(0.25, 1.0, sink)
		_plumes[i].scale = Vector3(1.0, tall, 1.0)
		_plumes[i].position = Vector3(0.0, BASE * (1.0 - tall), 0.0)

	# The skirt running round from the front, each half eaten from its far
	# end until the pour reaches it; going as the wall sinks.
	var run := clampf((_life - POUR_DOWN) / POUR_SWEEP, 0.0, 1.0)

	for skirt in _skirts:
		var look := skirt.material_override as ShaderMaterial
		look.set_shader_parameter(&"tail_eat", lerpf(3.0, 0.2, run))
		look.set_shader_parameter(&"erosion", lerpf(1.0, STANDING, sink))

	if not _embers.is_empty():
		_move_embers()

	rotation.y += TURN * delta


func _end() -> void:
	for ref in active.duplicate():
		if ref.get_ref() == self:
			active.erase(ref)

	_drain()
	queue_free()


## Its smoke draining off across the floor where it stood: a widening ring
## left in the world, eaten away over DRAIN_LIFE.
func _drain() -> void:
	if not MagicFx.allowed(self):
		return

	var foot := global_position + Vector3.UP * BASE
	var floor_hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(foot + Vector3.UP * 0.5, foot - Vector3.UP * 1.0, 1))
	var at: Vector3 = floor_hit["position"] if not floor_hit.is_empty() else foot
	var ring := MeshInstance3D.new()
	ring.name = "WardDrain"
	ring.mesh = MagicFx._ring_mesh(RADIUS, 0.4, 40)
	var look := _smoke_look(12.7)
	look.set_shader_parameter(&"near_fade", 0.0)
	look.set_shader_parameter(&"tail_eat", 0.0)
	look.set_shader_parameter(&"tiling", Vector2(3.0, 0.6))
	ring.material_override = look
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	ring.add_to_group(&"ward_drain")
	get_parent().add_child(ring)
	ring.global_position = at + Vector3.UP * 0.04
	var spread := ring.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).set_parallel(true)
	spread.tween_property(ring, "scale", Vector3(DRAIN_TO, 1.0, DRAIN_TO), DRAIN_LIFE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	spread.tween_method(func(e: float): look.set_shader_parameter(&"erosion", e), STANDING, 1.0, DRAIN_LIFE).set_ease(Tween.EASE_IN)
	MagicFx._keep(ring, DRAIN_LIFE)
