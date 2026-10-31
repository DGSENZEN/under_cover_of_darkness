# The Metro's Sound Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The candle lane and the whole Metro map sound like themselves, room by room, from the user's layered ElevenLabs takes, under a Metro mix.

**Architecture:** `tools/prepare_sfx.py --metro` layers the takes into many seeded variations and loops (hums retuned to G). A director, `scripts/Audio/PlaceSound.gd`, added by `maps/metro.gd` beside PlaceScore, reads the plan's spaces through its own `PlaceZones` table (space → bed family), crossfades a bed per family, thins the city with depth, adopts the lane's train as the Metro's one train clock, gives the station's listed pieces their sounds, answers floors with no `surface` meta from the place, and puts the Metro's glue compression and space-led reverb on while the Metro is loaded.

**Tech Stack:** Godot 4.5.1 GDScript (headless suites under `tools/run_suites.sh`), Python 3 + numpy + ffmpeg (`tools/prepare_sfx.py`, `unittest`).

**Spec:** `docs/superpowers/specs/2026-10-31-metro-sound-design.md`

## Global Constraints

- Work only in the worktree `.claude/worktrees/metro-sound` (branch `metro-sound`). `metro-standard`'s later commits come in by merging, on the user's word; never edit its files beyond what a task names.
- The takes live outside git at `~/Downloads/AUCOD ElevenLabs/ucod_sounds/` (unpacked from `~/Desktop/ucod_sounds.zip`, the `__MACOSX` folder dropped); results go to `audio/sfx/` and `audio/ambience/` as the tool does today.
- Nothing is reverbed offline: "Dry. Nothing is reverbed offline: the room is the game's."
- Every hum sits on G: within 20 cents of 98 Hz × 2ⁿ, or the tool refuses it.
- Seeded everywhere: the tool's layering (seed 1931), the director's own RNG; suites stay frame-exact under `--fixed-fps 60`.
- Nothing moved in `_process` that is drawn interpolated (no emitter here moves; keep it so).
- Levels in this plan are starting points; every family is approved by the user by ear before it counts as done. Never call a stand-in finished.
- Out of scope (the spec's non-goals): the spells, the mix outside the Metro, the dark train (it keeps running silently in the lane), voices, the score's code.
- A suite that listens to a sound whose source changes is re-baselined in the task that changes it, with the reason in the commit.
- Run one suite: `tools/run_suites.sh tests/<name>.tscn` (prints `PASS n / FAIL m`). Python: `python3 -m unittest tests/test_prepare_sfx_metro.py -v`.

**Three calls of mine that differ from the spec's letter (written back into the spec in Task 11):**
1. The station's sources come from the lists the station set already keeps (`neon`, `runs`, `mains`, `risers`, `mouths`, `floor_mains`, `mouth_runs`), not from `metro_sound` tags: no line in the map's files at all, which serves the spec's anti-goal better.
2. The Metro's one train clock is the lane's own `TrainPass` (`candle_lane.train`, already saved), adopted by the director; it makes its own only when no lane is set in.
3. No "sign that starts dark": none exists (YAGNI). Ignition plays on coming back from a deep brownout only.

## Review Focus

1. **Loading a save or reloading the Metro:** the glue compressor and the MetroBed bus are never added twice. Owner: Task 4 (S8).
2. **Leaving the Metro** (a scene change): Master is left exactly as it was, with no glue, and the acoustics go back to stone. Owner: Task 4 (S9).
3. **Standing in no space** (a gap in the greybox, a fall, the track bed between polygons): `weights_at` returns `{}`, and the beds hold their last levels instead of dropping to silence. Owner: Task 4 (S10).
4. **Sound switched off** (`Sfx.enabled = false`): the director builds nothing audible and raises no errors. Owner: Task 4 (S11).
5. **Slow motion and hit-stops:** the beds fade on real time (TimeFx), and the train runs on game time. Owner: Task 4 (S12).

---

### Task 1: The layering engine in the tool

**Files:**
- Modify: `tools/prepare_sfx.py` (new functions beside `layered`; `main()` gains `--metro`)
- Test: `tests/test_prepare_sfx_metro.py` (new; synthetic sources, no real takes needed)

**Interfaces:**
- Produces:
  - `hum_hz(x: np.ndarray, lo=40.0, hi=420.0) -> float`: the strongest FFT peak in [lo, hi].
  - `retune(x: np.ndarray, to_hz: float, lo=40.0, hi=420.0) -> np.ndarray`: resamples so the measured hum lands on `to_hz`. Raises `ValueError` if the result is more than 20 cents off.
  - `g_of(hz: float) -> float`: the nearest of 98 × 2ⁿ.
  - `layered_shots(hits: list[np.ndarray], count: int, rng, under_chance=0.5, under_db=(-12.0, -6.0), under_late=(0.002, 0.012), pitch=0.06) -> list[np.ndarray]`: each variation is one hit, sometimes with a second hit from another take laid under it. All variations are loudness-matched to their median.
  - `layered_loop(takes: list[np.ndarray], seconds: float, rng, stereo=False) -> np.ndarray`: takes laid over each other at random offsets, with the seam crossfaded equal-power over 1.5 s (as `write_loop`).
  - `prepare_metro(source=METRO_SOURCE, sfx_out=OUT, ambience_out=AMBIENCE_OUT, listen=None, shots=None, loops=None, seed=1931) -> dict`: `shots` defaults to METRO_SHOTS, `loops` to METRO_LOOPS (Task 2).
    - A shot row is `(group, [(take, hits to split)], count)`; a take is a file id under `source`, a bare name in the tests.
    - A loop row is `(name, [take ids], seconds, {"stereo": bool, "pitch": float, "lowpass": Hz, "hum_to": Hz})`.
    - Returns `{name: [paths written]}`. Before writing a group, it deletes that group's old `<group>_<n>.wav` and `.wav.import` files. With `listen` set, it writes `<listen>/<name>.wav`: every variation in a row, 0.4 s apart.

- [ ] **Step 1: Write the failing tests**

```python
class MetroLayeringTest(unittest.TestCase):
    # fixtures written in setUp: hum113.wav (113.3 Hz sine + noise, 12 s), hum100.wav (100 Hz),
    # knocks.wav (5 clicks 1.5 s apart), bed_a.wav / bed_b.wav (8 s noise, stereo)
    def test_retunes_a_hum_onto_g(self):
        x = self.prep.retune(self.hum113, 98.0)
        self.assertLess(abs(1200 * np.log2(self.prep.hum_hz(x) / 98.0)), 20.0)
    def test_nudges_a_sharp_hum(self):
        self.assertAlmostEqual(self.prep.g_of(100.0), 98.0)
        self.assertAlmostEqual(self.prep.g_of(200.0), 196.0)
    def test_shots_are_seeded_and_matched(self):
        a = self.prep.layered_shots(self.hits, 10, np.random.default_rng(1931))
        b = self.prep.layered_shots(self.hits, 10, np.random.default_rng(1931))
        self.assertEqual(len(a), 10)
        self.assertTrue(all(np.array_equal(p, q) for p, q in zip(a, b)))
        levels = [self.prep.loudness(v) for v in a]
        self.assertLess(max(levels) - min(levels), 1.0)
    def test_loop_seam_is_seamless(self):
        x = self.prep.layered_loop([self.bed_a, self.bed_b], 6.0, np.random.default_rng(1), stereo=True)
        self.assertEqual(x.shape[1], 2)
        jump = np.abs(x[0] - x[-1]).max()
        self.assertLess(jump, 4 * np.abs(np.diff(x, axis=0)).mean() + 1e-3)
    def test_prepare_metro_replaces_a_group_whole(self):
        sfx = self.out / 'sfx'; sfx.mkdir()
        for k in range(1, 13):
            (sfx / f'pipe_knock_{k}.wav').write_bytes(b'')
        self.prep.prepare_metro(self.source, sfx, self.out / 'amb', None,
                                shots=[('pipe_knock', [('knocks', 5)], 4)], loops=[])
        self.assertEqual(sorted(p.name for p in sfx.glob('pipe_knock_*.wav')), [f'pipe_knock_{k}.wav' for k in range(1, 5)])
    def test_listening_file_holds_every_variation(self):
        written = self.prep.prepare_metro(self.source, self.out / 'sfx', self.out / 'amb', self.out / 'listen',
                                          shots=[('pipe_knock', [('knocks', 5)], 4)], loops=[])
        total = sum(len(self.read(p)) for p in written['pipe_knock']) + 4 * int(0.4 * self.prep.RATE)
        self.assertLess(abs(len(self.read(self.out / 'listen' / 'pipe_knock.wav')) - total), self.prep.RATE // 10)
```

- [ ] **Step 2: Run them to verify they fail**

Run: `python3 -m unittest tests/test_prepare_sfx_metro.py -v`
Expected: FAIL with `AttributeError: module 'prepare_sfx' has no attribute 'retune'`.

- [ ] **Step 3: Implement the functions above in `tools/prepare_sfx.py`**

Take the hits from `split_events`. Pitch by resampling (`np.interp`, as `prepare_underground` does). `loudness` is the existing one. `--metro` in `main()` calls `prepare_metro(listen=<--listen=DIR, default None>)` and returns.

- [ ] **Step 4: Run them to verify they pass**

Run: `python3 -m unittest tests/test_prepare_sfx_metro.py -v`
Expected: 6 tests OK. `python3 -m unittest tests/test_prepare_place_score.py` stays OK.

- [ ] **Step 5: Commit**

```bash
git add tools/prepare_sfx.py tests/test_prepare_sfx_metro.py
git commit -m "feat(sfx): the Metro's layering: seeded variations, seamless loops, hums onto G"
```

### Task 2: The takes, cut and layered (the user's ear is the gate)

**Files:**
- Modify: `tools/prepare_sfx.py` (`METRO_SOURCE`, `METRO_SHOTS`, `METRO_LOOPS`, the module docstring's list of modes), `CREDITS.md`
- Create: `audio/sfx/*`, `audio/ambience/*` (generated)
- Test: `tests/test_prepare_sfx_metro.py` (one more test against the real tables)

**Interfaces:**
- Consumes: Task 1's `prepare_metro`, `layered_shots`, `layered_loop`, `retune`.
- Produces: the game names later tasks play.
  - Groups in `audio/sfx/`: `pipe_knock`, `pipe_tick`, `pipe_hiss`, `neon_tick`, `neon_zap`, `neon_ignite`, `cable_surge`, `train_far`, `metro_draught`, `step_tile`, `step_carpet`, `scuff`, `book_open`, `book_shut`, `book_riffle`.
  - Loops in `audio/ambience/`: `metro_room`, `metro_room_deep`, `metro_crowd`, `neon_buzz_1..3`, `junction_hum`, `transformer_hum`, `vent_hum`.

Each take is named by its id, the number after its last `-` (a helper `take(id)` globs `METRO_SOURCE/*-<id>.mp3`). These are the tables' contents. The counts are starting points:

| Name | Takes (id: hits split) | Out | Notes |
|---|---|---|---|
| pipe_knock | 1793485028335:3, 1793485034866:3, 1793485078302:5 | 10 mono | replaces FilmCow's hammer |
| pipe_tick | 1793485036928, 1793485046858:7, 1793485054268 | 12 mono | new |
| pipe_hiss | 1793485126062:3, 1793485122863:3 | 8 mono | the valve; replaces gas leak |
| neon_tick / neon_zap | 1793485274299, 1793485286256 | 6 + 6 mono | hits sorted by length: shortest half tick, longest zap |
| neon_ignite | 1793485326156 whole | 3 mono | pitch ±4 % |
| cable_surge | 1793485423078:3 | 6 mono | retuned 120→98 Hz |
| train_far | 1793484809228, …821215, …826366 whole | 8 mono | 15 s, matches a pass (5 + 3 + 6 s) |
| metro_draught | 1793484872682, 1793484877298 whole | 6 stereo | flat gust |
| step_tile | 1793485480540 | 10 mono | |
| step_carpet | 1793485499577:8 | 8 mono | |
| scuff | 1793485549125:8 | 8 mono | or landings: the user decides by ear in Step 4 |
| book_open | 1793485586835:4 + the current sources | 6 mono | "layered with the current ones" |
| book_shut | 1793485606047:3 + current | 6 mono | |
| book_riffle | 1793485667655 + page turns 1793485652718:4 | 8 mono | |
| metro_room | 1793484770277 | 2 stereo loops, 24 s | |
| metro_room_deep | 1793484770277, pitch 0.72, low-pass 700 Hz | 1 stereo loop, 24 s | the old layer's stand-in |
| metro_crowd | 1793484944353, 1793484985187 | 2 stereo loops, 26 s | |
| neon_buzz_1..3 | 1793485295398 (100→98), 1793485246893 | 3 mono loops, 8 s | replaces NOX |
| junction_hum | 1793485369165 (200→196) | mono loop, 10 s | |
| transformer_hum | 1793485379139 (113→98) | mono loop, 12 s | |
| vent_hum | 1793484872682, low-pass 2400 Hz | mono loop, 10 s | replaces FilmCow's ventilation |

- [ ] **Step 1: Move the takes and credit them**

Unzip `~/Desktop/ucod_sounds.zip` into `~/Downloads/AUCOD ElevenLabs/` (without `__MACOSX`). Check: `ls "$HOME/Downloads/AUCOD ElevenLabs/ucod_sounds" | wc -l` shows 39. In CREDITS.md, add under the sound packs: "ElevenLabs Sound Effects, generated by Diego Gaytan on a paid plan (commercial use), Oct 31 2026: the Metro's room tone, trains, draught, crowd, pipes, neon, electrics, steps and books."

- [ ] **Step 2: Write the failing test `test_real_tables_resolve`**

Skipped when `METRO_SOURCE` is missing. It asserts:
- every take id in `METRO_SHOTS` and `METRO_LOOPS` resolves to exactly one file;
- every loop with a hum lands within 20 cents of G (run on the real files, writing to a temp dir).

- [ ] **Step 3: Fill the tables, run the tool, run the test**

Run: `python3 -I tools/prepare_sfx.py --metro --listen="$TMPDIR/metro_listen"`, then `python3 -m unittest tests/test_prepare_sfx_metro.py -v`.
Expected:
- The tool prints a line for each name with its count and LUFS.
- All tests pass.
- `ls audio/sfx/pipe_knock_*.wav | wc -l` shows 10.

- [ ] **Step 4: The user listens (gate)**

Send the listening files in `$TMPDIR/metro_listen/` to the user, grouped as beds, pipes, neon, electrics, steps and books. Ask for each group whether it is approved, and whether the person take is scuffs or landings. Change only the tables, re-run Step 3, and repeat until every group is approved.

- [ ] **Step 5: Commit**

```bash
git add tools/prepare_sfx.py tests/test_prepare_sfx_metro.py CREDITS.md audio/sfx audio/ambience
git commit -m "feat(sfx): the Metro's takes layered: rooms, crowd, trains, pipes, neon, electrics, steps, books (approved by ear)"
```

### Task 3: Sfx: tile steps, gains, an acoustics mix

**Files:**
- Modify: `scripts/Audio/Sfx.gd`: `GAIN` and `LOOP_GAIN` for the new names; `ACOUSTICS` gains `"tile"`; `step()`; a new `set_acoustics_mix`.
- Test: `tests/metro_sound_test.gd` + `tests/metro_sound_test.tscn` (new; the same harness as `tests/layers_test.gd`, with `_check(name, ok, detail)`, `_frames`, Master muted and RESULTS printed).

**Interfaces:**
- Produces:
  - `Sfx.step("tile") == &"step_tile"`. Like carpet and metal, tile has steps only: a run, a jump or a landing on tile is stone's.
  - `Sfx.ACOUSTICS["tile"] := [0.72, 0.3, 0.24, 1.0, 0.1]`: bigger and less damped than stone. By ear.
  - `static func set_acoustics_mix(weights: Dictionary) -> void`: `{kind: weight}`. It blends the `ACOUSTICS` rows by weight (normalised) and reshapes the room as `set_acoustics` does. `set_acoustics(kind)` stays as it is.
  - GAIN entries (dB, starting points): `pipe_tick` −10, `neon_ignite` −6, `cable_surge` −8, `train_far` −4, `metro_draught` −10. LOOP_GAIN: `metro_room` −18, `metro_room_deep` −20, `metro_crowd` −16, `junction_hum` −22, `transformer_hum` −20. The existing names keep their entries.

- [ ] **Step 1: Write the failing checks**

```gdscript
_check("S1 tile has its own steps; its runs, jumps and landings are stone's",
	Sfx.step("tile") == &"step_tile" and Sfx.step("tile", true) == &"step_tile"
	and Sfx.step("tile", false, "jump") == &"jump_stone" and Sfx.step("tile", false, "land") == &"land_stone", "")
Sfx.set_acoustics_mix({"tile": 1.0}); var tiled := _world_reverb().room_size
Sfx.set_acoustics_mix({"stone": 1.0}); var stoned := _world_reverb().room_size
Sfx.set_acoustics_mix({"tile": 0.5, "stone": 0.5}); var half := _world_reverb().room_size
_check("S2 the acoustics blend by weight", tiled > stoned and absf(half - (tiled + stoned) / 2.0) < 0.02, "%.3f %.3f %.3f" % [tiled, stoned, half])
_check("S3 every Metro name has a gain", [&"pipe_tick", &"neon_ignite", &"cable_surge", &"train_far", &"metro_draught"].all(func(n): return Sfx.GAIN.has(n))
	and [&"metro_room", &"metro_room_deep", &"metro_crowd", &"junction_hum", &"transformer_hum"].all(func(n): return Sfx.LOOP_GAIN.has(n)), "")
```

(`_world_reverb()` returns the World bus's AudioEffectReverb.)

- [ ] **Step 2: Run to verify they fail**

Run: `tools/run_suites.sh tests/metro_sound_test.tscn`. Expected: S1-S3 FAIL.

- [ ] **Step 3: Implement as in Interfaces.**

- [ ] **Step 4: Run to verify they pass**

Run: `tools/run_suites.sh tests/metro_sound_test.tscn tests/sound_test.tscn tests/layers_test.tscn`.
Expected: all PASS. If a layers_test check counts takes of a group Task 2 changed, re-baseline it and say so in the commit.

- [ ] **Step 5: Commit**

```bash
git add scripts/Audio/Sfx.gd tests/metro_sound_test.gd tests/metro_sound_test.tscn tests/layers_test.gd
git commit -m "feat(sfx): tile steps, the Metro's gains, acoustics blended by weight"
```

### Task 4: The director: beds by family, depth, the Metro's buses and glue

**Files:**
- Create: `scripts/Audio/PlaceSound.gd`
- Modify: `maps/metro.gd` (`_ready`: `set_meta(&"ambience", "")` before the player is added; `_sets`: the director after PlaceScore), `data/save/stateless.txt`
- Test: `tests/metro_sound_test.gd`

**Interfaces:**
- Consumes:
  - `PlaceZones.from_plan(plan, spaces, circles)`, `weights_at(point) -> {theme: weight}`, `depth_at(point) -> float`.
  - `Sfx.set_acoustics_mix`, `Sfx.LOOP_GAIN`, `Sfx.enabled`, `Sfx.BUS_AMBIENCE`.
  - `TimeFx` real time, as `Ambience.gd` uses it.
- Produces:
  - `class_name PlaceSound extends Node`, in group `&"place_sound"`.
  - `const FAMILIES := {space: family}` covering every plan space:
    - `hall`: hall, corridor_*, cross_*, exit_stairs_*, kiosk_landing_*;
    - `platforms`: platform_n/s, track, siding, stairs_n/s;
    - `market`: market_stairs, pasaje, pasaje_n/s, cistern_lane, herb_market, lane_sw, lane_se, tianguis_lane, fondas, rag_lane, storeroom, square_s, light_gallery, grate_room, loft;
    - `lane`: candle_lane, chapel;
    - `shop`: librarian_shop;
    - `old`: every layer-3 space.
  - `const BEDS := {family: [[loop name, dB, thinned_by_depth]]}`:
    - hall: `[["metro_room", -24, false], ["metro_crowd", -40, true]]`
    - platforms: `[["metro_room", -22, false]]`
    - market: `[["metro_crowd", -20, true], ["metro_room", -30, false]]`
    - lane: `[["metro_crowd", -34, true]]`
    - shop: `[["metro_room", -36, false]]`
    - old: `[["metro_room_deep", -30, false]]`
  - `const FAMILY_SURFACE := {hall: "tile", platforms: "tile", market: "tile", lane: "tile", shop: "carpet", old: ""}`
  - `const FAMILY_ACOUSTICS := {hall: "tile", platforms: "tile", market: "tile", lane: "stone", shop: "stone", old: "cave"}`
  - `const BUS := &"MetroBed"`: it sends to Ambience. Its effects are a compressor (threshold −24, ratio 2, attack 20 ms, release 300 ms) and a low-pass.
  - `const GLUE := {threshold = -20.0, ratio = 2.0, attack_us = 10000.0, release_ms = 250.0}`: on Master at index 0, before the limiter, marked with meta `&"metro_glue"`.
  - `func setup(plan: Dictionary, listener: Node3D, station: Node3D = null, lane: Node3D = null) -> void`: builds the zones, the buses, the glue, one looping player per distinct bed name (on BUS, started at a seeded offset) and the train (Task 6). It is idempotent.
  - `func family_weights_at(point: Vector3) -> Dictionary` (`{family: weight}`).
  - `static func city_of(depth: float) -> float`: `1.0 - smoothstep(0.35, 0.7, depth)`.
  - `func bed_db(name: String, weights: Dictionary, depth: float) -> float`: the loudest that bed is wanted across the families present, by weight, as linear sums. A city bed is scaled by `city_of`. Gives −80 when the bed is absent.
  - `func surface_at(point: Vector3) -> String` (used by Task 5).
  - `var beds := {}` (name → AudioStreamPlayer); `var train: TrainPass` (Task 6).
  - `_process`, on real time: each bed eases toward `bed_db` at 12 dB/s. The acoustics mix is set from the family weights. The MetroBed low-pass cutoff is `lerp(9000.0, 900.0, smoothstep(0.35, 1.0, depth))`.
  - `_exit_tree`: removes the glue and sets `Sfx.set_acoustics("stone")`.

- [ ] **Step 1: Write the failing checks**

The checks run on a synthetic plan: three squares (a hall at layer 1, a market at layer 2, an old space at layer 3), each with openings onto the next, a `Node3D` as the listener, and no station or lane.

```gdscript
_check("S4 inside a space its family's bed is full", is_equal_approx(sound.family_weights_at(HALL_MID).get("hall", 0.0), 1.0), str(sound.family_weights_at(HALL_MID)))
_check("S5 at an opening two families cross over", _near(sound.family_weights_at(HALL_MARKET_DOOR).get("hall", 0.0), 0.5, 0.1), "")
_check("S6 the city keeps full through the market, gone in the old layer",
	is_equal_approx(PlaceSound.city_of(0.0), 1.0) and is_equal_approx(PlaceSound.city_of(0.35), 1.0) and is_equal_approx(PlaceSound.city_of(0.7), 0.0), "")
_check("S7 the market's crowd is louder than the hall's; the old layer has none",
	sound.bed_db("metro_crowd", {"market": 1.0}, 0.35) > sound.bed_db("metro_crowd", {"hall": 1.0}, 0.0)
	and sound.bed_db("metro_crowd", {"old": 1.0}, 0.7) <= -79.0, "")
sound.setup(plan, ear); sound.setup(plan, ear)
_check("S8 set up twice: one glue, one MetroBed", _glue_count() == 1 and _bus_count(&"MetroBed") == 1, "")
sound.queue_free(); await _frames(2)
_check("S9 gone: Master as it was, no glue; the acoustics back to stone", _glue_count() == 0 and _master_effects() == before_effects, "")
# S10: walk the ear from HALL_MID into a hole outside every polygon; after 30 frames the bed's level holds within 1 dB of where it was.
# S11: with Sfx.enabled = false: setup and 30 frames give no errors (the engine-error scan) and no beds playing.
# S12: Engine.time_scale = 0.2: a bed's fade from −80 toward its target moves at its real-time rate (within 10 %).
_check("S13 the Metro: the director is in, the default night ambience is not",
	metro.get_node_or_null("PlaceSound") != null and metro.get_node_or_null("Ambience") == null, "")
```

- [ ] **Step 2: Run to verify they fail**

Run: `tools/run_suites.sh tests/metro_sound_test.tscn`. Expected: S4-S13 FAIL with "PlaceSound" not found.

- [ ] **Step 3: Implement `PlaceSound.gd`, hook it into `maps/metro.gd`, and list it in `data/save/stateless.txt`**

The stateless line: `# its beds are worked out each frame from where you stand; its train is the lane's (saved)`.

- [ ] **Step 4: Run to verify they pass**

Run: `tools/run_suites.sh tests/metro_sound_test.tscn tests/metro_test.tscn tests/place_score_test.tscn tests/save_coverage_test.tscn`. Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/Audio/PlaceSound.gd maps/metro.gd data/save/stateless.txt tests/metro_sound_test.gd
git commit -m "feat(metro): the Metro's sound follows its spaces: beds by family, thinned by depth, its own glue and room"
```

### Task 5: Floors answer from the place

**Files:**
- Modify: `scripts/PlayerController.gd` (`_surface_name`, ~line 1546)
- Test: `tests/metro_sound_test.gd`

**Interfaces:**
- Consumes: `PlaceSound.surface_at(point) -> String` (Task 4).
- Produces: when the floor under the feet has no `surface` meta, `_surface_name()` returns `get_tree().get_first_node_in_group(&"place_sound").surface_at(feet)` if a director exists, else `""` as today. A floor's own meta still wins, and so does water.

- [ ] **Step 1: Write the failing checks**

```gdscript
_check("S14 a bare floor in the hall walks as tile, in the shop as carpet, in the old layer as stone",
	sound.surface_at(HALL_MID) == "tile" and sound.surface_at(SHOP_MID) == "carpet" and sound.surface_at(OLD_MID) == "", "")
# S15: a player on a bare StaticBody3D floor inside the synthetic hall: _surface_name() == "tile";
#      the same floor given set_meta(&"surface", "wood"): "wood".
```

- [ ] **Step 2: Run, verify they fail.** Run: `tools/run_suites.sh tests/metro_sound_test.tscn`. Expected: S14-S15 FAIL.
- [ ] **Step 3: Implement as in Interfaces.**
- [ ] **Step 4: Run, verify they pass.** Run: `tools/run_suites.sh tests/metro_sound_test.tscn tests/sound_test.tscn tests/movement_test.tscn`. Expected: all PASS.
- [ ] **Step 5: Commit**: `git commit -am "feat(metro): a bare floor walks as its place: tile in the station and market, carpet in the shop"`

### Task 6: One train for the Metro

**Files:**
- Modify: `scripts/Audio/PlaceSound.gd`
- Test: `tests/metro_sound_test.gd`

**Interfaces:**
- Consumes: `TrainPass` (`began`, `peaked`, `strength()`, `seed`); the lane's `train` (underground_lab.gd); the station's `mouth_runs` (`[x from, x to, z, bed, roof]` in the set's frame); Focus; `Sfx.play(context, sound, at, volume, pitch)`.
- Produces:
  - `train` is `lane.train` when a lane is given, else a `TrainPass` of its own (seed 31) added under the director.
  - On `began`: a `train_far` take plays at each track mouth's middle (`station.to_global(Vector3((from + to) / 2, bed + 1.5, z))`) at `RUMBLE_DB (−4) + linear_to_db(maxf(city_of(depth), 0.001))`, so it is gone in the old layer. Then, 1.0 s later, `metro_draught` plays flat on BUS, scaled by the platforms' weight × city.
  - On `peaked`: a `cable_surge` plays at the station run end (the last of a run's `points` meta) nearest the listener, asking `Focus.allow(&"detail")`.
  - `func train_heard() -> Array`: `[[sound, where, dB]]` played this pass, for tests.

- [ ] **Step 1: Write the failing checks**

```gdscript
_check("S16 with a lane, the Metro's train is the lane's", sound_with_lane.train == fake_lane.train, "")
# S17: start_pass() with the ear on a platform: train_heard() has two train_far (one per mouth) above −10 dB and a metro_draught.
# S18: the same with the ear in the old layer: no train_far above −79 dB, no draught.
# S19: at the peak: one cable_surge, at the run end nearest the ear.
```

(The fake station is a `Node3D` with `mouth_runs` and `runs` holding two run nodes with `points` metas. The fake lane is a `Node` with a `train: TrainPass`.)

- [ ] **Step 2: Run, verify they fail.** Run: `tools/run_suites.sh tests/metro_sound_test.tscn`. Expected: S16-S19 FAIL.
- [ ] **Step 3: Implement as in Interfaces.**
- [ ] **Step 4: Run, verify they pass.** Run: `tools/run_suites.sh tests/metro_sound_test.tscn tests/underground_lab_test.tscn`. Expected: all PASS.
- [ ] **Step 5: Commit**: `git commit -am "feat(metro): one train for the Metro: its rumble from the tunnel mouths, its draught on the platforms, the cables surging"`

### Task 7: The station's sources

**Files:**
- Modify: `scripts/Audio/PlaceSound.gd`
- Test: `tests/metro_sound_test.gd`

**Interfaces:**
- Consumes the station's lists: `neon` (NeonSign, `buzz` is `&""` today), `runs` (meta `points`), `mains`, `risers`, `mouths`, `floor_mains`, all in the tree. Also `PipeSounds.run(loop, from, to, reach)`, `knocks(from, to, every)`, `events(sound, at, every, db, pitch)`; `Focus.hold`.
- Produces, in `setup` when a station is given:
  - each `station.neon[i].buzz = StringName("neon_buzz_%d" % (1 + i % 3))`;
  - a `junction_hum` loop at each run's last point (max_distance 6, held `&"loop"`);
  - one `PipeSounds` child, `station_pipes`, fed with:
    - `run(&"transformer_hum", a, b, 7.0)` along each floor main;
    - `knocks(a, b, Vector2(40, 90))` along each main and riser;
    - `events(&"pipe_tick", riser middle, Vector2(6, 14), -8.0)`;
    - `events(&"pipe_hiss", mouth + Vector3(0, 0.9, 0), Vector2(18, 40), -6.0)`.

    `a` and `b` are the two ends of the piece's long axis: its mesh AABB in world space, at the middles of its two smallest faces.
  - `func station_sources() -> Dictionary`: `{neon: n, junctions: n, transformer_runs: n, knock_runs: n, ticks: n, hisses: n}`, for tests.

- [ ] **Step 1: Write the failing checks**

```gdscript
var counts := metro_sound.station_sources()
_check("S20 the station's pieces sound: every sign buzzes, every run ends in a junction, the mains and vents are fed",
	counts.neon == station.neon.size() and station.neon.all(func(s): return s.buzz != &"")
	and counts.junctions == station.runs.size() and counts.knock_runs == station.mains.size() + station.risers.size()
	and counts.hisses == station.mouths.size(), str(counts))
```

This runs on the real Metro (`maps/metro.tscn`), loaded once in the suite's Metro section.

- [ ] **Step 2: Run, verify it fails.** Run: `tools/run_suites.sh tests/metro_sound_test.tscn`. Expected: S20 FAIL.
- [ ] **Step 3: Implement as in Interfaces.**
- [ ] **Step 4: Run, verify it passes.** Run: `tools/run_suites.sh tests/metro_sound_test.tscn tests/metro_station_test.tscn tests/layers_test.tscn`. Expected: all PASS.
- [ ] **Step 5: Commit**: `git commit -am "feat(metro): the station's machine sounds: its neon, its junctions, the transformer in its floor mains, knocks, ticks and the vents' hiss"`

### Task 8: Neon going out and coming back

**Files:**
- Modify: `scripts/Visual/NeonSign.gd` (`_sound`), `scripts/Audio/PlaceSound.gd` (the station's signs sag with the train)
- Test: `tests/layers_test.gd` (N-series)

**Interfaces:**
- Produces:
  - `NeonSign.OUT_BELOW := 0.3` and `NeonSign.BACK_ABOVE := 0.6`. When `dim` falls below OUT_BELOW the sign counts as out; when it next rises above BACK_ABOVE, `neon_ignite` plays once at the sign, asking `Focus.allow(&"detail")`. A new saved field, `_out`, is appended to `SAVED`.
  - PlaceSound sets each station sign's `dim` to `1.0 - s * (STATION_BROWNOUT.x + STATION_BROWNOUT.y * dip)` while a train passes. `STATION_BROWNOUT := Vector2(0.35, 0.45)`, and `dip` follows the bay's formula with its own clock. The deepest dips reach 0.2, so a sign goes out and comes back.

- [ ] **Step 1: Write the failing checks**

```gdscript
# N-ignite: a NeonSign with buzz set; dim = 0.2 for 10 frames, then 1.0: one neon_ignite recorded (Sfx.recording); dim 0.5 → 1.0 again: none.
# N-saved: "_out" in NeonSign.SAVED.
```

- [ ] **Step 2: Run, verify they fail.** Run: `tools/run_suites.sh tests/layers_test.tscn`. Expected: the two new N checks FAIL.
- [ ] **Step 3: Implement as in Interfaces.**
- [ ] **Step 4: Run, verify they pass.** Run: `tools/run_suites.sh tests/layers_test.tscn tests/metro_sound_test.tscn tests/save_coverage_test.tscn`. Expected: all PASS.
- [ ] **Step 5: Commit**: `git commit -am "feat(neon): a sign put out by a train's draw strikes back on with its ignition"`

### Task 9: The candle lane un-hushed

**Files:**
- Modify: `maps/candle_lane.gd` (`_hush`), `maps/underground_lab.gd` (the rattle's `hushed` guard)
- Test: `tests/metro_sound_test.gd`, `tests/layers_test.gd` (Y-series, if it asserts the hush)

**Interfaces:**
- Produces: when the lane is set into the Metro (`standalone == false`), `_hush()` keeps `vent_hum` (its new source comes from Task 2) and lets the jars' `_rattle` play on `peaked`. It still stops the flat `rumble`, the `crowd` node and `dark_wind`. Standalone, it behaves as today.

- [ ] **Step 1: Write the failing checks**

```gdscript
# S21 (the real Metro): the lane's vent_hum is playing with a stream; its rumble and dark_wind have none; its crowd is disabled.
# S22: lane.train.start_pass(), run to peaked: the lane's _rattle played.
```

- [ ] **Step 2: Run, verify they fail.** Run: `tools/run_suites.sh tests/metro_sound_test.tscn`. Expected: S21-S22 FAIL.
- [ ] **Step 3: Implement as in Interfaces.**
- [ ] **Step 4: Run, verify they pass.** Run: `tools/run_suites.sh tests/metro_sound_test.tscn tests/layers_test.tscn tests/underground_lab_test.tscn tests/metro_test.tscn`. Expected: all PASS.
- [ ] **Step 5: Commit**: `git commit -am "feat(lane): set into the Metro, the lane's vent breathes and its jars rattle again; the Metro's train and crowd stand in for its own"`

### Task 10: The whole run, and the docs

**Files:**
- Modify: `docs/systems/audio.md` (a "The Metro's sound" section: the director, families, buses, the tool's `--metro`), `docs/reference/README.md` if it lists audio scripts
- Test: every suite

- [ ] **Step 1: Run every suite.** Run: `tools/run_suites.sh`. Expected: everything passes, except what was red before this branch: `pasaje_view_test` (windowed only) and the known flakes (`sound_test` M12 under load, `library_lab_test` L20). Re-run each of those alone to confirm.
- [ ] **Step 2: Write the docs section.** Then commit: `git commit -am "docs(audio): the Metro's sound"`

### Task 11: The listening walk (the user's ear, then play)

**Files:**
- Create: `tests/diag_metro_sound_walk.gd` + `.tscn`: the score's walk (`tests/diag_place_score_walk.gd`), recording Master with `AudioEffectRecord`. The walk goes from the platform up to the hall, along a corridor, down into the Pasaje, through the candle lane, into the shop and down to the vaults, with one train forced on the platform. It writes `$TMPDIR/metro_sound_walk.wav` and prints the time at which each family is entered.
- Modify: `docs/superpowers/specs/2026-10-31-metro-sound-design.md` (the plan's three calls written in)

- [ ] **Step 1: Record the walk.** Run: `GODOT=/Users/tinkertailorr/Desktop/Godot.app/Contents/MacOS/Godot; "$GODOT" --path . --fixed-fps 60 res://tests/diag_metro_sound_walk.tscn`. Expected: the WAV is written, and each family is printed with its time.
- [ ] **Step 2: The user listens (gate).** Send the WAV with the family times. Adjust levels in `BEDS`, GAIN and LOOP_GAIN only, then re-record, until the user approves.
- [ ] **Step 3: The user plays `maps/metro.tscn`.** Fix what they hear test-first, with each fix in its own commit.
- [ ] **Step 4: Commit the walk and the spec**: `git commit -am "test(metro): the sound's listening walk; the spec carries the plan's calls"`
