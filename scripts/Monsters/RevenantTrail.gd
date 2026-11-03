extends Node3D
## What a revenant's arms leave behind them in a blow: a smear of the lake's black water, lit at its edge with the seep, gone in a moment. Drawn from where its wrist and forearm
## have been, in the world, so it hangs where the arm was.

const LOOK := preload("res://scripts/Monsters/revenant_trail.gdshader")
const LONG := 14
const LASTS := 0.34

var _mesh: ImmediateMesh
var _draw: MeshInstance3D
## Each arm's: [wrist, along the forearm, age].
var _points: Array = [[], []]


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_mesh = ImmediateMesh.new()
	_draw = MeshInstance3D.new()
	_draw.mesh = _mesh
	var look := ShaderMaterial.new()
	look.shader = LOOK
	_draw.material_override = look
	_draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_draw.custom_aabb = AABB(Vector3(-200, -50, -200), Vector3(400, 100, 400))
	add_child(_draw)


## How many points each arm's smear has now.
func points_now() -> int:
	return _points[0].size() + _points[1].size()


func work(delta: float, striking: bool, wrist_r: Vector3, elbow_r: Vector3, wrist_l: Vector3, elbow_l: Vector3) -> void:
	for side in 2:
		var row: Array = _points[side]

		for point in row:
			point[2] += delta

		while not row.is_empty() and float(row[0][2]) > LASTS:
			row.pop_front()

		if striking:
			var wrist_at: Vector3 = wrist_r if side == 0 else wrist_l
			var elbow_at: Vector3 = elbow_r if side == 0 else elbow_l
			# Only an arm that is going somewhere leaves anything.
			if row.is_empty() or wrist_at.distance_to(row[-1][0]) > 0.05:
				row.append([wrist_at, wrist_at.lerp(elbow_at, 0.72), 0.0])

				if row.size() > LONG:
					row.pop_front()

	_mesh.clear_surfaces()
	_draw.visible = points_now() > 0

	for row in _points:
		if row.size() < 2:
			continue

		_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)

		for i in row.size():
			var along := float(i) / float(row.size() - 1)
			var fades := 1.0 - float(row[i][2]) / LASTS
			_mesh.surface_set_color(Color(along, fades, 0.0, 1.0))
			_mesh.surface_set_uv(Vector2(along, 0.0))
			_mesh.surface_add_vertex(row[i][0])
			_mesh.surface_set_uv(Vector2(along, 1.0))
			_mesh.surface_add_vertex(row[i][1])

		_mesh.surface_end()
