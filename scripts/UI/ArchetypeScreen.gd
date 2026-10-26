class_name ArchetypeScreen
extends Control
## After New Game: who you are, as a triptych over the living city. The card
## you point at wakes with its effects; Enter or a click on it confirms,
## Escape or Back returns to the menu.
const IDS: Array[StringName] = [&"derive", &"thaumaturge", &"factotum"]
## The user's own names and lines.
const NAMES := ["Derivé", "Thaumaturge", "Factotum"]
const LINES := [
	"Guided by their body, their gut instinct and their fists.",
	"Manipulates people and the occult as easily as he breathes.",
	"Knowledge and experience are both your weapon and your tools to traverse the world.",
]
const TOP := 120.0
const GAP := 96.0
## The cards rise in one after another, this far apart (s), from this far below.
const RISE_STAGGER := 0.12
const RISE := 40.0
## The confirm's surge holds this long before the game starts (s).
const SURGE_HOLD := 0.55

signal chosen(index: int)
signal confirmed(index: int)
signal back_out

var cards: Array[ArchetypeCard] = []
var selected := -1
var opened := false
var confirming := false
var back: MenuWord
var _effects: Control

func _init() -> void:
	name = "Archetypes"
	size = MainMenu.DESIGN
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Every card's effects on one layer behind every portrait.
	_effects = Control.new()
	_effects.name = "Effects"
	_effects.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_effects)
	for i in range(IDS.size()):
		var card := ArchetypeCard.new()
		card.configure(i, NAMES[i], LINES[i])
		_effects.add_child(card.fx)
		add_child(card)
		card.hovered.connect(select)
		card.clicked.connect(_clicked)
		cards.append(card)
	back = MenuWord.new()
	back.configure("Back", -1, MainMenu.GOLD)
	back.position = Vector2(MainMenu.WORD_X, 812)
	back.size = Vector2(200, 52)
	back.focus_mode = Control.FOCUS_NONE
	back.mouse_entered.connect(func(): back.set_selected(true))
	back.mouse_exited.connect(func(): back.set_selected(false))
	back.pressed.connect(go_back)
	add_child(back)
	_arrange(false)
	hide()

func open() -> void:
	opened = true
	confirming = false
	selected = -1
	show()
	back.modulate.a = 0.0
	back.mouse_filter = Control.MOUSE_FILTER_STOP
	MenuMotion.tween(back).tween_property(back, "modulate:a", MenuWord.DIM, MenuMotion.BLOOM)
	for card in cards:
		card.set_chosen(false)
		card.wake = 0.0
		card.surge = 0.0
		card.scale = Vector2.ONE * ArchetypeCard.ASLEEP_SCALE
		card.mouse_filter = Control.MOUSE_FILTER_STOP
	_arrange(false)
	for card in cards:
		var home := card.position.y
		card.position.y = home + RISE
		card.modulate.a = 0.0
		var rise := MenuMotion.tween(card)
		rise.tween_property(card, "position:y", home, MenuMotion.BLOOM).set_delay(card.index * RISE_STAGGER)
		rise.tween_property(card, "modulate:a", 1.0, MenuMotion.BLOOM).set_delay(card.index * RISE_STAGGER)
	select(1)

func close() -> void:
	opened = false
	confirming = false
	for card in cards:
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fade := MenuMotion.tween(self)
	for card in cards:
		fade.tween_property(card, "modulate:a", 0.0, MenuMotion.FADE)
	fade.tween_property(back, "modulate:a", 0.0, MenuMotion.FADE)
	fade.chain().tween_callback(func(): if not opened: hide())

## The one path for mouse and keys: wakes one card.
func select(index: int) -> void:
	if not opened or confirming or index == selected or index < 0 or index >= cards.size():
		return
	selected = index
	for card in cards:
		card.set_chosen(card.index == index)
	_arrange(true)
	chosen.emit(index)

func _clicked(index: int) -> void:
	if index != selected:
		select(index)
	else:
		confirm()

## The chosen card surges and the others fall away; then the game begins.
func confirm() -> void:
	if not opened or confirming or selected < 0:
		return
	confirming = true
	var index := selected
	for card in cards:
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if card.index == index:
			card.surge_out()
		else:
			card.fall_away()
	MenuMotion.tween(back).tween_property(back, "modulate:a", 0.0, MenuMotion.FADE)
	await get_tree().create_timer(SURGE_HOLD).timeout
	if opened and confirming:
		confirmed.emit(index)

func go_back() -> void:
	if opened and not confirming:
		back_out.emit()

## Lays the cards out side by side: the chosen one full size, the others
## stepped back, all centred with room between them for the effects.
func _arrange(animate: bool) -> void:
	var widths: Array[float] = []
	var total := GAP * (cards.size() - 1)
	for card in cards:
		var w := ArchetypeCard.SIZE.x * (1.0 if card.index == selected else ArchetypeCard.ASLEEP_SCALE)
		widths.append(w)
		total += w
	var x := MainMenu.DESIGN.x * 0.5 - total * 0.5
	for card in cards:
		var centre := x + widths[card.index] * 0.5
		var to := centre - ArchetypeCard.SIZE.x * 0.5
		if animate:
			MenuMotion.tween(card).tween_property(card, "position:x", to, MenuMotion.BLOOM)
		else:
			card.position = Vector2(to, TOP)
		x += widths[card.index] + GAP

func _unhandled_key_input(event: InputEvent) -> void:
	if not opened or not event.is_pressed() or event.is_echo():
		return
	var key := (event as InputEventKey).physical_keycode if event is InputEventKey else KEY_NONE
	if event.is_action_pressed("ui_left") or key == KEY_A:
		select(maxi(selected - 1, 0))
	elif event.is_action_pressed("ui_right") or key == KEY_D:
		select(mini(selected + 1, cards.size() - 1))
	elif event.is_action_pressed("ui_accept"):
		confirm()
	elif event.is_action_pressed("ui_cancel"):
		go_back()
	else:
		return
	get_viewport().set_input_as_handled()
