class_name SettingsPage
extends Control
## The settings book, the same on the main menu's Settings page and in the
## pause menu: four tabs written as small-caps words (Audio, Video, Controls,
## Interface), each a column of rows: a label, and its control (a brush-stroke
## slider, a ‹ cycler ›, an On / Off switch, a key). Up and down move between
## rows, left and right change one, Enter flips or starts a key; Q and E turn
## the tabs. Everything reads and writes GameSettings.
const INK := Color("f4e6cc")
const GOLD := Color("d9b46a")
const DIM := Color(0.957, 0.902, 0.8, 0.6)
const WIDTH := 780.0
const HEIGHT := 368.0
const ROW_HEIGHT := 46.0
## Where each row's control (or value) begins, and a slider's width.
const CONTROL_X := 340.0
const SLIDER_WIDTH := 290.0

## Each tab's rows: [setting key, label, kind, extra]. Kinds: "slider" (extra:
## [min, max, step, format]), "cycle" (extra: [[value, words], ...]),
## "switch", "key" (key = "keys/<action>"), "button".
const TABS := {
	"Audio": [
		["audio/master_volume", "Master", "slider", [0.0, 1.0, 0.05, "percent"]],
		["audio/music", "Music", "slider", [0.0, 1.0, 0.05, "percent"]],
		["audio/effects", "Effects", "slider", [0.0, 1.0, 0.05, "percent"]],
		["audio/ambience", "Ambience", "slider", [0.0, 1.0, 0.05, "percent"]],
		["audio/souls", "Voices and souls", "slider", [0.0, 1.0, 0.05, "percent"]],
	],
	"Video": [
		["video/window", "Window", "cycle", [[0, "Windowed"], [1, "Borderless"], [2, "Fullscreen"]]],
		["video/vsync", "VSync", "switch", null],
		["video/fps", "Frame limit", "cycle", [[30, "30"], [60, "60"], [120, "120"], [144, "144"], [0, "Unlimited"]]],
		["video/brightness", "Brightness", "slider", [0.5, 1.5, 0.05, "percent"]],
		["video/fov", "Field of view", "slider", [60.0, 100.0, 1.0, "degrees"]],
		["video/grid", "Pixel grid", "cycle", [[480, "480"], [360, "360"], [240, "240"], [0, "Off"]]],
	],
	"Controls": [
		["controls/sensitivity", "Mouse sensitivity", "slider", [0.25, 3.0, 0.05, "percent"]],
		["controls/invert", "Invert look", "switch", null],
		["keys/move_forward", "Move forward", "key", null],
		["keys/move_back", "Move back", "key", null],
		["keys/move_left", "Move left", "key", null],
		["keys/move_right", "Move right", "key", null],
		["keys/jump", "Jump", "key", null],
		["keys/sprint", "Sprint", "key", null],
		["keys/crouch", "Crouch", "key", null],
		["keys/frob", "Use", "key", null],
		["keys/inventory", "Inventory", "key", null],
		["keys/throw", "Throw", "key", null],
		["keys/block", "Block", "key", null],
		["keys/kick", "Kick", "key", null],
		["keys/dodge", "Dodge", "key", null],
		["keys/lean_left", "Lean left", "key", null],
		["keys/lean_right", "Lean right", "key", null],
		["keys/belt_next", "Belt next", "key", null],
		["keys/belt_prev", "Belt previous", "key", null],
		["reset", "Reset keys", "button", null],
	],
	"Interface": [
		["hud/awareness_marks", "Awareness marks", "switch", null],
		["hud/subtitles", "Subtitles", "switch", null],
		["hud/subtitle_size", "Subtitle size", "cycle", [[0, "Small"], [1, "Medium"], [2, "Large"]]],
		["hud/crosshair", "Crosshair", "switch", null],
		["comfort/camera_motion", "Camera motion", "slider", [0.0, 1.0, 0.05, "percent"]],
	],
}

## One setting on the page.
class Row extends Control:
	var page: SettingsPage
	var key := ""
	var kind := ""
	var extra: Variant
	var label: Label
	var value_label: Label
	var slider: HSlider
	var _quiet := false

	func setup(owner_page: SettingsPage, spec: Array) -> void:
		page = owner_page
		key = spec[0]
		kind = spec[2]
		extra = spec[3]
		name = key.replace("/", "_")
		custom_minimum_size = Vector2(WIDTH - 24.0, ROW_HEIGHT)
		focus_mode = Control.FOCUS_ALL
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		label = page.text(MenuType.body(), 27, spec[1])
		label.position = Vector2(18, 4)
		add_child(label)
		value_label = page.text(MenuType.choice(), 24, "")
		value_label.size = Vector2(custom_minimum_size.x - CONTROL_X, ROW_HEIGHT - 6)
		value_label.position = Vector2(CONTROL_X, 6)
		add_child(value_label)
		if kind == "slider":
			slider = HSlider.new()
			slider.min_value = extra[0]
			slider.max_value = extra[1]
			slider.step = 0.01 if extra[2] < 1.0 else 1.0
			slider.focus_mode = Control.FOCUS_NONE
			slider.custom_minimum_size = Vector2(SLIDER_WIDTH, 30)
			slider.size = Vector2(SLIDER_WIDTH, 30)
			slider.position = Vector2(CONTROL_X - 8, 8)
			slider.value_changed.connect(func(v: float):
				if not _quiet:
					GameSettings.set_value(key, v)
				refresh())
			add_child(slider)
			value_label.size.x = 90
			value_label.position.x = CONTROL_X + SLIDER_WIDTH + 6
			value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		focus_entered.connect(_lit)
		focus_exited.connect(_lit)
		mouse_entered.connect(grab_focus)
		refresh()
		_lit()

	## What the row shows for its value (a cycler's words without its arrows).
	func value_text() -> String:
		return String(value_label.get_meta(&"plain", value_label.text))

	func refresh() -> void:
		match kind:
			"slider":
				var v := float(GameSettings.value(key))
				_quiet = true
				slider.set_value_no_signal(v)
				_quiet = false
				value_label.text = ("%d°" % roundi(v)) if extra[3] == "degrees" else ("%d%%" % roundi(v * 100.0))
			"cycle":
				var words := _words_for(GameSettings.value(key))
				value_label.text = "‹  %s  ›" % words
				value_label.set_meta(&"plain", words)
			"switch":
				value_label.text = "On" if GameSettings.value(key) else "Off"
			"key":
				value_label.text = "Press a key…" if page.capturing == self else GameSettings.key_name(StringName(key.trim_prefix("keys/")))
			"button":
				value_label.text = ""

	func _words_for(v: Variant) -> String:
		for choice in extra:
			if choice[0] == v:
				return choice[1]
		return str(v)

	## Left (-1) or right (+1): a slider steps, a cycler turns, a switch flips.
	func change(direction: int) -> void:
		match kind:
			"slider":
				var stepped := clampf(snappedf(float(GameSettings.value(key)) + direction * float(extra[2]), float(extra[2])), extra[0], extra[1])
				GameSettings.set_value(key, stepped)
			"cycle":
				var at := 0
				for i in range(extra.size()):
					if extra[i][0] == GameSettings.value(key):
						at = i
				GameSettings.set_value(key, extra[posmod(at + direction, extra.size())][0])
			"switch":
				GameSettings.set_value(key, not GameSettings.value(key))
		refresh()

	## Enter or a click: a switch flips, a cycler turns on, a key waits, a
	## button acts.
	func press() -> void:
		match kind:
			"switch", "cycle":
				change(1)
			"key":
				page.begin_capture(self)
			"button":
				if key == "reset":
					GameSettings.reset_keys()
					page.refresh_all()

	func _gui_input(event: InputEvent) -> void:
		if page.capturing != null:
			return
		if event.is_action_pressed("ui_left"):
			change(-1)
		elif event.is_action_pressed("ui_right"):
			change(1)
		elif event.is_action_pressed("ui_accept"):
			press()
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and (slider == null or not slider.get_global_rect().has_point(event.global_position)):
			press()
		else:
			return
		accept_event()

	func _lit() -> void:
		var on := has_focus()
		label.add_theme_color_override("font_color", INK if on else DIM)
		value_label.add_theme_color_override("font_color", GOLD if on else DIM)
		queue_redraw()

	func _draw() -> void:
		if has_focus():
			# A gold tick at the row's start, and a hairline under it.
			draw_rect(Rect2(0, 12, 3, size.y - 24), GOLD)
			draw_line(Vector2(16, size.y - 2), Vector2(size.x * 0.55, size.y - 2), Color(GOLD, 0.35), 1.0)

var tab := 0
## The key row waiting for a key, if any.
var capturing: Row = null
var colour := GOLD
var _tabs: Array[Button] = []
var _scroll: ScrollContainer
var _column: VBoxContainer
var _rows_by_tab: Array = []

func build() -> void:
	name = "SettingsPage"
	custom_minimum_size = Vector2(WIDTH, HEIGHT + 60)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 34)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	var i := 0
	for title in TABS:
		var word := Button.new()
		word.text = title
		word.flat = true
		word.focus_mode = Control.FOCUS_NONE
		word.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		word.add_theme_font_override("font", MenuType.choice())
		word.add_theme_font_size_override("font_size", 28)
		for state in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
			word.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		word.pressed.connect(show_tab.bind(i))
		bar.add_child(word)
		_tabs.append(word)
		i += 1
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(0, 58)
	_scroll.size = Vector2(WIDTH, HEIGHT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	# No panel or focus frame: the rows sit straight on the page.
	_scroll.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_scroll.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	# A thin gold rule for a scroll bar.
	var bar_line := _scroll.get_v_scroll_bar()
	var groove := StyleBoxFlat.new()
	groove.bg_color = Color(INK, 0.08)
	groove.content_margin_left = 2
	groove.content_margin_right = 2
	var grip := StyleBoxFlat.new()
	grip.bg_color = Color(GOLD, 0.55)
	grip.content_margin_left = 2
	grip.content_margin_right = 2
	bar_line.add_theme_stylebox_override("scroll", groove)
	bar_line.add_theme_stylebox_override("grabber", grip)
	bar_line.add_theme_stylebox_override("grabber_highlight", grip)
	bar_line.add_theme_stylebox_override("grabber_pressed", grip)
	add_child(_scroll)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 2)
	_scroll.add_child(_column)
	for title in TABS:
		var rows: Array[Row] = []
		for spec in TABS[title]:
			var row := Row.new()
			row.setup(self, spec)
			rows.append(row)
		_rows_by_tab.append(rows)
	GameSettings.events().changed.connect(_on_setting_changed)
	show_tab(0)

func tab_names() -> Array:
	return TABS.keys()

func rows() -> Array[Row]:
	return _rows_by_tab[tab]

## The row for a setting key on the shown tab or any other.
func row_for(key: String) -> Row:
	for rows_of_tab in _rows_by_tab:
		for row in rows_of_tab:
			if row.key == key:
				return row
	return null

func show_tab(index: int) -> void:
	end_capture()
	tab = posmod(index, _rows_by_tab.size())
	for child in _column.get_children():
		_column.remove_child(child)
	for row in _rows_by_tab[tab]:
		_column.add_child(row)
		row.refresh()
	for i in range(_tabs.size()):
		_tabs[i].add_theme_color_override("font_color", colour if i == tab else DIM)
		_tabs[i].add_theme_color_override("font_hover_color", INK)
	_scroll.scroll_vertical = 0
	if is_visible_in_tree():
		focus_first()

func focus_first() -> void:
	if not _rows_by_tab[tab].is_empty():
		_rows_by_tab[tab][0].grab_focus()

## The page's colour (its word's) on the tabs and the painted controls.
func paint(page_colour: Color) -> void:
	colour = page_colour
	for rows_of_tab in _rows_by_tab:
		for row in rows_of_tab:
			if row.slider:
				MenuPages.paint_slider(row.slider, colour)
	show_tab(tab)

func refresh_all() -> void:
	for rows_of_tab in _rows_by_tab:
		for row in rows_of_tab:
			row.refresh()

func begin_capture(row: Row) -> void:
	capturing = row
	row.refresh()

func end_capture() -> void:
	var was := capturing
	capturing = null
	if was:
		was.refresh()

func _on_setting_changed(_key: String) -> void:
	refresh_all()

## While a key row waits, the next key or mouse button is its own; Escape
## cancels the wait (and only that).
func _input(event: InputEvent) -> void:
	if capturing == null or not is_visible_in_tree():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_ESCAPE or (event as InputEventKey).physical_keycode == KEY_ESCAPE:
			end_capture()
		else:
			var key := InputEventKey.new()
			key.physical_keycode = (event as InputEventKey).physical_keycode if (event as InputEventKey).physical_keycode != KEY_NONE else (event as InputEventKey).keycode
			GameSettings.bind(StringName(capturing.key.trim_prefix("keys/")), key)
			end_capture()
			refresh_all()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2]:
		var button := InputEventMouseButton.new()
		button.button_index = (event as InputEventMouseButton).button_index
		GameSettings.bind(StringName(capturing.key.trim_prefix("keys/")), button)
		end_capture()
		refresh_all()
		get_viewport().set_input_as_handled()

## Q and E turn the tabs.
func _unhandled_key_input(event: InputEvent) -> void:
	if capturing != null or not is_visible_in_tree() or not event.is_pressed() or event.is_echo():
		return
	var code := (event as InputEventKey).physical_keycode if (event as InputEventKey).physical_keycode != KEY_NONE else (event as InputEventKey).keycode
	if code == KEY_Q:
		show_tab(tab - 1)
	elif code == KEY_E:
		show_tab(tab + 1)
	else:
		return
	get_viewport().set_input_as_handled()

func text(font: Font, point_size: int, words: String) -> Label:
	var label := Label.new()
	label.text = words
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", point_size)
	label.add_theme_color_override("font_color", DIM)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label
