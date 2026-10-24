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
