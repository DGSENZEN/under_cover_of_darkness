extends Node3D
## The character dialogue files (the talk and quests spec, section 1): the
## .dialogue parser (D1-D4, D16-D17, D22 the schools), the words conditions
## and effects share (D5), the library with its types and link checks
## (D6-D15, D18-D21), what people remember (P1-P8), the conversation runner
## (C1-C12, C12 the options' schools), the shade
## who speaks it (S1-S8) and the talk box the player reads it in (B1-B7,
## B9-B10 its draft-28 layout, B13-B15 the HUD and the letter around it,
## B16 its paint going on and off).
##   Godot --headless --fixed-fps 60 --path . res://tests/dialogue_test.tscn
##
## The words still to write (every text in <<...>>) are printed as WORDS:
## lines; their number never fails a check.

const DialogueBook := preload("res://scripts/Level/DialogueBook.gd")
const JobBook := preload("res://scripts/Level/JobBook.gd")
const Terms := preload("res://scripts/Level/Terms.gd")
const PeopleState := preload("res://scripts/Level/PeopleState.gd")
const JobState := preload("res://scripts/Level/JobState.gd")
const Inventory := preload("res://scripts/Interaction/Inventory.gd")
const Conversation := preload("res://scripts/Interaction/Conversation.gd")
const LetterText := preload("res://scripts/UI/LetterText.gd")
const Shade := preload("res://scripts/Interaction/Shade.gd")
const SHADE_SHADER := preload("res://scripts/Visual/talk_shade.gdshader")
const HumanoidScript := preload("res://scripts/Visual/Humanoid.gd")
const PLAYER := preload("res://Player.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const TalkBox := preload("res://scripts/UI/TalkBox.gd")

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
	_order()
	_people()
	_conversation()
	await _shade()
	await _box()
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
		and characters["fx_librarian"].get("colour") == DialogueBook.colour_of("#e63833")
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
	# (A goto after the options is never taken, so it is no way out: D24.)
	var walked_lines: Array = (walked["warnings"] as Array).map(func(w): return String(w).get_slice(" ", 0))
	walked_lines.sort()
	_check("D15 a beat whose options can all be filtered warns (a goto after them is no way out)",
		(filtered["errors"] as Array).is_empty() and gone.size() == 1 and (filtered["warnings"] as Array).size() == 1
		and (rescued["warnings"] as Array).is_empty() and walked_lines == ["a.dialogue:2:", "a.dialogue:5:"],
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

	# D22: a special option may name its school (!obsidian), a bare ! names
	# none; a school not in the list is an error at its line, on an option or
	# a Sense line.
	var schooled: Dictionary = DialogueBook.parse("\n".join(["== beat open", "A: <<x>>", "> !obsidian <<x>> -> end",
		"> [if has(bk)] !copal <<y>> -> end {do: mood(+1)}", "> ! <<z>> -> end", "> <<w>> -> end"]), "t.dialogue")
	var opts: Array = (_entry(schooled, "beat", "open").get("body", []) as Array).filter(func(l): return l["type"] == "option")
	var schools: Array = opts.map(func(o): return [o.get("special"), o.get("school"), o.get("text")])
	var lava: Array = DialogueBook.parse("== beat open\nA: <<x>>\n> !lava <<x>> -> end", "t.dialogue")["errors"]
	var capital: Array = DialogueBook.parse("== beat open\n> !Obsidian <<x>> -> end", "t.dialogue")["errors"]
	var sense_lava: Array = DialogueBook.parse("== beat open\nA: <<x>>\nA: <<y>>\nSense lava: <<x>>", "t.dialogue")["errors"]
	var every: Array = DialogueBook.SCHOOLS.filter(func(s):
		return (DialogueBook.parse("== beat open\nSense %s: <<x>>\n> !%s <<x>> -> end" % [s, s], "t.dialogue")["errors"] as Array).is_empty())
	_check("D22 > !obsidian is special with school obsidian, a bare ! has none; an unknown school is an error at file:line",
		(schooled["errors"] as Array).is_empty()
		and schools == [[true, "obsidian", "<<x>>"], [true, "copal", "<<y>>"], [true, "", "<<z>>"], [false, "", "<<w>>"]]
		and lava.size() == 1 and String(lava[0]).begins_with("t.dialogue:3: ") and String(lava[0]).contains("lava")
		and capital.size() == 1 and String(capital[0]).begins_with("t.dialogue:2: ")
		and sense_lava.size() == 1 and String(sense_lava[0]).begins_with("t.dialogue:4: ") and String(sense_lava[0]).contains("lava")
		and every == ["obsidian", "copal", "seance", "nahual", "lumen", "relic"],
		"schools %s, errors %s, lava %s, capital %s, sense %s, every %s" % [schools, schooled["errors"], lava, capital, sense_lava, every])


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


# ---------------------------------------------------------------------------
# D23-D25: a way on and the type's options; the parts of a line in order
# ---------------------------------------------------------------------------

func _order() -> void:
	# D23: an opener with no options of its own whose way on is a goto keeps
	# it: the type's >> options join the beat it leads to (once, however many
	# openers lead there), and none join an opener whose way on is the end.
	var lib: Dictionary = DialogueBook.check_alone({
		"a.dialogue": "\n".join(["== character a", "type: t", "== beat open", "A: <<hi>>", "-> menu", "== beat open_again", "when: met",
			"A: <<again>>", "-> menu", "== beat open_out", "when: said(gone)", "A: <<out>>", "-> end", "== beat menu", "A: <<what>>",
			"> <<Bye.>> -> end", "== beat set_gone", "A: <<x>>", "> <<y>> -> end {do: set(gone)}"]),
		"types/t.dialogue": "== beat open\n>> <<Ask.>> -> ask\n== beat ask\nT: <<a>>",
	})
	var beats: Dictionary = lib["characters"].get("a", {}).get("beats", {})
	var kinds := func(id: String) -> Array: return (beats.get(id, {}).get("body", []) as Array).map(func(l): return String(l["type"]))
	var menu: Array = _options(beats.get("menu", {})).map(func(l): return String(l["text"]))
	DialogueBook.use(lib)
	var visit := _visit("a", PeopleState.new(), null)
	var heard: Dictionary = visit[1]
	var lines: Array = (heard["lines"] as Array).map(func(l): return String(l[1]))
	_check("D23 a type's >> options join the beat an opener's goto leads to (once), not before the goto; an opener going to the end gets none",
		(lib["errors"] as Array).is_empty() and kinds.call("open") == ["say", "goto"] and kinds.call("open_again") == ["say", "goto"]
		and kinds.call("open_out") == ["say", "goto"] and menu == ["<<Ask.>>", "<<Bye.>>"]
		and lines == ["<<hi>>", "<<what>>"] and _heard_options(heard) == ["<<Ask.>>", "<<Bye.>>"],
		"open %s, open_again %s, open_out %s, menu %s, heard %s then %s, errors %s" % [kinds.call("open"), kinds.call("open_again"),
			kinds.call("open_out"), menu, lines, _heard_options(heard), lib["errors"]])
	DialogueBook.reload()

	# D24: a beat with options and a goto: the goto after them is never taken,
	# a goto before them leaves them never offered. A warning at the goto.
	var after: Array = DialogueBook.parse("== beat open\nA: <<x>>\n> <<Bye.>> -> end\n-> open", "t.dialogue")["warnings"]
	var before: Array = DialogueBook.parse("== beat open\nA: <<x>>\n-> b\n> <<Bye.>> -> end", "t.dialogue")["warnings"]
	var clean: Array = DialogueBook.parse("== beat open\nA: <<x>>\n-> b\n== beat b\nA: <<y>>\n> <<Bye.>> -> end", "t.dialogue")["warnings"]
	_check("D24 a beat with options and a goto warns at the goto's file:line (after them it is never taken, before them they never show)",
		after.size() == 1 and String(after[0]).begins_with("t.dialogue:4: ") and String(after[0]).contains("never taken")
		and before.size() == 1 and String(before[0]).begins_with("t.dialogue:3: ") and String(before[0]).contains("never offered")
		and clean.is_empty(),
		"after %s, before %s, clean %s" % [after, before, clean])

	# D25: the parts of an option or a Sense line out of order would be read
	# as its words, the [if] or the {do:} lost: an error spelling the order.
	var misordered := {
		"! before [if]": ["== beat open\nA: <<x>>\n> ! [if purse>=5] <<Pay.>> -> end", 3, "> [if <condition>] ! <<text>> -> beat {do: effects}"],
		"!school before [if]": ["== beat open\n> !obsidian [if has(x)] <<y>> -> end", 2, "> [if <condition>] ! <<text>> -> beat {do: effects}"],
		"{do:} before ->": ["== beat open\nA: <<x>>\n> <<x>> {do: give(a)} -> end", 3, "> [if <condition>] ! <<text>> -> beat {do: effects}"],
		"two ways on": ["== beat open\nA: <<x>>\n> <<x>> -> open -> end", 3, "> [if <condition>] ! <<text>> -> beat {do: effects}"],
		"[if] after the colon": ["== beat open\nA: <<x>>\nSense obsidian: [if has(x)] <<y>>", 3, "Sense <school> [if <condition>]: <<text>>"],
	}
	var wrong: Array[String] = []

	for what in misordered:
		var parsed: Dictionary = DialogueBook.parse(String(misordered[what][0]), "t.dialogue")
		var errors: Array = parsed["errors"]

		if errors.size() != 1 or not String(errors[0]).begins_with("t.dialogue:%d: " % int(misordered[what][1])) \
				or not String(errors[0]).contains(String(misordered[what][2])):
			wrong.append("%s: %s" % [what, errors])

	_check("D25 an option or Sense line whose [if], {do:} or -> sits in its words is an error at file:line spelling the order",
		wrong.is_empty(), "; ".join(wrong) if not wrong.is_empty() else "five misordered lines, one error each")


# ---------------------------------------------------------------------------
# P1-P8: what people remember (PeopleState), kept for good
# ---------------------------------------------------------------------------

func _people() -> void:
	DialogueBook.use(DialogueBook.load_dir(FIXTURES))

	var people: RefCounted = PeopleState.new()
	people.set_flag("a", "x")
	people.add_mood("a", 2)
	people.meet("a")
	_check("P1 flags, moods and met are per character",
		people.holds("said(x)", "a") and not people.holds("said(x)", "b") and people.holds("said(a.x)", "b")
		and people.holds("mood>=2, mood(a)>=2, not(mood(a)>=3)", "a") and not people.holds("mood>=1", "b")
		and people.holds("mood(a)>=1", "b") and people.holds("met", "a") and not people.holds("met", "b")
		and people.mood_of("a") == 2 and people.mood_of("b") == 0
		and not people.holds("said(x)", "") and people.holds("said(a.x)", ""),
		"a said x %s, b %s, from b %s" % [people.holds("said(x)", "a"), people.holds("said(x)", "b"), people.holds("said(a.x)", "b")])
	people.clear_flag("a", "x")
	people.record_gave("a", "fx_book")
	_check("P1b clear_flag forgets, record_gave remembers",
		not people.holds("said(x)", "a") and people.holds("gave(fx_book)", "a") and people.holds("gave(a.fx_book)", "b")
		and not people.holds("gave(fx_book)", "b"), "gave %s" % [people.gave])

	var inventory: Node = Inventory.new()
	inventory.add_belt_item(&"fx_book", "book")
	inventory.add_loot(5)
	var kit: RefCounted = PeopleState.new()
	kit.inventory = inventory
	var with_it: bool = kit.holds("has(fx_book), purse>=5", "a")
	var short: bool = not kit.holds("purse>=6", "a") and not kit.holds("has(nothing)", "a")
	kit.inventory = null
	_check("P2 has and purse read the inventory",
		with_it and short and not kit.holds("has(fx_book)", "a") and not kit.holds("purse>=5", "a") and not kit.holds("purse>=0", "a"),
		"with %s, short %s" % [with_it, short])
	inventory.free()

	var talk: RefCounted = PeopleState.new()
	var heard := {"shown": [], "done": [], "noted": []}
	talk.goal_shown.connect(func(id): heard["shown"].append(id))
	talk.goal_finished.connect(func(id): heard["done"].append(id))
	talk.noted.connect(func(id): heard["noted"].append(id))
	talk.refresh()
	var quiet: bool = talk.goals_listed().is_empty()
	talk.set_flag("fx_curandera", "asked")
	talk.refresh()
	var shown: Array = talk.goals_listed()
	var first_ok: bool = shown.size() == 1 and shown[0]["id"] == "fx_bring_book" and shown[0]["kind"] == &"side" and not shown[0]["done"]
	talk.record_gave("fx_curandera", "fx_book")
	talk.refresh()
	var by_condition: bool = talk.goal_done("fx_bring_book") and talk.goals_listed()[0]["done"]
	var other: RefCounted = PeopleState.new()
	other.show_goal("fx_bring_book")
	other.finish_goal("fx_bring_book")
	other.finish_goal("fx_bring_book")
	_check("P3 a talk goal shows on said() and is done by its done: or by finish_goal()",
		quiet and first_ok and by_condition and heard["shown"] == ["fx_bring_book"] and heard["done"] == ["fx_bring_book"]
		and heard["noted"] == ["fx_book_note"] and talk.notes == ["fx_book_note"]
		and other.goal_done("fx_bring_book") and other.goals_listed()[0]["done"] and not talk.goal_done("nope"),
		"quiet %s, listed %s, by_condition %s, heard %s" % [quiet, shown, by_condition, heard])

	var dep := JobBook.check_alone("== goal g\nkind: side\nshows: said(fx_curandera.asked)\ndone: took(y)\ntext: Hear her out.\n", "mission.job")
	var job: RefCounted = JobState.new()
	var link: RefCounted = PeopleState.new()
	job.reset(dep)
	job.people = link
	job.refresh()
	var before: bool = job.shown.is_empty()
	link.set_flag("fx_curandera", "asked")
	job.refresh()
	var then: bool = job.shown.has("g")
	_check("P4 a .job goal can depend on talk",
		(dep["errors"] as Array).is_empty() and before and then and job.holds("said(fx_curandera.asked), not(mood(fx_curandera)>=1)") and not job.holds("said(fx_curandera.nope)"),
		"before %s, then %s" % [before, then])

	var lettered: RefCounted = JobState.new()
	lettered.reset()
	var plain := LetterText.sides(lettered)
	lettered.people = talk
	var sides := LetterText.sides(lettered)
	var empty_ok: bool = LetterText.sides(_linked(JobState.new(), PeopleState.new())) == plain
	_check("P5 the letter lists talk goals and talk notes",
		sides[0].contains("Bring the curandera her book.") and sides[0].contains("[s]<<Bring the curandera her book.>>[/s]")
		and plain.size() == 1 and sides.size() == 2 and sides[sides.size() - 1].contains("The curandera wants her book back")
		and empty_ok and plain[0] != sides[0],
		"front '%s', sides %d (plain %d)" % [sides[0].right(80), sides.size(), plain.size()])

	_memory_survives()
	_saved()
	_belt_look()
	DialogueBook.reload()


func _linked(job: RefCounted, people: RefCounted) -> RefCounted:
	job.reset()
	job.people = people
	return job


func _memory_survives() -> void:
	var people: RefCounted = CityState.people
	people.set_flag("fx_librarian", "lied")
	people.add_mood("fx_librarian", -1)
	people.show_goal("fx_bring_book")
	people.finish_goal("fx_bring_book")
	people.show_goal("fx_trust_librarian")
	CityState.begin()
	var kept: bool = CityState.people.holds("said(fx_librarian.lied), mood(fx_librarian)<=-1", "")
	var ids := func() -> Array: return CityState.people.goals_listed().map(func(g): return g["id"])
	var gone: bool = ids.call() == ["fx_trust_librarian"] and CityState.people.goals_shown == ["fx_trust_librarian"] \
		and CityState.people.goal_done("fx_bring_book")
	var open: bool = not CityState.people.goals_listed()[0]["done"] if gone else false
	people.refresh()
	people.set_flag("fx_curandera", "asked")
	people.refresh()
	var quiet: bool = ids.call() == ["fx_trust_librarian"]
	_check("P6 memory survives CityState.begin(): flags and moods stay, an open goal stays on the letter, a done goal leaves it and stays done",
		kept and gone and open and quiet and CityState.job.people == CityState.people and CityState.people.job == CityState.job,
		"kept %s, gone %s, open %s, quiet %s, shown %s" % [kept, gone, open, quiet, CityState.people.goals_shown])
	CityState.people = PeopleState.new()
	CityState.begin()


func _saved() -> void:
	var people: RefCounted = PeopleState.new()
	people.set_flag("fx_curandera", "asked")
	people.record_gave("fx_curandera", "fx_book")
	people.add_mood("fx_librarian", -2)
	people.meet("fx_librarian")
	people.show_goal("fx_bring_book")
	people.learn("fx_book_note")
	var copy: RefCounted = PeopleState.new()
	copy.load_state(people.save_state())
	var alike: bool = copy.said == people.said and copy.gave == people.gave and copy.moods == people.moods and copy.met == people.met \
		and copy.goals_shown == people.goals_shown and copy.goals_done == people.goals_done and copy.notes == people.notes
	people.finish_goal("fx_bring_book")
	var apart: bool = copy.goals_done.is_empty() and copy.said["fx_curandera"] == ["asked"]
	copy.load_state(people.save_state())
	_check("P7 save_state/load_state round-trips every field into a fresh PeopleState",
		alike and apart and copy.goals_done == ["fx_bring_book"] and copy.holds("mood(fx_librarian)<=-2, met, gave(fx_curandera.fx_book)", "fx_librarian"),
		"state %s" % [copy.save_state()])


func _belt_look() -> void:
	var held: Node = Inventory.new()
	held.add_belt_item(&"fx_book", "The Fx Book")
	held.add_belt_item(&"lockpick", "lockpick")
	var state: Dictionary = held.save_state()
	var back: Node = Inventory.new()
	back.load_state(state)
	var book: Mesh = back.belt[0]["mesh"]
	var pick: Mesh = back.belt[1]["mesh"]
	_check("P8 a dialogue item keeps its mesh across a gate (and a tool its own)",
		book != null and book is BoxMesh and pick != null and not pick is BoxMesh, "book %s, pick %s" % [book, pick])
	held.free()
	back.free()


# ---------------------------------------------------------------------------
# C1-C11: the conversation runner (Conversation.gd)
# ---------------------------------------------------------------------------

## Every signal of `talk`, collected, and the order the kinds came in.
func _listen(talk: RefCounted) -> Dictionary:
	var heard := {"lines": [], "senses": [], "pauses": [], "options": [], "cues": [], "resting": [], "gave": [], "took": [], "ended": [],
		"order": []}
	talk.line.connect(func(speaker, text, cues):
		heard["lines"].append([speaker, text, cues])
		heard["order"].append("line"))
	talk.sense.connect(func(school, text):
		heard["senses"].append([school, text])
		heard["order"].append("sense"))
	talk.paused.connect(func(seconds):
		heard["pauses"].append(seconds)
		heard["order"].append("pause"))
	talk.options.connect(func(list):
		heard["options"].append(list)
		heard["order"].append("options"))
	talk.cue.connect(func(what): heard["cues"].append(what))
	talk.resting.connect(func(state): heard["resting"].append(state))
	talk.gave_item.connect(func(id):
		heard["gave"].append(id)
		heard["order"].append("gave"))
	talk.took_item.connect(func(id): heard["took"].append(id))
	talk.ended.connect(func(how):
		heard["ended"].append(how)
		heard["order"].append("ended"))
	return heard


## Advances until the conversation wants a choice or is over.
func _play(talk: RefCounted) -> void:
	var guard := 0

	while not talk.is_over() and not talk.is_waiting_for_choice() and guard < 200:
		talk.advance()
		guard += 1


## The texts of the last options list heard.
func _heard_options(heard: Dictionary) -> Array:
	var all: Array = heard["options"]
	return [] if all.is_empty() else (all[all.size() - 1] as Array).map(func(o): return String(o["text"]))


## A fresh talk with `id`, started and played to its first choice: [talk, heard].
func _visit(id: String, people: RefCounted, inventory: Node) -> Array:
	var talk: RefCounted = Conversation.new(DialogueBook.character(id), people, inventory)
	var heard := _listen(talk)
	talk.start()
	_play(talk)
	return [talk, heard]


## A one-file library `lines` (character a), made the library.
func _only(lines: Array) -> void:
	DialogueBook.use(_alone(lines))


func _conversation() -> void:
	DialogueBook.use(DialogueBook.load_dir(FIXTURES))
	var inventory: Node = Inventory.new()
	var people: RefCounted = PeopleState.new()
	var job: RefCounted = JobState.new()
	job.reset(JobBook.check_alone("== goal g\nkind: side\nshows: said(fx_curandera.asked)\ndone: took(y)\ntext: Hear her out.\n", "mission.job"))
	job.people = people
	people.job = job
	people.inventory = inventory

	var first := _visit("fx_curandera", people, inventory)
	var first_heard: Dictionary = first[1]
	var met_after: bool = people.met.has("fx_curandera")
	var second := _visit("fx_curandera", people, inventory)
	var second_heard: Dictionary = second[1]
	_check("C1 the first opener whose when: holds plays, and met is true only after it was picked",
		first_heard["lines"][0][1] == "<<She reads you.>>" and met_after and second_heard["lines"][0][1] == "<<Back again.>>"
		and first[0].is_waiting_for_choice() and not first[0].is_over(),
		"first '%s', second '%s', met %s" % [first_heard["lines"], second_heard["lines"], met_after])

	_check("C2 lines arrive in order with their cues, then the options",
		first_heard["lines"] == [["Fx Curandera", "<<She reads you.>>", [&"flare"]]] and first_heard["cues"] == [&"flare"]
		and first_heard["senses"] == [["obsidian", "<<The copal bends toward your shoulder.>>"]]
		and first_heard["order"] == ["line", "sense", "options"]
		and _heard_options(first_heard) == ["<<Ask about the book.>>", "<<Ask for a cleansing.>>", "<<Leave.>>"]
		and (first_heard["options"][0] as Array).all(func(o): return o["special"] == false),
		"order %s, options %s" % [first_heard["order"], _heard_options(first_heard)])

	_only(["== character a", "== beat open", "A [dim]: <<one>>", "Sense obsidian [if has(bk)]: <<smells of paper>>", "[pause 0.5]",
		"A: <<two>>", "-> next", "== beat next", "A [nod]: <<three>>", "> <<Go.>> -> end"])
	var walk := _visit("a", PeopleState.new(), inventory)
	var walked: Dictionary = walk[1]
	_check("C2b a false [if] sense is skipped, a pause is told, a goto flows on into the next beat",
		(walked["lines"] as Array).map(func(l): return l[1]) == ["<<one>>", "<<two>>", "<<three>>"] and walked["senses"].is_empty()
		and walked["pauses"] == [0.5] and walked["order"] == ["line", "pause", "line", "line", "options"] and walked["cues"] == [&"dim", &"nod"],
		"order %s, lines %s" % [walked["order"], walked["lines"]])

	DialogueBook.use(DialogueBook.load_dir(FIXTURES))
	var hidden := _visit("fx_curandera", people, inventory)
	var without: Array = _heard_options(hidden[1])
	people.set_flag("fx_curandera", "asked")
	var shown := _visit("fx_curandera", people, inventory)
	var with_it: Array = _heard_options(shown[1])
	people.clear_flag("fx_curandera", "asked")
	_check("C3 an [if] option is hidden when false and shown when true",
		without == ["<<Ask for a cleansing.>>", "<<Never mind.>>"]
		and with_it == ["<<Ask about the book again.>>", "<<Ask for a cleansing.>>", "<<Never mind.>>"],
		"without %s, with %s" % [without, with_it])

	var opening := PeopleState.new()
	opening.job = job
	opening.inventory = inventory
	job.people = opening
	var begin := _visit("fx_curandera", opening, inventory)
	var talk: RefCounted = begin[0]
	var heard: Dictionary = begin[1]
	var before: bool = opening.holds("said(asked)", "fx_curandera") or not opening.goals_shown.is_empty()
	talk.choose(0)
	var after_choose: bool = opening.holds("said(asked)", "fx_curandera") and opening.goals_shown == ["fx_bring_book"]
	var no_line_yet: bool = heard["lines"].size() == 1
	_play(talk)
	_check("C4 choose runs the option's effects then enters its beat, and the job hears of it",
		not before and after_choose and no_line_yet and heard["lines"][1][1] == "<<Bring me the book from the librarian.>>"
		and _heard_options(heard) == ["<<Ask for the book as a gift.>>", "<<Leave.>>"]
		and opening.notes == ["fx_book_note"] and job.shown.has("g"),
		"lines %s, shown %s, job %s" % [heard["lines"], opening.goals_shown, job.shown])

	talk.choose(0)
	_play(talk)
	talk.choose(0)
	var gift_order: Array = heard["order"].slice(heard["order"].size() - 2)
	_check("C5 give puts the item on the belt with a mesh",
		inventory.count_of(&"fx_book") == 1 and inventory.belt[0]["name"] == "The Fx Book" and inventory.belt[0]["mesh"] is BoxMesh
		and heard["gave"] == ["fx_book"] and gift_order == ["gave", "ended"] and heard["ended"] == [&"end"] and talk.is_over(),
		"belt %s, gave %s, order %s" % [inventory.belt, heard["gave"], gift_order])

	var handing := _visit("fx_curandera", opening, inventory)
	var hand: RefCounted = handing[0]
	var hand_heard: Dictionary = handing[1]
	hand.choose(_heard_options(hand_heard).find("<<Hand over the book.>>"))
	_play(hand)
	var was_there: bool = inventory.count_of(&"fx_book") == 1
	hand.choose(0)
	_check("C6 take removes it, records gave, and finishes the goal",
		was_there and inventory.count_of(&"fx_book") == 0 and inventory.belt.is_empty() and opening.holds("gave(fx_book)", "fx_curandera")
		and opening.goal_done("fx_bring_book") and hand_heard["took"] == ["fx_book"] and hand_heard["ended"] == [&"end"],
		"took %s, gave %s, goals done %s" % [hand_heard["took"], opening.gave, opening.goals_done])

	var liar := PeopleState.new()
	var lie := _visit("fx_librarian", liar, inventory)
	var lie_heard: Dictionary = lie[1]
	lie[0].choose(0)
	_play(lie[0])
	var lied: bool = liar.holds("said(lied), mood>=-1, mood<=-1", "fx_librarian")
	var next := _visit("fx_librarian", liar, inventory)
	var next_heard: Dictionary = next[1]
	next[0].choose(0)
	_play(next[0])
	var forgiven: bool = not liar.holds("said(lied)", "fx_librarian")
	var then := _visit("fx_librarian", liar, inventory)
	_check("C7 mood moves with a lie and gates the next opener",
		lie_heard["lines"][0][1] == "<<Yes?>>" and lied and lie_heard["cues"] == [&"gutter"] and lie_heard["ended"] == [&"end"]
		and next_heard["lines"][0][1] == "<<You lied to me.>>" and forgiven and then[1]["lines"][0][1] == "<<Yes?>>"
		and liar.mood_of("fx_librarian") == -1,
		"mood %d, lied %s, then '%s'" % [liar.mood_of("fx_librarian"), lied, then[1]["lines"]])

	var leaver := PeopleState.new()
	var leave := _visit("fx_librarian", leaver, inventory)
	leave[0].walk_off()
	var quiet := PeopleState.new()
	var cut := _visit("fx_librarian", quiet, inventory)
	cut[0].interrupt()
	_check("C8 walk_off sets walked_off; interrupt sets nothing",
		leaver.holds("said(walked_off)", "fx_librarian") and leave[1]["ended"] == [&"walked_off"] and leave[0].is_over()
		and quiet.said.is_empty() and cut[1]["ended"] == [&"interrupted"] and cut[0].is_over() and not cut[0].is_waiting_for_choice(),
		"left %s, cut %s, said %s" % [leave[1]["ended"], cut[1]["ended"], quiet.said])

	_only(["== character a", "== beat open", "A: <<x>>", "> [if mood>=2] <<one>> -> end", "> [if mood>=1] <<two>> -> end"])
	var none := _visit("a", PeopleState.new(), inventory)
	var only_one: Array = none[1]["options"][0]
	none[0].choose(0)
	_check("C9 all options filtered: a single ending option appears",
		only_one == [{"text": "<<…>>", "special": false, "school": ""}] and none[1]["ended"] == [&"end"] and none[0].is_over(),
		"options %s, ended %s" % [only_one, none[1]["ended"]])

	_only(["== character a", "== item bk", "name: Bk", "== beat open", "A: <<x>>", "> <<take it>> -> end {do: take(bk), charge(5)}"])
	var holder: Node = Inventory.new()
	holder.add_belt_item(&"other", "other")
	var empty_handed := PeopleState.new()
	var bare := _visit("a", empty_handed, holder)
	bare[0].choose(0)
	_check("C10 take without the item changes nothing; charge without the coin neither",
		empty_handed.gave.is_empty() and holder.belt.size() == 1 and holder.purse == 0 and bare[1]["took"].is_empty()
		and bare[1]["ended"] == [&"end"],
		"gave %s, belt %d, purse %d" % [empty_handed.gave, holder.belt.size(), holder.purse])

	_only(["== character a", "== goal g", "kind: side", "text: <<t>>", "note: n", "== note n", "text: t", "== beat open", "A: <<x>>",
		"> <<go>> -> end {do: pay(7), charge(3), mood(+2), mood(-1), shade(dim), set(f), note(n), goal(g), done(g)}"])
	var purse := PeopleState.new()
	var spend := _visit("a", purse, holder)
	spend[0].choose(0)
	_check("C10b pay, charge, mood, shade, set, note, goal and done each do their one thing",
		holder.purse == 4 and purse.mood_of("a") == 1 and spend[1]["resting"] == [&"dim"] and purse.holds("said(f)", "a")
		and purse.notes == ["n"] and purse.goals_shown == ["g"] and purse.goal_done("g"),
		"purse %d, mood %d, resting %s, notes %s, goals %s/%s" % [holder.purse, purse.mood_of("a"), spend[1]["resting"], purse.notes,
		purse.goals_shown, purse.goals_done])
	holder.free()

	DialogueBook.use(DialogueBook.load_dir(FIXTURES))
	var stand: Dictionary = DialogueBook.type_character("fx_trade", "Stand-in")
	var stranger := PeopleState.new()
	var type_talk: RefCounted = Conversation.new(stand, stranger, inventory)
	var type_heard := _listen(type_talk)
	type_talk.start()
	_play(type_talk)
	_check("C11 {name} becomes the speaker's name on a type-only character, whose memory is under its own id",
		type_heard["lines"][0][1] == "<<I am Stand-in.>>" and stranger.met == [String(stand["id"])]
		and _heard_options(type_heard) == ["<<Ask for a cleansing.>>", "<<Leave.>>"],
		"line '%s', met %s" % [type_heard["lines"], stranger.met])

	_only(["== character a", "== beat open", "A: <<x>>", "Sense nahual: <<a scent>>", "> !obsidian <<Cut.>> -> end",
		"> ! <<Red.>> -> end", "> <<Plain.>> -> end"])
	var schooled := _visit("a", PeopleState.new(), inventory)
	var schooled_heard: Dictionary = schooled[1]
	var offered: Array = schooled_heard["options"][0] if not (schooled_heard["options"] as Array).is_empty() else []
	var carried: Array = offered.map(func(o): return [o.get("text"), o.get("special"), o.get("school")])
	_check("C12 the options signal carries each option's school (\"\" for a bare ! and a plain one), the sense its own",
		carried == [["<<Cut.>>", true, "obsidian"], ["<<Red.>>", true, ""], ["<<Plain.>>", false, ""]]
		and schooled_heard["senses"] == [["nahual", "<<a scent>>"]],
		"options %s, senses %s" % [carried, schooled_heard["senses"]])
	# The job and the people hold each other: let go, or neither is ever freed.
	job.people = null
	opening.job = null
	people.job = null
	inventory.free()
	DialogueBook.reload()



# ---------------------------------------------------------------------------
# S1-S4: the shade
# ---------------------------------------------------------------------------

func _shade() -> void:
	DialogueBook.use(DialogueBook.load_dir(FIXTURES))
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	add_child(world)
	Props.block(self, Vector3(0, -0.5, 0), Vector3(20, 1, 20))
	var shade: StaticBody3D = Shade.new()
	shade.character = "fx_curandera"
	add_child(shade)
	shade.global_position = Vector3(0, 0, -1.5)
	await _frames(2)
	var worn: Array = shade.man.worn() if shade.man != null else []
	# Each wears it twice: its depth first (priority -1, before anything
	# see-through), then its colour (0, sorted by distance with the rest).
	var prepassed := func(m: MeshInstance3D) -> bool:
		var colour := m.material_override as ShaderMaterial
		var depth := colour.next_pass as ShaderMaterial if colour != null else null
		return colour != null and colour.shader == SHADE_SHADER and depth != null and depth.shader == SHADE_SHADER \
			and depth.get_shader_parameter(&"depth_only") == true and colour.get_shader_parameter(&"depth_only") != true \
			and depth.render_priority == -1 and colour.render_priority == 0
	_check("S1 a shade dresses its body and every worn mesh wears the shade material, depth pass first",
		not worn.is_empty() and shade.dialogue.get("id") == "fx_curandera" and worn.all(prepassed),
		"%d worn, prepassed %s" % [worn.size(), worn.map(func(m): return "%s %s" % [m.name, prepassed.call(m)])])

	shade.cue(&"flare")
	await _frames(60)
	var flared: float = shade.glow_now()
	shade.cue(&"dim")
	await _frames(60)
	var dimmed: float = shade.glow_now()
	shade.end_line()
	await _frames(60)
	var calmed: float = shade.glow_now()
	_check("S2 flare raises and dim lowers the glow", flared > 2.0 and dimmed < 0.5 and absf(calmed - 1.0) < 0.05,
		"flare %.2f, dim %.2f, calm %.2f" % [flared, dimmed, calmed])

	shade.cue(&"flare")
	await _frames(30)
	var during: StringName = shade.shade_state()
	shade.end_line()
	await _frames(60)
	var after_line: float = shade.glow_now()
	var line_state: StringName = shade.shade_state()
	shade.set_resting(&"dim")
	await _frames(60)
	shade.cue(&"flare")
	await _frames(30)
	var dim_flared: float = shade.glow_now()
	shade.end_line()
	await _frames(60)
	var rested: float = shade.glow_now()
	var rest_state: StringName = shade.shade_state()
	_check("S3 a line's cue passes; a resting state stays",
		during == &"flare" and line_state == &"calm" and absf(after_line - 1.0) < 0.05 and dim_flared > 1.5
		and rest_state == &"dim" and rested < 0.5,
		"during %s, after the line %s %.2f, flared from dim %.2f, resting %s %.2f" % [during, line_state, after_line, dim_flared,
		rest_state, rested])
	shade.set_resting(&"calm")

	var player: CharacterBody3D = PLAYER.instantiate()
	player.set("show_hud", false)
	add_child(player)
	player.reload_on_death = false
	player.global_position = Vector3(0, 1.05, 0)
	await _frames(10)
	var eye: Vector3 = player.get_node("Neck/Camera3D").global_position
	var to := shade.global_position + Vector3(0, 1.2, 0) - eye
	player.rotation.y = atan2(-to.x, -to.z)
	player.get_node("Neck").rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
	await _frames(10)
	var prompt: String = player.frob.current_prompt()
	_check("S4 the frob ray finds it and its prompt is Talk", player.frob.target == shade and prompt == "Talk",
		"target %s, prompt '%s'" % [player.frob.target, prompt])
	player.queue_free()
	shade.queue_free()
	await _frames(2)

	# The librarian: another body, his own colour, and no sword at his hip.
	var librarian: StaticBody3D = Shade.new()
	librarian.character = "fx_librarian"
	add_child(librarian)
	await _frames(2)
	var his: Array = librarian.man.worn() if librarian.man != null else []
	var red := DialogueBook.colour_of("#e63833")
	_check("S5 the librarian dresses arms_master in his own colour, every worn mesh on the shade with its depth pass",
		librarian.dialogue.get("body") == &"arms_master" and not his.is_empty() and his.all(prepassed)
		and his.all(func(m): return m.material_override.get_shader_parameter(&"shade_colour") == red),
		"%d worn, prepassed %s" % [his.size(), his.map(func(m): return prepassed.call(m))])
	librarian.queue_free()
	await _frames(2)
	DialogueBook.reload()
	await _carried()


## S6-S8: what a shade leaves off its wardrobe body (Shade.rebuild): the
## sword at the hip, and never clothing.
func _carried() -> void:
	# The sword's triangles on each kind's outfit, found by
	# .superpowers/diag/diag_carried.gd and seen gone in the stills: the
	# duelist's blade (28) and its two grip pieces (12 + 12), the others' one
	# 28-triangle sword. The archer and the brute carry none: their
	# pelvis-only islands are pouches, buckles and tassels.
	var swords := {&"archer": 0, &"arms_master": 28, &"brute": 0, &"duelist": 52, &"swordsman": 28, &"watchman": 28}
	var cut := {}

	for kind in swords:
		var man: Node3D = HumanoidScript.new()
		add_child(man)
		man.dress(kind, 7, &"Idle")
		var outfit: MeshInstance3D = man.body
		var pelvis_bound := range(outfit.skin.get_bind_count()).any(func(b): return String(outfit.skin.get_bind_name(b)) == "pelvis")
		var before := _triangles(outfit)
		var strips: MeshInstance3D = Shade.rebuild(outfit, man.skeleton)
		var after := _triangles(outfit) + (_triangles(strips) if strips != null and strips != outfit else 0)
		cut[kind] = [before - after, pelvis_bound]
		man.queue_free()

	await _frames(1)
	_check("S6 a shade leaves off exactly each body's sword, nothing else of its outfit",
		swords.keys().all(func(k): return cut[k][0] == swords[k] and cut[k][1]), "cut (triangles, pelvis bound) %s" % [cut])

	# Pelvis-only islands of every shape a costume might hang there: only the
	# long, thin one (and the guard touching it) is a weapon.
	var made := _hip_islands()
	var kept: PackedInt32Array = Shade._without_carried(made["arrays"], 0)
	var left := {}

	for t in range(0, kept.size(), 3):
		var name: String = made["owner"][kept[t]]
		left[name] = int(left.get(name, 0)) + 1

	_check("S7 a belt, a loincloth and a pouch rigged only to the pelvis stay; a blade and its guard go",
		left.get("body", 0) == made["tris"]["body"] and left.get("belt", 0) == made["tris"]["belt"]
		and left.get("loincloth", 0) == made["tris"]["loincloth"] and left.get("pouch", 0) == made["tris"]["pouch"]
		and not left.has("blade") and not left.has("guard"), "left %s of %s" % [left, made["tris"]])

	# A surface that is nothing but a weapon goes, and every other surface
	# keeps its own material.
	var two := ArrayMesh.new()
	var body_only := _hip_islands(["body"])
	var blade_only := _hip_islands(["blade", "guard"])
	two.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, body_only["arrays"])
	two.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, blade_only["arrays"])
	var cloth := StandardMaterial3D.new()
	cloth.resource_name = "WR_closed_body"
	var steel := StandardMaterial3D.new()
	steel.resource_name = "WR_closed_steel"
	two.surface_set_material(0, cloth)
	two.surface_set_material(1, steel)
	var worn := MeshInstance3D.new()
	worn.mesh = two
	worn.skin = Skin.new()
	worn.skin.add_named_bind("pelvis", Transform3D.IDENTITY)
	worn.skin.add_named_bind("spine_01", Transform3D.IDENTITY)
	add_child(worn)
	Shade.rebuild(worn, null)
	_check("S8 a surface that is only a weapon is dropped and the rest keep their own materials",
		worn.mesh.get_surface_count() == 1 and worn.mesh.surface_get_material(0) == cloth,
		"%d surfaces, first %s" % [worn.mesh.get_surface_count(),
		worn.mesh.surface_get_material(0).resource_name if worn.mesh.get_surface_count() > 0 else "none"])
	worn.queue_free()


## Triangles a mesh draws.
func _triangles(mesh: MeshInstance3D) -> int:
	var count := 0

	for surface in mesh.mesh.get_surface_count():
		count += (mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3

	return count


## A surface of boxes and a ring, skinned to bind 0 (pelvis) or 1 (spine):
## a body, a belt ring round the hips, a loincloth, a pouch, a blade at the
## hip and a crossguard touching it. {arrays, owner (per vertex), tris}.
func _hip_islands(only: Array = []) -> Dictionary:
	var verts := PackedVector3Array()
	var index := PackedInt32Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var owner := []
	var tris := {}
	var box := func(name: String, centre: Vector3, size: Vector3, basis: Basis, bind: int) -> void:
		if not only.is_empty() and not only.has(name):
			return
		var first := verts.size()
		for corner in 8:
			var unit := Vector3(corner & 1, (corner >> 1) & 1, (corner >> 2) & 1) - Vector3.ONE * 0.5
			verts.append(centre + basis * (unit * size))
			bones.append_array([bind, 0, 0, 0])
			weights.append_array([1.0, 0.0, 0.0, 0.0])
			owner.append(name)
		for face in [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]:
			index.append_array([first + face[0], first + face[1], first + face[2], first + face[0], first + face[2], first + face[3]])
		tris[name] = int(tris.get(name, 0)) + 12
	box.call("body", Vector3(0.0, 1.2, 0.0), Vector3(0.3, 0.6, 0.2), Basis.IDENTITY, 1)
	# The belt: a ring of 12 short boxes round the hips, touching.
	for i in 12:
		var angle := TAU * i / 12.0
		box.call("belt", Vector3(sin(angle), 0.0, cos(angle)) * 0.18 + Vector3(0.0, 1.0, 0.0), Vector3(0.1, 0.05, 0.02),
			Basis(Vector3.UP, angle), 0)
	box.call("loincloth", Vector3(0.0, 0.75, 0.2), Vector3(0.28, 0.45, 0.01), Basis.IDENTITY, 0)
	box.call("pouch", Vector3(-0.2, 0.9, 0.05), Vector3(0.1, 0.12, 0.06), Basis.IDENTITY, 0)
	# The blade hangs at the hip, slanting back; the guard sits across its top.
	var slant := Basis(Vector3.RIGHT, 0.6)
	box.call("blade", Vector3(0.25, 0.6, -0.25), Vector3(0.04, 0.9, 0.01), slant, 0)
	box.call("guard", Vector3(0.25, 0.6, -0.25) + slant * Vector3(0.0, 0.46, 0.0), Vector3(0.16, 0.02, 0.03), slant, 0)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = index
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	return {"arrays": arrays, "owner": owner, "tris": tris}


# ---------------------------------------------------------------------------
# B1-B7: the talk box, and the player held while he talks
# ---------------------------------------------------------------------------

func _box() -> void:
	DialogueBook.use(DialogueBook.load_dir(FIXTURES))
	CityState.begin()
	# A clean memory: she has never met him.
	CityState.people.load_state({})
	var shade: StaticBody3D = Shade.new()
	shade.character = "fx_curandera"
	add_child(shade)
	shade.global_position = Vector3(0, 0, -1.5)
	# (With its HUD: B13-B14 look at it.)
	var player: CharacterBody3D = PLAYER.instantiate()
	add_child(player)
	player.reload_on_death = false
	player.global_position = Vector3(0, 1.05, 0)
	await _frames(10)
	_aim(player, shade.global_position + Vector3(0, 1.2, 0))
	await _frames(20)
	var hud: Node = player.hud
	var hud_pieces := ["crosshair", "gem", "marks", "shields"]
	var hud_before := hud_pieces.map(func(p): return _hud_piece(hud, p)) if hud != null else [0.0, 0.0, 0.0, 0.0]

	# B1: E on her opens the box, and her opener's first line is told out.
	# (B16: its paint goes on within 0.7 s.)
	await _press("frob")
	var box: Node = _talking(player)
	var painting := [box.reveal() if box != null else -1.0]
	var paint_frames := 2
	# B16: the panel leads, the portrait follows (never ahead of it).
	var portrait_lags := false
	var portrait_ahead := false

	while box != null and box.reveal() < 1.0 and paint_frames < 120:
		await _frames(1)
		paint_frames += 1
		portrait_lags = portrait_lags or box._panel_reveal > box._portrait_reveal + 0.05
		portrait_ahead = portrait_ahead or box._portrait_reveal > box._panel_reveal + 0.001

	var painted_in := paint_frames / 60.0
	await _reveal()
	var first: String = box.shown_text() if box != null else ""
	_check("B1 frob on a shade opens the box with the opener's first line",
		box != null and box is TalkBox and first == "<<She reads you.>>",
		"box %s, shown '%s'" % [box, first])

	if box == null:
		for missed in ["B2 the player is held while talking and freed on close", "B3 choosing an option advances the conversation and applies effects",
				"B4 hands busy: no box", "B5 hurt mid-talk closes the box without walked_off", "B6 a press inside OPTION_GUARD picks nothing",
				"B7 holding back 0.5 s walks away and sets walked_off"]:
			_check(missed, false, "no box opened")

		player.queue_free()
		shade.queue_free()
		await _frames(2)
		DialogueBook.reload()
		return

	# B13: the HUD gives way (the crosshair, the gem); B14: its rows are the
	# talk's; B15: the letter stays put away.
	var hud_during := hud_pieces.map(func(p): return _hud_piece(hud, p)) if hud != null else [1.0, 1.0, 1.0, 1.0]
	var line_rows: Array = player.frob.current_actions()
	var row_texts: PackedStringArray = hud.prompt_texts() if hud != null else PackedStringArray()
	player.frob.open_letter()
	Input.action_press("letter")
	await _frames(1)
	Input.action_release("letter")
	await _frames(5)
	var letter_up: bool = player.hand.is_page_up()
	_check("B15 the letter is refused while talking", not letter_up and _talking(player) == box, "page up %s" % letter_up)

	# B2 (held): pushing forward goes nowhere while the box is up.
	var held: bool = player.get("talk_hold") == true
	var before: Vector3 = player.global_position
	Input.action_press("move_forward")
	await _frames(30)
	Input.action_release("move_forward")
	var moved: float = player.global_position.distance_to(before)

	# B6: on to her sense line, then the options; a press at once, inside
	# OPTION_GUARD, picks nothing.
	box.press_advance()
	await _reveal()
	var sensed: String = box.shown_text()
	box.press_advance()
	await _frames(1)
	var offered: Array = box.shown_options()
	var option_rows: Array = player.frob.current_actions()
	box.press_advance()
	box.select(0)
	await _frames(1)
	_check("B6 a press inside OPTION_GUARD picks nothing",
		sensed == "<<The copal bends toward your shoulder.>>" and offered.size() >= 2 and offered[0] == "<<Ask about the book.>>"
		and box.conversation.is_waiting_for_choice() and box.shown_options() == offered
		and not CityState.people.holds("said(asked)", "fx_curandera"),
		"sense '%s', options %s, still waiting %s" % [sensed, offered, box.conversation.is_waiting_for_choice()])

	_check("B14 while talking the HUD shows no rows (no Choose, no 1-4, no Hold to walk away)",
		line_rows.is_empty() and option_rows.is_empty() and row_texts.is_empty(),
		"line %s, options %s, HUD %s" % [line_rows, option_rows, row_texts])

	# B9: draft 28's layout at 1920 x 1080 (its numbers, by hand: the panel
	# 1000 wide, 1000 / (1802 / 1050) tall, its top 40 px below H - that; the
	# portrait 320 x 470 overlapping it 70 px, 70 px above; the pair centred;
	# the name 146, the line 182, the options 318 + 50 i below the panel's top).
	await _frames(30)
	box._layout(Vector2(1920, 1080))
	var big: Dictionary = box.layout_rects()
	var tall := 1000.0 / (1802.0 / 1050.0)
	var top := 1080.0 - tall + 40.0
	var want := {"panel": Rect2(585, top, 1000, tall), "portrait": Rect2(335, top - 70, 320, 470)}
	var off: Array[String] = []

	for key in want:
		var got: Rect2 = big.get(key, Rect2())
		var w: Rect2 = want[key]

		if got.position.distance_to(w.position) > 2.0 or got.size.distance_to(w.size) > 2.0:
			off.append("%s %s not %s" % [key, got, w])

	for pair in [["name", 146.0], ["line", 182.0]] + range(offered.size()).map(func(i): return ["option %d" % i, 318.0 + 50.0 * i]):
		var got_y: float = (big.get(pair[0], Rect2()) as Rect2).position.y

		if absf(got_y - (top + float(pair[1]))) > 2.0:
			off.append("%s y %.1f not %.1f" % [pair[0], got_y, top + float(pair[1])])

	# Across: the name across the panel, the line's 560 px in its middle;
	# the options' words 30 px into one shared column (the longest + 70),
	# centred; every swipe from the column's left, the unchosen ones the
	# column wide, the chosen one longer by the marker (150 - 20 overlap),
	# its top 8 px above its words (the others 6).
	var column: float = box._plan.get("column", 0.0)
	var words_x := 585.0 + (1000.0 - column) * 0.5 + 30.0
	var across := {"name x": [(big.get("name", Rect2()) as Rect2).position.x, 585.0],
		"name w": [(big.get("name", Rect2()) as Rect2).size.x, 1000.0], "line x": [(big.get("line", Rect2()) as Rect2).position.x, 585.0 + 220.0]}

	for i in offered.size():
		var swipe: Rect2 = big.get("swipe %d" % i, Rect2())
		var chosen: bool = i == box._choice
		across["option %d x" % i] = [(big.get("option %d" % i, Rect2()) as Rect2).position.x, words_x]
		across["swipe %d x" % i] = [swipe.position.x, words_x - 30.0]
		across["swipe %d w" % i] = [swipe.size.x, column + (130.0 if chosen else 0.0)]
		across["swipe %d y" % i] = [swipe.position.y, top + 318.0 + 50.0 * i - (8.0 if chosen else 6.0)]

	for key in across:
		if absf(float(across[key][0]) - float(across[key][1])) > 2.0:
			off.append("%s %.1f not %.1f" % [key, across[key][0], across[key][1]])

	if column < 70.0:
		off.append("column %.1f" % column)

	_check("B9 at 1920x1080 the panel, the portrait and the words sit where draft 28 has them",
		off.is_empty() and big.size() >= 4 + 2 * offered.size(),
		"; ".join(off) if not off.is_empty() else "panel %s portrait %s" % [big.get("panel"), big.get("portrait")])

	# B10: at 1280 x 720 every rect is two thirds of the 1080p one.
	box._layout(Vector2(1280, 720))
	var small: Dictionary = box.layout_rects()
	var unlike: Array[String] = []

	for key in big:
		var a: Rect2 = big[key]
		var b: Rect2 = small.get(key, Rect2())

		if b.position.distance_to(a.position * 2.0 / 3.0) > 2.0 or b.size.distance_to(a.size * 2.0 / 3.0) > 2.0:
			unlike.append("%s %s not %s" % [key, b, Rect2(a.position * 2.0 / 3.0, a.size * 2.0 / 3.0)])

	_check("B10 at 1280x720 every rect is 2/3 of the 1080p one", unlike.is_empty() and small.size() == big.size(),
		"; ".join(unlike) if not unlike.is_empty() else "%d rects" % small.size())

	# B3: past the guard, choosing asks about the book: its beat sets the flag
	# and her next line comes.
	await _frames(int(ceil(TalkBox.OPTION_GUARD * 60.0)) + 2)
	box.select(0)
	await _reveal()
	var asked: bool = CityState.people.holds("said(asked)", "fx_curandera")
	var told: String = box.shown_text()
	_check("B3 choosing an option advances the conversation and applies effects",
		asked and told == "<<Bring me the book from the librarian.>>" and CityState.people.goals_shown.has("fx_bring_book"),
		"asked %s, shown '%s', goals %s" % [asked, told, CityState.people.goals_shown])

	# B2 (freed): leaving by the option closes the box and lets him go.
	box.press_advance()
	await _frames(int(ceil(TalkBox.OPTION_GUARD * 60.0)) + 2)
	box.select(box.shown_options().find("<<Leave.>>"))
	var lift_frames := 0
	# B16: closing, the words are gone before the paint is.
	var words_gone_first := false

	while is_instance_valid(box) and box.reveal() > 0.0 and lift_frames < 120:
		await _frames(1)
		lift_frames += 1

		if is_instance_valid(box) and box._words_ink <= 0.0 and box.reveal() > 0.0:
			words_gone_first = true

	var lifted := lift_frames / 60.0
	_check("B2 the player is held while talking and freed on close",
		held and moved < 0.01 and _talking(player) == null and player.get("talk_hold") == false,
		"held %s, moved %.3f m, box after %s, hold after %s" % [held, moved, _talking(player), player.get("talk_hold")])
	await _frames(20)
	var hud_after := hud_pieces.map(func(p): return _hud_piece(hud, p)) if hud != null else [0.0, 0.0, 0.0, 0.0]
	_check("B13 while talking the HUD's crosshair, gem, awareness marks and shields fade out, and come back after",
		hud != null and hud_before.all(func(a): return a > 0.9) and hud_during.all(func(a): return a < 0.01)
		and hud_after.all(func(a): return a > 0.9),
		"before %s, talking %s, after %s" % [hud_before, hud_during, hud_after])

	# B4: hands busy (a crate held, the letter up, hanging): no box, and the
	# prompt is a blocked status row.
	var crate := Props.crate(self, Vector3(0.6, 0.3, -0.6))
	await _frames(5)
	player.frob._pick_up(crate)
	await _frames(5)
	shade.frob(player)
	var carrying_box: Node = _talking(player)
	player.frob._release(false)
	crate.queue_free()
	await _frames(5)
	player.frob.open_letter()
	await _frames(5)
	shade.frob(player)
	var reading_box: Node = _talking(player)
	player.frob.put_page_away()
	await _frames(30)
	_aim(player, shade.global_position + Vector3(0, 1.2, 0))
	await _frames(5)
	var free_rows: Array = player.frob.current_actions()
	player.movement_state = player.MoveState.HANGING
	var hanging_rows: Array = player.frob.current_actions()
	shade.frob(player)
	var hanging_box: Node = _talking(player)
	player.movement_state = player.MoveState.LOCOMOTION
	_check("B4 hands busy: no box",
		carrying_box == null and reading_box == null and hanging_box == null and free_rows == [[&"frob", "Talk"]]
		and hanging_rows.size() == 1 and (hanging_rows[0] as Array)[0] == &"" and player.get("talk_hold") == false,
		"carrying %s, reading %s, hanging %s, rows free %s hanging %s" % [carrying_box, reading_box, hanging_box, free_rows,
		hanging_rows])

	# B5: a blow mid-talk breaks it off: closed at once, nothing remembered.
	await _press("frob")
	box = _talking(player)
	await _reveal()
	var reopened: String = box.shown_text() if box != null else ""
	var how := [&""]

	if box != null:
		box.conversation.ended.connect(func(h): how[0] = h)

	player.take_damage(10.0, null)
	var shut: bool = _talking(player) == null
	var gone_at_once: float = box.reveal() if is_instance_valid(box) else 0.0
	await _frames(2)
	_check("B5 hurt mid-talk closes the box without walked_off",
		reopened == "<<Back again.>>" and shut and how[0] == &"interrupted" and player.get("talk_hold") == false
		and not CityState.people.holds("said(walked_off)", "fx_curandera"),
		"reopened '%s', closed at once %s, ended %s, hold %s" % [reopened, shut, how[0], player.get("talk_hold")])
	_check("B16 the paint goes on within 0.7 s of open (the portrait after the panel), off within 0.45 s of close (the words first), and at once on interrupt",
		painting[0] >= 0.0 and painting[0] < 0.2 and painted_in <= 0.7 and lifted <= 0.45 and lifted > 0.1 and gone_at_once == 0.0
		and portrait_lags and not portrait_ahead and words_gone_first,
		"at open %.2f, whole after %.2f s, gone %.2f s after close, %.2f the frame it was broken off; portrait lags %s, ahead %s; words first %s" % [
		painting[0], painted_in, lifted, gone_at_once, portrait_lags, portrait_ahead, words_gone_first])

	# B7: a tap of back is not walking away; holding it 0.5 s is.
	await _frames(30)
	await _press("frob")
	var opened := _talking(player) != null
	await _reveal()
	Input.action_press("move_back")
	await _frames(15)
	Input.action_release("move_back")
	await _frames(5)
	var after_tap: bool = _talking(player) != null
	Input.action_press("move_back")
	await _frames(int(ceil(TalkBox.WALK_AWAY * 60.0)) + 3)
	var gone: bool = _talking(player) == null
	var hold_after: bool = player.get("talk_hold") == true
	Input.action_release("move_back")
	await _frames(2)
	_check("B7 holding back 0.5 s walks away and sets walked_off",
		opened and after_tap and gone and not hold_after and CityState.people.holds("said(walked_off)", "fx_curandera"),
		"opened %s, open after a tap %s, gone %s, hold %s, walked_off %s" % [opened, after_tap, gone, hold_after,
		CityState.people.holds("said(walked_off)", "fx_curandera")])

	player.queue_free()
	shade.queue_free()
	await _frames(2)
	CityState.people.load_state({})
	DialogueBook.reload()


## The box the player has open, or null.
## How much of a HUD piece shows (B13). The shields show only in a fight, so
## theirs is how far they have given way to the talk (their own fade).
func _hud_piece(hud: Node, piece: String) -> float:
	if piece == "shields":
		return (hud._shields as CanvasItem).self_modulate.a

	return hud.shown(piece)


func _talking(player: Node) -> Node:
	return player.frob.talking() if player.frob.has_method("talking") else null


## Turns the player's view on `point`.
func _aim(player: CharacterBody3D, point: Vector3) -> void:
	var eye: Vector3 = player.get_node("Neck/Camera3D").global_position
	var to := point - eye
	player.rotation.y = atan2(-to.x, -to.z)
	player.get_node("Neck").rotation.x = atan2(to.y, Vector2(to.x, to.z).length())


## One press of an action, a frame long.
func _press(action: StringName) -> void:
	Input.action_press(action)
	await _frames(1)
	Input.action_release(action)
	await _frames(1)


## Long enough for any fixture line to be told out.
func _reveal() -> void:
	await _frames(int(ceil(48.0 / TalkBox.REVEAL_CPS * 60.0)) + 4)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _entry(parsed: Dictionary, kind: String, id: String) -> Dictionary:
	for entry in parsed["entries"]:
		if String(entry["kind"]) == kind and entry["id"] == id:
			return entry

	return {}


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
