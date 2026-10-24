extends RefCounted
## The character files' words (the talk and quests spec, section 1):
## data/dialogue/*.dialogue, the user's to write, one file per character.
## The same shape as JobBook's job files, with a beat's body read like a play:
##
##   == beat open_first                   a block: its kind and id
##   when: not(met)                       key: value (a beat's when, do, intent)
##   Amparo [dim]: <<Stand still.>>       a spoken line, its cues in brackets
##   Sense obsidian [if has(x)]: <<..>>   an inner voice, red, maybe conditional
##   [pause 1.2]                          a held silence
##   > [if has(x)] ! <<Take it.>> -> end {do: give(x), mood(+1)}
##                                        an option: [if] shown only when it
##                                        holds, ! drawn red, {do:} its effects
##   >> <<Ask for copal.>> -> copal       a type's option, added to every opener
##   -> next                              the beat that follows, no options
##
## A line outside a beat's keys is a body line. A text still in <<...>> is a
## placeholder (JobBook's). Errors carry file:line. Conditions and effects are
## read by Terms.gd. docs/systems/dialogue.md is the writer's guide.
##
## The library: data/dialogue/<character>.dialogue, one per character, and
## data/dialogue/types/<type>.dialogue, one per kind of NPC. A character with
## `type: t` gets every beat of t it doesn't write itself, and t's `>>` options
## join each of its openers (before the ones that end). load_dir() reads them
## all and checks every link; library() holds the result.

const Terms := preload("res://scripts/Level/Terms.gd")

const OPEN := "<<"
const CLOSE := ">>"
const KINDS := [&"character", &"beat", &"item", &"goal", &"note"]
## The keys each kind of block may have.
const KEYS := {
	&"character": ["name", "type", "colour", "body", "voice", "intent"],
	&"beat": ["when", "do", "intent"],
	&"item": ["name", "look", "intent"],
	&"goal": ["kind", "shows", "done", "note", "intent", "text"],
	&"note": ["intent", "text"],
}
const GOAL_KINDS := ["main", "side"]
const VOICES := ["male", "male_b", "female"]
## The cues a spoken line may carry: the shade's states, then the head.
const CUES := [&"flare", &"dim", &"gutter", &"calm", &"nod", &"shake"]
## The block that ends a conversation, as an option's or a goto's target.
const END := "end"

const _SAY := "^(?<speaker>[\\p{L}' .-]+?)\\s*(?<cues>(\\[[a-z]+\\]\\s*)*):\\s*(?<text>.+)$"
const _SENSE := "^Sense (?<school>[a-z]+)\\s*(\\[if (?<if>[^\\]]+)\\])?\\s*:\\s*(?<text>.+)$"
const _PAUSE := "^\\[pause (?<s>[0-9.]+)\\]$"
const _OPTION := "^(?<m>>>?)\\s*(\\[if (?<if>[^\\]]+)\\])?\\s*(?<sp>!)?\\s*(?<text>.+?)\\s*->\\s*(?<to>[A-Za-z0-9_]+)\\s*(\\{do:\\s*(?<do>.*)\\})?$"
const _GOTO := "^->\\s*(?<to>[A-Za-z0-9_]+)$"

static var _patterns := {}


const FOLDER := "res://data/dialogue"
## The subfolder of the type files (data/dialogue/types/<type>.dialogue).
const TYPES := "types"
## The beats that may begin a conversation have an id starting with this.
const OPENER := "open"
## The names of a shade's colour, as the spec gives them; a colour may also be hex.
const SWATCHES := {
	"copal": Color(1.0, 0.62, 0.22),
	"ink": Color(0.55, 0.38, 1.0),
	"marigold": Color(0.95, 0.69, 0.2),
	"cochineal": Color(0.76, 0.16, 0.16),
	"teal": Color(0.18, 0.55, 0.55),
}
## Flags every character has without any beat setting them.
const BUILT_IN_FLAGS := ["walked_off"]

static var _library := {}


## The library, read once (reload() to read again, use() to swap it).
static func library() -> Dictionary:
	if _library.is_empty():
		_library = load_dir()

		for error in _library["errors"]:
			push_error("dialogue: " + String(error))

		for warning in _library["warnings"]:
			push_warning("dialogue: " + String(warning))

	return _library


## Forgets the library, so the next library() reads the folder again.
static func reload() -> void:
	_library = {}


## Makes `lib` (a load_dir() or check_alone() result) the library, for tests.
static func use(lib: Dictionary) -> void:
	_library = lib


## A character's record (see load_dir), or {}.
static func character(id: String) -> Dictionary:
	return (library()["characters"] as Dictionary).get(id, {})


## An item's record ({id, name, look, source}), or {}.
static func item(id: String) -> Dictionary:
	return (library()["items"] as Dictionary).get(id, {})


## A character made from the type `type_id` alone, a nameless NPC called
## `display_name`: the type's beats, colour, voice and body, and an id of its
## own ("<type>_<name>") for its memory. {} if there is no such type.
static func type_character(type_id: String, display_name: String) -> Dictionary:
	var types: Dictionary = library()["types"]

	if not types.has(type_id):
		return {}

	var raw := {"id": "%s_%s" % [type_id, display_name.to_snake_case()], "name": display_name, "type": type_id, "keys": {}, "sources": {},
		"beats": {}, "source": types[type_id]["source"], "intent": ""}
	return _compose(raw, types)


## The colour `value` names: a swatch (copal, ink, marigold, cochineal, teal)
## or hex. Anything else is copal; colour_error() says what is wrong with it.
static func colour_of(value: String) -> Color:
	var word := value.strip_edges()

	if SWATCHES.has(word):
		return SWATCHES[word]

	if Color.html_is_valid(word):
		return Color.html(word)

	return SWATCHES["copal"]


## "" if `value` is a swatch or hex, else what is wrong.
static func colour_error(value: String) -> String:
	var word := value.strip_edges()

	if SWATCHES.has(word) or Color.html_is_valid(word):
		return ""

	return "'%s' is not a colour (%s, or hex like #c8a040)" % [value, ", ".join(SWATCHES.keys())]


## Every .dialogue file of `path` (the characters) and of its types/ folder
## (the types), read into one library, types merged into their characters and
## every reference checked:
##   characters  {id: {id, name, type, colour (Color), body, voice, intent,
##               beats: {id: beat}, openers: [ids, the character's own first,
##               then the type's], keys, sources, source}}
##   types       the same shape, for type files (no merging)
##   items       {id: {id, name, look, intent, source, sources}}
##   goals       [JobBook-shaped goals, district &"people", owner and owner_kind]
##   notes       {id: JobBook-shaped note}
##   errors, warnings   ["<file>:<line>: ...", ...]
## A beat: {id, when, do (effects), intent, body (parse's lines), source,
## sources, own (false when it came from the type)}.
static func load_dir(path := FOLDER) -> Dictionary:
	var parsed := []

	for name in [TYPES, ""]:
		var folder := path.path_join(String(name))

		for file in _dialogue_files(folder):
			var shown := String(file) if name == "" else "%s/%s" % [TYPES, file]
			parsed.append([shown, name != "", parse(FileAccess.get_file_as_string(folder.path_join(file)), shown)])

	return _gather(parsed)


## Files read as the whole library would be: {filename: text}, a name in
## types/ being a type file. For tests.
static func check_alone(files: Dictionary) -> Dictionary:
	var parsed := []
	var names := files.keys()
	names.sort()

	for file in names:
		parsed.append([String(file), String(file).begins_with(TYPES + "/"), parse(String(files[file]), String(file))])

	return _gather(parsed)


## The texts still to write: "<file>:<line> beat <beat>" for each spoken line,
## sense line and option still in <<...>>, "<file>:<line> <kind> <id>" for each
## goal and note. A type's lines are listed once, not once per character.
static func placeholders(lib := {}) -> Array[String]:
	if lib.is_empty():
		lib = library()

	var out: Array[String] = []

	for group in ["characters", "types"]:
		for who in (lib[group] as Dictionary).values():
			for beat in (who["beats"] as Dictionary).values():
				if not beat["own"]:
					continue

				for line in beat["body"]:
					if ["say", "sense", "option"].has(line["type"]) and not line.get("inherited", false) and is_placeholder(String(line["text"])):
						out.append("%s beat %s" % [line["source"], beat["id"]])

	for entry in lib["goals"] + (lib["notes"] as Dictionary).values():
		if is_placeholder(String(entry["text"])):
			out.append("%s %s %s" % [entry["source"], entry["block"], entry["id"]])

	return out


## One file's blocks: {"entries": [{kind, id, keys, body, text, source,
## sources}], "errors": ["file:line: ..."], "warnings": [...]}. `file` is what
## errors and sources name. A beat's `body` is its lines in order, each a
## dictionary with a "type" and its "source":
##   say     {speaker, cues, text}
##   sense   {school, if, text}
##   pause   {seconds}
##   option  {type_only (>>), if, special (!), text, to (a beat id or "end"), do}
##   goto    {to}
## A goal's and a note's text is also `text`, as JobBook's.
static func parse(text: String, file: String) -> Dictionary:
	var out := {"entries": [], "errors": [], "warnings": []}
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
			block = {"kind": kind, "id": id, "keys": {}, "body": [], "text": "", "source": at, "sources": {}}
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

		if block["kind"] == &"beat" and not (KEYS[&"beat"] as Array).has(name):
			var problem := _body_line(line, at, block["body"], out["warnings"])

			if problem != "":
				out["errors"].append("%s: %s" % [at, problem])
				block["bad"] = true

			continue

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
		var problem := _key_error(block["kind"], name, value)

		if problem != "":
			out["errors"].append("%s: %s" % [at, problem])
			block["bad"] = true

	_finish(block, text_lines, in_text, out)
	return out


static func is_placeholder(text: String) -> bool:
	var t := text.strip_edges()
	return t.begins_with(OPEN) and t.ends_with(CLOSE)


## "" if `value` is fine for the key `name` of a `kind` block, else what is wrong.
static func _key_error(kind: StringName, name: String, value: String) -> String:
	match [kind, name]:
		[&"beat", "when"], [&"goal", "shows"], [&"goal", "done"]:
			return Terms.condition_error(value, true)
		[&"beat", "do"]:
			return _effects_error(value)
		[&"goal", "kind"]:
			return "" if GOAL_KINDS.has(value) else "a goal is main or side ('%s')" % value
		[&"goal", "note"], [&"character", "type"], [&"character", "body"], [&"item", "look"]:
			return "" if _is_word(value) else "'%s' is not an id" % value
		[&"character", "voice"]:
			return "" if VOICES.has(value) else "a voice is %s ('%s')" % [", ".join(VOICES), value]

	return ""


## "" if `value` is effects joined by commas, each one fine, else what is wrong.
static func _effects_error(value: String) -> String:
	if value.strip_edges() == "":
		return "an empty list of effects"

	for effect in Terms.split_top(value):
		var problem := Terms.effect_error(String(effect))

		if problem != "":
			return problem

	return ""


## Reads one line of a beat's body onto `body`. "" if it was one, else what is wrong.
static func _body_line(line: String, at: String, body: Array, warnings: Array) -> String:
	var found: RegExMatch

	if line.begins_with("["):
		found = _pattern(_PAUSE).search(line)

		if found != null:
			var seconds := found.get_string("s")

			if not seconds.is_valid_float():
				return "'%s' is not a number of seconds" % seconds

			body.append({"type": "pause", "seconds": seconds.to_float(), "source": at})
			return ""

	elif line.begins_with("->"):
		found = _pattern(_GOTO).search(line)

		if found == null:
			return "'%s' is not a way on (-> <beat>)" % line

		body.append({"type": "goto", "to": found.get_string("to"), "source": at})
		return ""

	elif line.begins_with(">"):
		return _option(line, at, body)

	elif line.begins_with("Sense "):
		found = _pattern(_SENSE).search(line)

		if found != null:
			var cond := found.get_string("if")
			var problem := Terms.condition_error(cond, true) if cond != "" else ""

			if problem != "":
				return problem

			body.append({"type": "sense", "school": found.get_string("school"), "if": cond, "text": found.get_string("text"),
				"source": at})
			return ""

		return "'%s' is not an inner-voice line (Sense <school> [if <condition>]: <<text>>, the school in lowercase)" % line

	found = _pattern(_SAY).search(line)

	if found == null:
		return "'%s' is not a line of a beat (Speaker [cue]: <<text>>, Sense school: <<text>>, [pause n], > <<option>> -> beat, -> beat)" % line

	var cues: Array[StringName] = []

	for cue in RegEx.create_from_string("\\[([a-z]+)\\]").search_all(found.get_string("cues")):
		var word := StringName(cue.get_string(1))

		if not CUES.has(word):
			return "no such cue '[%s]' (%s)" % [word, ", ".join(CUES)]

		cues.append(word)

	var speaker := found.get_string("speaker")
	var words := found.get_string("text")

	if cues.is_empty() and speaker == speaker.to_lower() and not is_placeholder(words):
		warnings.append("%s: '%s:' is read as a speaker, but may be a mistyped key (%s)" % [at, speaker, ", ".join(KEYS[&"beat"])])

	body.append({"type": "say", "speaker": speaker, "cues": cues, "text": words, "source": at})
	return ""


static func _option(line: String, at: String, body: Array) -> String:
	var found := _pattern(_OPTION).search(line)

	if found == null:
		return "'%s' is not an option (> <<text>> -> beat, with [if ...], ! and {do: ...} if needed)" % line

	var cond := found.get_string("if")
	var problem := Terms.condition_error(cond, true) if cond != "" else ""

	if problem != "":
		return problem

	var effects: Array[String] = []
	var done := found.get_string("do")

	if found.get_start("do") >= 0:
		problem = _effects_error(done)

		if problem != "":
			return problem

		for effect in Terms.split_top(done):
			effects.append(String(effect))

	body.append({"type": "option", "type_only": found.get_string("m") == ">>", "if": cond, "special": found.get_string("sp") == "!",
		"text": found.get_string("text"), "to": found.get_string("to"), "do": effects, "source": at})
	return ""


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

	if block["kind"] in [&"goal", &"note"] and String(block["text"]) == "":
		out["errors"].append("%s: the %s '%s' has no text" % [block["source"], block["kind"], block["id"]])
	elif block["kind"] == &"goal" and not (block["keys"] as Dictionary).has("done"):
		out["errors"].append("%s: the goal '%s' has no done:" % [block["source"], block["id"]])

	out["entries"].append(block)


static func _pattern(source: String) -> RegEx:
	if not _patterns.has(source):
		_patterns[source] = RegEx.create_from_string(source)

	return _patterns[source]


static func _is_word(text: String) -> bool:
	return RegEx.create_from_string("^[A-Za-z0-9_]+$").search(text) != null


# ---------------------------------------------------------------------------
# The library
# ---------------------------------------------------------------------------

static func _dialogue_files(folder: String) -> Array:
	var files := Array(DirAccess.get_files_at(folder)).filter(func(f): return String(f).ends_with(".dialogue"))
	files.sort()
	return files


## The files' blocks gathered, types merged into characters and every
## reference checked: [[filename, is a type file, parsed]...] in order.
static func _gather(parsed: Array) -> Dictionary:
	var lib := {"characters": {}, "types": {}, "items": {}, "goals": [], "notes": {}, "errors": [], "warnings": []}
	var raw_characters := {}
	var raw_types := {}

	for pair in parsed:
		var file := String(pair[0])
		var is_type: bool = pair[1]
		var result: Dictionary = pair[2]
		lib["errors"].append_array(result["errors"])
		lib["warnings"].append_array(result["warnings"])
		var block := {}

		for entry in result["entries"]:
			if entry["kind"] != &"character":
				continue

			if block.is_empty():
				block = entry
			else:
				lib["errors"].append("%s: a second character in one file (the first at %s)" % [entry["source"], block["source"]])

		var id := file.get_file().get_basename() if is_type else String(block.get("id", ""))
		var beats := {}

		for entry in result["entries"]:
			match entry["kind"]:
				&"beat":
					if entry["id"] == END:
						lib["errors"].append("%s: a beat cannot be called '%s', that ends the conversation" % [entry["source"], END])
					else:
						beats[entry["id"]] = _beat(entry)
				&"item":
					_add_item(lib, entry)
				&"goal":
					_add_goal(lib, entry, &"type" if is_type else &"character", id)
				&"note":
					_add_note(lib, entry)

		if is_type:
			if not block.is_empty() and block["id"] != id:
				lib["errors"].append("%s: a type file holds its defaults as 'character %s', the file's name" % [block["source"], id])

			raw_types[id] = _raw(id, block, beats, file)
		elif block.is_empty():
			if not beats.is_empty():
				lib["errors"].append("%s:1: no '== character <id>' block, whose beats these would be" % file)
		elif raw_characters.has(id):
			lib["errors"].append("%s: a second character '%s' (the first at %s)" % [block["source"], id, raw_characters[id]["source"]])
		else:
			raw_characters[id] = _raw(id, block, beats, file)

	for id in raw_types:
		_check_keys(lib, raw_types[id])
		lib["types"][id] = _compose(raw_types[id], {})

	for id in raw_characters:
		var raw: Dictionary = raw_characters[id]
		_check_keys(lib, raw)

		if raw["type"] != "" and not (lib["types"] as Dictionary).has(raw["type"]):
			lib["errors"].append("%s: no type '%s' (types/%s.dialogue)" % [raw["sources"].get("type", raw["source"]), raw["type"], raw["type"]])

		lib["characters"][id] = _compose(raw, lib["types"])

	_link(lib)
	return lib


static func _beat(entry: Dictionary) -> Dictionary:
	var keys: Dictionary = entry["keys"]
	var effects: Array[String] = []

	for effect in Terms.split_top(String(keys.get("do", ""))):
		effects.append(String(effect))

	return {"id": entry["id"], "when": String(keys.get("when", "")), "do": effects, "intent": String(keys.get("intent", "")),
		"body": entry["body"], "source": entry["source"], "sources": entry["sources"], "own": true}


## A character's (or type's) own words, before any merging.
static func _raw(id: String, block: Dictionary, beats: Dictionary, file: String) -> Dictionary:
	var keys: Dictionary = block.get("keys", {})
	return {"id": id, "name": String(keys.get("name", id.capitalize())), "type": String(keys.get("type", "")), "keys": keys,
		"sources": block.get("sources", {}), "beats": beats, "source": block.get("source", "%s:1" % file), "intent": String(keys.get("intent", ""))}


static func _check_keys(lib: Dictionary, raw: Dictionary) -> void:
	var colour := String((raw["keys"] as Dictionary).get("colour", "copal"))
	var problem := colour_error(colour)

	if problem != "":
		lib["errors"].append("%s: %s" % [raw["sources"].get("colour", raw["source"]), problem])


## A character made of its own words and, if it has a type, the type's:
## beats of the type it doesn't define itself (copies, `own` false), the
## type's `>>` options joining each of its own openers before their end
## options, and the type's colour, voice and body where it has none.
static func _compose(raw: Dictionary, types: Dictionary) -> Dictionary:
	var type: Dictionary = types.get(raw["type"], {})
	var keys: Dictionary = raw["keys"]
	var type_keys: Dictionary = type.get("keys", {})
	var out := {"id": raw["id"], "name": raw["name"], "type": raw["type"], "intent": raw["intent"], "keys": keys, "sources": raw["sources"],
		"source": raw["source"],
		"colour": colour_of(String(keys.get("colour", type_keys.get("colour", "copal")))),
		"body": StringName(keys.get("body", type_keys.get("body", ""))),
		"voice": StringName(keys.get("voice", type_keys.get("voice", "male"))),
		"beats": {}, "openers": [] as Array[String]}
	var beats: Dictionary = out["beats"]
	var joining := []

	for id in raw["beats"]:
		beats[id] = (raw["beats"][id] as Dictionary).duplicate(true)

	for id in type.get("beats", {}):
		var theirs: Dictionary = type["beats"][id]

		if String(id).begins_with(OPENER):
			for line in theirs["body"]:
				if line["type"] == "option" and line["type_only"]:
					joining.append(line)

		if not beats.has(id):
			beats[id] = theirs.duplicate(true)
			beats[id]["own"] = false

	for id in beats:
		if String(id).begins_with(OPENER):
			out["openers"].append(String(id))

			if beats[id]["own"] and not joining.is_empty():
				_join(beats[id]["body"], joining)

	return out


## Puts a copy of the type's options `joining` into a beat's `body`: before
## the first option that ends the conversation, else after the last option.
static func _join(body: Array, joining: Array) -> void:
	var at := -1
	var last := -1
	var way_on := -1

	for i in body.size():
		var line: Dictionary = body[i]

		if line["type"] == "option":
			last = i

			if at < 0 and line["to"] == END and not line["type_only"]:
				at = i
		elif line["type"] == "goto" and way_on < 0:
			way_on = i

	if at < 0:
		at = last + 1 if last >= 0 else (way_on if way_on >= 0 else body.size())

	for line in joining:
		var copy: Dictionary = (line as Dictionary).duplicate(true)
		copy["inherited"] = true
		body.insert(at, copy)
		at += 1


static func _add_item(lib: Dictionary, entry: Dictionary) -> void:
	var keys: Dictionary = entry["keys"]
	var items: Dictionary = lib["items"]

	if items.has(entry["id"]):
		lib["errors"].append("%s: a second item '%s' (the first at %s)" % [entry["source"], entry["id"], items[entry["id"]]["source"]])
		return

	items[entry["id"]] = {"id": entry["id"], "name": String(keys.get("name", String(entry["id"]).capitalize())),
		"look": StringName(keys.get("look", "")), "intent": String(keys.get("intent", "")), "source": entry["source"], "sources": entry["sources"]}


## JobBook's shape, with `district` &"people" and the owner it was written in.
static func _made(entry: Dictionary) -> Dictionary:
	var keys: Dictionary = entry["keys"]
	return {"id": entry["id"], "block": entry["kind"], "district": &"people", "text": entry["text"],
		"intent": String(keys.get("intent", "")), "note": String(keys.get("note", "")), "source": entry["source"], "sources": entry["sources"]}


static func _add_goal(lib: Dictionary, entry: Dictionary, owner_kind: StringName, owner: String) -> void:
	var keys: Dictionary = entry["keys"]
	var made := _made(entry)
	made["kind"] = StringName(keys.get("kind", "main"))
	made["shows"] = String(keys.get("shows", ""))
	made["done"] = String(keys.get("done", ""))
	made["owner"] = owner
	made["owner_kind"] = owner_kind

	for goal in lib["goals"]:
		if goal["id"] == made["id"]:
			lib["errors"].append("%s: a second goal '%s' (the first at %s)" % [entry["source"], made["id"], goal["source"]])
			return

	lib["goals"].append(made)


static func _add_note(lib: Dictionary, entry: Dictionary) -> void:
	var notes: Dictionary = lib["notes"]

	if notes.has(entry["id"]):
		lib["errors"].append("%s: a second note '%s' (the first at %s)" % [entry["source"], entry["id"], notes[entry["id"]]["source"]])
		return

	notes[entry["id"]] = _made(entry)


# ---------------------------------------------------------------------------
# The links between blocks
# ---------------------------------------------------------------------------

## The references of the library, checked: the beats a way on leads to, the
## items, goals, notes, characters and flags terms and effects name, the
## openers, and what no opener reaches.
static func _link(lib: Dictionary) -> void:
	var ctx := {"lib": lib, "char_flags": {}, "type_flags": {}, "goals": {}}

	for goal in lib["goals"]:
		ctx["goals"][goal["id"]] = true

	for id in lib["types"]:
		ctx["type_flags"][id] = _flags_in(lib["types"][id]["beats"])

	for id in lib["characters"]:
		ctx["char_flags"][id] = _flags_in(lib["characters"][id]["beats"])

	for id in lib["types"]:
		_link_beats(ctx, &"type", lib["types"][id])

	for id in lib["characters"]:
		var who: Dictionary = lib["characters"][id]
		_link_beats(ctx, &"character", who)

		if not (who["openers"] as Array).any(func(o): return who["beats"][o]["when"] == ""):
			lib["errors"].append("%s: '%s' has no opener without a when: (the one played when no other holds)" % [who["source"], id])

	for goal in lib["goals"]:
		for key in ["shows", "done"]:
			if String(goal[key]) != "":
				_check_condition(ctx, goal["owner_kind"], goal["owner"], String(goal[key]), goal["sources"].get(key, goal["source"]))


## The flags a set of beats sets or clears (its own words only).
static func _flags_in(beats: Dictionary) -> Dictionary:
	var out := {}

	for beat in beats.values():
		if not beat["own"]:
			continue

		for effect in beat["do"]:
			_note_flag(String(effect), out)

		for line in beat["body"]:
			if line["type"] == "option" and not line.get("inherited", false):
				for effect in line["do"]:
					_note_flag(String(effect), out)

	return out


static func _note_flag(effect: String, into: Dictionary) -> void:
	var found := _pattern("^(set|clear)\\(([A-Za-z0-9_]+)\\)$").search(effect)

	if found != null:
		into[found.get_string(2)] = true


## The flags that exist for a character, or for a type (its own, and those of
## every character of it): its file's and its type's sets and clears.
static func _flags_of(ctx: Dictionary, kind: StringName, id: String) -> Dictionary:
	var lib: Dictionary = ctx["lib"]
	var out := {}

	for flag in BUILT_IN_FLAGS:
		out[flag] = true

	if kind == &"character":
		out.merge(ctx["char_flags"].get(id, {}))
		out.merge(ctx["type_flags"].get(lib["characters"][id]["type"], {}))
	else:
		out.merge(ctx["type_flags"].get(id, {}))

		for other in lib["characters"]:
			if lib["characters"][other]["type"] == id:
				out.merge(ctx["char_flags"][other])

	return out


## Checks the beats `who` wrote itself: the beats a way on leads to, the
## words in its conditions and effects, the options it may leave a player
## without, and the beats nothing reaches.
static func _link_beats(ctx: Dictionary, kind: StringName, who: Dictionary) -> void:
	var lib: Dictionary = ctx["lib"]
	var beats: Dictionary = who["beats"]
	var owner := String(who["id"])

	for beat in beats.values():
		if not beat["own"]:
			continue

		if beat["when"] != "":
			_check_condition(ctx, kind, owner, beat["when"], beat["sources"].get("when", beat["source"]))

		for effect in beat["do"]:
			_check_effect(ctx, effect, beat["sources"].get("do", beat["source"]))

		var options := 0
		var open_ways := 0

		for line in beat["body"]:
			var inherited: bool = line.get("inherited", false)

			match line["type"]:
				"sense":
					if line["if"] != "":
						_check_condition(ctx, kind, owner, line["if"], line["source"])
				"goto":
					_check_target(lib, beats, line["to"], line["source"])
					open_ways += 1
				"option":
					options += 1

					if line["if"] == "":
						open_ways += 1

					if inherited:
						continue

					_check_target(lib, beats, line["to"], line["source"])

					if line["if"] != "":
						_check_condition(ctx, kind, owner, line["if"], line["source"])

					for effect in line["do"]:
						_check_effect(ctx, effect, line["source"])

						var taking := _pattern("^take\\(([A-Za-z0-9_]+)\\)$").search(String(effect))

						if taking != null and not Terms.split_top(String(line["if"])).has("has(%s)" % taking.get_string(1)):
							lib["warnings"].append("%s: %s without [if has(%s)], so it is offered to a player who cannot give it" % [
								line["source"], effect, taking.get_string(1)])

		if options > 0 and open_ways == 0:
			lib["warnings"].append("%s: every option of the beat '%s' has an [if], so a player may be left with none" % [beat["source"], beat["id"]])

	var reached := {}
	var queue: Array = (who["openers"] as Array).duplicate()

	while not queue.is_empty():
		var id := String(queue.pop_back())

		if reached.has(id) or not beats.has(id):
			continue

		reached[id] = true

		for line in beats[id]["body"]:
			if line["type"] == "option" or line["type"] == "goto":
				queue.append(line["to"])

	for id in beats:
		if beats[id]["own"] and not reached.has(id):
			lib["warnings"].append("%s: the beat '%s' is never reached (no opener leads to it)" % [beats[id]["source"], id])


static func _check_target(lib: Dictionary, beats: Dictionary, to: String, at: String) -> void:
	if to != END and not beats.has(to):
		lib["errors"].append("%s: no beat '%s'" % [at, to])


## The terms of `cond`, each one's references (items, characters, flags) checked.
static func _check_condition(ctx: Dictionary, kind: StringName, owner: String, cond: String, at: String) -> void:
	if Terms.condition_error(cond, true) != "":
		return

	var lib: Dictionary = ctx["lib"]

	for piece in Terms.split_top(cond):
		var term := String(piece)

		while term.begins_with("not(") and term.ends_with(")"):
			term = term.substr(4, term.length() - 5).strip_edges()

		var called := _pattern("^(said|gave|has|mood)\\(([A-Za-z0-9_]+)(\\.([A-Za-z0-9_]+))?\\)").search(term)

		if called == null:
			continue

		var name := called.get_string(1)
		var first := called.get_string(2)
		var second := called.get_string(4)

		if name == "has":
			_check_item(lib, first, at)
		elif name == "mood":
			if not (lib["characters"] as Dictionary).has(first):
				lib["errors"].append("%s: no character '%s'" % [at, first])
		elif second != "" and not (lib["characters"] as Dictionary).has(first):
			lib["errors"].append("%s: no character '%s'" % [at, first])
		elif name == "gave":
			_check_item(lib, second if second != "" else first, at)
		else:
			var of_kind := &"character" if second != "" else kind
			var of_id := first if second != "" else owner
			var flag := second if second != "" else first

			if not _flags_of(ctx, of_kind, of_id).has(flag):
				lib["errors"].append("%s: no flag '%s' of '%s' (nothing in its file or its type's does set(%s) or clear(%s))" % [
					at, flag, of_id, flag, flag])


static func _check_item(lib: Dictionary, id: String, at: String) -> void:
	if not (lib["items"] as Dictionary).has(id):
		lib["errors"].append("%s: no item '%s'" % [at, id])


## One effect's reference checked: its item, goal or note.
static func _check_effect(ctx: Dictionary, effect: String, at: String) -> void:
	if Terms.effect_error(effect) != "":
		return

	var lib: Dictionary = ctx["lib"]
	var called := _pattern("^([a-z_]+)\\((.*)\\)$").search(effect)
	var arg := called.get_string(2).strip_edges()

	match called.get_string(1):
		"give", "take":
			_check_item(lib, arg, at)
		"goal", "done":
			if not (ctx["goals"] as Dictionary).has(arg):
				lib["errors"].append("%s: no goal '%s'" % [at, arg])
		"note":
			if not (lib["notes"] as Dictionary).has(arg):
				lib["errors"].append("%s: no note '%s'" % [at, arg])
