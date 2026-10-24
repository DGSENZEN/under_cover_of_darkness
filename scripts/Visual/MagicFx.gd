extends RefCounted
## The spells' effects in the world, in the shot's approved look (GunFx,
## MeshVfx): Obsidian's black glass (the splinter, its shatter, Blink's
## mirror-crack and ripple), and Empower's shockwave. Every piece is
## short-lived and counted (live_count); with Fx.enabled off (tests,
## captures) none is made.

const Fx := preload("res://scripts/Visual/Fx.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")
const ViewArms := preload("res://scripts/Interaction/ViewArms.gd")
## The viewmodel's render layer (HandSlot.VIEWMODEL_LAYER).
const VIEWMODEL_LAYER := 1 << 18

## Obsidian: black glass, its glints cold.
const GLASS := Color("#0A0A0D")
const GLINT := Color("#E6EEF5")
## A shard's shatter: how many splinters, and how long they lie.
const SHATTER_PIECES := 8
const SHATTER_LIFE := 1.5
## Blink: the mirror-crack left where you stood (how many shards, how long),
## and the ripple you arrive in (how long, how high on the body).
const MIRROR_SHARDS := 10
const MIRROR_LIFE := 0.6
const RIPPLE_LIFE := 0.3
const RIPPLE_HEIGHT := 0.3
const RIPPLE_SHADER := preload("res://scripts/Visual/vfx_ripple.gdshader")
## Empower spent: a flat ring of beast strength thrown out (how long, how
## wide it grows), umber with a bone core.
const SHOCKWAVE_LIFE := 0.3
const SHOCKWAVE_FROM := 0.2
const SHOCKWAVE_TO := 1.8
const UMBER := Color("#4A3423")
const BONE := Color("#D8C7A3")
const UMBER_EDGE := Color("#22170F")
## The Shard, round two: its look, its release at the palm (flakes, a ring
## the world bends through, a cold light), and what it leaves on the world
## (a star of spikes that crumbles, a ring of glass dust) or in a man.
const OBSIDIAN_SHADER := preload("res://scripts/Visual/vfx_obsidian.gdshader")
const REFRACT_RING_SHADER := preload("res://scripts/Visual/vfx_refract_ring.gdshader")
const RELEASE_FLAKES := 8
const RELEASE_LIFE := 0.12
const LIGHT_LIFE := 0.08
## The impact's spikes: [tilt off the normal, turn about it, length] each,
## the longest straight out (a fixed star, so tests and clips repeat).
const SPIKES := [[0.2, 0.4, 0.5], [1.0, 0.3, 0.46], [1.25, 1.3, 0.32], [0.95, 2.2, 0.5],
	[1.3, 3.1, 0.25], [1.1, 4.0, 0.4], [1.25, 5.1, 0.3]]
const SPIKE_GROW := 0.05
const SPIKE_STAY := 3.0
const SPIKE_CRUMBLE := 0.4
const CRUMBLE_LIFE := 0.6
## The ring of glass dust: how long it spreads, how wide it gets.
const DUST_RING_LIFE := 0.3
const DUST_RING_TO := 0.8
const DUST := Color("#3A3A40")
const DUST_BODY := Color("#1C1C21")
## Stuck in a man: how long it stays.
const STUCK_LIFE := 6.0

static var _live: Array = []
static var _glass_look: StandardMaterial3D
static var _obsidian: ShaderMaterial


## A thin pointed splinter of glass: a long four-sided bipyramid, `width` by
## `depth` at its waist, `length` from point to point, its long axis on +Y.
static func splinter_mesh(width: float, length: float, depth: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# The waist a third of the way up: a long blade above, a short heel below.
	var waist := length * 0.32 - length * 0.5
	var ring := [Vector3(width * 0.5, waist, 0.0), Vector3(0.0, waist, depth * 0.5), Vector3(-width * 0.5, waist, 0.0), Vector3(0.0, waist, -depth * 0.5)]
	var tips := [Vector3(0.0, length * 0.5, 0.0), Vector3(0.0, -length * 0.5, 0.0)]

	for t in 2:
		for i in 4:
			var a: Vector3 = ring[i]
			var b: Vector3 = ring[(i + 1) % 4]
			var corners := [a, b, tips[t]] if t == 0 else [b, a, tips[t]]
			var normal: Vector3 = ((corners[1] as Vector3) - (corners[0] as Vector3)).cross((corners[2] as Vector3) - (corners[0] as Vector3)).normalized()

			for k in 3:
				st.set_normal(normal)
				st.set_uv(Vector2(float(k) * 0.5, 1.0 if k == 2 else 0.0))
				st.add_vertex(corners[k])

	return st.commit()


## Black glass: glossy, nearly mirror, a cold rim where it turns away.
static func glass_look() -> StandardMaterial3D:
	if _glass_look == null:
		_glass_look = StandardMaterial3D.new()
		_glass_look.albedo_color = GLASS
		_glass_look.metallic = 0.85
		_glass_look.roughness = 0.08
		_glass_look.rim_enabled = true
		_glass_look.rim = 0.6
		_glass_look.rim_tint = 0.4

	return _glass_look


## A shard broken on something: SHATTER_PIECES small splinters thrown out
## along the face it struck (a fixed spread), gone after SHATTER_LIFE; the
## crack of glass.
static func shatter(context: Node, at: Vector3, normal: Vector3) -> void:
	if not allowed(context):
		return

	var world := _world_of(context)
	var out := normal.normalized() if normal.length() > 0.01 else Vector3.UP
	var side := out.cross(Vector3.UP if absf(out.y) < 0.9 else Vector3.RIGHT).normalized()
	var up := side.cross(out).normalized()

	for i in SHATTER_PIECES:
		var turn := TAU * float(i) / float(SHATTER_PIECES)
		var piece := RigidBody3D.new()
		piece.name = "Shatter"
		piece.collision_layer = 0
		piece.collision_mask = 1
		piece.mass = 0.02
		piece.add_to_group(&"shatter")
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.012, 0.04, 0.006)
		shape.shape = box
		piece.add_child(shape)
		var visual := MeshInstance3D.new()
		visual.mesh = splinter_mesh(0.012, 0.03 + 0.012 * float(i % 3), 0.005)
		visual.material_override = glass_look()
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		piece.add_child(visual)
		world.add_child(piece)
		piece.global_position = at + out * 0.03
		piece.reset_physics_interpolation()
		piece.linear_velocity = out * 2.2 + (side * cos(turn) + up * sin(turn)) * 1.6
		piece.angular_velocity = Vector3(9.0, 4.0 * float(i % 3), 6.0)
		_keep(piece, SHATTER_LIFE)

	Fx.glint(context, at, 0.18, null, GLINT)
	Sfx.play(context, &"ting", at, -3.0, 2.4)


## Where you blinked from: a ring of flat mirror shards at your body,
## bursting out a little and fading, a shatter of reflections.
static func mirror_crack(context: Node, at: Vector3) -> void:
	if not allowed(context):
		return

	var world := _world_of(context)
	var middle := at + Vector3.UP * 0.2

	for i in MIRROR_SHARDS:
		var turn := TAU * float(i) / float(MIRROR_SHARDS) + 0.31 * float(i % 3)
		var out := Vector3(cos(turn), 0.25 * float(i % 3 - 1), sin(turn)).normalized()
		var shard := MeshInstance3D.new()
		shard.name = "Mirror"
		var quad := QuadMesh.new()
		var side := 0.06 + 0.03 * float(i % 3)
		quad.size = Vector2(side, side * 1.4)
		shard.mesh = quad
		var mirror := StandardMaterial3D.new()
		mirror.albedo_color = Color(0.82, 0.86, 0.9, 0.95)
		mirror.metallic = 1.0
		mirror.roughness = 0.04
		mirror.rim_enabled = true
		mirror.rim = 0.8
		mirror.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mirror.cull_mode = BaseMaterial3D.CULL_DISABLED
		shard.material_override = mirror
		shard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shard.add_to_group(&"mirror")
		world.add_child(shard)
		shard.global_position = middle + out * 0.5
		shard.global_basis = Basis.looking_at(out, Vector3.UP).rotated(out, 0.9 * float(i))
		shard.reset_physics_interpolation()
		var fade := shard.create_tween().set_parallel(true)
		fade.tween_property(shard, "global_position", middle + out * 0.8, MIRROR_LIFE).set_ease(Tween.EASE_OUT)
		fade.tween_property(mirror, "albedo_color:a", 0.0, MIRROR_LIFE).set_ease(Tween.EASE_IN)
		_keep(shard, MIRROR_LIFE)


## Where you arrive: a shell of glass the world bends through, swelling and
## fading.
static func ripple(context: Node, at: Vector3) -> void:
	if not allowed(context):
		return

	var shell := MeshInstance3D.new()
	shell.name = "Ripple"
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 24
	sphere.rings = 12
	shell.mesh = sphere
	var look := ShaderMaterial.new()
	look.shader = RIPPLE_SHADER
	look.set_shader_parameter(&"rim_tint", GLINT)
	shell.material_override = look
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shell.add_to_group(&"ripple")
	_world_of(context).add_child(shell)
	shell.global_position = at + Vector3.UP * RIPPLE_HEIGHT
	shell.scale = Vector3.ONE * 0.4
	shell.reset_physics_interpolation()
	var swell := shell.create_tween().set_parallel(true)
	swell.tween_property(shell, "scale", Vector3.ONE * 2.8, RIPPLE_LIFE).set_ease(Tween.EASE_OUT)
	swell.tween_method(func(f: float): look.set_shader_parameter(&"fade", f), 1.0, 0.0, RIPPLE_LIFE)
	_keep(shell, RIPPLE_LIFE)


## Empower's charge spent at `at`: a flat ring thrown out square to `up`,
## eaten away as it grows; a heavier crack.
static func shockwave(context: Node, at: Vector3, up := Vector3.UP) -> void:
	if not allowed(context):
		return

	var ring := MeshInstance3D.new()
	ring.name = "Shockwave"
	ring.mesh = _ring_mesh(0.5, 0.15, 32)
	var look := MeshVfx.look(BONE, UMBER, UMBER_EDGE, 1.6, 0.15, 0.9, 2.3)
	look.set_shader_parameter(&"tail_eat", 0.0)
	look.set_shader_parameter(&"tiling", Vector2(3.0, 0.6))
	ring.material_override = look
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.add_to_group(&"shockwave")
	_world_of(context).add_child(ring)
	var normal := up.normalized() if up.length() > 0.01 else Vector3.UP
	var across := normal.cross(Vector3.RIGHT if absf(normal.x) < 0.9 else Vector3.FORWARD).normalized()
	ring.global_transform = Transform3D(Basis(across, normal, across.cross(normal)), at)
	ring.scale = Vector3.ONE * SHOCKWAVE_FROM
	ring.reset_physics_interpolation()
	var grow := ring.create_tween().set_parallel(true)
	grow.tween_property(ring, "scale", Vector3.ONE * SHOCKWAVE_TO, SHOCKWAVE_LIFE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	grow.tween_method(func(e: float): look.set_shader_parameter(&"erosion", e), 0.15, 1.0, SHOCKWAVE_LIFE).set_ease(Tween.EASE_IN)
	_keep(ring, SHOCKWAVE_LIFE)
	Sfx.play(context, &"bone_crack", at, 0.0, 0.7)
	Sfx.play(context, &"thud", at, 0.0, 0.7)


## A spearhead of black glass, knapped: a short heel, a wide waist, a
## narrower shoulder turned half a facet, a long point; `width` and `depth`
## at the waist, `length` point to heel along +Y (centred on its middle, or
## from its heel at the origin with `from_heel`). Flat facets, each corner
## carrying its barycentric place in COLOR for the facets' edges
## (vfx_obsidian).
static func spearhead_mesh(width: float, length: float, depth: float, from_heel := false) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base := 0.0 if from_heel else -length * 0.5
	var sides := 6
	# Knapped: the waist's corners not quite even.
	var chips := [1.0, 0.86, 0.97, 0.9, 1.0, 0.83]
	var waist := []
	var shoulder := []

	for i in sides:
		var turn := TAU * float(i) / float(sides)
		waist.append(Vector3(cos(turn) * width * 0.5 * chips[i], base + length * 0.22, sin(turn) * depth * 0.5 * chips[i]))
		var half := turn + PI / float(sides)
		shoulder.append(Vector3(cos(half) * width * 0.3, base + length * 0.55, sin(half) * depth * 0.3))

	var heel := Vector3(0.0, base, 0.0)
	var point := Vector3(0.0, base + length, 0.0)
	var corners := [Color(1, 0, 0), Color(0, 1, 0), Color(0, 0, 1)]
	var faces := []

	for i in sides:
		var j := (i + 1) % sides
		faces.append([waist[j], waist[i], heel])
		faces.append([waist[i], waist[j], shoulder[i]])
		faces.append([shoulder[i], waist[j], shoulder[j]])
		faces.append([shoulder[i], shoulder[j], point])

	for face in faces:
		var normal: Vector3 = ((face[1] as Vector3) - (face[0] as Vector3)).cross((face[2] as Vector3) - (face[0] as Vector3)).normalized()

		for k in 3:
			st.set_normal(normal)
			st.set_color(corners[k])
			st.set_uv(Vector2(float(k) * 0.5, ((face[k] as Vector3).y - base) / length))
			st.add_vertex(face[k])

	return st.commit()


## Obsidian (vfx_obsidian): in the world, or drawn in your view as the arms
## are (`view_fov` the arms' field of view, 0 the camera's).
static func obsidian_look(in_view := false, view_fov := 0.0) -> ShaderMaterial:
	if not in_view and _obsidian != null:
		return _obsidian

	var m := ShaderMaterial.new()
	m.shader = OBSIDIAN_SHADER
	m.set_shader_parameter(&"glass", GLASS)
	m.set_shader_parameter(&"glint", GLINT)

	if in_view:
		m.set_shader_parameter(&"z_clip", ViewArms.Z_CLIP)
		m.set_shader_parameter(&"fov_override", view_fov)
		m.render_priority = 12
	else:
		_obsidian = m

	return m


## The Shard let go at the palm, in your view: RELEASE_FLAKES flakes flung
## out ahead of it and a ring the world bends through, swelling, both gone
## in RELEASE_LIFE. `parent` is the viewmodel's node; `at` the circle's
## middle in its space, `ahead` the way the shard goes, `size` the
## viewmodel's scale.
static func release_burst(parent: Node3D, at: Vector3, ahead: Vector3, size: float, view_fov: float) -> void:
	if not allowed(parent):
		return

	var forward := ahead.normalized()
	var side := forward.cross(Vector3.UP).normalized()
	var up := side.cross(forward).normalized()
	var look := obsidian_look(true, view_fov)
	var flake := spearhead_mesh(0.012, 0.035, 0.005)

	for i in RELEASE_FLAKES:
		var turn := TAU * float(i) / float(RELEASE_FLAKES) + 0.4 * float(i % 2)
		var out := (forward * 1.2 + (side * cos(turn) + up * sin(turn)) * 0.8).normalized()
		var piece := MeshInstance3D.new()
		piece.name = "ReleaseFlake"
		piece.mesh = flake
		piece.material_override = look
		piece.layers = VIEWMODEL_LAYER
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		piece.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		piece.add_to_group(&"shard_release")
		parent.add_child(piece)
		piece.transform = Transform3D(Basis.looking_at(out, up) * Basis(Vector3.RIGHT, -PI * 0.5), at).scaled_local(Vector3.ONE * size)
		var fly := piece.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).set_parallel(true)
		fly.tween_property(piece, "position", at + out * (0.16 + 0.04 * float(i % 3)) * size, RELEASE_LIFE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		fly.tween_property(piece, "scale", Vector3.ONE * size * 0.3, RELEASE_LIFE).set_ease(Tween.EASE_IN)
		_keep(piece, RELEASE_LIFE)

	var ring := MeshInstance3D.new()
	ring.name = "ReleaseRing"
	ring.mesh = _ring_mesh(0.5, 0.12, 32)
	var bend := ShaderMaterial.new()
	bend.shader = REFRACT_RING_SHADER
	bend.set_shader_parameter(&"rim_tint", GLINT)
	bend.set_shader_parameter(&"z_clip", ViewArms.Z_CLIP)
	bend.set_shader_parameter(&"fov_override", view_fov)
	bend.render_priority = 11
	ring.material_override = bend
	ring.layers = VIEWMODEL_LAYER
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	ring.add_to_group(&"shard_release")
	parent.add_child(ring)
	# Flat across the shard's way: its plane square to `ahead`.
	ring.transform = Transform3D(Basis(side, forward, -up), at)
	ring.scale = Vector3.ONE * 0.04 * size
	var swell := ring.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).set_parallel(true)
	swell.tween_property(ring, "scale", Vector3.ONE * 0.16 * size, RELEASE_LIFE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	swell.tween_method(func(f: float): bend.set_shader_parameter(&"fade", f), 1.0, 0.0, RELEASE_LIFE).set_ease(Tween.EASE_IN)
	_keep(ring, RELEASE_LIFE)


## A cold light for a moment at `at` in the world (a release, an impact),
## lighting what is round it, gone in LIGHT_LIFE.
static func glint_light(context: Node, at: Vector3, energy := 2.0, reach := 3.0) -> void:
	if not allowed(context):
		return

	var light := OmniLight3D.new()
	light.name = "GlintLight"
	light.light_color = GLINT
	light.light_energy = energy
	light.omni_range = reach
	light.shadow_enabled = false
	light.add_to_group(&"shard_light")
	_world_of(context).add_child(light)
	light.global_position = at
	light.reset_physics_interpolation()
	light.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).tween_property(light, "light_energy", 0.0, LIGHT_LIFE).set_ease(Tween.EASE_IN)
	_keep(light, LIGHT_LIFE)


## Where a shard struck the world: a star of black glass spikes burst out
## of the face round `normal` (SPIKES), grown in SPIKE_GROW, standing
## SPIKE_STAY, then crumbling into falling flakes; a ring of glass dust on
## the face; a cold light.
static func spike_star(context: Node, at: Vector3, normal: Vector3) -> void:
	if not allowed(context):
		return

	var world := _world_of(context)
	var out := normal.normalized() if normal.length() > 0.01 else Vector3.UP
	var side := out.cross(Vector3.UP if absf(out.y) < 0.9 else Vector3.RIGHT).normalized()
	var up := side.cross(out).normalized()

	for i in SPIKES.size():
		var tilt: float = SPIKES[i][0]
		var turn: float = SPIKES[i][1]
		var length: float = SPIKES[i][2]
		var lean := (side * cos(turn) + up * sin(turn))
		var along := (out * cos(tilt) + lean * sin(tilt)).normalized()
		var spike := MeshInstance3D.new()
		spike.name = "Spike"
		spike.mesh = spearhead_mesh(length * 0.3, length, length * 0.18, true)
		spike.material_override = obsidian_look()
		spike.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		spike.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		spike.set_meta(&"length", length)
		spike.add_to_group(&"shard_spike")
		world.add_child(spike)
		# Its heel just into the face, a little off the middle.
		var heel := at + lean * 0.025 * float(i > 0) - out * 0.015
		var facing := along.cross(lean if i > 0 else side).normalized()
		var basis := Basis(along.cross(facing).normalized(), along, facing)
		spike.global_transform = Transform3D(basis.scaled_local(Vector3(1.0, 0.05, 1.0)), heel)
		var life := spike.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		life.tween_method(func(g: float): spike.global_basis = basis.scaled_local(Vector3(1.0, g, 1.0)), 0.05, 1.0, SPIKE_GROW).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		life.tween_interval(SPIKE_STAY - SPIKE_GROW)
		life.tween_callback(func(): _crumble(spike, along, length))
		life.tween_method(func(g: float): spike.global_basis = basis.scaled_local(Vector3(g, g, g)), 1.0, 0.0, SPIKE_CRUMBLE).set_ease(Tween.EASE_IN)
		_keep(spike, SPIKE_STAY + SPIKE_CRUMBLE)

	_dust_ring(context, at + out * 0.01, out)
	glint_light(context, at + out * 0.3, 1.0, 2.5)


## A shard stuck in a man where it struck (`at`, going `direction`): on the
## bone nearest, so it goes where his body goes (a ragdoll's limb too), or on
## him; gone after STUCK_LIFE.
static func stuck_in(target: Node3D, at: Vector3, direction: Vector3) -> void:
	if not allowed(target):
		return

	var shard := MeshInstance3D.new()
	shard.name = "StuckShard"
	shard.mesh = spearhead_mesh(0.05, 0.32, 0.022)
	shard.material_override = obsidian_look()
	shard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shard.add_to_group(&"shard_stuck")
	var way := direction.normalized()
	# Its point a third of its length in.
	var place := Transform3D(Basis.looking_at(way, Vector3.UP if absf(way.y) < 0.99 else Vector3.RIGHT) * Basis(Vector3.RIGHT, -PI * 0.5), at - way * 0.05)
	var rig := target.get_node_or_null("Rig")
	var man: Node3D = rig.get("man") as Node3D if rig != null else null
	var bone := _nearest_bone(man, at)

	if bone != &"":
		man.attach(bone, shard, man.bone_global(bone).affine_inverse() * place)
	else:
		target.add_child(shard)
		shard.global_transform = place

	shard.reset_physics_interpolation()
	_keep(shard, STUCK_LIFE)


static func _nearest_bone(man: Node3D, at: Vector3) -> StringName:
	if man == null or not man.has_method("attach") or man.get("skeleton") == null:
		return &""

	var best: StringName = &""
	var nearest := INF

	for bone in [&"pelvis", &"spine_02", &"spine_03", &"neck_01", &"head", &"upperarm_l", &"upperarm_r",
			&"lowerarm_l", &"lowerarm_r", &"thigh_l", &"thigh_r", &"calf_l", &"calf_r"]:
		if (man.skeleton as Skeleton3D).find_bone(bone) < 0:
			continue

		var gap: float = man.bone_global(bone).origin.distance_to(at)

		if gap < nearest:
			nearest = gap
			best = bone

	return best


## A spike falling apart: a few flakes of it drop from along its length.
static func _crumble(spike: Node3D, along: Vector3, length: float) -> void:
	if not is_instance_valid(spike) or not spike.is_inside_tree():
		return

	var world := _world_of(spike)

	for i in 3:
		var piece := RigidBody3D.new()
		piece.name = "Crumble"
		piece.collision_layer = 0
		piece.collision_mask = 1
		piece.mass = 0.02
		piece.add_to_group(&"shard_crumble")
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.02, 0.04, 0.01)
		shape.shape = box
		piece.add_child(shape)
		var visual := MeshInstance3D.new()
		visual.mesh = spearhead_mesh(0.02, 0.04 + 0.015 * float(i), 0.008)
		visual.material_override = obsidian_look()
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		piece.add_child(visual)
		world.add_child(piece)
		piece.global_position = spike.global_position + along * length * (0.25 + 0.3 * float(i))
		piece.reset_physics_interpolation()
		piece.linear_velocity = along * 0.4 + Vector3(0.3 * float(i - 1), 0.2, 0.0)
		piece.angular_velocity = Vector3(5.0, 3.0 * float(i), 2.0)
		_keep(piece, CRUMBLE_LIFE)


## A ring of black glass dust spreading flat on the face (square to `out`).
static func _dust_ring(context: Node, at: Vector3, out: Vector3) -> void:
	var ring := MeshInstance3D.new()
	ring.name = "DustRing"
	ring.mesh = _ring_mesh(0.5, 0.22, 32)
	var look := MeshVfx.look(DUST, DUST_BODY, GLASS, 1.0, 0.2, 0.4, 4.1)
	look.set_shader_parameter(&"tail_eat", 0.0)
	look.set_shader_parameter(&"tiling", Vector2(4.0, 0.8))
	look.set_shader_parameter(&"rim", 6.0)
	ring.material_override = look
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	ring.add_to_group(&"shard_ring")
	_world_of(context).add_child(ring)
	var across := out.cross(Vector3.RIGHT if absf(out.x) < 0.9 else Vector3.FORWARD).normalized()
	ring.global_transform = Transform3D(Basis(across, out, across.cross(out)), at)
	ring.scale = Vector3.ONE * 0.15
	var grow := ring.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).set_parallel(true)
	grow.tween_property(ring, "scale", Vector3.ONE * DUST_RING_TO, DUST_RING_LIFE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	grow.tween_method(func(e: float): look.set_shader_parameter(&"erosion", e), 0.2, 1.0, DUST_RING_LIFE).set_ease(Tween.EASE_IN)
	_keep(ring, DUST_RING_LIFE)


## A flat ring in its own XZ plane: `radius` to its middle, `width` across,
## v running across it (0 inside, 1 outside), u round it.
static func _ring_mesh(radius: float, width: float, sides: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for i in sides:
		var a := TAU * float(i) / float(sides)
		var b := TAU * float(i + 1) / float(sides)
		var corners := []

		for turn in [a, b]:
			for r in [radius - width * 0.5, radius + width * 0.5]:
				corners.append(Vector3(cos(turn) * r, 0.0, sin(turn) * r))

		var uvs := [Vector2(float(i) / sides, 0.0), Vector2(float(i) / sides, 1.0), Vector2(float(i + 1) / sides, 0.0), Vector2(float(i + 1) / sides, 1.0)]

		for k in [0, 1, 2, 2, 1, 3]:
			st.set_normal(Vector3.UP)
			st.set_uv(uvs[k])
			st.add_vertex(corners[k])

	return st.commit()


## Every magic effect still showing.
static func live_count() -> int:
	_live = _live.filter(func(ref): return ref.get_ref() != null and is_instance_valid(ref.get_ref()) and not (ref.get_ref() as Node).is_queued_for_deletion())
	return _live.size()


## Whether effects may be made now.
static func allowed(context: Node) -> bool:
	return Fx.enabled and context != null and context.is_inside_tree()


## Counted, and gone after `seconds` (physics time).
static func _keep(node: Node, seconds: float) -> void:
	live_count()
	_live.append(weakref(node))
	node.get_tree().create_timer(seconds, false, true).timeout.connect(node.queue_free)


static func _world_of(context: Node) -> Node:
	var tree := context.get_tree()
	return tree.current_scene if tree.current_scene != null else tree.root
