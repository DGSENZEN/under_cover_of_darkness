extends RefCounted
## The revolver's own effects, the Deadlock way (MeshVfx: meshes with noise
## scrolled over them, eaten with a hard edge, in flat bands of colour):
## the muzzle flash in your view (a hot core, a burst of uneven spikes, a
## tongue along the bore, smaller and eaten in its second frame), sparks
## streaking out and a ring of smoke puffing from the muzzle, the powder
## smoke that hangs in the world after the shot, and the ball's faint
## tracer. Every piece is short-lived and counted (live_count); they clean
## themselves up. (Spec: docs/superpowers/specs/2026-10-23-revolver-model-and-flash-design.md.)

const ViewArmsScript := preload("res://scripts/Interaction/ViewArms.gd")
const Fx := preload("res://scripts/Visual/Fx.gd")
const FLASH_SHADER := preload("res://scripts/Visual/vfx_gunflash.gdshader")
const SMOKE_SHADER := preload("res://scripts/Visual/vfx_smoke.gdshader")

## The flash: a cream core, amber, burnt orange at the edge (never white,
## never black), bright enough for the bloom to take its core.
const FLASH_CORE := Color("#FFF1C9")
const FLASH_BODY := Color("#F2A33A")
const FLASH_EDGE := Color("#B2481B")
const FLASH_ENERGY := 3.0
## How long the longest spike is (m, the gun's own size), and the shell's the
## larger; the core's size; how long the tongue is (of the spike).
const PETAL := 0.17
const SHELL_WIDER := 1.5
const CORE := 0.032
const TONGUE := 1.6
const TONGUE_WIDE := 0.12
## How far out the cream reaches up a spike and up the tongue (of each).
const SPIKE_CREAM := 0.4
const TONGUE_CREAM := 0.3
## The spikes' lengths, uneven as a drawn flash's (of PETAL): the ball's
## eight, the shell's twelve.
const SPIKES := [1.0, 0.5, 0.78, 0.42, 0.92, 0.55, 0.7, 0.46]
const SHELL_SPIKES := [1.0, 0.48, 0.82, 0.4, 0.95, 0.56, 0.72, 0.44, 0.88, 0.5, 0.66, 0.42]
## Seconds the flash shows (two frames), shrinking to this and eaten; it
## is freed a frame after.
const FLASH_LIFE := 2.0 / 60.0
const FLASH_SHRINK := 0.68
## Sparks out of the muzzle: how many, how far, how long; the ring of smoke:
## how far it drifts, how big it grows.
const SPARKS := 6
const SHELL_SPARKS := 12
const SPARK_LIFE := 0.12
const RING_DRIFT := 0.45
const RING_GROW := 2.4
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
## The curls held back while the flash shows (s), and born this big.
const SMOKE_HELD := 2.0 / 60.0
const SMOKE_BORN := 0.2
const SHELL_SMOKE_LIFE := 2.0

## The tracer: hot white at its head to amber, 12 mm across, for a moment.
const TRACER_CORE := Color("#FFF6E0")
const TRACER_EDGE := Color("#D08A3A")
const TRACER_WIDTH := 0.012
const TRACER_LIFE := 0.06

## Copal's thread of resin in the air: amber, a little wavering, how wide, how long.
const TRAIL_CORE := Color("#E8B070")
const TRAIL_BODY := Color("#B07A3C")
const TRAIL_EDGE := Color("#6E4C2A")
const TRAIL_WIDTH := 0.06
const TRAIL_WAVER := 0.03
const TRAIL_POINTS := 10
const TRAIL_LIFE := 0.8
## A ball's mark on a monster: how far its star reaches (m) and how long it shows
## (s), glancing and bursting; how far a glancing ball's spark skips off (m).
const GLANCE_SIZE := 0.6
const GLANCE_LIFE := 0.1
const BURST_SIZE := 1.1
const BURST_LIFE := 0.2
const RICOCHET := 1.5

## The smoke ring's life (s).
const RING_LIFE := 0.55

static var _live: Array = []


## The flash at the muzzle of the gun in your view: a hot round core, a
## burst of uneven sharp spikes about the bore leaning forward, a tongue of
## flame along it; over its two frames it shrinks to FLASH_SHRINK and is
## eaten away. A shell's is wider, with twelve spikes. `gun` is the
## viewmodel's gun mesh; `muzzle` the muzzle in its own space; `shot` turns
## it.
static func flash(gun: MeshInstance3D, muzzle: Vector3, shell: bool, shot: int) -> Node3D:
	if gun == null or not gun.is_inside_tree():
		return null

	var root := Node3D.new()
	root.name = "GunFlash"
	var lengths: Array = SHELL_SPIKES if shell else SPIKES
	var length := PETAL * (SHELL_WIDER if shell else 1.0)
	var roll := float(ROLLS[shot % ROLLS.size()])
	root.set_meta(&"petals", lengths.size())
	root.set_meta(&"spike_lengths", lengths.map(func(l): return float(l) * length))
	# The spikes cream only at their roots, orange out to burnt tips; the
	# tongue slim, cream at the muzzle, frayed at its far end.
	var look := _flash_look(shot)
	look.set_shader_parameter(&"core_reach", SPIKE_CREAM)
	look.set_shader_parameter(&"tail_eat", 0.3)
	root.set_meta(&"look", look)
	var lick := look.duplicate() as ShaderMaterial
	lick.set_shader_parameter(&"core_reach", TONGUE_CREAM)
	lick.set_shader_parameter(&"tail_eat", 0.75)
	lick.set_shader_parameter(&"tiling", Vector2(1.0, 2.5))
	# The core brightest: barely eaten.
	var hot := look.duplicate() as ShaderMaterial
	hot.set_shader_parameter(&"erosion", 0.0)
	hot.set_shader_parameter(&"energy", FLASH_ENERGY * 1.4)

	var core := MeshInstance3D.new()
	core.name = "Core"
	var ball := SphereMesh.new()
	ball.radius = CORE * (SHELL_WIDER if shell else 1.0)
	ball.height = ball.radius * 1.6
	ball.radial_segments = 16
	ball.rings = 8
	core.mesh = ball
	core.material_override = hot
	var spikes := MeshInstance3D.new()
	spikes.name = "Spikes"
	spikes.mesh = _spikes(lengths, length, roll)
	spikes.material_override = look
	var tongue := MeshInstance3D.new()
	tongue.name = "Tongue"
	tongue.mesh = MeshVfx.flame(length * TONGUE, length * TONGUE_WIDE, 8, 10)
	tongue.material_override = lick
	# The tongue's root at the muzzle, its length out along the bore (-Z).
	tongue.transform = Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3.ZERO)

	for piece in [core, spikes, tongue]:
		piece.layers = HandSlotLayer.VIEWMODEL
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(piece)

	gun.add_child(root)
	root.position = muzzle
	root.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var fade := root.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).set_parallel(true)
	fade.tween_property(root, "scale", Vector3.ONE * FLASH_SHRINK, FLASH_LIFE).set_ease(Tween.EASE_OUT)
	# Eaten away, dimmer, and turning orange: the cream drawn back to nothing.
	for m in [look, lick]:
		var reach: float = m.get_shader_parameter(&"core_reach")
		fade.tween_method(func(e: float): m.set_shader_parameter(&"erosion", e), 0.1, 0.6, FLASH_LIFE)
		fade.tween_method(func(e: float): m.set_shader_parameter(&"energy", e), FLASH_ENERGY, FLASH_ENERGY * 0.5, FLASH_LIFE)
		fade.tween_method(func(e: float): m.set_shader_parameter(&"core_reach", e), reach, 0.0, FLASH_LIFE * 0.7)
	# (The tween takes its first step the frame it is made, a frame ahead.)
	fade.tween_callback(root.hide).set_delay(FLASH_LIFE + 1.0 / 60.0)
	_keep(root, FLASH_LIFE + 1.0 / 60.0)
	return root


## Sparks streaking out of the muzzle along the shot (`ahead`), in a narrow
## cone: SPARKS (SHELL_SPARKS for a shell), gone in SPARK_LIFE.
static func sparks(context: Node, at: Vector3, ahead: Vector3, shell: bool, shot: int) -> void:
	if context == null or not context.is_inside_tree() or not Fx.enabled:
		return

	var world := _world_of(context)
	var forward := ahead.normalized()
	var side := forward.cross(Vector3.UP).normalized() if absf(forward.y) < 0.99 else Vector3.RIGHT
	var up := side.cross(forward).normalized()
	var count := SHELL_SPARKS if shell else SPARKS
	var streak := _streak_mesh(0.14, 0.009)

	for i in count:
		var turn := TAU * float(i) / float(count) + 0.7 * float(shot)
		var spread := (0.12 + 0.07 * float(i % 3)) * (1.6 if shell else 1.0)
		var way := (forward + (side * cos(turn) + up * sin(turn)) * spread).normalized()
		var spark := MeshInstance3D.new()
		spark.name = "GunSpark"
		spark.mesh = streak
		var look := MeshVfx.look(TRACER_CORE, FLASH_BODY, FLASH_EDGE, 3.0, 0.0, 0.0, float(i))
		look.set_shader_parameter(&"tail_eat", 0.7)
		spark.material_override = look
		spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		spark.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		spark.add_to_group(&"gunfx_spark")
		world.add_child(spark)
		spark.global_transform = Transform3D(Basis.looking_at(way, up), at)
		var reach := 2.0 + 0.5 * float(i % 4)
		var fly := spark.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).set_parallel(true)
		fly.tween_property(spark, "global_position", at + way * reach + Vector3.DOWN * 0.08, SPARK_LIFE).set_ease(Tween.EASE_OUT)
		fly.tween_method(func(e: float): look.set_shader_parameter(&"erosion", e), 0.0, 0.9, SPARK_LIFE).set_ease(Tween.EASE_IN)
		_keep(spark, SPARK_LIFE)


## A ring of powder smoke puffing out of the muzzle along the shot, growing
## to RING_GROW and drifting on RING_DRIFT as it is eaten away over
## RING_LIFE (a shell's bigger and slower).
static func smoke_ring(context: Node, at: Vector3, ahead: Vector3, shell: bool) -> Node3D:
	if context == null or not context.is_inside_tree() or not Fx.enabled:
		return null

	var forward := ahead.normalized()
	var side := forward.cross(Vector3.UP).normalized() if absf(forward.y) < 0.99 else Vector3.RIGHT
	var ring := MeshInstance3D.new()
	ring.name = "GunSmokeRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.028
	torus.outer_radius = 0.052
	torus.rings = 28
	torus.ring_segments = 10
	ring.mesh = torus
	var look := MeshVfx.look(SMOKE_CORE, SMOKE_BODY, SMOKE_EDGE, 1.0, 0.2, 0.3, 4.2)
	look.shader = SMOKE_SHADER
	look.set_shader_parameter(&"tail_eat", 0.0)
	look.set_shader_parameter(&"tiling", Vector2(2.0, 0.8))
	look.set_shader_parameter(&"hardness", 0.1)
	look.set_shader_parameter(&"opacity", 0.35)
	look.set_shader_parameter(&"rim", 1.4)
	ring.material_override = look
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	ring.add_to_group(&"gunfx_ring")
	_world_of(context).add_child(ring)
	# Its axis (the torus's Y) along the shot.
	ring.global_transform = Transform3D(Basis(side, forward, side.cross(forward)), at + forward * 0.05)
	var life := RING_LIFE * (1.6 if shell else 1.0)
	var grow := RING_GROW * (1.3 if shell else 1.0)
	var drift := RING_DRIFT * (1.3 if shell else 1.0)
	var puff := ring.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).set_parallel(true)
	puff.tween_property(ring, "scale", Vector3.ONE * grow, life).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	puff.tween_property(ring, "global_position", ring.global_position + forward * drift + Vector3.UP * 0.05, life).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	puff.tween_method(func(e: float): look.set_shader_parameter(&"erosion", e), 0.2, 1.0, life).set_ease(Tween.EASE_IN)
	_keep(ring, life)
	return ring


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
		# Out of the muzzle after the flash, never over it: held back for its
		# first frames, then grown from small.
		curl.scale = Vector3.ONE * SMOKE_BORN
		curl.visible = false
		curl.reset_physics_interpolation()
		# It rises and spreads as it is eaten away.
		var fade := curl.create_tween().set_parallel(true)
		fade.tween_callback(func(): curl.visible = true).set_delay(SMOKE_HELD)
		fade.tween_method(func(e: float): look.set_shader_parameter(&"erosion", e), 0.2, 1.0, life).set_ease(Tween.EASE_IN)
		fade.tween_property(curl, "position", curl.position + Vector3.UP * 0.25 * grow, life)
		fade.tween_property(curl, "scale", Vector3.ONE * 1.6, life).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		_keep(curl, life)
		made.append(curl)

	return made


## The ball's tracer, from the muzzle to where it struck, for a moment; in the look
## of its round (`spec`, Rounds.info), if it is given one.
static func tracer(context: Node, from: Vector3, to: Vector3, eye: Vector3, round_id := &"", spec := {}) -> Node3D:
	if context == null or not context.is_inside_tree() or from.distance_to(to) < 0.2:
		return null

	var line := MeshInstance3D.new()
	line.name = "GunTracer"
	var width: float = spec.get("tracer_width", TRACER_WIDTH)
	var life: float = spec.get("tracer_life", TRACER_LIFE)
	var core: Color = spec.get("tracer_core", TRACER_CORE)
	var edge: Color = spec.get("tracer_edge", TRACER_EDGE)
	line.mesh = MeshVfx.ribbon(PackedVector3Array([from, from.lerp(to, 0.5), to]), width, eye)
	line.set_meta(&"round", round_id)
	line.set_meta(&"width", width)
	line.set_meta(&"life", life)
	var look := MeshVfx.look(core, core.lerp(edge, 0.5), edge, spec.get("tracer_energy", 2.2), 0.05, 0.0)
	look.set_shader_parameter(&"tail_eat", 0.5)
	line.mesh.surface_set_material(0, look)
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	line.add_to_group(&"gunfx_tracer")
	_world_of(context).add_child(line)
	_keep(line, life)
	return line


## The resin a copal ball leaves on its way: a thread of amber smoke, hanging where
## it went a moment after the tracer has gone.
static func trail(context: Node, from: Vector3, to: Vector3, eye: Vector3) -> Node3D:
	if context == null or not context.is_inside_tree() or from.distance_to(to) < 0.2:
		return null

	var line := MeshInstance3D.new()
	line.name = "RoundTrail"
	var points := PackedVector3Array()

	for i in TRAIL_POINTS + 1:
		var u := float(i) / float(TRAIL_POINTS)
		points.append(from.lerp(to, u) + Vector3(0.0, sin(u * 11.0) * TRAIL_WAVER * u, 0.0))

	line.mesh = MeshVfx.ribbon(points, TRAIL_WIDTH, eye)
	var look := MeshVfx.look(TRAIL_CORE, TRAIL_BODY, TRAIL_EDGE, 1.0, 0.15, 0.3, 4.2)
	look.shader = SMOKE_SHADER
	look.set_shader_parameter(&"tail_eat", 0.0)
	look.set_shader_parameter(&"hardness", 0.1)
	look.set_shader_parameter(&"opacity", 0.75)
	line.mesh.surface_set_material(0, look)
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	line.add_to_group(&"round_fx_trail")
	_world_of(context).add_child(line)
	var thin := line.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	thin.tween_method(func(e: float): look.set_shader_parameter(&"erosion", e), 0.15, 1.0, TRAIL_LIFE).set_ease(Tween.EASE_IN)
	_keep(line, TRAIL_LIFE)
	return line


## What a ball did to a monster, big enough to read at range: `read` &"glance", a
## small cold star and a spark skipping off, it told for little; &"burst", a star in
## its round's colours, `size` 1 for its full measure.
static func impact(context: Node, read: StringName, spec: Dictionary, at: Vector3, eye: Vector3, shot: int, size := 1.0, coming := Vector3.FORWARD) -> Node3D:
	if context == null or not context.is_inside_tree():
		return null

	var core: Color = spec.get("tracer_core", FLASH_CORE)
	var edge: Color = spec.get("tracer_edge", FLASH_EDGE)
	var body: Color = spec.get("colour", FLASH_BODY)
	var glance := read == &"glance"
	var mark := MeshInstance3D.new()
	mark.name = "RoundImpact"
	mark.set_meta(&"read", read)
	mark.add_to_group(&"round_fx_impact")
	var roll := float(ROLLS[shot % ROLLS.size()])
	mark.mesh = _spikes(SPIKES, (GLANCE_SIZE if glance else BURST_SIZE) * size, roll)
	var look := _flash_look(shot)
	look.set_shader_parameter(&"core", core)
	look.set_shader_parameter(&"body", body)
	look.set_shader_parameter(&"edge", edge)
	look.set_shader_parameter(&"energy", 2.0 if glance else FLASH_ENERGY)
	look.set_shader_parameter(&"core_reach", SPIKE_CREAM)
	look.set_shader_parameter(&"tail_eat", 0.3)
	look.set_shader_parameter(&"z_clip", 1.0)
	look.set_shader_parameter(&"fov_override", 0.0)
	mark.material_override = look
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mark.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_world_of(context).add_child(mark)
	# Its spikes lean toward you, so you see all of the star.
	mark.global_transform = Transform3D(Basis.IDENTITY, at).looking_at(eye, Vector3.UP if absf((eye - at).normalized().y) < 0.99 else Vector3.RIGHT)
	var life := GLANCE_LIFE if glance else BURST_LIFE
	var fade := mark.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).set_parallel(true)
	mark.scale = Vector3.ONE * 0.6
	fade.tween_property(mark, "scale", Vector3.ONE * 1.15, life).set_ease(Tween.EASE_OUT)
	fade.tween_method(func(e: float): look.set_shader_parameter(&"erosion", e), 0.1, 0.85, life)
	_keep(mark, life)

	if glance:
		# Off it goes, back the way it came and aside.
		var turn := roll * 2.0
		var off := (-coming.normalized() + Vector3(cos(turn), 0.6, sin(turn)) * 0.9).normalized()
		tracer(context, at, at + off * RICOCHET, eye, &"", spec)

	return mark


## Every gun effect still showing.
static func live_count() -> int:
	_live = _live.filter(func(ref): return ref.get_ref() != null and is_instance_valid(ref.get_ref()) and not (ref.get_ref() as Node).is_queued_for_deletion())
	return _live.size()


# Pieces

## A burst of sharp spikes about the bore (-Z), one for each of `lengths`
## (of `length`), turned by `roll`: each a thin three-sided spike from near
## the bore out and forward to its point; v runs from its root to its point,
## so the noise eats it from its tip.
static func _spikes(lengths: Array, length: float, roll: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := lengths.size()

	for i in count:
		var turn := roll + TAU * float(i) / float(count)
		var out := Vector3(cos(turn), sin(turn), 0.0)
		var long := length * float(lengths[i])
		var tip := (out * 0.82 + Vector3(0, 0, -0.58)).normalized() * long
		var across := out.cross(Vector3.FORWARD).normalized() * long * 0.11
		var root := out * length * 0.06
		var depth := Vector3(0, 0, -long * 0.08)
		var base := [root - across, root + across, root + depth]

		for k in 3:
			var a: Vector3 = base[k]
			var b: Vector3 = base[(k + 1) % 3]
			st.set_uv(Vector2(0.0, 0.0))
			st.add_vertex(a)
			st.set_uv(Vector2(1.0, 0.0))
			st.add_vertex(b)
			st.set_uv(Vector2(0.5, 1.0))
			st.add_vertex(tip)

	st.generate_normals()
	return st.commit()


## A spark's streak: two crossed thin quads `length` long along -Z, `width`
## across; v from its head (0) to its tail (1).
static func _streak_mesh(length: float, width: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for across in [Vector3.RIGHT, Vector3.UP]:
		var w: Vector3 = across * width * 0.5
		var corners := [-w, w, w + Vector3(0, 0, length), -w + Vector3(0, 0, length)]
		var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]

		for k in [0, 1, 2, 0, 2, 3]:
			st.set_uv(uvs[k])
			st.set_normal(across.cross(Vector3.BACK))
			st.add_vertex(corners[k])

	return st.commit()


## A star of `count` flat petals about -Z (the Ward's puncture), each `length` long,
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
