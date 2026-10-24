extends RefCounted
## What the people of the city remember of the player (the talk and quests
## spec, section 2), kept for good: it outlives a mission's job, a district
## and a loading screen (CityState holds it and never resets it). Per
## character: the flags set, the items given, the mood, whether they have met.
## Besides: the talk goals shown and finished, the pencil notes learnt. The
## words are DialogueBook's; this is only what happened.
##
## It reads conditions in Terms' words. A bare said(x), gave(x), mood>=n or
## met is about the character the condition is asked for; a dotted said(c.x)
## or mood(c)>=n about the one named. It answers has(x) and purse>=n from the
## player's inventory (false with none), and took(x), arrived(x) and loot>=n
## from the job.

const DialogueBook := preload("res://scripts/Level/DialogueBook.gd")
const Terms := preload("res://scripts/Level/Terms.gd")

## A talk goal came onto the letter; one was finished (the signal is not
## `goal_done`: goal_done(id) below answers whether one is); a pencil note was
## added.
signal goal_shown(id: String)
signal goal_finished(id: String)
signal noted(id: String)

## {character: [flag...]}: what they were told or did (set(f), clear(f)).
var said := {}
## {character: [item...]}: what the player gave them.
var gave := {}
## {character: int}
var moods := {}
var met: Array[String] = []
var goals_shown: Array[String] = []
var goals_done: Array[String] = []
var notes: Array[String] = []

## The job (took, arrived, loot, done) and the player's inventory (has,
## purse); either may be null, and then what it answers is false.
var job: RefCounted = null
var inventory: Node = null


# What they remember

func set_flag(character: String, flag: String) -> void:
	var flags: Array = said.get(character, [])

	if not flags.has(flag):
		flags.append(flag)

	said[character] = flags


func clear_flag(character: String, flag: String) -> void:
	if said.has(character):
		(said[character] as Array).erase(flag)


func add_mood(character: String, by: int) -> void:
	moods[character] = mood_of(character) + by


func mood_of(character: String) -> int:
	return int(moods.get(character, 0))


func meet(character: String) -> void:
	if not met.has(character):
		met.append(character)


## `character` was given `item` (once; it stays said).
func record_gave(character: String, item: String) -> void:
	var items: Array = gave.get(character, [])

	if not items.has(item):
		items.append(item)

	gave[character] = items


# Conditions

## Whether a condition (Terms' words) holds, said about `character` ("" for
## one with none, as in a .job file: then only the dotted words mean anything).
func holds(condition: String, character: String) -> bool:
	for term in Terms.split_top(condition):
		if not self.term(String(term), character):
			return false

	return true


## Whether one term holds.
func term(term: String, character: String) -> bool:
	term = term.strip_edges()

	if term.begins_with("not(") and term.ends_with(")"):
		return not self.term(term.substr(4, term.length() - 5), character)

	var number := RegEx.create_from_string("^(loot|purse|mood(?:\\(([A-Za-z0-9_]+)\\))?)\\s*(>=|<=)\\s*(-?[0-9]+)$").search(term)

	if number != null:
		return _compare(number, character)

	if term == "met":
		return character != "" and met.has(character)

	var called := RegEx.create_from_string("^([a-z_]+)\\(([A-Za-z0-9_]+)(?:\\.([A-Za-z0-9_]+))?\\)$").search(term)

	if called == null:
		return false

	var word := called.get_string(1)
	var who := called.get_string(2) if called.get_string(3) != "" else character
	var what := called.get_string(3) if called.get_string(3) != "" else called.get_string(2)

	match word:
		"said":
			return who != "" and (said.get(who, []) as Array).has(what)
		"gave":
			return who != "" and (gave.get(who, []) as Array).has(what)
		"has":
			return _has(what)
		"done":
			return goal_done(what) or (job != null and job.done.has(what))
		"took":
			return job != null and job.took.has(what)
		"arrived":
			return job != null and job.arrived.has(what)

	return false


# Goals and notes

## A talk goal onto the letter, once, its note learnt. One the words do not
## have is a mistake in them.
func show_goal(id: String) -> void:
	if _goal(id).is_empty():
		push_error("people: no goal '%s'" % id)
		return

	if goals_shown.has(id):
		return

	goals_shown.append(id)
	goal_shown.emit(id)
	var note := String(_goal(id).get("note", ""))

	if note != "":
		learn(note)


## A talk goal finished, once.
func finish_goal(id: String) -> void:
	if _goal(id).is_empty():
		push_error("people: no goal '%s'" % id)
		return

	if goals_done.has(id):
		return

	goals_done.append(id)
	goal_finished.emit(id)


func goal_done(id: String) -> bool:
	return goals_done.has(id)


## A pencil note, once; one the words do not have is a mistake in them.
func learn(note_id: String) -> void:
	if not (DialogueBook.library()["notes"] as Dictionary).has(note_id):
		push_error("people: no note '%s'" % note_id)
		return

	if notes.has(note_id):
		return

	notes.append(note_id)
	noted.emit(note_id)


## The talk goals as they now stand: shown when `shows:` holds, finished when
## `done:` holds, again until nothing changes (one finished may show the
## next). A goal with no `shows:` waits for the goal(g) effect: talk goals
## belong to people, not to districts. A goal finished stays finished, and is
## not shown again.
func refresh() -> void:
	var changed := true

	while changed:
		changed = false

		for goal in DialogueBook.library()["goals"]:
			var id := String(goal["id"])
			var owner := String(goal["owner"])

			if goals_done.has(id):
				continue

			if not goals_shown.has(id):
				if String(goal["shows"]) == "" or not holds(String(goal["shows"]), owner):
					continue

				show_goal(id)
				changed = true

			if String(goal["done"]) != "" and holds(String(goal["done"]), owner):
				finish_goal(id)
				changed = true


## The talk goals on the letter: [{id, kind, text, done}], in the library's
## order.
func goals_listed() -> Array:
	var out := []

	for goal in DialogueBook.library()["goals"]:
		if goals_shown.has(String(goal["id"])):
			out.append({"id": goal["id"], "kind": goal["kind"], "text": goal["text"], "done": goals_done.has(String(goal["id"]))})

	return out


## A new mission: the goals done come off the letter; everything else, the
## goals still open too, is kept.
func begin_mission() -> void:
	goals_shown = goals_shown.filter(func(id): return not goals_done.has(id))


# Saving

func save_state() -> Dictionary:
	return {"said": said.duplicate(true), "gave": gave.duplicate(true), "moods": moods.duplicate(), "met": met.duplicate(),
		"goals_shown": goals_shown.duplicate(), "goals_done": goals_done.duplicate(), "notes": notes.duplicate()}


func load_state(state: Dictionary) -> void:
	said = (state.get("said", {}) as Dictionary).duplicate(true)
	gave = (state.get("gave", {}) as Dictionary).duplicate(true)
	moods = (state.get("moods", {}) as Dictionary).duplicate()
	met.assign(state.get("met", []))
	goals_shown.assign(state.get("goals_shown", []))
	goals_done.assign(state.get("goals_done", []))
	notes.assign(state.get("notes", []))


## The library's talk goal `id`, or {}.
func _goal(id: String) -> Dictionary:
	for goal in DialogueBook.library()["goals"]:
		if String(goal["id"]) == id:
			return goal

	return {}


func _has(item: String) -> bool:
	if inventory == null:
		return false

	for entry in inventory.belt:
		if String(entry["id"]) == item and int(entry["count"]) > 0:
			return true

	return inventory.has_key(StringName(item))


## `matched`: a loot/purse/mood comparison (word, mood's character, operator, number).
func _compare(matched: RegExMatch, character: String) -> bool:
	var word := matched.get_string(1)
	var number := matched.get_string(4).to_int()
	var value := 0

	if word == "loot":
		if job == null:
			return false

		value = int(job.loot)
	elif word == "purse":
		if inventory == null:
			return false

		value = int(inventory.purse)
	else:
		var who := matched.get_string(2) if matched.get_string(2) != "" else character

		if who == "":
			return false

		value = mood_of(who)

	return value >= number if matched.get_string(3) == ">=" else value <= number
