extends Node3D
## The silt it brings up where it treads, hanging, as it would in still water: there's no water here, but it moves as if there were.

const SiltShader := preload("res://scripts/Monsters/revenant_silt.gdshader")
const BRUSH := preload("res://textures/painted/eclipse/brush.png")
const SILTS := 18
const SILT_LASTS := 2.4
const SILT_RISES := 0.16
const SILT_SIZE := 0.9

var _silts: MultiMeshInstance3D
## Each: [where, age, size].
var _silt_list: Array = []


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	var upright := QuadMesh.new()
	var look := ShaderMaterial.new()
	look.shader = SiltShader
	look.set_shader_parameter(&"stroke_sheet", BRUSH)
	upright.material = look
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	many.use_custom_data = true
	many.mesh = upright
	many.instance_count = SILTS
	_silts = MultiMeshInstance3D.new()
	_silts.multimesh = many
	_silts.custom_aabb = AABB(Vector3(-300, -60, -300), Vector3(600, 120, 600))
	_silts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_silts)

	for i in SILTS:
		many.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * 0.0005), Vector3(0.0, -50.0, 0.0)))
		many.set_instance_custom_data(i, Color(1.0, float(i) * 0.37, 0.0, 0.0))


func silt_now() -> int:
	return _silt_list.size()


## It comes down here, this hard.
func splash(at: Vector3, hard := 1.0) -> void:
	_silt_list.append([at, 0.0, hard])

	if _silt_list.size() > SILTS:
		_silt_list.pop_front()


func work(delta: float) -> void:
	for one in _silt_list:
		one[1] += delta

	while not _silt_list.is_empty() and float(_silt_list[0][1]) >= SILT_LASTS:
		_silt_list.pop_front()

	var silts := _silts.multimesh

	for i in SILTS:
		if i < _silt_list.size():
			var silt: Array = _silt_list[i]
			var share: float = float(silt[1]) / SILT_LASTS
			var size: float = SILT_SIZE * float(silt[2]) * (0.5 + share * 1.1)
			silts.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(size, size, 1.0)), (silt[0] as Vector3) + Vector3.UP * (0.1 + share * SILT_RISES * float(silt[2]))))
			silts.set_instance_custom_data(i, Color(share, float(i) * 0.37, 0.0, 0.0))
		else:
			silts.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * 0.0005), Vector3(0.0, -50.0, 0.0)))
