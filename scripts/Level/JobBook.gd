extends RefCounted
## The job's words (the harbour's job spec, section 3): data/jobs/*.job, the
## user's to write. mission.job holds the commission and the city's own goals
## and shouts; each district's file (named after it) its goals, the pencil
## notes, the readables' texts and its gates. Read here into one library:
##
##   == goal seal                     a block: its kind and id
##   kind: main                       key: value
##   done: took(the_seal)
##   intent: what the words must say  (for the writer; never shown)
##   text: <<take the seal>>          or `text:` alone, then lines to the next ==
##
## A text still in <<...>> is a placeholder: the game shows it as written and
## placeholders() lists it. Errors carry file:line. docs/systems/jobs.md is
## the writer's guide.

const Districts := preload("res://scripts/Level/Districts.gd")

const FOLDER := "res://data/jobs"
const KINDS := [&"letter", &"goal", &"note", &"readable", &"gate", &"shout"]
## The keys each kind of block may have.
const KEYS := {
	&"letter": ["intent", "text"],
	&"goal": ["kind", "shows", "done", "note", "intent", "text"],
	&"note": ["intent", "text"],
	&"readable": ["note", "intent", "text"],
	&"gate": ["exits", "needs", "intent", "text"],
	&"shout": ["intent", "text"],
}
const GOAL_KINDS := ["main", "side"]
## What a condition's terms may ask: took(<loot>), arrived(<district>),
## done(<goal>), loot>=<value>, not(<term>).
const TERMS := ["took", "arrived", "done"]
## A placeholder's marks.
const OPEN := "<<"
const CLOSE := ">>"
## The file whose goals come first and belong to no district.
const MISSION := "mission"

static var _library := {}


## The library, read once (reload() to read again).
static func library() -> Dictionary:
	if _library.is_empty():
		_library = load_dir()

		for error in _library["errors"]:
			push_error("job: " + String(error))

	return _library


static func reload() -> void:
	_library = {}


## One file's blocks: {"entries": [{kind, id, keys, text, source, sources}],
## "errors": ["file:line: ..."]}. `file` is what errors and sources name.
static func parse(text: String, file: String) -> Dictionary:
	var out := {"entries": [], "errors": []}
	var block := {}
	var in_text := false
	var text_lines: Array[String] = []
	var number := 0
	var seen := {}
	var skipping := false

	for raw in text.split("\n"):
		number += 1
		var line := String(raw).strip_edges()
		var at := "%s:%d" % [file, number]

		if line.begins_with("=="):
			_finish(block, text_lines, in_text, out)
			block = {}
			in_text = false
			text_lines = []
			skipping = false
			var words := line.trim_prefix("==").strip_edges().split(" ", false)
			var kind := StringName(words[0]) if words.size() > 0 else &""

			if not KINDS.has(kind):
				out["errors"].append("%s: no such kind of block '%s' (%s)" % [at, kind, ", ".join(KINDS)])
				skipping = true
				continue

			var id := String(words[1]) if words.size() > 1 else ""

			if words.size() != 2 or not _is_word(id):
				out["errors"].append("%s: a block is '== <kind> <id>', the id of letters, digits and _" % at)
				skipping = true
				continue

			var key := "%s %s" % [kind, id]

			if seen.has(key):
				out["errors"].append("%s: the %s '%s' is there twice (also at %s)" % [at, kind, id, seen[key]])
				skipping = true
				continue

			seen[key] = at
			block = {"kind": kind, "id": id, "keys": {}, "text": "", "source": at, "sources": {}}
			continue

		if skipping:
			continue

		if in_text:
			if not line.begins_with("#"):
				text_lines.append(line)

			continue

		if line == "" or line.begins_with("#"):
			continue

		if block.is_empty():
			out["errors"].append("%s: a line outside any block" % at)
			continue

		var colon := line.find(":")
		var name := line.substr(0, colon).strip_edges() if colon > 0 else ""

		if name == "" or not (KEYS[block["kind"]] as Array).has(name):
			out["errors"].append("%s: a %s has no key '%s' (%s)" % [at, block["kind"], name if name != "" else line,
				", ".join(KEYS[block["kind"]])])
			continue

		var value := line.substr(colon + 1).strip_edges()
		block["sources"][name] = at

		if name == "text":
			if value == "":
				in_text = true
			else:
				block["text"] = value
				block["keys"]["text"] = value

			continue

		block["keys"][name] = value
		var problem := ""

		match name:
			"shows", "done":
				problem = condition_error(value)
			"kind":
				problem = "" if GOAL_KINDS.has(value) else "a goal is main or side ('%s')" % value
			"note", "needs":
				problem = "" if _is_word(value) else "'%s' is not an id" % value
			"exits":
				problem = _exits_error(value)

		if problem != "":
			out["errors"].append("%s: %s" % [at, problem])
			block["bad"] = true

	_finish(block, text_lines, in_text, out)
	return out


## Every .job file in `path`, read into one library: {"letter": entry,
## "goals": [goal...] (mission's first, then the districts in the registry's
## order), "notes", "readables", "shouts": {id: entry}, "gates": [gate...],
## "errors": [...]}. Every entry: {id, block (its kind of block), district,
## text, intent, note, source, sources}; a goal's also kind (main or side),
## shows, done; a gate's exits and needs.
static func load_dir(path := FOLDER) -> Dictionary:
	var files := Array(DirAccess.get_files_at(path)).filter(func(f): return String(f).ends_with(".job"))
	var order: Array = [MISSION] + Array(Districts.registry()["districts"].keys())
	files.sort_custom(func(a: String, b: String) -> bool:
		var ia := order.find(a.get_basename())
		var ib := order.find(b.get_basename())
		ia = ia if ia >= 0 else order.size()
		ib = ib if ib >= 0 else order.size()
		return ia < ib if ia != ib else a < b)
	var parsed := []

	for file in files:
		parsed.append([String(file).get_basename(), parse(FileAccess.get_file_as_string(path.path_join(file)), String(file))])

	return _gather(parsed)


## One file's text read as the whole library would be, its references to
## its own notes and goals checked (a test's).
static func check_alone(text: String, file: String) -> Dictionary:
	return _gather([[file.get_basename(), parse(text, file)]])


## "" if `condition` uses only the words a condition may, else what is wrong.
static func condition_error(condition: String) -> String:
	if condition.strip_edges() == "":
		return "an empty condition"

	for term in condition.split(","):
		var problem := _term_error(String(term).strip_edges())

		if problem != "":
			return problem

	return ""


## The texts still to write: "<file>:<line> <kind> <id>" each.
static func placeholders(lib := {}) -> Array[String]:
	if lib.is_empty():
		lib = library()

	var out: Array[String] = []

	for entry in all_entries(lib):
		if is_placeholder(String(entry["text"])):
			out.append("%s %s %s" % [entry["source"], entry["block"], entry["id"]])

	return out


static func is_placeholder(text: String) -> bool:
	var t := text.strip_edges()
	return t.begins_with(OPEN) and t.ends_with(CLOSE)


## Every block of the library, the letter first.
static func all_entries(lib: Dictionary) -> Array:
	var out := []

	if not (lib.get("letter", {}) as Dictionary).is_empty():
		out.append(lib["letter"])

	out.append_array(lib.get("goals", []))

	for kind in ["notes", "readables", "shouts"]:
		out.append_array((lib.get(kind, {}) as Dictionary).values())

	out.append_array(lib.get("gates", []))
	return out


static func note_text(id: String) -> String:
	return String((library()["notes"] as Dictionary).get(id, {}).get("text", OPEN + id + CLOSE))


## A readable's block ({id, text, note, intent, source}), or {}.
static func readable(slot: String) -> Dictionary:
	return (library()["readables"] as Dictionary).get(slot, {})


static func shout(id: String) -> String:
	return String((library()["shouts"] as Dictionary).get(id, {}).get("text", ""))


static func _finish(block: Dictionary, text_lines: Array[String], in_text: bool, out: Dictionary) -> void:
	if block.is_empty():
		return

	if in_text:
		while not text_lines.is_empty() and text_lines[0] == "":
			text_lines.pop_front()

		while not text_lines.is_empty() and text_lines[-1] == "":
			text_lines.pop_back()

		block["text"] = "\n".join(text_lines)
		block["keys"]["text"] = block["text"]

	if block.has("bad"):
		block.erase("bad")
		out["entries"].append(block)
		return

	if String(block["text"]) == "":
		out["errors"].append("%s: the %s '%s' has no text" % [block["source"], block["kind"], block["id"]])
	elif block["kind"] == &"goal" and not (block["keys"] as Dictionary).has("done"):
		out["errors"].append("%s: the goal '%s' has no done:" % [block["source"], block["id"]])
	elif block["kind"] == &"gate" and not ((block["keys"] as Dictionary).has("exits") and (block["keys"] as Dictionary).has("needs")):
		out["errors"].append("%s: the gate '%s' needs exits: and needs:" % [block["source"], block["id"]])

	out["entries"].append(block)


## The files' blocks gathered and their references checked: [[district,
## parsed]...] in order.
static func _gather(parsed: Array) -> Dictionary:
	var lib := {"letter": {}, "goals": [], "notes": {}, "readables": {}, "shouts": {}, "gates": [], "errors": []}

	for pair in parsed:
		var district := StringName(pair[0])
		lib["errors"].append_array(pair[1]["errors"])

		for entry in pair[1]["entries"]:
			var keys: Dictionary = entry["keys"]
			var made := {"id": entry["id"], "block": entry["kind"], "district": district, "text": entry["text"],
				"intent": String(keys.get("intent", "")), "note": String(keys.get("note", "")), "source": entry["source"],
				"sources": entry["sources"]}

			match entry["kind"]:
				&"letter":
					if not (lib["letter"] as Dictionary).is_empty():
						lib["errors"].append("%s: a second letter (the first at %s)" % [entry["source"], lib["letter"]["source"]])
					else:
						lib["letter"] = made
				&"goal":
					made["kind"] = StringName(keys.get("kind", "main"))
					made["shows"] = String(keys.get("shows", ""))
					made["done"] = String(keys.get("done", ""))

					if (lib["goals"] as Array).any(func(g): return g["id"] == made["id"]):
						lib["errors"].append("%s: a second goal '%s'" % [entry["source"], made["id"]])
					else:
						lib["goals"].append(made)
				&"gate":
					made["exits"] = Array(String(keys.get("exits", "")).split(",", false)).map(func(e): return String(e).strip_edges())
					made["needs"] = String(keys.get("needs", ""))
					lib["gates"].append(made)
				_:
					var into: Dictionary = lib[{&"note": "notes", &"readable": "readables", &"shout": "shouts"}[entry["kind"]]]

					if into.has(made["id"]):
						lib["errors"].append("%s: a second %s '%s' (the first at %s)" % [entry["source"], entry["kind"], made["id"],
							into[made["id"]]["source"]])
					else:
						into[made["id"]] = made

	_link(lib)
	return lib


## The references between blocks: notes named, goals needed or asked after.
static func _link(lib: Dictionary) -> void:
	var goal_ids: Array = (lib["goals"] as Array).map(func(g): return g["id"])

	for entry in lib["goals"] + (lib["readables"] as Dictionary).values():
		var note := String(entry["note"])

		if note != "" and not (lib["notes"] as Dictionary).has(note):
			lib["errors"].append("%s: no note '%s'" % [entry["sources"].get("note", entry["source"]), note])

	for goal in lib["goals"]:
		for key in ["shows", "done"]:
			for found in RegEx.create_from_string("done\\(([A-Za-z0-9_]+)\\)").search_all(String(goal[key])):
				if not goal_ids.has(found.get_string(1)):
					lib["errors"].append("%s: no goal '%s'" % [goal["sources"].get(key, goal["source"]), found.get_string(1)])

	for gate in lib["gates"]:
		if not goal_ids.has(gate["needs"]):
			lib["errors"].append("%s: no goal '%s'" % [gate["sources"].get("needs", gate["source"]), gate["needs"]])


static func _term_error(term: String) -> String:
	if term.begins_with("not(") and term.ends_with(")"):
		return _term_error(term.substr(4, term.length() - 5).strip_edges())

	if RegEx.create_from_string("^loot\\s*>=\\s*[0-9]+$").search(term) != null:
		return ""

	var called := RegEx.create_from_string("^([a-z_]+)\\(([A-Za-z0-9_]+)\\)$").search(term)

	if called != null and TERMS.has(called.get_string(1)):
		return ""

	return "'%s' is not a condition (took(x), arrived(x), done(x), loot>=n, not(...))" % term


static func _exits_error(value: String) -> String:
	for part in value.split(","):
		var exit := String(part).strip_edges()

		if not (_is_word(exit) or RegEx.create_from_string("^to\\([A-Za-z0-9_]+\\)$").search(exit) != null):
			return "'%s' is neither an exit's name nor to(<district>)" % exit

	return ""


static func _is_word(text: String) -> bool:
	return RegEx.create_from_string("^[A-Za-z0-9_]+$").search(text) != null
