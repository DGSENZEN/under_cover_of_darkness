extends CanvasLayer
## What the viewer of the NPC showcase reads, over the picture:
##   subtitles   what the men say (their barks, their gossip), over the
##               speaker's head, with his name: only men in view and near, at
##               most three at once, each fading after a few seconds.
##   marks       over a man whose mind changes, for a moment: "?" suspicious,
##               an eye looking (investigating, searching), "!" when he sees
##               the intruder; a white flag while he begs.
##   titles      a card as each act begins; a name card while the camera
##               follows a man; a word when the ending or the speed changes.
## H hides all of it, for clean footage. Timed on real time
## (TimeFx.real_time), like the camera.

const TimeFx := preload("res://scripts/Visual/TimeFx.gd")

## Guard.Alert.
const SUSPICIOUS := 1
const INVESTIGATING := 2
const SEARCHING := 3
const COMBAT := 4
## Subtitles: how long, the fade at the end, how many, how far off a speaker
## is heard, how high over his head, the text size.
const SAY_FOR := 3.5
const SAY_FADE := 0.5
const SAY_MAX := 3
const SAY_RANGE := 30.0
const SAY_ABOVE := 0.55
const SAY_SIZE := 15
## Marks: how long, and how high over his head.
const MARK_FOR := 2.0
const MARK_ABOVE := 1.05
## A title's fade in, hold and fade out (s); a toast's length.
const TITLE_IN := 0.6
const TITLE_HOLD := 2.5
const TITLE_OUT := 0.8
const TOAST_FOR := 1.8
## Kept this far inside the screen's edge (px).
const MARGIN := 12.0
## The plea activities (GuardMercy, as the rig shows them).
const PLEAS := [&"kneel", &"plead_kneel", &"plead_stand"]

var map: Node3D = null

var _clock := 0.0
var _last := -1.0
## [{man, text, at}]; man -> {"glyph", "at"}.
var _said: Array = []
var _marks := {}
var _roles := {}
var _shown_subtitles: Array = []
var _shown_marks: Array = []
var _canvas: Control
var _title: Label
var _title_at := -100.0
var _card: Label
var _toast: Label
var _toast_at := -100.0


func _init() -> void:
	name = "ShowOverlay"
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_canvas)
	add_child(_canvas)
	_title = _label(38, HORIZONTAL_ALIGNMENT_CENTER)
	_title.set_anchors_preset(Control.PRESET_CENTER)
	_title.modulate.a = 0.0
	_card = _label(18, HORIZONTAL_ALIGNMENT_LEFT)
	_card.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_card.position = Vector2(24, -56)
	_toast = _label(16, HORIZONTAL_ALIGNMENT_RIGHT)
	_toast.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_toast.modulate.a = 0.0


## Every man of the showcase: what he says, and when his mind changes.
func setup(p_map: Node3D) -> void:
	map = p_map

	for name in map.cast:
		watch(map.cast[name], String(map.roles.get(name, "")))


func watch(man: Node3D, role: String) -> void:
	_roles[man] = role
	man.barked.connect(_on_barked.bind(man))
	man.alert_changed.connect(_on_alert_changed.bind(man))


## An act's card.
func title(text: String) -> void:
	_title.text = text
	_title_at = _clock
	_title.reset_size()
	_title.position = -_title.size * 0.5


## Who the camera follows ("Aldous, lookout"), or none (null).
func name_card(man: Node3D) -> void:
	if man == null or not is_instance_valid(man):
		_card.text = ""
		return

	var role: String = _roles.get(man, "")
	_card.text = "%s, %s" % [man.given_name, role] if role != "" else String(man.given_name)


## A word for a moment: the ending chosen, the speed.
func toast(text: String) -> void:
	_toast.text = text
	_toast_at = _clock
	_toast.reset_size()
	_toast.position = Vector2(-_toast.size.x - 24.0, 20.0)


## The subtitles on screen this frame ("Name: line"), and the marks
## ([man, glyph]); empty while hidden.
func shown_subtitles() -> Array:
	return _shown_subtitles.duplicate() if visible else []


func shown_marks() -> Array:
	return _shown_marks.duplicate() if visible else []


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == KEY_H:
		visible = not visible
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# Every frame
# ---------------------------------------------------------------------------

func _process(_delta: float) -> void:
	var now := TimeFx.real_time()
	_clock += clampf(now - _last, 0.0, 0.1) if _last >= 0.0 else 0.0
	_last = now

	_said = _said.filter(func(s): return is_instance_valid(s["man"]) and _clock - float(s["at"]) < SAY_FOR + SAY_FADE)

	for man in _marks.keys():
		if not is_instance_valid(man) or _clock - float(_marks[man]["at"]) >= MARK_FOR:
			_marks.erase(man)

	_update_shown()
	_fade(_title, _title_at, TITLE_IN, TITLE_HOLD, TITLE_OUT)
	_fade(_toast, _toast_at, 0.15, TOAST_FOR, 0.4)
	_canvas.queue_redraw()


func _update_shown() -> void:
	_shown_subtitles.clear()
	_shown_marks.clear()
	var camera := get_viewport().get_camera_3d()

	if camera == null:
		return

	# The newest few, of men in view and near.
	var count := 0

	for i in range(_said.size() - 1, -1, -1):
		var entry: Dictionary = _said[i]

		if count >= SAY_MAX:
			break

		if _in_view(camera, entry["man"], SAY_ABOVE):
			_shown_subtitles.append("%s: %s" % [(entry["man"] as Node3D).given_name, entry["text"]])
			count += 1

	for man in _marks:
		if _in_view(camera, man, MARK_ABOVE):
			_shown_marks.append([man, _marks[man]["glyph"]])

	# Begging: the white flag, for as long as he does.
	if map != null:
		for name in map.cast:
			var man: Variant = map.cast[name]

			if man != null and is_instance_valid(man) and StringName((man as Node).activity()) in PLEAS and _in_view(camera, man, MARK_ABOVE):
				_shown_marks.append([man, "flag"])


func _in_view(camera: Camera3D, man: Node3D, above: float) -> bool:
	if not is_instance_valid(man):
		return false

	var head := _head(man, above)

	if camera.is_position_behind(head) or camera.global_position.distance_to(head) > SAY_RANGE:
		return false

	var at := camera.unproject_position(head)
	var size := get_viewport().get_visible_rect().size
	return at.x >= 0.0 and at.y >= 0.0 and at.x <= size.x and at.y <= size.y


func _head(man: Node3D, above: float) -> Vector3:
	var rig: Variant = man.get("_rig")
	var size: float = float(rig.get("size")) if rig != null and rig.get("size") != null else 1.0
	return man.global_position + Vector3.UP * (1.75 * size + above)


# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------

func _draw_canvas() -> void:
	var camera := get_viewport().get_camera_3d()

	if camera == null:
		return

	var font := ThemeDB.fallback_font
	var size := get_viewport().get_visible_rect().size
	var stacked := {}

	for i in range(_said.size() - 1, -1, -1):
		var entry: Dictionary = _said[i]
		var man: Node3D = entry["man"]
		var line := "%s: %s" % [man.given_name, entry["text"]]

		if not (line in _shown_subtitles):
			continue

		var age := _clock - float(entry["at"])
		var alpha := clampf(1.0 - (age - SAY_FOR) / SAY_FADE, 0.0, 1.0)
		var at := camera.unproject_position(_head(man, SAY_ABOVE))
		# Lines of one man stack upwards.
		var row: int = stacked.get(man, 0)
		stacked[man] = row + 1
		var width := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, SAY_SIZE).x
		var spot := Vector2(clampf(at.x - width * 0.5, MARGIN, size.x - width - MARGIN), clampf(at.y - row * (SAY_SIZE + 4), MARGIN + SAY_SIZE, size.y - MARGIN))
		font.draw_string_outline(_canvas.get_canvas_item(), spot, line, HORIZONTAL_ALIGNMENT_LEFT, -1, SAY_SIZE, 5, Color(0, 0, 0, 0.85 * alpha))
		font.draw_string(_canvas.get_canvas_item(), spot, line, HORIZONTAL_ALIGNMENT_LEFT, -1, SAY_SIZE, Color(0.96, 0.92, 0.82, alpha))

	for mark in _shown_marks:
		var man: Node3D = mark[0]
		var at := camera.unproject_position(_head(man, MARK_ABOVE))
		var age := _clock - float(_marks.get(man, {"at": _clock})["at"])
		var alpha := clampf(1.0 - (age - MARK_FOR + 0.4) / 0.4, 0.0, 1.0) if mark[1] != "flag" else 1.0
		_draw_mark(font, at, mark[1], alpha)


func _draw_mark(font: Font, at: Vector2, glyph: String, alpha: float) -> void:
	var ink := Color(0.98, 0.95, 0.88, alpha)
	var shade := Color(0, 0, 0, 0.8 * alpha)

	match glyph:
		"?", "!":
			var colour := Color(1.0, 0.85, 0.3, alpha) if glyph == "?" else Color(1.0, 0.35, 0.25, alpha)
			var spot := at + Vector2(-6, 0)
			font.draw_string_outline(_canvas.get_canvas_item(), spot, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, 6, shade)
			font.draw_string(_canvas.get_canvas_item(), spot, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, colour)
		"eye":
			var colour := Color(1.0, 0.65, 0.3, alpha)
			var lid := PackedVector2Array()

			for i in 17:
				var a := PI * float(i) / 16.0
				lid.append(at + Vector2(cos(a) * 11.0, -sin(a) * 6.0 - 8.0))

			for i in 17:
				var a := PI * float(i) / 16.0
				lid.append(at + Vector2(-cos(a) * 11.0, sin(a) * 6.0 - 8.0))

			_canvas.draw_polyline(lid, shade, 4.0)
			_canvas.draw_polyline(lid, colour, 2.0)
			_canvas.draw_circle(at + Vector2(0, -8), 3.2, colour)
		"flag":
			_canvas.draw_line(at + Vector2(-6, 2), at + Vector2(-6, -24), shade, 4.0)
			_canvas.draw_line(at + Vector2(-6, 2), at + Vector2(-6, -24), Color(0.55, 0.4, 0.25, alpha), 2.0)
			var cloth := PackedVector2Array([at + Vector2(-5, -24), at + Vector2(10, -21), at + Vector2(-5, -15)])
			_canvas.draw_colored_polygon(cloth, ink)


# ---------------------------------------------------------------------------
# Heard and seen
# ---------------------------------------------------------------------------

func _on_barked(text: String, man: Node3D) -> void:
	if text.strip_edges() == "":
		return

	_said.append({"man": man, "text": text, "at": _clock})


func _on_alert_changed(new_state: int, _old_state: int, man: Node3D) -> void:
	var glyph := ""

	match new_state:
		SUSPICIOUS:
			glyph = "?"
		INVESTIGATING, SEARCHING:
			glyph = "eye"
		COMBAT:
			glyph = "!"

	if glyph == "":
		_marks.erase(man)
	else:
		_marks[man] = {"glyph": glyph, "at": _clock}


func _fade(label: Label, at: float, fade_in: float, hold: float, fade_out: float) -> void:
	var age := _clock - at
	var alpha := 0.0

	if age < fade_in:
		alpha = age / fade_in
	elif age < fade_in + hold:
		alpha = 1.0
	elif age < fade_in + hold + fade_out:
		alpha = 1.0 - (age - fade_in - hold) / fade_out

	label.modulate.a = clampf(alpha, 0.0, 1.0)


func _label(size: int, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.horizontal_alignment = align
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", Color(0.96, 0.92, 0.82))
	label.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override(&"outline_size", 8)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label
