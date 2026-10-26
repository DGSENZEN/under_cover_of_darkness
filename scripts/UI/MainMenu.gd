extends CanvasLayer
## The title menu: four words in a column; the chosen one is lit.
const Settings := preload("res://scripts/UI/Settings.gd")
const ArtLoading := preload("res://scripts/UI/ArtLoadingScreen.gd")
const CITY := preload("res://assets/ui/main_menu/city.png")
const BUTTONS := preload("res://assets/ui/main_menu/buttons.png")
const LIVING_PAINT := preload("res://scripts/UI/living_paint.gdshader")
const FLOW := preload("res://scripts/UI/paint_flow.tres")
const DESIGN := Vector2(1600, 900)
const INK := Color("f4e6cc")
const LORE := "THE ECLIPSE OF 1923\nMexico City was changed by the Eclipse and the seepage it left behind. The uncanny has a history here.\n\nTHE CITY ABOVE THE LAKE\nThe lakebed sinks. A failed drain brings the canal back into the streets. Colonial rooms carry machinery bolted into them decades later.\n\nTHE ZÓCALO\nThe plaza, cathedral, palace and market form the city's first district. Roofs, canals and underground passages offer different ways through."

## The actual underground station and built candle lane from metro-standard.
@export_file("*.tscn") var game_scene := "res://maps/metro.tscn"
signal selection_changed(index: int)

const NAMES := ["New Game", "Continue", "Settings", "Lore"]
const COLOURS := [Color("ef774c"), Color("67c9ed"), Color("929fdb"), Color("efa25e")]
const WORD_X := 72.0
const WORD_TOP := 360.0
const WORD_GAP := 64.0
var words: Array[MenuWord] = []
var selected := -1
var panel: Control
var panel_title: Label
var panel_body: Label
var settings_box: VBoxContainer
var _root: Control
var _design: Control
var _font: SystemFont
var _return_focus := 0
var _close: Button
var _transitioning := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Palatino", "Palatino Linotype", "Book Antiqua", "Georgia", "serif"])
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var theme := Theme.new()
	theme.default_font = _font
	theme.default_font_size = 23
	_root.theme = theme
	var background := TextureRect.new()
	background.texture = CITY
	var paint_motion := ShaderMaterial.new()
	paint_motion.shader = LIVING_PAINT
	paint_motion.set_shader_parameter("painting", CITY)
	paint_motion.set_shader_parameter("flow_map", FLOW)
	background.material = paint_motion
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(background)
	var veil := TextureRect.new()
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.005, 0.018, 0.024, 0.63), Color(0.005, 0.018, 0.024, 0.05)])
	var wash := GradientTexture2D.new()
	wash.gradient = gradient
	wash.fill_from = Vector2(0, 0.5)
	wash.fill_to = Vector2(0.75, 0.5)
	veil.texture = wash
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(veil)
	_design = Control.new()
	_design.size = DESIGN
	_design.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_design)
	_text("UNDER COVER", Vector2(72, 115), 52)
	_text("OF DARKNESS", Vector2(72, 175), 58)
	for i in range(NAMES.size()):
		var word := MenuWord.new()
		word.configure(NAMES[i], i, COLOURS[i], _font)
		word.position = Vector2(WORD_X, WORD_TOP + i * WORD_GAP - 26)
		word.size = Vector2(420, 52)
		word.chosen.connect(select)
		word.pressed.connect(_activate.bind(i))
		_design.add_child(word)
		words.append(word)
	for i in range(words.size()):
		words[i].focus_neighbor_top = words[maxi(i - 1, 0)].get_path()
		words[i].focus_neighbor_bottom = words[mini(i + 1, words.size() - 1)].get_path()
		words[i].focus_neighbor_left = words[i].get_path()
		words[i].focus_neighbor_right = words[i].get_path()
	_build_panel()
	get_viewport().size_changed.connect(_layout)
	_layout()
	# No automatic focus highlight until keyboard navigation is used.

func _text(words: String, at: Vector2, point_size: int, colour := INK) -> Label:
	var label := Label.new()
	label.text = words
	label.position = at
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", point_size)
	label.add_theme_color_override("font_color", colour)
	_design.add_child(label)
	return label

func _layout() -> void:
	var viewport := get_viewport().get_visible_rect().size
	var factor := minf(viewport.x / DESIGN.x, viewport.y / DESIGN.y)
	_design.scale = Vector2.ONE * factor
	_design.position = (viewport - DESIGN * factor) * 0.5

func _build_panel() -> void:
	panel = Control.new()
	panel.name = "Overlay"
	panel.size = DESIGN
	panel.visible = false
	_design.add_child(panel)
	var shade := ColorRect.new()
	shade.size = DESIGN
	shade.color = Color(0.005, 0.012, 0.02, 0.78)
	panel.add_child(shade)
	var card := PanelContainer.new()
	card.position = Vector2(390, 145)
	card.size = Vector2(820, 610)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101e25")
	style.border_color = Color("866e52")
	style.set_border_width_all(1)
	style.content_margin_left = 42
	style.content_margin_right = 42
	style.content_margin_top = 30
	style.content_margin_bottom = 28
	card.add_theme_stylebox_override("panel", style)
	panel.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 20)
	card.add_child(column)
	panel_title = Label.new()
	panel_title.add_theme_font_size_override("font_size", 40)
	panel_title.add_theme_color_override("font_color", INK)
	column.add_child(panel_title)
	panel_body = Label.new()
	panel_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel_body.add_theme_font_size_override("font_size", 21)
	panel_body.add_theme_color_override("font_color", Color("cec7b9"))
	column.add_child(panel_body)
	settings_box = VBoxContainer.new()
	settings_box.add_theme_constant_override("separation", 20)
	column.add_child(settings_box)
	var volume_text := Label.new()
	volume_text.text = "Master volume"
	settings_box.add_child(volume_text)
	var volume := HSlider.new()
	volume.name = "Volume"
	volume.max_value = 1.0
	volume.step = 0.01
	volume.value = Settings.master_volume()
	volume.custom_minimum_size.y = 36
	volume.value_changed.connect(Settings.set_master_volume)
	settings_box.add_child(volume)
	var marks := CheckButton.new()
	marks.text = "Awareness marks above guards"
	marks.button_pressed = Settings.awareness_marks()
	marks.toggled.connect(Settings.set_awareness_marks)
	settings_box.add_child(marks)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	_close = Button.new()
	_close.text = "Back"
	_close.custom_minimum_size.y = 45
	_close.pressed.connect(close_panel)
	column.add_child(_close)

func _activate(index: int) -> void:
	if _transitioning:
		return
	_return_focus = index
	if index == 0:
		_transitioning = true
		# Draw the click response before beginning the existing game's scene.
		await get_tree().create_timer(0.22).timeout
		var cover := ArtLoading.open(get_tree())
		var error: Error = await cover.change_to(game_scene)
		if error != OK:
			_transitioning = false
			_show_panel("New Game", "The game scene could not be opened. Please try again.")
	elif index == 1:
		_show_panel("Continue", "No saved game is available yet.\n\nThis build does not have a disk-save system. Choose New Game to begin.")
	elif index == 2:
		_show_panel("Settings", "Adjust your sound and awareness cues.")
		settings_box.show()
		settings_box.get_node("Volume").grab_focus()
	else:
		_show_panel("Lore", LORE)

func _show_panel(title: String, body: String) -> void:
	panel_title.text = title
	panel_body.text = body
	settings_box.hide()
	panel.show()
	for word in words:
		word.focus_mode = Control.FOCUS_NONE
		word.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_close.grab_focus()

func close_panel() -> void:
	panel.hide()
	for word in words:
		word.focus_mode = Control.FOCUS_ALL
		word.mouse_filter = Control.MOUSE_FILTER_STOP
	words[_return_focus].grab_focus()

## The one path for mouse, keyboard and controller: lights one word.
func select(index: int) -> void:
	if index == selected or index < 0 or index >= words.size():
		return
	selected = index
	for word in words:
		word.set_selected(word.index == index)
	if not words[index].has_focus() and words[index].focus_mode != Control.FOCUS_NONE:
		words[index].grab_focus()
	selection_changed.emit(index)

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and panel.visible:
		close_panel()
		get_viewport().set_input_as_handled()
	elif not panel.visible and get_viewport().gui_get_focus_owner() == null and (event.is_action_pressed("ui_down") or event.is_action_pressed("ui_up") or event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right") or event.is_action_pressed("ui_accept")):
		words[0].grab_focus()
		get_viewport().set_input_as_handled()
