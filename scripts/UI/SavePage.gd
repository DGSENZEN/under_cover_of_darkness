class_name SavePage
extends Control
## The Load and Save pages (the save and load spec, section 5), built in code
## in the menu's book type, over a page's painting (the main menu's, the
## pause's).
##
## Load: every run, the one played last first and open; an open run lists its
## saves, newest first, each with its picture, place, kind, date and time
## played; a damaged one is shown, greyed, and cannot be chosen. Save: a new
## save first, then this run's named saves to write over. A save or a whole
## run can be deleted (Delete or X on its row), asked first; so is writing
## over a save. Every word is SaveWords' (the user's to write).

const SaveFiles := preload("res://scripts/Save/SaveFiles.gd")
const SaveWords := preload("res://scripts/Save/SaveWords.gd")
const INK := Color("f4e6cc")
const GOLD := Color("d9b46a")
const DIM := Color(0.957, 0.902, 0.8, 0.45)
## The page's area (MenuPages.AREA's size), and a save's picture in its row.
const AREA := Vector2(560, 560)
const PICTURE := Vector2(96, 54)
const ROW_GAP := 4

## A save chosen to load; a slot chosen to save into ("" a new save).
signal load_chosen(run_id: String, slot: String)
signal save_chosen(slot: String)

var mode := &"load"
## The run whose saves show (Load), or that is saved into (Save).
var open_run := ""
## The rows in reading order: Buttons with metas what (&"run", &"save",
## &"new"), run and slot.
var rows: Array[Button] = []
## The question asked before deleting or writing over, and what Yes does.
var question: Label
var asking := {}
var _list: VBoxContainer
var _scroll: ScrollContainer
var _confirm: HBoxContainer
var _current := ""


func _init() -> void:
	name = "SavePage"
	size = AREA
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll = ScrollContainer.new()
	_scroll.size = AREA - Vector2(0, 48)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_list = VBoxContainer.new()
	_list.custom_minimum_size.x = AREA.x - 16
	_list.add_theme_constant_override("separation", ROW_GAP)
	_scroll.add_child(_list)
	_confirm = HBoxContainer.new()
	_confirm.position = Vector2(0, AREA.y - 40)
	_confirm.add_theme_constant_override("separation", 18)
	add_child(_confirm)
	question = Label.new()
	question.add_theme_font_override("font", MenuType.body_italic())
	question.add_theme_font_size_override("font_size", 22)
	question.add_theme_color_override("font_color", INK)
	_confirm.add_child(question)

	for yes in [true, false]:
		var word := _button("Yes" if yes else "No", 22)
		word.pressed.connect(answer.bind(yes))
		_confirm.add_child(word)

	_confirm.hide()


## Opens as `as_mode` (&"load" or &"save") for `current_run` (the run being
## played; "" from the main menu, where the run played last opens).
func open(as_mode: StringName, current_run: String) -> void:
	mode = as_mode
	_current = current_run
	open_run = current_run if current_run != "" else SaveFiles.last_run()
	_close_question()
	_rebuild()


## The row of a run (`slot` "") or of one of its saves; null if none shows.
func row_for(run_id: String, slot := "") -> Button:
	for row in rows:
		if row.get_meta(&"run") == run_id and row.get_meta(&"slot") == slot and row.get_meta(&"what") != &"new":
			return row

	return null


func focus_first() -> void:
	for row in rows:
		if not row.disabled:
			row.grab_focus()
			return


func _rebuild() -> void:
	for row in rows:
		_list.remove_child(row)
		row.queue_free()

	rows.clear()

	if mode == &"save":
		_add_row(SaveWords.NEW_SAVE, &"new", open_run, "")

		for entry in SaveFiles.saves(open_run):
			if entry["kind"] == &"named":
				_add_save(entry)

		return

	# The run open first, the rest after it newest first.
	var runs := SaveFiles.runs()
	var open_first := runs.filter(func(r): return r["id"] == open_run)
	open_first.append_array(runs.filter(func(r): return r["id"] != open_run))
	runs = open_first

	for run in runs:
		var played := _time(float(run["played"]))
		_add_row("%s   %s   %s" % [SaveWords.ARCHETYPES.get(run["archetype"], ""), played, _date(int(run["newest"]))], &"run", run["id"], "")

		if run["id"] == open_run:
			for entry in SaveFiles.saves(run["id"]):
				_add_save(entry)


func _add_save(entry: Dictionary) -> void:
	var text: String

	if entry["readable"]:
		text = "%s   %s   %s   %s" % [entry.get("place", SaveWords.SOMEWHERE), SaveWords.KINDS.get(entry["kind"], ""), _date(int(entry["date"])),
			_time(float(entry.get("played", 0.0)))]
	else:
		text = "%s   %s" % [SaveWords.UNREADABLE, _date(int(entry["date"]))]

	var row := _add_row(text, &"save", String(entry.get("run", open_run)), String(entry["slot"]))
	row.disabled = not entry["readable"]

	if row.disabled:
		row.modulate = DIM

	if entry["picture"] != "":
		var image := Image.load_from_file(entry["picture"])

		if image != null and not image.is_empty():
			row.icon = ImageTexture.create_from_image(image)
			row.expand_icon = true
			row.custom_minimum_size.y = PICTURE.y


func _add_row(text: String, what: StringName, run_id: String, slot: String) -> Button:
	var row := _button(text, 20 if what == &"save" else 24)
	row.set_meta(&"what", what)
	row.set_meta(&"run", run_id)
	row.set_meta(&"slot", slot)
	row.pressed.connect(_chosen.bind(row))
	row.gui_input.connect(_row_input.bind(row))
	_list.add_child(row)
	rows.append(row)
	return row


func _button(text: String, font_size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.flat = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_override("font", MenuType.body())
	button.add_theme_font_size_override("font_size", font_size)

	for state in ["font_color", "font_disabled_color"]:
		button.add_theme_color_override(state, INK)

	for state in ["font_hover_color", "font_focus_color", "font_pressed_color"]:
		button.add_theme_color_override(state, GOLD)

	return button


func _chosen(row: Button) -> void:
	if row.disabled or not asking.is_empty():
		return

	match row.get_meta(&"what"):
		&"run":
			open_run = row.get_meta(&"run")
			_rebuild()
			var reopened := row_for(open_run)

			if reopened != null:
				reopened.grab_focus()
		&"new":
			save_chosen.emit("")
		&"save":
			if mode == &"save":
				_ask(SaveWords.OVERWRITE, func(): save_chosen.emit(row.get_meta(&"slot")))
			else:
				load_chosen.emit(row.get_meta(&"run"), row.get_meta(&"slot"))


func _row_input(event: InputEvent, row: Button) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_DELETE or event.keycode == KEY_X):
		accept_event()
		ask_delete(row)


## Asks before deleting `row`'s save, or its whole run.
func ask_delete(row: Button) -> void:
	if row == null or row.get_meta(&"what") == &"new":
		return

	var run_id: String = row.get_meta(&"run")
	var slot: String = row.get_meta(&"slot")

	if row.get_meta(&"what") == &"run":
		_ask(SaveWords.DELETE_RUN, func(): SaveFiles.delete_run(run_id); _rebuild())
	else:
		_ask(SaveWords.DELETE_SAVE, func(): SaveFiles.delete_save(run_id, slot); _rebuild())


func _ask(text: String, yes: Callable) -> void:
	question.text = text
	asking = {"yes": yes}
	_confirm.show()
	(_confirm.get_child(2) as Button).grab_focus()


## The question answered: Yes does what was asked; either way it closes.
func answer(yes: bool) -> void:
	if asking.is_empty():
		return

	var then: Callable = asking["yes"]
	_close_question()

	if yes:
		then.call()

	focus_first()


func _close_question() -> void:
	asking = {}
	_confirm.hide()


## Whether a question is up (Escape answers No to it first).
func is_asking() -> bool:
	return not asking.is_empty()


static func _time(seconds: float) -> String:
	var minutes := int(seconds / 60.0)
	return "%d:%02d" % [minutes / 60, minutes % 60]


static func _date(unix: int) -> String:
	# (The player's own clock, not the world's.)
	var at := Time.get_datetime_dict_from_unix_time(unix + int(Time.get_time_zone_from_system()["bias"]) * 60)
	return "%04d-%02d-%02d %02d:%02d" % [at["year"], at["month"], at["day"], at["hour"], at["minute"]]
