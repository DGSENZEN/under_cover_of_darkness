# The Station's Machinery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The Zócalo station relit in Deadlock's key (warm haze against the Company's cold blue lamps, real neon,
crackling tesla arcs on brass cable runs) around the Light Company's engine at the hall's middle, with the taquillas
and turnstile banks fed by it.

**Architecture:**
- **The light first:** the station's own light is retuned in `maps/metro_station_dressing.gd`.
- **One home for the machinery:** everything new is placed by `maps/metro_station_machinery.gd`, static and given the
  set as the dressing is, called from `StationDressing.dress` after `_light`.
- **Effects as scripts:** two reusable effects, `NeonSign` (existing, used silent) and a new `TeslaArc`.
- **Kits for the models:** neon signs, cable runs, the engine and the astral lamp, each painted through the layered
  atlas. The engine and the astral lamp are hero pieces built with the user.

**Tech Stack:** Godot 4.5.1 (GDScript, shaders), Blender 4 (bpy kit scripts), Python 3 (atlas painter).

**Spec:** `docs/superpowers/specs/2026-10-31-station-machinery-design.md` (approved Oct 31 2026). Its context:
`docs/superpowers/specs/2026-10-27-metro-station-design.md`, `docs/superpowers/plans/2026-10-30-metro-station.md`
(Tasks 1–8 done; Task 9 dropped; Tasks 10–14 follow this plan in the new register).

## Global Constraints

- Work on branch `metro-standard` in `.claude/worktrees/metro-standard`; never merge or push without the user's word.
- The set's frame (the station plan's): the hall floor y 6 (height 5, ceiling 11); the platforms' floors y 0 (height
  5.5); the hall x −30…30, z −14…14; the wall tiles' face at |z| 13.633 (14 − 0.3 − 0.067).
- The walks: 1.1 m clear, reachable from the arrival; nothing under 2.4 m over a walk (runs and arcs included); the
  MP-68's envelope (2.6 × 3.6 m over the pads at z ±5.6, x −50…50) clear (M24).
- Light key (spec, goal 1):
  - warm haze against cold electric-blue lamps, neon accents;
  - `HAZE := Color("#FFB060")` for the warm fittings and the fog;
  - `COMPANY_BLUE := Color("#5AB4FF")` for the Company's lamps and arcs;
  - the engine's leap arc `ARC_RED := Color("#FF5A3C")` (the patron's hall).
- The light budget (S6c) and the frame-cost gate are suspended (the user, Oct 31): S6c and the frame check report
  counts and pass; they never gate.
- Silent: every `NeonSign` here has `buzz = &""`; `TeslaArc` makes no sound (the no-new-sounds rule).
- Our own effects only: no downloaded VFX or textures; arcs, sparks and glows are shader-drawn or made by our tools.
- Surfaces stay ours: painted atlases (underground recipes, the user's brush sheets); kit standard as ever (closed
  solids, no layered faces within 3 cm, no shared texels, budgets, atlas 4096).
- Words: sign faces, dial faces and the Company emblem stay blank; neon symbols are stand-ins: marigold, eye, skull,
  serpent, hand, arrow.
- Anything moved or rebuilt in `_process` draws uninterpolated (`PHYSICS_INTERPOLATION_MODE_OFF`).
- Randomness seeded per node (an `@export var seed`), so suites stay frame-exact.
- Hero pieces (Task 5, Task 6) with the user: shape signed off before paint, in-game stills, the next piece waits.
- The approved looks' suites keep passing (`pasaje_test`, `candle_lane_test`).

## Review Focus

1. **Walking under the new runs:** a cable run or its arc sagging into the head height over a stair head or a
   platform walk. Task 4 (S10b samples every run).
2. **Something in the car's envelope:** a run strung along a platform drifting over the track. Task 4 re-runs M24
   with the runs in.
3. **Judder in the station:** M20 only stands in the Pasaje, the lane and the corridors, so a gear, ring or arc moved
   interpolated in the hall would pass it. Task 3 adds the hall and a platform to M20's spots.
4. **Light through a floor:** a new neon or arc light that leaves out its level's layer, lighting the platform from
   the hall. Every new light goes into `station.lights` (S6d reads it). Tasks 1–6.
5. **Suites flaking on random arcs:** an unseeded arc shape shifting the frame counts. Task 3, T6 (same seed, same
   shape).

---

### Task 1: The station in Deadlock's key

**Files:**
- Modify: `maps/metro_station_dressing.gd` (`_light`, the `FLUO` family of constants, `_tube`),
  `tools/eclipse/station_shell.py` (a `ward_bracket` piece)
- Test: `tests/metro_station_test.gd` (S6c, new S6f); `tools/eclipse/test_kit_bpy.py` (`StationShell`: the bracket
  closed, through the gate, its cage's lenses `obsidian`)

**Interfaces:**
- Produces: the constants `HAZE`, `COMPANY_BLUE`, `ARC_RED` in `metro_station_dressing.gd` (`StationDressing.HAZE`…),
  read by every later task; `station.lights` holds every light of the station, the machinery's included.

- [ ] **Step 1: Write the failing tests.**
  - **S6f "warm haze against the Company's blue"**, all of these:
    - every station space (`hall`, `stairs_n`, `stairs_s`, `platform_n`, `platform_s`, `track`) is covered by a
      `FogVolume` whose material albedo has r − b ≥ 0.15;
    - the hall and each platform have at least 4 lights with b − r ≥ 0.2 (the Company's blue) and at least 4 with
      r − b ≥ 0.2 (the warm fittings);
    - no light keeps the old `FLUO` colour.
  - **S6c** becomes a report: it always passes, and its detail prints the counts.
- [ ] **Step 2:** Run `bash tools/run_suites.sh tests/metro_station_test.tscn`. Expected: S6f FAIL (no fog volumes;
  the lamps all FLUO).
- [ ] **Step 3: Implement.**
  - **The fittings:** the fluorescent fittings burn warm at `HAZE` and dimmer, as the incandescent warmth of the
    reference's haze. Some coffers' tubes are left dark as a cause: the Company's lamps took their power.
  - **The Company's blue lamps:** a caged lamp in `COMPANY_BLUE` on brackets.
    - Placed on the hall's columns (`HALL_COLUMNS`, facing the walks).
    - And on the platforms' back walls between the name tablets.
    - The cage is the taquillas' `_ward_lamp` form: reuse the taquillas kit's lamp by building a `ward_bracket`
      piece in `tools/eclipse/station_shell.py`.
  - **The haze:** one `FogVolume` per station space, albedo `HAZE`, density a third of the map's.
  - **Ruling:** the exact energies are tuned from the stills.
- [ ] **Step 4:** Run the four suites:
  `bash tools/run_suites.sh tests/metro_station_test.tscn tests/metro_test.tscn tests/pasaje_test.tscn tests/candle_lane_test.tscn`.
  Expected: all PASS, with S6/S6b/S6d/S6f GREEN.
- [ ] **Step 5: Show the user** in-game stills: the hall from both corridors' mouths and from a stair head, a
  platform's length, a column's blue lamp close. Tune the key on their notes, then wait for their word.
- [ ] **Step 6: Commit** `feat(metro): the station in Deadlock's key`.

### Task 2: Neon signs with symbols

**Files:**
- Create: `tools/eclipse/station_neon.py`, `maps/metro_station_machinery.gd`
- Modify: `tools/eclipse/lab.sh` (KITS), `tools/eclipse/test_kit_bpy.py` (class `StationNeon`),
  `maps/metro_station_dressing.gd` (`dress` calls `StationMachinery.dress(station, root)` after `_light`),
  `maps/metro_station.gd` (`var neon: Array[Node3D]`)
- Test: `tests/metro_station_test.gd` (S9)

**Interfaces:**
- Consumes: `NeonSign` (`colour`, `pattern`, `seed`, `energy`, `light_energy`, `light_range`, `buzz`; its tube is
  its first `MeshInstance3D` child), `Neon.material(colour, energy)`.
- Produces:
  - `StationMachinery.dress(station, root) -> void` (the dressing preloads it:
    `const StationMachinery := preload("res://maps/metro_station_machinery.gd")`);
  - `StationMachinery.neon(root, mesh, colour, at, yaw, seed, level_layer) -> NeonSign`: builds the sign, silent, its
    light on `level_layer` plus the movers, appended to `station.lights`;
  - `station.neon` lists every sign;
  - the kit's pieces: `symbol_marigold`, `symbol_eye`, `symbol_skull`, `symbol_serpent`, `symbol_hand`,
    `symbol_arrow` (tubes only, slot `neon`); `blade_company` (the Company's crowned blade sign: a stepped deco crown,
    a blank `sign` face, tube channels for a symbol, a backing in `iron` and `brass`).

- [ ] **Step 1: Write the failing tests.**
  - **Kit `StationNeon`:** the pieces are closed, in budget and through the gate. Every `symbol_*` is only slot
    `neon`, tube radius 0.012–0.02 m, fitting a 0.6 m square. `blade_company` stands under 2.4 m tall and carries a
    `sign` face and a crown of at least 3 stepped tiers.
  - **S9 "the station's signs in neon"**, all of these:
    - every hanging direction sign (the dressing's `sign_board` instances) has a `NeonSign` within 0.5 m of it, an
      arrow and one symbol;
    - a `blade_company` stands on each turnstile bank's pylon (2) and at the engine's place (1, at (0, 6, 0) ± 3 m);
    - every `NeonSign` in `station.neon` has `buzz == &""`, `light_energy > 0`, `light_range >= 3`, and its light
      is in `station.lights`.
- [ ] **Step 2:** Run the kit tests:
  `$BLENDER -b --factory-startup --python-exit-code 1 --python tools/eclipse/test_kit_bpy.py -- StationNeon`.
  Then run the station suite. Expected: both FAIL (no kit, no signs).
- [ ] **Step 3: Implement.**
  - **The kit:** build the symbols as `pipe` polylines.
  - **The placement:** the hanging signs take an arrow and a symbol for where they lead:
    - a platform gets the serpent;
    - a corridor gets the eye;
    - the market stairs get the marigold;
    - the exits get the hand.
  - **Colours:** symbols in `COMPANY_BLUE` and one warm accent colour of your choice per sign family, shown to the
    user.
  - **Ruling:** the engine's blade sign stands where the engine will; Task 5 moves it onto the engine.
- [ ] **Step 4:** Build, paint, import: `bash tools/eclipse/lab.sh station_neon`, then
  `python3 tools/textures/layered_atlas.py station_neon --recipes=underground --import`. Run the four suites.
  Expected: all PASS.
- [ ] **Step 5:** Show the user in-game stills; wait for their word.
- [ ] **Step 6: Commit** `feat(metro): the station's signs in neon`.

### Task 3: The tesla arc

**Files:**
- Create: `scripts/Visual/TeslaArc.gd`, `scripts/Visual/tesla_arc.gdshader`, `tests/tesla_arc_test.gd`,
  `tests/tesla_arc_test.tscn`
- Modify: `tests/metro_test.gd` (M20's spots)

**Interfaces:**
- Produces `class_name TeslaArc extends Node3D`:
  - **exports:**
    - `points: PackedVector3Array` (local; two for a leap, more for a run it rides);
    - `ride := false`;
    - `colour := Color("#5AB4FF")`;
    - `width := 0.05`, `jag := 0.12` (m);
    - `steps_per_second := 18.0`;
    - `reach := 0.6` (a ride's lit length as a fraction of its run);
    - `light_energy := 1.5`, `light_range := 6.0`;
    - `seed := 0`;
  - **members:** `var mesh_instance: MeshInstance3D`, `var light: OmniLight3D`, `var sparks: GPUParticles3D`;
  - `func shape_at(t: float) -> PackedVector3Array`: the arc's polyline at game time `t`, deterministic in `seed`
    and `t`;
  - `func centre_at(t: float) -> Vector3`.
- The ribbon faces the drawing camera. It is rebuilt on its step, not every frame. Its mesh and light are
  uninterpolated. Sparks are a `GPUParticles3D` with a shader-drawn spark (no texture).

- [ ] **Step 1: Write the failing tests** in `tests/tesla_arc_test.gd` (headless, `--fixed-fps 60`):
  - **T1:** a leap's shape starts and ends at its points (≤ 0.01 m), and every inner vertex lies within
    `jag × 1.5` of the line between them.
  - **T2:** the shape changes between t 0 and t 0.2.
  - **T3:** over 3 s its light's energy stays within [0, `light_energy` × 1.5], with a mean ≥ 0.3 × `light_energy`.
  - **T4:** on a ride, `centre_at` moves along the run (its projection advances over 1 s) and stays within
    `jag × 1.5` of the run.
  - **T5:** the mesh, light and sparks are all `PHYSICS_INTERPOLATION_MODE_OFF`.
  - **T6:** two arcs with the same seed have the same `shape_at(1.3)`; different seeds give different shapes.
  - **T7:** its material's shader is `res://scripts/Visual/tesla_arc.gdshader` and binds no texture.
  - **M20 (in `tests/metro_test.gd`):** add the spots `Vector3(4.0, -7.0, 3.0)` (the hall, plan frame) and
    `Vector3(10.0, -13.0, -10.0)` (a platform).
- [ ] **Step 2:** Run `bash tools/run_suites.sh tests/tesla_arc_test.tscn`. Expected: FAIL (no script).
- [ ] **Step 3: Implement `TeslaArc`.**
  - **The bolt:** midpoint displacement seeded by `hash(seed, step)`, with a forked branch now and then.
  - **The ribbon:** a camera-facing strip in an `ImmediateMesh`.
  - **The shader:** unshaded, additive, a hot white core fading to `colour`.
  - **The light:** follows the step with a decaying flicker.
- [ ] **Step 4:** Run the arc test and the four suites. Expected: all PASS.
- [ ] **Step 5: Commit** `feat(fx): the tesla arc`.

### Task 4: The Company's cable runs, arcs riding them

**Files:**
- Create: `tools/eclipse/station_runs.py` (writes `assets/eclipse/kit/station_runs.json`)
- Modify: `tools/eclipse/lab.sh`, `tools/eclipse/test_kit_bpy.py` (class `StationRuns`), `maps/metro_station_machinery.gd`, `maps/metro_station.gd` (`var runs: Array[Node3D]`), `tests/metro_station_test.gd` (S10, S10b), `tests/metro_test.gd` (M24 includes the runs)

**Interfaces:**
- Consumes: `TeslaArc` (Task 3); the engine's terminal (fixed here): `ENGINE_TERMINAL := Vector3(0.0, 10.6, 0.0)`.
- Produces:
  - **The kit:** one piece per run, `run_<name>`, its cable in `brass` with insulator bells in glazed porcelain
    (`talavera_glaze`) and ceiling hangers in `iron`, in the set's frame (placed at the origin, no turn).
  - **`station_runs.json`:** `{name: {"points": [[x, y, z]…], "to": what it powers}}`.
  - **`station.runs`:** each run's piece, with metas `"to"` and `"arc"` (its riding `TeslaArc`).
- **The runs (set frame)**, each from `ENGINE_TERMINAL`, along the hall's ceiling at y ≥ 10.4 (coffers at 0.6 below
  the ceiling are avoided), then down to its end:

  | Run | Ends at |
  |---|---|
  | `bank_west` | the west bank's pylon crown (x −14, z −3.72, y 8.16) |
  | `bank_east` | the east bank's pylon crown (x 14, z 3.72, y 8.16) |
  | `taquilla_east` | over the east booth's crest (x 20, z −11.3, y 9.6) |
  | `taquilla_west` | over the west booth's crest (x −20, z 11.3, y 9.6) |
  | `platform_n` | down the north stairwell's ceiling to the north platform, then along it at y 5.0, z −10.5, x −40…40 |
  | `platform_s` | the south's, mirrored through the south stairwell |

- [ ] **Step 1: Write the failing tests.**
  - **Kit `StationRuns`:** each run piece is closed, in budget and through the gate. Its points match the JSON.
    Every cable segment's radius is ≥ 0.03 (chunky).
  - **S10:** six runs. Each one's first point is within 0.05 of `ENGINE_TERMINAL` and its `"to"` names a placed
    piece within 1 m of its last point. Each has a riding `TeslaArc` (`ride == true`, `colour == COMPANY_BLUE`)
    whose light is in `station.lights`.
  - **S10b:** every run point and every 0.25 m along it stands ≥ 2.4 m over the floor under it, where that floor is
    a walk.
  - **M24:** includes the runs' meshes.
- [ ] **Step 2:** Run the kit class and the station suite. Expected: FAIL.
- [ ] **Step 3:** Implement the kit (sagging catenary between hangers every 2.4–3.6 m, varied by cause: hangers at
  the coffers' ribs) and the placement.
- [ ] **Step 4:** Build, paint, import; run the four suites. Expected: all PASS.
- [ ] **Step 5:** Show the user in-game stills (the hall's ceiling web from below, a platform's run, an arc close);
  wait for their word.
- [ ] **Step 6: Commit** `feat(metro): the Company's cable runs`.

### Task 5: The Company's engine (hero piece, with the user)

**Files:**
- Create: `tools/eclipse/station_engine.py`, `scripts/Visual/Clockwork.gd`
- Modify: `tools/eclipse/lab.sh`, `tools/eclipse/test_kit_bpy.py` (class `StationEngine`), `maps/metro_station_machinery.gd`,
  `maps/metro_station.gd` (`var engine: Node3D`), `tests/metro_station_test.gd` (S11, S11b, S11c)

**Interfaces:**
- Consumes: `TeslaArc`, `NeonSign` / `StationMachinery.neon`, `ENGINE_TERMINAL`.
- Produces:
  - **The kit's pieces:**
    - `engine` (static), centred on (0, 0) of its frame, standing at z 0, its top at z 5.0 (the hall's ceiling);
    - `gear_<n>` (the turning clockwork in its base's windows, each spun about its own +y in Godot);
  - **The kit's constants:** `TERMINALS` (the leap arc's two tube tops, kit frame) and `GAUGES` (each gauge face's
    centre and normal);
  - **`station.engine`:** meta `"footprint"` (Rect2) and `"terminals"` (set frame).
  - **`Clockwork extends Node3D`:** turns its child gear about its local Y at `turns_per_second`, uninterpolated.
- **The shape, from the spec and the patron's hall:**
  - a heavy stepped base (tezontle and iron), windows into its clockwork;
  - bundles of big brass tubes rising into the coffers, ending in the ceiling with collars, leaving where they go to
    interpretation;
  - clusters of gauge faces hung on the bundles, slot `gauge`, drawn by a glowing glass material in Godot with
    occult diagrams (`library_glyphs` stand-ins);
  - a brass ring 0.035 m proud on the floor round it, of radius ≤ 3.4;
  - the leap arc in `ARC_RED` between its `TERMINALS`;
  - the Company's `blade_company` moved onto it (Task 2's ruling).

- [ ] **Step 1: Write the failing tests.**
  - **Kit `StationEngine`:** the pieces are closed, in budget and through the gate. It stands on z 0, its top at
    5.0 ± 0.005. It fits a 6.0 m square. It has ≥ 3 gauge clusters of ≥ 3 faces, ≥ 4 tube bundles reaching z 5.0,
    and ≥ 2 gear pieces. `TERMINALS` lie on its tubes.
  - **S11:** the engine stands at (0, 6, 0) ± 0.01. Its footprint is clear by ≥ 1.5 m of:
    - the stair heads (−6, −12.5) and (6, 12.5);
    - the market stairs' mouth (−10, 14);
    - each lane's approach (x ±12…±16, z −4…4).
  - **S11b:** the player walks from corridor_w's mouth (−29, 7.05, 0) to corridor_e's (29, 7.05, 0) through the
    lanes and round the engine (`_walk_path`).
  - **S11c:** its gears turn (each `Clockwork`'s child basis changes over 0.5 s) uninterpolated. Its leap arc spans
    its terminals.
- [ ] **Step 2:** Run the kit class and the station suite. Expected: FAIL.
- [ ] **Step 3:** Build the shape (`bash tools/eclipse/lab.sh station_engine`). Send renders. Loop on the user's
  notes until they sign the shape off. Their vertex edits are kept (`yours`).
- [ ] **Step 4:** Paint (ask the user for any texture the sheets cannot give), import, place. Run the four suites.
  Expected: all PASS.
- [ ] **Step 5:** Show the user in-game stills from the corridors' mouths, the stair heads, a lane and close; wait
  for their word.
- [ ] **Step 6: Commit** `feat(metro): the Company's engine`.

### Task 6: The astral lamp (hero piece, with the user)

**Files:**
- Create: `tools/eclipse/station_astral.py`, `scripts/Visual/AstralLamp.gd`, `scripts/Visual/astral_core.gdshader`
- Modify: `tools/eclipse/lab.sh`, `tools/eclipse/test_kit_bpy.py` (class `StationAstral`), `maps/metro_station_machinery.gd`,
  `tests/metro_station_test.gd` (S12)

**Interfaces:**
- Produces:
  - **The kit's pieces:** `astral_frame` (its static holder: brass and iron, held by the engine or a bracket) and
    `ring_<n>` (≥ 2 armillary rings, each turned about its own axis in Godot).
  - **`AstralLamp extends Node3D`:**
    - exports `colour := Color("#A05AFF")`, `ring_turns: PackedFloat32Array`, `seed := 0`;
    - its core is a sphere drawn by `astral_core.gdshader`;
    - its light pulses;
    - ≥ 6 glyph quads orbit it (the ward-glyph shader, `scripts/Visual/vfx_ward_glyph.gdshader`);
    - a `FogVolume` in its colour lies at its foot;
    - everything moved is uninterpolated.
- **Places:** one on the engine's front (the spec: "at least one on the engine"); others where the user places them
  from stills.

- [ ] **Step 1: Write the failing tests.**
  - **Kit `StationAstral`:** the pieces are closed, in budget and through the gate. The rings nest without touching
    (≥ 0.02 m apart).
  - **S12:** every `AstralLamp` in the station:
    - its rings turn and its glyphs orbit within 1.5 m of the core over 1 s;
    - its light pulses within [0.4, 1.6] × its energy and is in `station.lights`;
    - its fog volume lies within 2 m below the core;
    - all of it is uninterpolated;
    - one stands within 3.5 m of the engine.
- [ ] **Step 2:** Run the kit class and the station suite. Expected: FAIL.
- [ ] **Step 3:** Build, show renders, and loop with the user until the shape is signed off.
- [ ] **Step 4:** Paint, import, place. Run the four suites. Expected: all PASS.
- [ ] **Step 5:** Show the user in-game stills; wait for their word.
- [ ] **Step 6: Commit** `feat(metro): the astral lamp`.

### Task 7: The taquillas and turnstile banks fed by the engine

**Files:**
- Modify: `maps/metro_station_dressing.gd` (`_taquillas`, `_turnstiles`, `_ward_globe`), `maps/metro_station_machinery.gd`
- Test: `tests/metro_station_test.gd` (S13)

**Interfaces:**
- Consumes: `station.taquillas`, `station.turnstiles` (their metas), the runs ending on them (Task 4).
- Produces: glowing overrides on the existing kits' surfaces by slot name. No kit rebuild unless the user asks for
  new shapes from stills.

- [ ] **Step 1: Write the failing test.** **S13:**
  - every working turnstile cabinet's ward eye (slot `obsidian`) and tally dial (slot `sign`) draws with an emissive
    override in `COMPANY_BLUE`;
  - the fused cabinets' eyes stay dark (`hollow`, no override);
  - the pylons' eyes glow, except the fused bank's blown eye;
  - the taquillas' ward lamps light in `COMPANY_BLUE` (light colour b − r ≥ 0.2), their globes glowing in it.
- [ ] **Step 2:** Run the station suite. Expected: S13 FAIL.
- [ ] **Step 3:** Implement the overrides. The dials are blank glowing faces (the user's words to come).
- [ ] **Step 4:** Run the four suites. Expected: all PASS.
- [ ] **Step 5:** Show the user in-game stills. Apply their notes, each fault with its failing check first. Wait for
  their word.
- [ ] **Step 6: Commit** `feat(metro): the booths and banks fed by the engine`.

### Task 8: The views and the frame's cost

**Files:**
- Create: `tests/metro_station_view_test.gd`, `tests/metro_station_view_test.tscn` (windowed)

- [ ] **Step 1: Write the views** (windowed, 1152×648, the player camera):
  - **SV1:** the engine is in frame and unoccluded (a ray to its centre meets it first) from:
    - corridor_w's mouth (−29, 7.05, 0) looking east;
    - corridor_e's mouth (29, 7.05, 0) looking west;
    - both stair heads looking at it.
  - **SV2:** the frame's cost over 300 frames at those four spots and on a platform, against the candle lane's at
    its mouth. Report only (the user suspended the gate): print both and the ratio.
- [ ] **Step 2:** Run
  `$GODOT --path . --resolution 1152x648 res://tests/metro_station_view_test.tscn`. Expected: SV1 PASS; SV2 prints.
- [ ] **Step 3: Commit** `test(metro): the station's views and its frame cost`.

### After the last task

The final whole-branch review (from the commit before Task 1), its fix pass, the user's play, then the station plan's
Tasks 10–14 in the new register.
