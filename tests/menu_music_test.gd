extends Node
## The menu score: its clock, layers, jingles and ending, against a test score.
var failures := 0

func check(ok: bool, message: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + message)
	if not ok:
		failures += 1

func near(a: float, b: float, within := 0.0005) -> bool:
	return absf(a - b) <= within

func _ready() -> void:
	clock_checks()
	print("==== RESULTS ====")
	get_tree().quit(1 if failures else 0)

func clock_checks() -> void:
	check(near(MenuClock.beat_seconds(78.0), 0.76923), "a beat at 78 bpm")
	check(MenuClock.next_eighth(0.0, 78.0) == 0.0, "on an eighth, it is now")
	check(MenuClock.next_eighth(0.001, 78.0) == 0.0, "just after an eighth still counts as it")
	check(near(MenuClock.next_eighth(0.01, 78.0), 0.38462), "otherwise the next eighth")
	check(MenuClock.bar_at(3.1, 78.0, 4) == 1, "bar from position")
	var chords := [{"bar": 0, "name": "Dm"}, {"bar": 4, "name": "Gm"}]
	check(MenuClock.chord_at(chords, 5, 16) == "Gm", "chord in a later bar")
	check(MenuClock.chord_at(chords, 17, 16) == "Dm", "chords wrap with the loop")
	check(near(MenuClock.phrase_end_after(10.0, 78.0, 4, 8), 24.615, 0.001), "end of the current phrase")
	check(near(MenuClock.corrected(1.0, 0.01, 0.03), 0.98), "latency-corrected position")
	check(MenuClock.corrected(0.01, 0.0, 0.03) == 0.0, "corrected position never negative")
