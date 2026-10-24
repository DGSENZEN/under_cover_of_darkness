extends MeshInstance3D
## The smoke that trails up from the muzzle once the gun stops firing, the
## Deadlock way: a thin ribbon of powder smoke breathed out of the barrel
## for `emit_time`, each point of it rising, curling and spreading as it
## ages and is eaten away (vfx_smoke, lit by the scene). Its root follows
## the muzzle, so the trail bends behind the barrel as the gun moves; the
## next shot (stop()) or putting the gun away cuts it off, and what is
## already out rises on and fades. In the world, built afresh each tick as
## a ribbon turned to the camera.

const MeshVfx := preload("res://scripts/Visual/MeshVfx.gd")
const SMOKE_SHADER := preload("res://scripts/Visual/vfx_smoke.gdshader")
const Fx := preload("res://scripts/Visual/Fx.gd")

## Seconds a point of it lasts.
const LIFE := 1.4
## How fast it rises (m/s), and how far it drifts with the air (m/s).
const RISE := 0.22
const DRIFT := Vector3(0.03, 0.0, 0.015)
## How wide it is as it leaves the barrel and at the top of its climb (m).
const WIDTH_ROOT := 0.008
const WIDTH_TOP := 0.048
## How far it curls aside as it climbs (m), and how fast.
const CURL := 0.07
const CURL_RATE := 2.6
## The last of its breath thins out over this much of emit_time; its first
## swells in over SWELL (s), so its tip is drawn to a point.
const THIN := 0.45
const SWELL := 0.25
## Pale grey smoke, lit: lighter than the shot's curls, as a thin wisp is.
const CORE := Color("#E4DED4")
const BODY := Color("#C4BCB0")
const EDGE := Color("#9C9488")

## Seconds it breathes smoke out of the barrel.
var emit_time := 1.0
## Where the muzzle is (world), or null when the gun is away.
var _source: Callable
var _emitted := 0.0
var _emitting := true
var _phase := 0.0
## [birth position, age, width at birth (of 1), curl phase] from the oldest
## to the newest.
var _points: Array = []


## A trail from the muzzle `source` gives (world; null when the gun is
## away), breathed out for `seconds`. Null with effects off.
static func rise(context: Node, source: Callable, seconds: float, seed := 0) -> MeshInstance3D:
	if context == null or not context.is_inside_tree() or not Fx.enabled:
		return null

	var wisp: MeshInstance3D = load("res://scripts/Visual/GunWisp.gd").new()
	wisp.name = "GunWisp"
	wisp.emit_time = seconds
	wisp._source = source
	wisp._phase = float(seed) * 1.7
	var look := MeshVfx.look(CORE, BODY, EDGE, 1.0, 0.15, 0.55, 2.3 + float(seed))
	look.shader = SMOKE_SHADER
	look.set_shader_parameter(&"tail_eat", 0.75)
	# Long soft shapes up the ribbon; a soft bitten edge; see-through.
	look.set_shader_parameter(&"tiling", Vector2(0.6, 1.4))
	look.set_shader_parameter(&"hardness", 0.12)
	look.set_shader_parameter(&"opacity", 0.75)
	look.set_shader_parameter(&"churn", 0.006)
	look.set_shader_parameter(&"rim", 1.0)
	wisp.material_override = look
	wisp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wisp.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	wisp.add_to_group(&"gunfx_wisp")
	var tree := context.get_tree()
	(tree.current_scene if tree.current_scene != null else tree.root).add_child(wisp)
	wisp.global_transform = Transform3D.IDENTITY
	return wisp


func is_emitting() -> bool:
	return _emitting


## Cut off: no more out of the barrel; what is out rises on and fades.
func stop() -> void:
	_emitting = false


## Its top (the oldest point) and its root at the muzzle (world).
func span() -> Array:
	if _points.is_empty():
		return [global_position, global_position]

	return [_place(_points[0]), _place(_points[-1])]


## How wide it is at the muzzle and at its widest (m).
func widths() -> Vector2:
	if _points.is_empty():
		return Vector2.ZERO

	var top := 0.0

	for p in _points:
		top = maxf(top, _width(p))

	return Vector2(_width(_points[-1]), top)


func _physics_process(delta: float) -> void:
	for p in _points:
		p[1] += delta

	while not _points.is_empty() and float(_points[0][1]) >= LIFE:
		_points.pop_front()

	if _emitting:
		_emitted += delta
		var from: Variant = _source.call() if _source.is_valid() else null

		if from == null or _emitted >= emit_time:
			_emitting = false
		else:
			# Thinning out over the last of its breath.
			var left := (emit_time - _emitted) / maxf(emit_time * THIN, 0.01)
			var strength := minf(clampf(left, 0.15, 1.0), clampf(_emitted / SWELL, 0.1, 1.0))
			_points.append([from, 0.0, strength, _phase + _emitted * CURL_RATE])

	if not _emitting and _points.is_empty():
		queue_free()
		return

	_build()


## Where a point is now: risen, drifted, curled aside more the older it is.
func _place(p: Array) -> Vector3:
	var age: float = p[1]
	var turn: float = p[3] + age * 1.5
	var curl := Vector3(sin(turn), 0.0, cos(turn * 0.8)) * CURL * age / LIFE
	return (p[0] as Vector3) + Vector3.UP * RISE * age + DRIFT * age + curl


func _width(p: Array) -> float:
	var t: float = float(p[1]) / LIFE
	return lerpf(WIDTH_ROOT, WIDTH_TOP, sqrt(t)) * float(p[2])


## A ribbon through its points, turned to the camera; v each point's age, so
## the noise eats its old end first.
func _build() -> void:
	if _points.size() < 2:
		mesh = null
		return

	var camera := get_viewport().get_camera_3d()
	var eye: Vector3 = camera.global_position if camera != null else Vector3.ZERO
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var edges := []
	var n := _points.size()
	var places: Array = _points.map(func(p): return _place(p))

	for i in n:
		var at: Vector3 = places[i]
		var along: Vector3 = (places[mini(i + 1, n - 1)] as Vector3) - (places[maxi(i - 1, 0)] as Vector3)
		var facing := (eye - at).normalized()
		var across := along.cross(facing).normalized() * _width(_points[i]) * 0.5
		# v from its root (0) to its oldest (1).
		var age := float(_points[i][1]) / LIFE
		edges.append([at - across, at + across, age, facing])

	for i in n - 1:
		var a: Array = edges[i]
		var b: Array = edges[i + 1]
		var corners := [a[0], a[1], b[0], b[1]]
		var uvs := [Vector2(0, a[2]), Vector2(1, a[2]), Vector2(0, b[2]), Vector2(1, b[2])]
		var normals := [a[3], a[3], b[3], b[3]]

		# Wound to face the camera, so it is lit on the side you see.
		for k in [0, 2, 1, 2, 3, 1]:
			st.set_uv(uvs[k])
			st.set_normal(normals[k])
			st.add_vertex(corners[k])

	mesh = st.commit()
