# The Zócalo Station (Build 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The Metro's station is built and alive: its ticket hall, two stairwells, two platforms and the track, set
into `maps/metro` in place of their greybox. It is dressed with its scenes, lit by its own fittings, crowded with
shades, and made ready for the MP-68 (build 2).

**Architecture:**
- **The set:** a new set scene `maps/metro_station.tscn` (`maps/metro_station.gd`), built the way the Pasaje's is:
  standalone, or set into the Metro through `SETS` with `standalone = false` at its `PLAN_ORIGIN`.
- **The shell from code:** the walls, floors, ceilings, stairs, platform edges, track and tunnel mouths come from
  two kits (`station_shell`, `station_track`) and the existing underground kits.
- **The big pieces with the user:** eight hero pieces, one kit each, built one at a time in the user's live Blender
  session. The user signs each off before the next starts, and their own vertex edits survive every rebuild
  (Task 2).
- **Life:** reuses ShadeCrowd, Silhouette and Vfx.

**Tech Stack:** Godot 4.5.1 (GDScript), Blender 4 (bpy kit scripts; the Blender MCP for the live session), Python 3
(plan tools, atlas painter).

**Spec:** `docs/superpowers/specs/2026-10-27-metro-station-design.md` (approved Oct 30 2026, with Claude's calls).

## Global Constraints

- **The set's frame:** the plan's axes moved by `PLAN_ORIGIN = Vector3(0, -14, 0)`, with no rotation. The platform
  floors are at y 0. The plan's other levels sit at:
  - the hall floor at y 6 (plan −8), its ceiling at y 11;
  - the track bed at y −1.2 (plan −15.2);
  - the platforms' and track's ceiling at y 5.5 (the hall's slab, 0.5 m, above it).
- **The set's spaces** (plan x, z; the same in the set):
  - `hall` (x −30…30, z −14…14);
  - `stairs_n` (x −8…0, z −30…−14) and `stairs_s` (x 0…8, z 14…30);
  - `platform_n` (x −50…50, z −14…−7) and `platform_s` (x −50…50, z 7…14);
  - `track` (x −50…50, z −7…7);
  - the route meshes inside them: `stairs_n_flight`, `stairs_s_flight`, `track_steps_n`, `track_steps_s`.
  - Their openings are read from `assets/eclipse/metro/greybox.json`, never retyped.
- **Stays greybox:** `corridor_w`, `corridor_e`, `market_stairs`, `siding` and everything beyond. Only their
  openings into the set are finished. `pasaje_n` and `pasaje_s` stay greybox too (the astral passages are shelved).
- **Ready for the MP-68 (build 2):**
  - the track centres at z ±5.6;
  - the running pads' tops at y −1.0;
  - the car's envelope: 2.6 m wide (2.5 m and 5 cm of sway each side), 3.6 m tall over the pads;
  - the car's doors along the platform edge, which stands at |z| 7, its face 0.15 m from the car's side.
- **The walk:**
  - the player's capsule is 1 m wide and 2 m tall; every passage people walk is at least 1.1 m clear and reachable
    from the spawn (the plan's `arrival`, (0, 0, −9) in the set);
  - turnstile lanes at least 1.1 m clear;
  - nothing hangs lower than 2.4 m over a walk.
- **Words:** every face meant for words is the `sign` slot, left blank, or in the invented script
  (`library_glyphs`) as a stand-in. The user writes all words.
- **Figures:** no modelled human figure; the people are shades (Silhouette). New poses are reviewed by the user
  before they are placed.
- **Assets:** all VFX and textures our own; painted with the underground recipes and the user's brush sheets,
  painterly; grid off. No textures.com files in the repository. Review media under `docs/superpowers/refs/` is not
  committed. Claude asks the user for a texture (the mosaic name tablets; the Tenochtitlan model's paint) when that
  piece is reached, never stretching a stand-in.
- **No new sounds.** The station keeps the Metro's existing mix.
- **Kit standard:**
  - solid closed meshes;
  - no layered faces within 3 cm (the gate);
  - no shared atlas texels;
  - budgets per piece;
  - each kit's atlas at most 2048.
- **Judder:** anything moved in `_process` has physics interpolation off (M20 checks it).
- **Light:** at most 40 shadowless lights in the set and at most 2 with shadows.
- **Performance:** the Metro with the station, measured windowed, takes no more than 1.25× the candle lane's frame.
- **Scenes, not sprinkles:** every object stands where a cause puts it, never at even spacing.
- **Review:** each step that changes the look goes to the user as in-game stills from the real Metro, through the
  player camera's field of view. The next big piece waits for the user's word. Never merge or push without it.
- **Do not touch:**
  - the Pasaje's and the candle lane's approved looks (their suites keep passing);
  - other sessions' uncommitted edits (`scripts/Visual/Animas.gd`, `tests/animas_test.gd`).

## Review Focus

1. **The player in the track pit.** From anywhere on the track bed the player can walk back to a platform by
   `track_steps_n` or `track_steps_s`, and nothing on the bed traps the capsule. Task 3 (M23).
2. **Something inside the car's envelope.** No set geometry, sign, cable, light or shade route stands inside the
   MP-68's envelope over either track (2.6 × 3.6 m over the pads, x −50…50). Task 5 (M24), re-run in Task 16.
3. **Shades through solid things.** No crowd route crosses the vitrine, a turnstile cabinet, a bench, a stand, the
   platform edge or the vault's breach. Task 15 (S15b).
4. **The frame's cost on 100 m platforms.** The light budget is held (Task 6, S6c), and the measured frame is no
   more than 1.25× the lane's (Task 16).
5. **The user's edits lost on a rebuild.** A vertex the user moved in a piece's `.blend` survives `lab.sh`'s next
   build of that kit. Task 2 (`YourShapes`).

## File Structure

- **Create:**
  - `maps/metro_station.gd`, `maps/metro_station.tscn`: the set.
  - `tests/metro_station_test.gd` / `.tscn`: the set's suite (S-checks).
  - `tests/metro_station_view_test.gd` / `.tscn`: the windowed views (SV-checks).
  - `tools/eclipse/yours.py`: the user's shapes kept through rebuilds (Task 2).
  - `tools/eclipse/station_shell.py`: tile wall modules, columns, ceilings, platform edges, stair treads and rails,
    tunnel portals, sign hangers and blank signs, the line map board, the fluorescent fittings.
  - `tools/eclipse/station_track.py`: running pads, guide bars, safety rails, guard boards, the drain channel.
  - The big pieces' kits: `tools/eclipse/station_taquillas.py`, `station_turnstiles.py`, `station_tenochtitlan.py`,
    `station_shrine.py`, `station_benches.py`, `station_cabin.py`, `station_vault.py`, `station_stands.py`.
- **Modify:**
  - `tools/level/layouts/metro/places.py` and `tools/level/test_metro_plan.py`: the scenes' landmarks moved to
    their places in the station.
  - `tools/eclipse/common.py` (`export_piece` keeps the user's shapes), `tools/eclipse/harvest.py` (reads them),
    `tools/eclipse/lab.sh` (KITS), `tools/eclipse/test_kit_bpy.py` (gate classes and `YourShapes`).
  - `maps/metro.gd`: `SETS`.
  - `tools/textures/silhouettes.py` and `tools/textures/test_silhouettes.py`: the waiting and working poses.
  - `tests/metro_test.gd`: M21–M24.
  - `tests/library_render_check.gd`: `-- --station`.

Commands used throughout:

- **Godot:** `GODOT=/Users/tinkertailorr/Desktop/Godot.app/Contents/MacOS/Godot`;
  `BLENDER=/Applications/Blender.app/Contents/MacOS/Blender`.
- **The suites:**
  `bash tools/run_suites.sh tests/metro_station_test.tscn tests/metro_test.tscn tests/pasaje_test.tscn tests/candle_lane_test.tscn`
  (logs in `$TMPDIR/suites/`).
- **One kit's gate class:**
  `$BLENDER -b --factory-startup --python-exit-code 1 --python tools/eclipse/test_kit_bpy.py -- <Class>`.
- **Build, paint and import a kit:** `bash tools/eclipse/lab.sh <kit>`;
  `python3 tools/textures/layered_atlas.py <kit> --recipes=underground --import`.

---

### Task 1: The station's scenes in the plan

**Files:** Modify `tools/level/layouts/metro/places.py`, `tools/level/test_metro_plan.py`; regenerate
`assets/eclipse/metro/`.

**Interfaces:**
- **Produces:** the plan's landmarks where the station puts their causes (plan frame):
  - `jammed_turnstiles` at (−14, HALL, −2): the west bank's fused half;
  - `ticket_booth` / `ticket_seller` at (20, HALL, −13): the east taquillas against the hall's north wall;
  - `motorman_ofrenda` at (42, PLATFORM, −12.8): beside the relief cabin, which takes x 44…50;
  - `seeping_track` unchanged at (−40, TRACK, 0): it is where the vault's seepage reaches the rails.

- [ ] **Step 1: Write the failing test** `test_the_station_scenes_stand_at_their_causes` in `test_metro_plan.py`,
  asserting the four landmarks' positions above.
- [ ] **Step 2: Run it and watch it fail.** Run `cd tools/level && python3 -m unittest test_metro_plan`.
  Expected: the new test FAILS on `jammed_turnstiles`.
- [ ] **Step 3: Move them** in `places.py` (their causes' words unchanged), and regenerate with
  `bash tools/level/level.sh metro` (0 problems).
- [ ] **Step 4: Run the plan tests and the Metro suite.** Expected: all OK; metro 19/19 (its labels move with them).
- [ ] **Step 5: Commit.** `git commit -m "plan(metro): the station's scenes where their causes stand"`

---

### Task 2: The user's shapes kept through rebuilds

The spec routes the user's edits through the level workshop (`tools/level/level.sh workshop`), but that serves the
level kits (`kit.py`), not the eclipse kits these pieces are built in. This task gives the eclipse kits the same
promise. Rule on it in the ledger.

**Files:**
- Create: `tools/eclipse/yours.py`
- Modify: `tools/eclipse/common.py`, `tools/eclipse/harvest.py`, `tools/eclipse/test_kit_bpy.py`

**Interfaces:**
- **Produces (`yours.py`):**
  - `YOURS = ROOT / "assets/eclipse/source/yours"`;
  - `stamp(objects) -> None`: sets each mesh object's custom property `built` to `fingerprint(o)`;
  - `fingerprint(o) -> str`: the sha1 of its vertex positions (rounded to 0.1 mm) and face indices;
  - `harvest(objects, kit) -> list[str]`: for each object whose `fingerprint` differs from its `built`, writes
    `YOURS/<kit>/<object>.npz` (positions, faces, material index per face, uv per loop) and returns the names;
  - `keep(objects, kit) -> list[str]`: replaces each object's mesh with its `.npz` when one exists (its material
    slots kept) and returns the names. It prints `yours: <kit>/<name> no longer built` for each `.npz` with no
    object of that name, and never deletes it.
- **`common.export_piece`:** calls `yours.keep(...)` before it unwraps and gates, and `yours.stamp(...)` on what it
  saves.
- **`harvest.py`:** runs `yours.harvest(...)` beside `weather.harvest(...)`.

- [ ] **Step 1: Write the failing tests:** class `YourShapes` in `test_kit_bpy.py`, using a two-object test kit (a
  box and a cylinder) exported to a temporary folder, with `yours.YOURS` pointed there.
  - `test_a_moved_vertex_survives_the_next_build`: move one box vertex 5 cm, `harvest`, rebuild → the vertex is
    still 5 cm out; the cylinder is as generated.
  - `test_an_untouched_piece_writes_nothing`: rebuild with no edit → no `.npz` written.
  - `test_a_kept_shape_still_meets_the_gate`: the kept box goes through `gate.check` like any piece.
  - `test_a_shape_for_a_piece_no_longer_built_is_reported_not_lost`: an `.npz` for `gone` → `keep` returns no
    `gone`, prints the line, and the file is still there.
- [ ] **Step 2: Run them and watch them fail** (no module `yours`).
- [ ] **Step 3: Write `yours.py`, and hook it into `common.export_piece` and `harvest.py`.**
- [ ] **Step 4: Run `YourShapes` and every gate class** (`$BLENDER ... test_kit_bpy.py`). Expected: all OK. Rebuild
  one existing kit (`bash tools/eclipse/lab.sh pasaje_shell`); `git status` shows no change in
  `assets/eclipse/source/yours/`.
- [ ] **Step 5: Commit.** `git commit -m "feat(eclipse): the user's shapes kept through a kit's rebuild"`

---

### Task 3: The set, walkable, in its place

**Files:**
- Create: `maps/metro_station.gd`, `maps/metro_station.tscn`, `tests/metro_station_test.gd`,
  `tests/metro_station_test.tscn`
- Modify: `maps/metro.gd`, `tests/metro_test.gd`

**Interfaces:**
- **Produces (`metro_station.gd`, `extends Node3D`):**
  - `const PLAN_ORIGIN := Vector3(0, -14, 0)`;
  - `const SPACES := ["hall", "stairs_n", "stairs_s", "platform_n", "platform_s", "track"]`;
  - `const ROUTES_TAKEN := ["stairs_n_flight", "stairs_s_flight", "track_steps_n", "track_steps_s"]`;
  - `const TRACKS_Z := [-5.6, 5.6]`, `const PAD_TOP := -1.0`, `const CAR := Vector2(2.6, 3.6)`;
  - `const EDGE_Z := 7.0`;
  - `static func spaces() -> Dictionary`: the greybox records of `SPACES` (name → its record, with `gaps`), read
    from `assets/eclipse/metro/greybox.json` and moved into the set's frame;
  - `@export var standalone := true`, `var host_player: Node3D`, `var player: CharacterBody3D`;
  - `var shell: Array[Node3D]` (its structural boxes: the collision);
  - standalone: its own WorldEnvironment (the Pasaje's `_environment()`) and the player at the arrival,
    (0, 1.05, −9), facing west.
- **Metro:** `SETS` gains `"metro_station": ["res://maps/metro_station.tscn", SPACES + ROUTES_TAKEN]`.
- **The structure from boxes:**
  - each space's floor, walls cut round its gaps, ceiling, and the slab between the hall and what is under it;
  - the platform edges' faces down to the bed;
  - each stairwell's flight as treads (rise 0.17 m at most, the player's step) along the greybox flight's line, with
    its switchback landing;
  - the track's bed;
  - at each end, a mouth 4.4 m wide and 4.6 m tall round each track, running 12 m on into the dark to a black cap;
  - the east end's centre left open for the walkers' way to `temple_tunnel_way`;
  - the west end's centre left open for `siding_tunnel`.
  - Walls end SEAM (1 cm) short of every greybox plane they meet, as the Pasaje's do.

- [ ] **Step 1: Write the failing tests.**
  - `metro_station_test.gd` (headless, the Pasaje suite's shape):
    - **S1 "the shell at the plan's measure":**
      - floors at y 0 (platforms, stairs' feet), 6 (hall) and −1.2 (bed);
      - ceilings at 5.5 and 11;
      - a ray at 1.5 m over its floor through the middle of every gap in `spaces()` passes, and one 0.5 m beside it
        meets wall.
    - **S2 "walked":** `_walk_path` from the arrival east along `platform_n` to x 40 and west to x −45; from the
      arrival through `stairs_n` up its flight into the hall; across the hall to `stairs_s` and down to
      `platform_s`.
    - **S3 "the tunnel mouths run on into the dark":** for each track at each end, a ray along the track from x ±45
      outward passes x ±50 and meets the black cap between x ±60 and ±63.
  - `metro_test.gd`:
    - **M21 "the station in its place":** the set is at `PLAN_ORIGIN`; the greybox has none of `SPACES` and
      `ROUTES_TAKEN`; it still has `corridor_w`, `corridor_e`, `market_stairs`, `siding`.
    - **M22 "walked from the arrival":** a `_tour` from the arrival up `stairs_n`, across the hall, out of each of
      its gaps 2 m into `corridor_w`, `corridor_e` and `market_stairs`, and down `stairs_s` to `platform_s`.
    - **M23 "out of the pit":** from the bed at (−20, −15.2, 0) and (20, −15.2, −5.6), a `_tour` reaches
      `platform_n` by `track_steps_n` and `platform_s` by `track_steps_s`.
- [ ] **Step 2: Run them and watch them fail.** `metro_station_test`: it fails to load. `metro_test`: M21–M23
  FAIL.
- [ ] **Step 3: Write `metro_station.gd`** and register it in `metro.gd`'s `SETS`.
- [ ] **Step 4: Run the suites.** Expected: S1–S3, metro all (M1's arrival still stands on the floor; the
  generalized set checks M11–M15 hold for the station's seams), Pasaje and lane unchanged.
- [ ] **Step 5: Commit.** `git commit -m "feat(metro): the station set, walkable, in its place"`

---

### Task 4: The shell dressed

**Files:** Create `tools/eclipse/station_shell.py`; Modify `lab.sh`, `test_kit_bpy.py`, `maps/metro_station.gd`,
`tests/metro_station_test.gd`

**Interfaces:**
- **Produces:**
  - kit `station_shell`:
    - tile wall modules (1.2 m) for the hall (5 m), the platforms (5.5 m) and the stairwells, in the line's colour
      band;
    - columns (the hall's two rows; the row between the tracks);
    - the hall's coffered ceiling;
    - the platform's ceiling;
    - platform edge copings with the yellow line, 0.5 m in from the edge;
    - stair treads' nosings and handrails;
    - tunnel portals;
    - sign hangers, direction signs and the line map board, their faces the `sign` slot;
    - the mosaic name tablets' frames, their faces the `sign` slot (the user's texture comes later);
    - the fluorescent fittings (housings; their tubes the `lit` slot).
  - It reuses `underground_floor` (floor tile) and `underground_services` (wall services).
  - Placed by `metro_station._shell_dressing()`. Not solid: the boxes stay the collision.
  - `var wall_panels`, `var columns`, `var signs: Array[MeshInstance3D]`.
- **Columns:**
  - none within 1.5 m of any gap's line;
  - the hall's columns clear of the routes Task 15 will walk;
  - between the tracks, at z 0 from x −44 to 38, at most every 8 m, none in a car's envelope.

- [ ] **Step 1: Write the failing tests.**
  - Gate class `StationShell`.
  - **S4 "tiled to every gap and corner":** every 1.2 m module of every wall run has a panel except across a gap.
  - **S4b "the signs blank":** every sign's word face is the `sign` slot; no Label3D under the set.
  - **S4c "over the walks, nothing lower than 2.4 m."**
- [ ] **Step 2: Run them and watch them fail.**
- [ ] **Step 3: Model, build, paint and import the kit; place it.** The tile is the Pasaje's line band. **Before
  placing the tablets, ask the user for the mosaic name tablets' texture.** Until it comes, the tablets stay framed
  and blank, and say so in the stills.
- [ ] **Step 4: Run the gate and the suites.** Expected: all PASS.
- [ ] **Step 5: Commit, send stills, wait.**
  - Commit message: `feat(metro): the station's shell dressed`.
  - Stills: the arrival looking west; the hall from the north stairs' head; down the south stairwell.
  - Wait for the user's word.

---

### Task 5: The track, laid for the MP-68

**Files:** Create `tools/eclipse/station_track.py`; Modify `lab.sh`, `test_kit_bpy.py`, `maps/metro_station.gd`,
`tests/metro_station_test.gd`, `tests/metro_test.gd`

**Interfaces:**
- **Produces:** kit `station_track`, in 10 m modules along x:
  - two concrete running pads per track (their tops at `PAD_TOP`, 0.3 m wide, centred 1.0 m either side of the
    track's centre);
  - the guide bars outside them;
  - steel safety rails between them;
  - the guard boards over the guide bars;
  - the drain channel between the tracks, under the column row;
  - placed by `metro_station._track()`, the pieces solid where a foot can stand.

- [ ] **Step 1: Write the failing tests.**
  - Gate class `StationTrack`.
  - **S5 "two tracks laid end to end":** for each track at every 1 m of x from −50 to 50, the pads' tops at
    `PAD_TOP` ± 1 cm.
  - **M24 "nothing inside the car's envelope":** no face of the set and no light lies inside the box `CAR` wide by
    `CAR.y` tall over `PAD_TOP`, centred on each track, over x −50…50. Re-run in Task 16.
- [ ] **Step 2: Run them and watch them fail.**
- [ ] **Step 3: Model, build, paint, import, place.**
- [ ] **Step 4: Run the gate and the suites** (M23's walk out of the pit re-run over the laid track). Expected:
  all PASS.
- [ ] **Step 5: Commit, send stills (the track from the platform's edge, the east mouth and the walkers' way),
  wait.** Commit message: `feat(metro): the track laid for the MP-68`.

---

### Task 6: The station's light

**Files:** Modify `maps/metro_station.gd`, `tests/metro_station_test.gd`

**Interfaces:**
- **Produces:**
  - `var lights: Array[Light3D]`;
  - the fluorescent fittings' tubes lit (an emissive `lit` look);
  - the Light Company's brass lamps where it has patched: by the taquillas, at the relief cabin, over the vault's
    breach. These are placed in their tasks, but counted here.
- **One strip by the vault flickers:** the seepage is in its ballast. Its flicker runs off a clock with physics
  interpolation off, and with no sound.

- [ ] **Step 1: Write the failing tests.**
  - **S6 "every walk lit":** along S2's walks, the light reaching a point 1 m up (summed falloff of the set's
    lights and the strips' emission probe) is never under the Pasaje's darkest street point.
  - **S6b "the tunnel mouths dark":** no light within 6 m of a mouth's far half.
  - **S6c "the light in budget":** at most 40 shadowless lights; at most 2 with shadows.
- [ ] **Step 2: Run them and watch them fail.**
- [ ] **Step 3: Light the hall's coffers, the platforms' strips and the stairwells.**
- [ ] **Step 4: Run the suites.** Expected: all PASS.
- [ ] **Step 5: Commit, send stills (the same three as Task 4, and the platform from its east end), wait.**
  Commit message: `feat(metro): the station lit by its own fittings`.

---

### The big pieces (Tasks 7–14): the loop every one follows

Each big piece is one kit (`station_<piece>`), built with the user in their live Blender, one at a time. The next
starts only when the user signs this one off **in game**.

1. **Write its failing tests:**
   - its gate class (closed, in budget, through the gate, its named pieces present);
   - its placement checks in `metro_station_test` (named in its task);
   - S2's walks re-run with it placed.
2. **Run them and watch them fail.**
3. **Build it with the user:**
   - write `tools/eclipse/station_<piece>.py` in the hero stall's manner (shape first, big bevels, details that read;
     `docs/superpowers/refs/underground/recipe.md`), and build it (`bash tools/eclipse/lab.sh station_<piece>`);
   - open `assets/eclipse/source/station_<piece>.blend` in the user's live Blender through the Blender MCP, frame
     the piece, and send viewport renders;
   - change it on the user's notes and rebuild. The user may push vertices in that file themselves; they save in
     Blender, and the next build keeps their shapes (Task 2);
   - loop until the user signs the shape off.
4. **Paint, import, place it** in the set at its anchor; run its gate and the suites.
5. **Send in-game stills** from the real Metro through the player camera's field of view; wait for the user's word.
   Fix each fault they name with its failing check first.
6. **Commit:** `feat(metro): the station's <piece>`.

Anchors are in the set's frame (= the plan's x, z; y above that level's floor).

### Task 7: The taquillas

- **Cause:** the Light Company sells the rides here, through brass bars, from wooden booths with a lamp each.
- **What:** two booths, each 2–3 windows behind brass bars, with counters, cash slots, the Company's lamp and the
  `sign` slot over each window:
  - east: against the hall's north wall at x 16…24, on the unpaid side of the east bank;
  - west: against the south wall at x −24…−16.
- **Tests:**
  - **S7:** each booth stands against its wall, within its x range, its windows facing into the hall;
  - **S7b:** 2 m of clear floor in front of each window (the queue's room).

### Task 8: The turnstile bank

- **Cause:** the surge on the Eclipse's first night fused the west bank's south half open, and nobody has paid
  there since. The Company patched the rest with its wood.
- **What:** two banks across the hall at x −14 and x 14, marking the paid zone between them:
  - each bank's turnstile cabinets across z −4…4, with railings from them to the north and south walls;
  - the west bank's half across z −4…0 fused open, scorched (`jammed_turnstiles`), and its other half patched in
    wood;
  - the east bank working: its arms turn a third when anyone walks through (an Area3D per lane, the turn on a clock
    with interpolation off). The fused arms never move.
  - Dressing: nothing stops anyone.
- **Tests:**
  - **S8:** every lane at least 1.1 m clear;
  - **S8b:** the player walks through every lane both ways;
  - **S8c:** a working arm turns as the player passes, and a fused one doesn't.

### Task 9: The model of Tenochtitlan under its glass

- **Cause:** the city keeps its old self under glass where everyone passes. It is the hall's landmark.
- **What:**
  - a vitrine 4.0 × 3.0 m on a plinth at the hall's centre (0, 6, 0);
  - the island city, its causeways, the lake, the Templo Mayor, in relief under the glass;
  - a brass rail round it.
- **Before painting it, ask the user for the model's paint.**
- **Tests:**
  - **S9:** its footprint within 0.1 m of 4.0 × 3.0 at the centre;
  - **S9b:** 2.0 m clear walk all round it;
  - **S9c:** its glass is see-through, as the `sign` and glass slots are made by `SetKit.place`.

### Task 10: The Virgin's shrine

- **Cause:** the workers who dug the station set her where the stairs go down, and the riders keep her candles lit.
- **What:**
  - a tiled niche in the hall's north wall at x 1…3, inside the paid zone;
  - her image (the `sign` slot: the user's picture later);
  - candles, milagros and flowers at her feet;
  - one brass lamp (counted in S6c).
- **Tests:**
  - **S10:** the niche is cut into the wall run, not stood proud of it (no face within 3 cm of the wall's);
  - **S10b:** its candles flicker without judder (M20).

### Task 11: The Light Company's benches

- **Cause:** the Company replaced the broken stone benches with its own wood and brass.
- **What:** about 6 benches a platform against the back walls, in groups by cause, never evenly spaced:
  - some by the stairs' doors, where the riders wait;
  - none by the vault;
  - none before the cabin;
  - none before a tablet.
- **Tests:**
  - **S11:** every bench's back is within 0.1 m of its back wall, and its front at least 4.5 m from the platform's
    edge;
  - **S11b:** no two benches' gaps are equal within 0.3 m.

### Task 12: The driver's relief cabin

- **Cause:** the drivers change shifts here. The motorman lost the night the lines stopped is kept in an ofrenda
  beside it (`motorman_ofrenda`).
- **What:**
  - a wooden cabin at `platform_n`'s east end, x 44…50, z −14…−11.5, against the back and end walls, with its door
    and window onto the platform;
  - the Company's lamp;
  - the ofrenda at (42, 0, −12.8).
- **Tests:**
  - **S12:** the cabin is within its footprint, its door facing the platform;
  - **S12b:** 1.1 m clear between it and the platform's edge.

### Task 13: The cracked colonial vault

- **Cause:** the colonial drain behind the tiles broke the wall. Its water seeps across the platform and onto the
  rails (`seeping_track`).
- **What:**
  - a breach in `platform_n`'s back wall at x −44…−38: the tile cracked away from a brick colonial vault about
    2 m deep;
  - lit within by one brass lamp the Company hung;
  - the seepage running out of it across the platform as a wet runnel to the edge at x ≈ −40, and down onto the bed;
  - ward candles at its foot;
  - a look-in only: its breach blocked to the walk at 1.0 m in.
- **Tests:**
  - **S13:** the breach is cut through the wall run (the wall has no panel across x −44…−38 below its top);
  - **S13b:** the player cannot walk more than 1.0 m into it;
  - **S13c:** from the arrival looking west, its lamp's pixels are in frame (in Task 16's views).

### Task 14: The vendors' stands

- **Cause:** riders eat on the way, and the stairs' feet and heads are where they pass.
- **What:**
  - a tamale and coffee stand at each stairs' foot: `platform_n` against its back wall at x 1…3; `platform_s` at
    x −3…−1;
  - a shoeshine stand by `stairs_n`'s head in the hall at (−10, 6, −12.5);
  - a lottery seller's stand by `stairs_s`'s head at (10, 6, 12.5);
  - steam from the food (Fumes `pot_steam`).
- **Tests:**
  - **S14:** each stand is within 0.3 m of its anchor, clear of its doorway's 1.1 m line;
  - **S14b:** each food stand steams.

---

### Task 15: Life: the crowd of shades

**Files:** Modify `tools/textures/silhouettes.py`, `tools/textures/test_silhouettes.py`, `maps/metro_station.gd`,
`tests/metro_station_test.gd`

**Interfaces:**
- **Produces:**
  - Silhouette poses `wait_paper`, `wait_bag`, `wait_child`, `wait_lean`, `queue_stand`, `shoeshine_kneel`,
    `lottery_hawk`;
  - in `metro_station.gd`:
    - `const ROUTES` (the Pasaje's route shape: `[name, points, every, keep, along]`, points in the set's frame and
      on its floors, following the flights' slope on the stairs);
    - `var crowds: Array[Node3D]` (one ShadeCrowd each for the hall, the two stairwells and the two platforms);
    - `var waiting: Array[MeshInstance3D]`, `var queues: Array[MeshInstance3D]`, `var workers: Array[MeshInstance3D]`.
- **Where they go:**
  - **Routes:**
    - each corridor's mouth ↔ its bank (most of the west's through the fused lane) ↔ a stairs' head;
    - the market stairs ↔ the stairs' heads;
    - each stairwell, from head to door;
    - each platform from its door to near its ends and back.
  - **Waiting shades:** 14–20 a platform, standing 0.8 m or more back from the edge. They are thickest within 10 m
    of the stairs' doors and thin toward the ends.
  - **Queues:** 3–6 at each taquilla.
  - **At work:** a vendor at each stand, the shoeshine man and the lottery seller.

- [ ] **Step 1: Make the seven poses and send them to the user as stills; wait for their word before placing
  them.** `test_silhouettes.py` gains a check that each pose renders a filled silhouette.
- [ ] **Step 2: Write the failing tests.**
  - **S15 "the station alive":** shades formed on every route within 60 s; at least 14 waiting on each platform,
    half of them within 10 m of its door; a queue at each taquilla; a worker at each stand.
  - **S15b "none through solid things":** no route segment crosses a footprint of the vitrine, a turnstile cabinet,
    a bench, a stand, the cabin, the breach, or the platform's edge; on the stairs every route point is within
    0.15 m of the flight's slope.
  - **S15c "the crowd moves without judder"** (M20 at a hall spot and a platform spot).
- [ ] **Step 3: Run them and watch them fail.**
- [ ] **Step 4: Lay the routes, the waiting, the queues and the workers.** Run the suites. Expected: all PASS.
- [ ] **Step 5: Commit, send stills (the platform from the arrival, the hall from the east bank, the north
  stairwell), wait.** Commit message: `feat(metro): the station crowded with its shades`.

---

### Task 16: The views, the frame's cost and the whole Metro

**Files:** Create `tests/metro_station_view_test.gd` / `.tscn`; Modify `tests/library_render_check.gd`,
`tests/metro_test.gd`

- [ ] **Step 1: Write the view checks.** Run windowed with
  `$GODOT --path . --fixed-fps 60 --resolution 1152x648 res://tests/metro_station_view_test.tscn`, in the Pasaje
  view test's shape.
  - **SV1:** from the arrival looking west, the vault's lamp in frame (S13c), and less than 2 % greybox in the
    frame's middle third (the Pasaje's PV3 measure).
  - **SV2:** from `stairs_n`'s head looking south, the vitrine and a taquilla projected in frame and not occluded.
  - **SV3:** from `platform_n` at x 30 looking east, the mouths' far halves darker than every lit wall in the
    frame.
- [ ] **Step 2: Run them.** SV1–SV3 PASS. Any FAIL is a defect in Tasks 3–15, fixed with its own failing check
  first.
- [ ] **Step 3: Measure the frame.** Add `-- --station` to `library_render_check.gd`: three eyes (the hall's
  centre, the arrival, `platform_s` at x −30) against the lane's three. Expected: no more than 1.25×. Over it, cut
  draws (MultiMesh repeated tile modules, benches and signs; merge static pieces per wall run) until it is under.
- [ ] **Step 4: The whole Metro.**
  - Run `bash tools/run_suites.sh tests/metro_station_test.tscn tests/metro_test.tscn tests/pasaje_test.tscn tests/candle_lane_test.tscn tests/underground_lab_test.tscn tests/ambient_test.tscn tests/talk_quest_test.tscn`;
  - run every gate class (`$BLENDER ... test_kit_bpy.py`), the plan tests, and the view tests
    (`metro_station_view_test`, `pasaje_view_test`, `lane_landmarks_view_test`).
  - Expected: all PASS.
- [ ] **Step 5: Send the user the station's final stills and a walk clip** from the arrival up through the hall and
  down to `platform_s` (`tests/tour_video.gd`'s way), then commit:
  `git commit -m "test(metro): the station's views, its frame's cost, the whole Metro"`
