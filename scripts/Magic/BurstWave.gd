extends Node3D
## What you see of the Burst: dark amethyst spikes (assets/magic/burst_glass.glb) tearing up
## through the floor in rings, tall near where it was cast and short at its edge, each full of the
## spell as it comes up and cooling, then cracking and falling to rubble, and gone. Nothing in it
## touches anything: ObsidianBurst.gd does the hitting. Spikes and chunks are drawn on a MultiMesh
## a shape, so a cast costs little however many there are.

const MagicFx := preload("res://scripts/Visual/MagicFx.gd")
const Fx := preload("res://scripts/Visual/Fx.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")

## The rings: how far apart (m), the first how far out, how many to a metre round; a share go
## missing, so it isn't a pattern.
const RING_APART := 0.68
const RING_FIRST := 0.9
const PER_METRE := 1.05
const GAPS := 0.12
const SCATTER := 0.2
## How tall, near and at the edge (m), against each other; how much wider than the model; how far
## they lean out (radians).
const TALL_NEAR := 1.5
const TALL_EDGE := 0.45
const TALL_VARIES := Vector2(0.75, 1.2)
const WIDER := 1.25
const LEANS := 0.25
## Coming up (s): with a kick past its height, and how much of the spell it comes up with, cooling
## over how long.
const RISES := 0.09
const OVERSHOOT := 0.14
const FULL_OF_IT := 1.1
const COOLS := 0.9
## Standing: how long after the wave has passed, longest last; how it sinks as it goes.
const STANDS := Vector2(0.55, 1.0)
const SINKS := 0.12
## Falling to pieces: how many, how hard they burst, how long the rubble lies.
const CHUNKS_EACH := Vector2i(3, 4)
const GRAVITY := 11.0
const BURST_SPEED := Vector2(0.5, 1.8)
const RUBBLE_LIES := 1.4
const RUBBLE_GOES := 0.5
## How often a spike throws dust as it breaks through, and as it falls (one in).
const DUST_ONE_IN := 4
const FLOOR_LOOK := 1.6
## What it draws is kept to this far round it (m), up and down.
const DRAWN_WIDE := 9.0
const DRAWN_DOWN := 3.0
const DRAWN_UP := 5.0
const SPIKE_SHAPES := 5
const CHUNK_SHAPES := 6

var _spikes: Array[Dictionary] = []
var _chunks: Array[Dictionary] = []
var _spike_draws: Array[MultiMeshInstance3D] = []
var _chunk_draws: Array[MultiMeshInstance3D] = []
var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _rubble_end := 0.0
var _rubble_drawn := 0

## The glass, once, shared by every cast: its own copies, wearing a look that takes each spike's charge.
static var _spike_shapes: Array[Mesh] = []
static var _chunk_shapes: Array[Mesh] = []


static func rise_at(context: Node, floor_at: Vector3, reach: float, takes: float) -> Node3D:
	var wave: Node3D = (load("res://scripts/Magic/BurstWave.gd") as GDScript).new()
	context.add_child(wave)
	wave.global_position = floor_at
	wave._lay_out(reach, takes)
	return wave


func spikes_total() -> int:
	return _spikes.size()


## How many have come up, and not yet fallen.
func spikes_up() -> int:
	var up := 0

	for spike in _spikes:
		if _t >= float(spike["born"]) and _t < float(spike["falls"]) + SINKS:
			up += 1

	return up


func spike_places() -> PackedVector3Array:
	var places := PackedVector3Array()

	for spike in _spikes:
		places.append(spike["at"])

	return places


func spike_height(i: int) -> float:
	return _spikes[i]["tall"]


func rubble_left() -> int:
	return _chunks.size()


## How far across what it draws is kept (m).
func drawn_across() -> float:
	return _spike_draws[0].custom_aabb.size.x


## How many pieces of rubble are being drawn, of all it could hold.
func rubble_drawn() -> int:
	var drawn := 0

	for draw in _chunk_draws:
		drawn += draw.multimesh.visible_instance_count

	return drawn


func spike_mesh(i: int) -> Mesh:
	return _spike_draws[i].multimesh.mesh


static func _shapes_ready() -> void:
	if not _spike_shapes.is_empty():
		return

	for i in SPIKE_SHAPES:
		_spike_shapes.append(_charged(MagicFx.glass_mesh("Spike_%d" % (i + 1))))

	for i in CHUNK_SHAPES:
		_chunk_shapes.append(_charged(MagicFx.glass_mesh("Chunk_%d" % (i + 1))))


static func _charged(mesh: Mesh) -> Mesh:
	var shape: Mesh = mesh.duplicate()
	var look := MagicFx.big_glass_look()
	look.set_shader_parameter(&"custom_share", 1.0)
	shape.surface_set_material(0, look)
	return shape


func _lay_out(reach: float, takes: float) -> void:
	add_to_group(&"burst_wave")
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_rng.seed = hash(global_position) + Time.get_ticks_usec()
	_shapes_ready()
	var spike_meshes := _spike_shapes
	var chunk_meshes := _chunk_shapes
	var space := get_world_3d().direct_space_state
	var centre := global_position + Vector3.UP * 0.5
	var ring := RING_FIRST

	while ring <= reach:
		var count := int(TAU * ring * PER_METRE)
		var start := _rng.randf() * TAU

		for i in count:
			if _rng.randf() < GAPS:
				continue

			var out := ring + _rng.randf_range(-SCATTER, SCATTER)
			var turn := start + TAU * float(i) / float(count) + _rng.randf_range(-0.1, 0.1)
			var way := Vector3(cos(turn), 0.0, sin(turn))
			var over := global_position + way * out + Vector3.UP * 0.5

			# Not through a wall.
			if not space.intersect_ray(PhysicsRayQueryParameters3D.create(centre, over, 1)).is_empty():
				continue

			var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(over, over + Vector3.DOWN * FLOOR_LOOK, 1))

			# Only where there is a floor.
			if down.is_empty():
				continue

			var share := clampf(out / reach, 0.0, 1.0)
			var tall := lerpf(TALL_NEAR, TALL_EDGE, share) * _rng.randf_range(TALL_VARIES.x, TALL_VARIES.y)
			var lean: Basis = Basis(way.cross(Vector3.UP).normalized(), -_rng.randf_range(0.3, 1.0) * LEANS) * Basis(Vector3.UP, _rng.randf() * TAU)
			var born := takes * out / reach
			_spikes.append({
				"at": down["position"], "tall": tall, "lean": lean, "born": born,
				"falls": takes + _rng.randf_range(STANDS.x, STANDS.y) + born * 0.5,
				"shape": _rng.randi() % spike_meshes.size(), "index": 0, "way": way, "broke": false,
			})

		ring += RING_APART

	var counts: Array[int] = []
	counts.resize(spike_meshes.size())
	counts.fill(0)

	for spike in _spikes:
		spike["index"] = counts[spike["shape"]]
		counts[spike["shape"]] += 1

	for i in spike_meshes.size():
		_spike_draws.append(_new_draw(spike_meshes[i], counts[i], true))

	# Enough room for every spike's chunks, whichever they turn out to be.
	var chunks_each := ceili(float(_spikes.size() * CHUNKS_EACH.y) / float(maxi(chunk_meshes.size(), 1)))

	for mesh in chunk_meshes:
		var draw := _new_draw(mesh, chunks_each, false)
		draw.multimesh.visible_instance_count = 0
		_chunk_draws.append(draw)

	_rubble_end = takes + STANDS.y + takes * 0.5 + SINKS + RUBBLE_LIES + RUBBLE_GOES


func _new_draw(mesh: Mesh, count: int, shadows: bool) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_custom_data = true
	multi.mesh = mesh
	multi.instance_count = count

	for i in count:
		multi.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * 0.0005), global_position + Vector3.DOWN))

	var draw := MultiMeshInstance3D.new()
	draw.multimesh = multi
	draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	draw.top_level = true
	draw.global_transform = Transform3D.IDENTITY
	draw.custom_aabb = AABB(global_position + Vector3(-DRAWN_WIDE, -DRAWN_DOWN, -DRAWN_WIDE), Vector3(DRAWN_WIDE * 2.0, DRAWN_DOWN + DRAWN_UP, DRAWN_WIDE * 2.0))
	add_child(draw)
	return draw


func _physics_process(delta: float) -> void:
	_t += delta

	for spike in _spikes:
		_work_spike(spike)

	_work_chunks(delta)

	if _t >= _rubble_end and _chunks.is_empty():
		queue_free()


func _work_spike(spike: Dictionary) -> void:
	var born: float = spike["born"]
	var falls: float = spike["falls"]
	var multi: MultiMesh = _spike_draws[spike["shape"]].multimesh
	var index: int = spike["index"]

	if _t < born or _t >= falls + SINKS:
		if _t >= falls + SINKS and not spike["broke"]:
			spike["broke"] = true
			_break(spike)
			multi.set_instance_transform(index, Transform3D(Basis.from_scale(Vector3.ONE * 0.0005), Vector3(spike["at"]) + Vector3.DOWN))

		return

	if not spike["broke"] and _t - born < 0.0001 + 0.017 and index % DUST_ONE_IN == 0:
		Fx.dust(self, spike["at"], Vector3.UP, 0.7)

	var up := clampf((_t - born) / RISES, 0.0, 1.0)
	# Ease out, past its height, and back.
	var grown := 1.0 - pow(1.0 - up, 3.0)
	var kick := sin(clampf((_t - born) / (RISES * 2.5), 0.0, 1.0) * PI) * OVERSHOOT
	var sunk := clampf((_t - falls) / SINKS, 0.0, 1.0)
	var tall: float = spike["tall"]
	var height := tall * (grown + kick) * (1.0 - sunk * 0.35)
	var wide := tall * WIDER * (0.8 + 0.2 * grown)
	var lean: Basis = spike["lean"]
	var shape := lean * Basis.from_scale(Vector3(wide, height, wide))
	multi.set_instance_transform(index, Transform3D(shape, Vector3(spike["at"])))
	var charge := FULL_OF_IT * (1.0 - clampf((_t - born) / COOLS, 0.0, 1.0))
	multi.set_instance_custom_data(index, Color(0.0, 0.0, 0.0, charge))


## It falls to pieces where it stood.
func _break(spike: Dictionary) -> void:
	var tall: float = spike["tall"]
	var at: Vector3 = spike["at"]
	var way: Vector3 = spike["way"]
	var count := _rng.randi_range(CHUNKS_EACH.x, CHUNKS_EACH.y)

	for i in count:
		var shape := _rng.randi() % _chunk_draws.size()
		var slot := _free_slot(shape)

		if slot < 0:
			continue

		var multi: MultiMesh = _chunk_draws[shape].multimesh
		multi.visible_instance_count = maxi(multi.visible_instance_count, slot + 1)
		_chunks.append({
			"shape": shape, "slot": slot, "at": at + Vector3.UP * tall * (float(i) + 0.5) / float(count) * 0.8,
			"floor": at.y + 0.04, "speed": (way * _rng.randf_range(-0.3, 1.0) + Vector3(_rng.randf_range(-0.5, 0.5), _rng.randf_range(0.0, 0.8), _rng.randf_range(-0.5, 0.5))) * _rng.randf_range(BURST_SPEED.x, BURST_SPEED.y),
			"turn": Basis(Vector3(_rng.randf() - 0.5, _rng.randf() - 0.5, _rng.randf() - 0.5).normalized(), _rng.randf() * TAU),
			"spin": Vector3(_rng.randf() - 0.5, _rng.randf() - 0.5, _rng.randf() - 0.5).normalized(), "rate": _rng.randf_range(4.0, 10.0),
			"size": _rng.randf_range(0.6, 1.2) * clampf(tall, 0.5, 1.2), "left": RUBBLE_LIES + RUBBLE_GOES + _rng.randf_range(0.0, 0.4),
		})

	if spike["index"] % DUST_ONE_IN == 0:
		Fx.dust(self, at, Vector3.UP, 0.5)

	if spike["index"] % (DUST_ONE_IN * 2) == 0:
		Sfx.play(self, &"ting", at, -19.0, _rng.randf_range(0.5, 0.8))


func _free_slot(shape: int) -> int:
	var used := {}

	for chunk in _chunks:
		if chunk["shape"] == shape:
			used[chunk["slot"]] = true

	for i in _chunk_draws[shape].multimesh.instance_count:
		if not used.has(i):
			return i

	return -1


func _work_chunks(delta: float) -> void:
	for i in range(_chunks.size() - 1, -1, -1):
		var chunk: Dictionary = _chunks[i]
		var multi: MultiMesh = _chunk_draws[chunk["shape"]].multimesh
		chunk["left"] = float(chunk["left"]) - delta

		if float(chunk["left"]) <= 0.0:
			multi.set_instance_transform(chunk["slot"], Transform3D(Basis.from_scale(Vector3.ONE * 0.0005), Vector3(chunk["at"]) + Vector3.DOWN))
			_chunks.remove_at(i)
			continue

		var at: Vector3 = chunk["at"]
		var speed: Vector3 = chunk["speed"]
		speed.y -= GRAVITY * delta
		at += speed * delta

		if at.y <= float(chunk["floor"]):
			at.y = float(chunk["floor"])
			speed = Vector3(speed.x * 0.4, absf(speed.y) * 0.25 if absf(speed.y) > 1.0 else 0.0, speed.z * 0.4)
			chunk["rate"] = float(chunk["rate"]) * 0.5

		chunk["at"] = at
		chunk["speed"] = speed
		chunk["turn"] = (chunk["turn"] as Basis) * Basis(chunk["spin"], float(chunk["rate"]) * delta)
		var size: float = chunk["size"] * clampf(float(chunk["left"]) / RUBBLE_GOES, 0.0, 1.0)
		multi.set_instance_transform(chunk["slot"], Transform3D((chunk["turn"] as Basis).scaled(Vector3.ONE * maxf(size, 0.0005)), at))
