# The Candle Lane Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the candle lane — the Underground corridor bay lengthened into the Metro's lane between the Pasaje and the chapel, the librarian's shop opening off it — as a set reviewed on its own, then instanced into `maps/metro`.

**Architecture:** The bay's script (`maps/underground_lab.gd`) learns any length and a table of placements; `maps/candle_lane.gd` extends it (as `maps/underground_library_lab.gd` does) at half-length 16 m, cuts the shop's arch into its far wall and embeds `maps/library_lab.tscn` behind it, opens its west end onto a Pasaje stub and its east end through the chapel's doorway. A small kit (`tools/eclipse/candle_lane.py`) supplies what the bay lacks; people are flat black silhouette cards rendered by a generalised `tools/textures/silhouettes.py`. `maps/metro.gd` gets a registry of hand-built sets, skipping their spaces' greybox.

**Tech Stack:** Godot 4.5.1 GDScript; Blender 4 kit scripts (`tools/eclipse`, `common.export_piece`); Python 3 + numpy/PIL (`tools/textures`, `tools/level`).

**Spec:** `docs/superpowers/specs/2026-10-23-candle-lane-design.md` (approved Oct 23 2026), with its decisions and calls.

## Global Constraints

- The set's frame is the bay's: x along the lane, z across it (BACK_WALL −2.35 the north wall's tile face, FAR_WALL 4.55 the south's), floor y 0; plan (x, y) = bay (x + 12, z + 74.35); floor −11. In `maps/metro` the set's node sits at `Vector3(12, -11, 74.35)`, unrotated.
- The lane: plan `rect(-4, 72, 28, 78.9)`, height 4.0 (half-length 16 m in the set); the shop's arch on the far (south) wall centred at plan x 19 (bay x 7), its 8 m front from bay x 3 to 11.
- Walk order, chapel → Pasaje (plan x): chapel doorway 28; votive ledges 22–28; his arch 15–23; the stall and the tamale cart 7–13; the niche and its bench 1–4; the mouth −4.
- Passages ≥ 1.1 m wide, clear to 2.1 m, for the player's metre-wide capsule; walks start from a spawn, never teleported into the space.
- The shop keeps its 1.1× frame budget against the bay (L20; windowed `tests/library_render_check.tscn`); the set's cost is measured windowed against the bay and reported.
- Our own VFX; CC0/Apache assets credited in `CREDITS.md`; every word, sign face and glyph is the user's (blank faces left); each new piece reviewed by the user with stills (a clip where it moves) before the next.
- People are flat black silhouette cards; no modelled figures. Sound: silent emitters marked per pocket, no streams.
- Never commit `scripts/Level/Vfx.gd`, `scripts/Visual/Fumes.gd`, `tests/ambient_test.gd`, `tests/underground_lab_test.gd` (another session's); review media under `docs/superpowers/refs/` is not committed. Nothing merged or pushed without the user's OK.
- Long suites take minutes: use the quick suites named per task; the full library/Underground suites only where a task says.
- Commands: `GODOT=/Users/tinkertailorr/Desktop/Godot.app/Contents/MacOS/Godot`, `BLENDER=/Applications/Blender.app/Contents/MacOS/Blender`; work in the `metro-standard` worktree; import new assets with `$GODOT --headless --path . --import` (under a `perl -e 'alarm 200; exec @ARGV'` guard).

## Review Focus

1. **The bay changed under its own map:** `maps/underground_lab` and `maps/underground_library_lab` must look and behave as before after the bay learns any length (Task 2 pins it: same piece transforms at length 12).
2. **The seams at the set's ends inside `maps/metro`:** the lane's mouth meets the greybox Pasaje with no floor step, gap or doubled face, and the chapel doorway meets the greybox chapel the same (Task 9: floor heights equal within 1 cm, the player walks across both).
3. **The shop inside a lane that is not its look-dev bay:** its inspection keys, its effects' camera checks and its ward/shadow/stir keep working when the lab is embedded rotated by π (Task 3: F2/F3 restore checks run in the set).
4. **Silhouettes from behind and edge-on:** a flat card seen side-on vanishes to a line or shows its back; cards must read from the lane's walking line (Task 7: every card faces within 60° of the lane's walking line's nearest point).
5. **The set's stub left on when instanced:** the Pasaje stub and chapel glimpse must hide in `maps/metro`, never double the greybox (Task 9: `standalone == false` hides them; no stub mesh inside a greybox space).

---

### Task 1: The layout — the lane widened, the shop's room, the openings

**Files:**
- Modify: `tools/level/layouts/metro/market.py` (`candle_lane`; new `librarian_shop`)
- Test: `tools/level/test_metro_plan.py`
- Regenerate: `assets/eclipse/metro/plan.json`, `greybox.json`, sheets (`tools/level/level.sh metro`)

**Interfaces:**
- Produces: plan spaces `candle_lane` = `rect(-4, 72, 28, 78.9)`, floor −11, height 4.0, openings `pasaje` at (−4, 75.45) width 6.9, `chapel` at (28, 74.5) width 3.0, `librarian_shop` at (19, 78.9) width 3.0; `librarian_shop` = `rect(15, 78.9, 23, 85.65)`, floor −11, height 4.5, `interior=True`, layer 2, opening `candle_lane` at (19, 78.9) width 3.0. The `pasaje` space's opening to `candle_lane` moves to (−4, 75.45) width 6.9.

- [ ] **Step 1: Write the failing tests** in `test_metro_plan.py`: `test_the_candle_lane_is_the_bays_section` (its polygon spans x −4..28, y 72..78.9; height 4.0; floor −11), `test_the_librarian_shop_opens_off_the_lane` (space exists at `rect(15, 78.9, 23, 85.65)`, interior, its only opening to `candle_lane` at (19, 78.9)), `test_the_lane_opens_wide_on_the_pasaje` (both sides' openings at (−4, 75.45) width 6.9).
- [ ] **Step 2: Run** `python3 tools/level/test_metro_plan.py -k candle -k librarian`. Expected: 3 failures.
- [ ] **Step 3: Edit `market.py`** to the Interfaces values.
- [ ] **Step 4: Run** the three tests and `python3 tools/level/test_plan_check.py`, then `bash tools/level/level.sh metro`. Expected: PASS; the plan check clean (it stops the build otherwise); plan.json regenerated.
- [ ] **Step 5: Run** `perl -e 'alarm 600; exec @ARGV' $GODOT --headless --fixed-fps 60 --path . res://tests/metro_test.tscn`. Expected: M1–M6 pass.
- [ ] **Step 6: Commit** the layout, the test and the regenerated plan assets.

### Task 2: The bay at any length, its pieces from a table

**Files:**
- Modify: `maps/underground_lab.gd`
- Test: `tests/underground_bay_layout_test.gd` + `.tscn` (new, quick)

**Interfaces:**
- Produces: in `underground_lab.gd`, `var half_run := RUN` (every use of `RUN` in building becomes `half_run`; `RUN` stays the bay's default) and `var places := {"stall": Vector3(0, 0, 0), "cart": …, "bench": …, "niche": …, "bin": …, "nahual": NAHUAL_AT, "hat": HAT_AT, "drain_column": DRAIN_COLUMN, "crack_column": CRACK_COLUMN, "vent_x": VENT_X, "trail": [TRAIL_START, TRAIL_BEND, TRAIL_END]}` holding the bay's current values (fill the furniture's from `_furniture`'s current literals), read by the builders instead of the constants. A subclass sets both before `super._ready()`.

- [ ] **Step 1: Write the failing test** `B1 the bay at length 12 builds every piece where it stood`: instantiate `maps/underground_lab.tscn`, record every `MeshInstance3D`/`MultiMeshInstance3D`'s name and global transform into `tests/fixtures/bay_pieces.json` **from the current commit first** (a one-off capture run before Step 3), then assert a fresh build matches it (same names, transforms within 1 mm). `B2 the bay's length and places are settable`: a subclass instance with `half_run = 16` builds floor/walls 32 m long and the stall at `places["stall"]`.
- [ ] **Step 2: Run** the capture, then the suite. Expected: B1 PASS (capture of itself), B2 FAIL (no `half_run`).
- [ ] **Step 3: Implement** `half_run` and `places` in `underground_lab.gd`.
- [ ] **Step 4: Run** the quick suite (B1, B2 PASS), then `tests/underground_lab_test.tscn` and `tests/library_integration_test.tscn` once. Expected: all pass as before (run, never commit, `underground_lab_test.gd`).
- [ ] **Step 5: Commit** `underground_lab.gd`, the new suite and its fixture.

### Task 3: The lane's shell and the shop in its wall

**Files:**
- Create: `maps/candle_lane.gd`, `maps/candle_lane.tscn`
- Test: `tests/candle_lane_test.gd` + `.tscn` (the set's quick suite, C-checks)

**Interfaces:**
- Consumes: Task 2's `half_run`, `places`; `library_lab.tscn` (`standalone`, `player`, `inspection_sections` as `underground_library_lab.gd` uses them).
- Produces: `maps/candle_lane.gd` `extends "res://maps/underground_lab.gd"`; `@export var standalone := true`; `const PLAN_ORIGIN := Vector3(12.0, -11.0, 74.35)`; `const SHOP_FRONT := Vector2(3.0, 11.0)` (bay x); `var shop: Node3D` (the embedded library, `Transform3D(Basis(Vector3.UP, PI), Vector3(7.0, 0.0, FAR_WALL + 0.4))`); `var chapel_door: Node3D` (the east end's doorway, 3.0 m wide, 2.8 m tall, centred bay z 0.15); `func plan_point(bay: Vector3) -> Vector3` (bay → plan coordinates).

- [ ] **Step 1: Write the failing tests:** `C1 the lane is the bay's section, 32 m long` (floor and walls span bay x −16..16; inner z −2.35..4.55; height 4.0); `C2 the shop's front stands in the far wall, its arch centred at plan x 19` (`plan_point` of the shop's arch middle has x 19 ± 0.05; no far-wall tile panel or collision between bay x 3 and 11); `C3 the west end lies open on the Pasaje and the east end opens through a 3 m doorway` (rays along the lane at 1 m and 1.7 m height pass both ends: west fully, east only within the doorway); `C4 the player walks from the lane's mouth into the shop to his desk's front, and through the chapel doorway` (capsule walk from a spawn at bay (−15, 1.05, 1.1), as L7 does); `C5 the shop's keys still work embedded: F2 on and off restores every material, F3 hides and restores its decals` (call `shop.set_form`, `shop.set_decals` as E89/E90 do).
- [ ] **Step 2: Run** `perl -e 'alarm 180; exec @ARGV' $GODOT --headless --fixed-fps 60 --path . res://tests/candle_lane_test.tscn`. Expected: FAIL (no scene).
- [ ] **Step 3: Implement** `candle_lane.gd`: `half_run = 16.0`; after `super._ready()`, free the far-wall panels and split the far wall's collision across `SHOP_FRONT`, free the east end's panels for a doorway wall, free the west end's, embed the shop as the joined map does (player shared, `inspection_sections` appended).
- [ ] **Step 4: Run** the set's suite. Expected: C1–C5 PASS.
- [ ] **Step 5: Render** stills (a `--only=lane_*` group in a new `tests/candle_lane_stills.gd` modelled on `underground_library_stills.gd`): the lane from its mouth, from the chapel end, the shop's front from across the lane. **Send to the user for review**; fix what they flag before the next task.
- [ ] **Step 6: Commit.**

### Task 4: The bay's pieces along the lane, in the walk's order

**Files:**
- Modify: `maps/candle_lane.gd` (its `places` and `half_run` before `super._ready()`)
- Test: `tests/candle_lane_test.gd`

**Interfaces:**
- Consumes: Task 2's `places` keys; the Global Constraints' walk order.

- [ ] **Step 1: Write the failing tests:** `C6 the pieces stand in the walk's order` (plan x of: stall in 7..13, cart in 7..13, niche in 1..4, bench in 1..4, nahual on the bench, drain beside the stall within 2 m); `C7 a body passes every piece` (capsule walk along the lane's middle from the mouth to the chapel doorway, and round the stall and cart, nothing within 0.55 m of the walking line closer than 1.1 m clear); `C8 the services and the vault run the lane's full length` (service runs and vault spans cover bay x −16..16 without a gap over 0.1 m).
- [ ] **Step 2: Run** the set's suite. Expected: C6–C8 FAIL.
- [ ] **Step 3: Set** `places` in `candle_lane.gd` to the walk order (stall at plan x ≈ 10, its back on the north wall; cart beside it toward the mouth; niche and bench on the north wall at plan x ≈ 2.5; the ánimas' drain beside the stall).
- [ ] **Step 4: Run.** Expected: C1–C8 PASS.
- [ ] **Step 5: Stills** of the stall's pocket and the niche's pocket; **user review**.
- [ ] **Step 6: Commit.**

### Task 5: The lane's own pieces — the chapel end, the mouth, the way

**Files:**
- Create: `tools/eclipse/candle_lane.py` (kit `candle_lane`); register in `tools/eclipse/lab.sh` KITS
- Modify: `tools/eclipse/test_kit_bpy.py` (class `CandleLane`), `maps/candle_lane.gd`
- Test: `tests/candle_lane_test.gd`

**Interfaces:**
- Produces: kit objects `chapel_door` (stone frame for the 3.0 × 2.8 m doorway, a worn step), `votive_ledges` (two wall ledges, plan x 22–28, candle stubs as wicks), `milagros_board` (a board of pinned tin milagros by the doorway), `puesto` (a market stall frame with a canvas awning, its sign face blank), `enamel_sign` (blank face, mounted at the mouth), `arrow_plates` (arrows, faces blank of words), `line_band` (the line colour band along both walls at 2.2 m). Wicks: `votive_ledges` (each candle).

- [ ] **Step 1: Write the failing kit tests** in `CandleLane`: closed, in budget (3000 each), through the gate (sliver 0.004 for candles and tin, 0.01 otherwise); doorway opening 3.0 × 2.8 m; ledge candle wicks ≥ 20, all on the ledges' tops; the sign's and arrows' faces a separate `sign` slot.
- [ ] **Step 2: Run** `$BLENDER -b --factory-startup --python-exit-code 1 --python tools/eclipse/test_kit_bpy.py -- CandleLane`. Expected: FAIL (no module).
- [ ] **Step 3: Write the kit**, build it (`bash tools/eclipse/lab.sh candle_lane`), paint it (`python3 tools/textures/layered_atlas.py candle_lane --recipes=underground`).
- [ ] **Step 4: Write the failing set tests:** `C9 the chapel end: the doorway's frame on the east end, votive ledges with lit flames between plan x 22 and 28, the milagros board beside the doorway`; `C10 the mouth: the line's band along both walls, the enamel sign over the mouth, arrows toward the trains (west) and to the south-east exit (east), every face blank`; `C11 standalone, the Pasaje stub (two puestos either side of the mouth, lit backdrops 6 m up and down it) and the chapel's glimpse (warm light 2 m inside the doorway, a backdrop) stand; not standalone, neither does`.
- [ ] **Step 5: Place** the pieces in `candle_lane.gd` (candles via `Vfx.system("candles")` on the ledge wicks, as `LibraryWard` does; the stub and glimpse under one `stub` node shown only when `standalone`).
- [ ] **Step 6: Run** the set's suite. Expected: C1–C11 PASS.
- [ ] **Step 7: Stills** of the chapel end, the mouth and the way's signs; **user review**.
- [ ] **Step 8: Commit** (kit, assets, set, tests).

### Task 6: The silhouettes' poses (review gate)

**Files:**
- Create: `tools/textures/silhouettes.py` (from `tools/textures/librarian_shadow.py`: its dressing functions moved into a shared module `tools/textures/dressing.py`, both scripts importing it)
- Test: `tools/textures/test_silhouettes.py` (pure-Python checks on the written images)

**Interfaces:**
- Produces: `textures/painted/underground/silhouettes.png` (a sheet of cells 256 × 512, black, alpha the shape) and `silhouettes.json` (`{"poses": [{"name", "cell": [col, row], "height_m", "facing"}]}`); poses `bargaining`, `waiting`, `kneeling_a`, `kneeling_b`, `walking_a`, `walking_b`, `walking_c` (posed from the base body; men's and women's dress from `dressing.py`: coat, skirt, rebozo, hat).

- [ ] **Step 1: Write the failing tests:** every pose's cell is opaque black inside, clear outside, the figure touching the cell's foot row (standing on the floor), its height in the json within 1.5–1.95 m (kneelers 1.0–1.3 m); `librarian_shadow.py` still renders its approved still unchanged (pixel-equal to the committed `librarian_shadow.png`).
- [ ] **Step 2: Run** `python3 tools/textures/test_silhouettes.py`. Expected: FAIL.
- [ ] **Step 3: Implement** `dressing.py` and `silhouettes.py`; render.
- [ ] **Step 4: Run.** Expected: PASS.
- [ ] **Step 5: Send the sheet to the user. Do not place silhouettes until they approve the poses** (the no-figures rule; reshape what they flag).
- [ ] **Step 6: Commit** after approval.

### Task 7: People in the lane

**Files:**
- Create: `scripts/Visual/Silhouette.gd` (a two-sided alpha-scissor quad, black, one cell of the sheet)
- Modify: `maps/candle_lane.gd`
- Test: `tests/candle_lane_test.gd`

**Interfaces:**
- Consumes: Task 6's sheet and json.
- Produces: `Silhouette.gd`: `static func make(pose: String) -> MeshInstance3D` (sized from `height_m`, foot at its origin); `candle_lane.gd` `var people: Array[MeshInstance3D]`.

- [ ] **Step 1: Write the failing tests:** `C12 people stand in their pockets: two at the stall (bargaining, waiting), two kneeling at the ledges, three walking at the mouth; none at his arch or the niche`; `C13 every silhouette faces within 60° of the nearest point of the lane's walking line, stands on the floor (foot within 1 cm), and leaves the 1.1 m way clear`.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement** `Silhouette.gd` and the placements.
- [ ] **Step 4: Run.** Expected: C1–C13 PASS.
- [ ] **Step 5: Stills** of each pocket with its people; **user review**.
- [ ] **Step 6: Commit.**

### Task 8: The pockets — light and marked sound

**Files:**
- Modify: `maps/candle_lane.gd`
- Test: `tests/candle_lane_test.gd`

**Interfaces:**
- Produces: `var pockets: Array[Dictionary]` — `{"name": "arch"|"chapel"|"stall"|"niche"|"mouth", "loud": bool, "x": Vector2 (plan x range), "emitters": Array[AudioStreamPlayer3D]}` (emitters named for what will sound there, `stream == null`).

- [ ] **Step 1: Write the failing tests:** `C14 the pockets alternate along the lane, chapel to mouth: quiet, quiet (arch), loud (stall), quiet (niche), loud (mouth)`; `C15 a loud pocket is lit by a different light from its quiet neighbours: neon or bulb against candle (light colours' hue differ by ≥ 30°) and its measured brightness at 1.6 m differs`; `C16 every pocket has its emitters, all silent (no stream)`.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement** the pockets' lights (warm candle pools at the chapel end and niche, the stall's bulb and neon, the mouth's neon from the stub's puestos) and silent emitters.
- [ ] **Step 4: Run.** Expected: C1–C16 PASS.
- [ ] **Step 5: A walk clip** from his arch to the mouth; **user review**.
- [ ] **Step 6: Commit.**

### Task 9: The set in the Metro

**Files:**
- Modify: `maps/metro.gd`, `scripts/Level/GreyboxLoader.gd` (only if `skip` needs it)
- Test: `tests/metro_test.gd` (new M7–M9)

**Interfaces:**
- Consumes: Task 3's `candle_lane.tscn`, `standalone`, `PLAN_ORIGIN`; Task 1's spaces.
- Produces: `maps/metro.gd` `const SETS := {"candle_lane": ["res://maps/candle_lane.tscn", ["candle_lane", "librarian_shop"]]}` (scene, the spaces whose greybox it replaces); sets instanced with `standalone = false` at their `PLAN_ORIGIN`.

- [ ] **Step 1: Write the failing tests:** `M7 the candle lane stands in its place, the greybox gone from its spaces and nowhere else` (the set at (12, −11, 74.35); no greybox mesh named `candle_lane`/`librarian_shop`; `pasaje`'s and `chapel`'s present); `M8 no stub inside the Metro` (the set's `stub` hidden; no visible set mesh inside the greybox `pasaje` or `chapel` volumes); `M9 the player walks from the Pasaje into the lane, to the shop's desk, and through the chapel into lane_se` (floor heights across both seams equal within 1 cm).
- [ ] **Step 2: Run** `metro_test`. Expected: M7–M9 FAIL.
- [ ] **Step 3: Implement** the registry in `metro.gd` (greybox built with the skip list; each set instanced with `standalone = false`; the set's own player removed in favour of the map's — `candle_lane.gd` makes no player when not standalone).
- [ ] **Step 4: Run** `metro_test` (M1–M9 PASS) and the set's suite (C1–C16 PASS).
- [ ] **Step 5: Measure** the set windowed against the bay (a `--set` mode in `tests/library_render_check.gd`: the set's frame and CPU from three eyes along the lane, against the bay's) and report the numbers; the shop's 1.1× check still passes.
- [ ] **Step 6: Commit.**

### Task 10: Review and handoff

**Files:**
- Modify: `docs/superpowers/specs/2026-10-23-candle-lane-design.md` (implementation status), `CREDITS.md` (the silhouettes' base body and walk, if new sources)

- [ ] **Step 1: Run** the quick suites (dressing, candle lane, bay layout) and `metro_test`; then once, the library and Underground suites (`bash tools/run_suites.sh tests/library_lab_test.tscn tests/library_effects_test.tscn tests/library_integration_test.tscn tests/underground_lab_test.tscn`). Expected: all pass; report anything else separately.
- [ ] **Step 2: A showcase walk** (as `tests/library_showcase.tscn`): from the Pasaje through the lane into the shop and out through the chapel, in `maps/metro`.
- [ ] **Step 3: Record** the status, the numbers, what the user approved and what waits on them (their words, sign faces, recordings) in the spec; **commit**.
