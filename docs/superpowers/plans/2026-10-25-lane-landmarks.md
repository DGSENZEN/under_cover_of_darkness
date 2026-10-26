# The Candle Lane's Landmarks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** From the Pasaje mouth, the curandera's stall and the librarian's shop read as landmarks. Hers: a garland, a
tin heart and a copal haze. His: a red lantern, a dressed threshold and drifting pages. The blank sign and the niche
quieten.

**Architecture:**
- **Kit:** a new small kit, `tools/eclipse/lane_landmarks.py`, with its own atlas of at most 2048, built by the existing
  lab pipeline into `assets/eclipse/kit/lane_landmarks.glb`. `maps/candle_lane.gd` places it.
- **Effects:** the copal haze is a `Vfx.gd` preset; the pages are a new script, `scripts/Visual/DriftingPages.gd`,
  riding the bay's one draught through a new `draught_now()`.
- **Checks:** a windowed mouth-view test judges what reads; the headless lane suite judges placement and clearances.

**Tech Stack:** Godot 4.5.1 (GDScript), Blender 4 (bpy kit scripts), Python 3 (atlas painter).

**Spec:** `docs/superpowers/specs/2026-10-24-lane-landmarks-design.md`

## Global Constraints

- **Frame:** all positions are in the lane's frame (`maps/candle_lane.gd`: x along the lane, z across).
  - **Walls:** BACK_WALL −2.35 (north), FAR_WALL 4.55 (south), HEIGHT 4.0, half_run 16.8 (the mouth at x −16.8).
  - **Her stall:** at the origin, counter face at z 0; her front rail is at 2.35 m (`stall.py` FRONT_H). Her customers
    stand at x 0.65 and 1.85.
  - **His shop:** the front spans x 2.2–10.2; the arch's opening is x 4.7–7.7 (3 m, middle 6.2).
  - **Services:** the south wall's air line is at 2.75 m and the fire main at 3.1 m.
  - **The walk:** z 0.2–2.6, where the crowd's routes and the player's 1 m-wide, 2 m-tall capsule go.
- **Clearances:**
  - the garland, over the walk: ≥ 2.6 m;
  - the milagro, anywhere over the walk: ≥ 2.1 m;
  - the lectern and barrow: footprints within z 3.4–4.55, none in x 4.7–7.7.
- **Red:** his shade's #e63833. "Red" is the hue band 350°–15°; the lantern is the lane's only light in it (the shop's
  interior aside).
- **Pages:** released every 8–20 s, one to three at a time; they ride `draught_now()` (+x), surge with it, run out into
  the walk (z 0.5–3.0), settle, and fade.
- **Words and figures:**
  - every face meant for words is the `sign` slot, left blank;
  - pages and papel picado carry no letters;
  - no modelled human figure.
- **Effects and textures:** all ours (no downloaded sprites or VFX); paint from the underground recipes and the user's
  brush sheets, painterly.
- **Kit standard:**
  - solid closed meshes;
  - no layered faces (the 3 cm gate);
  - no shared atlas texels;
  - each piece within its budget (garland 3000, milagro_heart 2000, red_lantern 2500, lectern 2000, book_barrow 4000).
- **Review:** piece by piece. After each piece, send in-game stills from the real map (mouth view and one close view),
  never a staged backdrop, and wait for the user's word before the next piece.
- **Out of bounds:**
  - `assets/ui/talk/*/` stays out of git;
  - the finished `candle_lane.glb` and `stall.glb` kits are not rebuilt.

## Review Focus

1. **Trains and the dark train blow hard.** Pages must not fly off past the lane's end or pile up. Each page dies
   within its life and never goes past x 16.8 (Task 6, L10c).
2. **The lane set into the Metro at its offset.** The new pieces, the lantern's light and the pages stand in the
   lane's spaces (`metro_test` M11–M13 keep passing; every task runs it).
3. **The inspection keys.** F2 must grey the new pieces and give back their materials; the pages and haze are left as
   effects (Task 2, L5b).
4. **The brownout.** The lantern's light sags with the train like the lane's other lights: it is registered in the
   bay's `_full` (Task 4, L7b).
5. **Walking the threshold.** With the lectern and barrow placed, the player still walks from the lane through the arch
   to his desk (Task 5, L8b: the existing C4 walk re-run).

## File Structure

- **Create:**
  - `tools/eclipse/lane_landmarks.py`: the kit (garland, milagro_heart, red_lantern, lectern, book_barrow), in the
    lane's frame like `candle_lane.py`.
  - `scripts/Visual/DriftingPages.gd`: loose pages lifted out of the arch on the draught.
  - `tests/lane_landmarks_view_test.gd` / `.tscn`: the windowed mouth-view checks, grown from
    `tests/diag_lane_landmarks.gd`, which it replaces.
- **Modify:**
  - `tools/eclipse/lab.sh`: KITS gains `lane_landmarks`.
  - `tools/eclipse/test_kit_bpy.py`: `class LaneLandmarks`.
  - `maps/candle_lane.gd`: `_landmarks()` and its constants.
  - `maps/underground_lab.gd`: `draught_now()`.
  - `scripts/Level/Vfx.gd`: the `copal_pool` preset.
  - `tests/candle_lane_test.gd`: L5–L11.
- **Delete:** `tests/diag_lane_landmarks.gd` / `.tscn`, after Task 1 replaces them.

---

### Task 1: The mouth-view test (all red)

**Files:**
- Create: `tests/lane_landmarks_view_test.gd`, `tests/lane_landmarks_view_test.tscn`
- Delete: `tests/diag_lane_landmarks.gd`, `tests/diag_lane_landmarks.tscn`

**Interfaces:**
- **Consumes:**
  - `maps/metro.tscn` (`map.player`, `map.spawn_point()`, `map.get_node("candle_lane")`);
  - the lane's `PLAN_ORIGIN`.
- **Produces:** views saved to `docs/superpowers/refs/underground/landmarks/` (not committed), and the checks LV1–LV6,
  which later tasks turn green.
  - Each check projects lane-frame points with `eye.unproject_position(lane.to_global(p))`, so it holds wherever the
    eye is.
  - Run: `$GODOT --path . --fixed-fps 60 --resolution 1920x1080 res://tests/lane_landmarks_view_test.tscn`. It prints
    `PASS|FAIL  LVn ...` and exits 1 on any FAIL.

- [ ] **Step 1: Write the test.**
  - **Views:** the three views of `diag_lane_landmarks.gd`, the mouth view first, plus a close view of her stall (eye
    at lane (−4, 1.65, 1.4) looking at (0, 2.2, −1)) and of his arch (eye at (2, 1.65, 1.2) looking at (6.2, 2.0, 4.5)).
  - **Waits:** in game frames, as `vfx_test.gd`'s `_seconds()` does. The mouth view is shot twice, 0.5 s apart.
  - **The checks** (all on the mouth view):
    - **LV1 her garland crosses the corridor.** In the image column band projected from lane x 0.5–3.0, at heights
      projected from y 2.6–3.6, a run of marigold-hued pixels (hue 20°–45°, s > 0.5, v > 0.35) spans from the
      projected north wall line to the south wall line.
    - **LV2 a red pool at his arch.** In the region projected round lane (6.2, 0.0–3.2, 4.55) ±1.5 m, ≥ 4 % of pixels
      have hue in 350°–15°, s > 0.45, v > 0.3. The chapel end's region (lane x ≥ 14) has < 1 % in that band.
    - **LV3 something moves out of his arch.** Between the two mouth shots, ≥ 0.5 % of pixels in the floor region
      projected from lane x 6–16, z 0.5–3.0 change (summed rgb > 0.15).
    - **LV4 the sign leads no more.** The mean luminance of the station sign's projected face is below the mean
      luminance of her stall's projected region (lane x −1.5–1.5, y 0.5–2.8, z −2.35–0).
    - **LV5 the niche is quieter than her stall.** The niche's projected region (its node's AABB) has a lower mean
      luminance than her stall's region.
    - **LV6 a warm cloud over her pitch.** The region projected from lane x −1.5–1.5, y 3.0–3.9, z −2.0–0.5 has a mean
      hue in 20°–50° and a luminance ≥ 1.5 × the same box at x −6 (bare vault).

- [ ] **Step 2: Run it and watch it fail.**
  - Run: the command above.
  - Expected: LV1, LV2, LV3, LV4, LV5 and LV6 all FAIL. If any passes now, its threshold is wrong; tighten it until
    it fails on today's lane before going on.

- [ ] **Step 3: Delete the diag scene and commit.**
```bash
git rm tests/diag_lane_landmarks.gd tests/diag_lane_landmarks.tscn
git add tests/lane_landmarks_view_test.gd tests/lane_landmarks_view_test.tscn
git commit -m "test(metro): the candle lane's landmarks as seen from the Pasaje"
```

---

### Task 2: The kit, its gate, and the garland

**Files:**
- Create: `tools/eclipse/lane_landmarks.py`
- Modify: `tools/eclipse/lab.sh` (KITS), `tools/eclipse/test_kit_bpy.py` (`class LaneLandmarks`), `maps/candle_lane.gd`,
  `tests/candle_lane_test.gd`

**Interfaces:**
- **Produces:**
  - `lane_landmarks.py`, with:
    - `NAME = "lane_landmarks"`;
    - `ATLAS = 2048`;
    - `SLOTS` drawn from the underground recipes (marigold, picado, picado_b, iron, tin, brass, wood, paper,
      page_edge, leather_brown, leather_red, cloth, sign, plus an atlas-free `glass_red`);
    - `BUDGET` and `SLIVER` dicts keyed by piece;
    - `build()` and `main()` as in `candle_lane.py`.
  - Pieces are built in the lane's frame (Blender x along the lane, y = the lane's −z, z up) and set at the lane's
    origin, as `candle_lane.py`'s frames are.
  - In `candle_lane.gd`:
    - `const LANDMARKS_KIT := "res://assets/eclipse/kit/lane_landmarks.glb"`;
    - `var landmarks := {}` (piece name → MeshInstance3D);
    - `func _landmarks() -> void`, called in `_ready()` after `_lane_pieces()`; it places each piece with `_place(mesh,
      look, name, Vector3.ZERO, 0.0, solid)` and the kit's own painted look (`_painted(["lane_landmarks.png",
      "lane_landmarks_base.png"])`).

- [ ] **Step 1: Write the failing gate test.** In `test_kit_bpy.py`, `class LaneLandmarks(unittest.TestCase)`, shaped
  like `class CandleLane`.
  - `test_pieces_closed_in_budget_through_the_gate`: sorted objects equal sorted BUDGET keys; every object closed;
    `gate.check(...)[:3] == []` with each piece's budget and sliver.
  - `test_the_garland_clears_the_walk`: every garland vertex whose lane z (−Blender y) lies in 0.2–2.6 has z ≥ 2.6.
  - `test_the_garland_spans_the_lane`: its extent in Blender y covers −4.4 to 0.2 (from the south wall's bracket to her
    awning's front).
  - `BUDGET` holds only `garland` for now; later tasks add their pieces.
- [ ] **Step 2: Run it and watch it fail.**
  - Run: `$BLENDER -b --factory-startup --python-exit-code 1 --python tools/eclipse/test_kit_bpy.py -- LaneLandmarks`
  - Expected: FAIL (no module lane_landmarks).
- [ ] **Step 3: Write `lane_landmarks.py` with `garland(m)`.**
  - **The rope:** ropes of cempasúchil heads (closed lumpy spheres in the `marigold` slot, on a twisted cord).
  - **Its run:** strung from her awning's front corner at about (x 1.2, z 0.0, 2.3) across to an iron hook-plate on the
    south wall at about (x 1.8, z 4.5, 3.4). It sags along a catenary whose lowest point over z 0.2–2.6 is ≥ 2.6.
  - **Flags:** 6–9 papel picado flags hung under it (`picado`/`picado_b`), their cut patterns abstract, no letters.
  - **Tie:** any riser or tie it needs at her end is part of this piece.
  - **lab.sh:** add `lane_landmarks` to KITS.
- [ ] **Step 4: Run the gate test and see it pass.** Run: as Step 2. Expected: OK.
- [ ] **Step 5: Build, paint and import.**
```bash
bash tools/eclipse/lab.sh lane_landmarks
python3 tools/textures/layered_atlas.py lane_landmarks --recipes=underground
perl -e 'alarm 300; exec @ARGV' $GODOT --headless --path . --import
```
  - Expected: `assets/eclipse/kit/lane_landmarks.glb` and `textures/painted/underground/lane_landmarks.png` exist; the
    import prints no ERROR.
- [ ] **Step 6: Write the failing lane checks** in `candle_lane_test.gd`, in a new `_landmarks()` run after
  `_crowd_of_shades()`.
  - **L5 "her garland hangs across the walk, clear of every head":**
    - `lane.landmarks.has("garland")`;
    - every garland vertex, transformed into the lane's frame, with z in 0.2–2.6 has y ≥ 2.6.
  - **L5b "F2 greys the landmarks and gives back their materials":**
    - `lane.set_form(true)` sets every landmarks mesh's `material_override` to the form material;
    - `lane.set_form(false)` restores the materials as they were (compare by surface).
- [ ] **Step 7: Run the lane suite and watch L5 and L5b fail.**
  - Run: `perl -e 'alarm 590; exec @ARGV' $GODOT --headless --fixed-fps 60 --path . res://tests/candle_lane_test.tscn`
  - Expected: L5 and L5b FAIL; the rest PASS.
- [ ] **Step 8: Implement `_landmarks()` in `candle_lane.gd`** placing the garland (not solid). Then add a gentle sway on
  the draught: a slow rotation about its span's axis, at most 3°, its amplitude from `draught_now()` once Task 6 adds
  it (until then from `DRAUGHT`).
- [ ] **Step 9: Run the lane suite, Metro suite and view test.**
  - lane: all PASS (31 checks);
  - `metro_test`: 13/13;
  - view test: LV1 PASS, the rest still FAIL.
- [ ] **Step 10: Commit, send stills and wait.**
```bash
git add tools/eclipse/lane_landmarks.py tools/eclipse/lab.sh tools/eclipse/test_kit_bpy.py maps/candle_lane.gd tests/candle_lane_test.gd assets/eclipse/kit/lane_landmarks.glb* assets/eclipse/source/lane_landmarks* textures/painted/underground/lane_landmarks*
git commit -m "feat(metro): her marigold garland across the lane"
```
  - Send the user the mouth view and her close view from the view test's saved files.
  - Wait for their word before Task 3. Changes they ask for are made, re-checked and recommitted within this task.

---

### Task 3: The tin sacred heart

**Files:** Modify `tools/eclipse/lane_landmarks.py`, `tools/eclipse/test_kit_bpy.py`, `maps/candle_lane.gd`,
`tests/candle_lane_test.gd`

**Interfaces:**
- **Produces:** kit piece `milagro_heart`: a pressed-tin sacred heart with flames at its top, about 0.5 m tall, its
  iron bracket from her frame's front post.
  - It is built with its hook at the origin of its own object, so the lane can turn it.
  - In `candle_lane.gd`, `landmarks["milagro_heart"]` sits under a `Node3D` pivot at the hook, named `milagro_pivot`.

- [ ] **Step 1: Write the failing gate test.** `test_the_heart_hangs_from_its_hook`: the object's highest vertex is
  within 0.05 m of its origin; its height is 0.45–0.6 m. Add `milagro_heart: 2000` to BUDGET.
- [ ] **Step 2: Run it and watch it fail.** Run: the gate command. Expected: FAIL (no object milagro_heart).
- [ ] **Step 3: Model `milagro_heart(m)`.**
  - **The heart:** tin body with embossed rays and flames and a nailed border (`tin`, `brass`).
  - **The bracket:** a scrolled iron arm (`iron`), a separate object only if the gate needs it.
- [ ] **Step 4: Run the gate test and see it pass.** Then build, paint and import as in Task 2 Step 5.
- [ ] **Step 5: Write the failing lane checks.**
  - **L6 "the tin heart hangs over her pitch, above every head over the walk and clear of her customers":**
    - the heart's lowest point, wherever its AABB lies over z ≥ 0.2, is ≥ 2.1;
    - its xz footprint is ≥ 0.4 m from (0.65, 0.6) and (1.85, 0.6).
  - **L6b "it turns on its hook":** `milagro_pivot.rotation.y` changes by more than 0.05 rad over 120 frames.
- [ ] **Step 6: Run the lane suite and watch L6 and L6b fail.**
- [ ] **Step 7: Place it.**
  - The pivot hangs from the bracket's end at about (x 1.3, y 2.75, z 0.35).
  - The heart turns slowly: its yaw follows a sum of two slow sines, at most ±25°, pushed by `draught_now()`'s length.
- [ ] **Step 8: Run the lane suite (all PASS), the Metro suite (13/13) and the view test** (LV1 still PASS).
- [ ] **Step 9: Commit, send stills and wait.**
  - Commit message: `feat(metro): the tin sacred heart hung from her stall`.
  - Stills: mouth and close. Wait for the user's word.

---

### Task 4: The red lantern and its light

**Files:** Modify `tools/eclipse/lane_landmarks.py`, `tools/eclipse/test_kit_bpy.py`, `maps/candle_lane.gd`,
`tests/candle_lane_test.gd`

**Interfaces:**
- **Produces:** kit piece `red_lantern`: an iron bracket from the south wall over the arch's middle, about 3.0 m up,
  routed round the air line (2.75 m) and the fire main (3.1 m), with a lantern of red glass (`glass_red`) hanging clear
  of the arch's head.
  - In `candle_lane.gd`:
    - `const LANTERN_RED := Color("e63833")`;
    - `var lantern_light: OmniLight3D`, at the lantern's middle, with energy about 1.2 and range about 6 m, registered
      in the bay's `_full` so it sags with the brownout;
    - the `glass_red` surface gets an emissive red glass material, the bay's `_glass()` tinted.

- [ ] **Step 1: Write the failing gate test.** `test_the_lantern_bracket_misses_the_pipes`: no lantern vertex lies
  within 0.06 m of the air line's or the fire main's axis (lane z 4.55 − their offsets in `underground_lab.gd`'s
  services, heights 2.75 and 3.1) over x 4.7–7.7. Add `red_lantern: 2500` to BUDGET.
- [ ] **Step 2: Run it and watch it fail.**
- [ ] **Step 3: Model `red_lantern(m)`.** A four-sided iron frame with a peaked cap and a ring; red glass panes as
  closed thin boxes (`glass_red`); the bracket's scroll.
- [ ] **Step 4: Run the gate test and see it pass.** Then build, paint and import.
- [ ] **Step 5: Write the failing lane checks.**
  - **L7 "his red lantern hangs over the arch, the lane's only red light":**
    - `landmarks.has("red_lantern")`;
    - `lantern_light.light_color`'s hue is in 350°–15°;
    - among the lane's `Light3D` nodes not under `lane.shop`, exactly one has hue in that band with saturation > 0.45.
  - **L7b "it sags with the train":** emit `lane.train.peaked`; within 30 frames `lantern_light.light_energy` is below
    its full energy.
- [ ] **Step 6: Run the lane suite and watch L7 and L7b fail.**
- [ ] **Step 7: Place the lantern** (not solid) and its light.
- [ ] **Step 8: Run the lane suite (all PASS), the Metro suite (13/13) and the view test** (LV1, LV2 PASS).
- [ ] **Step 9: Commit, send stills and wait.**
  - Commit message: `feat(metro): his red lantern over the arch`.
  - Stills: mouth and his close view. Wait for the user's word.

---

### Task 5: The threshold: lectern, chained book, book barrow

**Files:** Modify `tools/eclipse/lane_landmarks.py`, `tools/eclipse/test_kit_bpy.py`, `maps/candle_lane.gd`,
`tests/candle_lane_test.gd`

**Interfaces:**
- **Consumes:** `scripts/Visual/ChainedBook.gd`. Its cover strains against its chain; read its API before placing a
  copy, and give the copy its own instance, not the desk's.
- **Produces:**
  - kit piece `lectern`: a wooden reading stand, its book rest slanted, with a staple for the chain;
  - kit piece `book_barrow`: a low wooden handcart heaped with books (`leather_brown`, `leather_red`, `page_edge`),
    their spines blank `sign`;
  - in `candle_lane.gd`, `var threshold_book: Node3D`, a ChainedBook placed on the lectern's rest.
  - Both pieces are solid (`_place(..., true)`), with footprints within z 3.4–4.55 and none in x 4.7–7.7.

- [ ] **Step 1: Write the failing gate test.** Each piece is closed and in budget (`lectern: 2000`, `book_barrow:
  4000`), and each one's Blender-y extent lies within −4.55 to −3.4.
- [ ] **Step 2: Run it and watch it fail.**
- [ ] **Step 3: Model both pieces.**
  - **lectern:** stands at about x 3.9, beside the arch's west jamb.
  - **book_barrow:** stands at about x 8.6, beside the east jamb, its handles toward the mouth.
- [ ] **Step 4: Run the gate test and see it pass.** Then build, paint and import.
- [ ] **Step 5: Write the failing lane checks.**
  - **L8 "the threshold is dressed and the doorway clear":**
    - both pieces placed, their AABBs within z 3.4–4.55 and outside x 4.7–7.7;
    - `threshold_book` is a ChainedBook on the lectern (within 0.15 m of its rest's top);
    - no `Label3D` or `Decal` under any landmarks node (every face meant for words left blank).
  - **L8b "the player still walks through the arch to his desk":** re-run C4's walk path (lane → arch → desk) with
    `_walk_path`, and require arrival.
- [ ] **Step 6: Run the lane suite and watch L8 fail.** L8b may pass already; it must still pass after placing.
- [ ] **Step 7: Place both pieces and the book.**
- [ ] **Step 8: Run the lane suite (all PASS) and the Metro suite (13/13).** The Metro suite's M9 walk to the desk must
  still pass.
- [ ] **Step 9: Commit, send stills and wait.**
  - Commit message: `feat(metro): his threshold dressed: lectern, chained book, book barrow`.
  - Stills: his close view and the mouth. Wait for the user's word.

---

### Task 6: The draught, the drifting pages and the copal haze

**Files:**
- Create: `scripts/Visual/DriftingPages.gd`
- Modify: `maps/underground_lab.gd`, `scripts/Level/Vfx.gd`, `maps/candle_lane.gd`, `tests/candle_lane_test.gd`

**Interfaces:**
- **Produces:**
  - In `underground_lab.gd`: `func draught_now() -> Vector3`, returning `DRAUGHT * (1.0 + 4.0 * s) + DARK_DRAUGHT * d`
    (the expression now inline in `_process`, which then calls it). `s` and `d` are the train's and dark train's
    strengths, as `_process` reads them.
  - `DriftingPages.gd` (`class_name DriftingPages`, `extends Node3D`), in its parent's frame, with:
    - `@export var from := Vector3.ZERO` (where they lift: the arch's foot);
    - `@export var every := Vector2(8.0, 20.0)`;
    - `@export var end_x := 16.8`;
    - `var wind: Callable` (returns the current draught, `Vector3`);
    - `var pages: Array[MeshInstance3D]` (alive);
    - `var released := 0`;
    - `func release_now() -> int` (lifts 1–3 pages now; returns how many).
  - **Each page:** a thin blank card (`paper`/abstract strokes, no letters), about 0.2 × 0.28 m.
    - **Its path:** it lifts to 0.4–1.0 m, tumbles out into the walk (z 0.5–3.0), then skates along the floor with
      the wind, slowing.
    - **Its end:** it settles flat and fades over its last second.
    - **Its life:** 4–7 s, and it is freed when it dies or when its x passes `end_x`.
  - In `Vfx.gd`: a preset `copal_pool`, made of the existing `"pool"` draw and an amber warm tint (her copal), sized
    about 3 × 0.9 × 2.4 m.
  - In `candle_lane.gd`:
    - `var pages: DriftingPages` (from the arch's foot (6.2, 0.1, 4.2), `wind = draught_now`);
    - `var copal_haze: Node3D` (the preset, centred at (0, 3.45, −0.8), under the vault over her pitch).

- [ ] **Step 1: Write the failing lane checks.**
  - **L9 "a copal haze pools under the vault over her pitch":** `copal_haze` exists; its centre is within x ±1.5,
    y 3.0–3.9, z −2.0–0.5; it contains a FogVolume or pool node.
  - **L10 "pages lift out of his arch and drift with the draught":**
    - `pages.release_now()` returns 1–3;
    - after 180 frames each released page has x ≥ start x + 1.5;
    - each page's z is within 0.5–3.0;
    - y is ≤ 0.1 by the end of its life.
  - **L10b "they come of their own accord":** over 1500 frames (25 s), `pages.released` grows by ≥ 1.
  - **L10c "a gust carries them farther and never past the lane's end":**
    - with `lane.dark_train` at full strength, a released page travels farther in 180 frames than one in still air;
    - after 600 frames under full strength, no page has x > 16.8, and `pages.pages.size() <= 6`.
  - **L11 "draught_now is the lane's one draught":** it equals `DRAUGHT` with no train, and has a larger x after
    `lane.train.peaked` is emitted.
- [ ] **Step 2: Run the lane suite and watch L9–L11 fail.**
- [ ] **Step 3: Add `draught_now()`** and have `_process` use it. Run the full lane and Underground suites: nothing
  else changes (`bash tools/run_suites.sh tests/underground_lab_test.tscn tests/candle_lane_test.tscn`; all
  previously passing checks pass).
- [ ] **Step 4: Write `DriftingPages.gd`, add the `copal_pool` preset, and place both in `candle_lane.gd`.**
- [ ] **Step 5: Run the lane suite (all PASS), the Metro suite (13/13), the ambient suite (39/39), and the view test**
  (LV1, LV2, LV3, LV6 PASS).
- [ ] **Step 6: Commit, send stills and wait.**
  - Commit message: `feat(metro): pages drift out of his arch on the draught; her copal pools under the vault`.
  - Stills: the mouth, twice 0.5 s apart; her close view. Wait for the user's word.

---

### Task 7: The sign and the niche, quieter

**Files:** Modify `maps/candle_lane.gd`, `tests/candle_lane_test.gd`

**Interfaces:**
- **Consumes:**
  - `mouth_sign` (the enamel sign);
  - the pockets' `pasaje_neon` light (`MOUTH_NEON`);
  - the bay's `niche_flames` (its Vfx candles and their light).
- **Produces:**
  - `const NICHE_DIM := 0.55` (the niche's candle light at 55 % of the bay's);
  - the sign's face no longer the mouth's brightest thing. Either keep the Pasaje neon's light off the sign's face, or
    lower the sign face's response. The mouth's teal pocket (C17) must survive.

- [ ] **Step 1: Write the failing lane check.** **L12 "the niche's candles burn lower here than in the bay":** the
  niche's light energy ≤ 0.6 × its full energy in the bay. C17, the pockets' lights, keeps passing.
- [ ] **Step 2: Run the lane suite and watch L12 fail.**
- [ ] **Step 3: Implement the dimming of both,** registering the lowered niche energy in `_full` so the brownout scales
  from it.
- [ ] **Step 4: Run the lane suite (all PASS, C17 included), the Metro suite (13/13), and the view test.** All of
  LV1–LV6 PASS.
- [ ] **Step 5: Commit, send stills and wait.**
  - Commit message: `feat(metro): the blank sign and the niche quieter than the landmarks`.
  - Stills: all five views. Wait for the user's word.

---

### Task 8: The whole lane, checked

- [ ] **Step 1: Run every suite the lane touches:**
```bash
bash tools/run_suites.sh tests/candle_lane_test.tscn tests/metro_test.tscn tests/underground_lab_test.tscn tests/ambient_test.tscn tests/talk_quest_test.tscn tests/layers_test.tscn
$BLENDER -b --factory-startup --python-exit-code 1 --python tools/eclipse/test_kit_bpy.py -- LaneLandmarks CandleLane
$GODOT --path . --fixed-fps 60 --resolution 1920x1080 res://tests/lane_landmarks_view_test.tscn
```
  - Expected: all PASS.
  - The talk quest suite checks the shades still stand clear at the stall, the shop and the ledges.
- [ ] **Step 2:** Update `CREDITS.md` only if a new outside asset was used (none is planned).
- [ ] **Step 3:** Commit any test-only touch-ups:
  `git commit -m "test(metro): the landmarks' whole-lane run"`.
