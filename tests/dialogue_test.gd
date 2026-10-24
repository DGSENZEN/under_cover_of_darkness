extends Node3D
## The character dialogue files (the talk and quests spec, section 1): the
## .dialogue parser (D1-D4) and the words conditions and effects share (D5).
##   Godot --headless --fixed-fps 60 --path . res://tests/dialogue_test.tscn

const DialogueBook := preload("res://scripts/Level/DialogueBook.gd")
const JobBook := preload("res://scripts/Level/JobBook.gd")
const Terms := preload("res://scripts/Level/Terms.gd")

var results: Array[String] = []


func _ready() -> void:
	_parser()
	_terms()
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


func _entry(parsed: Dictionary, kind: String, id: String) -> Dictionary:
	for entry in parsed["entries"]:
		if String(entry["kind"]) == kind and entry["id"] == id:
			return entry

	return {}


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
