# The Pasaje Market (Middle Stretch) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The Pasaje's middle stretch (plan z 55–95) is a set of its own, set into the Metro. It is built to the
candle lane's density as a night market under a vault, with stalls by trade, each under its own neon, signs and cables
overhead, steam, posters, and the shade crowd. A canopy at its south end closes the view.

**Architecture:**
- **The plan:** splits the one Pasaje space into three, so the Metro's greybox keeps the north and south stretches.
- **The set:** a new `maps/pasaje.tscn` (`maps/pasaje.gd`), built the way the candle lane is: standalone, or set into
  `maps/metro` with `standalone = false` at its `PLAN_ORIGIN`. Its pieces come from four small Blender kits
  (shell, stalls, wares, overhead) through a static helper extracted from the bay's (`scripts/Level/SetKit.gd`).
- **Life:** reuses the lane's systems: ShadeCrowd, Silhouette, Vfx and Fumes, NeonSign, and the corridor's
  `draught_now()`.

**Tech Stack:** Godot 4.5.1 (GDScript), Blender 4 (bpy kit scripts), Python 3 (plan tools, atlas painter).

**Spec:** `docs/superpowers/specs/2026-10-26-pasaje-market-design.md`

## Global Constraints

- **The set's frame:** the plan's axes moved to `PLAN_ORIGIN = Vector3(-9, -11, 75)`, with no rotation.
  - x runs across the street: west wall at x −5 (plan −14), east wall at x +5 (plan −4).
  - z runs along the street: the stretch is z −20…+20 (plan 55…95). Height 4.5; floor y 0.
  - **Side openings (set frame):** the herb market on the west wall, z −3…+1 (plan 72–76); the candle lane on the
    east wall, z −3…+3.9 (plan 72–78.9).
  - **The stretch's ends:** z −20 (meeting `pasaje_n`) and z +20 (meeting `pasaje_s`) are open their full width onto
    the greybox.
- **The walk:**
  - a clear street at least 4 m wide end to end;
  - stall footprints within 2 m of their wall (|x| ≥ 3.0);
  - no stall footprint within 0.5 m of a side opening's z range;
  - the player's capsule is 1 m wide and 2 m tall;
  - anything over the walk hangs no lower than 2.4 m.
- **Words:**
  - every face meant for words is the `sign` slot, left blank;
  - posters are painted images, never letters;
  - graffiti are painted marks, never letterforms.
- **Figures:** no modelled human figure. Stallkeepers and passers-by are black shades (Silhouette).
- **Assets:** all VFX and textures our own; paint from the underground recipes and the user's brush sheets,
  painterly; grid off.
- **Kit standard:** solid closed meshes; the 3 cm layered-face gate; no shared atlas texels; budgets per piece; each
  kit's atlas at most 2048.
- **Neon colours:**
  - distinct from each other, neighbours at least 25° apart in hue;
  - none within 15° of the lane's magenta (~328°) or of his red (~2°);
  - none within 15° of the mouth's teal (~186°), except the one stall beside the lane's mouth, which is that teal
    (its spill is the lane's `MOUTH_NEON`).
- **The canopy and sign gantry** across the street at the stretch's south end (z ≈ +13…+20), its lowest point at
  2.4 m or higher.
- **The lane's crowd, in the Metro:** the candle lane keeps only its `into_lane` and `out_of_lane` routes; the
  Pasaje set owns the Pasaje's crowd.
- **Performance:** the Metro with the set, measured windowed, takes no more than 1.25× the candle lane's frame time
  from the lane's own views.
- **Review:** each family goes to the user as in-game stills from the real map (`maps/metro`), never a staged
  backdrop. The next family waits for their word. Stallkeeper poses are reviewed before they are placed.
- **Do not touch:** `assets/ui/talk/*/` stays out of git; the candle lane's approved look is not changed (its suite
  keeps passing).

## Review Focus

1. **The set at the Metro's offset.** Everything it lights, sounds and shows stands in its own space; nothing stands
   in the map's other spaces; no face lies flush with a greybox wall's. Task 2 (M14, M15) and Task 9 (M17).
2. **Shades doubled where the lane and the Pasaje meet.** In the Metro no lane route runs in the Pasaje and the
   Pasaje's routes don't enter the lane. Task 8 (M16).
3. **The player caught at a side opening or a stall's corner.** Walked from the north greybox into the herb market's
   mouth and into the lane, and down the whole street. Task 2 (P2) and Task 4 (P4b re-runs it).
4. **Too many lights for the frame.** No more than 24 shadowless omni lights in the set and no more than 2 with
   shadows. Task 5 (P5c); performance in Task 9.
5. **The view ending in grey.** From the stretch's north end looking south, the frame's middle shows no greybox.
   Task 9 (PV3).

## File Structure

- **Create:**
  - `scripts/Level/SetKit.gd`: static `kit()`, `place()`, `painted()`, copied from the bay's `_kit`, `_place` and
    `_painted` so sets share them.
  - `maps/pasaje.gd`, `maps/pasaje.tscn`: the set.
  - `tools/eclipse/pasaje_shell.py`: the shell's dressing (tile walls, ceiling, floor, services, the openings'
    reveals).
  - `tools/eclipse/pasaje_stalls.py`: stall frames, counters, awnings, neon boxes.
  - `tools/eclipse/pasaje_wares.py`: each trade's goods.
  - `tools/eclipse/pasaje_overhead.py`: hanging signs, cable bundles, bulb strings, the canopy and gantry, posters.
  - `tools/textures/pasaje_graffiti.py`: painted-mark decals from the user's brush sheets.
  - `tests/pasaje_test.gd` / `.tscn`: the set's suite (P-checks).
  - `tests/pasaje_view_test.gd` / `.tscn`: the windowed views (PV-checks).
- **Modify:**
  - `tools/level/layouts/metro/market.py`: the three spaces.
  - `tools/level/layouts/metro/places.py`: `PUESTOS` for the middle.
  - `tools/level/test_metro_plan.py`.
  - `maps/metro.gd`: `SETS`, the draught wiring.
  - `maps/candle_lane.gd`: its Pasaje routes only when standalone.
  - `tools/textures/silhouettes.py`: stallkeeper poses.
  - `tools/eclipse/lab.sh`: KITS.
  - `tools/eclipse/test_kit_bpy.py`: the gate classes.
  - `tests/metro_test.gd`: M14–M17, with its set checks generalized to every set.
  - `tests/library_render_check.gd`: `-- --pasaje`.

---

### Task 1: The Pasaje split in three in the plan

**Files:** Modify `tools/level/layouts/metro/market.py`, `tools/level/layouts/metro/places.py`,
`tools/level/test_metro_plan.py`; regenerate `assets/eclipse/metro/` (plan, sheets, greybox).

**Interfaces:**
- **Produces:**
  - plan spaces `pasaje_n` (x −14…−4, z 34…55), `pasaje` (z 55…95) and `pasaje_s` (z 95…150);
  - all at floor −11, height 4.5, layer 2;
  - the three joined by openings 10 m wide at z 55 and z 95.
- **Unchanged:** the candle lane's opening to `pasaje` (at (−4, 75.45), width 6.9, height 4.0).

- [ ] **Step 1: Write the failing tests** in `test_metro_plan.py`.
  - **`test_the_pasaje_is_three_stretches`:**
    - the three spaces' bounds as above;
    - `pasaje_n` opens to `pasaje` at (−9, 55) and `pasaje` to `pasaje_s` at (−9, 95), both width 10.0, both ways;
    - `market_stairs` and `cistern_lane` open onto `pasaje_n`;
    - `herb_market` and `candle_lane` open onto `pasaje`;
    - `tianguis_lane`, `rag_lane` and `square_s` open onto `pasaje_s`.
  - **`test_the_middle_puestos_are_the_markets`:** no `PUESTOS` entry with x in −14…−4 and z in 55…95 sells
    "records", "gloves" or "charms". The entries there name trades from the design (candles, copal, milagros,
    saints, herbs, chiles, flowers, tamales, tortas, atole, coffee, fruit, sweets, lottery, tinsmith, radio).
- [ ] **Step 2: Run them and watch them fail.** Run `cd tools/level && python3 -m unittest test_metro_plan`.
  Expected: the two new tests FAIL.
- [ ] **Step 3: Split the space** in `market.py`, moving each opening to its stretch. Rewrite `PUESTOS`' middle
  entries in `places.py` to the design's trades (candles, copal and milagros by the lane's mouth on the east; herbs
  and chiles by the herb market's on the west; food between).
- [ ] **Step 4: Run all the plan tests** (19 + 2 OK), then regenerate with `bash tools/level/level.sh metro`
  (0 problems).
- [ ] **Step 5: Run the Metro suite.**
  `perl -e 'alarm 590; exec @ARGV' $GODOT --headless --fixed-fps 60 --path . res://tests/metro_test.tscn`
  - Expected: 13/13. M7 and M8 read the greybox `pasaje` by prefix; M13's gap to the lane is still on `pasaje`.
  - If M7 or M13 break on the split, fix the test's name match, not the plan, and record it as a ruling.
- [ ] **Step 6: Commit.** `git commit -m "plan(metro): the Pasaje in three stretches; the middle's stalls by trade"`

---

### Task 2: The set, walkable, in the Metro

**Files:**
- Create: `scripts/Level/SetKit.gd`, `maps/pasaje.gd`, `maps/pasaje.tscn`, `tests/pasaje_test.gd`,
  `tests/pasaje_test.tscn`
- Modify: `maps/metro.gd`, `tests/metro_test.gd`

**Interfaces:**
- **Produces (`SetKit.gd`, `class_name SetKit`, all static):**
  - `kit(path: String) -> Dictionary` (mesh name → Mesh);
  - `place(parent: Node3D, mesh: Mesh, material: Material, kind: String, at: Vector3, yaw: float, solid: bool) ->
    MeshInstance3D` (glass slots get clear glass, as the bay's do);
  - `painted(names: Array, atlas_dir := "res://textures/painted/underground/") -> Texture2D`.
- **Produces (`pasaje.gd`, `extends Node3D`):**
  - `const PLAN_ORIGIN := Vector3(-9, -11, 75)`, `HALF_W := 5.0`, `HALF_L := 20.0`, `HEIGHT := 4.5`;
  - `const OPENINGS := {"herb_market": [-1, -3.0, 1.0], "candle_lane": [1, -3.0, 3.9]}` (wall side, z from, z to);
  - `@export var standalone := true`, `var host_player: Node3D`, `var player: CharacterBody3D`;
  - `var draught: Callable` (returns Vector3; standalone, the constant `Vector3(0.35, 0, 0)`). The lane's draught
    blows across the Pasaje, so the Pasaje's swinging pieces take only its strength, `draught.call().length()`, never
    its direction.
  - `var shell: Array[Node3D]` (the structural boxes).
  - **Standalone:** its own WorldEnvironment like the bay's `_environment()`, and the player at (0, 1.05, −18).
  - **Embedded:** neither; it uses `host_player`.
- **Metro:**
  - `SETS` gains `"pasaje": ["res://maps/pasaje.tscn", ["pasaje"]]`;
  - after both sets are added, `pasaje.draught = candle_lane.draught_now`.

- [ ] **Step 1: Write the failing tests.**
  - `tests/pasaje_test.gd` (headless, the lane suite's shape):
    - **P1 "the stretch's shell at the plan's measure":** floor at y 0 over x −5…5, z −20…20; walls at x ±5 with
      the two openings open (a ray at 1.5 m through each opening's middle passes, one 0.5 m outside its z range
      meets wall); the ceiling at 4.5.
    - **P2 "the player walks the street end to end, into the herb market's mouth and the lane's":** `_walk_path` as
      in the lane suite, from (0, 1.05, −19) to (0, 1.05, 19); from (0, 1.05, −1) west to (−5.5, 1.05, −1); and
      east to (5.5, 1.05, 0.5).
  - `tests/metro_test.gd`:
    - **M14 "the Pasaje stands in its place, the greybox gone from `pasaje` only":** the set is at `PLAN_ORIGIN`;
      the greybox has `pasaje_n` and `pasaje_s` but no `pasaje`.
    - **M15:** generalize M11–M13 to loop over every entry of `metro.SETS` (each set's own spaces, its taken
      greybox meshes excluded from the faces), so the Pasaje's seams are held to the lane's standard: no flush
      faces, nothing deeper than 6 cm in another space, openings their own size.
    - **M9b "walked from the market stairs down the Pasaje into the lane":** a `_tour` from (−10, −11, 36) to
      (−9, −11, 75.45) to (−2.2, −11, 75.45).
- [ ] **Step 2: Run them and watch them fail.**
  - Run `pasaje_test`. Expected: it fails to load (no scene).
  - Run `metro_test`. Expected: M14 FAIL; M9b FAIL (the Pasaje's middle is gone and nothing stands there yet); M15
    as before.
- [ ] **Step 3: Write `SetKit.gd`, then `pasaje.gd`.**
  - `pasaje.gd` builds its structural shell from boxes: floor slab; walls cut round the openings; ceiling.
  - The walls are set back by their tile depth as the bay's are, and end SEAM (1 cm) short of the greybox's planes
    at z ±20, as the lane's do.
- [ ] **Step 4: Register the set in `metro.gd` and run both suites.**
  - Run `bash tools/run_suites.sh tests/pasaje_test.tscn tests/metro_test.tscn tests/candle_lane_test.tscn`.
  - Expected: P1, P2; metro all; lane 52/52.
- [ ] **Step 5: Commit.** `git commit -m "feat(metro): the Pasaje set, walkable, in its place"`

---

### Task 3: The shell dressed

**Files:**
- Create: `tools/eclipse/pasaje_shell.py`
- Modify: `tools/eclipse/lab.sh`, `tools/eclipse/test_kit_bpy.py`, `maps/pasaje.gd`, `tests/pasaje_test.gd`

**Interfaces:**
- **Produces:** kit `pasaje_shell`, with:
  - tile wall runs (the line's blue band) for 4.5 m walls, in 1.2 m modules;
  - a ceiling for the 10 m span (ribbed or vaulted: builder's call, matched to the lane's vault in material);
  - the floor's tiles;
  - the services runs on both walls;
  - reveals for the two openings.
- Placed by `pasaje._shell_dressing()`. Its dressing is not solid; the boxes stay the collision.

- [ ] **Step 1: Write the failing tests.**
  - Gate class `PasajeShell`: closed, in budget, through the gate.
  - P3 "the walls are tiled to the openings and the stretch's ends, no strip left bare": every 1.2 m module of each
    wall's length has a tile panel, except across the openings.
  - The Metro's M15 holds for the dressing too.
- [ ] **Step 2: Run them and watch them fail.** Gate: no module. P3: FAIL.
- [ ] **Step 3: Model the kit,** then build, paint and import it as the lane's kits are built:
  - `bash tools/eclipse/lab.sh pasaje_shell`;
  - `python3 tools/textures/layered_atlas.py pasaje_shell --recipes=underground`;
  - `--import`.
- [ ] **Step 4: Place the dressing** and run the gate and `bash tools/run_suites.sh tests/pasaje_test.tscn
  tests/metro_test.tscn`. Expected: all PASS.
- [ ] **Step 5: Commit, send stills, wait.**
  - Commit message: `feat(metro): the Pasaje's shell dressed in the Company's tile`.
  - Stills from the real Metro: the lane's mouth looking out; the stretch's north end looking south.
  - Wait for the user's word.

---

### Task 4: The stalls

**Files:**
- Create: `tools/eclipse/pasaje_stalls.py`
- Modify: lab.sh, test_kit_bpy.py, `maps/pasaje.gd`, `tests/pasaje_test.gd`

**Interfaces:**
- **Produces:**
  - kit `pasaje_stalls`: frame families `puesto_pipe`, `booth_wood`, `cart`, `lean_to`, each in 2–3 widths;
    counters; awnings (canvas, tin, tarp); `neon_box` (a sign carrying a NeonSign tube, its face `sign`).
  - In `pasaje.gd`: `const STALLS := [...]`, entries `[name, trade, side (-1 | 1), z, width, frame, neon_colour]`,
    12–16 of them; `var stalls := {}` (name → Node3D root).
  - The stall beside the lane's mouth (east, at z ≈ −4.5) has `neon_colour = Color(0.25, 0.85, 0.9)`, the mouth's
    teal.

- [ ] **Step 1: Write the failing tests.**
  - Gate class `PasajeStalls`.
  - **P4 "the stalls stand against their walls, clear of the walk and the openings":**
    - every stall's footprint satisfies |x| ≥ 3.0 and |x| ≤ 5.0;
    - none within 0.5 m of an opening's z range;
    - 12–16 stalls, on both walls.
  - **P4b:** P2's walks re-run with the stalls placed.
  - **P4c "each stall under its own neon":**
    - neighbours on a wall at least 25° apart in hue;
    - none within 15° of 328°, 2° or 186°, except the mouth stall, which is within 10° of 186°.
  - **P4d "every face for words blank":** no Label3D or Decal under any stall.
  - **P4e "the floor under each counter is open, room for what will live there":** a ray along the floor at 0.15 m,
    under each counter's middle, runs at least 0.4 m before it meets anything.
- [ ] **Step 2: Run them and watch them fail.**
- [ ] **Step 3: Model the kit; build, paint, import.** Lay out `STALLS` by the design's trades:
  - candles, copal, milagros and saints round the lane's mouth on the east;
  - herbs, chiles and flowers round the herb market's mouth on the west;
  - food between: tamales, tortas, atole and coffee, fruit, sweets;
  - one or two others with a cause.
  - Widths vary, with alcoves between, never even spacing.
  - **Reuse what fits:**
    - the tortas stall from its card (`docs/superpowers/refs/underground/cards/stall/b_tortas_*.png`), built in this
      kit;
    - the candle lane kit's `puesto`;
    - the bay's tamale cart (the furniture kit);
    - the curandera's hero stall's language for the frames.
  - **Room for the creatures:** every counter leaves the floor open under it (P4e).
- [ ] **Step 4: Run the gate and the suites** (pasaje, metro, lane). Expected: all PASS.
- [ ] **Step 5: Commit, send stills (mouth out; north end looking south; two close views), wait.**
  Commit message: `feat(metro): the Pasaje's stalls by trade, each under its own neon`.

---

### Task 5: The wares, steam and light

**Files:**
- Create: `tools/eclipse/pasaje_wares.py`
- Modify: lab.sh, test_kit_bpy.py, `maps/pasaje.gd`, `scripts/Level/Vfx.gd` (only if a preset is needed),
  `tests/pasaje_test.gd`

**Interfaces:**
- **Produces:**
  - kit `pasaje_wares`: each trade's goods, named `<trade>_<n>` (e.g. `herbs_1`, `candles_2`, `tamales_pot`,
    `tortas_board`, `atole_urn`, `fruit_crates`);
  - in `pasaje.gd`: `var lights: Array[Light3D]` (the set's own: neons and bulbs);
  - `var steam: Array[Node3D]` (Vfx systems over the food stalls).

- [ ] **Step 1: Write the failing tests.**
  - Gate class `PasajeWares`.
  - **P5 "every stall has its trade's wares on or under its counter":** at least two wares pieces per stall, named
    for its trade, within its footprint.
  - **P5b "the food stalls steam":** a Vfx system emitting over each of tamales, atole/coffee and tortas.
  - **P5c "the set's light stays in budget":** at most 24 shadowless OmniLights in the set; at most 2 with shadows.
- [ ] **Step 2: Run them and watch them fail.**
- [ ] **Step 3: Model the wares; build, paint, import.**
  - Place them.
  - Light each stall: its NeonSign; one bare bulb over the counter where its cause wants one.
  - Steam from `pot_steam` / `steam` (the overhauled Fumes presets).
- [ ] **Step 4: Run the gate and the suites.** Expected: all PASS.
- [ ] **Step 5: Commit, send stills (close views of three trades, and the north end), wait.**
  Commit message: `feat(metro): the Pasaje's wares, steam and light`.

---

### Task 6: Overhead, and the canopy that closes the view

**Files:**
- Create: `tools/eclipse/pasaje_overhead.py`
- Modify: lab.sh, test_kit_bpy.py, `maps/pasaje.gd`, `tests/pasaje_test.gd`

**Interfaces:**
- **Produces:**
  - kit `pasaje_overhead`: `hanging_sign` (2–3 shapes, faces `sign`), `cable_bundle` (across the street, sagging),
    `bulb_string` (sagging, its bulbs' lights counted in P5c's budget), `canopy` (tarpaulin across the street at
    z ≈ +13…+20), `gantry` (a pipe gantry of hanging signs at z ≈ +18);
  - in `pasaje.gd`: `var hanging: Array[Node3D]` (pivots), each swinging about its hook, at most 4°, as strongly as `draught.call().length()` blows.

- [ ] **Step 1: Write the failing tests.**
  - Gate class `PasajeOverhead`.
  - **P6 "nothing overhead hangs into the walk":** every overhead piece's lowest vertex over |x| ≤ 3 is at 2.4 m or
    higher.
  - **P6b "the hanging signs swing on the draught":** a pivot's rotation changes by more than 0.01 rad over
    120 frames.
  - **P6c "the canopy spans the street at the stretch's south end":** its bounds cover x −4.5…4.5 and z +13…+20.
- [ ] **Step 2: Run them and watch them fail.**
- [ ] **Step 3: Model the kit; build, paint, import; place.**
- [ ] **Step 4: Run the gate and the suites.** Expected: all PASS.
- [ ] **Step 5: Commit, send stills (north end looking south, the canopy close), wait.**
  Commit message: `feat(metro): the Pasaje's signs, cables and the canopy closing its view`.

---

### Task 7: Posters and graffiti

**Files:**
- Create: `tools/textures/pasaje_graffiti.py`
- Modify: `tools/eclipse/pasaje_overhead.py` (`poster` pieces), `maps/pasaje.gd`, `tests/pasaje_test.gd`

**Interfaces:**
- **Produces:**
  - kit pieces `poster_a`, `poster_b`, `poster_c` (paper with torn edges and paste, their image area the `sign`
    slot);
  - `textures/painted/underground/pasaje_graffiti.png`: painted marks from the user's brush sheets, no letterforms,
    on a 4 × 4 grid;
  - in `pasaje.gd`: `var marks: Array[Node3D]` (posters and graffiti Decals), denser toward z +20.

- [ ] **Step 1: Write the failing tests.**
  - **P7 "posters and graffiti thicken toward the south end":** the count of marks in z +5…+20 exceeds the count in
    z −20…−5 by at least half again.
  - **P7b "none of them on an opening or a stall's neon face":** no mark's position within 0.3 m of an opening's z
    range or a neon box's face.
  - `python3 tools/textures/test_pasaje_graffiti.py`: the sheet has 16 cells, each with paint, and none matches a
    letter's outline. The check: each cell's ink mask has more than 2 separate blobs or a filled-area ratio outside
    0.08…0.5, the band where strokes read as letters.
- [ ] **Step 2: Run them and watch them fail.**
- [ ] **Step 3: Make the sheet and the posters; place the marks.**
- [ ] **Step 4: Run the tests and the suites.** Expected: all PASS.
- [ ] **Step 5: Commit, send stills (walls close, the south end), wait.**
  Commit message: `feat(metro): the Pasaje's posters and graffiti`.

---

### Task 8: Life: the crowd and the stallkeepers

**Files:**
- Modify: `tools/textures/silhouettes.py`, `maps/pasaje.gd`, `maps/candle_lane.gd`, `tests/pasaje_test.gd`,
  `tests/metro_test.gd`, `tools/textures/test_silhouettes.py`

**Interfaces:**
- **Produces:**
  - Silhouette poses `keeper_counter`, `keeper_stir`, `keeper_fan`, `keeper_weigh`, `keeper_wrap`, made by
    `silhouettes.py` like the lane's poses;
  - in `pasaje.gd`:
    - `const ROUTES` for a ShadeCrowd: north↔south along x ±1.2, and into and out of the herb market's mouth;
    - `var crowd_of_shades: Node3D`;
    - `var keepers: Array[MeshInstance3D]`.
  - In `candle_lane.gd`: when not `standalone`, its `pasaje_north` / `pasaje_south` routes are not started.

- [ ] **Step 1: Make the five poses and send them to the user as stills; wait for their word before placing them.**
  `test_silhouettes.py` gains a check that each pose renders a filled silhouette.
- [ ] **Step 2: Write the failing tests.**
  - **P8 "the crowd walks the street and comes and goes":** shades formed on each route within 60 s; none on a
    stall's footprint.
  - **P8b "a keeper behind every stall's counter, each in a pose that fits its trade":** stirring at the food
    stalls, weighing at the herbs.
  - **M16 "no shades doubled where the lane and the Pasaje meet":** in the Metro, no lane route's points lie in the
    Pasaje except `into_lane`'s and `out_of_lane`'s ends at the mouth, and no Pasaje route enters the lane.
- [ ] **Step 3: Run them and watch them fail.**
- [ ] **Step 4: Implement the routes, the keepers, and the lane's change.** Run the suites (pasaje, metro, lane).
  Expected: all PASS.
- [ ] **Step 5: Commit, send stills (the street from the lane's mouth, two keepers close), wait.**
  Commit message: `feat(metro): the Pasaje's crowd and its stallkeepers`.

---

### Task 9: The views and the frame's cost

**Files:**
- Create: `tests/pasaje_view_test.gd`, `tests/pasaje_view_test.tscn`
- Modify: `tests/library_render_check.gd`, `tests/metro_test.gd`

**Interfaces:**
- **Consumes:** the lane's mouth-view test's shape (`tests/lane_landmarks_view_test.gd`): game-time waits,
  projection of set-frame points, run at 1152×648.

- [ ] **Step 1: Write the view checks**, run windowed with
  `$GODOT --path . --fixed-fps 60 --resolution 1152x648 res://tests/pasaje_view_test.tscn`. Views: from the
  lane's mouth looking out (west and along), and from the stretch's north end (set (0, 1.65, −19)) looking south.
  - **PV1:** at least 5 distinct neon hues visible (clusters of saturated pixels, each ≥ 0.2 % of the frame).
  - **PV2:** steam moving over the food stalls (pale pixels changing between two shots 0.5 s apart).
  - **PV3:** from the north end, the frame's middle third shows less than 2 % greybox. Greybox is the plain
    material's grey: s < 0.06, its value in the band its lamp gives, measured once on the greybox north stretch.
  - **M17:** the Metro's M11 kind of check, for the Pasaje set: everything it lights, sounds and shows stands in
    `pasaje` (its crowd excepted).
- [ ] **Step 2: Run them.** PV1–PV3 and M17 PASS. Any FAIL is a defect in Tasks 3–8 to fix with its own failing
  check first.
- [ ] **Step 3: Measure the frame.** `library_render_check.gd -- --pasaje`: three eyes in the stretch against the
  lane's three; record the ratio.
  - Expected: no more than 1.25×.
  - Over it, cut draws (MultiMesh repeated wares; merge static pieces per stall) until it is under.
- [ ] **Step 4: Commit.** `git commit -m "test(metro): the Pasaje's views and its frame's cost"`

---

### Task 10: The whole Metro, checked

- [ ] **Step 1:** Run
  `bash tools/run_suites.sh tests/pasaje_test.tscn tests/metro_test.tscn tests/candle_lane_test.tscn tests/underground_lab_test.tscn tests/ambient_test.tscn tests/talk_quest_test.tscn`;
  the kit gates `-- PasajeShell PasajeStalls PasajeWares PasajeOverhead LaneLandmarks CandleLane`; the view tests
  (`pasaje_view_test`, `lane_landmarks_view_test`); and the plan tests.
  - Expected: all PASS.
- [ ] **Step 2:** Send the user the stretch's final stills and a short walk clip from the market stairs to the lane's
  mouth (the way `tests/metro_lane_showcase.gd` makes one).
- [ ] **Step 3:** Commit any test touch-ups: `git commit -m "test(metro): the Pasaje's whole-Metro run"`.
