extends MeshInstance3D
## The Shard's trail: a dark smear of bent light behind it with a thin cold
## line down its middle (vfx_shard_trail), from where it was let go to where
## it is, each point fading over LIFE; at the shard's speed it draws a line
## from your hand to what it hits, and outlives it by that fade. In the
## world, built afresh each tick as a ribbon turned to the camera.

const MagicFx := preload("res://scripts/Visual/MagicFx.gd")
const TRAIL_SHADER := preload("res://scripts/Visual/vfx_shard_trail.gdshader")

## Seconds a point of it lasts.
const LIFE := 0.18
## How wide it is at its head (m).
const WIDTH := 0.12

var _follow: Node3D
## [position, age] from the oldest to the newest.
var _points: Array = []


## A trail on `shard` (anything with a visual_position()), starting at
## `from` (where it was let go, as you saw it). Null with effects off.
static func follow(shard: Node3D, from: Vector3) -> MeshInstance3D:
	if not MagicFx.allowed(shard):
		return null

	var trail: MeshInstance3D = load("res://scripts/Visual/ShardTrail.gd").new()
	trail.name = "ShardTrail"
	trail._follow = shard
	trail._points = [[from, 0.0]]
	var look := ShaderMaterial.new()
	look.shader = TRAIL_SHADER
	look.set_shader_parameter(&"line_tint", MagicFx.GLINT)
	trail.material_override = look
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trail.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	trail.add_to_group(&"shard_trail")
	var tree := shard.get_tree()
	(tree.current_scene if tree.current_scene != null else tree.root).add_child(trail)
	trail.global_transform = Transform3D.IDENTITY
	MagicFx._keep(trail, 3.5)
	return trail


## Its tail and its head (world).
func span() -> Array:
	if _points.is_empty():
		return [global_position, global_position]

	return [_points[0][0], _points[-1][0]]


func _physics_process(delta: float) -> void:
	for p in _points:
		p[1] += delta

	if is_instance_valid(_follow) and _follow.is_inside_tree() and not _follow.is_queued_for_deletion():
		_points.append([_follow.call(&"visual_position"), 0.0])

	while not _points.is_empty() and float(_points[0][1]) >= LIFE:
		_points.pop_front()

	if _points.size() < 2 and not is_instance_valid(_follow):
		queue_free()
		return

	_build()


## A ribbon through its points, turned to the camera; v each point's age.
func _build() -> void:
	if _points.size() < 2:
		mesh = null
		return

	var camera := get_viewport().get_camera_3d()
	var eye: Vector3 = camera.global_position if camera != null else Vector3.ZERO
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var edges := []

	for i in _points.size():
		var at: Vector3 = _points[i][0]
		var along: Vector3 = (_points[mini(i + 1, _points.size() - 1)][0] as Vector3) - (_points[maxi(i - 1, 0)][0] as Vector3)
		var across := along.cross(eye - at).normalized() * WIDTH * 0.5
		var age := float(_points[i][1]) / LIFE
		edges.append([at - across, at + across, age])

	for i in edges.size() - 1:
		var a: Array = edges[i]
		var b: Array = edges[i + 1]
		var corners := [a[0], a[1], b[0], b[1]]
		var uvs := [Vector2(0, a[2]), Vector2(1, a[2]), Vector2(0, b[2]), Vector2(1, b[2])]

		for k in [0, 1, 2, 2, 1, 3]:
			st.set_uv(uvs[k])
			st.set_normal(Vector3.UP)
			st.add_vertex(corners[k])

	mesh = st.commit()
