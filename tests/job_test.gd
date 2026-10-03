extends Node3D
## The job (the harbour's job plan): the words files and their parser
## (J1-J6), the job's progress (J7-J14), the tally (J15).
##   Godot --headless --fixed-fps 60 --path . res://tests/job_test.tscn
##
## The words still to write (every text in <<...>>) are printed as WORDS:
## lines; their number never fails a check.

const JobBook := preload("res://scripts/Level/JobBook.gd")

var results: Array[String] = []


func _ready() -> void:
	_files()
	print("\n==== RESULTS ====")

	for line in results:
		print(line)

	var failed := results.filter(func(r): return r.begins_with("FAIL")).size()
	print("\n%d pass, %d fail" % [results.size() - failed, failed])
	get_tree().quit()


# ---------------------------------------------------------------------------
# J1-J6: the files
# ---------------------------------------------------------------------------

func _files() -> void:
	var lib: Dictionary = JobBook.load_dir()
	var ids: Array = (lib.get("goals", []) as Array).map(func(g): return String(g["id"]))
	_check("J1 the job files parse with no errors",
		(lib.get("errors", ["no library"]) as Array).is_empty() and ids == ["loot", "seal", "up", "captains_ring", "signet"],
		"errors %s, goals %s" % [lib.get("errors"), ids])

	var two: Dictionary = JobBook.parse("== note a\ntext:\nline one\n\nline two\n\n== note b\ntext: x", "t.job")
	var a_text := ""

	for entry in two["entries"]:
		if entry["id"] == "a":
			a_text = entry["text"]

	_check("J2 a text block runs to the next header", a_text == "line one\n\nline two" and (two["errors"] as Array).is_empty(),
		"a's text %s, errors %s" % [JSON.stringify(a_text), two["errors"]])

	var broken := {
		"an unknown kind": ["== bell x\ntext: hm", 1],
		"a goal with no done": ["== goal g\nkind: main\ntext: hm", 1],
		"a bad condition": ["== goal g\nkind: main\ndone: took(\ntext: hm", 3],
		"a note that is not there": ["== goal g\nkind: main\ndone: took(x)\nnote: missing_note\ntext: hm", 4],
		"a gate needing no goal": ["== gate g\nexits: to(old_town)\nneeds: no_goal\ntext: hm", 3],
	}
	var wrong: Array[String] = []

	for what in broken:
		var parsed: Dictionary = JobBook.check_alone(String(broken[what][0]), "t.job")
		var errors: Array = parsed["errors"]

		if errors.size() != 1 or not String(errors[0]).contains("t.job:%d" % int(broken[what][1])):
			wrong.append("%s: %s" % [what, errors])

	_check("J3 errors name file and line", wrong.is_empty(), "; ".join(wrong) if not wrong.is_empty() else "five broken files, one error each")

	var good := JobBook.condition_error("took(a), not(done(b)), loot>=5")
	var bad := JobBook.condition_error("stole(a)")
	_check("J4 conditions: the words a goal may use, and no others", good == "" and bad != "", "good '%s', bad '%s'" % [good, bad])

	var words: Array = JobBook.placeholders(lib)
	var placed := words.all(func(w): return String(w).begins_with("harbour.job:") or String(w).begins_with("mission.job:"))

	for w in words:
		print("WORDS: %s" % w)

	_check("J5 placeholders are listed, each by file and line", words.size() >= 23 and placed, "%d still to write" % words.size())

	var missing: Array[String] = []

	for kind in ["goals", "readables"]:
		var entries: Variant = lib.get(kind, {})

		for entry in (entries.values() if entries is Dictionary else entries):
			var note := String(entry.get("note", ""))

			if note != "" and not (lib.get("notes", {}) as Dictionary).has(note):
				missing.append("%s -> %s" % [entry["id"], note])

	_check("J6 every readable's and goal's note exists", missing.is_empty() and not (lib.get("readables", {}) as Dictionary).is_empty(),
		"missing %s, %d readables" % [missing, (lib.get("readables", {}) as Dictionary).size()])


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
