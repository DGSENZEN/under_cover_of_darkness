class_name PauseMenu
extends Control
## The game paused: the user's painting (or, without it, the frozen game
## dimmed) behind the main menu's title and word column: Resume, Settings,
## Main menu, Quit. Settings opens the settings book; Main menu and Quit ask
## first. Escape folds back one step at a time, then resumes. The HUD shows
## it while the player has paused the game (StealthHUD).
const DESIGN := Vector2(1600, 900)
## The painting behind the paused game; the frozen frame dimmed until it exists.
const BACKDROP := "res://assets/ui/main_menu/pause.webp"
const NAMES := ["Resume", "Settings", "Main menu", "Quit"]
const QUESTIONS := {2: "Main menu?", 3: "Quit?"}
const MAIN_MENU := "res://main_menu.tscn"
const ArtLoading := preload("res://scripts/UI/ArtLoadingScreen.gd")
const INK := Color("f4e6cc")
const GOLD := Color("d9b46a")

## Resume was chosen (or Escape with nothing open): the HUD unpauses.
signal resume_requested

var words: Array[MenuWord] = []
var selected := -1
var settings_open := false
## The word whose confirm is open (2 Main menu, 3 Quit), or -1.
var asking := -1
var settings: SettingsPage
var confirm_yes: MenuWord
var confirm_no: MenuWord
## What Yes does on Quit, and on Main menu (tests replace them).
var quit_game: Callable
var leave_to_menu: Callable
var _design: Control
var _backdrop: TextureRect
var _veil: Control
var _settings_panel: Control
var _confirm: Control
var _question: Label
var _pressing := false

func _ready() -> void:
	name = "PauseMenu"
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	quit_game = func(): get_tree().quit()
	leave_to_menu = _leave_to_menu
	_build_backdrop()
	_design = Control.new()
	_design.size = DESIGN
	_design.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_design)
	_title("UNDER COVER", Vector2(72, 104))
	_title("OF DARKNESS", Vector2(72, 166))
	_design.add_child(_hairline(Vector2(74, 238), Vector2(230, 1.5)))
	for i in range(NAMES.size()):
		var word := MenuWord.new()
		word.configure(NAMES[i], 10 + i, MainMenu.COLOURS[i])
		word.position = Vector2(MainMenu.WORD_X, MainMenu.WORD_TOP + i * MainMenu.WORD_GAP - 26)
		word.size = Vector2(420, 52)
		word.chosen.connect(func(_index): select(i))
		word.pressed.connect(_activate.bind(i))
		_design.add_child(word)
		words.append(word)
	for i in range(words.size()):
		words[i].focus_neighbor_top = words[maxi(i - 1, 0)].get_path()
		words[i].focus_neighbor_bottom = words[mini(i + 1, words.size() - 1)].get_path()
		words[i].focus_neighbor_left = words[i].get_path()
		words[i].focus_neighbor_right = words[i].get_path()
	_build_settings()
	_build_confirm()
	get_viewport().size_changed.connect(_layout)
	_layout()
	hide()

## Shown while paused, hidden when not; opening starts on Resume.
func set_open(on: bool) -> void:
	if on == visible:
		return
	visible = on
	if on:
		close_settings(false)
		close_confirm(false)
		selected = -1
		for word in words:
			word.set_selected(false)
		select(0)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		settings.end_capture()

## Escape: a confirm or the settings fold back first; then it resumes.
func back() -> void:
	if settings.capturing != null:
		return
	if asking >= 0:
		close_confirm()
	elif settings_open:
		close_settings()
	else:
		resume_requested.emit()

func select(index: int) -> void:
	if index == selected or index < 0 or index >= words.size() or settings_open or asking >= 0:
		return
	selected = index
	for word in words:
		word.set_selected(word == words[index])
	if not words[index].has_focus():
		words[index].grab_focus()

## The word column's rectangle on the screen (the HUD's layout checks).
func menu_rect() -> Rect2:
	var top := words[0].get_global_rect()
	return top.merge(words[-1].get_global_rect())

func _activate(index: int) -> void:
	if _pressing or settings_open or asking >= 0:
		return
	_pressing = true
	words[index].press_in()
	await get_tree().create_timer(MenuMotion.PRESS, true, false, true).timeout
	_pressing = false
	if not visible:
		return
	match index:
		0:
			resume_requested.emit()
		1:
			open_settings()
		_:
			open_confirm(index)

func open_settings() -> void:
	settings_open = true
	for word in words:
		word.focus_mode = Control.FOCUS_NONE
		word.mouse_filter = Control.MOUSE_FILTER_IGNORE
		word.set_page_dim(word != words[1])
	settings.refresh_all()
	settings.paint(MainMenu.COLOURS[2])
	_settings_panel.show()
	_settings_panel.modulate.a = 0.0
	MenuMotion.tween(_settings_panel).tween_property(_settings_panel, "modulate:a", 1.0, MenuMotion.ANSWER)
	settings.focus_first()

func close_settings(focus := true) -> void:
	settings.end_capture()
	settings_open = false
	_settings_panel.hide()
	_restore_words()
	if focus and visible:
		words[1].grab_focus()

func open_confirm(index: int) -> void:
	asking = index
	_question.text = QUESTIONS[index]
	_confirm.position = words[index].position + Vector2(230, 0)
	for word in words:
		word.focus_mode = Control.FOCUS_NONE
		word.mouse_filter = Control.MOUSE_FILTER_IGNORE
		word.set_page_dim(word != words[index])
	_confirm.show()
	_confirm.modulate.a = 0.0
	MenuMotion.tween(_confirm).tween_property(_confirm, "modulate:a", 1.0, MenuMotion.ANSWER)
	confirm_no.grab_focus()

func close_confirm(focus := true) -> void:
	var was := asking
	asking = -1
	_confirm.hide()
	_restore_words()
	if focus and visible and was >= 0:
		words[was].grab_focus()

func _restore_words() -> void:
	for word in words:
		word.focus_mode = Control.FOCUS_ALL
		word.mouse_filter = Control.MOUSE_FILTER_STOP
		word.set_selected(words.find(word) == selected)

func _confirmed() -> void:
	var index := asking
	if index < 0:
		return
	confirm_yes.press_in()
	await get_tree().create_timer(MenuMotion.PRESS, true, false, true).timeout
	if asking != index:
		return
	if index == 3:
		quit_game.call()
	else:
		leave_to_menu.call()

## Out of the game to the title, through the loading cover.
func _leave_to_menu() -> void:
	set_open(false)
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var cover := ArtLoading.open(get_tree())
	cover.fade_in(0.25)
	await cover.change_to(MAIN_MENU)

func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	var factor := minf(view.x / DESIGN.x, view.y / DESIGN.y)
	_design.scale = Vector2.ONE * factor
	_design.position = (view - DESIGN * factor) * 0.5

# Building

func _build_backdrop() -> void:
	_backdrop = TextureRect.new()
	_backdrop.name = "Backdrop"
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(BACKDROP):
		_backdrop.texture = load(BACKDROP)
	add_child(_backdrop)
	# Over it, a veil darkest at the left where the words are (over the frozen
	# game, without a painting, a deeper one).
	var shade := Gradient.new()
	var deep := 0.86 if _backdrop.texture == null else 0.7
	shade.colors = PackedColorArray([Color(0.01, 0.02, 0.03, deep), Color(0.01, 0.02, 0.03, deep * 0.35 if _backdrop.texture else deep * 0.75)])
	var wash := GradientTexture2D.new()
	wash.gradient = shade
	wash.fill_from = Vector2(0.0, 0.5)
	wash.fill_to = Vector2(0.8, 0.5)
	var veil := TextureRect.new()
	veil.name = "Veil"
	veil.texture = wash
	veil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	_veil = veil

func _title(words_text: String, at: Vector2) -> void:
	var label := Label.new()
	label.text = words_text
	label.position = at
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var spaced := FontVariation.new()
	spaced.base_font = MenuType.title()
	spaced.spacing_glyph = 18
	label.add_theme_font_override("font", spaced)
	label.add_theme_font_size_override("font_size", 56)
	label.add_theme_color_override("font_color", INK)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	label.add_theme_constant_override("shadow_outline_size", 8)
	_design.add_child(label)

func _hairline(at: Vector2, line_size: Vector2) -> TextureRect:
	var fade := Gradient.new()
	fade.colors = PackedColorArray([GOLD, Color(GOLD, 0.0)])
	var rule := GradientTexture2D.new()
	rule.gradient = fade
	rule.width = 256
	rule.height = 1
	var hairline := TextureRect.new()
	hairline.name = "Hairline"
	hairline.texture = rule
	hairline.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hairline.position = at
	hairline.size = line_size
	hairline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return hairline

## The settings book, as on the main menu's Settings page: a heading, its
## hairline, the book under a deeper wash, and Back.
func _build_settings() -> void:
	_settings_panel = Control.new()
	_settings_panel.name = "Settings"
	_settings_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settings_panel.size = DESIGN
	_design.add_child(_settings_panel)
	var deep := Gradient.new()
	deep.colors = PackedColorArray([Color(0.01, 0.02, 0.03, 0.86), Color(0.01, 0.02, 0.03, 0.7), Color(0.01, 0.02, 0.03, 0.0)])
	deep.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	var round_wash := GradientTexture2D.new()
	round_wash.gradient = deep
	round_wash.fill = GradientTexture2D.FILL_RADIAL
	round_wash.fill_from = Vector2(0.5, 0.5)
	round_wash.fill_to = Vector2(1.0, 0.5)
	var scrim := TextureRect.new()
	scrim.texture = round_wash
	scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scrim.position = Vector2(560, 20)
	scrim.size = Vector2(1000, 860)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settings_panel.add_child(scrim)
	var column := VBoxContainer.new()
	column.position = Vector2(620, MenuPages.SETTINGS_TOP)
	column.add_theme_constant_override("separation", 22)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settings_panel.add_child(column)
	var heading := Label.new()
	heading.text = "Settings"
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_theme_font_override("font", MenuType.choice())
	heading.add_theme_font_size_override("font_size", 52)
	heading.add_theme_color_override("font_color", INK)
	heading.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	heading.add_theme_constant_override("shadow_offset_y", 2)
	column.add_child(heading)
	var hairline := _hairline(Vector2.ZERO, Vector2(220, 1.5))
	hairline.custom_minimum_size = Vector2(220, 1.5)
	hairline.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(hairline)
	settings = SettingsPage.new()
	column.add_child(settings)
	settings.build()
	var back_word := MenuWord.new()
	back_word.configure("Back", -1, INK)
	back_word.custom_minimum_size = Vector2(240, 52)
	back_word.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back_word.focus_entered.connect(func(): back_word.set_selected(true))
	back_word.focus_exited.connect(func(): back_word.set_selected(false))
	back_word.mouse_entered.connect(back_word.grab_focus)
	back_word.pressed.connect(close_settings)
	column.add_child(back_word)
	_settings_panel.hide()

## "Main menu?" or "Quit?" beside its word, in the book's style: No is
## ready, Yes leaves.
func _build_confirm() -> void:
	_confirm = Control.new()
	_confirm.name = "Confirm"
	_confirm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_design.add_child(_confirm)
	var shade := Gradient.new()
	shade.colors = PackedColorArray([Color(0.01, 0.02, 0.03, 0.75), Color(0.01, 0.02, 0.03, 0.0)])
	var soft := GradientTexture2D.new()
	soft.gradient = shade
	soft.fill = GradientTexture2D.FILL_RADIAL
	soft.fill_from = Vector2(0.5, 0.5)
	soft.fill_to = Vector2(1.0, 0.5)
	var scrim := TextureRect.new()
	scrim.texture = soft
	scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scrim.position = Vector2(-60, -40)
	scrim.size = Vector2(560, 130)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm.add_child(scrim)
	_question = Label.new()
	_question.add_theme_font_override("font", MenuType.body_italic())
	_question.add_theme_font_size_override("font_size", 34)
	_question.add_theme_color_override("font_color", GOLD)
	_question.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm.add_child(_question)
	confirm_yes = MenuWord.new()
	confirm_yes.configure("Yes", -1, GOLD)
	confirm_yes.position = Vector2(180, -2)
	confirm_yes.size = Vector2(110, 52)
	confirm_no = MenuWord.new()
	confirm_no.configure("No", -1, GOLD)
	confirm_no.position = Vector2(300, -2)
	confirm_no.size = Vector2(110, 52)
	for answer in [confirm_yes, confirm_no]:
		_confirm.add_child(answer)
		answer.focus_entered.connect(func(): confirm_yes.set_selected(answer == confirm_yes); confirm_no.set_selected(answer == confirm_no))
		answer.mouse_entered.connect(answer.grab_focus)
	confirm_yes.focus_neighbor_right = confirm_no.get_path()
	confirm_no.focus_neighbor_left = confirm_yes.get_path()
	for edge in ["focus_neighbor_top", "focus_neighbor_bottom"]:
		confirm_yes.set(edge, confirm_yes.get_path())
		confirm_no.set(edge, confirm_no.get_path())
	confirm_yes.pressed.connect(_confirmed)
	confirm_no.pressed.connect(close_confirm)
	_confirm.hide()
