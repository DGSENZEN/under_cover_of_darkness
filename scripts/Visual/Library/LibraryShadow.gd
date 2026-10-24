extends Node3D
## The librarian's ownerless shadow (docs/superpowers/specs/2026-10-17-librarian-shop-design.md, "Shadows"): a tall man
## in the wide-brimmed hat and long coat that hang on his stand in the corner, walking (textures/painted/underground/
## librarian_shadow_walk.png: his formal walk frame by frame, tools/textures/librarian_shadow.py --walk), crossing the
## fronts of his wall cases where no one stands. His frames go round with the ground he covers, so his feet hold.
## It is how he is shown before his model exists. Like the corridor's shadow with no owner (OwnerlessShadow.gd, whose
## angles, fades and pace it keeps), it crosses only where the watcher sees it from the corner of the eye, and the
## moment they look at it, it is gone; every minute or two. It is thrown into a shallow box over the case it crosses
## (shadow_volume.gdshader: a decal could not darken the shop's painted light, which glows): from just before the
## case's front into its books, short of the wall behind; floors and tops turned away from it fade it out.

const Corridor := preload("res://scripts/Visual/OwnerlessShadow.gd")
const IMAGE := "res://textures/painted/underground/librarian_shadow_walk.png"
const WALK := "res://textures/painted/underground/librarian_shadow_walk.json"
const VOLUME := preload("res://scripts/Visual/Library/shadow_volume.gdshader")
## Its size on a case (m: wide, tall; the picture's 1:2, a man of about 1.95 m in his hat), how far its box reaches
## before a case's front and into it (m), how long between crossings (s).
const SIZE := Vector2(1.03, 2.06)
const BEFORE := 0.12
const INTO := 0.4
const EVERY := Vector2(60.0, 120.0)
## How dark it is at its darkest; over how much of each end of its way it fades in and out (m: a way may end on a
## case, where something else stands too near past it).
const DARK := 0.9
const ENDS := 0.35

## Its ways: [the case's front frame (its front's middle on the floor, +x along it, +z out of it), its run along x
## (from, to: m, from beyond one end of the case to beyond the other), the case].
var routes: Array = []
## Whose eye it keeps to (else whichever camera is drawing); the box it is drawn in, how dark it is now, and his
## picture (walking toward its left; turned round for the other way).
var watcher: Camera3D
var shade: MeshInstance3D
var darkness := 0.0
var picture: Texture2D
## His walk: how many frames, how far a cycle of them carries him (m), the frame he is on.
var frames := 1
var stride := 1.0
var frame := 0
## Until its next crossing is due (s); which way it crosses now (-1 none), how far along and which way it goes.
var wait := 0.0
var route := -1
var along := 0.0
## Only this way, or any (-1): for the stills and the tests.
var only := -1
## Whether it may be drawn: the effects on (not the form light), the decals on (F3).
var shown := true
var decals_on := true

var _rng := RandomNumberGenerator.new()
var _going := 0
var _seen := false
## How far he has walked on this crossing (m), whichever way.
var _walked := 0.0
## How dark he is coming in or going (before his way's ends fade him).
var _alpha := 0.0
var _look: ShaderMaterial


func build(ways: Array, texture: Texture2D) -> void:
	name = "LibraryShadow"
	routes = ways
	_rng.seed = 23
	wait = next_gap()
	picture = texture
	var cells := Vector2.ONE
	if FileAccess.file_exists(WALK):
		var walk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(WALK))
		frames = int(walk["frames"])
		cells = Vector2(walk["cols"], walk["rows"])
		stride = float(walk["stride"]) * SIZE.y
	var box := BoxMesh.new()
	box.size = Vector3(SIZE.x, SIZE.y, BEFORE + INTO)
	_look = ShaderMaterial.new()
	_look.shader = VOLUME
	_look.set_shader_parameter("picture", texture)
	_look.set_shader_parameter("size", box.size)
	_look.set_shader_parameter("cells", cells)
	_look.render_priority = 1
	box.material = _look
	shade = MeshInstance3D.new()
	shade.name = "shadow"
	shade.mesh = box
	shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shade.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	shade.visible = false
	add_child(shade)
	_darken(0.0)


## The wait before the next crossing.
func next_gap() -> float:
	return _rng.randf_range(EVERY.x, EVERY.y)


func crossing() -> bool:
	return route >= 0


## His shadow set `at` along `way` (its box over the case's front, its axis out of it, its picture upright).
func place(way: Array, at: float) -> void:
	var front: Transform3D = way[0]
	shade.global_transform = Transform3D(front.basis.orthonormalized(),
		front * Vector3(at, SIZE.y * 0.5, BEFORE - (BEFORE + INTO) * 0.5))


## He crosses way `i` now (or the one most in the corner of the eye), from its end farther from where the eye looks.
func cross_now(i := -1) -> void:
	if i < 0:
		i = _best()
	if i < 0:
		return
	route = i
	var way: Array = routes[i]
	var run: Vector2 = way[1]
	var front: Transform3D = way[0]
	var from_start := _angle_to(front * Vector3(run.x, 1.2, 0.0)) > _angle_to(front * Vector3(run.y, 1.2, 0.0))
	_going = 1 if from_start else -1
	along = run.x if from_start else run.y
	_seen = false
	_walked = 0.0
	frame = 0
	_look.set_shader_parameter("frame", 0.0)
	_alpha = 0.0
	# (The picture walks toward its left: crossing toward +x, it is turned round.)
	_look.set_shader_parameter("flip", _going > 0)
	_darken(0.0)
	place(way, along)
	_show()


func set_decals(on: bool) -> void:
	decals_on = on
	_show()


func set_shown(on: bool) -> void:
	shown = on
	_show()


func _show() -> void:
	shade.visible = route >= 0 and shown and decals_on


func _darken(value: float) -> void:
	darkness = value
	_look.set_shader_parameter("darkness", value)


func _process(delta: float) -> void:
	if route < 0:
		wait -= delta
		if wait <= 0.0:
			wait = next_gap()
			cross_now()
		return

	var way: Array = routes[route]
	var run: Vector2 = way[1]
	along += _going * Corridor.PACE * delta
	place(way, along)
	_walked += Corridor.PACE * delta
	var step := int(fposmod(_walked / stride, 1.0) * frames) % frames
	if step != frame:
		frame = step
		_look.set_shader_parameter("frame", float(frame))
	_seen = _seen or _angle_to(shade.global_position) < Corridor.LOOKED
	var alpha := _alpha
	alpha = maxf(0.0, alpha - Corridor.VANISH * delta) if _seen else minf(DARK, alpha + Corridor.ARRIVE * delta)
	_alpha = alpha
	var ends := clampf(minf(along - run.x, run.y - along) / ENDS, 0.0, 1.0)
	_darken(alpha * ends)
	if (_seen and alpha <= 0.0) or along < run.x or along > run.y:
		route = -1
		_alpha = 0.0
		_darken(0.0)
		_show()


## The way whose middle is most squarely in the corner of the eye (none if no way is, or no one looks).
func _best() -> int:
	var best := -1
	var most := INF
	for i in routes.size():
		if only >= 0 and i != only:
			continue
		var way: Array = routes[i]
		var run: Vector2 = way[1]
		var a := _angle_to((way[0] as Transform3D) * Vector3((run.x + run.y) * 0.5, 1.2, 0.0))
		# (Nearest the middle of the corner of the eye.)
		var off := absf(a - (Corridor.LOOKED + Corridor.SEEN_FROM) * 0.5)
		if a >= Corridor.LOOKED and a < Corridor.SEEN_FROM and off < most:
			most = off
			best = i
	return best


func _eye() -> Camera3D:
	if watcher != null and is_instance_valid(watcher):
		return watcher
	var viewport := get_viewport()
	return viewport.get_camera_3d() if viewport != null else null


## Degrees from where the eye looks to `at` (straight behind if no one looks).
func _angle_to(at: Vector3) -> float:
	var eye := _eye()
	if eye == null:
		return 180.0
	var look := -eye.global_transform.basis.z
	return rad_to_deg(look.angle_to((at - eye.global_position).normalized()))
