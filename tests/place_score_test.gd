extends Node
## The place score (docs/superpowers/specs/2026-10-31-metro-score-design.md):
## its clock, zones, theme sets, variants and the ánimas' acts, against the
## test score in tests/fixtures/place_score (240 bpm: a bar is one second).
var failures := 0

func check(ok: bool, message: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + message)
	if not ok:
		failures += 1

func near(a: float, b: float, within := 0.0005) -> bool:
	return absf(a - b) <= within

const FIXTURE := "res://tests/fixtures/place_score/score.json"
## The fixture: 240 bpm, a bar is one second, a phrase four.
const BAR := 1.0
const PHRASE := 4.0
const STEP := 1.0 / 60.0
## A swell from silence, and the longest weight glide (1 / WEIGHT_GLIDE), with a little over.
const SWELL := 1.5
const GLIDE := 1.25
var pos := 0.0


## Zones a test sets by hand.
class StubZones extends PlaceZones:
	var w := {}
	var d := 0.0

	func weights_at(_point: Vector3) -> Dictionary:
		return w

	func depth_at(_point: Vector3) -> float:
		return d


func make_score(path := FIXTURE, with_cue := false) -> PlaceScore:
	pos = 0.0
	var score := PlaceScore.new()
	score.score_json_path = path
	score.play_cue = with_cue
	score.position_source = func() -> float: return pos
	score.cue_source = func() -> float: return pos
	score.listener_source = func() -> Vector3: return Vector3.ZERO
	score.zones = StubZones.new()
	add_child(score)
	score.set_process(false)
	return score


## Advance the bed's position in 1/60 s steps, stepping the score with it;
## `scale` scales only the frame's delta (slow motion: the audio runs on).
func run_for(score: PlaceScore, seconds: float, scale := 1.0) -> void:
	for i in range(roundi(seconds / STEP)):
		pos += STEP
		score.step(STEP * scale)


func _ready() -> void:
	clock_checks()
	zone_checks()
	score_checks()
	variant_checks()
	anima_checks()
	cue_checks()
	await metro_checks()
	await get_tree().process_frame
	print("==== RESULTS ====")
	get_tree().quit(1 if failures else 0)

func clock_checks() -> void:
	check(near(PlaceClock.bar_seconds(72.0, 4), 3.33333), "P1 a bar at 72 bpm")
	check(near(PlaceClock.next_phrase_line(13.2, 13.3333), 13.3333), "P2 the next phrase line")
	check(near(PlaceClock.next_phrase_line(13.3335, 13.3333), 13.3333), "P3 just past a line still counts as it")
	check(near(PlaceClock.theme_offset(40.0, 13.3333), 0.0001, 0.001), "P4 a theme's place in its loop from bed time")
	check(near(PlaceClock.theme_offset(26.0, 26.6667), 26.0), "P5 within its first loop, bed time itself")

func zone_checks() -> void:
	var plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/eclipse/metro/plan.json"))
	var spaces := {"candle_lane": "lane", "librarian_shop": "librarian", "pasaje": "pasaje"}
	var circles := [{"theme": "curandera", "inside": "candle_lane", "at": [12.8, -11.0, 73.2], "radius": 3.5, "full": 1.5}]
	var zones := PlaceZones.from_plan(plan, spaces, circles)
	var w := zones.weights_at(Vector3(5.0, -11.0, 75.45))
	check(w.size() == 1 and near(float(w.get("lane", 0.0)), 1.0), "Z1 the lane's middle is the lane's alone: %s" % w)
	w = zones.weights_at(Vector3(-4.0, -11.0, 75.45))
	check(near(float(w.get("lane", 0.0)), 0.5, 0.05) and near(float(w.get("pasaje", 0.0)), 0.5, 0.05), "Z2 on the lane's mouth, half and half: %s" % w)
	w = zones.weights_at(Vector3(-2.5, -11.0, 75.45))
	check(near(float(w.get("lane", 0.0)), 0.75, 0.05) and near(float(w.get("pasaje", 0.0)), 0.25, 0.05), "Z3 1.5 m in, mostly the lane: %s" % w)
	w = zones.weights_at(Vector3(12.8, -11.0, 74.2))
	check(near(float(w.get("curandera", 0.0)), 1.0, 0.01) and near(float(w.get("lane", 0.0)), 0.4, 0.01), "Z4 at her stall the lane leans to her: %s" % w)
	w = zones.weights_at(Vector3(12.8, -11.0, 75.7))
	var hers := float(w.get("curandera", 0.0))
	check(hers > 0.0 and hers < 1.0, "Z5 nearing her stall, partly hers: %s" % w)
	check(zones.theme_of("chapel") == "lane", "Z6 the chapel opens from the lane, so it is the lane's")
	check(near(zones.depth_at(Vector3(5.0, -11.0, 75.45)), 0.35) and near(zones.depth_at(Vector3(0.0, -14.0, -10.0)), 0.0), "Z7 depth by age: the market 0.35, the platform 0")
	check(near(zones.depth_at(Vector3(100.0, -26.0, -185.0)), 1.0) and near(zones.depth_at(Vector3(0.0, -21.0, 0.0)), 0.7), "Z8 the old layer 0.7, deeper toward the shells' 1")
	check(zones.space_at(Vector3(0.0, 5.0, 0.0)) == "", "Z9 over the hall's ceiling is in no space")

func score_checks() -> void:
	var score := make_score()
	var zones := score.zones as StubZones
	check(score.available and score.bed_playing(), "S1 the bed plays at once")
	# Depth is only read while standing in some space (some weight).
	zones.w = {"a": 0.0}
	run_for(score, SWELL)
	check(near(score.stem_gain_db(&"bed", &"drone_city"), 0.0, 0.5) and score.stem_gain_db(&"bed", &"drone_deep") <= -79.0, "S1 at depth 0, the city drone alone")
	zones.d = 1.0
	run_for(score, 4.0)
	check(score.stem_gain_db(&"bed", &"drone_city") <= -79.0 and near(score.stem_gain_db(&"bed", &"drone_deep"), 0.0, 0.5), "S2 at depth 1, the deep drone alone")
	zones.d = 0.0
	score.free()

	score = make_score()
	zones = score.zones as StubZones
	run_for(score, 0.3)
	zones.w = {"a": 1.0}
	run_for(score, 3.6)
	check(not score.theme_playing(&"a"), "S3 not before the next phrase line")
	run_for(score, 0.2)
	check(score.theme_playing(&"a") and near(score.theme_started_at(&"a"), PHRASE, 0.02), "S3 a theme starts on the phrase line: %.3f" % score.theme_started_at(&"a"))
	run_for(score, BAR)
	check(score.stem_gain_db(&"a", &"lead") >= -1.0 and score.stem_gain_db(&"a", &"lead_full") <= -79.0, "S4 a bar in, the calm lead is up, the full one not")
	run_for(score, 2.0 * PHRASE)
	check(score.intensity_of(&"a") == &"full" and score.stem_gain_db(&"a", &"lead_full") >= -1.0, "S5 two phrases on, the theme is full")
	var started := score.theme_started_at(&"a")
	zones.w = {"a": 0.0}
	run_for(score, 1.0 * BAR)
	zones.w = {"a": 1.0}
	run_for(score, 2.0 * BAR)
	check(score.theme_playing(&"a") and near(score.theme_started_at(&"a"), started) and score.stem_gain_db(&"a", &"lead") >= -1.0, "S7 coming back while it fades swells it back, no restart")
	zones.w = {"a": 0.0}
	# The weight glides to nothing (1.25 s at most), then FADE_BARS of fade.
	run_for(score, GLIDE + 2.0 * BAR + 0.05)
	check(score.stem_gain_db(&"a", &"lead") <= -79.0, "S6 two bars after leaving, it has faded out: %.1f" % score.stem_gain_db(&"a", &"lead"))
	run_for(score, PHRASE + 0.1)
	check(not score.theme_playing(&"a"), "S6 a phrase at silence, it stops")
	score.free()

	score = make_score()
	zones = score.zones as StubZones
	var starts := 0
	var was := false
	var worst := 0.0
	var last := 0.0
	for i in range(80):
		zones.w = {"a": float(i % 2)}
		for j in range(6):
			pos += STEP
			score.step(STEP)
			var now := score.theme_weight(&"a")
			worst = maxf(worst, absf(now - last) / STEP)
			last = now
			if score.theme_playing(&"a") and not was:
				starts += 1
			was = score.theme_playing(&"a")
	check(starts <= 1 and worst <= PlaceScore.WEIGHT_GLIDE + 0.01, "S8 flickering on a threshold: %d starts, weight moving %.2f/s at most" % [starts, worst])
	score.free()

	score = make_score()
	zones = score.zones as StubZones
	zones.w = {"a": 1.0}
	run_for(score, PHRASE + 2.0)
	var lead := score.stem_gain_db(&"a", &"lead")
	zones.w = {}
	run_for(score, 2.0)
	check(near(score.stem_gain_db(&"a", &"lead"), lead, 0.5) and score.theme_playing(&"a"), "S9 in no space, the last weights hold")
	zones.w = {"a": 1.0}
	zones.d = 0.5
	run_for(score, 3.0)
	check(near(score.stem_gain_db(&"a", &"lead") - score.stem_gain_db(&"a", &"lead_city"), 12.0, 0.5), "S10 a city part sits 12 dB under at depth 0.5")
	zones.d = 0.0
	score.free()

	score = make_score()
	zones = score.zones as StubZones
	zones.w = {"a": 1.0}
	run_for(score, PHRASE + 0.05)
	run_for(score, 4.0 * 8.0 + 2.5)
	check(score.intensity_of(&"a") == &"rest" and score.stem_gain_db(&"a", &"lead") <= -79.0 and score.stem_gain_db(&"a", &"bass") >= -1.0, "S11 after four loops it rests, the bass alone")
	run_for(score, 2.0 * PHRASE - 2.4)
	check(score.intensity_of(&"a") == &"calm", "S11 after its rest, calm again")
	score.free()

	var timings := []
	for scale in [1.0, 0.25]:
		score = make_score()
		zones = score.zones as StubZones
		Engine.time_scale = scale
		run_for(score, 0.3, scale)
		zones.w = {"a": 1.0}
		run_for(score, PHRASE + 1.0, scale)
		timings.append([score.theme_started_at(&"a"), score.stem_gain_db(&"a", &"lead")])
		Engine.time_scale = 1.0
		score.free()
	check(near(timings[0][0], timings[1][0]) and near(timings[0][1], timings[1][1], 0.01), "S12 slow motion does not slow the score: %s" % [timings])

	# The mixer runs ahead of what is heard: a theme starts when the bed's next
	# mixed chunk reaches the line, from where the bed is in it, loop after loop.
	score = make_score()
	zones = score.zones as StubZones
	score.raw_source = func() -> float: return pos - 0.1
	zones.w = {"a": 1.0}
	run_for(score, PHRASE + 0.05)
	check(not score.theme_playing(&"a"), "S14 heard at the line, the mixer not yet: no start")
	run_for(score, 0.1)
	check(score.theme_playing(&"a") and score.theme_start_offset(&"a") <= STEP + 0.001, "S14 started as the mixer reaches the line, from its top: %.3f" % score.theme_start_offset(&"a"))
	zones.w = {"a": 0.0}
	run_for(score, 3.0 * PHRASE)
	zones.w = {"a": 1.0}
	run_for(score, 2.0 * PHRASE)
	check(score.theme_playing(&"a") and score.theme_start_offset(&"a") <= STEP + 0.001, "S15 after the bed has looped, still from its top: %.3f" % score.theme_start_offset(&"a"))
	score.free()

	score = make_score("res://tests/fixtures/place_score/nowhere.json")
	check(not score.available, "S13 no score, silent")
	run_for(score, 1.0)
	score.free()

func variant_checks() -> void:
	var people: RefCounted = preload("res://scripts/Level/PeopleState.gd").new()
	var score := make_score()
	var zones := score.zones as StubZones
	score.people_source = func() -> RefCounted: return people
	zones.w = {"b": 1.0}
	run_for(score, PHRASE + 2.0)
	check(score.part_choice(&"b", &"lead") == &"lead", "V1 not met: the plain lead")
	people.meet("curandera")
	run_for(score, 1.0)
	check(score.part_choice(&"b", &"lead") == &"lead", "V2 met mid-phrase: no change before the line")
	run_for(score, 1.05)
	check(score.part_choice(&"b", &"lead") == &"lead_met", "V2 on the next phrase line, her variant")
	run_for(score, BAR)
	check(score.stem_gain_db(&"b", &"lead_met") >= -1.0 and score.stem_gain_db(&"b", &"lead") <= -79.0, "V3 a bar after the switch: %.1f / %.1f" % [score.stem_gain_db(&"b", &"lead_met"), score.stem_gain_db(&"b", &"lead")])
	score.free()

	score = make_score()
	zones = score.zones as StubZones
	score.people_source = func() -> Variant: return null
	zones.w = {"b": 1.0}
	run_for(score, PHRASE + 2.0)
	check(score.part_choice(&"b", &"lead") == &"lead" and score.stem_gain_db(&"b", &"lead") >= -1.0, "V4 no one remembered: the defaults")
	score.free()

func souls(states: Array) -> Array:
	var out := []
	for state in states:
		out.append({"state": state, "at": Vector3(2.0, 0.0, 0.0)})
	return out

func anima_checks() -> void:
	# Changed in place: a lambda holds what its locals were when it was made.
	var near_souls := []
	var score := make_score()
	var zones := score.zones as StubZones
	score.animas_source = func() -> Array: return near_souls
	zones.w = {"a": 1.0}
	run_for(score, PHRASE + 2.0)
	near_souls.clear()
	near_souls.append_array(souls(["warming", "lurking", "warming"]))
	run_for(score, 3.0)
	var h := score.haunt()
	check(h.values().max() <= 0.0001 and near(PlaceScore.chorus().wet, 0.0, 0.001), "A1 near but only warming and lurking: nothing changes: %s" % h)
	near_souls.clear()
	near_souls.append_array(souls(["pleading"]))
	run_for(score, 1.0)
	h = score.haunt()
	check(float(h[&"pleading"]) >= 0.9 and near(PlaceScore.chorus().wet, PlaceScore.DETUNE_WET, 0.03), "A2 one begging you: the lead detunes (%.2f wet)" % PlaceScore.chorus().wet)
	run_for(score, 0.5)
	check(score.stem_gain_db(&"a", &"haunt") >= -2.0, "A2 and its pleading stem comes in: %.1f" % score.stem_gain_db(&"a", &"haunt"))
	near_souls.clear()
	run_for(score, 3.0)
	check(float(score.haunt()[&"pleading"]) <= 0.1 and score.stem_gain_db(&"a", &"haunt") <= -40.0, "A3 when it stops, it lets go")
	near_souls.clear()
	near_souls.append_array(souls(["dragged"]))
	run_for(score, 1.0)
	check(score.stem_gain_db(&"bed", &"pulse") <= -10.0 and PlaceScore.muffle().cutoff_hz <= 2500.0, "A4 one dragged back: the pulse falters (%.1f), muffled (%.0f Hz)" % [score.stem_gain_db(&"bed", &"pulse"), PlaceScore.muffle().cutoff_hz])
	near_souls.clear()
	near_souls.append_array(souls(["seeking", "seeking", "seeking"]))
	run_for(score, 4.0)
	var three := float(score.haunt()[&"swarm"])
	near_souls.clear()
	near_souls.append_array(souls(["seeking", "seeking", "seeking", "seeking", "seeking"]))
	run_for(score, 1.0)
	check(near(three, 0.0, 0.01) and float(score.haunt()[&"swarm"]) >= 0.99, "A5 five out at once swarm, three do not")
	score.free()

	score = make_score()
	run_for(score, 2.0)
	check(score.haunt().values().max() <= 0.0001, "A6 no ánimas anywhere: nothing")
	score.free()

func cue_checks() -> void:
	var score := make_score(FIXTURE, true)
	# The bed's own clock starts at 0 when the bed does (the cue lands at 1 s).
	score.position_source = func() -> float: return maxf(0.0, pos - 1.0)
	check(score.cue_playing() and not score.bed_playing(), "C1 the entrance cue first, the bed not yet")
	run_for(score, 0.9)
	check(not score.bed_playing(), "C1 not before the cue lands")
	run_for(score, 0.15)
	check(score.bed_playing(), "C1 the bed comes in where the cue lands (bar 1)")
	check(score.stem_gain_db(&"bed", &"drone_city") >= -1.0, "C4 landing from the cue, the bed is there at once, no swell: %.1f" % score.stem_gain_db(&"bed", &"drone_city"))
	score.free()

	# Landing deep down: the bed lands already at the place's depth.
	score = make_score(FIXTURE, true)
	score.position_source = func() -> float: return maxf(0.0, pos - 1.0)
	(score.zones as StubZones).w = {"a": 0.0}
	(score.zones as StubZones).d = 1.0
	run_for(score, 1.05)
	check(score.stem_gain_db(&"bed", &"drone_deep") >= -1.0 and score.stem_gain_db(&"bed", &"drone_city") <= -79.0, "C5 landing deep, the deep drone at once: %.1f" % score.stem_gain_db(&"bed", &"drone_deep"))
	score.free()

	# A cue that lands on its own last sound ends there: no frame may see it land.
	score = make_score(FIXTURE, true)
	score.cue_source = func() -> float: return 0.0
	score.cue_player.stop()
	run_for(score, STEP)
	check(score.bed_playing(), "C3 a cue that has ended brings the bed in")
	score.free()

	var fight := GDScript.new()
	fight.source_code = "extends Node\nvar intensity := 0.0\n"
	fight.reload()
	var music: Node = fight.new()
	music.name = "Music"
	get_tree().current_scene.add_child(music)
	score = make_score()
	var bus := AudioServer.get_bus_index(PlaceScore.BUS)
	music.intensity = 1.0
	run_for(score, 0.1)
	check(near(AudioServer.get_bus_volume_db(bus), PlaceScore.UNDER_COMBAT_DB, 0.5), "C2 in a fight the score sinks under it: %.1f dB" % AudioServer.get_bus_volume_db(bus))
	music.intensity = 0.0
	run_for(score, 0.1)
	check(near(AudioServer.get_bus_volume_db(bus), 0.0, 0.5), "C2 and comes back as the fight fades")
	score.free()
	music.free()

func metro_checks() -> void:
	var packed := load("res://maps/metro.tscn") as PackedScene
	var map := packed.instantiate()
	add_child(map)
	for i in range(5):
		await get_tree().process_frame
	var mine := map.get_node_or_null("PlaceScore")
	var under_lane: Array = map.get_node("candle_lane").find_children("*", "PlaceScore", true, false)
	check(mine is PlaceScore and under_lane.is_empty(), "M1 the Metro has its score at its root, none under the lane")
	check(mine != null and mine.available and mine.score_json_path == "res://audio/music/metro/score.json", "M1 it plays the Metro's own score")
	map.queue_free()
	await get_tree().process_frame

	map = packed.instantiate()
	map.score_path = FIXTURE
	add_child(map)
	for i in range(5):
		await get_tree().process_frame
	var first: PlaceScore = map.get_node("PlaceScore")
	check(first.available and first.cue_playing(), "M3 on arriving, the entrance cue")
	# The cue lands in audio time, which --fixed-fps frames do not keep.
	var since := Time.get_ticks_msec()
	while not first.bed_playing() and Time.get_ticks_msec() - since < 15000:
		await get_tree().process_frame
	map.get_node("candle_lane")._hush()
	await get_tree().process_frame
	check(first.bed_playing(), "M2 the lane's hush leaves the Metro's score playing")
	var players := first.find_children("*", "AudioStreamPlayer", true, false)
	map.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	check(players.all(func(p): return not is_instance_valid(p)), "M3 leaving the Metro lets go of every player")
	map = packed.instantiate()
	map.score_path = FIXTURE
	add_child(map)
	for i in range(5):
		await get_tree().process_frame
	var again: PlaceScore = map.get_node("PlaceScore")
	check(again != first and again.cue_playing() and not again.bed_playing(), "M3 coming back, the cue again, the bed from its top")
	map.queue_free()
	await get_tree().process_frame
