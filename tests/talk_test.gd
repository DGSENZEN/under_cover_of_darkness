extends Node3D
## What the men say to each other: the .talk files and their parser
## (TalkScript), the facts and casting (TalkFacts), the director that plays
## conversations (TalkDirector), and the voice they come out in (GuardVoice).
##
##   Godot --headless --fixed-fps 60 --quit-after 3000000 --path . res://tests/talk_test.tscn

const TalkScript := preload("res://scripts/AISystem/Talk/TalkScript.gd")

var results: Array[String] = []


func _ready() -> void:
	await _run()
	print("\n==== RESULTS ====")

	for r in results:
		print(r)

	get_tree().quit()


func _run() -> void:
	_files()


# ---------------------------------------------------------------------------
# The files
# ---------------------------------------------------------------------------

func _files() -> void:
	# T1 the talk files load clean
	var lib := TalkScript.load_dir()
	var cast: Dictionary = lib["cast"]
	_check("T1 the talk files load clean, the cast sheet has all twelve and its ties run both ways where they should",
		lib["errors"].is_empty() and lib["conversations"].size() >= 13 and cast.size() == 12
		and "Jory" in cast["Osric"]["ties"]["kin"] and "Osric" in cast["Jory"]["ties"]["kin"]
		and "Col" in cast["Piers"]["ties"]["owes"] and not ("Piers" in cast["Col"]["ties"]["owes"])
		and cast["Mirelle"]["rank"] == 4 and "captain" in cast["Mirelle"]["traits"],
		"errors %s, conversations %d, cast %s" % [lib["errors"], lib["conversations"].size(), cast.keys()])

	# T2 a sample reads as written
	var glass: Dictionary = _conv(lib, "the_moon_glass")
	_check("T2 the_moon_glass reads as written",
		not glass.is_empty() and glass["when"] == [["at_ease"], ["night:early", "night:middle"]]
		and glass["cast"][1]["reqs"] == [["friend(A)", "any"]] and glass["cooldown"] == TalkScript.ONCE
		and glass["lines"].size() == 4 and glass["lines"][3]["part"] == "B" and glass["lines"][3]["choices"].size() == 2
		and glass["lines"][3]["choices"][0]["if"] == "stubborn" and glass["lines"][3]["choices"][1]["if"] == ""
		and glass["lines"][0]["choices"][0]["emotes"] == ["looks:the tower"],
		str(glass))

	# T3 a bad file reports its file and line
	var bad := TalkScript.parse("== x\ncast: A = any\nA [dances]: Hi.\nQ: Who?\n== x\ncast: A = any\nA: Again.\n", "bad.talk")
	var errs: String = "\n".join(bad["errors"])
	_check("T3 a bad file names the file and line of each fault",
		errs.contains("bad.talk:3") and errs.contains("bad.talk:4") and errs.contains("bad.talk:5"), errs)

	# T4 turn and turn about
	var wrong := []

	for c in lib["conversations"]:
		if c["cast"].size() >= 2 and c["lines"].size() >= 2 and c["lines"][0]["part"] == c["lines"][1]["part"]:
			wrong.append(c["id"])

	_check("T4 every conversation of two or more opens with two different speakers", wrong.is_empty(), str(wrong))


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _conv(lib: Dictionary, id: String) -> Dictionary:
	for c in lib["conversations"]:
		if c["id"] == id:
			return c

	return {}


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _until(cond: Callable, max_frames: int) -> void:
	for i in max_frames:
		if cond.call():
			return

		await get_tree().physics_frame


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
