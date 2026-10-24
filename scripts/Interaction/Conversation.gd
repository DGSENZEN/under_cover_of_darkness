extends RefCounted
## One talk with one character (the talk and quests spec, section 3): pure
## logic, no nodes, so a test can drive a whole conversation headless. The box
## and the shade only listen to its signals.
##
## start() picks the opener, advance() tells the next thing of the beat (a line,
## an inner voice, a pause, then the options), choose(i) runs the option's
## effects and moves to its beat. Options whose [if] fails are left out without
## a trace. What happens is written to PeopleState (what they remember) and the
## player's Inventory; both are the caller's.

const DialogueBook := preload("res://scripts/Level/DialogueBook.gd")
const Props := preload("res://scripts/Interaction/Props.gd")

## A spoken line, with its cues (the shade hears each of them as `cue` too).
signal line(speaker: String, text: String, cues: Array)
## An inner voice speaks (Sense obsidian: ...).
signal sense(school: String, text: String)
## The talk holds its breath for this long.
signal paused(seconds: float)
## The player may choose: [{text, special, school}], in the order choose(i)
## counts (school: "" unless a special option names one, `> !obsidian`).
signal options(list: Array)
## flare, dim, gutter, calm, nod or shake.
signal cue(what: StringName)
## The shade settles into a state (the shade(...) effect).
signal resting(state: StringName)
signal gave_item(id: String)
signal took_item(id: String)
## The talk is over: &"end", &"walked_off" or &"interrupted".
signal ended(how: StringName)

## What the one option left when every option was filtered out says.
const NOTHING_TO_SAY := "<<…>>"
## Beats entered in one advance() before it gives up (a goto that loops).
const MOST_BEATS := 64

var character: Dictionary
var people: RefCounted
var inventory: Node

var _body: Array = []
var _at := 0
## The options the player may choose from now (the whole option dicts).
var _offered: Array = []
var _waiting := false
var _over := false
var _started := false


func _init(p_character: Dictionary, p_people: RefCounted, p_inventory: Node) -> void:
	character = p_character
	people = p_people
	inventory = p_inventory

	# The conditions has(x) and purse>=n must see the same belt the talk gives to.
	if people.inventory == null:
		people.inventory = inventory


# Telling it

## Picks the first opener whose `when:` holds, then meets them (so `met` is
## false while the opener is picked), and enters it.
func start() -> void:
	if _started:
		return

	_started = true
	var picked := ""

	for opener in character.get("openers", []):
		var when := String(_beat(String(opener)).get("when", ""))

		if when == "" or people.holds(when, _id()):
			picked = String(opener)
			break

	people.meet(_id())
	_changed()

	if picked == "":
		push_error("conversation: %s has no opener whose when: holds" % _id())
		_end(&"end")
		return

	_enter(picked)


## Tells the next thing of the beat: a line, an inner voice, a pause or the
## options. Past the last of a beat with no way on, the talk ends; a goto goes
## on into the next beat.
func advance() -> void:
	if _over or _waiting:
		return

	var beats := 0

	while not _over:
		if _at >= _body.size():
			_end(&"end")
			return

		var item: Dictionary = _body[_at]
		_at += 1

		match String(item["type"]):
			"say":
				var cues: Array = item["cues"]
				line.emit(_said(String(item["speaker"])), _said(String(item["text"])), cues)

				for what in cues:
					cue.emit(what)

				return
			"sense":
				var cond := String(item["if"])

				if cond == "" or people.holds(cond, _id()):
					sense.emit(String(item["school"]), _said(String(item["text"])))
					return
			"pause":
				paused.emit(float(item["seconds"]))
				return
			"option":
				_offer()
				return
			"goto":
				beats += 1

				if beats > MOST_BEATS:
					push_error("conversation: %s loops through its beats without a word" % _id())
					_end(&"end")
					return

				_move(String(item["to"]))


## The player chose option `index` of the last list: its effects, then its
## beat (or the end). The beat's first thing comes with the next advance().
func choose(index: int) -> void:
	if _over or not _waiting or index < 0 or index >= _offered.size():
		return

	var picked: Dictionary = _offered[index]
	_waiting = false
	_offered = []
	_run(picked["do"])
	_move(String(picked["to"]))


## The player turned away: they will remember it (the flag `walked_off`).
func walk_off() -> void:
	if _over:
		return

	people.set_flag(_id(), "walked_off")
	_changed()
	_end(&"walked_off")


## Something else broke it off (a blow, an alarm): nothing is remembered.
func interrupt() -> void:
	if not _over:
		_end(&"interrupted")


func is_waiting_for_choice() -> bool:
	return _waiting and not _over


func is_over() -> bool:
	return _over


# Beats

func _id() -> String:
	return String(character.get("id", ""))


func _beat(id: String) -> Dictionary:
	return (character.get("beats", {}) as Dictionary).get(id, {})


## `to` is a beat's id or "end".
func _move(to: String) -> void:
	if to == DialogueBook.END:
		_end(&"end")
	else:
		_enter(to)


## Into a beat: its `do:` runs now, its body is told from the top.
func _enter(id: String) -> void:
	var beat := _beat(id)

	if beat.is_empty():
		push_error("conversation: %s has no beat '%s'" % [_id(), id])
		_end(&"end")
		return

	_body = beat["body"]
	_at = 0
	_run(beat["do"])


## The options from here on, the ones whose [if] holds. If none does, the one
## way out is left, so the player is never stuck.
func _offer() -> void:
	_offered = []

	for item in _body.slice(_at - 1):
		var option: Dictionary = item

		if String(option["type"]) != "option":
			continue

		var cond := String(option["if"])

		if cond == "" or people.holds(cond, _id()):
			_offered.append(option)

	if _offered.is_empty():
		_offered.append({"text": NOTHING_TO_SAY, "special": false, "to": DialogueBook.END, "do": []})

	_at = _body.size()
	_waiting = true
	options.emit(_offered.map(func(o): return {"text": _said(String(o["text"])), "special": bool(o["special"]),
		"school": String(o.get("school", ""))}))


func _end(how: StringName) -> void:
	_over = true
	_waiting = false
	_offered = []
	ended.emit(how)


# Effects

## Each effect of a list in turn, then the goals and the job look again at what
## has changed.
func _run(effects: Array) -> void:
	if effects.is_empty():
		return

	for effect in effects:
		_apply(String(effect))

	_changed()


## The goals of the people, then those of the job (each refreshes on its own).
func _changed() -> void:
	people.refresh()

	if people.job != null:
		people.job.refresh()


func _apply(effect: String) -> void:
	var called := RegEx.create_from_string("^([a-z_]+)\\((.*)\\)$").search(effect.strip_edges())

	if called == null:
		push_error("conversation: '%s' is not an effect" % effect)
		return

	var arg := called.get_string(2).strip_edges()

	match called.get_string(1):
		"set":
			people.set_flag(_id(), arg)
		"clear":
			people.clear_flag(_id(), arg)
		"mood":
			people.add_mood(_id(), arg.to_int())
		"give":
			_give(arg)
		"take":
			_take(arg)
		"pay":
			if inventory != null:
				inventory.add_loot(arg.to_int())
		"charge":
			# Only what the player has: a short purse pays nothing.
			if inventory != null and inventory.purse >= arg.to_int():
				inventory.purse -= arg.to_int()
				inventory.changed.emit()
		"goal":
			people.show_goal(arg)
		"done":
			people.finish_goal(arg)
		"note":
			people.learn(arg)
		"shade":
			resting.emit(StringName(arg))
		_:
			push_error("conversation: no effect '%s'" % called.get_string(1))


## The item onto the player's belt, with the mesh of its look.
func _give(id: String) -> void:
	if inventory == null:
		return

	var item := DialogueBook.item(id)
	inventory.add_belt_item(StringName(id), String(item.get("name", id)), Props.look_mesh(StringName(item.get("look", &""))))
	gave_item.emit(id)


## One of the item off the belt, remembered as given to them; nothing at all if
## the player has none.
func _take(id: String) -> void:
	if inventory == null or inventory.count_of(StringName(id)) <= 0:
		return

	inventory.take_one(StringName(id))
	people.record_gave(_id(), id)
	took_item.emit(id)


## `text` as spoken: {name} is the character's.
func _said(text: String) -> String:
	return text.replace("{name}", String(character.get("name", "")))
