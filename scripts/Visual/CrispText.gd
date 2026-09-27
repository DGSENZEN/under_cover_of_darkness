extends Control
## The words over men's heads, drawn sharp over the retro screen rather than
## through it: its big pixels break small text into blocks. Retro draws this
## just over its grid, under the HUD, while the grid is on.
##
## Any Label3D in the group "crisp_text" (a guard's "Bark", the NPC gym's
## thinking labels) is drawn here in 2D, where it is on the screen: in its
## own font, colour and outline, centred on it; as big as it is in the world
## (a little bigger: BOOST), but never smaller than MIN_PX nor bigger than
## MAX_PX; and faded out where the world would draw it too small to read
## (READ_PX to GONE_PX: a guard's words from about 19 m to 24 m off). It is
## hidden behind anything solid between your eye and it (a ray every
## WALL_EVERY s), unless it shows through walls anyway (no_depth_test).
## While a label is drawn here the 3D one is kept off every render layer, and
## given back its layers when it is not (the grid off: `drawing` false).
##
##   CrispText.top_of(label, camera, view)   the top of its words on the
##                                           screen (the HUD's marks go
##                                           above them)

const GROUP := &"crisp_text"
const BOOST := 1.3
const MIN_PX := 12.0
const MAX_PX := 18.0
const READ_PX := 4.0
const GONE_PX := 3.2
const WALL_EVERY := 0.12
## How fast it fades in and out as a wall comes between (per second).
const FADE := 8.0

## Whether labels are drawn here now (the grid is on).
static var drawing := false

var active := false:
	set(value):
		active = value
		drawing = value

		if not value:
			_release_all()

## Per label (by instance id): {"seen": 0..1, "look_at": s, "walled": bool}.
var _state := {}
## Labels kept off the render layers: instance id -> weakref.
var _held := {}
## Drawn this frame: {"label", "at", "px", "presence", "depth"} each.
var _shown: Array = []
var _clock := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_clock += delta
	_shown.clear()
	queue_redraw()

	if not active:
		return

	var camera := get_viewport().get_camera_3d()
	var view := size if size.x > 1.0 else get_viewport().get_visible_rect().size
	var kept := {}

	for node in get_tree().get_nodes_in_group(GROUP):
		var label := node as Label3D

		if label == null:
			continue

		var id := label.get_instance_id()
		kept[id] = true
		_hold(label)

		if camera == null or not label.is_visible_in_tree() or label.text.strip_edges() == "" or camera.is_position_behind(label.global_position):
			_state.erase(id)
			continue

		if not _state.has(id):
			_state[id] = {"seen": 0.0, "look_at": -1.0, "walled": false}

		var state: Dictionary = _state[id]

		if label.no_depth_test:
			state["walled"] = false
		elif _clock >= float(state["look_at"]):
			state["look_at"] = _clock + WALL_EVERY
			state["walled"] = _walled(camera, label)

		state["seen"] = move_toward(float(state["seen"]), 0.0 if state["walled"] else 1.0, delta * FADE)
		var natural := size_of(label, camera, view)
		var presence := float(state["seen"]) * clampf(inverse_lerp(GONE_PX, READ_PX, natural), 0.0, 1.0)

		if presence * label.modulate.a <= 0.01:
			continue

		var local: Vector3 = camera.global_transform.affine_inverse() * label.global_position
		_shown.append({"label": label, "at": camera.unproject_position(label.global_position), "px": px_for(natural),
			"presence": presence, "depth": -local.z})

	# Out of the group (or gone): its layers back.
	for id in _held.keys():
		if not kept.has(id):
			var label := (_held[id] as WeakRef).get_ref() as Label3D

			if label != null:
				_release(label)

			_held.erase(id)

	for id in _state.keys():
		if not kept.has(id):
			_state.erase(id)


func _draw() -> void:
	# The farthest first, so the nearest is on top.
	_shown.sort_custom(func(a, b): return float(a["depth"]) > float(b["depth"]))

	for entry in _shown:
		var label: Label3D = entry["label"]

		if not is_instance_valid(label):
			continue

		var font := font_of(label)
		var px: int = entry["px"]
		var text := label.text
		var lines := text.count("\n") + 1
		var width := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, px, -1, TextServer.BREAK_MANDATORY).x
		var at: Vector2 = entry["at"]
		var corner := Vector2(at.x - width * 0.5, at.y - font.get_height(px) * lines * 0.5 + font.get_ascent(px))
		var presence: float = entry["presence"]
		var ink := label.modulate
		var edge := label.outline_modulate
		var outline := int(round(float(label.outline_size) * px / float(maxi(label.font_size, 1))))

		if outline > 0:
			draw_multiline_string_outline(font, corner, text, HORIZONTAL_ALIGNMENT_CENTER, width, px, -1, outline,
				Color(edge.r, edge.g, edge.b, edge.a * presence), TextServer.BREAK_MANDATORY)

		draw_multiline_string(font, corner, text, HORIZONTAL_ALIGNMENT_CENTER, width, px, -1,
			Color(ink.r, ink.g, ink.b, ink.a * presence), TextServer.BREAK_MANDATORY)


## What is drawn now (tests): {"label", "at", "px", "presence", "depth"} each.
func shown() -> Array:
	return _shown.duplicate()


## How big `label` would be on the screen in the world (the font size it
## would take, in the HUD's units): its font size times its pixel size, the
## height of a line in metres, over what the view spans at its depth (the
## same at any depth for a fixed-size label).
static func size_of(label: Label3D, camera: Camera3D, view: Vector2) -> float:
	var tall := float(label.font_size) * label.pixel_size

	if camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		return tall * view.y / maxf(camera.size, 0.001)

	var half := tan(deg_to_rad(camera.fov) * 0.5)

	if camera.keep_aspect == Camera3D.KEEP_WIDTH:
		half *= view.y / maxf(view.x, 1.0)

	if label.fixed_size:
		return tall * view.y / (2.0 * half)

	var local: Vector3 = camera.global_transform.affine_inverse() * label.global_position
	return tall * view.y / (2.0 * maxf(-local.z, 0.05) * half)


## The size it is drawn here, for the size it would be in the world.
static func px_for(natural: float) -> int:
	return int(round(clampf(natural * BOOST, MIN_PX, MAX_PX)))


## The top of `label`'s words on the screen, as drawn here (a line of them
## while it says nothing).
static func top_of(label: Label3D, camera: Camera3D, view: Vector2) -> float:
	var px := px_for(size_of(label, camera, view))
	var lines := label.text.count("\n") + 1 if label.text != "" else 1
	return camera.unproject_position(label.global_position).y - font_of(label).get_height(px) * lines * 0.5


static func font_of(label: Label3D) -> Font:
	return label.font if label.font != null else ThemeDB.fallback_font


## Whether something solid (the level, a closed door, a man) stands between
## the eye and `label`, not counting whoever it hangs over or whoever holds
## the camera.
func _walled(camera: Camera3D, label: Label3D) -> bool:
	var exclude: Array[RID] = []

	for end in [label, camera]:
		var body := _body_of(end)

		if body != null:
			exclude.append(body.get_rid())

	var query := PhysicsRayQueryParameters3D.create(camera.global_position, label.global_position, 1, exclude)
	query.collide_with_areas = false
	return not camera.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


static func _body_of(node: Node) -> CollisionObject3D:
	var at := node.get_parent()

	while at != null:
		if at is CollisionObject3D:
			return at as CollisionObject3D

		at = at.get_parent()

	return null


## Off every render layer while it is drawn here.
func _hold(label: Label3D) -> void:
	var id := label.get_instance_id()

	if _held.has(id):
		return

	_held[id] = weakref(label)
	label.set_meta(&"crisp_layers", label.layers)
	label.layers = 0


func _release(label: Label3D) -> void:
	if label.has_meta(&"crisp_layers"):
		label.layers = int(label.get_meta(&"crisp_layers"))
		label.remove_meta(&"crisp_layers")


func _release_all() -> void:
	for id in _held:
		var label := (_held[id] as WeakRef).get_ref() as Label3D

		if label != null:
			_release(label)

	_held.clear()
	_state.clear()
	_shown.clear()
	queue_redraw()
