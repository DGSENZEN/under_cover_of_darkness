extends MeshInstance3D
## The candle lane's people (tools/textures/silhouettes.py): each a shade, one cell of the sheet on a quad drawn in
## Mignola's ink fraying into smoke (shade_cutout.gdshader), seen from both sides, its feet at its origin, its face
## toward +Z (the side it is meant to be seen from). In its cell a figure faces left as drawn; mirrored, right. No
## light falls on it; it casts nothing.
## A flat figure seen along its own plane is a sliver: each turns toward whoever looks, never more than TURN from
## how it was stood (`rest_yaw`), so it keeps the way it faces and is never seen edge-on.

const SHEET := "res://textures/painted/underground/silhouettes.png"
const META := "res://textures/painted/underground/silhouettes.json"
const SHADE := preload("res://scripts/Visual/shade_cutout.gdshader")
## How many cells across the sheet is; how far a figure turns toward the eye (rad).
const COLS := 4
const TURN := deg_to_rad(55.0)
## Its smoke's bands (Mignola's black, only its last edge a cold grey: the nahual's), and how high it climbs (m).
const SMOKE := [Color(0.05, 0.05, 0.06), Color(0.04, 0.04, 0.05), Color(0.2, 0.23, 0.26)]
const PLUME_RISE := 0.5

static var _meta: Dictionary = {}
static var _sheet: Texture2D

## Which way it was stood (about the vertical, in its parent's frame); set on its first frame.
var rest_yaw := NAN


## A cut-out of `pose` (its name on the sheet), facing left (or, `mirror`ed, right) seen from its +Z side; null if
## the sheet has no such pose.
static func make(pose: String, mirror := false) -> MeshInstance3D:
	if _meta.is_empty():
		if not FileAccess.file_exists(META) or not ResourceLoader.exists(SHEET):
			return null
		_meta = JSON.parse_string(FileAccess.get_file_as_string(META))
		_sheet = load(SHEET)
	var entry: Dictionary = {}
	for p: Dictionary in _meta["poses"]:
		if p["name"] == pose:
			entry = p
	if entry.is_empty():
		return null
	var cell_m: float = _meta["cell_m"]
	var rows := ceili(float(_meta["poses"].size()) / COLS)
	var quad := QuadMesh.new()
	# (A cell is half as wide as it is tall.)
	quad.size = Vector2(cell_m * 0.5, cell_m)
	quad.center_offset = Vector3(0.0, cell_m / 2.0, 0.0)
	# A shade (shade_cutout.gdshader): the figure in ink, fraying into its climbing smoke, its feet lost in mist.
	var look := ShaderMaterial.new()
	look.shader = SHADE
	look.set_shader_parameter(&"sheet", _sheet)
	look.set_shader_parameter(&"noise", Vfx.noise_3d())
	var col: float = entry["cell"][0]
	var row: float = entry["cell"][1]
	look.set_shader_parameter(&"cell_scale", Vector2((-1.0 if mirror else 1.0) / COLS, 1.0 / rows))
	look.set_shader_parameter(&"cell_offset", Vector2((col + (1.0 if mirror else 0.0)) / COLS, row / rows))
	look.set_shader_parameter(&"presence", 1.0)
	quad.material = look
	var person: MeshInstance3D = load("res://scripts/Visual/Silhouette.gd").new()
	person.name = pose
	person.mesh = quad
	person.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	person.set_meta("pose", pose)
	person.set_meta("height_m", entry["height_m"])
	_smoke(person, entry, mirror)
	return person


## Its smoke rising off its head and shoulders, the nahual's black tendrils (MeshVfx), trailing back from the way it
## faces.
static func _smoke(person: MeshInstance3D, entry: Dictionary, mirror: bool) -> void:
	var side := -1.0 if mirror else 1.0
	var height: float = entry["height_m"]
	var head: Array = entry.get("head", [0.0, height - 0.15])
	var shoulders: Array = entry.get("shoulders", [0.0, height - 0.35])
	var roots := [Vector2(float(head[0]) * side, float(head[1]) + 0.08),
		Vector2((float(shoulders[0]) + 0.1) * side, float(shoulders[1]) + 0.02),
		Vector2((float(shoulders[0]) - 0.06) * side, float(shoulders[1]) - 0.02)]
	for k in roots.size():
		var root: Vector2 = roots[k]
		var path := PackedVector3Array()
		for i in 10:
			var t := i / 9.0
			# (Its figure faces -x as drawn: its smoke trails back, +x, and climbs.)
			path.append(Vector3(root.x + side * (0.14 * t + 0.03 * sin(t * 5.0 + k)), root.y + PLUME_RISE * t,
				0.025 * cos(t * 6.0 + k * 1.7)))
		var smoke := MeshInstance3D.new()
		smoke.name = "smoke_%d" % k
		smoke.mesh = MeshVfx.tendril(path, 0.07 if k == 0 else 0.05)
		var look := MeshVfx.look(SMOKE[0], SMOKE[1], SMOKE[2], 1.0, 0.22, 0.35, float(k) * 2.7 + float(head[1]) * 9.0)
		look.set_shader_parameter(&"tail_eat", 0.7)
		look.set_shader_parameter(&"churn", 0.015)
		look.set_shader_parameter(&"tiling", Vector2(0.8, 0.6))
		look.set_shader_parameter(&"hardness", 0.03)
		look.set_shader_parameter(&"rim", 6.0)
		smoke.set_surface_override_material(0, look)
		smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		person.add_child(smoke)


func _process(_delta: float) -> void:
	if is_nan(rest_yaw):
		rest_yaw = rotation.y
	var camera := get_viewport().get_camera_3d()
	var parent := get_parent_node_3d()
	if camera == null or parent == null:
		return
	var to := parent.to_local(camera.global_position) - position
	if Vector2(to.x, to.z).length() < 0.05:
		return
	var toward := atan2(to.x, to.z)
	rotation.y = rest_yaw + clampf(wrapf(toward - rest_yaw, -PI, PI), -TURN, TURN)
