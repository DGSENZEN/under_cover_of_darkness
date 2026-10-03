extends CanvasLayer
## A loading screen over everything while a map makes itself: a title and
## a line for what is being done (the map's own words; empty, nothing is
## shown), and a thin amber rule filling as it goes, creeping on its own
## through a long wait (a navmesh baking away from the main thread); it fades
## out when the map is ready. In the HUD's ink and serif.
##
##   var screen := LoadingScreen.open(self, "The city on the rock")
##   await screen.step("Laying out the harbour", 0.1)   # drawn before you go on
##   ... (a blocking load)
##   screen.creep_to(0.9)                               # through a long wait
##   await baker.baked
##   screen.close()

const StealthHUD := preload("res://scripts/UI/StealthHUD.gd")

const INK := Color(0.93, 0.88, 0.78)
const DIM := Color(0.62, 0.58, 0.5)
const AMBER := Color(1.0, 0.78, 0.36)
const BACKDROP := Color(0.012, 0.014, 0.02)
## The rule's width (px) and thickness.
const RULE := Vector2(420.0, 3.0)
## How fast the rule eases to where it is told (per second), and creeps
## through a wait (fraction per second, slowing as it nears its mark).
const EASE := 6.0
const CREEP := 0.06
## How long the ellipsis takes a dot (s); how long it fades away (s).
const DOT := 0.35

## Whether a tally shown waits for the player (hold); tests that travel
## turn it off.
static var holds := true

## The player pressed on (hold).
signal go_on

var fraction := 0.0
## The tally shown (show_tally): its district's name and its rows.
var tally_title := ""
var tally_rows: Array = []
var _holding := false
var _column: VBoxContainer
var _font: Font
var _shown := 0.0
var _creep_to := -1.0
var _clock := 0.0
var _text := ""
var _root: Control
var _title: Label
var _status: Label
var _fill: ColorRect


## A loading screen on `parent` (shown at once) for `title`.
static func open(parent: Node, title: String) -> CanvasLayer:
	var screen: CanvasLayer = (load("res://scripts/UI/LoadingScreen.gd") as GDScript).new()
	screen.name = "LoadingScreen"
	parent.add_child(screen)
	screen.call(&"_build", title)
	return screen


## Now doing `text`, `to` of the way through: drawn before it returns (await
## it before a step that holds the main thread).
func step(text: String, to: float) -> void:
	_text = text
	fraction = maxf(fraction, clampf(to, 0.0, 1.0))
	_creep_to = -1.0
	_status.text = text

	if is_inside_tree():
		await get_tree().process_frame
		await get_tree().process_frame


## Through a wait of unknown length: the rule creeps toward `to`, slower as it
## nears it, until the next step.
func creep_to(to: float) -> void:
	_creep_to = clampf(to, fraction, 1.0)


## Done: full, then faded out and gone.
func close(seconds := 0.6) -> void:
	fraction = 1.0
	_creep_to = -1.0
	_status.text = ""
	var tween := create_tween()
	tween.tween_property(_root, "modulate:a", 0.0, seconds).set_delay(0.15)
	tween.tween_callback(queue_free)


## Under the rule, the district just left and what was done there
## ([[label, value]], JobState.tally_rows).
func show_tally(title: String, rows: Array) -> void:
	tally_title = title
	tally_rows = rows.duplicate(true)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 10)
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_label(title, _font, 26, INK))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 28)
	grid.add_theme_constant_override(&"v_separation", 4)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	for row in rows:
		var name := _label(String(row[0]), _font, 20, DIM)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(name)
		var value := _label(String(row[1]), _font, 20, INK)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		grid.add_child(value)

	box.add_child(grid)
	_column.add_child(box)


## Ready: the world held still (paused) until the player presses on.
func hold() -> void:
	if not holds or not is_inside_tree():
		return

	_text = ""
	_status.text = "[%s] Go on" % StealthHUD.key_name(&"frob")
	_holding = true
	get_tree().paused = true
	await go_on
	get_tree().paused = false


## Gone while holding: the world let go, not left paused for good.
func _exit_tree() -> void:
	if _holding and is_inside_tree():
		_holding = false
		get_tree().paused = false


func _build(title: String) -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Palatino", "Palatino Linotype", "Book Antiqua", "Georgia", "Times New Roman", "serif"])
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var backdrop := ColorRect.new()
	backdrop.color = BACKDROP
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(backdrop)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override(&"separation", 18)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	_root.add_child(column)
	_column = column
	_font = font
	_title = _label(title, font, 46, INK)
	column.add_child(_title)
	var rule := Control.new()
	rule.custom_minimum_size = RULE
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(rule)
	var groove := ColorRect.new()
	groove.color = Color(DIM, 0.25)
	groove.size = RULE
	rule.add_child(groove)
	_fill = ColorRect.new()
	_fill.color = AMBER
	_fill.size = Vector2(0.0, RULE.y)
	rule.add_child(_fill)
	_status = _label("", font, 22, DIM)
	column.add_child(_status)


func _label(text: String, font: Font, size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override(&"font", font)
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", colour)
	return label


func _process(delta: float) -> void:
	_clock += delta

	if _holding:
		# (Still: nothing under the screen moves until the player goes on, not
		# even resumed by the pause screen's Esc.)
		if not get_tree().paused:
			get_tree().paused = true

		if Input.is_action_just_pressed(&"frob"):
			_holding = false
			go_on.emit()

	if _creep_to > fraction:
		fraction = minf(_creep_to, fraction + (_creep_to - fraction) * CREEP * delta * 10.0)

	_shown = lerpf(_shown, fraction, clampf(EASE * delta, 0.0, 1.0))

	if _fill != null:
		_fill.size.x = RULE.x * _shown

	if _status != null and _text != "":
		_status.text = _text + ".".repeat(int(_clock / DOT) % 4)

	if _title != null:
		_title.visible = _title.text != ""
