extends Node3D
## The job (the harbour's job plan): the words files and their parser
## (J1-J6), the job's progress (J7-J14), the tally (J15).
##   Godot --headless --fixed-fps 60 --path . res://tests/job_test.tscn
##
## The words still to write (every text in <<...>>) are printed as WORDS:
## lines; their number never fails a check.

const JobBook := preload("res://scripts/Level/JobBook.gd")
const JobState := preload("res://scripts/Level/JobState.gd")
const LoadingScreen := preload("res://scripts/UI/LoadingScreen.gd")

var results: Array[String] = []


func _ready() -> void:
	_files()
	_progress()
	await _hold()
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


# ---------------------------------------------------------------------------
# J7-J14: the job's progress
# ---------------------------------------------------------------------------

func _fresh() -> RefCounted:
	var job: RefCounted = JobState.new()
	job.reset()
	return job


func _progress() -> void:
	var job := _fresh()
	var heard := {"shown": [], "done": [], "noted": []}
	job.goal_shown.connect(func(id): heard["shown"].append(id))
	job.goal_done.connect(func(id, kind): heard["done"].append([id, kind]))
	job.noted.connect(func(id): heard["noted"].append(id))
	job.arrive(&"harbour")
	var listed: Array = job.goals_listed().map(func(g): return g["id"])
	var quiet: bool = (heard["shown"] as Array).is_empty()
	job.took_loot("the_seal", 250)
	var sealed: bool = job.done.has("seal") and heard["done"].has(["seal", &"main"]) and heard["shown"].has("up") and job.notes.has("way_up")
	job.arrive(&"old_town")
	_check("J7 goals unfold: listed on arrival, done when taken, the next shown with its note, done on arriving",
		listed == ["loot", "seal", "captains_ring", "signet"] and quiet and sealed and job.done.has("up"),
		"listed %s, quiet %s, sealed %s, heard %s, done %s" % [listed, quiet, sealed, heard, job.done])

	job = _fresh()
	var noted := []
	job.noted.connect(func(id): noted.append(id))
	job.learn("office_key")
	job.learn("office_key")
	job.learn("tower_bell")
	job.learn("no_such_note")
	_check("J8 notes learnt once, in order; an unknown one ignored", job.notes == ["office_key", "tower_bell"] and noted.size() == 2,
		"notes %s, noted %s" % [job.notes, noted])

	job = _fresh()
	job.arrive(&"harbour")
	job.read_slot("duty_orders")
	job.read_slot("duty_orders")
	_check("J9 reading a readable once: read, its note learnt, counted",
		job.read_slots == ["duty_orders"] and job.notes == ["office_key"] and int(job.tally_of(&"harbour").get("read", 0)) == 1,
		"read %s, notes %s, tally %s" % [job.read_slots, job.notes, job.tally_of(&"harbour")])

	job = _fresh()
	job.arrive(&"harbour")
	var sea_gate := Area3D.new()
	sea_gate.name = "exit_sea_gate"
	sea_gate.set_meta(&"to", &"old_town")
	var river := Area3D.new()
	river.name = "exit_river"
	river.set_meta(&"to", &"gorge")
	var before: Dictionary = job.gate_for(sea_gate)
	var elsewhere: Dictionary = job.gate_for(river)
	job.took_loot("the_seal", 250)
	var after: Dictionary = job.gate_for(sea_gate)
	_check("J10 the gate turns you back without the seal, and only on the ways up",
		String(before.get("text", "")).begins_with("<<") and elsewhere.is_empty() and after.is_empty(),
		"before %s, river %s, after %s" % [before.get("text", "-"), elsewhere, after])
	sea_gate.free()
	river.free()

	job = _fresh()
	job.arrive(&"harbour")
	var first: bool = job.notice_theft()
	var second: bool = job.notice_theft()
	_check("J11 the theft counts once in a district", first and not second and int(job.tally_of(&"harbour").get("alarms", 0)) == 1
		and job.fact(&"harbour", &"theft_noticed") == true, "first %s, second %s, tally %s" % [first, second, job.tally_of(&"harbour")])

	job = _fresh()
	job.arrive(&"harbour")
	job.took_loot("the_seal", 250)
	job.learn("blowhole")
	job.notice_theft()
	job.count("seconds", 30)
	job.letter_opened = true
	var copy := _fresh()
	copy.load_state(job.save_state())
	var same := true

	for key in ["done", "notes", "took", "loot", "tally", "facts", "arrived", "letter_opened", "shown", "read_slots"]:
		same = same and str(copy.get(key)) == str(job.get(key))

	_check("J12 the job's state round-trips", same, "saved %s" % JSON.stringify(job.save_state()).left(200))

	job = _fresh()
	job.arrive(&"harbour")
	job.set_total("loot_total", 2040)
	job.count("loot", 250)
	job.count("seconds", 754)
	var rows: Array = job.tally_rows(&"harbour")
	var labels: Array = rows.map(func(r): return r[0])
	_check("J13 the tally's rows, labelled",
		labels == ["Loot", "Specials", "Notes read", "Knocked out", "Killed", "Bodies found", "Times seen", "Alarms", "Time"]
		and rows[0] == ["Loot", "250 of 2040"] and rows[-1] == ["Time", "12:34"], "rows %s" % [rows])

	CityState.job.took_loot("the_seal", 250)
	var had: bool = not CityState.job.took.is_empty()
	CityState.begin()
	_check("J14 a new mission starts a new job", had and CityState.job.took.is_empty(), "had %s, after %s" % [had, CityState.job.took])


# ---------------------------------------------------------------------------
# J16: the tally's hold keeps the world still, and lets it go if it is gone
# ---------------------------------------------------------------------------

func _hold() -> void:
	LoadingScreen.holds = true
	var screen: CanvasLayer = LoadingScreen.open(self, "")
	screen.hold()
	await get_tree().process_frame
	await get_tree().process_frame
	var held: bool = get_tree().paused
	# (The pause screen's resume, Esc, under the held screen.)
	get_tree().paused = false
	await get_tree().process_frame
	await get_tree().process_frame
	var kept: bool = get_tree().paused
	screen.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	var freed: bool = not get_tree().paused
	get_tree().paused = false
	_check("J16 the tally's hold keeps the world still (resumed under it, it stills it again) and lets it go when gone", held and kept and freed,
		"held %s, kept %s, let go %s" % [held, kept, freed])


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
