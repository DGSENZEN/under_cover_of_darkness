extends MeshInstance3D
## The candle lane's people (tools/textures/silhouettes.py): each a flat black cut-out, one cell of the sheet on a
## quad, seen from both sides, its feet at its origin, its face toward +Z (the side it is meant to be seen from).
## In its cell a figure faces left as drawn; mirrored, right. Mignola's black: no light falls on it, it casts nothing.
## A flat figure seen along its own plane is a sliver: each turns toward whoever looks, never more than TURN from
## how it was stood (`rest_yaw`), so it keeps the way it faces and is never seen edge-on.

const SHEET := "res://textures/painted/underground/silhouettes.png"
const META := "res://textures/painted/underground/silhouettes.json"
## How many cells across the sheet is; how far a figure turns toward the eye (rad).
const COLS := 4
const TURN := deg_to_rad(55.0)

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
	var look := StandardMaterial3D.new()
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.albedo_color = Color.BLACK
	look.albedo_texture = _sheet
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	look.alpha_scissor_threshold = 0.5
	look.cull_mode = BaseMaterial3D.CULL_DISABLED
	var col: float = entry["cell"][0]
	var row: float = entry["cell"][1]
	look.uv1_scale = Vector3((-1.0 if mirror else 1.0) / COLS, 1.0 / rows, 1.0)
	look.uv1_offset = Vector3((col + (1.0 if mirror else 0.0)) / COLS, row / rows, 0.0)
	quad.material = look
	var person: MeshInstance3D = load("res://scripts/Visual/Silhouette.gd").new()
	person.name = pose
	person.mesh = quad
	person.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	person.set_meta("pose", pose)
	person.set_meta("height_m", entry["height_m"])
	return person


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
