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

func _ready() -> void:
	clock_checks()
	zone_checks()
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
