# Metro Score Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The Metro gets one continuous adaptive score. A bed loops forever, and every space has a theme of its own that morphs with where you are, what the ánimas are doing and what you have done. The first pieces are the frame and bed, the Metro entrance cue, the candle lane, the curandera and the librarian, composed in Logic with the user.

**Architecture:**
- A data-driven `PlaceScore` node plays a bed (one `AudioStreamSynchronized`) and one locked stem set per theme, each on its own player, all started on the bed's phrase lines.
- `PlaceZones` turns the Metro plan (`assets/eclipse/metro/plan.json`) into theme weights and a depth value at the player's feet.
- `tools/prepare_place_score.py` turns Logic stems into the game files and `score.json`.
- The music is written in Logic: Claude writes MIDI and drives Logic on screen, and the user judges every sound by ear.

**Tech Stack:** Godot 4.5.1 GDScript (`/Users/tinkertailorr/Desktop/Godot.app/Contents/MacOS/Godot`), Python 3 + numpy + ffmpeg + libsndfile (as `tools/prepare_menu_score.py`), Logic Pro, MIDI via `tools/menu_midi.py`.

**Spec:** `docs/superpowers/specs/2026-10-31-metro-score-design.md` (approved 2026-10-31). Read it before any task.

## Global Constraints

- **Claude cannot hear.** Every musical decision is auditioned and approved by the user. Nothing musical is final until the user approves it by ear.
- **Placeholder stems are labelled placeholder** (`"placeholder": true` in `map.json`, so it shows in `score.json`) until the user approves the real ones.
- **Logic export:**
  - File > Export > All Tracks as Audio Files;
  - 48 kHz, starting at bar 1;
  - normalisation off, the user's fader balance.
- **Source masters** go under `assets/audio/source/metro_score/` (gdignored by the parent `.gdignore`) and are never committed. Game files go under `audio/music/metro/`.
- **One frame for the whole score:** one bpm, 4/4, `phrase_bars` = 4. The bed and every theme loop at a whole number of phrases.
- **Stream limits:** at most 32 stems per theme set (the `AudioStreamSynchronized` limit).
- **The music sits under the world:** it plays on `Music` (which ducks under `World`) through its own `PlaceScore` sub-bus.
- **What the ánimas do, never mere nearness, bends a theme.** The acts are pleading, straining, dragged, and several out at once (the swarm).
- **The dark train is out of scope.** Do not add trains to the Metro.
- **The combat score (`scripts/Audio/Music.gd`) and the menu score are not changed.**
- **`PlaceScore` lives under the Metro map's root, never under `candle_lane`.** `candle_lane._hush()` stops every `AudioStreamPlayer` beneath the lane.
- **Model ids:** none used.

## Review Focus

1. **Walking back into a space whose theme is still fading out.** It should swell back from where it is, in step. It must not restart or double-start.
2. **Standing on a threshold, or stepping back and forth across it.** The weights glide; a theme set is not started and stopped every few frames.
3. **Feet outside every space polygon** (a doorway gap, mid-jump, climbing, a ledge). The last weights hold, and the music does not drop to silence.
4. **Slow motion, hit-stops and the pause menu.** The music's clock is the audio player's own, so `TimeFx` slow motion never slows or drifts the score.
5. **A story change mid-phrase** (talking to her sets a flag). The variant waits for the theme's next phrase line, and nothing switches mid-phrase.

---

## File Structure

| File | Responsibility |
|---|---|
| `tools/prepare_place_score.py` | Create. `map.json` + stems → oggs, `bed.tres`, `<theme>.tres`, `cue.ogg`, `score.json`. Reuses `prepare_score.command/encode/stereo` and `prepare_menu_score.fit/write_ogg/write_resource`. |
| `tools/fixture_place_score.py` | Create. Writes synthetic click/tone WAVs and a `map.json` at 240 bpm, then runs the prep tool into `tests/fixtures/place_score/`. |
| `tests/test_prepare_place_score.py` | Create. unittest of the prep tool. |
| `scripts/Audio/PlaceClock.gd` | Create. Pure musical time: phrase lines, theme phase, entry times. |
| `scripts/Audio/PlaceZones.gd` | Create. `RefCounted`: plan → theme weights and depth at a point. |
| `scripts/Audio/PlaceScore.gd` | Create. The node: players, mixing, fatigue, variants, ánima acts, the cue, sinking under the combat score. |
| `maps/metro.gd` | Modify. Add the `PlaceScore` once the sets have loaded. |
| `tests/place_score_test.gd/.tscn` | Create. Headless suite (checks P1…). |
| `tests/diag_place_score_drift.tscn/.gd` | Create. Records the bed and a theme set's clicks, and reports their offset. |
| `tests/diag_place_score_walk.tscn/.gd` | Create. A scripted walk recorded to a WAV, for the user's ears. |
| `tools/compose_metro_parts.py` | Create. Writes each piece's MIDI (`--piece bed|cue|lane|curandera|librarian`) using `tools/menu_midi.py`. |
| `assets/audio/source/metro_score/README.md` | Create. Stem table per piece, like `menu_theme/README.md`. Committed (the README only). |
| `docs/systems/audio.md` | Modify. A "Metro score" section. |

## `map.json` / `score.json` shape (decided here, used by every task)

```json
{
  "bpm": 72, "beats_per_bar": 4, "phrase_bars": 4, "placeholder": true,
  "bed": {"bars": 16, "stems": [
    {"id": "drone_city", "file": "bed/drone_city.wav", "role": "drone_city"},
    {"id": "drone_deep", "file": "bed/drone_deep.wav", "role": "drone_deep"},
    {"id": "pulse", "file": "bed/pulse.wav", "role": "pulse"},
    {"id": "room", "file": "bed/room.wav", "role": "room"}]},
  "cue": {"file": "cue/enter.wav", "lands_bar": 2},
  "themes": {
    "candle_lane": {"bars": 16, "stems": [
      {"id": "lane_bass", "file": "lane/bass.wav", "part": "bass", "intensity": "calm"},
      {"id": "lane_lead", "file": "lane/lead.wav", "part": "lead", "intensity": "calm", "city": true},
      {"id": "lane_lead_full", "file": "lane/lead_full.wav", "part": "lead_full", "intensity": "full"},
      {"id": "lane_pleading", "file": "lane/pleading.wav", "part": "haunt", "haunted": "pleading"}]},
    "curandera": {"bars": 8, "stems": [
      {"id": "her_lead", "file": "her/lead.wav", "part": "lead", "intensity": "calm"},
      {"id": "her_lead_met", "file": "her/lead_met.wav", "part": "lead", "intensity": "calm",
       "variant": {"character": "curandera", "when": "met"}}]}},
  "spaces": {"candle_lane": "candle_lane", "librarian_shop": "librarian", "hall": "hall"},
  "circles": [{"theme": "curandera", "inside": "candle_lane", "at": [12.8, -11.0, 73.2], "radius": 3.5, "full": 1.5}]
}
```

- **`intensity`** is `"calm"` (plays from the start) or `"full"` (added once the theme has grown). Missing means both.
- **`city: true`** stems thin with depth.
- **`haunted`** is one of `pleading`, `straining`, `dragged` or `swarm`. Those stems are silent until that act is happening.
- **`variant`:** stems sharing a `part` are alternatives. The first whose `when` holds for `character` (via `PeopleState.holds`) plays; the one without `variant` is the default. Variants are listed before their default.
- **`score.json`** echoes all of this, plus:
  - `bed.loop_seconds`, and per theme `loop_seconds` and `resource` (the `.tres` path);
  - per stem `index`, `peak_db` and `sha256`;
  - `cue.path`, `cue.seconds`;
  - `common_gain_db`.

---

### Task 1: The preparation tool and the test fixture

**Files:**
- Create: `tools/prepare_place_score.py`, `tools/fixture_place_score.py`, `tests/test_prepare_place_score.py`
- Create (generated, committed, small): `tests/fixtures/place_score/` (oggs, `.tres`, `score.json`)

**Interfaces:**
- Produces:
  - `python3 tools/prepare_place_score.py [--source DIR] [--out DIR] [--res-prefix res://...]` (defaults: `assets/audio/source/metro_score`, `audio/music/metro`, `res://audio/music/metro`);
  - `prepare(source: Path, out: Path, prefix: str) -> dict` (the `score.json` dict);
  - the fixture at `res://tests/fixtures/place_score/score.json`. It has bpm 240, a bed of 8 bars (`drone_city`, `drone_deep`, `pulse`, `room`), and three themes: `a` (8 bars: a calm `lead`, a full `lead_full`, a `haunt` stem with `haunted: "pleading"`), `b` (4 bars: a default `lead` and a `lead_met` variant on character `"curandera"`, `when: "met"`), and `c` (4 bars, one stem). It also has a 1-bar cue landing on bar 1, `spaces` `{"candle_lane": "a", "librarian_shop": "b"}`, and one circle for `c` inside `candle_lane`. Every stem is a click on each bar's downbeat over a quiet tone, so offsets can be measured.

- [ ] **Step 1: Write the failing tests** in `tests/test_prepare_place_score.py`, using a temp directory with WAVs written by `fixture_place_score.write_sources(dir)`:
  - `test_theme_loops_must_be_whole_phrases`: theme `bars: 6` with `phrase_bars: 4` → `SystemExit`.
  - `test_every_stem_of_a_set_has_the_set_length`: each theme's oggs decode to exactly `round(bars*4*60/bpm*48000)` samples.
  - `test_tails_fold_back_across_the_join`: a stem ringing 0.2 s past its end has that tail summed onto its start (reuse `prepare_menu_score.fit`).
  - `test_more_than_32_stems_in_a_set_fails`.
  - `test_one_common_gain_for_bed_themes_and_cue`: the prepared mix of the bed plus every theme peaks at most −3 dBFS (`gain = min(10**(-8/20), 0.70/peak)` over the bed plus all themes summed at their own lengths, tiled to the longest).
  - `test_score_json_lists_indices_resources_and_roles`: per theme `resource` ends with `<theme>.tres`, and the indices are 0..n-1 in map order. `placeholder`, `spaces` and `circles` are copied verbatim.
  - `test_missing_file_names_the_stem`.

- [ ] **Step 2: Run them:** `python3 -m unittest tests/test_prepare_place_score.py -v`. Expected: FAIL (module missing).

- [ ] **Step 3: Implement `prepare()` and `main()`** in `tools/prepare_place_score.py`, importing `fit`, `read_audio`, `write_ogg` and `write_resource` from `prepare_menu_score`.
  - Write `write_resource` output once per set: rename its file to `<set>.tres`, or add a `name` parameter defaulting to `'score'`, without changing the menu's output.
  - Oggs go to `<out>/<set>/<stem id>.ogg` with loop=true.
  - The cue goes to `<out>/cue.ogg` with loop=false.

- [ ] **Step 4: Implement `tools/fixture_place_score.py`**, with `write_sources(dir: Path) -> None` and a `main()` that writes the sources to a temp dir and calls `prepare(temp, ROOT/'tests/fixtures/place_score', 'res://tests/fixtures/place_score')`. Run it.

- [ ] **Step 5: Run the tests.** Expected: all PASS. Then `python3 -m unittest tests/test_prepare_score.py -v` still passes.

- [ ] **Step 6: Commit**

```bash
git add tools/prepare_place_score.py tools/fixture_place_score.py tests/test_prepare_place_score.py tests/fixtures/place_score
git commit -m "feat(music): place score preparation and its fixture"
```

### Task 2: The clock, and proving separate players stay locked

This is the spec's first risk. It is measured before anything is built on it.

**Files:**
- Create: `scripts/Audio/PlaceClock.gd`, `tests/place_score_test.gd`, `tests/place_score_test.tscn`, `tests/diag_place_score_drift.gd/.tscn`

**Interfaces:**
- Produces (`class_name PlaceClock`, all static):
  - `bar_seconds(bpm: float, beats_per_bar: int) -> float`
  - `phrase_seconds(bpm: float, beats_per_bar: int, phrase_bars: int) -> float`
  - `next_phrase_line(pos: float, phrase: float) -> float`: on a line (within `MenuClock.SLACK`), `pos` itself.
  - `theme_offset(bed_pos: float, theme_loop: float) -> float`: `fposmod(bed_pos, theme_loop)`.
  - `heard(position: float, since_mix: float, latency: float) -> float`: delegates to `MenuClock.corrected`.
- Bed time is continuous: `PlaceScore` keeps `bed_pos` as the bed player's heard position plus whole bed loops counted. A theme started at bed time `t` plays from `theme_offset(t, loop)`.

- [ ] **Step 1: Write the failing checks** in `tests/place_score_test.gd`, in the style of `tests/menu_music_test.gd` (`check()`, `near()`, a results line, quit 1 on failure):
  - P1: `bar_seconds(72, 4)` ≈ 3.3333.
  - P2: `next_phrase_line(13.2, 13.3333)` ≈ 13.3333.
  - P3: `next_phrase_line(13.3335, 13.3333)` ≈ 13.3333.
  - P4: `theme_offset(40.0, 13.3333)` ≈ 0.0001 (within 0.001).
  - P5: `theme_offset(26.0, 26.6667)` ≈ 26.0.

- [ ] **Step 2: Run:** `/Users/tinkertailorr/Desktop/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 res://tests/place_score_test.tscn`. Expected: script error or FAIL lines.

- [ ] **Step 3: Implement `PlaceClock.gd`.** Run again. Expected: P1–P5 PASS.

- [ ] **Step 4: Write `tests/diag_place_score_drift`.**
  - It plays the fixture's bed (`bed.tres`) and, starting 2.5 bars into it, the fixture's theme `a` via `play(theme_offset(...))` on a second `AudioStreamPlayer`.
  - It records the `Music` bus output with `AudioEffectRecord` for 180 s of audio. Under `--fixed-fps`, wait on audio time, not frames.
  - It finds the click onsets, then prints `DRIFT max_offset_ms=<x> after_s=<y>` and `SEEK ok|failed`. `SEEK failed` means a synchronized stream started from a position does not land on its expected onsets.

- [ ] **Step 5: Run the diag** (not headless, so a real audio driver mixes): `.../Godot --path . res://tests/diag_place_score_drift.tscn`. Pass: `max_offset_ms` ≤ 5 over 180 s and `SEEK ok`.
  - **If either fails, stop and report to the user.** Bring the numbers and the spec's two fallbacks: re-align on phrase lines, or merge the bed into each theme set. Do not choose a fallback alone.

- [ ] **Step 6: Commit**

```bash
git add scripts/Audio/PlaceClock.gd tests/place_score_test.* tests/diag_place_score_drift.*
git commit -m "feat(music): place score clock; separate players measured in step"
```

### Task 3: Zones from the Metro plan

**Files:**
- Create: `scripts/Audio/PlaceZones.gd`
- Modify: `tests/place_score_test.gd` (checks Z1…)

**Interfaces:**
- Produces (`class_name PlaceZones extends RefCounted`):
  - `static func from_plan(plan: Dictionary, spaces: Dictionary, circles: Array) -> PlaceZones`
  - `func space_at(point: Vector3) -> String`: "" when the point is in no space. A point is in a space when it is inside its `polygon` (x, z) and `floor - 0.5 ≤ y ≤ floor + height`. When spaces stack, the highest floor at or below the feet wins.
  - `func weights_at(point: Vector3) -> Dictionary`: `{theme: weight}`, weights 0..1.
  - `func depth_at(point: Vector3) -> float`: 0..1.
  - `func theme_of(space: String) -> String`: a mapped theme, or the theme of the nearest mapped space through `openings` (breadth-first over the plan's opening graph, both directions), or "".
- Values (Claude's calls, tuned by ear later): `THRESHOLD := 3.0` m, `LEAN := 0.6`, `LAYER_DEPTH := {1: 0.0, 2: 0.35, 3: 0.7}`, `DEEP_FROM := -21.0`, `DEEPEST := -26.0`.

- [ ] **Step 1: Write the failing checks**, against the real `assets/eclipse/metro/plan.json`, with spaces `{"candle_lane": "lane", "librarian_shop": "librarian", "pasaje": "pasaje"}` and one circle `{"theme": "curandera", "inside": "candle_lane", "at": [12.8, -11, 73.2], "radius": 3.5, "full": 1.5}`:
  - Z1: the middle of `candle_lane` (x 5, z 75.45, y −11) gives `{"lane": 1.0}`.
  - Z2: at the lane–Pasaje opening (x −4.0, z 75.45) both weigh 0.5 ± 0.05.
  - Z3: 1.5 m east of that opening, inside the lane, the lane's weight is 0.75 ± 0.05.
  - Z4: 1.0 m from the curandera circle's centre, `curandera` is 1.0 and `lane` is 0.4 (1 − LEAN).
  - Z5: at 2.5 m from it, `curandera` is between 0 and 1 (smoothstep from `radius` to `full`).
  - Z6: `theme_of("chapel")` == "lane" (unmapped, it opens from the lane).
  - Z7: `depth_at` in the lane (layer 2) is 0.35; on `platform_n` (layer 1) it is 0.0.
  - Z8: in `templo_shells` at y −26 it is 1.0; in `vaults` at −21 it is 0.7.
  - Z9: `space_at` a point above the `hall`'s ceiling and outside every polygon is "".

- [ ] **Step 2: Run the suite.** Expected: Z1–Z9 FAIL.

- [ ] **Step 3: Implement `PlaceZones.gd`.**
  - Use `Geometry2D.is_point_in_polygon` for containment.
  - For thresholds, take the distance to each opening segment of the containing space. The opening is centred at `at`, `width` wide, along the polygon edge it lies on. Within `THRESHOLD`, the far side's theme gets `0.5 * (1 - d/THRESHOLD)` and this side keeps the rest. Skip openings whose far side maps to the same theme.
  - For depth, take the layer value of the containing space; in layer 3, add `0.3 * clamp((DEEP_FROM - y)/(DEEP_FROM - DEEPEST), 0, 1)`. Across a threshold, blend depth by the same weights.

- [ ] **Step 4: Run the suite.** Expected: Z1–Z9 PASS.

- [ ] **Step 5: Commit** `git commit -m "feat(music): theme weights and depth from the Metro plan"` (add `scripts/Audio/PlaceZones.gd tests/place_score_test.gd`).

### Task 4: PlaceScore: bed, theme sets, entries, fades, depth, fatigue

**Files:**
- Create: `scripts/Audio/PlaceScore.gd`
- Modify: `tests/place_score_test.gd` (checks S1…)

**Interfaces:**
- Consumes: `PlaceClock`, `PlaceZones`, the fixture.
- Produces (`class_name PlaceScore extends Node`):
  - `@export var score_json_path: String`
  - `var listener_source: Callable`: returns the listening point (`Vector3`). By default, the `player` group's first node's `global_position`.
  - `var position_source: Callable`: the bed's heard position. By default `PlaceClock.heard(...)` of the bed player.
  - `var zones: PlaceZones`: built in `_ready` from `plan_path` (`@export`, default `res://assets/eclipse/metro/plan.json`) unless set beforehand.
  - `var available: bool`
  - `func step(delta: float) -> void`: one frame; `_process` calls it.
  - `func theme_gain_db(theme: StringName) -> float`
  - `func stem_gain_db(theme: StringName, stem_id: StringName) -> float`
  - `func theme_playing(theme: StringName) -> bool`
  - `func theme_started_at(theme: StringName) -> float`: bed time of its last start.
  - `func intensity_of(theme: StringName) -> StringName`: `&"calm"`, `&"full"` or `&"rest"`.
  - `func hush() -> void`
  - Constants: `OUT := -80.0`, `FADE_BARS := 2`, `SWELL_BARS := 1`, `STOP_AFTER_PHRASES := 1`, `WEIGHT_GLIDE := 0.8` (weight units per second), `FULL_AFTER_PHRASES := 2`, `REST_AFTER_LOOPS := 4`, `REST_PHRASES := 2`, `CITY_THIN_DB := 24.0`. All are tuned by ear later.

Behaviour:
- **The bed** plays from `_ready` while `available`. `drone_city` sits at `0 dB · (1 - depth)` and `drone_deep` at `depth`, both as linear gains converted to dB. Pulse and room stay at 0 dB.
- **Starting a theme.** A theme whose glided weight rises above 0.001 while its player is stopped is scheduled for the next phrase line. At that line it plays from `theme_offset(line, loop)` and swells from −40 dB to its target over `SWELL_BARS`.
- **A theme's target** is `linear_to_db(weight)`; every `city: true` stem drops a further `CITY_THIN_DB * depth`.
- **Leaving.** A theme whose weight falls slides to its target over `FADE_BARS`. Its player stops once it has sat at `OUT` for `STOP_AFTER_PHRASES`. If its weight returns before then, it swells back from its current gain, with no restart (Review Focus 1).
- **Holding the last weights.** When `space_at` is "", the last non-empty weights hold (Review Focus 3).
- **Intensity.** A started theme is `calm`. After `FULL_AFTER_PHRASES` phrases at weight ≥ 0.5 its `full` stems come in. After `REST_AFTER_LOOPS` loops at weight ≥ 0.5 without a break, it rests: every stem except bass goes to `OUT` for `REST_PHRASES`, then returns `calm`. A break (weight < 0.5 for one phrase) resets the counts.
- **Sub-bus.** It plays on a `PlaceScore` bus, made once like `MenuMusic.ensure_jingle_bus`, sending to `Music`. Effects are added in Task 6.
- **Process mode** is the default (pausable). Its clock is the audio position, never `delta` (Review Focus 4).

- [ ] **Step 1: Write the failing checks.** Build the score with `position_source = func(): return pos`, and `listener_source` returning a test-controlled point. Drive it with a `run_for(seconds)` helper like `menu_music_test`'s, with `set_process(false)`. Use a stub `PlaceZones` whose `weights_at` and `depth_at` return test-set values, via a small inner class overriding both.
  - S1: the bed is playing at once; `drone_city` is at 0 dB and `drone_deep` at `OUT` at depth 0.
  - S2: at depth 1, the reverse.
  - S3: weight `a` = 1 set at pos 0.3 bars → `theme_playing(&"a")` is false until the next phrase line (4 bars = 4.0 s at 240 bpm), then true. `theme_started_at(&"a")` ≈ 4.0.
  - S4: one bar after its start, `a`'s calm lead is ≥ −1 dB, and its full stem is at `OUT`.
  - S5: after 2 phrases at weight 1, `intensity_of(&"a") == &"full"` and the full stem is near 0 dB.
  - S6: weight to 0 → after `FADE_BARS` the lead is ≤ −79 dB. Still playing one phrase later? No: it stops.
  - S7 (Review Focus 1): weight to 0 for 1 bar, then back to 1 → `theme_started_at` unchanged, and the gain rises from its faded level without a stop.
  - S8 (Review Focus 2): the weight flips 0/1 every 0.1 s for 8 s → at most one start of `a`, and the gains move at most `WEIGHT_GLIDE` per second.
  - S9 (Review Focus 3): the stub returns {} → the gains stay at their last targets.
  - S10: a `city` stem at depth 0.5 is 12 dB under its non-city sibling.
  - S11: after 4 unbroken loops, `intensity_of == &"rest"`, the lead is at `OUT` and the bass is still sounding. After 2 phrases it is `calm` again.
  - S12 (Review Focus 4): `Engine.time_scale = 0.25` for 2 s of steps → `theme_started_at` values and the phrase lines match the run at 1.0. Reset the time scale after.
  - S13: a missing `score_json_path` → `available == false` and no errors (add to `tools/expected_errors.txt` only if Godot itself prints one).

- [ ] **Step 2: Run the suite.** Expected: S1–S13 FAIL.

- [ ] **Step 3: Implement `PlaceScore.gd`.** Load as `MenuMusic._load_score` does: parse `score.json`, then load `bed.tres` and each theme's `resource`. Duplicate each `AudioStreamSynchronized`. Make one `AudioStreamPlayer` per set, named after it.

- [ ] **Step 4: Run the suite.** Expected: P, Z and S checks all PASS.

- [ ] **Step 5: Commit** `git commit -m "feat(music): PlaceScore bed and theme sets on phrase lines"`.

### Task 5: Story variants

**Files:**
- Modify: `scripts/Audio/PlaceScore.gd`, `tests/place_score_test.gd` (checks V1…)

**Interfaces:**
- Consumes: `PeopleState.holds(condition: String, character: String) -> bool`, read from `CityState.people`.
- Produces:
  - `var people_source: Callable`: returns the `PeopleState`. Default `func(): return CityState.people`.
  - `func part_choice(theme: StringName, part: StringName) -> StringName`: the stem id playing that part.

Behaviour:
- At each of the theme's phrase lines (and at its start), each `part` with variants picks the first stem whose `variant.when` holds for `variant.character`, else the default.
- The incoming choice swells over 1 bar while the outgoing one fades over 1 bar.
- Between lines, nothing changes (Review Focus 5).

- [ ] **Step 1: Write the failing checks** with a fresh `PeopleState` (`preload("res://scripts/Level/PeopleState.gd").new()`):
  - V1: not met → `part_choice(&"b", &"lead") == &"lead"`.
  - V2: `people.meet("curandera")` halfway through a phrase → the choice is unchanged until the next phrase line, then `&"lead_met"`.
  - V3: one bar after the switch, `lead_met` ≥ −1 dB and `lead` ≤ −79 dB.
  - V4: no `people_source` result (null) → defaults, with no errors.

- [ ] **Step 2: Run.** Expected: V1–V4 FAIL.

- [ ] **Step 3: Implement** in `PlaceScore.gd`.

- [ ] **Step 4: Run.** Expected: all PASS.

- [ ] **Step 5: Commit** `git commit -m "feat(music): story variants change on phrase lines"`.

### Task 6: The ánimas' acts bend the theme

**Files:**
- Modify: `scripts/Audio/PlaceScore.gd`, `tests/place_score_test.gd` (checks A1…)

**Interfaces:**
- Consumes: Animas nodes (`scripts/Visual/Animas.gd`), found by script, with `count: int` and `state_of(i: int) -> String`. Do not change `Animas.gd`.
- Produces:
  - `var animas_source: Callable`: returns `Array` of `{state: String, at: Vector3}`, one per soul within `HAUNT_RANGE`. Default: every Animas node's souls (`state_of(i)` for `i < count`), placed at the node's `global_position`, within range of the listener.
  - `func haunt() -> Dictionary`: `{&"pleading": 0..1, &"straining": 0..1, &"dragged": 0..1, &"swarm": 0..1}`, each eased (`HAUNT_RISE := 2.0`, `HAUNT_FALL := 0.5` per second).
  - Constants: `HAUNT_RANGE := 8.0`, `SWARM_FROM := 4` (souls out, i.e. not `below`, at once), `DETUNE_WET := 0.35`, `MUFFLE_HZ := 1800.0`, `PULSE_FALTER_DB := -12.0`. All are tuned by ear later.

Behaviour:
- `pleading` drives the `PlaceScore` bus's `AudioEffectChorus` wet to `DETUNE_WET * pleading`.
- `straining` or `dragged` (the larger) drops the bed's pulse by `PULSE_FALTER_DB` scaled, and lowers an `AudioEffectLowPassFilter` cutoff from 20000 Hz toward `MUFFLE_HZ`.
- `swarm` = `clamp((out - SWARM_FROM + 1) / 3, 0, 1)`.
- Each theme's `haunted` stems follow their act's value (0 → `OUT`, 1 → their weighted target).
- **Every other state (climbing, seeking, warming, lurking, hiding, escorting, below) leaves the music alone.** In particular, nearness alone does nothing.

- [ ] **Step 1: Write the failing checks** with `animas_source` stubbed:
  - A1: three souls `warming` and `lurking` 2 m away → every haunt value stays 0 after 3 s, and the chorus wet is 0.
  - A2: one `pleading` → `pleading` ≥ 0.9 after 1 s; theme `a`'s `haunt` stem (`haunted: pleading`) is ≥ −2 dB under weight 1; the chorus wet ≈ 0.35.
  - A3: pleading stops → after 3 s `pleading` ≤ 0.1, and the haunt stem is ≤ −40 dB.
  - A4: one `dragged` → the pulse is ≤ −10 dB and the low-pass cutoff ≤ 2500 Hz after 1 s.
  - A5: five out (`seeking` ×5) → `swarm` == 1 eased; with three out it is 0.
  - A6: no Animas in the scene (the default source) → no errors, all 0.

- [ ] **Step 2: Run.** Expected: A1–A6 FAIL.

- [ ] **Step 3: Implement.** Add the chorus and the low-pass to the `PlaceScore` bus when making it.

- [ ] **Step 4: Run.** Expected: all PASS.

- [ ] **Step 5: Commit** `git commit -m "feat(music): what the ánimas do bends the theme"`.

### Task 7: The cue, the combat score, the Metro map

**Files:**
- Modify: `scripts/Audio/PlaceScore.gd`, `maps/metro.gd`, `tests/place_score_test.gd` (checks C1…, M1…)

**Interfaces:**
- Consumes: the combat score node, `Music` (`scripts/Audio/Music.gd`): its `intensity: float`, found as the current scene's `Music` child.
- Produces:
  - `const UNDER_COMBAT_DB := -18.0`
  - `func cue_playing() -> bool`
  - `metro.gd` adds `PlaceScore` (named `PlaceScore`, `score_json_path = "res://audio/music/metro/score.json"`) as a child of the Metro root after `_sets()` succeeds. It is never under a set.

Behaviour:
- **The cue.** When `score.json` has a cue, it plays first. The bed starts so that the bed's bar 0 lands on the cue's `lands_bar`; that is, the bed starts `lands_bar` bars into the cue. Themes may not start before the bed.
- **Under the combat score.** The whole score sits at `UNDER_COMBAT_DB * Music.intensity` (applied to the `PlaceScore` bus volume) and comes back as the fight's intensity falls.

- [ ] **Step 1: Write the failing checks:**
  - C1: the fixture's cue → `cue_playing()` at once. The bed is not playing until 1 bar (1.0 s), then it is.
  - C2: a fake `Music` child with `intensity = 1.0` → the `PlaceScore` bus volume is −18 dB ± 0.5. At `intensity = 0` it is 0 dB.
  - M1: load `res://maps/metro.tscn`, wait for `loading_complete` → it has a `PlaceScore` child of the root, and no `PlaceScore` under `candle_lane`. While `audio/music/metro/score.json` is absent, it is `available == false` and silent.
  - M2: the Metro's `PlaceScore` survives `candle_lane._hush()`: its bed player is still playing after the lane hushes, using the fixture path.
  - M3: freeing the Metro and loading it again → the old `PlaceScore`'s players are gone (`hush()` on `_exit_tree`), and the new one starts from the cue at bed time 0.

- [ ] **Step 2: Run** the suite, and `tools/run_suites.sh tests/metro_test.tscn tests/candle_lane_test.tscn`. Expected: C and M checks FAIL; the existing suites pass.

- [ ] **Step 3: Implement** the cue and the combat sink in `PlaceScore.gd`, and the addition in `maps/metro.gd`.

- [ ] **Step 4: Run.** Expected: all PASS, and `metro_test` and `candle_lane_test` still pass.

- [ ] **Step 5: Commit** `git commit -m "feat(music): Metro entrance cue, sinks under a fight, added to the Metro"`.

### Task 8: The listening walk

**Files:**
- Create: `tests/diag_place_score_walk.gd/.tscn`

**Interfaces:**
- Consumes: `PlaceScore` with `listener_source` scripted.
- Produces: `.../Godot --path . res://tests/diag_place_score_walk.tscn -- --score=<score.json> --walk=lane|her|shop|all --out=<wav>`, which writes a WAV the user can play.
  - The `all` walk: arrive in the lane (cue) → stand 20 s → walk to her stall (circle) → 30 s there → walk to the librarian's shop doorway (19.0, 78.9) → 30 s inside → back out to the Pasaje opening.
  - `--pleading=<s>` holds a stubbed pleading soul for that many seconds at the walk's midpoint, so the haunt can be heard.

- [ ] **Step 1: Write the diag**, recording the `Music` bus with `AudioEffectRecord` (as `tests/diag_anima_voices.tscn` does).

- [ ] **Step 2: Run it** on the fixture, and check: the WAV exists, is the walk's length ± 1 s, and its clicks fall on bar lines. Print `WALK ok seconds=<n>`.

- [ ] **Step 3: Commit** `git commit -m "test(music): listening walk for the place score"`.

### Task 9: The frame and the bed, in Logic, with the user

This is musical work with the user. Each step ends in the user's answer. Drive Logic on screen with the computer-use tools; ask access for Logic Pro only.

**Files:**
- Create: `tools/compose_metro_parts.py`, `assets/audio/source/metro_score/README.md`
- Create (not committed): `assets/audio/source/metro_score/map.json`, `bed/*.wav`, and the Logic project `~/Music/Logic/metro_score_template.logicx`

**Interfaces:**
- Produces:
  - `python3 tools/compose_metro_parts.py --piece bed --bpm <n> --pedal <note name> [--take N]`, writing `assets/audio/source/metro_score/parts/bed_<take>.mid`;
  - the approved bpm and pedal, recorded in the README and `map.json`;
  - `audio/music/metro/` with the bed (themes empty).

- [ ] **Step 1:** Write `compose_metro_parts.py --piece bed`. It writes:
  - a drone track (the pedal held over 16 bars, re-struck each 4 bars);
  - a deep-drone track (the pedal an octave down, plus the fifth);
  - a pulse track (a soft kick on 1 and a ghost on 3&, swung 58 %).
  
  The room texture is audio: a Logic patch the user picks, with no MIDI. Use `tools/menu_midi.py` for writing.

- [ ] **Step 2:** Make the template project in Logic at 72 bpm, 4/4, 48 kHz. Import three takes: pedal C, B♭ and E, each at 72 bpm. Put the drones on pad/organ patches and the pulse on a Drummer or Drum Machine Designer kit. **Ask the user to audition them, and to set the tempo and the pedal by ear.**

- [ ] **Step 3:** With the user, choose the drone and room patches. Shape the deep drone so that the crossfade from city to deep is clearly darker. Re-take MIDI as asked, and repeat until **the user approves the bed by ear**.

- [ ] **Step 4:** Export the bed's four stems to `assets/audio/source/metro_score/bed/`. Write `map.json` with the bed only and `"placeholder": false` for the bed. Run `python3 tools/prepare_place_score.py`.

- [ ] **Step 5:** Run the walk diag with `--walk=all` and send the user the WAV, plus a line on how to walk it in the game (`maps/metro.tscn`). **The user approves the bed in the game.**

- [ ] **Step 6:** Write the README's bed table and frame (bpm, pedal, bars, patches), then commit:

```bash
git add tools/compose_metro_parts.py assets/audio/source/metro_score/README.md audio/music/metro
git commit -m "feat(music): the Metro's frame and bed, approved by ear"
```

### Tasks 10–13: The four first pieces, one at a time, with the user

Each piece has the same steps. A piece starts only after the one before it is approved by ear in the game.

| Task | Piece | `--piece` | Where it plays | First idea (spec) | Hooks |
|---|---|---|---|---|---|
| 10 | Entering the Metro | `cue` | On arrival (New Game → the lane) | The city above falls away; it hands off to the bed | `cue.lands_bar` |
| 11 | The candle lane | `lane` | `candle_lane` (and the chapel, through `theme_of`) | A slow bolero, Dorian, between her and him | haunted stems: pleading, dragged, swarm |
| 12 | The curandera's space | `curandera` | The circle at her stall (`CURANDERA_AT` in `candle_lane.gd`, in map coordinates: `PLAN_ORIGIN` + its offset) | Marigold-warm: guitar in thirds, copal | variant: character `curandera`; condition chosen with the user (e.g. `met`, `said(asked_book)`) |
| 13 | The librarian's space | `librarian` | `librarian_shop` | Harpsichord, celesta, wordless choir; room left for the books | variants: character `librarian`, e.g. `said(lied)`, `said(forgiven)`, chosen with the user |

**Files:** modify `tools/compose_metro_parts.py`, `assets/audio/source/metro_score/README.md` and `map.json` (the latter not committed), and `audio/music/metro/`.

- [ ] **Step 1:** Add `--piece <name>` to `compose_metro_parts.py`. It writes 2–3 takes of the theme's lead over the approved pedal: different motifs of 4–5 notes in the spec's mode. It also writes bass, groove and colour parts for the strongest take. Logic's players carry the grooves (Drummer, the Percussionist, Bass Player on a Chord Track) where they fit better.
- [ ] **Step 2:** In Logic, copy the template to `~/Music/Logic/metro_<piece>.logicx` and import the takes over the real bed. **The user picks a take by ear** and swaps instruments. Repeat until they approve the motif.
- [ ] **Step 3:** Build the calm and full versions. Then, with the user:
  - the lane's haunted stems (pleading, dragged, swarm);
  - her variant and his variants, with their conditions.
  
  Decide which parts thin with depth (`city`) with the user.
- [ ] **Step 4:** Export the stems to `assets/audio/source/metro_score/<piece>/`, add the theme (and its `spaces` or `circles` entry) to `map.json`, and run the prep tool.
- [ ] **Step 5:** Send the user the walk diag's WAV for this piece (`--walk=lane|her|shop`; `--pleading=10` for the lane), and ask them to walk it in the game. **The user approves the piece in place.**
- [ ] **Step 6:** Write the piece's README table, then commit `audio/music/metro`, the README and the composer script: `git commit -m "feat(music): Metro <piece> theme, approved by ear"`.

### Task 14: Documentation and the whole-branch check

**Files:**
- Modify: `docs/systems/audio.md`, `docs/reference/` (if the project's reference generator covers new scripts; run it as the other docs say)

- [ ] **Step 1:** Write a "Metro score" section in `docs/systems/audio.md`. It covers:
  - the bed and theme sets, `map.json` and the roles;
  - the zones and depth, intensity and rest;
  - the variants, the ánimas' acts, and the combat sink;
  - the prep and walk commands;
  - the level re-balance owed once the user's recordings arrive (the spec's "Levels").
- [ ] **Step 2:** Run `tools/run_suites.sh` and `python3 -m unittest discover tests -p 'test_prepare*.py'`. Expected: the new suite passes, and no suite fails that passed before this branch. Compare against the base commit's run, and report any pre-existing failure by name.
- [ ] **Step 3:** Commit `git commit -m "docs(audio): the Metro score"`.

## Later (not in this plan)

The spec's later themes, each its own plan or a repeat of Tasks 10–13:
- the hall and platforms, the Pasaje, the old layer;
- the car ride (after Metro Part 2);
- the dark train (once it is in the Metro);
- the level re-balance pass once the user's recordings arrive.
