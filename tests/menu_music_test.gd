extends Node
## The menu score: its clock, layers, jingles and ending, against a test score.
var failures := 0

func check(ok: bool, message: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + message)
	if not ok:
		failures += 1

func near(a: float, b: float, within := 0.0005) -> bool:
	return absf(a - b) <= within

const FIXTURE := "res://tests/fixtures/menu_score/score.json"
const BEAT := 60.0 / 78.0
const BAR := BEAT * 4.0
var pos := 0.0

func make_music(path := FIXTURE) -> MenuMusic:
	var music := MenuMusic.new()
	music.score_json_path = path
	music.position_source = func() -> float: return pos
	add_child(music)
	music.set_process(false)
	music.score.chords = [{"bar": 0, "name": "Dm"}, {"bar": 4, "name": "Gm"}]
	return music

## Advance simulated time in 1/60 s steps, moving the song position with it.
func run_for(music: MenuMusic, seconds: float) -> void:
	var steps := roundi(seconds * 60.0)
	for i in range(steps):
		pos += 1.0 / 60.0
		music.step(1.0 / 60.0)

func _ready() -> void:
	clock_checks()
	layer_checks()
	await get_tree().process_frame
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

func layer_checks() -> void:
	pos = 0.0
	var music := make_music()
	check(music.available and music.score.stems.size() == 7, "the test score loads")
	check(music.player.bus == &"Music", "plays on the Music bus, made if missing")
	check(music.state == MenuMusic.State.ARRIVAL, "the menu opens arriving")
	check(music.layer_target_db(&"base") == 0.0 and music.layer_target_db(&"fx") == 0.0 and music.layer_target_db(&"high") == -80.0, "arrival: base and fx in, high out")
	check(music.layer_target_db(&"low") <= -60.0, "arrival: the groove starts out")
	run_for(music, 2.0 * BAR)
	check(music.layer_target_db(&"low") > -10.0 and music.layer_target_db(&"low") < 0.0, "arrival: the groove comes in over four bars")
	run_for(music, 2.0 * BAR + 0.05)
	check(music.state == MenuMusic.State.BROWSING and music.layer_target_db(&"low") == 0.0, "after four bars it is browsing, groove full")
	check(music.layer_target_db(&"high") == -80.0 and music.layer_target_db(&"fx") == -12.0, "browsing at rest: high out, fx low")
	music.activity = 1.0
	check(is_equal_approx(music.layer_target_db(&"high"), -3.0), "browsing busily: high in at -3 dB")
	music.set_selected(-1)
	var plain := music.stem_target_db(&"rhodes")
	music.set_selected(2)
	check(is_equal_approx(music.stem_target_db(&"rhodes"), minf(plain + 4.0, 0.0)) and music.stem_target_db(&"trumpet") == plain, "the chosen word's instrument leans forward")
	music.set_state(MenuMusic.State.LORE)
	check(music.layer_target_db(&"low") == -12.0 and music.layer_target_db(&"high") == -14.0 and music.layer_target_db(&"fx") == 0.0, "Lore: the occult layer forward")
	music.set_state(MenuMusic.State.SETTINGS)
	check(music.layer_target_db(&"low") == -14.0 and music.layer_target_db(&"high") == -80.0 and music.layer_target_db(&"fx") == -14.0, "Settings: stripped back")
	run_for(music, 3.0)
	check(is_equal_approx(music.stem_gain_db(&"drums"), -14.0) and music.layer_energy(&"low") < 0.25, "gains glide to their targets")
	music.set_state(MenuMusic.State.BROWSING)
	music.activity = 0.0
	music.note_input()
	run_for(music, 30.5)
	check(music.state == MenuMusic.State.IDLE and music.layer_target_db(&"base") == -10.0 and music.layer_target_db(&"low") == -80.0, "30 s untouched: idle floor")
	pos = 9.5 * BAR
	music.note_input()
	music.step(0.0)
	check(music.state == MenuMusic.State.IDLE, "waking waits for the bar line")
	pos = 10.0 * BAR - 0.01
	music.step(0.0)
	check(music.state == MenuMusic.State.IDLE, "still waiting just before it")
	pos = 10.0 * BAR + 0.001
	music.step(0.0)
	check(music.state == MenuMusic.State.BROWSING, "back to browsing on the bar line")
	music.queue_free()
	var silent := make_music("res://tests/fixtures/no_such_score.json")
	silent.set_state(MenuMusic.State.LORE)
	silent.set_selected(1)
	silent.note_input()
	silent.step(0.1)
	check(not silent.available and silent.layer_energy(&"base") == 0.0, "no score: silent, no errors")
	silent.queue_free()
