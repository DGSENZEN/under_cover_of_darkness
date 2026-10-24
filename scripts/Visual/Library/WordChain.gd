extends Node3D
## A chain of living words (docs/superpowers/specs/2026-10-17-librarian-shop-design.md: "chains of text, as if the
## words carried life"): its text's glyphs laid one after another along a path (world points), each standing upright
## on the path's line and turned along it, flowing along it as the words go. One draw for the whole chain: a MultiMesh
## of quads, each reading its glyph from the atlas (library_glyph.gdshader). An open chain's words come out of its
## start and are gone at its end, fading at both, and come again; a loop runs round and round. Its text and atlas can
## change at any time (the user's own words for the invented script).

const Glyphs := preload("res://scripts/Visual/Library/LibraryGlyphs.gd")
const Layers := preload("res://scripts/Visual/Layers.gd")
const SHADER := preload("res://scripts/Visual/Library/library_glyph.gdshader")

## A glyph's height (m); how fast the words go (m/s); the room a space leaves (of a glyph's size); how far at each end
## of an open chain the words fade (m).
@export var size := 0.04
@export var speed := 0.08
@export var gap := 0.6
@export var fade := 0.12
## Where its glyphs turn their faces, as far as the way they go lets them (world; Vector3.UP lays them flat on the
## floor): none stands each upright on the path's line.
@export var face := Vector3.ZERO
var loop := false

var path := PackedVector3Array()
var length := 0.0
## How many glyphs (spaces are not drawn); where each was last laid (world); how present the chain is.
var count := 0
var placed: Array[Vector3] = []
var presence := 0.0
var glyphs: MultiMeshInstance3D

var _along := PackedFloat32Array()
var _offsets := PackedFloat32Array()
var _cells: Array[Vector2i] = []
var _span := 0.0
var _flow := 0.0
var _look: ShaderMaterial
## The path's glyph frames, laid once every STEP along it (each glyph a lookup, not a fresh frame every frame); each
## glyph's last fade, sent again only when it changes.
const STEP := 0.005
var _table: Array[Transform3D] = []
var _fades := PackedFloat32Array()
## Whether any camera sees it: off screen its words keep their place along the path but are not laid out again.
var _seen: VisibleOnScreenNotifier3D


func build(points: PackedVector3Array, text: String, atlas: Dictionary, colour: Color, loops := false) -> void:
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	global_transform = Transform3D.IDENTITY
	loop = loops
	path = points
	_along = PackedFloat32Array([0.0])
	for i in range(1, path.size()):
		_along.append(_along[i - 1] + path[i].distance_to(path[i - 1]))
	length = _along[_along.size() - 1] if not _along.is_empty() else 0.0
	_tabulate()

	_look = ShaderMaterial.new()
	_look.shader = SHADER
	_look.set_shader_parameter("core", colour.lerp(Color.WHITE, 0.35))
	_look.set_shader_parameter("rim", colour.darkened(0.88))
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.material = _look
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_custom_data = true
	multi.mesh = quad
	glyphs = MultiMeshInstance3D.new()
	glyphs.name = "glyphs"
	glyphs.multimesh = multi
	glyphs.layers = Layers.FX
	glyphs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glyphs)
	_seen = VisibleOnScreenNotifier3D.new()
	_seen.name = "seen"
	glyphs.add_child(_seen)
	set_text(text, atlas)


## Already under way: the words as far along as `along` of the path, as if they had been flowing all along (a wave
## the player walks in on); 0 leaves it empty, its words about to come out (a book just opened).
func run_from(along: float) -> void:
	_flow = along * length
	_lay()


## Its words now `text`, drawn from `atlas`.
func set_text(text: String, atlas: Dictionary) -> void:
	_cells.clear()
	_offsets.clear()
	var at := 0.0
	for ch in text:
		if ch == " ":
			at += gap * size
			continue
		_cells.append(Glyphs.cell_of(atlas, ch))
		var run := Glyphs.advance_of(atlas, ch) * size
		_offsets.append(at + run * 0.5)
		at += run + size * 0.08
	_span = at
	count = _cells.size()
	if atlas.has("texture"):
		_look.set_shader_parameter("atlas", atlas["texture"])
		_look.set_shader_parameter("grid", Vector2(atlas["cols"], atlas["rows"]))
	var multi := glyphs.multimesh
	multi.instance_count = count
	_fades = PackedFloat32Array()
	_fades.resize(count)
	_fades.fill(-1.0)
	multi.visible_instance_count = count if length > 0.01 else 0
	glyphs.custom_aabb = _bounds()
	_seen.aabb = glyphs.custom_aabb
	_lay()


## How long its text is laid along the path (m).
func text_length() -> float:
	return _span


func set_presence(value: float) -> void:
	presence = value
	visible = value > 0.001
	_look.set_shader_parameter("presence", value)


## Where glyph `i` is along its run now (m; for an open chain its run starts `_span` before the path, where its words
## wait to come out). The first character leads, so the words read along the way they go.
func arc_of(i: int) -> float:
	var s := _span - _offsets[i] + _flow
	return fposmod(s, length) if loop else fposmod(s, _cycle())


func _process(delta: float) -> void:
	if not visible or count == 0 or length <= 0.01:
		return
	_flow += speed * delta
	if _seen.is_on_screen():
		_lay()


## An open chain's words run their span past its end before they come round again.
func _cycle() -> float:
	return length + _span + fade


func _lay() -> void:
	placed.clear()
	if count == 0 or length <= 0.01:
		return
	var multi := glyphs.multimesh
	for i in count:
		var s := arc_of(i)
		var here := 1.0
		if not loop:
			# (Out of the start, gone at the end: fading in and out over `fade`, hidden past the end.)
			s -= _span
			here = smoothstep(0.0, fade, s) * (1.0 - smoothstep(length - fade, length, s))
		var frame: Transform3D = _table[clampi(int(clampf(s, 0.0, length) / STEP), 0, _table.size() - 1)]
		if here <= 0.0:
			frame = Transform3D(frame.basis * 0.0001, frame.origin)
		multi.set_instance_transform(i, frame)
		if _fades[i] != here:
			_fades[i] = here
			multi.set_instance_custom_data(i, Color(_cells[i].x, _cells[i].y, here, float(i) * 0.137))
		placed.append(frame.origin)


## A glyph's frame every STEP along the path: upright on the path's line, turned along it, `size` large.
func _tabulate() -> void:
	_table.clear()
	if length <= 0.01:
		return
	for k in int(ceil(length / STEP)) + 1:
		var s := minf(k * STEP, length)
		var ahead := (_point(minf(s + 0.01, length)) - _point(maxf(s - 0.01, 0.0))).normalized()
		if ahead.length() < 0.5:
			ahead = Vector3.RIGHT
		var up := (Vector3.UP - ahead * ahead.dot(Vector3.UP))
		up = up.normalized() if up.length() > 0.05 else Vector3.BACK
		var facing := ahead.cross(up).normalized()
		var toward := face - ahead * ahead.dot(face)
		if toward.length() > 0.05:
			facing = toward.normalized()
			up = facing.cross(ahead).normalized()
		_table.append(Transform3D(Basis(ahead, up, facing).scaled(Vector3.ONE * size), _point(s)))


## The point `s` along the path.
func _point(s: float) -> Vector3:
	var i := _along.bsearch(s)
	if i <= 0:
		return path[0]
	if i >= _along.size():
		return path[path.size() - 1]
	var seg := _along[i] - _along[i - 1]
	return path[i - 1].lerp(path[i], (s - _along[i - 1]) / seg if seg > 0.0 else 0.0)


func _bounds() -> AABB:
	if path.is_empty():
		return AABB()
	var box := AABB(path[0], Vector3.ZERO)
	for p in path:
		box = box.expand(p)
	return box.grow(size)
