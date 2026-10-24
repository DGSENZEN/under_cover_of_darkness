extends RefCounted
## The spells' effects in the world, in the shot's approved look (GunFx,
## MeshVfx): Obsidian's black glass (the splinter, its shatter, Blink's
## mirror-crack and ripple), and Empower's shockwave. Every piece is
## short-lived and counted (live_count); with Fx.enabled off (tests,
## captures) none is made.

const Fx := preload("res://scripts/Visual/Fx.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")

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

static var _live: Array = []
static var _glass_look: StandardMaterial3D


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
