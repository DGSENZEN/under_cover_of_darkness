extends RefCounted
## The revolver's own effects, the Deadlock way (MeshVfx: meshes with noise
## scrolled over them, eaten with a hard edge, in flat bands of colour):
## the muzzle flash in your view, the powder smoke that hangs in the world
## after the shot, and the ball's faint tracer. Every piece is short-lived
## and counted (live_count); they clean themselves up.

const ViewArmsScript := preload("res://scripts/Interaction/ViewArms.gd")
const FLASH_SHADER := preload("res://scripts/Visual/vfx_gunflash.gdshader")
const SMOKE_SHADER := preload("res://scripts/Visual/vfx_smoke.gdshader")

## The flash: a cream core, amber, burnt orange at the edge (never white,
## never black), bright enough for the bloom to take its core.
const FLASH_CORE := Color("#FFF1C9")
const FLASH_BODY := Color("#F2A33A")
const FLASH_EDGE := Color("#B2481B")
const FLASH_ENERGY := 3.0
## How long a petal is (m, the gun's own size), and the shell's the larger.
const PETAL := 0.15
const SHELL_WIDER := 1.5
## Seconds the flash shows: two frames.
const FLASH_LIFE := 2.0 / 60.0
## Each shot's flash turned to one of these (radians), by the shot count.
const ROLLS := [0.0, 0.7, 1.9, 2.6, 3.8, 4.9]

## Powder smoke: grey-brown, its bands close together (wide apart, the noise
## reads as camouflage, not smoke), a paler lit core.
const SMOKE_CORE := Color("#ADA394")
const SMOKE_BODY := Color("#8E8577")
const SMOKE_EDGE := Color("#655D53")
## How big a curl is, as a share of the first draft's (which read as a
## sponge the size of a head).
const SMOKE_SIZE := 0.6
const SMOKE_LIFE := 1.2
const SHELL_SMOKE_LIFE := 2.0

## The tracer: hot white at its head to amber, 12 mm across, for a moment.
const TRACER_CORE := Color("#FFF6E0")
const TRACER_EDGE := Color("#D08A3A")
const TRACER_WIDTH := 0.012
const TRACER_LIFE := 0.06

static var _live: Array = []


## The flash at the muzzle of the gun in your view: four flat petals in a
## star about the bore and a short cone along it (six, and half as wide
## again, for the shell). `gun` is the viewmodel's gun mesh; `muzzle` the
## muzzle in its own space; `shot` picks its roll.
static func flash(gun: MeshInstance3D, muzzle: Vector3, shell: bool, shot: int) -> Node3D:
	if gun == null or not gun.is_inside_tree():
		return null

	var root := Node3D.new()
	root.name = "GunFlash"
	var petals := 6 if shell else 4
	var length := PETAL * (SHELL_WIDER if shell else 1.0)
	root.set_meta(&"petals", petals)
	var look := _flash_look(shot)
	var star := MeshInstance3D.new()
	star.mesh = _star(petals, length, float(ROLLS[shot % ROLLS.size()]))
	star.mesh.surface_set_material(0, look)
	var cone := MeshInstance3D.new()
	cone.mesh = MeshVfx.flame(length * 1.3, length * 0.32, 8, 10)
	cone.mesh.surface_set_material(0, look)
	# The cone's root at the muzzle, its length out along the bore (-Z).
	cone.transform = Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3.ZERO)

	for piece in [star, cone]:
		piece.layers = HandSlotLayer.VIEWMODEL
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(piece)

	gun.add_child(root)
	root.position = muzzle
	_keep(root, FLASH_LIFE)
	return root


## Powder smoke curling up from where the muzzle was, in the world, eaten
## away over its life: three curls (five, larger and slower, for the shell).
static func smoke(context: Node, at: Vector3, ahead: Vector3, shell: bool) -> Array[Node3D]:
	var made: Array[Node3D] = []

	if context == null or not context.is_inside_tree():
		return made

	var world := _world_of(context)
	var count := 5 if shell else 3
	var grow := (1.6 if shell else 1.0) * SMOKE_SIZE
	var life := SHELL_SMOKE_LIFE if shell else SMOKE_LIFE
	var forward := Vector3(ahead.x, 0.0, ahead.z).normalized() if Vector2(ahead.x, ahead.z).length() > 0.01 else Vector3.FORWARD
	var side := forward.cross(Vector3.UP).normalized()

	for i in count:
		# Each its own way: a fixed fan, curling up and aside.
		var lean := float(i) - float(count - 1) * 0.5
		var path := PackedVector3Array([
			Vector3.ZERO,
			forward * 0.12 * grow + Vector3.UP * 0.02,
			forward * 0.2 * grow + Vector3.UP * 0.12 * grow + side * 0.05 * lean,
			forward * 0.22 * grow + Vector3.UP * 0.28 * grow + side * 0.1 * lean,
			forward * 0.17 * grow + Vector3.UP * 0.42 * grow + side * 0.07 * lean,
		])
		var curl := MeshInstance3D.new()
		curl.name = "GunSmoke"
		curl.mesh = MeshVfx.plume(path, 0.018 * grow, 0.07 * grow, 10)
		var look := MeshVfx.look(SMOKE_CORE, SMOKE_BODY, SMOKE_EDGE, 1.0, 0.2, 0.25, 3.1 * float(i) + 0.7)
		# Lit by the scene, not glowing.
		look.shader = SMOKE_SHADER
		look.set_shader_parameter(&"tail_eat", 0.35)
		look.set_shader_parameter(&"churn", 0.008)
		# Big soft shapes: the noise stretched wide, a softer bitten edge, a
		# little see-through, a gentle rim for its roundness.
		look.set_shader_parameter(&"tiling", Vector2(0.45, 0.7))
		look.set_shader_parameter(&"hardness", 0.09)
		look.set_shader_parameter(&"opacity", 0.85)
		look.set_shader_parameter(&"rim", 1.4)
		curl.mesh.surface_set_material(0, look)
		curl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		curl.add_to_group(&"gunfx_smoke")
		world.add_child(curl)
		curl.global_position = at
		curl.reset_physics_interpolation()
		# It rises and spreads as it is eaten away.
		var fade := curl.create_tween().set_parallel(true)
		fade.tween_method(func(e: float): look.set_shader_parameter(&"erosion", e), 0.2, 1.0, life).set_ease(Tween.EASE_IN)
		fade.tween_property(curl, "position", curl.position + Vector3.UP * 0.25 * grow, life)
		fade.tween_property(curl, "scale", Vector3.ONE * 1.6, life)
		_keep(curl, life)
		made.append(curl)

	return made


## The ball's tracer, from the muzzle to where it struck, for a moment.
static func tracer(context: Node, from: Vector3, to: Vector3, eye: Vector3) -> Node3D:
	if context == null or not context.is_inside_tree() or from.distance_to(to) < 0.2:
		return null

	var line := MeshInstance3D.new()
	line.name = "GunTracer"
	line.mesh = MeshVfx.ribbon(PackedVector3Array([from, from.lerp(to, 0.5), to]), TRACER_WIDTH, eye)
	var look := MeshVfx.look(TRACER_CORE, TRACER_CORE.lerp(TRACER_EDGE, 0.5), TRACER_EDGE, 2.2, 0.05, 0.0)
	look.set_shader_parameter(&"tail_eat", 0.5)
	line.mesh.surface_set_material(0, look)
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	line.add_to_group(&"gunfx_tracer")
	_world_of(context).add_child(line)
	_keep(line, TRACER_LIFE)
	return line


## Every gun effect still showing.
static func live_count() -> int:
	_live = _live.filter(func(ref): return ref.get_ref() != null and is_instance_valid(ref.get_ref()) and not (ref.get_ref() as Node).is_queued_for_deletion())
	return _live.size()


# Pieces

## A star of `count` flat petals about the bore (-Z), each `length` long,
## leaning forward; v runs out along each petal, so the noise eats it from
## its tip.
static func _star(count: int, length: float, roll: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for i in count:
		var turn := roll + TAU * float(i) / float(count)
		var out := Vector3(cos(turn), sin(turn), 0.0)
		# Out from the bore and a little forward along it, wide at the root.
		var tip := (out * 0.85 + Vector3(0, 0, -0.55)).normalized() * length * (1.0 if i % 2 == 0 else 0.7)
		var across := out.cross(Vector3.FORWARD).normalized() * length * 0.26
		var root := out * length * 0.08
		var corners := [root - across, root + across, tip]
		var uvs := [Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(0.5, 1.0)]

		for k in 3:
			st.set_uv(uvs[k])
			st.set_normal(Vector3.BACK)
			st.add_vertex(corners[k])

	return st.commit()


static func _flash_look(shot: int) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FLASH_SHADER
	m.set_shader_parameter(&"core", FLASH_CORE)
	m.set_shader_parameter(&"body", FLASH_BODY)
	m.set_shader_parameter(&"edge", FLASH_EDGE)
	m.set_shader_parameter(&"energy", FLASH_ENERGY)
	m.set_shader_parameter(&"erosion", 0.12)
	m.set_shader_parameter(&"tail_eat", 0.45)
	m.set_shader_parameter(&"scroll", 2.0)
	m.set_shader_parameter(&"seed", float(shot) * 1.37)
	m.set_shader_parameter(&"noise", MeshVfx.noise())
	m.set_shader_parameter(&"z_clip", ViewArmsScript.Z_CLIP)
	m.set_shader_parameter(&"fov_override", ViewArmsScript.VIEW_FOV if ViewArmsScript.new_arms else 0.0)
	# Over the gun and the hands.
	m.render_priority = 12
	return m


## Counted, and gone after `seconds` (physics time).
static func _keep(node: Node, seconds: float) -> void:
	live_count()
	_live.append(weakref(node))
	node.get_tree().create_timer(seconds, false, true).timeout.connect(node.queue_free)


static func _world_of(context: Node) -> Node:
	var tree := context.get_tree()
	return tree.current_scene if tree.current_scene != null else tree.root


## The viewmodel's render layer (HandSlot.VIEWMODEL_LAYER), here so this
## file needs no HandSlot.
class HandSlotLayer:
	const VIEWMODEL := 1 << 18
