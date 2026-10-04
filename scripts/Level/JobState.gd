extends RefCounted
## What the player has done of the job (the harbour's job spec, sections 3,
## 7, 8), kept by CityState across the districts: the goals shown and done,
## the pencil notes learnt (in order), the readables read, what was taken,
## the districts reached, each district's facts (a theft noticed) and its
## tally. The words are JobBook's; this is only what happened.

const JobBook := preload("res://scripts/Level/JobBook.gd")

## A goal came onto the letter (one with `shows:`); one was done.
signal goal_shown(id: String)
signal goal_done(id: String, kind: StringName)
## A pencil note was added; a readable read.
signal noted(id: String)
signal read(slot: String)

## The tally's rows: [label, how the row is made]; "x of" rows read
## "<x> of <x>_total".
const ROWS := [["Loot", "loot of"], ["Specials", "specials of"], ["Notes read", "read of"], ["Knocked out", "knockouts"],
	["Killed", "kills"], ["Bodies found", "bodies_found"], ["Times seen", "seen"], ["Alarms", "alarms"], ["Time", "seconds"]]

## The district the player is in (a DistrictMap's), "" out of the city; the
## one he last left through a gate.
var here: StringName = &""
var last_left: StringName = &""
var arrived: Array[String] = []
## Loot taken, by its marker's name; the value of all of it.
var took: Array[String] = []
var loot := 0
var shown: Array[String] = []
var done: Array[String] = []
var notes: Array[String] = []
var read_slots: Array[String] = []
## {district: {fact: value}}: what a district remembers of the job (a
## theft noticed). Kept here, with the rest of the job, across the maps.
var facts := {}
## {district: {key: int}}: its tally.
var tally := {}
## The letter has been raised once (a fresh mission opens with it up).
var letter_opened := false
## The words (JobBook's library).
var book := {}


func _init() -> void:
	reset()


## A new job: nothing done, the words read from `with_book` (default the
## library's).
func reset(with_book := {}) -> void:
	book = with_book if not with_book.is_empty() else JobBook.library()
	here = &""
	last_left = &""
	arrived.clear()
	took.clear()
	loot = 0
	shown.clear()
	done.clear()
	notes.clear()
	read_slots.clear()
	facts = {}
	tally = {}
	letter_opened = false


# What happens

## The player is in `district` (its map is up).
func arrive(district: StringName) -> void:
	here = district

	if not arrived.has(String(district)):
		arrived.append(String(district))

	refresh()


## The player went through a gate out of `district`.
func leave(district: StringName) -> void:
	last_left = district


func took_loot(loot_name: String, value: int) -> void:
	if took.has(loot_name):
		return

	took.append(loot_name)
	loot += value
	refresh()


## A pencil note, once; one the words do not have is a mistake in them.
func learn(note_id: String) -> void:
	if not (book.get("notes", {}) as Dictionary).has(note_id):
		push_error("job: no note '%s'" % note_id)
		return

	if notes.has(note_id):
		return

	notes.append(note_id)
	noted.emit(note_id)


## A readable read, once: counted, its note learnt.
func read_slot(slot: String) -> void:
	if read_slots.has(slot):
		return

	read_slots.append(slot)
	count("read")
	read.emit(slot)
	var note := String((book.get("readables", {}) as Dictionary).get(slot, {}).get("note", ""))

	if note != "":
		learn(note)


## The goals as they now stand: shown when their district is reached (or
## when `shows:` holds: then said, and its note learnt), done when `done:`
## holds. Again until nothing changes (a goal done shows the next).
func refresh() -> void:
	var changed := true

	while changed:
		changed = false

		for goal in book.get("goals", []):
			var id := String(goal["id"])

			if not _listed(goal):
				continue

			if not shown.has(id):
				if String(goal["shows"]) == "":
					shown.append(id)
				elif holds(String(goal["shows"])):
					shown.append(id)
					goal_shown.emit(id)

					if String(goal["note"]) != "":
						learn(String(goal["note"]))
				else:
					continue

				changed = true

			if not done.has(id) and holds(String(goal["done"])):
				done.append(id)
				goal_done.emit(id, StringName(goal["kind"]))
				changed = true


## Whether a condition (JobBook's words) holds now.
func holds(condition: String) -> bool:
	for term in condition.split(",", false):
		if not _term(String(term).strip_edges()):
			return false

	return true


## The goals on the letter: [{id, kind, text, done}], in the book's order.
func goals_listed() -> Array:
	var out := []

	for goal in book.get("goals", []):
		if shown.has(String(goal["id"])):
			out.append({"id": goal["id"], "kind": goal["kind"], "text": goal["text"], "done": done.has(String(goal["id"]))})

	return out


# Facts and the gate

func set_fact(district: StringName, fact_name: StringName, value: Variant) -> void:
	if not facts.has(district):
		facts[district] = {}

	facts[district][fact_name] = value


func fact(district: StringName, fact_name: StringName) -> Variant:
	return (facts.get(district, {}) as Dictionary).get(fact_name)


## A theft found where the player is: true the first time only (counted as
## an alarm then).
func notice_theft() -> bool:
	if fact(here, &"theft_noticed") == true:
		return false

	set_fact(here, &"theft_noticed", true)
	count("alarms")
	return true


## The gate of this district that `exit` belongs to and that is not yet
## met (its `needs` goal not done), or {}.
func gate_for(exit: Node) -> Dictionary:
	var to := "to(%s)" % String(exit.get_meta(&"to", &""))

	for gate in book.get("gates", []):
		if StringName(gate["district"]) != here or done.has(String(gate["needs"])):
			continue

		for named in gate["exits"]:
			if String(named) == String(exit.name) or String(named) == to:
				return gate

	return {}


# The tally

## Adds `by` to a district's count (default: where the player is).
func count(key: String, by := 1, district: StringName = &"") -> void:
	var d := district if district != &"" else here

	if not tally.has(d):
		tally[d] = {}

	tally[d][key] = int(tally[d].get(key, 0)) + by


func set_total(key: String, value: int, district: StringName = &"") -> void:
	var d := district if district != &"" else here

	if not tally.has(d):
		tally[d] = {}

	tally[d][key] = value


func tally_of(district: StringName) -> Dictionary:
	return tally.get(district, {})


## [[label, value]] for the loading screen.
func tally_rows(district: StringName) -> Array:
	var t := tally_of(district)
	var out := []

	for row in ROWS:
		var how := String(row[1])
		var value := ""

		if how.ends_with(" of"):
			var key := how.trim_suffix(" of")
			value = "%d of %d" % [int(t.get(key, 0)), int(t.get(key + "_total", 0))]
		elif how == "seconds":
			var seconds := int(t.get("seconds", 0))
			value = "%d:%02d" % [seconds / 60, seconds % 60]
		else:
			value = str(int(t.get(how, 0)))

		out.append([row[0], value])

	return out


# Saving

func save_state() -> Dictionary:
	return {"last_left": last_left, "arrived": arrived.duplicate(), "took": took.duplicate(), "loot": loot, "shown": shown.duplicate(),
		"done": done.duplicate(), "notes": notes.duplicate(), "read_slots": read_slots.duplicate(), "facts": facts.duplicate(true),
		"tally": tally.duplicate(true), "letter_opened": letter_opened}


func load_state(state: Dictionary) -> void:
	last_left = StringName(state.get("last_left", &""))
	arrived.assign(state.get("arrived", []))
	took.assign(state.get("took", []))
	loot = int(state.get("loot", 0))
	shown.assign(state.get("shown", []))
	done.assign(state.get("done", []))
	notes.assign(state.get("notes", []))
	read_slots.assign(state.get("read_slots", []))
	facts = (state.get("facts", {}) as Dictionary).duplicate(true)
	tally = (state.get("tally", {}) as Dictionary).duplicate(true)
	letter_opened = bool(state.get("letter_opened", false))


func _listed(goal: Dictionary) -> bool:
	var district := String(goal["district"])
	return district == JobBook.MISSION or arrived.has(district)


func _term(term: String) -> bool:
	if term.begins_with("not(") and term.ends_with(")"):
		return not _term(term.substr(4, term.length() - 5).strip_edges())

	if term.begins_with("loot"):
		return loot >= int(term.substr(term.find(">=") + 2).strip_edges())

	var open := term.find("(")
	var word := term.substr(0, open)
	var arg := term.substr(open + 1, term.length() - open - 2)

	match word:
		"took":
			return took.has(arg)
		"arrived":
			return arrived.has(arg)
		"done":
			return done.has(arg)

	return false
