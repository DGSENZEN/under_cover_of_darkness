# The Company's Engine: Presence — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The engine reaches out into the hall on its own beat: steam, heat shimmer, breathing light with faked shafts
and a pool, a power pulse to the signs, a strain when a train draws on the line, and quiet oil and soot.

**Architecture:** One `EngineBeat` node under the engine owns the cranks' clock (game time) and emits a stroke per
crank at the top of its piston's travel; everything the engine gives off reads it. The effects are dressed by a new
`maps/metro_station_engine_fx.gd` (static, called from `metro_station_machinery._engine`), from points the engine's
kit writes into `station_engine.json`. New parts (valves, warning lamps) join the engine's works kit.

**Tech Stack:** Godot 4.5 (GDScript, spatial shaders, GPUParticles3D, Decal), Blender 4 kit scripts
(`tools/eclipse/station_engine.py`), headless suites.

**Spec:** docs/superpowers/specs/2026-11-01-engine-presence-design.md

## Global Constraints

- One beat: every effect reads `EngineBeat`; no effect keeps a clock of its own.
- Low-key details: soot and oil only seen up close (soot ring albedo alpha ≤ 0.25; oil decals within the plinth).
- No washing the hall: the engine adds to the hall's light (shafts and pool capped; checked in stills).
- No new sounds; no electric arcs; no volumetric fog; no change to the engine's shape or its parts' motion.
- Our own effects only (no downloaded sprites/textures): gradients, noise and shaders made here.
- Anything moved in `_process` has physics interpolation off.
- Cheap: added draw instances ≤ 40, particles alive ≤ 300 over the whole engine.
- Kit gate: closed solids, no parallel faces within 3 cm, cards excluded; paint with `python3.14`.
- Failing checks first; nothing pushed or merged without the user's word.

## Review Focus

1. Slow motion and pause (TimeFx): the beat, its steam and pulse follow game time; nothing runs on while paused —
   S12 checks the beat holds still while the tree is paused.
2. The station set alone (no lane, no train): no strain, no errors, unprompted valves still blow — S16 runs on the
   station alone.
3. A train's sag (`NeonSign.dim`) and the engine's dip together: they multiply, never fight — S15.
4. Seen from the deck walk (the player inside the shimmer card and among the shafts): no clipping-plane pop, the
   shimmer card fades out within 1.5 m of the eye — S13.
5. Frame cost under the whole effect set: the instance and particle caps — S17.

---

### Task 1: The beat and the breathing core

**Files:**
- Create: `scripts/Visual/EngineBeat.gd`
- Create: `maps/metro_station_engine_fx.gd`
- Modify: `maps/metro_station_machinery.gd` (`_engine`: add the beat, call `EngineFx.dress`)
- Modify: `scripts/Visual/engine_core.gdshader` (uniform `swell`)
- Modify: `scripts/Visual/TrainPass.gd` (`add_to_group(&"metro_train")` in `_ready`)
- Test: `tests/metro_station_test.gd` (`_engine_fx()`, S12)

**Interfaces:**
- Produces: `class_name EngineBeat extends Node`: `@export var turns := 0.25`, `@export var starts: PackedFloat32Array`
  (the cranks' `start`s from the json), `var time: float` (game time, advanced in `_process`), `var strain := 0.0`
  (0-1, set in Task 5), `signal stroke(index: int)` (crank `index`'s angle crosses π/2 mod 2π: its crosshead at the
  top), `func angle(index: int) -> float`, `func swell() -> float` (0-1: rises once a turn with a lift on each stroke),
  `func since_stroke() -> float` (s since the last stroke of any crank).
- Produces: `maps/metro_station_engine_fx.gd` with `static func dress(station, engine: Node3D, data: Dictionary,
  works_kit: Dictionary, works_look: Material) -> void`; the beat is `engine.get_node("beat")`.
- Produces: engine meta `"fx"` → Dictionary filled by each task (`"core"`, `"steam"`, `"plume"`, `"shimmer"`,
  `"shafts"`, `"pool"`, `"pulse"`, `"valves"`, `"warn"`, `"oil"`, `"soot"`).

- [ ] **Step 1: Write the failing test** — S12 in a new `_engine_fx()` (called after `_engine()`):
  - over 4.0 s of frames, `stroke` fires 4 times, once per crank index 0..3;
  - at each stroke, that crank's `head_height(angle)` is within 1 mm of `throw + conrod` (the top);
  - `swell()` sampled over 4 s: min ≤ 0.2, max ≥ 0.8, and its highest sample within 0.15 s after a stroke;
  - the core light's energy tracks `CORE_LIGHT.x * (CORE_LOW + (1 - CORE_LOW) * swell())`, `CORE_LOW := 0.7`, within
    0.01; the core material's `swell` parameter equals `swell()`;
  - paused (`get_tree().paused = true` for 30 frames): `time` does not move; the beat's interpolation is off.
- [ ] **Step 2: Run** `bash tools/run_suites.sh tests/metro_station_test.tscn` — Expected: S12 FAIL (no beat).
- [ ] **Step 3: Implement** `EngineBeat` (pausable, `PROCESS_MODE_PAUSABLE`), the beat added under the engine in
  `_engine` with the cranks' starts, `EngineFx.dress` reading it to drive the core light and the core shader's `swell`
  (the shader brightens its streaks and band by `mix(0.7, 1.3, swell)`), and the train group.
- [ ] **Step 4: Run** the suite — Expected: S12 PASS, the rest as before (41/41 + S12).
- [ ] **Step 5: Commit** `feat(metro): the engine's beat: its strokes, its core breathing on them`.

### Task 2: Steam, plume and shimmer

**Files:**
- Modify: `tools/eclipse/station_engine.py` (`write_json`: `"heads"` — each crank's cylinder top, set frame, out
  along its heading; `"dome"` — the dome's crown)
- Modify: `scripts/Visual/Fumes.gd` (`func burst(count := 3) -> void`, `var bursts := 0`)
- Create: `scripts/Visual/engine_shimmer.gdshader`
- Modify: `maps/metro_station_engine_fx.gd`
- Test: `tests/metro_station_test.gd` (S13), `tools/eclipse/test_kit_bpy.py` (StationEngine: heads and dome written)

**Interfaces:**
- Consumes: `EngineBeat.stroke(index)`.
- Produces: fx `"steam"`: Array[Fumes] by crank index (mouth up at its head, steady `puffs` ≤ 0.5, bursting on its
  stroke); `"plume"`: one Fumes off the dome (steady, `rise` to under the beams' soffit, 6.6 m over the hall floor);
  `"shimmer"`: MeshInstance3D card (quad facing the camera about Y, 3.2 × 2.4 m, from the drum's cornice up).

- [ ] **Step 1: Failing tests** — kit: the json has 4 `heads` 2.9–3.3 m over the hall floor and `dome` at 3.8 m;
  S13: per stroke, `steam[index].bursts` rises by 1 and no other crank's does; the plume is emitting; the shimmer's
  material reads `hint_screen_texture` and is unshaded, `cast_shadow` off, on `Layers.STATION_HALL` only, and its
  shader fades it to 0 within `NEAR_FADE := 1.5` m of the camera (parameter present and set).
- [ ] **Step 2: Run** the kit test and the station suite — Expected: the new checks FAIL.
- [ ] **Step 3: Implement** the json points (re-export with `bash tools/eclipse/lab.sh station_engine`), `Fumes.burst`
  (emits `count` puffs now; counts them), the steam and plume placement, and the shimmer shader (screen-UV offset by
  scrolling noise × `strength` 0.006, faded by depth-softness against what is behind and by `NEAR_FADE`).
- [ ] **Step 4: Run** both — Expected: PASS, the kit gate clean.
- [ ] **Step 5: Commit** `feat(metro): the engine breathes: steam on each stroke, its plume, heat over the drum`.

### Task 3: Shafts and the light's pool

**Files:**
- Modify: `tools/eclipse/station_engine.py` (`write_json`: `"windows"` — centre, heading, width, height, set frame)
- Create: `scripts/Visual/engine_shaft.gdshader`
- Modify: `maps/metro_station_engine_fx.gd`
- Test: `tests/metro_station_test.gd` (S14), `tools/eclipse/test_kit_bpy.py`

**Interfaces:**
- Consumes: `EngineBeat.swell()`.
- Produces: fx `"shafts"`: Array[MeshInstance3D], one per window (a frustum ArrayMesh from the opening out
  `SHAFT_LENGTH := 3.0` m, spreading 1.6×, tilted 25° down); `"pool"`: Array[Decal] (floor, ceiling) centred on the
  engine, radius `POOL_RADIUS := 6.5` m, a radial GradientTexture2D made here.

- [ ] **Step 1: Failing tests** — kit: 4 windows, at 45/135/225/315°; S14: 4 shafts, additive and unshaded,
  no shadows, depth-softened (`soft_depth` > 0), their `strength` = `SHAFT_STRENGTH * mix(0.6, 1.0, swell())` with
  `SHAFT_STRENGTH ≤ 0.35`; pools: 2 decals, `emission_energy ≤ 0.6`, `modulate` = Company blue, alpha following the
  swell between 0.5 and 1.0; nothing of either reaches past 7 m from the engine's middle.
- [ ] **Step 2: Run** — Expected: FAIL.
- [ ] **Step 3: Implement** the window points, the frustum builder, the shaft shader (additive, fades along its
  length and at its edges by view angle, depth-soft against what it touches, a slow drift of our own noise in it),
  the decals.
- [ ] **Step 4: Run** — Expected: PASS.
- [ ] **Step 5: Stills** — the hall from its four corners and from the deck: shafts and pool add to the hall's light
  without a blue wash (the blade-eye lesson). Tune `SHAFT_STRENGTH`/pool energy until so; note the values.
- [ ] **Step 6: Commit** `feat(metro): the engine's light leaves its windows and lies round it`.

### Task 4: The power pulse and the neon's dip

**Files:**
- Modify: `tools/eclipse/station_engine.py` (`write_json`: `"tubes"` — each tube line, foot to top, set frame,
  grouped by row)
- Create: `scripts/Visual/PowerPulse.gd`
- Modify: `scripts/Visual/NeonSign.gd` (`var dip := 1.0`; `_apply` uses `energy_at(_time) * dim * dip`)
- Modify: `maps/metro_station_engine_fx.gd`
- Test: `tests/metro_station_test.gd` (S15), `tools/eclipse/test_kit_bpy.py`

**Interfaces:**
- Consumes: `EngineBeat.stroke(index)`, `EngineBeat.since_stroke()`, `station.runs` (each run's meta `"points"`,
  set frame, starting at the engine's crown), `station.neon`.
- Produces: `class_name PowerPulse extends Node3D`: `func launch(path: PackedVector3Array) -> void`, `var alive: int`,
  glints (one MultiMesh of short emissive capsules, Company blue) moving at `SPEED := 7.0` m/s along a path;
  fx `"pulse"`. On stroke `index` a glint leaves the foot of row `index % 4`'s middle tube and, at its top, carries on
  along the run nearest that top.
- Produces: hall neon (signs on `Layers.STATION_HALL`) `dip = 1.0 - DIP * exp(-since_stroke() / 0.12)`, `DIP := 0.04`.

- [ ] **Step 1: Failing tests** — kit: 4 rows of ≥ 3 tube lines; S15: each stroke launches a glint (alive +1); a glint
  reaches its run's far end in `(row length + run length) / SPEED` ± 0.1 s, then is gone; hall neon's `dip` stays
  in [0.96, 1.0] and is back above 0.995 half a second after a stroke; with `dim = 0.6` the tube's flicker parameter
  is `level() * 0.6 * dip` (they multiply); signs off the hall keep `dip = 1`.
- [ ] **Step 2: Run** — Expected: FAIL.
- [ ] **Step 3: Implement** the tube lines, `PowerPulse`, the dip.
- [ ] **Step 4: Run** — Expected: PASS.
- [ ] **Step 5: Commit** `feat(metro): the engine's power runs up its rows and out to the signs`.

### Task 5: The strain, the valves, the warning lamps, oil and soot

**Files:**
- Modify: `tools/eclipse/station_engine.py` (pieces `valve` ×3 on the dome's shoulder, `warn` lamps ×4 on the gauge
  boards in a new glass slot `glass_warn`; json `"valves"`, `"warn"`, `"oil"` — under each crank)
- Create: `scripts/Visual/engine_warn.gdshader` (amber, flashes by a `flash` uniform)
- Modify: `maps/metro_station_engine_fx.gd`, `maps/metro_station_machinery.gd` (`_glaze`: `glass_warn`)
- Modify: `scripts/Visual/Clockwork.gd` (`var speed := 1.0` multiplying `turns`; time integrated so a change of speed
  never jumps the governor)
- Test: `tests/metro_station_test.gd` (S16, S17), `tools/eclipse/test_kit_bpy.py`

**Interfaces:**
- Consumes: the `metro_train` group's TrainPass (`began`, `peaked`, `strength()`), `EngineBeat.strain`.
- Produces: `strain` eased toward the train's `strength()` at 1/s; the governor's `speed = 1.0 + 1.5 * strain`;
  warn lamps flash at 3 Hz when `strain > 0.3`, dark otherwise; a valve blows (a Fumes `burst(8)` from its mouth) on
  `peaked`, and unprompted, seeded, `VALVE_EVERY := Vector2(25.0, 60.0)` s apart; fx `"oil"`: a small glossy dark
  Decal under each crank (inside the plinth) and a drip (one particle) every 3-7 s from one of them; fx `"soot"`: one
  ring Decal round the foot, albedo alpha ≤ 0.25, from 4.8 to 6.0 m.

- [ ] **Step 1: Failing tests** — kit: 3 valves, 4 warn lamps, gate clean, budget kept; S16: on the station alone,
  no strain, warn dark, a valve blows within 61 s and not again within 25 s; with a TrainPass in the group and
  `start_pass()`: strain > 0.5 at its peak, the governor faster, warn flashing, a valve blowing at `peaked`; strain
  back under 0.05 and warn dark 3 s after the pass fades; oil decals inside the plinth, the soot ring's alpha ≤ 0.25;
  S17: the engine's added instances ≤ 40, particles' `amount` summed ≤ 300.
- [ ] **Step 2: Run** — Expected: FAIL.
- [ ] **Step 3: Implement** the kit pieces (re-export, paint with `python3.14`, import), the warn shader, the strain,
  the valves, Clockwork's speed, oil and soot.
- [ ] **Step 4: Run** the kit test and the station, metro, pasaje and candle lane suites — Expected: all PASS.
- [ ] **Step 5: Commit** `feat(metro): the engine strains when a train draws on the line; oil and soot at its foot`.

### Task 6: Stills and the user's word

- [ ] **Step 1:** In-game stills (windowed): the hall wide from two corners, the engine at the deck rail, the deck
  walk looking up, under a crank (oil), the foot (soot), during a train pass (strain). Close-up inspect every new
  piece and effect; fix any fault found (test first).
- [ ] **Step 2:** Whole-branch review of this plan's range (fresh reviewer), fix pass, ledger.
- [ ] **Step 3:** Send the stills; the user's word before the video is re-recorded without captions.
