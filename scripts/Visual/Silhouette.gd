extends MeshInstance3D
## The candle lane's people (tools/textures/silhouettes.py): each a shade, one cell of a sheet on a quad drawn in
## Mignola's ink fraying into smoke (shade_cutout.gdshader), seen from both sides, its feet at its origin, its face
## toward +Z (the side it is meant to be seen from). In its cell a figure faces left as drawn; mirrored, right. No
## light falls on it; it casts nothing.
## A still one (`make`, the poses' sheet) turns toward whoever looks, never more than TURN from how it was stood
## (`rest_yaw`), so it keeps the way it faces and is never seen edge-on. A moving one (`make_loop`, the loops' sheet)
## plays its loop: an idle by the clock; a walker by the ground it covers (`walk`), always turned to the eye and
## mirrored so it is seen going the way it goes. Each forms out of its mist from the feet up and comes apart into
## smoke as it goes (`presence`).

const SHEET := "res://textures/painted/underground/silhouettes.png"
const META := "res://textures/painted/underground/silhouettes.json"
const LOOPS_SHEET := "res://textures/painted/underground/shade_loops.png"
const LOOPS_META := "res://textures/painted/underground/shade_loops.json"
const SHADE := preload("res://scripts/Visual/shade_cutout.gdshader")
## How many cells across the poses' sheet is; how far a still figure turns toward the eye (rad).
const COLS := 4
const TURN := deg_to_rad(55.0)
## Its smoke's bands (a charcoal a little lighter than the nahual's black, its last edge a cold grey), how high it
## climbs (m), how thick at its root, how eaten (more than the nahual's: gentle wisps, not plumes).
const SMOKE := [Color(0.09, 0.09, 0.1), Color(0.07, 0.07, 0.08), Color(0.24, 0.26, 0.29)]
const PLUME_RISE := 0.34
const PLUME_WIDTH := 0.04
const PLUME_EATEN := 0.42
## How little of it is here before its smoke shows (its wisps rise only from a formed figure).
const SMOKE_FROM := 0.75
## A walker turns over (mirrors) only when the way it goes crosses the eye's sight by this much (no flicker).
const FLIP_AT := 0.15

static var _meta: Dictionary = {}
static var _sheet: Texture2D
static var _loops_meta: Dictionary = {}
static var _loops_sheet: Texture2D

## Which way it was stood (about the vertical, in its parent's frame); set on its first frame.
var rest_yaw := NAN
## How much of it is here (0 mist, 1 whole).
var presence := 1.0:
	set(value):
		presence = clampf(value, 0.0, 1.0)
		if _look != null:
			_look.set_shader_parameter(&"presence", presence)
		if _smoke_holder != null:
			_smoke_holder.visible = presence >= SMOKE_FROM
## Its loop (an entry of the loops' sheet), its frame, which way it goes (a walker: its parent's frame), and how far
## through its cycle it is (0-1).
var loop: Dictionary = {}
var frame := 0
var heading := Vector3.ZERO
var cycle := 0.0

var _look: ShaderMaterial
var _smoke_holder: Node3D
var _mirror := false
var _row := 0.0
var _rows := 1.0
var _cols := 1.0
var _col := 0.0


## A still cut-out of `pose` (its name on the poses' sheet), facing left (or, `mirror`ed, right) seen from its +Z side;
## null if the sheet has no such pose.
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
	var rows := ceili(float(_meta["poses"].size()) / COLS)
	var person := _built(pose, entry, _sheet, _meta["cell_m"], COLS, rows)
	person._col = entry["cell"][0]
	person._row = entry["cell"][1]
	person._set_mirror(mirror)
	return person


## A moving shade playing `name` (its row on the loops' sheet), facing left (or `mirror`ed, right); null if none.
static func make_loop(name: String, mirror := false) -> MeshInstance3D:
	if _loops_meta.is_empty():
		if not FileAccess.file_exists(LOOPS_META) or not ResourceLoader.exists(LOOPS_SHEET):
			return null
		_loops_meta = JSON.parse_string(FileAccess.get_file_as_string(LOOPS_META))
		_loops_sheet = load(LOOPS_SHEET)
	var entry: Dictionary = {}
	for l: Dictionary in _loops_meta["loops"]:
		if l["name"] == name:
			entry = l
	if entry.is_empty():
		return null
	var frames: int = _loops_meta["frames"]
	var person := _built(name, entry, _loops_sheet, _loops_meta["cell_m"], frames, _loops_meta["loops"].size())
	person.loop = entry
	person._row = entry["row"]
	person._set_mirror(mirror)
	return person


static func _built(name: String, entry: Dictionary, sheet: Texture2D, cell_m: float, cols: int, rows: int) -> MeshInstance3D:
	var quad := QuadMesh.new()
	# (A cell is half as wide as it is tall.)
	quad.size = Vector2(cell_m * 0.5, cell_m)
	quad.center_offset = Vector3(0.0, cell_m / 2.0, 0.0)
	# A shade (shade_cutout.gdshader): the figure in ink, fraying into its climbing smoke, its feet lost in mist.
	var look := ShaderMaterial.new()
	look.shader = SHADE
	look.set_shader_parameter(&"sheet", sheet)
	look.set_shader_parameter(&"noise", Vfx.noise_3d())
	look.set_shader_parameter(&"presence", 1.0)
	quad.material = look
	var person: MeshInstance3D = load("res://scripts/Visual/Silhouette.gd").new()
	person.name = name
	person.mesh = quad
	person.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	person.set_meta("pose", name)
	person.set_meta("height_m", entry["height_m"])
	person._look = look
	person._cols = cols
	person._rows = rows
	person._smoke(entry)
	return person


## Its smoke rising gently off its head and a shoulder, thin wisps (MeshVfx tendrils, as the nahual's, but softer),
## trailing back from the way it faces (drawn facing left; turned round when it is mirrored).
func _smoke(entry: Dictionary) -> void:
	_smoke_holder = Node3D.new()
	_smoke_holder.name = "smoke"
	add_child(_smoke_holder)
	var height: float = entry["height_m"]
	var head: Array = entry.get("head", [0.0, height - 0.15])
	var shoulders: Array = entry.get("shoulders", [0.0, height - 0.35])
	var roots := [Vector2(float(head[0]), float(head[1]) + 0.06), Vector2(float(shoulders[0]) + 0.1, float(shoulders[1]) + 0.02)]
	for k in roots.size():
		var root: Vector2 = roots[k]
		var path := PackedVector3Array()
		for i in 10:
			var t := i / 9.0
			# (Its figure faces -x as drawn: its smoke drifts back, +x, and climbs, curling; bending back as it
			# rises, so it reads as smoke left behind, never a horn standing up.)
			path.append(Vector3(root.x + 0.26 * t * t + 0.06 * t + 0.035 * sin(t * 4.0 + k),
				root.y + PLUME_RISE * (t - 0.3 * t * t), 0.04 * cos(t * 5.0 + k * 1.7)))
		var smoke := MeshInstance3D.new()
		smoke.name = "smoke_%d" % k
		smoke.mesh = MeshVfx.tendril(path, PLUME_WIDTH * (1.2 if k == 0 else 1.0))
		var look := MeshVfx.look(SMOKE[0], SMOKE[1], SMOKE[2], 1.0, PLUME_EATEN, 0.3, float(k) * 2.7 + float(head[1]) * 9.0)
		look.set_shader_parameter(&"tail_eat", 0.7)
		look.set_shader_parameter(&"churn", 0.015)
		look.set_shader_parameter(&"tiling", Vector2(0.8, 0.6))
		look.set_shader_parameter(&"hardness", 0.03)
		look.set_shader_parameter(&"rim", 3.0)
		smoke.set_surface_override_material(0, look)
		smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_smoke_holder.add_child(smoke)


## Facing left as drawn, or (mirrored) right; its smoke turned to trail behind.
func _set_mirror(mirror: bool) -> void:
	_mirror = mirror
	_smoke_holder.rotation.y = PI if mirror else 0.0
	_show_cell()


func _show_cell() -> void:
	var col := float(frame) if not loop.is_empty() else _col
	_look.set_shader_parameter(&"cell_scale", Vector2((-1.0 if _mirror else 1.0) / _cols, 1.0 / _rows))
	_look.set_shader_parameter(&"cell_offset", Vector2((col + (1.0 if _mirror else 0.0)) / _cols, _row / _rows))


## A walker gone `distance` m on: its feet step through its cycle by the ground they cover.
func walk(distance: float) -> void:
	var stride: float = loop.get("stride_m", 0.0)
	if stride <= 0.0:
		return
	cycle = fposmod(cycle + distance / stride, 1.0)
	var now := int(cycle * _cols) % int(_cols)
	if now != frame:
		frame = now
		_show_cell()


func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	var parent := get_parent_node_3d()
	if camera == null or parent == null:
		return
	var to := parent.to_local(camera.global_position) - position
	if Vector2(to.x, to.z).length() < 0.05:
		return
	var toward := atan2(to.x, to.z)
	if heading != Vector3.ZERO:
		# A walker: full to the eye, and mirrored when the way it goes runs to the eye's right.
		rotation.y = toward
		var right := Vector3(cos(toward), 0.0, -sin(toward))
		var across := heading.normalized().dot(right)
		if (across > FLIP_AT and not _mirror) or (across < -FLIP_AT and _mirror):
			_set_mirror(not _mirror)
		return
	if not loop.is_empty():
		# An idle: its loop by the clock.
		var seconds: float = maxf(float(loop.get("seconds", 1.0)), 0.1)
		cycle = fposmod(cycle + delta / seconds, 1.0)
		var now := int(cycle * _cols) % int(_cols)
		if now != frame:
			frame = now
			_show_cell()
	if is_nan(rest_yaw):
		rest_yaw = rotation.y
	rotation.y = rest_yaw + clampf(wrapf(toward - rest_yaw, -PI, PI), -TURN, TURN)
