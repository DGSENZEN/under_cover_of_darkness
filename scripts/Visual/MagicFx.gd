extends RefCounted
## The spells' effects in the world, in the shot's approved look (GunFx,
## MeshVfx): Obsidian's black glass (the splinter, its shatter, Blink's
## mirror-crack and ripple), and Empower's shockwave. Every piece is
## short-lived and counted (live_count); with Fx.enabled off (tests,
## captures) none is made.

const Fx := preload("res://scripts/Visual/Fx.gd")

## Obsidian: black glass, its glints cold.
const GLASS := Color("#0A0A0D")
const GLINT := Color("#E6EEF5")

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
