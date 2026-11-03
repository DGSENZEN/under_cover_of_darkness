extends Control
## The gun, in paint: a blot of ink with the cylinder's six chambers in it,
## each its round's colour, turning as they fire; the shell's stub under them;
## what you packed beside it. Hand-drawn shapes, a little out of true, in the
## talk box's ink and brass. Shown only with the revolver drawn.

const Rounds := preload("res://scripts/Combat/Rounds.gd")
const PrepItems := preload("res://scripts/Hunt/PrepItems.gd")

const INK := Color(0.93, 0.88, 0.78)
const DIM := Color(0.54, 0.5, 0.43)
const BRASS := Color(1.0, 0.78, 0.36)
const BLOT := Color(0.035, 0.03, 0.032, 0.72)
## A fired chamber.
const SPENT := Color(0.17, 0.14, 0.125)
const SHELL := Color(0.62, 0.16, 0.1)
const CHAMBERS := 6
## Where the cylinder sits in the blot, how far out its chambers are, their size.
const WHEEL := Vector2(62.0, 60.0)
const WHEEL_REACH := 26.0
const CHAMBER := 10.0
## The turn after a shot: seconds.
const TURN_TIME := 0.12
## A round switched: the ring called out round the cylinder, in its colour, this long.
const SWITCH_SHOWN := 0.6

var player: CharacterBody3D
var font: Font
var _turn_shown := 0.0
var _switched := 0.0
var _round_was := &""
var _turn_wanted := 0.0
var _loaded_was := -1


func snapshot() -> Dictionary:
	if not is_instance_valid(player) or player.is_dead or not player.combat.gun_drawn():
		return {}

	var gun: Node = player.revolver
	var loaded_now := int(gun.loaded[gun.barrel])
	var in_cylinder := int(gun.loaded[&"cylinder"])
	var colour: Color = Rounds.info(gun.cylinder_round).get("colour", INK)
	var chambers: Array[Color] = []

	for i in CHAMBERS:
		chambers.append(colour if i < in_cylinder else SPENT)

	var items := {}

	for id in player.loadout.items:
		# (A weapon has no count to show.)
		if not PrepItems.info(id).get("weapon", false):
			items[id] = int(player.loadout.item_counts.get(id, 0))

	return {"barrel": gun.barrel, "round": gun.cylinder_round, "loaded": loaded_now, "chambers": chambers,
		"shell": int(gun.loaded[&"shot"]), "reserve": int(player.inventory.ammo.get(gun.shell_stock_id() if gun.barrel == &"shot" else gun.stock_id(), 0)),
		"capacity": 1 if gun.barrel == &"shot" else int(gun.weapon().rounds), "reloading": gun.is_reloading(), "items": items,
		"evil_eye": player.statuses.has(&"evil_eye"), "using": player.loadout.using(), "selected": player.loadout.selected_item(), "switched": _switched}


func _process(delta: float) -> void:
	_turn_shown = move_toward(_turn_shown, _turn_wanted, delta * (TAU / CHAMBERS) / TURN_TIME)
	_switched = move_toward(_switched, 0.0, delta / SWITCH_SHOWN)

	if is_instance_valid(player) and player.revolver != null:
		if _round_was != &"" and player.revolver.cylinder_round != _round_was:
			_switched = 1.0

		_round_was = player.revolver.cylinder_round


func _draw() -> void:
	var state := snapshot()

	if state.is_empty() or font == null:
		return

	# A shot gone: the cylinder comes round one.
	var in_cylinder: int = state["chambers"].filter(func(c): return c != SPENT).size()

	if _loaded_was >= 0 and in_cylinder < _loaded_was:
		_turn_wanted += TAU / CHAMBERS

	_loaded_was = in_cylinder
	_blot(WHEEL + Vector2(6, 0), 54.0, 3.0, BLOT)
	_blot(WHEEL + Vector2(46, 12), 30.0, 9.0, BLOT)
	_dry_strokes()
	var shot_up: bool = state["barrel"] == &"shot"
	var wheel_seen := 0.45 if shot_up else 1.0
	_blot(WHEEL, WHEEL_REACH + CHAMBER + 2.0, 21.0, Color(0.0, 0.0, 0.0, 0.55))

	for i in CHAMBERS:
		var turn := -PI * 0.5 + TAU / CHAMBERS * i + _turn_shown
		var at := WHEEL + Vector2(cos(turn), sin(turn)) * WHEEL_REACH
		var ink: Color = state["chambers"][i]
		ink.a = wheel_seen
		_blot(at, CHAMBER + 1.4, 30.0 + i, Color(0.0, 0.0, 0.0, 0.8 * wheel_seen))
		_blot(at, CHAMBER, 40.0 + i, ink)

		# A live one catches the light.
		if state["chambers"][i] != SPENT:
			draw_circle(at + Vector2(-2.0, -2.5), 1.8, Color(1.0, 0.95, 0.8, 0.5 * wheel_seen))

	_blot(WHEEL, 5.5, 60.0, Color(0.0, 0.0, 0.0, 0.9))

	# The middle wears the loaded round's colour, and calls out a switch.
	var round_ink: Color = Rounds.info(state["round"]).get("colour", INK)
	_blot(WHEEL, 3.6, 61.0, round_ink)

	if _switched > 0.0:
		var ring := round_ink
		ring.a = _switched
		draw_arc(WHEEL, WHEEL_REACH + CHAMBER + 3.0 + (1.0 - _switched) * 9.0, 0.0, TAU, 40, ring, 1.5 + _switched * 2.5, true)

	# The shell's stub below the cylinder, the hammer's nose picking it out.
	var stub := Rect2(WHEEL.x + 40.0, WHEEL.y + 22.0, 28.0, 12.0)
	var loaded_shell: bool = int(state["shell"]) > 0
	_stroke(stub.position + Vector2(0, 5.5), stub.end - Vector2(0, 5.5), 11.0, (SHELL if loaded_shell else SPENT).lightened(0.15 if shot_up else 0.0), 5.0)

	if shot_up:
		draw_line(stub.position + Vector2(-5, -2), stub.position + Vector2(-5, 13), BRASS, 2.0, true)

	# What is left in the pouch.
	var left := str(state["reserve"])
	var at_text := WHEEL + Vector2(42.0, 6.0)
	draw_string_outline(font, at_text, left, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, 5, Color(0, 0, 0, 0.8))
	draw_string(font, at_text, left, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, INK if int(state["reserve"]) > 0 else Color(0.85, 0.33, 0.22))

	if state["reloading"]:
		draw_arc(WHEEL, WHEEL_REACH + CHAMBER + 4.0, -PI * 0.5, PI * 0.9, 24, BRASS, 1.5, true)

	_items(state["items"], state["using"], state["selected"])


## What you packed: a small painted mark for each one left, along the blot's top.
func _items(items: Dictionary, using: StringName, selected: StringName) -> void:
	var x := WHEEL.x + 42.0

	for id in items:
		var colour: Color = PrepItems.info(id).get("colour", INK)

		# What V will use is lit, the rest dim; a brass line under it, even when you have none left.
		if id != selected:
			colour = Color(colour.r * 0.42, colour.g * 0.42, colour.b * 0.42, 0.75)
		else:
			var wide: float = maxf(float(items[id]), 1.0) * 15.0 - 3.0
			draw_line(Vector2(x - 6.0, 36.0), Vector2(x - 6.0 + wide, 36.0), BRASS, 2.0, true)

		for i in int(items[id]):
			_blot(Vector2(x, 26.0), 6.5, 70.0 + i, Color(0.0, 0.0, 0.0, 0.8))
			_blot(Vector2(x, 25.5), 5.0, 80.0 + i, colour)

			# In the hand: picked out in brass.
			if id == using and i == int(items[id]) - 1:
				draw_arc(Vector2(x, 25.5), 8.0, 0.0, TAU, 16, BRASS, 2.0, true)

			x += 15.0

		x += 6.0


## A shape a little out of true, the same every frame for the same `seed_value`.
func _blot(center: Vector2, radius: float, seed_value: float, colour: Color) -> void:
	var points := PackedVector2Array()
	var count := clampi(int(radius * 1.6), 10, 32)

	for i in count:
		var turn := TAU * float(i) / float(count)
		var out := radius * (1.0 + 0.09 * sin(turn * 3.0 + seed_value) + 0.05 * sin(turn * 7.0 + seed_value * 2.3))
		points.append(center + Vector2(cos(turn), sin(turn)) * out)

	draw_colored_polygon(points, colour)


func _stroke(from: Vector2, to: Vector2, width: float, colour: Color, seed_value: float) -> void:
	draw_line(from, to, Color(0.0, 0.0, 0.0, 0.8), width + 3.0, true)
	draw_line(from, to, colour, width, true)
	_blot(from, width * 0.5, seed_value, colour)
	_blot(to, width * 0.5, seed_value + 1.0, colour)


## A few thin hairs the brush dragged out past the blot.
func _dry_strokes() -> void:
	for i in 5:
		var from := WHEEL + Vector2(-30.0 + i * 16.0, 40.0 + sin(i * 2.1) * 6.0)
		draw_line(from, from + Vector2(22.0 + i * 3.0, 7.0 + sin(i * 1.3) * 3.0), Color(BLOT.r, BLOT.g, BLOT.b, 0.4), 1.2, true)
