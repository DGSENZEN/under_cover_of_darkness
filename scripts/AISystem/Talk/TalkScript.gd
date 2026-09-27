extends RefCounted
## What the men say to each other, written down: plain-text files in
## data/talk, one conversation to a block, read once at the start
## (`library`). A fault in a file names the file and the line.
##
##   == dice_debt                        a block, by its id (unique across files)
##   when: at_ease, night:early|middle   all must hold; | is "or"
##   cast: A = any; B = owes(A); C? = friend(A)|friend(B)
##                                       the parts; ? may be left empty
##   place: dice                         only chosen there (a gathering, a station)
##   cooldown: 10m                       30s, 10m, or once (a night); else 5m
##   priority: 10                        the higher first
##   group: dice                         all of a group used before any repeats
##   again: yes                          a man may say its lines twice a night
##   A: You still owe me four pennies.   a line: PART [emotes] {if cond}: text
##   B [shrugs]: It's a kind of winning.
##   -- interrupt                        said instead, if it is broken off
##   A: Hush. What was that?
##
## Lines of one part straight after each other, all but the last with an
## {if ...}, are one turn: the first whose condition holds for the speaker is
## said, else the last. The cast sheet is the block "== cast": a line a man,
## "Name: rank 4; kin Jory; captain" (ties: kin, friend, rival, owes, suspects;
## any other word is a trait).
##
## Each conversation comes out as a Dictionary:
##   {id, when, cast, place, cooldown, priority, group, again, lines,
##    interrupt, source, sources (the file:line of each key)}
## where `when` is an Array of terms (each an Array of its alternatives),
## `cast` an Array of {key, optional, reqs} (reqs shaped like `when`), and
## `lines`/`interrupt` Arrays of turns {part, choices: [{if, emotes, text,
## source}]}.

const TalkFactsScript := preload("res://scripts/AISystem/Talk/TalkFacts.gd")

const FOLDER := "res://data/talk"
## Once a night.
const ONCE := -1.0
const DEFAULT_COOLDOWN := 300.0
const PARTS := ["A", "B", "C", "D"]
const EMOTES := ["laughs", "sighs", "nods", "shakes", "shrugs", "spits", "coughs", "drinks", "kicks",
	"whispers", "shouts", "murmurs", "throws", "nudges"]
const EMOTE_PREFIXES := ["points:", "looks:"]
const TIES := ["kin", "friend", "rival", "owes", "suspects"]
## Ties that run both ways.
const MUTUAL := ["kin", "friend", "rival"]
const KEYS := ["when", "cast", "place", "cooldown", "priority", "group", "again"]

static var _library: Dictionary = {}


## Everything in the talk folder, read once.
static func library() -> Dictionary:
	if _library.is_empty():
		_library = load_dir()

	return _library


## Read it all again (the files were changed).
static func reload() -> void:
	_library = {}


## Every .talk file in `path`, merged: {conversations, cast, errors}.
static func load_dir(path := FOLDER) -> Dictionary:
	var merged := {"conversations": [], "cast": {}, "errors": []}
	var seen := {}
	var files := Array(DirAccess.get_files_at(path)).filter(func(f): return String(f).ends_with(".talk"))
	files.sort()

	var read := []

	for file in files:
		var full: String = path.path_join(file)
		read.append(parse(FileAccess.get_file_as_string(full), full))

	var traits := []

	for one in read:
		for man in one["cast"]:
			traits.append_array(one["cast"][man]["traits"])

	for one in read:
		merged["errors"].append_array(one["errors"])

		for c in one["conversations"]:
			merged["errors"].append_array(validate(c, traits))

		for c in one["conversations"]:
			if seen.has(c["id"]):
				merged["errors"].append("%s: the id '%s' is used twice (also at %s)" % [c["source"], c["id"], seen[c["id"]]])
				continue

			seen[c["id"]] = c["source"]
			merged["conversations"].append(c)

		for man in one["cast"]:
			merged["cast"][man] = one["cast"][man]

	_close_ties(merged["cast"])

	for error in merged["errors"]:
		push_error("talk: " + error)

	return merged


## `parse`, and the checks a whole library gets (the traits a requirement may
## name come from the cast sheet in the talk folder, and any in `text`).
static func load_text_for_test(text: String, file: String) -> Dictionary:
	var one := parse(text, file)
	var traits := []

	for sheet in [one["cast"], parse(FileAccess.get_file_as_string(FOLDER.path_join("cast.talk")), "cast.talk")["cast"]]:
		for man in sheet:
			traits.append_array(sheet[man]["traits"])

	for c in one["conversations"]:
		one["errors"].append_array(validate(c, traits))

	return one


## Every condition and requirement of `conv` means something: the faults, by
## file and line.
static func validate(conv: Dictionary, traits: Array) -> Array[String]:
	var errors: Array[String] = []
	var sources: Dictionary = conv.get("sources", {})

	for term in conv["when"]:
		for alt in term:
			if not TalkFactsScript.known(alt, false, traits):
				errors.append("%s: unknown condition '%s'" % [sources.get("when", conv["source"]), alt])

	for part in conv["cast"]:
		for req in part["reqs"]:
			for alt in req:
				if not TalkFactsScript.known(alt, true, traits):
					errors.append("%s: unknown requirement '%s'" % [sources.get("cast", conv["source"]), alt])

	for turn in conv["lines"] + conv["interrupt"]:
		for choice in turn["choices"]:
			if choice["if"] != "" and not TalkFactsScript.known(choice["if"], true, traits):
				errors.append("%s: unknown condition '%s'" % [choice["source"], choice["if"]])

	return errors


## One file's text: {conversations, cast, errors}.
static func parse(text: String, file: String) -> Dictionary:
	var out := {"conversations": [], "cast": {}, "errors": []}
	var ids := {}
	var block: Dictionary = {}
	var in_cast := false
	var interrupting := false
	var number := 0

	for raw in text.split("\n"):
		number += 1
		var line := String(raw).strip_edges()

		if line == "" or line.begins_with("#"):
			continue

		var at := "%s:%d" % [file, number]

		if line.begins_with("=="):
			_finish(block, out)
			block = {}
			interrupting = false
			var id := line.trim_prefix("==").strip_edges()
			in_cast = id == "cast"

			if in_cast:
				continue

			if id == "" or not _is_word(id):
				out["errors"].append("%s: a block needs an id of letters, digits and _ ('%s')" % [at, id])
				continue

			if ids.has(id):
				out["errors"].append("%s: the id '%s' is used twice (also at %s)" % [at, id, ids[id]])
				continue

			ids[id] = at
			block = {"id": id, "when": [], "cast": [], "place": &"", "cooldown": DEFAULT_COOLDOWN, "priority": 0,
				"group": &"", "again": false, "lines": [], "interrupt": [], "source": at, "sources": {}, "_parts": {}}
			continue

		if in_cast:
			_cast_line(line, at, out)
			continue

		if block.is_empty():
			out["errors"].append("%s: a line outside any block" % at)
			continue

		if line == "-- interrupt":
			interrupting = true
			continue

		var colon := line.find(":")

		if colon > 0 and KEYS.has(line.substr(0, colon)):
			block["sources"][line.substr(0, colon)] = at
			_key(block, line.substr(0, colon), line.substr(colon + 1).strip_edges(), at, out)
			continue

		_spoken(block, line, at, out, interrupting)

	_finish(block, out)
	_close_ties(out["cast"])
	return out


## Terms joined by commas, each of alternatives joined by |: "a, b|c" is
## [["a"], ["b", "c"]]. A bare word after "key:value" takes the key:
## "night:early|middle" is ["night:early", "night:middle"].
static func terms(text: String) -> Array:
	var result := []

	for piece in _split_top(text, ","):
		var term := String(piece).strip_edges()

		if term == "":
			continue

		var alternatives: Array[String] = []
		var key := ""

		for option in _split_top(term, "|"):
			var alt := String(option).strip_edges()

			if alt.contains(":") and not alt.contains("("):
				key = alt.substr(0, alt.find(":") + 1)
			elif key != "" and _is_word(alt):
				alt = key + alt

			alternatives.append(alt)

		result.append(alternatives)

	return result


# ---------------------------------------------------------------------------
# Reading a block
# ---------------------------------------------------------------------------

static func _key(block: Dictionary, key: String, value: String, at: String, out: Dictionary) -> void:
	match key:
		"when":
			block["when"] = terms(value)
		"cast":
			for piece in _split_top(value, ";"):
				var part := String(piece).strip_edges()
				var eq := part.find("=")

				if eq < 0:
					out["errors"].append("%s: a part is 'A = requirement' ('%s')" % [at, part])
					continue

				var name := part.substr(0, eq).strip_edges()
				var optional := name.ends_with("?")
				name = name.trim_suffix("?")

				if not PARTS.has(name):
					out["errors"].append("%s: parts are A, B, C and D ('%s')" % [at, name])
					continue

				block["cast"].append({"key": name, "optional": optional, "reqs": terms(part.substr(eq + 1))})
				block["_parts"][name] = true
		"place":
			block["place"] = StringName(value)
		"cooldown":
			var seconds := _duration(value)

			if seconds == -2.0:
				out["errors"].append("%s: a cooldown is like 30s, 10m or once ('%s')" % [at, value])
			else:
				block["cooldown"] = seconds
		"priority":
			if not value.is_valid_int():
				out["errors"].append("%s: a priority is a whole number ('%s')" % [at, value])
			else:
				block["priority"] = int(value)
		"group":
			block["group"] = StringName(value)
		"again":
			block["again"] = value in ["yes", "true"]


## A spoken line: PART [emotes] {if cond}: text.
static func _spoken(block: Dictionary, line: String, at: String, out: Dictionary, interrupting: bool) -> void:
	var pattern := RegEx.create_from_string("^([A-Za-z])\\s*(\\[[^\\]]*\\])?\\s*(\\{if [^}]*\\})?\\s*:\\s*(.*)$")
	var found := pattern.search(line)

	if found == null:
		out["errors"].append("%s: not a line, a key or a block ('%s')" % [at, line])
		return

	var part := found.get_string(1)

	if not block["_parts"].has(part):
		out["errors"].append("%s: the part '%s' is not in the cast" % [at, part])
		return

	var text := found.get_string(4).strip_edges()

	if text == "":
		out["errors"].append("%s: the line says nothing" % at)
		return

	var emotes: Array[String] = []
	var bracket := found.get_string(2)

	if bracket != "":
		for word in _emote_words(bracket.substr(1, bracket.length() - 2)):
			if EMOTES.has(word) or EMOTE_PREFIXES.any(func(p): return word.begins_with(p) and word.length() > String(p).length()):
				emotes.append(word)
			else:
				out["errors"].append("%s: no such emote '%s'" % [at, word])

	var condition := found.get_string(3)

	if condition != "":
		condition = condition.substr(4, condition.length() - 5).strip_edges()

	var choice := {"if": condition, "emotes": emotes, "text": text, "source": at}
	var turns: Array = block["interrupt"] if interrupting else block["lines"]

	# Straight after a line of his own that had a condition: another way to
	# say the same turn.
	if not turns.is_empty():
		var last: Dictionary = turns[-1]

		if last["part"] == part and String((last["choices"] as Array)[-1]["if"]) != "":
			last["choices"].append(choice)
			return

	turns.append({"part": part, "choices": [choice]})


static func _finish(block: Dictionary, out: Dictionary) -> void:
	if block.is_empty():
		return

	if block["cast"].is_empty():
		out["errors"].append("%s: '%s' has no cast" % [block["source"], block["id"]])
		return

	if block["lines"].is_empty():
		out["errors"].append("%s: '%s' has no lines" % [block["source"], block["id"]])
		return

	block.erase("_parts")
	out["conversations"].append(block)


## "Mirelle: rank 4; captain; south".
static func _cast_line(line: String, at: String, out: Dictionary) -> void:
	var colon := line.find(":")

	if colon <= 0:
		out["errors"].append("%s: a cast line is 'Name: what he is; ...'" % at)
		return

	var name := line.substr(0, colon).strip_edges()
	var man := {"rank": 1, "traits": [], "ties": {}}

	for tie in TIES:
		man["ties"][tie] = []

	for item in line.substr(colon + 1).split(";", false):
		var words := String(item).strip_edges().split(" ", false)

		if words.is_empty():
			continue

		if words[0] == "rank" and words.size() == 2 and words[1].is_valid_int():
			man["rank"] = int(words[1])
		elif TIES.has(words[0]) and words.size() == 2:
			man["ties"][words[0]].append(words[1])
		elif words.size() == 1:
			man["traits"].append(words[0])
		else:
			out["errors"].append("%s: '%s' is not a rank, a tie or a trait" % [at, String(item).strip_edges()])

	out["cast"][name] = man


## The words in an emote bracket: split on commas and spaces, but a place
## after "points:" or "looks:" keeps its spaces ("looks:the tower").
static func _emote_words(inside: String) -> Array[String]:
	var words: Array[String] = []

	for token in inside.replace(",", " , ").split(" ", false):
		var word := String(token)

		if word == ",":
			words.append("")
			continue

		var joins := not words.is_empty() and words[-1] != "" and EMOTE_PREFIXES.any(func(p): return words[-1].begins_with(p))

		if joins and not EMOTES.has(word) and not EMOTE_PREFIXES.any(func(p): return word.begins_with(p)):
			words[-1] += " " + word
		else:
			words.append(word)

	return words.filter(func(w): return w != "")


## Kin, friends and rivals are so both ways.
static func _close_ties(cast: Dictionary) -> void:
	for name in cast:
		for tie in MUTUAL:
			for other in cast[name]["ties"][tie]:
				if cast.has(other) and not (name in cast[other]["ties"][tie]):
					cast[other]["ties"][tie].append(name)


## Seconds, ONCE, or -2 if it cannot be read.
static func _duration(value: String) -> float:
	if value == "once":
		return ONCE

	var number := value.substr(0, value.length() - 1)

	if value.ends_with("s") and number.is_valid_float():
		return float(number)

	if value.ends_with("m") and number.is_valid_float():
		return float(number) * 60.0

	return -2.0


## Splits on `separator` outside parentheses.
static func _split_top(text: String, separator: String) -> Array:
	var parts := []
	var depth := 0
	var start := 0

	for i in text.length():
		var c := text[i]

		if c == "(":
			depth += 1
		elif c == ")":
			depth -= 1
		elif c == separator and depth == 0:
			parts.append(text.substr(start, i - start))
			start = i + 1

	parts.append(text.substr(start))
	return parts


static func _is_word(text: String) -> bool:
	return RegEx.create_from_string("^[A-Za-z0-9_]+$").search(text) != null
