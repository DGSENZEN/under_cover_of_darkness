class_name DeathPage
extends Control
## After death (the save and load spec, section 2): three words in the pause
## menu's column, over the HUD's death dimming. Load latest loads the run's
## newest save (with none, the map starts again); Load opens the Load page;
## Main menu leaves through the loading cover. Its words are SaveWords' (the
## user's to write).

const SaveFiles := preload("res://scripts/Save/SaveFiles.gd")
const SaveWords := preload("res://scripts/Save/SaveWords.gd")
const ArtLoading := preload("res://scripts/UI/ArtLoadingScreen.gd")
const DESIGN := Vector2(1600, 900)
const MAIN_MENU := "res://main_menu.tscn"

var words: Array[MenuWord] = []
var saves: SavePage
var saves_open := false
var _design: Control
var _saves_panel: Control
var _pressing := false


func _ready() -> void:
	name = "DeathPage"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_design = Control.new()
	_design.size = DESIGN
	_design.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_design)
	var names := [SaveWords.LOAD_LATEST, SaveWords.LOAD, SaveWords.MAIN_MENU]

	for i in names.size():
		var word := MenuWord.new()
		# (Continue's colour and painting for the loads, Quit's for the way out.)
		word.configure(names[i], 20 + i, MainMenu.COLOURS[1] if i < 2 else MainMenu.COLOURS[4], 1 if i < 2 else -1)
		word.position = Vector2(MainMenu.WORD_X, MainMenu.WORD_TOP + i * MainMenu.WORD_GAP - 26)
		word.size = Vector2(420, 52)
		word.pressed.connect(_activate.bind(i))
		_design.add_child(word)
		words.append(word)

	_saves_panel = Control.new()
	_saves_panel.position = Vector2(620, 220)
	_saves_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_design.add_child(_saves_panel)
	saves = SavePage.new()
	_saves_panel.add_child(saves)
	saves.load_chosen.connect(_load)
	_saves_panel.hide()
	get_viewport().size_changed.connect(_layout)
	_layout()
	hide()


## Shown when the player has died.
func open() -> void:
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	words[0].grab_focus()


func _activate(index: int) -> void:
	if _pressing or saves_open:
		return

	_pressing = true
	words[index].press_in()
	await get_tree().create_timer(MenuMotion.PRESS, true, false, true).timeout
	_pressing = false

	match index:
		0:
			load_latest()
		1:
			open_saves()
		2:
			_leave_to_menu()


## The run's newest save; with none, the map from the start.
func load_latest() -> void:
	var city := get_node_or_null("/root/CityState")
	var newest := SaveFiles.newest_save(city.run_id) if city != null and city.run_id != "" else {}

	if newest.is_empty():
		get_tree().reload_current_scene()
		return

	_load(String(newest["run"]), String(newest["slot"]))


func _load(run_id: String, slot: String) -> void:
	var save := get_node_or_null("/root/SaveGame")

	if save != null:
		close_saves()
		save.load_slot(run_id, slot)


func open_saves() -> void:
	saves_open = true
	var city := get_node_or_null("/root/CityState")
	saves.open(&"load", city.run_id if city != null else "")
	_saves_panel.show()
	saves.focus_first()


func close_saves() -> void:
	saves_open = false
	_saves_panel.hide()


func _unhandled_input(event: InputEvent) -> void:
	if visible and saves_open and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()

		if saves.is_asking():
			saves.answer(false)
		else:
			close_saves()
			words[1].grab_focus()


func _leave_to_menu() -> void:
	var cover := ArtLoading.open(get_tree())
	cover.fade_in(0.25)
	await cover.change_to(MAIN_MENU)


func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	var factor := minf(view.x / DESIGN.x, view.y / DESIGN.y)
	_design.scale = Vector2.ONE * factor
	_design.position = (view - DESIGN * factor) * 0.5
