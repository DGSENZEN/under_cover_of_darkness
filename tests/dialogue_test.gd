extends Node3D
## The character dialogue files (the talk and quests spec, section 1): the
## .dialogue parser (D1-D4, D16-D17), the words conditions and effects share
## (D5) and the library with its types and link checks (D6-D15, D18-D19).
##   Godot --headless --fixed-fps 60 --path . res://tests/dialogue_test.tscn
##
## The words still to write (every text in <<...>>) are printed as WORDS:
## lines; their number never fails a check.

const DialogueBook := preload("res://scripts/Level/DialogueBook.gd")
const JobBook := preload("res://scripts/Level/JobBook.gd")
const Terms := preload("res://scripts/Level/Terms.gd")

## Two characters and one type, used only by tests (and the suites after).
const FIXTURES := "res://tests/fixtures/dialogue"

var results: Array[String] = []


func _ready() -> void:
	_parser()
	_terms()
	_library()
	_links()
	_edges()
	_typos()
	print("\n==== RESULTS ====")

	for line in results:
		print(line)

	var failed := results.filter(func(r): return r.begins_with("FAIL")).size()
	print("\n%d pass, %d fail" % [results.size() - failed, failed])
	get_tree().quit()


# ---------------------------------------------------------------------------
# D1-D4: the parser
# ---------------------------------------------------------------------------

func _parser() -> void:
	var fixture := "\n".join([
		"== character amparo",
		"name: Amparo",
		"voice: female",
		"",
		"== beat open_first",
		"when: not(met)",
		"do: set(met_once)",
		"# a comment",
		"Amparo [flare]: <<Stand still, joven.>>",
		"Sense obsidian [if has(the_book)]: <<The copal bends toward your shoulder.>>",
		"[pause 1.2]",
		"> [if has(the_book)] ! <<Take it.>> -> end {do: give(the_book), mood(+1)}",
		">> <<Who is behind me?>> -> behind",
		"-> behind",
	])
	var parsed: Dictionary = DialogueBook.parse(fixture, "t.dialogue")
	var beat := _entry(parsed, "beat", "open_first")
	var body: Array = beat.get("body", [])
	var types: Array = body.map(func(l): return String(l["type"]))
	var sense: Dictionary = body[1] if body.size() > 1 else {}
	var pause: Dictionary = body[2] if body.size() > 2 else {}
	var special: Dictionary = body[3] if body.size() > 3 else {}
	var plain: Dictionary = body[4] if body.size() > 4 else {}
	var goto: Dictionary = body[5] if body.size() > 5 else {}
	_check("D1 a beat's body parses into say/sense/pause/option/goto in order",
		(parsed["errors"] as Array).is_empty() and types == ["say", "sense", "pause", "option", "option", "goto"]
		and sense.get("school") == "obsidian" and sense.get("if") == "has(the_book)"
		and is_equal_approx(float(pause.get("seconds", 0)), 1.2)
		and special.get("special") == true and special.get("if") == "has(the_book)" and special.get("to") == "end"
		and special.get("do") == ["give(the_book)", "mood(+1)"] and special.get("type_only") == false
		and special.get("text") == "<<Take it.>>"
		and plain.get("special") == false and plain.get("type_only") == true and plain.get("to") == "behind"
		and plain.get("do") == [] and plain.get("if") == ""
		and goto.get("to") == "behind"
		and (beat["keys"] as Dictionary).get("when") == "not(met)" and (beat["keys"] as Dictionary).get("do") == "set(met_once)"
		and beat.get("source") == "t.dialogue:5",
		"errors %s, types %s" % [parsed["errors"], types])

	var cued: Dictionary = DialogueBook.parse("== beat open\nAmparo [dim] [nod]: <<x>>", "t.dialogue")
	var line: Dictionary = (_entry(cued, "beat", "open").get("body", [{}]) as Array)[0]
	_check("D2 cues are read off the speaker",
		(cued["errors"] as Array).is_empty() and line.get("cues") == [&"dim", &"nod"] and line.get("speaker") == "Amparo"
		and line.get("text") == "<<x>>",
		"line %s, errors %s" % [line, cued["errors"]])

	var broken := {
		"an unknown kind": ["== bell x\nname: hm", 1],
		"an unknown cue": ["== beat open\nAmparo [wobble]: <<hm>>", 2],
		"a bad condition": ["== beat open\nwhen: stole(x)\nAmparo: <<hm>>", 2],
		"a bad effect": ["== beat open\ndo: steal(x)\nAmparo: <<hm>>", 2],
		"an option with no ->": ["== beat open\nAmparo: <<hm>>\n> <<no way on>>", 3],
		"a body line outside any beat": ["# top\n\nAmparo: <<hm>>", 3],
	}
	var wrong: Array[String] = []

	for what in broken:
		var errors: Array = DialogueBook.parse(String(broken[what][0]), "t.dialogue")["errors"]

		if errors.size() != 1 or not String(errors[0]).contains("t.dialogue:%d" % int(broken[what][1])):
			wrong.append("%s: %s" % [what, errors])

	_check("D3 errors name file and line", wrong.is_empty(), "; ".join(wrong) if not wrong.is_empty() else "six broken files, one error each")

	var accent: Dictionary = DialogueBook.parse("== beat open\nDoña Amparo [dim]: <<Stand still.>>", "t.dialogue")
	var said: Dictionary = (_entry(accent, "beat", "open").get("body", [{}]) as Array)[0]
	_check("D4 an accented speaker is a spoken line",
		(accent["errors"] as Array).is_empty() and said.get("type") == "say" and said.get("speaker") == "Doña Amparo"
		and said.get("cues") == [&"dim"],
		"line %s, errors %s" % [said, accent["errors"]])


# ---------------------------------------------------------------------------
# D5: the shared words
# ---------------------------------------------------------------------------

func _terms() -> void:
	var good := Terms.condition_error("said(met), has(the_book), mood>=2, not(gave(librarian.the_book)), purse>=3, met", true)
	var job_bad := Terms.condition_error("said(met)", false)
	var job_good := JobBook.condition_error("said(curandera.asked_book)")
	var effects: Array[String] = ["set(f)", "clear(f)", "give(i)", "take(i)", "pay(3)", "charge(3)", "goal(g)", "done(g)", "note(n)",
		"mood(+1)", "mood(-2)", "shade(flare)", "shade(dim)", "shade(gutter)", "shade(calm)"]
	var bad_effects: Array[String] = ["steal(x)", "mood(1)", "shade(red)", "pay(x)", "set()"]
	var effect_problems: Array[String] = []

	for effect in effects:
		if Terms.effect_error(effect) != "":
			effect_problems.append("'%s' refused" % effect)

	for effect in bad_effects:
		if Terms.effect_error(effect) == "":
			effect_problems.append("'%s' let through" % effect)

	var split := Terms.split_top("said(a), not(gave(b.c)), purse>=3")
	_check("D5 the new terms",
		good == "" and job_bad != "" and job_good == "" and effect_problems.is_empty()
		and split == PackedStringArray(["said(a)", "not(gave(b.c))", "purse>=3"])
		and JobBook.condition_error("mood>=2") != "" and JobBook.condition_error("met") != ""
		and JobBook.condition_error("has(x), mood(c)<=1, purse>=2, took(y)") == ""
		and Terms.condition_error("said(a),", true) != "",
		"good '%s', job_bad '%s', job_good '%s', effects %s, split %s" % [good, job_bad, job_good, effect_problems, split])


# ---------------------------------------------------------------------------
# D6-D9, D12, D13, D18: the library
# ---------------------------------------------------------------------------

func _library() -> void:
	var lib: Dictionary = DialogueBook.load_dir(FIXTURES)
	var characters: Dictionary = lib.get("characters", {})
	var keys: Array = characters.keys()
	keys.sort()
	var goal: Dictionary = {}

	for g in lib.get("goals", []):
		if g["id"] == "fx_bring_book":
			goal = g

	_check("D6 the library gathers characters, types, items, goals and notes",
		keys == ["fx_curandera", "fx_librarian"] and (lib.get("types", {}) as Dictionary).has("fx_trade")
		and (lib.get("items", {}) as Dictionary).has("fx_book") and not goal.is_empty() and goal.get("district") == &"people"
		and goal.get("kind") == &"side" and goal.get("done") == "gave(fx_curandera.fx_book)"
		and goal.get("shows") == "said(fx_curandera.asked)" and (lib.get("notes", null) is Dictionary)
		and (lib["errors"] as Array).is_empty() and (lib["warnings"] as Array).is_empty()
		and characters["fx_curandera"].get("name") == "Fx Curandera" and characters["fx_curandera"].get("body") == &"duelist"
		and characters["fx_curandera"].get("voice") == &"female" and characters["fx_curandera"].get("type") == "fx_trade"
		and characters["fx_librarian"].get("colour") == DialogueBook.colour_of("ink")
		and lib["items"]["fx_book"].get("look") == &"book",
		"characters %s, errors %s, warnings %s" % [keys, lib.get("errors"), lib.get("warnings")])

	var beats: Dictionary = characters.get("fx_curandera", {}).get("beats", {})
	var opener: Dictionary = beats.get("open", {})
	var texts: Array = _options(opener).map(func(l): return String(l["text"]))
	_check("D7 a type's >> options join every opener, before its end options",
		texts == ["<<Ask about the book again.>>", "<<Hand over the book.>>", "<<Ask for a cleansing.>>", "<<Never mind.>>"],
		"options %s" % [texts])

	var first_to: Array = _options(beats.get("open_first", {})).map(func(l): return String(l["to"]))
	var openers: Array = characters.get("fx_curandera", {}).get("openers", [])
	_check("D7b every opener gets them, the character's own openers first",
		first_to == ["asked", "limpia", "end"] and openers == ["open_first", "open"]
		and characters["fx_librarian"].get("openers") == ["open_after_lie", "open"],
		"open_first goes to %s, openers %s" % [first_to, openers])

	_check("D8 the character's own beat overrides the type's",
		String(beats.get("limpia", {}).get("source", "")).begins_with("fx_curandera.dialogue:")
		and String(lib["types"]["fx_trade"]["beats"]["limpia"]["source"]).begins_with("types/fx_trade.dialogue:"),
		"limpia from %s" % [beats.get("limpia", {}).get("source")])

	DialogueBook.use(lib)
	var stand: Dictionary = DialogueBook.type_character("fx_trade", "Stand-in")
	var stand_open: Dictionary = (stand.get("beats", {}) as Dictionary).get("open", {})
	_check("D9 a type-only NPC",
		(stand.get("beats", {}) as Dictionary).has("open") and stand.get("name") == "Stand-in" and stand.get("type") == "fx_trade"
		and String(stand_open.get("source", "")).begins_with("types/fx_trade.dialogue:")
		and (stand.get("openers", []) as Array) == ["open"] and stand.get("voice") == &"female"
		and stand.get("colour") == DialogueBook.colour_of("copal") and _options(stand_open).size() == 2
		and DialogueBook.type_character("no_type", "x").is_empty(),
		"stand-in %s" % [(stand.get("beats", {}) as Dictionary).keys()])

	var real: Dictionary = DialogueBook.load_dir()
	_check("D12 the shipped files load clean", (real["errors"] as Array).is_empty(), "errors %s" % [real["errors"]])

	var words: Array = DialogueBook.placeholders(lib)
	var lines := 0

	for file in ["fx_curandera.dialogue", "fx_librarian.dialogue", "types/fx_trade.dialogue"]:
		for line in FileAccess.get_file_as_string(FIXTURES.path_join(file)).split("\n"):
			if String(line).contains("<<"):
				lines += 1

	var shape := RegEx.create_from_string("^(types/)?fx_[a-z]+\\.dialogue:[0-9]+ ")
	var placed := words.all(func(w): return shape.search(String(w)) != null)

	for w in words:
		print("WORDS: %s" % w)

	_check("D13 placeholders list file:line for dialogue too",
		words.size() == lines and placed and words.size() > 10 and _unique(words)
		and words.any(func(w): return String(w).begins_with("fx_curandera.dialogue:") and String(w).ends_with(" beat asked"))
		and words.any(func(w): return String(w).ends_with(" goal fx_bring_book")),
		"%d still to write, %d lines carry one" % [words.size(), lines])

	_check("D18 colour_of reads swatches and hex; use() swaps the library",
		DialogueBook.colour_of("teal") == Color(0.18, 0.55, 0.55) and DialogueBook.colour_of("copal") == Color(1.0, 0.62, 0.22)
		and DialogueBook.colour_of("ink") == Color(0.55, 0.38, 1.0) and DialogueBook.colour_of("marigold") == Color(0.95, 0.69, 0.2)
		and DialogueBook.colour_of("cochineal") == Color(0.76, 0.16, 0.16) and DialogueBook.colour_of("#ff0000") == Color(1, 0, 0)
		and DialogueBook.colour_of("00ff00") == Color(0, 1, 0)
		and DialogueBook.character("fx_librarian").get("name") == "Fx Librarian" and DialogueBook.item("fx_book").get("look") == &"book"
		and DialogueBook.character("nobody").is_empty() and DialogueBook.item("nothing").is_empty(),
		"character fx_librarian %s" % [DialogueBook.character("fx_librarian").get("name")])
	DialogueBook.reload()


## The option lines of a beat, in order.
func _options(beat: Dictionary) -> Array:
	return (beat.get("body", []) as Array).filter(func(l): return l["type"] == "option")


func _unique(list: Array) -> bool:
	var seen := {}

	for item in list:
		if seen.has(item):
			return false

		seen[item] = true

	return true


# ---------------------------------------------------------------------------
# D10, D11, D14, D15, D19: the links and the checks of the library
# ---------------------------------------------------------------------------

## What `check_alone` makes of one character file `a.dialogue` made of `lines`,
## and any `extra` files ({filename: text}).
func _alone(lines: Array, extra := {}) -> Dictionary:
	var files := {"a.dialogue": "\n".join(lines)}
	files.merge(extra)
	return DialogueBook.check_alone(files)


func _links() -> void:
	var head := ["== character a", "== item bk", "name: Bk", "look: book", "== beat open"]
	var cases := {
		"a -> nowhere": [head + ["A: <<x>>", "> <<go>> -> nowhere"], 7, "nowhere", {}],
		"give(no_item)": [head + ["A: <<x>>", "> <<go>> -> end {do: give(no_item)}"], 7, "no_item", {}],
		"said(nobody.flag)": [head + ["A: <<x>>", "> [if said(nobody.flag)] <<go>> -> end"], 7, "nobody", {}],
		"type: no_type": [["== character a", "type: no_type", "== beat open", "A: <<x>>"], 2, "no_type", {}],
		"no opener lacking when:": [["== character a", "== beat open", "when: met", "A: <<x>>"], 1, "when", {}],
		"a goto nowhere": [head + ["A: <<x>>", "-> nowhere"], 7, "nowhere", {}],
		"take(no_item) in a beat": [head + ["do: take(no_item)", "A: <<x>>"], 6, "no_item", {}],
		"has(no_item)": [head + ["A: <<x>>", "> [if has(no_item)] <<go>> -> end"], 7, "no_item", {}],
		"gave(nobody.bk)": [head + ["A: <<x>>", "> [if gave(nobody.bk)] <<go>> -> end"], 7, "nobody", {}],
		"goal(no_goal)": [head + ["A: <<x>>", "> <<go>> -> end {do: goal(no_goal)}"], 7, "no_goal", {}],
		"a flag nobody sets": [head + ["A: <<x>>", "> [if said(wished)] <<go>> -> end"], 7, "wished", {}],
		"a flag of another that is not set": [head + ["A: <<x>>", "> [if said(b.wished)] <<go>> -> end"], 7, "wished",
			{"b.dialogue": "== character b\n== beat open\nB: <<x>>"}],
		"a beat called end": [head + ["A: <<x>>", "== beat end", "A: <<x>>"], 7, "end", {}],
	}
	var wrong: Array[String] = []

	for what in cases:
		var spec: Array = cases[what]
		var errors: Array = _alone(spec[0], spec[3])["errors"]
		var at := "a.dialogue:%d: " % int(spec[1])

		if errors.size() != 1 or not String(errors[0]).begins_with(at) or not String(errors[0]).contains(String(spec[2])):
			wrong.append("%s: %s" % [what, errors])

	_check("D10 broken links are errors with file:line", wrong.is_empty(),
		"; ".join(wrong) if not wrong.is_empty() else "%d broken files, one error each" % cases.size())

	var lib := _alone(["== character a", "== beat open", "A: <<x>>", "> <<go>> -> end", "== beat orphan", "A: <<x>>", "== beat reached", "A: <<x>>",
		"== beat open_late", "when: met", "A: <<x>>", "-> reached"])
	var warned: Array = (lib["warnings"] as Array).filter(func(w): return String(w).begins_with("a.dialogue:5: ") and String(w).contains("orphan"))
	_check("D11 an unreachable beat is a warning, not an error",
		(lib["errors"] as Array).is_empty() and warned.size() == 1 and (lib["warnings"] as Array).size() == 1,
		"errors %s, warnings %s" % [lib["errors"], lib["warnings"]])

	var take_bare := _alone(["== character a", "== item bk", "name: Bk", "== beat open", "A: <<x>>", "> <<give it>> -> end {do: take(bk)}"])
	var take_ok := _alone(["== character a", "== item bk", "name: Bk", "== beat open", "A: <<x>>", "> [if has(bk)] <<give it>> -> end {do: take(bk)}",
		"> <<leave>> -> end"])
	var bare: Array = (take_bare["warnings"] as Array).filter(func(w): return String(w).begins_with("a.dialogue:6: ") and String(w).contains("take(bk)"))
	_check("D14 take(x) on an option without [if has(x)] warns",
		(take_bare["errors"] as Array).is_empty() and bare.size() == 1 and (take_bare["warnings"] as Array).size() == 1
		and (take_ok["warnings"] as Array).is_empty() and (take_ok["errors"] as Array).is_empty(),
		"bare warnings %s, ok warnings %s %s" % [take_bare["warnings"], take_ok["warnings"], take_ok["errors"]])

	var filtered := _alone(["== character a", "== beat open", "A: <<x>>", "> [if met] <<one>> -> end", "> [if mood>=1] <<two>> -> end"])
	var rescued := _alone(["== character a", "== beat open", "A: <<x>>", "> [if met] <<one>> -> end", "> <<two>> -> end"])
	var walked := _alone(["== character a", "== beat open", "A: <<x>>", "> [if met] <<one>> -> end", "-> end"])
	var gone: Array = (filtered["warnings"] as Array).filter(func(w): return String(w).begins_with("a.dialogue:2: "))
	_check("D15 a beat whose options can all be filtered warns",
		(filtered["errors"] as Array).is_empty() and gone.size() == 1 and (filtered["warnings"] as Array).size() == 1
		and (rescued["warnings"] as Array).is_empty() and (walked["warnings"] as Array).is_empty(),
		"filtered %s, rescued %s, walked %s" % [filtered["warnings"], rescued["warnings"], walked["warnings"]])

	var flags := _alone(["== character a", "type: t", "== beat open", "do: set(x)", "A: <<x>>",
		"> [if said(x), said(y), said(z), said(walked_off)] <<go>> -> next", "> <<go>> -> end {do: clear(z)}",
		"== beat next", "A: <<x>>", "> <<go>> -> end {do: set(w)}"], {"types/t.dialogue": "== beat open\nT: <<x>>\n> <<x>> -> end {do: set(y)}"})
	var cross := _alone(["== character a", "== beat open", "A: <<x>>", "> [if said(b.p), said(b.q)] <<go>> -> end"],
		{"b.dialogue": "== character b\ntype: u\n== beat open\nB: <<x>>\n> <<go>> -> end {do: set(p)}",
		"types/u.dialogue": "== beat open\nU: <<x>>\n> <<go>> -> end {do: clear(q)}"})
	_check("D19 a flag exists when the character's file or its type's sets or clears it",
		(flags["errors"] as Array).is_empty() and (cross["errors"] as Array).is_empty(),
		"flags %s, cross %s" % [flags["errors"], cross["errors"]])


func _edges() -> void:
	var goal := ["== goal g", "kind: side", "shows: said(x)", "done: took(y)", "text: <<t>>"]
	var errors: Array = _alone(goal)["errors"]
	var dotted: Array = _alone(["== goal g", "kind: side", "shows: gave(b.bk)", "done: took(y)", "text: <<t>>"],
		{"b.dialogue": "== character b\n== item bk\nname: Bk\n== beat open\nB: <<x>>"})["errors"]
	_check("D20 a bare said() in a goal of a file with no character is a load error, not a crash",
		errors.size() == 1 and String(errors[0]).begins_with("a.dialogue:3: ") and String(errors[0]).contains("needs a character")
		and dotted.is_empty(),
		"errors %s, dotted %s" % [errors, dotted])

	var twice: Array = _alone(["== character a", "== beat open", "A: <<x>>", "== beat open", "A: <<y>>"])["errors"]
	var other: Array = _alone(["== character a", "== beat open", "A: <<x>>"], {"types/t.dialogue": "== beat open\nT: <<x>>\n== beat open\nT: <<y>>"})["errors"]
	_check("D21 a second beat of one id is an error naming both places",
		twice.size() == 1 and String(twice[0]).begins_with("a.dialogue:4: ") and String(twice[0]).contains("the beat 'open' is there twice")
		and String(twice[0]).contains("a.dialogue:2") and other.size() == 1 and String(other[0]).begins_with("types/t.dialogue:3: "),
		"errors %s, in a type %s" % [twice, other])


# ---------------------------------------------------------------------------
# D16-D17: what the parser warns of, and what it refuses
# ---------------------------------------------------------------------------

func _typos() -> void:
	var typo: Dictionary = DialogueBook.parse("== beat open\nwehn: not(met)\nAmparo: <<hm>>", "t.dialogue")
	var fine: Dictionary = DialogueBook.parse("== beat open\nthe crowd: <<hm>>\nwhisper [dim]: murmurs\nAmparo: hm", "t.dialogue")
	var warnings: Array = typo["warnings"]
	_check("D16 a lowercase speaker with plain words is probably a mistyped key",
		(typo["errors"] as Array).is_empty() and warnings.size() == 1 and String(warnings[0]).begins_with("t.dialogue:2: ")
		and String(warnings[0]).contains("wehn") and (fine["warnings"] as Array).is_empty() and (fine["errors"] as Array).is_empty()
		and (_entry(typo, "beat", "open")["body"] as Array).size() == 2,
		"typo warnings %s, fine warnings %s" % [warnings, fine["warnings"]])

	var broken := {
		"no colon": ["== beat open\nSense obsidian <<hm>>", 2],
		"a capital school": ["== beat open\nAmparo: <<x>>\nSense Obsidian: <<hm>>", 3],
		"a bad if": ["== beat open\nSense obsidian [if stole(x)]: <<hm>>", 2],
		"no text": ["== beat open\nSense obsidian:", 2],
	}
	var wrong: Array[String] = []

	for what in broken:
		var errors: Array = DialogueBook.parse(String(broken[what][0]), "t.dialogue")["errors"]

		if errors.size() != 1 or not String(errors[0]).begins_with("t.dialogue:%d: " % int(broken[what][1])):
			wrong.append("%s: %s" % [what, errors])

	_check("D17 a Sense line that does not match the grammar is an error, not speech", wrong.is_empty(),
		"; ".join(wrong) if not wrong.is_empty() else "four broken Sense lines, one error each")


func _entry(parsed: Dictionary, kind: String, id: String) -> Dictionary:
	for entry in parsed["entries"]:
		if String(entry["kind"]) == kind and entry["id"] == id:
			return entry

	return {}


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
