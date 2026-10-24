# Underground Sound Layers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire the approved neon, pipe and book layers into the Underground bay, the candle lane and the librarian's shop, under one focus director that decides what is heard when many things sound.

**Architecture:** A scene-owned `Focus` node (made on demand like `Sfx`'s) holds every registered looping player. Each frame it sets that player's volume to its own base level plus an eased duck and a featured dip, and it gates one-shots per tier in a 2 s window. Each layer's sound lives in the script that owns its cause: `NeonSign` (hum + ticks), a new `PipeSounds` node (line sources sliding along each main, plus timed events), and a new `BookSounds` node that listens to signals added to `ShelfStir`, `FloatingBooks` and `LiveBook`. Every looping player is built on its node's first `_process`, so the candle lane's `_hush` (it runs once in `_ready`) never reaches it.

**Tech Stack:** Godot 4.5 GDScript; the takes and loops already cut by `tools/prepare_sfx.py --layers` (uncommitted, approved by ear); headless tests at `--fixed-fps 60`.

**Spec:** `docs/superpowers/specs/2026-10-24-underground-sound-layers-design.md`

## Global Constraints

- Godot: `G=/Users/tinkertailorr/Desktop/Godot.app/Contents/MacOS/Godot`. Run a suite with `$G --headless --path . --fixed-fps 60 tests/<suite>.tscn`. Every suite prints `PASS`/`FAIL` lines.
- Work in the worktree `.claude/worktrees/metro-standard` (branch metro-standard). **Another session works in it at the same time.** Before each commit, run `git status --short`, and `git add` only this plan's files by name, never `-A` or `.`.
- `tests/underground_lab_test.gd` has another session's uncommitted changes. Task 6 edits it. If `git diff tests/underground_lab_test.gd` still shows changes that aren't yours when you get there, stop and ask the user. Never commit someone else's hunks.
- `maps/candle_lane.gd` belongs to the other session. Don't edit it. Its `_hush()` must keep sparing every new sound.
- Tiers (target LUFS at 1 m): bed −42, loop −36, detail −30, featured −26. Per-tier counts kept at full: loop 3, detail 4. One-shots per 2 s window: detail 3, featured 2. A sunk source sinks by up to −12 dB, eased over ~1 s. While a featured sound plays within 8 m, loops and details dip −3 dB.
- Levels: one-shots use `Sfx.GAIN` and loops use `Sfx.LOOP_GAIN`. Both are already in `scripts/Audio/Sfx.gd`, uncommitted. Don't re-level an approved sound.
- Reaches: neon 4.5 m, pipes 8 m (the air line 6 m), books 6 m.
- Neon: the hum dips with every stutter. A tick/zap pair has a 35% chance per stutter and comes at least 5 s after the last.
- The ánimas keep their own cap and levels (voices −30, moans −28). Focus doesn't gate them; their moans call `Focus.featured`.
- New random draws use their own `RandomNumberGenerator`, so existing seeded suites don't shift. The suites to keep green: `animas_test` 7, `sound_test` 19, `underground_lab_test` 62, `candle_lane_test` 28, and the five `library_*_test` suites.
- In the headless suites, sound is turned on the way `tests/sound_test.gd:231` does it (`SfxScript.enabled = true`) and Master is muted (`AudioServer.set_bus_mute(0, true)`). Decisions are also counted in plain fields, so a check never depends on what was heard.
- Comment style: `##` doc lines in the project's voice (plain, concrete, the cause in the world). Match the surrounding files.

## Review Focus

1. **The lane's `_hush` after `_ready`.** A loop built in a node's `_ready` gets silenced. Expect the neon hum and the trickle to be playing in `maps/candle_lane.tscn` one second in. Pinned in Task 6 (Y3).
2. **A source freed while registered** (a map reloaded, a book queue-freed). Focus must drop it and never error on a freed player. Pinned in Task 1 (F5).
3. **The brownout** (`NeonSign.dim` < 1 while the dark train passes). The hum should sag with the light, never jump. Pinned in Task 2 (N3).
4. **Many loops in one place** (8 floating books plus the shop's neighbours). Only the 3 nearest loops play at full; the rest sink and are never cut off hard. Pinned in Task 1 (F2) and Task 5 (B4).
5. **Standing on a run's end or past it.** A pipe emitter clamps to its run's ends and never jumps across the room. Pinned in Task 3 (P2).

---

### Task 1: The focus director

**Files:**
- Create: `scripts/Audio/Focus.gd`
- Create: `tests/layers_test.gd`, `tests/layers_test.tscn` (a copy of `tests/animas_test.tscn` pointing at the new script)

**Interfaces:**
- Produces (all static, on `const Focus := preload("res://scripts/Audio/Focus.gd")`):
  - `TIERS := {&"bed": 1, &"loop": 3, &"detail": 4, &"featured": 2}` (how many play at full)
  - `SHOTS := {&"detail": 3, &"featured": 2}`, `WINDOW := 2.0`, `SINK := -12.0`, `EASE := 1.0`, `EVERY := 0.2`, `DIP := -3.0`, `DIP_NEAR := 8.0`
  - `hold(context: Node, player: AudioStreamPlayer3D, tier: StringName, base_db: float, priority := 1.0) -> void`: registers the player. From then on, Focus owns its `volume_db`.
  - `base(player: AudioStreamPlayer3D, db: float) -> void`: the source's own level now (a neon's flicker, occlusion).
  - `allow(context: Node, tier: StringName, at: Vector3) -> bool`: the one-shot gate. Counted with sound off too. Tiers not in `SHOTS` always pass.
  - `featured(context: Node, at: Vector3, length: float) -> void`: starts the dip.
  - `duck_of(player: AudioStreamPlayer3D) -> float`: the eased duck now, in dB (for tests).
  - `rank(entries: Array, ear: Vector3) -> Array`: pure. Each entry is `{"at": Vector3, "priority": float, "reach": float}`. Returns their indices, most audible first, leaving out any beyond its reach. Audibility is `priority / maxf(distance, 1.0)`.
  - `reset() -> void`: clears the static state between tests.
- The node: `_node_for(context)` follows `Sfx._node_for` (made under `tree.current_scene`, named `Focus`). Every `EVERY` s it re-ranks each tier. Each frame, for each held player, it sets `volume_db = base + duck + dip`. A player's duck eases toward 0 (if it is in its tier's top count) or toward `SINK`, at `-SINK / EASE` dB/s. Freed players are dropped.

- [ ] **Step 1: Write the failing tests** in `tests/layers_test.gd`, in `animas_test.gd`'s shape (`_check(label, ok, detail)`, a RESULTS block, quit 1 on failure). Sound on and Master muted, as in Global Constraints.
  - `F1 rank orders by priority over distance and leaves out those past reach`: entries at 1 m (p 1), 4 m (p 1), 2 m (p 3), 20 m (reach 8) → `[2, 0, 1]`.
  - `F2 only the three nearest loops play at full, the rest sink to -12 eased`: hold 5 loop players at 1, 2, 3, 6, 7 m from a current Camera3D, base −20. After 90 frames, the first three have `duck_of > -0.5` and the last two `< -11.5`. After 10 frames, the far two are between −1 and −11.5 (eased, not cut).
  - `F3 one-shots: at most three details in any two seconds`: 10 `allow(detail)` calls in one frame give 3 trues. After 2.1 s of frames, another true.
  - `F4 a featured sound near dips loops and details by 3 dB while it plays`: `featured(at 1 m, 1.0 s)`. A held loop's `volume_db` is `base + duck − 3 ± 0.3` mid-way and back to `base + duck ± 0.3` after 1.5 s.
  - `F5 a freed player is let go without error`: hold one, `queue_free` it, step 20 frames. No error, and Focus's held count drops by one.
- [ ] **Step 2: Run it and see it fail** (`tests/layers_test.tscn`). Expected: a parse error, since `Focus.gd` doesn't exist yet.
- [ ] **Step 3: Implement `scripts/Audio/Focus.gd`** with the interfaces above.
- [ ] **Step 4: Run it and see F1–F5 pass.**
- [ ] **Step 5: Commit** `scripts/Audio/Focus.gd tests/layers_test.gd tests/layers_test.tscn` with the message "feat(audio): the focus director".

### Task 2: The neon's hum and its stutters

**Files:**
- Modify: `scripts/Visual/NeonSign.gd`
- Modify: `scripts/Audio/Sfx.gd` and `tools/prepare_sfx.py` (commit the uncommitted layer gains and cuts with this task), plus `audio/ambience/{neon_buzz_*,pipe_*,book_flutter}.wav[.import]` and `audio/sfx/{neon_*,pipe_*,shelf_*,book_*}_N.wav[.import]`
- Test: `tests/layers_test.gd`

**Interfaces:**
- Consumes: `Focus.hold`, `Focus.base`, `Focus.allow`; `Sfx.play`, `Sfx.LOOP_GAIN`.
- Produces, on NeonSign:
  - `@export var buzz := &""`: a `LOOP_GAIN` name. Empty means silent, so other signs don't change.
  - `var hum: AudioStreamPlayer3D`: built on the first `_process`, only when `Sfx.enabled` and `buzz` is set. Bus World, `max_distance` 4.5, `unit_size` 1.2, started at a random point of its loop.
  - `var ticks := 0`.
  - `static func hum_db(gain: float, level: float) -> float`: returns `gain + linear_to_db(maxf(level, 0.02))`.
  - `TICK_CHANCE := 0.35`, `TICK_APART := 5.0`.
- Behaviour:
  - Each frame: `Focus.base(hum, hum_db(LOOP_GAIN[buzz], energy_at(_time) * dim))`.
  - On a fall from ≥ 0.5 to < 0.5: roll `_sound_rng` (seeded `seed * 31 + 3`). If it passes `TICK_CHANCE`, at least `TICK_APART` game seconds have gone since the last tick, and `Focus.allow(detail)` says yes: play `neon_tick`, `ticks += 1`, and arm a zap.
  - On the next rise to ≥ 0.5 while a zap is armed: play `neon_zap`.
  - Tier: loop, priority 1.

- [ ] **Step 1: Write the failing tests:**
  - `N1 her sign hums from its tube, its loudness following the flicker`: a NeonSign with the lab's pattern (`underground_lab.gd:390`), seed 11, `buzz = &"neon_buzz_1"`, a Camera3D 1.5 m away. After 30 frames, `hum.playing`, `hum.max_distance <= 4.5`. Over 300 frames, sampled each frame, Focus's base for it equals `hum_db(LOOP_GAIN[&"neon_buzz_1"], level())` within 0.1.
  - `N2 its stutters tick only now and then, never closer than five seconds`: over 60 s of frames, `ticks` is between 2 and 7, and no two ticks are less than 5 s apart (log the `_time` of each tick).
  - `N3 a brownout sags the hum with the light`: set `dim` from 1 to 0.3 over 1 s. The base falls monotonically, frame to frame, by no more than 1.5 dB in any frame.
- [ ] **Step 2: Run and see N1–N3 fail.**
- [ ] **Step 3: Implement it in `NeonSign.gd`.**
- [ ] **Step 4: Run and see N1–N3 pass.** Run `sound_test` too: still 19 PASS, since its D26b covers every `GAIN` name.
- [ ] **Step 5: Commit** NeonSign, Sfx.gd, prepare_sfx.py and the new audio files by name, with the message "feat(metro): the neon's hum follows its tube, and ticks now and then".

### Task 3: The pipes

**Files:**
- Create: `scripts/Audio/PipeSounds.gd`
- Test: `tests/layers_test.gd`

**Interfaces:**
- Consumes: `Focus.hold/base/allow`, `Sfx.play`, `Sfx.occlusion_at`, `Sfx.LOOP_GAIN`.
- Produces (`extends Node3D`, positions in its parent's frame; `@export var seed := 9`):
  - `run(loop: StringName, from: Vector3, to: Vector3, reach := 8.0) -> void`: a line source. Its player slides each frame to the point on `from`→`to` nearest the camera, clamped to the ends. Tier loop. Built on the first `_process`.
  - `knocks(from: Vector3, to: Vector3, every: Vector2) -> void`: every `every` s, 3 `pipe_knock` strikes travelling along the run from a random point on it, each 2.5–4 m further on and 0.16–0.38 s later, at 0, −4 and −8 dB.
  - `events(sound: StringName, at: Vector3, every: Vector2, db := 0.0, pitch := 1.0) -> void`: a one-shot at a fixed place every `every` s (gurgle, hiss, drip, the gas line's tick).
  - `var played := {}`: sound → count (with sound off too). `func emitter_of(i: int) -> AudioStreamPlayer3D`.
  - Every one-shot asks `Focus.allow(&"detail", at)` first. A refusal is counted in `played[&"refused"]` and not retried.
  - Its own `_rng` is seeded from `seed`.

- [ ] **Step 1: Write the failing tests:**
  - `P1 the main is heard where you are along it`: `run(&"pipe_trickle", (-12,3.25,-2.2), (12,3.25,-2.2))`. With the camera at x −5, 0 and +7 (z 0), the emitter's x is within 0.05 of the camera's.
  - `P2 past a run's end the sound stays at its end`: camera at x 20 → emitter at x 12.
  - `P3 a knock travels: three strikes, each fainter and further along`: `knocks(...)` with `every` (1, 1). Record the strikes for 3 s: there are at least 3, in order, at positions moving one way, 2.5–4 m apart.
  - `P4 the weeping joint drips, never two drops at once`: `events(&"pipe_drip", DRIP_AT_floor, Vector2(1.4, 3.4))` over 20 s gives between 5 and 15 drops, none closer than 1.4 s.
- [ ] **Step 2: Run and see P1–P4 fail.**
- [ ] **Step 3: Implement `PipeSounds.gd`.**
- [ ] **Step 4: Run and see P1–P4 pass.**
- [ ] **Step 5: Commit** with the message "feat(audio): the pipes heard along their runs, knocking now and then".

### Task 4: The books' cues

**Files:**
- Modify: `scripts/Visual/Library/ShelfStir.gd`, `scripts/Visual/Library/FloatingBooks.gd`, `scripts/Visual/LiveBook.gd`
- Test: `tests/layers_test.gd`, instancing `maps/library_lab.tscn` as `tests/library_effects_test.gd:4` does (the five `library_*_test` suites must keep passing unchanged)

**Interfaces:**
- Produces:
  - `ShelfStir`: `signal stirred(board: int, kind: StringName, at: Vector3)`, emitted in `try_board` after `changes += 1`. `kind` is the name of the attempt `_change` used: `&"by_height"`, `&"push_home"`, `&"close_gap"`, `&"stand_up"` or `&"square_stack"`. `_change` records it in `var last_kind`. `at` is the board's world middle. No new RNG draws.
  - `FloatingBooks`: `signal moved(k: int, what: StringName, at: Vector3)`, emitted on every state change: `&"descending"`, `&"resting"` (landed), `&"rising"` (lifted off), `&"aloft"`. `at` is the book's world position.
  - `LiveBook`: `signal opening(book: LiveBook)`, emitted the frame `open` leaves 0 on the way up. `closed` stays as it is.

- [ ] **Step 1: Write the failing tests:**
  - `B1 a shelf that changes unseen says how it changed`: in the library lab with the camera looking away, call `stir.try_board(i)` on a board it may change. `stirred` fires once, with a `kind` from the five and `at` within 1 m of that board.
  - `B2 a floating book tells when it comes down, lands, lifts and rises`: `floating.come_home(k)` for a transfer book. Over 10 s, `moved` gives `descending`, `resting`, `rising`, in that order.
  - `B3 a live book tells when it starts to open`: camera in front within `OPEN_NEAR`. `opening` fires before `opened`, at least `OPEN_TIME × 0.8` s earlier.
  - Every existing check in that suite still passes, since no RNG draw was added.
- [ ] **Step 2: Run and see B1–B3 fail.**
- [ ] **Step 3: Add the three signals.**
- [ ] **Step 4: Run and see them pass, plus all five `library_*_test` suites.**
- [ ] **Step 5: Commit** with the message "feat(library): the books say when they move".

### Task 5: The books heard

**Files:**
- Create: `scripts/Audio/BookSounds.gd`
- Modify: `maps/library_lab.gd` (build it after `stir`, around line 613)
- Test: `tests/layers_test.gd`

**Interfaces:**
- Consumes: Task 4's signals; `Focus`; `Sfx.play`.
- Produces: `BookSounds` (`extends Node`):
  - `func listen(stir: Node, floating: Node3D, live_books: Array) -> void`
  - `var played := {}`
- Mapping (every one-shot goes through `Focus.allow(&"detail", at)`):
  - `by_height` and `square_stack` (−3 dB) → `shelf_shuffle`
  - `push_home` → `shelf_slide`, then `shelf_tock` 0.35 s later
  - `close_gap` → `shelf_slide`
  - `stand_up` → `shelf_tock`
  - `moved resting` → `book_land`; `moved rising` → `book_lift`
  - `opening` → `book_open`, then `book_riffle` 0.45 s later; `closed` → `book_shut`
  - Each floating book carries a `book_flutter` loop. It is built on BookSounds' first `_process`, as a child of the book, `max_distance` 6, held as tier loop, started at a random point. While the book rests, its base is −60 (silent).

- [ ] **Step 1: Write the failing tests:**
  - `B4 eight floating books flutter, only the nearest three at full`: in the library lab with the camera under the vault, after 120 frames there are 8 flutter players, 3 with `duck_of > -0.5`.
  - `B5 each change of a shelf is heard by its kind`: drive `stirred` once for each kind. `played` gets the mapped sounds, with push_home's tock after its slide.
  - `B6 a resting book's pages fall silent`.
- [ ] **Step 2: Run and see B4–B6 fail.**
- [ ] **Step 3: Implement BookSounds and the hookup.**
- [ ] **Step 4: Run and see B4–B6 pass, plus the library suites.**
- [ ] **Step 5: Commit** with the message "feat(library): the shop's books heard".

### Task 6: Into the bay, the lane and the ánimas

**Files:**
- Modify: `maps/underground_lab.gd`:
  - set `neon.buzz = &"neon_buzz_1"` where the sign is built (line ~387);
  - remove the `hum` emitter, `hum_volume`, `junction_hum` and `drip_sound` (lines ~601-634 and ~891-896) and their constants `HUM`, `BOX_HUM`, `DRIP_SOUND`;
  - add `_pipe_sounds()`, called at the end of `_services()`.
- Modify: `scripts/Visual/Animas.gd`: in `_speak`, when `sound == &"anima_moan"` and the take plays, call `Focus.featured(self, at, length)`.
- Modify: `tests/underground_lab_test.gd`: U13, U19 and U29 (see Global Constraints about the other session's hunks).
- Test: `tests/layers_test.gd`

**Interfaces:**
- Consumes: Tasks 1-3.
- `_pipe_sounds()`: one `PipeSounds` child, `seed` 9, in the lab's frame. Run ends are `±half_run`. The y and wall values are the ones `_services` uses.
  - water main: `run(&"pipe_trickle", BACK_WALL at CONDUIT.y)`, gurgles every 14–30 s at a random x along it (one `events` per 6 m segment, or random per event, your call);
  - fire main: `knocks(FAR_WALL at FIRE_Y, every (18, 40))`; the valve hiss `events(&"pipe_hiss", (9, FIRE_Y, FAR_WALL), (20, 45))`;
  - air line: `run(&"pipe_air", FAR_WALL at AIR_Y, 6.0)`;
  - gas line: `events(&"pipe_knock", a joint at x −1.3, GAS_Y, (40, 90), −10, 1.6)`;
  - the weeping joint: `events(&"pipe_drip", (DRIP_AT.x, 0.05, DRIP_AT.z), (1.4, 3.4))`.

- [ ] **Step 1: Write the failing tests** in `layers_test.gd`:
  - `Y1 the bay's sign hums and its mains are heard`: instance `maps/underground_lab.tscn` with sound on. After 60 frames, `lab.neon.hum.playing`, and a PipeSounds child has 2 run emitters playing.
  - `Y2 the old hums are gone`: no node named `junction_hum`, `hum` or `drip_sound` anywhere under the lab.
  - `Y3 the candle lane's hush spares the new sounds`: instance `maps/candle_lane.tscn`. After 60 frames, the neon hum and the trickle are playing.
  - `Y4 an ánima's cry dips the bay under it`: force a moan on a lab ánima (`_become(i, "dragged")` with the moan roll passing; seed a soul to make it pass, or call `_speak(i, &"anima_moan")` directly). The trickle's volume is 3 dB under its `base + duck` for the moan's length.
  - Change U13 to "the neon hums from its sign, silent past 4.5 m, its loudness following the flicker" (it reads `lab.neon.hum` and `NeonSign.hum_db`). Change U19 to "water drips off the conduit into a puddle, its drops heard" (the PipeSounds drip `events` exists at the puddle). Delete U29 and leave a one-line comment that the junction box's hum was retired on Oct 24.
- [ ] **Step 2: Run and see Y1–Y4 fail.**
- [ ] **Step 3: Implement the hookups.**
- [ ] **Step 4: Run all of these and see them pass:** `layers_test`, `underground_lab_test` (still 62 or 61 checks, all PASS), `candle_lane_test` 28, `animas_test` 7, `sound_test` 19, `metro_test`, and the five library suites.
- [ ] **Step 5: Commit by name** with the message "feat(metro): the bay's neon, mains and drips heard; the old hums retired".

### Task 7: Everything at once, for the user's ear

**Files:**
- Modify: `tests/diag_layer_sounds.gd`: add `--layer=all`.
- Output: `docs/superpowers/refs/underground/sound/all.wav` (not committed, as the other listening files aren't)

- [ ] **Step 1:** `--layer=all` sets `Sfx.enabled = true`, instances `maps/underground_library_lab.tscn`, makes its own Camera3D current, and walks it 45 s: down the corridor past the stall's sign under the mains (where the drain's ánimas are), then in through the arch to stand under the vault. It records at the game's own levels plus `LISTEN`, and prints each one-shot Focus allowed or refused.
- [ ] **Step 2:** Run it and check the file. Peak below −1 dBFS. No silent stretch longer than 3 s. The log shows Focus refusing at least once, or say plainly that nothing crowded.
- [ ] **Step 3:** Send the file to the user. Their verdict decides any re-levels. The plan is done when they approve it.
