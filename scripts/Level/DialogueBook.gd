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
			var problem := _body_line(line, at, block["body"])

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
static func _body_line(line: String, at: String, body: Array) -> String:
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

	found = _pattern(_SAY).search(line)

	if found == null:
		return "'%s' is not a line of a beat (Speaker [cue]: <<text>>, Sense school: <<text>>, [pause n], > <<option>> -> beat, -> beat)" % line

	var cues: Array[StringName] = []

	for cue in RegEx.create_from_string("\\[([a-z]+)\\]").search_all(found.get_string("cues")):
		var word := StringName(cue.get_string(1))

		if not CUES.has(word):
			return "no such cue '[%s]' (%s)" % [word, ", ".join(CUES)]

		cues.append(word)

	body.append({"type": "say", "speaker": found.get_string("speaker"), "cues": cues, "text": found.get_string("text"), "source": at})
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
