extends CanvasLayer
## The talk box (the talk and quests spec, section 4, as the user settled it
## over 28 drafts: .superpowers/talkbox/draft28.jpg and draft28_reference.py):
## a talk with a shade, told on screen while the world goes on.
##   - A painted panel at the bottom middle, its foot running off the screen,
##     and the speaker's portrait overlapping its left edge, the pair centred
##     together over a soft shadow. Both fray out from their own paint
##     (talk_paint.gdshader) and paint themselves in, in splotches and
##     bristle strokes, as it opens, and lift off as it closes.
##   - Inside the panel, centred: the speaker's name in marigold, the line in
##     cream told out a few letters at a time (an inner voice, Sense obsidian,
##     in cochineal), then the options, each in its own painted brush swipe
##     (talk_swipe.gdshader); the chosen one warm gold with dark ink and the
##     marker at its end; picked with 1-9, the mouse, or the wheel and E.
##     A special option of a school (`> !obsidian`) and a Sense line wear the
##     school's look (SCHOOL_LOOK). More options than fit close up, then
##     scroll with the choice, a painted fade at each edge with more beyond.
##   - The look comes from a TalkSkin: the character's own paintings where
##     the user painted them (assets/ui/talk/<character>), else the plain one
##     (a backdrop painted from noise, the live render of the shade's head, a
##     painted spike). A painted skin lives: TalkSkin.animate each frame.
## A line taller than its area (from LINE_AT down to the options' first row)
## is told in pages that fit it, broken where the type really wraps, at a
## sentence's end where one falls on the page: a pulsing … at the area's
## bottom right while more pages remain; the options and the next line come
## after the last page. The wheel over the line (or anywhere while there are
## no options), PageUp and PageDown turn back and on through the pages read.
## E, Enter or a click tells the line out at once, the next press goes on. Holding
## back (WALK_AWAY) walks away, and they remember it (walked_off). A blow, a
## death or leaving the district breaks it off (interrupt): gone at once,
## nothing remembered. Escape pauses the game; the box freezes under the
## pause screen (it sits just under the HUD's layer).
##
## The player stands still meanwhile (PlayerController.talk_hold): no feet,
## no look, no blows; the view eases round to the speaker. The HUD gives way.
##
## Built in two halves so a skin can take over the look later: _build_* makes
## the parts, plan() and _layout place them. The talk, the keys and the sounds
## are the same for every look.

const Conversation := preload("res://scripts/Interaction/Conversation.gd")
const DialogueBook := preload("res://scripts/Level/DialogueBook.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")
const TalkSkin := preload("res://scripts/UI/TalkSkin.gd")
const PAINT := preload("res://scripts/UI/talk_paint.gdshader")
const SWIPE := preload("res://scripts/UI/talk_swipe.gdshader")
const FADE := preload("res://scripts/UI/talk_fade.gdshader")
const Layers := preload("res://scripts/Visual/Layers.gd")

## The box has closed (the talk is over, or broken off).
signal closed

## Letters told out a second.
const REVEAL_CPS := 45.0
## For this long after the options come up a press picks nothing, so the
## press that told the last line out does not also choose (s).
const OPTION_GUARD := 0.25
## Holding back this long walks away (s).
const WALK_AWAY := 0.5

## Draft 28's paints.
const MARIGOLD := Color8(242, 177, 52)
const COCHINEAL := Color8(214, 64, 56)
const CREAM := Color8(236, 228, 210)
## The words on the chosen gold swipe.
const DARK_INK := Color8(20, 14, 20)
const SHADOW := Color8(2, 3, 8)
## A special option of a school (`> !obsidian`) and a `Sense <school>:` line
## wear its look (the spec's "Magic options get their school's shader"): the
## swipe paints itself in the school's work (talk_swipe.gdshader's `school`,
## talk_school.gdshaderinc), and the words take its ink (`chosen` on its
## chosen swipe, never the gold wash's dark ink) and a faint doubling, a
## second print of the words `offset` px away (at 1080p) in `double`, as a
## reflection in black glass, smoke rising, a ghost beside them.
const SCHOOL_LOOK := {
	"obsidian": {"ink": Color(0.71, 0.77, 0.86), "chosen": Color(0.9, 0.95, 1.0), "double": Color(0.62, 0.76, 1.0, 0.26),
		"offset": Vector2(2.0, 2.0)},
	"copal": {"ink": Color(0.93, 0.74, 0.5), "chosen": Color(1.0, 0.86, 0.62), "double": Color(0.8, 0.62, 0.42, 0.22),
		"offset": Vector2(1.0, -2.0)},
	"seance": {"ink": Color(0.8, 0.88, 0.84), "chosen": Color(0.92, 1.0, 0.96), "double": Color(0.78, 0.92, 0.88, 0.22),
		"offset": Vector2(3.0, 0.0)},
	"nahual": {"ink": Color(0.86, 0.63, 0.47), "chosen": Color(0.98, 0.78, 0.6), "double": Color(0.6, 0.18, 0.12, 0.35),
		"offset": Vector2(2.0, 1.0)},
	"lumen": {"ink": Color(0.76, 0.86, 1.0), "chosen": Color(0.9, 0.96, 1.0), "double": Color(0.5, 0.7, 1.0, 0.3),
		"offset": Vector2(1.0, -1.0)},
	"relic": {"ink": Color(0.95, 0.81, 0.5), "chosen": Color(1.0, 0.9, 0.62), "double": Color(0.12, 0.08, 0.03, 0.5),
		"offset": Vector2(1.0, 2.0)},
}

## Draft 28's layout, in px at 1920 x 1080 (everything scales with the
## screen's height): the panel's width, how far its top stands below
## H - its height (its foot runs off the screen by as much), the portrait's
## height, how far it overlaps the panel and stands above it.
const PANEL_WIDE := 1000.0
const PANEL_DROP := 40.0
const PORTRAIT_TALL := 470.0
const PORTRAIT_OVERLAP := 70.0
const PORTRAIT_RISE := 70.0
## Inside the panel: the name's top, the line's top and its line step, the
## options' top and step, from the panel's top; the line wraps this wide.
const NAME_AT := 146.0
const LINE_AT := 182.0
const LINE_STEP := 38.0
const LINE_WIDE := 560.0
const OPTIONS_AT := 318.0
const OPTION_STEP := 50.0
## The more-marker of a line in pages: how far right of the line's width it
## stands, how wide it is (px at 1080p), its words, how often it pulses (Hz)
## and how low it dims between.
const MORE_GAP := 6.0
const MORE_WIDE := 40.0
const MORE_TEXT := "…"
const MORE_PULSE := 0.8
const MORE_LEAST := 0.45
## More options than fit at OPTION_STEP above the screen's foot (less
## OPTIONS_MARGIN) close up, down to OPTION_STEP_LEAST, their swipes as much
## thinner but never below SWIPE_THIN_LEAST (the words keep their size); more
## still than fit at that scroll, the chosen one always in view, a painted
## fade at each edge with more beyond it (FADE_TALL), the top one never over
## the spoken line.
const OPTION_STEP_LEAST := 42.0
const OPTIONS_MARGIN := 24.0
const FADE_TALL := 20.0
## A row's swipe, unchosen and chosen, at draft 28's step (px at 1080p): its
## middle always on the middle of the words (their ascent to descent), so the
## words sit in the swipe's painted bristle band (the middle 76% of it,
## talk_swipe.gdshader's BAND_TOP..BAND_BOTTOM). Thinned, it keeps that band
## at least as tall as the words: never below SWIPE_THIN_LEAST of itself.
const SWIPE_TALL := 42.0
const CHOSEN_TALL := 46.0
const SWIPE_THIN_LEAST := 0.96
## The options' column: the longest option plus this; the words stand this
## far into their swipe; the marker's width.
const COLUMN_MORE := 70.0
const OPTION_INDENT := 30.0
const MARKER_WIDE := 150.0
## The frayed pad round the panel and the portrait (the strokes' room).
const PANEL_PAD := 40.0
const PORTRAIT_PAD := 30.0
## Type sizes (Georgia first; no serif ships with the game).
const FONT_NAMES := ["Georgia", "Times New Roman", "Times", "Liberation Serif", "DejaVu Serif", "Noto Serif", "serif"]
const NAME_SIZE := 24
const LINE_SIZE := 29
const OPTION_SIZE := 26

## Painting in: the panel over this long (s), the portrait as long but this
## much later; the words once the panel is this far down; each swipe over
## SWIPE_TIME, the next this much later; a newly chosen one over CHOSEN_TIME;
## lifting off over CLOSE_TIME.
const PANEL_TIME := 0.5
const PORTRAIT_LAG := 0.1
const WORDS_FROM := 0.8
const SWIPE_TIME := 0.22
const SWIPE_STAGGER := 0.05
const CHOSEN_TIME := 0.15
const CLOSE_TIME := 0.35
## A word or option's letters fade up over this long once its paint is down.
const INK_TIME := 0.12

## The live portrait: how far before the face (m), how far below the eyes
## it looks (m), its lens (degrees); never sharper than this (px).
const PORTRAIT_DISTANCE := 1.25
const PORTRAIT_DROP := 0.12
const PORTRAIT_FOV := 30.0
const PORTRAIT_MOST := 1024
## How far it sees (m): the speaker and the room behind, not the city.
const PORTRAIT_FAR := 25.0
## It renders this many times a second (not every frame: it is the world a
## second time), in a lean copy of the world's environment (no volumetric
## fog, SSAO, SSR or SSIL; glow at most this strong, bloom at most this) and
## without positional shadows.
const PORTRAIT_HZ := 30.0
const PORTRAIT_GLOW := 0.8
const PORTRAIT_BLOOM := 0.05
## The speaker's head stands this far above the panel's top on the screen
## (px at 1080p): the view eases down to put it there, not behind the panel.
const HEAD_ABOVE_PANEL := 90.0
## The frayed edge's soft rim, at most this wide (px at 1080p): the paint is
## whole inside it, with no see-through band.
const FRAY_SOFT := 5.0

## A voice's NOX takes (Sfx: murmur, murmur_b, murmur_f, and hm the same).
const VOICE_SUFFIX := {&"male": "", &"male_b": "_b", &"female": "_f"}
## How fast the view comes round to the speaker (per second, exponential).
const TURN_EASE := 5.0

var conversation: Conversation
var shade: Node
var player: Node
var skin: TalkSkin = TalkSkin.plain()

var _open := false
## What the box shows now: &"line", &"sense", &"pause", &"options" or &"".
var _kind: StringName = &""
## The page of the line shown now (the whole line when it fits one).
var _text := ""
## The whole line said, and its pages on this screen: each page's words,
## where it starts in the line, how many lines it wraps to; the page shown,
## the furthest one reached; the screen height they were broken for.
var _said := ""
var _pages: Array[String] = []
var _page_starts: Array[int] = []
var _page_lines: Array[int] = []
var _page := 0
var _read := 0
var _paged_for := 0.0
## Letters told out of _text so far.
var _shown := 0.0
## The options up: [{text, special}], and the one the wheel or mouse is on.
var _options: Array = []
var _choice := 0
## How long the options have been up (s).
var _options_age := 0.0
var _pause_left := 0.0
var _back_held := 0.0
## Back has been up since the talk opened (only then does holding it count).
var _back_armed := false
var _opened_frame := -1
var _rng := RandomNumberGenerator.new()
## The screen size the type was last sized for (_layout).
var _typed_for := Vector2.ZERO
var _voice := ""

## The paint: how far the panel and the portrait are down (0..1), and each
## swipe's; opening (time since), or closing.
var _panel_reveal := 0.0
var _portrait_reveal := 0.0
var _swipe_reveal: Array[float] = []
var _since := 0.0
var _closing := false
var _seed := 0.0
## Each option's ink (0..1), and the name's and the line's.
var _option_ink: Array[float] = []
var _words_ink := 0.0

var _font: SystemFont
var _bold: SystemFont
var _italic: SystemFont
var _root: Control
var _shadow: ColorRect
var _panel: TextureRect
var _portrait: TextureRect
var _viewport: SubViewport
var _camera: Camera3D
var _name: Label
var _words: Label
## The more-marker: more pages of this line to come.
var _more: Label
var _swipes: Array[TextureRect] = []
var _option_labels: Array[Label] = []
## The first option in view and how many are (all of them unless they
## scroll); the mouse where it was when the list last scrolled (a row
## scrolled under a still mouse is not pointed at).
var _scroll := 0
var _in_view := 0
var _scroll_mouse := Vector2(-1e9, -1e9)
## The painted fades over the options' clipped edges (more above, more below).
var _fade_top: TextureRect
var _fade_bottom: TextureRect
## The school the line's words wear ("" a spoken line).
var _words_school := ""
## Paused: the words and the options are hidden under the pause screen.
var _paused_words := false
## The layout last placed (plan()).
var _plan := {}
## What plan() measured of the words, once per text: {key: size}. Measured
## at the 1080p type sizes (the screen only scales them), so the screen's
## size never makes them stale. And how many measurements it has made.
var _measured := {}
var _measures := 0
## Till the live portrait renders again (s), and how often it has.
var _portrait_wait := 0.0
var _portrait_renders := 0


# Opening and closing

## Opens a talk with `p_shade` (Shade: its dialogue, cue, face, head_point)
## for `p_player`, and tells its first line.
func open(p_shade: Node, p_player: Node) -> void:
	shade = p_shade
	player = p_player
	# Over the pixel grid (Retro, 4); with the HUD (5) but under it, so the
	# pause screen covers it (the player's frob puts it before the HUD).
	layer = 5
	# Laid out every frame: never interpolated.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var people: RefCounted = CityState.people
	# The conditions has(x) and purse>=n read the belt the talk gives to.
	people.inventory = player.inventory
	conversation = Conversation.new(shade.dialogue, people, player.inventory)
	conversation.line.connect(_on_line)
	conversation.sense.connect(_on_sense)
	conversation.paused.connect(_on_paused)
	conversation.options.connect(_on_options)
	conversation.cue.connect(_on_cue)
	conversation.resting.connect(_on_resting)
	conversation.ended.connect(_on_ended)
	_voice = String(VOICE_SUFFIX.get(StringName(shade.dialogue.get("voice", &"male")), ""))
	_open = true
	_opened_frame = Engine.get_physics_frames()
	# Its own dice, so the paint's seed draws nothing from the game's.
	_rng.randomize()
	_seed = _rng.randf() * 100.0
	# Back held from before the talk is not walking away: a fresh press is.
	_back_armed = not Input.is_action_pressed("move_back")
	player.talk_hold = true
	# Their own paintings if they have them (assets/ui/talk/<id>), else the
	# plain box.
	skin = TalkSkin.for_character(String(shade.dialogue.get("id", "")))

	_build()
	_place_portrait_camera()
	shade.face(_eye())
	_layout(_screen())
	conversation.start()

	if _open and not conversation.is_over():
		conversation.advance()


## The talk is over: the player is his own again at once, the mouse taken
## back; the paint lifts off (CLOSE_TIME) and the box goes.
func close() -> void:
	if not _open:
		return

	_release()
	_closing = true
	_since = 0.0


## Broken off (a blow, death, leaving): ended with nothing remembered, and
## gone this frame.
func interrupt() -> void:
	if conversation != null and not conversation.is_over():
		conversation.interrupt()

	if _open:
		_release()

	_gone()


func is_open() -> bool:
	return _open


## Hands everything back (once).
func _release() -> void:
	_open = false
	_kind = &""

	if is_instance_valid(player):
		player.talk_hold = false

		# Taken back as a click would: the press that closed it is no blow.
		if player.has_method("_recapture_mouse"):
			player._recapture_mouse()
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

		if player.has_method("spend_attack_press"):
			player.spend_attack_press()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if is_instance_valid(shade):
		shade.end_line()
		shade.speaking(false)

	closed.emit()


## Off the screen now and away.
func _gone() -> void:
	_closing = false
	_panel_reveal = 0.0
	_portrait_reveal = 0.0
	visible = false

	if is_inside_tree():
		queue_free()


## Paused (Esc): the box's words and options hide under the pause screen,
## so its text never crosses the pause screen's; they come back with play.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_UNPAUSED:
		_show_words(what == NOTIFICATION_UNPAUSED)


func _show_words(on: bool) -> void:
	_paused_words = not on

	for node in [_name, _words]:
		if node != null and is_instance_valid(node):
			(node as CanvasItem).visible = on

	_show_more()
	_show_rows()


## Each option's swipe and words shown while it is in view (and not paused),
## each fade while there is more beyond its edge.
func _show_rows() -> void:
	for i in _swipes.size():
		var shown := not _paused_words and i >= _scroll and i < _scroll + _in_view

		if is_instance_valid(_swipes[i]):
			_swipes[i].visible = shown

		if i < _option_labels.size() and is_instance_valid(_option_labels[i]):
			_option_labels[i].visible = shown

	if is_instance_valid(_fade_top):
		_fade_top.visible = not _paused_words and _scroll > 0

	if is_instance_valid(_fade_bottom):
		_fade_bottom.visible = not _paused_words and _scroll + _in_view < _swipes.size()


func _exit_tree() -> void:
	# Taken away with its player or its level: broken off, not left holding.
	if _open:
		interrupt()


# What it shows (for tests, too)

## The words told out so far (of the page shown).
func shown_text() -> String:
	return _text.substr(0, int(_shown))


## The line's pages on this screen (one when it fits), and the one shown.
func pages() -> Array[String]:
	return _pages.duplicate()


func page() -> int:
	return _page


## Whether the more-marker shows (more pages of the line to come).
func more_shown() -> bool:
	return _more != null and _more.visible


## The options' words, in order.
func shown_options() -> Array[String]:
	var words: Array[String] = []

	if _kind == &"options":
		for option in _options:
			words.append(String(option["text"]))

	return words


## How far the box is painted in (0 gone, 1 whole): its panel and portrait.
func reveal() -> float:
	return maxf(_panel_reveal, _portrait_reveal)


## Where each part is now (in the screen's px): the panel and the portrait
## (their pictures, not the frayed pad), the name, the line and each
## option's words, and each swipe.
func layout_rects() -> Dictionary:
	var rects := {
		"panel": _panel.get_rect().grow(-PANEL_PAD * _scale()),
		"portrait": _portrait.get_rect().grow(-PORTRAIT_PAD * _scale()),
		"name": _name.get_rect(),
		"line": _words.get_rect(),
		"line area": _plan.get("line_area", Rect2()),
		"more": _more.get_rect(),
	}

	for i in _option_labels.size():
		rects["option %d" % i] = _option_labels[i].get_rect()
		rects["swipe %d" % i] = _swipes[i].get_rect()

	return rects


# The keys

## E, Enter or a click: tells the page out, or turns to the next page, or
## goes on after the last; on the options, picks the one the wheel is on.
func press_advance() -> void:
	if not _open:
		return

	match _kind:
		&"line", &"sense":
			if _revealing():
				_finish_reveal()
			elif _page < _pages.size() - 1:
				_turn_to(_page + 1)
			else:
				_go_on()
		&"options":
			select(_choice)


## Back (-1) or on (1) a page through the pages of the line already read (the
## wheel over the line, PageUp, PageDown), even while the options are up.
func page_by(step: int) -> void:
	if not _open or _pages.size() < 2 or not (_kind == &"line" or _kind == &"sense" or _kind == &"options"):
		return

	var to := clampi(_page + step, 0, _read)

	if to == _page:
		return

	# (A page left half told counts as read.)
	if _revealing():
		_finish_reveal()

	_turn_to(to)


## Shows page `index`: whole if it was read before, else told out afresh.
func _turn_to(index: int) -> void:
	var fresh := index > _read
	_page = index
	_read = maxi(_read, index)
	_text = _pages[index]
	_words.text = _text
	_shown = 0.0 if fresh else float(_text.length())
	_words.visible_characters = int(_shown)

	if fresh and _kind == &"line":
		shade.speaking(true)

	_show_more()
	_layout(_screen())


## Picks option `index` (1-4, a click): its effects, then on.
func select(index: int) -> void:
	if not _open or _kind != &"options" or _options_age < OPTION_GUARD or index < 0 or index >= _options.size():
		return

	_clear_options()
	_kind = &""
	_show_more()
	shade.end_line()
	conversation.choose(index)

	if _open and not conversation.is_over():
		conversation.advance()


## Moves the choice (the wheel, the mouse): the new one paints in afresh.
## Only while options are up (after a choice their swipes are gone).
func choose_by_pointing(index: int) -> void:
	if _kind != &"options" or index == _choice or index < 0 or index >= _options.size() or index >= _swipes.size():
		return

	_choice = index
	_swipe_reveal[index] = 0.0
	_style_options()
	# The list scrolls at once to keep it in view (not a frame later).
	_layout(_screen())


## The mouse came over option `index`'s swipe: chosen, unless the list just
## scrolled it under a mouse that has not moved since.
func _on_hover(index: int) -> void:
	if get_viewport() != null and get_viewport().get_mouse_position() == _scroll_mouse:
		return

	choose_by_pointing(index)


## The options in view now, by their index (all of them unless they scroll).
func options_in_view() -> Array[int]:
	var out: Array[int] = []

	for i in range(_scroll, mini(_scroll + _in_view, _options.size())):
		out.append(i)

	return out


func _go_on() -> void:
	shade.end_line()
	conversation.advance()


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return

	var key := event as InputEventKey

	# 1-9 on the number row or the numpad, by where the key sits (any layout).
	if key != null and key.pressed and not key.echo:
		var number := _number_of(key)

		if number > 0:
			select(number - 1)
			get_viewport().set_input_as_handled()
			return

		# PageUp and PageDown turn the line's pages; Enter is E.
		var which := key.keycode if key.keycode != KEY_NONE else key.physical_keycode

		if which == KEY_PAGEUP or which == KEY_PAGEDOWN:
			page_by(-1 if which == KEY_PAGEUP else 1)
			get_viewport().set_input_as_handled()
			return

		if which == KEY_ENTER or which == KEY_KP_ENTER:
			press_advance()
			get_viewport().set_input_as_handled()
			return

	var button := event as InputEventMouseButton

	if button == null or not button.pressed:
		return

	match button.button_index:
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
			# Over the line (or anywhere while no options are up), a line in
			# pages turns them; else the wheel moves the choice.
			if _pages.size() > 1 and (_kind != &"options" or _over_line(button.position)):
				page_by(-1 if button.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
			else:
				_wheel(button)

			get_viewport().set_input_as_handled()
		MOUSE_BUTTON_LEFT:
			# On the options a click picks the one under it (its own input).
			if _kind != &"options":
				press_advance()

			get_viewport().set_input_as_handled()


## The wheel moves the choice a row, stopping at the first and the last
## (ruling R22: the list scrolls, so it does not wrap round); the list
## scrolls with it.
func _wheel(button: InputEventMouseButton) -> void:
	if _kind == &"options" and not _options.is_empty():
		var step := -1 if button.button_index == MOUSE_BUTTON_WHEEL_UP else 1
		choose_by_pointing(clampi(_choice + step, 0, _options.size() - 1))


## Whether `point` (the box's canvas units) lies over the line's area.
func _over_line(point: Vector2) -> bool:
	return (_plan.get("line_area", Rect2()) as Rect2).has_point(point)


## The number 1-9 a key is, by its physical key (the number row or the
## numpad), or 0.
static func _number_of(key: InputEventKey) -> int:
	var physical := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode

	if physical >= KEY_1 and physical <= KEY_9:
		return physical - KEY_1 + 1

	if physical >= KEY_KP_1 and physical <= KEY_KP_9:
		return physical - KEY_KP_1 + 1

	return 0


# Every frame

func _physics_process(delta: float) -> void:
	if not _open:
		return

	if not is_instance_valid(player) or not is_instance_valid(shade) or player.is_dead:
		interrupt()
		return

	if _kind == &"options":
		_options_age += delta

	# Turning away: back, held (a press begun since the talk opened).
	if not Input.is_action_pressed("move_back"):
		_back_armed = true

	if _back_armed and Input.is_action_pressed("move_back"):
		_back_held += delta

		if _back_held >= WALK_AWAY:
			conversation.walk_off()
			close()
			return
	else:
		_back_held = 0.0

	# (Not the press that opened it.)
	if Input.is_action_just_pressed("frob") and Engine.get_physics_frames() > _opened_frame:
		press_advance()

	if _kind == &"pause":
		_pause_left -= delta

		if _pause_left <= 0.0:
			_kind = &""
			conversation.advance()


func _process(delta: float) -> void:
	_since += delta

	if _closing:
		_lift(delta)
		return

	if not _open or not is_instance_valid(player) or not is_instance_valid(shade):
		return

	_paint_in(delta)
	# The living painting follows the shade, and a little the mouse.
	var screen := _screen()
	var mouse := (get_viewport().get_mouse_position() / screen - Vector2(0.5, 0.5)) * 2.0 if screen.x > 0.0 else Vector2.ZERO
	skin.animate(delta, shade.shade_state() if shade.has_method("shade_state") else &"calm", mouse)

	# The line is told once its part of the panel is down.
	if _revealing() and _panel_reveal >= WORDS_FROM:
		_shown = minf(_shown + REVEAL_CPS * delta, float(_text.length()))

		if not _revealing():
			shade.speaking(false)

	_words.visible_characters = int(_shown)
	_face_speaker(delta)
	_place_portrait_camera()
	_render_portrait(delta)
	_layout(_screen())

	# The mouse is yours while there are options to point at.
	var wanted := Input.MOUSE_MODE_VISIBLE if _kind == &"options" else Input.MOUSE_MODE_CAPTURED

	if Input.mouse_mode != wanted:
		Input.mouse_mode = wanted


## Opening: the panel, the portrait a little after, the words once the panel
## is down, each swipe in turn, each option's words once its swipe is.
func _paint_in(delta: float) -> void:
	_panel_reveal = clampf(_since / PANEL_TIME, 0.0, 1.0)
	_portrait_reveal = clampf((_since - PORTRAIT_LAG) / PANEL_TIME, 0.0, 1.0)
	_words_ink = move_toward(_words_ink, 1.0 if _panel_reveal >= WORDS_FROM else 0.0, delta / INK_TIME)

	for i in _swipes.size():
		var rate := 1.0 / (CHOSEN_TIME if i == _choice and _options_age > SWIPE_TIME + SWIPE_STAGGER * i else SWIPE_TIME)
		var wait := SWIPE_STAGGER * i if _options_age < SWIPE_TIME + SWIPE_STAGGER * i else 0.0

		if _panel_reveal >= WORDS_FROM and _options_age >= wait:
			_swipe_reveal[i] = minf(_swipe_reveal[i] + rate * delta, 1.0)

		_option_ink[i] = move_toward(_option_ink[i], 1.0 if _swipe_reveal[i] >= 0.7 else 0.0, delta / INK_TIME)

	_send_reveals()


## Closing: the same paint lifting off, faster; then gone.
func _lift(delta: float) -> void:
	var rate := delta / CLOSE_TIME
	_panel_reveal = maxf(_panel_reveal - rate, 0.0)
	_portrait_reveal = maxf(_portrait_reveal - rate, 0.0)
	_words_ink = move_toward(_words_ink, 0.0, delta / INK_TIME)

	for i in _swipes.size():
		_swipe_reveal[i] = maxf(_swipe_reveal[i] - rate * 1.4, 0.0)
		_option_ink[i] = move_toward(_option_ink[i], 0.0, delta / INK_TIME)

	_send_reveals()

	if _panel_reveal <= 0.0 and _portrait_reveal <= 0.0:
		_gone()


func _send_reveals() -> void:
	if _panel == null:
		return

	(_panel.material as ShaderMaterial).set_shader_parameter(&"reveal", _panel_reveal)
	(_portrait.material as ShaderMaterial).set_shader_parameter(&"reveal", _portrait_reveal)
	_shadow.modulate.a = maxf(_panel_reveal, _portrait_reveal)
	_name.modulate.a = _words_ink
	_words.modulate.a = _words_ink
	# The more-marker paints in with the words, and breathes gently.
	var breath := 0.5 + 0.5 * sin(_since * TAU * MORE_PULSE)
	_more.modulate.a = _words_ink * lerpf(MORE_LEAST, 1.0, breath)

	for i in _swipes.size():
		(_swipes[i].material as ShaderMaterial).set_shader_parameter(&"reveal", _swipe_reveal[i])
		_option_labels[i].modulate.a = _option_ink[i]


## The view eases round to the speaker, looking a little under the head so
## the head stands HEAD_ABOVE_PANEL over the panel's top on the screen (not
## behind the panel); the speaker turns to your eyes.
func _face_speaker(delta: float) -> void:
	var neck: Node3D = player.get_node("Neck")
	var to: Vector3 = shade.head_point() - neck.global_position
	var flat := Vector2(to.x, to.z).length()

	if flat < 0.05:
		return

	var k := 1.0 - exp(-TURN_EASE * delta)
	var limit := deg_to_rad(float(player.get("max_pitch_degrees")))
	var pitch := atan2(to.y, flat) - _below_head()
	player.rotation.y = lerp_angle(player.rotation.y, atan2(-to.x, -to.z), k)
	neck.rotation.x = lerpf(neck.rotation.x, clampf(pitch, -limit, limit), k)
	shade.face(_eye())


## How far under the speaker's head the view looks (rad) to put the head
## HEAD_ABOVE_PANEL above the panel's top: the head's height above the
## screen's middle, through the lens.
func _below_head() -> float:
	var camera := get_viewport().get_camera_3d() if get_viewport() != null else null

	if camera == null or _plan.is_empty():
		return 0.0

	var screen := _screen()
	var half := screen.y * 0.5
	var wanted: float = (_plan["panel"] as Rect2).position.y - HEAD_ABOVE_PANEL * float(_plan["scale"])
	var half_fov := deg_to_rad(camera.fov) * 0.5

	# A lens that keeps its width: its height's half angle from the width's.
	if camera.keep_aspect == Camera3D.KEEP_WIDTH and screen.x > 0.0:
		half_fov = atan(tan(half_fov) * screen.y / screen.x)

	return atan((half - wanted) / half * tan(half_fov))


func _eye() -> Vector3:
	return (player.get_node("Neck") as Node3D).global_position


## The portrait's camera: before the face, toward whoever it talks to.
func _place_portrait_camera() -> void:
	if _camera == null:
		return

	var head: Vector3 = shade.head_point()
	var toward := _eye() - head
	toward.y = 0.0

	if toward.length() < 0.05:
		toward = Vector3.BACK

	var at := head + toward.normalized() * PORTRAIT_DISTANCE
	var look := head - Vector3.UP * PORTRAIT_DROP
	_camera.global_transform = Transform3D(Basis.looking_at(look - at, Vector3.UP), at)


## The live portrait renders PORTRAIT_HZ times a second, once each time.
func _render_portrait(delta: float) -> void:
	if _viewport == null:
		return

	_portrait_wait -= delta

	if _portrait_wait <= 0.0001:
		_portrait_wait = maxf(_portrait_wait + 1.0 / PORTRAIT_HZ, 0.0)
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		_portrait_renders += 1


## The world's environment for the live portrait, made lean: no volumetric
## fog, SSAO, SSR or SSIL, its glow modest (the world's own is untouched).
## Null if the world has none.
func _lean_environment() -> Environment:
	var source: Environment = null
	var view := get_viewport()

	if view != null:
		var eye := view.get_camera_3d()
		source = eye.environment if eye != null and eye.environment != null else null

		if source == null and view.find_world_3d() != null:
			source = view.find_world_3d().environment

		if source == null and view.find_world_3d() != null:
			source = view.find_world_3d().fallback_environment

	if source == null:
		return null

	var lean := source.duplicate() as Environment
	lean.volumetric_fog_enabled = false
	lean.ssao_enabled = false
	lean.ssr_enabled = false
	lean.ssil_enabled = false
	lean.glow_intensity = minf(lean.glow_intensity, PORTRAIT_GLOW)
	lean.glow_bloom = minf(lean.glow_bloom, PORTRAIT_BLOOM)
	return lean


# What the conversation says

func _on_line(speaker: String, text: String, _cues: Array) -> void:
	_show(&"line", speaker, text)
	shade.speaking(true)
	Sfx.play(shade, StringName("murmur" + _voice), shade.head_point())


func _on_sense(school: String, text: String) -> void:
	_show(&"sense", school, text)
	Sfx.play(shade, StringName("hm" + _voice), shade.head_point())


func _on_paused(seconds: float) -> void:
	_kind = &"pause"
	_pause_left = seconds
	_text = ""
	_said = ""
	_set_pages(_paginate("", _screen().y))
	_page = 0
	_read = 0
	_shown = 0.0
	_words.text = ""
	_show_more()
	shade.speaking(false)


func _on_options(list: Array) -> void:
	_options = list
	_choice = 0
	_scroll = 0
	_scroll_mouse = Vector2(-1e9, -1e9)
	_options_age = 0.0
	_kind = &"options"
	_show_more()
	_build_options(list)
	_layout(_screen())


func _on_cue(what: StringName) -> void:
	shade.cue(what)


func _on_resting(state: StringName) -> void:
	shade.set_resting(state)


func _on_ended(_how: StringName) -> void:
	close()


func _show(kind: StringName, speaker: String, text: String) -> void:
	_kind = kind
	# In pages that fit the line's area on this screen, the first told out.
	_said = text
	_paged_for = _screen().y
	_set_pages(_paginate(text, _paged_for))
	_page = 0
	_read = 0
	_text = _pages[0]
	_shown = 0.0
	_words.text = _text
	_words.visible_characters = 0
	# An inner voice wears its school's ink and doubling (cochineal if it
	# names none the box knows).
	var inner := kind == &"sense"
	_words_school = speaker if inner and SCHOOL_LOOK.has(speaker) else ""
	var look: Dictionary = SCHOOL_LOOK.get(_words_school, {})
	var ink: Color = look.get("ink", COCHINEAL) if inner else CREAM
	_words.add_theme_color_override("font_color", ink)
	_double(_words, _words_school)
	_name.text = speaker.to_upper()
	_name.add_theme_color_override("font_color", ink if inner else MARIGOLD)
	_double(_name, _words_school)
	_more.add_theme_color_override("font_color", ink)
	_show_more()


## The more-marker shows while more pages of the line remain (not paused).
func _show_more() -> void:
	if _more == null or not is_instance_valid(_more):
		return

	var talking := _kind == &"line" or _kind == &"sense" or _kind == &"options"
	_more.visible = not _paused_words and talking and _page < _pages.size() - 1


func _revealing() -> bool:
	return (_kind == &"line" or _kind == &"sense") and _shown < float(_text.length())


func _finish_reveal() -> void:
	_shown = float(_text.length())
	shade.speaking(false)


# Building (a skin replaces these and plan())

func _build() -> void:
	_font = _serif(400, false)
	_bold = _serif(700, false)
	_italic = _serif(400, true)

	_root = Control.new()
	_root.name = "Talk"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_shadow()
	_build_panel()
	_build_portrait()
	_build_words()
	_send_reveals()


static func _serif(weight: int, italic: bool) -> SystemFont:
	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(FONT_NAMES)
	serif.font_weight = weight
	serif.font_italic = italic
	return serif


## A painted picture: talk_paint over a TextureRect, sampled at full
## resolution, filtered, only ever scaled down.
func _painted(texture: Texture2D, picture: Vector2, pad: float, seed_value: float) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = PAINT
	material.set_shader_parameter(&"picture_size", picture)
	material.set_shader_parameter(&"pad", pad)
	material.set_shader_parameter(&"fray_soft", FRAY_SOFT)
	material.set_shader_parameter(&"seed", seed_value)
	material.set_shader_parameter(&"reveal_seed", _seed + seed_value)
	rect.material = material
	return rect


## A blank to draw a shader over (a TextureRect draws nothing without one):
## white and whole, so it lends the shader no colour and takes no alpha.
static func _blank() -> Texture2D:
	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return ImageTexture.create_from_image(image)


func _build_shadow() -> void:
	_shadow = ColorRect.new()
	_shadow.name = "Shadow"
	_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = Shader.new()
	# A rounded box, softened about `blur` px: the pair seated in the world.
	material.shader.code = """shader_type canvas_item;
uniform vec2 size = vec2(100.0);
uniform vec4 box = vec4(0.0);
uniform float radius = 40.0;
uniform float blur = 40.0;
uniform vec3 tint = vec3(0.0);
uniform float strength = 0.59;
void fragment() {
	vec2 p = UV * size;
	vec2 centre = (box.xy + box.zw) * 0.5;
	vec2 half_size = (box.zw - box.xy) * 0.5;
	vec2 q = abs(p - centre) - half_size + radius;
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
	COLOR = vec4(tint, (1.0 - smoothstep(-blur, blur, d)) * strength * COLOR.a);
}
"""
	material.set_shader_parameter(&"tint", Vector3(SHADOW.r, SHADOW.g, SHADOW.b))
	_shadow.material = material
	_root.add_child(_shadow)


func _build_panel() -> void:
	var picture := Vector2(PANEL_WIDE, PANEL_WIDE / skin.panel_aspect())
	_panel = _painted(skin.backdrop if skin.backdrop != null else _blank(), picture, PANEL_PAD, 11.0)
	_panel.name = "Panel"
	var material := _panel.material as ShaderMaterial
	material.set_shader_parameter(&"procedural", skin.backdrop == null)
	var pool: Rect2 = skin.pool
	material.set_shader_parameter(&"pool", Vector4(pool.position.x, pool.position.y, pool.end.x, pool.end.y))
	material.set_shader_parameter(&"pool_strength", skin.pool_strength)
	skin.dress_panel(material, shade.dialogue.get("colour", Color(1.0, 0.62, 0.22)) if is_instance_valid(shade) else Color(1.0, 0.62, 0.22))
	_root.add_child(_panel)


func _build_portrait() -> void:
	var texture: Texture2D = skin.portrait

	# The plain skin: the shade's own head, live, rendered at the size it
	# shows (never scaled up).
	if texture == null:
		_viewport = SubViewport.new()
		_viewport.name = "Portrait"
		_viewport.size = Vector2i(320, 470)
		# Rendered PORTRAIT_HZ times a second (_render_portrait), not every
		# frame; no positional shadows (the world's lamps light it unshadowed).
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		_viewport.positional_shadow_atlas_size = 0
		add_child(_viewport)
		_camera = Camera3D.new()
		_camera.fov = PORTRAIT_FOV
		_camera.near = 0.05
		# The world, the speaker and its wisps; never the player's hands
		# (they would cross the speaker's face) or the lightgem's probe.
		_camera.cull_mask = Layers.WORLD_ALL | Layers.ACTORS | Layers.FX
		_camera.far = PORTRAIT_FAR
		_camera.environment = _lean_environment()
		_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		_viewport.add_child(_camera)
		_camera.current = true
		texture = _viewport.get_texture()

	var picture := Vector2(PORTRAIT_TALL * skin.face_aspect(), PORTRAIT_TALL)
	_portrait = _painted(texture, picture, PORTRAIT_PAD, 4.0)
	_portrait.name = "Portrait"
	skin.dress_portrait(_portrait.material)
	_root.add_child(_portrait)


func _build_words() -> void:
	_name = Label.new()
	_name.name = "Name"
	_name.add_theme_font_override("font", _bold)
	_name.add_theme_color_override("font_color", MARIGOLD)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_name)

	_words = Label.new()
	_words.name = "Line"
	_words.add_theme_font_override("font", _font)
	_words.add_theme_color_override("font_color", CREAM)
	_words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_words.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_words)

	_more = Label.new()
	_more.name = "More"
	_more.text = MORE_TEXT
	_more.add_theme_font_override("font", _font)
	_more.add_theme_color_override("font_color", CREAM)
	_more.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_more.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_more.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_more.visible = false
	_root.add_child(_more)


func _build_options(list: Array) -> void:
	_clear_options()

	for i in list.size():
		var swipe := TextureRect.new()
		swipe.name = "Swipe%d" % (i + 1)
		swipe.texture = _blank()
		swipe.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		swipe.stretch_mode = TextureRect.STRETCH_SCALE
		swipe.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		swipe.mouse_filter = Control.MOUSE_FILTER_STOP
		swipe.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		swipe.gui_input.connect(_on_option_input.bind(i))
		swipe.mouse_entered.connect(_on_hover.bind(i))
		var material := ShaderMaterial.new()
		material.shader = SWIPE
		material.set_shader_parameter(&"seed", 20.0 + i + _seed)
		material.set_shader_parameter(&"paint_dark", Vector3(skin.paint_dark.r, skin.paint_dark.g, skin.paint_dark.b))
		material.set_shader_parameter(&"paint_warm", Vector3(skin.paint_warm.r, skin.paint_warm.g, skin.paint_warm.b))

		if skin.cursor != null:
			material.set_shader_parameter(&"use_cursor", true)
			material.set_shader_parameter(&"cursor", skin.cursor)
			material.set_shader_parameter(&"cursor_tip", skin.cursor_tip)
			material.set_shader_parameter(&"cursor_aspect", float(skin.cursor.get_width()) / float(skin.cursor.get_height()))
			skin.dress_swipe(material)

		swipe.material = material
		_root.add_child(swipe)
		_swipes.append(swipe)
		_swipe_reveal.append(0.0)

		var label := Label.new()
		label.name = "Option%d" % (i + 1)
		label.text = String(list[i]["text"])
		label.add_theme_font_override("font", _italic)
		label.add_theme_font_size_override("font_size", roundi(OPTION_SIZE * _scale()))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.modulate.a = 0.0
		_root.add_child(label)
		_option_labels.append(label)
		_option_ink.append(0.0)

	_fade_top = _build_fade("FadeTop", false)
	_fade_bottom = _build_fade("FadeBottom", true)
	_style_options()


## A painted fade over the options' edge where more are hidden beyond it: the
## panel's dark paint deepening outward in dry bristle streaks, three small
## marigold dabs at its middle. `down`: under the list (else over it).
func _build_fade(fade_name: String, down: bool) -> TextureRect:
	var fade := TextureRect.new()
	fade.name = fade_name
	fade.texture = _blank()
	fade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fade.stretch_mode = TextureRect.STRETCH_SCALE
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.visible = false
	var material := ShaderMaterial.new()
	material.shader = FADE
	material.set_shader_parameter(&"down", down)
	material.set_shader_parameter(&"seed", _seed + (7.0 if down else 3.0))
	material.set_shader_parameter(&"paint", Vector3(skin.paint_dark.r, skin.paint_dark.g, skin.paint_dark.b) * 0.22)
	material.set_shader_parameter(&"dab", Vector3(MARIGOLD.r, MARIGOLD.g, MARIGOLD.b))
	fade.material = material
	_root.add_child(fade)
	return fade


## Each option's swipe and ink: the chosen one warm with the marker and dark
## ink; the rest dim, marigold or (special) cochineal. A special option of a
## school wears that school's swipe and ink, chosen or not.
func _style_options() -> void:
	for i in _swipes.size():
		var chosen := i == _choice
		var material := _swipes[i].material as ShaderMaterial
		var school := String(_options[i].get("school", "")) if i < _options.size() else ""
		school = school if SCHOOL_LOOK.has(school) else ""
		material.set_shader_parameter(&"school", DialogueBook.SCHOOLS.find(school) + 1 if school != "" else 0)
		material.set_shader_parameter(&"warm", chosen)
		material.set_shader_parameter(&"light", 1.1 if chosen else 0.5)
		material.set_shader_parameter(&"alpha_scale", 0.95 if chosen else 0.9)
		var region: Rect2 = skin.warm_region if chosen else skin.dark_region
		var painted: bool = skin.backdrop != null and region.has_area()
		material.set_shader_parameter(&"use_paint", painted)

		if painted:
			material.set_shader_parameter(&"paint", skin.backdrop)
			material.set_shader_parameter(&"region", Vector4(region.position.x, region.position.y, region.size.x, region.size.y))

		var special := bool(_options[i].get("special", false)) if i < _options.size() else false
		var ink := DARK_INK if chosen else (COCHINEAL if special else MARIGOLD)

		if school != "":
			ink = SCHOOL_LOOK[school]["chosen"] if chosen else SCHOOL_LOOK[school]["ink"]

		_option_labels[i].add_theme_color_override("font_color", ink)
		_double(_option_labels[i], school)


## The school's doubling on `label` (none: "" or a school the box lacks).
func _double(label: Label, school: String) -> void:
	var look: Dictionary = SCHOOL_LOOK.get(school, {})
	var offset: Vector2 = look.get("offset", Vector2.ZERO) * _scale()
	label.add_theme_color_override("font_shadow_color", look.get("double", Color(0, 0, 0, 0)))
	label.add_theme_constant_override("shadow_offset_x", int(signf(offset.x) * maxf(1.0, roundf(absf(offset.x)))) if offset.x != 0.0 else 0)
	label.add_theme_constant_override("shadow_offset_y", int(signf(offset.y) * maxf(1.0, roundf(absf(offset.y)))) if offset.y != 0.0 else 0)
	label.add_theme_constant_override("shadow_outline_size", 0)


func _clear_options() -> void:
	for node in _swipes:
		node.queue_free()

	for node in _option_labels:
		node.queue_free()

	for node in [_fade_top, _fade_bottom]:
		if is_instance_valid(node):
			node.queue_free()

	_fade_top = null
	_fade_bottom = null
	_in_view = 0

	_swipes.clear()
	_option_labels.clear()
	_swipe_reveal.clear()
	_option_ink.clear()


func _on_option_input(event: InputEvent, index: int) -> void:
	var button := event as InputEventMouseButton

	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		select(index)
		get_viewport().set_input_as_handled()
	# The wheel over a swipe (which stops the mouse's events) turns the list too.
	elif button != null and button.pressed and (button.button_index == MOUSE_BUTTON_WHEEL_UP or button.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		_wheel(button)
		get_viewport().set_input_as_handled()


# Placing (draft 28)

func _screen() -> Vector2:
	return get_viewport().get_visible_rect().size if get_viewport() != null else Vector2(1152, 648)


## How much the 1080p numbers are scaled on this screen.
func _scale() -> float:
	return _screen_height / 1080.0


var _screen_height := 1080.0


## Draft 28 on a screen this size (px or canvas units: everything scales by
## its height over 1080): the panel and the portrait, the name, the line and
## the options' words, each option's swipe, and the chosen swipe's marker.
func plan(screen: Vector2) -> Dictionary:
	var k := screen.y / 1080.0
	var wide := PANEL_WIDE * k
	var tall := wide / skin.panel_aspect()
	var face_tall := PORTRAIT_TALL * k
	var face_wide := face_tall * skin.face_aspect()
	var overlap := PORTRAIT_OVERLAP * k
	var pair := face_wide - overlap + wide
	var left := (screen.x - pair) * 0.5 + face_wide - overlap
	var top := screen.y - tall + PANEL_DROP * k
	var panel := Rect2(left, top, wide, tall)
	var portrait := Rect2(left - face_wide + overlap, top - PORTRAIT_RISE * k, face_wide, face_tall)

	# The line (its page shown): as many lines as it wraps to; more than three
	# push the options down by as many steps. A line in pages (each fitting
	# the area) keeps the options where its fullest page would have them, so
	# turning its pages back and on never moves them.
	var lines := _line_count(_text)
	var held := lines

	if _pages.size() > 1 and _page_lines.size() == _pages.size():
		lines = _page_lines[_page]
		held = _page_lines.max()

	var line := Rect2(left + (PANEL_WIDE - LINE_WIDE) * 0.5 * k, top + LINE_AT * k, LINE_WIDE * k, LINE_STEP * k * lines)
	var name_rect := Rect2(left, top + NAME_AT * k, wide, 34.0 * k)

	# The options' column: the longest option's words (at 1080p, so it
	# scales exactly) plus COLUMN_MORE.
	var longest := 0.0

	for option in _options:
		longest = maxf(longest, _option_wide(String(option["text"])))

	var column := ceilf(longest) + COLUMN_MORE
	var x := left + ((PANEL_WIDE - column) * 0.5 + OPTION_INDENT) * k
	var y := top + (OPTIONS_AT + LINE_STEP * maxi(0, held - 3)) * k
	# The middle of a row's words under its top (their ascent to descent):
	# every swipe is centred on it.
	var middle := _row_middle()
	var fit := _fit((screen.y - y) / k - OPTIONS_MARGIN, _options.size(), middle)

	# Scrolling, the top fade stands over the first row: the list steps down
	# as far as it must for the fade to clear the spoken line.
	if int(fit["in_view"]) < _options.size():
		var fade_from := (y - top) / k + middle - CHOSEN_TALL * 0.5 * _thin(OPTION_STEP_LEAST) - FADE_TALL
		var under := LINE_AT + LINE_STEP * held + 2.0 - fade_from

		if under > 0.0:
			y += under * k
			fit = _fit((screen.y - y) / k - OPTIONS_MARGIN, _options.size(), middle)

	var step: float = fit["step"]
	var thin := _thin(step)
	var in_view: int = fit["in_view"]
	# The window of rows in view: where it was, moved just enough to hold the
	# chosen one.
	var first := clampi(_scroll, 0, maxi(0, _options.size() - in_view))

	if _choice < first:
		first = _choice
	elif _choice >= first + in_view:
		first = _choice - in_view + 1

	var words := []
	var swipes := []

	for i in _options.size():
		var at := y + step * k * (i - first)
		var mid := at + middle * k
		words.append(Rect2(x, at, column * k, 36.0 * k))

		if i == _choice:
			swipes.append(Rect2(x - OPTION_INDENT * k, mid - CHOSEN_TALL * 0.5 * thin * k, (column + MARKER_WIDE - 20.0) * k,
				CHOSEN_TALL * thin * k))
		else:
			swipes.append(Rect2(x - OPTION_INDENT * k, mid - SWIPE_TALL * 0.5 * thin * k, column * k, SWIPE_TALL * thin * k))

	# The fades: just over the first row in view's (chosen) swipe, just
	# under the last's.
	var fade_wide := (column + MARKER_WIDE - 20.0) * k
	var reach := CHOSEN_TALL * 0.5 * thin
	var fade_top := Rect2(x - OPTION_INDENT * k, y + (middle - reach - FADE_TALL) * k, fade_wide, FADE_TALL * k)
	var fade_bottom := Rect2(x - OPTION_INDENT * k, y + (step * (in_view - 1) + middle + reach) * k, fade_wide, FADE_TALL * k)

	# The line's area, the wheel's for its pages: the line's width (and its
	# marker's) from LINE_AT down to the options' first row, never over the
	# top row's swipe or fade.
	var area_foot := top + OPTIONS_AT * k

	if not swipes.is_empty():
		area_foot = minf(area_foot, (swipes[first] as Rect2).position.y)

	if in_view < _options.size():
		area_foot = minf(area_foot, fade_top.position.y)

	var line_area := Rect2(line.position, Vector2((LINE_WIDE + MORE_GAP + MORE_WIDE) * k, area_foot - line.position.y))
	# The more-marker: right of the line's width, on the fullest page's last
	# line (inside the area, above the options and their fade).
	var more := Rect2(line.end.x + MORE_GAP * k, top + (LINE_AT + LINE_STEP * (held - 1)) * k, MORE_WIDE * k, LINE_STEP * k)

	var shadow_box := Rect2(Vector2(portrait.position.x - 10.0 * k, top - 90.0 * k), Vector2.ZERO)
	shadow_box.end = Vector2(left + wide + 20.0 * k, screen.y + 40.0 * k)
	return {"scale": k, "panel": panel, "portrait": portrait, "name": name_rect, "line": line, "options": words, "swipes": swipes,
		"column": column, "shadow": shadow_box, "step": step, "first": first, "in_view": in_view, "fade_top": fade_top,
		"fade_bottom": fade_bottom, "line_area": line_area, "more": more}


## How `count` options sit in `room` (px at 1080p, from the first row's top to
## the lowest a row's swipe may reach): at OPTION_STEP if they all fit, closer
## (down to OPTION_STEP_LEAST, the swipes thinner with it) if that fits them,
## else at the least step with as many in view as fit. A row reaches `middle`
## (its words' middle) and half the chosen swipe under its top.
static func _fit(room: float, count: int, middle := 15.0) -> Dictionary:
	if count <= 1:
		return {"step": OPTION_STEP, "in_view": count}

	var rows := float(count - 1)
	var half := CHOSEN_TALL * 0.5
	# The swipes thinning with the step; past SWIPE_THIN_LEAST, as thin as
	# they get.
	var step := (room - middle) / (rows + half / OPTION_STEP)

	if step < SWIPE_THIN_LEAST * OPTION_STEP:
		step = (room - middle - half * SWIPE_THIN_LEAST) / rows

	step = minf(step, OPTION_STEP)

	if step >= OPTION_STEP_LEAST:
		return {"step": step, "in_view": count}

	var foot := middle + half * _thin(OPTION_STEP_LEAST)
	var in_view := clampi(int(floor((room - foot) / OPTION_STEP_LEAST)) + 1, 1, count)
	return {"step": OPTION_STEP_LEAST, "in_view": in_view}


## How thin the swipes are at `step`: as much as the step is closed up, but
## never below SWIPE_THIN_LEAST (their painted band still holds the words).
static func _thin(step: float) -> float:
	return clampf(step / OPTION_STEP, SWIPE_THIN_LEAST, 1.0)


## How many lines `text` wraps to as the spoken line (measured once a text).
func _line_count(text: String) -> int:
	if _font == null or text == "":
		return 1

	var key := "line " + text

	if not _measured.has(key):
		_measures += 1
		var high := _font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, LINE_WIDE, LINE_SIZE).y
		_measured[key] = maxi(1, int(round(high / _font.get_height(LINE_SIZE))))

	return _measured[key]


## The spoken line's spacing between its lines at type size `size` on a
## screen scaled `k`: its lines LINE_STEP apart.
func _line_spacing(size: int, k: float) -> int:
	return roundi(LINE_STEP * k - _font.get_height(size))


## `text` broken into pages that each fit the line's area (LINE_AT down to
## OPTIONS_AT) as the line's label draws it on a screen `height` tall: its
## type at that size, wrapped as it wraps (word bounds, a word too long for
## the width broken), its lines LINE_STEP apart. A page ends where its last
## line ends, or at the last sentence's end on that last line.
## {pages, starts (where each begins in `text`), lines (each one's)};
## measured once a text and screen.
func _paginate(text: String, height: float) -> Dictionary:
	var key := "pages %d %s" % [int(height), text]

	if _measured.has(key):
		return _measured[key]

	var pages: Array[String] = []
	var starts: Array[int] = []
	var lines: Array[int] = []

	if _font == null or text.strip_edges() == "":
		pages.append(text)
		starts.append(0)
		lines.append(1)
		return {"pages": pages, "starts": starts, "lines": lines}

	_measures += 1
	var k := height / 1080.0
	var size := roundi(LINE_SIZE * k)
	var spacing := float(_line_spacing(size, k))
	var room := (OPTIONS_AT - LINE_AT) * k
	var at := 0

	while at < text.length():
		# (A page begins at a word, never at the space before it.)
		while at < text.length() and " \t\n".contains(text[at]):
			at += 1

		if at >= text.length():
			break

		var rest := text.substr(at)
		var paragraph := TextParagraph.new()
		paragraph.width = LINE_WIDE * k
		paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
		paragraph.add_string(rest, _font, size)
		var count := paragraph.get_line_count()
		var fit := 0
		var high := 0.0

		while fit < count:
			var more := paragraph.get_line_size(fit).y + (spacing if fit > 0 else 0.0)

			if fit > 0 and high + more > room + 0.01:
				break

			high += more
			fit += 1

		var cut := rest.length()

		if fit < count:
			cut = paragraph.get_line_range(fit - 1).y
			# (A sentence ending on its last line, so a page is never left
			# half empty for one.)
			var stop := _sentence_end(rest, paragraph.get_line_range(fit - 1).x, cut) if fit > 1 else -1

			if stop > 0:
				cut = stop

		var wraps := 0

		for i in count:
			if paragraph.get_line_range(i).x < cut:
				wraps += 1

		var words := rest.substr(0, cut).strip_edges()

		if words != "":
			pages.append(words)
			starts.append(at)
			lines.append(maxi(1, wraps))

		at += maxi(cut, 1)

	# A line that fits one page is shown as it was written.
	if pages.size() <= 1:
		pages.assign([text])
		starts.assign([0])
		lines.assign([lines[0] if not lines.is_empty() else 1])

	_measured[key] = {"pages": pages, "starts": starts, "lines": lines}
	return _measured[key]


## Just past the last sentence's end in `text` between `from` and `to` (its
## stop, then any closing marks, then a space or the end), or -1.
static func _sentence_end(text: String, from: int, to: int) -> int:
	for i in range(mini(to, text.length()) - 1, maxi(from, 1) - 1, -1):
		if not ".!?…".contains(text[i]):
			continue

		var j := i + 1

		while j < text.length() and "\"'”’»)]>".contains(text[j]):
			j += 1

		if j <= to and (j >= text.length() or " \t\n".contains(text[j])):
			return j

	return -1


func _set_pages(paged: Dictionary) -> void:
	_pages = paged["pages"]
	_page_starts = paged["starts"]
	_page_lines = paged["lines"]


## The line broken again for a screen `height` tall: the page shown and the
## furthest read kept by where they began in the line.
func _repage(height: float) -> void:
	_paged_for = height

	if _pages.is_empty():
		return

	var was := _page_starts[mini(_page, _page_starts.size() - 1)]
	var furthest := _page_starts[mini(_read, _page_starts.size() - 1)]
	var told := _shown >= float(_text.length())
	_set_pages(_paginate(_said, height))
	_page = _page_at(was)
	_read = maxi(_page_at(furthest), _page)
	_text = _pages[_page]
	_words.text = _text
	_shown = float(_text.length()) if told or _page < _read else minf(_shown, float(_text.length()))
	_words.visible_characters = int(_shown)
	_show_more()


## The page that holds the line's letter `offset`.
func _page_at(offset: int) -> int:
	var index := 0

	for i in _page_starts.size():
		if _page_starts[i] <= offset:
			index = i

	return index


## How wide `text` is as an option at 1080p (px; measured once a text).
func _option_wide(text: String) -> float:
	if _italic == null:
		return 0.0

	var key := "option " + text

	if not _measured.has(key):
		_measures += 1
		_measured[key] = _italic.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, OPTION_SIZE).x

	return _measured[key]


## The middle of an option's words under its row's top (px at 1080p): half
## their ascent to descent.
func _row_middle() -> float:
	if _italic == null:
		return 15.0

	if not _measured.has("middle"):
		_measures += 1
		_measured["middle"] = _italic.get_height(OPTION_SIZE) * 0.5

	return _measured["middle"]


## Places every part by plan() for a screen this size.
func _layout(screen: Vector2) -> void:
	_screen_height = screen.y

	# The type's size changes with the screen's height: the line broken again
	# where it now wraps.
	if _said != "" and screen.y != _paged_for:
		_repage(screen.y)

	var p := plan(screen)
	_plan = p
	var k: float = p["scale"]

	# The shadow, softened 40 px round a box with 40 px corners.
	var shadow: Rect2 = p["shadow"]
	var room := 80.0 * k
	_shadow.position = shadow.position - Vector2(room, room)
	_shadow.size = shadow.size + Vector2(room, room) * 2.0
	var shade_material := _shadow.material as ShaderMaterial
	shade_material.set_shader_parameter(&"size", _shadow.size)
	shade_material.set_shader_parameter(&"box", Vector4(room, room, room + shadow.size.x, room + shadow.size.y))
	shade_material.set_shader_parameter(&"radius", 40.0 * k)
	shade_material.set_shader_parameter(&"blur", 40.0 * k)

	_place(_panel, (p["panel"] as Rect2).grow(PANEL_PAD * k))
	_place(_portrait, (p["portrait"] as Rect2).grow(PORTRAIT_PAD * k))
	_fit_portrait_render(p["portrait"])

	# The type is sized only when the screen's size changes (a theme change
	# every frame would re-shape every label every frame).
	var retype := screen != _typed_for
	_typed_for = screen

	if retype:
		_name.add_theme_font_size_override("font_size", roundi(NAME_SIZE * k))
		var line_size := roundi(LINE_SIZE * k)
		_words.add_theme_font_size_override("font_size", line_size)
		_words.add_theme_constant_override("line_spacing", _line_spacing(line_size, k))
		_more.add_theme_font_size_override("font_size", line_size)
		_double(_words, _words_school)
		_double(_name, _words_school)

		for i in _option_labels.size():
			_double(_option_labels[i], String(_options[i].get("school", "")) if i < _options.size() else "")

	# The options' window: scrolled (the mouse noted, so a row scrolled under
	# it is not taken as pointed at), its rows and fades shown to match.
	var first: int = p["first"]
	var in_view: int = p["in_view"]

	if first != _scroll or in_view != _in_view:
		if first != _scroll and get_viewport() != null:
			_scroll_mouse = get_viewport().get_mouse_position()

		_scroll = first
		_in_view = in_view
		_show_rows()

	if is_instance_valid(_fade_top):
		_place(_fade_top, p["fade_top"])
		_place(_fade_bottom, p["fade_bottom"])

	_place(_name, p["name"])
	_place(_words, p["line"])
	_place(_more, p["more"])

	var words: Array = p["options"]
	var swipes: Array = p["swipes"]

	for i in _option_labels.size():
		var label := _option_labels[i]

		if retype:
			label.add_theme_font_size_override("font_size", roundi(OPTION_SIZE * k))

		_place(label, words[i])
		var swipe := _swipes[i]
		var rect: Rect2 = swipes[i]
		_place(swipe, rect)
		var material := swipe.material as ShaderMaterial
		material.set_shader_parameter(&"swipe_size", rect.size / k)
		material.set_shader_parameter(&"marker_x", float(p["column"]) - 26.0 if i == _choice else -1.0)
		material.set_shader_parameter(&"marker_width", MARKER_WIDE)


func _place(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size


## The live portrait renders at the size it shows on the window.
func _fit_portrait_render(rect: Rect2) -> void:
	if _viewport == null or not is_inside_tree():
		return

	var to_window := get_viewport().get_final_transform().get_scale()
	var wanted := Vector2i((rect.size * to_window).ceil()).clamp(Vector2i(16, 16), Vector2i(PORTRAIT_MOST, PORTRAIT_MOST))

	if (wanted - _viewport.size).abs().x > 1 or (wanted - _viewport.size).abs().y > 1:
		_viewport.size = wanted
