class_name MainMenu
extends CanvasLayer
## The title menu: four words in a column; the chosen one is lit.
const Settings := preload("res://scripts/UI/Settings.gd")
const ArtLoading := preload("res://scripts/UI/ArtLoadingScreen.gd")
const DESIGN := Vector2(1600, 900)
const INK := Color("f4e6cc")
const LORE := "THE ECLIPSE OF 1923\nMexico City was changed by the Eclipse and the seepage it left behind. The uncanny has a history here.\n\nTHE CITY ABOVE THE LAKE\nThe lakebed sinks. A failed drain brings the canal back into the streets. Colonial rooms carry machinery bolted into them decades later.\n\nTHE ZÓCALO\nThe plaza, cathedral, palace and market form the city's first district. Roofs, canals and underground passages offer different ways through."

## The actual underground station and built candle lane from metro-standard.
@export_file("*.tscn") var game_scene := "res://maps/metro.tscn"
## The menu theme's score (prepared by tools/prepare_menu_score.py).
@export var music_score := MenuMusic.SCORE_JSON
signal selection_changed(index: int)

const NAMES := ["New Game", "Continue", "Settings", "Lore", "Quit"]
const COLOURS := [Color("ef774c"), Color("67c9ed"), Color("929fdb"), Color("efa25e"), Color("b9b0a2")]
const GOLD := Color("d9b46a")
const WORD_X := 72.0
const WORD_TOP := 400.0
const WORD_GAP := 64.0
var words: Array[MenuWord] = []
var band: MenuBand
var background: LivingCity
var _dim := 1.0
var selected := -1
var pages: MenuPages
var music: MenuMusic
var page_open := -1
var _root: Control
var _design: Control
var _font: SystemFont
var _page_turn := 0
## Quit's confirm: open while asking; its two answers.
var confirming := false
var confirm_yes: MenuWord
var confirm_no: MenuWord
var _confirm: Control
## What Yes does (tests replace it).
var quit_game: Callable
var _transitioning := false
var _pressing := false

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
	background = LivingCity.new()
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
	band = MenuBand.new()
	band.name = "Band"
	_design.add_child(band)
	selection_changed.connect(_sound_choice)
	_title("UNDER COVER", Vector2(72, 104))
	_title("OF DARKNESS", Vector2(72, 166))
	# A gold hairline under the title, fading to nothing.
	var fade := Gradient.new()
	fade.colors = PackedColorArray([GOLD, Color(GOLD, 0.0)])
	var hairline_texture := GradientTexture2D.new()
	hairline_texture.gradient = fade
	hairline_texture.width = 256
	hairline_texture.height = 1
	var hairline := TextureRect.new()
	hairline.name = "Hairline"
	hairline.texture = hairline_texture
	hairline.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hairline.position = Vector2(74, 238)
	hairline.size = Vector2(230, 1.5)
	hairline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_design.add_child(hairline)
	# The words' paintings sit on one layer behind all the words.
	var washes := Control.new()
	washes.name = "Washes"
	washes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_design.add_child(washes)
	for i in range(NAMES.size()):
		var word := MenuWord.new()
		word.configure(NAMES[i], i, COLOURS[i])
		word.position = Vector2(WORD_X, WORD_TOP + i * WORD_GAP - 26)
		word.size = Vector2(420, 52)
		word.chosen.connect(select)
		word.pressed.connect(_activate.bind(i))
		_design.add_child(word)
		words.append(word)
		if word.wash:
			washes.add_child(word.wash)
			word.place_wash()
	for i in range(words.size()):
		words[i].focus_neighbor_top = words[maxi(i - 1, 0)].get_path()
		words[i].focus_neighbor_bottom = words[mini(i + 1, words.size() - 1)].get_path()
		words[i].focus_neighbor_left = words[i].get_path()
		words[i].focus_neighbor_right = words[i].get_path()
	pages = MenuPages.new()
	pages.build(_font, LORE)
	pages.back.pressed.connect(close_page)
	_design.add_child(pages)
	_build_confirm()
	quit_game = func(): get_tree().quit()
	_start_music()
	get_viewport().size_changed.connect(_layout)
	_layout()
	# No automatic focus highlight until keyboard navigation is used.

func _title(words: String, at: Vector2) -> Label:
	var label := Label.new()
	label.text = words
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
	return label

func _layout() -> void:
	var viewport := get_viewport().get_visible_rect().size
	var factor := minf(viewport.x / DESIGN.x, viewport.y / DESIGN.y)
	_design.scale = Vector2.ONE * factor
	_design.position = (viewport - DESIGN * factor) * 0.5
	if band:
		band.set_screen(visible_design_rect(viewport))

## The window's visible area in the 1600x900 design space.
static func visible_design_rect(viewport: Vector2) -> Rect2:
	var factor := minf(viewport.x / DESIGN.x, viewport.y / DESIGN.y)
	var offset := (viewport - DESIGN * factor) * 0.5
	return Rect2(-offset / factor, viewport / factor)

## How many words' paintings are drawn (one, or two mid-change).
func washes_showing() -> int:
	return words.filter(func(w): return w.wash != null and w.wash.visible).size()

## The city's brightness: dimmed a little while a painting is showing.
func city_dim() -> float:
	return _dim

func _process(delta: float) -> void:
	_dim = move_toward(_dim, 0.72 if washes_showing() > 0 or band.page else 1.0, delta / 0.5 * 0.28)
	background.dim = _dim
	if is_instance_valid(music):
		background.set_energy(music.layer_energy(&"base"), music.layer_energy(&"low"), music.layer_energy(&"high"), music.layer_energy(&"fx"))

## The theme lives under the root, so it can finish its phrase after the menu.
func _start_music() -> void:
	music = MenuMusic.new()
	music.name = "MenuMusic"
	music.score_json_path = music_score
	get_tree().root.add_child.call_deferred(music)

func _sound_choice(index: int) -> void:
	if is_instance_valid(music):
		music.set_selected(index)
		music.hover(index)
		music.note_input()

func _exit_tree() -> void:
	if is_instance_valid(music) and music.state != MenuMusic.State.STARTING:
		music.queue_free()

func _activate(index: int) -> void:
	if _transitioning or page_open >= 0 or confirming or _pressing:
		return
	# The word dips in first; the action follows it.
	_pressing = true
	words[index].press_in()
	await get_tree().create_timer(MenuMotion.PRESS).timeout
	_pressing = false
	if _transitioning or page_open >= 0:
		return
	if index == 4:
		open_quit_confirm()
		return
	if is_instance_valid(music):
		music.press(index)
	if index == 0:
		_transitioning = true
		# The loading cover opens at once; the song finishes its phrase under it.
		if is_instance_valid(music):
			music.start_game()
		var cover := ArtLoading.open(get_tree())
		var error: Error = await cover.change_to(game_scene)
		if error != OK:
			_transitioning = false
			_start_music()
			open_page(0, "The game scene could not be opened. Please try again.")
	else:
		open_page(index)

## Spreads the choice's band over the right two-thirds and writes its page on it.
func open_page(index: int, message := "") -> void:
	select(index)
	page_open = index
	_page_turn += 1
	var turn := _page_turn
	band.open_page(index)
	for word in words:
		word.focus_mode = Control.FOCUS_NONE
		word.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if word.index != index:
			word.set_page_dim(true)
		# The page's own painting takes over from the words'.
		if word.wash:
			word.wash.fade()
	if is_instance_valid(music) and index > 0:
		music.set_state([MenuMusic.State.BROWSING, MenuMusic.State.CONTINUE, MenuMusic.State.SETTINGS, MenuMusic.State.LORE][index])
	await get_tree().create_timer(MenuMotion.ANSWER).timeout
	if turn == _page_turn and page_open == index:
		pages.show_page(index, NAMES[index], COLOURS[index], message)

## Folds the page back into its word's band.
func close_page() -> void:
	if page_open < 0:
		return
	var index := page_open
	page_open = -1
	_page_turn += 1
	pages.hide_page()
	band.close_page()
	if is_instance_valid(music):
		music.set_state(MenuMusic.State.BROWSING)
	for word in words:
		word.focus_mode = Control.FOCUS_ALL
		word.mouse_filter = Control.MOUSE_FILTER_STOP
		word.set_selected(word.index == index)
	words[index].grab_focus()

## "Quit?" beside the Quit word, in the book's style: No is ready, Yes leaves.
func _build_confirm() -> void:
	_confirm = Control.new()
	_confirm.name = "QuitConfirm"
	_confirm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm.position = words[4].position + Vector2(170, 0)
	_design.add_child(_confirm)
	# A feathered dark wash so the answers read over the lit city.
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
	scrim.size = Vector2(460, 130)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm.add_child(scrim)
	var ask := Label.new()
	ask.text = "Quit?"
	ask.add_theme_font_override("font", MenuType.body_italic())
	ask.add_theme_font_size_override("font_size", 34)
	ask.add_theme_color_override("font_color", GOLD)
	ask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm.add_child(ask)
	confirm_yes = MenuWord.new()
	confirm_yes.configure("Yes", -1, GOLD)
	confirm_yes.position = Vector2(100, -2)
	confirm_yes.size = Vector2(110, 52)
	confirm_no = MenuWord.new()
	confirm_no.configure("No", -1, GOLD)
	confirm_no.position = Vector2(220, -2)
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
	confirm_yes.pressed.connect(func():
		if not confirming:
			return
		confirm_yes.press_in()
		await get_tree().create_timer(MenuMotion.PRESS).timeout
		if not confirming:
			return
		confirming = false
		quit_game.call())
	confirm_no.pressed.connect(close_quit_confirm)
	_confirm.hide()

func open_quit_confirm() -> void:
	confirming = true
	for word in words:
		word.focus_mode = Control.FOCUS_NONE
		word.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if word.index != 4:
			word.set_page_dim(true)
	_confirm.show()
	_confirm.modulate.a = 0.0
	MenuMotion.tween(_confirm).tween_property(_confirm, "modulate:a", 1.0, MenuMotion.ANSWER)
	confirm_no.grab_focus()

func close_quit_confirm() -> void:
	if not confirming:
		return
	confirming = false
	_confirm.hide()
	for word in words:
		word.focus_mode = Control.FOCUS_ALL
		word.mouse_filter = Control.MOUSE_FILTER_STOP
		word.set_selected(word.index == selected)
	words[4].grab_focus()

## The one path for mouse, keyboard and controller: lights one word.
func select(index: int) -> void:
	if index == selected or index < 0 or index >= words.size() or confirming or page_open >= 0:
		return
	var previous := selected
	selected = index
	for word in words:
		word.set_selected(word.index == index)
		# Only the outgoing painting may fade under the incoming one.
		if word.wash and word.index != index and word.index != previous:
			word.wash.clear()
	if not words[index].has_focus() and words[index].focus_mode != Control.FOCUS_NONE:
		words[index].grab_focus()
	selection_changed.emit(index)

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and confirming:
		close_quit_confirm()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and page_open >= 0:
		close_page()
		get_viewport().set_input_as_handled()
	elif page_open < 0 and get_viewport().gui_get_focus_owner() == null and (event.is_action_pressed("ui_down") or event.is_action_pressed("ui_up") or event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right") or event.is_action_pressed("ui_accept")):
		words[0].grab_focus()
		get_viewport().set_input_as_handled()
